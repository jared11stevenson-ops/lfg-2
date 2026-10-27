extends RulesTestBase
## Resource tiers (T1 common, T2 regional, T3 rare from POIs), crafting stations and the pass-3 buildings: every one has a real effect.

const NEW_BUILDABLE: Array[String] = ["brew_vat", "smokehouse", "cistern", "fortified_gate", "glasshouse", "lantern_mast", "trophy_hall", "infirmary"]
const STATIONS: Array[String] = ["workbench", "kiln", "loom", "spore_forge"]

func _bid(n: String) -> String:
	return "lfg:building/" + n

func _give_build(s: MatchState, bid: String) -> void:
	for k in Content.building(bid)["cost"].keys():
		give(s, 1, {String(k): int(Content.building(bid)["cost"][k]) + 2})

func _put(s: MatchState, bid: String) -> void:
	(home(s)["buildings"] as Array).append(bid)

func test_tier_items_exist_and_pois_feed_them() -> void:
	var t2: Array = []
	var t3: Array = []
	for it in Content.items().values():
		match int(it.get("tier", 0)):
			2: t2.append(String(it["id"]))
			3: t3.append(String(it["id"]))
	check(t2.size() >= 4 and t3.size() >= 3, "T2 %d, T3 %d" % [t2.size(), t3.size()])
	var from_pois: Dictionary = {}
	for t in Content.poi_types().values():
		for k in (t["loot"] as Dictionary).keys():
			from_pois[String(k)] = true
	for k in ["lfg:item/bog_iron", "lfg:item/reed_fibre", "lfg:item/rime_salt", "lfg:item/amber_resin", "lfg:item/ruin_glass", "lfg:item/spore_silk", "lfg:item/kiln_clay"]:
		check(from_pois.has(k), "%s comes from a POI" % k)

func test_at_least_eight_new_buildings_need_rare_resources_and_have_models_and_effects() -> void:
	var rare: Array = ["bog_iron", "reed_fibre", "rime_salt", "amber_resin", "ruin_glass", "spore_silk", "kiln_clay", "iron_fittings", "rope", "fired_brick", "glass_pane", "silk_cloth"]
	for n in NEW_BUILDABLE:
		var b: Dictionary = Content.building(_bid(n))
		check(not b.is_empty(), "%s exists" % n)
		var has_rare: bool = false
		for k in (b["cost"] as Dictionary).keys():
			if rare.has(String(k).get_slice("/", 1)):
				has_rare = true
		check(has_rare, "%s costs rare resources" % n)
	for n in STATIONS:
		check(bool(Content.building(_bid(n)).get("station", false)), "%s is a station" % n)
	check(NEW_BUILDABLE.size() >= 8, "eight new buildable buildings")

func test_stations_gate_recipes_and_each_station_unlocks_its_chain() -> void:
	var s: MatchState = quiet()
	give(s, 1, {"lfg:item/reed_fibre": 6, "lfg:item/bog_iron": 4, "lfg:item/timber": 20, "lfg:item/stone": 20, "lfg:item/kiln_clay": 2, "lfg:item/ruin_glass": 2, "lfg:item/rime_salt": 1})
	eq(cmd(s, "craft", {"recipe": "lfg:recipe/rope"})["error"], "needs_station", "no workbench")
	check(cmd(s, "build", {"holding": 1, "building": _bid("workbench")})["ok"], "workbench")
	check(cmd(s, "craft", {"recipe": "lfg:recipe/rope"})["ok"], "rope")
	check(cmd(s, "craft", {"recipe": "lfg:recipe/iron_fittings"})["ok"], "iron fittings")
	eq(cmd(s, "craft", {"recipe": "lfg:recipe/fired_brick"})["error"], "needs_station", "no kiln yet")
	var r: Dictionary = cmd(s, "build", {"holding": 1, "building": _bid("kiln")})
	check(r["ok"], "kiln (iron fittings + stone): %s" % r["error"])
	check(cmd(s, "craft", {"recipe": "lfg:recipe/fired_brick"})["ok"], "fired brick")
	check(cmd(s, "craft", {"recipe": "lfg:recipe/glass_pane"})["ok"], "glass pane")
	eq(cmd(s, "craft", {"recipe": "lfg:recipe/silk_cloth"})["error"], "needs_station", "no loom")
	# a station at one holding does not serve a far-away craft
	s.actors[1]["hex"] = s.holdings[1]["hex"] + HexGrid.DIRS[0] * 8
	check(not cmd(s, "craft", {"recipe": "lfg:recipe/rope"})["ok"], "too far from the holding")

