extends SceneTree
## One game client process for tests/net/test_shared_world.gd (NOT a test suite). Runs the REAL WorldStage scene fed by an
## OnlineSession against net/server_main.gd, drives a scripted command stream with ordinary commands, then writes its final view.
##   godot --headless --path . -s tests/net/shared_client.gd -- --role A|B --dir <control dir>
## Files in <dir>: tokens.json (in), <role>.trace (progress lines), <role>.done (script finished), frozen.flag (in), <role>.view (out)
var role: String = "A"
var dir: String = ""
var session: OnlineSession
var stage: WorldStage
var trace: PackedStringArray = []
var event_counts: Dictionary = {}
var captures: Array = []
var combat_events: Array = []
var t0: int = 0
var errors: Array = []
var fogged_rival_at_start: bool = false
var stage_ok: bool = false
var leaked: int = 0
var peak_state_plots: int = 0
var peak_stage_plots: int = 0
var peak_foreign_plots: int = 0

func _initialize() -> void:
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var i := 0
	while i < a.size() - 1:
		if a[i] == "--role": role = a[i + 1]
		if a[i] == "--dir": dir = a[i + 1]
		i += 2
	t0 = Time.get_ticks_msec()
	_run()

func _t(msg: String) -> void:
	var line := "[%6.2f] %s" % [float(Time.get_ticks_msec() - t0) / 1000.0, msg]
	trace.append(line)
	var f := FileAccess.open(dir.path_join(role + ".trace"), FileAccess.WRITE)
	f.store_string("\n".join(trace))
	f.close()

func _frames(n: int) -> void:
	for _i in n:
		await process_frame

func _wait(cond: Callable, timeout: float = 60.0) -> bool:
	var end: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < end:
		if cond.call():
			return true
		await process_frame
	return false

func _st() -> MatchState:
	return session.state

func _me() -> Dictionary:
	return _st().actors[session.actor_id]

## submit a command and wait for the server's verdict
func _do(type: StringName, args: Dictionary, label: String = "") -> Dictionary:
	var r: Dictionary = session.command(type, args)
	if not r.get("ok", false):
		_t("%s %s -> local refusal %s" % [label, type, r.get("error")])
		return r
	var seq: int = r["seq"]
	var got: bool = await _wait(func(): return session.client.results.has(seq), 20.0)
	var res: Dictionary = session.client.results.get(seq, {"ok": false, "error": "timeout"})
	_t("%s %s %s -> %s %s" % [label, type, JSON.stringify(args), "ok" if res.get("ok") else "FAIL", res.get("error", "")])
	if not got:
		errors.append("timeout " + label)
	return res

func _walk_to(h: Vector2i, timeout: float = 60.0) -> bool:
	var r: Dictionary = await _do(&"move_intent", {"to": h}, "walk")
	if not r.get("ok", false):
		return false
	var ok: bool = await _wait(func(): return _me()["hex"] == h, timeout)
	_t("walk arrived=%s at %s" % [ok, str(_me()["hex"])])
	return ok

func _walk_adjacent(h: Vector2i, timeout: float = 60.0) -> bool:
	for n in HexGrid.neighbors(h):
		if WorldGen.move_cost(_st().world, n) > 0.0 and CmdUtil.holding_at(_st(), n) == -1 and not _st().plots.has(MatchState.plot_key(n)):
			if await _walk_to(n, timeout):
				return true
			break
	return false

func _wait_tend(plots: Array[Vector2i], timeout: float) -> bool:
	var end: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	var day_watered: int = -1
	while Time.get_ticks_msec() < end:
		for h in plots:
			var key: String = MatchState.plot_key(h)
			if _st().plots.has(key) and int(_st().plots[key]["age"]) >= 2:
				return true
		var day: int = int(_st().clock["day"])
		if day != day_watered:
			day_watered = day
			for h in plots:
				var key2: String = MatchState.plot_key(h)
				if _st().plots.has(key2) and not bool(_st().plots[key2]["watered"]):
					await _do(&"water", {"hex": h}, "A-rewater")
		await process_frame
	return false

func _neutral_near(home: Vector2i) -> Dictionary:
	var best: Dictionary = {}
	var bd: int = 99999
	for h in _st().holdings.values():
		if int(h["owner"]) == -1:
			var d: int = HexGrid.distance(home, h["hex"])
			var score: int = int(h["tier"]) * 100 + d
			if d <= 12 and score < bd:
				bd = score
				best = h
	return best

func _home_of(fid: int) -> Dictionary:
	return _st().holdings.get(int(_st().factions[fid]["home"]), {})

