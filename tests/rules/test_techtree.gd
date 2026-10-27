extends RulesTestBase
## Pass 4 resource and crafting depth: T4 materials, three new stations, ten new buildables with real effects, and a solo path to every item.
## The walk (tests/rules/tech_walk.gd) starts from a class's starting kit and never trades.

const NEW_STATIONS: Array[String] = ["alembic", "rift_anvil", "seed_press"]
const NEW_BUILDABLES: Array[String] = ["kennel", "seed_bank", "compost_heap", "spore_bed", "ward_stones", "rest_hall", "guardian_hall", "bastion", "foraging_den", "apiary"]
const T4_MATS: Array[String] = ["mother_seed", "tide_pearl", "heart_cap", "vault_sigil", "rime_plume", "thunder_horn", "fen_gland"]
## Things that really are class perks, not part of everyone's tree: game meat needs a hunter, the healing draught needs Mira's questline (and an alchemist's hands).
const CLASS_ITEMS: Array[String] = ["lfg:item/game_meat", "lfg:item/healing_draught"]
const CLASS_BUILDINGS: Array[String] = ["lfg:building/sun_terrace", "lfg:building/anvil_hall"]      # quest-line signature buildings (Judd, Forge)

func _b(n: String) -> String:
	return "lfg:building/" + n

func _i(n: String) -> String:
	return "lfg:item/" + n

func _value(bundle: Dictionary) -> int:
	var t: int = 0
	for k in bundle.keys():
		t += Content.item_value(String(k)) * int(bundle[k])
	return t

# ------------------------------------------------------------------ the walk
func test_every_class_can_walk_the_whole_tree_with_zero_trades() -> void:
	for cid in Content.classes().keys():
		var w: Dictionary = TechWalk.walk(String(cid))
		for id in TechWalk.unreachable_items(w):
			check(CLASS_ITEMS.has(id), "%s: %s is unreachable and not a class perk" % [cid, id])
		var cd: Dictionary = Content.class_def(String(cid))
		if int(cd.get("mods", {}).get("hunt_meat", 0)) > 0:
			check((w["have"] as Dictionary).has(_i("game_meat")), "%s hunts" % cid)
		for bid in Content.buildings().keys():
			if not (w["built"] as Dictionary).has(bid):
				check(CLASS_BUILDINGS.has(String(bid)), "%s: %s cannot be built and is not a quest signature" % [cid, bid])
		for r in Content.recipes().values():
			if not (w["made"] as Dictionary).has(String(r["id"])):
				var tag: String = String(r.get("requires_tag", ""))
				var ru: String = String(r.get("requires_unlock", ""))
				var item_gap: bool = false
				for k in (r["inputs"] as Dictionary).keys():
					if not (w["have"] as Dictionary).has(String(k)):
						item_gap = true
				check(tag != "" or ru != "" or item_gap and CLASS_ITEMS.has((r["inputs"] as Dictionary).keys()[0]),
					"%s: recipe %s is gated by a class tag, a quest unlock or a class item only" % [cid, r["id"]])
		for c in Content.crops().values():
			check((w["grown"] as Dictionary).has(String(c["id"])), "%s can grow %s" % [cid, c["id"]])
		for t4 in T4_MATS:
			check((w["have"] as Dictionary).has(_i(t4)), "%s reaches the T4 material %s" % [cid, t4])

func test_union_of_classes_covers_every_building_recipe_and_unlock() -> void:
	var built: Dictionary = {}
	var made: Dictionary = {}
	var have: Dictionary = {}
	for cid in Content.classes().keys():
		var w: Dictionary = TechWalk.walk(String(cid))
		built.merge(w["built"])
		made.merge(w["made"])
		have.merge(w["have"])
	for bid in Content.buildings().keys():
		check(built.has(bid), "%s is buildable by some class" % bid)
	for rid in Content.recipes().keys():
		check(made.has(rid), "%s is craftable by some class" % rid)
	for id in Content.items().keys():
		check(have.has(id), "%s is obtainable by some class" % id)

