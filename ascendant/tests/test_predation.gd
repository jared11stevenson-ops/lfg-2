extends "res://tests/test_case.gd"
## A hungry predator beside a stationary prey must be able to kill it (danger is real).
func test_stoat_kills_idle_vole() -> void:
	var ps := PlayScene.new(); ps.autoplay_input = false
	tree_root.add_child(ps); ps.start_new(51, "vole", 20)
	var prey := ps.player
	# clear neighbours so the outcome is attributable
	for c in ps.critters.duplicate():
		if c != prey: c.queue_free(); ps.critters.erase(c)
	var rng := RandomNumberGenerator.new(); rng.seed = 5
	var a := Archetypes.by_id("stoat")
	var g := Archetypes.make_genome(a, rng, 0.0)
	var sp := 0
	for s in ps.sim.species: if s["arch"] == "stoat": sp = s["id"]; break
	var st := ps._make_critter(g, 0, sp, prey.position + Vector2(70, 0), 0.6)
	st.energy = 0.3
	prey.move_dir = Vector2.ZERO
	var killed := false
	for i in 1200:
		ps.world.set_meta("critters", ps.critters)
		for c in ps.critters.duplicate():
			if is_instance_valid(c): c.tick(0.05)
		if prey.is_queued_for_deletion() or prey.hp <= 0.0: killed = true; break
	check(killed, "a hungry stoat kills an unmoving vole within 60s")
	ps.queue_free()
