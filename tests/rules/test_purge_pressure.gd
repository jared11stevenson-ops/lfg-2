extends RulesTestBase
## Purge pressure and ways in: Purge-only crops/materials, escalation, non-lethal commands, pacifist deed routes (docs/INCENTIVES.md, COMMUNITY_RPG.md).

func _purge(s: MatchState) -> void:
	warp(s, 7, 0.6)

func _other_leader(s: MatchState, fid: int) -> Dictionary:
	return Standing.leader_of(s, fid)

# ------------------------------------------------------------ purgebloom
func test_purgebloom_grows_only_through_tended_purges() -> void:
	var s: MatchState = quiet()
	Standing.set_rank(s, 0, 4)
	give(s, 1, {"lfg:item/purgebloom_seed": 3})
	var near: Vector2i = home(s)["hex"] + HexGrid.DIRS[0]
	eq(cmd(s, "plant", {"crop": "lfg:crop/purgebloom", "hex": near})["error"], "needs_outdoors", "must be tended outdoors, not under the walls")
	var out: Vector2i = home(s)["hex"] + HexGrid.DIRS[0] * 2
	var r: Dictionary = cmd(s, "plant", {"crop": "lfg:crop/purgebloom", "hex": out})
	check(r["ok"], "plant outdoors: %s" % r["error"])
	var key: String = MatchState.plot_key(out)
	eq(cmd(s, "water", {"hex": out})["error"], "purge_only", "cannot be tended in PEACE")
	# peace dawns do nothing, and it never withers
	for i in range(5):
		warp(s, 2 + i, 0.0)
		Farming.dawn_crops(s, [])
	eq(int(s.plots[key]["age"]), 0, "it does not grow in peacetime")
	check(s.plots.has(key), "and does not wither")
	# an untended Purge: no growth
	_purge(s)
	var ev: Array = tick_all(s, 60.0 * 0.45, 1.0)
	eq(int(s.plots[key]["age"]), 0, "untended Purge: no growth")
	# two tended Purges: ripe
	for round in range(2):
		warp(s, 7 * (round + 1) + 7, 0.6)
		s.actors[1]["hex"] = out
		check(cmd(s, "water", {"hex": out})["ok"], "tend during PURGE_ACTIVE")
		eq(cmd(s, "water", {"hex": out})["error"], "already_watered", "once per Purge")
		s.actors[1]["hp"] = s.actors[1]["max_hp"]
		tick_all(s, 60.0 * 0.45, 1.0)
	eq(int(s.plots[key]["age"]), 2, "two tended Purges")
	s.actors[1]["hex"] = home(s)["hex"] + HexGrid.DIRS[0]
	check(cmd(s, "harvest", {"hex": out})["ok"], "harvest the bloom")
	check(Inv.count(s.actors[1]["inv"], "lfg:item/purgebloom") >= 3, "purgebloom in the pack")

func test_purgebloom_is_rank_gated() -> void:
	var s: MatchState = quiet()
	give(s, 1, {"lfg:item/purgebloom_seed": 1})
	eq(cmd(s, "plant", {"crop": "lfg:crop/purgebloom", "hex": home(s)["hex"] + HexGrid.DIRS[0] * 2})["error"], "rank_required", "rank 4 crop")

# ------------------------------------------------------------ ashmarrow
func test_raiders_and_wave_beasts_drop_ashmarrow() -> void:
	var s: MatchState = quiet()
	_purge(s)
	var eid: int = Setup.spawn_enemy(s, "lfg:enemy/sporeling", home(s)["hex"] + HexGrid.DIRS[1], true)
	var ev: Array = []
	Combat.kill(s, eid, 1, ev)
	check(Inv.count(s.actors[1]["inv"], "lfg:item/ashmarrow") >= 1, "a wave beast drops ashmarrow to the killer")
	var wild: int = Setup.spawn_enemy(s, "lfg:enemy/sporeling", home(s)["hex"] + HexGrid.DIRS[2], false)
	var before: int = Inv.count(s.actors[1]["inv"], "lfg:item/ashmarrow")
	Combat.kill(s, wild, 1, ev)
	eq(Inv.count(s.actors[1]["inv"], "lfg:item/ashmarrow"), before, "ordinary wild beasts do not")
	check(Content.item("lfg:item/ashmarrow").size() > 0, "item defined")

