class_name WorldGen
extends RefCounted
## Deterministic world generation. Pure data out (PackedByteArrays) for the renderer.
## world = {width, height, biome:PackedByteArray (Content.BIOMES idx), terrain:PackedByteArray (T_*),
##          elevation:PackedByteArray (0..255), road:PackedByteArray (0/1), start:Vector2i, sites:Array[Dictionary]}
const VERSION := 1
const T_GROUND := 0
const T_SHALLOW := 1
const T_DEEP := 2
const T_CLIFF := 3
const HOLDING_TARGET := 40
const B_MEADOW := 0
const B_SHORE := 1
const B_GROVE := 2
const B_RUINS := 3
const B_SALT := 4
const B_HIGH := 5
const B_BOG := 6

static func _vnoise(x: float, y: float, s: int) -> float:
	var xi: int = floori(x)
	var yi: int = floori(y)
	var tx: float = x - xi
	var ty: float = y - yi
	tx = tx * tx * (3.0 - 2.0 * tx)
	ty = ty * ty * (3.0 - 2.0 * ty)
	var a: float = Rng.hash2(xi, yi, s)
	var b: float = Rng.hash2(xi + 1, yi, s)
	var c: float = Rng.hash2(xi, yi + 1, s)
	var d: float = Rng.hash2(xi + 1, yi + 1, s)
	return lerpf(lerpf(a, b, tx), lerpf(c, d, tx), ty)

static func _fbm(x: float, y: float, s: int) -> float:
	return (_vnoise(x, y, s) * 0.55 + _vnoise(x * 2.1, y * 2.1, s + 7) * 0.30 + _vnoise(x * 4.3, y * 4.3, s + 13) * 0.15)

static func _c(v: float, k: float) -> float:
	return clampf((v - 0.5) * k + 0.5, 0.0, 1.0)

static func generate(seed_value: int) -> Dictionary:
	for attempt in range(12):
		var w: Dictionary = _try(seed_value, attempt)
		if not w.is_empty():
			return w
	# Fallback: should be practically unreachable; return the last attempt ignoring size requirement.
	return _try(seed_value, 12, true)

static func _try(seed_value: int, attempt: int, force: bool = false) -> Dictionary:
	var W: int = HexGrid.WIDTH
	var H: int = HexGrid.HEIGHT
	var n: int = W * H
	var s: int = (seed_value * 31 + attempt * 977) & 0x3FFFFFFF
	var biome := PackedByteArray()
	var terrain := PackedByteArray()
	var elev := PackedByteArray()
	var road := PackedByteArray()
	biome.resize(n)
	terrain.resize(n)
	elev.resize(n)
	road.resize(n)
	for row in range(H):
		for col in range(W):
			var i: int = row * W + col
			var e: float = _c(_fbm(col / 16.0, row / 16.0, s), 2.0)
			var dx: float = absf(col - W * 0.5) / (W * 0.5)
			var dy: float = absf(row - H * 0.5) / (H * 0.5)
			var d: float = maxf(dx, dy)
			var fall: float = smoothstep(0.84, 1.0, d)
			e = e + 0.15 - fall * 0.6
			var m: float = _c(_fbm(col / 13.0, row / 13.0, s + 101), 1.8)
			var f: float = _c(_fbm(col / 8.0, row / 8.0, s + 202), 1.8)
			var ru: float = _c(_fbm(col / 6.0, row / 6.0, s + 303), 1.8)
			var b: int = B_MEADOW
			var t: int = T_GROUND
			if e < 0.20:
				b = B_SHORE
				t = T_DEEP
			elif e < 0.27:
				b = B_SHORE
				t = T_SHALLOW
			elif e < 0.31:
				b = B_SHORE
			elif e > 0.78:
				b = B_HIGH
				if e > 0.92:
					t = T_CLIFF
			elif m > 0.70 and e < 0.6:
				b = B_BOG
			elif m < 0.28 and e < 0.65:
				b = B_SALT
			elif ru > 0.75:
				b = B_RUINS
			elif f > 0.66:
				b = B_GROVE
			biome[i] = b
			terrain[i] = t
			elev[i] = clampi(int(e * 255.0), 0, 255)
	var world: Dictionary = {"width": W, "height": H, "biome": biome, "terrain": terrain, "elevation": elev, "road": road, "version": VERSION}
	var rng := Rng.new(s ^ 0x5bd1e995)
	var start: Vector2i = _pick_start(world, rng)
	if start.x == -9999:
		return {} if not force else world
	# Flatten start area into meadow.
	for h in HexGrid.ring_within(start, 2):
		var i2: int = HexGrid.index(h)
		world["biome"][i2] = B_MEADOW
		world["terrain"][i2] = T_GROUND
	var comp: Dictionary = flood(world, start)
	if comp.size() < 900 and not force:
		return {}
	var sites: Array[Dictionary] = _place_holdings(world, start, comp, rng)
	if sites.size() < 36 and not force:
		return {}
	world["start"] = start
	world["sites"] = sites
	_build_roads(world, sites)
	return world

