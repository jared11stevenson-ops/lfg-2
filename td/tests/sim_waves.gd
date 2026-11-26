extends SceneTree
# Headless balance smoke test. Usage: godot --headless --path td --fixed-fps 60 -s tests/sim_waves.gd -- tickindle:500,260 dugloom:420,420 ...
# Towers are placed free of charge; prints outcome. Exit code 0 if the run is won.
var main
var frames := 0
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	var defs = load("res://creatures.gd").DEFS
	for a in OS.get_cmdline_user_args():
		var parts: PackedStringArray = a.split(":")
		var xy: PackedStringArray = parts[1].split(",")
		var t = load("res://tower.gd").new()
		t.def = defs[parts[0]]
		t.position = Vector2(float(xy[0]), float(xy[1]))
		main.add_child(t)
func _process(_d: float) -> bool:
	frames += 1
	if main.state == "play" and not main.wave_running:
		main._start_wave()
	if main.state != "play" or frames > 60 * 600:
		print("state=", main.state, " wave=", main.wave, " lives=", main.lives, " sec=", frames / 60)
		quit(0 if main.state == "won" else 1)
	return false
