class_name Sim
extends RefCounted
## Clock, phase machine, movement, effects, daily processing. Driven only by Rules.tick.
const MAX_STEP := 5.0
const WALK_SEC_PER_HEX := 4.0
const ENERGY_REGEN := 2.0

static func _boundary_dt(state: MatchState) -> float:
	var ds: float = state.day_seconds
	var tod: float = state.tod()
	var dt: float = (1.0 - tod) * ds
	var dow: int = state.day_of_week()
	if dow == 7 and tod < Calendar.PURGE_START_TOD:
		dt = minf(dt, (Calendar.PURGE_START_TOD - tod) * ds)
	if dow == 1 and state.week() >= 1 and tod < Calendar.RESOLUTION_END_TOD:
		dt = minf(dt, (Calendar.RESOLUTION_END_TOD - tod) * ds)
	return dt

static func run(state: MatchState, dt: float, events: Array) -> void:
	if dt <= 0.0 or is_nan(dt) or is_inf(dt) or state.over:
		return
	var remaining: float = dt
	while remaining > 1e-9 and not state.over:
		var step: float = minf(remaining, MAX_STEP)
		if EnemyAI.engaged(state):
			step = minf(step, 0.1)
		elif _any_moving(state):
			step = minf(step, 0.5)
		elif AIFactions.has_parties(state):
			step = minf(step, 1.0)
		step = minf(step, maxf(_boundary_dt(state), 1e-4))
		advance(state, step, events)
		remaining -= step

static func _any_moving(state: MatchState) -> bool:
	var p: Dictionary = state.player()
	return not p.is_empty() and not (p["move"] as Dictionary).is_empty()

static func advance(state: MatchState, step: float, events: Array) -> void:
	state.clock["elapsed"] = MatchState.q(float(state.clock["elapsed"]) + step)
	state.clock["day_t"] = MatchState.q(float(state.clock["day_t"]) + step)
	state.clock["time_of_day"] = MatchState.q(state.tod())
	var rolled: bool = false
	if state.day_seconds - float(state.clock["day_t"]) < 1e-5:
		state.clock["day"] = int(state.clock["day"]) + 1
		state.clock["day_t"] = 0.0
		state.clock["time_of_day"] = 0.0
		rolled = true
		events.append({"type": &"day_changed", "day": state.clock["day"]})
	var np: StringName = Calendar.phase_for(int(state.clock["day"]), state.tod())
	if np != state.phase:
		var old: StringName = state.phase
		state.phase = np
		events.append({"type": &"phase_changed", "from": old, "to": np, "day": state.clock["day"]})
		if np == &"PURGE_ACTIVE":
			_spawn_wave(state, events)
			if state.opts.get("ai_enabled", true):
				AIFactions.purge_round(state, events)
		elif np == &"RESOLUTION":
			settle(state, events)
	if rolled:
		dawn(state, events)
	_actors(state, step, events)
	if state.opts.get("ai_enabled", true):
		state.ai_t = MatchState.q(state.ai_t + step)
		var per: float = AIFactions.period(state)
		while state.ai_t >= per:
			state.ai_t = MatchState.q(state.ai_t - per)
			if state.phase == &"PURGE_ACTIVE":
				AIFactions.purge_round(state, events)
		AIFactions.party_step(state, events)
	Fx.step(state, events)
	EnemyAI.step(state, events)

static func dawn(state: MatchState, events: Array) -> void:
	Economy.dawn_buildings(state, events)
	Economy.drift_prices(state)
	Farming.dawn_crops(state, events)
	if state.opts.get("ai_enabled", true):
		AIFactions.dawn(state, events)
	Economy.dawn_recruit(state, events)
	var fids: Array = state.factions.keys()
	fids.sort()
	for fid in fids:
		if state.factions[fid]["alive"]:
			Economy.feed_faction(state, fid, events)
	Economy.check_victory(state, events)
	Economy.check_starved_out(state, events)
	if state.over:
		return

