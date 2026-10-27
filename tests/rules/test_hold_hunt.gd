extends RulesTestBase
## Pass 3 fixes from the pass-2 simulation: skill pacing, Pacify (holding a dozen holdings), the last-rival hunt, leader escape, stealth thieves, Warding Aura trigger.

func _ai(sd: int = 11) -> MatchState:
	return mk("lfg:class/judd", sd, {"wild_enemies": false})

func _purge(s: MatchState) -> void:
	warp(s, 7, 0.55)

# ------------------------------------------------------------ skills: slower trees
func test_node_costs_scale_but_roots_stay_cheap() -> void:
	var t: Dictionary = Skills.tree("lfg:class/judd")
	var roots: int = 0
	for id in t["order"]:
		var nd: Dictionary = t["nodes"][id]
		var c: int = Skills.cost_of(nd)
		if int(nd["cost"]) <= 1:
			eq(c, 1, "%s: roots stay 1" % id)
			roots += 1
		else:
			eq(c, int(nd["cost"]) * 2, "%s: x2" % id)
	eq(roots, 3, "three roots")
	var s: MatchState = quiet()
	s.actors[1]["sp"] = 1
	var m: Dictionary = Skills.panel_model(s.actors[1])
	var costs: Array = []
	for b in m["branches"].values():
		for r in b:
			costs.append(int(r["cost"]))
	costs.sort()
	check(costs[-1] == 8 and costs[0] == 1, "panel shows the real prices (%d..%d)" % [costs[0], costs[-1]])
	var total: int = 0
	for c in costs:
		total += c
	check(total >= 60, "a whole tree costs %d points" % total)

func test_buying_charges_the_scaled_price() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	a["sp"] = 1
	check(cmd(s, "unlock_skill", {"node": "judd.e1"})["ok"], "root for 1")
	var nd: Dictionary = {}
	for id in Skills.tree("lfg:class/judd")["order"]:
		var n: Dictionary = Skills.node("lfg:class/judd", id)
		if (n.get("requires", []) as Array) == ["judd.e1"] and int(n["cost"]) == 2:
			nd = n
			break
	a["sp"] = 3
	eq(cmd(s, "unlock_skill", {"node": nd["id"]})["error"], "not_enough_points", "3 points do not buy a 2-cost node any more")
	a["sp"] = 4
	check(cmd(s, "unlock_skill", {"node": nd["id"]})["ok"], "4 do")
	eq(int(a["sp"]), 0, "all four spent")

func test_weekly_skill_point_cap_and_resets_each_week() -> void:
	var s: MatchState = quiet()
	_purge(s)
	var ev: Array = []
	for i in range(12):
		s.factions[0]["pcap"] = {}
		Standing.record(s, 0, "kill_leader", ev)
	var cap: int = int(Standing.cfg()["skills"]["week_cap"])
	eq(int(s.actors[1]["sp"]), cap, "at most %d points a week (12 leader kills would be 72)" % cap)
	check(Standing.deed_score(s, s.factions[0]) > 100.0, "the deeds still count for Standing")
	warp(s, 14, 0.55)
	s.factions[0]["pcap"] = {}
	Standing.record(s, 0, "kill_leader", ev)
	eq(int(s.actors[1]["sp"]), cap + mini(6, cap), "a new week, a new allowance (the next kill pays up to the cap again)")

func test_scout_and_escort_pay_one_deed_a_purge() -> void:
	eq(int(Standing.deed_def("scout")["cap"]), 1, "scout cap")
	eq(int(Standing.deed_def("escort")["cap"]), 1, "escort cap")
	check(int(Standing.deed_def("scout")["standing"]) <= 1 and int(Standing.deed_def("escort")["standing"]) <= 1, "light standing weights")

