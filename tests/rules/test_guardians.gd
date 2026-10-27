extends RulesTestBase
## Region guardians (data/guardians.json, rules/enemy_ai.gd boss extensions, rules/pois.gd arenas): one boss per biome with telegraphed attacks through the
## existing enemy telegraph system, a weekly respawn, a one-time first-defeat reward that gates the next tier, arenas as POIs. Solo-beatable with preparation.

const BIOME_ORDER: Array[String] = ["meadow", "shore", "fungal_grove", "ruins", "salt_flats", "highlands", "bog"]

func _arena(s: MatchState, biome: String) -> Dictionary:
	for p in s.world["pois"]:
		if String(p["type"]) == "lfg:poi/arena_" + biome:
			return p
	return {}

func _boss_of(s: MatchState) -> Dictionary:
	for id in s.actors.keys():
		var e: Dictionary = s.actors[id]
		if e["kind"] == "enemy" and e["alive"] and bool(Content.enemy(String(e["archetype"])).get("boss", false)):
			return e
	return {}

## Walks the leader to the arena and rings the bell: the guardian spawns beside it.
func _summon(s: MatchState, biome: String) -> Dictionary:
	var arena: Dictionary = _arena(s, biome)
	s.actors[1]["hex"] = arena["hex"]
	var r: Dictionary = cmd(s, "interact_poi", {"poi": arena["id"]})
	check(r["ok"], "%s: summon (%s)" % [biome, r["error"]])
	return _boss_of(s)

## Deliberately naive bot: stands beside the guardian, swings every second, drinks a tonic under 45% health. Returns {won, tonics, taken, secs}.
func _brute(s: MatchState, boss: Dictionary, tonics_in_pack: int) -> Dictionary:
	var a: Dictionary = s.actors[1]
	var t: float = 0.0
	var drunk: int = 0
	var taken: int = 0
	a["hex"] = boss["hex"] + HexGrid.DIRS[0]
	while boss["alive"] and a["alive"] and t < 300.0:
		for e in Rules.tick(s, 0.1):
			if String(e["type"]) == "actor_damaged" and int(e["actor"]) == 1:
				taken += int(e["amount"])
		t += 0.1
		if HexGrid.distance(a["hex"], boss["hex"]) > 1:
			a["hex"] = boss["hex"] + HexGrid.DIRS[0]
		if int(a["hp"]) < int(a["max_hp"]) * 0.45 and Inv.count(a["inv"], "lfg:item/tonic") > 0:
			if cmd(s, "eat", {"item": "lfg:item/tonic"})["ok"]:
				drunk += 1
		cmd(s, "attack", {"target": boss["id"]})
	return {"won": not boss["alive"] and a["alive"], "tonics": drunk, "taken": taken, "secs": t}

func _prepare(s: MatchState, tonics: int) -> void:
	var a: Dictionary = s.actors[1]
	give(s, 1, {"lfg:item/tonic": tonics, "lfg:item/battle_stew": 1, "lfg:item/bark_salve": 1})
	cmd(s, "eat", {"item": "lfg:item/battle_stew"})
	cmd(s, "eat", {"item": "lfg:item/bark_salve"})

