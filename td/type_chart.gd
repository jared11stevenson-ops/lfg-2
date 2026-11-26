extends RefCounted
# Pass-1 chart: only the starter triangle is wired. Full 12-type chart is the next design pass.
# Ember > Verdant > Tide > Ember. Super-effective 1.5x, resisted 0.67x.
const BEATS := {"ember": "verdant", "verdant": "tide", "tide": "ember"}

static func mult(att: String, defs: Array) -> float:
	var m := 1.0
	for d in defs:
		if BEATS.get(att, "") == d:
			m *= 1.5
		elif BEATS.get(d, "") == att:
			m *= 0.67
	return m

static func best(atts: Array, defs: Array) -> float:
	var b := 0.0
	for a in atts:
		b = maxf(b, mult(a, defs))
	return b
