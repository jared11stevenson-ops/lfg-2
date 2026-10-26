extends TestCase

func test_hex_basics() -> void:
	eq(HexGrid.distance(Vector2i(0, 0), Vector2i(0, 0)), 0, "d0")
	eq(HexGrid.distance(Vector2i(0, 0), Vector2i(3, -3)), 3, "d diag")
	eq(HexGrid.neighbors(Vector2i(10, 10)).size(), 6, "6 neighbors interior")
	for n in HexGrid.neighbors(Vector2i(10, 10)):
		eq(HexGrid.distance(Vector2i(10, 10), n), 1, "neighbor dist 1")
	for i in [0, 83, 84, 4535, 1234]:
		eq(HexGrid.index(HexGrid.from_index(i)), i, "index roundtrip %d" % i)
	for row in [0, 1, 52, 53]:
		for col in [0, 83]:
			var h: Vector2i = HexGrid.from_offset(col, row)
			eq(HexGrid.to_offset(h), Vector2i(col, row), "offset roundtrip")
			check(HexGrid.in_bounds(h), "in bounds")
	check(not HexGrid.in_bounds(HexGrid.from_offset(84, 0)), "col 84 out")
	check(not HexGrid.in_bounds(HexGrid.from_offset(0, 54)), "row 54 out")
	check(not HexGrid.in_bounds(HexGrid.from_offset(-1, 3)), "col -1 out")
	var ln: Array[Vector2i] = HexGrid.line(Vector2i(2, 2), Vector2i(8, 4))
	eq(ln.size(), HexGrid.distance(Vector2i(2, 2), Vector2i(8, 4)) + 1, "line len")
	eq(ln[0], Vector2i(2, 2), "line start")
	eq(ln[ln.size() - 1], Vector2i(8, 4), "line end")
	for i in range(1, ln.size()):
		eq(HexGrid.distance(ln[i - 1], ln[i]), 1, "line contiguous")

func test_pathing_cost_and_blocking() -> void:
	var cost := func(h: Vector2i) -> float:
		if h.x == 5 and h.y >= 0 and h.y < 8:
			return 0.0 # wall
		return 1.0
	var p: Array[Vector2i] = HexGrid.find_path(Vector2i(2, 2), Vector2i(8, 2), cost)
	check(p.size() > 0, "path found around wall")
	eq(p[p.size() - 1], Vector2i(8, 2), "path ends at goal")
	for h in p:
		check(not (h.x == 5 and h.y >= 0 and h.y < 8), "path avoids wall")
	var blocked := func(h: Vector2i) -> float: return 0.0 if h == Vector2i(9, 2) else 1.0
	eq(HexGrid.find_path(Vector2i(2, 2), Vector2i(9, 2), blocked).size(), 0, "impassable goal -> empty")
	# cheaper route preferred
	var road := func(h: Vector2i) -> float: return 0.1 if h.y == 3 else 5.0
	var p2: Array[Vector2i] = HexGrid.find_path(Vector2i(0, 3), Vector2i(10, 3), road)
	check(p2.size() >= 10, "road path found")

func test_world_dimensions_and_biomes() -> void:
	for sd in [1, 7, 12345]:
		var w: Dictionary = WorldGen.generate(sd)
		eq(w["width"], 84, "width")
		eq(w["height"], 54, "height")
		eq((w["biome"] as PackedByteArray).size(), 84 * 54, "biome size")
		var seen: Dictionary = {}
		var land: int = 0
		for i in range(84 * 54):
			seen[int(w["biome"][i])] = true
			if int(w["terrain"][i]) == WorldGen.T_GROUND:
				land += 1
		eq(seen.size(), 7, "all 7 biomes present seed %d" % sd)
		check(land > 84 * 54 * 0.5, "mostly land seed %d (land %d)" % [sd, land])
		check(land < 84 * 54 * 0.95, "some water/cliff seed %d" % sd)

func test_world_determinism() -> void:
	var a: Dictionary = WorldGen.generate(42)
	var b: Dictionary = WorldGen.generate(42)
	var c: Dictionary = WorldGen.generate(43)
	check(a["biome"] == b["biome"] and a["terrain"] == b["terrain"] and a["road"] == b["road"], "same seed same world")
	eq(a["sites"], b["sites"], "same holdings")
	check(a["biome"] != c["biome"], "different seed differs")

func test_holdings_reachable_and_spaced() -> void:
	for sd in [3, 99]:
		var w: Dictionary = WorldGen.generate(sd)
		var sites: Array = w["sites"]
		check(sites.size() >= 36 and sites.size() <= 44, "about 40 holdings (got %d)" % sites.size())
		eq(sites[0]["hex"], w["start"], "site 0 is player start")
		eq(WorldGen.biome_at(w, w["start"]), "meadow", "start in meadow")
		var comp: Dictionary = WorldGen.flood(w, w["start"])
		var seen: Dictionary = {}
		for s in sites:
			check(comp.has(s["hex"]), "holding reachable from start")
			check(WorldGen.passable(w, s["hex"]), "holding passable")
			check(not seen.has(s["hex"]), "unique holding hex")
			seen[s["hex"]] = true
			check(int(s["tier"]) >= 1 and int(s["tier"]) <= 3, "tier range")
		var p: Array[Vector2i] = HexGrid.find_path(w["start"], sites[sites.size() - 1]["hex"], func(h: Vector2i) -> float: return WorldGen.move_cost(w, h))
		check(p.size() > 0, "path start -> last holding")

func test_impassable_terrain_has_zero_cost() -> void:
	var w: Dictionary = WorldGen.generate(5)
	var deep: int = 0
	for i in range(84 * 54):
		var t: int = int(w["terrain"][i])
		var c: float = WorldGen.move_cost(w, HexGrid.from_index(i))
		if t == WorldGen.T_DEEP or t == WorldGen.T_CLIFF:
			eq(c, 0.0, "impassable cost 0")
			deep += 1
		else:
			check(c > 0.0, "passable cost > 0")
	check(deep > 0, "world has impassable tiles")
	eq(WorldGen.move_cost(w, Vector2i(-50, 0)), 0.0, "out of bounds impassable")