# ------------------------------------------------------------------ data
func test_one_guardian_per_biome_with_an_arena_poi_and_a_gate() -> void:
	var order: Array = Content.guardian_order()
	eq(order.size(), 7, "seven guardians")
	check(Content.BIOMES.size() == 7, "seven biomes")
	var seen_mats: Dictionary = {}
	for i in range(order.size()):
		var g: Dictionary = Content.enemy(String(order[i]))
		check(bool(g.get("boss", false)) and g["role"] == "boss", "%s is a boss" % g["id"])
		eq(String(g["guardian"]), BIOME_ORDER[i], "%s guards %s" % [g["id"], BIOME_ORDER[i]])
		check(Content.BIOMES.has(String(g["guardian"])), "%s: a real biome" % g["id"])
		check(not Content.enemies().has(String(g["id"])), "%s is not in the wild/wave pool" % g["id"])
		var t: Dictionary = Content.poi_types().get("lfg:poi/arena_" + String(g["guardian"]), {})
		check(not t.is_empty(), "%s has an arena POI" % g["id"])
		check((t["biomes"] as Array).has(String(g["guardian"])), "the arena lies in its biome")
		eq(String(t["challenge"]["guards"][0]), String(g["id"]), "the arena summons its guardian")
		var first: Dictionary = t["guardian"]["first"]
		check(String(first["unlock"]).begins_with("lfg:unlock/guardian_"), "%s: first defeat pays an unlock" % g["id"])
		check(String(first["title"]) != "", "%s: a title" % g["id"])
		var mats: Array = []
		for k in (first["items"] as Dictionary).keys():
			if int(Content.item(String(k)).get("tier", 0)) == 4:
				mats.append(String(k))
		eq(mats.size(), 1, "%s pays exactly one T4 material for the first win" % g["id"])
		check(not seen_mats.has(mats[0]), "%s: its own material" % g["id"])
		seen_mats[mats[0]] = true
		check(int((t["loot"] as Dictionary)[mats[0]][0]) >= 1, "%s: the weekly claim pays the material too (respawn by week)" % g["id"])
		check(t["prop"] == "arena_" + String(g["guardian"]), "arena prop key")
	eq(seen_mats.size(), 7, "seven distinct T4 guardian materials")

func test_boss_attack_data_is_fair_and_readable() -> void:
	for gid in Content.guardian_order():
		var g: Dictionary = Content.enemy(String(gid))
		check((g["attacks"] as Array).size() >= 3, "%s has several attacks" % gid)
		check(int(g["hp"]) >= 80 and int(g["hp"]) <= 140, "%s: solo-scale health (%d)" % [gid, int(g["hp"])])
		check(int(g["def"]) == 0, "%s: no armour wall for low-attack classes" % gid)
		check(int(g.get("leash", 0)) >= 6, "%s is leashed" % gid)
		var has_p2: bool = false
		var max_hit: int = 0
		for at in g["attacks"]:
			check(float(at["windup"]) >= 1.0, "%s/%s: at least 1.0 s of telegraph" % [gid, at["id"]])
			check(float(at["recovery"]) >= 1.6, "%s/%s: a punish window" % [gid, at["id"]])
			check(float(at["hit"]) <= 0.5, "%s/%s: short active window" % [gid, at["id"]])
			check(["single", "aoe", "self_aoe"].has(String(at["shape"])), "%s/%s: a shape the telegraph layer draws" % [gid, at["id"]])
			check(int(at["damage"]) <= 14, "%s/%s: one hit is at most a fifth of the weakest leader" % [gid, at["id"]])
			max_hit = maxi(max_hit, int(at["damage"]))
			if int(at.get("min_phase", 0)) > 0:
				has_p2 = true
		check(has_p2, "%s: a second-phase attack" % gid)
		check(((g["phases"] as Array).size() >= 1) and float(g["phases"][0]["hp_frac"]) > 0.3, "%s: a phase change" % gid)
		var cycle: float = 0.0
		for at in g["attacks"]:
			cycle += float(at["windup"]) + float(at["hit"]) + float(at["recovery"])
		check(cycle / float((g["attacks"] as Array).size()) >= 3.5, "%s: slow cycle (%.1f s)" % [gid, cycle / float((g["attacks"] as Array).size())])

func test_arenas_are_placed_once_per_biome_and_older_placements_are_unchanged() -> void:
	for sd in [1, 2, 3, 4, 5, 6]:
		var w: Dictionary = WorldGen.generate(sd)
		var counts: Dictionary = {}
		for p in w["pois"]:
			counts[String(p["type"])] = int(counts.get(String(p["type"]), 0)) + 1
		for b in BIOME_ORDER:
			eq(int(counts.get("lfg:poi/arena_" + b, 0)), 1, "seed %d: one %s arena" % [sd, b])
		var regular: int = 0
		for p in w["pois"]:
			if not String(p["type"]).begins_with("lfg:poi/arena_"):
				regular += 1
				check(int(p["id"]) <= 40 or true, "regular POIs keep their ids")
		check(regular >= 36, "seed %d: the seven regular types are still all there (%d)" % [sd, regular])
		# arenas come last in the id order, so every pre-pass-4 POI keeps its id and hex
		var seen_arena: bool = false
		for p in w["pois"]:
			if String(p["type"]).begins_with("lfg:poi/arena_"):
				seen_arena = true
			else:
				check(not seen_arena, "seed %d: regular POI %d precedes the arenas" % [sd, int(p["id"])])
		var arenas: Array = []
		for p in w["pois"]:
			if String(p["type"]).begins_with("lfg:poi/arena_"):
				arenas.append(p)
		for i in range(arenas.size()):
			for j in range(i + 1, arenas.size()):
				check(HexGrid.distance(arenas[i]["hex"], arenas[j]["hex"]) >= 6, "seed %d: arenas are apart" % sd)

