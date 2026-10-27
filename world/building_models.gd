class_name BuildingModels
extends RefCounted
## Toy-scale models for every building in data/buildings.json (+ a generic fallback for ids added later).
## Footprint fits inside ~6 m so up to 3-4 can ring a holding. Origin = ground centre, front faces -Z.
static var _cache: Dictionary = {}
const KNOWN: Array[String] = ["lfg:building/wall", "lfg:building/wall_stone", "lfg:building/barracks", "lfg:building/storehouse", "lfg:building/sawmill",
	"lfg:building/sawmill_2", "lfg:building/kitchen", "lfg:building/kitchen_2", "lfg:building/well", "lfg:building/granary", "lfg:building/watchtower", "lfg:building/watchtower_2",
	"lfg:building/shrine", "lfg:building/greenhouse", "lfg:building/forge", "lfg:building/workbench", "lfg:building/kiln", "lfg:building/loom", "lfg:building/spore_forge",
	"lfg:building/brew_vat", "lfg:building/smokehouse", "lfg:building/cistern", "lfg:building/fortified_gate", "lfg:building/glasshouse", "lfg:building/lantern_mast",
	"lfg:building/trophy_hall", "lfg:building/infirmary", "lfg:building/sun_terrace", "lfg:building/anvil_hall"]

static func all_ids() -> Array[String]:
	var out: Array[String] = []
	for k in Content.buildings().keys():
		out.append(String(k))
	out.sort()
	return out

static func has_dedicated_model(id: String) -> bool:
	return KNOWN.has(id) or BuildingModelsP4.has_model(id)

static func mesh_for(id: String) -> ArrayMesh:
	if _cache.has(id):
		return _cache[id]
	var k := MeshKit.new()
	match id:
		"lfg:building/wall": _palisade(k)
		"lfg:building/wall_stone": _stone_wall(k)
		"lfg:building/sawmill": _sawmill(k, false)
		"lfg:building/sawmill_2": _sawmill(k, true)
		"lfg:building/kitchen": _kitchen(k, false)
		"lfg:building/kitchen_2": _kitchen(k, true)
		"lfg:building/well": _well(k)
		"lfg:building/granary": _granary(k)
		"lfg:building/watchtower": _tower(k, false)
		"lfg:building/watchtower_2": _tower(k, true)
		"lfg:building/barracks": _barracks(k)
		"lfg:building/storehouse": _storehouse(k)
		"lfg:building/shrine": _shrine(k)
		"lfg:building/greenhouse": _greenhouse(k, false)
		"lfg:building/glasshouse": _greenhouse(k, true)
		"lfg:building/forge": _forge(k)
		"lfg:building/workbench": _workbench(k)
		"lfg:building/kiln": _kiln(k)
		"lfg:building/loom": _loom(k)
		"lfg:building/spore_forge": _spore_forge(k)
		"lfg:building/brew_vat": _brew_vat(k)
		"lfg:building/smokehouse": _smokehouse(k)
		"lfg:building/cistern": _cistern(k)
		"lfg:building/fortified_gate": _gate(k)
		"lfg:building/lantern_mast": _lantern_mast(k)
		"lfg:building/trophy_hall": _trophy_hall(k)
		"lfg:building/infirmary": _infirmary(k)
		"lfg:building/sun_terrace": _terrace(k)
		"lfg:building/anvil_hall": _anvil_hall(k)
		_:
			if not BuildingModelsP4.build(id, k):
				_generic(k)
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

static func _stone_wall(k: MeshKit) -> void:
	var st := Color("a898ac")
	k.box(Vector3(0, 1.3, 0), Vector3(7.0, 2.6, 1.3), st, Color("cfc0d4"))
	for i in 5:
		k.box(Vector3(-2.9 + 1.45 * float(i), 2.85, 0), Vector3(0.9, 0.6, 1.3), st.lightened(0.1), Color("e3d6e6"))
	k.box(Vector3(0, 0.15, 0), Vector3(7.3, 0.3, 1.6), Color("7a6a8a"))
	k.box(Vector3(0, 1.4, -0.68), Vector3(6.4, 0.08, 0.06), st.darkened(0.25))
	k.box(Vector3(0, 0.8, -0.68), Vector3(6.4, 0.08, 0.06), st.darkened(0.25))

