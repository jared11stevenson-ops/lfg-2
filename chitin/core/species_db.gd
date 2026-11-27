class_name SpeciesDB
extends RefCounted
## The Wild. Roles: prey (flees/grazes), pack (swarms), ambush, hunter, drone, regent.
## "want" is the secret scent chord (Fear, Kin, Hunger, Regent) each species answers to.

const SPECIES := {
	"mold_grub": {"name": "Mold Grub", "hp": 18.0, "speed": 2.2, "damage": 3.0, "sense": 7.0, "scale": 0.6,
		"role": "prey", "color": Color(0.7, 0.75, 0.5), "bile": 4, "recruitable": true, "fearable": true,
		"want": Vector4(0.05, 0.75, 0.2, 0.1), "genes": ["larval_limbs", "tarsal_pads", "vestigial_stubs", "chitin_plate"],
		"r": 0.35, "k": 60.0, "eats": []},
	"rust_beetle": {"name": "Rust Beetle", "hp": 55.0, "speed": 2.6, "damage": 7.0, "sense": 8.0, "scale": 1.0,
		"role": "prey", "color": Color(0.55, 0.3, 0.15), "bile": 9, "recruitable": true, "fearable": false,
		"want": Vector4(0.1, 0.5, 0.65, 0.35), "genes": ["hardened_thorax", "chitin_plate", "burrow_claws", "elytra_shield"],
		"r": 0.18, "k": 28.0, "eats": ["mold_grub"]},
	"ash_moth": {"name": "Ash Moth", "hp": 22.0, "speed": 4.5, "damage": 4.0, "sense": 12.0, "scale": 0.7,
		"role": "prey", "color": Color(0.7, 0.68, 0.72), "bile": 7, "recruitable": true, "fearable": true,
		"want": Vector4(0.2, 0.3, 0.1, 0.8), "genes": ["gossamer_wings", "compound_eyes", "mimic_pattern", "biolume_organ"],
		"r": 0.25, "k": 24.0, "eats": []},
	"gutter_roach": {"name": "Gutter Roach", "hp": 30.0, "speed": 5.2, "damage": 6.0, "sense": 10.0, "scale": 0.8,
		"role": "pack", "color": Color(0.3, 0.18, 0.1), "bile": 6, "recruitable": true, "fearable": true,
		"want": Vector4(0.45, 0.2, 0.8, 0.2), "genes": ["saltatorial_legs", "muscle_cords", "tarsal_pads", "spore_coat"],
		"r": 0.3, "k": 40.0, "eats": ["mold_grub"]},
	"web_widow": {"name": "Web Widow", "hp": 70.0, "speed": 3.8, "damage": 14.0, "sense": 11.0, "scale": 1.2,
		"role": "ambush", "color": Color(0.1, 0.05, 0.12), "bile": 16, "recruitable": false, "fearable": false,
		"want": Vector4(0.0, 0.1, 0.9, 0.7), "genes": ["silk_spinneret", "venom_stinger", "raptorial_forelimbs", "acid_spitter"],
		"r": 0.1, "k": 8.0, "eats": ["gutter_roach", "ash_moth", "rust_beetle"]},
	"razor_mantis": {"name": "Razor Mantis", "hp": 90.0, "speed": 4.4, "damage": 18.0, "sense": 14.0, "scale": 1.4,
		"role": "hunter", "color": Color(0.25, 0.5, 0.2), "bile": 22, "recruitable": false, "fearable": true,
		"want": Vector4(0.0, 0.0, 0.55, 0.9), "genes": ["raptorial_forelimbs", "mandible_shear", "compound_eyes", "muscle_cords"],
		"r": 0.08, "k": 6.0, "eats": ["gutter_roach", "ash_moth", "rust_beetle"]},
	"hive_drone": {"name": "Hive Drone", "hp": 45.0, "speed": 4.0, "damage": 9.0, "sense": 13.0, "scale": 1.0,
		"role": "drone", "color": Color(0.8, 0.55, 0.15), "bile": 12, "recruitable": true, "fearable": true,
		"want": Vector4(0.1, 0.85, 0.3, 0.95), "genes": ["royal_jelly_gland", "pheromone_gland", "antennae_array", "venom_stinger"],
		"r": 0.12, "k": 14.0, "eats": []},
	"cathedral_regent": {"name": "Cathedral Regent", "hp": 520.0, "speed": 3.4, "damage": 32.0, "sense": 20.0, "scale": 3.0,
		"role": "regent", "color": Color(0.55, 0.1, 0.25), "bile": 120, "recruitable": true, "fearable": false, "elite": true,
		"want": Vector4(0.0, 0.9, 0.0, 1.0), "genes": ["second_heart", "pheromone_gland", "elytra_shield", "royal_jelly_gland"],
		"r": 0.0, "k": 1.0, "eats": []},
}

static func get_species(id: String) -> Dictionary:
	return SPECIES.get(id, {})

static func ids() -> Array:
	var a: Array = SPECIES.keys()
	a.sort()
	return a

## Drop table: a gene from the species pool, rarer genes with lower weight.
static func roll_gene(species_id: String, rng: RandomNumberGenerator) -> String:
	var pool: Array = SPECIES[species_id].genes
	var total := 0.0
	var weights: Array = []
	for id in pool:
		var w := 1.0 / (1.0 + float(GeneDB.get_gene(id).get("rarity", 1)))
		weights.append(w)
		total += w
	var r := rng.randf() * total
	for i in pool.size():
		r -= weights[i]
		if r <= 0.0:
			return pool[i]
	return pool[pool.size() - 1]
