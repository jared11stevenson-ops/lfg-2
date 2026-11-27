extends Node2D
# Main menu: level grid (10 levels), run setup (difficulty + mutators), daily challenge, bestiary of all 20 creatures.
const Levels = preload("res://levels.gd")
const Rules = preload("res://rules.gd")
const Creatures = preload("res://creatures.gd")
const Session = preload("res://session.gd")
const PuppetLib = preload("res://puppet_lib.gd")
const TypeChart = preload("res://type_chart.gd")
const UiStyle = preload("res://ui_style.gd")
const Sfx = preload("res://sfx.gd")
const SettingsPanel = preload("res://settings_panel.gd")
const TeamScreen = preload("res://team_screen.gd")
const CARD := Vector2(236, 196)
const SPECIES := ["tickindle", "dugloom", "hutzin", "shuckit", "zapnose", "glomm", "hoardillo", "mirewick", "gloamoth", "bogbard", "quillwyrm", "drumbeak", "pyrelope", "mudskip", "thornarok", "ptarmitten", "tentbat", "dumbomaton", "colukite", "gilamancer"]
const BLURBS := {
	"tickindle": "Starter. Grumpy manul with a pocket watch. Winds up on one target.",
	"dugloom": "Befriend it by clearing Frostrun Pass. Sleepy dugong with a lantern. Slows and drags foes back.",
	"hutzin": "Befriend it by clearing Gloamwood. Manic hoatzin with a teapot hut. Stacking poison.",
}
var clock := 0.0
var hover := -1
var _art := {}
var mode := "levels"
var setup: Control
var setup_level := "mossgate"
var diff_btns := {}
var mut_btns := {}
var score_lbl: Label
var title_lbl: Label
var rule_lbl: Label
var dev_btn: Button
var daily_btn: Button
var best_btn: Button
var back_btn: Button
var settings_btn: Button
var settings_panel
var team_btn: Button
var team_screen

func _ready() -> void:
	Session.init_ui()
	Session.load_save()
	Sfx.start_music(self)
	var layer := CanvasLayer.new()
	add_child(layer)
	daily_btn = _btn("Daily Challenge", Vector2(1030, 14), Vector2(230, 46), 20, Color("c4552b"), _daily)
	best_btn = _btn("Bestiary", Vector2(1030, 68), Vector2(230, 40), 18, Color("3a4a6b"), func(): mode = "bestiary"; back_btn.visible = true)
	dev_btn = _btn("", Vector2(780, 14), Vector2(230, 44), 17, Color("4a4f66"), _toggle_dev)
	back_btn = _btn("Back", Vector2(1100, 14), Vector2(160, 46), 20, Color("3a4a6b"), func(): mode = "levels"; back_btn.visible = false)
	back_btn.visible = false
	settings_btn = _btn("Settings", Vector2(810, 62), Vector2(200, 46), 20, Color("3a4a6b"), func(): settings_panel.visible = true)
	team_btn = _btn("Team", Vector2(560, 14), Vector2(200, 46), 20, Color("2f6b3a"), _open_team)
	for b in [daily_btn, best_btn, dev_btn, back_btn, settings_btn, team_btn]:
		layer.add_child(b)
	_update_dev()
	_build_setup(layer)
	settings_panel = SettingsPanel.new()
	settings_panel.closed.connect(func(): settings_panel.visible = false)
	layer.add_child(settings_panel)
	settings_panel.position = Vector2(380, 130)

func _open_team() -> void:
	if team_screen != null and is_instance_valid(team_screen):
		team_screen.queue_free()
	team_screen = TeamScreen.new()
	team_screen.closed.connect(func(): team_screen.queue_free(); team_screen = null)
	team_btn.get_parent().add_child(team_screen)

