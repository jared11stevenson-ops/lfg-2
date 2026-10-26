class_name HoldingPanel
extends PanelBase
## Holding management: every holding you own, its stores/garrison/buildings, with SHORTAGES highlighted in red
## (rations under 1 day per garrison, no garrison, barracks without coin, faction starving).
## Emits store_requested(holding_id, side:"deposit"|"withdraw", item, qty) and demolish_requested(holding_id, building_id).
signal store_requested(holding_id: int, side: String, item: String, qty: int)
signal demolish_requested(holding_id: int, building_id: String)
const FLAG_TEXT: Dictionary = {"rations": "LOW RATIONS", "undefended": "NO GARRISON", "coin": "NO RECRUIT COIN", "starving": "STARVING"}
var model: Dictionary = {}
var list_box: VBoxContainer
var flagged_rows: int = 0

func _init() -> void:
	super("HOLDINGS", Vector2(900, 560))
	var sc: ScrollContainer = UiKit.scroll(380)
	body.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	sc.add_child(list_box)

func set_model(m: Dictionary) -> void:
	model = m
	UiKit.clear(list_box)
	flagged_rows = 0
	var n: int = int(m.get("shortages", 0))
	set_status("%d shortage warning(s)." % n if n > 0 else "All holdings are supplied.", UiStyle.BAD if n > 0 else UiStyle.GOOD)
	for r in m.get("rows", []):
		list_box.add_child(_row(r))
	if (m.get("rows", []) as Array).is_empty():
		list_box.add_child(UiStyle.label("You hold no villages. Capture one during the Purge.", 22, UiStyle.WARN, false))

func _row(r: Dictionary) -> Control:
	var flags: Array = r["flags"]
	var bad: bool = not flags.is_empty()
	if bad:
		flagged_rows += 1
	var card: PanelContainer = UiKit.card(Color(0.35, 0.05, 0.12, 0.92) if bad else Color(0.16, 0.1, 0.28, 0.9))
	var v := VBoxContainer.new()
	card.add_child(v)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 8)
	v.add_child(top)
	var nm: Label = UiStyle.label("%s   tier %d   garrison %d   rations %d (%s)" % [r["name"], int(r["tier"]), int(r["garrison"]), int(r["rations"]), "enough" if float(r["ration_days"]) >= 1.0 else "%.1f d" % float(r["ration_days"])], 20, UiStyle.TEXT, false)
	nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(nm)
	for f in flags:
		top.add_child(UiKit.chip(String(FLAG_TEXT.get(f, f)), UiStyle.BAD))
	var stock := HBoxContainer.new()
	stock.add_theme_constant_override("separation", 6)
	v.add_child(stock)
	for it in r["items"]:
		stock.add_child(UiKit.chip("%s %d" % [it["name"], int(it["count"])], UiKit.item_color(String(it["item"])), 16))
	var acts := HBoxContainer.new()
	acts.add_theme_constant_override("separation", 8)
	v.add_child(acts)
	var near: bool = bool(r["near"])
	var hid: int = int(r["id"])
	var dep: Button = UiKit.button("DEPOSIT RATIONS", UiStyle.GOOD, Vector2(220, 56), 18)
	dep.disabled = not near or int(r["player_rations"]) < 1
	dep.pressed.connect(func() -> void: store_requested.emit(hid, "deposit", Economy.RATION, mini(5, int(r["player_rations"]))))
	acts.add_child(dep)
	var wd: Button = UiKit.button("TAKE RATIONS", UiStyle.PURPLE, Vector2(200, 56), 18)
	wd.disabled = not near or int(r["rations"]) < 1
	wd.pressed.connect(func() -> void: store_requested.emit(hid, "withdraw", Economy.RATION, mini(5, int(r["rations"]))))
	acts.add_child(wd)
	if not near:
		acts.add_child(UiStyle.label("Walk to the village to move goods.", 16, Color(1, 1, 1, 0.6), false))
	return card
