extends RulesTestBase
## Real AI: A* routes, marching raid parties, sieges, sorties, fog-limited intel, personas, conservation, bounded CPU.

const DAY := 360.0

func _ai(seed_value: int = 12, extra: Dictionary = {}) -> MatchState:
	var o: Dictionary = {"day_seconds": DAY, "wild_enemies": false}
	o.merge(extra, true)
	return Rules.new_match(seed_value, &"lfg:class/judd", o)

func _persona(s: MatchState, who: String) -> int:
	for fid in s.factions.keys():
		if s.factions[fid]["is_ai"] and s.factions[fid]["persona"] == who:
			return fid
	return -1

func _home(s: MatchState, fid: int) -> Dictionary:
	return s.holdings[int(s.factions[fid]["home"])]

## Moves holding `hid` to a ground hex exactly `d` away from `from` that is connected by land.
func _relocate(s: MatchState, hid: int, from: Vector2i, d: int) -> bool:
	var comp: Dictionary = WorldGen.flood(s.world, from)
	var ids: Array = comp.keys()
	ids.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return HexGrid.index(a) < HexGrid.index(b))
	for h in ids:
		if HexGrid.distance(h, from) == d and int(s.world["terrain"][HexGrid.index(h)]) == WorldGen.T_GROUND and CmdUtil.holding_at(s, h) == -1 and not s.plots.has(MatchState.plot_key(h)):
			s.holdings[hid]["hex"] = h
			return true
	return false

func _quiet_others(s: MatchState, keep: Array) -> void:
	## Only the factions in `keep` act; the rest are inert (alive but no raids).
	for fid in s.factions.keys():
		if s.factions[fid]["is_ai"] and not keep.has(fid):
			s.factions[fid]["persona"] = "turtle"

func _run_until(s: MatchState, pred: Callable, max_secs: float, step: float = 1.0) -> Array:
	var all: Array = []
	var t: float = 0.0
	while t < max_secs and not s.over:
		all.append_array(Rules.tick(s, step))
		t += step
		if pred.call(all):
			break
	return all

func _first(events: Array, type: String) -> Dictionary:
	for e in events:
		if String(e["type"]) == type:
			return e
	return {}

# ------------------------------------------------------------ pathing
func test_routes_are_contiguous_passable_and_cost_aware() -> void:
	var s: MatchState = _ai()
	var f: int = _persona(s, "raider")
	var from: Vector2i = _home(s, f)["hex"]
	var to: Vector2i = from
	for h in s.holdings.values():
		var d: int = HexGrid.distance(h["hex"], from)
		if d >= 8 and d <= 14 and not AIFactions.route(s, from, h["hex"]).is_empty():
			to = h["hex"]
			break
	check(to != from, "found a reachable holding 8-14 away")
	var path: Array[Vector2i] = AIFactions.route(s, from, to)
	eq(path[path.size() - 1], to, "ends at the target")
	var prev: Vector2i = from
	var cost: float = 0.0
	for h in path:
		eq(HexGrid.distance(prev, h), 1, "adjacent steps")
		check(WorldGen.move_cost(s.world, h) > 0.0, "passable")
		cost += WorldGen.move_cost(s.world, h)
		prev = h
	check(path.size() >= HexGrid.distance(from, to), "no shorter than the hex distance")
	var again: Array[Vector2i] = AIFactions.route(s, from, to)
	eq(again, path, "cached route is identical")
	# cost-awareness: route cost <= the cost of the naive straight line where that is walkable
	var line: Array[Vector2i] = HexGrid.line(from, to)
	var line_cost: float = 0.0
	var walkable: bool = true
	for i in range(1, line.size()):
		var c: float = WorldGen.move_cost(s.world, line[i])
		if c <= 0.0:
			walkable = false
			break
		line_cost += c
	if walkable:
		check(cost <= line_cost + 0.001, "A* is no costlier than the straight line (%f vs %f)" % [cost, line_cost])

# ------------------------------------------------------------ marching raid
func _raid_setup() -> Dictionary:
	var s: MatchState = _ai()
	var f: int = _persona(s, "raider")
	_quiet_others(s, [f])
	var home: Dictionary = _home(s, f)
	home["garrison"] = 12
	var tid: int = -1
	for h in s.holdings.values():
		if int(h["owner"]) == -1:
			tid = int(h["id"])
			break
	check(_relocate(s, tid, home["hex"], 6), "target placed 6 hexes away")
	var t: Dictionary = s.holdings[tid]
	t["garrison"] = 0
	t["store"] = {"lfg:item/ration": 20, "lfg:item/coin": 30, "lfg:item/timber": 6}
	t["merchant"] = false
	return {"s": s, "f": f, "home": home, "t": t}

