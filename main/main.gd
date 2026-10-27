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
	if "--smoke" in OS.get_cmdline_user_args():
		_smoke()
		return
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
	_build_progress_ui()
	p.quest_accept_requested.connect(func(q: String) -> void: _send(UiCommands.accept_quest(q), "Quest accepted"))
	p.quest_abandon_requested.connect(func(q: String) -> void: _send(UiCommands.abandon_quest(q), "Quest abandoned"))
	p.quest_turn_in_requested.connect(func(q: String) -> void: _send(UiCommands.turn_in(q), "Quest complete"))
	p.poi_action_requested.connect(func(pid: int, pick: int) -> void: _send(UiCommands.interact_poi(pid, pick), "Done"))
	await stage.start_from_state(Game.state)
	stage.player.hex_changed.connect(_on_hex)
	stage.hud.toast("Feed your people. Survive the Purge.", UiStyle.GOOD, 5.0)

var standing_panel: StandingPanel
var skill_panel: SkillTreePanel
var _prog_layer: CanvasLayer
var _model_t: float = 0.0

func _build_progress_ui() -> void:
	if _prog_layer != null:
		_prog_layer.queue_free()
	_prog_layer = CanvasLayer.new()
	_prog_layer.layer = 14
	add_child(_prog_layer)
	standing_panel = StandingPanel.new()
	skill_panel = SkillTreePanel.new()
	_prog_layer.add_child(standing_panel)
	_prog_layer.add_child(skill_panel)
	standing_panel.skill_tree_requested.connect(func() -> void:
		standing_panel.visible = false
		_open_skills())
	skill_panel.unlock_requested.connect(func(node_id: String) -> void:
		_report(Game.command(&"unlock_skill", {"node": node_id}), "Skill learned")
		skill_panel.set_model(Skills.panel_model(Game.state.actors[Game.state.player_id])))
	var box := VBoxContainer.new()
	box.position = Vector2(162, 104)
	box.add_theme_constant_override("separation", 6)
	_prog_layer.add_child(box)
	var b1: Button = UiKit.button("RANK", UiStyle.PURPLE, Vector2(132, 48), 18)
	b1.pressed.connect(_open_standing)
	box.add_child(b1)

func _open_standing() -> void:
	skill_panel.visible = false
	standing_panel.set_model(Standing.hud_model(Game.state, 0))
	standing_panel.visible = not standing_panel.visible

func _open_skills() -> void:
	skill_panel.set_model(Skills.panel_model(Game.state.actors[Game.state.player_id]))
	skill_panel.visible = true

func _send(c: Dictionary, ok_text: String) -> void:
	var res: Dictionary = Game.command(c["type"], c["args"])
	_report(res, ok_text)
	if stage != null:
		stage.panels.refresh()

func _on_hex(offset_hex: Vector2i) -> void:
	Game.command(&"sync_position", {"hex": HexMath.offset_to_axial(offset_hex)})

func _on_interact(kind: StringName, data: Dictionary) -> void:
	if kind == &"plot":
		var hx: Vector2i = _parse(String(data["id"]))
		var st: int = int(data["stage"])
		var t: StringName = &"harvest" if st == FarmLayer.Stage.RIPE or st == FarmLayer.Stage.WILTED else &"water"
		_report(Game.command(t, {"hex": hx}), String(data["label"]))
	elif kind == &"poi":
		pass
	elif kind == &"holding":
		stage.panels.open(&"holdings")
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
	for e0 in events:
		if e0.get("type", &"") == &"phase_changed" and e0.get("to", &"") == &"WARNING":
			var sm: Dictionary = Standing.hud_model(Game.state, 0)
			var lv: Dictionary = sm.get("levy", {})
			var mk: Dictionary = sm.get("marked", {})
			stage.hud.toast("Purge near. %s | Levy: %s rations, %s coin | Marked: %s" % [sm.get("rank_name", ""), lv.get("rations", 0), lv.get("coin", 0), "YOU" if mk.get("is_you", false) else mk.get("name", "-")], UiStyle.WARN, 7.0)
	var extra: Dictionary = {"day": int(st.clock["day"]), "class_label": stage.hud_model.get("class_label", "")}
	for e in events:
		var t: StringName = e.get("type", &"")
		if t == &"victory" and not bool(e.get("player", false)):
			_over = true
			menu.show_game_over(extra.merged({"reason": "rival_conquest"}))
			return
		if t == &"match_over" or t == &"victory":
			_over = true
			menu.handle_events(events, extra)
			return

func _unhandled_key_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k != null and k.pressed and not k.echo:
		match k.physical_keycode:
			KEY_N: menu.show_menu()
			KEY_P:
				if stage != null:
					_open_standing()
			KEY_K:
				if stage != null:
					_open_skills()
			KEY_B:
				if stage != null:
					stage.panels.toggle(&"build")
			KEY_F:
				if stage != null:
					_on_hit()

func cmd(type: StringName, args: Dictionary) -> Dictionary:
	return Game.command(type, args)

## Export smoke test: start a real match, build the world, tick 2 in-world days, print a summary and quit. Works from an exported binary.
func _smoke() -> void:
	menu.hide_all()
	_start(LocalSession.new_game(seed_value, &"lfg:class/judd", -1, {}, null))
	while stage == null or not stage.started:
		await get_tree().process_frame
	var st: MatchState = Game.state
	var t: float = 0.0
	while int(st.clock["day"]) < 3 and t < 1200.0:
		Game.events_emitted.emit(Rules.tick(st, 2.0))
		t += 2.0
	var r: Dictionary = Game.command(&"plant", {"crop": "lfg:crop/glowfruit", "hex": HexMath.offset_to_axial(stage.player.current_hex)})
	print("SMOKE_OK day=%d phase=%s actors=%d holdings=%d plant_ok=%s err=%s" % [int(st.clock["day"]), st.phase, st.actors.size(), st.holdings.size(), r.get("ok"), r.get("error")])
	get_tree().quit()
