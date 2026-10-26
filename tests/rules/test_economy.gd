extends RulesTestBase

func _merchant(s: MatchState) -> Dictionary:
	var best: Dictionary = {}
	var bd: int = 9999
	for h in s.holdings.values():
		if h["merchant"] and int(h["owner"]) == -1:
			var d: int = HexGrid.distance(h["hex"], home(s)["hex"])
			if d < bd:
				bd = d
				best = h
	return best

func test_parse_qty_rejects_bad_values() -> void:
	eq(Inv.parse_qty(3), 3, "int ok")
	eq(Inv.parse_qty(3.0), 3, "integral float ok (JSON)")
	for bad in [0, -1, 2.5, 10000, 99999999999, NAN, INF, "3", null, [1], 0.0, -0.5]:
		eq(Inv.parse_qty(bad), -1, "rejects %s" % str(bad))
	eq(Inv.parse_qty(9999), 9999, "max ok")

func test_transfer_is_atomic_and_conserving() -> void:
	var a: Dictionary = {"lfg:item/ration": 5, "lfg:item/coin": 2}
	var b: Dictionary = {"lfg:item/ration": 9997}
	var before_a: Dictionary = a.duplicate()
	var before_b: Dictionary = b.duplicate()
	eq(Inv.transfer(a, b, {"lfg:item/coin": 1, "lfg:item/ration": 5}), "no_room", "overflow rejected")
	eq(a, before_a, "source untouched on overflow")
	eq(b, before_b, "dest untouched on overflow")
	eq(Inv.transfer(a, b, {"lfg:item/coin": 1, "lfg:item/ration": 6}), "insufficient_items", "partial consumption rejected")
	eq(a, before_a, "source untouched when one item short")
	eq(Inv.transfer(a, b, {"lfg:item/coin": 2}), "", "valid ok")
	eq(a.get("lfg:item/coin", 0), 0, "coin moved")
	eq(b["lfg:item/coin"], 2, "coin arrived")

func test_craft_validation_no_partial_consumption() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = s.actors[1]
	p["inv"] = {"lfg:item/glowfruit": 3}
	var before: String = snap(s)
	var r: Dictionary = cmd(s, "craft", {"recipe": "lfg:recipe/ration_glowfruit", "qty": 2})
	eq(r["error"], "insufficient_items", "needs 4 glowfruit")
	eq(snap(s), before, "failed craft mutates nothing")
	for bad in [0, -1, 1.5, 100, "x"]:
		var r2: Dictionary = cmd(s, "craft", {"recipe": "lfg:recipe/ration_glowfruit", "qty": bad})
		check(not r2["ok"], "craft qty %s rejected" % str(bad))
	eq(snap(s), before, "still nothing mutated")
	var r3: Dictionary = cmd(s, "craft", {"recipe": "lfg:recipe/ration_glowfruit", "qty": 1})
	check(r3["ok"], "craft ok")
	eq(p["inv"]["lfg:item/glowfruit"], 1, "consumed 2")
	eq(p["inv"]["lfg:item/ration"], 1, "made 1 ration")

func test_craft_overflow_rejected() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = s.actors[1]
	p["inv"] = {"lfg:item/glowfruit": 4, "lfg:item/ration": 9999}
	var before: String = snap(s)
	eq(cmd(s, "craft", {"recipe": "lfg:recipe/ration_glowfruit", "qty": 1})["error"], "no_room", "overflow")
	eq(snap(s), before, "overflow craft mutates nothing")

