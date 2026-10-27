class_name BuildingModelsP4
extends RefCounted
## Pass 4 building models: three stations (alembic, rift anvil, seed press) and ten buildables (kennel, seed bank, compost heap, spore bed, ward stones, rest hall,
## hall of guardians, bastion, foraging den, apiary). Same rules as building_models.gd: flat-shaded MeshKit primitives, origin = ground centre, front faces -Z,
## footprint inside ~6 m, a silhouette per building. BuildingModels.mesh_for hands these ids here.
const IDS: Array[String] = ["lfg:building/alembic", "lfg:building/rift_anvil", "lfg:building/seed_press", "lfg:building/kennel", "lfg:building/seed_bank",
	"lfg:building/compost_heap", "lfg:building/spore_bed", "lfg:building/ward_stones", "lfg:building/rest_hall", "lfg:building/guardian_hall", "lfg:building/bastion",
	"lfg:building/foraging_den", "lfg:building/apiary"]

static func has_model(id: String) -> bool:
	return IDS.has(id)

static func build(id: String, k: MeshKit) -> bool:
	match id:
		"lfg:building/alembic": _alembic(k)
		"lfg:building/rift_anvil": _rift_anvil(k)
		"lfg:building/seed_press": _seed_press(k)
		"lfg:building/kennel": _kennel(k)
		"lfg:building/seed_bank": _seed_bank(k)
		"lfg:building/compost_heap": _compost(k)
		"lfg:building/spore_bed": _spore_bed(k)
		"lfg:building/ward_stones": _ward_stones(k)
		"lfg:building/rest_hall": _rest_hall(k)
		"lfg:building/guardian_hall": _guardian_hall(k)
		"lfg:building/bastion": _bastion(k)
		"lfg:building/foraging_den": _den(k)
		"lfg:building/apiary": _apiary(k)
		_: return false
	return true

static func _alembic(k: MeshKit) -> void:
	k.box(Vector3(0, 0.2, 0), Vector3(4.2, 0.4, 3.4), Color("6a5a7a"))
	k.frustum(Vector3(-0.6, 0.4, 0), 0.0, 1.3, 1.5, 1.0, 9, Color("2b7f8c"), Color("4fe3d2"))                 # the still: a squat glass belly
	k.dome(Vector3(-0.6, 1.9, 0), 1.0, 0.8, 2, 9, Color("49c6e5"), Color("b6f3ff"))
	k.frustum(Vector3(-0.6, 2.6, 0), 0.0, 0.18, 1.2, 0.12, 6, Color("d8fff6"))                              # swan neck
	k.box(Vector3(0.3, 3.7, 0), Vector3(1.9, 0.16, 0.16), Color("d8fff6"))
	k.frustum(Vector3(1.2, 1.2, 0), 0.0, 0.14, 2.5, 0.14, 5, Color("d8fff6"))
	k.frustum(Vector3(1.6, 0.4, -0.8), 0.0, 0.4, 0.9, 0.34, 7, Color("c47bff"), Color("e8c8ff"))              # receiving flask
	k.dome(Vector3(1.6, 1.3, -0.8), 0.34, 1.0, 1, 6, Color("ffd24a"), Color("fff7c2"))
	k.box(Vector3(-1.7, 0.8, -1.2), Vector3(0.7, 0.8, 0.7), Color("8a5a3a"), Color("c8945a"))

static func _rift_anvil(k: MeshKit) -> void:
	k.frustum(Vector3.ZERO, 0.0, 2.2, 0.5, 2.0, 8, Color("3a3046"), Color("5a4a6a"))
	k.box(Vector3(0, 1.1, 0), Vector3(1.4, 1.2, 1.1), Color("5a4a6a"), Color("7a6a8a"))
	k.box(Vector3(0, 1.9, 0), Vector3(3.2, 0.5, 1.4), Color("7a6a8a"), Color("a898ac"))                     # the anvil face
	k.pyramid(Vector3(1.9, 1.9, 0), 0.8, 0.5, 0.0, Color("a898ac"))
	k.box(Vector3(-1.8, 2.05, 0), Vector3(0.9, 0.3, 0.9), Color("7a6a8a"))
	for i in 3:                                                                                               # the rift: three shards of violet light standing behind
		var x: float = -1.2 + 1.2 * float(i)
		k.frustum(Vector3(x, 0, 1.9), 0.0, 0.35, 3.2 + 0.7 * float(i % 2), 0.0, 4, Color("8f5cff"), Color("e8d8ff"), false, false, 0.3 * float(i))
	k.dome(Vector3(0, 2.15, 0), 0.3, 1.0, 1, 6, Color("ff7a1a"), Color("ffe84a"))

