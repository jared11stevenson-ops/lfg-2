extends RefCounted
# Weather shifts tower damage by element. The HUD previews the next wave's weather.
const WEATHER := {
	"clear": {"label": "Clear skies", "mult": {}},
	"rain": {"label": "Rain: Tide/Volt +20%, Ember/Forge -15%", "mult": {"tide": 1.2, "volt": 1.2, "ember": 0.85, "forge": 0.85}},
	"snow": {"label": "Snow: Spirit/Frost +15%, Ember/Verdant -15%", "mult": {"spirit": 1.15, "frost": 1.15, "ember": 0.85, "verdant": 0.85}},
	"heat": {"label": "Heatwave: Ember/Forge +20%, Tide/Frost -15%", "mult": {"ember": 1.2, "forge": 1.2, "tide": 0.85, "frost": 0.85}},
}

static func mult(weather: String, types: Array) -> float:
	var m: Dictionary = WEATHER[weather].mult
	var total := 0.0
	for t in types:
		total += float(m.get(t, 1.0))
	return total / float(types.size())
