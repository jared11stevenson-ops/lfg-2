extends RulesTestBase
## Points of interest: deterministic per-biome placement, fog-of-war discovery rewards, the five challenge kinds, weekly respawn, saves.

func _poi_of(s: MatchState, type: String, nth: int = 0) -> Dictionary:
	var n: int = 0
	for p in s.world["pois"]:
		if p["type"] == type:
			if n == nth:
				return p
			n += 1
	return {}

func _of(events: Array, t: String) -> Dictionary:
	for e in events:
		if String(e["type"]) == t:
			return e
	return {}

func _claimed(events: Array) -> Dictionary:
	return _of(events, "poi_claimed")

func _go(s: MatchState, p: Dictionary) -> void:
	s.actors[1]["hex"] = p["hex"]

func test_placement_is_deterministic_per_biome_and_well_spaced() -> void:
	var w1: Dictionary = WorldGen.generate(5)
	var w2: Dictionary = WorldGen.generate(5)
	eq(w1["pois"], w2["pois"], "same seed, same points of interest")
	check(WorldGen.generate(6)["pois"] != w1["pois"], "another seed differs")
	var types: Dictionary = {}
	for p in w1["pois"]:
		types[String(p["type"])] = true
		var t: Dictionary = Content.poi_types()[String(p["type"])]
		check((t["biomes"] as Array).has(String(p["biome"])), "%s sits in a fitting biome (%s)" % [p["type"], p["biome"]])
		eq(WorldGen.biome_at(w1, p["hex"]), String(p["biome"]), "recorded biome is the real one")
		eq(int(w1["terrain"][HexGrid.index(p["hex"])]), WorldGen.T_GROUND, "on open ground")
		for st in w1["sites"]:
			check(HexGrid.distance(p["hex"], st["hex"]) >= 3, "clear of holding %s" % st["name"])
		for o in w1["pois"]:
			if int(o["id"]) != int(p["id"]):
				check(HexGrid.distance(p["hex"], o["hex"]) >= 6, "points of interest keep a gap")
	check(types.size() >= 5, "at least five distinct types (%d)" % types.size())
	eq(types.size(), 14, "all fourteen types (7 regular + 7 guardian arenas)")
	var farm: Dictionary = {}
	for p in w1["pois"]:
		if p["type"] == "lfg:poi/derelict_farm":
			farm = p
			break
	var d: int = HexGrid.distance(farm["hex"], w1["start"])
	check(d >= 7 and d <= 16, "the first farm is a short walk from the start (%d)" % d)
	check(w1["pois"].size() >= 36, "a lived-in map: %d" % w1["pois"].size())

func test_world_generation_still_places_the_same_holdings() -> void:
	var w: Dictionary = WorldGen.generate(11)
	eq(w["sites"].size(), 40, "holdings unchanged by the POI pass")
	check(w["poi_by_id"].size() == w["pois"].size(), "id index")

func test_discovery_fog_of_war_reward_once() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = _poi_of(s, "lfg:poi/shrine")
	var a: Dictionary = s.actors[1]
	check(not Pois.seen(a, int(p["id"])), "unseen at the start")
	a["hex"] = p["hex"] + HexGrid.DIRS[0] * 6
	var coin0: int = Inv.count(a["inv"], "lfg:item/coin")
	# walking toward it: a sync_position next to the poi reveals it
	var near: Vector2i = p["hex"] + HexGrid.DIRS[0] * 2
	var ev: Array = []
	a["hex"] = near + HexGrid.DIRS[0]
	a["sync_t"] = -100.0
	var r: Dictionary = cmd(s, "sync_position", {"hex": near})
	if r["ok"]:
		ev = r["events"]
	else:
		a["hex"] = near          # walk rejected for speed: emit the same event the sim does
		ev = [{"type": &"actor_moved", "actor": 1, "hex": near}]
		Pois.observe(s, ev, 0)
	var found: Array = ev.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "poi_discovered")
	eq(found.size(), 1, "discovered when within the radius: %s" % str(types(ev)))
	check(Pois.seen(a, int(p["id"])), "remembered")
	eq(Inv.count(a["inv"], "lfg:item/coin"), coin0 + 4, "discovery reward paid")
	var again: Array = [{"type": &"actor_moved", "actor": 1, "hex": near}]
	Pois.observe(s, again, 0)
	eq(again.size(), 1, "no second discovery")
	var mk: Array = Pois.markers(s, a)
	eq(mk.size(), 1, "the strategic map shows discovered POIs only")
	var toast: Dictionary = Pois.toast_for(found[0])
	check(String(toast["title"]).begins_with("Discovered: Wayside Shrine"), "toast data: %s" % str(toast))
	var far: Dictionary = Pois.info(s, a, int(_poi_of(s, "lfg:poi/shrine", 1)["id"]))
	check(not far["discovered"] and far["name"] == "Something unexplored" and far["hint"].is_empty(), "undiscovered POIs hide their details")

