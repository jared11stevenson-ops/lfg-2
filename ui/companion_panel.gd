class_name CompanionPanel
extends PanelBase
## PETS: your creature companions and the ones still to meet. A pure view over Companions.panel_model(state, actor): set_model(model).
## It never touches Rules; it emits request signals and the lead maps them to commands (UiCommands.adopt_companion / feed_companion / assign_companion / dismiss_companion).
signal adopt_requested(kind: String)
signal feed_requested(kind: String, item: String)
signal assign_requested(kind: String, mode: String, holding_id: int)
signal dismiss_requested(kind: String)
signal tab_changed(tab: String)
const TABS: Array[String] = ["yours", "wild"]
const TAB_LABELS: Dictionary = {"yours": "YOURS", "wild": "TO MEET"}
var model: Dictionary = {}
var tab: String = "yours"
var tab_buttons: Dictionary = {}
var list_box: VBoxContainer
var summary: Label
var buttons: Dictionary = {}           # "feed:<kind>:<item>" | "follow:<kind>" | "hold:<kind>:<hid>" | "rest:<kind>" | "dismiss:<kind>" | "adopt:<kind>" -> Button

func _init() -> void:
	super("PETS", Vector2(940, 600))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	body.add_child(bar)
	for t in TABS:
		var b: Button = UiKit.button(String(TAB_LABELS[t]), UiStyle.PURPLE, Vector2(170, 56), 20)
		var tt: String = t
		b.pressed.connect(func() -> void: show_tab(tt))
		bar.add_child(b)
		tab_buttons[t] = b
	summary = _lbl("", 18, Color(1, 1, 1, 0.8))
	body.add_child(summary)
	var sc: ScrollContainer = UiKit.scroll(360)
	body.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	sc.add_child(list_box)

func show_tab(t: String) -> void:
	if not TABS.has(t):
		return
	tab = t
	tab_changed.emit(t)
	_render()

func set_model(m: Dictionary) -> void:
	model = m
	_render()

func _render() -> void:
	UiKit.clear(list_box)
	buttons.clear()
	var owned: Array = model.get("owned", [])
	var wild: Array = model.get("wild", [])
	for t in TABS:
		var btn: Button = tab_buttons[t]
		btn.text = "%s (%d)" % [TAB_LABELS[t], owned.size() if t == "yours" else wild.size()]
		btn.disabled = t == tab
	summary.text = "Places %d/%d   Following %d/%d   Companions never fight for you: they work, and they steady the garrison." % [int(model.get("slots_used", 0)),
		int(model.get("slots", 2)), int(model.get("followers", 0)), int(model.get("followers_max", 2))]
	var rows: Array = owned if tab == "yours" else wild
	if rows.is_empty():
		list_box.add_child(_lbl("None yet. Open TO MEET to see how to make friends with a creature." if tab == "yours" else "You have met them all.", 20, Color(1, 1, 1, 0.7)))
		return
	for r in rows:
		list_box.add_child(_owned_card(r) if tab == "yours" else _wild_card(r))

static func _col(r: Dictionary) -> Color:
	var cs: Array = r.get("colors", [])
	return Color(String(cs[1])) if cs.size() >= 2 else UiStyle.PURPLE

func _status_chip(r: Dictionary) -> Control:
	if not bool(r["fed"]):
		return UiKit.chip("HUNGRY", UiStyle.BAD, 16)
	var where: String = "FOLLOWING" if String(r["post"]) == "follow" else ("AT " + String(r["hold_name"]).to_upper() if String(r["post"]) == "hold" else "RESTING")
	return UiKit.chip("%s  -  FED %dd" % [where, int(r["days_fed"])], UiStyle.GOOD, 16)

