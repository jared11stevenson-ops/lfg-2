class_name FollowCamera
extends Camera3D
## Diorama follow camera: telephoto-ish FOV, ~52 degree pitch, yaw rotation (Q/E, RMB drag, touch drag),
## zoom (wheel / pinch). Keeps above terrain. Tuned for a small landscape phone (compact mode = tighter).
var target: Node3D
var world: WorldData
var yaw: float = 0.0
var pitch_deg: float = 52.0
var distance: float = 46.0
var min_distance: float = 18.0
var max_distance: float = 90.0
var look_height: float = 1.0
var follow_speed: float = 8.0
var compact: bool = false:
	set(v):
		compact = v
		distance = 36.0 if v else 46.0
		fov = 40.0 if v else 34.0

func _init() -> void:
	name = "FollowCamera"
	fov = 36.0
	near = 0.5
	far = 900.0
	keep_aspect = Camera3D.KEEP_HEIGHT
	current = true

func rotate_yaw(rad: float) -> void:
	yaw = wrapf(yaw + rad, -PI, PI)

func zoom_by(factor: float) -> void:
	distance = clampf(distance * factor, min_distance, max_distance)

func snap() -> void:
	if target != null:
		global_position = _desired_position()
		_aim()

func _desired_position() -> Vector3:
	var pr: float = deg_to_rad(pitch_deg)
	var off := Vector3(sin(yaw) * cos(pr), sin(pr), cos(yaw) * cos(pr)) * distance
	var p: Vector3 = target.global_position + Vector3(0, look_height, 0) + off
	if world != null:
		p.y = maxf(p.y, world.height_at(p.x, p.z) + 3.0)
	return p

func _aim() -> void:
	look_at(target.global_position + Vector3(0, look_height, 0), Vector3.UP)

func _process(dt: float) -> void:
	if target == null:
		return
	if Input.is_physical_key_pressed(KEY_Q):
		rotate_yaw(-1.8 * dt)
	if Input.is_physical_key_pressed(KEY_E):
		rotate_yaw(1.8 * dt)
	var k: float = 1.0 - exp(-follow_speed * dt)
	global_position = global_position.lerp(_desired_position(), k)
	_aim()
	if target is Player:
		(target as Player).camera_yaw = yaw

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion and (ev.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		rotate_yaw(-ev.relative.x * 0.006)
	elif ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP:
			zoom_by(0.92)
		elif ev.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			zoom_by(1.08)
