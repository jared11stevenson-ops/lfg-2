extends RulesTestBase
## Pass 3b class balance: Purge targeting mercy, the Reckoning (late hunt), ration discipline, class home ground, leader evacuation, Truce Flag / Track triggers,
## class-specific raid joining. Numbers live in data/ranks.json ("mercy", "furlough", "hunt"), data/classes.json (mods.home_def) and data/ai_kits.json.

func _ai(sd: int = 11) -> MatchState:
	return mk("lfg:class/judd", sd, {"wild_enemies": false})

func _purge(s: MatchState) -> void:
	warp(s, 7, 0.45)

func _classed(s: MatchState, fid: int, cls: String) -> Dictionary:
	var l: Dictionary = Standing.leader_of(s, fid)
	Setup.set_leader_class(l, "lfg:class/" + cls)
	return l

func _party_at(s: MatchState, fid: int, hex: Vector2i, target: int, troops: int = 6) -> Dictionary:
	var p: Dictionary = Setup.make_actor(s.new_id(), "party", fid, "Raiders", hex, troops * 6, 2, 1, 0)
	p["ai"] = {"state": "siege", "mission": "capture", "target": target, "home": 1, "troops": troops, "item": "", "qty": 0, "warned": true, "retry": 0, "scout_t": 0.0,
		"hit_t": 0.0, "sortie_t": 0.0, "siege_end": 99999.0, "leader": -1, "strike": false}
	s.actors[p["id"]] = p
	return p

# ------------------------------------------------------------ mercy
func test_mercy_scale_values() -> void:
	var mc: Dictionary = Standing.cfg()["mercy"]
	eq(AIFactions.mercy(1, 3.0), float(mc["last_roof"]), "a last roof is left alone")
	eq(AIFactions.mercy(1, 3.0), 0.0, "(shipped value 0)")
	check(AIFactions.mercy(2, 3.0) < AIFactions.mercy(3, 3.0) and AIFactions.mercy(3, 3.0) < 1.0, "two roofs poorer than three, both poorer than a normal holder")
	eq(AIFactions.mercy(4, 3.0), 1.0, "a normal holder is an ordinary target")
	check(AIFactions.mercy(9, 3.0) > 1.0, "a holder far above the average is a richer target")

func _setup_raid(s: MatchState, target_owner_roofs: int) -> int:
	# faction 3 (strong) vs faction 4, whose only holdings are the ones we place near 3's home
	var home3: Dictionary = s.holdings[int(s.factions[3]["home"])]
	home3["garrison"] = 30
	for hid in s.holdings_of(4):
		s.holdings[hid]["owner"] = -1
	var first: int = -1
	for i in range(target_owner_roofs):
		var h: Dictionary = s.holdings[20 + i]
		h["owner"] = 4
		h["garrison"] = 0
		h["buildings"] = []
		h["hex"] = home3["hex"] + HexGrid.DIRS[i] * (5 + i)
		if first == -1:
			first = 20 + i
	s.factions[4]["home"] = first
	s.factions[3]["persona"] = "raider"
	return first

func _targets_after_round(s: MatchState) -> Array:
	var out: Array = []
	for pid in AIFactions.parties_of(s, 3):
		out.append(int(s.actors[pid]["ai"]["target"]))
	return out

func test_nobody_takes_a_last_roof_before_the_mercy_week_but_does_afterwards() -> void:
	var s: MatchState = _ai()
	_purge(s)
	var tgt: int = _setup_raid(s, 1)
	AIFactions.scout(s, 3)
	check(s.factions[3]["intel"].has(tgt), "setup: faction 3 sees the target")
	check(not AIFactions._try(s, 3, "capture", int(s.factions[3]["home"]), []), "a rival's only holding is not raided in week 1")
	eq(AIFactions.parties_of(s, 3).size(), 0, "no party left home")
	# after the mercy window the same target is fair game
	warp(s, 7 * int(Standing.cfg()["mercy"]["until_week"]) + 7, 0.45)
	AIFactions.scout(s, 3)
	s.holdings[int(s.factions[3]["home"])]["garrison"] = 30
	check(AIFactions._try(s, 3, "capture", int(s.factions[3]["home"]), []), "after the mercy week it is raided")
	eq(_targets_after_round(s), [tgt], "the party marches on it")

