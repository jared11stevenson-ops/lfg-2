extends SceneTree
func _init():
	for path in OS.get_cmdline_user_args():
		var n = (load(path) as PackedScene).instantiate()
		var meshes = n.find_children("*", "MeshInstance3D", true, false)
		var tot := AABB(); var first := true
		for m in meshes:
			var bb = m.global_transform * m.get_aabb() if m.is_inside_tree() else m.get_aabb()
			tot = bb if first else tot.merge(bb); first = false
		print(path.get_file(), " size=", tot.size, " pos=", tot.position)
		for a in n.find_children("*", "AnimationPlayer", true, false):
			print("   anims: ", ", ".join(a.get_animation_list()))
		n.free()
	quit()
