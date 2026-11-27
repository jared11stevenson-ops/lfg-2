class_name Genome
extends RefCounted
## Diploid body plan. Each of the six slots holds TWO alleles ({id, mut}).
## The allele with the higher effective dominance is expressed; the other is
## carried silently and can resurface in a descendant (your lineage's memory).

var alleles: Dictionary = {}   # slot:int -> [ {id:String, mut:int}, {id, mut} ]

func _init() -> void:
	for s in 6:
		alleles[s] = [make_allele(GeneDB.baseline(s)), make_allele(GeneDB.baseline(s))]

static func make_allele(id: String, mut: int = 0) -> Dictionary:
	return {"id": id, "mut": mut}

static func effective_dom(a: Dictionary) -> float:
	var g := GeneDB.get_gene(a.id)
	if g.is_empty():
		return 0.0
	return float(g.dom) * (1.0 + 0.2 * int(a.mut)) + 0.01 * int(g.rarity)

func express(slot: int) -> Dictionary:
	var pair: Array = alleles[slot]
	return pair[0] if effective_dom(pair[0]) >= effective_dom(pair[1]) else pair[1]

func recessive(slot: int) -> Dictionary:
	var pair: Array = alleles[slot]
	return pair[1] if effective_dom(pair[0]) >= effective_dom(pair[1]) else pair[0]

func set_pair(slot: int, a: Dictionary, b: Dictionary) -> void:
	alleles[slot] = [a.duplicate(), b.duplicate()]

func stats() -> Dictionary:
	var st: Dictionary = GeneDB.BASE_STATS.duplicate()
	for s in 6:
		var a := express(s)
		var g := GeneDB.get_gene(a.id)
		var scale := 1.0 + 0.35 * int(a.mut)
		for k in g.get("mods", {}):
			st[k] = st.get(k, 0.0) + float(g.mods[k]) * scale
	st["stealth"] = clampf(st["stealth"], 0.0, 0.8)
	return st

func abilities() -> Array:
	var out: Array = []
	for s in 6:
		var g := GeneDB.get_gene(express(s).id)
		if g.has("ability") and not out.has(g.ability):
			out.append(g.ability)
	return out

func power_rating() -> float:
	var st := stats()
	return st.hp * 0.5 + st.damage * 3.0 + st.speed * 5.0 + st.armor * 8.0 + abilities().size() * 15.0

## Mendelian-style cross: one random allele from each parent per slot, with a
## chance (raised by stress) that the inherited allele mutates.
static func cross(a: Genome, b: Genome, rng: RandomNumberGenerator, mutation_rate: float) -> Genome:
	var child := Genome.new()
	for s in 6:
		var from_a: Dictionary = a.alleles[s][rng.randi() % 2]
		var from_b: Dictionary = b.alleles[s][rng.randi() % 2]
		var pair := [from_a.duplicate(), from_b.duplicate()]
		for i in 2:
			if rng.randf() < mutation_rate:
				pair[i] = mutate_allele(s, pair[i], rng)
		child.alleles[s] = pair
	return child

static func mutate_allele(slot: int, allele: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var r := rng.randf()
	if r < 0.6 and allele.id != GeneDB.baseline(slot):
		return make_allele(allele.id, mini(int(allele.mut) + 1, 3))   # deepen the gene
	var pool := GeneDB.genes_for_slot(slot)                            # or wildly new
	return make_allele(pool[rng.randi() % pool.size()], 0)

func to_dict() -> Dictionary:
	var d := {}
	for s in 6:
		d[str(s)] = [alleles[s][0].duplicate(), alleles[s][1].duplicate()]
	return d

static func from_dict(d: Dictionary) -> Genome:
	var g := Genome.new()
	for s in 6:
		if d.has(str(s)):
			var p: Array = d[str(s)]
			var a: Dictionary = {"id": String(p[0].id), "mut": int(p[0].mut)}
			var b: Dictionary = {"id": String(p[1].id), "mut": int(p[1].mut)}
			if GeneDB.get_gene(a.id).is_empty(): a = make_allele(GeneDB.baseline(s))
			if GeneDB.get_gene(b.id).is_empty(): b = make_allele(GeneDB.baseline(s))
			g.alleles[s] = [a, b]
	return g

func equals(o: Genome) -> bool:
	return to_dict() == o.to_dict()