static func _sawmill(k: MeshKit, big: bool) -> void:
	var wood := Color("c8945a")
	k.box(Vector3(0, 0.15, 0), Vector3(5.2, 0.3, 3.8), Color("7a5a3a"))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box(Vector3(sx * 2.3, 1.2, sz * 1.5), Vector3(0.3, 2.4, 0.3), Color("5a3a22"))
	k.pyramid(Vector3(0, 2.4, 0), 2.9, 2.2, 1.2, Color("8a4a2a"), Color("b8663a"))
	k.box(Vector3(0, 0.9, 0), Vector3(3.6, 0.5, 1.2), wood, wood.lightened(0.15)) # work bench
	k.frustum(Vector3(0, 1.15, -0.7), 0.0, 0.8, 0.12, 0.8, 12, Color("c8c8d8"), Color("f0f0ff")) # blade
	for i in 4:
		k.frustum(Vector3(-3.4 + 0.1 * float(i % 2), 0.0 + 0.55 * float(i), 1.8), 0.0, 0.3, 0.5, 0.3, 6, Color("8a5a3a"), Color("f0d9a8"))
	if big:
		k.frustum(Vector3(1.9, 2.4, 1.0), 0.0, 0.4, 2.0, 0.34, 6, Color("5a4a5a"), Color("7a6a7a"))
		k.dome(Vector3(1.9, 4.6, 1.0), 0.7, 0.8, 2, 7, Color("ffffff"), Color("e8e4f4"))
		k.dome(Vector3(2.3, 5.5, 1.0), 0.5, 0.8, 1, 6, Color("f4f0ff"))
		k.box(Vector3(-2.7, 0.6, -1.9), Vector3(0.9, 1.2, 0.9), Color("ff7a1a"), Color("ffb060"))

static func _kitchen(k: MeshKit, big: bool) -> void:
	var wall := Color("fff1dc")
	k.box(Vector3(0, 1.1, 0), Vector3(4.0 if not big else 5.2, 2.2, 3.2), wall, wall)
	k.box(Vector3(0, 0.15, 0), Vector3(4.2 if not big else 5.4, 0.3, 3.4), Color("8a6a4a"))
	k.pyramid(Vector3(0, 2.2, 0), 2.4 if not big else 3.0, 2.0, 1.6, Color("2f9a8a") if not big else Color("c4122f"), Color("4fd8c0") if not big else Color("ff5a5a"))
	k.box(Vector3(0, 0.8, -1.62), Vector3(0.9, 1.6, 0.08), Color("7a4a3a"))
	k.box(Vector3(-1.3, 1.3, -1.62), Vector3(0.7, 0.6, 0.08), Color("ffd24a"))
	k.frustum(Vector3(1.2, 2.2, 0.5), 0.0, 0.32, 1.7, 0.28, 6, Color("8a6a5a"), Color("5a4a40"))
	k.dome(Vector3(1.2, 3.9, 0.5), 0.45, 0.8, 2, 6, Color("ffffff"), Color("e8e4f4"))
	k.frustum(Vector3(-2.4 if not big else -3.0, 0, -1.6), 0.0, 0.6, 0.9, 0.5, 8, Color("3a3a46"), Color("5a5a66")) # cauldron
	k.dome(Vector3(-2.4 if not big else -3.0, 0.85, -1.6), 0.5, 0.3, 1, 8, Color("ff7a1a"), Color("ffb060"))
	if big:
		k.frustum(Vector3(-1.2, 2.2, 0.5), 0.0, 0.3, 1.5, 0.26, 6, Color("8a6a5a"), Color("5a4a40"))
		k.box(Vector3(0, 1.9, -1.9), Vector3(4.2, 0.12, 0.9), Color("ff5a5a"), Color("ffb0b0")) # awning
		k.box(Vector3(2.9, 0.5, -1.4), Vector3(0.9, 1.0, 0.9), Color("b8884a"), Color("d8a86a"))

static func _well(k: MeshKit) -> void:
	var st := Color("a898ac")
	k.frustum(Vector3.ZERO, 0.0, 1.3, 1.0, 1.15, 10, st, Color("cfc0d4"), false)
	k.frustum(Vector3.ZERO, 0.95, 1.0, 1.05, 1.0, 10, Color("2b7f8c"), Color("4fe3d2"))
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 1.1, 1.9, 0), Vector3(0.22, 1.8, 0.22), Color("6a4a30"))
	k.box(Vector3(0, 2.2, 0), Vector3(0.18, 0.18, 2.4), Color("5a3a22"))
	k.pyramid(Vector3(0, 2.8, 0), 1.7, 1.5, 1.0, Color("e8553a"), Color("ff7a4a"))
	k.frustum(Vector3(0, 1.3, 0.0), 0.0, 0.3, 0.45, 0.26, 7, Color("8a5a3a"), Color("c9783a"))