func _btn(text: String, pos: Vector2, size: Vector2, fsize: int, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = size
	b.add_theme_font_size_override("font_size", fsize)
	b.pressed.connect(cb)
	UiStyle.style_btn(b, col, col)
	return b

func _update_dev() -> void:
	dev_btn.text = "Unlock all (test): %s" % ("ON" if Session.dev_all else "off")

func _toggle_dev() -> void:
	Session.set_dev_all(not Session.dev_all)
	_update_dev()

func _build_setup(layer: CanvasLayer) -> void:
	setup = PanelContainer.new()
	setup.position = Vector2(190, 70)
	setup.custom_minimum_size = Vector2(900, 580)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.16, 0.97)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(4)
	sb.border_color = Color("f0b43c")
	sb.set_content_margin_all(18)
	setup.add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	setup.add_child(v)
	title_lbl = Label.new()
	title_lbl.add_theme_font_size_override("font_size", 34)
	v.add_child(title_lbl)
	rule_lbl = Label.new()
	rule_lbl.add_theme_font_size_override("font_size", 17)
	rule_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule_lbl.custom_minimum_size = Vector2(860, 0)
	v.add_child(rule_lbl)
	var dl := Label.new()
	dl.text = "Difficulty"
	dl.add_theme_font_size_override("font_size", 20)
	v.add_child(dl)
	var drow := HBoxContainer.new()
	drow.add_theme_constant_override("separation", 8)
	v.add_child(drow)
	for d in Rules.DIFF_ORDER:
		var b := Button.new()
		b.toggle_mode = true
		b.text = "%s\nlives %d, HP x%.2f" % [Rules.DIFFICULTY[d].name, Rules.DIFFICULTY[d].lives, Rules.DIFFICULTY[d].hp]
		b.custom_minimum_size = Vector2(205, 58)
		b.add_theme_font_size_override("font_size", 15)
		b.pressed.connect(func(): Session.diff = d; _sync_setup())
		UiStyle.style_btn(b, Color("2f4a6b"), Color("d9892a"))
		drow.add_child(b)
		diff_btns[d] = b
	var ml := Label.new()
	ml.text = "Mutators (pick up to 3: harder and richer)"
	ml.add_theme_font_size_override("font_size", 20)
	v.add_child(ml)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 6)
	v.add_child(grid)
	for m in Rules.MUT_ORDER:
		var b := Button.new()
		b.toggle_mode = true
		b.text = "%s: %s" % [Rules.MUTATORS[m].name, Rules.MUTATORS[m].desc]
		b.custom_minimum_size = Vector2(425, 40)
		b.add_theme_font_size_override("font_size", 14)
		b.clip_text = true
		b.pressed.connect(func(): _toggle_mut(m))
		UiStyle.style_btn(b, Color("4a3a6b"), Color("c4552b"))
		grid.add_child(b)
		mut_btns[m] = b
	score_lbl = Label.new()
	score_lbl.add_theme_font_size_override("font_size", 18)
	v.add_child(score_lbl)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	v.add_child(row)
	var go := _btn("Begin", Vector2.ZERO, Vector2(260, 60), 28, Color("2f6b3a"), _begin)
	go.custom_minimum_size = Vector2(260, 60)
	var cancel := _btn("Cancel", Vector2.ZERO, Vector2(160, 60), 22, Color("6b3a3a"), func(): setup.visible = false)
	cancel.custom_minimum_size = Vector2(160, 60)
	row.add_child(go)
	row.add_child(cancel)
	setup.visible = false
	layer.add_child(setup)

func _toggle_mut(m: String) -> void:
	if m in Session.muts:
		Session.muts.erase(m)
	elif Session.muts.size() < 3:
		Session.muts.append(m)
	_sync_setup()

func _sync_setup() -> void:
	for d in diff_btns:
		diff_btns[d].set_pressed_no_signal(Session.diff == d)
	for m in mut_btns:
		mut_btns[m].set_pressed_no_signal(m in Session.muts)
	var mult := Session.score_mult()
	score_lbl.text = "Score multiplier x%.2f.   3 stars need: win with half your lives AND (Hard+ or 2+ mutators). Stars unlock new allies!" % mult

func _open_setup(id: String) -> void:
	setup_level = id
	var lv: Dictionary = Levels.LEVELS[id]
	title_lbl.text = lv.name
	rule_lbl.text = "%s\n%s" % [lv.blurb, lv.rule]
	var gl := Session.goals_line(id)
	if gl != "":
		rule_lbl.text += "\n" + gl
	for d in Rules.DIFF_ORDER:
		diff_btns[d].text = "%s\n%s %d, HP x%.2f" % [Rules.DIFFICULTY[d].name, "gold" if lv.get("steal", false) else "lives", Rules.DIFFICULTY[d].lives, Rules.DIFFICULTY[d].hp]
	Session.muts = []
	_sync_setup()
	setup.visible = true

