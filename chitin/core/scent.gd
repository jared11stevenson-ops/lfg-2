class_name Scent
extends RefCounted
## Chemical language. A "chord" is four channels in 0..1:
##   x FEAR   y KIN   z HUNGER   w REGENT (dominance)
## Every species has a private "want" chord. Parley quality = how closely your
## chord matches it, scaled by your scent power. You must LEARN each species'
## want (antennae reveal it with noise that shrinks as scent power grows).

enum Outcome { ENRAGE, IGNORE, CALM, RECRUIT, FLEE }
const CHANNEL_NAMES := ["Fear", "Kin", "Hunger", "Regent"]

static func similarity(chord: Vector4, want: Vector4) -> float:
	var d := (chord - want)
	var dist := sqrt(d.x * d.x + d.y * d.y + d.z * d.z + d.w * d.w)   # 0..2
	return clampf(1.0 - dist / 2.0, 0.0, 1.0)

static func parley(species: Dictionary, chord: Vector4, power: float, elite_resist: bool = true) -> Dictionary:
	var want: Vector4 = species.get("want", Vector4(0.5, 0.5, 0.5, 0.5))
	var q := similarity(chord, want) * clampf(0.55 + 0.45 * power, 0.0, 1.5)
	var outcome := Outcome.IGNORE
	# Pure terror works on the fearful, whatever their taste in perfume.
	if chord.x > 0.8 and chord.y < 0.4 and species.get("fearable", true) and power >= 1.0:
		outcome = Outcome.FLEE
	elif q >= 0.82 and species.get("recruitable", false):
		outcome = Outcome.RECRUIT
	elif q >= 0.62:
		outcome = Outcome.CALM
	elif q < 0.28:
		outcome = Outcome.ENRAGE
	if elite_resist and species.get("elite", false) and outcome == Outcome.RECRUIT:
		outcome = Outcome.CALM
	return {"outcome": outcome, "quality": q}

## What your antennae tell you about a species' want. Noise shrinks with power.
static func reveal(species: Dictionary, power: float, rng: RandomNumberGenerator) -> Vector4:
	var want: Vector4 = species.get("want", Vector4(0.5, 0.5, 0.5, 0.5))
	var noise := clampf(0.5 - 0.22 * power, 0.0, 0.5)
	return Vector4(
		clampf(want.x + rng.randf_range(-noise, noise), 0, 1),
		clampf(want.y + rng.randf_range(-noise, noise), 0, 1),
		clampf(want.z + rng.randf_range(-noise, noise), 0, 1),
		clampf(want.w + rng.randf_range(-noise, noise), 0, 1))

static func outcome_name(o: int) -> String:
	return ["Enraged", "Ignored", "Calmed", "Recruited", "Fled"][o]