static func _granary(k: MeshKit) -> void:
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.frustum(Vector3(sx * 1.2, 0, sz * 1.2), 0.0, 0.2, 1.0, 0.2, 5, Color("6a4a30"))
	k.frustum(Vector3.ZERO, 1.0, 1.9, 3.4, 1.8, 10, Color("f0c870"), Color("fff0a0"), true, true)
	k.frustum(Vector3.ZERO, 1.8, 1.95, 1.95, 1.95, 10, Color("8a5a3a"), Color("8a5a3a"), false)
	k.frustum(Vector3.ZERO, 2.6, 1.95, 2.75, 1.95, 10, Color("8a5a3a"), Color("8a5a3a"), false)
	k.pyramid(Vector3(0, 3.4, 0), 2.1, 2.1, 1.5, Color("c4122f"), Color("ff3a5a"))
	k.box(Vector3(0, 1.7, -1.85), Vector3(0.9, 1.3, 0.1), Color("5a3a22"))
	k.box(Vector3(0, 0.5, -1.9), Vector3(1.4, 0.15, 1.6), Color("8a5a3a")) # ramp

static func _tower(k: MeshKit, beacon: bool) -> void:
	var wood := Color("8a5a3a") if not beacon else Color("a898ac")
	var top := Color("c8945a") if not beacon else Color("cfc0d4")
	k.frustum(Vector3.ZERO, 0.0, 1.5, 6.5, 1.0, 6, wood, top, false)
	k.box(Vector3(0, 6.6, 0), Vector3(3.2, 0.4, 3.2), wood.darkened(0.2), top)
	for i in 4:
		var a: float = TAU * float(i) / 4.0 + 0.78
		k.box(Vector3(cos(a) * 1.5, 7.2, sin(a) * 1.5), Vector3(0.3, 1.0, 0.3), wood)
	if beacon:
		k.frustum(Vector3(0, 6.8, 0), 0.0, 0.8, 0.6, 0.6, 7, Color("3a3a46"), Color("5a5a66"))
		k.dome(Vector3(0, 7.4, 0), 0.7, 1.3, 2, 7, Color("ff7a1a"), Color("ffe84a"))
		k.pyramid(Vector3(0, 7.9, 0), 0.4, 0.4, 1.0, Color("ffe84a"), Color("ffffff"))
	else:
		k.pyramid(Vector3(0, 7.7, 0), 2.1, 2.1, 1.5, Color("2f9a8a"), Color("4fd8c0"))
		k.frustum(Vector3(1.2, 7.5, 1.2), 0.0, 0.07, 2.2, 0.05, 5, Color("5a3a22"))
		k.box(Vector3(1.7, 9.4, 1.2), Vector3(0.9, 0.5, 0.05), Color("ff2fb5"))
	k.box(Vector3(0, 0.9, -1.4), Vector3(0.7, 1.4, 0.1), Color("3a2a22"))

# ---------------------------------------------------------------- pass 3 models (all original, procedural)
static func _shrine(k: MeshKit) -> void:
	var st := Color("c5b4c8")
	k.frustum(Vector3.ZERO, 0.0, 2.6, 0.5, 2.3, 8, Color("8f7f9a"), Color("b8a8c0"))
	k.frustum(Vector3(0, 0.5, 0), 0.0, 0.9, 1.5, 0.7, 6, st, Color("e3d6e6"))
	for i in 3:
		var a: float = deg_to_rad(-60.0 + 60.0 * float(i)) + PI * 0.5
		var p := Vector3(cos(a) * 1.8, 0.5, sin(a) * 1.8 - 0.4)
		k.frustum(p, 0.0, 0.26, 1.7, 0.2, 5, st, Color("e3d6e6"))
		k.dome(p + Vector3(0, 1.7, 0), 0.34, 1.1, 1, 6, Color("ffd24a"), Color("fff7c2"))
	k.box(Vector3(0, 2.3, 0.2), Vector3(3.4, 0.35, 0.7), Color("8f7f9a"), Color("b8a8c0"))
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 1.55, 1.55, 0.2), Vector3(0.4, 1.6, 0.7), st, Color("e3d6e6"))
	k.dome(Vector3(0, 2.5, 0.2), 0.55, 0.9, 2, 7, Color("49c6e5"), Color("b6f3ff"))

