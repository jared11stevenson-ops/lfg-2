extends RulesTestBase
## Class skill trees (data/skill_trees.json): shape, gating by Purge-deed points, caps, pacifist and solo routes, no respec.

const BRANCHES: Array[String] = ["economy", "purge", "hybrid"]
## effects whose NEGATIVE value hurts the leader, and effects whose POSITIVE value hurts
const BAD_WHEN_NEGATIVE: Array[String] = ["max_hp", "max_energy", "atk", "def", "yield_bonus", "plot_slots", "sell_mult", "walk_mult"]
const BAD_WHEN_POSITIVE: Array[String] = ["dmg_taken_mult", "buy_mult"]

func _purge(s: MatchState) -> void:
	warp(s, 7, 0.6)

func _grant(s: MatchState, n: int) -> void:
	_purge(s)
	s.actors[1]["sp"] = int(s.actors[1].get("sp", 0)) + n

func test_fourteen_original_trees_three_branches_each() -> void:
	var classes: Array = Content.classes().keys()
	eq(classes.size(), 14, "14 classes")
	for cid in classes:
		var t: Dictionary = Skills.tree(String(cid))
		check(not t.is_empty(), "%s has a tree" % cid)
		var nodes: Dictionary = t["nodes"]
		check(nodes.size() >= 15, "%s: ~15 nodes (%d)" % [cid, nodes.size()])
		var per: Dictionary = {}
		for id in nodes.keys():
			var b: String = String(nodes[id]["branch"])
			check(BRANCHES.has(b), "%s branch %s" % [id, b])
			per[b] = int(per.get(b, 0)) + 1
			check(String(id).begins_with(String(cid).get_slice("/", 1) + "."), "node ids are namespaced by class (%s)" % id)
		for b in BRANCHES:
			check(int(per.get(b, 0)) >= 4, "%s has a %s branch of 4+ nodes" % [cid, b])
		check(String(t["name"]) != "", "tree is named")
	# original: no two trees share a node name set
	var names: Dictionary = {}
	for cid in classes:
		var key: String = ",".join(Skills.tree(String(cid))["nodes"].values().map(func(n: Dictionary) -> String: return n["name"]))
		check(not names.has(key), "tree names are unique")
		names[key] = true

func test_drawback_nodes_are_costed_and_really_hurt() -> void:
	for cid in Content.classes().keys():
		var drawbacks: int = 0
		for n in Skills.tree(String(cid))["nodes"].values():
			if not bool(n.get("drawback", false)):
				continue
			drawbacks += 1
			check(int(n["cost"]) >= 3, "%s drawback nodes are not cheap" % n["id"])
			var hurts: bool = false
			var helps: bool = false
			for k in n["effects"].keys():
				var v: float = float(n["effects"][k])
				if (BAD_WHEN_NEGATIVE.has(k) and v < 0.0) or (BAD_WHEN_POSITIVE.has(k) and v > 0.0):
					hurts = true
				else:
					helps = true
			check(hurts and helps, "%s trades a real cost for a real benefit" % n["id"])
		check(drawbacks >= 2, "%s has costed drawback nodes (%d)" % [cid, drawbacks])

func test_prerequisites_form_a_reachable_acyclic_graph() -> void:
	for cid in Content.classes().keys():
		var nodes: Dictionary = Skills.tree(String(cid))["nodes"]
		var taken: Dictionary = {}
		var progress: bool = true
		while progress:
			progress = false
			for id in nodes.keys():
				if taken.has(id):
					continue
				var ok: bool = true
				for r in nodes[id]["requires"]:
					check(nodes.has(r), "%s requires an existing node %s" % [id, r])
					if not taken.has(r):
						ok = false
				if ok:
					taken[id] = true
					progress = true
		eq(taken.size(), nodes.size(), "%s: every node is reachable from the roots" % cid)
		for b in BRANCHES:
			var roots: int = 0
			for n in nodes.values():
				if n["branch"] == b and (n["requires"] as Array).is_empty():
					roots += 1
					eq(int(n["cost"]), 1, "roots are the cheapest buy")
			check(roots >= 1, "%s: a root in every branch" % cid)