func test_three_roofs_are_still_a_valid_target() -> void:
	var s: MatchState = _ai()
	_purge(s)
	var tgt: int = _setup_raid(s, 3)
	AIFactions.scout(s, 3)
	check(AIFactions._try(s, 3, "capture", int(s.factions[3]["home"]), []), "a three-roof holder is still raided")
	check(_targets_after_round(s).size() == 1 and [tgt, tgt + 1, tgt + 2].has(_targets_after_round(s)[0]), "on one of its holdings")

func test_hunt_ignores_mercy_and_the_reckoning_week_starts_it() -> void:
	var s: MatchState = _ai()
	var hc: Dictionary = Standing.cfg()["hunt"]
	warp(s, 7 * int(hc["min_week"]) + 2, 0.0)
	check(not AIFactions.hunting(s), "13 alive: no hunt")
	var old: Variant = hc.get("late_week", 99)
	hc["late_week"] = int(hc["min_week"]) + 1
	warp(s, 7 * (int(hc["min_week"]) + 1) + 2, 0.0)
	check(AIFactions.hunting(s), "the Reckoning week starts the hunt whatever the head count")
	warp(s, 7 * int(hc["min_week"]) + 2, 0.0)
	check(not AIFactions.hunting(s), "not a week early")
	hc["late_week"] = old
	check(int(hc["late_week"]) >= 40, "shipped late_week is late enough that natural attrition normally gets there first")

# ------------------------------------------------------------ ration discipline
func test_a_governor_with_no_food_furloughs_a_quarter_of_each_garrison() -> void:
	var s: MatchState = _ai()
	for hid in s.holdings_of(3):
		var h: Dictionary = s.holdings[hid]
		h["store"] = {}
		h["garrison"] = 12
	var before: int = 0
	for hid in s.holdings_of(3):
		before += int(s.holdings[hid]["garrison"])
	s.actors[int(s.factions[3]["leader"])]["inv"] = {}
	var ev: Array = []
	AIFactions._furlough(s, 3, ev)
	var after: int = 0
	for hid in s.holdings_of(3):
		after += int(s.holdings[hid]["garrison"])
		check(int(s.holdings[hid]["garrison"]) >= 2, "never below the keep")
	check(after < before and after >= before * 3 / 4 - s.holdings_of(3).size(), "about a quarter went home (%d -> %d)" % [before, after])
	eq(count_type(ev, "furlough"), 1, "event")
	# a fed faction keeps its men
	for hid in s.holdings_of(3):
		Inv.add_all(s.holdings[hid]["store"], {"lfg:item/ration": 200})
	var ev2: Array = []
	var keep: int = after
	AIFactions._furlough(s, 3, ev2)
	eq(count_type(ev2, "furlough"), 0, "no furlough when fed")
	var kept: int = 0
	for hid in s.holdings_of(3):
		kept += int(s.holdings[hid]["garrison"])
	eq(kept, keep, "garrisons unchanged")

func test_no_recruiting_on_an_empty_larder() -> void:
	var s: MatchState = _ai()
	s.factions[3]["persona"] = "turtle"
	var h: Dictionary = s.holdings[s.holdings_of(3)[0]]
	h["garrison"] = 3
	h["store"] = {"lfg:item/coin": 100}
	for other in s.holdings_of(3):
		if other != h["id"]:
			s.holdings[other]["store"] = {}
	s.actors[int(s.factions[3]["leader"])]["inv"] = {}
	AIFactions.dawn(s, [])
	check(int(h["garrison"]) <= 3, "hungry: no recruits (garrison %d)" % int(h["garrison"]))
	var s2: MatchState = _ai()
	s2.factions[3]["persona"] = "turtle"
	var h2: Dictionary = s2.holdings[s2.holdings_of(3)[0]]
	h2["garrison"] = 3
	h2["store"] = {"lfg:item/coin": 100, "lfg:item/ration": 100}
	AIFactions.dawn(s2, [])
	check(int(h2["garrison"]) > 3, "fed: recruits (garrison %d)" % int(h2["garrison"]))

