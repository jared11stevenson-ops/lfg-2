extends SceneTree
## SIMULATION OUTPUT: run a world forward, then photograph the largest civilization the sim actually produced.
func _initialize():
	var seed_ := 12; var ticks := 400
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="): seed_ = int(a.substr(5))
		if a.begins_with("ticks="): ticks = int(a.substr(6))
	var s := EcoSim.new(); s.generate(seed_)
	for i in ticks: s.step()
	var best: Dictionary = {}
	for c in s.civs: if best.is_empty() or c["structures"].size() > best["structures"].size(): best = c
	if best.is_empty(): print("no civ emerged"); quit(); return
	print("civ %s (%s) structs=%d know=%d" % [best["name"], s.species[best["sp"]]["name"], best["structures"].size(), best["know"].size()])
	var styles := {}
	for st in best["structures"]: styles[st["style"]] = styles.get(st["style"], 0) + 1
	print(styles)
	var ps := PlayScene.new(); ps.autoplay_input = false
	root.add_child(ps)
	ps.start_from_sim(s, "", true)
	var cx := 0.0; var cy := 0.0
	for st in best["structures"]: cx += st["tile"].x; cy += st["tile"].y
	var n := float(best["structures"].size())
	ps.focus = Vector2(cx / n, cy / n) * 32.0 + Vector2(16, 16)
	ps.cam.zoom = Vector2(0.55, 0.55)
	ps.set_process(false)
	ps.cam.position = ps.focus
	for i in 30: await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://captures/civ_real_seed%d.png" % seed_)
	quit()
