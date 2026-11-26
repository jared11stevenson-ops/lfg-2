extends SceneTree
# Visual capture (needs a display, e.g. xvfb-run). Usage: ... -s tests/shot.gd -- out.png frame tickindle:500,260 ...
var main
var frames := 0
var out := "shot.png"
var at := 900
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	out = a[0]
	at = int(a[1])
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var defs = load("res://creatures.gd").DEFS
	for i in range(2, a.size()):
		var parts: PackedStringArray = a[i].split(":")
		var xy: PackedStringArray = parts[1].split(",")
		var t = load("res://tower.gd").new()
		t.def = defs[parts[0]]
		t.position = Vector2(float(xy[0]), float(xy[1]))
		main.add_child(t)
func _process(_d: float) -> bool:
	frames += 1
	if main.state == "play" and not main.wave_running and main.wave < 5:
		main._start_wave()
	if frames == at:
		root.get_texture().get_image().save_png(out)
		print("saved ", out, " wave=", main.wave)
		quit(0)
	return false
