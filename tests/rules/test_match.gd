extends RulesTestBase

func test_new_match_shape() -> void:
	var s: MatchState = mk()
	eq(s.schema_version, 1, "schema")
	eq(s.holdings.size(), 40, "40 holdings")
	var ai: int = 0
	for f in s.factions.values():
		if f["is_ai"]:
			ai += 1
	eq(ai, 12, "12 AI factions")
	eq(s.holdings_of(0).size(), 1, "player starts with one")
	eq(s.phase, &"PEACE", "peace")
	eq(s.clock["day"], 1, "day 1")
	eq(s.actors[1]["class_id"], "lfg:class/judd", "class")
	for a in s.actors.values():
		if a["kind"] == "ai_leader":
			check(a["is_ai"], "AI leaders flagged as AI")
	var wild: int = 0
	for a in s.actors.values():
		if a["kind"] == "enemy":
			wild += 1
	check(wild >= 10, "wild enemies present (%d)" % wild)

func test_serialisation_roundtrip_through_json() -> void:
	var s: MatchState = mk("lfg:class/mira", 31)
	tick_all(s, 60.0 * 2.5, 5.0)
	cmd(s, "plant", {"crop": "lfg:crop/glowfruit", "hex": neighbor_plot(s, 1)})
	var d: Dictionary = s.to_dict()
	var text: String = JSON.stringify(d)
	var s2: MatchState = MatchState.from_dict(JSON.parse_string(text))
	check(same(s, s2), "JSON round trip is identical")
	eq(s2.phase, s.phase, "phase")
	eq(s2.actors[1]["hex"], s.actors[1]["hex"], "Vector2i restored")
	check(s2.world.has("biome"), "world regenerated")
	var ea: Array = tick_all(s, 60.0 * 5.0, 5.0)
	var eb: Array = tick_all(s2, 60.0 * 5.0, 5.0)
	check(same(s, s2), "restored state continues identically")
	eq(ea.size(), eb.size(), "same events after restore")
	eq(s.to_dict()["schema_version"], 1, "schema_version in dict")

func test_leader_death_is_match_over() -> void:
	var s: MatchState = quiet()
	var ev: Array = []
	Combat.hurt(s, 1, 9999, -1, ev, "test")
	eq(s.over, true, "over")
	eq(s.result["reason"], "leader_died", "reason")
	var mo: Array = ev.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "match_over")
	eq(mo.size(), 1, "one match_over event")
	eq(String(mo[0]["reason"]), "leader_died", "event reason")
	var before: String = snap(s)
	eq(cmd(s, "rest")["error"], "match_over", "commands rejected after death")
	eq(Rules.tick(s, 100.0).size(), 0, "tick inert after match over")
	eq(snap(s), before, "state frozen")

func test_leader_dies_to_poison_and_enemies() -> void:
	var s: MatchState = quiet()
	s.actors[1]["hp"] = 2
	Combat.add_effect(s.actors[1], "poison", 100.0, {"dps": 3, "next": 1.0, "source": -1})
	var ev: Array = tick_all(s, 3.0, 1.0)
	check(s.over, "poison killed leader -> match over")
	check(count_type(ev, "match_over") == 1, "match_over once")

func _others_dead(s: MatchState, keep: int) -> void:
	for fid in s.factions.keys():
		if int(fid) != keep:
			s.factions[fid]["alive"] = false

func test_no_dominion_or_crowned_win_any_more() -> void:
	var s: MatchState = quiet()
	var ids: Array = s.holdings.keys()
	ids.sort()
	for i in range(30):
		s.holdings[ids[i]]["owner"] = 0
	var ev: Array = []
	Economy.check_victory(s, ev)
	eq(s.won, "", "30/40 holdings is not a win")
	home(s)["store"]["lfg:item/ration"] = 9000
	warp(s, 7 * 12 + 7, 0.97)
	var ev2: Array = tick_all(s, 60.0 * 0.2, 1.0)
	eq(s.won, "", "twelve weeks is not a win")
	eq(count_type(ev2, "victory"), 0, "no victory event")

func test_total_conquest_needs_every_rival_dead_and_every_holding() -> void:
	var s: MatchState = quiet()
	for h in s.holdings.values():
		h["owner"] = 0
	var ev: Array = []
	Economy.check_victory(s, ev)
	eq(s.won, "", "rivals still alive: no win even owning every holding")
	_others_dead(s, 0)
	s.holdings[7]["owner"] = -1
	Economy.check_victory(s, ev)
	eq(s.won, "", "one neutral holding left: no win")
	s.holdings[7]["owner"] = 0
	Economy.check_victory(s, ev)
	eq(s.won, "total_conquest", "all rivals gone and every holding owned")
	eq(count_type(ev, "victory"), 1, "one victory event")
	eq(ev[0]["kind"], "total_conquest", "kind")
	check(ev[0]["player"] and int(ev[0]["faction"]) == 0, "the player won")
	check(not s.over, "winning does not end the match (Endless)")
	Economy.check_victory(s, ev)
	eq(count_type(ev, "victory"), 1, "only once")