func test_the_walk_never_consults_trade() -> void:
	var src: String = FileAccess.get_file_as_string("res://tests/rules/tech_walk.gd")
	for w in ["base_stock", "merchant", "Economy.trade", "&\"trade\"", "\"trade\""]:
		# the only mentions are in the comments that promise it; code lines must not touch trade
		for line in src.split("\n"):
			var t: String = line.strip_edges()
			if t.begins_with("##") or t.begins_with("#"):
				continue
			check(not t.contains(w) or t.contains("##"), "tech_walk code does not use %s: %s" % [w, t])
	# and no recipe or building names a merchant or a coin sink that only a trade could fill
	for b in Content.buildings().values():
		for k in (b["cost"] as Dictionary).keys():
			check(not Content.item(String(k)).is_empty(), "%s: real cost item %s" % [b["id"], k])

func test_t4_materials_come_only_from_guardians() -> void:
	var w: Dictionary = TechWalk.walk("lfg:class/judd")
	var arena_names: Array = []
	for t in Content.poi_types().values():
		if t.has("guardian"):
			arena_names.append(String(t["name"]))
	for m in T4_MATS:
		var srcs: Array = w["sources"][_i(m)]
		for s in srcs:
			var ok: bool = false
			for n in arena_names:
				if String(s).begins_with(String(n)):
					ok = true
			check(ok, "%s comes only from an arena (%s)" % [m, s])
		eq(int(Content.item(_i(m))["tier"]), 4, "%s is tier 4" % m)
	for e in Content.enemies().values():
		for k in (e.get("loot", {}) as Dictionary).keys():
			check(not T4_MATS.has(String(k).get_slice("/", 1)), "no wild beast drops a guardian material")
	for r in Content.recipes().values():
		for k in (r["outputs"] as Dictionary).keys():
			check(not T4_MATS.has(String(k).get_slice("/", 1)), "no recipe makes a guardian material")
	for b in Content.buildings().values():
		for k in ((b.get("work", {}) as Dictionary).get("outputs", {}) as Dictionary).keys():
			check(not T4_MATS.has(String(k).get_slice("/", 1)), "no building makes a guardian material")

func test_tiers_are_ordered_in_the_walk() -> void:
	var w: Dictionary = TechWalk.walk("lfg:class/judd")
	var built: Dictionary = w["built"]
	check(int(built[_b("workbench")]) < int(built[_b("kiln")]), "workbench before kiln")
	for st in NEW_STATIONS:
		var b: Dictionary = Content.building(_b(st))
		check(bool(b["station"]), "%s is a station" % st)
		check(int(built[_b(st)]) > int(built[_b("workbench")]), "%s comes after the workbench" % st)
		if st != "seed_press":
			check(int(built[_b(st)]) > int(built[_b("kiln")]), "%s comes after the kiln (bricks, glass)" % st)
		var tiers: Dictionary = {}
		for k in (b["cost"] as Dictionary).keys():
			tiers[int(Content.item(String(k)).get("tier", 1))] = true
		check(tiers.has(4), "%s needs a guardian's T4 material" % st)
		check(tiers.has(3) or tiers.has(2), "%s also needs earlier tiers" % st)
		check(String(b["requires_unlock"]).begins_with("lfg:unlock/guardian_"), "%s needs a guardian's unlock" % st)
		var recipes: int = 0
		for r in Content.recipes().values():
			if String(r.get("station", "")) == _b(st):
				recipes += 1
		check(recipes >= 2, "%s has recipes (%d)" % [st, recipes])
	check(int(w["have"][_i("guardian_alloy")]) > int(w["have"][_i("vault_sigil")]), "alloy after sigil")
	check(int(w["have"][_i("greatbrew")]) > int(w["have"][_i("fen_gland")]), "greatbrew after fen gland")

func test_five_station_chain_exists() -> void:
	var chain: Array[String] = ["workbench", "kiln", "loom", "spore_forge", "alembic", "rift_anvil", "seed_press"]
	for st in chain:
		check(not Content.building(_b(st)).is_empty() and bool(Content.building(_b(st)).get("station", false)), "%s is a crafting station" % st)
	var stations: int = 0
	for b in Content.buildings().values():
		if bool(b.get("station", false)):
			stations += 1
	eq(stations, 7, "seven stations: four from pass 3, three new")

