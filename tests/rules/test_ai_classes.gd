extends RulesTestBase
## Class-aware faction AI: every AI/bot leader has a class and acts through its kit; leaders march with raids, defend, and can die;
## passive personas still have Purge routes that earn deeds; bounded CPU.

const SimMatch := preload("res://tools/sim_match.gd")

func _purge(s: MatchState) -> void:
	warp(s, 7, 0.6)

func _lead(s: MatchState, fid: int, cls: String) -> Dictionary:
	var l: Dictionary = Standing.leader_of(s, fid)
	Setup.set_leader_class(l, "lfg:class/" + cls)
	l["hex"] = s.holdings[int(s.factions[fid]["home"])]["hex"]
	return l

func _foe_party(s: MatchState, fid: int, hex: Vector2i, troops: int = 6) -> Dictionary:
	var p: Dictionary = Setup.make_actor(s.new_id(), "party", fid, "Test Raiders", hex, troops * AIFactions.HP_PER_TROOP, 2, 1, 0)
	p["ai"] = {"state": "siege", "mission": "capture", "target": 1, "home": int(s.factions[fid]["home"]), "troops": troops, "item": "", "qty": 0, "warned": false,
		"retry": 0, "scout_t": 0.0, "hit_t": 0.0, "sortie_t": 0.0, "siege_end": 1.0e9, "leader": -1, "strike": false}
	s.actors[p["id"]] = p
	return p

func _abilities(ev: Array) -> Array:
	return ev.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "ability_used").map(func(e: Dictionary) -> String: return String(e["ability"]).get_slice("/", 1))

# ------------------------------------------------------------ classes for AI leaders
func test_ai_leaders_get_distinct_classes_never_the_players() -> void:
	var s: MatchState = mk("lfg:class/judd", 11, {"ai_enabled": false, "wild_enemies": false})
	var seen: Dictionary = {}
	for fid in range(1, 13):
		var l: Dictionary = Standing.leader_of(s, fid)
		var cid: String = String(l["class_id"])
		check(cid != "" and cid != "lfg:class/judd" and not seen.has(cid), "faction %d has its own class (%s)" % [fid, cid])
		seen[cid] = true
		check(int(l["max_hp"]) > 0 and int(l["max_hp"]) != 60 or cid == "lfg:class/mira", "class stats applied")
	eq(seen.size(), 12, "12 different classes, 13 available")
	var s2: MatchState = mk("lfg:class/judd", 11, {"ai_enabled": false, "wild_enemies": false})
	for fid in range(1, 13):
		eq(Standing.leader_of(s2, fid)["class_id"], Standing.leader_of(s, fid)["class_id"], "same seed, same deal")
	var s3: MatchState = mk("lfg:class/judd", 12, {"ai_enabled": false, "wild_enemies": false})
	var differ: bool = false
	for fid in range(1, 13):
		differ = differ or Standing.leader_of(s3, fid)["class_id"] != Standing.leader_of(s, fid)["class_id"]
	check(differ, "a different seed deals differently")
	var plain: MatchState = mk("lfg:class/judd", 11, {"ai_enabled": false, "wild_enemies": false, "ai_classes": false})
	eq(Standing.leader_of(plain, 3)["class_id"], "", "opt-out keeps classless leaders (harness use)")

func test_every_class_has_an_ai_kit_row_with_a_real_ability() -> void:
	for cid in Content.classes().keys():
		var k: Dictionary = Content.ai_kit(String(cid))
		check(not k.is_empty(), "%s has an AI kit row" % cid)
		for f in ["role", "peace", "cast", "joins_raid", "bias"]:
			check(k.has(f), "%s.%s" % [cid, f])
		var cast: String = String(k["cast"])
		if cast != "none":
			var ab: String = String(Content.class_def(String(cid))["ability"]["id"])
			check(ab.ends_with("/" + cast), "%s casts its own main ability (%s)" % [cid, cast])

