extends TestCase
## Pass 3 presentation: POI props and layer, strategic-map markers, quest journal and POI panels, HUD tracker/toasts, the new commands end to end.

var _got: Array = []

func _state(cls: String = "lfg:class/judd", seed_v: int = 11) -> MatchState:
	return Rules.new_match(seed_v, StringName(cls), {"day_seconds": 60.0, "ai_enabled": false, "wild_enemies": false})

func _cmd(s: MatchState, c: Dictionary) -> Dictionary:
	var a: Dictionary = s.actors[1]
	return Rules.apply(s, UiCommands.wrap(c, 1, int(a["last_seq"]) + 1))

func _poi(s: MatchState, type: String) -> Dictionary:
	for p in s.world["pois"]:
		if p["type"] == type:
			return p
	return {}

func test_poi_props_are_distinct_readable_and_small() -> void:
	var sigs: Dictionary = {}
	for key in PoiModels.PROPS:
		var m: ArrayMesh = PoiModels.mesh_for(key)
		check(m.get_surface_count() == 1, "%s builds" % key)
		var bb: AABB = m.get_aabb()
		check(bb.size.y > 1.8 and bb.size.y < 8.0, "%s is a readable height (%.1f)" % [key, bb.size.y])
		check(bb.size.x < 9.0 and bb.size.z < 9.0, "%s fits a hex (%.1f x %.1f)" % [key, bb.size.x, bb.size.z])
		var arrs: Array = m.surface_get_arrays(0)
		var sig: int = hash(arrs[Mesh.ARRAY_VERTEX]) ^ hash(arrs[Mesh.ARRAY_COLOR])
		check(not sigs.has(sig), "%s is not a copy of %s" % [key, sigs.get(sig, "")])
		sigs[sig] = key
		check(PoiModels.ACCENT.has(key), "%s has an accent colour" % key)
	eq(PoiModels.PROPS.size(), 7, "one prop per POI type")
	var types: Dictionary = {}
	for t in Content.poi_types().values():
		types[String(t["prop"])] = true
		check(PoiModels.PROPS.has(String(t["prop"])), "%s has a prop" % t["id"])
	eq(types.size(), 7, "all props used")
	var on: AABB = PoiModels.mesh_for("beacon_on").get_aabb()
	var off: AABB = PoiModels.mesh_for("beacon_off").get_aabb()
	check(on.size.y > off.size.y + 4.0, "the live beacon stands taller than the spent one")

func test_poi_layer_draws_only_discovered_points() -> void:
	var s: MatchState = _state()
	var w: WorldData = RulesWorldAdapter.from_state(s)
	var layer := PoiLayer.new()
	layer.world = w
	layer.sync_from_state(s)
	eq(layer.placed_last.size(), 0, "nothing discovered, nothing drawn")
	var p: Dictionary = _poi(s, "lfg:poi/shrine")
	s.actors[1]["pois_seen"] = [int(p["id"])]
	layer.sync_from_state(s)
	eq(layer.placed_last.size(), 1, "the discovered shrine is drawn")
	eq(int(layer.counts.get("shrine", 0)), 1, "in the shrine MultiMesh")
	eq(int(layer.counts.get("beacon_on", 0)), 1, "with a live beacon")
	s.poi_state[int(p["id"])] = {"claimed_week": 0, "week": 0, "prog": 0, "guards": []}
	layer.sync_from_state(s)
	eq(int(layer.counts.get("beacon_off", 0)), 1, "spent this week: grey beacon")
	check(int(layer.counts.get("beacon_on", 0)) == 0, "no live beacon")
	var pos: Vector3 = layer.placed_last[0]["pos"]
	check(layer.nearest(pos + Vector3(2, 0, 0), 9.0).get("id", -1) == int(p["id"]), "nearest finds it")
	check(layer.nearest(pos + Vector3(60, 0, 0), 9.0).is_empty(), "and ignores far ones")
	layer.show_all = true
	layer.sync_from_state(s)
	eq(layer.placed_last.size(), s.world["pois"].size(), "show_all draws every point")
	layer.free()

