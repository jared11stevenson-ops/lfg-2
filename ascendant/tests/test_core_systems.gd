extends "res://tests/test_case.gd"
## Genetics, determinism, invention and item-history invariants.

func _rng(s: int) -> RandomNumberGenerator:
	var r := RandomNumberGenerator.new(); r.seed = s; return r

func test_genome_constraints() -> void:
	var r := _rng(1)
	for bp in 7:
		var g := Genome.random_for(bp, r)
		check(g.size() == Genome.N, "genome length")
		for v in g: check(v >= 0.0 and v <= 1.0, "gene in range")
	var avian := Genome.random_for(Genome.BP.AVIAN, r); check(Genome.get_g(avian, "wing") >= 0.35, "birds always winged")
	var q := Genome.random_for(Genome.BP.QUAD, r); assert_eq(Genome.get_g(q, "wing"), 0.0, "quadrupeds cannot grow wings")
	var f := Genome.random_for(Genome.BP.FISH, r); assert_eq(Genome.get_g(f, "aqua"), 1.0, "fish are fully aquatic")

func test_inheritance_keeps_ancestry() -> void:
	var r := _rng(2)
	var a := Archetypes.make_genome(Archetypes.by_id("stoat"), r)
	var child := Genome.mutate(a, 0, r)
	var stranger := Archetypes.make_genome(Archetypes.by_id("hare"), r)
	check(Genome.distance(a, child) < Genome.distance(a, stranger), "child closer to parent than to another species")
	var line := a
	for i in 30: line = Genome.mutate(line, 0, r)
	check(Genome.distance(a, line) > Genome.distance(a, child), "divergence accumulates over generations")

func test_phenotype_valid_for_all_archetypes() -> void:
	var r := _rng(3)
	for a in Archetypes.LIST:
		for k in 20:
			var ph := Phenotype.build(Archetypes.make_genome(a, r, 0.1), a["bp"])
			var errs := Phenotype.validate(ph)
			check(errs.is_empty(), "%s invalid body: %s" % [a["id"], str(errs)])

func test_sim_is_deterministic() -> void:
	var a := EcoSim.new(); a.generate(11)
	var b := EcoSim.new(); b.generate(11)
	for i in 30: a.step(); b.step()
	assert_eq(a.species.size(), b.species.size(), "same seed -> same species count")
	assert_near(a.totals().values().reduce(func(x, y): return x + y, 0.0), b.totals().values().reduce(func(x, y): return x + y, 0.0), 0.01, "same totals")

func test_sim_keeps_life_alive() -> void:
	var s := EcoSim.new(); s.generate(5)
	for i in 80: s.step()
	check(s.totals().size() >= 8, "ecosystem still has diverse life after 20 years")

func test_invention_is_property_based() -> void:
	var g := Genome.blank(); Genome.set_g(g, "c_manip", 0.8); Genome.set_g(g, "c_plan", 0.6)
	var spear := Invention.evaluate("pierce", {"point": "flint", "shaft": "wood"}, g)
	check(spear["ok"], "flint-tipped wood spear works")
	var bad := Invention.evaluate("pierce", {"point": "mud", "shaft": "clay"}, g)
	check(not bad["ok"], "mud-tipped clay spear fails")
	var weak := Genome.blank(); Genome.set_g(weak, "c_manip", 0.05)
	check(not Invention.evaluate("pierce", {"point": "flint", "shaft": "wood"}, weak)["ok"], "body without dexterity cannot make a spear")
	check(Invention.evaluate("bind", {"strand": "silk"}, g)["score"] > Invention.evaluate("bind", {"strand": "clay"}, g)["score"], "silk is better cordage than clay")
	var pool := ["flint", "wood", "mud", "fiber"]
	var bd := Invention.best_design("cut", pool, g)
	assert_eq(bd["edge"], "flint", "best edge is flint")

func test_silk_only_for_secretors() -> void:
	var no := Materials.available(0.3, 0.3, 0.4, 0.5, 0.1, false)
	var yes := Materials.available(0.3, 0.3, 0.4, 0.5, 0.9, false)
	check(not no.has("silk") and yes.has("silk"), "silk requires a secreting body")

func test_item_legend_is_earned() -> void:
	var it := Item.create("pierce", {"point": "flint", "shaft": "wood"}, 0.6, "Vex", 1, "Marsh Frog")
	assert_eq(it.legend_tier(), 0, "new item is plain")
	for i in 12: it.record_kill("Stoat", 10 + i)
	check(it.legend_tier() >= 2, "kills raise legend")
	check(it.epithet != "", "epithet earned")
	it.transfer("Heir Wren", "inherited", 100)
	check(it.owners.size() == 2, "owner chain kept")
	var back := Item.from_dict(it.to_dict())
	assert_eq(back.kills, it.kills, "round-trips through save")
	check(back.history.size() == it.history.size(), "history survives save")
