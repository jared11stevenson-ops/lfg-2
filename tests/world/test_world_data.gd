extends TestCase
## WorldData + stub generator + Rules adapter: determinism, biome coverage, heights, walkability.
const SEED := 7

static func _hash(w: WorldData) -> int:
	return hash([w.biome, w.heights, w.start_hex, w.holdings.size()])

func test_stub_is_deterministic() -> void:
	var a: WorldData = StubWorldGen.generate(SEED)
	var b: WorldData = StubWorldGen.generate(SEED)
	eq(_hash(a), _hash(b), "same seed -> identical world")
	var c: WorldData = StubWorldGen.generate(SEED + 1)
	check(_hash(a) != _hash(c), "different seed -> different world")

func test_stub_has_all_biomes_and_holdings() -> void:
	var w: WorldData = StubWorldGen.generate(SEED)
	var seen := {}
	for b in w.biome:
		seen[b] = true
	for b in 8:
		check(seen.has(b), "biome %s present" % Biomes.NAMES[b])
	eq(w.holdings.size(), StubWorldGen.HOLDING_COUNT, "40 holdings")
	for h in w.holdings:
		check(w.biome_hex(h["hex"]) != Biomes.B.WATER, "holding not in water")
	eq(w.biome.size(), HexMath.COLS * HexMath.ROWS, "biome array covers the grid")
	eq(w.heights.size(), (WorldData.NX + 1) * (WorldData.NZ + 1), "height grid size")

func test_start_is_walkable_and_flat() -> void:
	var w: WorldData = StubWorldGen.generate(SEED)
	var c: Vector2 = HexMath.offset_center(w.start_hex.x, w.start_hex.y)
	check(w.walkable(c.x, c.y), "start hex centre walkable")
	check(w.slope_at(c.x, c.y) < 0.2, "start is gentle")

func test_height_at_matches_grid_vertices() -> void:
	var w: WorldData = StubWorldGen.generate(SEED)
	for k in 30:
		var ix: int = 10 + k * 9
		var iz: int = 8 + k * 5
		var x: float = WorldData.ORIGIN.x + float(ix) * WorldData.CELL
		var z: float = WorldData.ORIGIN.y + float(iz) * WorldData.CELL
		check(absf(w.height_at(x, z) - w._h(ix, iz)) < 0.001, "height_at hits vertex height")

func test_water_and_cliffs_not_walkable() -> void:
	var w: WorldData = StubWorldGen.generate(SEED)
	var water_checked := 0
	var cliff_checked := 0
	for r in HexMath.ROWS:
		for c in HexMath.COLS:
			var cen: Vector2 = HexMath.offset_center(c, r)
			if w.biome_hex(Vector2i(c, r)) == Biomes.B.WATER:
				if water_checked < 200:
					check(not w.walkable(cen.x, cen.y), "water hex centre blocked")
					water_checked += 1
	for iz in range(0, WorldData.NZ, 3):
		for ix in range(0, WorldData.NX, 3):
			var x: float = WorldData.ORIGIN.x + float(ix) * WorldData.CELL
			var z: float = WorldData.ORIGIN.y + float(iz) * WorldData.CELL
			if w.slope_at(x, z) > WorldData.MAX_WALK_SLOPE and HexMath.in_bounds(HexMath.world_to_offset(x, z)):
				check(not w.walkable(x, z), "steep cell blocked")
				cliff_checked += 1
	check(water_checked > 50, "enough water hexes sampled")
	check(cliff_checked > 20, "world contains walkable-blocking cliffs (%d)" % cliff_checked)

func test_can_build() -> void:
	var w: WorldData = StubWorldGen.generate(SEED)
	eq(w.can_build(w.start_hex), false, "cannot build on a holding hex")
	var ok := 0
	for n in HexMath.neighbors(w.start_hex):
		if w.can_build(n):
			ok += 1
	check(ok > 0, "some neighbours of the start can host buildings")
	for r in HexMath.ROWS:
		for c in HexMath.COLS:
			if w.biome_hex(Vector2i(c, r)) == Biomes.B.WATER:
				eq(w.can_build(Vector2i(c, r)), false, "no building on water")
				return

func test_rules_adapter_real_world() -> void:
	var st: MatchState = Rules.new_match(SEED, &"lfg:class/judd")
	var w: WorldData = RulesWorldAdapter.from_state(st)
	eq(w.holdings.size(), (st.world["sites"] as Array).size(), "holdings mirror rules sites")
	var water := 0
	var deep := 0
	for i in w.biome.size():
		var t: int = int(st.world["terrain"][i])
		if t == WorldGen.T_DEEP:
			deep += 1
			if w.biome[i] == Biomes.B.WATER:
				water += 1
		else:
			check(w.biome[i] == int(st.world["biome"][i]), "biome index preserved at %d" % i)
	eq(water, deep, "deep terrain -> water biome")
	var sh: Vector2i = HexMath.axial_to_offset(st.world["start"])
	eq(w.start_hex, sh, "start converted to offset")
	var c: Vector2 = HexMath.offset_center(sh.x, sh.y)
	check(w.walkable(c.x, c.y), "rules start walkable")
	eq(w.holding_at(sh) >= 0, true, "start hex is a holding")
	# every rules-impassable hex is blocked in presentation
	var bad := 0
	for i in w.biome.size():
		var t2: int = int(st.world["terrain"][i])
		if t2 == WorldGen.T_DEEP or t2 == WorldGen.T_CLIFF:
			var hx := Vector2i(i % HexMath.COLS, i / HexMath.COLS)
			var cc: Vector2 = HexMath.offset_center(hx.x, hx.y)
			if w.walkable(cc.x, cc.y):
				bad += 1
	eq(bad, 0, "rules-impassable hexes are unwalkable in 3D")
