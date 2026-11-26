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
const Maps = preload("res://maps.gd")
const Session = preload("res://session.gd")
const Sfx = preload("res://sfx.gd")
const POOF_COL := {"shuckit": Color("8a89c0"), "zapnose": Color("ffd23a"), "glomm": Color("bfe6ff"), "hoardillo": Color("ffb0c8"), "mirewick": Color("7fffd0")}

var PATH: PackedVector2Array
var map: Dictionary
var weather := "clear"
var clock := 0.0
var retry_btn: Button
var menu_btn: Button
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
var sound_btn: Button
var banner: Label
var selected := "tickindle"
var placing := true
var cards := {}
var queue: Array = []
var decor: Array = []
var sel_tower = null
var panel
var shake := 0.0
var red_flash := 0.0
var endless := false
var surge_cd := 0.0
var surge_btn: Button
var endless_btn: Button
var hint: Label
const SURGE_CD := 45.0

func _ready() -> void:
	map = Maps.MAPS[Session.map_id]
	PATH = PackedVector2Array(map.path)
	weather = "clear"
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
	sound_btn = Button.new()
	sound_btn.position = Vector2(1100, 64)
	sound_btn.size = Vector2(160, 40)
	sound_btn.add_theme_font_size_override("font_size", 18)
	sound_btn.text = "Sound: On" if Sfx.music_on else "Sound: Off"
	sound_btn.pressed.connect(func(): sound_btn.text = "Sound: On" if Sfx.toggle_sound(self) else "Sound: Off")
	layer.add_child(sound_btn)
	UiStyle.style_btn(sound_btn, Color("3a4a6b"), Color("3a4a6b"))
	Sfx.start_music(self)
	banner = Label.new()
	banner.position = Vector2(340, 300)
	banner.add_theme_font_size_override("font_size", 48)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 10)
	banner.visible = false
	layer.add_child(banner)
	retry_btn = Button.new()
	retry_btn.text = "Retry"
	retry_btn.position = Vector2(420, 460)
	retry_btn.size = Vector2(200, 64)
	retry_btn.add_theme_font_size_override("font_size", 26)
	retry_btn.pressed.connect(func(): get_tree().reload_current_scene())
	retry_btn.visible = false
	layer.add_child(retry_btn)
	menu_btn = Button.new()
	menu_btn.text = "Menu"
	menu_btn.position = Vector2(660, 460)
	menu_btn.size = Vector2(200, 64)
	menu_btn.add_theme_font_size_override("font_size", 26)
	menu_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://menu.tscn"))
	menu_btn.visible = false
	layer.add_child(menu_btn)
	endless_btn = Button.new()
	endless_btn.text = "Endless mode"
	endless_btn.position = Vector2(540, 540)
	endless_btn.size = Vector2(200, 64)
	endless_btn.add_theme_font_size_override("font_size", 24)
	endless_btn.pressed.connect(_go_endless)
	endless_btn.visible = false
	layer.add_child(endless_btn)
	UiStyle.style_btn(endless_btn, Color("8a5a1a"), Color("8a5a1a"))
	surge_btn = Button.new()
	surge_btn.position = Vector2(1060, 556)
	surge_btn.size = Vector2(200, 64)
	surge_btn.add_theme_font_size_override("font_size", 20)
	surge_btn.pressed.connect(_surge)
	layer.add_child(surge_btn)
	UiStyle.style_btn(surge_btn, Color("2a6f9a"), Color("2a6f9a"))
	hint = Label.new()
	hint.position = Vector2(330, 540)
	hint.add_theme_font_size_override("font_size", 22)
	hint.add_theme_color_override("font_outline_color", Color.BLACK)
	hint.add_theme_constant_override("outline_size", 6)
	hint.text = "Pick a creature below, tap grass to place it.\nTap a placed creature to upgrade it. Then press Start wave!"
	hint.visible = Session.best.is_empty()
	layer.add_child(hint)
	UiStyle.style_btn(retry_btn, Color("2f6b3a"), Color("2f6b3a"))
	UiStyle.style_btn(menu_btn, Color("3a4a6b"), Color("3a4a6b"))
	for i in ["tickindle", "dugloom", "hutzin", "ally_shuckit", "ally_zapnose", "ally_glomm"]:
		var d: Dictionary = Creatures.DEFS[i]
		var b := Button.new()
		b.toggle_mode = true
		var open := Session.is_unlocked(d)
		b.text = ("%s\n%s\n%d" % [d.name, " / ".join(d.types.map(func(t): return t.capitalize())), d.cost]) if open else "%s\nLocked\n(%s)" % [d.name, Maps.MAPS[d.unlock].name.get_slice(" ", 0)]
		b.disabled = not open
		b.position = Vector2(16 + cards.size() * 150, 616)
		b.size = Vector2(142, 90)
		b.add_theme_font_size_override("font_size", 14)
		b.clip_text = true
		b.alignment = HORIZONTAL_ALIGNMENT_CENTER
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

