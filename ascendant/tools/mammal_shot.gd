extends SceneTree
func _initialize():
	var bg := ColorRect.new(); bg.color = Color(0.5, 0.58, 0.36); bg.size = Vector2(1280, 720); root.add_child(bg)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var ids := ["vole", "hare", "reedgnaw", "mole", "squirrel", "stoat"]
	for i in ids.size():
		var a := Archetypes.by_id(ids[i])
		var c := CreatureNode.new().setup(Archetypes.make_genome(a, rng, 0.01), a["bp"], 10 + i)
		c.position = Vector2(220 + (i % 3) * 420, 190 + (i / 3) * 340); c.scale = Vector2(3.4, 3.4); c.rotation = 0.0
		c.pose["spd"] = 0.0; c.pose["t"] = 1.0
		root.add_child(c)
	for i in 4: await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://captures/mammals_v1.png")
	quit()