func test_data_counts_and_models() -> void:
	for n in NEW_STATIONS + NEW_BUILDABLES:
		var b: Dictionary = Content.building(_b(n))
		check(not b.is_empty(), "%s exists" % n)
		check(String(b.get("note", "")) != "", "%s: a one-line note for the build menu" % n)
		check(b.has("group") and int(b["max"]) == 1, "%s: group and max" % n)
	eq(Content.buildings().size(), 42, "29 from pass 3 + 3 stations + 10 buildables")
	# every new buildable carries a key some rule reads
	var keys: Dictionary = {"kennel": "companion_slots", "seed_bank": "seed_return", "compost_heap": "grow_frac", "spore_bed": "work", "ward_stones": "wave_cut",
		"rest_hall": "rest_energy", "guardian_hall": "standing_bonus", "bastion": "garrison_cap", "foraging_den": "companion_forage", "apiary": "work"}
	for n in keys.keys():
		check(Content.building(_b(n)).has(keys[n]), "%s carries %s" % [n, keys[n]])
	var rules_src: String = ""
	for f in ["farming", "economy", "companions", "standing", "sim", "conquest"]:
		rules_src += FileAccess.get_file_as_string("res://rules/%s.gd" % f)
	for k in ["companion_slots", "seed_return", "grow_frac", "wave_cut", "rest_energy", "standing_bonus", "garrison_cap", "companion_forage"]:
		check(rules_src.contains("\"" + k + "\""), "some rule reads %s" % k)
	for n in NEW_STATIONS + NEW_BUILDABLES:
		check(BuildingModelsP4.has_model(_b(n)), "%s has a model" % n)

# ------------------------------------------------------------------ real rules slice: gating end to end
func _arena(s: MatchState, biome: String) -> Dictionary:
	for p in s.world["pois"]:
		if String(p["type"]) == "lfg:poi/arena_" + biome:
			return p
	return {}

func _beat(s: MatchState, biome: String) -> void:
	var arena: Dictionary = _arena(s, biome)
	s.actors[1]["hex"] = arena["hex"]
	var r: Dictionary = cmd(s, "interact_poi", {"poi": arena["id"]})
	check(r["ok"], "%s: ring the bell (%s)" % [biome, r["error"]])
	for id in s.actors.keys():
		var e: Dictionary = s.actors[id]
		if e["kind"] == "enemy" and e["alive"] and bool(Content.enemy(String(e["archetype"])).get("boss", false)):
			Combat.kill(s, int(id), 1, [])
	var r2: Dictionary = cmd(s, "interact_poi", {"poi": arena["id"]})
	check(r2["ok"], "%s: claim (%s)" % [biome, r2["error"]])
	s.actors[1]["hex"] = home(s)["hex"]

func test_stations_are_locked_until_the_guardian_falls_then_real_commands_work() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	a["max_hp"] = 9999
	a["hp"] = 9999
	# stock the raw (T1-T3) parts the walk says a solo leader gathers; the T4 part must come from the arena
	give(s, 1, {_i("stone"): 20, _i("timber"): 20, _i("fired_brick"): 10, _i("iron_fittings"): 10, _i("bog_iron"): 10, _i("glass_pane"): 6})
	var r: Dictionary = cmd(s, "build", {"holding": 1, "building": _b("rift_anvil")})
	eq(r["error"], "locked_building", "locked before the Vaultwarden falls")
	_beat(s, "ruins")
	check((a["unlocks"] as Array).has("lfg:unlock/guardian_ruins"), "unlocked")
	var sigils: int = Inv.count(a["inv"], _i("vault_sigil"))
	check(sigils >= 3, "2 guaranteed + weekly loot (%d)" % sigils)
	r = cmd(s, "build", {"holding": 1, "building": _b("rift_anvil")})
	check(r["ok"], "the Rift Anvil stands: %s" % r["error"])
	eq(Inv.count(a["inv"], _i("vault_sigil")), sigils - 2, "it cost two sigils")
	var cr: Dictionary = cmd(s, "craft", {"recipe": "lfg:recipe/guardian_alloy"})
	check(cr["ok"], "alloy: %s" % cr["error"])
	eq(Inv.count(a["inv"], _i("guardian_alloy")), 1, "one alloy")
	# the Bastion wants three alloys and a Thunder Horn: ruins alone is not enough
	eq(cmd(s, "build", {"holding": 1, "building": _b("bastion")})["error"], "insufficient_items", "needs more than one guardian")
	# a station is needed for the recipe
	var s2: MatchState = quiet()
	give(s2, 1, {_i("vault_sigil"): 1, _i("bog_iron"): 2, _i("iron_fittings"): 2})
	eq(cmd(s2, "craft", {"recipe": "lfg:recipe/guardian_alloy"})["error"], "needs_station", "no anvil, no alloy")

