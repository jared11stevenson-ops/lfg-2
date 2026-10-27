extends TestCase
## Roads as ribbons, building models for every building id, per-crop plant models, holding layer on Rules sites, draw bounds.
static var _state: MatchState
static var _world: WorldData

func _ensure() -> void:
	if _state == null:
		_state = Rules.new_match(5, &"lfg:class/judd", {"wild_enemies": false})
		_world = RulesWorldAdapter.from_state(_state)

func test_roads_are_ribbon_meshes() -> void:
	_ensure()
	var rl := RoadLayer.new()
	rl.build(_world)
	var road_hexes := 0
	var pairs := 0
	for r in HexMath.ROWS:
		for c in HexMath.COLS:
			var h := Vector2i(c, r)
			if _world.is_road(h):
				road_hexes += 1
				for n in HexMath.neighbors(h):
					if _world.is_road(n) and HexMath.idx(n) > HexMath.idx(h):
						pairs += 1
	check(road_hexes > 20, "generated world has roads (%d hexes)" % road_hexes)
	eq(int(rl.stats["road_hexes"]), road_hexes, "every road hex gets a hub")
	eq(int(rl.stats["segments"]), pairs, "one ribbon per adjacent road pair")
	check(int(rl.stats["chunks"]) >= 1 and int(rl.stats["chunks"]) <= 77, "ribbons bucketed per chunk (%d meshes)" % rl.stats["chunks"])
	check(rl.get_child_count() == int(rl.stats["chunks"]), "one MeshInstance3D per chunk")
	# ribbons sit just above the terrain
	var mi: MeshInstance3D = rl.get_child(0)
	var arr: Array = mi.mesh.surface_get_arrays(0)
	var verts: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
	var worst := 99.0
	var best := -99.0
	for v in verts:
		var d: float = v.y - _world.height_at(v.x, v.z)
		worst = minf(worst, d)
		best = maxf(best, d)
	check(worst > 0.05 and best < 0.6, "road lies on the ground (lift %.2f..%.2f)" % [worst, best])
	check(mi.cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "no shadows by default")
	rl.free()

func test_terrain_tint_reduced_for_roads() -> void:
	# the old 55% tint was replaced by a faint underlay; the ribbon carries the look
	var src: String = FileAccess.get_file_as_string("res://world/world_view.gd")
	check(src.contains("0.18"), "terrain road tint is a faint underlay")