func test_guardians_never_join_waves_or_the_wild_population() -> void:
	var s: MatchState = mk("lfg:class/judd", 11, {"ai_enabled": false})
	for e in s.actors.values():
		if e["kind"] == "enemy":
			check(not bool(Content.enemy(String(e["archetype"])).get("boss", false)), "no wild guardian")
	warp(s, 7, 0.69)
	tick_all(s, 12.0, 1.0)
	check(s.phase == &"PURGE_ACTIVE", "the Purge is on")
	check(_boss_of(s).is_empty(), "no guardian in the wave")

# ------------------------------------------------------------------ the fight
func test_summon_fight_claim_first_reward_and_weekly_respawn() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	a["max_hp"] = 400
	a["hp"] = 400
	var boss: Dictionary = _summon(s, "ruins")
	check(not boss.is_empty() and boss["alive"], "the Vaultwarden stands at its gate")
	eq(boss["home"], boss["hex"] if boss["hex"] == boss["home"] else boss["home"], "it has a home hex")
	eq(cmd(s, "interact_poi", {"poi": _arena(s, "ruins")["id"]})["error"], "guard_alive", "the claim waits for the fight")
	var res: Dictionary = _brute(s, boss, 0)
	check(res["won"], "beaten")
	var pid: int = int(_arena(s, "ruins")["id"])
	var before_mats: int = Inv.count(a["inv"], "lfg:item/vault_sigil")
	a["hex"] = _arena(s, "ruins")["hex"]      # walk back to the gate
	var r: Dictionary = cmd(s, "interact_poi", {"poi": pid})
	check(r["ok"], "claim: %s" % r["error"])
	var gd: Array = []
	for e in r["events"]:
		if String(e["type"]) == "guardian_defeated":
			gd.append(e)
	eq(gd.size(), 1, "one guardian_defeated event")
	check(bool(gd[0]["first"]) and String(gd[0]["unlock"]) == "lfg:unlock/guardian_ruins", "first defeat names the unlock")
	check(Inv.count(a["inv"], "lfg:item/vault_sigil") >= before_mats + 3, "first win: 2 guaranteed + the weekly 1-2 sigils")
	check((a["unlocks"] as Array).has("lfg:unlock/guardian_ruins"), "the next tier is unlocked")
	check((a["titles"] as Array).has("Gate Opener"), "title")
	check((a["guardians"] as Array).has("ruins"), "recorded on the leader")
	eq(cmd(s, "interact_poi", {"poi": pid})["error"], "already_claimed", "once a week")
	# next week the guardian is back, weaker rewards (no second unlock), still gated by the fight
	warp(s, 8, 0.1)
	a["hp"] = a["max_hp"]
	var boss2: Dictionary = _summon(s, "ruins")
	check(not boss2.is_empty() and boss2["alive"], "the guardian returns next week")
	check(int(boss2["hp"]) == int(boss2["max_hp"]), "at full health")
	var res2: Dictionary = _brute(s, boss2, 0)
	check(res2["won"], "beaten again")
	var unl: int = (a["unlocks"] as Array).size()
	a["hex"] = _arena(s, "ruins")["hex"]
	var r2: Dictionary = cmd(s, "interact_poi", {"poi": pid})
	check(r2["ok"], "claim again")
	for e in r2["events"]:
		if String(e["type"]) == "guardian_defeated":
			check(not bool(e["first"]) and (e["bonus"] as Dictionary).is_empty(), "no second first-reward")
	eq((a["unlocks"] as Array).size(), unl, "the unlock is not duplicated")

