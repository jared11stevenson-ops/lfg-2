class_name Echo
extends RefCounted
## When an instar ends, that body does not vanish. It becomes an Echo: a
## creature in the world carrying your old genome and the personality your
## play style stamped into it. Echoes are what your past choices LOOK like.
##
##  kinship > aggression  -> a Kin-Echo: escorts you, shares genes, defends nests
##  otherwise             -> a Revenant: hunts you, drops its (rarer) genes

const SYLL_A := ["Vor", "Ska", "Mir", "Tho", "Qel", "Dra", "Nix", "Ul", "Ket", "Zar"]
const SYLL_B := ["ix", "ak", "eth", "ul", "ora", "is", "yn", "ek"]

static func make(genome: Genome, instar: int, summary: Dictionary, rng: RandomNumberGenerator) -> Dictionary:
	var kills: int = summary.get("kills", 0)
	var recruits: int = summary.get("recruits", 0)
	var calms: int = summary.get("calms", 0)
	var aggression := float(kills) / float(kills + recruits + calms + 1)
	var kinship := float(recruits * 2 + calms) / float(kills + recruits * 2 + calms + 1)
	return {
		"name": SYLL_A[rng.randi() % SYLL_A.size()] + SYLL_B[rng.randi() % SYLL_B.size()],
		"genome": genome.to_dict(),
		"instar": instar,
		"cause": String(summary.get("cause", "molted")),
		"aggression": aggression,
		"kinship": kinship,
		"scent": summary.get("scent", [0.5, 0.5, 0.5, 0.5]),
		"power": genome.power_rating(),
	}

static func disposition(e: Dictionary) -> String:
	if e.get("cause", "") == "died" and float(e.aggression) >= float(e.kinship):
		return "revenant"
	return "kin" if float(e.kinship) > float(e.aggression) else "revenant"

static func genome_of(e: Dictionary) -> Genome:
	return Genome.from_dict(e.genome)