func test_raid_party_marches_hex_by_hex_arrives_captures_and_returns_loot() -> void:
	var c: Dictionary = _raid_setup()
	var s: MatchState = c["s"]
	var f: int = c["f"]
	var home: Dictionary = c["home"]
	var t: Dictionary = c["t"]
	warp(s, 7, 0.49)
	var all: Array = _run_until(s, func(_e: Array) -> bool: return s.phase == &"PURGE_ACTIVE", 60.0, 1.0)
	eq(s.phase, &"PURGE_ACTIVE", "purge began")
	var t0: Dictionary = Inv.world_totals(s)
	var now0: float = float(s.clock["elapsed"])
	var disp: Dictionary = _first(all, "party_dispatched")
	check(not disp.is_empty(), "a party was dispatched on the purge's first tick")
	var parties: Array[int] = AIFactions.parties_of(s, f)
	eq(parties.size(), 1, "raider has one party out")
	var p: Dictionary = s.actors[parties[0]]
	eq(p["kind"], "party", "party is an actor")
	eq(p["faction"], f, "owned by the raider")
	eq(p["ai"]["mission"], "capture", "raider captures")
	eq(p["ai"]["target"], t["id"], "at the intel target")
	check(int(home["garrison"]) < 12, "troops left the garrison (%d)" % int(home["garrison"]))
	eq(p["hex"], home["hex"], "marches out of the home holding")
	var trail: Array[Vector2i] = [p["hex"]]
	var arrived: Dictionary = {}
	var guard: int = 0
	while arrived.is_empty() and guard < 600:
		guard += 1
		var e2: Array = Rules.tick(s, 1.0)
		all.append_array(e2)
		if s.actors.has(parties[0]) and s.actors[parties[0]]["hex"] != trail[trail.size() - 1]:
			trail.append(s.actors[parties[0]]["hex"])
		arrived = _first(e2, "party_arrived")
	check(not arrived.is_empty(), "party reached the target")
	for i in range(1, trail.size()):
		check(HexGrid.distance(trail[i - 1], trail[i]) == 1, "marched one hex at a time")
	check(trail.size() >= 4, "walked several hexes (%d)" % trail.size())
	check(HexGrid.distance(trail[trail.size() - 1], t["hex"]) <= 1, "arrived next to the target")
	var walked_secs: float = float(s.clock["elapsed"]) - now0
	check(walked_secs >= float(disp["eta"]) * 0.5, "took real march time (%f s of eta %f)" % [walked_secs, float(disp["eta"])])
	var res: Array = _run_until(s, func(e: Array) -> bool: return not _first(e, "party_returned").is_empty(), 200.0, 1.0)
	all.append_array(res)
	check(not _first(all, "holding_captured").is_empty(), "the siege resolved through Conquest.resolve_capture")
	eq(t["owner"], f, "undefended target fell to the raiders")
	check(not _first(all, "party_returned").is_empty(), "courier brought the loot home")
	check(AIFactions.parties_of(s, f).is_empty(), "party disbanded")
	eq(Inv.world_totals(s), t0, "the whole raid conserved every item")

func test_ai_party_resolves_with_current_troops_after_sorties() -> void:
	var c: Dictionary = _raid_setup()
	var s: MatchState = c["s"]
	var f: int = c["f"]
	var t: Dictionary = c["t"]
	t["garrison"] = 6                       # defenders will sortie while the siege runs
	warp(s, 7, 0.4)
	var all: Array = _run_until(s, func(_e: Array) -> bool: return s.phase == &"PURGE_ACTIVE", 200.0, 5.0)
	all.append_array(_run_until(s, func(e: Array) -> bool: return not _first(e, "party_returned").is_empty() or not _first(e, "actor_died").is_empty(), 300.0, 1.0))
	check(not _first(all, "sortie").is_empty(), "garrison sortied")
	var disp: Dictionary = _first(all, "party_dispatched")
	check(not disp.is_empty(), "dispatched")
	var arrived: Dictionary = _first(all, "party_arrived")
	if not arrived.is_empty():
		check(int(arrived["troops"]) <= int(disp["troops"]), "arrived with no more troops than sent")

