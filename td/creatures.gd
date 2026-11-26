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
		"id": "shuckit", "name": "Shuckit", "types": ["umbra", "gale"],
		"hp": 18.0, "hp_wave": 7.0, "speed": 120.0, "reward": 5, "leak": 1,
	},
	# Zapnose: Volt/Aether. Elephantnose fish + Nikola Tesla + doorbell. Fast, fragile.
	"zapnose": {
		"id": "zapnose", "name": "Zapnose", "types": ["volt", "aether"],
		"hp": 10.0, "hp_wave": 3.0, "speed": 190.0, "reward": 4, "leak": 1,
	},
	# Glomm: Stone/Frost. Yeti crab + Golem of Prague + snow globe. Slow tank, costs 3 lives if it leaks.
	"glomm": {
		"id": "glomm", "name": "Glomm", "types": ["stone", "frost"],
		"hp": 70.0, "hp_wave": 22.0, "speed": 62.0, "reward": 14, "leak": 3,
	},
}
