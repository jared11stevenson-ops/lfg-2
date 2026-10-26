extends SceneTree
## Pass-1 screenshots: menus, class select, end screens, panels, placement ghost, combat feel, day/night, roads, buildings, crops.
## Needs a display (not headless):
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tools/art_capture_pass1.gd
## Software GL: evidence of looks only, not performance.
var out_dir: String = "res://art/captures/pass1"
var stage: WorldStage
var state: MatchState
var seq: int = 5000

func _init() -> void:
	_run()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _save(name: String, frames: int = 5) -> void:
	await _frames(frames)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	img.save_png(ProjectSettings.globalize_path(out_dir.path_join(name + ".png")))
	print("SHOT ", name)

func _cmd(type: StringName, args: Dictionary) -> Dictionary:
	seq += 1
	var r: Dictionary = Rules.apply(state, {"type": type, "actor": state.player_id, "seq": seq, "args": args})
	if r.get("ok", false):
		stage.on_events(r["events"], state)
	return r

func _new_stage(class_id: StringName, seed_v: int = 7) -> void:
	if stage != null:
		stage.queue_free()
		await process_frame
	state = Rules.new_match(seed_v, class_id)
	stage = WorldStage.new()
	root.add_child(stage)
	await stage.start_from_state(state)
	stage.atmosphere.set_phase(&"PEACE", true)
	await _frames(3)

func _tp_axial(hx: Vector2i) -> void:
	var off: Vector2i = HexMath.axial_to_offset(hx)
	var cen: Vector2 = HexMath.offset_center(off.x, off.y)
	stage.player.place_on_ground(cen)
	stage.fog.reveal(off, 5)
	stage.cam.snap()
	state.actors[state.player_id]["hex"] = hx

func _run() -> void:
	await process_frame
	await _menus()
	await _world_scenes()
	quit()

func _menus() -> void:
	var flow := MenuFlow.new()
	root.add_child(flow)
	await _frames(3)
	flow.main_menu.set_save_info(true, "Day 4 - Judd (Farmer/Monk) - 3 holdings")
	await _save("01_main_menu")
	flow.main_menu.new_match_pressed.emit()
	flow.class_select.select("lfg:class/judd")
	await _frames(6)
	await _save("02_class_select_implemented")
	# All 14 classes are implemented in data now; flag one as WIP in the Content cache to show the unimplemented state.
	Content.class_def("lfg:class/halo")["implemented"] = false
	flow.class_select.populate()
	flow.class_select.select("lfg:class/halo")
	await _frames(6)
	await _save("03_class_select_unimplemented_flagged")
	Content.class_def("lfg:class/halo")["implemented"] = true
	flow.show_game_over({"reason": "leader_died", "day": 9, "class_label": "Judd - Farmer/Monk", "holdings": 3, "total_holdings": 25})
	await _save("04_game_over_permadeath")
	flow.show_victory({"kind": "dominion", "day": 31, "class_label": "Oren - Cook/Medic", "holdings": 16, "total_holdings": 25})
	await _save("05_victory")
	flow.queue_free()
	await process_frame

func _find_open_axial_near(c: Vector2i, r: int, min_d: int) -> Vector2i:
	for h in HexGrid.ring_within(c, r):
		if HexGrid.distance(h, c) >= min_d and WorldGen.move_cost(state.world, h) > 0.0 and not stage.farm.hex_has_plot(HexMath.axial_to_offset(h)):
			return h
	return c

