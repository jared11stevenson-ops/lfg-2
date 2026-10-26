class_name CharacterRig
extends Node3D
## Procedural rigged low-poly character (no imported assets). Parts are rigid vertex-coloured meshes on pivots;
## animation is pure maths: idle bob, walk swing, attack, hurt recoil, death topple, plus a white hit flash.
## Drive with `speed01` (0..1) and `play(&"attack"|&"hurt"|&"death")`. `advance(dt)` is called from _process but can
## be called by hand (tests, tools). Face direction is -Z, like Player.
signal anim_finished(anim: StringName)

const ATTACK_T := 0.45
const HURT_T := 0.32
const DEATH_T := 0.75
const FLASH_T := 0.22

var anim: StringName = &"idle"
var anim_t: float = 0.0
var speed01: float = 0.0
var dead: bool = false
var float_height: float = 0.0 # flyers hover
var nominal_height: float = 2.0
var look_id: String = ""
var parts: Array[Dictionary] = [] # {node:Node3D, kind:String(leg|arm|wing|body|tail), side:float}
var body: Node3D
var mesh_count: int = 0
var tri_total: int = 0
var _phase: float = 0.0
var _flash: float = 0.0
var _mat: StandardMaterial3D
var _time: float = 0.0

func _init() -> void:
	name = "CharacterRig"
	_mat = StandardMaterial3D.new()
	_mat.vertex_color_use_as_albedo = true
	_mat.vertex_color_is_srgb = true
	_mat.roughness = 1.0
	_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_mat.emission_enabled = true
	_mat.emission = Color(1, 1, 1)
	_mat.emission_energy_multiplier = 0.0
	body = Node3D.new()
	body.name = "Body"
	add_child(body)

## Add one rigid mesh on its own pivot (pivot at `pivot_pos` in body space). Returns the pivot.
func add_part(kit: MeshKit, pivot_pos: Vector3 = Vector3.ZERO, kind: String = "body", side: float = 0.0) -> Node3D:
	var n := Node3D.new()
	n.position = pivot_pos
	n.name = "%s%d" % [kind, parts.size()]
	body.add_child(n)
	var mi := MeshInstance3D.new()
	mi.mesh = kit.build()
	mi.material_override = _mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if _casts_shadows else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(mi)
	mesh_count += 1
	tri_total += kit.tri_count()
	parts.append({"node": n, "kind": kind, "side": side})
	return n

var _casts_shadows: bool = false
func set_cast_shadows(on: bool) -> void:
	_casts_shadows = on
	var stack: Array[Node] = [body]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MeshInstance3D:
			(n as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		stack.append_array(n.get_children())

func limbs(kind: String) -> Array[Node3D]:
	var out: Array[Node3D] = []
	for p in parts:
		if p["kind"] == kind:
			out.append(p["node"])
	return out

func play(a: StringName) -> void:
	if dead:
		return
	anim = a
	anim_t = 0.0
	if a == &"hurt":
		_flash = FLASH_T
	elif a == &"death":
		dead = true
		_flash = FLASH_T

func flash() -> void:
	_flash = FLASH_T

func is_flashing() -> bool:
	return _flash > 0.0

func flash_amount() -> float:
	return _mat.emission_energy_multiplier

func _process(dt: float) -> void:
	advance(dt)

func advance(dt: float) -> void:
	_time += dt
	anim_t += dt
	_phase += dt * (6.0 + 6.0 * speed01) * speed01
	if _flash > 0.0:
		_flash = maxf(_flash - dt, 0.0)
	_mat.emission_energy_multiplier = (_flash / FLASH_T) * 0.9
	var swing: float = sin(_phase) * 0.8 * speed01
	var idle: float = sin(_time * 2.0) * 0.03
	# reset body transform, then layer the active animation
	body.rotation = Vector3.ZERO
	body.position = Vector3(0, float_height, 0)
	var arm_extra: float = 0.0
	match anim:
		&"attack":
			var p: float = clampf(anim_t / ATTACK_T, 0.0, 1.0)
			arm_extra = _attack_curve(p)
			body.rotation.x = -sin(p * PI) * 0.3
			body.position.z = -sin(p * PI) * 0.35
			if anim_t >= ATTACK_T:
				_finish()
		&"hurt":
			var p2: float = clampf(anim_t / HURT_T, 0.0, 1.0)
			body.rotation.x = sin(p2 * PI) * 0.45
			body.position.z = sin(p2 * PI) * 0.25
			if anim_t >= HURT_T:
				_finish()
		&"death":
			var p3: float = clampf(anim_t / DEATH_T, 0.0, 1.0)
			var e: float = p3 * p3 * (3.0 - 2.0 * p3)
			body.rotation.z = e * (PI * 0.5)
			body.position.y = float_height * (1.0 - e) + 0.0
			body.position.x = e * 0.5
			if anim_t >= DEATH_T and anim != &"dead":
				anim = &"dead"
				anim_finished.emit(&"death")
		&"dead":
			body.rotation.z = PI * 0.5
			body.position.x = 0.5
			body.position.y = 0.0
		_:
			body.position.y += absf(sin(_phase)) * 0.08 * speed01 + idle * 0.5
	if anim == &"dead":
		return
	for p in parts:
		var node: Node3D = p["node"]
		var side: float = p["side"]
		match p["kind"]:
			"leg":
				node.rotation.x = swing * side
			"arm":
				var a: float = -swing * side * 0.8 + idle * side
				if side > 0.0:
					a += arm_extra
				node.rotation.x = a
			"wing":
				node.rotation.z = side * (0.35 + sin(_time * 14.0) * 0.55)
			"tail":
				node.rotation.y = sin(_time * 5.0 + _phase) * 0.5 * (0.3 + speed01)
			"slither":
				node.rotation.y = sin(_time * 6.0 + _phase * 1.5 + side) * 0.35

func _attack_curve(p: float) -> float:
	# wind up (arm back), then slam forward
	if p < 0.35:
		return lerpf(0.0, 1.1, p / 0.35)
	return lerpf(1.1, -1.7, (p - 0.35) / 0.65)

func _finish() -> void:
	var done: StringName = anim
	anim = &"idle"
	anim_t = 0.0
	anim_finished.emit(done)