func test_alembic_and_seed_press_unlock_from_their_own_guardians() -> void:
	var s: MatchState = quiet()
	s.actors[1]["max_hp"] = 9999
	s.actors[1]["hp"] = 9999
	give(s, 1, {_i("fired_brick"): 6, _i("glass_pane"): 6, _i("iron_fittings"): 8, _i("timber"): 10, _i("rope"): 6})
	eq(cmd(s, "build", {"holding": 1, "building": _b("alembic")})["error"], "locked_building", "alembic locked")
	eq(cmd(s, "build", {"holding": 1, "building": _b("seed_press")})["error"], "locked_building", "press locked")
	_beat(s, "bog")
	check(cmd(s, "build", {"holding": 1, "building": _b("alembic")})["ok"], "alembic after the Bogtoad")
	eq(cmd(s, "build", {"holding": 1, "building": _b("seed_press")})["error"], "locked_building", "the press still waits for the Gourdmother")
	_beat(s, "meadow")
	check(cmd(s, "build", {"holding": 1, "building": _b("seed_press")})["ok"], "press after the Gourdmother")
	# the press turns crops into more seed
	give(s, 1, {_i("glowfruit"): 4, _i("sporebean"): 2, _i("saltroot"): 1})
	var seeds0: int = Inv.count(s.actors[1]["inv"], _i("glowfruit_seed"))
	check(cmd(s, "craft", {"recipe": "lfg:recipe/press_glowfruit", "qty": 2})["ok"], "press glowfruit")
	eq(Inv.count(s.actors[1]["inv"], _i("glowfruit_seed")), seeds0 + 6, "2 fruit -> 3 seeds, twice")
	# the alembic makes the boss-prep boons and the greatbrew
	give(s, 1, {_i("mushroom"): 2, _i("saltroot"): 1, _i("amber_resin"): 6, _i("reed_fibre"): 2, _i("rime_salt"): 2, _i("glowfruit"): 2})
	check(cmd(s, "craft", {"recipe": "lfg:recipe/battle_stew"})["ok"], "battle stew")
	check(cmd(s, "craft", {"recipe": "lfg:recipe/bark_salve"})["ok"], "bark salve")
	var gb: Dictionary = cmd(s, "craft", {"recipe": "lfg:recipe/greatbrew"})
	check(gb["ok"], "greatbrew from the Bogtoad's gland: %s" % gb["error"])
	s.actors[1]["hp"] = 10
	check(cmd(s, "eat", {"item": _i("greatbrew")})["ok"], "drinkable")
	eq(int(s.actors[1]["hp"]), 100, "heals 90")

# ------------------------------------------------------------------ the ten buildables do what they say
func _holding_with(s: MatchState, names: Array) -> void:
	for n in names:
		(home(s)["buildings"] as Array).append(_b(String(n)))

func test_seed_bank_returns_an_extra_seed() -> void:
	var results: Array = []
	for bank in [false, true]:
		var s: MatchState = quiet()
		if bank:
			_holding_with(s, ["seed_bank"])
		var hx: Vector2i = neighbor_plot(s)
		s.plots[MatchState.plot_key(hx)] = {"crop": "lfg:crop/glowfruit", "age": 2, "watered": false, "dry_days": 0, "holding": 1}
		var before: int = Inv.count(s.actors[1]["inv"], _i("glowfruit_seed"))
		check(cmd(s, "harvest", {"hex": hx})["ok"], "harvest")
		results.append(Inv.count(s.actors[1]["inv"], _i("glowfruit_seed")) - before)
	eq(results, [1, 2], "one seed back, two with a Seed Bank")

func test_compost_heap_ripens_a_day_sooner_over_three_days() -> void:
	var ripe_day: Array = []
	for heap in [false, true]:
		var s: MatchState = quiet()
		if heap:
			_holding_with(s, ["compost_heap"])
		var hx: Vector2i = neighbor_plot(s)
		s.plots[MatchState.plot_key(hx)] = {"crop": "lfg:crop/sporebean", "age": 0, "watered": false, "dry_days": 0, "holding": 1}
		var d: int = 0
		var crop: Dictionary = Content.crop("lfg:crop/sporebean")
		while int(s.plots[MatchState.plot_key(hx)]["age"]) < int(crop["grow_days"]) and d < 10:
			d += 1
			Farming.dawn_crops(s, [])
		ripe_day.append(d)
	eq(ripe_day[0], 4, "sporebean takes 4 dawns")
	eq(ripe_day[1], 3, "3 dawns with compost")

