extends Node
## Playable entry: MenuFlow -> LocalSession (Rules) -> WorldStage. Online play swaps in OnlineSession.
## Controls: WASD/stick move, USE/E interact (plot: water/harvest, else plant), HIT/F attack nearest, abilities on bar, B build, N menu.
var stage: WorldStage
var menu: MenuFlow
var seed_value: int = 1
var _over: bool = false
var _slot: int = 0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="):
			seed_value = int(a.get_slice("=", 1))
	menu = MenuFlow.new()
	add_child(menu)
	menu.new_match_requested.connect(func(cid: String, sd: int) -> void: _start(LocalSession.new_game(sd, StringName(cid), _slot, MenuApi.new_match_opts(), MenuApi.meta())))
	menu.continue_requested.connect(_continue)
	menu.endless_requested.connect(func() -> void: _over = false)
	menu.quit_requested.connect(func() -> void: get_tree().quit())
	menu.options_changed.connect(func(o: Dictionary) -> void:
		if stage != null:
			stage.apply_options(o))
	Game.events_emitted.connect(_on_events)
	if "--journey" in OS.get_cmdline_user_args():
		menu.hide_all()
		_start(LocalSession.new_game(seed_value, &"lfg:class/judd", -1, {}, null))
		var j: Node = load("res://main/journey.gd").new()
		add_child(j)
		j.run(self)
	else:
		menu.show_menu()

func _continue() -> void:
	var s: LocalSession = LocalSession.continue_slot(MenuApi.continue_slot(), MenuApi.meta())
	if s == null:
		menu.show_menu()
		return
	_start(s)

func _start(s: GameSession) -> void:
	if s == null:
		menu.show_menu()
		return
	if stage != null:
		stage.queue_free()
		stage = null
	_over = false
	Game.use_session(s)
	stage = WorldStage.new()
	add_child(stage)
	move_child(stage, 0)
	stage.interact_requested.connect(_on_interact)
	stage.action_requested.connect(_on_hit)
	stage.ability_requested.connect(func(id: String) -> void: _report(Game.command(&"use_ability", {"ability": id}), "Ability used"))
	var p: UiPanels = stage.panels
	p.build_requested.connect(func(b: String, h: int, hx: Vector2i) -> void: _send(UiCommands.build(b, h, hx), "Built"))
	p.craft_requested.connect(func(r: String, q: int) -> void: _send(UiCommands.craft(r, q), "Crafted"))
	p.trade_requested.connect(func(h: int, sd: String, it: String, q: int) -> void: _send(UiCommands.trade(h, sd, it, q), "Traded"))
	p.policy_requested.connect(func(k: String, v: String, h: int) -> void: _send(UiCommands.policy(k, v, h), "Policy set"))
	p.demolish_requested.connect(func(h: int, b: String) -> void: _send(UiCommands.demolish(h, b), "Demolished"))
	await stage.start_from_state(Game.state)
	stage.player.hex_changed.connect(_on_hex)
	stage.hud.toast("Feed your people. Survive the Purge.", UiStyle.GOOD, 5.0)

func _send(c: Dictionary, ok_text: String) -> void:
	var res: Dictionary = Game.command(c["type"], c["args"])
	_report(res, ok_text)
	if stage != null:
		stage.panels.refresh()

func _on_hex(offset_hex: Vector2i) -> void:
	Game.command(&"move_intent", {"to": HexMath.offset_to_axial(offset_hex)})

func _on_interact(kind: StringName, data: Dictionary) -> void:
	if kind == &"plot":
		var hx: Vector2i = _parse(String(data["id"]))
		var st: int = int(data["stage"])
		var t: StringName = &"harvest" if st == FarmLayer.Stage.RIPE or st == FarmLayer.Stage.WILTED else &"water"
		_report(Game.command(t, {"hex": hx}), String(data["label"]))
	elif kind == &"holding":
		stage.panels.open(&"holding")
	else:
		_report(Game.command(&"plant", {"crop": "lfg:crop/glowfruit", "hex": HexMath.offset_to_axial(stage.player.current_hex)}), "Planted glowfruit")

func _on_hit() -> void:
	var st: MatchState = Game.state
	var me: Dictionary = st.actors[st.player_id]
	var best: int = -1
	var bd: int = 99
	for id in st.actors:
		var t: Dictionary = st.actors[id]
		if int(id) == st.player_id or not t["alive"] or int(t["faction"]) == int(me["faction"]):
			continue
		var d: int = HexGrid.distance(me["hex"], t["hex"])
		if d < bd:
			bd = d
			best = int(id)
	if best < 0 or bd > 1:
		stage.hud.toast("Nothing in reach", UiStyle.TEXT, 1.0)
		return
	_report(Game.command(&"attack", {"target": best}), "Hit!")

func _report(res: Dictionary, ok_text: String) -> void:
	if stage == null:
		return
	if res.get("ok", false):
		stage.hud.toast(ok_text, UiStyle.GOOD, 1.2)
	else:
		stage.hud.toast("Can't: %s" % String(res.get("error", "?")).replace("_", " "), UiStyle.WARN, 1.5)

func _parse(k: String) -> Vector2i:
	var p: PackedStringArray = k.split(",")
	return Vector2i(int(p[0]), int(p[1]))

func _on_events(events: Array) -> void:
	if stage == null:
		return
	stage.on_events(events, Game.state)
	if _over:
		return
	var st: MatchState = Game.state
	var extra: Dictionary = {"day": int(st.clock["day"]), "class_label": stage.hud_model.get("class_label", "")}
	for e in events:
		var t: StringName = e.get("type", &"")
		if t == &"match_over" or t == &"victory":
			_over = true
			menu.handle_events(events, extra)
			return

func _unhandled_key_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k != null and k.pressed and not k.echo:
		match k.physical_keycode:
			KEY_N: menu.show_menu()
			KEY_B:
				if stage != null:
					stage.panels.toggle(&"build")
			KEY_F:
				if stage != null:
					_on_hit()

func cmd(type: StringName, args: Dictionary) -> Dictionary:
	return Game.command(type, args)
