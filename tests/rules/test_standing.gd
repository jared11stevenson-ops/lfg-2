extends RulesTestBase
## Standing, deeds, ranks, the Mark, thin crown, upkeep/stability, Purge Levy, idle bleed, spoilage, Prosperity (docs/INCENTIVES.md).

func _purge(s: MatchState) -> void:
	warp(s, 7, 0.6)

func _ai_leader(s: MatchState, fid: int) -> Dictionary:
	return Standing.leader_of(s, fid)

func _give_deeds(s: MatchState, fid: int, kind: String, n: int) -> void:
	_purge(s)
	var ev: Array = []
	for i in range(n):
		s.factions[fid]["pcap"] = {}
		Standing.record(s, fid, kind, ev)

# ------------------------------------------------------------ deeds
func test_deeds_only_count_in_the_purge() -> void:
	var s: MatchState = quiet()
	var ev: Array = [{"type": &"holding_captured", "holding": 5, "by": 0, "from": -1, "actor": 1}]
	Standing.observe(s, ev, 0)
	eq(s.factions[0]["deeds"].size(), 0, "PEACE: a capture event is no deed")
	_purge(s)
	Standing.observe(s, ev, 0)
	eq(s.factions[0]["deeds"].size(), 1, "PURGE_ACTIVE: it counts")
	eq(String(s.factions[0]["deeds"][0]["k"]), "capture", "kind")
	check(count_type(ev, "deed") == 1 and count_type(ev, "skill_points") == 1, "deed and skill_points events were emitted")
	eq(s.actors[1]["sp"], 4, "capture pays 4 skill points to the leader")

func test_leader_kill_is_a_deed_and_eliminates_the_victim_faction() -> void:
	var s: MatchState = quiet()
	_purge(s)
	var v: Dictionary = _ai_leader(s, 3)
	v["hex"] = s.actors[1]["hex"] + HexGrid.DIRS[0]
	v["hp"] = 1
	s.actors[1]["atk"] = 50
	var r: Dictionary = cmd(s, "attack", {"target": v["id"]})
	check(r["ok"], "attack: %s" % r["error"])
	check(not s.factions[3]["alive"], "an AI leader's death eliminates its faction")
	var kinds: Array = []
	for e in r["events"]:
		if String(e["type"]) == "deed":
			kinds.append(e["kind"])
	eq(kinds, ["kill_leader"], "one kill_leader deed")
	eq(s.actors[1]["sp"], 6, "kill_leader pays 6 points (the most valuable deed)")
	check(float(s.factions[0]["deeds"][0]["w"]) == 12.0, "standing weight 12")

func test_deed_weights_follow_the_incentive_order() -> void:
	var d: Dictionary = Standing.cfg()["deeds"]
	var sp: Callable = func(k: String) -> int: return int(d[k]["sp"])
	check(sp.call("kill_leader") > sp.call("capture") and sp.call("capture") > sp.call("steal") and sp.call("steal") > sp.call("defend"), "kill > capture > steal > defend")
	for k in ["heal", "broker", "scout", "escort"]:
		check(sp.call("defend") > sp.call(k) or sp.call("defend") >= sp.call(k), "%s is at most a defend" % k)
		check(sp.call(k) >= 1, "%s still earns points" % k)

func test_deeds_decay_over_three_weeks() -> void:
	var s: MatchState = quiet()
	_give_deeds(s, 0, "capture", 1)
	var f: Dictionary = s.factions[0]
	var fresh: float = Standing.deed_score(s, f)
	check(absf(fresh - 8.0) < 0.01, "fresh deed counts in full (%f)" % fresh)
	s.clock["elapsed"] = float(s.clock["elapsed"]) + 10.5 * s.day_seconds
	check(absf(Standing.deed_score(s, f) - 4.0) < 0.2, "half way: half")
	s.clock["elapsed"] = float(s.clock["elapsed"]) + 11.0 * s.day_seconds
	eq(Standing.deed_score(s, f), 0.0, "after ~3 weeks it is gone")
	Standing.recompute(s, [])
	eq(f["deeds"].size(), 0, "and pruned")

