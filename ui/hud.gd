class_name Hud
extends CanvasLayer
## Landscape HUD. Pure view: feed it a model dictionary via set_model() (see ui/hud_binder.gd for MatchState -> model).
## model keys: day:int, time_of_day:float 0..1, phase:StringName, hint:String, rations:int, rations_per_day:int,
##   class_label:String, hp:float, hp_max:float, inventory:Array[{id,name,count,color}], prompt:String
signal bag_toggled(open: bool)
## The bag's EAT / USE button for food, tonics and boons. The lead maps it to UiCommands.eat(item). (Pass 4: before this the bag was read-only and `eat` had no UI.)
signal item_use_requested(item_id: String)

var model: Dictionary = {}
var bag_open: bool = false
var root: Control
var banner: PanelContainer
var banner_title: Label
var banner_sub: Label
var tod_bar: ProgressBar
var class_chip: PanelContainer
var class_label: Label
var hp_bar: ProgressBar
var rations_chip: PanelContainer
var rations_label: Label
var rations_sub: Label
var tracker_chip: PanelContainer
var tracker_label: Label
var pets_chip: PanelContainer
var pets_label: Label
var prompt_chip: PanelContainer
var prompt_label: Label
var hotbar: HBoxContainer
var bag_panel: PanelContainer
var bag_grid: GridContainer
var toast_box: VBoxContainer
var purge_veil: ColorRect
var _pulse_t: float = 0.0
var _banner_style: StyleBoxFlat
var _last_phase: StringName = &""
const HOTBAR_SLOTS := 6

func _init() -> void:
	name = "Hud"
	layer = 5

func _ready() -> void:
	_build()
	if model.is_empty():
		model = {"day": 1, "time_of_day": 0.4, "phase": &"PEACE", "rations": 0, "rations_per_day": 1, "class_label": "", "hp": 1.0, "hp_max": 1.0, "inventory": [], "prompt": ""}
	set_model(model)

func _build() -> void:
	root = Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# Purge veil (edge vignette, sits under all HUD widgets)
	purge_veil = ColorRect.new()
	purge_veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	purge_veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float amount = 0.0;\nuniform vec3 tint : source_color = vec3(0.55,0.0,0.4);\nvoid fragment(){ vec2 q = UV-0.5; float v = smoothstep(0.18, 0.75, length(q*vec2(1.0,1.25))); COLOR = vec4(tint, v*amount*0.75); }"
	sm.shader = sh
	purge_veil.material = sm
	root.add_child(purge_veil)
	_build_banner()
	_build_class_chip()
	_build_rations()
	_build_tracker()
	_build_pets_chip()
	_build_prompt()
	_build_hotbar()
	_build_bag()
	toast_box = VBoxContainer.new()
	toast_box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_box.position = Vector2(-220, 118)
	toast_box.custom_minimum_size = Vector2(440, 0)
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.alignment = BoxContainer.ALIGNMENT_BEGIN
	root.add_child(toast_box)

func _build_banner() -> void:
	banner = PanelContainer.new()
	banner.name = "PhaseBanner"
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -190
	banner.offset_right = 190
	banner.offset_top = 14
	banner.offset_bottom = 104
	_banner_style = UiStyle.box(UiStyle.PHASE_COLORS[&"PEACE"], UiStyle.PANEL_EDGE, 18, 3)
	banner.add_theme_stylebox_override("panel", _banner_style)
	root.add_child(banner)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_theme_constant_override("separation", 0)
	banner.add_child(v)
	banner_title = UiStyle.label("DAY 1  -  PEACE", 34)
	banner_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(banner_title)
	banner_sub = UiStyle.label("", 18)
	banner_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(banner_sub)
	tod_bar = ProgressBar.new()
	tod_bar.show_percentage = false
	tod_bar.custom_minimum_size = Vector2(0, 8)
	tod_bar.max_value = 1.0
	tod_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tod_bar.add_theme_stylebox_override("background", UiStyle.box(Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), 4, 0))
	tod_bar.add_theme_stylebox_override("fill", UiStyle.box(Color(1, 1, 1, 0.85), Color(0, 0, 0, 0), 4, 0))
	v.add_child(tod_bar)

