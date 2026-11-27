extends Node2D
# Battle scene: level lanes, waves, shop, upgrade panel, stones, zones, difficulty/mutators, stars and unlocks.
const Creatures = preload("res://creatures.gd")
const EnemyScript = preload("res://enemy.gd")
const TowerScript = preload("res://tower.gd")
const UiStyle = preload("res://ui_style.gd")
const PanelScript = preload("res://upgrade_panel.gd")
const PoofScript = preload("res://poof.gd")
const FxScript = preload("res://fx.gd")
const Levels = preload("res://levels.gd")
const Rules = preload("res://rules.gd")
const Waves = preload("res://waves.gd")
const Weather = preload("res://weather.gd")
const Session = preload("res://session.gd")
const Sfx = preload("res://sfx.gd")
const Backdrop = preload("res://backdrop.gd")
const PuppetLib = preload("res://puppet_lib.gd")
const SettingsPanel = preload("res://settings_panel.gd")
const HudBar = preload("res://hud_bar.gd")
const ResultScreen = preload("res://result_screen.gd")
const Tutorial = preload("res://tutorial.gd")
const Moves = preload("res://moves.gd")
const TypeChart = preload("res://type_chart.gd")
const SURGE_CD := 45.0
const PATH_HALF := 34.0
const PAGE := 6

var lv: Dictionary
var paths: Array = []
var zones: Array = []
var stones: Array = []
var mut: Dictionary = {}
var weather := "clear"
var coins := 220
var lives := 20
var lives_start := 20
var wave := 0
var to_spawn := 0
var spawn_cd := 0.0
var wave_running := false
var state := "play"
var endless := false
var queue: Array = []
var plans := {}
var run_seed := 0
var rng := RandomNumberGenerator.new()
var spawn_idx := 0
var clock := 0.0
var shake := 0.0
var red_flash := 0.0
var surge_cd := 0.0
var selected := "tickindle"
var placing := true
var sel_tower = null
var shop_ids: Array = []
var shop_page := 0
var cards := {}
var backdrop_vp: SubViewport
var hud: Label
var info: Label
var start_btn: Button
var speed_btn: Button
var sound_btn: Button
var pause_btn: Button
var surge_btn: Button
var banner: Label
var retry_btn: Button
var menu_btn: Button
var endless_btn: Button
var hint: Label
var prev_btn: Button
var next_btn: Button
var panel
var paused_scale := 1.0
var intro: Label
var enemy_list: Array = []
var pending := Vector2.ZERO
var has_pending := false
var pause_menu
var well_flash := 0.0
var hud_bar
var fade_rect: ColorRect
var fade_t := 0.0
var run_seconds := 0.0
var tutorial
var event_id := ""
var intro_t := 3.6
var lures := 3
var captures_run := 0
var free_ids := {}          # tower id -> free placements left (granted by capturing it)
var run_xp := {}            # tower id -> XP earned this run (banked at the end)
var capture_hint_shown := false
const CAPTURE_HP := 0.35

func _ready() -> void:
	Session.load_save()
	lures = 3 + Session.lure_bonus
	Session.lure_bonus = 0
	Session.init_ui()
	lv = Levels.LEVELS[Session.level_id]
	paths = Levels.to_paths(lv)
	for z in lv.zones:
		zones.append({"pos": Vector2(z.pos[0], z.pos[1]), "r": z.r, "kind": z.kind})
	for s in lv.stones:
		stones.append({"pos": Vector2(s[0], s[1]), "type": s[2]})
	mut = Rules.combine(Session.diff, Session.muts)
	lives = int(mut.lives)
	lives_start = lives
	coins = int(float(lv.coins) * float(mut.coins))
	run_seed = Session.run_seed if Session.run_seed != 0 else randi()
	Session.run_seed = 0
	backdrop_vp = Backdrop.make(self, lv)
	_build_ui()
	_build_shop()
	_refresh()