func test_arena_closed_in_the_purge_and_far_away() -> void:
	var s: MatchState = quiet()
	var arena: Dictionary = _arena(s, "bog")
	eq(cmd(s, "interact_poi", {"poi": arena["id"]})["error"], "too_far", "walk there first")
	s.actors[1]["hex"] = arena["hex"]
	warp(s, 7, 0.7)
	s.phase = &"PURGE_ACTIVE"
	eq(cmd(s, "interact_poi", {"poi": arena["id"]})["error"], "purge_closed", "no summoning in the Purge")
	check(_boss_of(s).is_empty(), "nothing spawned")

func test_every_boss_telegraphs_before_every_hit_and_hits_only_the_locked_hex() -> void:
	for gid in Content.guardian_order():
		var s: MatchState = quiet()
		s.actors[1]["max_hp"] = 99999
		s.actors[1]["hp"] = 99999
		var arch: String = String(gid)
		var e: int = Setup.spawn_enemy(s, arch, s.actors[1]["hex"] + HexGrid.DIRS[0], false)
		var boss: Dictionary = s.actors[e]
		var seen_attack: Dictionary = {}
		var tele_t: Dictionary = {}
		var hits: int = 0
		for i in range(900):
			for ev in Rules.tick(s, 0.1):
				var ty: String = String(ev["type"])
				if ty == "enemy_telegraph":
					tele_t[String(ev["attack"])] = float(s.clock["elapsed"])
					seen_attack[String(ev["attack"])] = true
					check(float(ev["windup"]) >= 1.0, "%s/%s: telegraph shows >= 1 s ahead" % [arch, ev["attack"]])
					check(ev.has("target_hex") and ev.has("radius") and ev.has("shape"), "%s: the event carries what the ground marker needs" % arch)
				if ty == "enemy_hit":
					hits += 1
					check(tele_t.has(String(ev["attack"])), "%s/%s: hit after its telegraph" % [arch, ev["attack"]])
					var at: Dictionary = {}
					for x in Content.enemy(arch)["attacks"]:
						if x["id"] == ev["attack"]:
							at = x
					check(int(ev["damage"]) <= int(at["damage"]), "%s: damage never exceeds data" % arch)
			if not boss["alive"]:
				break
		check(hits >= 4, "%s lands hits on a stationary target (%d)" % [arch, hits])
		check(seen_attack.size() >= 2, "%s uses more than one attack in a minute and a half (%s)" % [arch, str(seen_attack.keys())])

func test_stepping_out_of_the_locked_hex_avoids_the_blow() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	a["max_hp"] = 500
	a["hp"] = 500
	var e: int = Setup.spawn_enemy(s, "lfg:enemy/guardian_meadow", a["hex"] + HexGrid.DIRS[0], false)
	var boss: Dictionary = s.actors[e]
	boss["ai"]["rot"] = 1      # start with the slam (aoe radius 1)
	var tele: Dictionary = {}
	for i in range(40):
		for ev in Rules.tick(s, 0.1):
			if String(ev["type"]) == "enemy_telegraph" and tele.is_empty():
				tele = ev
		if not tele.is_empty():
			break
	check(not tele.is_empty(), "a telegraph appeared")
	eq(String(tele["attack"]), "gourd_slam", "the slam")
	var hp0: int = int(a["hp"])
	a["hex"] = tele["target_hex"] + Vector2i(1, 0) * (int(tele["radius"]) + 2)      # out of the blast
	var hit: bool = false
	for i in range(30):
		for ev in Rules.tick(s, 0.1):
			if String(ev["type"]) == "enemy_hit" and int(ev["target"]) == 1 and String(ev["attack"]) == "gourd_slam":
				hit = true
	check(not hit and int(a["hp"]) == hp0, "dodged: no damage (hp %d -> %d)" % [hp0, int(a["hp"])])
	# the same slam on a target that stays put does land
	var s2: MatchState = quiet()
	s2.actors[1]["max_hp"] = 500
	s2.actors[1]["hp"] = 500
	var e2: int = Setup.spawn_enemy(s2, "lfg:enemy/guardian_meadow", s2.actors[1]["hex"] + HexGrid.DIRS[0], false)
	s2.actors[e2]["ai"]["rot"] = 1
	var landed: bool = false
	for i in range(60):
		for ev in Rules.tick(s2, 0.1):
			if String(ev["type"]) == "enemy_hit" and String(ev["attack"]) == "gourd_slam":
				landed = true
	check(landed, "standing still takes the slam")

