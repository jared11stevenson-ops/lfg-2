extends TestCase
## Procedural geometry + chunked world build: winding, budgets, chunk structure, instancing.

func test_meshkit_faces_point_outward() -> void:
	var k := MeshKit.new()
	k.box(Vector3.ZERO, Vector3(2, 2, 2), Color.WHITE)
	eq(k.tri_count(), 12, "box = 12 triangles")
	var bad := 0
	for i in range(0, k.verts.size(), 3):
		var cen: Vector3 = (k.verts[i] + k.verts[i + 1] + k.verts[i + 2]) / 3.0
		if k.norms[i].dot(cen) <= 0.0:
			bad += 1
		# Godot front faces are clockwise: (c-a)x(b-a) must equal the stored normal.
		var n: Vector3 = (k.verts[i + 2] - k.verts[i]).cross(k.verts[i + 1] - k.verts[i]).normalized()
		if n.dot(k.norms[i]) < 0.99:
			bad += 1
	eq(bad, 0, "every box face has outward normal and consistent winding")

func test_prop_meshes_exist_and_are_cheap() -> void:
	for t in Props.COUNT:
		var m: ArrayMesh = Props.mesh_for(t)
		check(m.get_surface_count() == 1, "%s has a surface" % Props.NAMES[t])
		var tris: int = (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
		check(tris > 4 and tris < 300, "%s tri budget ok (%d)" % [Props.NAMES[t], tris])
		var aabb: AABB = m.get_aabb()
		check(aabb.size.y > 0.2 and aabb.size.y < 8.0, "%s plausible height (%.1f)" % [Props.NAMES[t], aabb.size.y])

func test_scatter_is_deterministic_and_biome_specific() -> void:
	var w: WorldData = StubWorldGen.generate(7)
	var found_fungal := false
	var found_ruins := false
	for r in HexMath.ROWS:
		for c in HexMath.COLS:
			var h := Vector2i(c, r)
			var b: int = w.biome_hex(h)
			if b == Biomes.B.FUNGAL and not found_fungal and w.holding_at(h) < 0:
				var a: Array[Dictionary] = Props.scatter_hex(w, h)
				var a2: Array[Dictionary] = Props.scatter_hex(w, h)
				eq(a.size(), a2.size(), "scatter deterministic")
				var has_tree := false
				for p in a:
					if p["t"] == Props.T.FUNGUS_TREE:
						has_tree = true
				check(has_tree or a.size() > 0, "fungal grove gets fungal props")
				found_fungal = true
			if b == Biomes.B.RUINS and not found_ruins and w.holding_at(h) < 0:
				var types := {}
				for p in Props.scatter_hex(w, h):
					types[p["t"]] = true
				check(types.has(Props.T.PILLAR) or types.has(Props.T.RUIN_BLOCK) or types.has(Props.T.TUFT), "ruins get ruin props")
				found_ruins = true
	check(found_fungal and found_ruins, "world has fungal + ruins hexes")
	var home: Array[Dictionary] = Props.scatter_hex(w, w.start_hex)
	var houses := 0
	for p in home:
		if p["t"] == Props.T.HOUSE:
			houses += 1
	check(houses >= 4, "village hex has toy houses (%d)" % houses)

func test_world_view_chunking() -> void:
	var w: WorldData = StubWorldGen.generate(7)
	var f := FogOfWar.new()
	var v := WorldView.new()
	v.setup(w, f)
	v.build_all()
	eq(v.chunks.size(), WorldView.CHUNKS_X * WorldView.CHUNKS_Y, "77 chunks (11x7 of 8x8 hexes)")
	eq(WorldView.CHUNKS_X * WorldView.CHUNK_HEX >= HexMath.COLS, true, "chunks cover all columns")
	eq(WorldView.CHUNKS_Y * WorldView.CHUNK_HEX >= HexMath.ROWS, true, "chunks cover all rows")
	var max_tris := 0
	var total_tris := 0
	var mm_instances := 0
	for k in v.chunks:
		var chunk: Node3D = v.chunks[k]
		var terrain: MeshInstance3D = chunk.get_node_or_null("Terrain")
		check(terrain != null, "chunk %s has terrain" % str(k))
		if terrain != null:
			var tris: int = (terrain.mesh.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3
			max_tris = maxi(max_tris, tris)
			total_tris += tris
		for ch in chunk.get_children():
			if ch is MultiMeshInstance3D:
				mm_instances += (ch as MultiMeshInstance3D).multimesh.instance_count
				check((ch as MultiMeshInstance3D).visibility_range_end > 0.0, "props have a draw distance")
	check(max_tris < 3500, "max terrain tris per chunk %d < 3500" % max_tris)
	check(total_tris > 100000, "terrain triangles total %d" % total_tris)
	eq(v.stats["terrain_tris"], total_tris, "stats match actual meshes")
	check(mm_instances > 5000, "props are instanced (%d instances)" % mm_instances)
	check(v.stats["multimeshes"] < 12 * 77, "multimesh count bounded (%d)" % v.stats["multimeshes"])
	check(v.stats["build_ms"] < 60000, "sync build finishes (%d ms)" % v.stats["build_ms"])
	v.free()

func test_every_terrain_triangle_faces_up() -> void:
	var w: WorldData = StubWorldGen.generate(7)
	var v := WorldView.new()
	v.setup(w, FogOfWar.new())
	v._bucket_terrain()
	var bad := 0
	var n := 0
	for k in v._terrain_kits:
		var kit: MeshKit = v._terrain_kits[k]
		for i in range(0, kit.norms.size(), 3):
			n += 1
			if kit.norms[i].y <= 0.0:
				bad += 1
	check(n > 100000, "triangles checked (%d)" % n)
	eq(bad, 0, "no downward-facing terrain triangles")
	v.free()

func test_shaders_load() -> void:
	for p in ["res://world/shaders/world.gdshader", "res://world/shaders/water.gdshader", "res://world/shaders/telegraph.gdshader", "res://ui/shaders/tilt_shift.gdshader"]:
		var s: Shader = load(p)
		check(s != null and s.code.length() > 50, "shader loads: " + p)
