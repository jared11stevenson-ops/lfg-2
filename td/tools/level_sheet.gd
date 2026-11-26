extends SceneTree
# Renders every level backdrop into one contact sheet. xvfb-run godot --path td --rendering-driver opengl3 -s tools/level_sheet.gd -- /abs/out.png
const Levels = preload("res://levels.gd")
const Backdrop = preload("res://backdrop.gd")

func _initialize() -> void:
	_run()

func _run() -> void:
	var out := OS.get_cmdline_user_args()[0]
	var sheet := Image.create(1280, 1800, false, Image.FORMAT_RGBA8)
	for i in Levels.ORDER.size():
		var vp: SubViewport = Backdrop.make(root, Levels.LEVELS[Levels.ORDER[i]])
		await process_frame
		await process_frame
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.convert(Image.FORMAT_RGBA8)
		img.resize(640, 360, Image.INTERPOLATE_BILINEAR)
		sheet.blit_rect(img, Rect2i(0, 0, 640, 360), Vector2i((i % 2) * 640, (i / 2) * 360))
		vp.queue_free()
	sheet.save_png(out)
	print("saved ", out)
	quit(0)
