extends RulesTestBase

func _neutral_near(s: MatchState) -> Dictionary:
	var best: Dictionary = {}
	var bd: int = 9999
	for h in s.holdings.values():
		if int(h["owner"]) == -1:
			var d: int = HexGrid.distance(h["hex"], home(s)["hex"])
			if d < bd:
				bd = d
				best = h
	return best

func _purge(s: MatchState) -> void:
	warp(s, 7, 0.7)

func test_capture_success_conserves_items_and_moves_ownership() -> void:
	var s: MatchState = quiet()
	var t: Dictionary = _neutral_near(s)
	t["garrison"] = 0
	s.actors[1]["hex"] = t["hex"] + HexGrid.DIRS[2]
	_purge(s)
	var t0: Dictionary = Inv.world_totals(s)
	var r: Dictionary = cmd(s, "capture", {"holding": t["id"]})
	check(r["ok"], "capture ok: %s" % r["error"])
	eq(t["owner"], 0, "now owned by player")
	check(count_type(r["events"], "holding_captured") == 1, "event")
	eq(Inv.world_totals(s), t0, "items conserved across capture")
	check(Inv.count(s.actors[1]["inv"], "lfg:item/coin") > 20, "looted half the coin into inventory")
	eq(s.holdings_of(0).size(), 2, "player holds 2")
	eq(cmd(s, "capture", {"holding": t["id"]})["error"], "already_yours", "cannot capture own")

func test_capture_failure_conserves_and_costs_troops() -> void:
	var s: MatchState = quiet()
	var t: Dictionary = _neutral_near(s)
	t["garrison"] = 30
	s.actors[1]["hex"] = t["hex"] + HexGrid.DIRS[2]
	_purge(s)
	var t0: Dictionary = Inv.world_totals(s)
	var g0: int = home(s)["garrison"]
	var r: Dictionary = cmd(s, "capture", {"holding": t["id"], "commit": 2, "from": 1})
	check(r["ok"], "attempt resolved: %s" % r["error"])
	eq(t["owner"], -1, "still neutral")
	check(count_type(r["events"], "capture_failed") == 1, "failed event")
	check(home(s)["garrison"] < g0, "troops lost")
	eq(Inv.world_totals(s), t0, "items conserved on failure")

func test_capture_validation() -> void:
	var s: MatchState = quiet()
	var t: Dictionary = _neutral_near(s)
	_purge(s)
	var before: String = snap(s)
	eq(cmd(s, "capture", {"holding": t["id"]})["error"], "too_far", "must be adjacent")
	s.actors[1]["hex"] = t["hex"]
	before = snap(s)
	for bad in [{"holding": t["id"], "commit": -1}, {"holding": t["id"], "commit": 1.5}, {"holding": t["id"], "commit": 99}, {"holding": t["id"], "commit": 50},
			{"holding": t["id"], "commit": 1, "from": 9999}, {"holding": t["id"], "commit": 100000}, {"holding": 9999}]:
		check(not cmd(s, "capture", bad)["ok"], "rejected %s" % str(bad))
	eq(snap(s), before, "all rejections mutate nothing")
	home(s)["garrison"] = 1
	before = snap(s)
	check(not cmd(s, "capture", {"holding": t["id"], "commit": 5, "from": 1})["ok"], "not enough troops")
	eq(snap(s), before, "troop shortfall mutates nothing")

func test_captured_fields_follow_holding() -> void:
	var s: MatchState = quiet()
	var t: Dictionary = _neutral_near(s)
	t["garrison"] = 0
	s.actors[1]["hex"] = t["hex"] + HexGrid.DIRS[2]
	_purge(s)
	cmd(s, "capture", {"holding": t["id"]})
	warp(s, 2, 0.1)
	s.actors[1]["hex"] = t["hex"]
	var h: Vector2i = t["hex"] + HexGrid.DIRS[3]
	if WorldGen.passable(s.world, h):
		s.world["terrain"][HexGrid.index(h)] = WorldGen.T_GROUND
		s.world["biome"][HexGrid.index(h)] = WorldGen.B_MEADOW
		var r: Dictionary = cmd(s, "plant", {"crop": "lfg:crop/glowfruit", "hex": h})
		check(r["ok"], "can farm around captured holding: %s" % r["error"])

