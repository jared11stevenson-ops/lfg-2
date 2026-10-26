extends RulesTestBase

const IMPLEMENTED := ["judd", "mira", "bram", "vex", "oren", "tavi", "pip", "sable", "quill", "forge", "nyx", "rook", "dune", "halo"]

func _enemy_next_to(s: MatchState, arch: String = "lfg:enemy/sporeling", dir: int = 0) -> int:
	return Setup.spawn_enemy(s, arch, s.actors[1]["hex"] + HexGrid.DIRS[dir], false)

func _freeze(s: MatchState, id: int) -> void:
	s.actors[id]["ai"]["state"] = "recovery"
	s.actors[id]["ai"]["t_rec"] = 1.0e9

func test_fourteen_classes_complete_data() -> void:
	var cl: Dictionary = Content.classes()
	eq(cl.size(), 14, "14 classes")
	var impl: int = 0
	for id in cl.keys():
		var c: Dictionary = cl[id]
		check(String(c["id"]).begins_with("lfg:class/"), "namespaced id %s" % id)
		for k in ["peace_perk", "purge_kit", "weakness", "stats", "start_kit", "ability", "name"]:
			check(c.has(k) and str(c[k]) != "", "%s has %s" % [id, k])
		check(c.has("implemented"), "%s has implemented flag" % id)
		var short: String = String(id).get_slice("/", 1)
		eq(bool(c["implemented"]), IMPLEMENTED.has(short), "%s implemented flag matches" % id)
		if bool(c["implemented"]):
			impl += 1
		else:
			check(not (c["ability"]["id"] as String).is_empty(), "%s has placeholder ability id" % id)
	eq(impl, 14, "all 14 implemented")

func test_every_class_can_start_a_match() -> void:
	for id in Content.classes().keys():
		var s: MatchState = Rules.new_match(3, StringName(id), {"ai_enabled": false, "wild_enemies": false})
		eq(s.actors[1]["class_id"], id, "starts as %s" % id)
		check(s.actors[1]["hp"] > 0, "hp")

func test_unimplemented_class_ability_rejected_cleanly() -> void:
	var cd: Dictionary = Content.class_def("lfg:class/tavi")
	cd["implemented"] = false
	var s: MatchState = quiet("lfg:class/tavi")
	var before: String = snap(s)
	eq(cmd(s, "use_ability", {})["error"], "ability_not_implemented", "flagged unimplemented")
	eq(snap(s), before, "no mutation")
	cd["implemented"] = true

func test_judd_guard_halves_damage_with_cost_and_cooldown() -> void:
	var s: MatchState = quiet("lfg:class/judd")
	var p: Dictionary = s.actors[1]
	var ev: Array = []
	Combat.hurt(s, 1, 10, -1, ev, "t")
	eq(p["hp"], 80, "unguarded takes 10")
	var r: Dictionary = cmd(s, "use_ability", {})
	check(r["ok"], "guard: %s" % r["error"])
	eq(p["energy"], 75.0, "25 energy spent")
	Combat.hurt(s, 1, 10, -1, ev, "t")
	eq(p["hp"], 75, "guarded takes 5")
	eq(cmd(s, "use_ability", {})["error"], "cooldown", "cooldown blocks")
	tick_all(s, 13.0, 1.0)
	Combat.hurt(s, 1, 10, -1, ev, "t")
	eq(p["hp"], 65, "guard expired after 12s")
	tick_all(s, 20.0, 1.0)
	check(cmd(s, "use_ability", {})["ok"], "usable again after 30s")
	p["energy"] = 5.0
	s.actors[1]["cd"] = {}
	var before: String = snap(s)
	eq(cmd(s, "use_ability", {})["error"], "no_energy", "energy gate")
	eq(snap(s), before, "no mutation on energy fail")

func test_judd_harvest_bonus_and_weak_attack() -> void:
	var j: MatchState = quiet("lfg:class/judd")
	var b: MatchState = quiet("lfg:class/bram")
	check(Combat.atk_of(j, j.actors[1]) < Combat.atk_of(b, b.actors[1]), "Judd hits weaker")
	eq(Combat.class_mod(j.actors[1], "yield_bonus", 0), 1, "yield bonus")

func test_mira_plague_cloud_poisons_hostiles() -> void:
	var s: MatchState = quiet("lfg:class/mira")
	var before: String = snap(s)
	eq(cmd(s, "use_ability", {})["error"], "no_targets", "no targets rejected")
	eq(snap(s), before, "no mutation when no targets")
	var e1: int = Setup.spawn_enemy(s, "lfg:enemy/rootbrute", s.actors[1]["hex"] + Vector2i(2, 0), false)
	var e2: int = Setup.spawn_enemy(s, "lfg:enemy/rootbrute", s.actors[1]["hex"] + Vector2i(-2, 0), false)
	var far_e: int = Setup.spawn_enemy(s, "lfg:enemy/rootbrute", s.actors[1]["hex"] + Vector2i(6, 0), false)
	for id in [e1, e2, far_e]:
		_freeze(s, id)
	var hp0: int = s.actors[e1]["hp"]
	var r: Dictionary = cmd(s, "use_ability", {})
	check(r["ok"], "plague cloud: %s" % r["error"])
	eq(s.actors[1]["energy"], 90.0, "30 energy")
	tick_all(s, 6.0, 0.5)
	check(s.actors[e1]["hp"] <= hp0 - 15, "poison ticked ~18 (hp %d -> %d)" % [hp0, s.actors[e1]["hp"]])
	check(s.actors[e2]["hp"] < s.actors[e2]["max_hp"], "second enemy poisoned")
	eq(s.actors[far_e]["hp"], s.actors[far_e]["max_hp"], "out of radius untouched")
	eq(cmd(s, "use_ability", {})["error"], "cooldown", "cooldown")