static func _seed_press(k: MeshKit) -> void:
	var wood := Color("8a5a3a")
	k.box(Vector3(0, 0.15, 0), Vector3(4.4, 0.3, 3.4), Color("7a6a5a"))
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 1.6, 1.8, 0), Vector3(0.4, 3.4, 0.4), wood)
	k.box(Vector3(0, 3.3, 0), Vector3(3.6, 0.45, 0.5), wood.lightened(0.1))
	k.frustum(Vector3(0, 0.3, 0), 0.0, 1.0, 1.0, 0.9, 9, Color("c8945a"), Color("e8b87a"))                  # the tub
	k.frustum(Vector3(0, 1.0, 0), 0.0, 0.2, 2.4, 0.2, 6, Color("5a3a22"))                                    # screw
	k.frustum(Vector3(0, 2.2, 0), 0.0, 0.7, 0.35, 0.7, 8, Color("6a4a30"), Color("8a5a3a"))
	k.box(Vector3(0, 2.7, 0), Vector3(2.6, 0.18, 0.18), Color("5a3a22"))
	for i in 5:
		k.dome(Vector3(-1.0 + 0.5 * float(i), 0.34, -1.5), 0.2, 0.7, 1, 5, Color("ffd24a") if i % 2 == 0 else Color("7fd04a"), Color("fff7c2"))

static func _kennel(k: MeshKit) -> void:
	k.box(Vector3(0, 0.15, 0), Vector3(5.0, 0.3, 3.4), Color("7a6a5a"))
	for i in 2:
		var x: float = -1.2 + 2.4 * float(i)
		k.box(Vector3(x, 0.95, 0), Vector3(2.0, 1.3, 2.2), Color("c8a878"), Color("d8b888"))
		k.pyramid(Vector3(x, 1.6, 0), 1.2, 1.3, 0.9, Color("5a8a4a"), Color("7aaa5a"))
		k.box(Vector3(x, 0.7, -1.12), Vector3(0.8, 0.9, 0.08), Color("2a1a22"))
		k.dome(Vector3(x, 0.4, -1.55), 0.32, 0.5, 1, 6, Color("ff8a3c"), Color("ffd0a0"))                       # a bowl
	k.box(Vector3(0, 0.9, 1.5), Vector3(4.6, 0.12, 0.12), Color("6a4a30"))
	for i in 5:
		k.box(Vector3(-2.2 + 1.1 * float(i), 0.55, 1.5), Vector3(0.12, 1.0, 0.12), Color("6a4a30"))

static func _seed_bank(k: MeshKit) -> void:
	k.box(Vector3(0, 0.15, 0), Vector3(4.0, 0.3, 3.2), Color("7a6a5a"))
	k.box(Vector3(0, 1.3, 0), Vector3(3.2, 2.0, 2.4), Color("b8683a"), Color("d88858"))
	k.pyramid(Vector3(0, 2.3, 0), 2.0, 1.5, 1.0, Color("5a3a8a"), Color("8f5cff"))
	for i in 3:                                                                                               # drawers of seed
		for j in 2:
			k.box(Vector3(-0.8 + 0.8 * float(i), 0.9 + 0.7 * float(j), -1.22), Vector3(0.6, 0.5, 0.06), Color("f0d9a8"), Color("fff3d0"))
	k.box(Vector3(0, 0.55, -1.3), Vector3(1.0, 1.0, 0.12), Color("3a2a22"))
	k.frustum(Vector3(2.0, 0, -0.6), 0.0, 0.5, 1.1, 0.4, 8, Color("c8945a"), Color("ffd24a"))                 # a sack and its spill
	k.dome(Vector3(2.0, 1.1, -0.6), 0.4, 0.5, 1, 7, Color("ffd24a"), Color("fff7c2"))

static func _compost(k: MeshKit) -> void:
	k.frustum(Vector3.ZERO, 0.0, 2.3, 1.3, 1.5, 9, Color("5a3a22"), Color("7a5a3a"))
	k.dome(Vector3(0, 1.3, 0), 1.5, 0.6, 2, 9, Color("4a3020"), Color("6a4a30"))
	for i in 7:
		var a: float = TAU * float(i) / 7.0
		k.dome(Vector3(cos(a) * 1.0, 1.7 - 0.1 * float(i % 3), sin(a) * 1.0), 0.28, 0.9, 1, 5, Color("7fd04a") if i % 2 == 0 else Color("ff2fb5"), Color("f0ffd0"))
	for i in 4:
		k.box(Vector3(-2.4, 0.6, -1.5 + 1.0 * float(i)), Vector3(0.18, 1.2, 0.18), Color("8a5a3a"))
		k.box(Vector3(2.4, 0.6, -1.5 + 1.0 * float(i)), Vector3(0.18, 1.2, 0.18), Color("8a5a3a"))
	k.box(Vector3(-2.4, 0.9, -0.5), Vector3(0.14, 0.14, 3.0), Color("6a4a30"))
	k.box(Vector3(2.4, 0.9, -0.5), Vector3(0.14, 0.14, 3.0), Color("6a4a30"))

