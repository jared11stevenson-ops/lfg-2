class_name RData
extends RefCounted
## Static rules data for Raceborn: Ages.

const MAP_W := 28
const MAP_H := 18
const AGE_NAMES := ["Antiquity", "Exploration", "Modern"]
const AGE_TARGET := 100.0
const YIELDS := ["food", "prod", "gold", "sci", "cul"]

enum T { OCEAN, GRASS, FOREST, HILLS, MOUNTAIN }
# terrain: [name, food, prod, gold, move_cost, defense_bonus]
const TERRAIN := {
	T.OCEAN: ["Ocean", 1, 0, 2, 99, 0.0],
	T.GRASS: ["Grassland", 2, 0, 0, 1, 0.0],
	T.FOREST: ["Forest", 1, 1, 0, 2, 0.15],
	T.HILLS: ["Hills", 0, 2, 0, 2, 0.25],
	T.MOUNTAIN: ["Mountain", 0, 0, 0, 99, 0.0],
}
# resources: id -> [name, terrain, food, prod, gold, sci, cul]
const RESOURCES := {
	"wheat": ["Wheat", T.GRASS, 2, 0, 0, 0, 0],
	"stone": ["Stone", T.HILLS, 0, 2, 0, 0, 0],
	"fish": ["Fish", T.OCEAN, 2, 0, 0, 0, 0],
	"relic": ["Relic", T.GRASS, 0, 0, 0, 0, 3],
	"gems": ["Gems", T.HILLS, 0, 0, 3, 0, 0],
}

const K := "res://assets/characters/kaykit/"
const O := "res://assets/characters/outfits/"
const Q := "res://assets/characters/quaternius/"

