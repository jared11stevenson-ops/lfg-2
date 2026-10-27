class_name PoiPanel
extends PanelBase
## One point of interest up close: name, flavour, what it asks of you, the carved hint, and the buttons to try it. A pure view over
## Pois.info(state, actor, poi_id): set_model(info). Emits action_requested(poi_id, pick) (pick = -1 for no pick); the lead maps it to interact_poi.
signal action_requested(poi_id: int, pick: int)
var model: Dictionary = {}
var flavor: Label
var challenge: Label
var hint_label: Label
var status_label: Label
var pick_row: HBoxContainer
var go_btn: Button
var pick_buttons: Array[Button] = []

func _init() -> void:
	super("", Vector2(720, 460))
	flavor = _lbl("", 20, Color(1, 1, 1, 0.8))
	body.add_child(flavor)
	challenge = _lbl("", 22, UiStyle.TEXT)
	body.add_child(challenge)
	hint_label = _lbl("", 22, UiStyle.WARN)
	body.add_child(hint_label)
	status_label = _lbl("", 20, UiStyle.GOOD)
	body.add_child(status_label)
	pick_row = HBoxContainer.new()
	pick_row.add_theme_constant_override("separation", 10)
	body.add_child(pick_row)
	for i in 3:
		var b: Button = UiKit.button("", UiStyle.PURPLE, Vector2(160, 64), 22)
		var idx: int = i
		b.pressed.connect(func() -> void: action_requested.emit(int(model.get("id", -1)), idx))
		pick_row.add_child(b)
		pick_buttons.append(b)
	go_btn = UiKit.button("TRY", UiStyle.GOOD, Vector2(220, 64), 24)
	go_btn.pressed.connect(func() -> void: action_requested.emit(int(model.get("id", -1)), -1))
	body.add_child(go_btn)

func set_model(m: Dictionary) -> void:
	model = m
	if m.is_empty():
		title_label.text = "NOTHING HERE"
		return
	title_label.text = String(m["name"]).to_upper()
	flavor.text = String(m["flavor"])
	challenge.text = String(m["text"])
	var kind: String = String(m["kind"])
	var h: Dictionary = m.get("hint", {})
	hint_label.text = ""
	if kind == "lamps" and h.has("lit"):
		var parts: Array[String] = []
		for i in 3:
			parts.append("lamp %d %s" % [i + 1, "LIT" if bool(h["lit"][i]) else "dark"])
		hint_label.text = "The bowl is carved: " + ", ".join(parts) + "."
	elif kind == "sequence" and h.has("order"):
		var seq: Array[String] = []
		for o in h["order"]:
			seq.append(str(int(o) + 1))
		hint_label.text = "The lintel shows plates in this order: " + " then ".join(seq) + "."
	var avail: bool = bool(m["available"])
	var guards: int = int(m.get("guards_alive", 0))
	var picks: bool = (kind == "lamps" or kind == "sequence") and avail
	pick_row.visible = picks
	for i in 3:
		pick_buttons[i].text = ("Lamp %d" % (i + 1)) if kind == "lamps" else ("Plate %d" % (i + 1))
	go_btn.visible = not picks
	go_btn.disabled = not avail
	go_btn.text = {"offering": "LEAVE THE OFFERING", "effort": "PRY IT OPEN", "guard": "CLEAR IT" if guards == 0 else "FIGHT (%d left)" % guards}.get(kind, "TRY")
	var arena: bool = bool(m.get("arena", false))
	if arena:      # region guardian: wake it, fight it with the usual HIT button, then come back and claim
		if guards > 0:
			go_btn.text = "THE GUARDIAN IS UP"
			go_btn.disabled = true
		elif bool(m.get("summoned", false)):
			go_btn.text = "CLAIM THE SPOILS"
		else:
			go_btn.text = "WAKE THE GUARDIAN"
	if not avail:
		status_label.text = "Spent for this week. It returns when the week turns."
		status_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.7))
	else:
		status_label.text = "Progress: %d" % int(m.get("prog", 0)) if (kind == "lamps" or kind == "sequence") else ("Something stirs inside." if guards > 0 else "A reward waits here.")
		if arena:
			status_label.text = ("Fight it with HIT. Step out of the red ground when it winds up." if guards > 0 else
				("It is down. Claim what it guarded." if bool(m.get("summoned", false)) else "Bring tonics. A Battle Stew and a Bark Salve (Alembic) make it much easier."))
		status_label.add_theme_color_override("font_color", UiStyle.GOOD)

static func _lbl(text: String, size: int, color: Color = UiStyle.TEXT) -> Label:
	var l: Label = UiStyle.label(text, size, color, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(160, 0)
	return l