static func _spore_bed(k: MeshKit) -> void:
	k.box(Vector3(0, 0.3, 0), Vector3(5.0, 0.6, 3.4), Color("5a3a22"), Color("3a2418"))
	for i in 9:
		var x: float = -2.0 + 0.5 * float(i)
		var z: float = -0.9 + 0.9 * float((i * 5) % 3)
		var h: float = 0.7 + 0.35 * float(i % 4)
		k.frustum(Vector3(x, 0.6, z), 0.0, 0.1, h, 0.08, 5, Color("f6ead7"))
		k.dome(Vector3(x, 0.6 + h, z), 0.34, 0.7, 1, 6, [Color("ff2fb5"), Color("b6ff6a"), Color("49c6e5")][i % 3], Color("fff0f8"))
	k.box(Vector3(2.6, 0.4, -1.8), Vector3(0.4, 0.8, 0.12), Color("c8945a"))

static func _ward_stones(k: MeshKit) -> void:
	k.frustum(Vector3.ZERO, 0.0, 2.6, 0.3, 2.4, 9, Color("8f7f9a"), Color("b8a8c0"))
	for i in 5:
		var a: float = TAU * float(i) / 5.0 + 0.3
		var h: float = 2.8 + 0.5 * float(i % 3)
		k.frustum(Vector3(cos(a) * 1.8, 0.3, sin(a) * 1.8), 0.0, 0.5, h, 0.28, 5, Color("a898ac"), Color("e3d6e6"), true, false, a)
		k.dome(Vector3(cos(a) * 1.8, 0.3 + h * 0.72, sin(a) * 1.8 - 0.35), 0.16, 1.0, 1, 5, Color("49c6e5"), Color("d8fff6"))      # a glowing glyph
	k.dome(Vector3(0, 0.3, 0), 0.7, 0.5, 1, 7, Color("ffd24a"), Color("fff7c2"))

static func _rest_hall(k: MeshKit) -> void:
	k.box(Vector3(0, 0.15, 0), Vector3(5.4, 0.3, 4.0), Color("7a6a5a"))
	k.box(Vector3(0, 1.25, 0), Vector3(4.4, 1.9, 3.0), Color("f0d9e8"), Color("fff0f8"))
	k.pyramid(Vector3(0, 2.2, 0), 2.9, 2.0, 1.7, Color("c47bff"), Color("e8c8ff"))
	k.box(Vector3(0, 0.85, -1.55), Vector3(1.0, 1.3, 0.1), Color("5a3a22"))
	for sx in [-1.0, 1.0]:
		k.box(Vector3(sx * 1.6, 1.4, -1.55), Vector3(0.8, 0.6, 0.08), Color("ffd24a"), Color("fff7c2"))    # lit windows
	k.frustum(Vector3(1.9, 0.3, -2.0), 0.0, 0.1, 1.5, 0.1, 5, Color("5a3a22"))
	k.dome(Vector3(1.9, 1.8, -2.0), 0.35, 1.2, 1, 6, Color("ffe84a"), Color("fffbd0"))                       # a lantern on a pole
	k.dome(Vector3(-2.0, 0.45, -1.9), 0.5, 0.6, 1, 7, Color("e8553a"), Color("ff8a6a"))                      # a cushion on the step

static func _guardian_hall(k: MeshKit) -> void:
	k.frustum(Vector3.ZERO, 0.0, 3.0, 0.5, 2.8, 10, Color("8f7f9a"), Color("b8a8c0"))
	k.box(Vector3(0, 1.7, 0), Vector3(4.6, 2.4, 3.0), Color("d8c8e8"), Color("f0e8f8"))
	k.pyramid(Vector3(0, 2.9, 0), 3.0, 2.0, 1.3, Color("5a3a8a"), Color("8f5cff"))
	var cols: Array[Color] = [Color("ffd24a"), Color("49c6e5"), Color("ff2fb5"), Color("c47bff"), Color("d8fff6"), Color("ff8a3c"), Color("6fd3a0")]
	for i in 7:                                                                                               # seven plinths, one coloured trophy for each guardian
		var x: float = -2.4 + 0.8 * float(i)
		k.box(Vector3(x, 0.9, -1.75), Vector3(0.55, 0.8, 0.55), Color("a898ac"), Color("cfc0d4"))
		k.dome(Vector3(x, 1.3, -1.75), 0.3, 1.1, 1, 6, cols[i], cols[i].lightened(0.4))
	k.box(Vector3(0, 0.7, -1.55), Vector3(0.1, 0.1, 0.1), Color("5a3a22"))
	for sx in [-1.0, 1.0]:
		k.frustum(Vector3(sx * 2.7, 0.5, -1.2), 0.0, 0.3, 3.4, 0.24, 6, Color("c5b4c8"), Color("e3d6e6"))

