extends SceneTree
## Renders real screenshots of the presentation layer. Needs a display (e.g. xvfb) - NOT headless:
##   xvfb-run -a godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tools/art_capture.gd -- out=art/captures
## Software GL gives images for evidence only; frame timings from it are not a performance benchmark.
var demo: Node
var stage: WorldStage
var out_dir: String = "res://art/captures"

func _init() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("out="):
			out_dir = a.substr(4)
	_run()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await _frames(6)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	var path: String = out_dir.path_join(name + ".png")
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	var err: int = img.save_png(ProjectSettings.globalize_path(path))
	print("SHOT %s %dx%d err=%d" % [path, img.get_width(), img.get_height(), err])

func _find_hex(biome: int, near: Vector2i) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := 99999
	for r in HexMath.ROWS:
		for c in HexMath.COLS:
			var h := Vector2i(c, r)
			if stage.world.biome_hex(h) != biome or stage.world.holding_at(h) >= 0:
				continue
			var cen: Vector2 = HexMath.offset_center(c, r)
			if not stage.world.walkable(cen.x, cen.y):
				continue
			var d: int = HexMath.distance(h, near)
			if d < bd:
				bd = d
				best = h
	return best

func _tp(h: Vector2i, reveal: int = 5) -> void:
	var cen: Vector2 = HexMath.offset_center(h.x, h.y)
	stage.player.place_on_ground(cen)
	stage.fog.reveal(h, reveal)
	stage.cam.snap()

func _run() -> void:
	var scene: PackedScene = load("res://world/world_demo.tscn")
	demo = scene.instantiate()
	root.add_child(demo)
	await _frames(2)
	while demo.stage == null or not demo.stage.started:
		await process_frame
	stage = demo.stage
	var home: Vector2i = stage.world.start_hex
	demo.auto_clock = false
	stage.set_hud_model({"time_of_day": 0.45, "day": 3, "phase": &"PEACE"})
	stage.atmosphere.set_phase(&"PEACE", true)
	await _frames(3)
	print("STATS ", stage.view.stats)
	# 1 homestead hero with plots + houses, fog edge visible
	stage.cam.yaw = 0.5
	stage.cam.snap()
	await _shot("01_homestead_peace")
	# 2 fungal grove
	var fg: Vector2i = _find_hex(Biomes.B.FUNGAL, home)
	if fg.x >= 0:
		_tp(fg, 6)
		stage.cam.yaw = -0.4
		await _shot("02_fungal_grove")
	# 3 ruins / reeds
	var ru: Vector2i = _find_hex(Biomes.B.RUINS, home)
	if ru.x >= 0:
		_tp(ru, 6)
		await _shot("03_ruins")
	var bg: Vector2i = _find_hex(Biomes.B.BOG, home)
	if bg.x >= 0:
		_tp(bg, 6)
		await _shot("04_bog_reeds")
	var sh: Vector2i = _find_hex(Biomes.B.SHORE, home)
	if sh.x >= 0:
		_tp(sh, 6)
		await _shot("05_shore")
	# 6 overview of whole world with fog lifted, high camera
	_tp(home, 4)
	stage.fog.set_reveal_all(true)
	stage.cam.distance = 46.0
	stage.cam.pitch_deg = 38.0
	stage.cam.max_distance = 200.0
	stage.cam.distance = 130.0
	stage.cam.pitch_deg = 33.0
	stage.cam.snap()
	await _shot("06_overview_diorama")
	stage.fog.set_reveal_all(false)
	stage.cam.distance = 46.0
	stage.cam.pitch_deg = 52.0
	# 7 purge look
	stage.set_phase(&"PURGE_ACTIVE", true)
	stage.set_hud_model({"day": 7, "time_of_day": 0.82})
	await _frames(4)
	stage.cam.yaw = 0.5
	_tp(home, 5)
	await _shot("07_purge_active")
	stage.set_phase(&"WARNING", true)
	stage.set_hud_model({"day": 6, "time_of_day": 0.7})
	await _shot("08_warning")
	stage.set_phase(&"PEACE", true)
	stage.set_hud_model({"day": 2, "time_of_day": 0.4})
	# 9 farm plots closeup + prompt + build preview invalid/valid
	var fp: Vector2 = stage.farm.slot_position(home, 3)
	stage.player.place_on_ground(fp + Vector2(0, 3.0))
	stage.cam.distance = 28.0
	stage.cam.pitch_deg = 48.0
	stage.cam.yaw = 0.35
	stage.cam.snap()
	await _frames(6)
	await _shot("09_farm_plots")
	# 10 build preview valid then invalid
	stage.player.rotation.y = 0.0
	stage.cam.distance = 42.0
	var vh := Vector2i(-1, -1)
	var ih := Vector2i(-1, -1)
	for n in HexMath.neighbors(home):
		if stage.world.can_build(n) and vh.x < 0:
			vh = n
	for r in range(home.y - 8, home.y + 8):
		for c in range(home.x - 8, home.x + 8):
			if stage.world.biome_hex(Vector2i(c, r)) == Biomes.B.WATER and ih.x < 0:
				ih = Vector2i(c, r)
	var pv: Vector2 = HexMath.offset_center(vh.x, vh.y)
	stage.player.place_on_ground(pv + Vector2(0, 14.0))
	stage.cam.snap()
	stage.preview.show_at(vh)
	await _shot("10_build_preview_valid")
	stage.preview.hide_preview()
	stage.preview.show_at(home)
	await _shot("11_build_preview_invalid")
	stage.preview.hide_preview()
	# 12 telegraphs
	stage.set_phase(&"PURGE_ACTIVE", true)
	_tp(home, 5)
	stage.cam.distance = 46.0
	stage.cam.yaw = 0.0
	stage.cam.snap()
	demo.demo_telegraph()
	await _frames(70)
	await _shot("12_enemy_telegraphs")
	stage.set_phase(&"PEACE", true)
	await _frames(2)
	# 13 strategic map (with partial exploration)
	for h in [Vector2i(30, 20), Vector2i(20, 30), Vector2i(55, 15), Vector2i(60, 35)]:
		if stage.world.biome_hex(h) != Biomes.B.WATER:
			stage.fog.reveal(h, 6)
	_tp(home, 5)
	stage.toggle_map()
	await _shot("13_strategic_map")
	stage.toggle_map()
	# 14 3D hex grid overlay + bag
	stage.toggle_grid()
	stage.hud.set_bag_open(true)
	stage.cam.distance = 50.0
	stage.cam.snap()
	await _shot("14_hex_grid_and_bag")
	stage.hud.set_bag_open(false)
	stage.toggle_grid()
	# 15 phone-landscape aspect
	root.size = Vector2i(1440, 640)
	await _frames(3)
	stage.cam.distance = 40.0
	stage.cam.snap()
	await _shot("15_phone_landscape_2.25to1")
	quit()
