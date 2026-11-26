extends SceneTree
# Bakes every puppet to PNG frames. xvfb-run godot --path td --rendering-driver opengl3 -s tools/bake_puppets.gd -- [id[:variant] ...]
const Puppets = preload("res://art/puppets.gd")
const FRAMES := {"idle": 6, "walk": 8, "attack": 5}
const OUTSIZE := 192
const SS := 2
const BASE := ["tickindle", "dugloom", "hutzin", "shuckit", "zapnose", "glomm", "hoardillo", "mirewick", "gloamoth", "bogbard", "quillwyrm", "drumbeak", "pyrelope", "mudskip", "thornarok", "ptarmitten", "tentbat", "dumbomaton", "colukite", "gilamancer"]
var IDS: Array = BASE.duplicate()

func _initialize() -> void:
	_run()

func _run() -> void:
	var args := OS.get_cmdline_user_args()
	var ids: Array = []
	if args.size() == 1 and args[0] == "all":
		ids = BASE.duplicate()
		for b in BASE:
			ids.append(b + ":a")
			ids.append(b + ":b")
	elif args.size() > 0:
		ids = Array(args)
	else:
		ids = BASE.duplicate()
	var vp := SubViewport.new()
	vp.size = Vector2i(OUTSIZE * SS, OUTSIZE * SS)
	vp.transparent_bg = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var canvas = load("res://tools/puppet_canvas.gd").new()
	canvas.position = Vector2(105, 173) * SS
	canvas.scale = Vector2(SS, SS)
	vp.add_child(canvas)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://art/puppets"))
	var cols := 8
	var sheet_rows := 0
	for x in ids:
		if not ":" in String(x):
			sheet_rows += 1
	var sheet := Image.create(OUTSIZE * cols, OUTSIZE * maxi(1, sheet_rows), false, Image.FORMAT_RGBA8)
	var sheet_row := -1
	sheet.fill(Color("3a2a5a"))
	var sheet_pick := [["idle", 0], ["idle", 3], ["walk", 0], ["walk", 2], ["walk", 4], ["walk", 6], ["attack", 1], ["attack", 3]]
	for row in ids.size():
		var parts: PackedStringArray = String(ids[row]).split(":")
		var variant := parts[1] if parts.size() > 1 else ""
		canvas.parts = Puppets.build(parts[0], variant)
		var fname := String(ids[row]).replace(":", "_")
		if variant == "":
			sheet_row += 1
		for state in FRAMES:
			if variant != "" and state == "walk":
				continue
			for i in FRAMES[state]:
				canvas.state = state
				canvas.t = float(i) / FRAMES[state]
				canvas.queue_redraw()
				await process_frame
				await process_frame
				await RenderingServer.frame_post_draw
				var img := vp.get_texture().get_image()
				img.convert(Image.FORMAT_RGBA8)
				img.resize(OUTSIZE, OUTSIZE, Image.INTERPOLATE_LANCZOS)
				img.save_png("res://art/puppets/%s_%s_%d.png" % [fname, state, i])
				for c in sheet_pick.size():
					if variant == "" and sheet_pick[c][0] == state and sheet_pick[c][1] == i:
						sheet.blend_rect(img, Rect2i(0, 0, OUTSIZE, OUTSIZE), Vector2i(c * OUTSIZE, sheet_row * OUTSIZE))
	sheet.save_png("res://art/puppet_sheet.png")
	print("baked ", ids)
	quit(0)