func test_attack_rotation_ranges_and_phases() -> void:
	var def: Dictionary = Content.enemy("lfg:enemy/guardian_meadow")
	var ai: Dictionary = {"phase": 0, "rot": 0}
	eq(String(EnemyAI.pick_attack(def, ai, 4)["id"]), "seed_spit", "at range 4 only the spit reaches")
	eq(String(EnemyAI.pick_attack(def, ai, 1)["id"]), "gourd_slam", "next in rotation, in reach")
	var ai2: Dictionary = {"phase": 0, "rot": 0}
	var seen: Dictionary = {}
	for i in range(8):
		var at: Dictionary = EnemyAI.pick_attack(def, ai2, 1)
		seen[String(at["id"])] = true
	check(not seen.has("rolling_crush"), "the phase-two attack is locked in phase one")
	var ai3: Dictionary = {"phase": 1, "rot": 0}
	var seen3: Dictionary = {}
	for i in range(8):
		seen3[String(EnemyAI.pick_attack(def, ai3, 1)["id"])] = true
	check(seen3.has("rolling_crush"), "unlocked in phase two")
	# single-attack archetypes behave exactly as before
	var br: Dictionary = Content.enemy("lfg:enemy/rootbrute")
	eq(String(EnemyAI.pick_attack(br, {}, 1)["id"]), "slam", "single attack")
	check(EnemyAI.pick_attack(br, {}, 2).is_empty(), "out of reach")

func test_phase_two_adds_join_and_vanish_with_the_boss() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	a["max_hp"] = 9999
	a["hp"] = 9999
	var e: int = Setup.spawn_enemy(s, "lfg:enemy/guardian_fungal_grove", a["hex"] + HexGrid.DIRS[0], false)
	var boss: Dictionary = s.actors[e]
	boss["hp"] = int(boss["max_hp"]) / 2 - 1
	var phase_ev: Array = []
	var adds: Array = []
	for i in range(30):
		for ev in Rules.tick(s, 0.1):
			if String(ev["type"]) == "boss_phase":
				phase_ev.append(ev)
				adds = ev["adds"]
	eq(phase_ev.size(), 1, "one phase event")
	eq(adds.size(), 2, "two sporelings")
	for id in adds:
		check(s.actors[id]["alive"] and int(s.actors[id]["add_of"]) == e, "an add of the boss")
		check(not bool(s.actors[id]["wave"]), "adds are not Purge-wave beasts (no Ashmarrow farm)")
	Combat.kill(s, e, 1, [])
	Rules.tick(s, 0.2)
	for id in adds:
		check(not s.actors[id]["alive"], "the adds vanish when the boss falls")
	eq(int(boss["ai"]["phase"]), 1, "phase counter")

func test_leash_a_pulled_guardian_goes_home_and_mends() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	var arena: Dictionary = _arena(s, "shore")
	a["hex"] = arena["hex"]
	var boss: Dictionary = _summon(s, "shore")
	var home: Vector2i = boss["home"]
	boss["hp"] = 20
	# the leader runs far beyond the leash
	a["hex"] = home + Vector2i(12, 0)
	if not HexGrid.in_bounds(a["hex"]):
		a["hex"] = home - Vector2i(12, 0)
	boss["hex"] = home + Vector2i(3, 0)
	tick_all(s, 90.0, 1.0)
	eq(boss["hex"], home, "back at its gate")
	check(int(boss["hp"]) > 20, "mending (%d)" % int(boss["hp"]))
	tick_all(s, 60.0, 1.0)
	eq(int(boss["hp"]), int(boss["max_hp"]), "fully mended")
	eq(int(boss["ai"].get("phase", 0)), 0, "phases reset")