func test_stage_shows_pois_markers_prompt_and_toasts() -> void:
	var st: MatchState = Rules.new_match(3, &"lfg:class/judd")
	var s := WorldStage.new()
	s.hud._ready()
	s.touch._ready()
	s.map._ready()
	s.start_from_state_sync(st)
	eq(s.pois.placed_last.size(), 0, "fresh world: nothing discovered")
	var p: Dictionary = _poi(st, "lfg:poi/derelict_farm")
	st.actors[1]["hex"] = p["hex"]
	var ev: Array = []
	Pois.discover_near(st, st.actors[1], ev)
	var found: Dictionary = ev[0]
	s.on_events(ev, st)
	eq(s.pois.placed_last.size(), 1, "the farm appears once discovered")
	eq(s.map.poi_markers.size(), 1, "and on the strategic map")
	check(s.hud.toast_box.get_child_count() >= 1, "discovery toast shown")
	var off: Vector2i = HexMath.axial_to_offset(p["hex"])
	var c: Vector2 = HexMath.offset_center(off.x, off.y)
	s.player.position = Vector3(c.x + 2.0, s.world.height_at(c.x, c.y), c.y)
	var it: Dictionary = s.nearest_interactable()
	eq(it.get("kind", &""), &"poi", "standing at the farm offers its interaction")
	check(String(it["label"]).contains("farm"), "prompt names it: %s" % it.get("label", ""))
	s.panels.open_poi(int(it["id"]))
	check(s.panels.poi.visible and s.panels.poi.title_label.text == "DERELICT FARM", "the POI panel opened: %s" % s.panels.poi.title_label.text)
	check(String(found["type"]) == "poi_discovered", "event type")
	# quest tracker reaches the HUD
	var r: Dictionary = Rules.apply(st, {"type": &"accept_quest", "actor": 1, "seq": 1, "args": {"quest": "lfg:quest/judd_1"}})
	s.on_events(r["events"], st)
	check(s.hud.tracker_chip.visible and s.hud.tracker_label.text.contains("Quiet Hands"), "tracker shows the quest: %s" % s.hud.tracker_label.text)
	s.free()

func test_strategic_map_markers_convert_and_label() -> void:
	var s: MatchState = _state()
	var p: Dictionary = _poi(s, "lfg:poi/shrine")
	s.actors[1]["pois_seen"] = [int(p["id"])]
	var m := StrategicMap.new()
	m.set_poi_markers(Pois.markers(s, s.actors[1]))
	eq(m.poi_markers.size(), 1, "one marker")
	eq(m.poi_markers[0]["hex"], HexMath.axial_to_offset(p["hex"]), "converted to offset hex")
	eq(m.poi_markers[0]["prop"], "shrine", "prop key")
	m.free()

func test_quest_panel_tabs_cards_and_signals() -> void:
	var s: MatchState = _state("lfg:class/mira")
	var p := QuestPanel.new()
	p.set_model(Quests.journal(s, s.actors[1]))
	eq(p.tab, "active", "starts on active")
	p.show_tab("available")
	check(p.buttons.has("accept:lfg:quest/mira_1") and p.buttons.has("accept:lfg:quest/settle_in"), "accept buttons for available quests")
	check(not p.buttons.has("accept:lfg:quest/mira_2"), "a locked chapter has none")
	_got.clear()
	p.accept_requested.connect(func(q: String) -> void: _got.append("accept:" + q))
	p.buttons["accept:lfg:quest/mira_1"].pressed.emit()
	eq(_got, ["accept:lfg:quest/mira_1"], "signal only")
	check(not (s.actors[1].get("quests", {}) as Dictionary).has("lfg:quest/mira_1"), "the panel changed no state")
	_cmd(s, UiCommands.accept_quest("lfg:quest/mira_1"))
	p.set_model(Quests.journal(s, s.actors[1]))
	p.show_tab("active")
	check(p.buttons.has("abandon:lfg:quest/mira_1") and p.buttons.has("turn_in:lfg:quest/mira_1"), "active card has abandon and hand-in")
	check(p.buttons["turn_in:lfg:quest/mira_1"].disabled, "nothing to hand in yet")
	p.turn_in_requested.connect(func(q: String) -> void: _got.append("turn:" + q))
	p.abandon_requested.connect(func(q: String) -> void: _got.append("abandon:" + q))
	p.buttons["abandon:lfg:quest/mira_1"].pressed.emit()
	eq(_got[-1], "abandon:lfg:quest/mira_1", "abandon signal")
	eq(UiKit.small_buttons(p).size(), 0, "touch-sized buttons")
	p.show_tab("later")
	eq(p.rows_for("later").size() >= 2, true, "locked chapters and the coming-soon stub are listed under LATER")
	check(p.tab_buttons["later"].text.begins_with("LATER ("), "tab counts: %s" % p.tab_buttons["later"].text)
	p.free()
	var v: MatchState = _state("lfg:class/vex")
	var pv := QuestPanel.new()
	pv.set_model(Quests.journal(v, v.actors[1]))
	pv.show_tab("later")
	var stub_ok: bool = false
	for r in pv.rows_for("later"):
		if String(r["id"]) == "lfg:quest/vex_1" and not bool(r["implemented"]):
			stub_ok = true
	check(stub_ok, "Vex's stub shows as coming soon")
	check(not pv.buttons.has("accept:lfg:quest/vex_1"), "and cannot be accepted")
	pv.free()

func test_quest_panel_steps_progress_and_theme_nod() -> void:
	var s: MatchState = _state("lfg:class/pip")
	s.actors[1]["quests"] = {"lfg:quest/pip_1": {"st": "done"}}
	_cmd(s, UiCommands.accept_quest("lfg:quest/pip_2"))
	s.actors[1]["inv"]["lfg:item/reed_fibre"] = 3
	Quests.observe(s, [], 0, 1)
	var j: Dictionary = Quests.journal(s, s.actors[1])
	var row: Dictionary = j["active"][0]
	eq(row["steps"][0]["progress"], 3, "state-based progress is live")
	eq(row["steps"][0]["theme"], "lfg:class/judd", "the nod to another class is in the model")
	var p := QuestPanel.new()
	p.set_model(j)
	var texts: Array = []
	var stack: Array = [p.list_box]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Label:
			texts.append((n as Label).text)
		stack.append_array(n.get_children())
	var joined: String = "\n".join(PackedStringArray(texts))
	check(joined.contains("(3/6)") and joined.contains("a nod to Judd"), "journal text: %s" % joined.substr(0, 300))
	p.free()

