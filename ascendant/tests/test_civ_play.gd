extends "res://tests/test_case.gd"
## Player <-> civilization gameplay on a CONSTRUCTED civ (fixture): trade for knowledge, ruin rediscovery, save of both.
func _fixture(ps: PlayScene, collapsed: bool) -> Dictionary:
	var g := ps.player.genome
	var civ := {"id": ps.sim.civs.size(), "sp": ps.player.sp, "bp": ps.player.bp, "name": "Test Hold", "home": 0, "regions": [0], "founded": 1, "collapsed": 5 if collapsed else -1,
		"caps": {}, "g": g, "know": {"bind": {"score": 0.7, "design": {"strand": "silk"}, "tick": 2, "name": "Silk cordage"}}, "structures": [], "bp_pts": 0.0, "pop": 50.0,
		"culture": {}, "rel": {}, "famine_t": 0, "leader": "Kator", "leader_born": 0, "law": "", "heirlooms": [], "state": "tribe"}
	civ["structures"].append({"kind": "shelter", "style": "warren", "tile": Vector2i(int(ps.player.position.x / 32), int(ps.player.position.y / 32)), "region": 0, "hp": 0.3, "state": "ruin" if collapsed else "alive", "built": 1, "age": 9, "civ": civ["id"], "layer": "underground"})
	ps.sim.civs.append(civ)
	return civ

func test_ruin_rediscovery() -> void:
	var ps := PlayScene.new(); ps.autoplay_input = false
	tree_root.add_child(ps); ps.start_new(31, "weaver", 10)
	_fixture(ps, true)
	var found := false
	for k in 12:
		ps.searched.clear(); ps.rng.seed = k
		ps.search_ruin(ps.player)
		if ps.items.size() > 0: found = true; break
	check(found, "searching a ruin can yield an artifact")
	if found:
		var it: Item = ps.items[0]
		check(it.history.size() >= 2 and it.owners.has("the dead of Test Hold"), "artifact carries the dead civ's history")
	ps.queue_free()

func test_trade_for_knowledge() -> void:
	var ps := PlayScene.new(); ps.autoplay_input = false
	tree_root.add_child(ps); ps.start_new(32, "weaver", 10)
	var civ := _fixture(ps, false)
	var tribe: Critter = ps._make_critter(ps.player.genome, ps.player.bp, ps.player.sp, ps.player.position, 0.5)
	tribe.civ_id = civ["id"]; tribe.position = ps.player.position + Vector2(40, 0)
	ps.player.inv.clear()
	ps.interact_civ(ps.player)
	check(not ps.known.has("bind"), "no knowledge without paying")
	ps.player.inv["silk"] = 1
	ps.interact_civ(ps.player)
	check(ps.known.has("bind"), "paying materials teaches the technique")
	check(ps.player.inv.get("silk", 0) == 0, "materials consumed")
	# attacking a civ member sours relations
	tribe.take_hit(1.0, ps.player, Vector2.ZERO)
	check(float(ps.rep.get(civ["id"], 0.0)) < 0.0, "violence costs standing")
	ps.queue_free()