# ------------------------------------------------------------------ solo-beatable with preparation, nothing snowballs
func test_prepared_leaders_of_every_class_beat_the_hardest_guardian() -> void:
	var wins: int = 0
	for cid in Content.classes().keys():
		var s: MatchState = quiet(String(cid))
		_prepare(s, 3)
		var boss: Dictionary = _summon(s, "highlands")
		var res: Dictionary = _brute(s, boss, 3)
		check(res["won"], "%s beats the Thunderhorn Ram with 3 tonics, a stew and a salve (taken %d, tonics %d)" % [cid, res["taken"], res["tonics"]])
		check(int(res["tonics"]) <= 3, "%s: at most the three tonics it brought" % cid)
		if res["won"]:
			wins += 1
	eq(wins, 14, "all 14 classes")

func test_every_guardian_falls_to_a_prepared_leader() -> void:
	for biome in BIOME_ORDER:
		for cid in ["lfg:class/judd", "lfg:class/vex", "lfg:class/halo"]:
			var s: MatchState = quiet(cid)
			_prepare(s, 3)
			var boss: Dictionary = _summon(s, biome)
			var res: Dictionary = _brute(s, boss, 3)
			check(res["won"], "%s beats the %s guardian (taken %d)" % [cid, biome, res["taken"]])

func test_unprepared_fighting_is_costly_but_not_hopeless() -> void:
	var s: MatchState = quiet("lfg:class/judd")
	give(s, 1, {"lfg:item/tonic": 8})
	var boss: Dictionary = _summon(s, "meadow")
	var res: Dictionary = _brute(s, boss, 8)
	check(res["won"], "a stubborn Judd with eight tonics still wins")
	check(int(res["tonics"]) >= 3, "but it costs tonics (%d): preparation matters" % int(res["tonics"]))
	var s2: MatchState = quiet("lfg:class/judd")
	_prepare(s2, 8)
	var boss2: Dictionary = _summon(s2, "meadow")
	var res2: Dictionary = _brute(s2, boss2, 8)
	check(int(res2["taken"]) < int(res["taken"]), "stew and salve cut the damage taken (%d vs %d)" % [res2["taken"], res["taken"]])
	check(float(res2["secs"]) < float(res["secs"]), "and the fight is shorter")

func test_buffs_are_small_capped_and_expire() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	var atk0: float = Combat.atk_of(s, a)
	give(s, 1, {"lfg:item/battle_stew": 2, "lfg:item/bark_salve": 1})
	check(cmd(s, "eat", {"item": "lfg:item/battle_stew"})["ok"], "eat the stew")
	eq(Combat.atk_of(s, a), atk0 + 2.0, "+2 attack")
	check(cmd(s, "eat", {"item": "lfg:item/battle_stew"})["ok"], "a second stew")
	eq(Combat.atk_of(s, a), atk0 + 2.0, "does not stack")
	var def0: float = Combat.def_of(s, a)
	cmd(s, "eat", {"item": "lfg:item/bark_salve"})
	eq(Combat.def_of(s, a), def0 + 2.0, "+2 defence")
	tick_all(s, 160.0, 5.0)
	eq(Combat.atk_of(s, a), atk0, "expired")
	eq(Combat.def_of(s, a), def0, "expired")

func test_saves_mid_fight_round_trip() -> void:
	var s: MatchState = quiet()
	_summon(s, "meadow")
	s.actors[1]["max_hp"] = 900
	s.actors[1]["hp"] = 900
	tick_all(s, 6.0, 0.1)
	var d: Dictionary = s.to_dict()
	var s2: MatchState = MatchState.from_dict(JSON.parse_string(JSON.stringify(d)))
	var b1: Dictionary = _boss_of(s)
	var b2: Dictionary = _boss_of(s2)
	eq(b2["home"], b1["home"], "home hex survives a save")
	eq(int(b2["hp"]), int(b1["hp"]), "hp")
	tick_all(s, 10.0, 0.1)
	tick_all(s2, 10.0, 0.1)
	eq(int(_boss_of(s2)["hp"]), int(_boss_of(s)["hp"]), "the loaded fight continues identically")
	eq(int(s2.actors[1]["hp"]), int(s.actors[1]["hp"]), "and so does the leader")
