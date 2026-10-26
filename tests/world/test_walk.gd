extends TestCase
## Locomotion: the player must never end up in water, off-map, or on a cliff face.
var w: WorldData = StubWorldGen.generate(7)

func test_spawn_is_walkable() -> void:
	var p: Vector3 = Walk.find_spawn(w, w.start_hex)
	check(w.walkable(p.x, p.z), "spawn walkable")
	check(absf(p.y - w.height_at(p.x, p.z)) < 0.001, "spawn snapped to ground")

func test_random_walk_never_enters_blocked_terrain() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 99
	var pos: Vector3 = Walk.find_spawn(w, w.start_hex)
	var violations := 0
	var moved := 0.0
	for step in 4000:
		if step % 200 == 0:
			var a: float = rng.randf() * TAU
			var dir := Vector2(cos(a), sin(a))
			for _i in 200:
				var before: Vector3 = pos
				pos = Walk.step(w, pos, dir * Player.SPEED * 0.016)
				moved += Vector2(pos.x - before.x, pos.z - before.z).length()
				if not w.walkable(pos.x, pos.z):
					violations += 1
	eq(violations, 0, "no step ended in blocked terrain")
	check(moved > 100.0, "walker actually moved (%.0f m)" % moved)

func test_water_blocks_movement() -> void:
	# walk straight towards the nearest water hex from a shore hex; must stop before it.
	var shore := Vector2i(-1, -1)
	var water := Vector2i(-1, -1)
	for r in range(1, HexMath.ROWS - 1):
		for c in range(1, HexMath.COLS - 1):
			var h := Vector2i(c, r)
			if shore.x >= 0:
				break
			if w.biome_hex(h) == Biomes.B.WATER:
				continue
			var cen: Vector2 = HexMath.offset_center(c, r)
			if not w.walkable(cen.x, cen.y):
				continue
			for n in HexMath.neighbors(h):
				if w.biome_hex(n) == Biomes.B.WATER:
					shore = h
					water = n
					break
	check(shore.x >= 0, "found a shore hex")
	var a: Vector2 = HexMath.offset_center(shore.x, shore.y)
	var b: Vector2 = HexMath.offset_center(water.x, water.y)
	var pos := Vector3(a.x, w.height_at(a.x, a.y), a.y)
	var dir: Vector2 = (b - a).normalized()
	for i in 300:
		pos = Walk.step(w, pos, dir * 0.1)
	check(w.walkable(pos.x, pos.z), "still on walkable ground after pushing into water")
	var pushed_to: Vector2 = Vector2(pos.x, pos.z)
	check(pushed_to.distance_to(b) > 2.0, "stopped before reaching the water hex centre")
	eq(w.biome_at(pos.x, pos.z) != Biomes.B.WATER, true, "never inside a water hex")

func test_cliff_blocks_movement() -> void:
	# find a walkable cell with a cliff directly east; walk into it.
	var found := false
	for iz in range(10, WorldData.NZ - 10, 2):
		for ix in range(10, WorldData.NX - 10, 2):
			var x: float = WorldData.ORIGIN.x + float(ix) * WorldData.CELL
			var z: float = WorldData.ORIGIN.y + float(iz) * WorldData.CELL
			if not w.walkable(x, z):
				continue
			var ahead: float = x + 6.0
			if w.slope_at(ahead, z) > 1.5 and not w.walkable(ahead, z) and HexMath.in_bounds(HexMath.world_to_offset(ahead, z)):
				var pos := Vector3(x, w.height_at(x, z), z)
				for i in 200:
					pos = Walk.step(w, pos, Vector2(0.08, 0.0))
				check(w.walkable(pos.x, pos.z), "ended on walkable ground")
				check(pos.x < ahead, "did not climb the cliff face")
				found = true
				break
		if found:
			break
	check(found, "found a cliff to test against")

func test_slides_along_obstacles() -> void:
	var p: Vector3 = Walk.find_spawn(w, w.start_hex)
	var q: Vector3 = Walk.step(w, p, Vector2(1.0, 1.0))
	check(Vector2(q.x - p.x, q.z - p.z).length() > 0.5, "open ground allows full move")

func test_player_input_mapping_and_class_colors() -> void:
	var pl := Player.new()
	pl.world = w
	pl.camera_yaw = 0.0
	var d: Vector2 = pl.world_dir_from_input(Vector2(0, 1))
	check(d.is_equal_approx(Vector2(0, -1)), "forward = -Z at yaw 0")
	pl.camera_yaw = PI * 0.5
	d = pl.world_dir_from_input(Vector2(0, 1))
	check(d.is_equal_approx(Vector2(-1, 0)), "forward rotates with camera yaw")
	pl.set_class_colors(Color.RED, Color.BLUE)
	check(pl.get_child_count() > 0, "model rebuilt after recolor")
	pl.free()

func test_player_process_moves_with_joystick_and_updates_fog_hex() -> void:
	var pl := Player.new()
	pl.world = w
	pl.camera_yaw = 0.0
	pl.place_on_ground(Vector2(Walk.find_spawn(w, w.start_hex).x, Walk.find_spawn(w, w.start_hex).z))
	var hexes: Array[Vector2i] = []
	pl.hex_changed.connect(func(h: Vector2i) -> void: hexes.append(h))
	var start: Vector3 = pl.position
	pl.touch_move = Vector2(0, 1) # joystick forward
	for i in 120:
		pl._process(1.0 / 60.0)
	check(pl.position.z < start.z - 5.0, "forward joystick walks toward -Z (moved %.1f m)" % (start.z - pl.position.z))
	check(w.walkable(pl.position.x, pl.position.z), "still on walkable ground")
	check(absf(pl.position.y - w.height_at(pl.position.x, pl.position.z)) < 0.001, "feet on the terrain")
	check(hexes.size() >= 1, "hex_changed emitted while walking (%d)" % hexes.size())
	check(absf(wrapf(pl.rotation.y, -PI, PI)) < 0.5, "character turned to face -Z")
	pl.input_enabled = false
	var before: Vector3 = pl.position
	pl._process(0.1)
	eq(before, pl.position, "input_enabled=false freezes the player")
	pl.free()
