class_name Pupation
extends RefCounted
## The rebuild. After a molt you choose, per slot, which two alleles your next
## body inherits from: your own pair, genes you ate this life (latent), and an
## optional Echo mate. Stress then rolls mutations; Bile buys rerolls/locks.

static func options_for(slot: int, genome: Genome, latent: Array, mate: Genome = null) -> Array:
	var opts: Array = []
	for a in genome.alleles[slot]:
		opts.append({"id": a.id, "mut": a.mut, "src": "self"})
	for a in latent:
		if GeneDB.get_gene(a.id).get("slot", -1) == slot:
			opts.append({"id": a.id, "mut": a.mut, "src": "eaten"})
	if mate != null:
		for a in mate.alleles[slot]:
			opts.append({"id": a.id, "mut": a.mut, "src": "echo"})
	# de-duplicate identical id+mut+src combos but keep distinct sources
	var seen := {}
	var out: Array = []
	for o in opts:
		var key := "%s|%d|%s" % [o.id, o.mut, o.src]
		if not seen.has(key):
			seen[key] = true
			out.append(o)
	return out

## Best-by-dominance default picks (what the UI preselects).
static func auto_picks(genome: Genome, latent: Array, mate: Genome = null) -> Dictionary:
	var picks := {}
	for s in 6:
		var opts := options_for(s, genome, latent, mate)
		opts.sort_custom(func(a, b): return Genome.effective_dom(a) > Genome.effective_dom(b))
		var first: Dictionary = opts[0]
		var second: Dictionary = opts[1] if opts.size() > 1 else opts[0]
		picks[s] = [first, second]
	return picks

static func mutation_rate(stress: float) -> float:
	return clampf(0.06 + 0.30 * clampf(stress, 0.0, 1.0), 0.0, 0.5)

## picks: slot -> [optA, optB]. locked: slots that skip mutation (cost Bile each).
static func finalize(picks: Dictionary, stress: float, locked: Array, rng: RandomNumberGenerator) -> Genome:
	var g := Genome.new()
	var rate := mutation_rate(stress)
	for s in 6:
		var pair: Array = []
		for opt in picks[s]:
			var al := Genome.make_allele(opt.id, int(opt.mut))
			if not locked.has(s) and rng.randf() < rate:
				al = Genome.mutate_allele(s, al, rng)
			pair.append(al)
		g.alleles[s] = pair
	return g

const LOCK_COST := 25