# ---------- UI ----------
func _label(pos: Vector2, size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_outline_color", Color("1d1230"))
	l.add_theme_constant_override("outline_size", 7)
	return l

func _button(text: String, pos: Vector2, size: Vector2, fsize: int, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", fsize)
	b.pressed.connect(cb)
	UiStyle.style_btn(b, col, col)
	return b

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	hud = _label(Vector2(16, 8), 26)
	hud.visible = false
	layer.add_child(hud)
	info = _label(Vector2(16, 40), 17)
	info.visible = false
	layer.add_child(info)
	hud_bar = HudBar.new()
	hud_bar.m = self
	layer.add_child(hud_bar)
	start_btn = _button("Start wave", Vector2(1060, 636), Vector2(200, 64), 24, Color("c4552b"), _start_wave)
	layer.add_child(start_btn)
	speed_btn = _button("", Vector2(1100, 8), Vector2(160, 52), 22, Color("3a4a6b"), _cycle_speed)
	layer.add_child(speed_btn)
	sound_btn = _button("Sound: On" if Sfx.music_on else "Sound: Off", Vector2(1100, 64), Vector2(160, 46), 19, Color("3a4a6b"), func(): sound_btn.text = "Sound: On" if Sfx.toggle_sound(self) else "Sound: Off")
	layer.add_child(sound_btn)
	pause_btn = _button("Menu", Vector2(970, 8), Vector2(120, 52), 22, Color("3a4a6b"), _toggle_pause)
	layer.add_child(pause_btn)
	surge_btn = _button("", Vector2(1060, 556), Vector2(200, 64), 20, Color("2a6f9a"), _surge)
	surge_btn.visible = not bool(mut.nosurge)
	layer.add_child(surge_btn)
	banner = _label(Vector2(340, 250), 48)
	banner.visible = false
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.size = Vector2(600, 200)
	layer.add_child(banner)
	retry_btn = _button("Retry", Vector2(330, 525), Vector2(190, 60), 26, Color("2f6b3a"), func(): get_tree().reload_current_scene())
	retry_btn.visible = false
	layer.add_child(retry_btn)
	menu_btn = _button("Levels", Vector2(545, 525), Vector2(190, 60), 26, Color("3a4a6b"), func(): Engine.time_scale = 1.0; get_tree().change_scene_to_file("res://menu.tscn"))
	menu_btn.visible = false
	layer.add_child(menu_btn)
	endless_btn = _button("Endless", Vector2(760, 525), Vector2(190, 60), 26, Color("8a5a1a"), _go_endless)
	endless_btn.visible = false
	layer.add_child(endless_btn)
	if Session.level_id == "mossgate" and not bool(Session.settings.get("tutorial_done", false)):
		tutorial = Tutorial.new()
		tutorial.m = self
		layer.add_child(tutorial)
	hint = _label(Vector2(260, 470), 22)
	hint.text = "Pick a creature below, tap the ground to place it.\nTap a placed creature to upgrade it. Glowing rune stones boost whoever stands on them!"
	Session.load_save()
	hint.visible = false
	layer.add_child(hint)
	panel = PanelScript.new()
	panel.upgrade.connect(_on_upgrade)
	panel.sell.connect(_on_sell)
	panel.cycle_target.connect(func(): panel.refresh(coins))
	layer.add_child(panel)
	panel.position = Vector2(16, 116)
	pause_menu = SettingsPanel.new()
	pause_menu.mode = "pause"
	pause_menu.resume.connect(_toggle_pause)
	pause_menu.restart.connect(func(): Engine.time_scale = 1.0; get_tree().reload_current_scene())
	pause_menu.levels.connect(func(): Engine.time_scale = 1.0; get_tree().change_scene_to_file("res://menu.tscn"))
	layer.add_child(pause_menu)
	pause_menu.position = Vector2(380, 150)
	prev_btn = _button("<", Vector2(924, 612), Vector2(50, 44), 22, Color("3a4a6b"), func(): _page(-1))
	next_btn = _button(">", Vector2(924, 662), Vector2(50, 44), 22, Color("3a4a6b"), func(): _page(1))
	layer.add_child(prev_btn)
	layer.add_child(next_btn)
	fade_rect = ColorRect.new()
	fade_rect.color = Color(0.03, 0.0, 0.08, 1.0)
	fade_rect.size = Vector2(1280, 720)
	fade_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(fade_rect)
	intro = _label(Vector2(0, 250), 34)
	intro.size = Vector2(1280, 200)
	intro.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	intro.text = "%s\n%s" % [lv.name, lv.rule]
	layer.add_child(intro)
	Sfx.start_music(self)

func _build_shop() -> void:
	shop_ids.clear()
	var team: Array = Session.team_ids()
	for k in Creatures.TOWERS:
		if Session.tower_open(Creatures.TOWERS[k]) and (k in team or int(free_ids.get(k, 0)) > 0):
			shop_ids.append(k)
	if not selected in shop_ids:
		selected = shop_ids[0]
	for k in cards:
		cards[k].queue_free()
	cards.clear()
	var layer: CanvasLayer = prev_btn.get_parent()
	for i in shop_ids.size():
		var id: String = shop_ids[i]
		var d: Dictionary = Creatures.TOWERS[id]
		var b := Button.new()
		b.toggle_mode = true
		b.text = "%s\n%d  Lv%d" % [d.name, d.cost, Session.level_of(id)]
		b.icon = PuppetLib.tex(d.sprite, "idle", 0)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 44)
		b.add_theme_font_size_override("font_size", 14)
		b.clip_text = true
		b.size = Vector2(142, 90)
		b.toggled.connect(func(on): _on_card(id, on))
		layer.add_child(b)
		UiStyle.style_btn(b, Color("2f6b3a"), Color("d9892a"))
		cards[id] = b
	_layout_cards()

func _layout_cards() -> void:
	var pages := maxi(1, ceili(float(shop_ids.size()) / PAGE))
	shop_page = clampi(shop_page, 0, pages - 1)
	for i in shop_ids.size():
		var b: Button = cards[shop_ids[i]]
		var on_page := i >= shop_page * PAGE and i < (shop_page + 1) * PAGE
		b.visible = on_page
		b.position = Vector2(16 + (i - shop_page * PAGE) * 150, 616)
		b.set_pressed_no_signal(placing and shop_ids[i] == selected)
	prev_btn.visible = pages > 1
	next_btn.visible = pages > 1

func _page(d: int) -> void:
	shop_page += d
	_layout_cards()

func _on_card(id: String, on: bool) -> void:
	Sfx.play(self, "click")
	if on:
		selected = id
		placing = true
		_deselect_tower()
	else:
		placing = false
	_layout_cards()

func _cycle_speed() -> void:
	if Engine.time_scale <= 0.0:
		Engine.time_scale = paused_scale
	Engine.time_scale = 2.0 if Engine.time_scale < 1.5 else (3.0 if Engine.time_scale < 2.5 else 1.0)
	_refresh()

func _toggle_pause() -> void:
	if Engine.time_scale > 0.0:
		paused_scale = Engine.time_scale
		Engine.time_scale = 0.0
		pause_menu.visible = true
	else:
		Engine.time_scale = paused_scale
		pause_menu.visible = false
	_refresh()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST and state == "play":
		_toggle_pause()

func _refresh() -> void:
	speed_btn.text = "Speed x%d" % int(maxf(1.0, Engine.time_scale if Engine.time_scale > 0.0 else paused_scale))
	var nxt: String = lv.weather[wave % lv.weather.size()] if not wave_running else weather
	var wtxt: String = "Weather: " + String(Weather.WEATHER[nxt].label)
	hud.text = "Coins %d    Lives %d    Lures %d    Wave %s" % [coins, lives, lures, ("%d (Endless)" % wave) if endless else ("%d/%d" % [wave, Levels.TOTAL_WAVES])]
	var line2 := ("Next: " + _incoming_text(wave + 1)) if (not wave_running and (endless or wave < Levels.TOTAL_WAVES)) else "Tap a creature to upgrade it"
	info.text = "%s  |  %s\n%s" % [lv.name, Rules.DIFFICULTY[Session.diff].name, line2 + "\n" + wtxt]
	if sel_tower != null and is_instance_valid(sel_tower):
		panel.refresh(coins)

# ---------- waves ----------
func _plan(w: int) -> Array:
	if not plans.has(w):
		var r := RandomNumberGenerator.new()
		r.seed = hash([run_seed, w])
		plans[w] = Waves.build(lv, w, r, float(mut.count))
	return plans[w]

func _incoming_text(w: int) -> String:
	var counts := {}
	for k in _plan(w):
		var key := String(k).replace("boss:", "").replace("champion:", "")
		counts[key] = counts.get(key, 0) + 1
	var parts := []
	for k in counts:
		parts.append("%d %s" % [counts[k], Creatures.ENEMIES[k].name])
	return ", ".join(parts)

func _start_wave() -> void:
	if wave_running or state != "play":
		return
	wave += 1
	weather = lv.weather[(wave - 1) % lv.weather.size()]
	Sfx.play(self, "horn")
	FxScript.text_at(self, Vector2(640, 250), "Wave %d" % wave, Color("ffffff"))
	queue = _plan(wave).duplicate()
	to_spawn = queue.size()
	spawn_idx = 0
	spawn_cd = 0.0
	wave_running = true
	rng.seed = hash([run_seed, wave, 77])
	_roll_event()
	start_btn.disabled = true
	hint.visible = false
	_refresh()

func _roll_event() -> void:
	event_id = ""
	var r := RandomNumberGenerator.new()
	r.seed = hash([run_seed, wave, 4242])
	if wave >= 3 and r.randf() < 0.3:
		event_id = Rules.EVENT_ORDER[r.randi() % Rules.EVENT_ORDER.size()]
		var ev: Dictionary = Rules.EVENTS[event_id]
		FxScript.text_at(self, Vector2(640, 210), "%s  %s" % [ev.name, ev.desc], Color("ffd23a"))

# Combined multiplier for key: run mutators x current wave event.
func eff(key: String) -> float:
	var m := float(mut.get(key, 1.0))
	if event_id != "":
		m *= float(Rules.EVENTS[event_id].get(key, 1.0))
	return m

func _process(delta: float) -> void:
	enemy_list = get_tree().get_nodes_in_group("enemies")
	if state == "play" and wave_running:
		_update_capturable()
	clock += delta
	fade_t += delta
	fade_rect.modulate.a = clampf(1.0 - fade_t / 0.6, 0.0, 1.0)
	if state == "play" and wave_running:
		run_seconds += delta
	well_flash = maxf(0.0, well_flash - delta * 1.6)
	intro_t -= delta
	intro.modulate.a = clampf(intro_t / 1.2, 0.0, 1.0) if not pause_menu.visible else 0.0
	red_flash = maxf(0.0, red_flash - delta)
	surge_cd = maxf(0.0, surge_cd - delta)
	surge_btn.disabled = surge_cd > 0.0 or not wave_running
	surge_btn.text = "Well Surge\n(stun + damage)" if surge_cd <= 0.0 else "Surge in %ds" % ceili(surge_cd)
	shake = maxf(0.0, shake - delta * 2.5)
	position = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * shake * 9.0 if bool(Session.settings.shake) else Vector2.ZERO
	if state == "play" and wave_running:
		spawn_cd -= delta
		if to_spawn > 0 and spawn_cd <= 0.0:
			_spawn()
			to_spawn -= 1
			spawn_cd = maxf(0.4, 1.1 - 0.05 * wave) * eff("interval")
		elif to_spawn == 0 and enemy_list.is_empty():
			_wave_done()
	queue_redraw()

func _pick_lane() -> int:
	var n := paths.size()
	if n == 1:
		return 0
	match String(lv.lane_mode):
		"alternate": return (wave - 1) % n
		"split": return spawn_idx % n
	return rng.randi() % n

func _update_capturable() -> void:
	for e in get_tree().get_nodes_in_group("enemies"):
		var ok: bool = not e.dead and not e.is_boss and e.hp / e.max_hp <= CAPTURE_HP and Session.tower_for(e.kind) != ""
		if ok and not e.capturable and not capture_hint_shown:
			capture_hint_shown = true
			FxScript.text_at(self, Vector2(640, 300), "Weak creature! Tap it to capture it (uses a Lure)", Color("ffe08a"))
		e.capturable = ok

func _capturable_at(p: Vector2):
	var best = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.capturable and not e.dead and e.position.distance_to(p) < 48.0:
			if best == null or e.position.distance_to(p) < best.position.distance_to(p):
				best = e
	return best

func capture_chance(e) -> float:
	return clampf(lerpf(0.9, 0.45, e.hp / e.max_hp / CAPTURE_HP) + (0.1 if e.shiny else 0.0), 0.45, 0.95)

func _try_capture(e) -> void:
	if lures <= 0:
		FxScript.text_at(self, e.position + Vector2(0, -50), "No Lures left!", Color("ff9a9a"))
		return
	lures -= 1
	if rng.randf() <= capture_chance(e):
		e.dead = true
		coins += int(e.reward * 1.5)
		var id := Session.tower_for(e.kind)
		var fresh := Session.capture(e.kind)
		free_ids[id] = int(free_ids.get(id, 0)) + 1
		run_xp[id] = int(run_xp.get(id, 0)) + (50 if e.shiny else 25)
		var pf = PoofScript.new()
		pf.col = Color("ffd23a")
		pf.position = e.position
		add_child(pf)
		captures_run += 1
		FxScript.text_at(self, e.position + Vector2(0, -50), "Captured %s!%s" % [Creatures.ENEMIES[e.kind].name, " NEW" if fresh else ""], Color("ffe08a"))
		Sfx.play(self, "up", -6.0)
		Sfx.haptic(60)
		e.queue_free()
		_build_shop()
	else:
		e.boost(2.5)
		FxScript.text_at(self, e.position + Vector2(0, -50), "Broke free!", Color("ff9a9a"))
		Sfx.play(self, "leak", -14.0)
	_refresh()

func _spawn() -> void:
	if queue.is_empty():
		return
	var kind: String = queue.pop_front()
	spawn_idx += 1
	var d: Dictionary
	var champion := kind.begins_with("champion:")
	if champion:
		kind = kind.substr(9)
	var boss := kind.begins_with("boss:")
	if boss:
		d = Waves.boss_def(lv, kind.substr(5), wave)
		shake = 1.5
		Sfx.haptic(180)
		Sfx.play(self, "boss")
		FxScript.text_at(self, Vector2(640, 330), "BOSS: %s!" % d.name, Color("ff6a5a"))
	else:
		d = Creatures.ENEMIES[kind]
	var lane := _pick_lane()
	var path: PackedVector2Array = paths[lane]
	if bool(d.get("flying", false)):
		path = PackedVector2Array([path[0], path[path.size() - 1]])
	var en = _make_enemy(d, path, wave, true, boss)
	var gp = PoofScript.new()
	gp.col = Color(lv.colors.accent)
	gp.position = path[0]
	gp.scale = Vector2(0.55, 0.55)
	add_child(gp)
	if champion:
		en.make_elite()
		en.hp *= 1.6
		en.max_hp = en.hp
		en.reward *= 2
		FxScript.text_at(self, Vector2(640, 330), "Champion: %s!" % d.name, Color("ffb040"))

func _make_enemy(d: Dictionary, path: PackedVector2Array, w: int, scale_stats: bool, boss: bool = false):
	var e = EnemyScript.new()
	e.setup(path, d, w)
	if scale_stats:
		e.hp *= float(lv.hp_mult) * eff("hp")
		e.max_hp = e.hp
		e.speed *= eff("speed")
		e.reward = int(round(e.reward * eff("reward")))
		if not boss and float(mut.elite_p) > 0.0 and rng.randf() < float(mut.elite_p):
			e.make_elite()
		if not boss and not e.elite and wave >= 2 and rng.randf() < 0.04 and Session.tower_for(e.kind) != "":
			e.shiny = true
			e.hp *= 1.3
			e.max_hp = e.hp
			e.reward *= 3
			FxScript.text_at(self, Vector2(640, 260), "A shiny %s appeared!" % d.name, Color("ffe35a"))
	e.zones = zones
	e.died.connect(_on_died)
	e.leaked.connect(_on_leaked)
	add_child(e)
	return e

func _on_died(e) -> void:
	coins += e.reward
	var pf = PoofScript.new()
	pf.col = TypeChart.COLORS[e.types[0]]
	pf.position = e.position
	pf.scale = Vector2(1.4, 1.4) if e.is_boss else Vector2.ONE
	add_child(pf)
	FxScript.text_at(self, e.position + Vector2(0, -20), "+%d" % e.reward, Color("ffd23a"))
	Sfx.play(self, "pop", -11.0, 30)
	Sfx.voice(self, e.sprite_id, true, -12.0)
	Sfx.play(self, "coin", -14.0, 60)
	# Gale hook: a fallen Shuckit whips nearby packmates into a sprint.
	for o in get_tree().get_nodes_in_group("enemies"):
		if e.kind == "shuckit" and o != e and not o.dead and o.position.distance_to(e.position) < 170.0:
			o.boost(1.5)
	# Venom hook: poison hops to the nearest foe (or everything nearby with Brewmother).
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
	# Quillwyrm: splits into smaller wyrms
	if e.split > 0 and not e.flying:
		for i in e.split:
			var d: Dictionary = Creatures.ENEMIES[e.kind].duplicate()
			d.split = 0
			d.hp = e.max_hp * 0.3
			d.hp_wave = 0.0
			d.scale = 0.7
			d.reward = 2
			var ch = _make_enemy(d, e.path, wave, false)
			ch.position = e.position
			ch.seg = e.seg
			ch.travelled = e.travelled - i * 18.0
			ch.hp = d.hp
			ch.max_hp = d.hp
	_refresh()

func _on_leaked(e) -> void:
	if state != "play":
		return
	lives -= e.leak
	red_flash = 0.5
	well_flash = 1.0
	shake = 1.0 if e.leak < 5 else 2.0
	Sfx.haptic(60 if e.leak < 5 else 140)
	Sfx.play(self, "leak", -4.0)
	_refresh()
	if lives <= 0:
		_end("lost")

func _wave_done() -> void:
	wave_running = false
	var inc := 0
	for t in get_tree().get_nodes_in_group("towers"):
		inc += int(t.st.income)
	coins += int((50 + 14 * wave) * float(mut.reward)) + inc
	lures = mini(lures + 1, 6)
	for t in get_tree().get_nodes_in_group("towers"):
		var tid := String(t.def.id)
		run_xp[tid] = int(run_xp.get(tid, 0)) + 10 + 2 * int(t.tiers.a + t.tiers.b)
	if inc > 0:
		FxScript.text_at(self, Vector2(640, 300), "Tea money: +%d" % inc, Color("9fffa0"))
	start_btn.disabled = false
	_refresh()
	if wave >= Levels.TOTAL_WAVES and not endless:
		_end("won")

var result_screen

func _end(result: String) -> void:
	state = result
	start_btn.disabled = true
	retry_btn.visible = true
	menu_btn.visible = true
	banner.visible = false
	if result_screen != null and is_instance_valid(result_screen):
		result_screen.queue_free()
	var rs = ResultScreen.new()
	rs.won = result == "won"
	var lvl_lines: Array = []
	for id in run_xp:
		var bonus := 40 if result == "won" else 0
		var lv_change := Session.add_xp(String(id), int(run_xp[id]) + bonus)
		if lv_change[1] > lv_change[0]:
			lvl_lines.append("%s grew to Lv %d!" % [Creatures.TOWERS[id].name, lv_change[1]])
			for mv in Moves.gained(Creatures.TOWERS[id].types, lv_change[0], lv_change[1]):
				lvl_lines.append("   learned %s (%s)" % [mv.name, mv.desc])
	var gold_gain := wave * 15 + (100 if result == "won" else 0) + captures_run * 30
	Session.add_gold(gold_gain)
	lvl_lines.append("Gold +%d (total %d)" % [gold_gain, Session.gold])
	var layer: CanvasLayer = start_btn.get_parent()
	if result == "won":
		var rec := Session.record_win(Session.level_id, wave, lives, lives_start, endless)
		rs.title = "The Well holds!"
		rs.stars = int(rec.stars)
		rs.lines = ["Waves cleared: %d/%d" % [wave, Levels.TOTAL_WAVES], "Lives left: %d/%d" % [lives, lives_start], "Difficulty: %s" % Rules.DIFFICULTY[Session.diff].name] + lvl_lines
		for a in rec.allies:
			rs.ally_sprites.append(Creatures.TOWERS[a].sprite)
			rs.ally_names.append(Creatures.TOWERS[a].name)
		endless_btn.visible = not endless
		Sfx.play(self, "win")
		Sfx.haptic(120)
	else:
		Session.record_loss(Session.level_id, wave)
		rs.title = "The Well is lost..."
		rs.lines = ["You reached wave %d of %d" % [wave, Levels.TOTAL_WAVES], "Run seed: %d" % run_seed] + lvl_lines
		var tips := ["Put creatures on rune stones for a free boost.", "Mix types: Super! hits do 50% more damage.", "Upgrade a path to tier 3 to evolve a creature.", "Dugloom's slow gives every other defender more time to shoot.", "Try the Well Surge when a wave overwhelms you."]
		rs.tip = tips[wave % tips.size()]
		Sfx.play(self, "lose")
	layer.add_child(rs)
	layer.move_child(rs, retry_btn.get_index())
	if tutorial != null and is_instance_valid(tutorial):
		tutorial.queue_free()
	result_screen = rs

func _go_endless() -> void:
	endless = true
	state = "play"
	banner.visible = false
	retry_btn.visible = false
	menu_btn.visible = false
	endless_btn.visible = false
	if result_screen != null and is_instance_valid(result_screen):
		result_screen.queue_free()
	start_btn.disabled = false
	FxScript.text_at(self, Vector2(640, 300), "Endless mode: the Wells never stop!", Color("ffd23a"))
	_refresh()

func _surge() -> void:
	if surge_cd > 0.0 or not wave_running or state != "play" or bool(mut.nosurge):
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

# ---------- towers ----------
func weather_mult(types: Array) -> float:
	return Weather.mult(weather, types)

func stone_mult(t) -> float:
	var m := 1.0
	for s in stones:
		if t.position.distance_to(s.pos) < 46.0:
			m = maxf(m, 1.3 if s.type in t.def.types else 1.15)
	return m

func add_coins(n: int, pos: Vector2) -> void:
	coins += n
	FxScript.text_at(self, pos + Vector2(0, -30), "+%d" % n, Color("ffd23a"))

func _dist_to_paths(p: Vector2) -> float:
	var best := INF
	for path in paths:
		for i in path.size() - 1:
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, path[i], path[i + 1])))
	return best

