extends SceneTree
## Headless test runner:  godot --headless --path chitin --script tests/run_tests.gd

var passed := 0
var failed := 0

func check(cond: bool, label: String) -> void:
	if cond:
		passed += 1
	else:
		failed += 1
		print("  FAIL: ", label)

func _initialize() -> void:
	test_genes()
	test_genome()
	test_scent()
	test_ecology()
	test_echo_and_pupation()
	test_district()
	test_save_roundtrip()
	print("\n== %d passed, %d failed ==" % [passed, failed])
	quit(1 if failed > 0 else 0)

func test_genes() -> void:
	print("genes")
	for id in GeneDB.GENES:
		var g: Dictionary = GeneDB.GENES[id]
		check(g.slot >= 0 and g.slot < 6, id + " slot valid")
		check(g.dom > 0.0 and g.dom <= 1.0, id + " dom valid")
		if g.has("ability"):
			check(GeneDB.ABILITY_INFO.has(g.ability), id + " ability known")
	for s in 6:
		check(GeneDB.genes_for_slot(s).size() >= 2, "slot %d has options" % s)
	for sid in SpeciesDB.SPECIES:
		for gid in SpeciesDB.SPECIES[sid].genes:
			check(GeneDB.GENES.has(gid), "%s drops known gene %s" % [sid, gid])
		for prey in SpeciesDB.SPECIES[sid].eats:
			check(SpeciesDB.SPECIES.has(prey), "%s eats known %s" % [sid, prey])

func test_genome() -> void:
	print("genome")
	var g := Genome.new()
	check(g.stats().hp == 60.0, "baseline hp")
	g.set_pair(0, Genome.make_allele("mandible_shear"), Genome.make_allele("compound_eyes"))
	check(g.express(0).id == "mandible_shear", "higher dominance expressed")
	check(g.recessive(0).id == "compound_eyes", "other is recessive")
	check(g.stats().damage == 14.0, "mandible adds 6 dmg")
	g.set_pair(0, Genome.make_allele("mandible_shear", 2), Genome.make_allele("larval_head"))
	check(is_equal_approx(g.stats().damage, 8.0 + 6.0 * 1.7), "mutation scales mods")
	g.set_pair(4, Genome.make_allele("gossamer_wings"), Genome.make_allele("larval_wings"))
	check(g.abilities().has("wing_dash"), "wings grant ability")
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var a := Genome.new()
	var b := Genome.new()
	a.set_pair(1, Genome.make_allele("hardened_thorax"), Genome.make_allele("hardened_thorax"))
	b.set_pair(1, Genome.make_allele("muscle_cords"), Genome.make_allele("muscle_cords"))
	var c := Genome.cross(a, b, rng, 0.0)
	var ids := [c.alleles[1][0].id, c.alleles[1][1].id]
	check(ids[0] == "hardened_thorax" and ids[1] == "muscle_cords", "cross takes one allele per parent")
	var rng1 := RandomNumberGenerator.new(); rng1.seed = 99
	var rng2 := RandomNumberGenerator.new(); rng2.seed = 99
	check(Genome.cross(a, b, rng1, 0.4).equals(Genome.cross(a, b, rng2, 0.4)), "cross deterministic per seed")
	var mutated := 0
	var rng3 := RandomNumberGenerator.new(); rng3.seed = 5
	for i in 200:
		if not Genome.cross(a, b, rng3, 0.5).equals(Genome.cross(a, b, rng3, 0.0)):
			mutated += 1
	check(mutated > 100, "high mutation rate mutates often")
	check(Genome.from_dict(g.to_dict()).equals(g), "genome dict round-trip")
	var bad := Genome.from_dict({"0": [{"id": "nope", "mut": 1}, {"id": "nope", "mut": 0}]})
	check(bad.express(0).id == "larval_head", "unknown genes sanitized")

