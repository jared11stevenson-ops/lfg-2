class_name Archetypes
extends RefCounted
## Founding wildlife. These are only the *starting* gene pools: nothing here is guaranteed to
## become intelligent, survive, or keep its niche. `role` is just ecology bootstrapping.

const LIST := [
	{"id": "vole", "name": "Meadow Vole", "bp": 0, "g": {"size": 0.2, "elong": 0.4, "girth": 0.6, "limb": 0.25, "snout": 0.4, "tail": 0.2, "ear": 0.3, "fertility": 0.95, "carniv": 0.05, "social": 0.4, "burrow": 0.55, "hue": 0.09, "sat": 0.3, "val": 0.4, "pat": 0.0, "fur": 0.8, "smell": 0.6, "speed": 0.45}},
	{"id": "hare", "name": "Dune Hare", "bp": 0, "g": {"size": 0.55, "elong": 0.5, "girth": 0.5, "limb": 0.85, "snout": 0.3, "tail": 0.1, "ear": 0.95, "fertility": 0.7, "carniv": 0.0, "social": 0.25, "speed": 0.9, "vision": 0.8, "hearing": 0.8, "hue": 0.1, "sat": 0.35, "val": 0.6, "pat": 0.5, "fur": 0.7}},
	{"id": "reedgnaw", "name": "Reed-Gnawer", "bp": 0, "g": {"size": 0.55, "elong": 0.45, "girth": 0.8, "limb": 0.3, "snout": 0.25, "tail": 0.55, "ear": 0.15, "fertility": 0.5, "carniv": 0.0, "social": 0.7, "aqua": 0.8, "strength": 0.75, "hue": 0.07, "sat": 0.5, "val": 0.35, "fur": 0.85, "c_manip": 0.35, "c_spatial": 0.35}},
	{"id": "mole", "name": "Velvet Mole", "bp": 0, "g": {"size": 0.3, "elong": 0.6, "girth": 0.75, "limb": 0.15, "snout": 0.8, "tail": 0.05, "ear": 0.0, "burrow": 1.0, "vision": 0.05, "smell": 0.8, "vibe": 0.85, "carniv": 0.55, "strength": 0.7, "hue": 0.62, "sat": 0.2, "val": 0.18, "fur": 0.95, "social": 0.2}},
	{"id": "squirrel", "name": "Canopy Squirrel", "bp": 0, "g": {"size": 0.35, "elong": 0.45, "girth": 0.4, "limb": 0.6, "snout": 0.2, "tail": 0.95, "ear": 0.5, "climb": 0.95, "vision": 0.75, "carniv": 0.1, "c_curio": 0.4, "c_spatial": 0.4, "c_manip": 0.4, "hue": 0.04, "sat": 0.7, "val": 0.55, "fur": 0.9}},
	{"id": "stoat", "name": "Ember Stoat", "bp": 0, "g": {"size": 0.4, "elong": 0.95, "girth": 0.3, "limb": 0.3, "snout": 0.5, "tail": 0.45, "ear": 0.3, "carniv": 0.95, "aggr": 0.85, "speed": 0.85, "smell": 0.8, "strength": 0.6, "hue": 0.07, "sat": 0.8, "val": 0.5, "pat": 0.75, "acc_hue": 0.0, "fur": 0.6}},
	{"id": "frog", "name": "Marsh Frog", "bp": 1, "g": {"size": 0.4, "girth": 0.7, "limb": 0.8, "head": 0.7, "aqua": 0.7, "carniv": 0.8, "fertility": 0.95, "hue": 0.3, "sat": 0.7, "val": 0.5, "pat": 0.5, "pat_i": 0.7, "vision": 0.85, "toxin": 0.35}},
	{"id": "toad", "name": "Ash Toad", "bp": 1, "g": {"size": 0.5, "girth": 0.9, "limb": 0.4, "head": 0.6, "aqua": 0.25, "carniv": 0.7, "toxin": 0.8, "armor": 0.3, "hue": 0.09, "sat": 0.3, "val": 0.3, "pat": 0.5, "pat_i": 0.9, "burrow": 0.4}},
	{"id": "weaver", "name": "Dew Weaver", "bp": 2, "g": {"size": 0.45, "girth": 0.5, "limb": 0.8, "carniv": 1.0, "secrete": 1.0, "vibe": 0.95, "vision": 0.3, "c_spatial": 0.45, "c_plan": 0.35, "toxin": 0.5, "social": 0.1, "aggr": 0.5, "hue": 0.78, "sat": 0.45, "val": 0.28, "pat": 0.75, "acc_hue": 0.2, "climb": 0.9}},
	{"id": "ant", "name": "Quarry Ant", "bp": 3, "g": {"size": 0.3, "girth": 0.3, "limb": 0.55, "carniv": 0.5, "social": 1.0, "c_coop": 0.55, "c_comm": 0.5, "smell": 0.9, "aggr": 0.7, "fertility": 1.0, "secrete": 0.5, "strength": 0.8, "burrow": 0.8, "hue": 0.03, "sat": 0.8, "val": 0.3, "wing": 0.0, "armor": 0.35}},
	{"id": "rook", "name": "Ash Rook", "bp": 4, "g": {"size": 0.45, "girth": 0.45, "wing": 0.65, "snout": 0.5, "tail": 0.4, "carniv": 0.4, "social": 0.85, "c_curio": 0.6, "c_memory": 0.55, "c_comm": 0.5, "c_manip": 0.4, "c_plan": 0.4, "c_learn": 0.55, "vision": 0.9, "hue": 0.65, "sat": 0.15, "val": 0.12, "acc_hue": 0.0, "climb": 0.5, "fertility": 0.4}},
	{"id": "kestrel", "name": "Sun Kestrel", "bp": 4, "g": {"size": 0.5, "wing": 0.8, "snout": 0.7, "tail": 0.6, "carniv": 1.0, "aggr": 0.9, "vision": 1.0, "speed": 0.9, "social": 0.1, "hue": 0.07, "sat": 0.75, "val": 0.55, "pat": 0.5, "acc_hue": 0.0, "fertility": 0.25}},
	{"id": "skink", "name": "Salt Skink", "bp": 5, "g": {"size": 0.35, "elong": 0.8, "limb": 0.35, "tail": 0.9, "carniv": 0.7, "speed": 0.7, "heat": 0.9, "cold": 0.1, "hue": 0.14, "sat": 0.7, "val": 0.6, "pat": 0.25, "camo": 0.7, "fertility": 0.6}},
	{"id": "minnow", "name": "Glass Minnow", "bp": 6, "g": {"size": 0.15, "social": 0.9, "carniv": 0.3, "speed": 0.7, "fertility": 1.0, "hue": 0.52, "sat": 0.5, "val": 0.7, "pat": 0.25, "camo": 0.5}},
	{"id": "pike", "name": "Moss Pike", "bp": 6, "g": {"size": 0.7, "elong": 0.9, "carniv": 1.0, "aggr": 0.9, "speed": 0.8, "strength": 0.7, "hue": 0.28, "sat": 0.55, "val": 0.4, "pat": 0.5, "camo": 0.8, "fertility": 0.5}},
]

static func by_id(id: String) -> Dictionary:
	for a in LIST:
		if a["id"] == id: return a
	return {}

static func make_genome(a: Dictionary, rng: RandomNumberGenerator, jitter: float = 0.04) -> PackedFloat32Array:
	var g := Genome.random_for(a["bp"], rng, a["g"])
	for i in Genome.N:
		g[i] = clampf(g[i] + rng.randfn(0.0, jitter), 0.0, 1.0)
	# re-apply template (random_for jitters everything, restore intent with small noise)
	for k in a["g"]:
		Genome.set_g(g, k, float(a["g"][k]) + rng.randfn(0.0, jitter))
	Genome.constrain(g, a["bp"])
	return g