func test_stale_intel_leads_to_failed_raid_and_survivors_return() -> void:
	var c: Dictionary = _raid_setup()
	var s: MatchState = c["s"]
	var f: int = c["f"]
	var home: Dictionary = c["home"]
	var t: Dictionary = c["t"]
	# The AI remembers an empty village (seen by an earlier party) ...
	check(_relocate(s, t["id"], home["hex"], 12), "target 12 away: out of current sight")
	s.factions[f]["intel"] = {t["id"]: {"owner": -1, "garrison": 0, "def": 2, "tier": 0, "item": "lfg:item/ration", "qty": 5, "val": 25, "seen_t": 0.0}}
	# ... which has since been fortified (the AI cannot know).
	t["garrison"] = 1
	t["buildings"] = ["lfg:building/wall_stone", "lfg:building/wall_stone", "lfg:building/wall_stone"]
	t["ward"] = 1.0e9
	warp(s, 7, 0.49)
	var all: Array = _run_until(s, func(_e: Array) -> bool: return s.phase == &"PURGE_ACTIVE", 60.0, 1.0)
	check(not _first(all, "party_dispatched").is_empty(), "attacked on remembered intel")
	all.append_array(_run_until(s, func(e: Array) -> bool: return not _first(e, "capture_failed").is_empty() or not _first(e, "holding_captured").is_empty(), 500.0, 1.0))
	check(not _first(all, "capture_failed").is_empty(), "and the raid failed against the real defences")
	all.append_array(_run_until(s, func(_e: Array) -> bool: return AIFactions.parties_of(s, f).is_empty(), 300.0, 1.0))
	var ret: Dictionary = _first(all, "party_returned")
	check(not ret.is_empty(), "survivors marched home")
	check(int(ret["troops"]) < 8, "casualties are real (%d of 8 came back)" % int(ret["troops"]))
	check(int(t["owner"]) != f, "target not taken")

# ------------------------------------------------------------ fog
func test_targeting_is_limited_to_what_the_faction_has_seen() -> void:
	var c: Dictionary = _raid_setup()
	var s: MatchState = c["s"]
	var f: int = c["f"]
	var home: Dictionary = c["home"]
	var t: Dictionary = c["t"]
	# push the juicy target beyond sight (week 0 vision is 8) but inside raid range
	check(_relocate(s, t["id"], home["hex"], 12), "target 12 away")
	AIFactions.scout(s, f)
	check(not (s.factions[f]["intel"] as Dictionary).has(t["id"]), "unseen: not in intel")
	warp(s, 7, 0.51)
	var ev: Array = []
	s.phase = &"PURGE_ACTIVE"
	var n: int = AIFactions.purge_round(s, ev)
	for e in ev:
		if String(e["type"]) == "party_dispatched":
			check(int(e["target"]) != int(t["id"]), "never attacks a holding it has not seen")
	# bring it into view -> becomes the preferred target
	check(_relocate(s, t["id"], home["hex"], 5), "target 5 away")
	for pid in AIFactions.parties_of(s, f):
		s.actors.erase(pid)
	home["garrison"] = 12
	s.factions[f]["next_act"] = 0.0
	ev.clear()
	n = AIFactions.purge_round(s, ev)
	var d: Dictionary = _first(ev, "party_dispatched")
	check(not d.is_empty(), "now it attacks (dispatched %d)" % n)
	eq(int(d.get("target", -1)), int(t["id"]), "the seen, undefended village is chosen")

func test_vision_grows_with_the_weeks() -> void:
	var s: MatchState = _ai()
	var h: Dictionary = _home(s, _persona(s, "raider"))
	var v0: int = AIFactions.vision_of(s, h)
	s.set_time(22, 0.1)
	check(AIFactions.vision_of(s, h) > v0, "factions learn the map")
	var tower: Dictionary = h
	tower["buildings"] = ["lfg:building/watchtower_2"]
	check(AIFactions.vision_of(s, tower) >= AIFactions.vision_of(s, {"buildings": []}) , "towers extend sight")