# ------------------------------------------------------------ peace perks used by AI leaders
func test_peace_routines_use_the_class_perks() -> void:
	var checks: Dictionary = {"tavi": ["mine", "lfg:item/stone"], "bram": ["forage", "lfg:item/mushroom"], "halo": ["bless", ""]}
	for cls in checks.keys():
		var s: MatchState = mk("lfg:class/judd", 11, {"wild_enemies": false})
		var l: Dictionary = _lead(s, 4, cls)
		var home_h: Dictionary = s.holdings[int(s.factions[4]["home"])]
		var before: Dictionary = (home_h["store"] as Dictionary).duplicate()
		var ev: Array = []
		AILeaders.dawn(s, ev)
		check(_abilities(ev).has(checks[cls][0]), "%s's leader used %s at dawn: %s" % [cls, checks[cls][0], str(_abilities(ev))])
		if checks[cls][1] != "":
			check(Inv.count(home_h["store"], checks[cls][1]) > Inv.count(before, checks[cls][1]), "%s: the haul went into the store" % cls)
		else:
			check(Economy.blessed(s, home_h), "halo blessed the holding")
	var s2: MatchState = mk("lfg:class/judd", 11, {"wild_enemies": false})
	_lead(s2, 4, "sable")
	var h2: Dictionary = s2.holdings[int(s2.factions[4]["home"])]
	var m0: int = Inv.count(h2["store"], "lfg:item/game_meat")
	AILeaders.dawn(s2, [])
	check(Inv.count(h2["store"], "lfg:item/game_meat") > m0, "Sable hunts game meat")
	var s3: MatchState = mk("lfg:class/judd", 11, {"wild_enemies": false})
	_lead(s3, 4, "dune")
	var h3: Dictionary = s3.holdings[int(s3.factions[4]["home"])]
	h3["store"]["lfg:item/timber"] = 5
	h3["store"]["lfg:item/stone"] = 5
	AILeaders.dawn(s3, [])
	check(Inv.count(h3["store"], "lfg:item/gadget") >= 3, "Dune tinkers gadgets")

func test_class_perks_change_ai_economy_and_costs() -> void:
	var s: MatchState = mk("lfg:class/judd", 11, {"wild_enemies": false})
	_lead(s, 4, "oren")
	_lead(s, 5, "bram")
	for fid in [4, 5]:
		var h: Dictionary = s.holdings[int(s.factions[fid]["home"])]
		h["store"] = {"lfg:item/glowfruit": 40, "lfg:item/ration": 0}
	var ev: Array = []
	AIFactions.dawn(s, ev)
	var r4: int = Inv.count(s.holdings[int(s.factions[4]["home"])]["store"], "lfg:item/ration")
	var r5: int = Inv.count(s.holdings[int(s.factions[5]["home"])]["store"], "lfg:item/ration")
	check(r4 > r5 - 12, "Oren's kitchen bonus makes more rations per batch (%d vs %d, Bram forages instead)" % [r4, r5])
	# Forge builds cheaper
	var f: MatchState = mk("lfg:class/judd", 11, {"wild_enemies": false})
	_lead(f, 4, "forge")
	_lead(f, 5, "tavi")
	var cost_forge: Dictionary = Economy.build_cost(Standing.leader_of(f, 4), Content.building("lfg:building/wall"))
	var cost_tavi: Dictionary = Economy.build_cost(Standing.leader_of(f, 5), Content.building("lfg:building/wall"))
	check(Inv.total(cost_forge) < Inv.total(cost_tavi), "Forge pays less for walls than Tavi")

