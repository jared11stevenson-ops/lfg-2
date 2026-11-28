extends SceneTree
# Art evidence: a lineup of all body plans, rendered. Usage: tools/shot.sh res://tools/lineup.gd
func _initialize():
	var bg := ColorRect.new(); bg.color = Color(0.82, 0.76, 0.6); bg.size = Vector2(1280, 720)
	root.add_child(bg)
	var rng := RandomNumberGenerator.new(); rng.seed = 7
	var k := 0
	for a in Archetypes.LIST:
		var g := Archetypes.make_genome(a, rng)
		var c := CreatureNode.new().setup(g, a["bp"], 100 + k)
		var col := k % 5; var row := k / 5
		c.position = Vector2(130 + col * 255, 120 + row * 230)
		c.scale = Vector2(1.9, 1.9)
		c.rotation = [0.3, -0.4, 0.1, 0.6, -0.2][col]
		c.pose["phase"] = 1.0 + k; c.pose["spd"] = 0.5; c.pose["t"] = 1.3 * k
		root.add_child(c)
		k += 1
	for i in 4: await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://captures/lineup_v2.png")
	quit()