# ------------------------------------------------------------ pacify
func test_pacify_command_steadies_a_holding_and_costs_stores() -> void:
	var s: MatchState = quiet()
	var h: Dictionary = home(s)
	h["stab"] = 30
	Inv.add_all(h["store"], {"lfg:item/ration": 5, "lfg:item/coin": 10})
	var r0: int = Inv.count(h["store"], "lfg:item/ration")
	var c0: int = Inv.count(h["store"], "lfg:item/coin")
	var r: Dictionary = cmd(s, "pacify", {"holding": 1})
	check(r["ok"] and count_type(r["events"], "pacified") == 1, "pacify: %s" % r["error"])
	eq(int(h["stab"]), 60, "stability +30")
	check(Standing.pacified(s, h), "pacified")
	eq(Inv.count(h["store"], "lfg:item/ration"), r0 - 1 * int(h["tier"]), "rations paid per tier")
	eq(Inv.count(h["store"], "lfg:item/coin"), c0 - 2 * int(h["tier"]), "coin paid per tier")
	eq(cmd(s, "pacify", {"holding": 1})["error"], "already_pacified", "not twice in a row")
	eq(cmd(s, "pacify", {"holding": 999})["error"], "unknown_holding", "unknown")
	eq(cmd(s, "pacify", {"holding": 2})["error"], "not_yours", "not a rival's")
	s.actors[1]["hex"] = h["hex"] + HexGrid.DIRS[0] * 6
	s.holdings[1]["pacified_until"] = 0
	eq(cmd(s, "pacify", {"holding": 1})["error"], "not_near_own_holding", "stand near it")
	check(Rules.COMMAND_TYPES.has(&"pacify"), "listed")

func test_pacify_is_paid_from_other_stores_when_the_holding_is_bare() -> void:
	var s: MatchState = quiet()
	var far: Dictionary = s.holdings[2]
	far["owner"] = 0
	far["store"] = {}
	far["hex"] = home(s)["hex"] + HexGrid.DIRS[0] * 2
	var ev: Array = []
	check(Standing.pacify(s, 0, 2, ev) == "", "a bare holding is pacified from the capital's stores")
	var s2: MatchState = quiet()
	s2.holdings[1]["store"] = {}
	eq(Standing.pacify(s2, 0, 1, []), "insufficient_items", "nothing to pay with")

func test_pacified_holdings_do_not_revolt_and_keep_a_floor() -> void:
	var s: MatchState = _ai()
	var fid: int = 3
	var hs: Array[int] = s.holdings_of(fid)
	var far: Dictionary = {}
	for hid in s.holdings.keys():
		if int(s.holdings[hid]["owner"]) == -1:
			far = s.holdings[hid]
			break
	far["owner"] = fid
	far["stab"] = 5
	far["pacified_until"] = int(s.clock["day"]) + 3
	for i in range(40):
		s.set_time(1 + (i % 6), 0.0)
		far["pacified_until"] = int(s.clock["day"]) + 3
		Standing.dawn_upkeep(s, [])
	eq(int(far["owner"]), fid, "never revolted")
	check(int(far["stab"]) >= 55, "stability held up (%d)" % int(far["stab"]))
	far["pacified_until"] = 0
	far["stab"] = 5
	var lost: bool = false
	for i in range(80):
		Standing.dawn_upkeep(s, [])
		if int(far["owner"]) != fid:
			lost = true
			break
		far["stab"] = mini(int(far["stab"]), 8)
	check(lost, "an unpacified restless holding does revolt")
	check(not hs.is_empty(), "setup")

func test_ai_governor_pacifies_restless_holdings_at_dawn() -> void:
	var s: MatchState = _ai()
	var h: Dictionary = s.holdings[s.holdings_of(3)[0]]
	h["stab"] = 40
	var ev: Array = []
	Inv.add_all(h["store"], {"lfg:item/ration": 40, "lfg:item/coin": 20})
	AIFactions.dawn(s, ev)
	check(Standing.pacified(s, h), "pacified at dawn")
	# a faction that is short of food keeps its last rations
	var s3: MatchState = _ai()
	var hh: Dictionary = s3.holdings[s3.holdings_of(3)[0]]
	hh["stab"] = 40
	hh["store"] = {"lfg:item/ration": 2, "lfg:item/coin": 20}
	AIFactions.dawn(s3, [])
	check(not Standing.pacified(s3, hh), "no pacify while rations are short")
	check(count_type(ev, "pacified") >= 1, "pacified event")
	var h2: Dictionary = s.holdings[s.holdings_of(4)[0]]
	check(not Standing.pacified(s, h2) or int(h2["stab"]) >= 75, "calm holdings are left alone")

