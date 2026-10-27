class_name TechWalk
extends RefCounted
## Walks the whole tech tree from a class's starting kit with ZERO trades and no other player: a fixpoint over everything a solo leader can do. Used by
## tests/rules/test_techtree.gd and by the docs table generator (run: godot --headless -s tests/rules/tech_walk.gd -- table).
## Sources, and nothing else: the start kit, the home store, crops (a held seed), wild enemy loot, point-of-interest loot (offerings must already be held; arenas are
## beaten solo, see test_guardians), class peace abilities, building work outputs, recipes at stations that stand, quest unlocks of the class's own line and guardian unlocks.
## Merchant stock (base_stock), `trade` and coin from other players are never consulted. Ranks are treated as earnable (the Purge has a solo, pacifist route to deeds).

## Returns {have:{item:round}, built:{building:round}, made:{recipe:round}, grown:{crop:round}, unlocks:{id:round}, sources:{item:[where]}}.
static func walk(class_id: String) -> Dictionary:
	var cd: Dictionary = Content.class_def(class_id)
	var have: Dictionary = {}
	var src: Dictionary = {}
	var built: Dictionary = {}
	var made: Dictionary = {}
	var grown: Dictionary = {}
	var unlocks: Dictionary = {}
	var rnd: int = 0
	var ctx: Dictionary = {"r": 0}      # lambdas copy ints: the round lives in a dictionary
	var add: Callable = func(item: String, where: String) -> bool:
		if not have.has(item):
			have[item] = int(ctx["r"])
			src[item] = [where]
			return true
		if not (src[item] as Array).has(where):
			(src[item] as Array).append(where)
		return false
	for k in (cd["start_kit"] as Dictionary).keys():
		add.call(String(k), "start kit")
	for k in ["lfg:item/timber", "lfg:item/stone", "lfg:item/ration", "lfg:item/coin"]:
		add.call(k, "home store")      # Setup.build: the player's holding starts with timber, stone, rations and coin
	var pa: String = String((cd.get("peace_ability", {}) as Dictionary).get("id", ""))
	var mods: Dictionary = cd.get("mods", {})
	var guardian_unlocks: Array = []
	for t in Content.poi_types().values():
		if t.has("guardian"):
			guardian_unlocks.append(String(t["guardian"]["first"]["unlock"]))
	var line_unlocks: Array = []
	for qid in Content.quest_order():
		var q: Dictionary = Content.quest(String(qid))
		if String(q.get("class", "")) == class_id and String(q.get("reward", {}).get("unlock", "")) != "":
			line_unlocks.append(String(q["reward"]["unlock"]))
	var changed: bool = true
	while changed and rnd < 60:
		changed = false
		rnd += 1
		ctx["r"] = rnd
		if pa == "lfg:ability/mine" or int(mods.get("mine_bonus", 0)) > 0:
			changed = add.call("lfg:item/timber", "mine") or changed
			changed = add.call("lfg:item/stone", "mine") or changed
		if pa == "lfg:ability/forage":
			changed = add.call("lfg:item/mushroom", "forage") or changed
			changed = add.call("lfg:item/spore_sac", "forage") or changed
		if int(mods.get("hunt_meat", 0)) > 0:
			changed = add.call("lfg:item/game_meat", "hunt") or changed
		for e in Content.enemies().values():
			for k in (e.get("loot", {}) as Dictionary).keys():
				changed = add.call(String(k), "enemy " + String(e["name"])) or changed
		changed = add.call("lfg:item/ashmarrow", "Purge raiders") or changed
		for qid in line_unlocks:
			if not unlocks.has(qid):
				unlocks[qid] = rnd
				changed = true
		for t in Content.poi_types().values():
			var ch: Dictionary = t["challenge"]
			if String(ch["kind"]) == "offering":
				var ok: bool = true
				for k in (ch["items"] as Dictionary).keys():
					if not have.has(String(k)):
						ok = false
				if not ok:
					continue
			for k2 in (t.get("loot", {}) as Dictionary).keys():
				if int(t["loot"][k2][1]) > 0:
					changed = add.call(String(k2), String(t["name"])) or changed
			if t.has("guardian"):
				var fu: String = String(t["guardian"]["first"]["unlock"])
				if not unlocks.has(fu):
					unlocks[fu] = rnd
					changed = true
				for k3 in (t["guardian"]["first"]["items"] as Dictionary).keys():
					changed = add.call(String(k3), String(t["name"]) + " (first win)") or changed
		for cp in Content.companions().values():
			# a companion whose feeding route is open (a held food item; the haunt exists in every world) works at a holding: hauls, forages, lays
			var open_way: bool = false
			for o in cp["obtain"]:
				if String(o["kind"]) == "quest" or have.has(String(o.get("item", "-"))):
					open_way = true
			if not open_way:
				continue
			var post: Dictionary = cp.get("post", {})
			if post.has("haul"):
				changed = add.call("lfg:item/timber", "companion " + String(cp["name"])) or changed
				changed = add.call("lfg:item/stone", "companion " + String(cp["name"])) or changed
			if post.has("forage"):
				for k9 in ["lfg:item/mushroom", "lfg:item/spore_sac", "lfg:item/reed_fibre", "lfg:item/amber_resin", "lfg:item/timber"]:
					changed = add.call(k9, "companion " + String(cp["name"])) or changed
			for k10 in (post.get("produce", {}) as Dictionary).keys():
				changed = add.call(String(k10), "companion " + String(cp["name"])) or changed
		for c in Content.crops().values():
			if have.has(String(c["seed"])) and not grown.has(String(c["id"])):
				grown[String(c["id"])] = rnd
				changed = true
			if grown.has(String(c["id"])):
				changed = add.call(String(c["item"]), "grown") or changed
				changed = add.call(String(c["seed"]), "harvest returns a seed") or changed
		for b in Content.buildings().values():
			var bid: String = String(b["id"])
			if built.has(bid):
				continue
			var ru: String = String(b.get("requires_unlock", ""))
			if ru != "" and not unlocks.has(ru):
				continue
			if b.has("upgrade_of") and not built.has(String(b["upgrade_of"])):
				continue
			var ok2: bool = true
			for k4 in (b["cost"] as Dictionary).keys():
				if not have.has(String(k4)):
					ok2 = false
					break
			if ok2:
				built[bid] = rnd
				changed = true
		for bid2 in built.keys():
			var w: Dictionary = Content.building(String(bid2)).get("work", {})
			var inputs_ok: bool = true
			for k5 in (w.get("inputs", {}) as Dictionary).keys():
				if not have.has(String(k5)):
					inputs_ok = false
			if inputs_ok:
				for k6 in (w.get("outputs", {}) as Dictionary).keys():
					changed = add.call(String(k6), "building " + String(Content.building(String(bid2))["name"])) or changed
		for r in Content.recipes().values():
			var rid: String = String(r["id"])
			if made.has(rid):
				continue
			var tag: String = String(r.get("requires_tag", ""))
			if tag != "" and int(mods.get(tag, 0)) < 1:
				continue
			var ru2: String = String(r.get("requires_unlock", ""))
			if ru2 != "" and not unlocks.has(ru2):
				continue
			var st: String = String(r.get("station", ""))
			if st != "" and not built.has(st):
				continue
			var ok3: bool = true
			for k7 in (r["inputs"] as Dictionary).keys():
				if not have.has(String(k7)):
					ok3 = false
					break
			if ok3:
				made[rid] = rnd
				changed = true
				for k8 in (r["outputs"] as Dictionary).keys():
					changed = add.call(String(k8), "recipe " + String(r["name"])) or changed
	return {"have": have, "built": built, "made": made, "grown": grown, "unlocks": unlocks, "sources": src, "rounds": rnd}

## Items no listed source ever produces for this class.
static func unreachable_items(w: Dictionary) -> Array:
	var out: Array = []
	for id in Content.items().keys():
		if not (w["have"] as Dictionary).has(String(id)):
			out.append(String(id))
	out.sort()
	return out
