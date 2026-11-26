extends RefCounted
# Data-driven creature defs. See docs/creatures_v1.md for the design behind each.
const DEFS := {
	"tickindle": {
		"name": "Tickindle", "types": ["ember", "forge"],
		"cost": 100, "range": 190.0, "dmg": 7.0, "rate": 1.6,
	},
	"shuckit": {
		"name": "Shuckit", "types": ["umbra", "gale"],
		"hp": 18.0, "speed": 120.0, "reward": 5,
	},
}