# ------------------------------------------------------------ the last-rival hunt
func _thin_field(s: MatchState, keep: Array) -> void:
	for fid in s.factions.keys():
		if not keep.has(int(fid)):
			s.factions[fid]["alive"] = false
			for hid in s.holdings_of(int(fid)):
				s.holdings[hid]["owner"] = -1

func test_hunting_starts_when_few_live_and_the_weeks_have_passed() -> void:
	var hc: Dictionary = Standing.cfg()["hunt"]
	var s: MatchState = _ai()
	warp(s, 7 * int(hc["min_week"]) + 2, 0.0)
	check(not AIFactions.hunting(s), "13 factions alive: no hunt")
	var few: Array = [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].slice(0, int(hc["live_at"]))
	_thin_field(s, few)
	check(AIFactions.hunting(s), "%d left after week %d: the hunt is on" % [int(hc["live_at"]), int(hc["min_week"])])
	var s1: MatchState = _ai()
	warp(s1, 7 * int(hc["min_week"]) + 2, 0.0)
	_thin_field(s1, [0, 3, 4, 5, 6, 7, 8, 9, 10, 11, 12].slice(0, int(hc["live_at"]) + 1))
	check(not AIFactions.hunting(s1), "one more than live_at: no hunt")
	var s2: MatchState = _ai()
	_thin_field(s2, few)
	warp(s2, 10, 0.0)
	check(not AIFactions.hunting(s2), "not before week %d" % int(hc["min_week"]))
	eq(AIFactions.effective_persona(s, 3), "raider", "survivors raid")
	check(AIFactions.max_dispatch(s) > 8 and AIFactions.party_cap(s) >= 3 * 8, "bigger and more parties")
	check(AIFactions.weakest_survivor(s, -1) >= 0, "a quarry exists")

func test_muster_takes_troops_from_the_whole_realm_and_conserves_them() -> void:
	var s: MatchState = _ai()
	warp(s, 100, 0.0)
	_thin_field(s, [0, 3, 4, 5, 6].slice(0, int(Standing.cfg()["hunt"]["live_at"])))
	var hs: Array[int] = []
	for i in range(4):
		var h: Dictionary = s.holdings[i + 20]
		h["owner"] = 3
		h["garrison"] = 9
		h["hex"] = s.holdings[s.factions[3]["home"]]["hex"] + HexGrid.DIRS[i] * (3 + i * 4)
		hs.append(i + 20)
	var homeh: Dictionary = s.holdings[int(s.factions[3]["home"])]
	homeh["garrison"] = 10
	var total0: int = 0
	for hid in s.holdings_of(3):
		total0 += int(s.holdings[hid]["garrison"])
	var avail: int = AIFactions.musterable(s, 3, homeh)
	eq(avail, 8 + 4 * 7, "home spare 8 + four holdings of 7 spare")
	AIFactions.take_troops(s, 3, homeh, 20)
	var total1: int = 0
	for hid in s.holdings_of(3):
		total1 += int(s.holdings[hid]["garrison"])
		check(int(s.holdings[hid]["garrison"]) >= 2, "no holding stripped below 2")
	eq(total1, total0 - 20, "exactly the committed troops left the garrisons")

