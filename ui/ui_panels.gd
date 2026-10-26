class_name UiPanels
extends CanvasLayer
## Host for the playable panels (Build, Craft, Trade, Policy, Holdings) plus the left-edge toolbar. Pure view:
## it reads state through PanelModels and re-emits panel signals; it never calls Rules. The lead maps the signals to
## commands with UiCommands (build_requested -> UiCommands.build, ...). Call refresh() after any events so numbers stay live.
signal build_requested(building_id: String, holding_id: int)
signal craft_requested(recipe_id: String, qty: int)
signal trade_requested(holding_id: int, side: String, item: String, qty: int)
signal policy_requested(key: String, value: String, holding_id: int)
signal store_requested(holding_id: int, side: String, item: String, qty: int)
signal demolish_requested(holding_id: int, building_id: String)
signal placement_started(building_id: String)
signal placement_ended
signal panel_changed(kind: StringName) # &"" when all closed
const KINDS: Array[StringName] = [&"build", &"craft", &"trade", &"policy", &"holdings"]
const LABELS: Dictionary = {&"build": "BUILD", &"craft": "CRAFT", &"trade": "TRADE", &"policy": "POLICY", &"holdings": "HOLD"}
var state: Object
var root: Control
var build: BuildMenu
var craft: CraftPanel
var trade: TradePanel
var policy: PolicyPanel
var holdings: HoldingPanel
var toolbar: VBoxContainer
var toolbar_buttons: Dictionary = {}
var merchant_id: int = -1
var current: StringName = &""
var placing: bool = false

func _init() -> void:
	name = "UiPanels"
	layer = 12
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	toolbar = VBoxContainer.new()
	toolbar.position = Vector2(20, 104)
	toolbar.add_theme_constant_override("separation", 6)
	root.add_child(toolbar)
	for k in KINDS:
		var b: Button = UiKit.button(String(LABELS[k]), UiStyle.PURPLE, Vector2(132, 56), 20)
		b.pressed.connect(toggle.bind(k))
		toolbar.add_child(b)
		toolbar_buttons[k] = b
	(toolbar_buttons[&"trade"] as Button).disabled = true
	build = BuildMenu.new()
	craft = CraftPanel.new()
	trade = TradePanel.new()
	policy = PolicyPanel.new()
	holdings = HoldingPanel.new()
	for p in [build, craft, trade, policy, holdings]:
		root.add_child(p)
		(p as PanelBase).closed.connect(_on_panel_closed)
	build.building_picked.connect(_on_pick)
	build.build_confirmed.connect(func(b: String, h: int) -> void:
		build_requested.emit(b, h))
	build.placement_cancelled.connect(end_placement)
	craft.craft_requested.connect(func(r: String, q: int) -> void: craft_requested.emit(r, q))
	trade.trade_requested.connect(func(h: int, s: String, i: String, q: int) -> void: trade_requested.emit(h, s, i, q))
	policy.policy_changed.connect(func(k: String, v: String, h: int) -> void: policy_requested.emit(k, v, h))
	holdings.store_requested.connect(func(h: int, s: String, i: String, q: int) -> void: store_requested.emit(h, s, i, q))
	holdings.demolish_requested.connect(func(h: int, b: String) -> void: demolish_requested.emit(h, b))

func bind_state(s: Object) -> void:
	state = s
	refresh()

func panel_for(kind: StringName) -> PanelBase:
	match kind:
		&"build": return build
		&"craft": return craft
		&"trade": return trade
		&"policy": return policy
		&"holdings": return holdings
	return null

func any_open() -> bool:
	for k in KINDS:
		if panel_for(k).visible and not (k == &"build" and build.docked):
			return true
	return false

func toggle(kind: StringName) -> void:
	if current == kind and panel_for(kind).visible:
		close_all()
	else:
		open(kind)

func open(kind: StringName) -> void:
	if kind == &"trade" and merchant_id < 0:
		return
	if placing:
		end_placement()
	for k in KINDS:
		if k != kind:
			panel_for(k).visible = false
	current = kind
	refresh()
	panel_for(kind).open()
	panel_changed.emit(kind)

func close_all() -> void:
	if placing:
		end_placement()
	for k in KINDS:
		panel_for(k).visible = false
	current = &""
	panel_changed.emit(&"")

func _on_panel_closed() -> void:
	if placing:
		end_placement()
	if not any_open():
		current = &""
		panel_changed.emit(&"")

func set_merchant(id: int) -> void:
	merchant_id = id
	(toolbar_buttons[&"trade"] as Button).disabled = id < 0
	if id < 0 and current == &"trade":
		close_all()

## Re-render the open panel from state (cheap; call after events).
func refresh() -> void:
	if state == null:
		return
	if build.visible or current == &"build":
		build.set_model(PanelModels.build_model(state))
	match current:
		&"craft": craft.set_model(PanelModels.craft_model(state))
		&"trade":
			if merchant_id >= 0:
				trade.set_model(PanelModels.trade_model(state, merchant_id))
		&"policy": policy.set_model(PanelModels.policy_model(state))
		&"holdings": holdings.set_model(PanelModels.holdings_model(state))

func _on_pick(building_id: String) -> void:
	placing = true
	build.set_docked(true)
	placement_started.emit(building_id)

func end_placement() -> void:
	if not placing:
		return
	placing = false
	build.selected = ""
	build.set_docked(false)
	placement_ended.emit()

func toolbar_rects() -> Array[Rect2]:
	var out: Array[Rect2] = []
	for k in KINDS:
		var b: Button = toolbar_buttons[k]
		out.append(Rect2(b.global_position, b.size).grow(8.0))
	return out
