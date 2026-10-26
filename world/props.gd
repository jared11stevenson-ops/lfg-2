class_name Props
extends RefCounted
## Procedural prop meshes (no imported assets) + deterministic per-hex scatter.
enum T { FUNGUS_TREE, MUSHROOM, REED, PILLAR, RUIN_BLOCK, HOUSE, ROCK, CRYSTAL, TUFT, FLOWER, CROP_ROW, BANNER }
const COUNT := 12
const NAMES: Array[String] = ["fungus_tree", "mushroom", "reed", "pillar", "ruin_block", "house", "rock", "crystal", "tuft", "flower", "crop_row", "banner"]
static var _cache: Dictionary = {}

static func mesh_for(t: int) -> ArrayMesh:
	if _cache.has(t):
		return _cache[t]
	var k := MeshKit.new()
	match t:
		T.FUNGUS_TREE: _fungus_tree(k)
		T.MUSHROOM: _mushroom(k)
		T.REED: _reed(k)
		T.PILLAR: _pillar(k)
		T.RUIN_BLOCK: _ruin_block(k)
		T.HOUSE: _house(k)
		T.ROCK: k.blob(Vector3(0, 0.5, 0), Vector3(1.3, 0.9, 1.1), 11, Color("7b5f8f"), Color("a58bb5"))
		T.CRYSTAL: _crystal(k)
		T.TUFT: _tuft(k)
		T.FLOWER: _flower(k)
		T.CROP_ROW: _crop_row(k)
		T.BANNER: _banner(k)
	var m: ArrayMesh = k.build()
	_cache[t] = m
	return m

static func _blade(k: MeshKit, at: Vector3, h: float, w: float, lean: Vector3, col: Color, col_tip: Color) -> void:
	var a := at + Vector3(-w, 0, 0)
	var b := at + Vector3(w, 0, 0)
	var tip := at + Vector3(0, h, 0) + lean
	var mid := at + Vector3(0, h * 0.4, 0.3)
	k.tri(a, b, tip, col_tip)
	# double-sided: add reverse so blades read from both sides
	k.tri(b, a, tip, col)
	var _unused := mid

static func _fungus_tree(k: MeshKit) -> void:
	var stalk := Color("f3e4cf")
	k.frustum(Vector3.ZERO, 0.0, 0.55, 4.4, 0.34, 7, stalk, Color(0, 0, 0, 0), false, false)
	k.frustum(Vector3.ZERO, 4.1, 2.1, 4.6, 0.5, 9, Color("c9b4c4"), Color(0, 0, 0, 0), false, false) # gills
	k.dome(Vector3(0, 4.15, 0), 2.1, 0.8, 3, 9, Color("ffffff"), Color("d8d0e8"))
	k.dome(Vector3(0.6, 5.7, 0.3), 0.45, 0.45, 1, 5, Color("fffbd0"))
	k.dome(Vector3(-0.8, 5.5, -0.4), 0.35, 0.45, 1, 5, Color("fffbd0"))

static func _mushroom(k: MeshKit) -> void:
	k.frustum(Vector3.ZERO, 0.0, 0.22, 0.9, 0.16, 5, Color("f6ead7"), Color(0, 0, 0, 0), false)
	k.dome(Vector3(0, 0.8, 0), 0.7, 0.8, 2, 6, Color("ffffff"), Color("d8d0e8"))

static func _reed(k: MeshKit) -> void:
	var g := Color("4f9a58")
	var gt := Color("9bd45a")
	for i in 5:
		var a: float = float(i) * 1.26
		var off := Vector3(cos(a) * 0.25, 0, sin(a) * 0.25)
		_blade(k, off, 2.2 + 0.25 * float(i % 3), 0.05, Vector3(cos(a) * 0.3, 0, sin(a) * 0.3), g, gt)
	k.frustum(Vector3(0.1, 0, 0.1), 1.5, 0.09, 2.1, 0.09, 5, Color("7a4a2c"))

static func _pillar(k: MeshKit) -> void:
	var s := Color("c5b4c8")
	k.box(Vector3(0, 0.2, 0), Vector3(1.5, 0.4, 1.5), Color("a898ac"))
	k.frustum(Vector3.ZERO, 0.4, 0.55, 2.7, 0.5, 6, s, Color("e3d6e6"))
	k.frustum(Vector3(1.4, 0, 0.6), 0.0, 0.5, 0.8, 0.5, 6, s, Color("e3d6e6"), true, false, 0.4)