func _build_class_chip() -> void:
	class_chip = PanelContainer.new()
	class_chip.name = "ClassChip"
	class_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	class_chip.position = Vector2(20, 14)
	class_chip.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL))
	root.add_child(class_chip)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	class_chip.add_child(v)
	class_label = UiStyle.label("CLASS", 24)
	v.add_child(class_label)
	hp_bar = ProgressBar.new()
	hp_bar.show_percentage = false
	hp_bar.custom_minimum_size = Vector2(210, 14)
	hp_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hp_bar.add_theme_stylebox_override("background", UiStyle.box(Color(0, 0, 0, 0.5), Color(0, 0, 0, 0), 6, 0))
	hp_bar.add_theme_stylebox_override("fill", UiStyle.box(UiStyle.BAD, Color(0, 0, 0, 0), 6, 0))
	v.add_child(hp_bar)

func _build_rations() -> void:
	rations_chip = PanelContainer.new()
	rations_chip.name = "RationsChip"
	rations_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rations_chip.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	rations_chip.anchor_left = 1.0
	rations_chip.anchor_right = 1.0
	rations_chip.offset_left = -250
	rations_chip.offset_right = -20
	rations_chip.offset_top = 14
	rations_chip.add_theme_stylebox_override("panel", UiStyle.box(UiStyle.PANEL))
	root.add_child(rations_chip)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rations_chip.add_child(v)
	rations_label = UiStyle.label("RATIONS 0", 26)
	rations_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(rations_label)
	rations_sub = UiStyle.label("", 16)
	rations_sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	v.add_child(rations_sub)

## Companion line under the rations chip ("Pets: Mossbun, Dewsnail (hungry)"). Hidden when you have none.
func _build_pets_chip() -> void:
	pets_chip = PanelContainer.new()
	pets_chip.name = "PetsChip"
	pets_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pets_chip.position = Vector2(1000, 98)
	pets_chip.custom_minimum_size = Vector2(260, 0)
	pets_chip.add_theme_stylebox_override("panel", UiStyle.box(Color(0.10, 0.06, 0.18, 0.7), UiStyle.PURPLE, 12, 2))
	pets_chip.visible = false
	root.add_child(pets_chip)
	pets_label = UiStyle.label("", 17, UiStyle.TEXT, false)
	pets_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	pets_label.custom_minimum_size = Vector2(240, 0)
	pets_chip.add_child(pets_label)

## Quest tracker: the active quest's current step, under the class chip. Hidden when there is nothing to track.
func _build_tracker() -> void:
	tracker_chip = PanelContainer.new()
	tracker_chip.name = "QuestTracker"
	tracker_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tracker_chip.position = Vector2(20, 82)
	tracker_chip.custom_minimum_size = Vector2(260, 0)
	tracker_chip.add_theme_stylebox_override("panel", UiStyle.box(Color(0.10, 0.06, 0.18, 0.7), UiStyle.GOOD, 12, 2))
	tracker_chip.visible = false
	root.add_child(tracker_chip)
	tracker_label = UiStyle.label("", 17, UiStyle.TEXT, false)
	tracker_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tracker_label.custom_minimum_size = Vector2(240, 0)
	tracker_chip.add_child(tracker_label)

func _build_prompt() -> void:
	prompt_chip = PanelContainer.new()
	prompt_chip.name = "Prompt"
	prompt_chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt_chip.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_chip.anchor_left = 0.5
	prompt_chip.anchor_right = 0.5
	prompt_chip.anchor_top = 1.0
	prompt_chip.anchor_bottom = 1.0
	prompt_chip.offset_left = -200
	prompt_chip.offset_right = 200
	prompt_chip.offset_top = -158
	prompt_chip.offset_bottom = -104
	prompt_chip.grow_horizontal = Control.GROW_DIRECTION_BOTH
	prompt_chip.add_theme_stylebox_override("panel", UiStyle.box(Color(0.1, 0.05, 0.2, 0.88), UiStyle.WARN, 22, 3))
	prompt_chip.visible = false
	root.add_child(prompt_chip)
	prompt_label = UiStyle.label("", 26)
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_chip.add_child(prompt_label)

func _build_hotbar() -> void:
	hotbar = HBoxContainer.new()
	hotbar.name = "Hotbar"
	hotbar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hotbar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	hotbar.anchor_left = 0.5
	hotbar.anchor_right = 0.5
	hotbar.anchor_top = 1.0
	hotbar.anchor_bottom = 1.0
	hotbar.offset_left = -215
	hotbar.offset_right = 215
	hotbar.offset_top = -92
	hotbar.offset_bottom = -20
	hotbar.add_theme_constant_override("separation", 8)
	hotbar.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_child(hotbar)
	for i in HOTBAR_SLOTS:
		hotbar.add_child(_make_slot(i))