func test_trade_conserves_items_and_coin() -> void:
	var s: MatchState = quiet()
	var m: Dictionary = _merchant(s)
	var p: Dictionary = s.actors[1]
	p["hex"] = m["hex"]
	warp(s, 2, 0.2)
	var t0: Dictionary = Inv.world_totals(s)
	var r: Dictionary = cmd(s, "trade", {"holding": m["id"], "side": "buy", "item": "lfg:item/timber", "qty": 3})
	check(r["ok"], "buy: %s" % r["error"])
	eq(Inv.world_totals(s), t0, "buy conserves")
	eq(p["inv"]["lfg:item/timber"], 3, "got timber")
	r = cmd(s, "trade", {"holding": m["id"], "side": "sell", "item": "lfg:item/timber", "qty": 2})
	check(r["ok"], "sell: %s" % r["error"])
	eq(Inv.world_totals(s), t0, "sell conserves")
	# buy/sell spread means no free money
	var coin_after: int = p["inv"]["lfg:item/coin"]
	check(coin_after < 20, "round trip loses coin (spread): %d" % coin_after)

func test_trade_rejections_mutate_nothing() -> void:
	var s: MatchState = quiet()
	var m: Dictionary = _merchant(s)
	var p: Dictionary = s.actors[1]
	p["hex"] = m["hex"]
	warp(s, 2, 0.2)
	var cases: Array = [
		{"holding": m["id"], "side": "buy", "item": "lfg:item/timber", "qty": -3},
		{"holding": m["id"], "side": "buy", "item": "lfg:item/timber", "qty": 1.5},
		{"holding": m["id"], "side": "buy", "item": "lfg:item/timber", "qty": 0},
		{"holding": m["id"], "side": "buy", "item": "lfg:item/timber", "qty": 99999},
		{"holding": m["id"], "side": "buy", "item": "lfg:item/timber", "qty": 5000},
		{"holding": m["id"], "side": "buy", "item": "lfg:item/nothing", "qty": 1},
		{"holding": m["id"], "side": "sell", "item": "lfg:item/stone", "qty": 1},
		{"holding": m["id"], "side": "sell", "item": "lfg:item/coin", "qty": 1},
		{"holding": m["id"], "side": "swap", "item": "lfg:item/timber", "qty": 1},
		{"holding": 9999, "side": "buy", "item": "lfg:item/timber", "qty": 1},
		{"holding": 1, "side": "buy", "item": "lfg:item/timber", "qty": 1},
		{"holding": m["id"], "side": "withdraw", "item": "lfg:item/timber", "qty": 1},
	]
	var before: String = snap(s)
	for c in cases:
		var r: Dictionary = cmd(s, "trade", c)
		check(not r["ok"], "rejected: %s" % str(c))
		eq(snap(s), before, "unchanged after %s" % str(c))
	p["hex"] = home(s)["hex"] + Vector2i(10, 0)
	eq(cmd(s, "trade", {"holding": m["id"], "side": "buy", "item": "lfg:item/timber", "qty": 1})["error"], "too_far", "range check")

func test_deposit_withdraw_conserve() -> void:
	var s: MatchState = quiet()
	var t0: Dictionary = Inv.world_totals(s)
	check(cmd(s, "trade", {"holding": 1, "side": "deposit", "item": "lfg:item/ration", "qty": 4})["ok"], "deposit")
	eq(home(s)["store"]["lfg:item/ration"], 8, "stored")
	check(cmd(s, "trade", {"holding": 1, "side": "withdraw", "item": "lfg:item/ration", "qty": 8})["ok"], "withdraw")
	eq(Inv.world_totals(s), t0, "conserved")
	eq(cmd(s, "trade", {"holding": 1, "side": "withdraw", "item": "lfg:item/ration", "qty": 50})["error"], "insufficient_items", "over-withdraw")

func test_vex_sells_for_more() -> void:
	var s1: MatchState = quiet("lfg:class/judd")
	var s2: MatchState = quiet("lfg:class/vex")
	for s in [s1, s2]:
		var m: Dictionary = _merchant(s)
		s.actors[1]["hex"] = m["hex"]
		s.actors[1]["inv"] = {"lfg:item/tonic": 5}
		warp(s, 2, 0.2)
		check(cmd(s, "trade", {"holding": m["id"], "side": "sell", "item": "lfg:item/tonic", "qty": 5})["ok"], "sell")
	check(s2.actors[1]["inv"]["lfg:item/coin"] > s1.actors[1]["inv"]["lfg:item/coin"], "Vex fences for more")