func test_pacifist_deed_caps_per_purge() -> void:
	var s: MatchState = quiet()
	_purge(s)
	var ev: Array = []
	var n: int = 0
	for i in range(10):
		if Standing.record(s, 0, "scout", ev):
			n += 1
	eq(n, int(Standing.deed_def("scout")["cap"]), "scouting is capped per Purge so it cannot be farmed")

# ------------------------------------------------------------ ranks
func test_rank_from_score_and_threshold_scaling() -> void:
	var s: MatchState = quiet()
	eq(Standing.rank_of(s, 0), 0, "start as a Settler")
	var t1: float = Standing.threshold(s, 3)
	for fid in [2, 3, 4, 5, 6, 7, 8, 9]:
		s.factions[fid]["alive"] = false
	check(Standing.threshold(s, 3) > t1, "thresholds rise as rivals die (live-faction scaling)")
	var s2: MatchState = quiet()
	_give_deeds(s2, 0, "kill_leader", 3)
	Standing.recompute(s2, [])
	check(Standing.rank_of(s2, 0) >= 2, "36 standing of deeds lifts the rank (%d)" % Standing.rank_of(s2, 0))
	var ev: Array = []
	Standing.recompute(s2, ev)
	eq(count_type(ev, "rank_changed"), 0, "no event without a change")

func test_ranks_buff_production_access_logistics_never_combat() -> void:
	var s: MatchState = quiet()
	var cfg: Array = Standing.cfg()["ranks"]
	eq(cfg.size(), 6, "ranks 0-5")
	var allowed: Array = ["growth_pct", "yield", "plots", "carry", "garrison", "supply", "price_pct", "unlock"]
	for r in cfg:
		for k in (r as Dictionary).keys():
			check(allowed.has(k), "rank key %s is production/access/logistics" % k)
	var atk0: float = Combat.atk_of(s, s.actors[1])
	var def0: float = Combat.def_of(s, s.actors[1])
	var pw0: float = Conquest.attacker_power(s, s.actors[1], 5)
	Standing.set_rank(s, 0, 5)
	eq(Combat.atk_of(s, s.actors[1]), atk0, "rank 5 does not change attack")
	eq(Combat.def_of(s, s.actors[1]), def0, "rank 5 does not change defence")
	eq(Conquest.attacker_power(s, s.actors[1], 5), pw0, "rank 5 does not change raid power")
	var prev: Dictionary = Standing.rank_def(0)
	for r in range(1, 6):
		var cur: Dictionary = Standing.rank_def(r)
		for k in ["growth_pct", "plots", "carry", "garrison", "supply", "price_pct"]:
			check(float(cur[k]) >= float(prev[k]), "%s never falls with rank" % k)
		prev = cur
	Standing.set_rank(s, 0, 0)
	var plots0: int = Standing.plot_cap(s, 0)
	var gar0: int = Standing.garrison_cap(s, s.holdings[1])
	var sup0: int = Standing.supply_range(s, 0)
	Standing.set_rank(s, 0, 4)
	check(Standing.plot_cap(s, 0) > plots0 and Standing.garrison_cap(s, s.holdings[1]) > gar0 and Standing.supply_range(s, 0) > sup0, "plot slots, garrison cap and supply range rise")
	check(Standing.growth_frac(s, 0) > 0.0, "crops grow faster")
	check(Standing.yield_bonus(s, s.holdings[1]) >= 1, "yield bonus step")

