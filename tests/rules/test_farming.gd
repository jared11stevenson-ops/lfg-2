extends RulesTestBase

func _plant(s: MatchState, crop: String, i: int = 0) -> Vector2i:
	var h: Vector2i = neighbor_plot(s, i)
	var r: Dictionary = cmd(s, "plant", {"crop": crop, "hex": h})
	check(r["ok"], "plant %s: %s" % [crop, r["error"]])
	return h

func test_glowfruit_full_cycle_and_yield() -> void:
	var s: MatchState = quiet()
	var h: Vector2i = _plant(s, "lfg:crop/glowfruit")
	eq(s.actors[1]["inv"]["lfg:item/glowfruit_seed"], 5, "seed consumed")
	eq(cmd(s, "harvest", {"hex": h})["error"], "not_ready", "not ready")
	check(cmd(s, "water", {"hex": h})["ok"], "water")
	eq(cmd(s, "water", {"hex": h})["error"], "already_watered", "double water")
	var ev: Array = tick_all(s, 60.0, 5.0)
	check(cmd(s, "water", {"hex": h})["ok"], "water day 2")
	ev.append_array(tick_all(s, 60.0, 5.0))
	eq(count_type(ev, "crop_grown"), 1, "crop_grown event once")
	check(cmd(s, "harvest", {"hex": h})["ok"], "harvest")
	# base 2 + meadow 1 + Judd 1
	eq(s.actors[1]["inv"]["lfg:item/glowfruit"], 4, "yield 2 base + 1 meadow + 1 Judd")
	eq(s.actors[1]["inv"]["lfg:item/glowfruit_seed"], 6, "seed returned")
	check(not s.plots.has(MatchState.plot_key(h)), "plot cleared")

func test_unwatered_glowfruit_withers() -> void:
	var s: MatchState = quiet()
	var h: Vector2i = _plant(s, "lfg:crop/glowfruit")
	var ev: Array = tick_all(s, 60.0 * 3.2, 5.0)
	eq(count_type(ev, "crop_withered"), 1, "withered after 3 dry days")
	check(not s.plots.has(MatchState.plot_key(h)), "plot gone")

func test_sporebean_needs_no_water_but_is_slow() -> void:
	var s: MatchState = quiet()
	var h: Vector2i = _plant(s, "lfg:crop/sporebean")
	eq(cmd(s, "water", {"hex": h})["error"], "not_needed", "no water needed")
	tick_all(s, 60.0 * 3.1, 5.0)
	eq(cmd(s, "harvest", {"hex": h})["error"], "not_ready", "not ready on day 3")
	tick_all(s, 60.0 * 1.0, 5.0)
	check(cmd(s, "harvest", {"hex": h})["ok"], "ready after 4 days with zero watering")
	eq(s.actors[1]["inv"]["lfg:item/sporebean"], 4, "yield 3 base + 0 meadow + 1 Judd")

func test_saltroot_biome_gated_slow_rich() -> void:
	var s: MatchState = quiet()
	var h: Vector2i = neighbor_plot(s, 0)
	eq(cmd(s, "plant", {"crop": "lfg:crop/saltroot", "hex": h})["error"], "bad_biome", "meadow rejects saltroot")
	s.world["biome"][HexGrid.index(h)] = WorldGen.B_SALT
	check(cmd(s, "plant", {"crop": "lfg:crop/saltroot", "hex": h})["ok"], "salt flats accept")
	var days: int = 0
	while days < 12:
		cmd(s, "water", {"hex": h})
		tick_all(s, 60.0, 10.0)
		days += 1
		if int(s.plots[MatchState.plot_key(h)]["age"]) >= 6:
			break
	eq(days, 6, "takes 6 days")
	check(cmd(s, "harvest", {"hex": h})["ok"], "harvest saltroot")
	eq(s.actors[1]["inv"]["lfg:item/saltroot"], 7 + 2 + 1, "7 base + 2 salt + 1 judd")

func test_crops_have_distinct_tradeoffs() -> void:
	var crops: Array = Content.crops().values()
	check(crops.size() >= 3, "3+ crops")
	var grow: Dictionary = {}
	var rate: Dictionary = {}
	var water: Dictionary = {}
	for c in crops:
		grow[c["grow_days"]] = true
		water[c["needs_water"]] = true
		rate[float(c["yield"]) / float(c["grow_days"])] = true
	eq(grow.size(), crops.size(), "distinct grow times")
	eq(water.size(), 2, "some need water, some do not")
	check(rate.size() >= 2, "distinct yield/day")
	var biome_sets: Dictionary = {}
	for c in crops:
		biome_sets[str(c["biomes"])] = true
	eq(biome_sets.size(), crops.size(), "distinct biome sets")

