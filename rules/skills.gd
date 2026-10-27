class_name Skills
extends RefCounted
## Class skill trees (data/skill_trees.json). Skill points come ONLY from Purge deeds (Standing.record in PURGE_ACTIVE); nothing earns points in PEACE.
## No respec (the tree resets with the match). Node effects are small, capped deltas: most feed Combat.class_mod via actor["skill_fx"].
## Immediate stat nodes (max_hp, atk, def, max_energy) are applied once at unlock.
const IMMEDIATE: Array[String] = ["max_hp", "atk", "def", "max_energy"]
const AB_KEYS: Array[String] = ["ab_cd_pct", "ab_energy_pct", "ab_duration", "ab_power_pct"]

static func tree(class_id: String) -> Dictionary:
	return Content.skill_data()["trees"].get(class_id, {})

static func node(class_id: String, node_id: String) -> Dictionary:
	return tree(class_id).get("nodes", {}).get(node_id, {})

static func caps() -> Dictionary:
	return Content.skill_data()["caps"]

## Unspent points, taken nodes (ids) for the faction leader.
static func points(a: Dictionary) -> int:
	return int(a.get("sp", 0))

static func taken(a: Dictionary) -> Array:
	return a.get("nodes", [])

static func requirement_error(a: Dictionary, nd: Dictionary) -> String:
	for r in nd.get("requires", []):
		if not taken(a).has(String(r)):
			return "node_locked"
	return ""

## "" when the node can be bought now.
static func can_unlock(a: Dictionary, node_id: String) -> String:
	var nd: Dictionary = node(String(a.get("class_id", "")), node_id)
	if nd.is_empty():
		return "unknown_node"
	if taken(a).has(node_id):
		return "already_taken"
	var rq: String = requirement_error(a, nd)
	if rq != "":
		return rq
	if points(a) < int(nd["cost"]):
		return "not_enough_points"
	return ""