func test_parties_that_cannot_arrive_before_the_purge_ends_are_not_sent() -> void:
	var s: MatchState = _ai()
	warp(s, 70, 0.0)
	var f: Dictionary = s.factions[3]
	var homeh: Dictionary = s.holdings[int(f["home"])]
	homeh["garrison"] = 20
	var far: int = -1
	var bd: int = 0
	for hid in s.holdings.keys():
		var d: int = HexGrid.distance(s.holdings[hid]["hex"], homeh["hex"])
		if d > bd and int(s.holdings[hid]["owner"]) != 3:
			bd = d
			far = int(hid)
	warp(s, 7, 0.97)       # the last seconds of the Purge
	var g0: int = int(homeh["garrison"])
	var ev: Array = []
	check(not AIFactions._dispatch(s, 3, int(f["home"]), far, "capture", 6, "", 0, ev), "too late to march %d hexes" % bd)
	eq(int(homeh["garrison"]), g0, "no troops left home")
	eq(ev.size(), 0, "no event")
	warp(s, 7, 0.5)
	var near: int = -1
	var nd: int = 99
	for hid in s.holdings.keys():
		var d2: int = HexGrid.distance(s.holdings[hid]["hex"], homeh["hex"])
		if d2 < nd and d2 >= 2 and int(s.holdings[hid]["owner"]) != 3:
			nd = d2
			near = int(hid)
	check(AIFactions._dispatch(s, 3, int(f["home"]), near, "capture", 6, "", 0, ev), "a near target is fine at the start of the Purge (%d hexes)" % nd)
	eq(int(homeh["garrison"]), g0 - 6, "six troops marched")

func test_a_faction_down_to_its_last_holding_fights_harder() -> void:
	var s: MatchState = _ai()
	var f3: Array[int] = s.holdings_of(3)
	var h: Dictionary = s.holdings[f3[0]]
	var one: float = Conquest.defender_power(s, h)
	var extra: Dictionary = s.holdings[20]
	extra["owner"] = 3
	var two: float = Conquest.defender_power(s, h)
	check(one > two, "one holding: %.1f > two holdings: %.1f" % [one, two])
	check(absf(one / two - float(Standing.cfg()["hold"]["last_stand"])) < 0.2, "by the last_stand factor")

func test_decapitation_candidates_use_the_lower_power_ratio_in_a_hunt() -> void:
	check(float(Standing.cfg()["hunt"]["power_ratio"]) < 1.3, "hunters accept a tougher fight")
	check(int(Standing.cfg()["hunt"]["muster_range"]) >= 30, "and muster the whole realm")

# ------------------------------------------------------------ leader escape, stealth, ward
## Wounded-leader escape is a roll against the kit's escape.evac (pass 3b); the old tests want it certain.
func _sure_escape() -> void:
	for cid in Content.classes().keys():
		var k: Dictionary = Content.ai_kit(String(cid))
		if not k.has("escape"):
			k["escape"] = {}
		(k["escape"] as Dictionary)["evac_saved"] = (k["escape"] as Dictionary).get("evac", 0.5)
		(k["escape"] as Dictionary)["evac"] = 1.0

func _restore_escape() -> void:
	for cid in Content.classes().keys():
		var e: Dictionary = Content.ai_kit(String(cid))["escape"]
		if e.has("evac_saved"):
			e["evac"] = e["evac_saved"]
			e.erase("evac_saved")

func _classed_ai(s: MatchState, fid: int, cls: String) -> Dictionary:
	var l: Dictionary = Standing.leader_of(s, fid)
	Setup.set_leader_class(l, "lfg:class/" + cls)
	return l

func _party_at(s: MatchState, fid: int, hex: Vector2i, target: int, state_name: String = "siege") -> Dictionary:
	var p: Dictionary = Setup.make_actor(s.new_id(), "party", fid, "Raiders", hex, 40, 2, 1, 0)
	p["ai"] = {"state": state_name, "mission": "capture", "target": target, "home": 1, "troops": 6, "item": "", "qty": 0, "warned": true, "retry": 0, "scout_t": 0.0,
		"hit_t": 0.0, "sortie_t": 0.0, "siege_end": 99999.0, "leader": -1, "strike": false}
	s.actors[p["id"]] = p
	return p