static func _greenhouse(k: MeshKit, big: bool) -> void:
	var w: float = 5.2 if big else 4.4
	var frame := Color("5a4a6a") if big else Color("7a5a3a")
	k.box(Vector3(0, 0.2, 0), Vector3(w + 0.4, 0.4, 3.6), Color("8a7a6a"))
	k.box(Vector3(0, 1.2, 0), Vector3(w, 1.6, 3.2), Color("a8f0e0") if big else Color("7fd8a8"), Color("d8fff6") if big else Color("b6f5cf"))
	for i in range(3 if not big else 5):
		k.box(Vector3(-w * 0.5 + w * float(i) / float(2 if not big else 4), 1.2, -1.62), Vector3(0.14, 1.7, 0.1), frame)
	k.pyramid(Vector3(0, 2.0, 0), w * 0.5 + 0.2, 1.8, 1.2 if not big else 1.6, Color("c8fff4") if big else Color("2f9a6a"), Color("e8fffb") if big else Color("4fc890"))
	for i in range(4 if not big else 6):
		k.dome(Vector3(-w * 0.4 + w * 0.8 * float(i) / float(3 if not big else 5), 0.4, 0.3), 0.4, 1.0, 1, 6, Color("ff2fb5"), Color("ffd0f0"))
	if big:
		k.frustum(Vector3(w * 0.5 - 0.3, 2.0, 0.9), 0.0, 0.3, 1.3, 0.2, 5, Color("cfc0d4"), Color("ffffff"))

static func _forge(k: MeshKit) -> void:
	k.box(Vector3(0, 0.15, 0), Vector3(5.4, 0.3, 4.0), Color("5a5060"))
	k.box(Vector3(0, 1.2, 0.3), Vector3(4.6, 2.1, 2.8), Color("7a6a80"), Color("a898ac"))
	k.pyramid(Vector3(0, 2.25, 0.3), 2.5, 1.7, 1.0, Color("3a3340"), Color("5a5060"))
	k.frustum(Vector3(1.3, 2.25, 1.0), 0.0, 0.5, 2.6, 0.38, 6, Color("5a4a50"), Color("3a3036"))
	k.dome(Vector3(1.3, 4.9, 1.0), 0.6, 0.9, 2, 6, Color("d8d4e4"), Color("ffffff"))
	k.box(Vector3(-0.4, 0.8, -1.4), Vector3(1.8, 1.0, 0.1), Color("ff7a1a"), Color("ffe84a"))
	k.box(Vector3(-2.7, 0.55, -1.6), Vector3(0.9, 0.9, 0.7), Color("3a3a46"))
	k.box(Vector3(-2.7, 1.1, -1.6), Vector3(1.4, 0.3, 0.6), Color("3a3a46"), Color("6a6a7a"))
	k.box(Vector3(2.5, 0.5, -1.5), Vector3(0.9, 1.0, 0.9), Color("b8884a"), Color("d8a86a"))

static func _workbench(k: MeshKit) -> void:
	k.box(Vector3(0, 1.0, 0), Vector3(4.2, 0.25, 1.9), Color("c8945a"), Color("e0b078"))
	for sx in [-1.0, 1.0]:
		for sz in [-1.0, 1.0]:
			k.box(Vector3(sx * 1.8, 0.45, sz * 0.7), Vector3(0.3, 0.9, 0.3), Color("6a4a30"))
	k.box(Vector3(0, 0.35, 0), Vector3(3.6, 0.15, 1.3), Color("8a5a3a"))
	k.box(Vector3(-1.3, 1.35, 0), Vector3(0.9, 0.4, 0.5), Color("5a5a6a"), Color("8a8a9a"))
	k.frustum(Vector3(0.6, 1.12, 0.2), 0.0, 0.08, 0.7, 0.06, 4, Color("6a4a30"))
	k.box(Vector3(0.6, 1.85, 0.2), Vector3(0.5, 0.2, 0.18), Color("8a8a9a"))
	k.box(Vector3(1.5, 1.3, -0.1), Vector3(0.5, 0.35, 0.5), Color("b8884a"), Color("d8a86a"))
	k.frustum(Vector3(-2.9, 0, 0.6), 0.0, 0.45, 1.3, 0.4, 7, Color("8a5a3a"), Color("c9783a"))