func test_brew_vat_turns_mushrooms_into_tonics_each_dawn() -> void:
	var s: MatchState = quiet()
	_put(s, _bid("brew_vat"))
	home(s)["garrison"] = 2
	var t0: int = Inv.count(home(s)["store"], "lfg:item/tonic")
	Inv.add_all(home(s)["store"], {"lfg:item/mushroom": 4, "lfg:item/glowfruit": 2})
	var ev: Array = []
	Economy.dawn_buildings(s, ev)
	eq(Inv.count(home(s)["store"], "lfg:item/tonic"), t0 + 2, "two tonics")
	eq(Inv.count(home(s)["store"], "lfg:item/mushroom"), 2, "inputs consumed")
	Economy.dawn_buildings(s, ev)
	Economy.dawn_buildings(s, ev)
	eq(Inv.count(home(s)["store"], "lfg:item/tonic"), t0 + 4, "stops when the inputs run out")

func test_smokehouse_cures_sporebeans_into_rations_and_cuts_spoilage() -> void:
	var s: MatchState = quiet()
	_put(s, _bid("smokehouse"))
	home(s)["garrison"] = 2
	Inv.add_all(home(s)["store"], {"lfg:item/sporebean": 8})
	var r0: int = Inv.count(home(s)["store"], "lfg:item/ration")
	Economy.dawn_buildings(s, [])
	eq(Inv.count(home(s)["store"], "lfg:item/ration"), r0 + 3, "four sporebeans -> three rations")
	var a: MatchState = quiet()
	var b: MatchState = quiet()
	for st in [a, b]:
		st.set_time(22, 0.0)
		Inv.add_all(home(st)["store"], {"lfg:item/ration": 60})
	_put(b, _bid("smokehouse"))
	Standing.dawn_upkeep(a, [])
	Standing.dawn_upkeep(b, [])
	check(Inv.count(home(b)["store"], "lfg:item/ration") > Inv.count(home(a)["store"], "lfg:item/ration"), "the smokehouse halves spoilage (%d vs %d)" % [Inv.count(home(b)["store"], "lfg:item/ration"), Inv.count(home(a)["store"], "lfg:item/ration")])

func test_cistern_waters_plots_of_neighbouring_holdings_within_range() -> void:
	var s: MatchState = quiet()
	# the cistern is an upgrade of the well
	_put(s, _bid("well"))
	give(s, 1, {"lfg:item/fired_brick": 6, "lfg:item/rope": 4, "lfg:item/iron_fittings": 4})
	var r: Dictionary = cmd(s, "build", {"holding": 1, "building": _bid("cistern")})
	check(r["ok"], "cistern upgrades the well: %s" % r["error"])
	check((home(s)["buildings"] as Array).has(_bid("cistern")) and not (home(s)["buildings"] as Array).has(_bid("well")), "replaced in place")
	home(s)["garrison"] = 2
	var other: Dictionary = s.holdings[2]
	other["owner"] = 0
	other["hex"] = home(s)["hex"] + HexGrid.DIRS[0] * 3
	var far: Dictionary = s.holdings[3]
	far["owner"] = 0
	far["hex"] = home(s)["hex"] + HexGrid.DIRS[3] * 6
	s.plots["a"] = {"crop": "lfg:crop/glowfruit", "age": 0, "watered": false, "dry_days": 0, "holding": 2}
	s.plots["b"] = {"crop": "lfg:crop/glowfruit", "age": 0, "watered": false, "dry_days": 0, "holding": 3}
	s.plots["c"] = {"crop": "lfg:crop/glowfruit", "age": 0, "watered": false, "dry_days": 0, "holding": 1}
	Economy.dawn_buildings(s, [])
	check(bool(s.plots["a"]["watered"]), "plot of a holding 3 hexes away is watered")
	check(bool(s.plots["c"]["watered"]), "own plot is watered")
	check(not bool(s.plots["b"]["watered"]), "6 hexes away is out of range")

func test_fortified_gate_adds_defense_and_garrison_room() -> void:
	Standing.cfg()["hold"]["last_stand"] = 1.0      # a lone holding gets a last-stand bonus (test_hold_hunt); measure the gate on its own
	var s: MatchState = quiet()
	var h: Dictionary = home(s)
	var d0: float = Conquest.defender_power(s, h)
	var cap0: int = Standing.garrison_cap(s, h)
	_put(s, _bid("fortified_gate"))
	eq(Conquest.defender_power(s, h), d0 + 10.0, "defence +10")
	eq(Standing.garrison_cap(s, h), cap0 + 2, "garrison cap +2")

func test_glasshouse_upgrades_the_greenhouse_yield() -> void:
	var s: MatchState = quiet()
	Standing.set_rank(s, 0, 3)
	_put(s, _bid("greenhouse"))
	var y1: int = Standing.yield_bonus(s, home(s))
	give(s, 1, {"lfg:item/glass_pane": 6, "lfg:item/iron_fittings": 4, "lfg:item/timber": 6})
	var r: Dictionary = cmd(s, "build", {"holding": 1, "building": _bid("glasshouse")})
	check(r["ok"], "glasshouse: %s" % r["error"])
	eq(Standing.yield_bonus(s, home(s)), y1 + 1, "+1 over the greenhouse")

