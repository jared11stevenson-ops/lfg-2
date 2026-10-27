class_name UiPanels
extends CanvasLayer
## Host for the playable panels (Build, Craft, Trade, Policy, Holdings) plus the left-edge toolbar. Pure view:
## it reads state through PanelModels and re-emits panel signals; it never calls Rules. The lead maps the signals to
## commands with UiCommands (build_requested -> UiCommands.build, ...). Call refresh() after any events so numbers stay live.
signal build_requested(building_id: String, holding_id: int, hex: Vector2i)
signal craft_requested(recipe_id: String, qty: int)
signal trade_requested(holding_id: int, side: String, item: String, qty: int)
signal policy_requested(key: String, value: String, holding_id: int)
signal store_requested(holding_id: int, side: String, item: String, qty: int)
signal demolish_requested(holding_id: int, building_id: String)
signal quest_accept_requested(quest_id: String)
signal quest_abandon_requested(quest_id: String)
signal quest_turn_in_requested(quest_id: String)
signal poi_action_requested(poi_id: int, pick: int)
signal companion_adopt_requested(kind: String)
signal companion_feed_requested(kind: String, item: String)
signal companion_assign_requested(kind: String, mode: String, holding_id: int)
signal companion_dismiss_requested(kind: String)
signal tutorial_ack_requested(topic: String)
signal placement_started(building_id: String)
signal placement_ended
signal panel_changed(kind: StringName) # &"" when all closed
const KINDS: Array[StringName] = [&"build", &"craft", &"trade", &"policy", &"holdings", &"quests", &"companions", &"poi"]
const LABELS: Dictionary = {&"build": "BUILD", &"craft": "CRAFT", &"trade": "TRADE", &"policy": "POLICY", &"holdings": "HOLD", &"quests": "JOURNAL", &"companions": "PETS"}
## Tutorial highlight key -> toolbar button (the others, "plot" "bag" "purge_guide", point at the world or a card).
const HIGHLIGHT_BUTTONS: Dictionary = {"craft": &"craft", "build": &"build", "hold": &"holdings", "journal": &"quests"}
var state: Object
var root: Control
var build: BuildMenu
var craft: CraftPanel
var trade: TradePanel
var policy: PolicyPanel
var holdings: HoldingPanel
var quests: QuestPanel
var companions: CompanionPanel
var tutorial: TutorialOverlay
var poi: PoiPanel
var _pulse: StringName = &""
var _pulse_t: float = 0.0
var poi_id: int = -1
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
	toolbar.position = Vector2(20, 140)
	toolbar.add_theme_constant_override("separation", 6)
	root.add_child(toolbar)
	for k in KINDS:
		if not LABELS.has(k):
			continue      # the point-of-interest panel opens from the world, not from the toolbar
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
	quests = QuestPanel.new()
	companions = CompanionPanel.new()
	poi = PoiPanel.new()
	tutorial = TutorialOverlay.new()      # added before the panels so any open panel draws over the guide
	root.add_child(tutorial)
	for p in [build, craft, trade, policy, holdings, quests, companions, poi]:
		root.add_child(p)
		(p as PanelBase).closed.connect(_on_panel_closed)
	build.building_picked.connect(_on_pick)
	build.build_confirmed.connect(func(b: String, h: int, hx: Vector2i) -> void:
		build_requested.emit(b, h, hx))
	build.placement_cancelled.connect(end_placement)
	craft.craft_requested.connect(func(r: String, q: int) -> void: craft_requested.emit(r, q))
	trade.trade_requested.connect(func(h: int, s: String, i: String, q: int) -> void: trade_requested.emit(h, s, i, q))
	policy.policy_changed.connect(func(k: String, v: String, h: int) -> void: policy_requested.emit(k, v, h))
	holdings.store_requested.connect(func(h: int, s: String, i: String, q: int) -> void: store_requested.emit(h, s, i, q))
	holdings.demolish_requested.connect(func(h: int, b: String) -> void: demolish_requested.emit(h, b))
	quests.accept_requested.connect(func(q: String) -> void: quest_accept_requested.emit(q))
	quests.abandon_requested.connect(func(q: String) -> void: quest_abandon_requested.emit(q))
	quests.turn_in_requested.connect(func(q: String) -> void: quest_turn_in_requested.emit(q))
	poi.action_requested.connect(func(i: int, pk: int) -> void: poi_action_requested.emit(i, pk))
	companions.adopt_requested.connect(func(k: String) -> void: companion_adopt_requested.emit(k))
	companions.feed_requested.connect(func(k: String, i: String) -> void: companion_feed_requested.emit(k, i))
	companions.assign_requested.connect(func(k: String, m: String, h: int) -> void: companion_assign_requested.emit(k, m, h))
	companions.dismiss_requested.connect(func(k: String) -> void: companion_dismiss_requested.emit(k))
	tutorial.accept_requested.connect(func(q: String) -> void: quest_accept_requested.emit(q))
	tutorial.ack_requested.connect(func(t: String) -> void: tutorial_ack_requested.emit(t))
	tutorial.highlight_changed.connect(_on_highlight)

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
		&"quests": return quests
		&"companions": return companions
		&"poi": return poi
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

## Opens the point-of-interest panel for a poi id (the lead calls this from interact_requested(&"poi", {id})).
func open_poi(id: int) -> void:
	poi_id = id
	open(&"poi")

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
		&"quests": quests.set_model(Quests.journal(state as MatchState, PanelModels._actor(state, -1)))
		&"companions": companions.set_model(Companions.panel_model(state as MatchState, PanelModels._actor(state, -1)))
		&"poi":
			if poi_id >= 0:
				poi.set_model(Pois.info(state as MatchState, PanelModels._actor(state, -1), poi_id))

	if state is MatchState:
		tutorial.set_model(Quests.tutorial_model(state as MatchState, PanelModels._actor(state, -1)))

## Pulses the toolbar button the tutorial points at (a gentle glow; cleared when the step moves on).
func _on_highlight(key: String) -> void:
	if toolbar_buttons.has(_pulse):
		(toolbar_buttons[_pulse] as Button).modulate = Color.WHITE
	_pulse = HIGHLIGHT_BUTTONS.get(key, &"")
	_pulse_t = 0.0

func _process(dt: float) -> void:
	if _pulse != &"" and toolbar_buttons.has(_pulse):
		_pulse_t += dt
		(toolbar_buttons[_pulse] as Button).modulate = Color(1.0, 1.0, 0.55).lerp(Color.WHITE, 0.5 + 0.5 * sin(_pulse_t * 5.0))

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
		if not toolbar_buttons.has(k):
			continue
		var b: Button = toolbar_buttons[k]
		out.append(Rect2(b.global_position, b.size).grow(8.0))
	return out
