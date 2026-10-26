class_name WorldView
extends Node3D
## Renders a WorldData as chunked (8x8 hex) flat-shaded low-poly terrain + MultiMesh props + water.
## One terrain MeshInstance3D + one water MeshInstance3D + one MultiMesh per prop type per chunk.
signal build_progress(fraction: float)
signal built

const CHUNK_HEX := 8
const CHUNKS_X := 11 # ceil(84/8)
const CHUNKS_Y := 7 # ceil(54/8)
const PROP_VIEW_RANGE := 240.0

var data: WorldData
var fog: FogOfWar
var terrain_mat: ShaderMaterial
var prop_mat: ShaderMaterial
var water_mat: ShaderMaterial
var chunks: Dictionary = {} # Vector2i -> Node3D
var stats: Dictionary = {"chunks": 0, "terrain_tris": 0, "water_tris": 0, "prop_instances": 0, "multimeshes": 0, "build_ms": 0}

var _terrain_kits: Dictionary = {}
var _water_kits: Dictionary = {}

func _init() -> void:
	name = "WorldView"
	var sh: Shader = load("res://world/shaders/world.gdshader")
	terrain_mat = ShaderMaterial.new()
	terrain_mat.shader = sh
	prop_mat = ShaderMaterial.new()
	prop_mat.shader = sh
	prop_mat.set_shader_parameter("hide_unseen", true)
	water_mat = ShaderMaterial.new()
	water_mat.shader = load("res://world/shaders/water.gdshader")

func setup(world: WorldData, fog_of_war: FogOfWar) -> void:
	data = world
	fog = fog_of_war
	for m in [terrain_mat, prop_mat, water_mat]:
		(m as ShaderMaterial).set_shader_parameter("fow_tex", fog.texture)
	fog._push()

func set_grid_overlay(on: bool) -> void:
	terrain_mat.set_shader_parameter("grid_on", on)

func set_fog_enabled(on: bool) -> void:
	for m in [terrain_mat, prop_mat, water_mat]:
		(m as ShaderMaterial).set_shader_parameter("fow_enabled", on)

func set_purge_amount(t: float) -> void:
	water_mat.set_shader_parameter("purge", t)

## Synchronous build (tests, tools).
func build_all() -> void:
	var t0: int = Time.get_ticks_msec()
	_bucket_terrain()
	for cy in CHUNKS_Y:
		for cx in CHUNKS_X:
			_build_chunk(Vector2i(cx, cy))
	stats["build_ms"] = Time.get_ticks_msec() - t0
	built.emit()

## Spread chunk construction across frames so a phone does not hitch at load.
func build_async(per_frame: int = 3) -> void:
	var t0: int = Time.get_ticks_msec()
	_bucket_terrain()
	await get_tree().process_frame
	var n := 0
	var total: int = CHUNKS_X * CHUNKS_Y
	# build nearest the start hex first
	var order: Array[Vector2i] = []
	for cy in CHUNKS_Y:
		for cx in CHUNKS_X:
			order.append(Vector2i(cx, cy))
	var sc := Vector2i(data.start_hex.x / CHUNK_HEX, data.start_hex.y / CHUNK_HEX)
	order.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return (a - sc).length_squared() < (b - sc).length_squared())
	for k in order:
		_build_chunk(k)
		n += 1
		if n % per_frame == 0:
			build_progress.emit(float(n) / float(total))
			await get_tree().process_frame
	stats["build_ms"] = Time.get_ticks_msec() - t0
	build_progress.emit(1.0)
	built.emit()

func _chunk_of_xz(x: float, z: float) -> Vector2i:
	var h: Vector2i = HexMath.world_to_offset(x, z)
	return Vector2i(clampi(h.x / CHUNK_HEX, 0, CHUNKS_X - 1), clampi(h.y / CHUNK_HEX, 0, CHUNKS_Y - 1))

func _hash01(a: int, b: int, c: int) -> float:
	var h: int = (a * 73856093) ^ (b * 19349663) ^ (c * 83492791)
	h = (h ^ (h >> 13)) * 1274126177
	return float((h ^ (h >> 16)) & 0xffff) / 65535.0

func _tri_color(a: Vector3, b: Vector3, c: Vector3, ix: int, iz: int, t: int) -> Color:
	var cen: Vector3 = (a + b + c) / 3.0
	var biome_id: int = data.biome_at(cen.x, cen.z)
	var n: Vector3 = (c - a).cross(b - a).normalized()
	if n.y < 0.0:
		n = -n
	var nz: float = _hash01(ix, iz, t)
	var col: Color = Biomes.GROUND[biome_id].lerp(Biomes.GROUND_ALT[biome_id], nz * 0.85)
	if cen.y < 0.35:
		# wet sand / lake bed
		var depth: float = clampf(-cen.y / 3.5, 0.0, 1.0)
		col = col.lerp(Color("2b7f8c"), 0.25 + depth * 0.7)
	elif biome_id == Biomes.B.HIGHLANDS:
		col = col.lerp(Color("d9c6ee"), clampf(cen.y / 26.0, 0.0, 0.5))
	var rock_t: float = smoothstep(0.88, 0.62, n.y)
	if rock_t > 0.0:
		col = col.lerp(Biomes.ROCK.lerp(Color("a58bb5"), nz), rock_t)
	return col

