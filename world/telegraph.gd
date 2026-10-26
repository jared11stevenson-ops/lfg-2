class_name Telegraphs
extends Node3D
## Ground danger zones for enemy attacks (terrain-conforming meshes, wind-up fill, then flash).
## Event shape the presentation understands (Rules may emit this; B does not depend on it existing):
##   {type:&"enemy_telegraph", pos:Vector2|Vector3 (world xz), yaw:float, shape:"circle"|"cone"|"line",
##    radius:float (or length for line), half_angle:float, width:float, windup:float(seconds)}
signal resolved(zone: Node3D)
enum Shape { CIRCLE, CONE, LINE }
const GRID := 14
var world: WorldData
var _live: Array[Dictionary] = []
var _shader: Shader
var purge_colors: bool = false

func _init() -> void:
	name = "Telegraphs"
	_shader = load("res://world/shaders/telegraph.gdshader")

func set_progress_seconds(t: float) -> void:
	for z in _live:
		z["t"] = t

func active_count() -> int:
	return _live.size()

func handle_event(e: Dictionary) -> void:
	if e.get("type", &"") != &"enemy_telegraph":
		return
	var pos: Variant = e.get("pos", Vector2.ZERO)
	var p3 := Vector3.ZERO
	if pos is Vector3:
		p3 = pos
	elif pos is Vector2:
		p3 = Vector3(pos.x, world.height_at(pos.x, pos.y) if world != null else 0.0, pos.y)
	var shape: int = Shape.CIRCLE
	match str(e.get("shape", "circle")):
		"cone": shape = Shape.CONE
		"line": shape = Shape.LINE
	spawn(shape, p3, float(e.get("yaw", 0.0)), float(e.get("radius", e.get("length", 6.0))), float(e.get("windup", 1.0)), {"half_angle": float(e.get("half_angle", 0.7)), "width": float(e.get("width", 1.5))})

func spawn(shape: int, origin: Vector3, yaw: float, radius: float, windup: float, params: Dictionary = {}) -> Node3D:
	var node := MeshInstance3D.new()
	node.name = "Telegraph"
	node.position = origin
	node.rotation.y = yaw
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	node.mesh = _conform_mesh(origin, yaw, radius)
	var mat := ShaderMaterial.new()
	mat.shader = _shader
	mat.set_shader_parameter("shape", shape)
	mat.set_shader_parameter("progress", 0.0)
	mat.set_shader_parameter("half_angle", float(params.get("half_angle", 0.7)))
	mat.set_shader_parameter("line_half_width", clampf(float(params.get("width", 1.5)) * 0.5 / radius, 0.03, 1.0))
	if purge_colors:
		mat.set_shader_parameter("color_a", Color(1.0, 0.3, 0.9))
		mat.set_shader_parameter("color_b", Color(1.0, 1.0, 0.55))
	node.material_override = mat
	add_child(node)
	_live.append({"node": node, "mat": mat, "t": 0.0, "windup": maxf(windup, 0.05), "flash": 0.2})
	return node

func _conform_mesh(origin: Vector3, yaw: float, r: float) -> ArrayMesh:
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	var rot := Basis(Vector3.UP, yaw)
	for j in GRID + 1:
		for i in GRID + 1:
			var lx: float = (float(i) / float(GRID) * 2.0 - 1.0) * r
			var lz: float = (float(j) / float(GRID) * 2.0 - 1.0) * r
			var wpos: Vector3 = origin + rot * Vector3(lx, 0, lz)
			var y: float = (world.height_at(wpos.x, wpos.z) if world != null else origin.y) - origin.y + 0.18
			verts.append(Vector3(lx, y, lz))
			uvs.append(Vector2(float(i) / float(GRID), 1.0 - float(j) / float(GRID)))
	for j in GRID:
		for i in GRID:
			var a: int = j * (GRID + 1) + i
			idx.append_array([a, a + 1, a + GRID + 2, a, a + GRID + 2, a + GRID + 1])
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	var m := ArrayMesh.new()
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m

func _process(dt: float) -> void:
	for i in range(_live.size() - 1, -1, -1):
		var z: Dictionary = _live[i]
		z["t"] += dt
		var prog: float = clampf(z["t"] / z["windup"], 0.0, 1.0)
		(z["mat"] as ShaderMaterial).set_shader_parameter("progress", prog)
		if z["t"] >= z["windup"] + z["flash"]:
			var n: Node3D = z["node"]
			resolved.emit(n)
			n.queue_free()
			_live.remove_at(i)
