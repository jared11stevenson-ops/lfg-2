extends SceneTree
# Visual capture (needs a display, e.g. xvfb-run). Usage: ... -s tests/shot.gd -- out.png frame tickindle:500,260 ...
var main
var frames := 0
var out := "shot.png"
var at := 900
var sel_spec := ""
var first_tower
func _has_prefix(a: PackedStringArray, pre: String) -> bool:
	for x in a:
		if x.begins_with(pre):
			return true
	return false

func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	at = int(a[1])
	for x in a:
		if x.begins_with("map=") or x.begins_with("level="):
			load("res://session.gd").level_id = x.get_slice("=", 1)
	load("res://session.gd").no_save = true
	main = load("res://scene.tscn".replace("scene", "menu" if ("menu" in a or "bestiary" in a or _has_prefix(a, "setup=")) else "main")).instantiate()
	root.add_child(main)
	var defs = load("res://creatures.gd").TOWERS
	for i in range(2, a.size()):
		if a[i].begins_with("setup="):
			main.call_deferred("_open_setup", a[i].substr(6))
			continue
		if a[i] == "pause":
			main.call_deferred("_toggle_pause")
			continue
		if a[i].begins_with("ghost="):
			var gp := a[i].substr(6).split(",")
			main.pending = Vector2(float(gp[0]), float(gp[1]))
			main.has_pending = true
			continue
		if a[i] == "bestiary":
			main.mode = "bestiary"
			continue
		if a[i] == "menu" or a[i].begins_with("map=") or a[i].begins_with("level="):
			continue
		if a[i].begins_with("select="):
			sel_spec = a[i].substr(7)
			continue
		if a[i].begins_with("wave="):
			main.wave = int(a[i].substr(5)) - 1
			continue
		var parts: PackedStringArray = a[i].split(":")
		var xy: PackedStringArray = parts[1].split(",")
		var t = load("res://tower.gd").new()
		t.def = defs[parts[0]]
		t.position = Vector2(float(xy[0]), float(xy[1]))
		if parts.size() > 2:
			for ch in parts[2]:
				t.buy(ch)
		main.add_child(t)
		if first_tower == null:
			first_tower = t
func _process(_d: float) -> bool:
	frames += 1
	if frames == 5 and sel_spec != "":
		main._select_tower(first_tower)
	if not ("state" in main):
		pass
	elif main.state == "play" and not main.wave_running and main.wave < 8:
		main._start_wave()
	if frames == at:
		root.get_texture().get_image().save_png(out)
		print("saved ", out)
		quit(0)
	return false
