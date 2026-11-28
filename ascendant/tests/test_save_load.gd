extends "res://tests/test_case.gd"
## Save -> load must restore the same world, bloodline and items exactly.
func test_roundtrip() -> void:
	var root: Node = tree_root
	var a := PlayScene.new(); a.autoplay_input = false
	root.add_child(a)
	a.start_new(21, "hare", 24)
	for i in 8: a.sim.step()
	var it := Item.create("cut", {"edge": "flint", "haft": "wood"}, 0.7, "Tester", a.sim.tick, "Dune Hare")
	it.record_kill("Stoat", a.sim.tick)
	a.items.append(it)
	check(SaveGame.write("unit_test", a), "write ok")
	var d := SaveGame.read("unit_test")
	check(not d.is_empty(), "read ok")
	var b := PlayScene.new(); b.autoplay_input = false
	root.add_child(b)
	b.load_game(d)
	assert_eq(b.sim.tick, a.sim.tick, "tick")
	assert_eq(b.sim.species.size(), a.sim.species.size(), "species")
	assert_eq(b.generation, a.generation, "generation")
	check(is_instance_valid(b.player), "player restored")
	if is_instance_valid(b.player) and is_instance_valid(a.player):
		assert_eq(b.player.genome, a.player.genome, "genome exact")
		assert_eq(b.player.sp, a.player.sp, "species id")
	assert_eq(b.items.size(), 1, "item restored")
	assert_eq(b.items[0].kills, 1, "item history restored")
	# continued simulation after load is identical to uninterrupted run (determinism through save)
	for i in 5: a.sim.step(); b.sim.step()
	assert_eq(a.sim.species.size(), b.sim.species.size(), "post-load determinism: species")
	var ta := a.sim.totals(); var tb := b.sim.totals()
	assert_eq(ta.size(), tb.size(), "post-load determinism: live species")
	a.queue_free(); b.queue_free()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(SaveGame.path("unit_test")))