func test_spore_bed_and_apiary_produce_and_the_honey_recipe_works() -> void:
	var s: MatchState = quiet()
	_holding_with(s, ["spore_bed", "apiary"])
	var st: Dictionary = home(s)["store"]
	var m0: int = Inv.count(st, _i("mushroom"))
	var h0: int = Inv.count(st, _i("honey"))
	var ev: Array = []
	Economy.dawn_buildings(s, ev)
	eq(Inv.count(st, _i("mushroom")), m0 + 2, "two mushrooms")
	eq(Inv.count(st, _i("honey")), h0 + 1, "one jar")
	home(s)["garrison"] = 0
	var ev2: Array = []
	Economy.dawn_buildings(s, ev2)
	eq(Inv.count(st, _i("honey")), h0 + 1, "an empty holding does no work")
	give(s, 1, {_i("honey"): 2, _i("sporebean"): 1})
	var rations0: int = Inv.count(s.actors[1]["inv"], _i("ration"))
	check(cmd(s, "craft", {"recipe": "lfg:recipe/ration_honey"})["ok"], "honey ration")
	eq(Inv.count(s.actors[1]["inv"], _i("ration")), rations0 + 2, "two rations")
	give(s, 1, {_i("egg"): 2})
	check(cmd(s, "craft", {"recipe": "lfg:recipe/ration_egg"})["ok"], "egg ration")

func test_ward_stones_turn_beasts_away_with_a_floor_and_a_cap() -> void:
	var sizes: Array = []
	for stones in [0, 1]:
		var s: MatchState = mk("lfg:class/judd", 11, {"ai_enabled": false})
		warp(s, 15, 0.0)      # week 2
		if stones == 1:
			_holding_with(s, ["ward_stones"])
		var ev: Array = []
		Sim._spawn_wave(s, ev)
		for e in ev:
			if String(e["type"]) == "purge_wave":
				sizes.append((e["enemies"] as Array).size())
	eq(sizes.size(), 2, "two waves")
	eq(int(sizes[1]), int(sizes[0]) - 1, "one beast fewer (%d vs %d)" % [sizes[1], sizes[0]])
	# never below one, never more than three in all
	var s2: MatchState = mk("lfg:class/judd", 11, {"ai_enabled": false})
	_holding_with(s2, ["ward_stones"])
	var ev2: Array = []
	Sim._spawn_wave(s2, ev2)
	for e in ev2:
		if String(e["type"]) == "purge_wave":
			check((e["enemies"] as Array).size() >= 1, "at least one beast always comes")
	for hid in s2.holdings.keys():
		s2.holdings[hid]["owner"] = 0
		s2.holdings[hid]["buildings"] = [_b("ward_stones")]
	eq(Economy.wave_cut(s2, 0), 3, "capped at three")
	check(Content.building(_b("ward_stones"))["defense"] >= 4, "and the stones also add defence")

func test_rest_hall_wakes_a_nearby_leader_refreshed() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	_holding_with(s, ["rest_hall"])
	a["energy"] = 10.0
	a["hp"] = 40
	a["hex"] = home(s)["hex"]
	var ev: Array = []
	Economy.dawn_buildings(s, ev)
	eq(float(a["energy"]), float(a["max_energy"]), "energy full")
	eq(int(a["hp"]), 40 + int(ceil(float(a["max_hp"]) * 0.15)), "15% health back")
	eq(count_type(ev, "rest_hall_slept"), 1, "event")
	a["energy"] = 10.0
	a["hex"] = home(s)["hex"] + Vector2i(6, 0)
	Economy.dawn_buildings(s, [])
	eq(float(a["energy"]), 10.0, "away from the hall: nothing")

func test_guardian_hall_adds_standing_and_bastion_adds_defence_and_garrison() -> void:
	var s: MatchState = quiet()
	var sc0: float = Standing.holdings_score(s, 0)
	_holding_with(s, ["guardian_hall"])
	eq(Standing.holdings_score(s, 0), sc0 + 4.0, "Standing +4")
	var p0: float = Conquest.defender_power(s, home(s))
	var cap0: int = Standing.garrison_cap(s, home(s))
	_holding_with(s, ["bastion"])
	check(Conquest.defender_power(s, home(s)) >= p0 + 16.0, "defence +16 at least (multipliers can only help)")
	eq(Standing.garrison_cap(s, home(s)), cap0 + 3, "garrison cap +3")

