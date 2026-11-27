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
	print("capture: %d/%d ok" % [ok, ok + bad])
	quit(0 if bad == 0 else 1)
