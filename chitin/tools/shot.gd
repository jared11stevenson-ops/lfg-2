extends Node
# godot --path chitin --rendering-driver opengl3 -- --shot out.png
func _ready() -> void:
	Lineage.new_lineage(5)
	Lineage.echoes.push_front(Echo.make(Lineage.genome, 1, {"kills": 0, "recruits": 4, "calms": 2, "cause": "molted"}, Lineage.rng))
	var w := InstarWorld.new()
	add_child(w)
	for i in 90: await get_tree().process_frame
	w.hud.scent_panel.visible = true
	for i in 10: await get_tree().process_frame
	var img := get_viewport().get_texture().get_image()
	img.save_png(OS.get_cmdline_user_args()[1])
	get_tree().quit()