func _bucket_terrain() -> void:
	_terrain_kits.clear()
	_water_kits.clear()
	var nx: int = WorldData.NX
	var nz: int = WorldData.NZ
	var cell: float = WorldData.CELL
	var dn := Vector3(0, -100.0, 0)
	var shallow := Color("4fe3d2")
	var deep := Color("2b2fa0")
	for iz in nz:
		for ix in nx:
			var x0: float = WorldData.ORIGIN.x + float(ix) * cell
			var z0: float = WorldData.ORIGIN.y + float(iz) * cell
			var p00 := Vector3(x0, data._h(ix, iz), z0)
			var p10 := Vector3(x0 + cell, data._h(ix + 1, iz), z0)
			var p01 := Vector3(x0, data._h(ix, iz + 1), z0 + cell)
			var p11 := Vector3(x0 + cell, data._h(ix + 1, iz + 1), z0 + cell)
			var k1: Vector2i = _chunk_of_xz((x0 + x0 + cell + x0 + cell) / 3.0, (z0 + z0 + z0 + cell) / 3.0)
			var k2: Vector2i = _chunk_of_xz((x0 + x0 + cell + x0) / 3.0, (z0 + z0 + cell + z0 + cell) / 3.0)
			(_kit(_terrain_kits, k1)).tri(p00, p10, p11, _tri_color(p00, p10, p11, ix, iz, 0), (p00 + p10 + p11) / 3.0 + dn)
			(_kit(_terrain_kits, k2)).tri(p00, p11, p01, _tri_color(p00, p11, p01, ix, iz, 1), (p00 + p11 + p01) / 3.0 + dn)
			var hmin: float = minf(minf(p00.y, p10.y), minf(p01.y, p11.y))
			if hmin < 0.05:
				var depth: float = -(p00.y + p10.y + p01.y + p11.y) * 0.25
				var tcol: Color = shallow.lerp(deep, clampf(depth / 4.0, 0.0, 1.0))
				tcol.a = clampf(0.5 + depth * 0.14, 0.45, 0.93)
				var kw: MeshKit = _kit(_water_kits, _chunk_of_xz(x0 + cell * 0.5, z0 + cell * 0.5))
				var w00 := Vector3(x0, WorldData.WATER_LEVEL, z0)
				var w10 := Vector3(x0 + cell, WorldData.WATER_LEVEL, z0)
				var w01 := Vector3(x0, WorldData.WATER_LEVEL, z0 + cell)
				var w11 := Vector3(x0 + cell, WorldData.WATER_LEVEL, z0 + cell)
				kw.tri(w00, w10, w11, tcol, w00 + dn)
				kw.tri(w00, w11, w01, tcol, w00 + dn)

func _kit(d: Dictionary, k: Vector2i) -> MeshKit:
	if not d.has(k):
		d[k] = MeshKit.new()
	return d[k]

func _build_chunk(k: Vector2i) -> void:
	var root := Node3D.new()
	root.name = "Chunk_%d_%d" % [k.x, k.y]
	add_child(root)
	chunks[k] = root
	if _terrain_kits.has(k):
		var kit: MeshKit = _terrain_kits[k]
		var mi := MeshInstance3D.new()
		mi.name = "Terrain"
		mi.mesh = kit.build()
		mi.material_override = terrain_mat
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
		stats["terrain_tris"] += kit.tri_count()
	if _water_kits.has(k):
		var wk: MeshKit = _water_kits[k]
		var wi := MeshInstance3D.new()
		wi.name = "Water"
		wi.mesh = wk.build()
		wi.material_override = water_mat
		wi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(wi)
		stats["water_tris"] += wk.tri_count()
	_terrain_kits.erase(k)
	_water_kits.erase(k)
	# props
	var per_type: Array = []
	for _i in Props.COUNT:
		per_type.append([])
	for r in range(k.y * CHUNK_HEX, mini(HexMath.ROWS, (k.y + 1) * CHUNK_HEX)):
		for c in range(k.x * CHUNK_HEX, mini(HexMath.COLS, (k.x + 1) * CHUNK_HEX)):
			for p in Props.scatter_hex(data, Vector2i(c, r)):
				per_type[p["t"]].append(p)
	for t in Props.COUNT:
		var list: Array = per_type[t]
		if list.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = Props.mesh_for(t)
		mm.instance_count = list.size()
		for i in list.size():
			var p: Dictionary = list[i]
			var basis := Basis(Vector3.UP, p["yaw"]).scaled(Vector3.ONE * p["scale"])
			mm.set_instance_transform(i, Transform3D(basis, p["pos"]))
			mm.set_instance_color(i, p["color"])
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Props_" + Props.NAMES[t]
		mmi.multimesh = mm
		mmi.material_override = prop_mat
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mmi.visibility_range_end = PROP_VIEW_RANGE
		root.add_child(mmi)
		stats["prop_instances"] += list.size()
		stats["multimeshes"] += 1
	stats["chunks"] += 1
