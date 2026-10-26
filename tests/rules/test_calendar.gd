extends RulesTestBase

func test_phase_table() -> void:
	eq(Calendar.phase_for(1, 0.0), &"PEACE", "d1")
	eq(Calendar.phase_for(5, 0.99), &"PEACE", "d5 end")
	eq(Calendar.phase_for(6, 0.0), &"WARNING", "d6")
	eq(Calendar.phase_for(7, 0.2), &"WARNING", "d7 morning")
	eq(Calendar.phase_for(7, 0.5), &"PURGE_ACTIVE", "d7 night")
	eq(Calendar.phase_for(7, 0.99), &"PURGE_ACTIVE", "d7 late")
	eq(Calendar.phase_for(8, 0.0), &"RESOLUTION", "d8 resolution")
	eq(Calendar.phase_for(8, 0.5), &"PEACE", "d8 later")
	eq(Calendar.phase_for(1, 0.0), &"PEACE", "no resolution in week 0")
	eq(Calendar.phase_for(14, 0.6), &"PURGE_ACTIVE", "week 2 purge")

func test_default_day_is_six_minutes_and_configurable() -> void:
	var s: MatchState = Rules.new_match(5, &"lfg:class/judd", {"ai_enabled": false, "wild_enemies": false})
	eq(s.day_seconds, 360.0, "default 6 min/day")
	var s2: MatchState = Rules.new_match(5, &"lfg:class/judd", {"day_seconds": 120.0, "ai_enabled": false, "wild_enemies": false})
	eq(s2.day_seconds, 120.0, "configurable")
	Rules.tick(s2, 120.0)
	eq(s2.clock["day"], 2, "120s = one day with 120s days")
	Rules.tick(s, 359.0)
	eq(s.clock["day"], 1, "still day 1 at 359s")
	Rules.tick(s, 2.0)
	eq(s.clock["day"], 2, "day 2 after 361s")

func test_full_week_state_machine_order() -> void:
	var s: MatchState = quiet()
	var changes: Array = []
	for e in tick_all(s, 60.0 * 8.2, 7.0):
		if String(e["type"]) == "phase_changed":
			changes.append(String(e["to"]))
	eq(changes, ["WARNING", "PURGE_ACTIVE", "RESOLUTION", "PEACE"], "phase sequence")
	eq(s.phase, &"PEACE", "back to peace")
	eq(s.clock["day"], 9, "day 9 after 8.2 days")

func test_phase_boundaries_exact_with_one_big_tick() -> void:
	var s: MatchState = quiet()
	var ev: Array = Rules.tick(s, 60.0 * 5.0 + 1.0)
	eq(s.phase, &"WARNING", "day 6 warning after one huge tick")
	var seq: Array = []
	for e in ev:
		if String(e["type"]) == "phase_changed":
			seq.append(String(e["to"]))
	eq(seq, ["WARNING"], "one big tick still reports phase change")
	Rules.tick(s, 60.0 * 1.5)
	eq(s.phase, &"PURGE_ACTIVE", "purge at day 7 tod .5")

func test_pvp_and_capture_disabled_outside_purge() -> void:
	var s: MatchState = quiet()
	var fid: int = 1
	var ai_leader: Dictionary = s.actors[int(s.factions[fid]["leader"])]
	var tgt_h: Dictionary = s.holdings[int(s.factions[fid]["home"])]
	var p: Dictionary = s.actors[1]
	p["hex"] = tgt_h["hex"] + HexGrid.DIRS[0]
	ai_leader["hex"] = tgt_h["hex"]
	for day in [1, 3, 6]:
		warp(s, day, 0.2)
		var before: String = snap(s)
		eq(cmd(s, "attack", {"target": ai_leader["id"]})["error"], "not_purge", "attack blocked day %d" % day)
		eq(cmd(s, "capture", {"holding": tgt_h["id"]})["error"], "not_purge", "capture blocked day %d" % day)
		eq(cmd(s, "steal", {"holding": tgt_h["id"], "item": "lfg:item/ration", "qty": 1})["error"], "not_purge", "steal blocked day %d" % day)
		eq(snap(s), before, "blocked commands mutate nothing day %d" % day)
	warp(s, 7, 0.6)
	eq(s.phase, &"PURGE_ACTIVE", "purge active")
	var r: Dictionary = cmd(s, "attack", {"target": ai_leader["id"]})
	check(r["ok"], "attack allowed in purge: %s" % r["error"])
	var r2: Dictionary = cmd(s, "capture", {"holding": tgt_h["id"]})
	check(r2["ok"], "capture attempt allowed in purge: %s" % r2["error"])

func test_market_closed_in_purge() -> void:
	var s: MatchState = quiet()
	var merchant: Dictionary = {}
	for h in s.holdings.values():
		if h["merchant"] and int(h["owner"]) == -1:
			merchant = h
			break
	s.actors[1]["hex"] = merchant["hex"]
	warp(s, 2, 0.1)
	check(cmd(s, "trade", {"holding": merchant["id"], "side": "buy", "item": "lfg:item/timber", "qty": 1})["ok"], "trade ok in peace")
	warp(s, 7, 0.7)
	eq(cmd(s, "trade", {"holding": merchant["id"], "side": "buy", "item": "lfg:item/timber", "qty": 1})["error"], "market_closed", "closed in purge")

func test_resolution_settles_exactly_once() -> void:
	var s: MatchState = quiet()
	var resolved: int = 0
	var all: Array = tick_all(s, 60.0 * 15.5, 0.7)
	for e in all:
		if String(e["type"]) == "purge_resolved":
			resolved += 1
	eq(resolved, 2, "two purges completed in 15.5 days -> two settlements")
	eq(s.settled_week, 1, "settled_week index")
	var again: Array = []
	Sim.settle(s, again)
	eq(again.size(), 0, "settle is idempotent for the same week")
	# tiny steps straddling the resolution window do not double settle
	var s2: MatchState = quiet()
	warp(s2, 7, 0.98)
	var n: int = 0
	for e in tick_all(s2, 60.0 * 0.6, 0.05):
		if String(e["type"]) == "purge_resolved":
			n += 1
	eq(n, 1, "settles once with tiny steps")

func test_no_time_passes_with_zero_or_negative_dt() -> void:
	var s: MatchState = mk()
	warp(s, 7, 0.6)
	var before: String = snap(s)
	eq(Rules.tick(s, 0.0).size(), 0, "dt 0 no events")
	eq(Rules.tick(s, -5.0).size(), 0, "negative dt no events")
	eq(Rules.tick(s, NAN).size(), 0, "nan dt no events")
	eq(snap(s), before, "state unchanged by non-positive dt")

func test_tick_is_deterministic() -> void:
	var a: MatchState = mk("lfg:class/judd", 21)
	var b: MatchState = mk("lfg:class/judd", 21)
	var ea: Array = tick_all(a, 60.0 * 9.0, 3.0)
	var eb: Array = tick_all(b, 60.0 * 9.0, 3.0)
	eq(snap(a), snap(b), "identical state after identical ticks")
	eq(ea.size(), eb.size(), "identical event count")