func test_flat_stat_nodes_are_small_and_the_whole_tree_stays_capped() -> void:
	var caps: Dictionary = Skills.caps()
	for cid in Content.classes().keys():
		var s: MatchState = quiet(String(cid))
		var a: Dictionary = s.actors[1]
		var atk0: int = int(a["atk"])
		var def0: int = int(a["def"])
		var hp0: int = int(a["max_hp"])
		a["sp"] = 999
		var events: Array = []
		var order: Array = Skills.tree(String(cid))["order"]
		var guard: int = 0
		while guard < 40:
			guard += 1
			var any: bool = false
			for id in order:
				if Skills.can_unlock(a, String(id)) == "":
					Skills.apply_node(s, a, String(id), events)
					any = true
			if not any:
				break
		eq((a["nodes"] as Array).size(), order.size(), "%s: whole tree bought" % cid)
		for k in a["skill_fx"].keys():
			check(caps.has(k), "%s: effect %s has a cap" % [cid, k])
			if caps.has(k):
				var v: float = float(a["skill_fx"][k])
				check(v >= float(caps[k][0]) - 1e-6 and v <= float(caps[k][1]) + 1e-6, "%s: %s=%s within caps" % [cid, k, str(v)])
		check(int(a["atk"]) - atk0 <= 2 and int(a["def"]) - def0 <= 1, "%s: flat attack/defence nodes are tiny (+%d/+%d)" % [cid, int(a["atk"]) - atk0, int(a["def"]) - def0])
		check(int(a["max_hp"]) - hp0 <= 20, "%s: health nodes capped" % cid)
		check(float(Combat.class_mod(a, "dmg_taken_mult", 1.0)) <= 1.4, "damage taken multiplier stays sane")

func test_no_node_is_reachable_without_points() -> void:
	var s: MatchState = quiet("lfg:class/bram")
	_purge(s)
	var before: String = snap(s)
	var order: Array = Skills.tree("lfg:class/bram")["order"]
	for id in order:
		var r: Dictionary = cmd(s, "unlock_skill", {"node": id})
		check(not r["ok"], "%s must not unlock with zero points" % id)
		var nd: Dictionary = Skills.node("lfg:class/bram", String(id))
		eq(r["error"], "not_enough_points" if (nd["requires"] as Array).is_empty() else "node_locked", "reason for %s" % id)
	eq(snap(s), before, "failed unlocks mutate nothing")
	eq(cmd(s, "unlock_skill", {"node": "nope"})["error"], "unknown_node", "unknown node")
	eq(cmd(s, "unlock_skill", {"node": "judd.e1"})["error"], "unknown_node", "another class's node is unknown")
	eq(cmd(s, "unlock_skill", {})["error"], "unknown_node", "missing arg")

func test_points_come_only_from_purge_deeds() -> void:
	var s: MatchState = quiet()
	var all: Array = tick_all(s, 60.0 * 20.0, 5.0)
	eq(int(s.actors[1].get("sp", 0)), 0, "three weeks of play with no Purge deed: zero points")
	eq(count_type(all, "skill_points"), 0, "no skill_points events")
	# PEACE: nothing records, nothing grants
	var s2: MatchState = quiet()
	var ev: Array = []
	check(not Standing.record(s2, 0, "capture", ev), "no deed in PEACE")
	Skills.grant(s2, 0, 5, "capture", ev)
	eq(int(s2.actors[1].get("sp", 0)), 0, "grant refuses outside PURGE_ACTIVE")
	warp(s2, 6, 0.9)
	Skills.grant(s2, 0, 5, "capture", ev)
	eq(int(s2.actors[1].get("sp", 0)), 0, "not even in WARNING")
	_purge(s2)
	Skills.grant(s2, 0, 3, "capture", ev)
	eq(int(s2.actors[1]["sp"]), 3, "PURGE_ACTIVE grants (up to the weekly cap of %d)" % int(Standing.cfg()["skills"]["week_cap"]))
	# trading, crafting, farming earn nothing
	var s3: MatchState = quiet()
	give(s3, 1, {"lfg:item/glowfruit": 10})
	cmd(s3, "craft", {"recipe": "lfg:recipe/ration_glowfruit"})
	cmd(s3, "plant", {"crop": "lfg:crop/glowfruit", "hex": neighbor_plot(s3, 0)})
	eq(int(s3.actors[1].get("sp", 0)), 0, "economy actions earn no points")