static func _ruin_block(k: MeshKit) -> void:
	k.box(Vector3(0, 0.55, 0), Vector3(2.4, 1.1, 1.5), Color("b9a6b5"), Color("dccfdc"))
	k.box(Vector3(0.6, 1.35, 0.1), Vector3(1.0, 0.5, 0.9), Color("a898ac"), Color("cfc0cf"))
	k.box(Vector3(-1.8, 0.25, 0.9), Vector3(0.9, 0.5, 0.8), Color("a898ac"))

static func _house(k: MeshKit) -> void:
	k.box(Vector3(0, 1.15, 0), Vector3(3.2, 2.3, 2.8), Color("fff1dc"), Color("fff1dc"))
	k.box(Vector3(0, 0.7, 1.41), Vector3(0.8, 1.4, 0.1), Color("7a4a3a"))
	k.box(Vector3(-1.0, 1.4, 1.41), Vector3(0.6, 0.6, 0.08), Color("ffd24a"))
	k.box(Vector3(1.0, 1.4, 1.41), Vector3(0.6, 0.6, 0.08), Color("ffd24a"))
	k.pyramid(Vector3(0, 2.3, 0), 2.1, 1.9, 1.9, Color("e8553a"), Color("ff7a4a"))
	k.box(Vector3(1.0, 3.4, -0.5), Vector3(0.5, 1.0, 0.5), Color("8a6a5a"))

static func _crystal(k: MeshKit) -> void:
	k.frustum(Vector3(0, 0, 0), 0.0, 0.35, 2.2, 0.0, 5, Color("ffd6f0"), Color(0, 0, 0, 0), false)
	k.frustum(Vector3(0.6, 0, 0.2), 0.0, 0.28, 1.4, 0.0, 4, Color("d6fff4"), Color(0, 0, 0, 0), false, false, 0.5)
	k.frustum(Vector3(-0.5, 0, -0.3), 0.0, 0.25, 1.0, 0.0, 4, Color("fff7c2"), Color(0, 0, 0, 0), false, false, 0.2)

static func _tuft(k: MeshKit) -> void:
	var g := Color("86b24a")
	var gt := Color("d6e86a")
	for i in 6:
		var a: float = float(i) * 1.05
		_blade(k, Vector3(cos(a) * 0.18, 0, sin(a) * 0.18), 0.7 + 0.15 * float(i % 3), 0.07, Vector3(cos(a) * 0.25, 0, sin(a) * 0.25), g, gt)

static func _flower(k: MeshKit) -> void:
	k.frustum(Vector3.ZERO, 0.0, 0.05, 0.8, 0.04, 4, Color("5aa04a"), Color(0, 0, 0, 0), false)
	k.dome(Vector3(0, 0.75, 0), 0.32, 0.6, 1, 6, Color("ffffff"), Color("ffe9a8"))

static func _crop_row(k: MeshKit) -> void:
	for r in 3:
		var z: float = (float(r) - 1.0) * 1.3
		k.box(Vector3(0, 0.15, z), Vector3(6.0, 0.3, 0.7), Color("8a5a32"), Color("a06a3a"))
		for i in 6:
			var x: float = -2.5 + float(i)
			k.dome(Vector3(x, 0.3, z), 0.42, 1.1, 1, 5, Color("7fd04a"), Color("4fa03a"))

static func _banner(k: MeshKit) -> void:
	k.frustum(Vector3.ZERO, 0.0, 0.14, 5.0, 0.1, 5, Color("6b4a3a"))
	k.quad(Vector3(0, 4.9, 0), Vector3(0, 3.7, 0), Vector3(1.9, 3.9, 0), Vector3(1.9, 4.6, 0), Color("ff2fb5"))
	k.quad(Vector3(0, 3.7, 0), Vector3(0, 4.9, 0), Vector3(1.9, 4.6, 0), Vector3(1.9, 3.9, 0), Color("ff2fb5"))

const HOUSE_TINTS: Array[Color] = [Color("ffffff"), Color("ffe9e0"), Color("e6fff6"), Color("f6e8ff"), Color("fff6cf")]

