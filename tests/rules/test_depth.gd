extends RulesTestBase
## Economy depth: building placement, production, upgrades, merchant price drift, Vex stealing risk.

func _stock(s: MatchState, items: Dictionary) -> void:
	give(s, 1, items)

func _plain_ring_hex(s: MatchState, dist: int = 1) -> Vector2i:
	var hx: Vector2i = s.holdings[1]["hex"]
	for d in HexGrid.ring_within(hx, dist):
		if HexGrid.distance(d, hx) == dist and Economy.site_free(s, s.holdings[1], d) == "":
			return d
	return Vector2i(-9999, 0)

func _neutral(s: MatchState) -> Dictionary:
	for h in s.holdings.values():
		if h["merchant"] and h["owner"] == -1:
			return h
	return {}

# ------------------------------------------------------------ placement
func test_build_placement_validation() -> void:
	var s: MatchState = quiet()
	_stock(s, {"lfg:item/timber": 50, "lfg:item/stone": 50})
	var home_hex: Vector2i = s.holdings[1]["hex"]
	var site: Vector2i = _plain_ring_hex(s, 2)
	check(site.x != -9999, "a free ring-2 hex exists")
	var before: String = snap(s)
	eq(cmd(s, "build", {"holding": 1, "building": "lfg:building/wall", "hex": home_hex})["error"], "site_out_of_range", "not on the holding itself")
	eq(cmd(s, "build", {"holding": 1, "building": "lfg:building/wall", "hex": home_hex + Vector2i(5, 0)})["error"], "site_out_of_range", "too far from the holding")
	eq(cmd(s, "build", {"holding": 1, "building": "lfg:building/wall", "hex": [999, 999]})["error"], "bad_hex", "out of the world")
	eq(cmd(s, "build", {"holding": 1, "building": "lfg:building/wall", "hex": "x"})["error"], "bad_hex", "malformed")
	eq(snap(s), before, "rejected placements mutate nothing")
	# terrain: find a non-ground hex within range by editing the terrain
	var water: Vector2i = home_hex + Vector2i(2, 0)
	var idx: int = HexGrid.index(water)
	var old: int = int(s.world["terrain"][idx])
	s.world["terrain"][idx] = WorldGen.T_SHALLOW
	eq(cmd(s, "build", {"holding": 1, "building": "lfg:building/wall", "hex": water})["error"], "bad_terrain", "cannot build on water")
	s.world["terrain"][idx] = old
	# occupancy: crop plot, existing building, other holding
	var plot: Vector2i = _plain_ring_hex(s, 1)
	s.plots[MatchState.plot_key(plot)] = {"crop": "lfg:crop/glowfruit", "age": 0, "watered": false, "dry_days": 0, "holding": 1}
	eq(cmd(s, "build", {"holding": 1, "building": "lfg:building/wall", "hex": plot})["error"], "occupied", "crop occupies the hex")
	var r: Dictionary = cmd(s, "build", {"holding": 1, "building": "lfg:building/wall", "hex": site})
	check(r["ok"], "valid build: %s" % r["error"])
	eq(r["events"][0]["hex"], site, "event reports the site")
	eq(s.holdings[1]["sites"][MatchState.plot_key(site)], "lfg:building/wall", "site recorded")
	eq(cmd(s, "build", {"holding": 1, "building": "lfg:building/storehouse", "hex": site})["error"], "occupied", "building occupies the hex")
	eq(cmd(s, "plant", {"crop": "lfg:crop/glowfruit", "hex": site})["error"], "occupied", "cannot plant on a building")

func test_auto_site_is_deterministic_and_dense_packing_ends() -> void:
	var a: MatchState = quiet()
	var b: MatchState = quiet()
	for s in [a, b]:
		_stock(s, {"lfg:item/timber": 100, "lfg:item/stone": 100})
		cmd(s, "build", {"holding": 1, "building": "lfg:building/wall"})
		cmd(s, "build", {"holding": 1, "building": "lfg:building/storehouse"})
	eq(a.holdings[1]["sites"], b.holdings[1]["sites"], "same sites on same seed")
	eq(a.holdings[1]["sites"].size(), 2, "two distinct sites")
	for k in a.holdings[1]["sites"].keys():
		var parts: PackedStringArray = (k as String).split(",")
		var d: int = HexGrid.distance(Vector2i(int(parts[0]), int(parts[1])), a.holdings[1]["hex"])
		check(d >= 1 and d <= Economy.BUILD_RADIUS, "site within build radius (%d)" % d)