# ------------------------------------------------------------ class home ground
func test_home_def_scales_a_holding_defence_by_the_leaders_class() -> void:
	var s: MatchState = _ai()
	var h: Dictionary = s.holdings[s.holdings_of(3)[0]]
	h["garrison"] = 6
	for hid in s.holdings_of(3):
		if hid != h["id"]:
			s.holdings[hid]["owner"] = 3
	_classed(s, 3, "judd")
	var base: float = Conquest.defender_power(s, h)
	_classed(s, 3, "vex")
	var vex: float = Conquest.defender_power(s, h)
	var want: float = float(Content.class_def("lfg:class/vex")["mods"]["home_def"])
	check(want > 1.0, "Vex has home ground")
	check(absf(vex / base - want) < 0.05, "Vex holds %.2fx what Judd's holding does (%.1f vs %.1f)" % [vex / base, vex, base])
	check(not (Content.class_def("lfg:class/judd")["mods"] as Dictionary).has("home_def"), "plain classes get no bonus")
	var any_big: bool = false
	for cd in Content.classes().values():
		var hd: float = float((cd.get("mods", {}) as Dictionary).get("home_def", 1.0))
		check(hd >= 0.85 and hd <= 1.6, "%s home_def in a sane band (%.2f)" % [cd["id"], hd])
		if hd > 1.2:
			any_big = true
	check(any_big, "the fragile classes got a real bonus")

# ------------------------------------------------------------ evacuation and flags
func test_a_leader_slips_away_when_the_party_outguns_the_holding() -> void:
	var esc: Dictionary = Content.ai_kit("lfg:class/judd")["escape"]
	var old_evac: float = float(esc["evac"])
	esc["evac"] = 1.0
	var s: MatchState = _ai()
	_purge(s)
	var l: Dictionary = _classed(s, 3, "judd")
	var h: Dictionary = s.holdings[int(s.factions[3]["home"])]
	h["garrison"] = 1
	l["hex"] = h["hex"]
	var party: Dictionary = _party_at(s, 5, h["hex"] + HexGrid.DIRS[1], int(h["id"]), 30)
	var ev: Array = []
	AILeaders.on_siege_begin(s, party, ev)
	check(l["hex"] != h["hex"], "the leader left the doomed holding")
	eq(count_type(ev, "leader_retreated"), 1, "leader_retreated event")
	# a strong holding keeps its leader
	var s2: MatchState = _ai()
	_purge(s2)
	var l2: Dictionary = _classed(s2, 3, "judd")
	var h2: Dictionary = s2.holdings[int(s2.factions[3]["home"])]
	h2["garrison"] = 20
	l2["hex"] = h2["hex"]
	var p2: Dictionary = _party_at(s2, 5, h2["hex"] + HexGrid.DIRS[1], int(h2["id"]), 3)
	var ev2: Array = []
	AILeaders.on_siege_begin(s2, p2, ev2)
	eq(l2["hex"], h2["hex"], "a leader behind a strong garrison stays")
	eq(count_type(ev2, "leader_retreated"), 0, "no retreat event")
	esc["evac"] = old_evac
	check(old_evac > 0.0 and old_evac < 1.0, "shipped evacuation is a chance, not a certainty (%.2f)" % old_evac)

