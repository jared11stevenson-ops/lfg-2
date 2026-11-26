extends Node2D
# Battle scene: lane, waves, shop cards, tap-to-select upgrade panel, speed control.
const Creatures = preload("res://creatures.gd")
const EnemyScript = preload("res://enemy.gd")
const TowerScript = preload("res://tower.gd")
const DrawUtil = preload("res://draw_util.gd")
const UiStyle = preload("res://ui_style.gd")
const PanelScript = preload("res://upgrade_panel.gd")
const PoofScript = preload("res://poof.gd")
const FxScript = preload("res://fx.gd")
const POOF_COL := {"shuckit": Color("8a89c0"), "zapnose": Color("ffd23a"), "glomm": Color("bfe6ff")}

var PATH := PackedVector2Array([
	Vector2(-40, 360), Vector2(300, 360), Vector2(300, 160), Vector2(700, 160),
	Vector2(700, 560), Vector2(1000, 560), Vector2(1000, 300), Vector2(1320, 300),
])
const PATH_HALF := 34.0
const TOTAL_WAVES := 8

var coins := 220
var lives := 20
var wave := 0
var to_spawn := 0
var spawn_cd := 0.0
var wave_running := false
var state := "play"
var hud: Label
var start_btn: Button
var speed_btn: Button
var banner: Label
var selected := "tickindle"
var placing := true
var cards := {}
var queue: Array = []
var decor: Array = []
var sel_tower = null
var panel
var shake := 0.0

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
	speed_btn = Button.new()
	speed_btn.position = Vector2(1100, 10)
	speed_btn.size = Vector2(160, 48)
	speed_btn.add_theme_font_size_override("font_size", 22)
	speed_btn.pressed.connect(_cycle_speed)
	layer.add_child(speed_btn)
	banner = Label.new()
	banner.position = Vector2(340, 300)
	banner.add_theme_font_size_override("font_size", 48)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 10)
	banner.visible = false
	layer.add_child(banner)
	for i in ["tickindle", "dugloom", "hutzin"]:
		var d: Dictionary = Creatures.DEFS[i]
		var b := Button.new()
		b.toggle_mode = true
		b.text = "%s\n%s\n%d" % [d.name, " / ".join(d.types.map(func(t): return t.capitalize())), d.cost]
		b.position = Vector2(16 + cards.size() * 150, 616)
		b.size = Vector2(140, 90)
		b.add_theme_font_size_override("font_size", 18)
		b.alignment = HORIZONTAL_ALIGNMENT_RIGHT
		b.toggled.connect(func(on): _on_card(i, on))
		layer.add_child(b)
		cards[i] = b
		UiStyle.style_btn(b, Color("2f6b3a"), Color("f0b43c"))
	UiStyle.style_btn(start_btn, Color("c4552b"), Color("c4552b"))
	UiStyle.style_btn(speed_btn, Color("3a4a6b"), Color("3a4a6b"))
	panel = PanelScript.new()
	panel.upgrade.connect(_on_upgrade)
	panel.sell.connect(_on_sell)
	panel.cycle_target.connect(func(): panel.refresh(coins))
	layer.add_child(panel)
	panel.position = Vector2(16, 90)
	_sync_cards()
	_build_decor()
	_refresh()

func _on_card(id: String, on: bool) -> void:
	if on:
		selected = id
		placing = true
		_deselect_tower()
	else:
		placing = false
	_sync_cards()

func _sync_cards() -> void:
	for k in cards:
		cards[k].set_pressed_no_signal(placing and k == selected)

func _cycle_speed() -> void:
	Engine.time_scale = 2.0 if Engine.time_scale < 1.5 else (3.0 if Engine.time_scale < 2.5 else 1.0)
	_refresh()

func _build_decor() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	for i in 160:
		var p := Vector2(rng.randf_range(20, 1260), rng.randf_range(20, 700))
		var kind := rng.randi() % 4
		if _dist_to_path(p) < 62.0 or (p.y > 596 and p.x < 500) or (p.y < 100 and p.x < 560) or (p.y > 620 and p.x > 1040):
			continue
		decor.append([p, kind, rng.randf_range(0.8, 1.2)])
	decor.sort_custom(func(a, b): return a[0].y < b[0].y)