func test_lantern_mast_extends_vision_and_warning_range() -> void:
	var s: MatchState = quiet()
	var h: Dictionary = home(s)
	var w0: int = AIFactions.warn_radius(h)
	var v0: int = AIFactions.vision_of(s, h)
	_put(s, _bid("lantern_mast"))
	eq(AIFactions.warn_radius(h), 8, "warns 8 hexes out (was %d)" % w0)
	check(AIFactions.vision_of(s, h) >= v0, "vision not smaller (%d -> %d)" % [v0, AIFactions.vision_of(s, h)])

func test_trophy_hall_adds_standing() -> void:
	var s: MatchState = quiet()
	var sc0: float = Standing.holdings_score(s, 0)
	_put(s, _bid("trophy_hall"))
	eq(Standing.holdings_score(s, 0), sc0 + 3.0, "+3 standing")

func test_infirmary_heals_the_leader_at_dawn_only_nearby() -> void:
	var s: MatchState = quiet()
	_put(s, _bid("infirmary"))
	var l: Dictionary = s.actors[1]
	l["hp"] = 10
	var ev: Array = []
	Economy.dawn_buildings(s, ev)
	check(int(l["hp"]) > 10, "healed (%d/%d)" % [l["hp"], l["max_hp"]])
	check(count_type(ev, "infirmary_healed") == 1, "event")
	l["hp"] = 10
	l["hex"] = home(s)["hex"] + HexGrid.DIRS[0] * 6
	Economy.dawn_buildings(s, [])
	eq(int(l["hp"]), 10, "no healing when away")

func test_anvil_hall_needs_the_forge_questline_and_a_garrison() -> void:
	var s: MatchState = quiet("lfg:class/forge")
	_give_build(s, _bid("anvil_hall"))
	eq(cmd(s, "build", {"holding": 1, "building": _bid("anvil_hall")})["error"], "locked_building", "locked")
	Quests.grant(s, s.actors[1], {"unlock": "lfg:unlock/anvil_hall"})
	var r: Dictionary = cmd(s, "build", {"holding": 1, "building": _bid("anvil_hall")})
	check(r["ok"], "anvil hall: %s" % r["error"])
	home(s)["garrison"] = 3
	var g0: int = Inv.count(home(s)["store"], "lfg:item/gadget")
	Economy.dawn_buildings(s, [])
	eq(Inv.count(home(s)["store"], "lfg:item/gadget"), g0 + 2, "two gadgets a day")

func test_pass_two_rank_buildings_keep_working_without_the_pending_flag() -> void:
	for n in ["shrine", "greenhouse", "forge"]:
		check(not bool(Content.building(_bid(n)).get("model_pending", false)), "%s has no model_pending" % n)
	var s: MatchState = quiet()
	Standing.set_rank(s, 0, 3)
	give(s, 1, {"lfg:item/timber": 20, "lfg:item/stone": 20, "lfg:item/coin": 40})
	check(cmd(s, "build", {"holding": 1, "building": _bid("shrine")})["ok"], "shrine")
	check(cmd(s, "build", {"holding": 1, "building": _bid("forge")})["ok"], "forge")

func test_every_building_cost_is_obtainable_by_a_solo_player() -> void:
	# fixpoint over content: start kit + enemy loot + POI loot + crops + stations (no merchants, no players)
	var have: Dictionary = {}
	for k in ["lfg:item/timber", "lfg:item/stone", "lfg:item/ration", "lfg:item/coin"]:
		have[k] = true
	for t in Content.poi_types().values():
		for k in (t["loot"] as Dictionary).keys():
			have[String(k)] = true
	var built: Dictionary = {}
	var changed: bool = true
	while changed:
		changed = false
		for b in Content.buildings().values():
			if built.has(String(b["id"])) or int(b.get("rank", 0)) > 3:
				continue
			if b.has("upgrade_of") and not built.has(String(b["upgrade_of"])):
				continue
			var ok: bool = true
			for k in (b["cost"] as Dictionary).keys():
				if not have.has(String(k)):
					ok = false
			if ok:
				built[String(b["id"])] = true
				changed = true
		for r in Content.recipes().values():
			if String(r.get("requires_tag", "")) != "" or (String(r.get("station", "")) != "" and not built.has(String(r["station"]))):
				continue
			var ok2: bool = true
			for k in (r["inputs"] as Dictionary).keys():
				if not have.has(String(k)):
					ok2 = false
			if ok2:
				for k in (r["outputs"] as Dictionary).keys():
					if not have.has(String(k)):
						have[String(k)] = true
						changed = true
	for b in Content.buildings().values():
		if int(b.get("rank", 0)) <= 3:
			check(built.has(String(b["id"])), "%s can be built from POI resources + common goods" % b["id"])
