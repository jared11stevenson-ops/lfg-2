extends SceneTree
## Pass 3 sheets: the seventeen new/previously-pending building models and the seven POI props with their beacons. Needs a display:
##   xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 -s tools/art_pass3.gd
var out_dir: String = "res://art/captures/pass3"
var _cam: Camera3D
const NEW_BUILDINGS: Array[String] = ["shrine", "greenhouse", "forge", "workbench", "kiln", "loom", "spore_forge", "brew_vat", "smokehouse", "cistern", "fortified_gate",
	"glasshouse", "lantern_mast", "trophy_hall", "infirmary", "sun_terrace", "anvil_hall"]

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

func _stage() -> Node3D:
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
	pm.size = Vector2(200, 120)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color("8ad08a")
	floor_mi.material_override = fm
	w.add_child(floor_mi)
	var cam := Camera3D.new()
	cam.fov = 30
	w.add_child(cam)
	cam.current = true
	_cam = cam
	return w

func _vc_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.vertex_color_is_srgb = true
	m.roughness = 1.0
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	return m

func _grid(w: Node3D, meshes: Array, cols: int, spacing: float) -> void:
	var rows: int = int(ceil(float(meshes.size()) / float(cols)))
	var mat: StandardMaterial3D = _vc_mat()
	for i in meshes.size():
		var mi := MeshInstance3D.new()
		mi.mesh = meshes[i]
		mi.material_override = mat
		mi.position = Vector3((float(i % cols) - float(cols - 1) * 0.5) * spacing, 0, (float(i / cols) - float(rows - 1) * 0.5) * spacing)
		mi.rotation.y = PI + 0.45
		w.add_child(mi)

func _run() -> void:
	await process_frame
	var w: Node3D = _stage()
	var ms: Array = []
	for n in NEW_BUILDINGS:
		ms.append(BuildingModels.mesh_for("lfg:building/" + n))
	_grid(w, ms, 6, 12.0)
	_cam.position = Vector3(0, 62, 66)
	_cam.look_at(Vector3(0, 1, 2))
	await _save("buildings_pass3")
	w.queue_free()
	var w2: Node3D = _stage()
	var ps: Array = []
	for k in PoiModels.PROPS:
		ps.append(PoiModels.mesh_for(k))
	ps.append(PoiModels.mesh_for("beacon_on"))
	ps.append(PoiModels.mesh_for("beacon_off"))
	_grid(w2, ps, 5, 12.0)
	_cam.position = Vector3(0, 40, 50)
	_cam.look_at(Vector3(0, 2, 1))
	await _save("poi_props")
	w2.queue_free()
	quit()