func _refresh() -> void:
	speed_btn.text = "Speed x%d" % int(Engine.time_scale)
	hud.text = "Coins %d    Lives %d    Wave %d/%d\n%s" % [coins, lives, wave, TOTAL_WAVES,
		("Next: " + _incoming_text(wave + 1)) if (not wave_running and wave < TOTAL_WAVES) else "Tap a creature to upgrade it"]
	if sel_tower != null and is_instance_valid(sel_tower):
		panel.refresh(coins)

func _build_wave(w: int) -> Array:
	var q: Array = []
	for i in 6 + 3 * w:
		q.append("shuckit")
	if w >= 2:
		for i in (w - 1) * 2:
			q.append("zapnose")
	if w >= 3:
		for i in w - 2:
			q.append("glomm")
	seed(1000 + w)
	q.shuffle()
	return q

func _incoming_text(w: int) -> String:
	var counts := {}
	for k in _build_wave(w):
		counts[k] = counts.get(k, 0) + 1
	var parts := []
	for k in counts:
		parts.append("%d %s" % [counts[k], Creatures.DEFS[k].name])
	return ", ".join(parts)

func _start_wave() -> void:
	if wave_running or state != "play":
		return
	wave += 1
	queue = _build_wave(wave)
	to_spawn = queue.size()
	spawn_cd = 0.0
	wave_running = true
	start_btn.disabled = true
	_refresh()

func _process(delta: float) -> void:
	shake = maxf(0.0, shake - delta * 2.5)
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 9.0
	if state == "play" and wave_running:
		spawn_cd -= delta
		if to_spawn > 0 and spawn_cd <= 0.0:
			_spawn()
			to_spawn -= 1
			spawn_cd = maxf(0.45, 1.1 - 0.05 * wave)
		elif to_spawn == 0 and get_tree().get_nodes_in_group("enemies").is_empty():
			_wave_done()
	queue_redraw()

func _spawn() -> void:
	var d: Dictionary = Creatures.DEFS[queue.pop_front()]
	var e = EnemyScript.new()
	e.setup(PATH, d, wave)
	e.died.connect(_on_died)
	e.leaked.connect(_on_leaked)
	add_child(e)

func _on_died(e) -> void:
	coins += e.reward
	var pf = PoofScript.new()
	pf.col = POOF_COL.get(e.kind, Color.WHITE)
	pf.position = e.position
	add_child(pf)
	FxScript.text_at(self, e.position + Vector2(0, -20), "+%d" % e.reward, Color("ffd23a"))
	# Gale hook: a fallen Shuckit whips nearby wave-mates into a speed burst.
	for o in get_tree().get_nodes_in_group("enemies"):
		if e.kind == "shuckit" and o != e and not o.dead and o.position.distance_to(e.position) < 170.0:
			o.boost(1.5)
	# Venom hook: poison hops to the nearest foe (or to everything nearby with Brewmother).
	if e.poison > 1:
		var near = null
		for o in get_tree().get_nodes_in_group("enemies"):
			if o == e or o.dead:
				continue
			var dist: float = o.position.distance_to(e.position)
			if e.spread_all and dist < 150.0:
				o.add_poison(e.poison - 1, e.poison_mul, 8, true)
			elif dist < 150.0 and (near == null or dist < near.position.distance_to(e.position)):
				near = o
		if near != null and not e.spread_all:
			near.add_poison(e.poison - 1, e.poison_mul)
	_refresh()

func _on_leaked(e) -> void:
	lives -= e.leak
	shake = 1.0
	_refresh()
	if lives <= 0:
		_end("lost")

func _wave_done() -> void:
	wave_running = false
	coins += 40 + 10 * wave
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
	if p.x < 30 or p.x > 1250 or p.y < 70 or p.y > 690 or (p.y > 600 and p.x < 480):
		return false
	if _dist_to_path(p) < PATH_HALF + 30.0:
		return false
	for dc in decor:
		if int(dc[1]) != 2 and int(dc[1]) >= 1 and p.distance_to(dc[0]) < 30.0:
			return false
	for n in get_children():
		if n.get_script() == TowerScript and n.position.distance_to(p) < 60.0:
			return false
	return true