static func _pick_start(world: Dictionary, rng: Rng) -> Vector2i:
	for k in range(200):
		var col: int = 26 + rng.rand_i(32)
		var row: int = 16 + rng.rand_i(22)
		var h: Vector2i = HexGrid.from_offset(col, row)
		var ok := true
		for n in HexGrid.ring_within(h, 2):
			if int(world["terrain"][HexGrid.index(n)]) != T_GROUND:
				ok = false
				break
		if ok:
			return h
	return Vector2i(-9999, 0)

static func passable(world: Dictionary, h: Vector2i) -> bool:
	if not HexGrid.in_bounds(h):
		return false
	var t: int = int(world["terrain"][HexGrid.index(h)])
	return t == T_GROUND or t == T_SHALLOW

static func move_cost(world: Dictionary, h: Vector2i) -> float:
	## Pathing cost to ENTER hex h (0 = impassable). Roads halve it.
	if not HexGrid.in_bounds(h):
		return 0.0
	var i: int = HexGrid.index(h)
	var t: int = int(world["terrain"][i])
	if t == T_DEEP or t == T_CLIFF:
		return 0.0
	var c: float = Content.BIOME_COST[int(world["biome"][i])]
	if t == T_SHALLOW:
		c = 3.0
	if int(world["road"][i]) == 1:
		c *= 0.5
	return c

static func biome_at(world: Dictionary, h: Vector2i) -> String:
	return Content.BIOMES[int(world["biome"][HexGrid.index(h)])]

static func flood(world: Dictionary, start: Vector2i) -> Dictionary:
	var seen: Dictionary = {start: true}
	var q: Array[Vector2i] = [start]
	var head: int = 0
	while head < q.size():
		var c: Vector2i = q[head]
		head += 1
		for n in HexGrid.neighbors(c):
			if not seen.has(n) and move_cost(world, n) > 0.0:
				seen[n] = true
				q.append(n)
	return seen

const _SYL_A: Array[String] = ["Ash", "Bram", "Cor", "Dun", "Elm", "Fen", "Glim", "Hob", "Ivy", "Jun", "Kel", "Lum", "Mor", "Nib", "Oak", "Pip", "Quill", "Rue", "Sedge", "Thorn", "Umber", "Vale", "Wick", "Yar", "Zin"]
const _SYL_B: Array[String] = ["ford", "stead", "hollow", "wick", "marsh", "cairn", "bury", "mere", "ton", "gate", "rest", "field"]

static func _place_holdings(world: Dictionary, start: Vector2i, comp: Dictionary, rng: Rng) -> Array[Dictionary]:
	var cands: Array[Vector2i] = []
	for h in comp.keys():
		var i: int = HexGrid.index(h)
		if int(world["terrain"][i]) == T_GROUND:
			cands.append(h)
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return HexGrid.index(a) < HexGrid.index(b))
	var chosen: Array[Vector2i] = [start]
	var min_d: int = 7
	while chosen.size() < HOLDING_TARGET and min_d >= 3:
		var tries: int = 0
		while chosen.size() < HOLDING_TARGET and tries < 600:
			tries += 1
			var c: Vector2i = cands[rng.rand_i(cands.size())]
			var ok := true
			for o in chosen:
				if HexGrid.distance(o, c) < min_d:
					ok = false
					break
			if ok:
				chosen.append(c)
		min_d -= 1
	var sites: Array[Dictionary] = []
	var used: Dictionary = {}
	for k in range(chosen.size()):
		var h: Vector2i = chosen[k]
		var d: int = HexGrid.distance(start, h)
		var tier: int = 1 if d < 16 else (2 if d < 30 else 3)
		var nm: String = ""
		for tries2 in range(20):
			nm = _SYL_A[rng.rand_i(_SYL_A.size())] + _SYL_B[rng.rand_i(_SYL_B.size())]
			if not used.has(nm):
				break
		used[nm] = true
		sites.append({"id": k + 1, "hex": h, "name": nm if k > 0 else "Homestead", "tier": tier})
	return sites

static func _build_roads(world: Dictionary, sites: Array[Dictionary]) -> void:
	var road: PackedByteArray = world["road"]
	var cost_fn := func(h: Vector2i) -> float: return move_cost(world, h)
	for k in range(1, sites.size()):
		var best: int = -1
		var bd: int = 99999
		for j in range(k):
			var d: int = HexGrid.distance(sites[k]["hex"], sites[j]["hex"])
			if d < bd:
				bd = d
				best = j
		var p: Array[Vector2i] = HexGrid.find_path(sites[k]["hex"], sites[best]["hex"], cost_fn)
		for h in p:
			road[HexGrid.index(h)] = 1
		road[HexGrid.index(sites[k]["hex"])] = 1
	road[HexGrid.index(sites[0]["hex"])] = 1
	world["road"] = road
