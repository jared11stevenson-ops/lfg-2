class_name Guardians
extends RefCounted
## Read-only helpers for the region guardians (data/guardians.json; the fight itself lives in enemy_ai.gd / pois.gd). View models for the HUD boss bar, the
## journal progress list and toasts. Nothing here mutates state.

## The living guardian nearest the actor within `max_d` hexes -> {id, name, hp, max_hp, phase, phases, biome, attack, windup_left} or {} (HUD boss bar).
static func nearest_boss(state: MatchState, a: Dictionary, max_d: int = 14) -> Dictionary:
	var best: Dictionary = {}
	var bd: int = 1 << 30
	for id in state.actors.keys():
		var e: Dictionary = state.actors[id]
		if e["kind"] != "enemy" or not e["alive"]:
			continue
		var d: Dictionary = Content.enemy(String(e["archetype"]))
		if not bool(d.get("boss", false)):
			continue
		var dist: int = HexGrid.distance(a["hex"], e["hex"])
		if dist > max_d or dist >= bd:
			continue
		bd = dist
		var ai: Dictionary = e["ai"]
		var left: float = 0.0
		if String(ai.get("state", "")) == "windup":
			left = maxf(0.0, float(ai.get("t_hit", 0.0)) - float(state.clock["elapsed"]))
		best = {"id": int(id), "name": String(d["name"]), "hp": int(e["hp"]), "max_hp": int(e["max_hp"]), "phase": int(ai.get("phase", 0)), "phases": (d.get("phases", []) as Array).size(),
			"biome": String(d.get("guardian", "")), "attack": String(ai.get("attack", "")) if String(ai.get("state", "")) in ["windup", "active"] else "", "windup_left": left, "dist": dist}
	return best

## One row per guardian, in biome order: {biome, name, arena, beaten, discovered, material, unlock, gates}. `gates` says what its first defeat opens.
static func progress(state: MatchState, a: Dictionary) -> Array:
	var out: Array = []
	var beaten: Array = a.get("guardians", [])
	for gid in Content.guardian_order():
		var g: Dictionary = Content.enemy(String(gid))
		var arena: Dictionary = Content.poi_types().get("lfg:poi/arena_" + String(g["guardian"]), {})
		var first: Dictionary = arena.get("guardian", {}).get("first", {})
		var mat: String = ""
		for k in (first.get("items", {}) as Dictionary).keys():
			if int(Content.item(String(k)).get("tier", 0)) == 4:
				mat = String(k)
		var disc: bool = false
		for p in Pois.all(state):
			if String(p["type"]) == String(arena.get("id", "")) and Pois.seen(a, int(p["id"])):
				disc = true
		var gates: Array = []
		var unlock: String = String(first.get("unlock", ""))
		for b in Content.buildings().values():
			if String(b.get("requires_unlock", "")) == unlock:
				gates.append(String(b["name"]))
		for b2 in Content.buildings().values():
			if (b2["cost"] as Dictionary).has(mat) and not gates.has(String(b2["name"])):
				gates.append(String(b2["name"]))
		out.append({"biome": String(g["guardian"]), "name": String(g["name"]), "arena": String(arena.get("name", "")), "beaten": beaten.has(String(g["guardian"])), "discovered": disc,
			"material": item_name(mat), "unlock": unlock, "gates": gates})
	return out

static func item_name(item: String) -> String:
	return String(Content.item(item).get("name", item.get_slice("/", 1).capitalize()))

static func toast_for(e: Dictionary) -> Dictionary:
	match String(e.get("type", "")):
		"boss_phase":
			return {"title": String(e.get("name", "The guardian")) + " changes", "body": String(e.get("text", "")), "kind": "warn"}
		"guardian_defeated":
			if bool(e.get("first", false)):
				return {"title": "%s defeated" % String(e.get("name", "")), "body": "A new tier opens. Check BUILD.", "kind": "good"}
			return {"title": "%s beaten again" % String(e.get("name", "")), "body": "The weekly spoils are yours.", "kind": "good"}
	return {}