## Deterministic scatter for one hex -> Array of {t:int, pos:Vector3, yaw:float, scale:float, color:Color}
static func scatter_hex(w: WorldData, c: Vector2i) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var b: int = w.biome_hex(c)
	if b == Biomes.B.WATER:
		return out
	var rng := RandomNumberGenerator.new()
	rng.seed = (w.world_seed * 100003 + HexMath.idx(c) * 7919) & 0x7fffffff
	var cen: Vector2 = HexMath.offset_center(c.x, c.y)
	var hold: int = w.holding_at(c)
	var near_hold := false
	for n in HexMath.neighbors(c):
		if w.holding_at(n) >= 0:
			near_hold = true
			break
	if hold >= 0:
		var hc: float = w.height_at(cen.x, cen.y)
		out.append({"t": T.BANNER, "pos": Vector3(cen.x, hc, cen.y), "yaw": 0.0, "scale": 1.0, "color": Color.WHITE})
		var cnt: int = 4 + (hold % 2)
		for i in cnt:
			var a: float = TAU * float(i) / float(cnt) + rng.randf() * 0.4
			var p := Vector2(cen.x + cos(a) * 4.6, cen.y + sin(a) * 4.6)
			out.append({"t": T.HOUSE, "pos": Vector3(p.x, w.height_at(p.x, p.y), p.y), "yaw": -a + PI * 0.5, "scale": 0.9 + rng.randf() * 0.3, "color": HOUSE_TINTS[rng.randi() % HOUSE_TINTS.size()]})
		return out
	var plan: Array = []
	match b:
		Biomes.B.MEADOW: plan = [[T.TUFT, 6, 10], [T.FLOWER, 3, 7], [T.ROCK, 0, 1], [T.MUSHROOM, 0, 1]]
		Biomes.B.SHORE: plan = [[T.REED, 2, 4], [T.ROCK, 0, 2], [T.TUFT, 1, 3]]
		Biomes.B.FUNGAL: plan = [[T.FUNGUS_TREE, 2, 4], [T.MUSHROOM, 4, 8], [T.FLOWER, 1, 3]]
		Biomes.B.RUINS: plan = [[T.PILLAR, 2, 4], [T.RUIN_BLOCK, 2, 4], [T.TUFT, 2, 4], [T.ROCK, 0, 2]]
		Biomes.B.SALT: plan = [[T.CRYSTAL, 3, 6], [T.ROCK, 0, 2]]
		Biomes.B.HIGHLANDS: plan = [[T.ROCK, 2, 5], [T.TUFT, 1, 2]]
		Biomes.B.BOG: plan = [[T.REED, 4, 7], [T.MUSHROOM, 2, 4], [T.FUNGUS_TREE, 0, 1]]
	if near_hold and (b == Biomes.B.MEADOW or b == Biomes.B.SHORE or b == Biomes.B.BOG or b == Biomes.B.FUNGAL):
		plan = [[T.CROP_ROW, 2, 2], [T.TUFT, 2, 3], [T.FLOWER, 1, 3]]
	for entry in plan:
		var n: int = rng.randi_range(entry[1], entry[2])
		for _i in n:
			var a2: float = rng.randf() * TAU
			var rad: float = sqrt(rng.randf()) * 6.2
			var x: float = cen.x + cos(a2) * rad
			var z: float = cen.y + sin(a2) * rad
			var h: float = w.height_at(x, z)
			if h < 0.2 or w.slope_at(x, z) > 0.7:
				continue
			var tint: Color = _tint_for(entry[0], rng)
			out.append({"t": entry[0], "pos": Vector3(x, h, z), "yaw": rng.randf() * TAU, "scale": 0.8 + rng.randf() * 0.6, "color": tint})
	return out

static func _tint_for(t: int, rng: RandomNumberGenerator) -> Color:
	match t:
		T.FUNGUS_TREE, T.MUSHROOM, T.FLOWER:
			return Biomes.FUNGI[rng.randi() % Biomes.FUNGI.size()]
		T.PILLAR, T.RUIN_BLOCK:
			return Color("ffffff").lerp(Color("a8ffe8"), rng.randf() * 0.5)
		T.ROCK:
			return Color.WHITE.lerp(Color("ffd0f0"), rng.randf() * 0.4)
		T.TUFT, T.REED:
			return Color.WHITE.lerp(Color("ffffa0"), rng.randf() * 0.6)
	return Color.WHITE