func test_poi_panel_hint_and_actions() -> void:
	var s: MatchState = _state()
	var shrine: Dictionary = _poi(s, "lfg:poi/shrine")
	s.actors[1]["pois_seen"] = [int(shrine["id"])]
	var p := PoiPanel.new()
	p.set_model(Pois.info(s, s.actors[1], int(shrine["id"])))
	eq(p.title_label.text, "WAYSIDE SHRINE", "title")
	check(p.hint_label.text.begins_with("The bowl is carved:"), "lamp pattern shown: %s" % p.hint_label.text)
	check(p.pick_row.visible and not p.go_btn.visible, "three lamp buttons")
	_got.clear()
	p.action_requested.connect(func(i: int, pk: int) -> void: _got.append([i, pk]))
	p.pick_buttons[1].pressed.emit()
	eq(_got, [[int(shrine["id"]), 1]], "emits poi id and pick")
	var vault: Dictionary = _poi(s, "lfg:poi/ruin_vault")
	s.actors[1]["pois_seen"].append(int(vault["id"]))
	p.set_model(Pois.info(s, s.actors[1], int(vault["id"])))
	check(p.hint_label.text.begins_with("The lintel shows"), "plate order shown: %s" % p.hint_label.text)
	var farm: Dictionary = _poi(s, "lfg:poi/derelict_farm")
	s.actors[1]["pois_seen"].append(int(farm["id"]))
	p.set_model(Pois.info(s, s.actors[1], int(farm["id"])))
	check(p.go_btn.visible and p.go_btn.text == "LEAVE THE OFFERING" and not p.go_btn.disabled, "offering button")
	s.poi_state[int(farm["id"])] = {"claimed_week": 0, "week": 0, "prog": 0, "guards": []}
	p.set_model(Pois.info(s, s.actors[1], int(farm["id"])))
	check(p.go_btn.disabled and p.status_label.text.contains("returns when the week turns"), "spent POIs say when they return")
	eq(UiKit.small_buttons(p).size(), 0, "touch-sized buttons")
	p.set_model({})
	check(p.title_label.text != "", "empty model is safe")
	p.free()

func test_new_commands_round_trip_through_ui_commands() -> void:
	var s: MatchState = _state("lfg:class/judd")
	var r: Dictionary = _cmd(s, UiCommands.accept_quest("lfg:quest/settle_in"))
	check(r["ok"], "accept: %s" % r["error"])
	r = _cmd(s, UiCommands.abandon_quest("lfg:quest/settle_in"))
	check(r["ok"], "abandon: %s" % r["error"])
	r = _cmd(s, UiCommands.turn_in("lfg:quest/settle_in"))
	eq(r["error"], "not_active", "nothing to hand in")
	var farm: Dictionary = _poi(s, "lfg:poi/derelict_farm")
	s.actors[1]["hex"] = farm["hex"]
	r = _cmd(s, UiCommands.interact_poi(int(farm["id"])))
	check(r["ok"], "interact: %s" % r["error"])
	eq(UiCommands.interact_poi(4, 2)["args"], {"poi": 4, "pick": 2}, "pick is passed through")
	eq(UiCommands.interact_poi(4)["args"], {"poi": 4}, "no pick key when there is none")
	check(Rules.COMMAND_TYPES.has(&"interact_poi") and Rules.COMMAND_TYPES.has(&"accept_quest") and Rules.COMMAND_TYPES.has(&"abandon_quest") and Rules.COMMAND_TYPES.has(&"turn_in"), "listed in COMMAND_TYPES")

func test_craft_and_build_models_show_locks_and_stations() -> void:
	var s: MatchState = _state("lfg:class/oren")
	var cm: Dictionary = PanelModels.craft_model(s)
	var rows: Dictionary = {}
	for r in cm["rows"]:
		rows[String(r["id"])] = r
	eq(rows["lfg:recipe/hearty_stew"]["reason"], "locked_recipe", "Hearty Stew is locked before the questline")
	eq(rows["lfg:recipe/rope"]["reason"], "needs_station", "rope needs a workbench")
	var bm: Dictionary = PanelModels.build_model(s)
	var brow: Dictionary = {}
	for r in bm["rows"]:
		if String(r["id"]) == "lfg:building/sun_terrace":
			brow = r
	eq(brow["reason"], "locked_building", "terrace locked")
	check(PanelModels.reason_text("locked_building") != "locked_building", "reason text exists")
	var glass: String = ""
	for r in bm["rows"]:
		if String(r["id"]) == "lfg:building/smokehouse":
			glass = String(r["info"])
	check(glass.contains("Spoilage halved") and glass.contains("uses"), "building info explains the effect: %s" % glass)