func test_wounded_leader_falls_back_to_another_holding() -> void:
	_sure_escape()
	var s: MatchState = _ai()
	_purge(s)
	var l: Dictionary = _classed_ai(s, 3, "judd")
	var mine: Array[int] = s.holdings_of(3)
	var second: Dictionary = s.holdings[mine[0]]
	var fine: Dictionary = s.holdings[20]
	fine["owner"] = 3
	fine["hex"] = s.holdings[int(s.factions[3]["home"])]["hex"] + HexGrid.DIRS[0] * 6
	l["hex"] = s.holdings[int(s.factions[3]["home"])]["hex"]
	l["hp"] = int(l["max_hp"]) * 3 / 10
	var party: Dictionary = _party_at(s, 5, l["hex"] + HexGrid.DIRS[1], int(s.factions[3]["home"]))
	var ev: Array = []
	check(AILeaders.try_escape(s, l, party, ev), "under 40%: it falls back")
	eq(l["hex"], fine["hex"], "to the other holding")
	eq(count_type(ev, "leader_retreated"), 1, "event")
	check(second["id"] != 0, "setup")
	# healthy: no retreat
	l["hex"] = s.holdings[int(s.factions[3]["home"])]["hex"]
	l["hp"] = int(l["max_hp"])
	check(not AILeaders.try_escape(s, l, party, []), "healthy leaders stand")
	# nowhere to go: it stays
	l["hp"] = 5
	fine["owner"] = -1
	for hid in s.holdings_of(3):
		if hid != int(s.factions[3]["home"]):
			s.holdings[hid]["owner"] = -1
	l["hex"] = s.holdings[int(s.factions[3]["home"])]["hex"]
	var ev0: Array = []
	check(AILeaders.try_escape(s, l, party, ev0), "no other holding: every leader slips out into the open (pass 3b)")
	eq(int(ev0[0]["to"]), -1, "hid, did not fall back")
	# a besieged neighbour is no refuge
	l["hex"] = s.holdings[int(s.factions[3]["home"])]["hex"]
	fine["owner"] = 3
	var p2: Dictionary = _party_at(s, 6, fine["hex"] + HexGrid.DIRS[2], int(fine["id"]))
	var ev1: Array = []
	check(AILeaders.try_escape(s, l, party, ev1) and int(ev1[0]["to"]) == -1, "a holding under siege is no refuge: it hides instead")
	check(p2["alive"], "setup")
	_restore_escape()

func test_a_brittle_leader_with_nowhere_to_go_hides_in_the_open_until_dawn() -> void:
	_sure_escape()
	var s: MatchState = _ai()
	_purge(s)
	var vex: Dictionary = _classed_ai(s, 3, "vex")
	var home_hex: Vector2i = s.holdings[int(s.factions[3]["home"])]["hex"]
	vex["hex"] = home_hex
	vex["hp"] = 10
	var party: Dictionary = _party_at(s, 5, home_hex + HexGrid.DIRS[1], int(s.factions[3]["home"]))
	var ev: Array = []
	check(AILeaders.try_escape(s, vex, party, ev), "Vex slips out the back")
	var d: int = HexGrid.distance(vex["hex"], home_hex)
	check(d >= 5 and d <= 7, "5-7 hexes out (%d)" % d)
	eq(int(WorldGen.move_cost(s.world, vex["hex"]) > 0.0), 1, "on passable ground")
	var r: Dictionary = ev[0]
	eq(int(r["to"]), -1, "the event says it hid in the open")
	AILeaders.dawn(s, [])
	eq(vex["hex"], home_hex, "back at the holding at dawn")
	# every class can hide now (pass 3b), but only the slippery ones also dodge blows
	var j: Dictionary = _classed_ai(s, 4, "judd")
	j["hp"] = 5
	var p2: Dictionary = _party_at(s, 6, j["hex"] + HexGrid.DIRS[2], int(s.factions[4]["home"]))
	check(AILeaders.try_escape(s, j, p2, []), "Judd, wounded, hides too")
	_restore_escape()

func test_slippery_classes_dodge_some_blows() -> void:
	var s: MatchState = _ai()
	_purge(s)
	var vex: Dictionary = _classed_ai(s, 3, "vex")
	var judd: Dictionary = _classed_ai(s, 4, "judd")
	var party: Dictionary = _party_at(s, 5, vex["hex"] + HexGrid.DIRS[1], int(s.factions[3]["home"]))
	var dodged: int = 0
	var dodged_j: int = 0
	for i in range(200):
		if AILeaders.try_escape(s, vex, party, []):
			dodged += 1
		if AILeaders.try_escape(s, judd, party, []):
			dodged_j += 1
	check(dodged > 90 and dodged < 150, "Vex slips about 60%% of the blows (%d/200)" % dodged)
	eq(dodged_j, 0, "Judd has no such trick")

