class_name BuildingModels
extends RefCounted
## Toy-scale models for every building in data/buildings.json (+ a generic fallback for ids added later).
## Footprint fits inside ~6 m so up to 3-4 can ring a holding. Origin = ground centre, front faces -Z.
static var _cache: Dictionary = {}
const KNOWN: Array[String] = ["lfg:building/wall", "lfg:building/barracks", "lfg:building/storehouse"]

static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for k in Content.buildings().keys():
		out.append(String(k))
	out.sort()
	return out

static func has_dedicated_model(id: String) -> bool:
	return KNOWN.has(id)

static func mesh_for(id: String) -> ArrayMesh:
	if _cache.has(id):
		return _cache[id]
	var k := MeshKit.new()
	match id:
		"lfg:building/wall": _palisade(k)
		"lfg:building/barracks": _barracks(k)
		"lfg:building/storehouse": _storehouse(k)
		_: _generic(k)
	var m: ArrayMesh = k.build()
	_cache[id] = m
	return m

static func footprint(id: String) -> AABB:
	var m: ArrayMesh = mesh_for(id)
	return m.get_aabb()

static func _palisade(k: MeshKit) -> void:
	var wood := Color("8a5a3a")
	for i in 9:
		var x: float = -3.2 + 0.8 * float(i)
		var h: float = 2.3 + 0.35 * float((i * 5) % 3)
		k.frustum(Vector3(x, 0, 0), 0.0, 0.34, h, 0.28, 5, wood.darkened(0.08 * float(i % 2)), wood.lightened(0.2))
		k.pyramid(Vector3(x, h, 0), 0.28, 0.28, 0.5, Color("f0d9a8"), Color("ffffff"))
	k.box(Vector3(0, 1.1, 0.3), Vector3(7.0, 0.22, 0.2), Color("5a3a22"))
	k.box(Vector3(0, 1.9, 0.3), Vector3(7.0, 0.22, 0.2), Color("5a3a22"))

static func _barracks(k: MeshKit) -> void:
	k.box(Vector3(0, 1.0, 0), Vector3(5.6, 2.0, 3.4), Color("c9b4c4"), Color("c9b4c4"))
	k.box(Vector3(0, 0.15, 0), Vector3(5.9, 0.3, 3.7), Color("7a6a8a"))
	k.pyramid(Vector3(0, 2.0, 0), 3.2, 2.1, 1.7, Color("5a3a8a"), Color("8f5cff"))
	k.box(Vector3(0, 0.8, -1.72), Vector3(1.1, 1.6, 0.1), Color("3a2a22"))
	k.box(Vector3(-1.9, 1.3, -1.72), Vector3(0.7, 0.55, 0.08), Color("ffd24a"))
	k.box(Vector3(1.9, 1.3, -1.72), Vector3(0.7, 0.55, 0.08), Color("ffd24a"))
	# banner pole + flag
	k.frustum(Vector3(2.7, 0, -1.9), 0.0, 0.1, 4.2, 0.07, 5, Color("5a3a22"))
	k.box(Vector3(3.2, 3.6, -1.9), Vector3(1.0, 0.7, 0.05), Color("c4122f"), Color("ff3a5a"))
	# training dummy
	k.frustum(Vector3(-3.4, 0, -2.4), 0.0, 0.12, 1.7, 0.1, 5, Color("5a3a22"))
	k.dome(Vector3(-3.4, 1.7, -2.4), 0.35, 0.9, 1, 6, Color("e8d8a0"))
	k.box(Vector3(-3.4, 1.35, -2.4), Vector3(1.1, 0.14, 0.14), Color("5a3a22"))

static func _storehouse(k: MeshKit) -> void:
	k.box(Vector3(0, 1.1, 0), Vector3(4.2, 2.2, 3.4), Color("e8c08a"), Color("e8c08a"))
	k.box(Vector3(0, 0.15, 0), Vector3(4.4, 0.3, 3.6), Color("8a6a4a"))
	k.pyramid(Vector3(0, 2.2, 0), 2.5, 2.1, 1.5, Color("2fa87a"), Color("4fd8a0"))
	k.box(Vector3(0, 0.9, -1.72), Vector3(1.6, 1.8, 0.1), Color("7a4a3a"))
	k.box(Vector3(0, 0.9, -1.78), Vector3(0.08, 1.8, 0.08), Color("3a2a22"))
	k.box(Vector3(-2.7, 0.45, -1.2), Vector3(0.9, 0.9, 0.9), Color("b8884a"), Color("d8a86a"))
	k.box(Vector3(-2.6, 1.2, -1.1), Vector3(0.7, 0.6, 0.7), Color("b8884a"), Color("d8a86a"))
	k.frustum(Vector3(2.7, 0, -1.4), 0.0, 0.55, 1.0, 0.5, 7, Color("8a5a3a"), Color("c9783a"))
	k.box(Vector3(0, 1.5, -1.8), Vector3(1.9, 0.18, 0.12), Color("ffd24a"))

static func _generic(k: MeshKit) -> void:
	k.box(Vector3(0, 0.9, 0), Vector3(3.0, 1.8, 3.0), Color("d8c8e8"))
	k.pyramid(Vector3(0, 1.8, 0), 1.9, 1.9, 1.3, Color("ff7a4a"), Color("e8553a"))
	k.box(Vector3(0, 0.6, -1.52), Vector3(0.7, 1.2, 0.08), Color("5a3a22"))

## World-space slot for the n-th building at a holding (ring around the hex centre, front toward the village centre).
static func slot_position(hex_center: Vector2, index: int) -> Vector3:
	var ang: float = deg_to_rad(200.0 + 72.0 * float(index))
	return Vector3(hex_center.x + cos(ang) * 8.6, 0.0, hex_center.y + sin(ang) * 6.6)