func test_rank_raises_crop_growth_and_harvest_yield() -> void:
	var fast: MatchState = quiet()
	var slow: MatchState = quiet()
	Standing.set_rank(fast, 0, 5)
	var key: String = MatchState.plot_key(neighbor_plot(fast, 0))
	for st in [fast, slow]:
		st.plots[key] = {"crop": "lfg:crop/moonbean", "age": 0, "watered": false, "dry_days": 0, "holding": 1}
	for i in range(4):
		Farming.dawn_crops(fast, [])
		Farming.dawn_crops(slow, [])
	eq(int(slow.plots[key]["age"]), 4, "unranked: 4 dawns, 4 stages")
	eq(int(fast.plots[key]["age"]), 5, "rank 5 (+25%%/dawn): an extra stage after 4 dawns")
	# harvest yield: +2 steps at rank 4
	var h: Vector2i = neighbor_plot(slow, 1)
	var h2: Vector2i = neighbor_plot(fast, 1)
	Standing.set_rank(fast, 0, 4)
	for pair in [[slow, h], [fast, h2]]:
		var st: MatchState = pair[0]
		st.plots[MatchState.plot_key(pair[1])] = {"crop": "lfg:crop/sporebean", "age": 4, "watered": false, "dry_days": 0, "holding": 1}
		check(cmd(st, "harvest", {"hex": pair[1]})["ok"], "harvest")
	var diff: int = Inv.count(fast.actors[1]["inv"], "lfg:item/sporebean") - Inv.count(slow.actors[1]["inv"], "lfg:item/sporebean")
	eq(diff, 2, "rank 4 adds 2 yield steps (%d)" % diff)

func test_rank_gated_crops_buildings_and_recipes() -> void:
	var s: MatchState = quiet()
	var h: Vector2i = neighbor_plot(s, 0)
	eq(cmd(s, "plant", {"crop": "lfg:crop/saltroot", "hex": h})["error"], "rank_required", "saltroot is rank 1")
	eq(cmd(s, "plant", {"crop": "lfg:crop/crownwheat", "hex": h})["error"], "rank_required", "crownwheat is rank 5")
	give(s, 1, {"lfg:item/timber": 50, "lfg:item/stone": 50, "lfg:item/coin": 50})
	eq(cmd(s, "build", {"holding": 1, "building": "lfg:building/granary"})["error"], "rank_required", "granary is rank 1")
	eq(cmd(s, "build", {"holding": 1, "building": "lfg:building/shrine"})["error"], "rank_required", "shrine is rank 2")
	give(s, 1, {"lfg:item/glowfruit_prime": 4})
	eq(cmd(s, "craft", {"recipe": "lfg:recipe/ration_prime"})["error"], "rank_required", "prime ration is rank 3")
	Standing.set_rank(s, 0, 3)
	check(cmd(s, "craft", {"recipe": "lfg:recipe/ration_prime"})["ok"], "unlocked at rank 3")
	check(cmd(s, "build", {"holding": 1, "building": "lfg:building/shrine"})["ok"], "shrine at rank 3")
	for crop in Content.crops().values():
		var need: int = int(crop.get("rank", 0))
		check(need == 0 or need <= 5, "crop rank in range")
	var seen: Dictionary = {}
	for crop in Content.crops().values():
		seen[int(crop.get("rank", 0))] = true
	for r in [1, 3, 4, 5]:
		check(seen.has(r), "a crop unlocks at rank %d" % r)

func test_better_prices_with_rank() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	var b0: int = Economy.buy_price("lfg:item/ration", 1.0, a)
	var s0: int = Economy.sell_price(a, "lfg:item/ration", 1.0)
	Standing.set_rank(s, 0, 5)
	check(Economy.buy_price("lfg:item/ration", 1.0, a) <= b0, "buy no dearer")
	check(Economy.sell_price(a, "lfg:item/ration", 1.0) >= s0, "sell no cheaper")

# ------------------------------------------------------------ the Mark
func test_top_standing_faction_is_marked_and_pays_a_bounty() -> void:
	var s: MatchState = quiet()
	eq(Standing.mark_of(s), -1, "nobody is marked at the start")
	_give_deeds(s, 5, "kill_leader", 3)
	var ev: Array = []
	Standing.recompute(s, ev)
	eq(Standing.mark_of(s), 5, "the top-standing faction is Marked")
	eq(count_type(ev, "mark_changed"), 1, "event")
	var plain: int = int(Standing.deed_def("capture")["sp"])
	_purge(s)
	var e2: Array = []
	Standing.record(s, 0, "capture", e2, 5)
	var sp: int = 0
	var marked: bool = false
	for e in e2:
		if String(e["type"]) == "deed":
			sp = int(e["sp"])
			marked = bool(e["marked"])
	check(marked and sp > plain, "striking the Marked pays bonus spoils (%d > %d)" % [sp, plain])

