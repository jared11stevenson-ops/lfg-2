extends SceneTree
## Grand Simulation: all 14 classes as competing faction leaders in ONE world until one remains (or the day cap).
## Real Rules module; harness only (a) converts the 12 AI faction leaders + the player faction into class leaders and adds a 14th faction,
## then (b) ticks the sim and lets each leader try its class ability during the Purge via ordinary use_ability commands.
## Usage: godot --headless --path . -s tools/sim_match.gd -- --seed=1 --days=168 --out=/path/result.json
const CLASSES: Array[String] = ["judd", "mira", "bram", "tavi", "pip", "oren", "vex", "sable", "quill", "forge", "nyx", "rook", "dune", "halo"]

func _init() -> void:
	var seed_v: int = 1
	var days: int = 168
	var out: String = ""
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--seed="): seed_v = int(a.get_slice("=", 1))
		elif a.begins_with("--days="): days = int(a.get_slice("=", 1))
		elif a.begins_with("--out="): out = a.get_slice("=", 1)
	var res: Dictionary = run(seed_v, days)
	var txt: String = JSON.stringify(res, "  ")
	if out != "":
		var f := FileAccess.open(out, FileAccess.WRITE)
		f.store_string(txt)
	else:
		print(txt)
	quit()

static func run(seed_v: int, days: int) -> Dictionary:
	var st: MatchState = Setup.build(seed_v, &"lfg:class/judd", {})
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7919 + 13
	# 14th faction on the neutral holding farthest from every owned holding.
	var best_h: int = -1
	var best_d: int = -1
	for hid in st.holdings:
		var h: Dictionary = st.holdings[hid]
		if int(h["owner"]) != -1:
			continue
		var md: int = 999
		for oid in st.holdings:
			if int(st.holdings[oid]["owner"]) >= 0:
				md = mini(md, HexGrid.distance(h["hex"], st.holdings[oid]["hex"]))
		if md > best_d:
			best_d = md
			best_h = int(hid)
	var home: Dictionary = st.holdings[best_h]
	home["owner"] = 13
	home["merchant"] = false
	home["garrison"] = 4
	home["store"] = {"lfg:item/ration": 8, "lfg:item/glowfruit": 6, "lfg:item/saltroot": 2, "lfg:item/coin": 12, "lfg:item/timber": 4}
	home.erase("base_stock")
	var la: Dictionary = Setup.make_actor(0, "ai_leader", 13, "Faction 13 Leader", home["hex"], 60, 5, 1, 100)
	la["id"] = st.new_id()
	st.actors[la["id"]] = la
	var personas: Array[String] = Setup.PERSONAS
	st.factions[13] = {"id": 13, "name": "Wayfarers", "is_ai": true, "leader": la["id"], "home": best_h, "alive": true, "hunger_days": 0, "persona": personas[rng.randi() % 4]}
	# Player faction becomes a bot faction.
	st.factions[0]["is_ai"] = true
	st.factions[0]["persona"] = personas[rng.randi() % 4]
	st.actors[1]["kind"] = "ai_leader"
	st.actors[1]["is_ai"] = true
	st.player_id = -999
	# Shuffle classes over faction slots.
	var order: Array[String] = CLASSES.duplicate()
	for i in range(order.size() - 1, 0, -1):
		var j: int = rng.randi() % (i + 1)
		var t: String = order[i]
		order[i] = order[j]
		order[j] = t
	var meta: Dictionary = {}
	for fid in range(14):
		var cid: String = "lfg:class/" + order[fid]
		var cd: Dictionary = Content.class_def(cid)
		var l: Dictionary = st.actors[int(st.factions[fid]["leader"])]
		var s: Dictionary = cd["stats"]
		l["class_id"] = cid
		l["max_hp"] = int(round(float(s["hp"]) * float(cd.get("mods", {}).get("max_hp_mult", 1.0))))
		l["hp"] = l["max_hp"]
		l["atk"] = int(s["atk"])
		l["def"] = int(s["def"])
		l["max_energy"] = int(s["energy"])
		l["energy"] = float(s["energy"])
		l["inv"] = {}
		for k in (cd["start_kit"] as Dictionary).keys():
			l["inv"][k] = int(cd["start_kit"][k])
		meta[fid] = {"class": order[fid], "persona": st.factions[fid]["persona"], "implemented": bool(cd.get("implemented", false)),
			"elim_day": -1, "kills": 0, "captures": 0, "steals": 0, "ability_uses": 0}
	var abil: Dictionary = {}
	for fid in range(14):
		var cd2: Dictionary = Content.class_def("lfg:class/" + order[fid])
		abil[fid] = String(cd2.get("ability", {}).get("id", ""))
	var timeline: Array = []
	var last_day: int = 0
	var step: float = 2.0
	var bot_t: float = 0.0
	var winner: int = -1
	var guard: int = 0
	while int(st.clock["day"]) <= days and guard < 5000000:
		guard += 1
		var evs: Array = Rules.tick(st, step)
		var day: int = int(st.clock["day"])
		for e in evs:
			var ty: StringName = e.get("type", &"")
			if ty == &"faction_eliminated":
				meta[int(e["faction"])]["elim_day"] = day
			elif ty == &"actor_died":
				var kid: int = int(e.get("killer", -1))
				if st.actors.has(kid) and int(st.actors[kid]["faction"]) >= 0 and st.actors[kid]["kind"] != "enemy" and int(e["faction"]) != int(st.actors[kid]["faction"]):
					var kf: int = int(st.actors[kid]["faction"])
					if meta.has(kf):
						meta[kf]["kills"] += 1
			elif ty == &"holding_captured":
				var cf: int = int(e.get("faction", e.get("by", -1)))
				if meta.has(cf):
					meta[cf]["captures"] += 1
			elif ty == &"steal_resolved" or ty == &"item_stolen":
				var sf: int = int(e.get("faction", -1))
				if meta.has(sf):
					meta[sf]["steals"] += 1
		bot_t += step
		if st.phase == &"PURGE_ACTIVE" and bot_t >= 10.0:
			bot_t = 0.0
			for fid in range(14):
				if not st.factions[fid]["alive"] or abil[fid] == "":
					continue
				var a: Dictionary = st.actors[int(st.factions[fid]["leader"])]
				var r: Dictionary = Rules.apply(st, {"type": &"use_ability", "actor": a["id"], "seq": int(a["last_seq"]) + 1, "args": {"ability": abil[fid]}})
				if r.get("ok", false):
					meta[fid]["ability_uses"] += 1
		if day != last_day:
			last_day = day
			if day % 7 == 1:
				var row: Dictionary = {"day": day, "alive": 0, "holdings": {}}
				for fid in range(14):
					if st.factions[fid]["alive"]:
						row["alive"] += 1
						row["holdings"][order[fid]] = st.holdings_of(fid).size()
				timeline.append(row)
		var alive: Array[int] = []
		for fid in range(14):
			if st.factions[fid]["alive"]:
				alive.append(fid)
		if alive.size() <= 1:
			winner = alive[0] if alive.size() == 1 else -2
			break
	var final_h: Dictionary = {}
	for fid in range(14):
		final_h[order[fid]] = st.holdings_of(fid).size() if st.factions[fid]["alive"] else 0
	return {"seed": seed_v, "end_day": int(st.clock["day"]), "winner": order[winner] if winner >= 0 else "", "winner_faction": winner,
		"solo_last_standing": winner >= 0, "factions": meta, "final_holdings": final_h, "timeline": timeline}
