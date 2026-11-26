extends RefCounted
# Difficulty tiers and run mutators (replayability). A run = level + difficulty + mutators + seed.
const DIFFICULTY := {
	"easy": {"name": "Easy", "hp": 0.8, "speed": 1.0, "lives": 30, "reward": 1.0, "sell": 0.8, "mult": 0.8},
	"normal": {"name": "Normal", "hp": 1.0, "speed": 1.0, "lives": 20, "reward": 1.0, "sell": 0.7, "mult": 1.0},
	"hard": {"name": "Hard", "hp": 1.35, "speed": 1.1, "lives": 15, "reward": 1.15, "sell": 0.6, "mult": 1.5},
	"nightmare": {"name": "Nightmare", "hp": 1.8, "speed": 1.2, "lives": 10, "reward": 1.3, "sell": 0.5, "mult": 2.2},
}
const DIFF_ORDER := ["easy", "normal", "hard", "nightmare"]

const MUTATORS := {
	"swift": {"name": "Swift Herd", "desc": "Enemies 25% faster, +20% coins", "speed": 1.25, "reward": 1.2, "mult": 0.25},
	"tough": {"name": "Thick Hides", "desc": "Enemies +40% HP, +25% coins", "hp": 1.4, "reward": 1.25, "mult": 0.3},
	"famine": {"name": "Lean Times", "desc": "Start with half coins, +30% kill coins", "coins": 0.5, "reward": 1.3, "mult": 0.3},
	"swarm": {"name": "Swarming", "desc": "50% more enemies with 25% less HP", "count": 1.5, "hp": 0.75, "mult": 0.3},
	"brittle": {"name": "Fragile Wells", "desc": "Only 10 lives, +30% coins", "lives_set": 10, "reward": 1.3, "mult": 0.4},
	"fog": {"name": "Fog of Well", "desc": "Defender range -20%", "range": 0.8, "mult": 0.3},
	"elite": {"name": "Elite Herd", "desc": "1 in 5 enemies is a tough, rich elite", "elite_p": 0.2, "mult": 0.35},
	"haste": {"name": "Relentless", "desc": "Enemies arrive 40% faster", "interval": 0.6, "mult": 0.25},
	"nosurge": {"name": "No Surge", "desc": "Well Surge disabled, +25% coins", "nosurge": true, "reward": 1.25, "mult": 0.25},
	"heavy": {"name": "Heavy Air", "desc": "Defenders attack 15% slower", "rate": 0.85, "mult": 0.25},
}
const MUT_ORDER := ["swift", "tough", "famine", "swarm", "brittle", "fog", "elite", "haste", "nosurge", "heavy"]

# Merge difficulty + mutators into one flat dictionary of multipliers.
static func combine(diff: String, muts: Array) -> Dictionary:
	var d: Dictionary = DIFFICULTY[diff]
	var out := {"hp": float(d.hp), "speed": float(d.speed), "reward": float(d.reward), "lives": int(d.lives), "sell": float(d.sell),
		"coins": 1.0, "count": 1.0, "range": 1.0, "rate": 1.0, "interval": 1.0, "elite_p": 0.0, "nosurge": false, "score": float(d.mult)}
	for m in muts:
		var mu: Dictionary = MUTATORS[m]
		for k in ["hp", "speed", "reward", "coins", "count", "range", "rate", "interval"]:
			if mu.has(k):
				out[k] = float(out[k]) * float(mu[k])
		if mu.has("elite_p"):
			out.elite_p = float(mu.elite_p)
		if mu.has("lives_set"):
			out.lives = mini(int(out.lives), int(mu.lives_set))
		if mu.get("nosurge", false):
			out.nosurge = true
		out.score = float(out.score) + float(mu.mult)
	return out

# Wave events: random per-wave twists (from wave 3). Effects are multipliers applied while the wave runs.
const EVENTS := {
	"stampede": {"name": "Stampede!", "desc": "Enemies 20% faster, +25% coins", "speed": 1.2, "reward": 1.25},
	"blessing": {"name": "Wellspring Blessing", "desc": "Defenders deal +20% damage", "dmg": 1.2},
	"frenzy": {"name": "Frenzy!", "desc": "Enemies arrive much faster", "interval": 0.6},
	"mist": {"name": "Thick Mist", "desc": "Defender range -15%", "range": 0.85},
	"gold": {"name": "Golden Herd", "desc": "+60% coins, enemies +25% HP", "reward": 1.6, "hp": 1.25},
	"calm": {"name": "Calm Winds", "desc": "Defenders attack 15% faster", "rate": 1.15},
}
const EVENT_ORDER := ["stampede", "blessing", "frenzy", "mist", "gold", "calm"]