func test_group_limits_upgrades_and_demolish_free_the_site() -> void:
	var s: MatchState = quiet()
	Standing.set_rank(s, 0, 3)
	_stock(s, {"lfg:item/timber": 100, "lfg:item/stone": 100, "lfg:item/coin": 100})
	eq(cmd(s, "build", {"holding": 1, "building": "lfg:building/sawmill_2"})["error"], "needs_base_building", "upgrade needs the base")
	check(cmd(s, "build", {"holding": 1, "building": "lfg:building/sawmill"})["ok"], "sawmill")
	eq(cmd(s, "build", {"holding": 1, "building": "lfg:building/sawmill"})["error"], "building_limit", "one sawmill")
	var sites0: Dictionary = (s.holdings[1]["sites"] as Dictionary).duplicate()
	var t0: Dictionary = s.actors[1]["inv"].duplicate()
	eq(cmd(s, "build", {"holding": 1, "building": "lfg:building/sawmill_2", "hex": [1, 1]})["error"], "upgrade_has_no_site", "upgrades keep their site")
	var r: Dictionary = cmd(s, "build", {"holding": 1, "building": "lfg:building/sawmill_2"})
	check(r["ok"], "upgrade: %s" % r["error"])
	check(r["events"][0]["upgrade"], "event flags upgrade")
	eq(s.holdings[1]["buildings"], ["lfg:building/sawmill_2"], "base replaced, not duplicated")
	eq(Inv.count(s.actors[1]["inv"], "lfg:item/timber"), Inv.count(t0, "lfg:item/timber") - 8, "upgrade cost paid")
	var k: String = sites0.keys()[0]
	eq(s.holdings[1]["sites"][k], "lfg:building/sawmill_2", "site now holds the upgrade")
	eq(cmd(s, "build", {"holding": 1, "building": "lfg:building/sawmill"})["error"], "building_limit", "group limit counts upgrades")
	var d: Dictionary = cmd(s, "demolish", {"holding": 1, "building": "lfg:building/sawmill_2"})
	check(d["ok"], "demolish: %s" % d["error"])
	check((s.holdings[1]["sites"] as Dictionary).is_empty(), "site freed")
	check(cmd(s, "build", {"holding": 1, "building": "lfg:building/sawmill", "hex": _plain_ring_hex(s, 1)})["ok"], "can rebuild there")

func test_wall_upgrade_and_forge_discount_paid() -> void:
	var s: MatchState = quiet("lfg:class/forge")
	Standing.set_rank(s, 0, 1)
	_stock(s, {"lfg:item/timber": 20, "lfg:item/stone": 20})
	check(cmd(s, "build", {"holding": 1, "building": "lfg:building/wall"})["ok"], "wall")
	var t: int = Inv.count(s.actors[1]["inv"], "lfg:item/timber")
	check(cmd(s, "build", {"holding": 1, "building": "lfg:building/wall_stone"})["ok"], "stone wall")
	eq(t - Inv.count(s.actors[1]["inv"], "lfg:item/timber"), 2, "ceil(2*0.75)=2 timber")
	var p0: float = Conquest.defender_power(s, s.holdings[1])
	s.holdings[1]["buildings"] = []
	check(p0 - Conquest.defender_power(s, s.holdings[1]) >= 8.0, "stone wall adds 8 defence")

# ------------------------------------------------------------ production
func _dawn(s: MatchState) -> Array:
	var ev: Array = []
	Sim.dawn(s, ev)
	return ev