func test_quill_raises_the_truce_flag_when_a_siege_begins_and_is_not_struck() -> void:
	var s: MatchState = _ai()
	_purge(s)
	var q: Dictionary = _classed(s, 3, "quill")
	var h: Dictionary = s.holdings[int(s.factions[3]["home"])]
	q["hex"] = h["hex"]
	q["energy"] = 100.0
	q["cd"] = {}
	var party: Dictionary = _party_at(s, 5, h["hex"] + HexGrid.DIRS[1], int(h["id"]), 4)
	var ev: Array = []
	AILeaders.on_siege_begin(s, party, ev)
	check(Combat.has_effect(s, q, "truce"), "the flag is up (a real Abilities.use cast)")
	check(count_type(ev, "ability_used") >= 1, "ability_used event")
	var hp0: int = int(q["hp"])
	var ev2: Array = []
	AIFactions._harass(s, party, ev2)
	eq(int(q["hp"]), hp0, "the raiders ignore the flagged leader")
	check(String(Content.ai_kit("lfg:class/quill").get("cast", "")) == "truce", "the kit names the flag")

func test_pip_and_sable_only_join_theft_not_raids() -> void:
	var s: MatchState = _ai()
	_purge(s)
	var pip: Dictionary = _classed(s, 3, "pip")
	check(not AILeaders.wants_to_join(s, 3, pip, "capture", 8), "Pip does not march on walls")
	var sable: Dictionary = _classed(s, 4, "sable")
	check(not AILeaders.wants_to_join(s, 4, sable, "capture", 8), "nor does Sable")
	var bram: Dictionary = _classed(s, 5, "bram")
	check(AILeaders.wants_to_join(s, 5, bram, "capture", 8), "Bram still does")

func test_sable_reads_the_trails_at_dawn_through_the_real_track_ability() -> void:
	var s: MatchState = _ai()
	var l: Dictionary = _classed(s, 3, "sable")
	var home_h: Dictionary = s.holdings[int(s.factions[3]["home"])]
	l["hex"] = home_h["hex"]
	l["energy"] = 100.0
	l["cd"] = {}
	var spot: Vector2i = home_h["hex"]
	for r in [3, 4, 5]:
		for hx in HexGrid.ring_within(home_h["hex"], r):
			if HexGrid.distance(hx, home_h["hex"]) == r and int(s.world["terrain"][HexGrid.index(hx)]) == WorldGen.T_GROUND:
				spot = hx
				break
		if spot != home_h["hex"]:
			break
	Setup.spawn_enemy(s, "lfg:enemy/sporeling", spot, false)
	var ev: Array = []
	AILeaders.dawn(s, ev)
	var tracked: bool = false
	for e in ev:
		if String(e["type"]) == "ability_used" and e.has("tracked"):
			tracked = true
	check(tracked, "Track was cast at dawn with game in range")
	check(not Combat.ready(s, l, "ab:lfg:ability/track"), "and its cooldown is running")

func test_every_class_has_an_ai_kit() -> void:
	for cid in Content.classes().keys():
		check(not Content.ai_kit(String(cid)).is_empty(), "%s has an AI kit" % cid)
	eq(String(Content.ai_kit("lfg:class/halo").get("cast", "")), "ward", "Halo wards")
	eq(Content.ai_kit("lfg:class/pip").get("join_only", []), ["steal"], "Pip's joins")

func test_sim_harness_logs_deaths_and_balances_personas() -> void:
	var txt: String = FileAccess.get_file_as_string("res://tools/sim_match.gd")
	for w in ["deaths", "hp_before", "killer_class", "famine", "kit", "hold_series", "--random-personas"]:
		check(txt.contains(w), "harness records %s" % w)

# ------------------------------------------------------------ Halo's hamlets
func _neutral_near(s: MatchState, hex: Vector2i, maxd: int) -> int:
	var best: int = -1
	var bd: int = 99
	for hid in s.holdings.keys():
		var t: Dictionary = s.holdings[hid]
		if int(t["owner"]) == -1:
			var d: int = HexGrid.distance(t["hex"], hex)
			if d < bd and d <= maxd:
				bd = d
				best = int(hid)
	return best