static func _bastion(k: MeshKit) -> void:
	var st := Color("7a6a8a")
	k.box(Vector3(0, 1.2, 0), Vector3(5.2, 2.4, 3.6), st, st.lightened(0.15))
	k.box(Vector3(0, 2.7, 0), Vector3(5.6, 0.6, 4.0), st.darkened(0.1), st.lightened(0.2))
	for i in 6:                                                                                               # crenellations
		k.box(Vector3(-2.4 + 0.96 * float(i), 3.3, -1.8), Vector3(0.6, 0.6, 0.5), st.lightened(0.1))
		k.box(Vector3(-2.4 + 0.96 * float(i), 3.3, 1.8), Vector3(0.6, 0.6, 0.5), st.lightened(0.1))
	for sx in [-1.0, 1.0]:
		k.frustum(Vector3(sx * 2.8, 0, 0), 0.0, 1.0, 4.0, 0.9, 7, st.darkened(0.05), st.lightened(0.15))
		k.pyramid(Vector3(sx * 2.8, 4.0, 0), 1.0, 1.0, 1.1, Color("c4122f"), Color("ff3a5a"))
	k.box(Vector3(0, 1.0, -1.85), Vector3(1.4, 2.0, 0.2), Color("3a2a22"))
	k.box(Vector3(0, 2.1, -1.95), Vector3(1.6, 0.25, 0.2), Color("ffc61a"), Color("fff08a"))

static func _den(k: MeshKit) -> void:
	k.blob(Vector3(0, 1.1, 0), Vector3(3.0, 1.9, 2.6), 23, Color("6a4a30"), Color("8a6a4a"))
	k.box(Vector3(0, 0.8, -1.9), Vector3(1.6, 1.5, 0.4), Color("1a0a12"))
	for i in 5:
		var a: float = deg_to_rad(-60.0 + 30.0 * float(i))
		k.frustum(Vector3(sin(a) * 1.7, 0.0, -2.1 - cos(a) * 0.3), 0.0, 0.09, 0.55 + 0.2 * float(i % 3), 0.07, 5, Color("f6ead7"))
		k.dome(Vector3(sin(a) * 1.7, 0.55 + 0.2 * float(i % 3), -2.1 - cos(a) * 0.3), 0.3, 0.7, 1, 6, [Color("d8a8ff"), Color("ff2fb5"), Color("b6ff6a")][i % 3], Color("fff0f8"))
	k.box(Vector3(-2.2, 0.35, 1.2), Vector3(0.8, 0.7, 0.6), Color("c8945a"), Color("e8b87a"))
	k.frustum(Vector3(2.0, 0, 1.0), 0.0, 0.12, 2.0, 0.1, 5, Color("5a3a22"))
	k.quad(Vector3(2.0, 2.0, 1.0), Vector3(2.0, 1.4, 1.0), Vector3(3.0, 1.5, 1.2), Vector3(3.0, 2.0, 1.2), Color("ff7a8a"))
	k.quad(Vector3(2.0, 1.4, 1.0), Vector3(2.0, 2.0, 1.0), Vector3(3.0, 2.0, 1.2), Vector3(3.0, 1.5, 1.2), Color("ffb0b8"))

static func _apiary(k: MeshKit) -> void:
	k.box(Vector3(0, 0.15, 0), Vector3(4.4, 0.3, 3.4), Color("8a9a4a"))
	for i in 3:
		var x: float = -1.4 + 1.4 * float(i)
		k.box(Vector3(x, 0.7, 0.2), Vector3(0.14, 0.8, 0.14), Color("6a4a30"))
		k.frustum(Vector3(x, 0.9, 0.2), 0.0, 0.62, 0.75, 0.5, 8, Color("ffd24a"), Color("fff0a0"), false)
		k.frustum(Vector3(x, 1.65, 0.2), 0.0, 0.5, 0.45, 0.38, 8, Color("ffc61a"), Color("fff0a0"), false)
		k.dome(Vector3(x, 2.1, 0.2), 0.38, 0.8, 1, 8, Color("e8a21a"), Color("fff0a0"))
		k.box(Vector3(x, 1.0, -0.38), Vector3(0.3, 0.12, 0.05), Color("3a2a22"))
	for i in 5:
		k.dome(Vector3(-1.8 + 0.9 * float(i), 0.4, -1.4), 0.26, 0.8, 1, 5, [Color("ff7a8a"), Color("ffd24a"), Color("c47bff")][i % 3], Color("ffffff"))
	k.box(Vector3(2.0, 0.5, -1.2), Vector3(0.7, 0.7, 0.7), Color("c8945a"), Color("e8b87a"))
