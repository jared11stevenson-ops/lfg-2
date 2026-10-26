class_name Biomes
extends RefCounted
## Biome ids + the saturated palette. Colours are authored as sRGB; the world shader linearises.
enum B { MEADOW, SHORE, FUNGAL, RUINS, SALT, HIGHLANDS, BOG, WATER }
const NAMES: Array[String] = ["Homestead Meadow", "Living Shore", "Fungal Grove", "Ruins", "Salt Flats", "Highlands", "Bog", "Water"]
const IDS: Array[StringName] = [&"meadow", &"shore", &"fungal", &"ruins", &"salt", &"highlands", &"bog", &"water"]

# Warm cozy ground, with fungal accents carried by props.
const GROUND: Array[Color] = [
	Color("d9b35a"), # meadow: warm honey-grass
	Color("f0c98a"), # shore: sunny sand
	Color("b0558f"), # fungal: plum loam
	Color("a8806a"), # ruins: dusty terracotta
	Color("f3e0d4"), # salt: pink-white crust
	Color("8f6f9a"), # highlands: lavender rock
	Color("5c8f6e"), # bog: teal moss
	Color("1b7f93"), # water (seen only via water mesh)
]
const GROUND_ALT: Array[Color] = [
	Color("bf9444"), Color("e3b878"), Color("8f3f7a"), Color("8a6652"), Color("e8c6c0"), Color("705582"), Color("3f7a62"), Color("166a80"),
]
const ROCK := Color("6d5382")
const FUNGI: Array[Color] = [Color("ff2fb5"), Color("19e0c8"), Color("e6ff2e"), Color("ff7a2f"), Color("8f5cff")]

static func map_color(b: int) -> Color:
	var base: Color = GROUND[clampi(b, 0, GROUND.size() - 1)]
	return base

static func name_of(b: int) -> String:
	return NAMES[clampi(b, 0, NAMES.size() - 1)]
