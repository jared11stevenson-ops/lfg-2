class_name TerrainHeights
extends RefCounted
## Build the continuous height grid from per-hex biome/terrain. Shared by the stub generator and the Rules adapter.
static func build(w: WorldData, elevation: PackedByteArray = PackedByteArray()) -> void:
	var nx1: int = WorldData.NX + 1
	var nz1: int = WorldData.NZ + 1
	var det := FastNoiseLite.new()
	det.seed = w.world_seed + 7
	det.frequency = 0.02
	det.fractal_octaves = 3
	var cliff := FastNoiseLite.new()
	cliff.seed = w.world_seed + 77
	cliff.frequency = 0.0075
	var base: PackedFloat32Array = PackedFloat32Array()
	base.resize(nx1 * nz1)
	var cliff_add: PackedFloat32Array = PackedFloat32Array()
	cliff_add.resize(nx1 * nz1)
	# per-biome base height + amplitude
	var bh: Array[float] = [2.0, 0.7, 3.0, 2.6, 1.4, 9.0, 0.55, -4.0]
	var ba: Array[float] = [1.3, 0.35, 3.0, 1.2, 0.35, 6.0, 0.35, 0.2]
	for iz in nz1:
		for ix in nx1:
			var x: float = WorldData.ORIGIN.x + float(ix) * WorldData.CELL
			var z: float = WorldData.ORIGIN.y + float(iz) * WorldData.CELL
			var hx: Vector2i = HexMath.world_to_offset(x, z)
			var b: int = w.biome_hex(hx)
			var tt: int = w.terrain_hex(hx)
			var n: float = det.get_noise_2d(x, z)
			base[iz * nx1 + ix] = bh[b] + n * ba[b]
			if tt == WorldData.T_SHALLOW:
				base[iz * nx1 + ix] = -0.4 + n * 0.12
			elif elevation.size() > 0 and b != Biomes.B.WATER and HexMath.in_bounds(hx):
				base[iz * nx1 + ix] += (float(elevation[HexMath.idx(hx)]) / 255.0 - 0.5) * 2.0
			if tt == WorldData.T_CLIFF:
				cliff_add[iz * nx1 + ix] = 9.0
			elif b == Biomes.B.HIGHLANDS:
				var cn: float = cliff.get_noise_2d(x, z) * 0.5 + 0.5
				cliff_add[iz * nx1 + ix] = 7.0 * smoothstep(0.50, 0.53, cn) + 7.0 * smoothstep(0.70, 0.73, cn)
	# two separable 5-tap blur passes so biome borders become ramps.
	var tmp := PackedFloat32Array()
	tmp.resize(nx1 * nz1)
	for _pass in 2:
		for iz in nz1:
			for ix in nx1:
				var s: float = 0.0
				for k in range(-2, 3):
					s += base[iz * nx1 + clampi(ix + k, 0, nx1 - 1)]
				tmp[iz * nx1 + ix] = s / 5.0
		for iz in nz1:
			for ix in nx1:
				var s2: float = 0.0
				for k in range(-2, 3):
					s2 += tmp[clampi(iz + k, 0, nz1 - 1) * nx1 + ix]
				base[iz * nx1 + ix] = s2 / 5.0
	w.heights.resize(nx1 * nz1)
	for i in base.size():
		w.heights[i] = base[i] + cliff_add[i]
	# Flatten the homestead so the first hex-ring is pleasant to farm.
	var sp: Vector2 = HexMath.offset_center(w.start_hex.x, w.start_hex.y)
	for iz in nz1:
		for ix in nx1:
			var x2: float = WorldData.ORIGIN.x + float(ix) * WorldData.CELL
			var z2: float = WorldData.ORIGIN.y + float(iz) * WorldData.CELL
			var d: float = Vector2(x2, z2).distance_to(sp)
			if d < 60.0:
				var t: float = 1.0 - smoothstep(30.0, 60.0, d)
				w.heights[iz * nx1 + ix] = lerpf(w.heights[iz * nx1 + ix], 2.0, t)
