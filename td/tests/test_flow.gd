extends SceneTree
# End-to-end flow with real saving (run with HOME set to a temp dir so user:// is clean):
# menu -> Level 1 setup -> begin -> story -> wave -> capture -> win -> result -> save/reload -> team screen.
var ok := 0
var bad := 0
func _check(c: bool, msg: String) -> void:
	if c:
		ok += 1
	else:
		bad += 1
		print("FAIL: " + msg)

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var S = load("res://session.gd")
	var C = load("res://creatures.gd")
	S.load_save()
	S.settings["tutorial_done"] = true
	var menu = load("res://menu.tscn").instantiate()
	root.add_child(menu)
	await process_frame
	menu._open_setup("mossgate")
	await process_frame
	_check(S.level_id == "mossgate", "setup selects level 1")
	menu._begin()
	for i in 6:
		await process_frame
	var main = current_scene
	_check(main != null and main.has_method("_start_wave"), "battle scene loaded")
	_check(main.story_screen != null and is_instance_valid(main.story_screen), "story shows on first visit")
	main.story_screen._close()
	await process_frame
	_check(S.settings.get("story_mossgate", false) == true, "story marked seen")
	_check(main.shop_ids == ["tickindle"], "only the starter is in the shop on a fresh save")
	# place a tower on a rune stone through the real placement path, then run a wave
	main._place(C.TOWERS["tickindle"], Vector2(460, 250))
	var coins0: int = main.coins
	Engine.time_scale = 6.0
	main._start_wave()
	var t := 0.0
	while t < 12.0 and main.get_tree().get_nodes_in_group("enemies").size() < 3:
		await process_frame
		t += 1.0 / 60.0 * 6.0
	_check(main.wave_running and main.get_tree().get_nodes_in_group("enemies").size() >= 1, "enemies spawn and walk")
	# weaken one and capture it
	var target = null
	for e in main.get_tree().get_nodes_in_group("enemies"):
		target = e
		break
	target.hp = target.max_hp * 0.1
	main._update_capturable()
	main.lures = 10
	main.rng.seed = 3
	Engine.time_scale = 8.0
	for i in 10:
		if is_instance_valid(target) and not target.dead:
			main._try_capture(target)
			await create_timer(2.2).timeout
	_check(S.unlocked.has("ally_shuckit") or S.unlocked.has("ally_glomm"), "captured creature unlocked")
	_check(main.shop_ids.size() >= 2, "captured creature appears in the shop")
	_check(S.goal_done("mossgate", "capture"), "capture goal completes on first capture")
	_check(S.goals_line("mossgate").contains("✔ Capture a Shuckit"), "goals line shows the completed goal")
	# finish the level: win, bank XP and gold
	Engine.time_scale = 1.0
	var gold0: int = S.gold
	main.run_xp["tickindle"] = 120
	main.wave = 10
	main.lives = 20
	main._end("won")
	_check(S.goal_done("mossgate", "win") and S.goal_done("mossgate", "gold15") and S.goal_done("mossgate", "perfect"), "win goals complete")
	await process_frame
	_check(main.result_screen != null and is_instance_valid(main.result_screen), "result screen shows")
	_check(S.gold > gold0, "gold earned")
	_check(S.level_of("tickindle") >= 3, "XP banked, creature levelled")
	_check(int(S.stars.get("mossgate", 0)) >= 1, "level 1 star saved")
	# reload from disk
	var stars_before: int = int(S.stars.get("mossgate", 0))
	var gold_saved: int = S.gold
	var unl: Dictionary = S.unlocked.duplicate()
	S._loaded = false
	S.stars = {}
	S.xp = {}
	S.unlocked = {}
	S.gold = 0
	S.settings = {"music": 0.8, "sfx": 0.9, "haptics": true, "shake": true, "tutorial_done": false}
	S.load_save()
	_check(S.settings.get("story_mossgate", false) == true, "story-seen flag persists across restart")
	_check(int(S.stars.get("mossgate", 0)) == stars_before and S.gold == gold_saved and S.unlocked.size() == unl.size() and S.level_of("tickindle") >= 3, "progress persists across restart")
	# team screen opens from the menu with the saved collection
	var m2 = load("res://menu.tscn").instantiate()
	root.add_child(m2)
	await process_frame
	m2._open_team()
	await process_frame
	_check(m2.team_screen != null and is_instance_valid(m2.team_screen), "team screen opens")
	_check(m2.team_screen.owned().size() >= 2, "team screen lists captured creatures")
	print("flow: %d/%d ok" % [ok, ok + bad])
	quit(0 if bad == 0 else 1)