func _make_slot(_i: int) -> PanelContainer:
	var p := PanelContainer.new()
	p.custom_minimum_size = Vector2(64, 64)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_theme_stylebox_override("panel", UiStyle.box(Color(0.1, 0.05, 0.2, 0.7), Color(1, 1, 1, 0.35), 10, 2))
	var c := Control.new()
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(c)
	var sw := ColorRect.new()
	sw.name = "Swatch"
	sw.position = Vector2(13, 6)
	sw.size = Vector2(36, 36)
	sw.mouse_filter = Control.MOUSE_FILTER_IGNORE
	sw.visible = false
	c.add_child(sw)
	var g := UiStyle.label("", 22, Color("1d1030"), false)
	g.name = "Glyph"
	g.position = Vector2(26, 7)
	c.add_child(g)
	var n := UiStyle.label("", 18)
	n.name = "Count"
	n.position = Vector2(36, 34)
	c.add_child(n)
	return p

func _build_bag() -> void:
	bag_panel = PanelContainer.new()
	bag_panel.name = "BagPanel"
	bag_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	bag_panel.set_anchors_preset(Control.PRESET_CENTER)
	bag_panel.anchor_left = 0.5
	bag_panel.anchor_right = 0.5
	bag_panel.anchor_top = 0.5
	bag_panel.anchor_bottom = 0.5
	bag_panel.offset_left = -330
	bag_panel.offset_right = 330
	bag_panel.offset_top = -210
	bag_panel.offset_bottom = 210
	bag_panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.08, 0.04, 0.16, 0.93), UiStyle.PANEL_EDGE, 20, 3))
	bag_panel.visible = false
	root.add_child(bag_panel)
	var v := VBoxContainer.new()
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag_panel.add_child(v)
	v.add_child(UiStyle.label("INVENTORY", 28, UiStyle.WARN))
	var bag_scroll: ScrollContainer = UiKit.scroll(300)
	v.add_child(bag_scroll)
	bag_grid = GridContainer.new()
	bag_grid.columns = 3
	bag_grid.add_theme_constant_override("h_separation", 28)
	bag_grid.add_theme_constant_override("v_separation", 4)
	bag_grid.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bag_scroll.add_child(bag_grid)

func toggle_bag() -> void:
	set_bag_open(not bag_open)

func set_bag_open(open: bool) -> void:
	bag_open = open
	bag_panel.visible = open
	bag_toggled.emit(open)

func set_model(m: Dictionary) -> void:
	model = m
	if banner == null:
		return
	var phase: StringName = m.get("phase", &"PEACE")
	var title: String = UiStyle.PHASE_TITLES.get(phase, str(phase))
	banner_title.text = "DAY %d  -  %s" % [int(m.get("day", 1)), title]
	var hint: String = m.get("hint", "")
	if hint == "":
		hint = _default_hint(phase, int(m.get("day", 1)))
	banner_sub.text = hint
	var bg: Color = UiStyle.PHASE_COLORS.get(phase, UiStyle.PHASE_COLORS[&"PEACE"])
	var fg: Color = UiStyle.PHASE_TEXT_COLORS.get(phase, Color.WHITE)
	_banner_style.bg_color = bg
	_banner_style.border_color = bg.lightened(0.5)
	banner_title.add_theme_color_override("font_color", fg)
	banner_sub.add_theme_color_override("font_color", fg)
	var outline: Color = UiStyle.INK if fg.v > 0.6 else Color(1, 1, 1, 0.0)
	banner_title.add_theme_color_override("font_outline_color", outline)
	banner_sub.add_theme_color_override("font_outline_color", outline)
	tod_bar.value = float(m.get("time_of_day", 0.0))
	_last_phase = phase
	class_label.text = String(m.get("class_label", "")).to_upper()
	class_chip.visible = class_label.text != ""
	hp_bar.max_value = maxf(float(m.get("hp_max", 1.0)), 1.0)
	hp_bar.value = float(m.get("hp", 1.0))
	var rat: int = int(m.get("rations", 0))
	var per_day: int = maxi(int(m.get("rations_per_day", 1)), 1)
	rations_label.text = "RATIONS  %d" % rat
	var days_left: float = float(rat) / float(per_day)
	rations_sub.text = "feeds %d/day  -  %.1f days" % [per_day, days_left]
	var rc: Color = UiStyle.GOOD
	if days_left < 1.0:
		rc = UiStyle.BAD
	elif days_left < 3.0:
		rc = UiStyle.WARN
	rations_label.add_theme_color_override("font_color", rc)
	var trk: String = String(m.get("quest_tracker", ""))
	tracker_chip.visible = trk != ""
	tracker_label.text = trk
	var pets: String = String(m.get("companions", ""))
	pets_chip.visible = pets != ""
	pets_label.text = "Pets: " + pets
	var prompt: String = m.get("prompt", "")
	prompt_chip.visible = prompt != ""
	prompt_label.text = prompt
	_refresh_inventory(m.get("inventory", []))
	(purge_veil.material as ShaderMaterial).set_shader_parameter("amount", 1.0 if phase == &"PURGE_ACTIVE" else (0.35 if phase == &"WARNING" else 0.0))

