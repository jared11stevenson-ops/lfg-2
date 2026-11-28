extends "res://tests/test_case.gd"
## Non-aquatic bloodlines must begin on dry land, across many worlds.
func test_player_spawns_on_land() -> void:
	for seed_ in [3, 5, 9, 14, 21, 33]:
		for arch in ["vole", "rook", "frog"]:
			var ps := PlayScene.new(); ps.autoplay_input = false
			tree_root.add_child(ps); ps.start_new(seed_, arch, 12)
			var p := ps.player
			if p.bp != Genome.BP.FISH and not p.ph["swims"]:
				check(not ps.world.is_water(p.position), "seed %d %s spawned in water" % [seed_, arch])
			else: check(true)
			ps.queue_free()