func test_unlock_flow_cost_prerequisites_events_and_no_double_buy() -> void:
	var s: MatchState = quiet("lfg:class/judd")
	_grant(s, 5)
	eq(cmd(s, "unlock_skill", {"node": "judd.e2"})["error"], "node_locked", "e2 needs e1")
	var r: Dictionary = cmd(s, "unlock_skill", {"node": "judd.e1"})
	check(r["ok"], "root: %s" % r["error"])
	eq(count_type(r["events"], "skill_unlocked"), 1, "event")
	eq(s.actors[1]["sp"], 4, "cost 1 deducted (roots keep their price)")
	eq(cmd(s, "unlock_skill", {"node": "judd.e1"})["error"], "already_taken", "no double buy")
	eq(Skills.cost_of(Skills.node("lfg:class/judd", "judd.e2")), 4, "a data cost of 2 now costs 4 (skills.cost_mult)")
	check(cmd(s, "unlock_skill", {"node": "judd.e2"})["ok"], "e2 now (cost 4)")
	eq(s.actors[1]["sp"], 0, "all spent")
	eq(cmd(s, "unlock_skill", {"node": "judd.e3"})["error"], "not_enough_points", "broke")
	eq((s.actors[1]["nodes"] as Array).size(), 2, "two nodes")
	var m: Dictionary = Standing.hud_model(s, 0)
	eq(m["nodes_taken"], 2, "hud model counts nodes")

func test_there_is_no_respec() -> void:
	var s: MatchState = quiet("lfg:class/judd")
	_grant(s, 3)
	cmd(s, "unlock_skill", {"node": "judd.e1"})
	var r: Dictionary = cmd(s, "respec", {})
	eq(r["error"], "unknown_command", "respec does not exist")
	check(not Rules.COMMAND_TYPES.has(&"respec"), "not in the command list")
	eq((s.actors[1]["nodes"] as Array).size(), 1, "node stays")
	tick_all(s, 60.0 * 8.0, 5.0)
	eq((s.actors[1]["nodes"] as Array).size(), 1, "node stays across weeks (it resets only with the match)")

func test_node_effects_reach_the_rules() -> void:
	var s: MatchState = quiet("lfg:class/judd")
	var hp0: int = int(s.actors[1]["max_hp"])
	_grant(s, 20)
	for id in ["judd.p1", "judd.e1", "judd.e2"]:
		check(cmd(s, "unlock_skill", {"node": id})["ok"], id)
	eq(int(s.actors[1]["max_hp"]), hp0 + 6, "max_hp node is applied once")
	eq(int(Combat.class_mod(s.actors[1], "yield_bonus", 0)), 2, "Judd's +1 yield and the node's +1 stack through class_mod")
	check(Standing.skill_fx(s, 0, "growth_pct") >= 5.0, "growth feeds Standing.growth_frac")
	var a0: Dictionary = Content.class_def("lfg:class/judd")["ability"]
	check(cmd(s, "unlock_skill", {"node": "judd.p2"})["ok"], "ability cooldown node")
	var tuned: Dictionary = Skills.tune_ability(s.actors[1], a0)
	check(float(tuned["cooldown"]) < float(a0["cooldown"]), "ability_cd_pct shortens the cooldown (%s < %s)" % [str(tuned["cooldown"]), str(a0["cooldown"])])
	eq(float(a0["cooldown"]), 30.0, "the shared data dictionary is untouched")
	# the tuned cooldown is what use_ability charges
	check(cmd(s, "use_ability", {"ability": a0["id"]})["ok"], "ability used")
	var left: float = float(s.actors[1]["cd"]["ab:" + String(a0["id"])]) - float(s.clock["elapsed"])
	check(left < 30.0, "cooldown applied is the shortened one (%f)" % left)

func test_drawback_node_applies_both_sides() -> void:
	var s: MatchState = quiet("lfg:class/judd")
	var node: Dictionary = Skills.node("lfg:class/judd", "judd.p4")
	check(bool(node["drawback"]), "judd.p4 is a drawback node")
	var e0: int = int(s.actors[1]["max_energy"])
	s.actors[1]["sp"] = 99
	for id in ["judd.p1", "judd.p2", "judd.p4"]:
		Skills.apply_node(s, s.actors[1], id, [])
	check(int(s.actors[1]["max_energy"]) < e0, "the drawback bites (max energy %d -> %d)" % [e0, int(s.actors[1]["max_energy"])])
	check(float(s.actors[1]["skill_fx"]["ab_power_pct"]) > 0.0, "and the boon is there")

