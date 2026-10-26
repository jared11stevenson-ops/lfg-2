class_name ClassSelect
extends Control
## Class-select screen: a 14-card grid (name, role, WIP flag) and a detail pane with the turntable, stats, peace perk,
## purge kit (ability), weakness - all read from data/classes.json via Content. Plus seed entry.
## Signals: class_chosen(class_id) on selection, start_requested(class_id, seed), back_requested.
signal class_chosen(class_id: String)
signal start_requested(class_id: String, seed_value: int)
signal back_requested
var class_ids: Array[String] = []
var selected: String = ""
var seed_value: int = 1
var cards: Dictionary = {} # class id -> Button
var preview: CharacterPreview
var detail: VBoxContainer
var seed_edit: LineEdit
var start_btn: Button
var back_btn: Button
var warn_label: Label
var grid: GridContainer
var _rng := RandomNumberGenerator.new()

func _init() -> void:
	name = "ClassSelect"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.03, 0.14, 0.97)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(bg)
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		m.add_theme_constant_override("margin_" + side, 18)
	add_child(m)
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 8)
	m.add_child(outer)
	var top := HBoxContainer.new()
	outer.add_child(top)
	back_btn = UiKit.button("< BACK", UiStyle.BAD, Vector2(150, 56))
	back_btn.pressed.connect(func() -> void: back_requested.emit())
	top.add_child(back_btn)
	var t: Label = UiKit.heading("CHOOSE YOUR LEADER", 34)
	t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	top.add_child(t)
	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(150, 0)
	top.add_child(spacer)
	var mid := HBoxContainer.new()
	mid.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mid.add_theme_constant_override("separation", 14)
	outer.add_child(mid)
	var sc: ScrollContainer = UiKit.scroll(400)
	sc.size_flags_stretch_ratio = 1.5
	mid.add_child(sc)
	grid = GridContainer.new()
	grid.columns = 4
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(grid)
	var right := VBoxContainer.new()
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	right.size_flags_stretch_ratio = 1.4
	mid.add_child(right)
	var dcard: PanelContainer = UiKit.card(Color(0.12, 0.07, 0.22, 0.95))
	dcard.size_flags_vertical = Control.SIZE_EXPAND_FILL
	right.add_child(dcard)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 10)
	dcard.add_child(hb)
	preview = CharacterPreview.new(Vector2(210, 330))
	hb.add_child(preview)
	detail = VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	detail.add_theme_constant_override("separation", 4)
	hb.add_child(detail)
	warn_label = UiStyle.label("", 18, UiStyle.WARN, false)
	warn_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	right.add_child(warn_label)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 10)
	outer.add_child(foot)
	foot.add_child(UiStyle.label("WORLD SEED", 22, UiStyle.TEXT, false))
	seed_edit = LineEdit.new()
	seed_edit.custom_minimum_size = Vector2(220, 56)
	seed_edit.add_theme_font_size_override("font_size", 26)
	seed_edit.text = "1"
	seed_edit.max_length = 9
	seed_edit.virtual_keyboard_type = LineEdit.KEYBOARD_TYPE_NUMBER
	seed_edit.text_changed.connect(func(tx: String) -> void: seed_value = parse_seed(tx))
	foot.add_child(seed_edit)
	var rnd: Button = UiKit.button("RANDOM", UiStyle.PURPLE, Vector2(150, 56))
	rnd.pressed.connect(randomize_seed)
	foot.add_child(rnd)
	var fill := Control.new()
	fill.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(fill)
	start_btn = UiKit.button("PLAY", UiStyle.GOOD, Vector2(260, 64), 30)
	start_btn.pressed.connect(func() -> void: start_requested.emit(selected, seed_value))
	foot.add_child(start_btn)
	populate()

## Seed text -> int (digits only, clamped to 9 digits; empty/garbage -> 1).
static func parse_seed(text: String) -> int:
	var digits: String = ""
	for ch in text:
		if ch >= "0" and ch <= "9":
			digits += ch
	if digits == "":
		return 1
	return int(digits.substr(0, 9))

