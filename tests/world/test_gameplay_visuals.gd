extends TestCase
## Farm plot growth states, build-placement preview colours, enemy telegraphs.
var w: WorldData = StubWorldGen.generate(7)

func test_every_growth_stage_has_a_distinct_mesh() -> void:
	var tri_counts: Array[int] = []
	var aabbs: Array[AABB] = []
	for s in FarmLayer.STAGE_NAMES.size():
		var m: ArrayMesh = FarmLayer.stage_mesh(s)
		var arr: Array = m.surface_get_arrays(0)
		tri_counts.append((arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size() / 3)
		aabbs.append(m.get_aabb())
	var uniq := {}
	for c in tri_counts:
		uniq[c] = true
	eq(uniq.size() >= 5, true, "stages differ in geometry (%s)" % str(tri_counts))
	check(tri_counts[FarmLayer.Stage.RIPE] > tri_counts[FarmLayer.Stage.SPROUT], "ripe is richer than sprout")
	check(tri_counts[FarmLayer.Stage.SPROUT] > tri_counts[FarmLayer.Stage.TILLED], "sprout has plants, tilled does not")
	check(aabbs[FarmLayer.Stage.RIPE].size.y > aabbs[FarmLayer.Stage.SEEDED].size.y + 0.5, "ripe plants stand taller than seeds")
	check(aabbs[FarmLayer.Stage.GROWING].size.y > aabbs[FarmLayer.Stage.SPROUT].size.y, "growing taller than sprout")

func test_plot_instancing_by_stage() -> void:
	var f := FarmLayer.new()
	f.world = w
	for i in 30:
		f.set_plot("p%d" % i, Vector2(100 + i * 6, 100), i % 6, i % 2 == 0)
	f.rebuild()
	for s in 6:
		var mmi: MultiMeshInstance3D = f.get_node("Plots_" + FarmLayer.STAGE_NAMES[s])
		eq(mmi.multimesh.instance_count, 5, "5 plots per stage in its own multimesh (%s)" % FarmLayer.STAGE_NAMES[s])
	eq(f.count_in_stage(FarmLayer.Stage.RIPE), 5, "count_in_stage")
	f.set_plot("p4", Vector2(0, 0), FarmLayer.Stage.RIPE)
	f.remove_plot("p0")
	f.rebuild()
	eq(f.plots.size(), 29, "remove works")
	f.free()

func test_sync_from_rules_state() -> void:
	var st: MatchState = Rules.new_match(7, &"lfg:class/judd")
	var ax: Vector2i = st.world["start"]
	var placed := 0
	for h in HexGrid.ring_within(ax, 2):
		if h == ax:
			continue
		var res: Dictionary = Rules.apply(st, {"type": &"plant", "actor": 1, "seq": 10 + placed, "args": {"crop": "lfg:crop/glowfruit", "hex": h}})
		if res["ok"]:
			placed += 1
		if placed >= 3:
			break
	check(placed >= 1, "planted through Rules (%d)" % placed)
	var f := FarmLayer.new()
	f.world = RulesWorldAdapter.from_state(st)
	f.sync_from_state(st)
	eq(f.plots.size(), st.plots.size(), "one visual plot per rules plot")
	for k in st.plots:
		eq(f.stage_of(k), FarmLayer.Stage.SEEDED, "age 0 shows as seeded")
		st.plots[k]["age"] = 99
	f.sync_from_state(st)
	for k in st.plots:
		eq(f.stage_of(k), FarmLayer.Stage.RIPE, "fully grown shows as ripe")
	st.plots.clear()
	f.sync_from_state(st)
	eq(f.plots.size(), 0, "plots removed when rules drops them (harvest/withered)")
	eq(FarmLayer.stage_for_age(1, 4), FarmLayer.Stage.SPROUT, "early growth = sprout")
	eq(FarmLayer.stage_for_age(3, 4), FarmLayer.Stage.GROWING, "late growth = growing")
	f.free()

func test_build_preview_valid_and_invalid_colours() -> void:
	var p := BuildPreview.new()
	p.world = w
	var good := Vector2i(-1, -1)
	for n in HexMath.neighbors(w.start_hex):
		if w.can_build(n):
			good = n
			break
	var water := Vector2i(-1, -1)
	for r in HexMath.ROWS:
		for c in HexMath.COLS:
			if water.x < 0 and w.biome_hex(Vector2i(c, r)) == Biomes.B.WATER:
				water = Vector2i(c, r)
	p.show_at(good)
	eq(p.valid, true, "open meadow valid")
	check(p._ghost_mat.albedo_color.g > p._ghost_mat.albedo_color.r, "valid ghost is green")
	check(p._foot.mesh != null and p._foot.mesh.get_surface_count() == 1, "footprint mesh built")
	var cen: Vector2 = HexMath.offset_center(good.x, good.y)
	check(absf(p.position.x - cen.x) < 0.01 and absf(p.position.z - cen.y) < 0.01, "snapped to hex centre")
	p.show_at(water)
	eq(p.valid, false, "water invalid")
	check(p._ghost_mat.albedo_color.r > p._ghost_mat.albedo_color.g, "invalid ghost is red")
	p.show_at(w.start_hex)
	eq(p.valid, false, "holding hex invalid")
	p.extra_validator = func(_h: Vector2i) -> bool: return false
	p.hex = Vector2i(-1, -1)
	p.show_at(good)
	eq(p.valid, false, "external validator can veto")
	p.hide_preview()
	eq(p.visible, false, "hide works")
	p.free()

func test_stage_blocks_build_on_plots() -> void:
	var f := FarmLayer.new()
	var hx := Vector2i(30, 20)
	var c: Vector2 = HexMath.offset_center(hx.x, hx.y)
	f.set_plot("a", c, FarmLayer.Stage.TILLED)
	eq(f.hex_has_plot(hx), true, "plot occupies its hex")
	eq(f.hex_has_plot(Vector2i(31, 20)), false, "neighbour free")
	f.free()

func test_telegraph_shapes_lifecycle_and_conformance() -> void:
	var t := Telegraphs.new()
	t.world = w
	var o := Vector3(HexMath.offset_center(40, 25).x, 2.0, HexMath.offset_center(40, 25).y)
	var zc: Node3D = t.spawn(Telegraphs.Shape.CIRCLE, o, 0.0, 6.0, 1.0)
	var zk: Node3D = t.spawn(Telegraphs.Shape.CONE, o, 1.0, 10.0, 1.0, {"half_angle": 0.5})
	var zl: Node3D = t.spawn(Telegraphs.Shape.LINE, o, 2.0, 14.0, 1.0, {"width": 2.0})
	eq(t.active_count(), 3, "three zones live")
	var m: ArrayMesh = (zc as MeshInstance3D).mesh
	eq((m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size(), (Telegraphs.GRID + 1) * (Telegraphs.GRID + 1), "terrain-conforming grid")
	var verts: PackedVector3Array = m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX]
	var max_err := 0.0
	for v in verts:
		var wp: Vector3 = o + v # yaw 0
		max_err = maxf(max_err, absf((wp.y) - (w.height_at(wp.x, wp.z) + 0.18)))
	check(max_err < 0.001, "zone hugs the terrain (max err %.4f)" % max_err)
	for z in [zc, zk, zl]:
		eq(((z as MeshInstance3D).material_override as ShaderMaterial).shader != null, true, "zone has shader")
	t.set_progress_seconds(0.5)
	t._process(0.0)
	eq(float(((zc as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("progress")), 0.5, "wind-up progress drives the fill")
	t.set_progress_seconds(5.0)
	t._process(0.0)
	eq(t.active_count(), 0, "zones expire after wind-up + flash")
	for z in [zc, zk, zl]:
		z.free()
	t.free()

func test_telegraph_event_adapter() -> void:
	var t := Telegraphs.new()
	t.world = w
	t.handle_event({"type": &"enemy_telegraph", "pos": Vector2(500, 300), "shape": "cone", "radius": 9.0, "yaw": 0.3, "windup": 1.5, "half_angle": 0.5})
	t.handle_event({"type": &"enemy_telegraph", "pos": Vector3(520, 0, 310), "shape": "line", "length": 12.0, "windup": 1.0})
	t.handle_event({"type": &"something_else"})
	eq(t.active_count(), 2, "only telegraph events spawn zones")
	t.purge_colors = true
	var z: Node3D = t.spawn(Telegraphs.Shape.CIRCLE, Vector3(500, 0, 300), 0.0, 4.0, 1.0)
	var ca: Color = ((z as MeshInstance3D).material_override as ShaderMaterial).get_shader_parameter("color_a")
	check(ca.b > 0.5, "purge recolours telegraphs for contrast on red ground")
	for ch in t.get_children():
		ch.free()
	t.free()
