class_name CraftPanel
extends PanelBase
## Recipes from data/recipes.json with have/need chips. Emits craft_requested(recipe_id, qty).
signal craft_requested(recipe_id: String, qty: int)
var model: Dictionary = {}
var list_box: VBoxContainer
var craft_buttons: Dictionary = {} # recipe id -> Button (x1)

func _init() -> void:
	super("CRAFT", Vector2(840, 540))
	var sc: ScrollContainer = UiKit.scroll(360)
	body.add_child(sc)
	list_box = VBoxContainer.new()
	list_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list_box.add_theme_constant_override("separation", 8)
	sc.add_child(list_box)

func set_model(m: Dictionary) -> void:
	model = m
	UiKit.clear(list_box)
	craft_buttons.clear()
	if not bool(m.get("near_holding", false)):
		set_status(PanelModels.reason_text("not_near_own_holding"), UiStyle.WARN)
	else:
		set_status("Crafting uses your pack.", UiStyle.TEXT)
	for r in m.get("rows", []):
		list_box.add_child(_row(r))

func _row(r: Dictionary) -> Control:
	var card: PanelContainer = UiKit.card(Color(0.16, 0.1, 0.28, 0.9))
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 10)
	card.add_child(h)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	h.add_child(info)
	var outs: Array[String] = []
	for o in r["outputs"]:
		outs.append("%s x%d" % [o["name"], int(o["qty"])])
	info.add_child(UiStyle.label("%s  ->  %s" % [r["name"], ", ".join(outs)], 22, UiStyle.TEXT, false))
	info.add_child(UiKit.cost_row(r["inputs"]))
	if String(r["reason"]) != "":
		info.add_child(UiStyle.label(PanelModels.reason_text(String(r["reason"])), 16, UiStyle.WARN, false))
	var b1: Button = UiKit.button("CRAFT", UiStyle.GOOD, Vector2(120, 56))
	b1.disabled = not bool(r["craftable"])
	b1.pressed.connect(func() -> void: craft_requested.emit(String(r["id"]), 1))
	craft_buttons[String(r["id"])] = b1
	h.add_child(b1)
	var b5: Button = UiKit.button("x5", UiStyle.PURPLE, Vector2(80, 56))
	b5.disabled = not bool(r["craftable"]) or int(r["max_qty"]) < 5
	b5.pressed.connect(func() -> void: craft_requested.emit(String(r["id"]), 5))
	h.add_child(b5)
	return card
