class_name Player
extends Node3D
## Original procedural low-poly leader: round bean body, mushroom-cap hat, swinging limbs.
## Moves on the heightfield via Walk (no physics bodies). Input: WASD/arrows + `touch_move` from the joystick.
signal hex_changed(hex: Vector2i)
signal moved(pos: Vector3)

const SPEED := 6.0
const TURN_RATE := 12.0

var world: WorldData
var touch_move: Vector2 = Vector2.ZERO # x right, y forward (joystick); length <= 1
var camera_yaw: float = 0.0 # set by FollowCamera
var input_enabled: bool = true
var tunic: Color = Color("19e0c8")
var hat: Color = Color("ff2fb5")
var current_hex: Vector2i = Vector2i(-1, -1)
var velocity_xz: Vector2 = Vector2.ZERO

var _legs: Array[Node3D] = []
var _arms: Array[Node3D] = []
var _body: Node3D
var _phase: float = 0.0
var _mat: StandardMaterial3D

func _init() -> void:
	name = "Player"
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true
	_mat.roughness = 1.0
	_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_build_model()

func set_class_colors(tunic_c: Color, hat_c: Color) -> void:
	tunic = tunic_c
	hat = hat_c
	for ch in get_children():
		ch.queue_free()
	_legs.clear()
	_arms.clear()
	_build_model()

func _mesh_node(k: MeshKit, parent: Node3D, pos: Vector3 = Vector3.ZERO) -> Node3D:
	var n := Node3D.new()
	n.position = pos
	parent.add_child(n)
	var mi := MeshInstance3D.new()
	mi.mesh = k.build()
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	return n

func _build_model() -> void:
	_body = Node3D.new()
	_body.name = "Body"
	add_child(_body)
	var k := MeshKit.new()
	# torso (bean) + belt + backpack
	k.frustum(Vector3.ZERO, 0.45, 0.46, 1.25, 0.34, 7, tunic, tunic.lightened(0.15), true, true)
	k.frustum(Vector3.ZERO, 0.78, 0.44, 0.9, 0.43, 7, Color("5b3a2a"), Color("5b3a2a"), false)
	k.box(Vector3(0, 0.95, 0.42), Vector3(0.5, 0.55, 0.28), Color("c9783a"), Color("e09a58"))
	# head
	k.dome(Vector3(0, 1.25, 0), 0.4, 1.0, 2, 8, Color("ffd9b8"), Color("ffd9b8"))
	k.dome(Vector3(0, 1.25, 0), 0.4, -0.8, 2, 8, Color("f2c29c"), Color("f2c29c"))
	# eyes (face points -Z)
	k.box(Vector3(-0.15, 1.3, -0.37), Vector3(0.1, 0.14, 0.06), Color("2a1838"))
	k.box(Vector3(0.15, 1.3, -0.37), Vector3(0.1, 0.14, 0.06), Color("2a1838"))
	# mushroom-cap hat
	k.dome(Vector3(0, 1.5, 0), 0.72, 0.62, 2, 9, hat, hat.darkened(0.2))
	k.dome(Vector3(0.25, 1.88, -0.1), 0.14, 0.5, 1, 5, Color("fff7c0"))
	k.dome(Vector3(-0.3, 1.8, 0.15), 0.11, 0.5, 1, 5, Color("fff7c0"))
	_mesh_node(k, _body)
	# limbs with hip/shoulder pivots
	for side in [-1.0, 1.0]:
		var lk := MeshKit.new()
		lk.box(Vector3(0, -0.2, 0), Vector3(0.2, 0.42, 0.22), Color("4a3a78"))
		lk.box(Vector3(0, -0.43, -0.04), Vector3(0.22, 0.12, 0.3), Color("2a1838"))
		_legs.append(_mesh_node(lk, _body, Vector3(0.2 * side, 0.46, 0)))
		var ak := MeshKit.new()
		ak.box(Vector3(0, -0.25, 0), Vector3(0.16, 0.5, 0.16), tunic.darkened(0.15))
		ak.box(Vector3(0, -0.52, 0), Vector3(0.18, 0.12, 0.18), Color("ffd9b8"))
		_arms.append(_mesh_node(ak, _body, Vector3(0.5 * side, 1.12, 0)))

func place_on_ground(pos_xz: Vector2) -> void:
	if world != null:
		position = Vector3(pos_xz.x, world.height_at(pos_xz.x, pos_xz.y), pos_xz.y)
	else:
		position = Vector3(pos_xz.x, 0.0, pos_xz.y)
	_refresh_hex()

func read_move_vector() -> Vector2:
	var v := Vector2.ZERO
	if input_enabled:
		if Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP):
			v.y += 1.0
		if Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN):
			v.y -= 1.0
		if Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT):
			v.x += 1.0
		if Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT):
			v.x -= 1.0
		v += touch_move
	return v.limit_length(1.0)

func world_dir_from_input(v: Vector2) -> Vector2:
	var fwd := Vector2(-sin(camera_yaw), -cos(camera_yaw))
	var right := Vector2(cos(camera_yaw), -sin(camera_yaw))
	return right * v.x + fwd * v.y

func _process(dt: float) -> void:
	if world == null:
		return
	var dir: Vector2 = world_dir_from_input(read_move_vector())
	var before: Vector3 = position
	var disp: Vector2 = dir * SPEED * dt
	position = Walk.step(world, position, disp)
	var actual := Vector2(position.x - before.x, position.z - before.z)
	velocity_xz = actual / maxf(dt, 0.0001)
	if actual.length() > 0.0005:
		var want: float = atan2(-dir.x, -dir.y)
		rotation.y = lerp_angle(rotation.y, want, clampf(TURN_RATE * dt, 0.0, 1.0))
		moved.emit(position)
		_refresh_hex()
	_animate(dt)

func _animate(dt: float) -> void:
	var speed01: float = clampf(velocity_xz.length() / SPEED, 0.0, 1.0)
	_phase += dt * (6.0 + 6.0 * speed01) * speed01
	var s: float = sin(_phase) * 0.8 * speed01
	if _legs.size() == 2:
		_legs[0].rotation.x = s
		_legs[1].rotation.x = -s
		_arms[0].rotation.x = -s * 0.8
		_arms[1].rotation.x = s * 0.8
	_body.position.y = absf(sin(_phase)) * 0.08 * speed01

func _refresh_hex() -> void:
	var h: Vector2i = HexMath.world_to_offset(position.x, position.z)
	if h != current_hex:
		current_hex = h
		hex_changed.emit(h)
