extends RulesTestBase

func _spawn_adjacent(s: MatchState, arch: String) -> int:
	return Setup.spawn_enemy(s, arch, s.actors[1]["hex"] + HexGrid.DIRS[0], false)

func test_six_enemy_archetypes_defined_as_data() -> void:
	var en: Dictionary = Content.enemies()
	eq(en.size(), 6, "6 archetypes")
	var roles: Dictionary = {}
	for e in en.values():
		roles[e["role"]] = true
		check(int(e["hp"]) > 0 and float(e["sec_per_hex"]) > 0.0 and int(e["aggro"]) > 0, "%s stats" % e["id"])
		check((e["attacks"] as Array).size() >= 1, "%s has attacks" % e["id"])
		for a in e["attacks"]:
			check(float(a["windup"]) > 0.0 and float(a["hit"]) > 0.0 and float(a["recovery"]) > 0.0, "%s/%s has windup, hit, recovery" % [e["id"], a["id"]])
			check(int(a["damage"]) > 0 and int(a["range"]) >= 1, "%s damage/range" % a["id"])
			check(["single", "aoe", "self_aoe"].has(a["shape"]), "%s shape" % a["id"])
	eq(roles.size(), 6, "distinct roles")

func test_telegraph_precedes_hit_and_respects_windup() -> void:
	var s: MatchState = quiet()
	var e: int = _spawn_adjacent(s, "lfg:enemy/sporeling")
	var tele_at: float = -1.0
	var hit_at: float = -1.0
	var hp0: int = s.actors[1]["hp"]
	for i in range(40):
		for ev in Rules.tick(s, 0.1):
			if String(ev["type"]) == "enemy_telegraph" and tele_at < 0.0:
				tele_at = float(s.clock["elapsed"])
				eq(ev["target_hex"], s.actors[1]["hex"], "telegraph locks target hex")
				eq(ev["windup"], 0.5, "windup in event")
			if String(ev["type"]) == "enemy_hit" and hit_at < 0.0:
				hit_at = float(s.clock["elapsed"])
	check(tele_at >= 0.0, "telegraph emitted")
	check(hit_at > tele_at, "hit strictly after telegraph")
	check(hit_at - tele_at >= 0.45, "windup respected (%.2f)" % (hit_at - tele_at))
	check(s.actors[1]["hp"] < hp0, "damage dealt")

func test_attack_is_dodgeable_by_leaving_telegraphed_hex() -> void:
	var s: MatchState = quiet()
	var e: int = _spawn_adjacent(s, "lfg:enemy/rootbrute")
	var hp0: int = s.actors[1]["hp"]
	var seen: bool = false
	for i in range(30):
		for ev in Rules.tick(s, 0.1):
			if String(ev["type"]) == "enemy_telegraph":
				seen = true
		if seen:
			break
	check(seen, "rootbrute telegraphs")
	s.actors[1]["hex"] = s.actors[1]["hex"] + Vector2i(-4, 0)  # dodge out of the slam radius
	tick_all(s, 4.0, 0.1)
	eq(s.actors[1]["hp"], hp0, "dodged: no damage")

func test_aoe_hits_neighbors_of_target_hex() -> void:
	var s: MatchState = quiet()
	var e: int = _spawn_adjacent(s, "lfg:enemy/rootbrute")
	# an ally of the player standing one hex from the player is caught in the radius-1 slam
	var ally: Dictionary = Setup.make_actor(s.new_id(), "follower", 0, "Ally", s.actors[1]["hex"] + HexGrid.DIRS[5], 50, 1, 0, 0)
	s.actors[ally["id"]] = ally
	tick_all(s, 3.0, 0.1)
	check(ally["hp"] < 50, "aoe splash hit ally")
	check(s.actors[1]["hp"] < s.actors[1]["max_hp"], "and the player")

func test_recovery_prevents_immediate_second_attack() -> void:
	var s: MatchState = quiet()
	s.actors[1]["max_hp"] = 9999
	s.actors[1]["hp"] = 9999
	var e: int = _spawn_adjacent(s, "lfg:enemy/rootbrute")
	var tele_times: Array = []
	for i in range(100):
		for ev in Rules.tick(s, 0.1):
			if String(ev["type"]) == "enemy_telegraph":
				tele_times.append(float(s.clock["elapsed"]))
	check(tele_times.size() >= 2, "repeats attack")
	check(tele_times[1] - tele_times[0] >= 1.4 + 0.3 + 1.8 - 0.15, "full windup+hit+recovery cycle between telegraphs (%.2f)" % (tele_times[1] - tele_times[0]))

func test_every_archetype_telegraphs_then_hits() -> void:
	for arch in Content.enemies().keys():
		var s: MatchState = quiet()
		s.actors[1]["max_hp"] = 9999
		s.actors[1]["hp"] = 9999
		var e: int = _spawn_adjacent(s, arch)
		var tele: bool = false
		var hit: bool = false
		for i in range(80):
			for ev in Rules.tick(s, 0.1):
				if String(ev["type"]) == "enemy_telegraph":
					tele = true
				if String(ev["type"]) == "enemy_hit":
					check(tele, "%s hit after telegraph" % arch)
					hit = true
		check(tele and hit, "%s telegraphs and hits" % arch)