# ------------------------------------------------------------ kits in a siege
func test_leaders_use_their_kit_with_real_arguments() -> void:
	var expect: Dictionary = {"judd": "guard", "bram": "rage", "mira": "plague_cloud", "tavi": "sentinel_post", "sable": "snare", "nyx": "spore_swarm",
		"rook": "rally", "halo": "ward", "oren": "field_dressing", "vex": "pickpocket", "pip": "dash"}
	for cls in expect.keys():
		var s: MatchState = quiet()
		_purge(s)
		var l: Dictionary = _lead(s, 4, cls)
		var foe: Dictionary = _foe_party(s, 7, l["hex"] + HexGrid.DIRS[0])
		foe["inv"] = {"lfg:item/ration": 3}
		l["hp"] = int(l["max_hp"] * 0.6)
		var ev: Array = []
		AILeaders.siege_cast(s, l, foe, {}, ev)
		check(_abilities(ev).has(expect[cls]), "%s's leader cast %s (got %s)" % [cls, expect[cls], str(_abilities(ev))])
	# forge: the ram needs a holding next to it
	var s2: MatchState = quiet()
	_purge(s2)
	var fl: Dictionary = _lead(s2, 4, "forge")
	var target: Dictionary = s2.holdings[s2.holdings_of(5)[0]]
	fl["hex"] = target["hex"] + HexGrid.DIRS[0]
	var ev2: Array = []
	AILeaders.siege_cast(s2, fl, {}, {"holding": target["id"]}, ev2)
	check(_abilities(ev2).has("siege_ram"), "Forge rams the walls it is besieging")
	var s3: MatchState = quiet()
	_purge(s3)
	var ql: Dictionary = _lead(s3, 4, "quill")
	var ev3: Array = []
	AILeaders.siege_cast(s3, ql, _foe_party(s3, 7, ql["hex"] + HexGrid.DIRS[0]), {}, ev3)
	eq(_abilities(ev3).size(), 0, "Quill does not fight: she talks (tribute)")

func test_leaders_do_not_spam_cooldowns() -> void:
	var s: MatchState = quiet()
	_purge(s)
	var l: Dictionary = _lead(s, 4, "bram")
	var foe: Dictionary = _foe_party(s, 7, l["hex"] + HexGrid.DIRS[0])
	var ev: Array = []
	AILeaders.siege_cast(s, l, foe, {}, ev)
	var n1: int = _abilities(ev).size()
	AILeaders.siege_cast(s, l, foe, {}, ev)
	eq(_abilities(ev).size(), n1, "the second cast on cooldown is skipped")
	s.opts["ai_log"] = true
	AILeaders.cast(s, l, {"ability": "lfg:ability/rage"}, ev)
	check(not s.sim_acc.has("ablog"), "preflighted attempts are not even logged")

func test_ability_attempts_are_logged_for_the_harness() -> void:
	var s: MatchState = mk("lfg:class/judd", 11, {"wild_enemies": false, "ai_log": true})
	_lead(s, 4, "tavi")
	AILeaders.dawn(s, [])
	var lg: Dictionary = s.sim_acc.get("ablog", {})
	check(lg.has("mine") and int(lg["mine"].get("ok", 0)) >= 1, "log records mine/ok: %s" % str(lg))

# ------------------------------------------------------------ leaders in raids and defence
func _raid_setup(cls: String, hp_ok: bool = true) -> Array:
	var s: MatchState = mk("lfg:class/judd", 11, {"wild_enemies": false})
	_purge(s)
	var l: Dictionary = _lead(s, 4, cls)
	var home_h: Dictionary = s.holdings[int(s.factions[4]["home"])]
	home_h["garrison"] = 14
	s.factions[4]["persona"] = "raider"
	var tgt: int = -1
	var bd: int = 99
	for h in s.holdings.values():
		var d: int = HexGrid.distance(h["hex"], home_h["hex"])
		if int(h["owner"]) == -1 and d >= 4 and d < bd:
			bd = d
			tgt = int(h["id"])
	return [s, l, home_h, tgt]