func _snap(p: Vector2) -> Vector2:
	for s in stones:
		if p.distance_to(s.pos) < 46.0:
			return s.pos
	return p

func _valid_spot(p: Vector2) -> bool:
	if p.x < 30 or p.x > 1250 or p.y < 84 or p.y > 690 or (p.y > 598 and p.x < 980) or (p.x > 1040 and p.y > 540) or (p.x > 980 and p.y < 108):
		return false
	if _dist_to_paths(p) < PATH_HALF + 30.0:
		return false
	for n in get_tree().get_nodes_in_group("towers"):
		if n.position.distance_to(p) < 56.0:
			return false
	return true

func _tower_at(p: Vector2):
	for n in get_tree().get_nodes_in_group("towers"):
		if n.position.distance_to(p) < 36.0:
			return n
	return null

func _select_tower(t) -> void:
	_deselect_tower()
	sel_tower = t
	t.selected = true
	placing = false
	_layout_cards()
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
	Sfx.haptic(30)
	_refresh()

func _on_sell() -> void:
	if sel_tower == null or not is_instance_valid(sel_tower):
		return
	coins += int(sel_tower.spent * float(mut.sell))
	Sfx.play(self, "coin")
	sel_tower.queue_free()
	sel_tower = null
	panel.visible = false
	_refresh()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		if state != "play" or Engine.time_scale <= 0.0:
			return
		var p: Vector2 = get_canvas_transform().affine_inverse() * ev.position
		var cap = _capturable_at(p)
		if cap != null:
			_try_capture(cap)
			return
		var tw = _tower_at(p)
		if tw != null:
			has_pending = false
			_select_tower(tw)
			return
		var d: Dictionary = Creatures.TOWERS[selected]
		var sp := _snap(p)
		if not placing:
			_deselect_tower()
			return
		# Tap once to preview the spot, tap the preview again to place (precise on touch screens).
		if has_pending and p.distance_to(pending) < 46.0 and coins >= _cost(d) and _valid_spot(pending):
			_place(d, pending)
			has_pending = false
		elif _valid_spot(sp):
			pending = sp
			has_pending = true
			Sfx.play(self, "click", -12.0)
		else:
			has_pending = false
			_deselect_tower()