func test_guardian_hall_needs_all_seven_guardians() -> void:
	var cost: Dictionary = Content.building(_b("guardian_hall"))["cost"]
	for m in T4_MATS:
		check(cost.has(_i(m)), "the Hall asks for a %s" % m)
	var s: MatchState = quiet()
	s.actors[1]["max_hp"] = 9999
	s.actors[1]["hp"] = 9999
	give(s, 1, {_i("fired_brick"): 6, _i("glass_pane"): 3})
	for b in ["meadow", "shore", "fungal_grove", "ruins", "salt_flats", "highlands"]:
		_beat(s, b)
	eq(cmd(s, "build", {"holding": 1, "building": _b("guardian_hall")})["error"], "insufficient_items", "six of seven is not enough")
	_beat(s, "bog")
	var r: Dictionary = cmd(s, "build", {"holding": 1, "building": _b("guardian_hall")})
	check(r["ok"], "seven guardians, one Hall: %s" % r["error"])

# ------------------------------------------------------------------ cost / benefit sanity
func test_production_buildings_pay_for_themselves_in_a_sane_time() -> void:
	for b in Content.buildings().values():
		var w: Dictionary = b.get("work", {})
		if not w.has("outputs"):
			continue
		var net: int = _value(w["outputs"]) - _value(w.get("inputs", {}))
		check(net > 0, "%s: yields more than it eats (net %d/day)" % [b["id"], net])
		var cost: int = _value(b["cost"])
		var days: float = float(cost) / float(maxi(1, net))
		check(days >= 2.0 and days <= 40.0, "%s: pays back in %.1f days (cost %d, net %d/day)" % [b["id"], days, cost, net])

func test_companions_yield_more_than_they_eat() -> void:
	for k in ["mossbun", "truffler", "brindlehen"]:
		var d: Dictionary = Content.companion("lfg:companion/" + k)
		var yield_v: float = 0.0
		var p: Dictionary = d["post"]
		if p.has("haul"):
			yield_v += float(p["haul"]) * 3.0
		if p.has("forage"):
			yield_v += float(p["forage"]) * 3.5
		for it in p.get("produce", {}).keys():
			yield_v += float(Content.item_value(String(it))) * float(p["produce"][it])
		var diet_v: float = float(Content.item_value(String(d["fave"]))) / float(Companions.conf_i("fave_days"))
		check(yield_v > 3.0 * diet_v, "%s: %.1f/day in, %.2f/day food" % [k, yield_v, diet_v])

func test_t4_costs_are_scarce_but_reachable_in_weeks() -> void:
	# a guardian pays 2 (first win) + 1-2 weekly: every building's T4 cost should be met within ten weeks of kills
	var per_week: Dictionary = {}
	for t in Content.poi_types().values():
		if t.has("guardian"):
			for k in (t["loot"] as Dictionary).keys():
				if int(Content.item(String(k)).get("tier", 0)) == 4:
					per_week[String(k)] = float(t["loot"][k][0] + t["loot"][k][1]) * 0.5
	for b in Content.buildings().values():
		for k in (b["cost"] as Dictionary).keys():
			if per_week.has(String(k)):
				var weeks: float = maxf(0.0, (float(b["cost"][k]) - 2.0) / float(per_week[String(k)]))
				check(weeks <= 10.0, "%s: %d x %s needs ~%.1f weeks of kills" % [b["id"], int(b["cost"][k]), k, weeks])
	# bastion: the dearest buildable (three alloys = three sigils + a horn)
	var alloy_weeks: float = 3.0 / float(per_week[_i("vault_sigil")])
	check(alloy_weeks <= 8.0, "three alloys in under eight weeks (%.1f)" % alloy_weeks)

func test_no_recipe_prints_money() -> void:
	for r in Content.recipes().values():
		var vin: int = _value(r["inputs"])
		var vout: int = _value(r["outputs"])
		check(float(vout) <= 2.5 * float(vin), "%s: out %d vs in %d (at most 2.5x)" % [r["id"], vout, vin])
	# the new recipes in particular: nothing converts a cheap pile into a T4 item
	for r in Content.recipes().values():
		for k in (r["outputs"] as Dictionary).keys():
			if int(Content.item(String(k)).get("tier", 0)) == 4:
				var has4: bool = false
				for ik in (r["inputs"] as Dictionary).keys():
					if int(Content.item(String(ik)).get("tier", 0)) == 4:
						has4 = true
				check(has4, "%s: a T4 product needs a T4 input" % r["id"])