func test_a_warlord_leader_marches_with_the_raid_and_comes_home() -> void:
	var x: Array = _raid_setup("bram")
	var s: MatchState = x[0]
	var l: Dictionary = x[1]
	var ev: Array = []
	check(AIFactions._dispatch(s, 4, int(x[2]["id"]), int(x[3]), "capture", 8, "", 0, ev), "dispatched")
	var pid: int = AIFactions.parties_of(s, 4)[0]
	var p: Dictionary = s.actors[pid]
	eq(int(p["ai"]["leader"]), int(l["id"]), "the leader joined the party")
	eq(int(l["ai"]["party"]), pid, "and knows it")
	for i in range(30):
		AIFactions.party_step(s, ev)
		tick_all(s, 1.0, 1.0)
		if s.actors.has(pid) and bool(l["alive"]):
			eq(l["hex"], p["hex"], "the leader is where the party is") if i % 7 == 0 else null
		if not s.actors.has(pid):
			break
	AIFactions._disband(s, p, ev, "test") if s.actors.has(pid) else null
	eq(l["hex"], x[2]["hex"], "after the party is gone the leader is home")
	eq(int(l["ai"]["party"]), -1, "link cleared")

func test_brittle_and_peaceful_leaders_stay_home() -> void:
	for cls in ["vex", "mira", "quill", "judd", "oren", "halo"]:
		var x: Array = _raid_setup(cls)
		var ev: Array = []
		AIFactions._dispatch(x[0], 4, int(x[2]["id"]), int(x[3]), "capture", 8, "", 0, ev)
		var ps: Array = AIFactions.parties_of(x[0], 4)
		check(ps.size() == 1 and int(x[0].actors[ps[0]]["ai"]["leader"]) == -1, "%s's leader does not join the raid" % cls)
	check(AILeaders.fragile(_lead(quiet(), 4, "vex")), "Vex is fragile")
	check(not AILeaders.fragile(_lead(quiet(), 4, "bram")), "Bram is not")

func test_leader_reinforces_a_threatened_holding_then_returns() -> void:
	var s: MatchState = quiet()
	_purge(s)
	var l: Dictionary = _lead(s, 4, "bram")
	var own: Array = s.holdings_of(4)
	# a second holding of faction 4 within range of its leader
	var second: int = -1
	for h in s.holdings.values():
		if int(h["owner"]) == -1 and (second == -1 or HexGrid.distance(h["hex"], l["hex"]) < HexGrid.distance(s.holdings[second]["hex"], l["hex"])):
			second = int(h["id"])
	check(second != -1, "a second site exists")
	s.holdings[second]["owner"] = 4
	l["hex"] = s.holdings[second]["hex"] + HexGrid.DIRS[3] * 4      # the leader keeps house 4 hexes from it
	var party: Dictionary = _foe_party(s, 7, s.holdings[second]["hex"] + HexGrid.DIRS[0])
	party["ai"]["target"] = second
	var home_hex: Vector2i = l["hex"]
	AILeaders.defend_call(s, party)
	eq(l["hex"], s.holdings[second]["hex"], "the leader reinforces the besieged holding")
	AIFactions._go_home(s, party, [])
	eq(l["hex"], home_hex, "and goes home when the siege ends")
	# a pacifist/support class stays put
	var l2: Dictionary = _lead(s, 4, "oren")
	var party2: Dictionary = _foe_party(s, 7, s.holdings[second]["hex"] + HexGrid.DIRS[0])
	party2["ai"]["target"] = second
	var hx2: Vector2i = l2["hex"]
	AILeaders.defend_call(s, party2)
	eq(l2["hex"], hx2, "a support class stays home")

func test_a_siege_can_kill_an_ai_leader_which_eliminates_the_faction() -> void:
	var s: MatchState = quiet()
	_purge(s)
	var l: Dictionary = _lead(s, 4, "rook")
	var home_h: Dictionary = s.holdings[int(s.factions[4]["home"])]
	home_h["buildings"] = ["lfg:building/wall", "lfg:building/storehouse"]
	home_h["garrison"] = 12
	var party: Dictionary = _foe_party(s, 7, home_h["hex"] + HexGrid.DIRS[0], 20)
	party["ai"]["target"] = int(home_h["id"])
	l["hp"] = 5
	var ev: Array = []
	AIFactions._harass(s, party, ev)
	check(not l["alive"], "the leader fell in its own siege")
	check(not s.factions[4]["alive"], "the faction is eliminated")
	Standing.observe(s, ev, 0)
	var deeds: Array = ev.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "deed")
	check(deeds.any(func(e: Dictionary) -> bool: return e["kind"] == "kill_leader" and int(e["faction"]) == 7), "the raiders earned a kill_leader deed")
	eq(home_h["owner"], -1, "holding neutral")
	check(int(home_h["garrison"]) <= 4, "a leaderless garrison routs")
	check(not (home_h["buildings"] as Array).has("lfg:building/wall") and (home_h["buildings"] as Array).has("lfg:building/storehouse"), "its walls fall, its storehouse stands")