func test_the_mark_needs_a_real_rank() -> void:
	var s: MatchState = quiet()
	_give_deeds(s, 5, "scout", 1)
	Standing.recompute(s, [])
	eq(Standing.mark_of(s), -1, "a single scout deed marks nobody")

# ------------------------------------------------------------ anti-snowball
func test_thin_crown_shrinks_rank_buffs() -> void:
	var s: MatchState = quiet()
	_give_deeds(s, 0, "kill_leader", 3)
	home(s)["store"]["lfg:item/ration"] = 500
	Standing.recompute(s, [])
	var r: int = Standing.rank_of(s, 0)
	check(r >= 2, "rank earned")
	eq(Standing.eff_rank(s, 0), r, "well fed: full buffs")
	home(s)["store"].erase("lfg:item/ration")
	s.actors[1]["inv"].erase("lfg:item/ration")
	Standing.recompute(s, [])
	eq(Standing.eff_rank(s, 0), Standing.rank_of(s, 0) - 1, "empty larder: the crown is thin, buffs drop a rank")
	check(bool(s.factions[0]["thin"]), "flag exposed")

func test_upkeep_grows_faster_than_holdings() -> void:
	var s: MatchState = quiet()
	eq(Standing.upkeep_cost(s, 0), 0, "one holding is free")
	var ids: Array = s.holdings.keys()
	ids.sort()
	var costs: Array = []
	var n: int = 1
	for id in ids:
		if int(s.holdings[id]["owner"]) == -1:
			s.holdings[id]["owner"] = 0
			n += 1
			if n in [4, 8, 16]:
				costs.append(Standing.upkeep_cost(s, 0))
	check(costs[0] >= 1 and costs[1] > costs[0] and costs[2] > costs[1], "upkeep rises with holdings %s" % str(costs))
	check(float(costs[2]) / 16.0 > float(costs[0]) / 4.0, "and per holding too (convex)")

func test_unpaid_upkeep_and_distance_destabilise_and_holdings_revolt() -> void:
	var s: MatchState = quiet()
	var far: Array = []
	for id in s.holdings.keys():
		var h: Dictionary = s.holdings[id]
		if int(h["owner"]) == -1 and HexGrid.distance(h["hex"], home(s)["hex"]) > 18:
			far.append(id)
		if far.size() >= 6:
			break
	for id in far:
		s.holdings[id]["owner"] = 0
		s.holdings[id]["store"] = {}
	home(s)["store"].erase("lfg:item/coin")
	var revolted: int = 0
	var ev: Array = []
	for day in range(40):
		Standing.dawn_upkeep(s, ev)
	for e in ev:
		if String(e["type"]) == "holding_revolted":
			revolted += 1
	var low: bool = false
	for id in far:
		if int(s.holdings[id]["stab"]) < 40:
			low = true
	check(low or revolted > 0, "far, unpaid holdings become unstable")
	check(revolted > 0, "and some revolt (%d)" % revolted)
	eq(s.holdings[1]["owner"], 0, "the capital never revolts")

func test_unstable_holdings_produce_less() -> void:
	var s: MatchState = quiet()
	var h: Dictionary = s.holdings[1]
	var base: int = Standing.yield_bonus(s, h)
	h["stab"] = 10
	eq(Standing.yield_bonus(s, h), base - 1, "unstable: yield step lost")

func test_passive_single_holding_factions_bleed() -> void:
	var s: MatchState = quiet()
	var ev: Array = []
	Standing.dawn_upkeep(s, ev)
	eq(count_type(ev, "idle_bleed"), 0, "not in the first two weeks")
	s.clock["elapsed"] = 15.0 * s.day_seconds
	var rat0: int = Economy.rations_available(s, 0)
	ev = []
	Standing.dawn_upkeep(s, ev)
	check(ev.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "idle_bleed" and int(e["faction"]) == 0).size() == 1, "no deed for two weeks: the upkeep bleeds the idle faction")
	check(Economy.rations_available(s, 0) < rat0, "rations were drained")
	# a recent deed spares it
	s.factions[0]["last_deed"] = float(s.clock["elapsed"]) - 2.0 * s.day_seconds
	ev = []
	Standing.dawn_upkeep(s, ev)
	eq(ev.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "idle_bleed" and int(e["faction"]) == 0).size(), 0, "an active faction is not bled")

