extends RulesTestBase
## Authoritative leader movement: path walking, smooth positions, validated sync_position (anti-teleport), move_to_pos.

func _step_from(s: MatchState, from: Vector2i, n: int) -> Array[Vector2i]:
	## n hexes of straight eastward walking over passable ground.
	var out: Array[Vector2i] = []
	var cur: Vector2i = from
	for i in range(n):
		var nx: Vector2i = cur + Vector2i(1, 0)
		if WorldGen.move_cost(s.world, nx) <= 0.0:
			break
		out.append(nx)
		cur = nx
	return out

func _sync(s: MatchState, hx: Vector2i) -> Dictionary:
	return cmd(s, "sync_position", {"hex": hx})

func test_sync_accepts_honest_walking_pace() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = s.actors[1]
	var path: Array[Vector2i] = _step_from(s, p["hex"], 6)
	check(path.size() >= 4, "have room to walk")
	var accepted: int = 0
	for hx in path:
		var need: float = Movement.step_secs(s, p, hx)
		tick_all(s, need, 0.5)          # presentation walks the hex, then reports it
		var r: Dictionary = _sync(s, hx)
		check(r["ok"], "honest step to %s: %s" % [str(hx), r["error"]])
		if r["ok"]:
			accepted += 1
			eq(p["hex"], hx, "authoritative hex follows")
	eq(accepted, path.size(), "every honest step accepted")

func test_sync_rejects_teleports_and_speed_hacks() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = s.actors[1]
	var start: Vector2i = p["hex"]
	var before: String = snap(s)
	var far: Vector2i = start + Vector2i(12, 0)
	eq(_sync(s, far)["error"], "too_fast", "12 hexes away at t=0")
	eq(snap(s), before, "rejected syncs mutate nothing (not even seq)")
	eq(p["hex"], start, "stays put")
	# sustained cheating: sync one hex per 0.5s forever
	var path: Array[Vector2i] = _step_from(s, start, 30)
	var rejected: int = 0
	for hx in path:
		tick_all(s, 0.5, 0.5)
		if not _sync(s, hx)["ok"]:
			rejected += 1
			break
	check(rejected > 0, "running at ~4x speed is eventually refused")
	var walked: int = HexGrid.distance(start, p["hex"])
	check(walked <= 6, "speed hack gained at most the banked allowance (%d hexes)" % walked)

func test_sync_rejects_impassable_oob_and_malformed() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = s.actors[1]
	tick_all(s, 30.0, 1.0)
	eq(_sync(s, Vector2i(9999, 9999))["error"], "bad_hex", "out of bounds")
	eq(cmd(s, "sync_position", {})["error"], "bad_hex", "missing hex")
	eq(cmd(s, "sync_position", {"hex": "x"})["error"], "bad_hex", "wrong type")
	var water: Vector2i = Vector2i(-9999, 0)
	for d in range(2, 6):
		for dir in HexGrid.DIRS:
			var h: Vector2i = p["hex"] + dir * d
			if HexGrid.in_bounds(h) and WorldGen.move_cost(s.world, h) <= 0.0:
				water = h
				break
		if water.x != -9999:
			break
	if water.x != -9999:
		eq(_sync(s, water)["error"], "impassable", "cannot stand in deep water or on a cliff")
	var same: Dictionary = _sync(s, p["hex"])
	check(same["ok"], "syncing the current hex is a harmless no-op")