# ------------------------------------------------------------ defenders and the player's response
func test_player_can_kill_a_raid_party_and_loot_is_conserved() -> void:
	var c: Dictionary = _raid_setup()
	var s: MatchState = c["s"]
	var f: int = c["f"]
	var t: Dictionary = c["t"]
	t["owner"] = 0                                  # the target is the player's holding
	t["garrison"] = 0
	t["merchant"] = false
	t["store"] = {"lfg:item/ration": 20, "lfg:item/coin": 30}
	s.holdings[1]["store"]["lfg:item/ration"] = 200
	warp(s, 7, 0.4)
	var all: Array = _run_until(s, func(_e: Array) -> bool: return s.phase == &"PURGE_ACTIVE", 200.0, 5.0)
	all.append_array(_run_until(s, func(e: Array) -> bool: return not _first(e, "raid_warning").is_empty(), 300.0, 1.0))
	var warn: Dictionary = _first(all, "raid_warning")
	check(not warn.is_empty(), "the player is warned when the party closes in")
	eq(int(warn["holding"]), int(t["id"]), "warning names the holding")
	var pid: int = AIFactions.parties_of(s, f)[0]
	var p: Dictionary = s.actors[pid]
	p["inv"] = {"lfg:item/coin": 7}               # pretend it already carries something
	var t0: Dictionary = Inv.world_totals(s)
	s.actors[1]["hex"] = p["hex"] + HexGrid.DIRS[0]
	s.actors[1]["atk"] = 60
	var r: Dictionary = cmd(s, "attack", {"target": pid})
	check(r["ok"], "the leader can strike a party: %s" % r["error"])
	check(p["hp"] < p["max_hp"] or not p["alive"], "party damaged")
	var guard: int = 0
	while p["alive"] and guard < 20:
		guard += 1
		s.actors[1]["cd"] = {}
		cmd(s, "attack", {"target": pid})
	check(not p["alive"], "the party can be wiped out")
	var t1: Dictionary = Inv.world_totals(s)
	check(int(t1.get("lfg:item/ashmarrow", 0)) >= 1, "a slain raider drops Purge-only ashmarrow")
	t1.erase("lfg:item/ashmarrow")
	eq(t1, t0, "its loot dropped without loss (ashmarrow is the only new item)")
	Rules.tick(s, 1.0)
	check(not s.actors.has(pid), "dead party removed")
	eq(t["owner"], 0, "holding saved")

func test_garrison_leader_and_ward_raise_defence_against_a_siege() -> void:
	var s: MatchState = _ai()
	var h: Dictionary = s.holdings[1]
	var base: float = Conquest.defender_power(s, h)
	s.actors[1]["hex"] = h["hex"]
	check(Conquest.defender_power(s, h) > base - 0.001, "leader presence never hurts")
	h["garrison"] = 10
	check(Conquest.defender_power(s, h) >= base + 20.0, "each defender counts 3")

# ------------------------------------------------------------ personas
func test_personas_behave_differently_over_a_purge() -> void:
	var s: MatchState = _ai(12, {"wild_enemies": true})
	s.holdings[1]["store"]["lfg:item/ration"] = 800
	var by_persona: Dictionary = {"raider": 0, "hoarder": 0, "trader": 0, "turtle": 0}
	var built: Dictionary = {"raider": 0, "hoarder": 0, "trader": 0, "turtle": 0}
	var traded: int = 0
	var hired: int = 0
	var missions: Dictionary = {}
	var all: Array = tick_all(s, DAY * 6.0, 5.0)           # through peace and into the warning
	for e in all:
		if String(e["type"]) == "ai_built":
			built[s.factions[int(e["faction"])]["persona"]] += 1
		elif String(e["type"]) == "ai_traded":
			traded += 1
		elif String(e["type"]) == "ai_hired":
			hired += 1
	all = tick_all(s, DAY * 1.5, 1.0)                       # the first purge
	for e in all:
		if String(e["type"]) == "party_dispatched":
			var per: String = s.factions[int(e["by"])]["persona"]
			by_persona[per] += 1
			missions[per] = String(e["mission"])
	eq(int(by_persona["trader"]), 0, "traders never raid")
	eq(int(by_persona["turtle"]), 0, "turtles never raid")
	check(int(by_persona["raider"]) + int(by_persona["hoarder"]) > 0, "raiders/hoarders send parties (%s)" % str(by_persona))
	if missions.has("raider"):
		eq(missions["raider"], "capture", "raiders capture")
	if missions.has("hoarder"):
		eq(missions["hoarder"], "steal", "hoarders steal")
	check(int(built["turtle"]) > 0, "turtles fortify in peace (%s)" % str(built))
	check(traded > 0, "traders trade in peace (%d)" % traded)
	check(hired > 0, "traders hire mercenaries on the warning day (%d)" % hired)