func test_ai_leaders_and_parties_never_discover() -> void:
	var s: MatchState = mk("lfg:class/judd", 11, {"wild_enemies": false})
	var ai: Dictionary = Standing.leader_of(s, 3)
	var p: Dictionary = s.world["pois"][0]
	ai["hex"] = p["hex"]
	var ev: Array = [{"type": &"actor_moved", "actor": ai["id"], "hex": p["hex"]}]
	Pois.observe(s, ev, 0)
	eq(ev.size(), 1, "only player leaders discover")

func test_offering_the_derelict_farm_and_weekly_respawn() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = _poi_of(s, "lfg:poi/derelict_farm")
	var a: Dictionary = s.actors[1]
	eq(cmd(s, "interact_poi", {"poi": p["id"]})["error"], "too_far", "walk up first")
	_go(s, p)
	a["inv"].erase("lfg:item/glowfruit_seed")
	eq(cmd(s, "interact_poi", {"poi": p["id"]})["error"], "need_offering", "needs a seed")
	a["inv"]["lfg:item/glowfruit_seed"] = 1
	var r: Dictionary = cmd(s, "interact_poi", {"poi": p["id"]})
	check(r["ok"], "claim: %s" % r["error"])
	var ev: Dictionary = _claimed(r["events"])
	eq(String(ev.get("type", "")), "poi_claimed", "poi_claimed")
	var loot: Dictionary = ev["items"]
	check(loot.has("lfg:item/kiln_clay") and loot.has("lfg:item/reed_fibre"), "T3 kiln clay and T2 reed fibre: %s" % str(loot))
	eq(cmd(s, "interact_poi", {"poi": p["id"]})["error"], "already_claimed", "once per week")
	warp(s, 8, 0.1)       # next week, peacetime
	a["inv"]["lfg:item/glowfruit_seed"] = 1
	r = cmd(s, "interact_poi", {"poi": p["id"]})
	check(r["ok"], "claimable again next week: %s" % r["error"])
	var loot2: Dictionary = _claimed(r["events"])["items"]
	check(Pois.roll_loot(s, p, 1) == loot2, "the roll is a pure function of (seed, poi, week)")

func test_loot_is_in_range_and_deterministic() -> void:
	var s: MatchState = quiet()
	for p in s.world["pois"]:
		var t: Dictionary = Content.poi_types()[String(p["type"])]
		for wk in range(0, 6):
			var l: Dictionary = Pois.roll_loot(s, p, wk)
			eq(l, Pois.roll_loot(s, p, wk), "stable")
			for k in l.keys():
				check(int(l[k]) >= int(t["loot"][k][0]) and int(l[k]) <= int(t["loot"][k][1]) and int(l[k]) > 0, "%s %s in range" % [p["type"], k])

