class_name BCMenu
extends CanvasLayer
## Title / civilization select, battle prompt and game-over overlays.

signal picked(idx: int)
var difficulty := 1
signal fight
signal auto_resolve
signal restart
signal keep_watching

var root: Control

func _init() -> void:
	layer = 30

func _clear() -> void:
	if root != null: root.queue_free()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(root)

func _panel_style(a: float = 0.94) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.07, a)
	sb.set_corner_radius_all(10)
	sb.set_border_width_all(1)
	sb.border_color = Color(1, 0.85, 0.4, 0.35)
	sb.content_margin_left = 18; sb.content_margin_right = 18; sb.content_margin_top = 14; sb.content_margin_bottom = 14
	return sb

func show_title() -> void:
	_clear()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	panel.add_child(vb)
	var t := Label.new(); t.text = "THE WALL"; t.add_theme_font_size_override("font_size", 46); t.add_theme_color_override("font_color", Color("ffd35a")); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(t)
	var st := Label.new(); st.text = "Twelve bottled civilizations. Every night the jars lock. Pick yours."; st.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; st.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65)); vb.add_child(st)
	var how := Label.new()
	how.text = "Each day you have 3 actions: set policy, build, trade, send envoys, forge alliances or go to war.\nRaids are fought as turn-based hex battles. Win by completing the Great Work, allying with everyone (Concord), or annexing them all."
	how.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	how.add_theme_color_override("font_color", Color(0.65, 0.62, 0.55))
	vb.add_child(how)
	var dh := HBoxContainer.new(); dh.alignment = BoxContainer.ALIGNMENT_CENTER; dh.add_theme_constant_override("separation", 8); vb.add_child(dh)
	var dl := Label.new(); dl.text = "Difficulty:"; dh.add_child(dl)
	var group := ButtonGroup.new()
	for d in 3:
		var db := Button.new(); db.text = ["Easy (4 actions, gentler AI)", "Normal", "Hard (aggressive AI, faster rival wonders)"][d]
		db.toggle_mode = true; db.button_group = group; db.button_pressed = (d == difficulty)
		db.pressed.connect(func(): difficulty = d)
		dh.add_child(db)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	vb.add_child(grid)
	for i in BCData.RACES.size():
		var r: Dictionary = BCData.RACES[i]
		var b := Button.new()
		b.custom_minimum_size = Vector2(230, 96)
		b.text = "%s\n%s - %s\n%s" % [r.jar, r.name, r.skill, _style_of(r)]
		b.add_theme_color_override("font_color", r.color)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.tooltip_text = r.blurb
		b.pressed.connect(func(): _pick(i))
		grid.add_child(b)
	var sp := Button.new()
	sp.text = "Spectate (watch the AI)"
	sp.pressed.connect(func(): _pick(-1))
	vb.add_child(sp)
	var hint := Label.new(); hint.text = "Right-drag orbit, wheel zoom, WASD pan, Esc overview, space pause, 1-5 speed."; hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; hint.add_theme_color_override("font_color", Color(0.55, 0.52, 0.47)); vb.add_child(hint)

func _style_of(r: Dictionary) -> String:
	var tr: Dictionary = r.traits
	if tr.aggression >= 0.6: return "Playstyle: aggressive"
	if tr.openness >= 0.7: return "Playstyle: diplomatic"
	if r.mult.lore >= 1.3: return "Playstyle: scholarly"
	if r.mult.ore >= 1.3 or r.mult.goods >= 1.3: return "Playstyle: industrial"
	if r.mult.food >= 1.2: return "Playstyle: growth"
	return "Playstyle: cunning" if r.get("spy", false) else "Playstyle: balanced"

func _pick(i: int) -> void:
	root.queue_free()
	root = null
	picked.emit(i)

func show_battle_prompt(text: String) -> void:
	_clear()
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var l := Label.new(); l.text = text; l.add_theme_font_size_override("font_size", 20); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(l)
	var hb := HBoxContainer.new(); hb.alignment = BoxContainer.ALIGNMENT_CENTER; hb.add_theme_constant_override("separation", 12); vb.add_child(hb)
	var b1 := Button.new(); b1.text = "Fight in person (tactical)"; b1.pressed.connect(func(): _close(); fight.emit()); hb.add_child(b1)
	var b2 := Button.new(); b2.text = "Auto-resolve"; b2.pressed.connect(func(): _close(); auto_resolve.emit()); hb.add_child(b2)

func show_game_over(title: String, text: String, good: bool) -> void:
	_clear()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.02, 0.04, 0.7)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _panel_style())
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
	panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	root.add_child(panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 10)
	panel.add_child(vb)
	var t := Label.new(); t.text = title; t.add_theme_font_size_override("font_size", 42)
	t.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if good else Color(1.0, 0.5, 0.45)); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; vb.add_child(t)
	var l := Label.new(); l.text = text; l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; l.custom_minimum_size = Vector2(520, 0); l.autowrap_mode = TextServer.AUTOWRAP_WORD; vb.add_child(l)
	var hb := HBoxContainer.new(); hb.alignment = BoxContainer.ALIGNMENT_CENTER; hb.add_theme_constant_override("separation", 12); vb.add_child(hb)
	var b1 := Button.new(); b1.text = "New game"; b1.pressed.connect(func(): restart.emit()); hb.add_child(b1)
	var b2 := Button.new(); b2.text = "Keep watching"; b2.pressed.connect(func(): _close(); keep_watching.emit()); hb.add_child(b2)

func _close() -> void:
	if root != null:
		root.queue_free()
		root = null
