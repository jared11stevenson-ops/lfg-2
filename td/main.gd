extends Node2D
# Pass 1 skeleton: one lane, place Tickindle, hold off 5 waves of Shuckits.
const Creatures = preload("res://creatures.gd")
const EnemyScript = preload("res://enemy.gd")
const TowerScript = preload("res://tower.gd")
const DrawUtil = preload("res://draw_util.gd")

var PATH := PackedVector2Array([
	Vector2(-40, 360), Vector2(300, 360), Vector2(300, 160), Vector2(700, 160),
	Vector2(700, 560), Vector2(1000, 560), Vector2(1000, 300), Vector2(1320, 300),
])
const PATH_HALF := 34.0
const TOTAL_WAVES := 5

var coins := 250
var lives := 20
var wave := 0
var to_spawn := 0
var spawn_cd := 0.0
var wave_running := false
var state := "play"
var hud: Label
var start_btn: Button
var banner: Label

func _ready() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = Label.new()
	hud.position = Vector2(16, 10)
	hud.add_theme_font_size_override("font_size", 26)
	hud.add_theme_color_override("font_outline_color", Color.BLACK)
	hud.add_theme_constant_override("outline_size", 6)
	layer.add_child(hud)
	start_btn = Button.new()
	start_btn.text = "Start wave"
	start_btn.position = Vector2(1060, 636)
	start_btn.size = Vector2(200, 64)
	start_btn.add_theme_font_size_override("font_size", 24)
	start_btn.pressed.connect(_start_wave)
	layer.add_child(start_btn)
	banner = Label.new()
	banner.position = Vector2(340, 300)
	banner.add_theme_font_size_override("font_size", 48)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 10)
	banner.visible = false
	layer.add_child(banner)
	_refresh()

func _refresh() -> void:
	hud.text = "Coins %d    Lives %d    Wave %d/%d\nTap grass: place Tickindle (%d)" % [coins, lives, wave, TOTAL_WAVES, Creatures.DEFS.tickindle.cost]

func _start_wave() -> void:
	if wave_running or state != "play":
		return
	wave += 1
	to_spawn = 6 + wave * 3
	spawn_cd = 0.0
	wave_running = true
	start_btn.disabled = true
	_refresh()

func _process(delta: float) -> void:
	if state == "play" and wave_running:
		spawn_cd -= delta
		if to_spawn > 0 and spawn_cd <= 0.0:
			_spawn()
			to_spawn -= 1
			spawn_cd = 1.1
		elif to_spawn == 0 and get_tree().get_nodes_in_group("enemies").is_empty():
			_wave_done()
	queue_redraw()

func _spawn() -> void:
	var d: Dictionary = Creatures.DEFS.shuckit
	var e = EnemyScript.new()
	e.setup(PATH, float(d.hp) + 3.0 * wave, float(d.speed), d.types, int(d.reward))
	e.died.connect(_on_died)
	e.leaked.connect(_on_leaked)
	add_child(e)

func _on_died(e) -> void:
	coins += e.reward
	# Gale hook: a fallen Shuckit whips nearby wave-mates into a speed burst (punishes single-target-only builds).
	for o in get_tree().get_nodes_in_group("enemies"):
		if o != e and not o.dead and o.position.distance_to(e.position) < 170.0:
			o.boost(1.5)
	_refresh()

func _on_leaked(_e) -> void:
	lives -= 1
	_refresh()
	if lives <= 0:
		_end("lost")

func _wave_done() -> void:
	wave_running = false
	coins += 50
	_refresh()
	if wave >= TOTAL_WAVES:
		_end("won")
	else:
		start_btn.disabled = false

func _end(result: String) -> void:
	state = result
	banner.text = "The Well holds!\nTap to restart" if result == "won" else "The Well is lost...\nTap to restart"
	banner.visible = true
	start_btn.disabled = true

func _dist_to_path(p: Vector2) -> float:
	var best := INF
	for i in PATH.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, PATH[i], PATH[i + 1])))
	return best

func _valid_spot(p: Vector2) -> bool:
	if p.x < 30 or p.x > 1250 or p.y < 70 or p.y > 690:
		return false
	if _dist_to_path(p) < PATH_HALF + 30.0:
		return false
	for n in get_children():
		if n.get_script() == TowerScript and n.position.distance_to(p) < 60.0:
			return false
	return true

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if state != "play":
			get_tree().reload_current_scene()
			return
		var d: Dictionary = Creatures.DEFS.tickindle
		var p := get_global_mouse_position()
		if coins >= int(d.cost) and _valid_spot(p):
			coins -= int(d.cost)
			var t = TowerScript.new()
			t.def = d
			t.position = p
			add_child(t)
			_refresh()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("5fae4f"))
	for i in 40:
		var h := hash(i * 7919)
		draw_circle(Vector2(h % 1280, (h / 1280) % 720), 40 + h % 50, Color(0.4, 0.68, 0.32, 0.35))
	for i in PATH.size() - 1:
		draw_line(PATH[i], PATH[i + 1], Color("6b4a2a"), PATH_HALF * 2 + 8)
	for p in PATH:
		draw_circle(p, PATH_HALF + 4, Color("6b4a2a"))
	for i in PATH.size() - 1:
		draw_line(PATH[i], PATH[i + 1], Color("d1a56a"), PATH_HALF * 2 - 4)
	for p in PATH:
		draw_circle(p, PATH_HALF - 2, Color("d1a56a"))
	if state == "play":
		var m := get_global_mouse_position()
		var d: Dictionary = Creatures.DEFS.tickindle
		var ok := coins >= int(d.cost) and _valid_spot(m)
		var tint := Color(1, 1, 1, 0.45) if ok else Color(1, 0.2, 0.2, 0.45)
		draw_arc(m, float(d.range), 0, TAU, 64, tint, 2.0, true)
		draw_circle(m, 26, tint)
