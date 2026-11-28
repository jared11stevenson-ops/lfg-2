extends PanelContainer
# Settings + pause overlay. mode "pause" adds Resume / Restart / Levels buttons. Shared by menu and battle.
const Session = preload("res://session.gd")
const Sfx = preload("res://sfx.gd")
const UiStyle = preload("res://ui_style.gd")
signal resume
signal restart
signal levels
signal closed
var mode := "menu"

func _ready() -> void:
	custom_minimum_size = Vector2(520, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.16, 0.98)
	sb.set_corner_radius_all(20)
	sb.set_border_width_all(4)
	sb.border_color = Color("f0b43c")
	sb.set_content_margin_all(22)
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	add_child(v)
	var t := Label.new()
	t.text = "Paused" if mode == "pause" else "Settings"
	t.add_theme_font_size_override("font_size", 38)
	v.add_child(t)
	v.add_child(_slider("Music", "music"))
	v.add_child(_slider("Effects", "sfx"))
	v.add_child(_toggle("Haptics (vibration)", "haptics"))
	v.add_child(_toggle("Screen shake", "shake"))
	v.add_child(_toggle("Damage numbers", "damage_text"))
	v.add_child(_toggle("Auto-start waves", "auto_wave"))
	v.add_child(_toggle("Low graphics (smoother on slow phones)", "low_gfx"))
	if mode == "pause":
		v.add_child(_btn("Resume", Color("2f6b3a"), func(): resume.emit()))
		v.add_child(_btn("Restart level", Color("8a5a1a"), func(): restart.emit()))
		v.add_child(_btn("Back to levels", Color("6b3a3a"), func(): levels.emit()))
	else:
		v.add_child(_btn("Done", Color("2f6b3a"), func(): closed.emit()))
	visible = false

func _btn(text: String, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 58)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	UiStyle.style_btn(b, col, col)
	return b

func _slider(label: String, key: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 14)
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(120, 0)
	l.add_theme_font_size_override("font_size", 24)
	row.add_child(l)
	var sl := HSlider.new()
	sl.min_value = 0.0
	sl.max_value = 1.0
	sl.step = 0.05
	sl.value = float(Session.settings[key])
	sl.custom_minimum_size = Vector2(300, 44)
	sl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	sl.value_changed.connect(func(val):
		Session.settings[key] = val
		Sfx.apply_volumes()
		Session.save_prefs())
	row.add_child(sl)
	return row

func _toggle(label: String, key: String) -> Control:
	var b := CheckButton.new()
	b.text = label
	b.button_pressed = bool(Session.settings[key])
	b.custom_minimum_size = Vector2(0, 50)
	b.add_theme_font_size_override("font_size", 24)
	b.toggled.connect(func(on):
		Session.settings[key] = on
		Session.save_prefs()
		if key == "haptics" and on:
			Sfx.haptic(40))
	return b