func test_scent() -> void:
	print("scent")
	var grub := SpeciesDB.get_species("mold_grub")
	var perfect: Vector4 = grub.want
	check(Scent.similarity(perfect, perfect) == 1.0, "identical chord similarity 1")
	check(Scent.similarity(Vector4(0, 0, 0, 0), Vector4(1, 1, 1, 1)) == 0.0, "opposite chord 0")
	var r := Scent.parley(grub, perfect, 1.6)
	check(r.outcome == Scent.Outcome.RECRUIT, "perfect chord recruits recruitable")
	var widow := SpeciesDB.get_species("web_widow")
	check(Scent.parley(widow, widow.want, 1.6).outcome == Scent.Outcome.CALM, "unrecruitable only calms")
	var bad := Scent.parley(grub, Vector4(0.3, 0.0, 1.0, 1.0), 1.0)
	check(bad.outcome == Scent.Outcome.ENRAGE, "wrong chord enrages")
	var fear := Scent.parley(grub, Vector4(1.0, 0.0, 0.0, 0.5), 1.0)
	check(fear.outcome == Scent.Outcome.FLEE, "pure fear makes fearable flee")
	var mantis := SpeciesDB.get_species("razor_mantis")
	check(Scent.parley(mantis, Vector4(1, 0, 0, 0.5), 1.0).outcome == Scent.Outcome.FLEE, "mantis can be scared")
	var regent := SpeciesDB.get_species("cathedral_regent")
	check(Scent.parley(regent, regent.want, 2.0).outcome == Scent.Outcome.CALM, "regent resists full recruitment")
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	var err_low := 0.0
	var err_high := 0.0
	for i in 100:
		err_low += (Scent.reveal(grub, 1.0, rng) - perfect).length()
		err_high += (Scent.reveal(grub, 2.4, rng) - perfect).length()
	check(err_high < err_low * 0.5, "more scent power reveals wants more accurately")
	for id in SpeciesDB.ids():
		var w: Vector4 = SpeciesDB.get_species(id).want
		check(w.x >= 0 and w.x <= 1 and w.w <= 1 and w.y <= 1 and w.z <= 1, id + " want in range")

func test_ecology() -> void:
	print("ecology")
	var e := Ecology.new()
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	e.step(rng, 200)
	for id in e.pops:
		var k: float = SpeciesDB.get_species(id).k
		check(e.pops[id] >= 0.5 and e.pops[id] <= k * 1.2 + 0.001, id + " population bounded")
	check(e.pops["mold_grub"] > e.pops["razor_mantis"], "prey outnumber apex")
	check(e.pops["cathedral_regent"] == 1.0, "one regent")
	var before: float = e.pops["gutter_roach"]
	for i in 30:
		e.apply_kill("gutter_roach")
	check(e.pops["gutter_roach"] < before, "overhunting depresses population")
	check(e.pops["gutter_roach"] >= 0.5, "population floor holds")
	var p := Ecology.new()
	p.deposit(0.0, 0.0, Vector4(1, 0, 0, 0), 1.0)
	var t0 := p.total_scent()
	var peak := p.sample(0.0, 0.0).x
	check(peak > 0.9, "deposit lands")
	p.decay_diffuse()
	check(p.total_scent() < t0, "scent decays")
	check(p.sample(0.0, 0.0).x < peak, "peak spreads out")
	check(p.sample(3.0, 0.0).x > 0.0 or p.sample(-3.0, 0.0).x > 0.0, "scent diffuses to neighbours")
	var r := Ecology.from_dict(e.to_dict())
	check(r.pops == e.pops, "ecology round-trip pops")
	check(r.grid.size() == e.grid.size(), "ecology round-trip grid")

