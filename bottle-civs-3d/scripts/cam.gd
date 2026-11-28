class_name BCCamRig
extends Node3D
## Orbit camera for the Wall. Wheel = zoom, right-drag = orbit, middle-drag / WASD = pan, Esc = overview.

const OVERVIEW_TARGET := Vector3(0, 1.5, 0)
const OVERVIEW_DIST := 96.0
const OVERVIEW_PITCH := -38.0

var cam: Camera3D
var target := OVERVIEW_TARGET
var dist := OVERVIEW_DIST
var yaw := 0.0
var pitch := OVERVIEW_PITCH
var g_target := OVERVIEW_TARGET
var g_dist := OVERVIEW_DIST
var g_yaw := 0.0
var g_pitch := OVERVIEW_PITCH
var focused := false

func _ready() -> void:
	cam = Camera3D.new()
	cam.fov = 34.0
	cam.near = 0.3
	cam.far = 400.0
	add_child(cam)
	cam.current = true
	_apply()

func overview() -> void:
	g_target = OVERVIEW_TARGET; g_dist = OVERVIEW_DIST; g_pitch = OVERVIEW_PITCH; g_yaw = 0.0
	focused = false

func focus(world_pos: Vector3) -> void:
	g_target = world_pos + Vector3(0, 1.0, 0.8); g_dist = 24.0; g_pitch = -52.0; g_yaw = 0.0
	focused = true

func jump_to_goal() -> void:
	target = g_target; dist = g_dist; yaw = g_yaw; pitch = g_pitch
	_apply()

func _process(dt: float) -> void:
	var k := minf(1.0, dt * 4.5)
	target = target.lerp(g_target, k)
	dist = lerpf(dist, g_dist, k)
	yaw = lerp_angle(deg_to_rad(yaw), deg_to_rad(g_yaw), k) * 180.0 / PI
	pitch = lerpf(pitch, g_pitch, k)
	var pan := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): pan.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): pan.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): pan.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): pan.x += 1
	if pan != Vector3.ZERO:
		var basis_y := Basis(Vector3.UP, deg_to_rad(g_yaw))
		g_target += basis_y * pan.normalized() * dt * g_dist * 0.7
	_apply()

func _apply() -> void:
	var basis_ := Basis.from_euler(Vector3(deg_to_rad(pitch), deg_to_rad(yaw), 0.0))
	cam.global_transform = Transform3D(basis_, target + basis_ * Vector3(0, 0, dist))

func handle_input(ev: InputEvent) -> void:
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP: g_dist = clampf(g_dist * 0.9, 8.0, 150.0)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN: g_dist = clampf(g_dist * 1.1, 8.0, 150.0)
	elif ev is InputEventMouseMotion:
		if ev.button_mask & MOUSE_BUTTON_MASK_RIGHT:
			g_yaw = clampf(g_yaw - ev.relative.x * 0.25, -80.0, 80.0)
			g_pitch = clampf(g_pitch - ev.relative.y * 0.2, -85.0, -8.0)
		elif ev.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			var b := Basis(Vector3.UP, deg_to_rad(g_yaw))
			g_target += b * Vector3(-ev.relative.x, 0, -ev.relative.y) * g_dist * 0.0016
