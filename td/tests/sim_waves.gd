extends SceneTree
# Headless balance smoke test. Usage: godot --headless --path td --fixed-fps 60 -s tests/sim_waves.gd -- tickindle:500,260 dugloom:420,420 ...
# Spec: id:x,y[:upgrades] e.g. tickindle:500,260:aab buys A,A,B free. Towers are placed free of charge; prints outcome. Exit code 0 if the run is won.
var main
var frames := 0
func _initialize() -> void:
	load("res://session.gd").no_save = true
	var args := OS.get_cmdline_user_args()
	for x in args:
		if x.begins_with("map=") or x.begins_with("level="):
			load("res://session.gd").level_id = x.get_slice("=", 1)
		if x.begins_with("diff="):
			load("res://session.gd").diff = x.substr(5)
		if x.begins_with("mut="):
			load("res://session.gd").muts = Array(x.substr(4).split(","))
		if x.begins_with("seed="):
			load("res://session.gd").run_seed = int(x.substr(5))
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var defs = load("res://creatures.gd").TOWERS
	for a in args:
		if "=" in a and not ":" in a:
			continue
		var parts: PackedStringArray = a.split(":")
		var xy: PackedStringArray = parts[1].split(",")
		var t = load("res://tower.gd").new()
		t.def = defs[parts[0]]
		t.position = Vector2(float(xy[0]), float(xy[1]))
		if parts.size() > 2:
			for ch in parts[2]:
				t.buy(ch)
		main.add_child(t)
func _process(_d: float) -> bool:
	frames += 1
	if main.state == "play" and not main.wave_running:
		main._start_wave()
	if main.state != "play" or frames > 60 * 600:
		print("state=", main.state, " wave=", main.wave, " lives=", main.lives, " sec=", frames / 60)
		quit(0 if main.state == "won" else 1)
	return false