func _default_hint(phase: StringName, day: int) -> String:
	match phase:
		&"PEACE": return "Farm, build, trade. Purge in %d days" % maxi(7 - day, 0)
		&"WARNING": return "Prepare! The Purge begins at dusk"
		&"PURGE_ACTIVE": return "NO LAW. Survive until dawn"
		&"RESOLUTION": return "Settling losses..."
	return ""

func _refresh_inventory(inv: Array) -> void:
	for i in HOTBAR_SLOTS:
		var slot: PanelContainer = hotbar.get_child(i)
		var c: Control = slot.get_child(0)
		var sw: ColorRect = c.get_node("Swatch")
		var g: Label = c.get_node("Glyph")
		var n: Label = c.get_node("Count")
		if i < inv.size():
			var it: Dictionary = inv[i]
			sw.visible = true
			sw.color = it.get("color", Color.WHITE)
			g.text = String(it.get("name", "?")).substr(0, 1).to_upper()
			n.text = str(int(it.get("count", 1)))
		else:
			sw.visible = false
			g.text = ""
			n.text = ""
	for ch in bag_grid.get_children():
		ch.queue_free()
	for it in inv:
		var row := HBoxContainer.new()
		row.mouse_filter = Control.MOUSE_FILTER_IGNORE
		var sw2 := ColorRect.new()
		sw2.custom_minimum_size = Vector2(22, 22)
		sw2.color = it.get("color", Color.WHITE)
		sw2.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(sw2)
		row.add_child(UiStyle.label("  %s" % String(it.get("name", "?")), 22))
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		bag_grid.add_child(row)
		bag_grid.add_child(UiStyle.label("x%d" % int(it.get("count", 1)), 22, UiStyle.WARN))
		var idef: Dictionary = Content.item(String(it.get("id", "")))
		if idef.has("food") or idef.has("heal") or idef.has("buff"):
			var ub: Button = UiKit.button("EAT" if idef.has("food") else "USE", UiStyle.GOOD, Vector2(100, 56), 20)
			var iid: String = String(it.get("id", ""))
			ub.pressed.connect(func() -> void: item_use_requested.emit(iid))
			bag_grid.add_child(ub)
		else:
			var sp := Control.new()
			sp.custom_minimum_size = Vector2(100, 0)
			sp.mouse_filter = Control.MOUSE_FILTER_IGNORE
			bag_grid.add_child(sp)

func toast(text: String, color: Color = UiStyle.WARN, seconds: float = 3.0) -> void:
	if toast_box == null:
		return
	var l := UiStyle.label(text, 22, color)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_box.add_child(l)
	while toast_box.get_child_count() > 3:
		toast_box.get_child(0).queue_free()
		toast_box.remove_child(toast_box.get_child(0))
	var tw := l.create_tween()
	tw.tween_interval(seconds)
	tw.tween_property(l, "modulate:a", 0.0, 0.6)
	tw.tween_callback(l.queue_free)

func _process(dt: float) -> void:
	if banner == null:
		return
	_pulse_t += dt
	if _last_phase == &"PURGE_ACTIVE":
		var k: float = 0.5 + 0.5 * sin(_pulse_t * 5.0)
		_banner_style.bg_color = UiStyle.PHASE_COLORS[&"PURGE_ACTIVE"].lerp(Color("ff3a5c"), k * 0.5)
		banner.scale = Vector2.ONE * (1.0 + 0.015 * k)
		banner.pivot_offset = banner.size * 0.5
	else:
		banner.scale = Vector2.ONE
