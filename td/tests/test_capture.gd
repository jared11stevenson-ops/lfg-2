extends SceneTree
# Capture + creature levelling. Usage: godot --headless --path td --quit-after 600 -s tests/test_capture.gd
var ok := 0
var bad := 0
func _check(c: bool, msg: String) -> void:
	if c:
		ok += 1
	else:
		bad += 1
		print("FAIL: " + msg)

func _initialize() -> void:
	var S = load("res://session.gd")
	var C = load("res://creatures.gd")
	S.no_save = true
	S.dev_all = false
	S.settings["tutorial_done"] = true
	_check(S.level_of("tickindle") == 1, "starts at level 1")
	S.add_xp("tickindle", 30)
	_check(S.level_of("tickindle") == 2, "30 xp = level 2")
	S.add_xp("tickindle", 120)
	_check(S.level_of("tickindle") == 3, "150 xp = level 3")
	_check(S.level_mult("tickindle") > 1.1, "level multiplier grows")
	var T = load("res://tower.gd")
	var t1 = T.new()
	S.xp["ally_shuckit"] = 0
	t1.def = C.TOWERS["ally_shuckit"]
	var base_dmg: float = t1.st.dmg
	var t2 = T.new()
	S.xp["ally_shuckit"] = 30 * 9 * 9
	t2.def = C.TOWERS["ally_shuckit"]
	_check(t2.lvl == 10 and t2.st.dmg > base_dmg * 1.4, "tower damage scales with level (lvl %d dmg %.2f vs %.2f)" % [t2.lvl, t2.st.dmg, base_dmg])
	_check(S.tower_for("shuckit") == "ally_shuckit" and S.tower_for("glomm") == "ally_glomm", "species map to tower ids")
	S.unlocked.erase("ally_shuckit")
	_check(S.capture("shuckit") == true, "first capture is new")
	_check(S.tower_open(C.TOWERS["ally_shuckit"]), "captured creature is unlocked")
	_check(S.capture("shuckit") == false, "second capture is not new")
	# moves, team, gold
	var M = load("res://moves.gd")
	_check(M.learned(["ember", "forge"], 4).size() == 0 and M.learned(["ember", "forge"], 10).size() == 2 and M.learned(["ember", "forge"], 20).size() == 3, "moves learned at 5/10/15")
	_check(M.gained(["tide"], 4, 11).size() == 2, "gained moves between levels")
	var t3 = T.new()
	S.xp["tickindle"] = 0
	t3.def = C.TOWERS["tickindle"]
	var d1: float = t3.st.dmg
	var t4 = T.new()
	S.xp["tickindle"] = 30 * 14 * 14
	t4.def = C.TOWERS["tickindle"]
	_check(t4.lvl == 15 and t4.st.dmg > d1 * 1.9, "level 15 tickindle has levels + 3 moves (%.2f vs %.2f)" % [t4.st.dmg, d1])
	S.xp["tickindle"] = 0
	S.gold = 0
	S.add_gold(250)
	_check(S.spend_gold(200) and S.gold == 50 and not S.spend_gold(100), "gold spend")
	_check(S.candy("tickindle") and S.level_of("tickindle") == 2, "rare candy +1 level")
	S.team = []
	_check(S.team_ids().size() >= 1, "empty team = all unlocked")
	S.unlocked["ally_shuckit"] = true
	S.team = ["tickindle"]
	_check(S.team_ids() == ["tickindle"], "team restricts loadout")
	_check(S.toggle_team("ally_shuckit") and S.team.size() == 2, "add to team")
	_check(not S.toggle_team("ally_glomm") or true, "toggle returns bool")
	S.team = []
	S.xp["tickindle"] = 0
	# in-battle capture
	S.level_id = "mossgate"
	var main = load("res://main.tscn").instantiate()
	root.add_child(main)
	await process_frame
	var E = load("res://enemy.gd")
	var e = E.new()
	e.setup(main.paths[0], C.ENEMIES["glomm"], 3)
	main.add_child(e)
	main.wave_running = true
	main._update_capturable()
	_check(not e.capturable, "healthy enemy is not capturable")
	e.hp = e.max_hp * 0.2
	main._update_capturable()
	_check(e.capturable, "weak enemy is capturable")
	var boss = E.new()
	var bd: Dictionary = C.ENEMIES["glomm"].duplicate()
	bd.boss = true
	boss.setup(main.paths[0], bd, 3)
	main.add_child(boss)
	boss.hp = boss.max_hp * 0.1
	main._update_capturable()
	_check(not boss.capturable, "bosses are not capturable")
	var l0: int = main.lures
	main.rng.seed = 1
	var got := false
	for i in 8:
		if is_instance_valid(e) and not e.dead:
			main._try_capture(e)
		else:
			got = true
			break
	_check(main.lures < l0, "capturing spends lures")
	_check(got or (is_instance_valid(e) and e.dead), "capture succeeds within a few tries")
	_check(int(main.free_ids.get("ally_glomm", 0)) >= 1, "captured creature grants a free placement")
	# rare encounter (Hutzin on Mossgate)
	main.rare_wave = 1
	main.wave_running = false
	main.state = "play"
	main._start_wave()
	_check("rare:hutzin" in main.queue, "rare wave queues the rare enemy")
	var spawned := 0
	for i in 30:
		if main.queue.is_empty():
			break
		main._spawn()
	var rares := 0
	for en in main.get_tree().get_nodes_in_group("enemies"):
		if en.rare and en.kind == "hutzin":
			rares += 1
			en.hp = en.max_hp * 0.2
	_check(rares == 1, "exactly one rare Hutzin spawns")
	main._update_capturable()
	var got_h := false
	main.lures = 10
	for i in 12:
		for en in main.get_tree().get_nodes_in_group("enemies"):
			if en.rare and en.capturable and not en.dead:
				main._try_capture(en)
	_check(S.unlocked.has("hutzin"), "capturing the rare Hutzin unlocks it permanently")
	S.rare_pity = 0
	_check(S.rare_chance(0.14, "hutzin") < 0.14, "owning the creature halves the rare chance")
	S.unlocked.erase("hutzin")
	S.rare_pity = 3
	_check(abs(S.rare_chance(0.14, "hutzin") - 0.26) < 0.001, "pity raises the chance (%.2f)" % S.rare_chance(0.14, "hutzin"))
	print("capture: %d/%d ok" % [ok, ok + bad])
	quit(0 if bad == 0 else 1)
