class_name CharacterPreview
extends SubViewportContainer
## Turntable 3D preview of a class look (own World3D, so it never touches the game scene). Used by the class-select screen.
var viewport: SubViewport
var rig: CharacterRig
var spin: float = 0.6
var current_id: String = ""
var _pivot: Node3D

func _init(px: Vector2 = Vector2(300, 340)) -> void:
	name = "CharacterPreview"
	stretch = true
	custom_minimum_size = px
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = true
	viewport.size = Vector2i(px)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(viewport)
	var env := Environment.new()
	env.background_mode = Environment.BG_CLEAR_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("c8b8f0")
	env.ambient_light_energy = 0.9
	var we := WorldEnvironment.new()
	we.environment = env
	viewport.add_child(we)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.7, 0)
	sun.light_energy = 1.15
	viewport.add_child(sun)
	_pivot = Node3D.new()
	viewport.add_child(_pivot)
	# soft platform
	var plat := MeshKit.new()
	plat.frustum(Vector3.ZERO, -0.2, 1.5, 0.0, 1.4, 14, Color("8f5cff"), Color("b890ff"), true, true)
	var pm := MeshInstance3D.new()
	pm.mesh = plat.build()
	var mat := StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.vertex_color_is_srgb = true
	mat.roughness = 1.0
	pm.material_override = mat
	_pivot.add_child(pm)
	var cam := Camera3D.new()
	cam.fov = 28
	cam.position = Vector3(0, 2.6, 8.8)
	viewport.add_child(cam)
	cam.look_at_from_position(cam.position, Vector3(0, 1.3, 0))
	cam.current = true

func show_class(class_id: String) -> void:
	current_id = class_id
	if rig != null:
		_pivot.remove_child(rig)
		rig.queue_free()
	rig = CharacterKit.build_class(class_id)
	rig.rotation.y = PI
	_pivot.add_child(rig)
	rig.scale = Vector3.ONE * 1.25

func _process(dt: float) -> void:
	if rig != null and is_visible_in_tree():
		_pivot.rotation.y += dt * spin