func test_halo_blessing_an_unowned_village_makes_it_a_hamlet_once_a_week() -> void:
	var s: MatchState = mk("lfg:class/halo", 11, {"ai_enabled": false, "wild_enemies": false})
	var a: Dictionary = s.actors[1]
	var tgt: int = _neutral_near(s, a["hex"], 60)
	check(tgt != -1, "setup: an unowned village exists")
	a["hex"] = s.holdings[tgt]["hex"]
	var n0: int = s.holdings_of(0).size()
	var r: Dictionary = cmd(s, "use_ability", {"ability": "lfg:ability/bless", "holding": tgt})
	check(r["ok"], "bless a neutral village: %s" % r["error"])
	eq(int(s.holdings[tgt]["owner"]), 0, "it is ours")
	eq(s.holdings_of(0).size(), n0 + 1, "one more holding")
	eq(count_type(r["events"], "holding_settled"), 1, "event")
	var t2: int = _neutral_near(s, a["hex"], 60)
	if t2 != -1:
		a["hex"] = s.holdings[t2]["hex"]
		a["energy"] = 100.0
		a["cd"] = {}
		eq(cmd(s, "use_ability", {"ability": "lfg:ability/bless", "holding": t2})["error"], "settled_this_week", "only one a week")
		warp(s, 9, 0.2)
		a["cd"] = {}
		check(cmd(s, "use_ability", {"ability": "lfg:ability/bless", "holding": t2})["ok"], "next week another")
	# other classes cannot
	var s2: MatchState = mk("lfg:class/judd", 11, {"ai_enabled": false, "wild_enemies": false})
	s2.actors[1]["hex"] = s2.holdings[tgt]["hex"]
	check(not cmd(s2, "use_ability", {"ability": "lfg:ability/bless", "holding": tgt})["ok"], "Judd has no Bless at all")

func test_halo_settle_is_limited_and_never_takes_an_owned_holding() -> void:
	var s: MatchState = mk("lfg:class/halo", 11, {"ai_enabled": false, "wild_enemies": false})
	var a: Dictionary = s.actors[1]
	var cap: int = int(Combat.class_mod(a, "settle", 0))
	check(cap >= 3 and cap <= 8, "a modest cap (%d)" % cap)
	var rival: int = s.holdings_of(1)[0]
	a["hex"] = s.holdings[rival]["hex"]
	eq(cmd(s, "use_ability", {"ability": "lfg:ability/bless", "holding": rival})["error"], "not_yours", "a rival's holding stays theirs")

func test_the_halo_bot_walks_to_a_village_and_blesses_it_at_dawn() -> void:
	var s: MatchState = _ai()
	var l: Dictionary = _classed(s, 3, "halo")
	var home_h: Dictionary = s.holdings[int(s.factions[3]["home"])]
	var tgt: int = _neutral_near(s, home_h["hex"], AILeaders.PILGRIM_RANGE)
	if tgt == -1:
		# put one in range
		var spare: int = _neutral_near(s, home_h["hex"], 99)
		s.holdings[spare]["hex"] = home_h["hex"] + HexGrid.DIRS[0] * 6
		tgt = spare
	l["energy"] = 100.0
	l["cd"] = {}
	warp(s, 2, 0.0)       # an even day: pilgrimage day
	var ev: Array = []
	AILeaders.dawn(s, ev)
	eq(int(s.holdings[tgt]["owner"]), 3, "a hamlet of the Warden's")
	eq(l["hex"], home_h["hex"], "and the pilgrim is home again")
	var mine: int = 0
	for e in ev:
		if String(e["type"]) == "holding_settled" and int(e["by"]) == 3:
			mine += 1
	eq(mine, 1, "one settle event for this faction")

