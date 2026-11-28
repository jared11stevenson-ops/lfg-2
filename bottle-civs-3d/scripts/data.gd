class_name BCData
extends RefCounted
## Static content: the first ten races of the Wall (+ two sealed jars for later).
## Every model is a third-party CC0 asset (Quaternius / KayKit) - see assets/CREDITS.md.

const RES := ["food", "wood", "ore", "goods", "lore", "gold"]
const COLS := 4
const ROWS := 3

const K := "res://assets/characters/kaykit/"
const Q := "res://assets/characters/quaternius/"

# rig: "kaykit" (Rig_Medium animations), "ual" (Universal Animation Library), "native" (embedded animations)
# scale: uniform scale; squash: extra (x,y,z) multiplier so one model can read as several races
const RACES := [
	{
		"id": "elf", "name": "Elves", "jar": "Glimmerwood", "color": Color("7ad98a"), "skill": "Herbalism",
		"blurb": "Forest-wardens whose gardens feed a lot of mouths and whose libraries run deep.",
		"mult": {"food": 1.25, "wood": 1.15, "ore": 0.7, "goods": 1.0, "lore": 1.3, "gold": 1.0, "might": 0.9},
		"traits": {"aggression": 0.2, "greed": 0.3, "openness": 0.7, "fertility": 0.10, "lifespan": 60},
		"like": ["human", "wizard"], "dislike": ["orc", "goblin", "dwarf"],
		"model": K + "Ranger.glb", "rig": "kaykit", "height": 0.9, "squash": Vector3(1, 1, 1),
		"bcolor": "green", "decor": "forest",
	},
	{
		"id": "dwarf", "name": "Dwarves", "jar": "Deepforge", "color": Color("e0a24a"), "skill": "Deep Mining",
		"blurb": "Ore and goods in absurd quantities. Hoard gold, hold grudges.",
		"mult": {"food": 0.85, "wood": 0.9, "ore": 1.7, "goods": 1.35, "lore": 0.9, "gold": 1.1, "might": 1.1},
		"traits": {"aggression": 0.4, "greed": 0.8, "openness": 0.35, "fertility": 0.10, "lifespan": 45},
		"like": ["human", "ogre"], "dislike": ["elf", "goblin"],
		"model": K + "Barbarian.glb", "rig": "kaykit", "height": 0.7, "squash": Vector3(1.2, 0.82, 1.2),
		"bcolor": "yellow", "decor": "mountain",
	},
	{
		"id": "human", "name": "Humans", "jar": "Crownmere", "color": Color("6aa8ff"), "skill": "Trade & Diplomacy",
		"blurb": "Jack-of-all-trades. Their merchants make better deals and friends everywhere.",
		"mult": {"food": 1.0, "wood": 1.0, "ore": 1.0, "goods": 1.0, "lore": 1.0, "gold": 1.4, "might": 1.0},
		"traits": {"aggression": 0.35, "greed": 0.5, "openness": 0.85, "fertility": 0.14, "lifespan": 30},
		"like": ["elf", "dwarf", "wizard"], "dislike": ["orc", "imp"], "tradeBonus": 1.25, "charm": 1.5,
		"model": K + "Knight.glb", "rig": "kaykit", "height": 0.8, "squash": Vector3(1, 1, 1),
		"bcolor": "blue", "decor": "town",
	},
	{
		"id": "lizard", "name": "Lizardfolk", "jar": "Mirefen", "color": Color("9acd32"), "skill": "Swamp Farming",
		"blurb": "Clutch-hatchers. Fast growing, fast fed, and surprisingly sociable.",
		"mult": {"food": 1.55, "wood": 1.1, "ore": 0.8, "goods": 0.8, "lore": 0.8, "gold": 0.9, "might": 0.95},
		"traits": {"aggression": 0.3, "greed": 0.3, "openness": 0.55, "fertility": 0.22, "lifespan": 26},
		"like": ["ogre", "goblin"], "dislike": ["elf"],
		"model": K + "Rogue.glb", "rig": "kaykit", "height": 0.85, "squash": Vector3(1, 1, 1), "tint": Color(0.55, 0.95, 0.45),
		"bcolor": "green", "decor": "swamp",
	},
	{
		"id": "orc", "name": "Orcs", "jar": "Skullgrit", "color": Color("e0533d"), "skill": "Warcraft",
		"blurb": "Born to the shield wall. Raiders first, farmers when they must be.",
		"mult": {"food": 0.9, "wood": 1.0, "ore": 1.0, "goods": 0.9, "lore": 0.6, "gold": 0.8, "might": 1.5},
		"traits": {"aggression": 0.9, "greed": 0.5, "openness": 0.3, "fertility": 0.17, "lifespan": 28},
		"like": ["ogre", "goblin"], "dislike": ["elf", "human", "dwarf"], "soldierShare": 0.4,
		"model": Q + "Orc_Male.glb", "rig": "ual", "height": 1.0, "squash": Vector3(1, 1, 1),
		"bcolor": "red", "decor": "war",
	},
	{
		"id": "goblin", "name": "Goblins", "jar": "Rustwick", "color": Color("b4d94a"), "skill": "Tinkering",
		"blurb": "Scrap-engineers. They build, scavenge and steal in roughly that order.",
		"mult": {"food": 0.9, "wood": 1.0, "ore": 1.0, "goods": 1.5, "lore": 1.0, "gold": 1.0, "might": 0.8},
		"traits": {"aggression": 0.55, "greed": 0.9, "openness": 0.5, "fertility": 0.24, "lifespan": 20},
		"like": ["orc", "imp", "lizard"], "dislike": ["elf", "dwarf"], "plunder": 1.4,
		"model": Q + "Puglin.glb", "rig": "ual", "height": 0.65, "squash": Vector3(1, 1, 1),
		"bcolor": "yellow", "decor": "scrap",
	},
	{
		"id": "skeleton", "name": "Skeletons", "jar": "Hollowbone", "color": Color("d8d8c8"), "skill": "Undying",
		"blurb": "Barely eat, never age, cannot breed. They raise the fallen of every battle they win.",
		"mult": {"food": 0.4, "wood": 1.0, "ore": 1.2, "goods": 1.0, "lore": 1.0, "gold": 0.7, "might": 1.1},
		"traits": {"aggression": 0.65, "greed": 0.2, "openness": 0.2, "fertility": 0.0, "lifespan": 400},
		"like": ["imp"], "dislike": ["elf", "human", "lizard"], "eats": 0.15, "raiseDead": true,
		"model": K + "Skeleton_Warrior.glb", "rig": "kaykit", "height": 0.8, "squash": Vector3(1, 1, 1),
		"bcolor": "green", "decor": "ruins",
	},
	{
		"id": "ogre", "name": "Ogres", "jar": "Mugdrum", "color": Color("c98f6b"), "skill": "Brewing & Brawn",
		"blurb": "Slow, huge and cheerful. Their ale turns surplus grain into gold.",
		"mult": {"food": 1.0, "wood": 1.3, "ore": 1.1, "goods": 0.8, "lore": 0.5, "gold": 1.2, "might": 1.3},
		"traits": {"aggression": 0.5, "greed": 0.4, "openness": 0.5, "fertility": 0.12, "lifespan": 36},
		"like": ["orc", "lizard", "dwarf"], "dislike": ["wizard"], "hp": 2.0, "brew": true,
		"model": K + "Knight.glb", "rig": "kaykit", "height": 1.3, "squash": Vector3(1.35, 1.0, 1.35), "tint": Color(1.0, 0.8, 0.5),
		"bcolor": "red", "decor": "tavern",
	},
	{
		"id": "imp", "name": "Imps", "jar": "Cinderhex", "color": Color("c14aff"), "skill": "Trickery",
		"blurb": "Tiny schemers. They steal gold and frame neighbours for crimes.",
		"mult": {"food": 0.9, "wood": 0.9, "ore": 0.9, "goods": 1.1, "lore": 1.1, "gold": 1.3, "might": 0.7},
		"traits": {"aggression": 0.35, "greed": 0.85, "openness": 0.6, "fertility": 0.20, "lifespan": 24},
		"like": ["goblin", "skeleton"], "dislike": ["wizard", "human"], "spy": true, "hp": 0.7,
		"model": Q + "Imp.glb", "rig": "ual", "height": 0.65, "squash": Vector3(1, 1, 1),
		"bcolor": "red", "decor": "hell",
	},
	{
		"id": "wizard", "name": "Wizards", "jar": "Aethervault", "color": Color("5ad1ff"), "skill": "Arcane Lore",
		"blurb": "Their towers turn lore into everything else. Frail, but terrifyingly clever.",
		"mult": {"food": 0.9, "wood": 0.8, "ore": 0.8, "goods": 1.15, "lore": 1.9, "gold": 1.0, "might": 0.8},
		"traits": {"aggression": 0.25, "greed": 0.45, "openness": 0.55, "fertility": 0.08, "lifespan": 70},
		"like": ["elf", "human"], "dislike": ["imp", "ogre"], "techBonus": 1.5, "hp": 0.8,
		"model": K + "Mage.glb", "rig": "kaykit", "height": 0.85, "squash": Vector3(1, 1, 1),
		"bcolor": "blue", "decor": "arcane",
	},
]

# Two jars exist but are still sealed - future content.
const SEALED := [
	{"id": "chort", "name": "Chorts", "jar": "Sealed Jar XI", "color": Color("e8613a"), "model": K + "Rogue_Hooded.glb", "rig": "kaykit", "height": 0.8},
	{"id": "angel", "name": "Angels", "jar": "Sealed Jar XII", "color": Color("f6e27a"), "model": K + "Skeleton_Mage.glb", "rig": "kaykit", "height": 0.8},
]