func test_peacetime_spoilage_grows_with_the_weeks_and_granary_halves_it() -> void:
	var s: MatchState = quiet()
	home(s)["store"]["lfg:item/ration"] = 112
	warp(s, 7 * 8 + 2, 0.0)
	var ev: Array = []
	Standing.dawn_upkeep(s, ev)
	var lost: int = 112 - Inv.count(home(s)["store"], "lfg:item/ration")
	check(lost >= 5, "late weeks spoil stock above the floor (%d)" % lost)
	var g: MatchState = quiet()
	g.holdings[1]["buildings"].append("lfg:building/granary")
	g.holdings[1]["store"]["lfg:item/ration"] = 112
	warp(g, 7 * 8 + 2, 0.0)
	Standing.dawn_upkeep(g, [])
	var lost_g: int = 112 - Inv.count(g.holdings[1]["store"], "lfg:item/ration")
	check(lost_g < lost and lost_g > 0, "granary halves spoilage (%d vs %d)" % [lost_g, lost])
	var early: MatchState = quiet()
	early.holdings[1]["store"]["lfg:item/ration"] = 112
	Standing.dawn_upkeep(early, [])
	check(112 - Inv.count(early.holdings[1]["store"], "lfg:item/ration") <= 1, "week 1 loses next to nothing")

func test_harvest_scarcity_creeps_in() -> void:
	var s: MatchState = quiet()
	var y0: int = Standing.yield_bonus(s, s.holdings[1])
	warp(s, 7 * 20 + 1, 0.0)
	check(Standing.yield_bonus(s, s.holdings[1]) < y0, "yield falls in late weeks")
	check(Standing.prod_mult(s) < 1.0 and Standing.prod_mult(s) >= 0.5, "AI production shrinks but has a floor")

# ------------------------------------------------------------ levy
func test_levy_is_charged_after_each_purge_and_fighting_reduces_it() -> void:
	var s: MatchState = quiet()
	var due: Dictionary = Standing.levy_due(s, 0)
	check(int(due["rations"]) > 0 and int(due["coin"]) > 0, "levy has a ration and a coin part")
	_give_deeds(s, 0, "capture", 2)
	var due2: Dictionary = Standing.levy_due(s, 0)
	check(int(due2["rations"]) < int(due["rations"]) or int(due2["coin"]) < int(due["coin"]), "fighting deeds cut the levy (%s -> %s)" % [str(due), str(due2)])
	check(float(due2["reduction"]) > 0.0 and float(due2["reduction"]) <= 0.8, "reduction capped")
	var s2: MatchState = quiet()
	home(s2)["store"]["lfg:item/coin"] = 50
	home(s2)["store"]["lfg:item/ration"] = 50
	warp(s2, 7, 0.6)
	var ev: Array = tick_all(s2, 60.0 * 0.45, 1.0)
	var paid: Array = ev.filter(func(e: Dictionary) -> bool: return String(e["type"]) == "levy_paid" and int(e["faction"]) == 0)
	eq(paid.size(), 1, "one levy event for the player after the Purge resolves")
	eq(int(paid[0]["unpaid_rations"]) + int(paid[0]["unpaid_coin"]), 0, "paid in full")

func test_unpaid_levy_hurts_stability_and_garrison() -> void:
	var s: MatchState = quiet()
	home(s)["store"] = {}
	s.actors[1]["inv"] = {}
	home(s)["garrison"] = 5
	var ev: Array = []
	Standing.charge_levy(s, ev)
	var e: Dictionary = ev.filter(func(x: Dictionary) -> bool: return String(x["type"]) == "levy_paid" and int(x["faction"]) == 0)[0]
	check(int(e["unpaid_rations"]) > 0, "unpaid")
	eq(home(s)["garrison"], 4, "a garrison deserts")
	eq(home(s)["stab"], 100 - int(Standing.cfg()["levy"]["unpaid_stab"]), "stability falls by the unpaid-levy amount")

func test_shrine_cuts_the_levy() -> void:
	var s: MatchState = quiet()
	var d0: Dictionary = Standing.levy_due(s, 0)
	home(s)["buildings"].append("lfg:building/shrine")
	var d1: Dictionary = Standing.levy_due(s, 0)
	check(float(d1["reduction"]) > float(d0["reduction"]), "shrine reduces the levy")