func test_sync_respects_class_speed_and_root() -> void:
	var slow: MatchState = quiet("lfg:class/tavi")
	var fast: MatchState = quiet("lfg:class/pip")
	var pa: Array[Vector2i] = _step_from(slow, slow.actors[1]["hex"], 8)
	var pb: Array[Vector2i] = _step_from(fast, fast.actors[1]["hex"], 8)
	var n: int = mini(pa.size(), pb.size())
	check(n >= 3, "walkable")
	# burn the initial bank, then walk at Pip's pace: Tavi must be refused, Pip accepted
	tick_all(slow, 40.0, 1.0)
	tick_all(fast, 40.0, 1.0)
	_sync(slow, pa[0])
	_sync(fast, pb[0])
	var slow_ok: bool = true
	var fast_ok: bool = true
	for i in range(1, n):
		var secs: float = Movement.step_secs(fast, fast.actors[1], pb[i])
		tick_all(fast, secs, 0.5)
		tick_all(slow, secs, 0.5)
		fast_ok = fast_ok and _sync(fast, pb[i])["ok"]
		slow_ok = slow_ok and _sync(slow, pa[i])["ok"]
	check(fast_ok, "Pip keeps pace at Pip's speed")
	var r: MatchState = quiet()
	Combat.add_effect(r.actors[1], "rooted", 100.0)
	tick_all(r, 20.0, 1.0)
	eq(_sync(r, _step_from(r, r.actors[1]["hex"], 1)[0])["error"], "rooted", "rooted leaders cannot be moved by sync")
	check(not slow_ok, "Tavi cannot keep Pip's pace (n=%d)" % n)

func test_world_pos_interpolates_along_the_walk() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = s.actors[1]
	var start: Vector2 = HexGrid.to_world(p["hex"])
	eq(Rules.actor_pos(s, 1), start, "standing still")
	var to: Vector2i = p["hex"] + Vector2i(3, 0)
	var r: Dictionary = cmd(s, "move_intent", {"to": to})
	check(r["ok"], "walk")
	var last: float = 0.0
	var mono: bool = true
	for i in range(20):
		Rules.tick(s, 0.5)
		var d: float = Rules.actor_pos(s, 1).distance_to(start)
		if d + 0.0001 < last:
			mono = false
		last = d
	check(mono, "distance from start never decreases")
	var mid: Vector2 = Rules.actor_pos(s, 1)
	var on_grid: bool = false
	for hx in [p["hex"]]:
		on_grid = mid.distance_to(HexGrid.to_world(hx)) < 0.001
	check(not on_grid or p["move"].is_empty(), "between hexes while moving")
	check(last > 8.0, "moved ~half a hex or more in 10s (%f m)" % last)
	var q: MatchState = quiet()
	cmd(q, "move_intent", {"to": q.actors[1]["hex"] + Vector2i(2, 0)})
	Rules.tick(q, 1.0)
	var ps: Vector2 = Rules.actor_pos(q, 1)
	var h0: Vector2 = HexGrid.to_world(q.actors[1]["hex"])
	check(ps.distance_to(h0) > 0.5 and ps.distance_to(h0) < HexGrid.HEX_METERS, "1s in: partway (%f m)" % ps.distance_to(h0))

func test_move_to_pos_walks_and_validates() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = s.actors[1]
	var target: Vector2i = p["hex"] + Vector2i(2, 0)
	var w: Vector2 = HexGrid.to_world(target)
	eq(HexGrid.from_world(w), target, "from_world inverts to_world")
	eq(HexGrid.from_world(w + Vector2(2.0, -1.5)), target, "anywhere inside the hex maps to it")
	var r: Dictionary = cmd(s, "move_to_pos", {"pos": [w.x, w.y]})
	check(r["ok"], "move_to_pos: %s" % r["error"])
	tick_all(s, 30.0, 0.5)
	eq(p["hex"], target, "arrived")
	eq(cmd(s, "move_to_pos", {"pos": [1.0]})["error"], "bad_pos", "bad shape")
	eq(cmd(s, "move_to_pos", {"pos": ["a", "b"]})["error"], "bad_pos", "bad type")
	eq(cmd(s, "move_to_pos", {"pos": [1e12, 0.0]})["error"], "bad_pos", "absurd")
	eq(cmd(s, "move_to_pos", {"pos": [-5000.0, -5000.0]})["error"], "bad_hex", "outside the world")
	eq(cmd(s, "move_to_pos", {})["error"], "bad_pos", "missing")
