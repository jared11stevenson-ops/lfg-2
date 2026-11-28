extends SceneTree
func _initialize():
	var m = load("res://main.gd").new()
	root.add_child(m)
	var st := "title"
	for a in OS.get_cmdline_user_args(): if a.begins_with("state="): st = a.substr(6)
	for i in 6: await process_frame
	if st == "new": m.title._build_new()
	if st == "settings": m.title._build_settings()
	for i in 12: await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://captures/ui_%s.png" % st)
	quit()
