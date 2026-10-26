class_name StubWorldGen
extends RefCounted
## TEMP: local deterministic world generator so Stream B is unblocked. Replace with an adapter over
## Rules world data (MatchState.world) once Stream A commits it. Do not add gameplay to this file.
const HOLDING_COUNT := 40

static func generate(seed_value: int) -> WorldData:
	var w := WorldData.new()
	w.world_seed = seed_value
	var cols: int = HexMath.COLS
	var rows: int = HexMath.ROWS
	var elev := FastNoiseLite.new()
	elev.seed = seed_value
	elev.frequency = 0.0032
	elev.fractal_octaves = 4
	var moist := FastNoiseLite.new()
	moist.seed = seed_value + 101
	moist.frequency = 0.0042
	moist.fractal_octaves = 3
	var temp := FastNoiseLite.new()
	temp.seed = seed_value + 202
	temp.frequency = 0.0035
	var fung := FastNoiseLite.new()
	fung.seed = seed_value + 303
	fung.frequency = 0.0055
	var ruin := FastNoiseLite.new()
	ruin.seed = seed_value + 404
	ruin.frequency = 0.008
	var ext: Rect2 = HexMath.world_extent()
	var cen: Vector2 = ext.get_center()
	var start: Vector2 = HexMath.offset_center(w.start_hex.x, w.start_hex.y)
	w.biome.resize(cols * rows)
	var is_land := PackedByteArray()
	is_land.resize(cols * rows)
	var elev_v := PackedFloat32Array()
	elev_v.resize(cols * rows)
	for r in rows:
		for c in cols:
			var p: Vector2 = HexMath.offset_center(c, r)
			var nx: float = (p.x - cen.x) / (ext.size.x * 0.5)
			var nz: float = (p.y - cen.y) / (ext.size.y * 0.5)
			var d: float = maxf(absf(nx), absf(nz) * 0.95)
			var e: float = elev.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			e -= smoothstep(0.62, 1.0, d) * 0.75
			e += 0.45 * exp(-p.distance_squared_to(start) / (2.0 * 110.0 * 110.0))
			elev_v[r * cols + c] = e
			is_land[r * cols + c] = 1 if e > 0.27 else 0
	for r in rows:
		for c in cols:
			var i: int = r * cols + c
			var p: Vector2 = HexMath.offset_center(c, r)
			if is_land[i] == 0:
				w.biome[i] = Biomes.B.WATER
				continue
			var e: float = elev_v[i]
			var m: float = moist.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			var t: float = temp.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			var f: float = fung.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			var rn: float = ruin.get_noise_2d(p.x, p.y) * 0.5 + 0.5
			var near_start: bool = HexMath.distance(Vector2i(c, r), w.start_hex) <= 5
			var b: int = Biomes.B.MEADOW
			if near_start:
				b = Biomes.B.MEADOW
			elif e > 0.68:
				b = Biomes.B.HIGHLANDS
			elif rn > 0.66:
				b = Biomes.B.RUINS
			elif f > 0.56 and m > 0.4:
				b = Biomes.B.FUNGAL
			elif m > 0.6 and e < 0.58:
				b = Biomes.B.BOG
			elif t > 0.56 and m < 0.46:
				b = Biomes.B.SALT
			w.biome[i] = b
	# Living Shore: land touching water.
	var shore: Array[int] = []
	for r in rows:
		for c in cols:
			var i: int = r * cols + c
			if w.biome[i] == Biomes.B.WATER or w.biome[i] == Biomes.B.HIGHLANDS:
				continue
			for n in HexMath.neighbors(Vector2i(c, r)):
				if w.biome[HexMath.idx(n)] == Biomes.B.WATER:
					shore.append(i)
					break
	for i in shore:
		if HexMath.distance(Vector2i(i % cols, i / cols), w.start_hex) > 5:
			w.biome[i] = Biomes.B.SHORE
	_holdings(w)
	w.terrain.resize(cols * rows)
	for i in cols * rows:
		w.terrain[i] = WorldData.T_DEEP if w.biome[i] == Biomes.B.WATER else WorldData.T_GROUND
	w.road.resize(cols * rows)
	TerrainHeights.build(w)
	return w

static func _holdings(w: WorldData) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = w.world_seed ^ 0x51ED
	w.holdings.append({"hex": w.start_hex, "name": "Home Farm", "owner": 0})
	var tries: int = 0
	var syll: Array[String] = ["Mum", "Bri", "Tol", "Fen", "Sporl", "Ka", "Nib", "Orr", "Pod", "Wex", "Glim", "Dun"]
	var tail: Array[String] = ["ford", "ham", "stead", "wick", "burrow", "moot", "croft", "hollow"]
	while w.holdings.size() < HOLDING_COUNT and tries < 6000:
		tries += 1
		var c := Vector2i(rng.randi_range(2, HexMath.COLS - 3), rng.randi_range(2, HexMath.ROWS - 3))
		var b: int = w.biome[HexMath.idx(c)]
		if b == Biomes.B.WATER or b == Biomes.B.HIGHLANDS or b == Biomes.B.SALT and rng.randf() < 0.6:
			continue
		var ok := true
		for h in w.holdings:
			if HexMath.distance(h["hex"], c) < 6:
				ok = false
				break
		if ok:
			w.holdings.append({"hex": c, "name": syll[rng.randi() % syll.size()] + tail[rng.randi() % tail.size()], "owner": 1 + (w.holdings.size() % 5)})