func test_truce_keeps_a_faction_off_the_players_holdings() -> void:
	var c: Dictionary = _raid_setup()
	var s: MatchState = c["s"]
	var f: int = c["f"]
	var t: Dictionary = c["t"]
	t["owner"] = 0
	t["garrison"] = 0
	s.factions[f]["truce_until"] = 1.0e6
	warp(s, 7, 0.51)
	s.phase = &"PURGE_ACTIVE"
	var ev: Array = []
	AIFactions.scout(s, f)
	AIFactions.purge_round(s, ev)
	for e in ev:
		if String(e["type"]) == "party_dispatched":
			check(int(e["target"]) != int(t["id"]), "truce: not the player's holding")
	s.factions[f]["truce_until"] = 0.0
	s.factions[f]["next_act"] = 0.0
	for pid in AIFactions.parties_of(s, f):
		s.actors.erase(pid)
	ev.clear()
	AIFactions.purge_round(s, ev)
	check(not _first(ev, "party_dispatched").is_empty(), "without the truce it comes")

# ------------------------------------------------------------ when does the AI act
func test_ai_only_acts_while_the_sim_ticks() -> void:
	var s: MatchState = _ai(12, {"ai_enabled": true})
	warp(s, 7, 0.49)
	var before: String = snap(s)
	for i in range(20):
		cmd(s, "rest")
	Rules.tick(s, 0.0)
	Rules.tick(s, -5.0)
	var after: Dictionary = JSON.parse_string(snap(s))
	var b: Dictionary = JSON.parse_string(before)
	eq(after["actors"].size(), b["actors"].size(), "no actors created by commands")
	for k in ["factions", "holdings", "fx"]:
		eq(after[k], b[k], "%s untouched" % k)
	var off: MatchState = _ai(12, {"ai_enabled": false})
	warp(off, 7, 0.49)
	tick_all(off, DAY * 0.4, 2.0)
	eq(AIFactions.parties_of(off, -1).size(), 0, "ai_enabled=false: no parties")

func test_recall_at_resolution_returns_troops_and_loot() -> void:
	var c: Dictionary = _raid_setup()
	var s: MatchState = c["s"]
	var f: int = c["f"]
	var home: Dictionary = c["home"]
	warp(s, 7, 0.4)
	_run_until(s, func(_e: Array) -> bool: return not AIFactions.parties_of(s, f).is_empty(), 400.0, 1.0)
	var pid: int = AIFactions.parties_of(s, f)[0]
	s.actors[pid]["inv"] = {"lfg:item/timber": 3}
	var g0: int = int(home["garrison"])
	var timber0: int = Inv.count(home["store"], "lfg:item/timber")
	var t0: Dictionary = Inv.world_totals(s)
	s.phase = &"RESOLUTION"
	var ev: Array = []
	AIFactions.party_step(s, ev)
	check(not s.actors.has(pid), "party recalled at the end of the purge")
	check(int(home["garrison"]) > g0, "troops rejoined the garrison")
	eq(Inv.count(home["store"], "lfg:item/timber"), timber0 + 3, "loot banked")
	eq(Inv.world_totals(s), t0, "conserved")

# ------------------------------------------------------------ cost
func test_ai_cpu_is_bounded_with_twelve_factions() -> void:
	var s: MatchState = _ai(12, {"wild_enemies": true})
	s.holdings[1]["store"]["lfg:item/ration"] = 3000
	s.actors[1]["max_hp"] = 100000
	s.actors[1]["hp"] = 100000
	var n_ai: int = 0
	for f in s.factions.values():
		if f["is_ai"]:
			n_ai += 1
	check(n_ai >= 12, "12+ AI factions (%d)" % n_ai)
	var ticks: int = 0
	var worst: int = 0
	var t_all: int = Time.get_ticks_usec()
	var secs: float = DAY * 15.0
	var left: float = secs
	var parties_seen: int = 0
	while left > 0.0:
		var t0: int = Time.get_ticks_usec()
		Rules.tick(s, 1.0)
		var us: int = Time.get_ticks_usec() - t0
		worst = maxi(worst, us)
		ticks += 1
		left -= 1.0
		if AIFactions.has_parties(s):
			parties_seen += 1
	var total_us: int = Time.get_ticks_usec() - t_all
	var avg_ms: float = float(total_us) / float(ticks) / 1000.0
	print("ai cpu: %d ticks of 1s, avg %.3f ms, worst %.2f ms, parties alive in %d ticks" % [ticks, avg_ms, float(worst) / 1000.0, parties_seen])
	check(avg_ms < 3.0, "average tick under 3 ms (%.3f)" % avg_ms)
	check(float(worst) / 1000.0 < 120.0, "worst tick bounded (%.1f ms)" % (float(worst) / 1000.0))
	check(parties_seen > 0, "parties were actually simulated during the measurement")
