extends Node
## Scripted integrated journey. Position is walked visually; ALL game effects go through Rules commands via the session.
## Run: xvfb-run -a godot --path . --rendering-driver opengl3 -- --journey
var m: Node
func run(main: Node) -> void:
	m = main
	while m.stage == null or not m.stage.started:
		await get_tree().process_frame
	await get_tree().create_timer(3.0).timeout
	var st: MatchState = Game.state
	var log: PackedStringArray = []
	await _shot("01_start")
	var here: Vector2i = HexMath.offset_to_axial(m.stage.player.current_hex)
	var n: int = 0
	for h in HexGrid.ring_within(here, 1):
		if n >= 4: break
		var r: Dictionary = m.cmd(&"plant", {"crop": "lfg:crop/glowfruit", "hex": h})
		log.append("plant %s -> %s %s" % [h, r.get("ok"), r.get("error")])
		if r.get("ok"):
			n += 1
			m.cmd(&"water", {"hex": h})
	m.stage.farm.sync_from_state(st)
	m.stage.panels.open(&"build")
	await _shot("02_build_panel")
	m.stage.panels.close_all()
	m.stage.panels.open(&"holdings")
	await _shot("03_holding_panel")
	m.stage.panels.close_all()
	m.stage.panels.open(&"quests")
	await _shot("03a_quest_journal")
	m.stage.panels.close_all()
	m.stage.panels.open(&"companions")
	await _shot("03d_companions")
	m.stage.panels.close_all()
	m._open_standing()
	await _shot("03b_standing_panel")
	m.standing_panel.visible = false
	m._open_skills()
	await _shot("03c_skill_tree")
	m.skill_panel.visible = false
	var ab: Dictionary = m.cmd(&"use_ability", {"ability": "lfg:ability/guard"})
	log.append("ability guard -> %s %s" % [ab.get("ok"), ab.get("error")])
	var t: float = 0.0
	while st.phase != &"WARNING" and t < 4000.0:
		Game.events_emitted.emit(Rules.tick(st, 1.0)); t += 1.0
	m.stage.set_hud_model(HudBinder.model_from_state(st))
	await _shot("04_warning")
	while st.phase != &"PURGE_ACTIVE" and t < 8000.0:
		Game.events_emitted.emit(Rules.tick(st, 1.0)); t += 1.0
	m.stage.set_hud_model(HudBinder.model_from_state(st))
	await _shot("05_purge")
	log.append("day %d, phase %s, over=%s" % [int(st.clock["day"]), st.phase, st.over])
	print("JOURNEY:\n  ", "\n  ".join(log))
	get_tree().quit()
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/captures/integrated/%s.png" % n)