func test_mire_leech_poisons() -> void:
	var s: MatchState = quiet()
	_spawn_adjacent(s, "lfg:enemy/mire_leech")
	tick_all(s, 1.5, 0.1)
	check(Combat.has_effect(s, s.actors[1], "poison"), "poisoned by latch")

func test_enemy_approaches_and_ranged_attacks_from_distance() -> void:
	var s: MatchState = quiet()
	var e: int = Setup.spawn_enemy(s, "lfg:enemy/thorn_slinger", s.actors[1]["hex"] + Vector2i(4, 0), false)
	var tele: bool = false
	for i in range(30):
		for ev in Rules.tick(s, 0.1):
			if String(ev["type"]) == "enemy_telegraph":
				tele = true
	check(tele, "slinger telegraphs at range 4")
	eq(s.actors[e]["hex"], s.actors[1]["hex"] + Vector2i(4, 0), "did not need to close in")
	var s2: MatchState = quiet()
	var far: int = Setup.spawn_enemy(s2, "lfg:enemy/sporeling", s2.actors[1]["hex"] + Vector2i(5, 0), false)
	var d0: int = HexGrid.distance(s2.actors[far]["hex"], s2.actors[1]["hex"])
	tick_all(s2, 3.0, 0.1)
	check(HexGrid.distance(s2.actors[far]["hex"], s2.actors[1]["hex"]) < d0, "sporeling closes in")

func test_player_attack_kills_enemy_and_loots() -> void:
	var s: MatchState = quiet("lfg:class/bram")
	var e: int = _spawn_adjacent(s, "lfg:enemy/sporeling")
	s.actors[e]["ai"]["state"] = "recovery"
	s.actors[e]["ai"]["t_rec"] = 1.0e9
	var kills: bool = false
	for i in range(8):
		var r: Dictionary = cmd(s, "attack", {"target": e})
		if not r["ok"]:
			eq(r["error"], "cooldown", "only cooldown blocks")
		elif count_type(r["events"], "actor_died") > 0:
			kills = true
			break
		tick_all(s, 1.0, 0.5)
	check(kills, "enemy killed")
	check(not s.actors[e]["alive"], "dead")
	eq(Inv.count(s.actors[1]["inv"], "lfg:item/mushroom"), 1, "looted mushroom")
	eq(cmd(s, "attack", {"target": e})["error"], "bad_target", "cannot hit corpse")

func test_attack_rules() -> void:
	var s: MatchState = quiet()
	var e: int = Setup.spawn_enemy(s, "lfg:enemy/sporeling", s.actors[1]["hex"] + Vector2i(3, 0), false)
	var before: String = snap(s)
	eq(cmd(s, "attack", {"target": e})["error"], "too_far", "range")
	eq(cmd(s, "attack", {"target": 1})["error"], "bad_target", "self")
	eq(cmd(s, "attack", {"target": "x"})["error"], "bad_target", "bad id")
	eq(snap(s), before, "unchanged")

func test_death_drops_carried_items_on_ground_and_pickup() -> void:
	var s: MatchState = quiet()
	var victim: Dictionary = s.actors[int(s.factions[1]["leader"])]
	victim["hex"] = s.actors[1]["hex"] + Vector2i(5, 0)
	victim["inv"] = {"lfg:item/coin": 9}
	var t0: Dictionary = Inv.world_totals(s)
	var ev: Array = []
	Combat.hurt(s, victim["id"], 9999, -1, ev, "t")
	eq(Inv.world_totals(s), t0, "death conserves carried items")
	check(s.drops.has(MatchState.plot_key(victim["hex"])), "items dropped on ground")
	s.actors[1]["hex"] = victim["hex"]
	check(cmd(s, "harvest", {"hex": victim["hex"]})["ok"], "pick up")
	eq(Inv.world_totals(s), t0, "pickup conserves")
	check(s.factions[1]["alive"] == false, "AI faction eliminated when its leader dies")

func test_wild_enemy_population_and_purge_wave_cleanup() -> void:
	var s: MatchState = mk("lfg:class/judd", 14, {"ai_enabled": false})
	var wild: int = 0
	for a in s.actors.values():
		if a["kind"] == "enemy":
			wild += 1
	eq(wild, 24, "24 wild enemies")
	s.actors[1]["max_hp"] = 99999
	s.actors[1]["hp"] = 99999
	home(s)["store"]["lfg:item/ration"] = 500
	var ev: Array = tick_all(s, 60.0 * 6.7, 5.0)
	eq(count_type(ev, "purge_wave"), 1, "wave spawned at purge")
	var waves: int = 0
	for a in s.actors.values():
		if a["kind"] == "enemy" and a.get("wave", false):
			waves += 1
	check(waves > 0, "wave enemies present during purge")
	tick_all(s, 60.0 * 1.2, 5.0)
	waves = 0
	for a in s.actors.values():
		if a["kind"] == "enemy" and a.get("wave", false):
			waves += 1
	eq(waves, 0, "wave cleaned up on resolution")