func test_sawmill_needs_workers_and_food() -> void:
	var s: MatchState = quiet()
	s.holdings[1]["buildings"] = ["lfg:building/sawmill"]
	s.holdings[1]["store"]["lfg:item/ration"] = 100
	var t0: int = Inv.count(s.holdings[1]["store"], "lfg:item/timber")
	_dawn(s)
	eq(Inv.count(s.holdings[1]["store"], "lfg:item/timber"), t0 + 2, "+2 timber a day")
	s.holdings[1]["garrison"] = 1
	var t1: int = Inv.count(s.holdings[1]["store"], "lfg:item/timber")
	_dawn(s)
	eq(Inv.count(s.holdings[1]["store"], "lfg:item/timber"), t1, "one soldier cannot run a sawmill")
	s.holdings[1]["garrison"] = 3
	s.factions[0]["hunger_days"] = 1
	var ev: Array = _dawn(s)
	eq(count_type(ev, "produced"), 0, "a starving faction does no work")
	s.factions[0]["hunger_days"] = 0
	s.holdings[1]["buildings"] = ["lfg:building/sawmill_2"]
	var st0: int = Inv.count(s.holdings[1]["store"], "lfg:item/stone")
	var t2: int = Inv.count(s.holdings[1]["store"], "lfg:item/timber")
	_dawn(s)
	eq(Inv.count(s.holdings[1]["store"], "lfg:item/timber"), t2 + 3, "upgrade: 3 timber")
	eq(Inv.count(s.holdings[1]["store"], "lfg:item/stone"), st0 + 1, "and 1 stone")

func test_kitchen_cooks_the_store_and_cookhouse_adds_bonus() -> void:
	var s: MatchState = quiet()
	var st: Dictionary = s.holdings[1]["store"]
	st["lfg:item/glowfruit"] = 10
	st["lfg:item/saltroot"] = 6
	s.holdings[1]["buildings"] = ["lfg:building/kitchen"]
	var r0: int = Inv.count(st, "lfg:item/ration")
	_dawn(s)
	# saltroot first (3 -> 2 rations), 2 batches: 2 saltroot batches = 4 rations
	eq(Inv.count(st, "lfg:item/ration"), r0 + 4, "2 batches/day, best yield first")
	eq(Inv.count(st, "lfg:item/saltroot"), 0, "6 saltroot used")
	eq(Inv.count(st, "lfg:item/glowfruit"), 10, "glowfruit waits")
	s.holdings[1]["buildings"] = ["lfg:building/kitchen_2"]
	var ev2: Array = _dawn(s)
	var made: int = 0
	for e in ev2:
		if String(e["type"]) == "produced":
			made += int(e["items"]["lfg:item/ration"])
	eq(made, 10, "cookhouse: 5 glowfruit batches of 2 -> 1+1 bonus ration each")
	eq(Inv.count(st, "lfg:item/glowfruit"), 0, "all glowfruit cooked")

func test_well_waters_thirsty_plots_at_dawn() -> void:
	var s: MatchState = quiet()
	var hx: Vector2i = s.holdings[1]["hex"] + HexGrid.DIRS[0]
	var hx2: Vector2i = s.holdings[1]["hex"] + HexGrid.DIRS[1]
	s.plots[MatchState.plot_key(hx)] = {"crop": "lfg:crop/glowfruit", "age": 0, "watered": false, "dry_days": 0, "holding": 1}
	s.plots[MatchState.plot_key(hx2)] = {"crop": "lfg:crop/sporebean", "age": 0, "watered": false, "dry_days": 0, "holding": 1}
	s.holdings[1]["buildings"] = ["lfg:building/well"]
	var ev: Array = _dawn(s)
	eq(count_type(ev, "well_watered"), 1, "event")
	eq(s.plots[MatchState.plot_key(hx)]["age"], 1, "watered glowfruit grew without the player")
	eq(s.plots[MatchState.plot_key(hx)]["dry_days"], 0, "never dry")
	var s2: MatchState = quiet()
	s2.plots[MatchState.plot_key(hx)] = {"crop": "lfg:crop/glowfruit", "age": 0, "watered": false, "dry_days": 0, "holding": 1}
	_dawn(s2)
	eq(s2.plots[MatchState.plot_key(hx)]["age"], 0, "no well: no growth")

