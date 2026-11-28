class_name Invention
extends RefCounted
## Functional invention: a FUNCTION is a practical problem; a DESIGN assigns materials to roles.
## The score is computed from material properties and the inventor's biology; there is no tech tree.
## A function only becomes known knowledge when a working design (score >= threshold) is made.

## role weights: property -> weight (negative = must be low). `need`: minimum body capability.
const FUNCS := {
	"cut":     {"roles": {"edge": {"sharp": 1.0, "hard": 0.5, "brit": -0.4}, "haft": {"tens": 0.4, "flex": 0.2, "dens": -0.2}}, "bind": "haft", "need": {"c_manip": 0.3}, "verb": "cutter"},
	"pierce":  {"roles": {"point": {"sharp": 0.9, "hard": 0.6, "brit": -0.5}, "shaft": {"tens": 0.6, "dens": -0.4, "flex": 0.1}}, "need": {"c_manip": 0.3}, "verb": "spear"},
	"pound":   {"roles": {"head": {"dens": 0.9, "hard": 0.6, "brit": -0.3}, "haft": {"tens": 0.5, "hard": 0.2}}, "need": {"c_manip": 0.25, "strength": 0.3}, "verb": "maul"},
	"dig":     {"roles": {"blade": {"hard": 0.7, "sharp": 0.3, "brit": -0.4}, "haft": {"tens": 0.4}}, "need": {"c_manip": 0.2}, "verb": "digger"},
	"bind":    {"roles": {"strand": {"tens": 1.0, "flex": 0.7}}, "need": {"c_manip": 0.2}, "verb": "cordage"},
	"contain": {"roles": {"wall": {"water": 0.8, "hard": 0.3, "brit": -0.3}, "seal": {"stick": 0.6, "water": 0.7}}, "need": {"c_manip": 0.35}, "verb": "vessel"},
	"carry":   {"roles": {"frame": {"flex": 0.4, "tens": 0.6, "dens": -0.4}, "strap": {"tens": 0.8, "flex": 0.5}}, "need": {"c_manip": 0.3}, "verb": "carrier"},
	"roof":    {"roles": {"cover": {"water": 0.8, "insul": 0.5, "flex": 0.3}, "frame": {"tens": 0.5, "hard": 0.3, "dens": -0.2}}, "need": {"c_manip": 0.25}, "verb": "roof"},
	"float":   {"roles": {"hull": {"buoy": 1.0, "water": 0.5, "dens": -0.5}, "bind": {"tens": 0.5}}, "need": {"c_manip": 0.3}, "verb": "raft"},
	"trap":    {"roles": {"mesh": {"tens": 0.8, "flex": 0.5}, "lure": {"stick": 0.6}}, "need": {"c_manip": 0.3, "c_plan": 0.3}, "verb": "snare"},
	"preserve":{"roles": {"agent": {"water": 0.6, "insul": 0.3}, "cure": {"stick": 0.1}}, "need": {"c_plan": 0.3}, "verb": "cache"},
	"sense":   {"roles": {"thread": {"tens": 0.9, "flex": 0.6}, "anchor": {"hard": 0.3}}, "need": {"c_spatial": 0.3}, "verb": "tripline"},
	"armor":   {"roles": {"plate": {"hard": 0.7, "dens": -0.3, "brit": -0.4}, "lining": {"insul": 0.4, "flex": 0.6}}, "need": {"c_manip": 0.3}, "verb": "guard"},
}

static func score_role(role_w: Dictionary, mat: String) -> float:
	var s := 0.0; var norm := 0.0
	for p in role_w:
		var w: float = role_w[p]
		var v: float = Materials.prop(mat, p)
		if w >= 0.0:
			s += w * v
		else:
			s += (-w) * (1.0 - v)    # negative weight = prefers LOW property
		norm += absf(w)
	return s / maxf(norm, 0.001)

## design: {role: material}. g: inventor genome (for capability checks). Returns {ok, score, parts, reasons}
static func evaluate(func_id: String, design: Dictionary, g: PackedFloat32Array) -> Dictionary:
	var f: Dictionary = FUNCS[func_id]
	var res := {"ok": false, "score": 0.0, "parts": {}, "reasons": [], "func": func_id}
	for need in f["need"]:
		if Genome.get_g(g, need) < float(f["need"][need]):
			res["reasons"].append("body cannot manage this: needs %s %.2f (has %.2f)" % [need, f["need"][need], Genome.get_g(g, need)])
			return res
	var tot := 0.0; var n := 0
	var weakest := 1.0
	for role in f["roles"]:
		if not design.has(role):
			res["reasons"].append("missing part: " + role)
			return res
		var sc := score_role(f["roles"][role], design[role])
		res["parts"][role] = sc
		tot += sc; n += 1; weakest = minf(weakest, sc)
		if sc < 0.35: res["reasons"].append("%s: %s is a poor %s" % [func_id, design[role], role])
	# the weakest part limits the whole (a spear with a rotten shaft is a bad spear)
	var score := (tot / n) * 0.55 + weakest * 0.45
	# skill from dexterity/planning improves workmanship but never creates function from nothing
	score *= 0.85 + 0.15 * (Genome.get_g(g, "c_manip") * 0.6 + Genome.get_g(g, "c_plan") * 0.4)
	res["score"] = score
	res["ok"] = score >= 0.5
	if not res["ok"] and res["reasons"].is_empty(): res["reasons"].append("works poorly (%.0f%%)" % (score * 100.0))
	return res

static func design_name(func_id: String, design: Dictionary) -> String:
	var f: Dictionary = FUNCS[func_id]
	var first_role: String = f["roles"].keys()[0]
	return "%s %s" % [String(design[first_role]).capitalize(), f["verb"]]

## best design from a pool of materials (what a competent inventor would try). Used by tribes & hints.
static func best_design(func_id: String, pool: Array, g: PackedFloat32Array) -> Dictionary:
	var f: Dictionary = FUNCS[func_id]
	var design := {}
	for role in f["roles"]:
		var best := ""; var bs := -1.0
		for m in pool:
			var s := score_role(f["roles"][role], m)
			if s > bs: bs = s; best = m
		if best == "": return {}
		design[role] = best
	return design