# mods: multipliers added to the empire (food, prod, gold, sci, cul, melee, ranged, def, hp, growth, cost_units)
# age_mods: extra mods gained in Antiquity / Exploration / Modern
const RACES := [
	{"id": "elf", "name": "Elves", "color": Color("7ad98a"), "bcolor": "green",
		"blurb": "Forest-wardens. Fast growth, deadly archers, deep culture.",
		"mods": {"food": 0.10, "sci": 0.05, "ranged": 0.20}, "age_mods": [{}, {"cul": 0.10}, {"sci": 0.10}],
		"melee_unit": "Glade Guard", "ranged_unit": "Elven Ranger", "ubuilding": ["Treehouse", 4, 0, 0, 0, 2, 60],
		"model": O + "Female_Ranger.gltf", "rig": "ual", "height": 1.0, "squash": Vector3.ONE},
	{"id": "dwarf", "name": "Dwarves", "color": Color("e0a24a"), "bcolor": "yellow",
		"blurb": "Mountain-forgers. Production and sturdy defence.",
		"mods": {"prod": 0.15, "def": 0.15}, "age_mods": [{}, {"gold": 0.10}, {"prod": 0.10}],
		"melee_unit": "Hammerguard", "ranged_unit": "Crossbow Clan", "ubuilding": ["Deepforge", 0, 5, 0, 0, 0, 60],
		"model": K + "Barbarian.glb", "rig": "kaykit", "height": 0.7, "squash": Vector3(1.2, 0.82, 1.2)},
	{"id": "human", "name": "Humans", "color": Color("6aa8ff"), "bcolor": "blue",
		"blurb": "Adaptable traders. Gold, cheap settlers, steady culture.",
		"mods": {"gold": 0.15, "cul": 0.05, "settler_cost": -0.25}, "age_mods": [{}, {"gold": 0.10}, {"cul": 0.10}],
		"melee_unit": "Legionnaire", "ranged_unit": "Longbowman", "ubuilding": ["Forum", 0, 0, 4, 0, 2, 60],
		"model": K + "Knight.glb", "rig": "kaykit", "height": 0.8, "squash": Vector3.ONE},
	{"id": "lizard", "name": "Lizardfolk", "color": Color("9acd32"), "bcolor": "green",
		"blurb": "Swamp-farmers. Explosive growth and coastal food.",
		"mods": {"food": 0.20, "growth": 0.20}, "age_mods": [{}, {"prod": 0.10}, {"food": 0.10}],
		"melee_unit": "Lizard Raider", "ranged_unit": "Spear Thrower", "ubuilding": ["Hatchery", 3, 0, 0, 0, 0, 60],
		"model": K + "Rogue.glb", "rig": "kaykit", "height": 0.85, "squash": Vector3.ONE, "tint": Color(0.55, 0.95, 0.45)},
	{"id": "orc", "name": "Orcs", "color": Color("e0533d"), "bcolor": "red",
		"blurb": "Warbands. Strong melee and culture from victories.",
		"mods": {"melee": 0.25, "prod": 0.05}, "age_mods": [{}, {"melee": 0.10}, {"prod": 0.10}],
		"melee_unit": "Berserker", "ranged_unit": "Axe Thrower", "ubuilding": ["War Hall", 0, 3, 0, 0, 0, 60],
		"model": Q + "Orc_Male.glb", "rig": "ual", "height": 1.0, "squash": Vector3.ONE},
	{"id": "goblin", "name": "Goblins", "color": Color("b4d94a"), "bcolor": "yellow",
		"blurb": "Tinkerers. Cheap units, scavenged gold, relentless production.",
		"mods": {"prod": 0.10, "gold": 0.05, "unit_cost": -0.15}, "age_mods": [{}, {"prod": 0.10}, {"gold": 0.10}],
		"melee_unit": "Skirmisher", "ranged_unit": "Slinger", "ubuilding": ["Junkyard", 0, 4, 1, 0, 0, 60],
		"model": Q + "Puglin.glb", "rig": "ual", "height": 0.65, "squash": Vector3.ONE},
	{"id": "skeleton", "name": "Skeletons", "color": Color("d8d8c8"), "bcolor": "green",
		"blurb": "The Undying. No unit upkeep, slow growth, raise fallen foes.",
		"mods": {"food": -0.20, "melee": 0.10, "no_upkeep": 1.0, "raise": 0.30}, "age_mods": [{}, {"sci": 0.10}, {"melee": 0.10}],
		"melee_unit": "Bone Legion", "ranged_unit": "Bone Archer", "ubuilding": ["Crypt", 0, 0, 0, 2, 2, 60],
		"model": K + "Skeleton_Warrior.glb", "rig": "kaykit", "height": 0.8, "squash": Vector3.ONE},
	{"id": "ogre", "name": "Ogres", "color": Color("c98f6b"), "bcolor": "red",
		"blurb": "Brewers and brawlers. Huge hit points, hearty food.",
		"mods": {"hp": 0.30, "melee": 0.10, "food": 0.10}, "age_mods": [{}, {"gold": 0.10}, {"cul": 0.10}],
		"melee_unit": "Brute", "ranged_unit": "Boulder Lobber", "ubuilding": ["Brewery", 3, 0, 3, 0, 0, 60],
		"model": O + "Male_Peasant.gltf", "rig": "ual", "height": 1.4, "squash": Vector3(1.3, 1.0, 1.3), "tint": Color(1.0, 0.82, 0.6)},
	{"id": "imp", "name": "Imps", "color": Color("c14aff"), "bcolor": "red",
		"blurb": "Schemers. Gold, far sight, and plunder from every victory.",
		"mods": {"gold": 0.10, "sight": 1.0, "plunder": 1.0}, "age_mods": [{}, {"gold": 0.10}, {"sci": 0.10}],
		"melee_unit": "Imp Stabber", "ranged_unit": "Fire Imp", "ubuilding": ["Black Market", 0, 0, 5, 0, 0, 60],
		"model": Q + "Imp.glb", "rig": "ual", "height": 0.65, "squash": Vector3.ONE},
	{"id": "wizard", "name": "Wizards", "color": Color("5ad1ff"), "bcolor": "blue",
		"blurb": "Arcanists. Science and cheaper technologies.",
		"mods": {"sci": 0.20, "tech_cost": -0.10}, "age_mods": [{}, {"sci": 0.10}, {"cul": 0.10}],
		"melee_unit": "Spellblade", "ranged_unit": "Battlemage", "ubuilding": ["Arcane Tower", 0, 0, 0, 5, 0, 60],
		"model": K + "Mage.glb", "rig": "kaykit", "height": 0.85, "squash": Vector3.ONE},
]

# Leaders (chosen separately from the race, like Civilization VII)
const LEADERS := [
	{"id": "conqueror", "name": "The Conqueror", "desc": "+10% unit strength. Kills grant culture.", "mods": {"melee": 0.10, "ranged": 0.10, "kill_cul": 2.0}},
	{"id": "scholar", "name": "The Sage", "desc": "+15% science. Techs 10% cheaper.", "mods": {"sci": 0.15, "tech_cost": -0.10}},
	{"id": "merchant", "name": "The Magnate", "desc": "+15% gold. Buying is 20% cheaper.", "mods": {"gold": 0.15, "buy": -0.20}},
	{"id": "visionary", "name": "The Visionary", "desc": "+15% culture. Age progresses 10% faster.", "mods": {"cul": 0.15, "age": 0.10}},
]