func test_each_tree_has_a_pacifist_deed_route() -> void:
	var defs: Dictionary = Standing.cfg()["deeds"]
	var pac_sp: int = 0
	for k in defs.keys():
		if not bool(defs[k]["fight"]):
			pac_sp += int(defs[k]["sp"]) * int(defs[k]["cap"])
	var wk_cap: int = int(Standing.cfg()["skills"]["week_cap"])
	check(pac_sp >= wk_cap, "non-fighting deeds can pay %d points per Purge, enough to reach the weekly cap of %d" % [pac_sp, wk_cap])
	for cid in Content.classes().keys():
		var total: int = 0
		var econ: int = 0
		for n in Skills.tree(String(cid))["nodes"].values():
			total += Skills.cost_of(n)
			if n["branch"] == "economy":
				econ += Skills.cost_of(n)
		var weeks: int = int(ceil(float(total) / float(mini(pac_sp, wk_cap))))
		check(weeks <= 30, "%s: the whole tree costs %d points = %d Purges of pure scouting/escorting/brokering/healing at the weekly cap" % [cid, total, weeks])
		check(int(ceil(float(econ) / float(mini(pac_sp, wk_cap)))) <= 12, "%s: the economy branch alone in <= 12 Purges" % cid)
	# and it works through real commands for the pure pacifist class
	var s: MatchState = quiet("lfg:class/halo")
	var rv: int = s.holdings_of(3)[0]
	s.actors[1]["hex"] = s.holdings[rv]["hex"] + HexGrid.DIRS[0]
	_purge(s)
	var r: Dictionary = cmd(s, "scout", {"holding": rv})
	check(r["ok"], "halo scouts: %s" % r["error"])
	check(int(s.actors[1]["sp"]) >= 1, "halo earned a point without harming anyone")
	check(cmd(s, "unlock_skill", {"node": "halo.e1"})["ok"], "and bought a root of its economy branch")

func test_trees_are_completable_solo_in_a_lifetime_and_ask_nothing_of_anyone_else() -> void:
	var defs: Dictionary = Standing.cfg()["deeds"]
	var pac_sp: int = 0
	for k in defs.keys():
		if not bool(defs[k]["fight"]):
			pac_sp += int(defs[k]["sp"]) * int(defs[k]["cap"])
	for cid in Content.classes().keys():
		var total: int = 0
		for n in Skills.tree(String(cid))["nodes"].values():
			total += Skills.cost_of(n)
			for k in (n["effects"] as Dictionary).keys():
				check(Skills.caps().has(k), "%s effect %s is a known solo stat" % [n["id"], k])
			for r in n["requires"]:
				check(String(r).begins_with(String(n["id"]).get_slice(".", 0) + "."), "%s only requires its own tree's nodes" % n["id"])
			check(not (n as Dictionary).has("trade") and not (n as Dictionary).has("ally") and not (n as Dictionary).has("friend"), "no social requirement field on %s" % n["id"])
		check(total <= mini(pac_sp, int(Standing.cfg()["skills"]["week_cap"])) * 48, "%s: a 48-week match of solo pacifist play pays for the whole tree (%d points)" % [cid, total])

func test_ai_leaders_spend_their_points_on_a_branch_that_fits_their_persona() -> void:
	var s: MatchState = quiet()
	_purge(s)
	var l: Dictionary = Standing.leader_of(s, 4)
	s.factions[4]["persona"] = "raider"
	var ev: Array = []
	Skills.grant(s, 4, 6, "capture", ev)
	check(count_type(ev, "skill_unlocked") >= 1, "AI factions spend at once")
	var first: String = String(ev.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "skill_unlocked")[0]["branch"])
	eq(first, "purge", "raiders favour the Purge branch")
	var t: MatchState = quiet()
	_purge(t)
	t.factions[5]["persona"] = "trader"
	var ev2: Array = []
	Skills.grant(t, 5, 6, "scout", ev2)
	eq(String(ev2.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "skill_unlocked")[0]["branch"]), "economy", "traders favour the economy branch")

func test_skill_state_round_trips() -> void:
	var s: MatchState = quiet("lfg:class/mira")
	_grant(s, 6)
	cmd(s, "unlock_skill", {"node": "mira.p1"})
	cmd(s, "unlock_skill", {"node": "mira.e1"})
	var s2: MatchState = MatchState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	eq(s2.actors[1]["nodes"], s.actors[1]["nodes"], "nodes")
	eq(int(s2.actors[1]["max_hp"]), int(s.actors[1]["max_hp"]), "max_hp")
	eq(s2.actors[1]["skill_fx"].keys().size(), s.actors[1]["skill_fx"].keys().size(), "fx keys")
	eq(float(Combat.class_mod(s2.actors[1], "max_hp_mult", 1.0)), float(Combat.class_mod(s.actors[1], "max_hp_mult", 1.0)), "class_mod identical")
