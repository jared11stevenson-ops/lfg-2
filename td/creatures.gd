extends RefCounted
# Data-driven creature defs. See docs/creatures_v1.md for the design behind each.
const DEFS := {
	"tickindle": {
		"name": "Tickindle", "types": ["ember", "forge"],
		"id": "tickindle", "cost": 100, "range": 190.0, "dmg": 7.0, "rate": 1.6,
		"upgrades": {
			"a": [
				{"name": "Greased Gears", "cost": 90, "desc": "+20% attack speed", "mul": {"rate": 1.2}},
				{"name": "Tick-Tock Volley", "cost": 150, "desc": "Longer wind-up (+3 stacks)", "add": {"windup_max": 3}},
				{"name": "Overwound", "cost": 280, "desc": "+25% speed, +2 damage", "mul": {"rate": 1.25}, "add": {"dmg": 2}},
				{"name": "Clockwork Pyre", "cost": 560, "desc": "Fires 2 bolts per shot", "set": {"multishot": 2}, "add": {"dmg": 1}},
			],
			"b": [
				{"name": "Hot Iron", "cost": 80, "desc": "+30% damage", "mul": {"dmg": 1.3}},
				{"name": "Longbarrel", "cost": 130, "desc": "+35 range", "add": {"range": 35}},
				{"name": "Molten Rounds", "cost": 300, "desc": "Molten every 5th shot, leaves burn patch", "set": {"molten_every": 5, "burn_patch": true}},
				{"name": "Anvil Drop", "cost": 600, "desc": "Molten shots splash, +30% damage", "set": {"splash": 70}, "mul": {"dmg": 1.3}},
			],
		},
	},
	"dugloom": {
		"id": "dugloom", "name": "Dugloom", "types": ["tide", "spirit"],
		"cost": 120, "range": 165.0, "dmg": 2.0, "rate": 0.8, "slow": 0.55, "slow_t": 2.0,
		"upgrades": {
			"a": [
				{"name": "Brighter Lamp", "cost": 80, "desc": "+30 range", "add": {"range": 30}},
				{"name": "Slow Tide", "cost": 140, "desc": "Stronger slow", "set": {"slow": 0.45}},
				{"name": "Lighthouse Pulse", "cost": 260, "desc": "+5 damage, +20% speed", "add": {"dmg": 5}, "mul": {"rate": 1.2}},
				{"name": "Beaconmaid", "cost": 520, "desc": "Pulse stuns 0.6s, +range, faster", "set": {"stun": 0.6}, "add": {"range": 25}, "mul": {"rate": 1.2}},
			],
			"b": [
				{"name": "Undertow", "cost": 90, "desc": "Pulse drags foes back", "set": {"pull": 18.0}},
				{"name": "Deeper Pull", "cost": 150, "desc": "Stronger drag", "set": {"pull": 36.0}},
				{"name": "Drowned Chorus", "cost": 270, "desc": "+40% speed, +2 damage", "mul": {"rate": 1.4}, "add": {"dmg": 2}},
				{"name": "Maelstrom", "cost": 540, "desc": "Huge drag, +8 damage", "set": {"pull": 70.0}, "add": {"dmg": 8}},
			],
		},
	},
	"hutzin": {
		"id": "hutzin", "name": "Hutzin", "types": ["verdant", "venom"],
		"cost": 130, "range": 175.0, "dmg": 2.0, "rate": 0.9, "stacks": 1,
		"upgrades": {
			"a": [
				{"name": "Stronger Brew", "cost": 90, "desc": "Poison hurts 40% more", "set": {"poison_mul": 1.4}},
				{"name": "Double Dose", "cost": 150, "desc": "2 poison stacks per shot", "set": {"stacks": 2}},
				{"name": "Rolling Boil", "cost": 280, "desc": "+30% speed, max 8 stacks", "mul": {"rate": 1.3}, "set": {"max_stacks": 8}},
				{"name": "Brewmother", "cost": 560, "desc": "Poison hurts more, spreads to ALL nearby on death", "set": {"spread_all": true, "poison_mul": 1.9}},
			],
			"b": [
				{"name": "Spore Puff", "cost": 100, "desc": "Shots splash poison", "set": {"splash": 50}},
				{"name": "Wider Cloud", "cost": 150, "desc": "Bigger splash", "set": {"splash": 85}},
				{"name": "Hex Teapot", "cost": 290, "desc": "Poisoned foes take +20% damage, +3 dmg", "set": {"vuln": true}, "add": {"dmg": 3}},
				{"name": "Walking Cottage", "cost": 580, "desc": "Every 6th shot a poison stomp, +25 range", "set": {"burst_every": 6}, "add": {"range": 25}},
			],
		},
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
