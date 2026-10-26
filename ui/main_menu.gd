class_name MainMenu
extends Control
## Title screen: NEW MATCH / CONTINUE / OPTIONS / QUIT. Emits signals only. `set_save_info()` enables CONTINUE.
signal new_match_pressed
signal continue_pressed
signal quit_pressed
signal options_changed(options: Dictionary) # {shadows:bool, tilt_shift:bool}
var new_btn: Button
var continue_btn: Button
var options_btn: Button
var quit_btn: Button
var save_label: Label
var shadows_check: CheckButton
var tilt_check: CheckButton
var options_box: VBoxContainer
var preview: CharacterPreview
var options: Dictionary = {"shadows": false, "tilt_shift": true}
var _t: float = 0.0
var _ids: Array[String] = []
var _idx: int = 0

func _init() -> void:
	name = "MainMenu"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("23104a")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nvoid fragment(){ vec3 a = vec3(0.10,0.04,0.26); vec3 b = vec3(0.95,0.32,0.55); vec3 c = vec3(1.0,0.78,0.35); float y = UV.y; vec3 col = mix(a, b, smoothstep(0.1, 0.75, y)); col = mix(col, c, smoothstep(0.7, 1.0, y)); COLOR = vec4(col, 1.0); }"
	sm.shader = sh
	bg.material = sm
	add_child(bg)
	var row := HBoxContainer.new()
	row.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	row.offset_left = 60
	row.offset_right = -60
	row.offset_top = 30
	row.offset_bottom = -30
	row.add_theme_constant_override("separation", 30)
	add_child(row)
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.alignment = BoxContainer.ALIGNMENT_CENTER
	left.add_theme_constant_override("separation", 12)
	row.add_child(left)
	var title: Label = UiStyle.label("LFG!", 120, Color("ffe84a"))
	left.add_child(title)
	left.add_child(UiStyle.label("LAST FARM STANDING", 40, Color("19e0c8")))
	left.add_child(UiStyle.label("Feed your people. Survive the Purge. One life, one world.", 20, UiStyle.TEXT, false))
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 16)
	left.add_child(sp)
	new_btn = UiKit.button("NEW MATCH", UiStyle.GOOD, Vector2(380, 70), 32)
	new_btn.pressed.connect(func() -> void: new_match_pressed.emit())
	left.add_child(new_btn)
	continue_btn = UiKit.button("CONTINUE", UiStyle.PURPLE, Vector2(380, 70), 32)
	continue_btn.disabled = true
	continue_btn.pressed.connect(func() -> void: continue_pressed.emit())
	left.add_child(continue_btn)
	save_label = UiStyle.label("No saved match.", 18, Color(1, 1, 1, 0.75), false)
	left.add_child(save_label)
	var bot := HBoxContainer.new()
	bot.add_theme_constant_override("separation", 12)
	left.add_child(bot)
	options_btn = UiKit.button("OPTIONS", UiStyle.PURPLE, Vector2(184, 56), 22)
	options_btn.pressed.connect(func() -> void: options_box.visible = not options_box.visible)
	bot.add_child(options_btn)
	quit_btn = UiKit.button("QUIT", UiStyle.BAD, Vector2(184, 56), 22)
	quit_btn.pressed.connect(func() -> void: quit_pressed.emit())
	bot.add_child(quit_btn)
	options_box = VBoxContainer.new()
	options_box.visible = false
	left.add_child(options_box)
	shadows_check = CheckButton.new()
	shadows_check.text = "Shadows (slower on phones)"
	shadows_check.custom_minimum_size = Vector2(380, 56)
	shadows_check.add_theme_font_size_override("font_size", 22)
	shadows_check.toggled.connect(func(on: bool) -> void:
		options["shadows"] = on
		options_changed.emit(options.duplicate()))
	options_box.add_child(shadows_check)
	tilt_check = CheckButton.new()
	tilt_check.text = "Tilt-shift blur"
	tilt_check.button_pressed = true
	tilt_check.custom_minimum_size = Vector2(380, 56)
	tilt_check.add_theme_font_size_override("font_size", 22)
	tilt_check.toggled.connect(func(on: bool) -> void:
		options["tilt_shift"] = on
		options_changed.emit(options.duplicate()))
	options_box.add_child(tilt_check)
	preview = CharacterPreview.new(Vector2(420, 560))
	preview.size_flags_horizontal = Control.SIZE_SHRINK_END
	row.add_child(preview)
	_ids = CharacterKit.class_ids()
	preview.show_class(_ids[0])

func set_save_info(has_save: bool, text: String = "") -> void:
	continue_btn.disabled = not has_save
	save_label.text = text if has_save else "No saved match."

func _process(dt: float) -> void:
	_t += dt
	if _t > 4.0 and is_visible_in_tree():
		_t = 0.0
		_idx = (_idx + 1) % _ids.size()
		preview.show_class(_ids[_idx])