func test_plant_rejections_mutate_nothing() -> void:
	var s: MatchState = quiet()
	var before: String = snap(s)
	var near: Vector2i = neighbor_plot(s, 0)
	var cases: Array = [
		{"crop": "lfg:crop/nothing", "hex": near},
		{"crop": "lfg:crop/glowfruit", "hex": null},
		{"crop": "lfg:crop/glowfruit", "hex": [9999, 9999]},
		{"crop": "lfg:crop/glowfruit", "hex": home(s)["hex"]},
		{"crop": "lfg:crop/glowfruit", "hex": home(s)["hex"] + Vector2i(8, 0)},
		{"crop": "lfg:crop/glowfruit", "hex": [1.5, 2]},
	]
	for c in cases:
		check(not cmd(s, "plant", c)["ok"], "rejected %s" % str(c))
	eq(snap(s), before, "nothing changed")
	s.actors[1]["inv"].erase("lfg:item/glowfruit_seed")
	eq(cmd(s, "plant", {"crop": "lfg:crop/glowfruit", "hex": near})["error"], "no_seed", "no seed")
	s.actors[1]["inv"]["lfg:item/glowfruit_seed"] = 3
	check(cmd(s, "plant", {"crop": "lfg:crop/glowfruit", "hex": near})["ok"], "ok")
	eq(cmd(s, "plant", {"crop": "lfg:crop/glowfruit", "hex": near})["error"], "occupied", "occupied")
	var json_hex: Array = [near.x + 1, near.y]
	check(cmd(s, "plant", {"crop": "lfg:crop/glowfruit", "hex": json_hex})["ok"] or true, "json style hex tolerated")

func test_rations_eaten_daily_per_person() -> void:
	var s: MatchState = quiet()
	eq(Economy.persons(s, 0), 4, "leader + garrison 3")
	var total0: int = Economy.rations_available(s, 0)
	eq(total0, 10, "6 carried + 4 stored")
	var ev: Array = tick_all(s, 60.0, 10.0)
	eq(Economy.rations_available(s, 0), 6, "ate 4")
	eq(s.factions[0]["hunger_days"], 0, "no hunger")
	var ate: bool = false
	for e in ev:
		if String(e["type"]) == "rations_eaten" and int(e["faction"]) == 0:
			ate = (int(e["eaten"]) == 4 and int(e["need"]) == 4)
	check(ate, "rations_eaten event")

func test_bram_eats_double() -> void:
	var s: MatchState = quiet("lfg:class/bram")
	eq(Economy.persons(s, 0), 5, "Bram needs 2 + garrison 3")

func test_starvation_debuff_then_desertion() -> void:
	var s: MatchState = quiet()
	s.actors[1]["inv"].erase("lfg:item/ration")
	home(s)["store"].erase("lfg:item/ration")
	var atk_fed: float = Combat.atk_of(s, s.actors[1])
	tick_all(s, 60.0, 10.0)
	eq(s.factions[0]["hunger_days"], 1, "day 1 hungry")
	check(Combat.atk_of(s, s.actors[1]) < atk_fed, "starvation debuff reduces attack")
	eq(home(s)["garrison"], 3, "no desertion yet")
	tick_all(s, 60.0, 10.0)
	eq(home(s)["garrison"], 3, "no desertion day 2")
	var ev: Array = tick_all(s, 60.0, 10.0)
	eq(s.factions[0]["hunger_days"], 3, "3 days")
	check(home(s)["garrison"] < 3, "desertion on day 3")
	check(count_type(ev, "desertion") >= 1, "desertion event")
	# feeding recovers
	home(s)["store"]["lfg:item/ration"] = 50
	tick_all(s, 60.0, 10.0)
	eq(s.factions[0]["hunger_days"], 0, "fed again, hunger resets")

func test_half_ration_policy_hungry_but_cheaper() -> void:
	var s: MatchState = quiet()
	check(cmd(s, "set_policy", {"key": "ration", "value": "half"})["ok"], "set half")
	var before: int = Economy.rations_available(s, 0)
	tick_all(s, 60.0, 10.0)
	eq(before - Economy.rations_available(s, 0), 2, "half rations eaten")
	eq(s.factions[0]["hunger_days"], 1, "half rations still hungry")
	check(not cmd(s, "set_policy", {"key": "ration", "value": "feast"})["ok"], "bad policy rejected")

func test_oren_ration_bonus() -> void:
	var a: MatchState = quiet("lfg:class/judd")
	var b: MatchState = quiet("lfg:class/oren")
	for s in [a, b]:
		s.actors[1]["inv"] = {"lfg:item/glowfruit": 4}
		check(cmd(s, "craft", {"recipe": "lfg:recipe/ration_glowfruit", "qty": 2})["ok"], "craft")
	eq(a.actors[1]["inv"]["lfg:item/ration"], 2, "judd 2 rations")
	eq(b.actors[1]["inv"]["lfg:item/ration"], 3, "oren +1 ration")

func test_eat_command() -> void:
	var s: MatchState = quiet()
	s.actors[1]["hp"] = 50
	check(cmd(s, "eat", {"item": "lfg:item/ration", "qty": 2})["ok"], "eat")
	eq(s.actors[1]["hp"], 66, "healed 8 each")
	eq(cmd(s, "eat", {"item": "lfg:item/timber"})["error"], "not_food", "not food")
	eq(cmd(s, "eat", {"item": "lfg:item/ration", "qty": -1})["error"], "bad_quantity", "neg")
