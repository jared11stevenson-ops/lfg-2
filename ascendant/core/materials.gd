class_name Materials
extends RefCounted
## Materials are bundles of physical properties (0..1). Nothing here says "tier".
## Properties: hard, flex, dens, sharp (can hold an edge), tens (tensile), insul, buoy, water (resists water), stick (adhesive), brit (brittle)
const PROPS := ["hard", "flex", "dens", "sharp", "tens", "insul", "buoy", "water", "stick", "brit"]
const DB := {
	"flint":   {"hard": 0.85, "flex": 0.0, "dens": 0.7, "sharp": 0.95, "tens": 0.1, "insul": 0.1, "buoy": 0.0, "water": 0.9, "stick": 0.0, "brit": 0.8, "src": "rock"},
	"stone":   {"hard": 0.8, "flex": 0.0, "dens": 0.9, "sharp": 0.2, "tens": 0.1, "insul": 0.3, "buoy": 0.0, "water": 0.9, "stick": 0.0, "brit": 0.4, "src": "rock"},
	"clay":    {"hard": 0.2, "flex": 0.3, "dens": 0.7, "sharp": 0.0, "tens": 0.1, "insul": 0.5, "buoy": 0.0, "water": 0.3, "stick": 0.4, "brit": 0.3, "src": "water"},
	"mud":     {"hard": 0.1, "flex": 0.2, "dens": 0.6, "sharp": 0.0, "tens": 0.05, "insul": 0.5, "buoy": 0.0, "water": 0.2, "stick": 0.6, "brit": 0.2, "src": "soil"},
	"wood":    {"hard": 0.5, "flex": 0.35, "dens": 0.45, "sharp": 0.3, "tens": 0.5, "insul": 0.5, "buoy": 0.7, "water": 0.5, "stick": 0.0, "brit": 0.3, "src": "tree"},
	"reed":    {"hard": 0.15, "flex": 0.85, "dens": 0.15, "sharp": 0.0, "tens": 0.5, "insul": 0.4, "buoy": 0.9, "water": 0.5, "stick": 0.0, "brit": 0.1, "src": "shore"},
	"fiber":   {"hard": 0.05, "flex": 0.95, "dens": 0.1, "sharp": 0.0, "tens": 0.6, "insul": 0.4, "buoy": 0.4, "water": 0.2, "stick": 0.0, "brit": 0.0, "src": "plant"},
	"leaf":    {"hard": 0.05, "flex": 0.8, "dens": 0.05, "sharp": 0.0, "tens": 0.2, "insul": 0.3, "buoy": 0.6, "water": 0.7, "stick": 0.0, "brit": 0.1, "src": "tree"},
	"bone":    {"hard": 0.7, "flex": 0.1, "dens": 0.5, "sharp": 0.6, "tens": 0.5, "insul": 0.1, "buoy": 0.2, "water": 0.8, "stick": 0.0, "brit": 0.5, "src": "carcass"},
	"chitin":  {"hard": 0.6, "flex": 0.3, "dens": 0.2, "sharp": 0.5, "tens": 0.6, "insul": 0.3, "buoy": 0.4, "water": 0.9, "stick": 0.0, "brit": 0.3, "src": "carcass"},
	"fur":     {"hard": 0.0, "flex": 0.9, "dens": 0.1, "sharp": 0.0, "tens": 0.2, "insul": 0.95, "buoy": 0.3, "water": 0.4, "stick": 0.0, "brit": 0.0, "src": "carcass"},
	"shell":   {"hard": 0.65, "flex": 0.0, "dens": 0.5, "sharp": 0.3, "tens": 0.2, "insul": 0.3, "buoy": 0.3, "water": 1.0, "stick": 0.0, "brit": 0.6, "src": "shore"},
	"silk":    {"hard": 0.05, "flex": 0.95, "dens": 0.05, "sharp": 0.0, "tens": 0.95, "insul": 0.3, "buoy": 0.3, "water": 0.5, "stick": 0.3, "brit": 0.0, "src": "secrete"},
	"resin":   {"hard": 0.4, "flex": 0.15, "dens": 0.3, "sharp": 0.0, "tens": 0.2, "insul": 0.4, "buoy": 0.3, "water": 0.95, "stick": 0.95, "brit": 0.5, "src": "secrete"},
	"wax":     {"hard": 0.2, "flex": 0.4, "dens": 0.25, "sharp": 0.0, "tens": 0.1, "insul": 0.6, "buoy": 0.5, "water": 1.0, "stick": 0.5, "brit": 0.3, "src": "secrete"},
	"salt":    {"hard": 0.3, "flex": 0.0, "dens": 0.5, "sharp": 0.1, "tens": 0.0, "insul": 0.1, "buoy": 0.0, "water": 0.0, "stick": 0.0, "brit": 0.7, "src": "dry"},
}

static func prop(m: String, p: String) -> float:
	return DB[m][p]

## Which raw materials can this species+region supply? (biology gates materials: only silk-makers have silk)
static func available(region_water: float, trees: float, elev: float, soil: float, secrete: float, dry: bool) -> Array:
	var a := ["mud", "fiber"]
	if elev > 0.55: a.append_array(["stone", "flint"])
	if region_water > 0.2: a.append_array(["clay", "reed", "shell"])
	if trees > 0.25: a.append_array(["wood", "leaf"])
	if trees > 0.5: a.append("resin")
	if dry: a.append("salt")
	a.append_array(["bone", "chitin", "fur"])     # from carcasses (scavenged)
	if secrete > 0.45:
		a.append("silk")
		a.append("wax")
	return a