func test_steal_conservation_and_both_outcomes() -> void:
	var wins: int = 0
	var fails: int = 0
	for sd in range(1, 15):
		var s: MatchState = quiet("lfg:class/judd", 10 + sd)
		var t: Dictionary = _neutral_near(s)
		t["garrison"] = 0
		s.actors[1]["hex"] = t["hex"]
		s.rng_state = sd * 7919
		_purge(s)
		var t0: Dictionary = Inv.world_totals(s)
		var store0: int = Inv.count(t["store"], "lfg:item/coin")
		var r: Dictionary = cmd(s, "steal", {"holding": t["id"], "item": "lfg:item/coin", "qty": 5})
		check(r["ok"], "steal resolved: %s" % r["error"])
		eq(Inv.world_totals(s), t0, "steal conserves (seed %d)" % sd)
		if count_type(r["events"], "item_stolen") == 1:
			wins += 1
			eq(Inv.count(t["store"], "lfg:item/coin"), store0 - 5, "taken from store")
		else:
			fails += 1
			eq(Inv.count(t["store"], "lfg:item/coin"), store0, "failed steal takes nothing")
			check(s.actors[1]["hp"] < s.actors[1]["max_hp"], "caught thief hurt")
	check(wins > 0 and fails > 0, "risk roll yields both outcomes (%d/%d)" % [wins, fails])

func test_steal_validation() -> void:
	var s: MatchState = quiet()
	var t: Dictionary = _neutral_near(s)
	s.actors[1]["hex"] = t["hex"]
	_purge(s)
	var before: String = snap(s)
	var cases: Array = [
		{"holding": t["id"], "item": "lfg:item/coin", "qty": 6}, {"holding": t["id"], "item": "lfg:item/coin", "qty": 0},
		{"holding": t["id"], "item": "lfg:item/coin", "qty": -2}, {"holding": t["id"], "item": "lfg:item/coin", "qty": 2.5},
		{"holding": t["id"], "item": "lfg:item/spore_sac", "qty": 1}, {"holding": t["id"], "item": "bogus", "qty": 1},
		{"holding": 1, "item": "lfg:item/ration", "qty": 1}, {"holding": 9999, "item": "lfg:item/ration", "qty": 1}]
	for c in cases:
		check(not cmd(s, "steal", c)["ok"], "rejected %s" % str(c))
	s.actors[1]["inv"]["lfg:item/coin"] = 9998
	before = snap(s)
	eq(cmd(s, "steal", {"holding": t["id"], "item": "lfg:item/coin", "qty": 5})["error"], "no_room", "no room rejected")
	eq(snap(s), before, "no mutation on no_room")

func test_player_loses_holding_to_ai_capture_conserves() -> void:
	var s: MatchState = quiet()
	var fid: int = 1
	home(s)["garrison"] = 0
	var ah: Dictionary = s.holdings[int(s.factions[fid]["home"])]
	# move the AI's home next to the player's by editing hex (test setup)
	ah["hex"] = home(s)["hex"] + Vector2i(3, 0)
	ah["garrison"] = 12
	_purge(s)
	s.actors[1]["hex"] = home(s)["hex"] + Vector2i(0, 9)  # leader away
	var t0: Dictionary = Inv.world_totals(s)
	var ev: Array = []
	var ok: bool = Conquest.resolve_capture(s, fid, -1, 1, ah["id"], 8, ev)
	eq(Inv.world_totals(s), t0, "AI capture conserves items")
	check(ok, "overwhelming AI force takes undefended homestead")
	eq(home(s)["owner"], fid, "owner changed")
	check(ev[0]["ai"], "event identifies AI")

