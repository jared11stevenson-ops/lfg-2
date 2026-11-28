class_name Phenotype
extends RefCounted
## Genome (+ bauplan) -> expressed body: shared by the renderer, combat and the simulation so that
## what you SEE is what the creature CAN DO.

const BASE_LEN := [62.0, 44.0, 34.0, 28.0, 56.0, 64.0, 58.0]  # per BP, px at size=0.5 (world scale 1px ~ 1.2cm)

static func build(g: PackedFloat32Array, bp: int) -> Dictionary:
	var G := func(n: String) -> float: return g[Genome.IDX[n]]
	var ph := {}
	ph["bp"] = bp
	var size: float = G.call("size")
	var L: float = BASE_LEN[bp] * lerpf(0.62, 1.7, size)
	var elong: float = G.call("elong")
	var girth: float = G.call("girth")
	ph["L"] = L
	ph["W"] = L * lerpf(0.13, 0.25, girth) * lerpf(1.1, 0.75, elong)
	ph["stretch"] = lerpf(0.85, 1.3, elong)
	ph["head_r"] = L * lerpf(0.09, 0.17, G.call("head"))
	ph["snout"] = lerpf(0.0, 1.0, G.call("snout"))
	ph["tail_len"] = L * lerpf(0.1, 0.85, G.call("tail"))
	ph["ear"] = lerpf(0.0, 1.0, G.call("ear"))
	ph["limb_len"] = L * lerpf(0.16, 0.42, G.call("limb"))
	ph["limb_w"] = L * lerpf(0.03, 0.06, G.call("girth") * 0.6 + G.call("strength") * 0.4)
	ph["wing"] = G.call("wing")
	ph["fur"] = G.call("fur")
	ph["aqua"] = G.call("aqua")
	ph["burrow"] = G.call("burrow")
	ph["climb"] = G.call("climb")
	ph["armor"] = G.call("armor")
	ph["toxin"] = G.call("toxin")
	ph["camo"] = G.call("camo")
	ph["secrete"] = G.call("secrete")
	ph["carniv"] = G.call("carniv")
	ph["pat"] = int(G.call("pat") * 4.999)  # 0 plain 1 stripes 2 spots 3 saddle 4 banded
	ph["pat_i"] = G.call("pat_i")
	ph["eye_size"] = lerpf(0.4, 1.0, G.call("vision")) * lerpf(1.0, 0.6, G.call("burrow"))
	ph["pal"] = Ink.palette(G.call("hue"), G.call("sat"), G.call("val"), G.call("acc_hue"), G.call("pat_i"))
	# --- Embodied capability (shared with sim/combat) ---
	var mass: float = pow(L / 40.0, 3.0) * lerpf(0.8, 1.6, girth)
	ph["mass"] = mass
	ph["speed"] = (60.0 + 140.0 * G.call("speed")) * pow(maxf(L, 10.0) / 50.0, 0.25) * (1.0 + 0.2 * G.call("limb"))
	ph["strength"] = (0.4 + 1.6 * G.call("strength")) * pow(maxf(mass, 0.05), 0.5)
	ph["hp"] = 10.0 + 40.0 * pow(maxf(mass, 0.05), 0.6) * lerpf(0.8, 1.5, G.call("stamina")) * (1.0 + G.call("armor"))
	# metabolism: bigger bodies, faster metabolism, bigger brains cost more (the evolutionary trade-offs)
	ph["upkeep"] = (0.4 + pow(maxf(mass, 0.02), 0.75)) * lerpf(0.7, 1.5, G.call("metab")) * (1.0 + 0.9 * Genome.brain_cost(g)) * (1.0 + 0.3 * G.call("armor"))
	ph["lifespan"] = lerpf(0.6, 1.6, G.call("lifespan")) * (1.0 + 0.4 * (1.0 - G.call("metab")))
	ph["bite"] = (0.5 + 1.5 * G.call("strength")) * (0.6 + 0.5 * ph["head_r"] / 8.0) * (1.0 + G.call("aggr") * 0.4)
	ph["flies"] = bp == Genome.BP.AVIAN or (bp == Genome.BP.INSECT and G.call("wing") > 0.5)
	ph["swims"] = bp == Genome.BP.FISH or G.call("aqua") > 0.55
	ph["digs"] = G.call("burrow") > 0.55
	ph["climbs"] = G.call("climb") > 0.55
	ph["dex"] = G.call("c_manip") * lerpf(0.5, 1.0, G.call("limb"))
	ph["sight"] = lerpf(60.0, 420.0, G.call("vision")) * (1.15 if bp == Genome.BP.AVIAN else 1.0)
	ph["hear"] = lerpf(40.0, 380.0, G.call("hearing"))
	ph["smell"] = lerpf(30.0, 360.0, G.call("smell"))
	ph["vibe"] = lerpf(0.0, 260.0, G.call("vibe")) * (1.5 if bp == Genome.BP.ARACH else 1.0)
	return ph

## Cheap deterministic structural validation used by the asset gate for runtime-generated bodies.
static func validate(ph: Dictionary) -> Array:
	var errs := []
	if ph["L"] < 10 or ph["L"] > 400: errs.append("length out of range")
	if ph["W"] > ph["L"] * 0.34: errs.append("body too wide")
	if ph["limb_len"] > ph["L"] * 0.6: errs.append("limbs too long")
	if ph["head_r"] > ph["L"] * 0.25: errs.append("head too big")
	return errs