func test_build_and_demolish() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = s.actors[1]
	give(s, 1, {"lfg:item/timber": 10, "lfg:item/stone": 10})
	check(cmd(s, "build", {"holding": 1, "building": "lfg:building/wall"})["ok"], "build wall")
	eq(p["inv"]["lfg:item/timber"], 6, "timber spent")
	var before: String = snap(s)
	eq(cmd(s, "build", {"holding": 1, "building": "lfg:building/nothing"})["error"], "unknown_building", "unknown")
	eq(cmd(s, "build", {"holding": 9999, "building": "lfg:building/wall"})["error"], "unknown_holding", "unknown holding")
	eq(snap(s), before, "failed builds mutate nothing")
	p["inv"] = {}
	eq(cmd(s, "build", {"holding": 1, "building": "lfg:building/wall"})["error"], "insufficient_items", "no materials")
	check(cmd(s, "demolish", {"holding": 1, "building": "lfg:building/wall"})["ok"], "demolish")
	eq(p["inv"]["lfg:item/timber"], 2, "refund half")
	eq(cmd(s, "demolish", {"holding": 1, "building": "lfg:building/wall"})["error"], "no_such_building", "nothing to demolish")

func test_duplicate_and_stale_seq_rejected() -> void:
	var s: MatchState = quiet()
	var c: Dictionary = {"type": &"eat", "actor": 1, "seq": 1, "args": {"item": "lfg:item/ration", "qty": 1}}
	check(Rules.apply(s, c)["ok"], "first ok")
	var left: int = s.actors[1]["inv"]["lfg:item/ration"]
	var r: Dictionary = Rules.apply(s, c)
	eq(r["error"], "duplicate_seq", "dup rejected")
	eq(s.actors[1]["inv"]["lfg:item/ration"], left, "dup did not eat again")
	c["seq"] = 5
	check(Rules.apply(s, c)["ok"], "higher seq ok")
	c["seq"] = 3
	eq(Rules.apply(s, c)["error"], "stale_seq", "stale rejected")
	c["seq"] = 0
	eq(Rules.apply(s, c)["error"], "bad_seq", "zero seq")
	c["seq"] = "x"
	eq(Rules.apply(s, c)["error"], "bad_seq", "string seq")

func test_failed_command_does_not_consume_seq() -> void:
	var s: MatchState = quiet()
	var bad: Dictionary = {"type": &"eat", "actor": 1, "seq": 1, "args": {"item": "lfg:item/ration", "qty": 500}}
	check(not Rules.apply(s, bad)["ok"], "bad eat")
	bad["args"]["qty"] = 1
	check(Rules.apply(s, bad)["ok"], "retry same seq after failure works")

func test_malformed_commands() -> void:
	var s: MatchState = quiet()
	var before: String = snap(s)
	for c in [{}, {"type": &"eat"}, {"type": &"fly", "actor": 1, "seq": 1}, {"type": &"eat", "actor": 77, "seq": 1}, {"type": 5, "actor": 1, "seq": 1},
			{"type": &"eat", "actor": 1, "seq": 1, "args": 5}, {"type": &"plant", "actor": 1, "seq": 1, "args": {}}]:
		check(not Rules.apply(s, c)["ok"], "rejected %s" % str(c))
	eq(snap(s), before, "no mutation")
	var enemy_state: MatchState = mk()
	var any_enemy: int = -1
	for a in enemy_state.actors.values():
		if a["kind"] == "enemy":
			any_enemy = a["id"]
			break
	check(any_enemy != -1, "wild enemies exist")
	eq(Rules.apply(enemy_state, {"type": &"rest", "actor": any_enemy, "seq": 1, "args": {}})["error"], "unknown_actor", "cannot command enemies")