func randomize_seed() -> void:
	_rng.randomize()
	seed_value = _rng.randi_range(1, 999999999)
	seed_edit.text = str(seed_value)

static func role_split(class_name_text: String) -> Array[String]:
	var p: PackedStringArray = class_name_text.split("/")
	var out: Array[String] = []
	for s in p:
		out.append(s.strip_edges())
	while out.size() < 2:
		out.append("")
	return out

static func person_name(class_id: String) -> String:
	return class_id.get_slice("/", 1).capitalize()

func populate() -> void:
	UiKit.clear(grid)
	cards.clear()
	class_ids.clear()
	var ids: Array = Content.classes().keys()
	ids.sort_custom(func(a: String, b: String) -> bool:
		var ia: bool = bool(Content.class_def(a).get("implemented", false))
		var ib: bool = bool(Content.class_def(b).get("implemented", false))
		if ia != ib:
			return ia
		return a < b)
	for id in ids:
		class_ids.append(String(id))
		var cd: Dictionary = Content.class_def(String(id))
		var impl: bool = bool(cd.get("implemented", false))
		var roles: Array[String] = role_split(String(cd["name"]))
		var b: Button = UiKit.button("%s\n%s / %s%s" % [person_name(String(id)).to_upper(), roles[0], roles[1], "" if impl else "\n[WIP]"], UiStyle.PURPLE if impl else Color("77708a"), Vector2(150, 92), 18)
		b.pressed.connect(select.bind(String(id)))
		grid.add_child(b)
		cards[String(id)] = b
	if not class_ids.is_empty():
		select(class_ids[0])

func select(class_id: String) -> void:
	if not Content.classes().has(class_id):
		return
	selected = class_id
	for id in cards:
		var b: Button = cards[id]
		b.add_theme_color_override("font_color", UiStyle.WARN if id == class_id else UiStyle.TEXT)
		b.add_theme_stylebox_override("normal", UiStyle.box(Color("1f8a7a") if id == class_id else (Color("3a2a66") if bool(Content.class_def(id).get("implemented", false)) else Color("3a3648")), UiStyle.WARN if id == class_id else Color("b890ff"), 14, 4 if id == class_id else 2))
	_fill_detail(class_id)
	preview.show_class(class_id)
	class_chosen.emit(class_id)

func _fill_detail(class_id: String) -> void:
	UiKit.clear(detail)
	var cd: Dictionary = Content.class_def(class_id)
	var impl: bool = bool(cd.get("implemented", false))
	var roles: Array[String] = role_split(String(cd["name"]))
	detail.add_child(UiKit.heading(person_name(class_id).to_upper(), 34, UiStyle.TEXT))
	detail.add_child(UiStyle.label("Peace: %s   Purge: %s" % [roles[0], roles[1]], 20, UiStyle.GOOD, false))
	var st: Dictionary = cd["stats"]
	detail.add_child(UiStyle.label("HP %d   ATK %d   DEF %d   ENERGY %d" % [int(st["hp"]), int(st["atk"]), int(st["def"]), int(st["energy"])], 20, UiStyle.TEXT, false))
	detail.add_child(_line("PEACE PERK", String(cd["peace_perk"]), UiStyle.GOOD))
	var ab: Dictionary = cd.get("ability", {})
	var kit: String = String(cd["purge_kit"])
	if not ab.is_empty() and impl:
		kit += "  [%s: %d energy, %ds cooldown]" % [ab.get("name", ""), int(ab.get("energy", 0)), int(ab.get("cooldown", 0))]
	detail.add_child(_line("PURGE KIT", kit, UiStyle.BAD))
	detail.add_child(_line("WEAKNESS", String(cd["weakness"]), UiStyle.WARN))
	warn_label.text = "" if impl else "Not implemented yet: this leader's perk and ability have no effect in this build. You can still play with the base stats."
	start_btn.text = "PLAY" if impl else "PLAY (LIMITED)"

func _line(head: String, text: String, color: Color) -> Control:
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	v.add_child(UiStyle.label(head, 16, color, false))
	var l: Label = UiStyle.label(text, 18, UiStyle.TEXT, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(260, 0)
	v.add_child(l)
	return v
