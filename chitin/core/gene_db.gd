class_name GeneDB
extends RefCounted
## Every heritable organ in the game. A gene lives in one body slot, has a
## dominance score (decides which allele of a pair is expressed), additive stat
## modifiers, and optionally grants an active ability.

enum Slot { HEAD, THORAX, ABDOMEN, LIMBS, WINGS, SKIN }
const SLOT_NAMES := ["Head", "Thorax", "Abdomen", "Limbs", "Wings", "Skin"]
const BASE_STATS := {"hp": 60.0, "speed": 5.0, "armor": 0.0, "damage": 8.0,
	"sense": 12.0, "scent": 1.0, "stamina": 100.0, "stealth": 0.0, "regen": 0.0}

# rarity 0 = baseline larval organ (always available), 1 common .. 4 mythic
const GENES := {
	# --- baselines (every slot always has one) ---
	"larval_head": {"name": "Larval Head", "slot": 0, "dom": 0.10, "rarity": 0, "mods": {}, "color": Color(0.55, 0.5, 0.4)},
	"larval_thorax": {"name": "Soft Thorax", "slot": 1, "dom": 0.10, "rarity": 0, "mods": {}, "color": Color(0.5, 0.45, 0.38)},
	"larval_abdomen": {"name": "Pale Abdomen", "slot": 2, "dom": 0.10, "rarity": 0, "mods": {}, "color": Color(0.6, 0.55, 0.45)},
	"larval_limbs": {"name": "Grub Legs", "slot": 3, "dom": 0.10, "rarity": 0, "mods": {}, "color": Color(0.5, 0.42, 0.35)},
	"larval_wings": {"name": "Wing Buds", "slot": 4, "dom": 0.10, "rarity": 0, "mods": {}, "color": Color(0.7, 0.7, 0.6)},
	"larval_skin": {"name": "Bare Cuticle", "slot": 5, "dom": 0.10, "rarity": 0, "mods": {}, "color": Color(0.55, 0.5, 0.42)},
	# --- head ---
	"mandible_shear": {"name": "Mandible Shear", "slot": 0, "dom": 0.60, "rarity": 1, "mods": {"damage": 6.0}, "color": Color(0.35, 0.18, 0.1), "desc": "Serrated jaws. +Damage."},
	"acid_spitter": {"name": "Acid Spitter", "slot": 0, "dom": 0.50, "rarity": 2, "mods": {"damage": 2.0}, "ability": "acid_spit", "color": Color(0.45, 0.6, 0.12), "desc": "Ranged corrosive glob."},
	"compound_eyes": {"name": "Compound Eyes", "slot": 0, "dom": 0.45, "rarity": 1, "mods": {"sense": 8.0}, "color": Color(0.12, 0.3, 0.35), "desc": "Wide sight; reveals creature scent wants from afar."},
	"antennae_array": {"name": "Antennae Array", "slot": 0, "dom": 0.55, "rarity": 2, "mods": {"scent": 0.6, "sense": 3.0}, "color": Color(0.5, 0.3, 0.55), "desc": "Reads and writes chemical speech more precisely."},
	"pheromone_gland": {"name": "Pheromone Gland", "slot": 0, "dom": 0.50, "rarity": 3, "mods": {"scent": 1.0}, "ability": "scent_burst", "color": Color(0.75, 0.25, 0.6), "desc": "Blast your chord across a wide radius."},
	# --- thorax ---
	"hardened_thorax": {"name": "Hardened Thorax", "slot": 1, "dom": 0.60, "rarity": 1, "mods": {"hp": 30.0, "armor": 2.0}, "color": Color(0.25, 0.2, 0.15)},
	"muscle_cords": {"name": "Muscle Cords", "slot": 1, "dom": 0.50, "rarity": 1, "mods": {"speed": 1.0, "damage": 3.0}, "color": Color(0.5, 0.2, 0.18)},
	"regen_ganglia": {"name": "Regen Ganglia", "slot": 1, "dom": 0.40, "rarity": 2, "mods": {"hp": 10.0}, "ability": "regen_pulse", "color": Color(0.2, 0.55, 0.35), "desc": "Pulse that mends flesh."},
	"second_heart": {"name": "Second Heart", "slot": 1, "dom": 0.45, "rarity": 3, "mods": {"stamina": 40.0, "hp": 15.0}, "color": Color(0.7, 0.1, 0.15)},
	# --- abdomen ---
	"venom_stinger": {"name": "Venom Stinger", "slot": 2, "dom": 0.55, "rarity": 2, "mods": {"damage": 4.0}, "ability": "sting_lunge", "color": Color(0.7, 0.55, 0.1), "desc": "Lunging strike."},
	"bombardier_sac": {"name": "Bombardier Sac", "slot": 2, "dom": 0.50, "rarity": 3, "mods": {}, "ability": "bombard", "color": Color(0.85, 0.35, 0.1), "desc": "Boiling chemical blast around you."},
	"silk_spinneret": {"name": "Silk Spinneret", "slot": 2, "dom": 0.45, "rarity": 2, "mods": {}, "ability": "web_snare", "color": Color(0.85, 0.85, 0.8), "desc": "Lay a snare that roots enemies."},
	"biolume_organ": {"name": "Biolume Organ", "slot": 2, "dom": 0.40, "rarity": 2, "mods": {"sense": 2.0}, "ability": "glow_lure", "color": Color(0.3, 0.9, 0.85), "desc": "Glowing lure draws prey."},
	"royal_jelly_gland": {"name": "Royal Jelly Gland", "slot": 2, "dom": 0.35, "rarity": 3, "mods": {"hp": 20.0, "scent": 0.4}, "color": Color(0.95, 0.8, 0.3)},
	# --- limbs ---
	"raptorial_forelimbs": {"name": "Raptorial Forelimbs", "slot": 3, "dom": 0.60, "rarity": 2, "mods": {"damage": 7.0}, "color": Color(0.3, 0.45, 0.2)},
	"saltatorial_legs": {"name": "Saltatorial Legs", "slot": 3, "dom": 0.50, "rarity": 1, "mods": {"speed": 1.8}, "color": Color(0.4, 0.5, 0.15)},
	"burrow_claws": {"name": "Burrow Claws", "slot": 3, "dom": 0.45, "rarity": 1, "mods": {"armor": 1.0, "damage": 2.0, "hp": 10.0}, "color": Color(0.3, 0.25, 0.2)},
	"tarsal_pads": {"name": "Tarsal Pads", "slot": 3, "dom": 0.35, "rarity": 1, "mods": {"speed": 0.8, "stamina": 10.0}, "color": Color(0.45, 0.4, 0.3)},
	# --- wings ---
	"elytra_shield": {"name": "Elytra Shield", "slot": 4, "dom": 0.55, "rarity": 2, "mods": {"armor": 3.0}, "ability": "carapace", "color": Color(0.1, 0.25, 0.5), "desc": "Raise wing-cases: brief damage immunity."},
	"gossamer_wings": {"name": "Gossamer Wings", "slot": 4, "dom": 0.50, "rarity": 2, "mods": {"speed": 1.0}, "ability": "wing_dash", "color": Color(0.8, 0.9, 1.0), "desc": "Burst dash, untouchable mid-flight."},
	"vestigial_stubs": {"name": "Vestigial Stubs", "slot": 4, "dom": 0.20, "rarity": 1, "mods": {"hp": 8.0}, "color": Color(0.5, 0.5, 0.4)},
	# --- skin ---
	"chitin_plate": {"name": "Chitin Plate", "slot": 5, "dom": 0.60, "rarity": 1, "mods": {"armor": 2.0, "hp": 10.0}, "color": Color(0.2, 0.17, 0.12)},
	"mimic_pattern": {"name": "Mimic Pattern", "slot": 5, "dom": 0.45, "rarity": 2, "mods": {"scent": 0.3, "stealth": 0.35}, "color": Color(0.3, 0.4, 0.25), "desc": "Creatures notice you from much less far."},
	"spore_coat": {"name": "Spore Coat", "slot": 5, "dom": 0.40, "rarity": 3, "mods": {"regen": 1.2}, "color": Color(0.55, 0.7, 0.4), "desc": "Symbiotic fungus knits wounds over time."},
}