func _owned_card(r: Dictionary) -> Control:
	var card: PanelContainer = UiKit.card(Color(0.16, 0.1, 0.28, 0.92))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var title: Label = UiStyle.label(String(r["name"]), 26, _col(r).lightened(0.3), false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	head.add_child(_status_chip(r))
	v.add_child(_lbl(String(r["blurb"]), 17, Color(1, 1, 1, 0.8)))
	v.add_child(_lbl(String(r["role"]), 17, UiStyle.WARN))
	var kind: String = String(r["kind"])
	var feed := HBoxContainer.new()
	feed.add_theme_constant_override("separation", 6)
	v.add_child(feed)
	feed.add_child(_lbl("Feed:", 17, Color(1, 1, 1, 0.8)))
	var have: Dictionary = model.get("pack", {})
	for it in r["diet"]:
		var itm: String = String(it)
		var fave: bool = UiKit.item_name(itm) == String(r["fave"])
		var b: Button = UiKit.button("%s%s" % [UiKit.item_name(itm), " *" if fave else ""], UiStyle.GOOD, Vector2(150, 56), 17)
		b.disabled = model.has("pack") and int(have.get(itm, 0)) <= 0
		b.pressed.connect(func() -> void: feed_requested.emit(kind, itm))
		buttons["feed:%s:%s" % [kind, itm]] = b
		feed.add_child(b)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	v.add_child(row)
	var f: Button = UiKit.button("FOLLOW", UiStyle.PURPLE, Vector2(140, 56), 18)
	f.disabled = String(r["post"]) == "follow"
	f.pressed.connect(func() -> void: assign_requested.emit(kind, "follow", -1))
	buttons["follow:" + kind] = f
	row.add_child(f)
	for h in model.get("holdings", []):
		var hid: int = int(h["id"])
		var hb: Button = UiKit.button("POST: %s" % String(h["name"]), UiStyle.PURPLE, Vector2(180, 56), 17)
		hb.disabled = not bool(h["near"]) or (String(r["post"]) == "hold" and int(r["hold"]) == hid)
		hb.pressed.connect(func() -> void: assign_requested.emit(kind, "hold", hid))
		buttons["hold:%s:%d" % [kind, hid]] = hb
		row.add_child(hb)
	var rest: Button = UiKit.button("REST", UiStyle.PURPLE, Vector2(110, 56), 18)
	rest.disabled = String(r["post"]) == "rest"
	rest.pressed.connect(func() -> void: assign_requested.emit(kind, "rest", -1))
	buttons["rest:" + kind] = rest
	row.add_child(rest)
	var d: Button = UiKit.button("SEND AWAY", UiStyle.BAD, Vector2(150, 56), 17)
	d.pressed.connect(func() -> void: dismiss_requested.emit(kind))
	buttons["dismiss:" + kind] = d
	row.add_child(d)
	return card

func _wild_card(r: Dictionary) -> Control:
	var card: PanelContainer = UiKit.card(Color(0.12, 0.1, 0.22, 0.92))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var head := HBoxContainer.new()
	v.add_child(head)
	var title: Label = UiStyle.label(String(r["name"]), 24, _col(r).lightened(0.3), false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if bool(r["here"]):
		head.add_child(UiKit.chip("IT IS HERE", UiStyle.GOOD, 16))
	v.add_child(_lbl(String(r["blurb"]), 17, Color(1, 1, 1, 0.8)))
	v.add_child(_lbl(String(r["role"]), 17, UiStyle.WARN))
	for h in r["hints"]:
		v.add_child(_lbl("How: " + String(h), 17, UiStyle.TEXT))
	var kind: String = String(r["kind"])
	var b: Button = UiKit.button("OFFER FOOD", UiStyle.GOOD, Vector2(200, 56), 20)
	b.disabled = not bool(r["here"])
	b.pressed.connect(func() -> void: adopt_requested.emit(kind))
	buttons["adopt:" + kind] = b
	v.add_child(b)
	return card

static func _lbl(text: String, size: int, color: Color = UiStyle.TEXT) -> Label:
	var l: Label = UiStyle.label(text, size, color, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(160, 0)
	return l
