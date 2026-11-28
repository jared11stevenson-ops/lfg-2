extends SceneTree
func _init():
	for path in OS.get_cmdline_user_args():
		var ps = load(path)
		if ps == null: print("FAIL ", path); continue
		var n = ps.instantiate()
		print("== ", path)
		var sk = n.find_children("*", "Skeleton3D", true, false)
		for s in sk: print("  skeleton bones=", s.get_bone_count(), " first=", s.get_bone_name(0), " ", s.get_bone_name(1), " ", s.get_bone_name(2))
		var ap = n.find_children("*", "AnimationPlayer", true, false)
		for a in ap:
			var names = a.get_animation_list()
			print("  animplayer ", a.get_path(), " n=", names.size(), " ", ", ".join(names.slice(0, 60)))
		var meshes = n.find_children("*", "MeshInstance3D", true, false)
		var tot := AABB()
		for m in meshes: tot = tot.merge(m.get_aabb()) if tot.size != Vector3.ZERO else m.get_aabb()
		print("  meshes=", meshes.size(), " aabb=", tot.size)
		n.free()
	quit()
