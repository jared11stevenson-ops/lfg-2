extends SceneTree
## Character lineup sheet: 14 classes, 6 enemies, NPCs. Needs a display:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tools/art_lineup.gd
var out_dir: String = "res://art/captures/pass1"
var _cam: Camera3D

func _init() -> void:
	_run()

func _frames(n: int) -> void:
	for i in n:
		await process_frame

func _save(name: String) -> void:
	await _frames(4)
	await RenderingServer.frame_post_draw
	var img: Image = root.get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(out_dir))
	img.save_png(ProjectSettings.globalize_path(out_dir.path_join(name + ".png")))
	print("SHOT ", name)

func _stage(rigs: Array, cols: int, spacing: float, cam_dist: float) -> Node3D:
	var w := Node3D.new()
	root.add_child(w)
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color("f1cdbd")
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("b9a8dc")
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	w.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.9, 0.6, 0)
	sun.light_energy = 1.2
	w.add_child(sun)
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(80, 40)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("8ad08a")
	floor_mi.material_override = fm
	w.add_child(floor_mi)
	var rows: int = int(ceil(float(rigs.size()) / float(cols)))
	for i in rigs.size():
		var r: CharacterRig = rigs[i]
		var cx: int = i % cols
		var cy: int = i / cols
		r.position = Vector3((float(cx) - float(cols - 1) * 0.5) * spacing, 0, (float(cy) - float(rows - 1) * 0.5) * spacing * 1.5)
		r.rotation.y = PI + 0.35
		w.add_child(r)
	var cam := Camera3D.new()
	cam.fov = 30
	cam.position = Vector3(0, cam_dist * 0.6, cam_dist)
	w.add_child(cam)
	cam.look_at(Vector3(0, 1.4, 0))
	cam.current = true
	_cam = cam
	return w

func _run() -> void:
	await process_frame
	var cls: Array = []
	for cid in CharacterKit.class_ids():
		cls.append(CharacterKit.build_class(cid))
	var w1: Node3D = _stage(cls, 7, 3.3, 27.0)
	await _save("characters_14_classes")
	w1.queue_free()
	var foes: Array = []
	for e in CharacterKit.ENEMY_IDS:
		foes.append(CharacterKit.build_enemy(e))
	foes.append(CharacterKit.build_npc("villager", 0))
	foes.append(CharacterKit.build_npc("villager", 1))
	foes.append(CharacterKit.build_npc("merchant", 2))
	foes.append(CharacterKit.build_npc("raider", 3))
	var w2: Node3D = _stage(foes, 5, 5.5, 26.0)
	await _save("enemies_npcs_raiders")
	w2.queue_free()
	await _buildings_and_crops()
	quit()

func _vc_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _mesh_row(w: Node3D, meshes: Array, cols: int, spacing: float, scale_f: float = 1.0) -> void:
	var rows: int = int(ceil(float(meshes.size()) / float(cols)))
	var mat: StandardMaterial3D = _vc_mat()
	for i in meshes.size():
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[i]
		mi.material_override = mat
		mi.scale = Vector3.ONE * scale_f
		mi.position = Vector3((float(i % cols) - float(cols - 1) * 0.5) * spacing, 0, (float(i / cols) - float(rows - 1) * 0.5) * spacing)
		mi.rotation.y = 0.5
		w.add_child(mi)

func _buildings_and_crops() -> void:
	var w: Node3D = _stage([], 1, 1.0, 40.0)
	var ms: Array = []
	for id in BuildingModels.all_ids():
		ms.append(BuildingModels.mesh_for(id))
	_mesh_row(w, ms, 4, 12.0)
	_cam.position = Vector3(0, 44, 46)
	_cam.look_at(Vector3(0, 1, 2))
	await _save("buildings_all_types")
	w.queue_free()
	var w2: Node3D = _stage([], 1, 1.0, 30.0)
	var cm: Array = []
	for cid in CropModels.CROPS:
		for st in [FarmLayer.Stage.SPROUT, FarmLayer.Stage.GROWING, FarmLayer.Stage.RIPE, FarmLayer.Stage.WILTED]:
			cm.append(FarmLayer.stage_mesh(st, cid))
	_mesh_row(w2, cm, 4, 7.5)
	_cam.position = Vector3(0, 26, 22)
	_cam.look_at(Vector3(0, 1.5, 0))
	await _save("crops_per_crop_and_stage")