static func _kiln(k: MeshKit) -> void:
	k.frustum(Vector3.ZERO, 0.0, 2.3, 1.6, 1.9, 10, Color("c8683a"), Color("e08858"))
	k.dome(Vector3(0, 1.6, 0), 1.9, 0.9, 3, 10, Color("d8784a"), Color("f09868"))
	k.box(Vector3(0, 0.8, -1.9), Vector3(1.3, 1.2, 0.5), Color("3a2a2a"))
	k.box(Vector3(0, 0.6, -2.1), Vector3(0.8, 0.7, 0.2), Color("ff7a1a"), Color("ffe84a"))
	k.frustum(Vector3(0.4, 3.0, 0.5), 0.0, 0.5, 1.7, 0.34, 6, Color("8a5a50"), Color("5a4040"))
	k.dome(Vector3(0.4, 4.6, 0.5), 0.55, 0.9, 2, 6, Color("d8d4e4"), Color("ffffff"))
	for i in 3:
		k.box(Vector3(-2.7 + 0.2 * float(i % 2), 0.2 + 0.4 * float(i), -1.2), Vector3(0.9, 0.35, 0.5), Color("e08858"), Color("f0b090"))

static func _loom(k: MeshKit) -> void:
	var wood := Color("8a5a3a")
	k.box(Vector3(0, 0.15, 0), Vector3(4.6, 0.3, 3.0), Color("7a6a5a"))
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 1.9, 1.5, 0), Vector3(0.3, 3.0, 0.3), wood)
	k.box(Vector3(0, 2.9, 0), Vector3(4.1, 0.3, 0.3), wood)
	k.box(Vector3(0, 0.7, 0), Vector3(4.1, 0.25, 0.3), wood)
	for i in 9:
		var cols: Array[Color] = [Color("ff2fb5"), Color("49c6e5"), Color("ffd24a")]
		k.box(Vector3(-1.6 + 0.4 * float(i), 1.8, 0), Vector3(0.06, 2.1, 0.06), cols[i % 3])
	k.box(Vector3(0, 1.5, -0.35), Vector3(3.2, 0.8, 0.1), Color("f6ead7"), Color("ffffff"))
	k.box(Vector3(0, 0.45, -1.1), Vector3(2.0, 0.5, 0.7), wood, Color("c8945a"))
	k.dome(Vector3(2.2, 0.3, -1.0), 0.45, 0.9, 1, 6, Color("ff2fb5"), Color("ffd0f0"))

static func _spore_forge(k: MeshKit) -> void:
	k.frustum(Vector3.ZERO, 0.0, 2.2, 0.8, 1.9, 10, Color("4a3a5a"), Color("6a5a7a"))
	k.frustum(Vector3(0, 0.8, 0), 0.0, 1.7, 1.5, 2.0, 10, Color("5a2a6a"), Color("8f5cff"))
	k.dome(Vector3(0, 2.3, 0), 2.0, 0.5, 2, 10, Color("ff2fb5"), Color("ffd0f0"))
	for i in 5:
		var a: float = TAU * float(i) / 5.0
		k.dome(Vector3(cos(a) * 1.2, 2.55, sin(a) * 1.2), 0.3, 1.2, 1, 5, Color("b6ff6a"), Color("f0ffd0"))
	k.frustum(Vector3(0, 2.5, 0), 0.0, 0.3, 2.3, 0.25, 6, Color("f3e4cf"))
	k.dome(Vector3(0, 4.8, 0), 0.9, 0.7, 2, 8, Color("ffe84a"), Color("fff7c2"))
	k.box(Vector3(0, 0.6, -2.0), Vector3(1.0, 1.0, 0.4), Color("1a0a2a"))
	k.box(Vector3(0, 0.45, -2.2), Vector3(0.7, 0.5, 0.15), Color("ff2fb5"), Color("ffd0f0"))

static func _brew_vat(k: MeshKit) -> void:
	k.box(Vector3(0, 0.15, 0), Vector3(4.0, 0.3, 4.0), Color("7a6a5a"))
	k.frustum(Vector3.ZERO, 0.3, 1.5, 2.7, 1.3, 10, Color("b8683a"), Color("e08858"))
	for y in [0.9, 1.7, 2.4]:
		k.frustum(Vector3.ZERO, y, 1.5 - (y - 0.3) * 0.08 + 0.02, y + 0.12, 1.5 - (y - 0.3) * 0.08 + 0.02, 10, Color("5a4a40"), Color("5a4a40"), false)
	k.dome(Vector3(0, 2.7, 0), 1.2, 0.45, 2, 10, Color("49c6e5"), Color("b6f3ff"))
	k.frustum(Vector3(1.6, 0.6, 0.0), 0.0, 0.14, 1.9, 0.14, 5, Color("c8945a"))
	k.box(Vector3(1.0, 2.5, 0.0), Vector3(1.4, 0.22, 0.22), Color("c8945a"))
	k.frustum(Vector3(-1.9, 0.3, -1.3), 0.0, 0.4, 0.9, 0.36, 7, Color("8a5a3a"), Color("c9783a"))
	k.dome(Vector3(-0.3, 3.3, 0.3), 0.35, 1.0, 1, 5, Color("d8fff6"), Color("ffffff"))