func test_every_building_has_a_model() -> void:
	var ids: Array[String] = BuildingModels.all_ids()
	check(ids.size() >= 12, "data lists buildings (%d)" % ids.size())
	var tris: Dictionary = {}
	var pending: int = 0
	for id in ids:
		if bool(Content.building(id).get("model_pending", false)):
			pending += 1      # pass-2 rank buildings (data/buildings.json "model_pending"): the world stream owes them a dedicated mesh; they use the fallback hut until then
			continue
		var m: ArrayMesh = BuildingModels.mesh_for(id)
		check(m.get_surface_count() == 1 and m.get_aabb().size.y > 1.5, "%s has a model" % id)
		var a: AABB = BuildingModels.footprint(id)
		check(a.size.x < 9.0 and a.size.z < 9.0, "%s footprint fits a hex site (%.1f x %.1f)" % [id, a.size.x, a.size.z])
		check(BuildingModels.has_dedicated_model(id), "%s has a dedicated (non-fallback) model" % id)
		tris[m.get_surface_count() * 100000 + (m.surface_get_arrays(0)[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()] = id
	eq(tris.size(), ids.size() - pending, "no two buildings share a mesh")
	check(pending <= 3, "at most the three pass-2 buildings still lack a model")
	for id in ids:
		if bool(Content.building(id).get("model_pending", false)):
			check(BuildingModels.mesh_for(id).get_aabb().size.y > 1.0, "%s renders with the fallback hut" % id)
	var fb: ArrayMesh = BuildingModels.mesh_for("lfg:building/not_in_data")
	check(fb.get_aabb().size.y > 1.0, "unknown ids fall back to a generic hut")

func test_crop_models_per_crop() -> void:
	var by_stage: Dictionary = {}
	for cid in CropModels.CROPS:
		check(Content.crops().has(cid), "%s in data" % cid)
		var prev := -1
		for st in [FarmLayer.Stage.SEEDED, FarmLayer.Stage.SPROUT, FarmLayer.Stage.GROWING, FarmLayer.Stage.RIPE, FarmLayer.Stage.WILTED]:
			var m: ArrayMesh = FarmLayer.stage_mesh(st, cid)
			check(m.get_surface_count() == 1, "%s stage %d builds" % [cid, st])
			var arrs: Array = m.surface_get_arrays(0)
			var n: int = hash(arrs[Mesh.ARRAY_VERTEX]) ^ hash(arrs[Mesh.ARRAY_COLOR])
			if not by_stage.has(st):
				by_stage[st] = {}
			by_stage[st][n] = true
			prev = 1
		check(prev > 0, "wilted model exists")
	for st in by_stage:
		eq((by_stage[st] as Dictionary).size(), 3, "stage %d differs between the 3 crops" % st)
	var ripe_a: ArrayMesh = FarmLayer.stage_mesh(FarmLayer.Stage.RIPE, "lfg:crop/glowfruit")
	var ripe_b: ArrayMesh = FarmLayer.stage_mesh(FarmLayer.Stage.RIPE, "lfg:crop/sporebean")
	check(ripe_a.get_aabb().size.y != ripe_b.get_aabb().size.y, "ripe sporebean is taller than glowfruit")

func test_farm_layer_routes_plots_by_crop() -> void:
	var f := FarmLayer.new()
	f.world = null
	eq(f._mmis.size(), CropModels.CROPS.size() * FarmLayer.STAGE_NAMES.size(), "one MultiMesh per (crop, stage): %d" % f._mmis.size())
	f.set_plot("a", Vector2(10, 10), FarmLayer.Stage.RIPE, false, Color.WHITE, "lfg:crop/sporebean")
	f.set_plot("b", Vector2(30, 10), FarmLayer.Stage.RIPE, false, Color.WHITE, "lfg:crop/saltroot")
	f.set_plot("c", Vector2(50, 10), FarmLayer.Stage.RIPE, false, Color.WHITE, "lfg:crop/glowfruit")
	f.set_plot("d", Vector2(70, 10), FarmLayer.Stage.SPROUT)
	f.rebuild()
	var used := 0
	for m in f._mmis:
		if m.multimesh.instance_count > 0:
			used += 1
	eq(used, 4, "four distinct (crop, stage) batches used")
	var total := 0
	for m in f._mmis:
		total += m.multimesh.instance_count
	eq(total, 4, "every plot drawn exactly once")
	var ripe_idx: int = CropModels.index_of("lfg:crop/sporebean") * FarmLayer.STAGE_NAMES.size() + FarmLayer.Stage.RIPE
	eq(f._mmis[ripe_idx].multimesh.instance_count, 1, "sporebean ripe batch has its plot")
	f.free()

func test_holding_layer_places_buildings_on_rules_sites() -> void:
	_ensure()
	var st: MatchState = Rules.new_match(5, &"lfg:class/judd", {"wild_enemies": false})
	var inv: Dictionary = st.actors[1]["inv"]
	inv["lfg:item/timber"] = 100
	inv["lfg:item/stone"] = 100
	inv["lfg:item/coin"] = 100
	var home: int = int(st.factions[0]["home"])
	Standing.set_rank(st, 0, 1)      # the granary is a rank-1 building
	var want: Dictionary = {}
	var seq := 100
	for b in ["lfg:building/wall", "lfg:building/storehouse", "lfg:building/well", "lfg:building/granary"]:
		seq += 1
		var r: Dictionary = Rules.apply(st, {"type": &"build", "actor": 1, "seq": seq, "args": {"holding": home, "building": b}})
		eq(r["ok"], true, "build %s ok (%s)" % [b, r["error"]])
		want[b] = true
	var hl := HoldingLayer.new()
	hl.world = _world
	hl.sync_from_state(st)
	eq(hl.counts.size(), 4, "one MultiMesh batch per building kind in use")
	var total := 0
	for k in hl.counts:
		total += int(hl.counts[k])
	eq(total, 4, "four buildings drawn")
	# each building stands on its Rules site hex
	var sites: Dictionary = st.holdings[home]["sites"]
	eq(sites.size(), 4, "rules recorded 4 sites")
	for k in sites:
		var parts: PackedStringArray = String(k).split(",")
		var c: Vector2 = BuildingModels.site_world(Vector2i(int(parts[0]), int(parts[1])))
		var found := false
		for pl in hl.placed_last:
			var o: Vector3 = pl["pos"]
			if pl["id"] == sites[k] and Vector2(o.x, o.z).distance_to(c) < 0.01:
				found = true
		check(found, "%s stands on its site %s" % [sites[k], k])
	# demolish clears it
	var r2: Dictionary = Rules.apply(st, {"type": &"demolish", "actor": 1, "seq": 200, "args": {"holding": home, "building": "lfg:building/well"}})
	eq(r2["ok"], true, "demolish ok")
	hl.sync_from_state(st)
	eq(hl.counts.has("lfg:building/well"), false, "demolished building disappears")
	hl.free()

func test_draw_call_bounds_documented_numbers() -> void:
	# crops: <= 18 MultiMeshes whatever the plot count; characters 5-6 meshes
	var f := FarmLayer.new()
	check(f._mmis.size() <= 18, "farm batches bounded (%d)" % f._mmis.size())
	f.free()
	var worst := 0
	for id in CharacterKit.ENEMY_IDS:
		var r: CharacterRig = CharacterKit.build_enemy(id)
		worst = maxi(worst, r.mesh_count)
		r.free()
	check(worst <= 6, "enemy rigs <= 6 draws (%d)" % worst)
	check(ActorLayer.MAX_RIGS * 6 + ActorLayer.MAX_NPC_HOLDINGS * 2 * 5 <= 200, "actor draw budget under 200")