func _surge() -> void:
	if surge_cd > 0.0 or not wave_running or state != "play":
		return
	surge_cd = SURGE_CD
	shake = 1.2
	Sfx.play(self, "pulse", -4.0)
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead:
			e.stun(1.6)
			e.take_damage(40.0 + 6.0 * wave)
	var pf = PoofScript.new()
	pf.col = Color("7fd8ff")
	pf.position = Vector2(640, 360)
	pf.scale = Vector2(9, 9)
	add_child(pf)

func _go_endless() -> void:
	endless = true
	state = "play"
	banner.visible = false
	retry_btn.visible = false
	menu_btn.visible = false
	endless_btn.visible = false
	start_btn.disabled = false
	FxScript.text_at(self, Vector2(640, 300), "Endless mode: the Wells never stop!", Color("ffd23a"))
	_refresh()

func _on_card(id: String, on: bool) -> void:
	Sfx.play(self, "click")
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
	var nxt: String = map.weather[wave % map.weather.size()] if not wave_running and (endless or wave < TOTAL_WAVES) else weather
	hud.text = "Coins %d    Lives %d    Wave %s\n%s\n%s" % [coins, lives, ("%d (Endless)" % wave) if endless else ("%d/%d" % [wave, TOTAL_WAVES]),
		("Next: " + _incoming_text(wave + 1)) if (not wave_running and (endless or wave < TOTAL_WAVES)) else "Tap a creature to upgrade it",
		"Weather: " + Maps.WEATHER[nxt].label]
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
	if w >= 4:
		for i in w - 3:
			q.append("hoardillo")
	if w >= 5:
		for i in (w - 4) * 2:
			q.append("mirewick")
	seed(1000 + w)
	q.shuffle()
	if w == TOTAL_WAVES or (w > TOTAL_WAVES and (w - TOTAL_WAVES) % 4 == 0):
		q.insert(q.size() / 2, "boss")
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
	weather = map.weather[(wave - 1) % map.weather.size()]
	Sfx.play(self, "horn")
	FxScript.text_at(self, Vector2(640, 250), "Wave %d" % wave, Color("ffffff"))
	queue = _build_wave(wave)
	to_spawn = queue.size()
	spawn_cd = 0.0
	wave_running = true
	start_btn.disabled = true
	_refresh()

func _process(delta: float) -> void:
	clock += delta
	red_flash = maxf(0.0, red_flash - delta)
	surge_cd = maxf(0.0, surge_cd - delta)
	surge_btn.disabled = surge_cd > 0.0 or not wave_running
	surge_btn.text = "Well Surge\n(stun + damage)" if surge_cd <= 0.0 else "Surge ready in %ds" % ceili(surge_cd)
	if hint.visible and clock > 14.0:
		hint.visible = false
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
	var kind: String = queue.pop_front()
	var d: Dictionary = Creatures.DEFS[kind]
	if kind == "boss":
		shake = 1.5
		Sfx.play(self, "boss")
		FxScript.text_at(self, Vector2(640, 330), "BOSS: Rimeheart Glomm!", Color("ff6a5a"))
	var e = EnemyScript.new()
	e.setup(PATH, d, wave)
	e.hp *= float(map.get("hp_mult", 1.0))
	e.max_hp = e.hp
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
	Sfx.play(self, "pop", -9.0, 30)
	Sfx.play(self, "coin", -14.0, 60)
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
	red_flash = 0.5
	shake = 1.0 if e.leak < 5 else 2.0
	Sfx.play(self, "leak", -4.0)
	_refresh()
	if lives <= 0:
		_end("lost")

