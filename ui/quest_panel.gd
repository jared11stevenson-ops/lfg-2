class_name QuestPanel
extends PanelBase
## QUEST JOURNAL: active / available / finished quests, their steps and rewards. A pure view over Quests.journal(state, actor):
## set_model(journal). It never touches Rules; it emits accept_requested / abandon_requested / turn_in_requested (quest id) and the lead maps them to
## the accept_quest / abandon_quest / turn_in commands (UiCommands.accept_quest ...). Quests of classes whose line is not written yet show under LATER.
signal accept_requested(quest_id: String)
signal abandon_requested(quest_id: String)
signal turn_in_requested(quest_id: String)
signal tab_changed(tab: String)
const TABS: Array[String] = ["active", "available", "done", "later"]
const TAB_LABELS: Dictionary = {"active": "ACTIVE", "available": "AVAILABLE", "done": "DONE", "later": "LATER"}
const LINE_COLORS: Dictionary = {"general": Color("49c6e5"), "judd": Color("6fd3a0"), "mira": Color("c47bff"), "bram": Color("ff8a3c"), "tavi": Color("ffd24a"),
	"pip": Color("5be0ff"), "oren": Color("ff7a8a"), "sable": Color("86b24a"), "forge": Color("ff5a3a")}
var model: Dictionary = {}
var tab: String = "active"
var tab_buttons: Dictionary = {}       # tab -> Button
var list_box: VBoxContainer
var buttons: Dictionary = {}           # "accept:<id>" | "abandon:<id>" | "turn_in:<id>" -> Button
var summary: Label

func _init() -> void:
	super("JOURNAL", Vector2(940, 600))
	var bar := HBoxContainer.new()
	bar.add_theme_constant_override("separation", 8)
	body.add_child(bar)
	for t in TABS:
		var b: Button = UiKit.button(String(TAB_LABELS[t]), UiStyle.PURPLE, Vector2(150, 56), 20)
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

func rows_for(t: String) -> Array:
	match t:
		"active": return model.get("active", [])
		"available": return model.get("available", [])
		"done": return model.get("done", [])
		"later": return (model.get("locked", []) as Array) + (model.get("soon", []) as Array)
	return []

func _render() -> void:
	UiKit.clear(list_box)
	buttons.clear()
	for t in TABS:
		var n: int = rows_for(t).size()
		var btn: Button = tab_buttons[t]
		btn.text = "%s (%d)" % [TAB_LABELS[t], n]
		btn.disabled = t == tab
	var rows: Array = rows_for(tab)
	var titles: Array = model.get("titles", [])
	summary.text = ("Titles: " + ", ".join(titles)) if not titles.is_empty() else "Quests are optional and never need another player."
	if rows.is_empty():
		var msg: String = {"active": "No active quests. Open AVAILABLE to pick one up.", "available": "Nothing new right now.", "done": "Nothing finished yet.",
			"later": "Nothing waiting."}[tab]
		list_box.add_child(_lbl(msg, 20, Color(1, 1, 1, 0.7)))
		return
	for r in rows:
		list_box.add_child(_card(r))

func _card(r: Dictionary) -> Control:
	var col: Color = LINE_COLORS.get(String(r["line"]), UiStyle.PURPLE)
	var card: PanelContainer = UiKit.card(Color(0.16, 0.1, 0.28, 0.92))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 4)
	card.add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 8)
	v.add_child(head)
	var title: Label = UiStyle.label(String(r["title"]), 24, col, false)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(title)
	if bool(r["signature"]):
		head.add_child(UiKit.chip("SIGNATURE", UiStyle.WARN, 16))
	if not bool(r["implemented"]):
		head.add_child(UiKit.chip("COMING SOON", Color("9a8fb0"), 16))
	elif String(r["state"]) == "locked":
		head.add_child(UiKit.chip("LOCKED", Color("9a8fb0"), 16))
	elif bool(r["ready"]):
		head.add_child(UiKit.chip("READY TO HAND IN", UiStyle.GOOD, 16))
	v.add_child(_lbl(String(r["intro"]), 17, Color(1, 1, 1, 0.8)))
	if bool(r["implemented"]):
		for s in r["steps"]:
			var mark: String = "[x] " if bool(s["done"]) else ("[>] " if bool(s["current"]) else "[ ] ")
			var txt: String = mark + String(s["text"])
			if bool(s["current"]) and int(s["qty"]) > 1:
				txt += "  (%d/%d)" % [int(s["progress"]), int(s["qty"])]
			if String(s["theme"]) != "":
				txt += "   - a nod to %s" % String(s["theme"]).get_slice("/", 1).capitalize()
			var c: Color = UiStyle.GOOD if bool(s["done"]) else (UiStyle.TEXT if bool(s["current"]) or String(r["state"]) != "active" else Color(1, 1, 1, 0.55))
			v.add_child(_lbl(txt, 18, c))
	if String(r["reward"]) != "":
		v.add_child(_lbl("Reward: " + String(r["reward"]), 17, UiStyle.WARN))
	var qid: String = String(r["id"])
	if String(r["state"]) == "locked" and bool(r["implemented"]) and not (r["requires"] as Array).is_empty():
		v.add_child(_lbl("Finish the earlier chapter first.", 16, Color(1, 1, 1, 0.6)))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	if String(r["state"]) == "available" and bool(r["implemented"]):
		var a: Button = UiKit.button("ACCEPT", UiStyle.GOOD, Vector2(160, 56))
		a.pressed.connect(func() -> void: accept_requested.emit(qid))
		buttons["accept:" + qid] = a
		row.add_child(a)
	elif String(r["state"]) == "active":
		var cur_deliver: bool = false
		for s2 in r["steps"]:
			if bool(s2["current"]) and String(s2["kind"]) == "deliver":
				cur_deliver = true
		var t: Button = UiKit.button("HAND IN" if bool(r["ready"]) else "DELIVER", UiStyle.GOOD, Vector2(160, 56))
		t.disabled = not (bool(r["ready"]) or cur_deliver)
		t.pressed.connect(func() -> void: turn_in_requested.emit(qid))
		buttons["turn_in:" + qid] = t
		row.add_child(t)
		var ab: Button = UiKit.button("ABANDON", UiStyle.BAD, Vector2(160, 56))
		ab.pressed.connect(func() -> void: abandon_requested.emit(qid))
		buttons["abandon:" + qid] = ab
		row.add_child(ab)
	if row.get_child_count() > 0:
		v.add_child(row)
	else:
		row.free()
	return card

## A wrapping label (the shared UiStyle.label never wraps, and quests are sentences).
static func _lbl(text: String, size: int, color: Color = UiStyle.TEXT) -> Label:
	var l: Label = UiStyle.label(text, size, color, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(160, 0)
	return l
