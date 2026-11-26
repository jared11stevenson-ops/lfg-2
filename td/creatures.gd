extends RefCounted
# Data-driven creature defs. See docs/creatures_v1.md for the design behind each.
const DEFS := {
	"tickindle": {
		"name": "Tickindle", "types": ["ember", "forge"],
		"id": "tickindle", "cost": 100, "range": 190.0, "dmg": 7.0, "rate": 1.6,
	},
	"dugloom": {
		"id": "dugloom", "name": "Dugloom", "types": ["tide", "spirit"],
		"cost": 120, "range": 165.0, "dmg": 2.0, "rate": 0.8, "slow": 0.55, "slow_t": 2.0,
	},
	"hutzin": {
		"id": "hutzin", "name": "Hutzin", "types": ["verdant", "venom"],
		"cost": 130, "range": 175.0, "dmg": 2.0, "rate": 0.9, "stacks": 1,
	},
	"shuckit": {
		"name": "Shuckit", "types": ["umbra", "gale"],
		"hp": 18.0, "speed": 120.0, "reward": 5,
	},
}