func _wave_done() -> void:
	wave_running = false
	coins += 40 + 10 * wave
	_refresh()
	if wave >= TOTAL_WAVES and not endless:
		_end("won")
	else:
		start_btn.disabled = false

func _end(result: String) -> void:
	state = result
	banner.text = "The Well holds!" if result == "won" else "The Well is lost..."
	banner.position = Vector2(440, 330)
	banner.visible = true
	retry_btn.visible = true
	menu_btn.visible = true
	endless_btn.visible = result == "won" and not endless
	start_btn.disabled = true
	var ally := ""
	for k in Creatures.DEFS:
		if Creatures.DEFS[k].get("unlock", "") == Session.map_id:
			ally = k
	Session.record(Session.map_id, wave, result == "won" or endless, ally if result == "won" else "")
	if result == "won" and ally != "":
		banner.text += "\nNew ally: %s befriended!" % Creatures.DEFS[ally].name
	Sfx.play(self, "win" if result == "won" else "lose")

func _dist_to_path(p: Vector2) -> float:
	var best := INF
	for i in PATH.size() - 1:
		best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, PATH[i], PATH[i + 1])))
	return best

func _valid_spot(p: Vector2) -> bool:
	if p.x < 30 or p.x > 1250 or p.y < 70 or p.y > 690 or (p.y > 600 and p.x < 930):
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

func weather_mult(types: Array) -> float:
	return Maps.weather_mult(weather, types)

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
	panel.position = Vector2(1280 - 16 - 380, 116) if t.position.x < 640 else Vector2(16, 116)

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
	Sfx.play(self, "up")
	_refresh()

func _on_sell() -> void:
	if sel_tower == null or not is_instance_valid(sel_tower):
		return
	coins += int(sel_tower.spent * 0.7)
	Sfx.play(self, "coin")
	sel_tower.queue_free()
	sel_tower = null
	panel.visible = false
	_refresh()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if state != "play":
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
			Sfx.play(self, "place")
			_refresh()
		else:
			_deselect_tower()

func _draw() -> void:
	var g: Color = map.grass
	draw_rect(Rect2(0, 0, 1280, 720), g)
	for gx in 20:
		for gy in 12:
			if (gx + gy) % 2 == 0:
				draw_rect(Rect2(gx * 64, gy * 64, 64, 64), Color(1, 1, 1, 0.045) if map.style != "snow" else Color(0.4, 0.5, 0.7, 0.05))
	for i in PATH.size() - 1:
		draw_line(PATH[i], PATH[i + 1], map.path_edge, PATH_HALF * 2 + 8)
	for p in PATH:
		draw_circle(p, PATH_HALF + 4, map.path_edge)
	for i in PATH.size() - 1:
		draw_line(PATH[i], PATH[i + 1], map.path_fill, PATH_HALF * 2 - 4)
	for p in PATH:
		draw_circle(p, PATH_HALF - 2, map.path_fill)
	for dc in decor:
		_draw_decor(dc[0], int(dc[1]), dc[2])
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
	_draw_weather()
	_draw_vignette()
	if red_flash > 0.0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(1, 0.1, 0.1, red_flash * 0.3))

func _draw_vignette() -> void:
	var steps := 8
	for i in steps:
		var inset := float(i) * 12.0
		var a := 0.05 * (1.0 - float(i) / steps)
		draw_rect(Rect2(0, 0, 1280, inset + 12.0), Color(0, 0, 0, a))
		draw_rect(Rect2(0, 720 - inset - 12.0, 1280, inset + 12.0), Color(0, 0, 0, a))
		draw_rect(Rect2(0, 0, inset + 12.0, 720), Color(0, 0, 0, a))
		draw_rect(Rect2(1280 - inset - 12.0, 0, inset + 12.0, 720), Color(0, 0, 0, a))