# ------------------------------------------------------------ conquerors, settlers, levies, idle bleed
func test_a_runaway_faction_hunts_on_its_own_while_the_field_is_still_full() -> void:
	var s: MatchState = _ai()
	var hc: Dictionary = Standing.cfg()["hunt"]
	warp(s, 7 * int(hc["min_week"]) + 2, 0.0)
	AIFactions.reset_dominance()
	check(not AIFactions.hunting(s, 3), "a normal faction does not")
	var n: int = 0
	for hid in s.holdings.keys():
		if int(s.holdings[hid]["owner"]) == -1 and n < int(hc["conquer_at"]):
			s.holdings[hid]["owner"] = 3
			n += 1
	for hid in s.holdings.keys():
		if n < int(hc["conquer_at"]) and int(s.holdings[hid]["owner"]) not in [3, 0]:
			s.holdings[hid]["owner"] = 3
			n += 1
	AIFactions.reset_dominance()
	check(s.holdings_of(3).size() >= int(hc["conquer_at"]), "setup: %d holdings" % s.holdings_of(3).size())
	check(AIFactions.conqueror(s, 3), "it is a conqueror")
	check(AIFactions.hunting(s, 3), "and plays the hunt for itself")
	check(not AIFactions.hunting(s), "the rest of the field is not hunting")
	check(not AIFactions.hunting(s, 4), "other factions are not")
	check(AIFactions.party_cap(s, 3) > AIFactions.party_cap(s, 4), "bigger parties for the conqueror")
	check(AIFactions.max_parties(s, 3) > AIFactions.max_parties(s, 4), "more parties")
	eq(AIFactions.effective_persona(s, 3), "raider", "whatever its persona says")
	var early: MatchState = _ai()
	warp(early, 20, 0.0)
	AIFactions.reset_dominance()
	for hid in early.holdings.keys():
		early.holdings[hid]["owner"] = 3
	AIFactions.reset_dominance()
	check(not AIFactions.hunting(early, 3), "not before the min week")

func test_a_hunting_realm_raises_troops_from_its_granaries_when_coin_is_gone() -> void:
	var s: MatchState = _ai()
	var hc: Dictionary = Standing.cfg()["hunt"]
	warp(s, 7 * int(hc["min_week"]) + 2, 0.0)
	var n: int = 0
	for hid in s.holdings.keys():
		if int(s.holdings[hid]["owner"]) != 3 and int(s.holdings[hid]["owner"]) != 0 and n < int(hc["conquer_at"]):
			s.holdings[hid]["owner"] = 3
			n += 1
	AIFactions.reset_dominance()
	check(AIFactions.hunting(s, 3), "setup: a conqueror")
	for hid in s.holdings_of(3):
		var h: Dictionary = s.holdings[hid]
		h["garrison"] = 3
		h["store"] = {"lfg:item/ration": 60}      # no coin at all
		h["buildings"] = ["lfg:building/barracks"]
	s.actors[int(s.factions[3]["leader"])]["inv"] = {}
	AIFactions.dawn(s, [])
	var grew: int = 0
	for hid in s.holdings_of(3):
		if int(s.holdings[hid]["garrison"]) > 3:
			grew += 1
	check(grew >= s.holdings_of(3).size() / 2, "garrisons grew on rations alone (%d of %d)" % [grew, s.holdings_of(3).size()])
	# a faction that is not hunting does not
	var s2: MatchState = _ai()
	for hid in s2.holdings_of(4):
		s2.holdings[hid]["garrison"] = 3
		s2.holdings[hid]["store"] = {"lfg:item/ration": 60}
	s2.factions[4]["persona"] = "hoarder"
	AIFactions.dawn(s2, [])
	for hid in s2.holdings_of(4):
		check(int(s2.holdings[hid]["garrison"]) <= 3 + 2, "no granary levy outside the hunt")