func _begin() -> void:
	Session.level_id = setup_level
	Session.daily = false
	Session.run_seed = 0
	Sfx.play(self, "click")
	get_tree().change_scene_to_file("res://main.tscn")

func _daily() -> void:
	var d := Time.get_date_dict_from_system()
	var seed_v := int(d.year) * 10000 + int(d.month) * 100 + int(d.day)
	var r := RandomNumberGenerator.new()
	r.seed = seed_v
	var id: String = Levels.ORDER[r.randi() % Levels.ORDER.size()]
	var pool := Rules.MUT_ORDER.duplicate()
	var picks := []
	for i in 2:
		var m: String = pool[r.randi() % pool.size()]
		pool.erase(m)
		picks.append(m)
	Session.level_id = id
	Session.diff = "hard"
	Session.muts = picks
	Session.run_seed = seed_v
	Session.daily = true
	get_tree().change_scene_to_file("res://main.tscn")

func _card_rect(i: int) -> Rect2:
	return Rect2(Vector2(24 + (i % 5) * 248, 126 + (i / 5) * 214), CARD)

func _process(delta: float) -> void:
	clock += delta
	hover = -1
	if mode == "levels" and not setup.visible and not settings_panel.visible:
		var m := get_global_mouse_position()
		for i in Levels.ORDER.size():
			if _card_rect(i).has_point(m):
				hover = i
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		if settings_panel.visible:
			settings_panel.visible = false
		elif setup.visible:
			setup.visible = false
		elif mode != "levels":
			mode = "levels"
			back_btn.visible = false

func _unhandled_input(ev: InputEvent) -> void:
	# Hit-test the tapped position directly: on touch screens a tap has no earlier hover frame.
	if ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT and mode == "levels" and (setup == null or not setup.visible):
		for i in Levels.ORDER.size():
			if _card_rect(i).has_point(ev.position):
				var id: String = Levels.ORDER[i]
				if Session.level_open(id):
					Sfx.play(self, "click")
					_open_setup(id)
				return