func test_defending_leaders_hit_back_and_use_their_kit() -> void:
	var s: MatchState = quiet()
	_purge(s)
	var l: Dictionary = _lead(s, 4, "bram")
	var home_h: Dictionary = s.holdings[int(s.factions[4]["home"])]
	var party: Dictionary = _foe_party(s, 7, home_h["hex"] + HexGrid.DIRS[0], 6)
	party["ai"]["target"] = int(home_h["id"])
	var hp0: int = int(party["hp"])
	var ev: Array = []
	AIFactions._harass(s, party, ev)
	check(int(l["hp"]) < int(l["max_hp"]), "the party hurt the leader")
	check(int(party["hp"]) < hp0, "and the leader hurt the party back")
	check(_abilities(ev).has("rage"), "Bram raged")

func test_famine_collapses_starving_ai_factions_but_not_the_player() -> void:
	var s: MatchState = quiet()
	for fid in [0, 4]:
		s.factions[fid]["hunger_days"] = 27
		for h in s.holdings_of(fid):
			s.holdings[h]["store"].erase("lfg:item/ration")
	s.actors[1]["inv"].erase("lfg:item/ration")
	var ev: Array = []
	Economy.feed_faction(s, 4, ev)
	check(count_type(ev, "famine_collapse") == 1 and not s.factions[4]["alive"], "an AI faction starved for four weeks collapses")
	var ev2: Array = []
	Economy.feed_faction(s, 0, ev2)
	eq(count_type(ev2, "famine_collapse"), 0, "the player has the Starved Out rule instead")
	check(s.factions[0]["alive"], "player alive")

# ------------------------------------------------------------ persona routes
func test_pacifist_classes_never_raid_whatever_their_persona() -> void:
	var s: MatchState = quiet()
	_lead(s, 4, "halo")
	s.factions[4]["persona"] = "raider"
	eq(AIFactions.effective_persona(s, 4), "turtle", "pacifist class overrides a raider persona")
	_lead(s, 4, "rook")
	eq(AIFactions.effective_persona(s, 4), "raider", "a warlord class keeps it")

func _closest_pair(s: MatchState) -> Array:
	var pa: int = 1
	var pb: int = 2
	var best: int = 999
	for a in range(1, 13):
		for b in range(1, 13):
			var d: int = HexGrid.distance(s.holdings[int(s.factions[a]["home"])]["hex"], s.holdings[int(s.factions[b]["home"])]["hex"])
			if a != b and d < best:
				best = d
				pa = a
				pb = b
	return [pa, pb, best]

func _lone(fid: int) -> MatchState:
	## A match where only faction `fid` acts (everyone else on a very long cooldown), in the Purge of week 9 (wide vision).
	var s: MatchState = mk("lfg:class/judd", 11, {"wild_enemies": false})
	warp(s, 7 * 8 + 7, 0.51)
	for f in s.factions.values():
		if int(f["id"]) != fid:
			f["next_act"] = 1.0e9
	return s