func test_halo_wards_the_moment_a_siege_begins() -> void:
	var s: MatchState = _ai()
	_purge(s)
	var halo: Dictionary = _classed_ai(s, 3, "halo")
	var home_h: Dictionary = s.holdings[int(s.factions[3]["home"])]
	halo["hex"] = home_h["hex"]
	halo["energy"] = 100.0
	var party: Dictionary = _party_at(s, 5, home_h["hex"] + HexGrid.DIRS[1], int(home_h["id"]))
	var ev: Array = []
	AILeaders.on_siege_begin(s, party, ev)
	check(Combat.has_effect(s, halo, "ward"), "the leader wears the ward")
	check(float(home_h.get("ward", 0.0)) > float(s.clock["elapsed"]), "and the holding is warded")
	eq(count_type(ev, "ability_used"), 1, "ward cast through Abilities.use")
	# other classes do not
	var s2: MatchState = _ai()
	_purge(s2)
	var j: Dictionary = _classed_ai(s2, 3, "judd")
	var h2: Dictionary = s2.holdings[int(s2.factions[3]["home"])]
	var p2: Dictionary = _party_at(s2, 5, h2["hex"] + HexGrid.DIRS[1], int(h2["id"]))
	var ev2: Array = []
	AILeaders.on_siege_begin(s2, p2, ev2)
	eq(ev2.size(), 0, "only the pilgrim reacts")
	check(j["alive"], "setup")

func test_thieves_join_steal_jobs_unseen_and_pick_pockets() -> void:
	var s: MatchState = _ai()
	_purge(s)
	var vex: Dictionary = _classed_ai(s, 3, "vex")
	check(AILeaders.fragile(vex), "Vex is brittle")
	check(AILeaders.wants_to_join(s, 3, vex, "steal", 2), "but joins a stealth job")
	check(not AILeaders.wants_to_join(s, 3, vex, "capture", 6), "never a raid")
	var judd: Dictionary = _classed_ai(s, 4, "judd")
	check(not AILeaders.wants_to_join(s, 4, judd, "steal", 2), "other classes unchanged")
	# a stealth party hides its leader
	var homeh: Dictionary = s.holdings[int(s.factions[3]["home"])]
	var victim_home: Dictionary = s.holdings[int(s.factions[4]["home"])]
	var party: Dictionary = _party_at(s, 3, victim_home["hex"] + HexGrid.DIRS[0], int(victim_home["id"]), "siege")
	party["ai"]["mission"] = "steal"
	party["ai"]["stealth"] = true
	AILeaders.join(s, vex, party)
	check(AILeaders.hidden(s, vex), "hidden while on the job")
	# pickpocket on the holding's leader standing at the door
	var vic: Dictionary = Standing.leader_of(s, 4)
	vic["hex"] = victim_home["hex"]
	Inv.add_all(vic["inv"], {"lfg:item/coin": 20})
	vex["energy"] = 100.0
	vex["cd"] = {}
	var e0: float = float(vex["energy"])
	var ev: Array = []
	AILeaders.pickpocket_job(s, party, int(victim_home["id"]), ev)
	check(float(vex["energy"]) < e0, "the pickpocket was attempted through the real ability")
	check(count_type(ev, "ability_used") >= 1 or int(vex["hp"]) < int(vex["max_hp"]), "with a result (success or being caught)")
	check(homeh["id"] != 0, "setup")

func test_pass_three_sim_metrics_exist_in_the_harness() -> void:
	var txt: String = FileAccess.get_file_as_string("res://tools/sim_match.gd")
	for w in ["peak_holdings", "hunt_day", "tree_done_week", "stealth_jobs", "leader_retreated"]:
		check(txt.contains(w), "harness records %s" % w)