func _text(s: String, pos: Vector2, size: int, col: Color, width: float = -1.0, align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := ThemeDB.fallback_font
	draw_string_outline(f, pos, s, align, width, size, 8, Color("1d1230"))
	draw_string(f, pos, s, align, width, size, col)

func _draw() -> void:
	draw_rect(Rect2(0, 0, 1280, 720), Color("241a4a"))
	for i in 24:
		draw_rect(Rect2(0, i * 30, 1280, 31), Color("241a4a").lerp(Color("5a2f7a"), float(i) / 23.0))
	for i in 40:
		draw_circle(Vector2(fmod(i * 233.0, 1280.0), fmod(i * 97.0, 300.0)), 1.6 + (i % 3), Color(1, 1, 0.9, 0.5 + 0.5 * sin(clock * 2.0 + i)))
	if mode == "bestiary":
		_draw_bestiary()
		return
	_text("WELLFALL", Vector2(24, 76), 72, Color("ffe36a"))
	_text("Tower defense for the last Wells  -  10 levels, 20 creatures", Vector2(28, 104), 20, Color("e8d8ff"))
	for i in Levels.ORDER.size():
		_draw_card(i)
	var n_open := 0
	for k in Session.unlocked:
		n_open += 1
	_text("Allies befriended: %d/17   (clear levels to befriend creatures; 3 stars befriends a bonus one)" % n_open, Vector2(24, 574), 18, Color("ffd23a"))
	# parade of creatures along the bottom
	for i in 7:
		var id: String = SPECIES[(i * 3 + int(clock / 8.0)) % SPECIES.size()]
		var x := fmod(clock * 55.0 + i * 190.0, 1500.0) - 100.0
		PuppetLib.draw(self, id, "walk", int(clock * 9.0 + i), false, 0.6, Vector2(x, 700))

func _draw_card(i: int) -> void:
	var id: String = Levels.ORDER[i]
	var lv: Dictionary = Levels.LEVELS[id]
	var r := _card_rect(i)
	var open := Session.level_open(id)
	if i == hover:
		r = r.grow(6)
	var c: Dictionary = lv.colors
	draw_rect(r.grow(4), Color("1d1230"))
	for k in 8:
		var h := r.size.y * 0.62 / 8.0
		draw_rect(Rect2(r.position + Vector2(0, k * h), Vector2(r.size.x, h + 1)), Color(c.g1).lerp(Color(c.g2), float(k) / 7.0))
	var prev_h := r.size.y * 0.62
	if lv.has("art") and ResourceLoader.exists(String(lv.art)):
		if not _art.has(id):
			_art[id] = load(String(lv.art))
		draw_texture_rect(_art[id], Rect2(r.position, Vector2(r.size.x, prev_h)), false)
	for path in ([] if lv.has("art") else lv.paths):
		var pts := PackedVector2Array()
		for q in path:
			pts.append(r.position + Vector2(clampf(q[0], 0, 1280) / 1280.0 * (r.size.x - 20) + 10, 8 + clampf(q[1], 0, 720) / 720.0 * (prev_h - 16)))
		draw_polyline(pts, Color(c.edge), 11.0, true)
		draw_polyline(pts, Color(c.path), 7.0, true)
	for s in ([] if lv.has("art") else lv.stones):
		draw_circle(r.position + Vector2(s[0] / 1280.0 * (r.size.x - 20) + 10, 8 + s[1] / 720.0 * (prev_h - 16)), 3.0, TypeChart.COLORS[s[2]])
	draw_rect(Rect2(r.position + Vector2(0, prev_h), Vector2(r.size.x, r.size.y - prev_h)), Color(0.08, 0.06, 0.14, 0.95))
	_text("%d. %s" % [i + 1, lv.name], r.position + Vector2(8, prev_h + 24), 19, Color.WHITE)
	var st := int(Session.stars.get(id, 0))
	_text("★".repeat(st) + "☆".repeat(3 - st), r.position + Vector2(8, prev_h + 48), 20, Color("ffd23a"))
	var bw := int(Session.best_wave.get(id, 0))
	_text("Best wave %d" % bw if bw > 0 else "New", r.position + Vector2(112, prev_h + 48), 15, Color("c8d8f0"))
	var lanes: int = lv.paths.size()
	_text("%d lane%s" % [lanes, "s" if lanes > 1 else ""] + (", " + lv.style), r.position + Vector2(8, prev_h + 68), 13, Color("a8b8d8"))
	if not open:
		draw_rect(r, Color(0, 0, 0, 0.62))
		_text("Locked", r.position + Vector2(0, r.size.y * 0.4), 28, Color("e8e8f8"), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)
		_text("clear level %d" % i, r.position + Vector2(0, r.size.y * 0.4 + 28), 16, Color("c8c8e0"), r.size.x, HORIZONTAL_ALIGNMENT_CENTER)

func _draw_bestiary() -> void:
	_text("Bestiary: 20 creatures", Vector2(24, 60), 40, Color("ffe36a"))
	for i in SPECIES.size():
		var id: String = SPECIES[i]
		var col := i % 5
		var row := i / 5
		var r := Rect2(Vector2(16 + col * 252, 96 + row * 152), Vector2(244, 144))
		draw_rect(r.grow(3), Color("1d1230"))
		draw_rect(r, Color("33265a"))
		var d: Dictionary = Creatures.TOWERS.get(id, Creatures.TOWERS.get("ally_" + id, {}))
		var e: Dictionary = Creatures.ENEMIES.get(id, {})
		var types: Array = d.get("types", e.get("types", []))
		PuppetLib.draw(self, id, "idle", int(clock * 6.0 + i), false, 0.7, r.position + Vector2(64, 112))
		_text(String(d.get("name", e.get("name", id))), r.position + Vector2(112, 26), 20, Color.WHITE)
		for t in types.size():
			draw_circle(r.position + Vector2(120 + t * 70, 44), 6.0, TypeChart.COLORS[types[t]])
			_text(String(types[t]).capitalize(), r.position + Vector2(130 + t * 70, 49), 13, Color("e0e0f8"))
		var blurb := String(BLURBS.get(id, e.get("blurb", "")))
		draw_multiline_string(ThemeDB.fallback_font, r.position + Vector2(112, 70), blurb, HORIZONTAL_ALIGNMENT_LEFT, 124, 12, 5, Color("d8d0f0"))
