extends SceneTree
## Grand Simulation harness (pass 2): all 14 classes as competing bot-run faction leaders in ONE 84x54 world until Total Conquest (or the day cap).
## Real Rules module only. The harness converts the player faction and the 12 AI factions into class leaders and adds a 14th faction; after that it
## ONLY ticks. Every leader acts through its class kit via rules/ai_leaders.gd (the same Abilities.use path as a player's use_ability command),
## personas bias the mission mix (rules/ai_factions.gd). No direct state edits during play.
## Usage: godot --headless --path . -s tools/sim_match.gd -- --seed=1 --days=336 --out=/path/result.json
const CLASSES: Array[String] = ["judd", "mira", "bram", "tavi", "pip", "oren", "vex", "sable", "quill", "forge", "nyx", "rook", "dune", "halo"]
const N := 14

func _init() -> void:
	var seed_v: int = 1
	var days: int = 336
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

static func build_world(seed_v: int, rng: RandomNumberGenerator) -> Dictionary:
	var st: MatchState = Setup.build(seed_v, &"lfg:class/judd", {"ai_log": true, "ai_classes": false})
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
	for fid in range(N):
		Setup.set_leader_class(st.actors[int(st.factions[fid]["leader"])], "lfg:class/" + order[fid])
	Standing.init_state(st)
	return {"state": st, "order": order}