func _on_events(evs: Array) -> void:
	for e in evs:
		var t: String = str(e.get("type", ""))
		event_counts[t] = int(event_counts.get(t, 0)) + 1
		if e.has("actor") and e["actor"] is int and _st().actors.has(e["actor"]) and int(_st().actors[e["actor"]]["faction"]) != int(_me()["faction"]):
			if e.has("items") or e.has("loot") or e.has("coin") or e.has("refund"):
				leaked += 1
		if t == "holding_captured" or t == "capture_failed":
			captures.append({"type": t, "holding": int(e.get("holding", -1)), "by": int(e.get("by", -9)), "from": int(e.get("from", -9))})
		if t in ["actor_attacked", "actor_damaged", "item_stolen", "steal_failed", "actor_died"]:
			combat_events.append({"type": t, "actor": int(e.get("actor", -1)), "target": int(e.get("target", -1))})
	if stage != null:
		stage.on_events(evs, _st())

func _on_updated() -> void:
	if stage != null and stage.started:
		stage.farm.sync_from_state(_st())
		peak_state_plots = maxi(peak_state_plots, _st().plots.size())
		peak_stage_plots = maxi(peak_stage_plots, stage.farm.plots.size())
		var foreign := 0
		for k in _st().plots:
			if int(_st().holdings[int(_st().plots[k]["holding"])]["owner"]) != int(_me()["faction"]):
				foreign += 1
		peak_foreign_plots = maxi(peak_foreign_plots, foreign)

func _run() -> void:
	# --- connect
	if not await _wait(func(): return FileAccess.file_exists(dir.path_join("tokens.json")), 60.0):
		errors.append("no tokens.json")
		_finish()
		return
	var cfg: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join("tokens.json")))
	var idx: String = "0" if role == "A" else "1"
	session = OnlineSession.join("127.0.0.1", int(cfg["port"]), String(cfg["players"][idx]["token"]))
	root.add_child(session)
	session.events_emitted.connect(_on_events)
	session.state_updated.connect(_on_updated)
	if not await _wait(func(): return session.is_ready(), 30.0):
		errors.append("never joined")
		_finish()
		return
	_t("joined as actor %d faction %d" % [session.actor_id, int(_me()["faction"])])
	# --- the real WorldStage scene
	stage = WorldStage.new()
	root.add_child(stage)
	stage.start_from_state_sync(_st())
	stage_ok = stage.started
	_t("WorldStage started=%s chunks=%d" % [stage.started, stage.view.chunks.size()])
	stage.farm.sync_from_state(_st())
	var rf := FileAccess.open(dir.path_join(role + ".ready"), FileAccess.WRITE)
	rf.store_string("1")
	rf.close()
	if not await _wait(func(): return FileAccess.file_exists(dir.path_join("go.flag")), 60.0):
		errors.append("no go.flag")
	_t("go")
	# the rival's leader must be a fogged stub at the beginning (they live 50+ hexes apart)
	var rival_fid: int = 1 if role == "A" else 0
	var rl: Dictionary = _st().actors.get(int(_st().factions[rival_fid]["leader"]), {})
	fogged_rival_at_start = bool(rl.get("fogged", false)) and (rl.get("inv", {"x": 1}) as Dictionary).is_empty()
	_t("rival fogged at start=%s" % fogged_rival_at_start)
	if role == "A":
		await _script_a()
	else:
		await _script_b()
	_t("script finished")
	var f := FileAccess.open(dir.path_join(role + ".done"), FileAccess.WRITE)
	f.store_string("1")
	f.close()
	# --- wait for the freeze, take a final snapshot, dump our view
	await _wait(func(): return FileAccess.file_exists(dir.path_join("frozen.flag")), 120.0)
	session.client.request_snapshot()
	await _frames(40)
	_finish()

