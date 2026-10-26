extends RulesTestBase

func test_twelve_week_soak_is_stable_and_deterministic() -> void:
	var a: MatchState = mk("lfg:class/judd", 77)
	var b: MatchState = mk("lfg:class/judd", 77)
	for s in [a, b]:
		s.actors[1]["max_hp"] = 100000
		s.actors[1]["hp"] = 100000
		s.holdings[1]["store"]["lfg:item/ration"] = 5000
	var t0: int = Time.get_ticks_msec()
	var ea: Array = tick_all(a, 60.0 * 86.0, 5.0)
	var elapsed: int = Time.get_ticks_msec() - t0
	var eb: Array = tick_all(b, 60.0 * 86.0, 5.0)
	check(same(a, b), "two identical soaks end identical")
	eq(ea.size(), eb.size(), "identical event streams")
	eq(a.won, "crowned", "survived 12 weeks -> crowned (or dominion earlier is also a win)") if a.won == "crowned" else check(a.won != "", "won by some route")
	check(not a.over, "player alive")
	var resolved: int = 0
	var conquests: int = 0
	for e in ea:
		if String(e["type"]) == "purge_resolved":
			resolved += 1
		if String(e["type"]) == "holding_captured":
			conquests += 1
	eq(resolved, 12, "12 settlements in 12 weeks")
	check(conquests > 0, "AI conquest happened over 12 weeks (%d)" % conquests)
	check(elapsed < 60000, "soak runs in reasonable time (%d ms)" % elapsed)
	var ai_alive: int = 0
	for f in a.factions.values():
		if f["is_ai"] and f["alive"]:
			ai_alive += 1
	check(ai_alive >= 1, "some AI survive")
	var tot: int = 0
	for h in a.holdings.values():
		tot += 1
		for k in h["store"].keys():
			check(int(h["store"][k]) >= 0 and int(h["store"][k]) <= Inv.MAX_QTY, "store bounds")
	eq(tot, 40, "holdings count constant")
	print("soak ms=", elapsed, " events=", ea.size(), " conquests=", conquests, " won=", a.won)
