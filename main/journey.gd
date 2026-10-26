extends Node
## Scripted integrated journey (visual position set per hex step; ALL game effects go through Rules commands).
## Run: xvfb-run -a godot --path . --rendering-driver opengl3 -- --journey
var m: Node
func run(main: Node) -> void:
	m = main
	await get_tree().create_timer(6.0).timeout
	while m.stage == null or not m.stage.started:
		await get_tree().process_frame
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
	await _shot("02_planted")
	var pid: int = st.player_id
	var day0: int = int(st.clock["day"])
	var phases: Dictionary = {}
	var t: float = 0.0
	while st.phase != &"WARNING" and t < 4000.0:
		Game.events_emitted.emit(Rules.tick(st, 1.0)); t += 1.0
	m.stage.set_hud_model(HudBinder.model_from_state(st))
	await _shot("03_warning_day%d" % int(st.clock["day"]))
	while st.phase != &"PURGE_ACTIVE" and t < 8000.0:
		Game.events_emitted.emit(Rules.tick(st, 1.0)); t += 1.0
	m.stage.set_hud_model(HudBinder.model_from_state(st))
	await _shot("04_purge")
	log.append("day %d -> %d, phase %s, over=%s, rations=%s" % [day0, int(st.clock["day"]), st.phase, st.over, str(Economy.rations_available(st, int(st.actors[pid]["faction"])))])
	print("JOURNEY:\n  ", "\n  ".join(log))
	get_tree().quit()
func _shot(n: String) -> void:
	await RenderingServer.frame_post_draw
	await get_tree().create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://art/captures/integrated/%s.png" % n)