func _script_a() -> void:
	var st: MatchState = _st()
	var home: Dictionary = _home_of(0)
	var plots: Array[Vector2i] = []
	for h in HexGrid.ring_within(_me()["hex"], 2):
		if plots.size() >= 2:
			break
		if h != _me()["hex"] and CmdUtil.holding_at(st, h) == -1:
			var r: Dictionary = await _do(&"plant", {"crop": "lfg:crop/glowfruit", "hex": h}, "A-plant")
			if r.get("ok", false):
				plots.append(h)
	for h in plots:
		await _do(&"water", {"hex": h}, "A-water")
	_t("planted %d plots" % plots.size())
	# keep the crops watered each day until ripe (rules: unwatered glowfruit does not grow), then harvest
	var ripe: bool = await _wait_tend(plots, 90.0)
	_t("ripe=%s day=%d" % [ripe, int(_st().clock["day"])])
	var hv_ok := 0
	for h in plots:
		var key: String = MatchState.plot_key(h)
		if _st().plots.has(key) and int(_st().plots[key]["age"]) >= 2:
			var gl0: int = int(_me()["inv"].get("lfg:item/glowfruit", 0))
			var r2: Dictionary = await _do(&"harvest", {"hex": h}, "A-harvest")
			if r2.get("ok", false):
				hv_ok += 1
	_t("harvested %d" % hv_ok)
	# construction: withdraw materials from our own holding, build a palisade
	await _do(&"trade", {"holding": home["id"], "side": "withdraw", "item": "lfg:item/timber", "qty": 4}, "A-withdraw")
	await _do(&"trade", {"holding": home["id"], "side": "withdraw", "item": "lfg:item/stone", "qty": 2}, "A-withdraw")
	await _do(&"build", {"holding": home["id"], "building": "lfg:building/wall"}, "A-build")
	# trade with the nearest neutral merchant
	var m: Dictionary = _neutral_near(home["hex"])
	_t("merchant %d tier %d at %s" % [m["id"], m["tier"], str(m["hex"])])
	if await _walk_adjacent(m["hex"]):
		await _do(&"trade", {"holding": m["id"], "side": "sell", "item": "lfg:item/glowfruit", "qty": 2}, "A-sell")
		await _do(&"trade", {"holding": m["id"], "side": "buy", "item": "lfg:item/sporebean_seed", "qty": 1}, "A-buy")
	# wait for the Purge and try to take the merchant town (commit what the garrison allows)
	await _wait(func(): return _st().phase == &"PURGE_ACTIVE", 240.0)
	_t("purge active; day %d" % int(_st().clock["day"]))
	var commit: int = mini(3, int(_st().holdings[int(home["id"])]["garrison"]))
	var cap: Dictionary = await _do(&"capture", {"holding": m["id"], "commit": commit}, "A-capture(commit %d)" % commit)
	# fight the rival (B arrives during the warning phase and is within sight)
	var rival: int = int(_st().factions[1]["leader"])
	await _wait(func(): return not bool(_st().actors[rival].get("fogged", false)), 20.0)
	_t("rival visible=%s hex=%s" % [not bool(_st().actors[rival].get("fogged", false)), str(_st().actors[rival]["hex"])])
	var hits := 0
	for _i in 4:
		if HexGrid.distance(_me()["hex"], _st().actors[rival]["hex"]) <= 1:
			var r3: Dictionary = await _do(&"attack", {"target": rival}, "A-attack")
			if r3.get("ok", false):
				hits += 1
		await _frames(25)
	_t("hits=%d" % hits)

func _script_b() -> void:
	var home: Dictionary = _home_of(1)
	await _do(&"trade", {"holding": home["id"], "side": "withdraw", "item": "lfg:item/ration", "qty": 2}, "B-withdraw")
	await _do(&"eat", {"item": "lfg:item/ration"}, "B-eat")
	var a_home: Dictionary = _home_of(0)
	var m: Dictionary = _neutral_near(a_home["hex"])
	await _walk_adjacent(m["hex"], 120.0)
	await _wait(func(): return _st().phase == &"PURGE_ACTIVE", 240.0)
	_t("purge active")
	# A is within sight now; try to take the same town (may fail), steal from it, then fight A
	var a_actor: int = int(_st().factions[0]["leader"])
	await _wait(func(): return not bool(_st().actors[a_actor].get("fogged", false)), 20.0)
	_t("A visible=%s hex=%s" % [not bool(_st().actors[a_actor].get("fogged", false)), str(_st().actors[a_actor]["hex"])])
	await _do(&"capture", {"holding": m["id"], "commit": 0}, "B-capture")
	await _do(&"steal", {"holding": m["id"], "item": "lfg:item/coin", "qty": 1}, "B-steal")
	var hits := 0
	for _i in 4:
		if HexGrid.distance(_me()["hex"], _st().actors[a_actor]["hex"]) <= 1:
			var r: Dictionary = await _do(&"attack", {"target": a_actor}, "B-attack")
			if r.get("ok", false):
				hits += 1
		await _frames(25)
	_t("hits=%d" % hits)

func _finish() -> void:
	var st: MatchState = _st() if session != null else null
	var view := {"role": role, "errors": errors, "trace_lines": trace.size(), "stage_started": stage_ok,
		"fogged_rival_at_start": fogged_rival_at_start, "events": event_counts, "captures": captures, "combat": combat_events, "leaked_items": leaked, "peak_state_plots": peak_state_plots, "peak_stage_plots": peak_stage_plots, "peak_foreign_plots": peak_foreign_plots}
	if st != null:
		view["actor"] = session.actor_id
		view["player_id"] = st.player_id
		view["plots"] = st.plots.keys()
		view["stage_plots"] = stage.farm.plots.keys() if stage != null else []
		view["hud_class"] = stage.hud.class_label.text if stage != null else ""
		view["stage_player_hex"] = [stage.player.current_hex.x, stage.player.current_hex.y] if stage != null else []
		view["session_ended"] = session.end_reason
		var f := FileAccess.open(dir.path_join(role + ".snapshot"), FileAccess.WRITE)
		f.store_string(var_to_str(session.last_snapshot))
		f.close()
	var g := FileAccess.open(dir.path_join(role + ".view"), FileAccess.WRITE)
	g.store_string(JSON.stringify(view))
	g.close()
	quit(0)