# ------------------------------------------------------------ prosperity + HUD model
func test_prosperity_is_a_non_ending_thriving_score() -> void:
	var s: MatchState = quiet()
	home(s)["store"]["lfg:item/ration"] = 60
	Standing.recompute(s, [])
	var p: Dictionary = s.factions[0]["prosperity"]
	for k in ["score", "output", "reserves", "holdings", "thriving", "ration_days"]:
		check(p.has(k), "prosperity.%s" % k)
	check(int(p["score"]) > 0 and int(p["reserves"]) > 0 and int(p["holdings"]) > 0, "components")
	var poor: MatchState = quiet()
	poor.holdings[1]["store"] = {}
	poor.actors[1]["inv"] = {}
	Standing.recompute(poor, [])
	check(int(poor.factions[0]["prosperity"]["score"]) < int(p["score"]), "poorer is lower")
	check(not poor.factions[0]["prosperity"]["thriving"], "an empty larder is not thriving")
	check(not s.over and s.won == "", "prosperity never ends a match")
	# output accrues from harvests
	var h: Vector2i = neighbor_plot(s, 0)
	cmd(s, "plant", {"crop": "lfg:crop/sporebean", "hex": h})
	s.plots[MatchState.plot_key(h)]["age"] = 4
	cmd(s, "harvest", {"hex": h})
	check(int(s.factions[0].get("out_day", 0)) > 0, "harvest counts as output")

func test_hud_model_exposes_standing_rank_levy_mark_prosperity() -> void:
	var s: MatchState = quiet()
	_give_deeds(s, 5, "kill_leader", 3)
	Standing.recompute(s, [])
	var m: Dictionary = Standing.hud_model(s, 0)
	for k in ["rank", "rank_name", "standing", "next_rank", "next_threshold", "to_next", "next_unlock", "prosperity", "thriving", "recent_deeds", "levy",
			"days_to_purge", "marked", "skill_points", "thin_crown", "live_factions", "holdings"]:
		check(m.has(k), "hud_model.%s" % k)
	eq(m["marked"]["faction"], 5, "marked faction")
	check(not m["marked"]["is_you"] and String(m["marked"]["name"]) != "", "named, not you")
	check(String(m["next_unlock"]) != "", "tells you what the next rank unlocks")
	check(int(m["levy"]["rations"]) > 0, "levy due is shown")
	eq(Standing.hud_model(s, 5)["marked"]["is_you"], true, "the Marked faction sees itself")

func test_state_survives_a_save_round_trip_with_deeds_and_ranks() -> void:
	var s: MatchState = quiet()
	_give_deeds(s, 0, "capture", 2)
	Standing.recompute(s, [])
	var s2: MatchState = MatchState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	eq(s2.factions[0]["deeds"].size(), 2, "deeds persisted")
	eq(Standing.rank_of(s2, 0), Standing.rank_of(s, 0), "rank persisted")
	check(absf(Standing.deed_score(s2, s2.factions[0]) - Standing.deed_score(s, s.factions[0])) < 0.001, "same score after load")
	eq(s2.actors[1]["sp"], s.actors[1]["sp"], "skill points persisted")

func test_a_pre_pass2_save_still_plays() -> void:
	var s: MatchState = quiet()
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	for f in d["factions"].values():
		for k in ["rank", "eff_rank", "deeds", "pcap", "dcount", "scouted", "escorted", "last_deed", "truces", "standing", "prosperity"]:
			f.erase(k)
	for h in d["holdings"].values():
		h.erase("stab")
	d["sim_acc"] = {}
	var old: MatchState = MatchState.from_dict(d)
	old.set_time(7, 0.6)
	var ev: Array = []
	check(Standing.record(old, 0, "capture", ev), "deeds work on an old save")
	tick_all(old, 60.0 * 3.0, 5.0)
	check(old.factions[0].has("rank") and old.holdings[1].has("stab"), "fields appear at the first dawn")
	check(not Standing.hud_model(old, 0).is_empty(), "hud model works")