func _cost(d: Dictionary) -> int:
	return 0 if int(free_ids.get(d.id, 0)) > 0 else int(d.cost)

func _place(d: Dictionary, at: Vector2) -> void:
	var c := _cost(d)
	if c == 0 and int(free_ids.get(d.id, 0)) > 0:
		free_ids[d.id] = int(free_ids[d.id]) - 1
	coins -= c
	var t = TowerScript.new()
	t.def = d
	t.spent = c
	t.position = at
	add_child(t)
	Sfx.play(self, "place")
	Sfx.haptic(25)
	_refresh()

# ---------- drawing ----------
func _draw() -> void:
	draw_texture(backdrop_vp.get_texture(), Vector2.ZERO)
	var c: Dictionary = lv.colors
	var acc := Color(c.accent)
	for s in stones:
		var pulse := 0.5 + 0.5 * sin(clock * 2.0 + s.pos.x)
		var col: Color = TypeChart.COLORS[s.type]
		draw_arc(s.pos, 46.0 + pulse * 3.0, 0, TAU, 40, Color(col.r, col.g, col.b, 0.35 + 0.3 * pulse), 3.0, true)
	if state == "play" and placing and has_pending:
		var m := pending
		var d: Dictionary = Creatures.TOWERS[selected]
		var ok := coins >= _cost(d) and _valid_spot(m)
		var tint := Color(1, 1, 1, 0.45) if ok else Color(1, 0.2, 0.2, 0.45)
		draw_arc(m, float(d.range), 0, TAU, 64, tint, 2.0, true)
		draw_set_transform(m, 0.0, Vector2.ONE)
		TowerScript.draw_icon(self, selected, d)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
		draw_circle(m, 28, Color(tint.r, tint.g, tint.b, 0.2))
		var pulse2 := 0.5 + 0.5 * sin(clock * 6.0)
		draw_arc(m, 40.0 + pulse2 * 4.0, 0, TAU, 32, Color(1, 0.95, 0.5, 0.9), 3.0, true)
		draw_string(ThemeDB.fallback_font, m + Vector2(-70, -86), "Tap again to place" if ok else "Can't place here", HORIZONTAL_ALIGNMENT_CENTER, 140, 18, Color.WHITE if ok else Color(1, 0.6, 0.6))
	var seen := {}
	for path in paths:
		var wp: Vector2 = path[path.size() - 1]
		if seen.has(wp):
			continue
		seen[wp] = true
		var g := Color(c.glow)
		var pw := 0.5 + 0.5 * sin(clock * 2.2)
		draw_circle(wp + Vector2(0, 10), 60.0 + pw * 8.0 + well_flash * 30.0, Color(g.r, g.g, g.b, 0.10 + 0.12 * pw + well_flash * 0.3))
		for i in 5:
			var a := clock * 1.2 + i * 1.3
			draw_circle(wp + Vector2(cos(a) * 22.0, 10.0 - fmod(clock * 18.0 + i * 11.0, 46.0)), 2.5, Color(1, 1, 1, 0.8))
	# fireflies / spirit motes in the level's accent colour
	for i in 26:
		var x := fmod(i * 197.0 + sin(clock * 0.4 + i) * 40.0 + clock * 6.0, 1300.0)
		var y := fmod(i * 83.0 + cos(clock * 0.5 + i * 1.3) * 30.0, 700.0)
		draw_circle(Vector2(x, y), 2.2, Color(acc.r, acc.g, acc.b, 0.35 + 0.4 * sin(clock * 2.0 + i)))
	_draw_weather()
	if red_flash > 0.0:
		draw_rect(Rect2(0, 0, 1280, 720), Color(1, 0.1, 0.1, red_flash * 0.3))

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
