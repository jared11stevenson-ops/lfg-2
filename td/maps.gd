extends RefCounted
# Map definitions: lane path, palette, decor style and per-wave weather.
const MAPS := {
	"mossgate": {
		"name": "Mossgate Lane", "blurb": "Gentle meadow. Rain rolls in on later waves.",
		"hp_mult": 1.0, "style": "meadow", "grass": Color("5fae4f"), "path_fill": Color("d1a56a"), "path_edge": Color("6b4a2a"),
		"weather": ["clear", "clear", "rain", "clear", "rain", "clear", "rain", "rain"],
		"path": [Vector2(-40, 360), Vector2(300, 360), Vector2(300, 160), Vector2(700, 160), Vector2(700, 560), Vector2(1000, 560), Vector2(1000, 300), Vector2(1320, 300)],
	},
	"frostrun": {
		"name": "Frostrun Pass", "blurb": "Long switchbacks in the snow. Cold favours the Spirit.",
		"hp_mult": 1.25, "style": "snow", "grass": Color("dce8f2"), "path_fill": Color("8d9bb3"), "path_edge": Color("4d5a73"),
		"weather": ["snow", "snow", "clear", "snow", "snow", "clear", "snow", "snow"],
		"path": [Vector2(-40, 140), Vector2(900, 140), Vector2(900, 300), Vector2(240, 300), Vector2(240, 470), Vector2(1000, 470), Vector2(1000, 560), Vector2(1320, 560)],
	},
	"emberflats": {
		"name": "Emberflats", "blurb": "Zig-zag desert. Heatwaves empower Ember and Forge.",
		"hp_mult": 1.5, "style": "desert", "grass": Color("dcb878"), "path_fill": Color("a8693f"), "path_edge": Color("5a3a22"),
		"weather": ["heat", "clear", "heat", "heat", "clear", "heat", "heat", "heat"],
		"path": [Vector2(-40, 540), Vector2(220, 540), Vector2(220, 200), Vector2(520, 200), Vector2(520, 460), Vector2(820, 460), Vector2(820, 160), Vector2(1100, 160), Vector2(1100, 420), Vector2(1320, 420)],
	},
}
const ORDER := ["mossgate", "frostrun", "emberflats"]

# Weather: tower damage multiplier per element, and display text.
const WEATHER := {
	"clear": {"label": "Clear skies", "mult": {}},
	"rain": {"label": "Rain: Tide/Volt +20%, Ember/Forge -15%", "mult": {"tide": 1.2, "volt": 1.2, "ember": 0.85, "forge": 0.85}},
	"snow": {"label": "Snow: Spirit +15%, Ember/Verdant -15%", "mult": {"spirit": 1.15, "ember": 0.85, "verdant": 0.85}},
	"heat": {"label": "Heatwave: Ember/Forge +20%, Tide -15%", "mult": {"ember": 1.2, "forge": 1.2, "tide": 0.85}},
}

static func weather_mult(weather: String, types: Array) -> float:
	var m: Dictionary = WEATHER[weather].mult
	var total := 0.0
	for t in types:
		total += float(m.get(t, 1.0))
	return total / float(types.size())