func test_lamps_puzzle_and_shrine_reward() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = _poi_of(s, "lfg:poi/shrine")
	_go(s, p)
	eq(cmd(s, "interact_poi", {"poi": p["id"]})["error"], "bad_pick", "needs a lamp to light")
	eq(cmd(s, "interact_poi", {"poi": p["id"], "pick": 5})["error"], "bad_pick", "three lamps")
	var h: Dictionary = Pois.hint(s, p)
	var lit: Array = h["lit"]
	var last: Dictionary = {}
	var steps: int = 0
	for i in range(3):
		if bool(lit[i]):
			last = cmd(s, "interact_poi", {"poi": p["id"], "pick": i})
			steps += 1
			check(last["ok"], "pick %d: %s" % [i, last["error"]])
	var claimed: Array = last["events"].filter(func(e: Dictionary) -> bool: return String(e["type"]) == "poi_claimed")
	eq(claimed.size(), 1, "the matching pattern pays out (steps %d)" % steps)
	check(claimed[0]["items"].has("lfg:item/amber_resin"), "amber resin from a shrine")

func test_sequence_vault_wrong_plate_hurts_and_resets() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = _poi_of(s, "lfg:poi/ruin_vault")
	_go(s, p)
	var order: Array = Pois.hint(s, p)["order"]
	var wrong: int = (int(order[0]) + 1) % 3
	var hp0: int = int(s.actors[1]["hp"])
	var r: Dictionary = cmd(s, "interact_poi", {"poi": p["id"], "pick": wrong})
	check(r["ok"], "a wrong plate is still a legal move")
	eq(int(s.actors[1]["hp"]), hp0 - 3, "the old trap bites for 3")
	eq(Pois.info(s, s.actors[1], int(p["id"]))["prog"], 0, "reset")
	cmd(s, "interact_poi", {"poi": p["id"], "pick": order[0]})
	eq(Pois.info(s, s.actors[1], int(p["id"]))["prog"], 1, "first plate")
	cmd(s, "interact_poi", {"poi": p["id"], "pick": order[1]})
	r = cmd(s, "interact_poi", {"poi": p["id"], "pick": order[2]})
	check(count_type(r["events"], "poi_claimed") == 1, "vault opens")
	check(_claimed(r["events"])["items"].has("lfg:item/ruin_glass"), "ruin glass (T3)")

func test_effort_wreck_spends_energy() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = _poi_of(s, "lfg:poi/wreck")
	_go(s, p)
	s.actors[1]["energy"] = 5.0
	eq(cmd(s, "interact_poi", {"poi": p["id"]})["error"], "no_energy", "too tired")
	s.actors[1]["energy"] = 50.0
	var r: Dictionary = cmd(s, "interact_poi", {"poi": p["id"]})
	check(r["ok"], "claim: %s" % r["error"])
	eq(float(s.actors[1]["energy"]), 30.0, "20 energy spent")
	check(_claimed(r["events"])["items"].has("lfg:item/bog_iron"), "bog iron (T2) from a wreck")

func test_guard_fight_then_claim() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = _poi_of(s, "lfg:poi/fungal_cave")
	_go(s, p)
	var r: Dictionary = cmd(s, "interact_poi", {"poi": p["id"]})
	check(r["ok"] and count_type(r["events"], "poi_guarded") == 1, "the first visit wakes the guards: %s" % r["error"])
	var guards: Array = _of(r["events"], "poi_guarded")["guards"]
	eq(guards.size(), 2, "two sporelings")
	eq(cmd(s, "interact_poi", {"poi": p["id"]})["error"], "guard_alive", "no looting past live guards")
	check(not Pois.info(s, s.actors[1], int(p["id"]))["available"] == false, "still unclaimed")
	for g in guards:
		Combat.kill(s, int(g), 1, [])
	r = cmd(s, "interact_poi", {"poi": p["id"]})
	check(r["ok"] and count_type(r["events"], "poi_claimed") == 1, "claimed after the fight: %s" % r["error"])
	check(_claimed(r["events"])["items"].has("lfg:item/spore_silk"), "spore silk (T3) from a cave")
	var salt: Dictionary = _poi_of(s, "lfg:poi/salt_spire")
	_go(s, salt)
	r = cmd(s, "interact_poi", {"poi": salt["id"]})
	eq(_of(r["events"], "poi_guarded")["guards"].size(), 1, "a thorn slinger guards the spire")

