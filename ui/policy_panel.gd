class_name PolicyPanel
extends PanelBase
## Ration policy (full/half/none) with food-days projection, plus per-holding stance (defend/raid).
## Emits policy_changed(key, value, holding_id) - holding_id is -1 for the faction-wide ration policy.
signal policy_changed(key: String, value: String, holding_id: int)
var model: Dictionary = {}
var ration_buttons: Dictionary = {} # value -> Button
var stance_buttons: Dictionary = {} # "hid:value" -> Button
var rations_box: VBoxContainer
var stance_box: VBoxContainer

func _init() -> void:
	super("POLICY", Vector2(860, 540))
	body.add_child(UiKit.heading("RATIONS", 24, UiStyle.GOOD))
	rations_box = VBoxContainer.new()
	rations_box.add_theme_constant_override("separation", 6)
	body.add_child(rations_box)
	body.add_child(UiKit.heading("HOLDING STANCE", 24, UiStyle.GOOD))
	var sc: ScrollContainer = UiKit.scroll(150)
	body.add_child(sc)
	stance_box = VBoxContainer.new()
	stance_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stance_box.add_theme_constant_override("separation", 6)
	sc.add_child(stance_box)

func set_model(m: Dictionary) -> void:
	model = m
	UiKit.clear(rations_box)
	UiKit.clear(stance_box)
	ration_buttons.clear()
	stance_buttons.clear()
	set_status("%d people, %d rations in stock. Hunger streak: %d day(s)." % [int(m.get("persons", 0)), int(m.get("rations", 0)), int(m.get("hunger_days", 0))],
		UiStyle.BAD if int(m.get("hunger_days", 0)) > 0 else UiStyle.TEXT)
	for o in m.get("options", []):
		var h := HBoxContainer.new()
		h.add_theme_constant_override("separation", 10)
		var active: bool = String(o["value"]) == String(m.get("policy", "full"))
		var b: Button = UiKit.button(String(o["value"]).to_upper() + ("  (ACTIVE)" if active else ""), UiStyle.GOOD if active else UiStyle.PURPLE, Vector2(240, 56))
		b.pressed.connect(func() -> void: policy_changed.emit("ration", String(o["value"]), -1))
		ration_buttons[String(o["value"])] = b
		h.add_child(b)
		var days: float = float(o["days"])
		var l: Label = UiStyle.label("%s - eats %d/day, lasts %s" % [o["note"], int(o["per_day"]), "forever" if days >= 99.0 else "%.1f days" % days], 18, UiStyle.TEXT, false)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		h.add_child(l)
		rations_box.add_child(h)
	for s in m.get("stances", []):
		var h2 := HBoxContainer.new()
		h2.add_theme_constant_override("separation", 8)
		var nm: Label = UiStyle.label("%s (garrison %d)" % [s["name"], int(s["garrison"])], 20, UiStyle.TEXT, false)
		nm.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		h2.add_child(nm)
		for v in ["defend", "raid"]:
			var on: bool = String(s["stance"]) == v
			var sb: Button = UiKit.button(v.to_upper(), UiStyle.GOOD if on else UiStyle.PURPLE, Vector2(130, 56), 20)
			var hid: int = int(s["holding_id"])
			sb.pressed.connect(func() -> void: policy_changed.emit("stance", v, hid))
			stance_buttons["%d:%s" % [hid, v]] = sb
			h2.add_child(sb)
		stance_box.add_child(h2)