static func _smokehouse(k: MeshKit) -> void:
	k.box(Vector3(0, 0.15, 0), Vector3(3.8, 0.3, 3.4), Color("6a5a4a"))
	k.box(Vector3(0, 1.6, 0), Vector3(3.0, 2.9, 2.6), Color("7a5a3a"), Color("9a7a52"))
	for i in 5:
		k.box(Vector3(-1.2 + 0.6 * float(i), 1.6, -1.32), Vector3(0.1, 2.8, 0.06), Color("5a3a22"))
	k.pyramid(Vector3(0, 3.05, 0), 1.9, 1.7, 1.2, Color("3a3a46"), Color("5a5a66"))
	k.frustum(Vector3(0.7, 4.0, 0.3), 0.0, 0.34, 1.5, 0.28, 6, Color("5a4a50"), Color("3a3036"))
	k.dome(Vector3(0.7, 5.5, 0.3), 0.5, 0.9, 2, 6, Color("b8b4c4"), Color("e8e4f4"))
	k.dome(Vector3(1.2, 6.3, 0.2), 0.4, 0.9, 1, 6, Color("d8d4e4"), Color("ffffff"))
	k.box(Vector3(0, 0.9, -1.35), Vector3(0.9, 1.4, 0.1), Color("3a2a22"))
	k.box(Vector3(-1.6, 2.0, -1.4), Vector3(0.4, 0.8, 0.12), Color("c4683a"))

static func _cistern(k: MeshKit) -> void:
	k.frustum(Vector3.ZERO, 0.0, 2.4, 1.6, 2.2, 12, Color("a898ac"), Color("cfc0d4"), false)
	k.frustum(Vector3.ZERO, 1.5, 2.3, 1.7, 2.3, 12, Color("7a6a8a"), Color("7a6a8a"), false)
	k.frustum(Vector3.ZERO, 1.5, 2.0, 1.6, 2.0, 12, Color("2b7f8c"), Color("4fe3d2"))
	for i in 4:
		var a: float = TAU * float(i) / 4.0 + 0.4
		k.box(Vector3(cos(a) * 2.35, 0.8, sin(a) * 2.35), Vector3(0.35, 1.6, 0.35), Color("8f7f9a"))
	k.frustum(Vector3(2.5, 0.3, 0.0), 0.0, 0.2, 0.9, 0.2, 6, Color("c8945a"))
	k.box(Vector3(2.0, 1.1, 0.0), Vector3(1.0, 0.2, 0.2), Color("c8945a"))
	k.pyramid(Vector3(0, 3.2, 0), 1.0, 1.0, 0.9, Color("e8553a"), Color("ff7a4a"))
	k.frustum(Vector3.ZERO, 1.7, 0.1, 3.2, 0.1, 5, Color("6a4a30"))

static func _gate(k: MeshKit) -> void:
	var st := Color("a898ac")
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 2.6, 2.4, 0), Vector3(1.7, 4.8, 1.7), st, Color("cfc0d4"))
		for i in 3:
			k.box(Vector3(sx * 2.6 - 0.55 + 0.55 * float(i), 5.1, 0), Vector3(0.4, 0.55, 1.7), st.lightened(0.1))
	k.box(Vector3(0, 4.0, 0), Vector3(3.6, 1.2, 1.5), st.darkened(0.1), Color("cfc0d4"))
	k.box(Vector3(0, 0.15, 0), Vector3(7.8, 0.3, 2.2), Color("6a5a7a"))
	for i in 7:
		k.box(Vector3(-1.5 + 0.5 * float(i), 1.6, -0.1), Vector3(0.12, 3.0, 0.12), Color("4a4a5a"), Color("8a8a9a"))
	k.box(Vector3(0, 2.3, -0.1), Vector3(3.2, 0.14, 0.14), Color("4a4a5a"))
	k.box(Vector3(2.6, 2.4, -0.88), Vector3(0.5, 0.9, 0.06), Color("ffd24a"))
	k.frustum(Vector3(0, 4.6, 0), 0.0, 0.07, 2.0, 0.05, 5, Color("5a3a22"))
	k.box(Vector3(0.5, 6.4, 0), Vector3(1.0, 0.6, 0.05), Color("c4122f"), Color("ff3a5a"))