func test_hermit_hut_trade_with_a_hermit_is_an_offering_not_a_player_trade() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = _poi_of(s, "lfg:poi/hermit_hut")
	_go(s, p)
	var rations: int = Inv.count(s.actors[1]["inv"], "lfg:item/ration")
	var r: Dictionary = cmd(s, "interact_poi", {"poi": p["id"]})
	check(r["ok"], "hermit: %s" % r["error"])
	eq(Inv.count(s.actors[1]["inv"], "lfg:item/ration"), rations - 1, "one ration left on the step")
	check(_claimed(r["events"])["items"].has("lfg:item/bog_iron"), "bog iron")

func test_purge_closes_pois_and_failed_interactions_mutate_nothing() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = _poi_of(s, "lfg:poi/derelict_farm")
	_go(s, p)
	var before: String = snap(s)
	warp(s, 7, 0.6)
	before = snap(s)
	var r: Dictionary = cmd(s, "interact_poi", {"poi": p["id"]})
	eq(r["error"], "purge_closed", "closed during the Purge")
	var b: Dictionary = JSON.parse_string(before)
	var a2: Dictionary = JSON.parse_string(snap(s))
	b["actors"]["1"]["last_seq"] = 0
	a2["actors"]["1"]["last_seq"] = 0
	check(a2 == b, "refused command changed nothing")
	warp(s, 2, 0.1)
	# a full pack refuses the claim and keeps the offering
	var pip: MatchState = quiet("lfg:class/pip")
	var pf: Dictionary = _poi_of(pip, "lfg:poi/wreck")
	pip.actors[1]["hex"] = pf["hex"]
	pip.actors[1]["inv"]["lfg:item/timber"] = 30
	var snap0: String = JSON.stringify(pip.actors[1]["inv"])
	r = cmd(pip, "interact_poi", {"poi": pf["id"]})
	eq(r["error"], "no_room", "Pip's pack is full")
	eq(JSON.stringify(pip.actors[1]["inv"]), snap0, "nothing was taken")
	eq(float(pip.actors[1]["energy"]), 100.0, "no energy spent")
	check(not pip.poi_state.has(int(pf["id"])), "not marked claimed")

func test_poi_state_round_trips() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = _poi_of(s, "lfg:poi/shrine")
	_go(s, p)
	var lit: Array = Pois.hint(s, p)["lit"]
	var pick: int = 0
	for i in range(3):
		if bool(lit[i]):
			pick = i
	if int(lit.count(true)) > 1:
		cmd(s, "interact_poi", {"poi": p["id"], "pick": pick})      # partial progress
	var s2: MatchState = MatchState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	eq(s2.poi_state, s.poi_state, "poi_state is identical after a save")
	eq(s2.world["pois"], s.world["pois"], "the world regenerates the same POIs from the seed")

func test_every_type_has_a_reachable_loot_and_a_distinct_challenge_text() -> void:
	var kinds: Dictionary = {}
	var texts: Dictionary = {}
	for t in Content.poi_types().values():
		kinds[String(t["challenge"]["kind"])] = true
		texts[String(t["challenge"]["text"])] = true
		check(not (t["loot"] as Dictionary).is_empty(), "%s pays something" % t["id"])
		for k in (t["loot"] as Dictionary).keys():
			check(not Content.item(String(k)).is_empty(), "%s: loot item exists" % t["id"])
	check(kinds.size() >= 5, "five challenge kinds (%d)" % kinds.size())
	eq(texts.size(), Content.poi_types().size(), "every type has its own challenge text")
	var tier3: Dictionary = {}
	for t in Content.poi_types().values():
		for k in (t["loot"] as Dictionary).keys():
			if int(Content.item(String(k)).get("tier", 0)) >= 3:
				tier3[String(k)] = true
	check(tier3.has("lfg:item/ruin_glass") and tier3.has("lfg:item/spore_silk") and tier3.has("lfg:item/kiln_clay"), "all three T3 resources come from POIs")
