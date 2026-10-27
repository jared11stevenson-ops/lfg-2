extends SceneTree
## Pass 3 in-world captures: discovered POIs with beacons, the quest journal, the POI panel, the HUD tracker, the strategic map markers. Needs a display:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tools/art_pass3_world.gd
var out_dir: String = "res://art/captures/pass3"
var stage: WorldStage
var state: MatchState
var seq: int = 9000

func _init() -> void:
	_run()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _save(name: String, frames: int = 6) -> void:
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

func _tp(hx: Vector2i, off_m: Vector2 = Vector2(5, 7)) -> void:
	var off: Vector2i = HexMath.axial_to_offset(hx)
	var cen: Vector2 = HexMath.offset_center(off.x, off.y) + off_m
	stage.player.place_on_ground(cen)
	stage.fog.reveal(off, 4)
	stage.cam.snap()
	state.actors[state.player_id]["hex"] = hx

func _poi(type: String) -> Dictionary:
	for p in state.world["pois"]:
		if p["type"] == type:
			return p
	return {}

func _run() -> void:
	await process_frame
	state = Rules.new_match(7, &"lfg:class/judd")
	stage = WorldStage.new()
	root.add_child(stage)
	await stage.start_from_state(state)
	stage.atmosphere.set_phase(&"PEACE", true)
	await _frames(3)
	_cmd(&"accept_quest", {"quest": "lfg:quest/judd_1"})
	_cmd(&"accept_quest", {"quest": "lfg:quest/lay_of_the_land"})
	# walk up to a farm and a shrine (discovery toasts, props, beacons)
	var farm: Dictionary = _poi("lfg:poi/derelict_farm")
	_tp(farm["hex"])
	var ev: Array = []
	Pois.discover_near(state, state.actors[1], ev)
	stage.on_events(ev, state)
	await _save("poi_farm_discovered")
	stage.panels.open_poi(int(farm["id"]))
	await _save("poi_panel_farm")
	stage.panels.close_all()
	var shrine: Dictionary = _poi("lfg:poi/shrine")
	_tp(shrine["hex"])
	ev = []
	Pois.discover_near(state, state.actors[1], ev)
	stage.on_events(ev, state)
	stage.panels.open_poi(int(shrine["id"]))
	await _save("poi_panel_shrine_lamps")
	stage.panels.close_all()
	await _save("poi_shrine_in_world")
	stage.panels.open(&"quests")
	await _save("quest_journal_active")
	stage.panels.quests.show_tab("available")
	await _save("quest_journal_available")
	stage.panels.close_all()
	stage.toggle_map()
	await _save("strategic_map_poi_markers")
	stage.toggle_map()
	quit()