static func _lantern_mast(k: MeshKit) -> void:
	k.frustum(Vector3.ZERO, 0.0, 0.7, 0.5, 0.55, 6, Color("8f7f9a"), Color("b8a8c0"))
	k.frustum(Vector3.ZERO, 0.5, 0.2, 7.5, 0.13, 6, Color("6a4a30"), Color("8a6a50"))
	k.box(Vector3(0, 6.4, 0), Vector3(3.0, 0.14, 0.14), Color("5a3a22"))
	k.box(Vector3(0, 5.0, 0), Vector3(0.14, 0.14, 2.2), Color("5a3a22"))
	for p in [Vector3(-1.4, 5.9, 0), Vector3(1.4, 5.9, 0), Vector3(0, 4.5, 1.0), Vector3(0, 4.5, -1.0)]:
		k.box(p + Vector3(0, 0.45, 0), Vector3(0.08, 0.9, 0.08), Color("3a3a46"))
		k.dome(p, 0.42, 1.2, 1, 6, Color("ffe84a"), Color("fffbd0"))
	k.dome(Vector3(0, 7.5, 0), 0.5, 1.4, 2, 6, Color("ff7a1a"), Color("ffe84a"))
	k.pyramid(Vector3(0, 7.9, 0), 0.35, 0.35, 0.8, Color("ffe84a"), Color("ffffff"))

static func _trophy_hall(k: MeshKit) -> void:
	k.box(Vector3(0, 0.2, 0), Vector3(7.4, 0.4, 4.6), Color("7a6a8a"))
	k.box(Vector3(0, 1.8, 0.3), Vector3(6.0, 2.8, 3.2), Color("fff1dc"), Color("fff1dc"))
	k.pyramid(Vector3(0, 3.2, 0.3), 3.3, 2.0, 1.6, Color("2f9a8a"), Color("4fd8c0"))
	for i in 4:
		k.frustum(Vector3(-2.7 + 1.8 * float(i), 0.4, -1.9), 0.0, 0.3, 3.0, 0.26, 6, Color("e3d6e6"), Color("ffffff"))
	k.box(Vector3(0, 2.7, -1.9), Vector3(6.2, 0.35, 0.5), Color("c9b4c4"))
	k.box(Vector3(0, 0.9, -1.35), Vector3(1.3, 1.6, 0.1), Color("5a3a22"))
	k.frustum(Vector3(0, 3.0, -0.6), 0.0, 0.35, 0.5, 0.2, 7, Color("ffd24a"), Color("fff7c2"))
	k.frustum(Vector3(0, 3.0, -0.6), 0.5, 0.1, 0.9, 0.1, 5, Color("ffd24a"))
	k.dome(Vector3(0, 3.9, -0.6), 0.4, 0.8, 1, 7, Color("ffd24a"), Color("fff7c2"))
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 2.0, 1.7, -1.4), Vector3(0.7, 1.1, 0.06), Color("c4122f"))

static func _infirmary(k: MeshKit) -> void:
	k.box(Vector3(0, 0.15, 0), Vector3(5.0, 0.3, 3.8), Color("8a7a6a"))
	k.box(Vector3(0, 1.4, 0), Vector3(4.4, 2.4, 3.2), Color("fff7f2"), Color("fff7f2"))
	k.pyramid(Vector3(0, 2.6, 0), 2.5, 1.9, 1.5, Color("49c6e5"), Color("b6f3ff"))
	k.box(Vector3(0, 1.9, -1.62), Vector3(1.4, 0.45, 0.08), Color("c4122f"))
	k.box(Vector3(0, 1.9, -1.64), Vector3(0.45, 1.4, 0.08), Color("c4122f"))
	k.box(Vector3(0, 0.8, -1.62), Vector3(0.9, 1.4, 0.08), Color("7a4a3a"))
	k.box(Vector3(-1.5, 1.5, -1.62), Vector3(0.6, 0.6, 0.08), Color("ffd24a"))
	k.box(Vector3(0, 1.7, -2.4), Vector3(4.6, 0.12, 1.4), Color("f6f0ff"), Color("ffffff"))
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 2.2, 0.85, -2.9), Vector3(0.15, 1.7, 0.15), Color("8a5a3a"))
	k.dome(Vector3(2.9, 0.3, 1.0), 0.5, 1.0, 1, 6, Color("86e8a0"), Color("d0ffd8"))

