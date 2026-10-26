extends TestCase
## Whole presentation rig built off-tree against the real Rules world: load, prompts, map, binder.

func _stage_from_rules(seed_v: int) -> WorldStage:
	var st: MatchState = Rules.new_match(seed_v, &"lfg:class/judd")
	var s := WorldStage.new()
	s.hud._ready()
	s.touch._ready()
	s.map._ready()
	s.start_from_state_sync(st)
	return s

func test_stage_loads_real_rules_world() -> void:
	var s: WorldStage = _stage_from_rules(3)
	eq(s.started, true, "stage started")
	eq(s.view.chunks.size(), 77, "all chunks built")
	check(s.world.walkable(s.player.position.x, s.player.position.z), "player spawns on walkable ground")
	eq(s.fog.state_of(s.player.current_hex), FogOfWar.VISIBLE, "player hex visible")
	check(s.fog.count_in_state(FogOfWar.VISIBLE) > 20, "starting vision revealed")
	check(s.fog.count_in_state(FogOfWar.UNSEEN) > 4000, "rest of the map is fogged")
	eq(s.hud.class_label.text.begins_with("JUDD"), true, "HUD shows the class from Rules state")
	eq(s.hud.banner_title.text.contains("PEACE"), true, "HUD shows phase from Rules state")
	s.free()

func test_interaction_prompt_at_start_holding() -> void:
	var s: WorldStage = _stage_from_rules(3)
	var it: Dictionary = s.nearest_interactable()
	eq(it.get("kind", &""), &"holding", "standing in the homestead offers a holding interaction")
	s.farm.set_plot("z", Vector2(s.player.position.x + 1.0, s.player.position.z), FarmLayer.Stage.RIPE)
	it = s.nearest_interactable()
	eq(it.get("kind", &""), &"plot", "closer ripe plot takes priority")
	eq(it.get("label", ""), "Harvest", "ripe plot says Harvest")
	s.player.position += Vector3(200, 0, 0)
	s.farm.remove_plot("z")
	eq(s.nearest_interactable().get("kind", &"none") != &"plot", true, "no plot prompt when far away")
	s.free()

func test_map_and_grid_toggles() -> void:
	var s: WorldStage = _stage_from_rules(3)
	eq(s.map.visible, false, "map starts closed")
	s.toggle_map()
	eq(s.map.visible, true, "map opens")
	eq(s.player.input_enabled, false, "player input paused while map is open")
	s.toggle_map()
	eq(s.player.input_enabled, true, "input restored")
	s.toggle_grid()
	eq(s.view.terrain_mat.get_shader_parameter("grid_on"), true, "hex grid overlay on the terrain")
	s.toggle_grid()
	eq(s.view.terrain_mat.get_shader_parameter("grid_on"), false, "grid overlay off")
	s.free()

func test_strategic_map_respects_fog() -> void:
	var s: WorldStage = _stage_from_rules(3)
	var m: StrategicMap = s.map
	eq(m._verts.size(), HexMath.COLS * HexMath.ROWS * 7, "7 vertices per hex")
	eq(m._idx.size(), HexMath.COLS * HexMath.ROWS * 18, "6 triangles per hex")
	var seen_i: int = HexMath.idx(s.player.current_hex)
	var far_i: int = 0
	eq(m._hex_color(far_i), StrategicMap.UNSEEN_COLOR, "unexplored hex is drawn as fog")
	check(m._hex_color(seen_i) != StrategicMap.UNSEEN_COLOR, "explored hex shows its biome")
	s.fog.set_reveal_all(true)
	check(m._hex_color(far_i) != StrategicMap.UNSEEN_COLOR, "reveal-all shows everything")
	m.size = Vector2(1280, 720)
	m._update_xform()
	var ext: Rect2 = HexMath.world_extent()
	var tl: Vector2 = m._xform * ext.position
	var br: Vector2 = m._xform * ext.end
	check(tl.x >= 0.0 and tl.y >= 0.0 and br.x <= 1280.0 and br.y <= 720.0, "whole map fits the screen")
	m._select_at((tl + br) * 0.5)
	check(m._info.text.begins_with("Hex "), "tapping a hex shows info (%s)" % m._info.text)
	s.free()

func test_hud_binder_matches_rules() -> void:
	var st: MatchState = Rules.new_match(5, &"lfg:class/oren")
	var m: Dictionary = HudBinder.model_from_state(st)
	eq(m["phase"], st.phase, "phase")
	eq(m["day"], int(st.clock["day"]), "day")
	eq(m["rations"], Economy.rations_available(st, 0), "rations from Rules economy")
	var inv: Dictionary = st.actors[1]["inv"]
	eq((m["inventory"] as Array).size(), inv.size(), "inventory rows = start kit rows")
	check(String(m["class_label"]).to_lower().contains("oren"), "class label (%s)" % m["class_label"])
	check(m["hp_max"] >= m["hp"] and m["hp"] > 0.0, "hp numbers sane")
	st.set_time(7, 0.9)
	eq(HudBinder.model_from_state(st)["phase"], st.phase, "phase follows the clock")

func test_events_drive_visuals() -> void:
	var st: MatchState = Rules.new_match(3, &"lfg:class/judd")
	var s := WorldStage.new()
	s.hud._ready()
	s.start_from_state_sync(st)
	s.on_events([{"type": &"enemy_telegraph", "pos": Vector2(s.player.position.x, s.player.position.z), "shape": "circle", "radius": 5.0, "windup": 1.0}], null)
	eq(s.telegraphs.active_count(), 1, "enemy_telegraph event spawns a danger zone")
	var ax: Vector2i = st.world["start"]
	for h in HexGrid.ring_within(ax, 2):
		if h != ax and Rules.apply(st, {"type": &"plant", "actor": 1, "seq": 1, "args": {"crop": "lfg:crop/glowfruit", "hex": h}})["ok"]:
			break
	s.on_events([{"type": &"crop_planted"}], st)
	eq(s.farm.plots.size(), st.plots.size(), "crop events resync farm visuals")
	s.set_phase(&"PURGE_ACTIVE", true)
	check(s.atmosphere.purge_amount > 0.99, "purge phase tints the world")
	eq(s.telegraphs.purge_colors, true, "telegraph palette switches in purge")
	for ch in s.telegraphs.get_children():
		ch.free()
	s.free()
