extends SceneTree
# Headless balance smoke test: 2 towers beside the lane, auto-start each wave.
var main
var frames := 0
func _initialize() -> void:
	main = load("res://main.tscn").instantiate()
	root.add_child(main)
	for pos in [Vector2(500, 260), Vector2(850, 420)]:
		var t = load("res://tower.gd").new()
		t.def = load("res://creatures.gd").DEFS.tickindle
		t.position = pos
		main.add_child(t)
func _process(_d: float) -> bool:
	frames += 1
	if main.state == "play" and not main.wave_running:
		main._start_wave()
	if main.state != "play" or frames > 60 * 400:
		print("state=", main.state, " wave=", main.wave, " lives=", main.lives, " coins=", main.coins, " sec=", frames / 60)
		quit(0 if main.state == "won" else 1)
	return false