static func run(seed_v: int, days: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_v * 7919 + 13
	var w: Dictionary = build_world(seed_v, rng)
	var st: MatchState = w["state"]
	var order: Array = w["order"]
	var meta: Dictionary = {}
	for fid in range(N):
		var cd: Dictionary = Content.class_def("lfg:class/" + order[fid])
		meta[fid] = {"class": order[fid], "persona": st.factions[fid]["persona"], "implemented": bool(cd.get("implemented", false)), "elim_day": -1,
			"elim_cause": "", "leader_kills": 0, "captures": 0, "steals": 0, "deeds": {}, "max_rank": 0, "rank_weeks": [], "nodes": [], "sp_total": 0,
			"marked_weeks": 0, "tributes": 0, "levy_unpaid": 0, "starve_days": 0, "revolts": 0, "idle_bleed": 0, "parties": 0, "party_leader": 0, "joined_raids": 0,
			"peak_holdings": 0, "tree_done_week": -1, "pacified": 0, "retreats": 0, "stealth_jobs": 0, "hunt_kills": 0}
	var last_dmg: Dictionary = {}       # actor id -> last damage tag
	var kill_causes: Dictionary = {}
	var leader_dmg: Dictionary = {}
	var timeline: Array = []
	var hunt_day: int = -1
	var peak_any: int = 0
	var peak_any_day: int = 0
	var last_change_day: int = 0
	var changes_by_week: Dictionary = {}
	var last_day: int = 0
	var step: float = 2.0
	var winner: int = -1
	var conquest_day: int = -1
	var solo_day: int = -1
	var wins: Dictionary = {}
	var guard: int = 0
	var t0: int = Time.get_ticks_msec()
	var tick_ms: float = 0.0
	var tick_n: int = 0
	var leader_of: Dictionary = {}
	for fid in range(N):
		leader_of[int(st.factions[fid]["leader"])] = fid
	while int(st.clock["day"]) <= days and guard < 5000000:
		guard += 1
		var ta: int = Time.get_ticks_usec()
		var evs: Array = Rules.tick(st, step)
		tick_ms += float(Time.get_ticks_usec() - ta) / 1000.0
		tick_n += 1
		var day: int = int(st.clock["day"])
		for e in evs:
			var ty: StringName = e.get("type", &"")
			match ty:
				&"actor_damaged":
					if leader_of.has(int(e["actor"])):
						var dtag: String = String(e.get("tag", ""))
						leader_dmg[dtag] = int(leader_dmg.get(dtag, 0)) + int(e.get("amount", 0))
					last_dmg[int(e["actor"])] = String(e.get("tag", "")) + ":" + str(int(e.get("source", -1)))
				&"faction_eliminated":
					var ef: int = int(e["faction"])
					if meta.has(ef):
						meta[ef]["elim_day"] = day
						if meta[ef]["elim_cause"] == "":
							meta[ef]["elim_cause"] = "holdings_lost"
					last_change_day = day
				&"famine_collapse":
					if meta.has(int(e["faction"])):
						meta[int(e["faction"])]["elim_cause"] = "famine"
				&"actor_died":
					var vid: int = int(e["actor"])
					if leader_of.has(vid):
						var vf: int = int(leader_of[vid])
						var cause: String = String(last_dmg.get(vid, "unknown"))
						var tag: String = cause.get_slice(":", 0)
						var src: int = int(cause.get_slice(":", 1))
						var cf: String = ""
						if st.actors.has(src):
							var sa: Dictionary = st.actors[src]
							cf = "party" if sa["kind"] == "party" else ("leader" if sa["kind"] != "enemy" else "beast")
						var key: String = tag + ("/" + cf if cf != "" else "")
						kill_causes[key] = int(kill_causes.get(key, 0)) + 1
						if meta[vf]["elim_cause"] != "famine":
							meta[vf]["elim_cause"] = key
						var kid: int = int(e.get("killer", -1))
						if st.actors.has(kid) and st.actors[kid]["kind"] != "enemy" and int(st.actors[kid]["faction"]) != vf:
							var kf: int = int(st.actors[kid]["faction"])
							if meta.has(kf):
								meta[kf]["leader_kills"] += 1
				&"holding_captured":
					var cf2: int = int(e.get("by", -1))
					if meta.has(cf2):
						meta[cf2]["captures"] += 1
					last_change_day = day
					changes_by_week[int((day - 1) / 7)] = int(changes_by_week.get(int((day - 1) / 7), 0)) + 1
				&"pacified":
					if meta.has(int(e["faction"])):
						meta[int(e["faction"])]["pacified"] += 1
				&"leader_retreated":
					if meta.has(int(e["faction"])):
						meta[int(e["faction"])]["retreats"] += 1
				&"holding_revolted":
					if meta.has(int(e["faction"])):
						meta[int(e["faction"])]["revolts"] += 1
					last_change_day = day
					changes_by_week[int((day - 1) / 7)] = int(changes_by_week.get(int((day - 1) / 7), 0)) + 1
				&"item_stolen":
					var sf: int = int(e.get("by", -1))
					if meta.has(sf):
						meta[sf]["steals"] += 1
				&"deed":
					var df: int = int(e["faction"])
					if meta.has(df):
						var dd: Dictionary = meta[df]["deeds"]
						dd[e["kind"]] = int(dd.get(e["kind"], 0)) + 1
				&"truce_signed":
					var tf: int = int(e.get("by", -1))
					if meta.has(tf):
						meta[tf]["tributes"] += 1
				&"levy_paid":
					if meta.has(int(e["faction"])) and (int(e["unpaid_rations"]) > 0 or int(e["unpaid_coin"]) > 0):
						meta[int(e["faction"])]["levy_unpaid"] += 1
				&"starving":
					if meta.has(int(e["faction"])):
						meta[int(e["faction"])]["starve_days"] += 1
				&"idle_bleed":
					if meta.has(int(e["faction"])):
						meta[int(e["faction"])]["idle_bleed"] += 1
				&"party_dispatched":
					var pf: int = int(e["by"])
					if meta.has(pf):
						meta[pf]["parties"] += 1
						if int(e.get("leader", -1)) != -1:
							meta[pf]["joined_raids"] += 1
						if String(e.get("mission", "")) == "steal" and int(e.get("leader", -1)) != -1:
							meta[pf]["stealth_jobs"] += 1
				&"victory":
					if conquest_day < 0:
						conquest_day = day
						winner = int(e["faction"])
		if day != last_day:
			last_day = day
			if hunt_day < 0 and AIFactions.hunting(st):
				hunt_day = day
			for fid2 in range(N):
				if st.factions[fid2]["alive"]:
					var nh: int = st.holdings_of(fid2).size()
					if nh > int(meta[fid2]["peak_holdings"]):
						meta[fid2]["peak_holdings"] = nh
					if nh > peak_any:
						peak_any = nh
						peak_any_day = day
					var ldr: Dictionary = st.actors[int(st.factions[fid2]["leader"])]
					if int(meta[fid2]["tree_done_week"]) < 0 and (ldr.get("nodes", []) as Array).size() >= 15:
						meta[fid2]["tree_done_week"] = int((day - 1) / 7)
			if day % 7 == 1:
				var row: Dictionary = {"day": day, "alive": 0, "holdings": {}, "rank": {}, "mark": Standing.mark_of(st)}
				for fid in range(N):
					if st.factions[fid]["alive"]:
						row["alive"] += 1
						row["holdings"][order[fid]] = st.holdings_of(fid).size()
						var rk: int = int(st.factions[fid].get("rank", 0))
						row["rank"][order[fid]] = rk
						meta[fid]["max_rank"] = maxi(int(meta[fid]["max_rank"]), rk)
						(meta[fid]["rank_weeks"] as Array).append(rk)
				var mk: int = Standing.mark_of(st)
				if mk >= 0 and meta.has(mk):
					meta[mk]["marked_weeks"] += 1
				timeline.append(row)
		if conquest_day >= 0:
			break
		var alive_n: int = 0
		for fid in range(N):
			if st.factions[fid]["alive"]:
				alive_n += 1
		if alive_n <= 1 and solo_day < 0:
			solo_day = day
		if alive_n == 0:
			break
	var final_h: Dictionary = {}
	var final_standing: Dictionary = {}
	for fid in range(N):
		final_h[order[fid]] = st.holdings_of(fid).size() if st.factions[fid]["alive"] else 0
		var l: Dictionary = st.actors[int(st.factions[fid]["leader"])]
		meta[fid]["nodes"] = (l.get("nodes", []) as Array).duplicate()
		meta[fid]["sp_total"] = int(l.get("sp_total", 0))
		meta[fid]["final_rank"] = int(st.factions[fid].get("rank", 0))
		meta[fid]["final_standing"] = float(st.factions[fid].get("standing", 0.0))
		meta[fid]["prosperity"] = (st.factions[fid].get("prosperity", {}) as Dictionary).duplicate()
		meta[fid]["deed_counts"] = (st.factions[fid].get("dcount", {}) as Dictionary).duplicate()
		meta[fid]["alive"] = bool(st.factions[fid]["alive"])
		meta[fid]["final_holdings"] = final_h[order[fid]]
	var alive_final: Array = []
	for fid in range(N):
		if st.factions[fid]["alive"]:
			alive_final.append(order[fid])
	var neutral: int = 0
	for h in st.holdings.values():
		if int(h["owner"]) == -1:
			neutral += 1
	var by_week: Array = []
	var wk_n: int = int((int(st.clock["day"]) - 1) / 7) + 1
	for wk in range(wk_n):
		by_week.append(int(changes_by_week.get(wk, 0)))
	return {"seed": seed_v, "end_day": int(st.clock["day"]), "total_conquest": conquest_day >= 0, "conquest_day": conquest_day,
		"winner": order[winner] if winner >= 0 else "", "winner_faction": winner, "solo_day": solo_day, "alive_final": alive_final, "neutral_holdings": neutral,
		"last_territory_change_day": last_change_day, "territory_changes_by_week": by_week, "factions": meta, "final_holdings": final_h,
		"kill_causes": kill_causes, "leader_damage": leader_dmg, "ability_log": st.sim_acc.get("ablog", {}), "timeline": timeline,
		"hunt_day": hunt_day, "peak_holdings_any": peak_any, "peak_holdings_day": peak_any_day, "tick_avg_ms": tick_ms / maxf(1.0, float(tick_n)), "wall_s": float(Time.get_ticks_msec() - t0) / 1000.0, "mark_final": Standing.mark_of(st)}
