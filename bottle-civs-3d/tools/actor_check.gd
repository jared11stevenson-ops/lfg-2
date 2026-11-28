extends SceneTree
func _init():
	var root := Node3D.new(); get_root().add_child(root)
	for i in BCData.RACES.size():
		var a := BCActor.new(); root.add_child(a); a.setup(BCData.RACES[i])
		print(BCData.RACES[i].name, " model_scale=", a.model.scale, " h=", a._model_height(a.model), " skel=", a.skeleton != null, " clips=", a.anim_lib.get_animation_list().size() if a.anim_lib else -1)
	quit()