func test_a_rival_can_win_total_conquest_too() -> void:
	var s: MatchState = quiet()
	for h in s.holdings.values():
		h["owner"] = 4
	_others_dead(s, 4)
	var ev: Array = []
	Economy.check_victory(s, ev)
	eq(s.won, "total_conquest", "rival conquest")
	check(not ev[0]["player"] and int(ev[0]["faction"]) == 4, "flagged as not the player")

func test_killing_the_last_rival_leader_wins_when_the_map_is_owned() -> void:
	var s: MatchState = quiet()
	for h in s.holdings.values():
		h["owner"] = 0
	for fid in s.factions.keys():
		if int(fid) != 0 and int(fid) != 9:
			s.factions[fid]["alive"] = false
	var lid: int = int(s.factions[9]["leader"])
	var ev: Array = []
	Combat.hurt(s, lid, 99999, 1, ev, "test")
	check(not s.factions[9]["alive"], "leader death eliminates an AI faction")
	eq(s.won, "total_conquest", "last rival gone with the whole map owned -> victory")
	eq(count_type(ev, "faction_eliminated"), 1, "one elimination")

func test_leader_death_eliminates_any_faction_and_frees_its_holdings() -> void:
	var s: MatchState = quiet()
	var hs: Array = s.holdings_of(5)
	check(hs.size() >= 1, "faction 5 owns something")
	var ev: Array = []
	Combat.kill(s, int(s.factions[5]["leader"]), 1, ev)
	check(not s.factions[5]["alive"], "eliminated by leader death although holdings remained")
	eq(s.holdings_of(5).size(), 0, "holdings released")
	for h in hs:
		eq(s.holdings[h]["owner"], -1, "neutral")
	check(not s.over, "the player's match goes on")

func test_starved_out_loss() -> void:
	var s: MatchState = quiet()
	s.holdings[1]["owner"] = -1
	s.actors[1]["inv"].erase("lfg:item/ration")
	var ev: Array = tick_all(s, 60.0, 10.0)
	check(s.over, "starved out")
	eq(s.result["reason"], "starved_out", "reason")
	var s2: MatchState = quiet()
	s2.holdings[1]["owner"] = -1
	tick_all(s2, 60.0, 10.0)
	check(not s2.over, "no holdings but still carrying rations -> alive")

func test_failed_commands_mutate_nothing_property() -> void:
	var s: MatchState = mk()
	var before: String = snap(s)
	var bad: Array = [
		["plant", {"crop": 5, "hex": 5}], ["water", {"hex": [0, 0]}], ["harvest", {}], ["craft", {"recipe": "x"}], ["build", {"holding": 1}],
		["demolish", {"holding": 1, "building": "lfg:building/wall"}], ["trade", {}], ["eat", {"item": "lfg:item/coin"}], ["attack", {"target": 1}],
		["attack", {"target": 99999}], ["use_ability", {"ability": "nope"}], ["capture", {"holding": 1}], ["steal", {"holding": 2, "item": "x", "qty": 1}],
		["set_policy", {"key": "ration", "value": 5}], ["move_intent", {"to": [-4, -4]}], ["move_intent", {"to": null}]]
	for b in bad:
		var r: Dictionary = cmd(s, b[0], b[1])
		check(not r["ok"], "%s rejected" % b[0])
		check(r["events"].is_empty(), "no events on failure")
	eq(snap(s), before, "all failures left state byte-identical")

func test_move_intent_walks_over_time() -> void:
	var s: MatchState = quiet()
	var start: Vector2i = s.actors[1]["hex"]
	var goal: Vector2i = start + Vector2i(3, 0)
	var r: Dictionary = cmd(s, "move_intent", {"to": goal})
	check(r["ok"], "move accepted: %s" % r["error"])
	eq(s.actors[1]["hex"], start, "intent does not teleport")
	tick_all(s, 60.0, 0.25)
	eq(s.actors[1]["hex"], goal, "arrived")
	eq(cmd(s, "move_intent", {"to": goal})["error"], "already_there", "already there")
	# impassable
	var deep: Vector2i = Vector2i(-999, 0)
	for i in range(84 * 54):
		if int(s.world["terrain"][i]) == WorldGen.T_DEEP:
			deep = HexGrid.from_index(i)
			break
	eq(cmd(s, "move_intent", {"to": deep})["error"], "impassable", "deep water blocked")