const ABILITY_INFO := {
	"acid_spit": {"name": "Spit", "cd": 2.5, "cost": 12.0},
	"scent_burst": {"name": "Burst", "cd": 6.0, "cost": 20.0},
	"regen_pulse": {"name": "Mend", "cd": 10.0, "cost": 25.0},
	"sting_lunge": {"name": "Lunge", "cd": 4.0, "cost": 18.0},
	"bombard": {"name": "Bombard", "cd": 8.0, "cost": 30.0},
	"web_snare": {"name": "Snare", "cd": 7.0, "cost": 15.0},
	"glow_lure": {"name": "Lure", "cd": 12.0, "cost": 15.0},
	"carapace": {"name": "Carapace", "cd": 9.0, "cost": 25.0},
	"wing_dash": {"name": "Dash", "cd": 3.5, "cost": 20.0},
}

static func baseline(slot: int) -> String:
	return ["larval_head", "larval_thorax", "larval_abdomen", "larval_limbs", "larval_wings", "larval_skin"][slot]

static func get_gene(id: String) -> Dictionary:
	return GENES.get(id, {})

static func genes_for_slot(slot: int, min_rarity: int = 1) -> Array:
	var out: Array = []
	for id in GENES:
		var g: Dictionary = GENES[id]
		if g.slot == slot and g.rarity >= min_rarity:
			out.append(id)
	out.sort()
	return out

static func all_ids() -> Array:
	var a: Array = GENES.keys()
	a.sort()
	return a