func _draw_decor(p: Vector2, kind: int, z: float) -> void:
	match String(map.style):
		"snow":
			match kind:
				0:
					DrawUtil.disc(self, p, 12 * z, Color("eef6fc"), Color("9db2c9"), 3.0)
				1:
					DrawUtil.disc(self, p, 11 * z, Color("a9b4c4"), Color("586378"), 3.0)
					draw_circle(p + Vector2(0, -5) * z, 6 * z, Color("f4faff"))
				2:
					for j in 3:
						draw_circle(p + Vector2(j * 7 - 7, (j % 2) * 5) * z, 3.0 * z, Color("9fd8ff"))
				3:
					draw_line(p + Vector2(0, 8) * z, p + Vector2(0, 24) * z, Color("5a3a1e"), 6.0 * z)
					for k in 3:
						var w := (26 - k * 6) * z
						DrawUtil.poly(self, PackedVector2Array([p + Vector2(-w, 8 - k * 14) * 1.0 * z, p + Vector2(w, 8 - k * 14) * 1.0 * z, p + Vector2(0, -12 - k * 14) * z]), Color("2f6f58"), Color("1c4034"), 3.0)
						draw_line(p + Vector2(-w * 0.6, 4 - k * 14) * z, p + Vector2(w * 0.6, 4 - k * 14) * z, Color("eef6fc"), 4.0 * z)
		"desert":
			match kind:
				0:
					DrawUtil.disc(self, p, 10 * z, Color("9a8a3a"), Color("5a5020"), 3.0)
				1:
					DrawUtil.disc(self, p, 11 * z, Color("b0845a"), Color("6a4a30"), 3.0)
				2:
					for j in 3:
						draw_circle(p + Vector2(j * 7 - 7, (j % 2) * 5) * z, 3.0 * z, Color("ff9a5a"))
				3:
					DrawUtil.disc(self, p + Vector2(0, -6) * z, 7 * z, Color("4a9a4a"), Color("2a5a2a"), 3.0)
					DrawUtil.disc(self, p + Vector2(0, 6) * z, 7 * z, Color("4a9a4a"), Color("2a5a2a"), 3.0)
					DrawUtil.disc(self, p + Vector2(-9, 0) * z, 5 * z, Color("4a9a4a"), Color("2a5a2a"), 3.0)
		_:
			match kind:
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

func _draw_weather() -> void:
	match weather:
		"rain":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.1, 0.15, 0.3, 0.16))
			for i in 110:
				var x := fmod(i * 97.0 + clock * 90.0, 1300.0) - 10.0
				var y := fmod(i * 53.0 + clock * 720.0, 760.0) - 20.0
				draw_line(Vector2(x, y), Vector2(x - 6, y + 16), Color(0.7, 0.85, 1.0, 0.5), 2.0)
		"snow":
			draw_rect(Rect2(0, 0, 1280, 720), Color(0.8, 0.9, 1.0, 0.07))
			for i in 90:
				var x := fmod(i * 131.0 + clock * 25.0 + sin(clock + i) * 18.0, 1300.0)
				var y := fmod(i * 61.0 + clock * 70.0, 760.0) - 20.0
				draw_circle(Vector2(x, y), 2.0 + (i % 3), Color(1, 1, 1, 0.85))
		"heat":
			draw_rect(Rect2(0, 0, 1280, 720), Color(1.0, 0.55, 0.15, 0.09))
			for i in 40:
				var x := fmod(i * 173.0 + sin(clock * 0.7 + i) * 30.0, 1300.0)
				var y := 720.0 - fmod(i * 47.0 + clock * 60.0, 760.0)
				draw_circle(Vector2(x, y), 2.5, Color(1.0, 0.7, 0.3, 0.6))