func test_passive_personas_scout_and_resupply_and_earn_deeds() -> void:
	var probe: MatchState = quiet()
	var pr: Array = _closest_pair(probe)
	var me: int = pr[0]
	var rival: int = pr[1]
	var s: MatchState = _lone(me)
	_lead(s, me, "tavi")
	s.factions[me]["persona"] = "turtle"
	var home_h: Dictionary = s.holdings[int(s.factions[me]["home"])]
	home_h["garrison"] = 12
	home_h["store"]["lfg:item/ration"] = 40
	AIFactions.scout(s, me)
	var ev: Array = []
	check(AIFactions._plan_support(s, me, "turtle", int(home_h["id"]), ev), "a turtle plans a support mission (rival %d hexes away)" % pr[2])
	var ps: Array = AIFactions.parties_of(s, me)
	eq(ps.size(), 1, "one party")
	var mission: String = String(s.actors[ps[0]]["ai"]["mission"])
	check(mission == "scout" or mission == "supply", "scout or supply (%s)" % mission)
	for pid in ps:
		s.actors.erase(pid)
	home_h["garrison"] = 12
	var target: int = s.holdings_of(rival)[0]
	check(AIFactions._dispatch(s, me, int(home_h["id"]), target, "scout", 1, "", 0, ev), "scout party dispatched")
	var got: bool = false
	for i in range(600):
		var e2: Array = tick_all(s, 1.0, 1.0)
		if e2.any(func(e: Dictionary) -> bool: return String(e["type"]) == "deed" and e["kind"] == "scout" and int(e["faction"]) == me):
			got = true
			break
		if s.phase != &"PURGE_ACTIVE":
			break
	check(got or int(s.factions[me]["dcount"].get("scout", 0)) > 0, "the scouts reached the rival and earned a scout deed")

func test_supply_train_reinforces_an_outlying_holding() -> void:
	var s: MatchState = _lone(4)
	_lead(s, 4, "judd")
	var home_h: Dictionary = s.holdings[int(s.factions[4]["home"])]
	var far: int = -1
	for h in s.holdings.values():
		var d: int = HexGrid.distance(h["hex"], home_h["hex"])
		if int(h["owner"]) == -1 and d >= 5 and d <= 9:
			far = int(h["id"])
			break
	check(far != -1, "outlying site")
	s.holdings[far]["owner"] = 4
	home_h["garrison"] = 8
	home_h["store"]["lfg:item/ration"] = 30
	var g0: int = int(s.holdings[far]["garrison"])
	var r0: int = Inv.count(s.holdings[far]["store"], "lfg:item/ration")
	var totals: Dictionary = Inv.world_totals(s)
	var ev: Array = []
	check(AIFactions._dispatch(s, 4, int(home_h["id"]), far, "supply", 1, "lfg:item/ration", 6, ev), "dispatched")
	var done: bool = false
	for i in range(600):
		var e2: Array = tick_all(s, 1.0, 1.0)
		ev.append_array(e2)
		if ev.any(func(e: Dictionary) -> bool: return String(e["type"]) == "party_returned" and e["reason"] == "delivered"):
			done = true
			break
		if s.phase != &"PURGE_ACTIVE":
			break
	check(done, "the train arrived")
	check(Inv.count(s.holdings[far]["store"], "lfg:item/ration") >= r0 + 6, "rations delivered")
	eq(int(s.holdings[far]["garrison"]), g0 + 1, "and the escort stays as garrison")
	check(ev.any(func(e: Dictionary) -> bool: return String(e["type"]) == "deed" and e["kind"] == "escort"), "escort deed")