# Technologies: [id, name, cost, unlocks(buildings), mods]
const TECHS := [
	[ # Antiquity
		["agri", "Agriculture", 30, ["granary"], {"food": 0.05}],
		["bronze", "Bronze Working", 40, ["workshop"], {"prod": 0.05}],
		["writing", "Writing", 45, ["library"], {"sci": 0.05}],
		["currency", "Currency", 55, ["market"], {"gold": 0.05}],
		["masonry", "Masonry", 60, ["walls"], {"def": 0.10}],
		["math", "Mathematics", 80, [], {"sci": 0.10, "ranged": 0.10}],
	],
	[ # Exploration
		["feud", "Feudalism", 90, [], {"melee": 0.15, "prod": 0.05}],
		["bank", "Banking", 100, [], {"gold": 0.12}],
		["print", "Printing", 110, [], {"sci": 0.12}],
		["astro", "Astronomy", 130, [], {"sci": 0.08, "food": 0.05}],
		["engine", "Engineering", 150, [], {"prod": 0.12, "def": 0.10}],
		["gunpow", "Gunpowder", 170, [], {"ranged": 0.15, "melee": 0.10}],
	],
	[ # Modern
		["indus", "Industrialization", 190, [], {"prod": 0.15}],
		["elec", "Electricity", 210, [], {"sci": 0.15}],
		["rifle", "Rifling", 230, [], {"melee": 0.20, "ranged": 0.15}],
		["steel", "Steel", 250, [], {"def": 0.20}],
		["econ", "Economics", 270, [], {"gold": 0.20}],
		["flight", "Flight", 300, [], {"sci": 0.15, "cul": 0.10}],
	],
]
# Civics (spend culture): [id, name, cost, mods]
const CIVICS := [
	[
		["tribal", "Tribal Customs", 25, {"food": 0.05}],
		["laws", "Code of Laws", 35, {"gold": 0.05}],
		["myst", "Mysticism", 45, {"cul": 0.08}],
		["martial", "Martial Tradition", 55, {"melee": 0.10}],
		["trade", "Trade Routes", 70, {"gold": 0.08}],
		["festival", "Festivals", 85, {"cul": 0.10}],
	],
	[
		["chiv", "Chivalry", 100, {"melee": 0.10}],
		["guild", "Guilds", 110, {"prod": 0.08}],
		["human", "Humanism", 125, {"cul": 0.10}],
		["merc", "Mercantilism", 140, {"gold": 0.10}],
		["divine", "Divine Right", 160, {"def": 0.10, "cul": 0.05}],
		["explore", "Exploration", 180, {"food": 0.08}],
	],
	[
		["nation", "Nationalism", 200, {"melee": 0.10, "ranged": 0.10}],
		["capital", "Capitalism", 220, {"gold": 0.12}],
		["mass", "Mass Media", 240, {"cul": 0.15}],
		["welfare", "Welfare", 260, {"food": 0.10}],
		["total", "Total War", 280, {"prod": 0.10, "melee": 0.10}],
		["global", "Globalism", 310, {"gold": 0.08, "sci": 0.08, "cul": 0.08}],
	],
]

# Buildings: id -> [name, cost, food, prod, gold, sci, cul, needs_tech, kaykit mesh]
const BUILDINGS := {
	"granary": ["Granary", 40, 2, 0, 0, 0, 0, "agri", "building_windmill"],
	"workshop": ["Workshop", 50, 0, 3, 0, 0, 0, "bronze", "building_blacksmith"],
	"library": ["Library", 50, 0, 0, 0, 3, 0, "writing", "building_church"],
	"market": ["Market", 50, 0, 0, 3, 0, 0, "currency", "building_market"],
	"temple": ["Temple", 55, 0, 0, 0, 0, 3, "", "building_well"],
	"walls": ["Walls", 60, 0, 0, 0, 0, 0, "masonry", "building_tower_base"],
}

# Unit classes: [name, attack, defense, cost, move, range] per age tier
const UNIT_TIERS := {
	"melee": [[22, 20, 30], [38, 30, 55], [58, 46, 90]],
	"ranged": [[20, 10, 35], [34, 16, 60], [60, 20, 100]],
}
const SETTLER_COST := 40
const SCOUT_COST := 20

static func race(i: int) -> Dictionary: return RACES[i]

static func terrain_info(t: int) -> Array: return TERRAIN[t]