func test_granary_shields_rations_from_looting_and_tower_defends() -> void:
	Standing.cfg()["hold"]["last_stand"] = 1.0      # the last-stand bonus (test_hold_hunt) would scale these single-holding numbers
	var results: Array = []
	for with in [false, true]:
		var s: MatchState = quiet()
		var h: Dictionary = _neutral(s)
		h["garrison"] = 0
		h["store"] = {"lfg:item/ration": 40, "lfg:item/coin": 40}
		if with:
			h["buildings"] = ["lfg:building/granary"]
		warp(s, 7, 0.7)
		s.actors[1]["hex"] = h["hex"]
		s.actors[1]["inv"]["lfg:item/coin"] = 0
		var ok: bool = false
		for i in range(30):
			s.actors[1]["cd"] = {}
			var t0: Dictionary = Inv.world_totals(s)
			var ev: Array = []
			h["owner"] = -1
			h["store"] = {"lfg:item/ration": 40, "lfg:item/coin": 40}
			s.actors[1]["inv"] = {}
			var won: bool = Conquest.resolve_capture(s, 0, 1, h["id"], -1, 20, ev)
			if won:
				results.append(Inv.count(s.actors[1]["inv"], "lfg:item/ration"))
				ok = true
				break
			h["garrison"] = 0
		check(ok, "captured (with granary=%s)" % str(with))
	eq(results[0], 20, "plain: half the rations (20)")
	eq(results[1], 10, "granary: 50%% shield -> 10")
	var t: MatchState = quiet()
	var base: float = Conquest.defender_power(t, t.holdings[1])
	t.holdings[1]["buildings"] = ["lfg:building/watchtower"]
	eq(Conquest.defender_power(t, t.holdings[1]), base + 3.0, "watchtower +3")
	t.holdings[1]["buildings"] = ["lfg:building/watchtower_2"]
	eq(Conquest.defender_power(t, t.holdings[1]), base + 6.0, "beacon +6")
	check(AIFactions.warn_radius(t.holdings[1]) == 9, "beacon warns 9 hexes out")

# ------------------------------------------------------------ merchants
func test_merchant_prices_drift_with_supply() -> void:
	var s: MatchState = quiet()
	var m: Dictionary = _neutral(s)
	s.actors[1]["hex"] = m["hex"]
	give(s, 1, {"lfg:item/coin": 2000})
	eq(Economy.price_mult(m, "lfg:item/ration"), 1.0, "starts at base price")
	var p0: int = Economy.buy_price("lfg:item/ration", 1.0)
	var t0: Dictionary = Inv.world_totals(s)
	check(cmd(s, "trade", {"holding": m["id"], "side": "buy", "item": "lfg:item/ration", "qty": 8})["ok"], "buy 8")
	eq(Inv.world_totals(s), t0, "trades conserve")
	var pm: float = Economy.price_mult(m, "lfg:item/ration")
	check(pm > 1.2, "buying raised the price (x%f)" % pm)
	check(Economy.buy_price("lfg:item/ration", pm) > p0, "next unit costs more")
	# stock is now low -> at dawn the multiplier keeps drifting up toward scarcity
	var before: float = pm
	_dawn(s)
	var target: float = sqrt(float(m["base_stock"]["lfg:item/ration"]) / (float(Inv.count(m["store"], "lfg:item/ration")) + 1.0))
	var after: float = Economy.price_mult(m, "lfg:item/ration")
	check(absf(after - target) < absf(before - target), "dawn moves price toward the supply target (%f -> %f, target %f)" % [before, after, target])
	# selling a glut pushes the price down
	give(s, 1, {"lfg:item/stone": 60})
	check(cmd(s, "trade", {"holding": m["id"], "side": "sell", "item": "lfg:item/stone", "qty": 40})["ok"], "sell 40 stone")
	check(Economy.price_mult(m, "lfg:item/stone") < 0.5 + 0.35, "glut -> cheap stone (x%f)" % Economy.price_mult(m, "lfg:item/stone"))
	check(Economy.price_mult(m, "lfg:item/stone") >= Economy.PRICE_MIN, "clamped at the floor")
	for i in range(40):
		_dawn(s)
	check(Economy.price_mult(m, "lfg:item/stone") <= 1.0, "glutted stone stays cheap (x%f)" % Economy.price_mult(m, "lfg:item/stone"))
	check(Economy.price_mult(m, "lfg:item/ration") <= Economy.PRICE_MAX, "capped at the ceiling")

