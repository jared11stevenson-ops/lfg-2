class_name BuildMenu
extends PanelBase
## Building list from data/buildings.json with costs (red = short) and a placement section. Picking a building emits
## building_picked (the stage then shows the ghost via BuildPreview.follow and feeds back set_placement()).
## Place emits build_confirmed(building_id, holding_id, hex); the lead turns that into a `build` command with
## UiCommands.build(building_id, holding_id, hex). Upgrade rows skip placement and confirm immediately (hex = (-9999,-9999)).
signal building_picked(building_id: String)
signal build_confirmed(building_id: String, holding_id: int, hex: Vector2i)
signal placement_cancelled
var model: Dictionary = {}
var selected: String = ""
var placement: Dictionary = {}
var list_box: VBoxContainer
var place_btn: Button
var cancel_btn: Button
var buttons: Dictionary = {} # building id -> Button

func _init() -> void:
	super("BUILD", Vector2(840, 540))
	var sc: ScrollContainer = UiKit.scroll(300)
	body.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	sc.add_child(list_box)
	var foot := HBoxContainer.new()
	foot.add_theme_constant_override("separation", 12)
	body.add_child(foot)
	cancel_btn = UiKit.button("CANCEL", UiStyle.BAD, Vector2(160, 56))
	cancel_btn.pressed.connect(func() -> void:
		selected = ""
		placement = {}
		_refresh_footer()
		placement_cancelled.emit())
	foot.add_child(cancel_btn)
	place_btn = UiKit.button("PLACE HERE", UiStyle.GOOD, Vector2(240, 56))
	place_btn.pressed.connect(_on_place)
	foot.add_child(place_btn)
	_refresh_footer()

## Docked = compact strip at the bottom while the player walks the ghost into place.
var docked: bool = false
var _full_offsets: Array[float] = []
func set_docked(on: bool) -> void:
	if on == docked:
		return
	docked = on
	if on:
		_full_offsets = [offset_left, offset_right, offset_top, offset_bottom]
		list_box.get_parent().visible = false
		anchor_top = 1.0
		anchor_bottom = 1.0
		offset_left = -330.0
		offset_right = 330.0
		offset_top = -230.0
		offset_bottom = -110.0
		custom_minimum_size = Vector2(660, 120)
		title_label.text = "PLACING: %s" % Content.building(selected).get("name", "")
	else:
		list_box.get_parent().visible = true
		anchor_top = 0.5
		anchor_bottom = 0.5
		if _full_offsets.size() == 4:
			offset_left = _full_offsets[0]
			offset_right = _full_offsets[1]
			offset_top = _full_offsets[2]
			offset_bottom = _full_offsets[3]
		custom_minimum_size = Vector2(840, 540)
		title_label.text = "BUILD"

func set_model(m: Dictionary) -> void:
	model = m
	UiKit.clear(list_box)
	buttons.clear()
	if int(m.get("holding_id", -1)) >= 0:
		list_box.add_child(UiStyle.label("Building at %s" % m["holding_name"], 20, UiStyle.GOOD, false))
	else:
		list_box.add_child(UiStyle.label("No holding of yours is within 3 hexes - walk home to build.", 20, UiStyle.WARN, false))
	for r in m.get("rows", []):
		list_box.add_child(_row(r))
	_refresh_footer()

func _row(r: Dictionary) -> Control:
	var card: PanelContainer = UiKit.card(Color(0.16, 0.1, 0.28, 0.9) if r["id"] != selected else Color(0.1, 0.3, 0.3, 0.95))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 12)
	card.add_child(h)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	info.add_child(UiStyle.label("%s   (%d/%d here)" % [r["name"], int(r["count_here"]), int(r["max"])], 24, UiStyle.TEXT, false))
	info.add_child(UiKit.cost_row(r["cost"]))
	if String(r["info"]) != "":
		info.add_child(UiStyle.label(String(r["info"]), 16, Color(1, 1, 1, 0.7), false))
	if String(r["reason"]) != "":
		info.add_child(UiStyle.label(PanelModels.reason_text(String(r["reason"])), 16, UiStyle.WARN, false))
	var b: Button = UiKit.button("UPGRADE" if bool(r.get("upgrade", false)) else "SELECT", UiStyle.GOOD if bool(r.get("upgrade", false)) else UiStyle.PURPLE, Vector2(150, 56))
	b.disabled = not bool(r["buildable"])
	b.pressed.connect(func() -> void:
		if bool(r.get("upgrade", false)):
			build_confirmed.emit(String(r["id"]), int(model.get("holding_id", -1)), Vector2i(-9999, -9999))
		else:
			pick(String(r["id"])))
	buttons[String(r["id"])] = b
	h.add_child(b)
	return card

func pick(building_id: String) -> void:
	selected = building_id
	placement = {}
	building_picked.emit(building_id)
	set_model(model)

## Fed by the stage every time the ghost's validity changes: {valid, reason, holding_id}.
func set_placement(p: Dictionary) -> void:
	placement = p
	_refresh_footer()

func _refresh_footer() -> void:
	if place_btn == null:
		return
	var ok: bool = selected != "" and bool(placement.get("valid", false))
	place_btn.disabled = not ok
	cancel_btn.disabled = selected == ""
	if selected == "":
		set_status("Pick a building, then walk so the ghost sits where you want it.", UiStyle.TEXT)
	elif ok:
		set_status("%s: valid spot." % Content.building(selected).get("name", selected), UiStyle.GOOD)
	else:
		set_status(PanelModels.reason_text(String(placement.get("reason", "no_own_holding_nearby"))), UiStyle.BAD)

func _on_place() -> void:
	if selected != "" and bool(placement.get("valid", false)):
		build_confirmed.emit(selected, int(placement.get("holding_id", -1)), placement.get("hex", Vector2i(-9999, -9999)))