func test_ai_purge_round_bounded_conserving_and_identified() -> void:
	var s: MatchState = mk("lfg:class/judd", 8, {"wild_enemies": false})
	warp(s, 7, 0.6)
	var t0: Dictionary = Inv.world_totals(s)
	var total_events: Array = []
	for i in range(5):
		s.clock["elapsed"] = float(s.clock["elapsed"]) + 100.0
		var acted: int = AIFactions.purge_round(s, total_events)
		check(acted <= 12, "at most one action per AI faction per round (%d)" % acted)
	eq(Inv.world_totals(s), t0, "AI raids and thefts conserve items")
	check(total_events.size() > 0, "AI did something in the purge")
	for e in total_events:
		check(e.get("ai", false), "AI event flagged ai: %s" % str(e["type"]))
		var fid: int = int(e["by"])
		check(s.factions[fid]["is_ai"], "attributed to an AI faction")

func test_ai_idle_outside_purge_and_when_not_ticking() -> void:
	var s: MatchState = mk("lfg:class/judd", 9, {"wild_enemies": false})
	var ev: Array = tick_all(s, 60.0 * 5.0, 5.0)
	for e in ev:
		check(not (String(e["type"]) in ["holding_captured", "capture_failed", "item_stolen", "steal_failed"]), "no raiding in peace: %s" % str(e["type"]))
	# frozen: no ticks, commands do not advance AI
	warp(s, 7, 0.7)
	var before: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	for i in range(30):
		Rules.apply(s, {"type": &"rest", "actor": 1, "seq": 1 + i, "args": {}})
	Rules.tick(s, 0.0)
	Rules.tick(s, -10.0)
	var after: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	for k in ["holdings", "factions", "ai_t", "clock"]:
		eq(after[k], before[k], "%s untouched without ticking" % k)
	var s2: MatchState = mk("lfg:class/judd", 9, {"wild_enemies": false})
	warp(s2, 7, 0.7)
	Combat.hurt(s2, 1, 9999, -1, [], "t")
	var snap_over: String = snap(s2)
	Rules.tick(s2, 500.0)
	eq(snap(s2), snap_over, "AI frozen after match over")

func test_ai_full_purge_with_ticks_acts_and_stays_bounded() -> void:
	var s: MatchState = mk("lfg:class/judd", 12, {"wild_enemies": false})
	home(s)["store"]["lfg:item/ration"] = 500
	s.actors[1]["hex"] = home(s)["hex"]
	var ev: Array = tick_all(s, 60.0 * 7.9, 5.0)
	var ai_actions: int = 0
	for e in ev:
		if String(e["type"]) in ["holding_captured", "capture_failed", "item_stolen", "steal_failed"]:
			ai_actions += 1
			check(e["ai"] or int(e["by"]) == 0, "attributed")
	check(ai_actions > 0, "AI raided/stole during the first purge (%d)" % ai_actions)
	check(ai_actions <= 12 * 5, "bounded activity (%d)" % ai_actions)

func test_ai_economy_rations_and_starvation() -> void:
	var s: MatchState = mk("lfg:class/judd", 13, {"wild_enemies": false})
	var ev: Array = tick_all(s, 60.0 * 2.0, 10.0)
	var fed: int = 0
	for e in ev:
		if String(e["type"]) == "rations_eaten" and e["ai"]:
			fed += 1
	check(fed >= 12, "AI factions eat rations daily (%d)" % fed)
	var farmed: int = ev.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "ai_farmed").size()
	check(farmed > 0, "AI factions farm")
	# starve one AI
	var h: Dictionary = s.holdings[int(s.factions[1]["home"])]
	h["store"] = {}
	h["garrison"] = 40
	s.factions[1]["hunger_days"] = 0
	var any_desert: bool = false
	for i in range(5):
		for e in tick_all(s, 60.0, 10.0):
			if String(e["type"]) == "desertion" and int(e["faction"]) == 1:
				any_desert = true
				check(e["ai"], "desertion flagged ai")
	check(any_desert, "starving AI faction loses garrison to desertion")
