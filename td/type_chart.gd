extends RefCounted
# 12 types. Every type beats exactly 2 and is beaten by exactly 2 (checked in tests/test_type_chart.gd).
# Super-effective 1.5x, resisted 0.67x. Starter triangle Ember > Verdant > Tide > Ember is preserved.
const TYPES := ["ember", "tide", "verdant", "volt", "stone", "frost", "gale", "venom", "forge", "umbra", "aether", "spirit"]
const BEATS := {
	"ember": ["verdant", "frost"], "tide": ["ember", "stone"], "verdant": ["tide", "stone"],
	"volt": ["tide", "gale"], "stone": ["volt", "ember"], "frost": ["verdant", "gale"],
	"gale": ["venom", "forge"], "venom": ["aether", "spirit"], "forge": ["frost", "umbra"],
	"umbra": ["venom", "aether"], "aether": ["volt", "spirit"], "spirit": ["forge", "umbra"],
}

static func mult(att: String, defs: Array) -> float:
	var m := 1.0
	for d in defs:
		if d in BEATS[att]:
			m *= 1.5
		elif att in BEATS[d]:
			m *= 0.67
	return m

static func best(atts: Array, defs: Array) -> float:
	var b := 0.0
	for a in atts:
		b = maxf(b, mult(a, defs))
	return b