func test_echo_and_pupation() -> void:
	print("echo + pupation")
	var rng := RandomNumberGenerator.new(); rng.seed = 21
	var g := Genome.new()
	g.set_pair(0, Genome.make_allele("mandible_shear"), Genome.make_allele("larval_head"))
	var killer := Echo.make(g, 3, {"kills": 20, "recruits": 0, "calms": 0, "cause": "died"}, rng)
	var pacifist := Echo.make(g, 4, {"kills": 0, "recruits": 5, "calms": 4, "cause": "molted"}, rng)
	check(Echo.disposition(killer) == "revenant", "killer returns as revenant")
	check(Echo.disposition(pacifist) == "kin", "pacifist returns as kin")
	check(Echo.genome_of(killer).equals(g), "echo preserves genome")
	var latent := [Genome.make_allele("raptorial_forelimbs"), Genome.make_allele("acid_spitter")]
	var opts := Pupation.options_for(3, g, latent, null)
	var ids := opts.map(func(o): return o.id)
	check(ids.has("raptorial_forelimbs"), "eaten gene offered for its slot")
	check(not ids.has("acid_spitter"), "gene of other slot not offered")
	var mate := Genome.new()
	mate.set_pair(3, Genome.make_allele("burrow_claws"), Genome.make_allele("burrow_claws"))
	check(Pupation.options_for(3, g, latent, mate).map(func(o): return o.id).has("burrow_claws"), "echo mate offers alleles")
	var picks := Pupation.auto_picks(g, latent, null)
	check(picks[3][0].id == "raptorial_forelimbs", "auto-pick prefers dominant eaten gene")
	check(Pupation.mutation_rate(1.0) > Pupation.mutation_rate(0.0), "stress raises mutation")
	var plain := Pupation.finalize(picks, 0.0, [0, 1, 2, 3, 4, 5], rng)
	check(plain.express(3).id == "raptorial_forelimbs", "locked slots never mutate")
	var changed := 0
	for i in 100:
		var gg := Pupation.finalize(picks, 1.0, [], rng)
		if not gg.equals(plain):
			changed += 1
	check(changed > 70, "high stress usually mutates something")

func test_district() -> void:
	print("district")
	var a := DistrictGen.generate(1234)
	var b := DistrictGen.generate(1234)
	check(a.blocks.size() == b.blocks.size() and a.spawn == b.spawn, "district deterministic")
	check(a.blocks.size() >= 20, "district has ruins")
	check(a.nests.size() == SpeciesDB.ids().size() * 2 - 1, "nests per species")
	for blk in a.blocks:
		check(blk.pos.distance_to(a.spawn) >= 9.0, "spawn clear of ruins")
	for s in [2, 3, 4, 5, 6]:
		var d := DistrictGen.generate(s)
		check(d.blocks.size() >= 15, "seed %d fills up" % s)
		for blk in d.blocks:
			check(absf(blk.pos.x) < DistrictGen.HALF and absf(blk.pos.y) < DistrictGen.HALF, "block in bounds")

func test_save_roundtrip() -> void:
	print("lineage")
	var L = root.get_node_or_null("Lineage")
	check(L != null, "Lineage autoload present")
	if L == null:
		return
	L.new_lineage(77)
	L.start_instar()
	L.run.kills = 3
	L.run.bile = 40
	L.run.time = 200.0
	L.add_latent(Genome.make_allele("acid_spitter"))
	var s: Dictionary = L.end_instar("molted")
	check(L.bile == 40, "bile banked on molt")
	check(L.echoes.size() == 1 and s.echo.instar == 1, "echo minted")
	L.start_instar()
	L.run.bile = 20
	L.end_instar("died")
	check(L.bile == 40 + 20 - 10, "death forfeits half the carried bile")
	var d: Dictionary = L.to_dict()
	var json := JSON.stringify(d)
	var back = JSON.parse_string(json)
	var before_genome: Genome = L.genome
	L.new_lineage(78)
	L.from_dict(back)
	check(L.bile == 50 and L.echoes.size() == 2, "state restored from JSON")
	check(L.genome.equals(before_genome), "genome restored from JSON")
	check(L.ecology.pops.size() == Ecology.new().pops.size(), "ecology restored")
	check(L.latent.size() == 1, "latent restored")