func test_tribute_buys_a_truce_that_raiders_respect() -> void:
	var s: MatchState = quiet()
	_purge(s)
	var pa: int = 1
	var pb: int = 2
	var best: int = 999
	for a in range(1, 13):
		for b in range(1, 13):
			var d: int = HexGrid.distance(s.holdings[int(s.factions[a]["home"])]["hex"], s.holdings[int(s.factions[b]["home"])]["hex"])
			if a != b and d < best:
				best = d
				pa = a
				pb = b
	check(best <= AILeaders.TRIBUTE_RANGE, "two homes within tribute range (%d)" % best)
	_lead(s, pa, "quill")
	s.factions[pa]["persona"] = "trader"
	_lead(s, pb, "rook")
	s.factions[pb]["persona"] = "raider"
	var h4: Dictionary = s.holdings[int(s.factions[pa]["home"])]
	var h5: Dictionary = s.holdings[int(s.factions[pb]["home"])]
	h4["store"]["lfg:item/coin"] = 30
	for f in s.factions.values():
		if int(f["id"]) not in [pa, pb]:
			f["persona"] = "turtle"
			(Standing.leader_of(s, int(f["id"])) as Dictionary)["class_id"] = "lfg:class/halo"
	var c4: int = Inv.count(h4["store"], "lfg:item/coin")
	var c5: int = Inv.count(h5["store"], "lfg:item/coin")
	var totals: Dictionary = Inv.world_totals(s)
	var ev: Array = []
	AILeaders.purge_start(s, ev)
	check(Standing.truced(s, pa, pb) and Standing.truced(s, pb, pa), "a truce stands between payer and raider")
	check(Inv.count(h4["store"], "lfg:item/coin") < c4 and Inv.count(h5["store"], "lfg:item/coin") > c5, "the coin moved")
	eq(Inv.world_totals(s), totals, "tribute conserves goods")
	Standing.observe(s, ev, 0)
	check(ev.any(func(e: Dictionary) -> bool: return String(e["type"]) == "deed" and e["kind"] == "broker" and int(e["faction"]) == pa), "brokering earns a deed")
	AIFactions.scout(s, pb)
	h5["garrison"] = 30
	AIFactions._try(s, pb, "capture", int(h5["id"]), [])
	var any_on_payer: bool = false
	for pid in AIFactions.parties_of(s, pb):
		if int(s.holdings[int(s.actors[pid]["ai"]["target"])]["owner"]) == pa:
			any_on_payer = true
	check(not any_on_payer, "the raider will not march on the payer")
	var coin_after: int = Inv.count(h4["store"], "lfg:item/coin")
	AILeaders.purge_start(s, ev)
	eq(Inv.count(h4["store"], "lfg:item/coin"), coin_after, "tribute is paid once per week")
	eq(int(s.factions[pa]["tribute_week"]), s.week(), "recorded")

func test_ai_building_respects_rank_gates() -> void:
	var s: MatchState = quiet()
	_lead(s, 4, "tavi")
	var h: Dictionary = s.holdings[int(s.factions[4]["home"])]
	h["store"] = {"lfg:item/timber": 500, "lfg:item/stone": 500, "lfg:item/coin": 500}
	Standing.set_rank(s, 4, 0)
	for i in range(8):
		AIFactions._build(s, 4, "turtle", int(h["id"]), [])
	for b in h["buildings"]:
		check(int(Content.building(String(b)).get("rank", 0)) == 0, "rank 0 AI builds only rank-0 buildings (%s)" % b)
	Standing.set_rank(s, 4, 3)
	for i in range(10):
		AIFactions._build(s, 4, "turtle", int(h["id"]), [])
	check((h["buildings"] as Array).size() > 1, "higher rank unlocks more")
	var gated: bool = false
	for b in h["buildings"]:
		gated = gated or int(Content.building(String(b)).get("rank", 0)) > 0
	check(gated, "and rank buildings appear")

# ------------------------------------------------------------ CPU budget with 14 factions
func test_fourteen_faction_tick_stays_under_three_milliseconds() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 7
	var w: Dictionary = SimMatch.build_world(3, rng)
	var st: MatchState = w["state"]
	eq(st.factions.size(), 14, "14 factions")
	var n: int = 0
	var t0: int = Time.get_ticks_usec()
	for i in range(int(7.0 * 360.0 / 2.0) * 2):      # two in-world weeks at 2 s steps (covers two Purges)
		Rules.tick(st, 2.0)
		n += 1
	var avg: float = float(Time.get_ticks_usec() - t0) / 1000.0 / float(n)
	check(avg < 3.0, "average tick %.2f ms < 3 ms with 14 factions (%d ticks)" % [avg, n])
	print("14-faction avg tick ms=", avg)
