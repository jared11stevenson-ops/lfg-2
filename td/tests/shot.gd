extends SceneTree
# Visual capture (needs a display, e.g. xvfb-run). Usage: ... -s tests/shot.gd -- out.png frame tickindle:500,260 ...
var main
var frames := 0
var out := "shot.png"
var at := 900
var sel_spec := ""
var first_tower
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	at = int(a[1])
	for x in a:
		if x.begins_with("map="):
			load("res://session.gd").map_id = x.substr(4)
	main = load("res://scene.tscn".replace("scene", "menu" if "menu" in a else "main")).instantiate()
	root.add_child(main)
	var defs = load("res://creatures.gd").DEFS
	for i in range(2, a.size()):
		if a[i] == "menu" or a[i].begins_with("map="):
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