func _world_scenes() -> void:
	await _new_stage(&"lfg:class/bram")
	var home: Vector2i = state.world["start"]
	stage.set_hud_model({"time_of_day": 0.15, "day": 2, "phase": &"PEACE"})
	stage.cam.yaw = 0.45
	stage.cam.snap()
	# --- panels over the world
	var inv: Dictionary = state.actors[state.player_id]["inv"]
	inv["lfg:item/timber"] = 3 # short on purpose so costs show red
	stage.panels.open(&"build")
	await _save("06_build_menu")
	stage.panels.close_all()
	inv["lfg:item/timber"] = 20
	inv["lfg:item/stone"] = 10
	inv["lfg:item/glowfruit"] = 6
	inv["lfg:item/mushroom"] = 3
	stage.panels.bind_state(state)
	stage.panels.open(&"build")
	stage.panels.build.pick("lfg:building/barracks")
	await _frames(4)
	stage.begin_placement("lfg:building/barracks")
	stage.player.rotation.y = 0.0
	await _save("07_build_placement_valid")
	# invalid: walk far from any own holding
	var far: Vector2i = home + Vector2i(9, 4)
	for h in HexGrid.ring_within(home, 9):
		if HexGrid.distance(h, home) >= 6 and WorldGen.move_cost(state.world, h) > 0.0:
			far = h
			break
	_tp_axial(far)
	await _frames(4)
	await _save("08_build_placement_invalid")
	stage.panels.end_placement()
	stage.panels.close_all()
	_tp_axial(home)
	stage.panels.open(&"craft")
	await _save("09_craft_panel")
	stage.panels.close_all()
	# trade: stand next to a merchant holding
	var merchant: int = -1
	for id in state.holdings:
		if state.holdings[id]["merchant"] and state.holdings[id]["owner"] == -1:
			merchant = id
			break
	if merchant >= 0:
		_tp_axial(state.holdings[merchant]["hex"])
		stage.cam.yaw = 0.5
		stage.cam.snap()
		stage.fog.reveal(HexMath.axial_to_offset(state.holdings[merchant]["hex"]), 6)
		stage.actors.refresh()
		stage._update_ui()
		stage.panels.open(&"trade")
		await _save("10_trade_panel")
		stage.panels.close_all()
		await _frames(3)
		await _save("11_merchant_npc_in_world")
	_tp_axial(home)
	stage.panels.open(&"policy")
	await _save("12_policy_panel")
	stage.panels.close_all()
	# holdings with a shortage
	var mine: int = int(state.factions[0]["home"])
	state.holdings[mine]["store"]["lfg:item/ration"] = 0
	state.holdings[mine]["garrison"] = 5
	stage.panels.bind_state(state)
	stage.panels.open(&"holdings")
	await _save("13_holdings_shortage")
	stage.panels.close_all()
	# --- buildings + crops + roads at home
	inv["lfg:item/timber"] = 300
	inv["lfg:item/stone"] = 300
	inv["lfg:item/coin"] = 200
	for b in ["lfg:building/wall", "lfg:building/barracks", "lfg:building/storehouse", "lfg:building/sawmill", "lfg:building/kitchen", "lfg:building/well", "lfg:building/granary", "lfg:building/watchtower"]:
		var br: Dictionary = _cmd(&"build", {"holding": mine, "building": b})
		print("build ", b, " -> ", br.get("ok"), " ", br.get("error"))
	var crops: Array[String] = ["lfg:crop/glowfruit", "lfg:crop/sporebean", "lfg:crop/saltroot"]
	var n: int = 0
	for h in HexGrid.ring_within(home, 2):
		if h == home or n >= 6:
			continue
		var cid: String = crops[n % 3]
		var seed_item: String = String(Content.crop(cid)["seed"])
		state.actors[state.player_id]["inv"][seed_item] = 5
		var r: Dictionary = _cmd(&"plant", {"crop": cid, "hex": h})
		if r.get("ok", false):
			state.plots[MatchState.plot_key(h)]["age"] = 99 if n < 3 else 1
			n += 1
	stage.farm.sync_from_state(state)
	stage.holding_layer.sync_from_state(state)
	stage.cam.yaw = 0.3
	stage.cam.distance = 40.0
	stage.cam.snap()
	_tp_axial(home)
	await _frames(4)
	await _save("14_buildings_crops_roads_home")
	# crop closeup
	stage.cam.distance = 22.0
	stage.cam.pitch_deg = 40.0
	stage.cam.snap()
	await _save("15_crops_three_kinds_ripe")
	stage.cam.distance = 46.0
	stage.cam.pitch_deg = 52.0
	# --- combat feel
	await _combat()
	await _daynight()

func _open_field(home: Vector2i) -> Vector2i:
	for h in HexGrid.ring_within(home, 8):
		if HexGrid.distance(h, home) < 5:
			continue
		var ok: bool = WorldGen.move_cost(state.world, h) > 0.0 and CmdUtil.holding_at(state, h) == -1
		for n in HexGrid.neighbors(h):
			if WorldGen.move_cost(state.world, n) <= 0.0 or CmdUtil.holding_at(state, n) != -1:
				ok = false
		if ok:
			return h
	return home

