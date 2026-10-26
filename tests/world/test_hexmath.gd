extends TestCase
## HexMath: world<->hex conversion must round-trip for every hex and agree with Rules' HexGrid.

func test_roundtrip_every_hex() -> void:
	var bad := 0
	for r in HexMath.ROWS:
		for c in HexMath.COLS:
			var p: Vector2 = HexMath.offset_center(c, r)
			if HexMath.world_to_offset(p.x, p.y) != Vector2i(c, r):
				bad += 1
	eq(bad, 0, "hex centres round trip")

func test_points_inside_hex_map_back() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 5
	var bad := 0
	for i in 400:
		var c: int = rng.randi_range(1, HexMath.COLS - 2)
		var r: int = rng.randi_range(1, HexMath.ROWS - 2)
		var cen: Vector2 = HexMath.offset_center(c, r)
		var a: float = rng.randf() * TAU
		var d: float = rng.randf() * HexMath.APOTHEM * 0.95 # inside the inscribed circle
		var p: Vector2 = cen + Vector2(cos(a), sin(a)) * d
		if HexMath.world_to_offset(p.x, p.y) != Vector2i(c, r):
			bad += 1
	eq(bad, 0, "points inside inscribed circle resolve to their hex")

func test_matches_rules_hexgrid() -> void:
	var bad := 0
	for r in range(0, HexMath.ROWS, 3):
		for c in range(0, HexMath.COLS, 3):
			var rules_p: Vector2 = HexGrid.to_world(HexGrid.from_offset(c, r))
			if rules_p.distance_to(HexMath.offset_center(c, r)) > 0.01:
				bad += 1
	eq(bad, 0, "HexMath.offset_center == HexGrid.to_world")
	eq(HexGrid.WIDTH, HexMath.COLS, "cols match rules")
	eq(HexGrid.HEIGHT, HexMath.ROWS, "rows match rules")

func test_neighbors_and_distance() -> void:
	var c := Vector2i(40, 20)
	eq(HexMath.neighbors(c).size(), 6, "interior hex has 6 neighbours")
	for n in HexMath.neighbors(c):
		eq(HexMath.distance(c, n), 1, "neighbour distance 1")
		var d: float = HexMath.offset_center(c.x, c.y).distance_to(HexMath.offset_center(n.x, n.y))
		check(absf(d - HexMath.HEX_W) < 0.01, "neighbour centres are one hex width apart")
	eq(HexMath.neighbors(Vector2i(0, 0)).size() < 6, true, "corner hex has fewer neighbours")
	for i in 50:
		var a := Vector2i((i * 7) % 84, (i * 11) % 54)
		var b := Vector2i((i * 13 + 5) % 84, (i * 3 + 1) % 54)
		eq(HexMath.distance(a, b), HexGrid.distance(HexGrid.from_offset(a.x, a.y), HexGrid.from_offset(b.x, b.y)), "distance agrees with HexGrid")

func test_axial_conversion() -> void:
	for r in range(0, 54, 5):
		for c in range(0, 84, 5):
			var ax: Vector2i = HexMath.offset_to_axial(Vector2i(c, r))
			eq(ax, HexGrid.from_offset(c, r), "offset->axial matches rules")
			eq(HexMath.axial_to_offset(ax), Vector2i(c, r), "axial->offset roundtrip")