func _tower_at(p: Vector2):
	for n in get_children():
		if n.get_script() == TowerScript and n.position.distance_to(p) < 34.0:
			return n
	return null

func _select_tower(t) -> void:
	_deselect_tower()
	sel_tower = t
	t.selected = true
	placing = false
	_sync_cards()
	panel.show_for(t, coins)
	panel.position = Vector2(1280 - 16 - 380, 70) if t.position.x < 640 else Vector2(16, 70)

func _deselect_tower() -> void:
	if sel_tower != null and is_instance_valid(sel_tower):
		sel_tower.selected = false
	sel_tower = null
	panel.visible = false

func _on_upgrade(path: String) -> void:
	if sel_tower == null or not is_instance_valid(sel_tower):
		return
	var u: Dictionary = sel_tower.next_upgrade(path)
	if u.is_empty() or sel_tower.blocked(path) or coins < int(u.cost):
		return
	coins -= sel_tower.buy(path)
	_refresh()

func _on_sell() -> void:
	if sel_tower == null or not is_instance_valid(sel_tower):
		return
	coins += int(sel_tower.spent * 0.7)
	sel_tower.queue_free()
	sel_tower = null
	panel.visible = false
	_refresh()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if state != "play":
			get_tree().reload_current_scene()
			return
		var p := get_global_mouse_position()
		var tw = _tower_at(p)
		if tw != null:
			_select_tower(tw)
			return
		var d: Dictionary = Creatures.DEFS[selected]
		if placing and coins >= int(d.cost) and _valid_spot(p):
			coins -= int(d.cost)
			var t = TowerScript.new()
			t.def = d
			t.spent = int(d.cost)
			t.position = p
			add_child(t)
			_refresh()
		else:
			_deselect_tower()

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("5fae4f"))
	for gx in 20:
		for gy in 12:
			if (gx + gy) % 2 == 0:
				draw_rect(Rect2(gx * 64, gy * 64, 64, 64), Color(1, 1, 1, 0.045))
	for i in PATH.size() - 1:
		draw_line(PATH[i], PATH[i + 1], Color("6b4a2a"), PATH_HALF * 2 + 8)
	for p in PATH:
		draw_circle(p, PATH_HALF + 4, Color("6b4a2a"))
	for i in PATH.size() - 1:
		draw_line(PATH[i], PATH[i + 1], Color("d1a56a"), PATH_HALF * 2 - 4)
	for p in PATH:
		draw_circle(p, PATH_HALF - 2, Color("d1a56a"))
	for dc in decor:
		var p: Vector2 = dc[0]
		var z: float = dc[2]
		match int(dc[1]):
			0:
				DrawUtil.disc(self, p, 13 * z, Color("3f8a3a"), Color("24501f"), 3.0)
				DrawUtil.disc(self, p + Vector2(11, 4) * z, 9 * z, Color("4a9a42"), Color("24501f"), 3.0)
			1:
				DrawUtil.disc(self, p, 11 * z, Color("9aa3ad"), Color("4a5260"), 3.0)
			2:
				for j in 3:
					draw_circle(p + Vector2(j * 7 - 7, (j % 2) * 5) * z, 3.5 * z, Color("ffe36a") if j != 1 else Color("ff8fb1"))
			3:
				draw_line(p + Vector2(0, 8) * z, p + Vector2(0, 26) * z, Color("5a3a1e"), 7.0 * z)
				DrawUtil.disc(self, p, 24 * z, Color("2f7a35"), Color("1c4a22"), 4.0)
				draw_circle(p + Vector2(-8, -8) * z, 8 * z, Color("4aa04a"))
	if state == "play" and placing:
		var m := get_global_mouse_position()
		var d: Dictionary = Creatures.DEFS[selected]
		var ok := coins >= int(d.cost) and _valid_spot(m)
		var tint := Color(1, 1, 1, 0.45) if ok else Color(1, 0.2, 0.2, 0.45)
		draw_arc(m, float(d.range), 0, TAU, 64, tint, 2.0, true)
		draw_set_transform(m, 0.0, Vector2.ONE)
		TowerScript.draw_icon(self, selected, d)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(m, 28, Color(tint.r, tint.g, tint.b, 0.2))