func test_wave_kills_are_raider_deeds_with_points() -> void:
	var s: MatchState = quiet()
	_purge(s)
	var eid: int = Setup.spawn_enemy(s, "lfg:enemy/sporeling", s.actors[1]["hex"] + HexGrid.DIRS[0], true)
	s.actors[eid]["hp"] = 1
	var r: Dictionary = cmd(s, "attack", {"target": eid})
	check(r["ok"], "attack: %s" % r["error"])
	var kinds: Array = r["events"].filter(func(e: Dictionary) -> bool: return String(e["type"]) == "deed").map(func(e: Dictionary) -> String: return e["kind"])
	eq(kinds, ["kill_raider"], "a Purge-wave beast counts as a raider kill")
	check(int(s.actors[1]["sp"]) >= 2, "and pays points")

# ------------------------------------------------------------ recipes: every rank recipe is solo-completable
func test_every_recipe_and_crop_is_completable_without_trade_or_other_players() -> void:
	# Items reachable by one self-sufficient leader: start kits, crops (any rank), recipes, buildings' work, enemy loot, abilities' yields.
	var have: Dictionary = {}
	for cd in Content.classes().values():
		for k in cd["start_kit"].keys():
			have[k] = true
	have["lfg:item/coin"] = true
	for k in ["lfg:item/timber", "lfg:item/stone", "lfg:item/mushroom", "lfg:item/spore_sac", "lfg:item/game_meat"]:
		have[k] = true      # mining, foraging, hunting (class abilities) and wild loot
	for e in Content.enemies().values():
		for k in e["loot"].keys():
			have[k] = true
	have["lfg:item/ashmarrow"] = true      # Purge raiders / wave beasts
	have["lfg:item/gadget"] = true
	for b in Content.buildings().values():      # pass 4: buildings that make things (apiary honey ...) and creatures that lay or haul (Brindlehen's eggs)
		for k in ((b.get("work", {}) as Dictionary).get("outputs", {}) as Dictionary).keys():
			have[String(k)] = true
	for cp in Content.companions().values():
		for k in (cp.get("post", {}).get("produce", {}) as Dictionary).keys():
			have[String(k)] = true
	for t in Content.poi_types().values():      # points of interest pay weekly, to anyone who walks there (data/pois.json)
		for k in (t["loot"] as Dictionary).keys():
			if int(t["loot"][k][1]) > 0:
				have[k] = true
	var changed: bool = true
	var guard: int = 0
	while changed and guard < 20:
		guard += 1
		changed = false
		for c in Content.crops().values():
			if have.has(c["seed"]) and not have.has(c["item"]):
				have[c["item"]] = true
				changed = true
		for r in Content.recipes().values():
			var ok: bool = true
			for k in r["inputs"].keys():
				if not have.has(k):
					ok = false
			if ok:
				for k in r["outputs"].keys():
					if not have.has(k):
						have[k] = true
						changed = true
	for c in Content.crops().values():
		check(have.has(c["item"]), "crop %s is reachable solo" % c["id"])
	for r in Content.recipes().values():
		for k in r["inputs"].keys():
			check(have.has(k), "recipe %s input %s is reachable solo" % [r["id"], k])
	for b in Content.buildings().values():
		for k in b["cost"].keys():
			check(have.has(k), "building %s cost %s reachable solo" % [b["id"], k])
	# nothing needs a merchant: the only thing a recipe can ask of a class is its own tag, and rank recipes ask for none
	for r in Content.recipes().values():
		if int(r.get("rank", 0)) > 0:
			check(not r.has("requires_tag"), "rank recipe %s needs no class" % r["id"])

# ------------------------------------------------------------ escalation
func test_each_purge_is_larger_than_the_last() -> void:
	var a: MatchState = mk("lfg:class/judd", 11, {"ai_enabled": false})
	var b: MatchState = mk("lfg:class/judd", 11, {"ai_enabled": false})
	for st in [a, b]:
		st.actors[1]["max_hp"] = 100000
		st.actors[1]["hp"] = 100000
	warp(a, 7 * 1 + 7, 0.49)
	warp(b, 7 * 9 + 7, 0.49)
	var wa: Array = tick_all(a, 60.0 * 0.05, 1.0).filter(func(e: Dictionary) -> bool: return String(e["type"]) == "purge_wave")
	var wb: Array = tick_all(b, 60.0 * 0.05, 1.0).filter(func(e: Dictionary) -> bool: return String(e["type"]) == "purge_wave")
	check(wa.size() == 1 and wb.size() == 1, "waves spawned")
	check(wb[0]["enemies"].size() > wa[0]["enemies"].size(), "week 10's wave is bigger than week 2's (%d vs %d)" % [wb[0]["enemies"].size(), wa[0]["enemies"].size()])
	check(AIFactions.max_dispatch(b) > AIFactions.max_dispatch(a), "more raid parties are dispatched later")
	check(AIFactions.party_cap(b) > AIFactions.party_cap(a), "and each is bigger")