func test_mira_exclusive_tonic_recipe_and_frailty() -> void:
	var m: MatchState = quiet("lfg:class/mira")
	var j: MatchState = quiet("lfg:class/judd")
	for s in [m, j]:
		give(s, 1, {"lfg:item/mushroom": 2, "lfg:item/glowfruit": 2})
	check(cmd(m, "craft", {"recipe": "lfg:recipe/tonic"})["ok"], "Mira brews")
	eq(cmd(j, "craft", {"recipe": "lfg:recipe/tonic"})["error"], "class_required", "Judd cannot")
	check(m.actors[1]["max_hp"] < j.actors[1]["max_hp"], "Mira frail")

func test_bram_forage_and_rage() -> void:
	var s: MatchState = quiet("lfg:class/bram")
	var p: Dictionary = s.actors[1]
	var m0: int = Inv.count(p["inv"], "lfg:item/mushroom")
	var r: Dictionary = cmd(s, "use_ability", {"ability": "lfg:ability/forage"})
	check(r["ok"], "forage: %s" % r["error"])
	check(Inv.count(p["inv"], "lfg:item/mushroom") > m0, "found mushrooms")
	eq(cmd(s, "use_ability", {"ability": "lfg:ability/forage"})["error"], "cooldown", "forage cooldown")
	var atk0: float = Combat.atk_of(s, p)
	var def0: float = Combat.def_of(s, p)
	var hp0: int = p["hp"]
	r = cmd(s, "use_ability", {})
	check(r["ok"], "rage: %s" % r["error"])
	eq(p["hp"], hp0 - 10, "rage costs 10 hp")
	eq(Combat.atk_of(s, p), atk0 * 1.5, "+50% attack")
	check(Combat.def_of(s, p) < def0, "defense drops")
	tick_all(s, 16.0, 1.0)
	eq(Combat.atk_of(s, p), atk0, "rage expires")
	p["hp"] = 5
	p["cd"] = {}
	eq(cmd(s, "use_ability", {})["error"], "too_weak", "cannot rage to death")
	warp(s, 7, 0.7)
	p["cd"] = {}
	eq(cmd(s, "use_ability", {"ability": "lfg:ability/forage"})["error"], "not_in_purge", "no foraging in purge")

func test_vex_pickpocket_and_steal_bonus() -> void:
	var s: MatchState = quiet("lfg:class/vex")
	var victim: Dictionary = s.actors[int(s.factions[1]["leader"])]
	victim["inv"] = {"lfg:item/coin": 7, "lfg:item/tonic": 2}
	victim["hex"] = s.actors[1]["hex"] + HexGrid.DIRS[0]
	eq(cmd(s, "use_ability", {"target": victim["id"]})["error"], "not_purge", "peace: no pickpocket")
	warp(s, 7, 0.7)
	var t0: Dictionary = Inv.world_totals(s)
	var got: int = 0
	var failed: int = 0
	for i in range(8):
		s.actors[1]["cd"] = {}
		s.actors[1]["energy"] = 100.0
		s.actors[1]["hp"] = 100
		var r: Dictionary = cmd(s, "use_ability", {"target": victim["id"]})
		check(r["ok"], "pickpocket call: %s" % r["error"])
		eq(Inv.world_totals(s), t0, "pickpocket conserves items")
		for e in r["events"]:
			if String(e["type"]) == "ability_used":
				if e.get("success", false):
					got += 1
				else:
					failed += 1
	check(got > 0, "some pickpockets succeed")
	check(got + failed == 8, "all resolved")
	var j: MatchState = quiet("lfg:class/judd")
	warp(j, 7, 0.7)
	var h: Dictionary = j.holdings[2]
	check(Conquest.steal_chance(s, s.actors[1], h) > Conquest.steal_chance(j, j.actors[1], h) + 0.3, "Vex steals far better from stores")

func test_oren_field_dressing() -> void:
	var s: MatchState = quiet("lfg:class/oren")
	var p: Dictionary = s.actors[1]
	eq(cmd(s, "use_ability", {})["error"], "full_health", "no waste at full hp")
	p["hp"] = 30
	var r: Dictionary = cmd(s, "use_ability", {})
	check(r["ok"], "heal: %s" % r["error"])
	eq(p["hp"], 60, "+30")
	eq(p["energy"], 80.0, "20 energy")
	eq(cmd(s, "use_ability", {})["error"], "full_health" if p["hp"] >= p["max_hp"] else "cooldown", "cooldown or full")
	p["hp"] = 10
	eq(cmd(s, "use_ability", {})["error"], "cooldown", "cooldown 8s")
	tick_all(s, 9.0, 1.0)
	check(cmd(s, "use_ability", {})["ok"], "ready again")
	s.actors[1]["cd"] = {}
	s.actors[1]["hp"] = 10
	eq(cmd(s, "use_ability", {"target": 101})["error"], "bad_target", "cannot heal rivals")

func test_class_stat_budgets_not_absurd() -> void:
	for c in Content.classes().values():
		var st: Dictionary = c["stats"]
		var power: int = int(st["hp"]) / 10 + int(st["atk"]) * 3 + int(st["def"]) * 4
		check(power >= 14 and power <= 33, "%s power budget %d" % [c["id"], power])
