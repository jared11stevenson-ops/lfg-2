class_name Genome
extends RefCounted
## Heritable genome: a fixed-length vector of loci in [0,1]. Body plan (clade) is NOT a gene:
## it is lineage-fixed developmental constraint, so descendants stay recognisably related.

enum BP { QUAD, AMPHIB, ARACH, INSECT, AVIAN, REPTILE, FISH }
const BP_NAMES := ["quadruped", "amphibian", "arachnid", "insect", "avian", "reptile", "fish"]

const NAMES: Array[String] = [
	"size", "elong", "girth", "limb", "head", "snout", "tail", "ear", "wing", "spine",
	"strength", "speed", "stamina", "metab", "lifespan", "fertility", "aggr", "social", "carniv",
	"vision", "hearing", "smell", "vibe",
	"armor", "toxin", "camo", "secrete",
	"c_spatial", "c_memory", "c_comm", "c_coop", "c_manip", "c_plan", "c_curio", "c_learn",
	"heat", "cold", "aqua", "burrow", "climb",
	"hue", "sat", "val", "pat", "pat_i", "acc_hue", "fur",
]
const N := 47
static var IDX: Dictionary = _build_idx()
static func _build_idx() -> Dictionary:
	var d := {}
	for i in NAMES.size():
		d[NAMES[i]] = i
	return d

const COG := ["c_spatial", "c_memory", "c_comm", "c_coop", "c_manip", "c_plan", "c_curio", "c_learn"]

static func get_g(g: PackedFloat32Array, name: String) -> float:
	return g[IDX[name]]

static func set_g(g: PackedFloat32Array, name: String, v: float) -> void:
	g[IDX[name]] = clampf(v, 0.0, 1.0)

static func blank() -> PackedFloat32Array:
	var g := PackedFloat32Array()
	g.resize(N)
	g.fill(0.5)
	return g

## Bauplan-specific constraints (what the developmental program forbids / forces).
const COG_CAP := [1.0, 0.65, 0.6, 0.5, 0.85, 0.7, 0.6]    # neuron budget per body plan
const MANIP_CAP := [0.9, 0.55, 0.7, 0.65, 0.75, 0.7, 0.15]   # per body plan: what the anatomy can physically handle
static func constrain(g: PackedFloat32Array, bp: int) -> void:
	set_g(g, "c_manip", minf(get_g(g, "c_manip"), MANIP_CAP[bp]))
	for cn in COG:
		set_g(g, cn, minf(get_g(g, cn), COG_CAP[bp]))
	match bp:
		BP.ARACH, BP.INSECT:
			set_g(g, "size", minf(get_g(g, "size"), 0.8))     # tracheal/book-lung scaling limit
			set_g(g, "snout", 0.1); set_g(g, "ear", 0.0)
			set_g(g, "fur", minf(get_g(g, "fur"), 0.35))
			if bp == BP.ARACH:
				set_g(g, "wing", 0.0)
		BP.QUAD, BP.REPTILE:
			set_g(g, "wing", 0.0)
			if bp == BP.REPTILE:
				set_g(g, "fur", 0.0); set_g(g, "ear", 0.0)
		BP.AMPHIB:
			set_g(g, "wing", 0.0); set_g(g, "fur", 0.0); set_g(g, "ear", 0.0)
			set_g(g, "tail", 0.0)
		BP.AVIAN:
			set_g(g, "wing", maxf(get_g(g, "wing"), 0.35)); set_g(g, "ear", 0.0)
			set_g(g, "size", minf(get_g(g, "size"), 0.85))    # flight mass limit
		BP.FISH:
			set_g(g, "wing", 0.0); set_g(g, "ear", 0.0); set_g(g, "fur", 0.0)
			set_g(g, "aqua", 1.0); set_g(g, "burrow", minf(get_g(g, "burrow"), 0.2))
			set_g(g, "climb", 0.0)

static func mutate(g: PackedFloat32Array, bp: int, rng: RandomNumberGenerator, rate: float = 0.12, sd: float = 0.06) -> PackedFloat32Array:
	var o := g.duplicate()
	for i in N:
		if rng.randf() < rate:
			o[i] = clampf(o[i] + rng.randfn(0.0, sd), 0.0, 1.0)
	constrain(o, bp)
	return o

static func cross(a: PackedFloat32Array, b: PackedFloat32Array, rng: RandomNumberGenerator) -> PackedFloat32Array:
	# Linked blocks (morphology, physiology, senses, cognition, colour) inherit together mostly.
	var o := a.duplicate()
	var blocks := [[0, 10], [10, 19], [19, 27], [27, 35], [35, 40], [40, 47]]
	for bl in blocks:
		var from_b := rng.randf() < 0.5
		for i in range(bl[0], bl[1]):
			var src: float = b[i] if from_b else a[i]
			# small within-block recombination noise
			if rng.randf() < 0.1:
				src = (a[i] + b[i]) * 0.5
			o[i] = src
	return o

static func distance(a: PackedFloat32Array, b: PackedFloat32Array) -> float:
	var s := 0.0
	for i in N:
		if i >= 40: continue   # colour drifts neutrally; not counted for speciation
		var d := a[i] - b[i]
		s += d * d
	return sqrt(s / 40.0)

static func cognition(g: PackedFloat32Array) -> Dictionary:
	var d := {}
	for n in COG:
		d[n] = get_g(g, n)
	return d

## Metabolic cost of cognition: brains are expensive (trade-off enforced in the sim).
static func brain_cost(g: PackedFloat32Array) -> float:
	var s := 0.0
	for n in COG:
		var v := get_g(g, n)
		s += v * v          # extreme specialisation is expensive: the cost is convex
	return s / COG.size() * 1.6

static func random_for(bp: int, rng: RandomNumberGenerator, template: Dictionary = {}) -> PackedFloat32Array:
	var g := blank()
	for i in N:
		g[i] = clampf(rng.randfn(0.5, 0.18), 0.02, 0.98)
	# low baseline cognition for wild animals
	for n in COG:
		set_g(g, n, clampf(rng.randfn(0.22, 0.07), 0.02, 0.5))
	for k in template:
		set_g(g, k, float(template[k]))
	constrain(g, bp)
	return g