func test_waves_are_bigger_for_a_marked_player() -> void:
	var sizes: Array = []
	for marked in [false, true]:
		var s: MatchState = mk("lfg:class/judd", 11, {"ai_enabled": false})
		s.actors[1]["max_hp"] = 100000
		s.actors[1]["hp"] = 100000
		s.sim_acc["mark"] = 0 if marked else -1
		warp(s, 7 * 4 + 7, 0.49)
		var w: Array = tick_all(s, 60.0 * 0.05, 1.0).filter(func(e: Dictionary) -> bool: return String(e["type"]) == "purge_wave")
		check(w.size() == 1, "wave spawned")
		sizes.append(w[0]["enemies"].size())
	check(sizes[1] > sizes[0], "a Marked player faces more beasts (%d vs %d)" % [sizes[1], sizes[0]])

func test_ai_mark_bleeds_garrisons_at_purge_start() -> void:
	var s: MatchState = quiet()
	s.sim_acc["mark"] = 4
	var hs: Array = s.holdings_of(4)
	s.holdings[hs[0]]["garrison"] = 24
	var ev: Array = []
	Standing.mark_pressure(s, ev)
	check(int(s.holdings[hs[0]]["garrison"]) < 24, "the Purge targets the Marked")
	eq(count_type(ev, "mark_pressure"), 1, "event")

# ------------------------------------------------------------ non-lethal / pacifist commands
func test_scout_earns_a_deed_once_per_holding_per_purge() -> void:
	var s: MatchState = quiet("lfg:class/halo")
	var rival: int = s.holdings_of(3)[0]
	s.actors[1]["hex"] = s.holdings[rival]["hex"] + HexGrid.DIRS[0]
	eq(cmd(s, "scout", {"holding": rival})["error"], "not_purge", "only in the Purge")
	_purge(s)
	var r: Dictionary = cmd(s, "scout", {"holding": rival})
	check(r["ok"], "a pacifist can scout: %s" % r["error"])
	check(count_type(r["events"], "scouted") == 1 and count_type(r["events"], "deed") == 1, "scouted + deed")
	s.actors[1]["cd"] = {}
	eq(cmd(s, "scout", {"holding": rival})["error"], "already_scouted", "once per holding")
	s.actors[1]["hex"] = Vector2i(0, 0)
	eq(cmd(s, "scout", {"holding": s.holdings_of(4)[0]})["error"], "too_far", "must be near")

func test_escort_carries_rations_to_an_outlying_holding() -> void:
	var s: MatchState = quiet("lfg:class/halo")
	var far: int = -1
	for id in s.holdings.keys():
		if HexGrid.distance(s.holdings[id]["hex"], home(s)["hex"]) >= 6 and int(s.holdings[id]["owner"]) == -1:
			far = id
			break
	s.holdings[far]["owner"] = 0
	s.actors[1]["hex"] = s.holdings[far]["hex"]
	give(s, 1, {"lfg:item/ration": 10})
	eq(cmd(s, "escort", {"holding": far, "qty": 5})["error"], "not_purge", "only in the Purge")
	_purge(s)
	var before: Dictionary = Inv.world_totals(s)
	var r: Dictionary = cmd(s, "escort", {"holding": far, "qty": 5})
	check(r["ok"], "escort: %s" % r["error"])
	eq(Inv.world_totals(s), before, "rations conserved (moved into the store)")
	check(count_type(r["events"], "deed") == 1, "escort deed")
	eq(cmd(s, "escort", {"holding": far, "qty": 3})["error"], "already_escorted", "once per holding per Purge")
	eq(cmd(s, "escort", {"holding": 1, "qty": 3})["error"], "too_far", "the capital is not outlying (and you must stand at the target)")

