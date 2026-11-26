extends SceneTree
# Renders every creature model to 8 facing directions. Needs a display: xvfb-run godot --path td --rendering-driver opengl3 -s tools/render_sprites.gd -- [ids...]
const Models = preload("res://art/creature_models.gd")
const SpriteLib = preload("res://sprite_lib.gd")
const SIZE := 256
const IDS := ["tickindle", "dugloom", "hutzin", "shuckit", "zapnose", "glomm"]

func _initialize() -> void:
	_run()

func _run() -> void:
	var ids: Array = OS.get_cmdline_user_args() if OS.get_cmdline_user_args().size() > 0 else IDS
	var vp := SubViewport.new()
	vp.size = Vector2i(SIZE, SIZE)
	vp.transparent_bg = true
	vp.msaa_3d = Viewport.MSAA_DISABLED
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.6, 0.64, 0.8)
	env.ambient_light_energy = 0.45
	var we := WorldEnvironment.new()
	we.environment = env
	vp.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, -35, 0)
	sun.light_energy = 0.88
	sun.light_color = Color(1.0, 0.96, 0.88)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 4.0
	vp.add_child(cam)
	cam.look_at_from_position(Vector3(0, 3.8, 4.2), Vector3(0, 0.95, 0))
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/sprites"))
	var sheet := Image.create(SIZE * 8, SIZE * ids.size(), false, Image.FORMAT_RGBA8)
	sheet.fill(Color(0.36, 0.68, 0.31))
	for row in ids.size():
		cam.size = float(SpriteLib.CAM[ids[row]])
		var model: Node3D = Models.build(ids[row])
		vp.add_child(model)
		for k in 8:
			var theta := k * PI / 4.0
			model.rotation.y = PI / 2.0 - theta
			print("frame ", ids[row], " ", k)
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			var img := vp.get_texture().get_image()
			img.convert(Image.FORMAT_RGBA8)
			img.save_png("res://art/sprites/%s_%d.png" % [ids[row], k])
			sheet.blend_rect(img, Rect2i(0, 0, SIZE, SIZE), Vector2i(k * SIZE, row * SIZE))
		model.queue_free()
	sheet.save_png("res://art/contact.png")
	print("rendered ", ids)
	quit(0)