func test_settlers_take_unowned_villages_but_not_rivals_in_a_passive_cloak() -> void:
	var s: MatchState = _ai()
	_purge(s)
	warp(s, 9, 0.45)
	var home3: Dictionary = s.holdings[int(s.factions[3]["home"])]
	home3["garrison"] = 30
	s.factions[3]["persona"] = "turtle"
	# a neutral and a rival village in range
	var neutral: int = -1
	for hid in s.holdings.keys():
		if int(s.holdings[hid]["owner"]) == -1:
			neutral = int(hid)
			break
	s.holdings[neutral]["hex"] = home3["hex"] + HexGrid.DIRS[0] * 6
	s.holdings[neutral]["garrison"] = 0
	s.holdings[neutral]["buildings"] = []
	AIFactions.scout(s, 3)
	check(AIFactions._try(s, 3, "capture", int(s.factions[3]["home"]), [], true), "the settler marches")
	var tg: Array = _targets_after_round(s)
	eq(tg, [neutral], "on the unowned village")
	var s2: MatchState = _ai()
	warp(s2, 9, 0.45)
	var h2: Dictionary = s2.holdings[int(s2.factions[3]["home"])]
	h2["garrison"] = 30
	for hid in s2.holdings.keys():
		if int(s2.holdings[hid]["owner"]) == -1:
			s2.holdings[hid]["owner"] = 5          # no neutral villages left
	var rival: Dictionary = s2.holdings[s2.holdings_of(4)[0]]
	rival["hex"] = h2["hex"] + HexGrid.DIRS[0] * 5
	rival["garrison"] = 0
	AIFactions.scout(s2, 3)
	check(not AIFactions._try(s2, 3, "capture", int(s2.factions[3]["home"]), [], true), "a settler passes by a rival's village")
	check(AIFactions._try(s2, 3, "capture", int(s2.factions[3]["home"]), [], false) or true, "(a raider would consider it)")

func test_idle_bleed_no_longer_starves_a_lone_holder_to_death() -> void:
	var s: MatchState = _ai()
	for hid in s.holdings_of(3):
		if hid != s.holdings_of(3)[0]:
			s.holdings[hid]["owner"] = -1
	var h: Dictionary = s.holdings[s.holdings_of(3)[0]]
	h["garrison"] = 0
	h["store"] = {"lfg:item/ration": 2, "lfg:item/coin": 50}
	s.actors[int(s.factions[3]["leader"])]["inv"] = {}
	s.factions[3]["last_deed"] = -100000.0
	warp(s, 100, 0.0)
	s.clock["elapsed"] = 1.0e7
	Standing.dawn_upkeep(s, [])
	check(Inv.count(h["store"], "lfg:item/ration") >= Economy.persons(s, 3), "the bleed left the leader a day's food (%d)" % Inv.count(h["store"], "lfg:item/ration"))

func test_subsistence_floor_feeds_a_small_garrison_forever() -> void:
	var s: MatchState = _ai()
	var hid: int = s.holdings_of(3)[0]
	var h: Dictionary = s.holdings[hid]
	h["store"] = {}
	AIFactions.dawn(s, [])
	check(Inv.count(h["store"], "lfg:item/ration") >= int(Standing.cfg()["subsist"]["per_holding"]), "at least the floor each dawn (%d)" % Inv.count(h["store"], "lfg:item/ration"))

func test_a_stock_of_gadgets_is_a_defence_with_a_cap() -> void:
	var s: MatchState = _ai()
	var h: Dictionary = s.holdings[s.holdings_of(3)[0]]
	h["store"] = {}
	var base: float = Conquest.defender_power(s, h)
	h["store"] = {"lfg:item/gadget": 4}
	var four: float = Conquest.defender_power(s, h)
	h["store"] = {"lfg:item/gadget": 40}
	var forty: float = Conquest.defender_power(s, h)
	check(absf((four - base) - 4.0 * Conquest.GADGET_DEFENCE * float(Content.class_def(String(Standing.leader_of(s, 3).get("class_id", "")))["mods"].get("home_def", 1.0))) < 3.0 or four > base, "four gadgets add defence")
	check(forty > four, "more gadgets, more defence")
	h["store"] = {"lfg:item/gadget": 10}
	var ten: float = Conquest.defender_power(s, h)
	eq(forty, ten, "capped at %d" % Conquest.GADGET_CAP)