func test_truce_is_an_ordinary_command_and_pays_a_broker_deed() -> void:
	var s: MatchState = quiet("lfg:class/judd")
	var rv: Dictionary = s.holdings[s.holdings_of(3)[0]]
	s.actors[1]["hex"] = rv["hex"] + HexGrid.DIRS[0]
	give(s, 1, {"lfg:item/coin": 40})
	warp(s, 7, 0.6)
	var before: Dictionary = Inv.world_totals(s)
	var r: Dictionary = cmd(s, "truce", {"faction": 3})
	check(r["ok"], "truce: %s" % r["error"])
	eq(Inv.world_totals(s), before, "the gift moved, nothing was minted")
	check(Standing.truced(s, 0, 3) and Standing.truced(s, 3, 0), "mutual truce")
	check(count_type(r["events"], "deed") == 1, "broker deed")
	eq(cmd(s, "truce", {"faction": 3})["error"], "already_truced", "not twice")
	eq(cmd(s, "truce", {"faction": 0})["error"], "bad_faction", "not with yourself")
	# raiders respect it
	var f3: Dictionary = s.factions[3]
	check(Standing.truced(s, 3, 0), "raiders of faction 3 consult the truce before targeting")

func test_ransom_spares_a_beaten_leader_for_coin() -> void:
	var s: MatchState = quiet("lfg:class/judd")
	var v: Dictionary = _other_leader(s, 3)
	v["hex"] = s.actors[1]["hex"] + HexGrid.DIRS[0]
	v["inv"] = {"lfg:item/coin": 40}
	_purge(s)
	eq(cmd(s, "ransom", {"target": v["id"]})["error"], "not_beaten", "only a beaten leader (<=40% hp)")
	v["hp"] = int(v["max_hp"] * 0.3)
	var before: Dictionary = Inv.world_totals(s)
	var r: Dictionary = cmd(s, "ransom", {"target": v["id"]})
	check(r["ok"], "ransom: %s" % r["error"])
	eq(Inv.world_totals(s), before, "coin moved, not minted")
	check(v["alive"] and s.factions[3]["alive"], "the captive lives")
	check(Inv.count(s.actors[1]["inv"], "lfg:item/coin") >= 20 + 30, "ransom paid")
	var kinds: Array = r["events"].filter(func(e: Dictionary) -> bool: return String(e["type"]) == "deed").map(func(e: Dictionary) -> String: return e["kind"])
	eq(kinds, ["ransom"], "ransom deed")
	check(int(Standing.deed_def("ransom")["standing"]) < int(Standing.deed_def("kill_leader")["standing"]), "pays less than a kill")
	s.actors[1]["cd"] = {}
	eq(cmd(s, "ransom", {"target": v["id"]})["error"], "already_ransomed", "once a week")

func test_sabotage_burns_rations_and_pacifists_cannot() -> void:
	var s: MatchState = quiet("lfg:class/judd")
	var rv: int = s.holdings_of(3)[0]
	s.actors[1]["hex"] = s.holdings[rv]["hex"] + HexGrid.DIRS[0]
	s.holdings[rv]["store"]["lfg:item/ration"] = 30
	s.holdings[rv]["garrison"] = 0
	_purge(s)
	var burned: bool = false
	for i in range(12):
		s.actors[1]["cd"] = {}
		s.actors[1]["hp"] = s.actors[1]["max_hp"]
		var r: Dictionary = cmd(s, "sabotage", {"holding": rv})
		if r["ok"] and count_type(r["events"], "sabotaged") == 1:
			burned = true
			check(count_type(r["events"], "deed") == 1, "sabotage deed")
			break
	check(burned, "sabotage succeeds sometimes")
	check(Inv.count(s.holdings[rv]["store"], "lfg:item/ration") < 30, "rations burned")
	var h: MatchState = quiet("lfg:class/halo")
	h.actors[1]["hex"] = h.holdings[h.holdings_of(3)[0]]["hex"] + HexGrid.DIRS[0]
	_purge(h)
	eq(cmd(h, "sabotage", {"holding": h.holdings_of(3)[0]})["error"], "pacifist", "a pacifist class refuses")

func test_every_class_has_a_pacifist_deed_route_with_commands_only() -> void:
	# scout, escort, truce need no combat class feature at all: any class can use them (checked for Halo, the pacifist, above)
	for k in ["scout", "escort", "broker"]:
		var d: Dictionary = Standing.deed_def(k)
		check(not d.is_empty() and not bool(d["fight"]) and int(d["sp"]) >= 1, "%s is a non-fighting deed that pays points" % k)
	for cid in Content.classes().keys():
		var s: MatchState = quiet(String(cid))
		var rv: int = s.holdings_of(3)[0]
		s.actors[1]["hex"] = s.holdings[rv]["hex"] + HexGrid.DIRS[0]
		_purge(s)
		var r: Dictionary = cmd(s, "scout", {"holding": rv})
		check(r["ok"] and s.actors[1]["sp"] >= 1, "%s earns points by scouting" % cid)
