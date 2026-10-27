extends SceneTree
## Pass 4 evidence shots (software GL, not a benchmark): companions at heel, a guardian arena with the boss bar and its telegraph, the PETS panel, the first-days
## guide with the Purge card, new buildings. Needs a display:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 -s art/capture_pass4.gd
var stage: WorldStage
var st: MatchState
const OUT := "res://art/captures/pass4"

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _shot(name: String) -> void:
	await _frames(8)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT))
	var err: int = img.save_png(ProjectSettings.globalize_path(OUT.path_join(name + ".png")))
	print("SHOT %s %dx%d err=%d" % [name, img.get_width(), img.get_height(), err])

func _tp(hex_axial: Vector2i) -> void:
	var off: Vector2i = HexMath.axial_to_offset(hex_axial)
	var cen: Vector2 = HexMath.offset_center(off.x, off.y)
	stage.player.place_on_ground(cen)
	stage.fog.reveal(off, 7)
	stage.cam.snap()

func _run() -> void:
	st = Rules.new_match(11, &"lfg:class/judd", {"day_seconds": 120.0, "tutorial": true, "ai_enabled": false})
	stage = WorldStage.new()
	root.add_child(stage)
	stage.start_from_state_sync(st)
	await _frames(4)
	var a: Dictionary = st.actors[1]
	for k in ["lfg:companion/mossbun", "lfg:companion/glowmoth", "lfg:companion/dewsnail", "lfg:companion/truffler", "lfg:companion/brindlehen", "lfg:companion/bristlepup"]:
		Companions.give(st, a, k, [])
	var i: int = 0
	for c in a["companions"]:
		c["post"] = "follow" if i < 2 else "hold"
		c["hold"] = 1 if i >= 2 else -1
		i += 1
	stage.companions.sync()
	stage.set_hud_model(HudBinder.model_from_state(st))
	stage.panels.refresh()
	stage.cam.yaw = 0.4
	await _frames(40)
	await _shot("01_companions_at_heel_and_first_days_banner")
	stage.panels.open(&"companions")
	stage.panels.refresh()
	await _shot("02_pets_panel")
	stage.panels.close_all()
	# the Purge card
	for q in ["lfg:quest/tut_1_furrow", "lfg:quest/tut_2_warm", "lfg:quest/tut_3_roof"]:
		a["quests"][q] = {"st": "done"}
	Quests.accept(st, a, {"quest": "lfg:quest/tut_4_dusk"}, [])
	stage.panels.refresh()
	await _shot("03_purge_card")
	stage.panels.tutorial.card.visible = false
	# guardian arenas: one shot each, boss standing at its gate
	var idx: int = 4
	for biome in ["meadow", "ruins", "fungal_grove", "bog", "salt_flats", "highlands", "shore"]:
		var arena: Dictionary = {}
		for p in st.world["pois"]:
			if String(p["type"]) == "lfg:poi/arena_" + biome:
				arena = p
		var at: Vector2i = arena["hex"] + HexGrid.DIRS[3] * 3
		a["hex"] = at
		_tp(at)
		(a["pois_seen"] as Array).append(int(arena["id"])) if a.has("pois_seen") else a.set("pois_seen", [int(arena["id"])])
		stage.pois.show_all = true
		stage._sync_pois(st)
		# summon the boss (a real interact_poi), then show one telegraph
		var save_hex: Vector2i = a["hex"]
		a["hex"] = arena["hex"]
		Rules.apply(st, {"type": &"interact_poi", "actor": 1, "seq": int(a["last_seq"]) + 1, "args": {"poi": arena["id"]}})
		a["hex"] = save_hex
		stage.set_hud_model(HudBinder.model_from_state(st))
		stage.actors.refresh()
		stage.cam.yaw = 0.0
		var evs: Array = []
		for t in range(30):
			evs.append_array(Rules.tick(st, 0.1))
		stage.on_events(evs, st)
		stage._update_ui()
		await _frames(30)
		await _shot("%02d_guardian_%s" % [idx, biome])
		idx += 1
		for id in st.actors.keys():
			if st.actors[id]["kind"] == "enemy":
				st.actors[id]["alive"] = false
		stage.actors.refresh()
	get_root().get_child(0).queue_free()
	quit(0)

func _init() -> void:
	_run()
