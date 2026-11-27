extends RefCounted
# Moves learned by level (no evolutions): every creature learns 3 moves from its primary type at levels 5, 10 and 15.
# A move is a stat modifier applied by tower.gd (same schema as upgrades: mul/add/set).
const LEVELS := [5, 10, 15]
const NAMES := {
	"ember": ["Cinder Snap", "Heat Haze", "Sunforge"],
	"tide": ["Brine Jet", "Undertow Drift", "Deluge"],
	"verdant": ["Thorn Lash", "Spore Veil", "Overgrowth"],
	"volt": ["Static Zip", "Arc Surge", "Stormcall"],
	"stone": ["Rock Pelt", "Granite Stance", "Landslide"],
	"frost": ["Rime Bite", "Cold Snap", "Whiteout"],
	"gale": ["Gust Dart", "Tailwind", "Cyclone"],
	"venom": ["Sour Spit", "Rot Cloud", "Blight"],
	"forge": ["Hammer Tap", "Quench", "Anvil Storm"],
	"umbra": ["Shade Nip", "Dusk Step", "Nightfall"],
	"aether": ["Prism Ping", "Thin Veil", "Starfall"],
	"spirit": ["Wisp Touch", "Lantern Gaze", "Moonlit Hymn"],
}
const UTILITY := {"ember": "range", "tide": "rate", "verdant": "range", "volt": "rate", "stone": "range", "frost": "rate",
	"gale": "rate", "venom": "range", "forge": "rate", "umbra": "range", "aether": "rate", "spirit": "range"}

static func for_type(t: String) -> Array:
	var out := []
	var n: Array = NAMES.get(t, ["Tackle", "Focus", "Burst"])
	var util: String = UTILITY.get(t, "rate")
	out.append({"lvl": 5, "name": n[0], "desc": "+12% damage", "mul": {"dmg": 1.12}})
	if util == "range":
		out.append({"lvl": 10, "name": n[1], "desc": "+20 range", "add": {"range": 20}})
	else:
		out.append({"lvl": 10, "name": n[1], "desc": "+12% attack speed", "mul": {"rate": 1.12}})
	out.append({"lvl": 15, "name": n[2], "desc": "+15% damage, +10% speed", "mul": {"dmg": 1.15, "rate": 1.1}})
	return out

static func learned(types: Array, level: int) -> Array:
	var out := []
	for m in for_type(String(types[0])):
		if level >= int(m.lvl):
			out.append(m)
	return out

# Moves gained when going from level a to level b.
static func gained(types: Array, a: int, b: int) -> Array:
	var out := []
	for m in for_type(String(types[0])):
		if int(m.lvl) > a and int(m.lvl) <= b:
			out.append(m)
	return out

const SPECIAL := ["ember", "tide", "volt", "frost", "spirit", "aether", "venom", "gale"]

static func category(t: String) -> String:
	return "Special" if t in SPECIAL else "Physical"