## Command handler: unlock_skill {node}
static func unlock(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	if a["kind"] == "enemy" or a["kind"] == "party":
		return "unknown_actor"
	var id: String = CmdUtil.s(args.get("node", ""))
	var err: String = can_unlock(a, id)
	if err != "":
		return err
	apply_node(state, a, id, events)
	return ""

static func apply_node(state: MatchState, a: Dictionary, node_id: String, events: Array) -> void:
	var nd: Dictionary = node(String(a["class_id"]), node_id)
	a["sp"] = points(a) - int(nd["cost"])
	if not a.has("nodes"):
		a["nodes"] = []
	(a["nodes"] as Array).append(node_id)
	if not a.has("skill_fx"):
		a["skill_fx"] = {}
	var fx: Dictionary = a["skill_fx"]
	var cp: Dictionary = caps()
	for k in (nd.get("effects", {}) as Dictionary).keys():
		var before: float = float(fx.get(k, 0.0))
		var want: float = before + float(nd["effects"][k])
		if cp.has(k):
			want = clampf(want, float(cp[k][0]), float(cp[k][1]))
		var applied: float = want - before
		if IMMEDIATE.has(k):
			_apply_immediate(a, String(k), int(round(applied)))
		fx[k] = _num(want)
	events.append({"type": &"skill_unlocked", "actor": a["id"], "faction": a["faction"], "node": node_id, "name": nd.get("name", node_id), "branch": nd.get("branch", ""), "ai": bool(a.get("is_ai", false))})

static func _num(v: float) -> Variant:
	return int(v) if v == floorf(v) else MatchState.q(v)

static func _apply_immediate(a: Dictionary, key: String, delta: int) -> void:
	match key:
		"max_hp":
			a["max_hp"] = maxi(1, int(a["max_hp"]) + delta)
			a["hp"] = clampi(int(a["hp"]) + delta, 1, int(a["max_hp"]))
		"atk":
			a["atk"] = maxi(0, int(a["atk"]) + delta)
		"def":
			a["def"] = maxi(0, int(a["def"]) + delta)
		"max_energy":
			a["max_energy"] = maxi(10, int(a["max_energy"]) + delta)

## Skill points granted by Standing.record (PURGE_ACTIVE only; the caller guards the phase). AI factions spend them at once.
static func grant(state: MatchState, fid: int, sp: int, kind: String, events: Array) -> void:
	if sp <= 0 or state.phase != &"PURGE_ACTIVE":
		return
	var f: Dictionary = state.factions.get(fid, {})
	var l: Dictionary = state.actors.get(int(f.get("leader", -1)), {})
	if l.is_empty() or not l["alive"]:
		return
	l["sp"] = points(l) + sp
	l["sp_total"] = int(l.get("sp_total", 0)) + sp
	events.append({"type": &"skill_points", "actor": l["id"], "faction": fid, "gained": sp, "points": l["sp"], "kind": kind, "ai": bool(f["is_ai"])})
	if bool(f["is_ai"]):
		auto_buy(state, l, events)

## Bot spending: prefer the persona/class branch, cheapest available node first. Deterministic.
static func auto_buy(state: MatchState, a: Dictionary, events: Array) -> void:
	var t: Dictionary = tree(String(a["class_id"]))
	if t.is_empty():
		return
	var f: Dictionary = state.factions.get(int(a["faction"]), {})
	var pref: Array = branch_pref(String(f.get("persona", "")), String(a["class_id"]))
	var guard: int = 0
	while guard < 6:
		guard += 1
		var best: String = ""
		var bscore: int = 1 << 30
		for id in t["order"]:
			if can_unlock(a, String(id)) != "":
				continue
			var nd: Dictionary = t["nodes"][id]
			var s: int = pref.find(String(nd["branch"])) * 100 + int(nd["cost"]) * 10 + (5 if bool(nd.get("drawback", false)) else 0)
			if s < bscore:
				bscore = s
				best = String(id)
		if best == "":
			return
		apply_node(state, a, best, events)

static func branch_pref(persona: String, class_id: String) -> Array:
	var warlike: bool = ["bram", "rook", "forge", "pip", "vex", "sable", "nyx"].has(class_id.get_slice("/", 1))
	if persona == "raider" or (warlike and persona != "turtle"):
		return ["purge", "hybrid", "economy"]
	if persona == "turtle":
		return ["hybrid", "purge", "economy"]
	return ["economy", "hybrid", "purge"]

## Scales an ability's numbers by the leader's ab_* skill effects. Returns the same dict when there is nothing to apply.
static func tune_ability(a: Dictionary, ab: Dictionary) -> Dictionary:
	var fx: Dictionary = a.get("skill_fx", {})
	if a.has("quest_fx"):
		fx = fx.duplicate()
		for k0 in (a["quest_fx"] as Dictionary).keys():
			fx[k0] = float(fx.get(k0, 0.0)) + float(a["quest_fx"][k0])
	if fx.is_empty():
		return ab
	var any: bool = false
	for k in AB_KEYS:
		if fx.has(k):
			any = true
			break
	if not any:
		return ab
	var o: Dictionary = ab.duplicate()
	if fx.has("ab_cd_pct"):
		o["cooldown"] = maxf(1.0, float(ab["cooldown"]) * (1.0 - float(fx["ab_cd_pct"]) / 100.0))
	if fx.has("ab_energy_pct"):
		o["energy"] = maxf(1.0, float(ab["energy"]) * (1.0 - float(fx["ab_energy_pct"]) / 100.0))
	if fx.has("ab_duration") and float(ab.get("duration", 0.0)) > 0.0:
		o["duration"] = float(ab["duration"]) + float(fx["ab_duration"])
	if fx.has("ab_power_pct"):
		var m: float = 1.0 + float(fx["ab_power_pct"]) / 100.0
		for k in ["heal", "dps", "damage"]:
			if ab.has(k):
				o[k] = maxi(1, int(round(float(ab[k]) * m)))
		if ab.has("strike_mult"):
			o["strike_mult"] = float(ab["strike_mult"]) * m
	return o

# ------------------------------------------------------------------ view model (read only; ui/skill_tree_panel.gd renders it)
const EFFECT_TEXT: Dictionary = {
	"growth_pct": "%+d%% crop growth", "yield_bonus": "%+d harvest yield", "plot_slots": "%+d plot slots", "ration_bonus": "%+d ration per batch",
	"max_hp": "%+d max health", "max_energy": "%+d max energy", "atk": "%+d attack", "def": "%+d defence", "ab_cd_pct": "%+d%% shorter ability cooldown",
	"ab_energy_pct": "%+d%% cheaper ability", "ab_duration": "%+d s ability duration", "ab_power_pct": "%+d%% ability power", "levy_pct": "%+d%% Purge Levy cut",
	"upkeep_pct": "%+d%% lower upkeep", "supply_range": "%+d supply range", "garrison_cap": "%+d garrison cap", "steal_bonus": "%+.2f steal chance",
	"dmg_taken_mult": "%+.2f damage taken", "buy_mult": "%+.2f buying price", "sell_mult": "%+.2f selling price", "walk_mult": "%+.2f walk speed",
	"carry_cap": "%+d carry", "mine_bonus": "%+d mining", "build_cost_mult": "%+.2f build cost"}

static func effect_text(key: String, v: float) -> String:
	var f: String = String(EFFECT_TEXT.get(key, key + " %+.2f"))
	return f % (int(v) if f.contains("%+d") else v)

## {class_id, tree_name, points, taken, total, branches:{economy:[row], purge:[row], hybrid:[row]}}
## row: {id, name, branch, cost, requires:[names], taken, state:"taken"|"available"|"locked"|"unaffordable", drawback, effects:[text]}
static func panel_model(a: Dictionary) -> Dictionary:
	var cid: String = String(a.get("class_id", ""))
	var t: Dictionary = tree(cid)
	var out: Dictionary = {"class_id": cid, "tree_name": String(t.get("name", "")), "points": points(a), "taken": taken(a).size(), "total": (t.get("order", []) as Array).size(),
		"branches": {"economy": [], "purge": [], "hybrid": []}}
	for id in t.get("order", []):
		var nd: Dictionary = t["nodes"][id]
		var st: String = "taken"
		if not taken(a).has(String(id)):
			if requirement_error(a, nd) != "":
				st = "locked"
			elif points(a) < int(nd["cost"]):
				st = "unaffordable"
			else:
				st = "available"
		var reqs: Array = []
		for r in nd.get("requires", []):
			reqs.append(String(t["nodes"][r]["name"]))
		var fx: Array = []
		for k in (nd.get("effects", {}) as Dictionary).keys():
			fx.append(effect_text(String(k), float(nd["effects"][k])))
		out["branches"][String(nd["branch"])].append({"id": String(id), "name": String(nd["name"]), "branch": String(nd["branch"]), "cost": int(nd["cost"]), "requires": reqs,
			"taken": st == "taken", "state": st, "drawback": bool(nd.get("drawback", false)), "effects": fx})
	return out