func _combat() -> void:
	var home: Vector2i = _open_field(state.world["start"])
	_tp_axial(home)
	var kinds: Array[String] = ["lfg:enemy/sporeling", "lfg:enemy/rootbrute", "lfg:enemy/thorn_slinger", "lfg:enemy/mire_leech", "lfg:enemy/gloomwing", "lfg:enemy/bulwark"]
	var ring: Array[Vector2i] = []
	for h in HexGrid.ring_within(home, 1):
		if h != home and WorldGen.move_cost(state.world, h) > 0.0:
			ring.append(h)
	var ids: Array[int] = []
	for i in mini(kinds.size(), ring.size()):
		ids.append(Setup.spawn_enemy(state, kinds[i], ring[i], false))
	for h in HexGrid.ring_within(home, 3):
		if HexGrid.distance(h, home) == 3 and WorldGen.move_cost(state.world, h) > 0.0:
			ids.append(Setup.spawn_enemy(state, "lfg:enemy/sporeling", h, false))
			break
	stage.fog.reveal(HexMath.axial_to_offset(home), 5)
	stage.actors.bind_state(state)
	stage.cam.yaw = 0.0
	stage.cam.distance = 56.0
	stage.cam.pitch_deg = 55.0
	stage.cam.snap()
	await _frames(40)
	print("COMBAT rigs=", stage.actors.rig_count(), " ids=", ids, " player=", stage.player.position)
	for id in stage.actors.rigs:
		var rg: CharacterRig = stage.actors.rigs[id]["rig"]
		print("  rig ", id, " ", rg.look_id, " pos=", rg.position, " vis=", rg.visible, " in_tree=", rg.is_inside_tree())
	# telegraphs + damage numbers + hurt flash through the real event path
	var evs: Array = []
	for i in [1, 2, 3]:
		var e: Dictionary = state.actors[ids[i]]
		evs.append({"type": &"enemy_telegraph", "enemy": ids[i], "attack": "slam", "shape": "aoe" if i == 1 else "single", "target_hex": home if i != 3 else e["hex"], "radius": 1 if i == 1 else 0, "windup": 3.0})
	evs.append({"type": &"actor_damaged", "actor": ids[0], "source": 1, "amount": 14, "hp": 3, "tag": "attack"})
	evs.append({"type": &"actor_damaged", "actor": ids[1], "source": 1, "amount": 6, "hp": 54, "tag": "attack"})
	evs.append({"type": &"actor_damaged", "actor": state.player_id, "source": ids[2], "amount": 9, "hp": 80, "tag": "attack"})
	evs.append({"type": &"actor_attacked", "actor": ids[3], "target": state.player_id, "damage": 4})
	stage.on_events(evs, state)
	# ability cooldown ring: Bram's rage on cooldown
	var a: Dictionary = state.actors[state.player_id]
	a["cd"]["ab:lfg:ability/rage"] = float(state.clock["elapsed"]) + 24.0
	stage.combat_hud.abilities.update_from_state(state)
	await _frames(6)
	stage.combat_hud.flash_hurt(9)
	stage.player.play_attack()
	await _save("16_combat_feel_telegraphs_numbers", 1)
	# off-screen threat arrows: zoom in so most enemies are outside the view
	stage.cam.distance = 14.0
	stage.cam.snap()
	stage._update_ui()
	await _frames(10)
	await _save("17_danger_arrows_edge")
	# death pose
	state.actors[ids[0]]["alive"] = false
	stage.on_events([{"type": &"actor_died", "actor": ids[0], "kind": "enemy", "faction": -2, "killer": 1, "hex": state.actors[ids[0]]["hex"], "items": {}, "items_to": ""}], state)
	stage.cam.distance = 56.0
	stage.cam.snap()
	await _frames(30)
	await _save("18_enemy_death_and_hit_flash")

func _daynight() -> void:
	# clear enemies for clean looks
	for id in state.actors.keys():
		if state.actors[id]["kind"] == "enemy":
			state.actors[id]["alive"] = false
	stage.actors.refresh()
	await _frames(100)
	var home: Vector2i = state.world["start"]
	_tp_axial(home)
	stage.cam.yaw = 0.7
	stage.cam.distance = 52.0
	stage.cam.snap()
	for pair in [["dawn", 0.0], ["noon", 0.25], ["dusk", 0.5], ["night", 0.75]]:
		stage.atmosphere.set_phase(&"PEACE", true)
		stage.set_hud_model({"time_of_day": float(pair[1]), "phase": &"PEACE"})
		stage.atmosphere.blend_speed = 100.0
		await _frames(8)
		await _save("19_daynight_%s" % pair[0])
	# purge night with shadows on
	stage.set_shadows(true)
	stage.set_hud_model({"time_of_day": 0.6, "phase": &"PURGE_ACTIVE", "day": 7})
	await _frames(10)
	await _save("20_purge_night_shadows_on")