static func _terrace(k: MeshKit) -> void:
	for i in 3:
		var w: float = 6.2 - 1.8 * float(i)
		k.box(Vector3(0, 0.3 + 0.6 * float(i), 0.0 + 0.2 * float(i)), Vector3(w, 0.6, 4.0 - 1.0 * float(i)), Color("a07a4a").lightened(0.08 * float(i)), Color("8a5a32"))
		for j in 4 - i:
			k.dome(Vector3(-w * 0.35 + w * 0.7 * float(j) / float(maxi(1, 3 - i)), 0.62 + 0.6 * float(i), 0.2 * float(i)), 0.4, 1.1, 1, 5, Color("7fd04a"), Color("4fa03a"))
	k.frustum(Vector3(-2.7, 1.8, 1.4), 0.0, 0.1, 2.0, 0.08, 5, Color("6a4a30"))
	k.quad(Vector3(-2.7, 3.7, 1.4), Vector3(-2.7, 3.0, 1.4), Vector3(-1.5, 3.1, 1.4), Vector3(-1.5, 3.6, 1.4), Color("ffd24a"))
	k.quad(Vector3(-2.7, 3.0, 1.4), Vector3(-2.7, 3.7, 1.4), Vector3(-1.5, 3.6, 1.4), Vector3(-1.5, 3.1, 1.4), Color("ffd24a"))

static func _anvil_hall(k: MeshKit) -> void:
	k.box(Vector3(0, 0.2, 0), Vector3(7.6, 0.4, 5.2), Color("5a5060"))
	k.box(Vector3(0, 2.0, 0.4), Vector3(6.6, 3.2, 3.6), Color("8f7f9a"), Color("b8a8c0"))
	k.pyramid(Vector3(0, 3.6, 0.4), 3.7, 2.3, 1.6, Color("3a3340"), Color("5a5060"))
	for sx in [-1.0, 1.0]:
		k.frustum(Vector3(sx * 2.4, 3.6, 1.3), 0.0, 0.55, 3.2, 0.4, 6, Color("5a4a50"), Color("3a3036"))
		k.dome(Vector3(sx * 2.4, 6.8, 1.3), 0.6, 0.9, 2, 6, Color("d8d4e4"), Color("ffffff"))
	k.box(Vector3(0, 1.0, -1.9), Vector3(2.8, 1.6, 0.2), Color("ff7a1a"), Color("ffe84a"))
	k.box(Vector3(0, 0.75, -3.0), Vector3(1.6, 0.9, 1.0), Color("3a3a46"))
	k.box(Vector3(0, 1.35, -3.0), Vector3(2.4, 0.4, 0.8), Color("3a3a46"), Color("7a7a8a"))
	k.box(Vector3(1.2, 1.5, -3.0), Vector3(1.0, 0.25, 0.4), Color("3a3a46"), Color("7a7a8a"))
	k.box(Vector3(-3.0, 0.6, -2.2), Vector3(1.0, 1.2, 1.0), Color("b8884a"), Color("d8a86a"))
	k.box(Vector3(3.0, 0.5, -2.2), Vector3(0.9, 1.0, 0.9), Color("c9b4c4"), Color("e3d6e6"))

static func _generic(k: MeshKit) -> void:
	k.box(Vector3(0, 0.9, 0), Vector3(3.0, 1.8, 3.0), Color("d8c8e8"))
	k.pyramid(Vector3(0, 1.8, 0), 1.9, 1.9, 1.3, Color("ff7a4a"), Color("e8553a"))
	k.box(Vector3(0, 0.6, -1.52), Vector3(0.7, 1.2, 0.08), Color("5a3a22"))

## World-space centre of a build site hex given as axial "q,r" (Rules holding.sites keys).
static func site_world(axial: Vector2i) -> Vector2:
	var off: Vector2i = HexMath.axial_to_offset(axial)
	return HexMath.offset_center(off.x, off.y)

## World-space slot for the n-th building at a holding (ring around the hex centre, front toward the village centre).
static func slot_position(hex_center: Vector2, index: int) -> Vector3:
	var ang: float = deg_to_rad(200.0 + 72.0 * float(index))
	return Vector3(hex_center.x + cos(ang) * 8.6, 0.0, hex_center.y + sin(ang) * 6.6)
