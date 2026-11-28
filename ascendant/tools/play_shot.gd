extends SceneTree
## Launch the real game scene, drive the player with the same API a human uses, capture frames.
func _initialize():
	var seed_ := 3; var arch := "vole"; var secs := 6.0; var tag := "play"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="): seed_ = int(a.substr(5))
		if a.begins_with("species="): arch = a.substr(8)
		if a.begins_with("secs="): secs = float(a.substr(5))
		if a.begins_with("tag="): tag = a.substr(4)
	var ps := PlayScene.new()
	ps.autoplay_input = false
	root.add_child(ps)
	ps.start_new(seed_, arch, 60)
	var t := 0.0
	var shot := 0
	while t < secs:
		await process_frame
		t += 1.0 / 20.0
		if is_instance_valid(ps.player):
			ps.player.move_dir = Vector2(1, 0.3).rotated(t * 0.4).normalized() * 0.8
	root.get_viewport().get_texture().get_image().save_png("res://captures/%s.png" % tag)
	print("critters=", ps.critters.size(), " species_alive=", ps.sim.totals().size(), " player=", ps.player.sp_name)
	quit()