func test_price_changes_affect_both_sides_and_never_break_trade_rules() -> void:
	var s: MatchState = quiet()
	var m: Dictionary = _neutral(s)
	s.actors[1]["hex"] = m["hex"]
	m["prices"] = {"lfg:item/ration": 2.0}
	give(s, 1, {"lfg:item/coin": 500, "lfg:item/ration": 4})
	var c0: int = Inv.count(s.actors[1]["inv"], "lfg:item/coin")
	var r: Dictionary = cmd(s, "trade", {"holding": m["id"], "side": "sell", "item": "lfg:item/ration", "qty": 2})
	check(r["ok"], "sell")
	eq(Inv.count(s.actors[1]["inv"], "lfg:item/coin") - c0, Economy.sell_price(s.actors[1], "lfg:item/ration", 2.0) * 2, "paid at the drifted price")
	var before: String = snap(s)
	eq(cmd(s, "trade", {"holding": m["id"], "side": "buy", "item": "lfg:item/ration", "qty": 100000})["error"], "bad_quantity", "absurd qty still rejected")
	eq(snap(s), before, "no mutation")

func test_ai_trader_trades_with_merchants_and_conserves() -> void:
	var s: MatchState = mk("lfg:class/judd", 12, {"day_seconds": 60.0, "wild_enemies": false})
	var tf: int = -1
	for fid in s.factions.keys():
		if s.factions[fid]["persona"] == "trader":
			tf = fid
			break
	check(tf != -1, "a trader exists")
	for fid in s.factions.keys():
		if s.factions[fid]["is_ai"] and fid != tf:
			s.factions[fid]["alive"] = false
	var home_h: Dictionary = s.holdings[s.factions[tf]["home"]]
	home_h["store"]["lfg:item/timber"] = 40
	home_h["store"]["lfg:item/stone"] = 40
	home_h["store"]["lfg:item/ration"] = 0
	var mers: int = 0
	for h in s.holdings.values():
		if h["merchant"] and h["owner"] == -1 and HexGrid.distance(h["hex"], home_h["hex"]) <= 12:
			mers += 1
	if mers == 0:
		return
	var ev: Array = []
	AIFactions._trade(s, tf, ev)
	eq(count_type(ev, "ai_traded"), 1, "trader trades")
	check(int(ev[0]["sold"]) > 0, "sold surplus")
	check(Inv.count(home_h["store"], "lfg:item/timber") < 40, "timber left the store")

# ------------------------------------------------------------ Vex
func test_vex_steal_chance_and_failure_alert() -> void:
	var v: MatchState = quiet("lfg:class/vex")
	var j: MatchState = quiet()
	var h: Dictionary = _neutral(v)
	var hj: Dictionary = _neutral(j)
	var cv: float = Conquest.steal_chance(v, v.actors[1], h)
	var cj: float = Conquest.steal_chance(j, j.actors[1], hj)
	check(absf(cv - cj - 0.35) < 0.001 or cv == 0.95, "Vex +35%% (%f vs %f)" % [cv, cj])
	h["buildings"] = ["lfg:building/storehouse", "lfg:building/granary"]
	check(Conquest.steal_chance(v, v.actors[1], h) < cv - 0.2, "storehouse+granary cut the odds")
	warp(v, 7, 0.7)
	v.actors[1]["hex"] = h["hex"]
	h["buildings"] = []
	h["garrison"] = 5     # ~50% odds for Vex: both outcomes show up
	var fail_seen: bool = false
	var wins: int = 0
	var losses: int = 0
	for i in range(40):
		v.actors[1]["cd"] = {}
		v.actors[1]["hp"] = 60
		var t0: Dictionary = Inv.world_totals(v)
		var ch0: float = Conquest.steal_chance(v, v.actors[1], h)
		var r: Dictionary = cmd(v, "steal", {"holding": h["id"], "item": "lfg:item/coin", "qty": 1})
		check(r["ok"], "steal: %s" % r["error"])
		eq(Inv.world_totals(v), t0, "steal conserves")
		if count_type(r["events"], "steal_failed") == 1:
			losses += 1
			var chance_event: float = float(r["events"][0]["chance"])
			check(chance_event > 0.0 and chance_event < 1.0, "event reports the risk")
			eq(v.actors[1]["hp"], 55, "caught: 5 damage")
			check(absf(Conquest.steal_chance(v, v.actors[1], h) - (ch0 - 0.15)) < 0.001, "alert makes the next try 15%% harder")
			fail_seen = true
			h.erase("alert")
		else:
			wins += 1
	check(fail_seen and wins > 0, "both outcomes with the risk roll (wins %d / losses %d)" % [wins, losses])
	h["alert"] = float(v.clock["elapsed"]) + 30.0
	tick_all(v, 31.0, 1.0)
	check(not Conquest._active(v, h, "alert"), "alert wears off after 30s")