static func _actors(state: MatchState, step: float, events: Array) -> void:
	var now: float = float(state.clock["elapsed"])
	var ids: Array = state.actors.keys()
	ids.sort()
	for id in ids:
		var a: Dictionary = state.actors[id]
		if not a["alive"]:
			continue
		if a["kind"] != "enemy":
			var regen: float = ENERGY_REGEN * Combat.offgrove_mult(state, a)
			a["energy"] = MatchState.q(minf(float(a["max_energy"]), float(a["energy"]) + regen * step))
		# poison / expiry
		var effs: Array = a["effects"]
		if not effs.is_empty():
			for e in effs:
				if e["id"] == "poison":
					while float(e["next"]) <= now and float(e["next"]) <= float(e["until"]) + 1e-9 and a["alive"]:
						e["next"] = MatchState.q(float(e["next"]) + 1.0)
						Combat.hurt(state, int(id), int(e["dps"]), int(e.get("source", -1)), events, "poison")
			var keep: Array = []
			for e in effs:
				if float(e["until"]) > now:
					keep.append(e)
			a["effects"] = keep
		# movement
		var mv: Dictionary = a["move"]
		if a["alive"] and not mv.is_empty() and not Movement.rooted(state, a):
			var path: Array = mv["path"]
			mv["acc"] = MatchState.q(float(mv["acc"]) + step)
			var moved: bool = false
			while not path.is_empty():
				var nxt: Vector2i = path[0]
				var cost: float = Movement.step_secs(state, a, nxt)
				if cost <= 0.0:
					path.clear()
					break
				if float(mv["acc"]) + 1e-9 >= cost:
					mv["acc"] = MatchState.q(float(mv["acc"]) - cost)
					a["hex"] = nxt
					path.remove_at(0)
					moved = true
					events.append({"type": &"actor_moved", "actor": id, "hex": nxt})
				else:
					break
			if path.is_empty():
				a["move"] = {}
				if moved:
					events.append({"type": &"move_finished", "actor": id, "hex": a["hex"]})

static func _spawn_wave(state: MatchState, events: Array) -> void:
	var homes: Array[int] = state.holdings_of(0)
	if homes.is_empty() or not state.opts.get("wild_enemies", true):
		return
	var n: int = mini(2 + state.week(), 8)
	var kinds: Array = Content.enemies().keys()
	kinds.sort()
	var spawned: Array[int] = []
	for i in range(n):
		var hid: int = homes[state.rand_i(homes.size())]
		var center: Vector2i = state.holdings[hid]["hex"]
		var ring: Array[Vector2i] = []
		for hx in HexGrid.ring_within(center, 6):
			var d: int = HexGrid.distance(hx, center)
			if d >= 4 and int(state.world["terrain"][HexGrid.index(hx)]) == WorldGen.T_GROUND:
				ring.append(hx)
		if ring.is_empty():
			continue
		var hx2: Vector2i = ring[state.rand_i(ring.size())]
		var arch: String = String(kinds[state.rand_i(kinds.size())])
		var eid: int = Setup.spawn_enemy(state, arch, hx2, true)
		if eid != -1:
			spawned.append(eid)
	events.append({"type": &"purge_wave", "enemies": spawned, "week": state.week()})

static func settle(state: MatchState, events: Array) -> void:
	## Runs exactly once per completed purge.
	var done_week: int = state.week() - 1
	if state.settled_week >= done_week:
		return
	state.settled_week = done_week
	var removed: int = 0
	for id in state.actors.keys().duplicate():
		var a: Dictionary = state.actors[id]
		if a["kind"] == "enemy" and (bool(a.get("wave", false)) or not a["alive"]):
			state.actors.erase(id)
			removed += 1
	var counts: Dictionary = {}
	for fid in state.factions.keys():
		counts[fid] = state.holdings_of(int(fid)).size()
	var p: Dictionary = state.player()
	if not p.is_empty() and p["alive"]:
		Combat.heal(p, int(int(p["max_hp"]) * 0.3))
	events.append({"type": &"purge_resolved", "week": done_week, "holdings": counts, "enemies_removed": removed})
	if done_week + 1 >= Calendar.CROWNED_WEEKS and state.won == "":
		state.won = "crowned"
		events.append({"type": &"victory", "kind": "crowned", "weeks": done_week + 1})
	Economy.check_victory(state, events)
