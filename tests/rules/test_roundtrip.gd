extends RulesTestBase
## to_dict/from_dict must be an exact, type-preserving round trip (0.0 stays a float, ints stay ints), also through JSON text.

func _diff(a: Variant, b: Variant, path: String) -> String:
	if typeof(a) != typeof(b):
		return "%s: type %s vs %s (%s vs %s)" % [path, type_string(typeof(a)), type_string(typeof(b)), str(a), str(b)]
	if a is Dictionary:
		var da: Dictionary = a
		var db: Dictionary = b
		if da.size() != db.size():
			return "%s: dict size %d vs %d" % [path, da.size(), db.size()]
		for k in da.keys():
			if not db.has(k):
				return "%s: missing key %s" % [path, str(k)]
			var r: String = _diff(da[k], db[k], path + "/" + str(k))
			if r != "":
				return r
		return ""
	if a is Array:
		var aa: Array = a
		var ab: Array = b
		if aa.size() != ab.size():
			return "%s: array size %d vs %d" % [path, aa.size(), ab.size()]
		for i in range(aa.size()):
			var r2: String = _diff(aa[i], ab[i], "%s[%d]" % [path, i])
			if r2 != "":
				return r2
		return ""
	return "" if a == b else "%s: %s vs %s" % [path, str(a), str(b)]

func _roundtrip(s: MatchState, label: String) -> void:
	var d1: Dictionary = s.to_dict()
	var s2: MatchState = MatchState.from_dict(d1)
	var r: String = _diff(d1, s2.to_dict(), label + " direct")
	eq(r, "", "direct round trip is exact: " + r)
	var via_json: Dictionary = JSON.parse_string(JSON.stringify(d1))
	var s3: MatchState = MatchState.from_dict(via_json)
	var r3: String = _diff(d1, s3.to_dict(), label + " json")
	eq(r3, "", "JSON text round trip is exact: " + r3)

func test_fresh_state_roundtrips_exactly_including_zero_energy() -> void:
	var s: MatchState = mk("lfg:class/judd", 5, {"day_seconds": 60.0})
	s.actors[1]["energy"] = 0.0
	s.actors[1]["cd"]["ab:x"] = 0.0
	_roundtrip(s, "fresh")
	var s2: MatchState = MatchState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	eq(typeof(s2.actors[1]["energy"]), TYPE_FLOAT, "energy 0.0 stays float")
	eq(typeof(s2.actors[1]["cd"]["ab:x"]), TYPE_FLOAT, "cooldown 0.0 stays float")
	eq(typeof(s2.opts["day_seconds"]), TYPE_FLOAT, "opts day_seconds stays float")
	eq(typeof(s2.actors[1]["hp"]), TYPE_INT, "hp stays int")

func test_state_after_ticks_and_ai_roundtrips() -> void:
	var s: MatchState = mk("lfg:class/judd", 12, {"day_seconds": 60.0})
	s.holdings[1]["store"]["lfg:item/ration"] = 500
	tick_all(s, 60.0 * 3.0, 3.0)
	_roundtrip(s, "day4")
	tick_all(s, 60.0 * 3.5 - 6.0, 3.0)
	_roundtrip(s, "purge start")

func test_state_with_parties_fx_and_prices_roundtrips() -> void:
	var s: MatchState = mk("lfg:class/judd", 12, {"day_seconds": 60.0, "wild_enemies": false})
	s.holdings[1]["store"]["lfg:item/ration"] = 500
	warp(s, 7, 0.45)
	var seen_party: bool = false
	for i in range(60):
		Rules.tick(s, 1.0)
		if AIFactions.has_parties(s):
			seen_party = true
			_roundtrip(s, "marching t=%d" % i)
			break
	check(seen_party, "a party existed to serialise")
	var t: MatchState = quiet("lfg:class/tavi")
	warp(t, 7, 0.7)
	cmd(t, "use_ability", {})
	cmd(t, "use_ability", {"ability": "lfg:ability/mine"})
	tick_all(t, 3.0, 1.0)
	_roundtrip(t, "tavi post")
	var d: MatchState = quiet("lfg:class/dune")
	give(d, 1, {"lfg:item/ration": 4})
	cmd(d, "use_ability", {"items": {"lfg:item/ration": 3}})
	_roundtrip(d, "dune cache")
	var mer: Dictionary = {}
	for h in d.holdings.values():
		if h["merchant"] and h["owner"] == -1:
			mer = h
			break
	d.actors[1]["hex"] = mer["hex"]
	give(d, 1, {"lfg:item/coin": 100})
	cmd(d, "trade", {"holding": mer["id"], "side": "buy", "item": "lfg:item/ration", "qty": 3})
	check(not (mer.get("prices", {}) as Dictionary).is_empty(), "trade moved the price")
	_roundtrip(d, "prices")

func test_schema_version_unchanged_and_old_saves_load() -> void:
	var s: MatchState = quiet()
	eq(s.to_dict()["schema_version"], 1, "schema_version stays 1 (only additive optional fields)")
	var old: Dictionary = s.to_dict()
	old.erase("fx")
	var back: MatchState = MatchState.from_dict(old)
	eq(back.fx.size(), 0, "pre-fx saves load with no effects")
	for h in back.holdings.values():
		check(not h.has("sites") or h["sites"] is Dictionary, "sites optional")
	check(cmd(back, "rest")["ok"], "loaded state is playable")
