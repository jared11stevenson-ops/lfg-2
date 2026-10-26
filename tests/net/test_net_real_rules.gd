extends TestCase
## Two-client localhost test against the REAL Rules module and REAL MatchState (rules/api.gd), no fake.
## Server and both clients run in this one process over real ENet sockets on 127.0.0.1.
var server: NetServer
var clients: Array[NetClient] = []
var port: int = 0
var tokens: Array[String] = []
var st: MatchState
var a_id: int = 1       # the player leader
var b_id: int = -1      # faction 1's leader, driven by client B (AI off in this match)

func _boot(day_seconds: float = 60.0) -> void:
	ClassLink.overrides = {}
	st = Rules.new_match(1234, &"lfg:class/judd", {"ai_enabled": false, "wild_enemies": false, "day_seconds": day_seconds})
	b_id = int(st.factions[1]["leader"])
	server = NetServer.new()
	for _t in 20:
		port = 20000 + randi() % 20000
		if server.start(port, st, Rules) == OK:
			break
	tokens = [server.issue_token(a_id), server.issue_token(b_id)]
	for i in 2:
		var c := NetClient.new()
		c.connect_to("127.0.0.1", port, tokens[i])
		clients.append(c)
	check(_until(func(): return clients[0].is_ready and clients[1].is_ready), "both clients welcomed")

func after_each() -> void:
	for c in clients:
		c.disconnect_now()
	clients.clear()
	if server != null:
		server.stop()

func _pump(n: int = 20) -> void:
	for _i in n:
		server.poll()
		for c in clients:
			c.poll()
		OS.delay_msec(1)

func _until(cond: Callable, max_iter: int = 600) -> bool:
	for _i in max_iter:
		_pump(1)
		if cond.call():
			return true
	return false

func _items_total() -> Dictionary:
	var t: Dictionary = {}
	for a in st.actors.values():
		for k in a["inv"]:
			t[k] = int(t.get(k, 0)) + int(a["inv"][k])
	for h in st.holdings.values():
		for k in h["store"]:
			t[k] = int(t.get(k, 0)) + int(h["store"][k])
	for d in st.drops.values():
		for k in d:
			t[k] = int(t.get(k, 0)) + int(d[k])
	return t

func _to_purge() -> void:
	var guard := 0
	while st.phase != &"PURGE_ACTIVE" and guard < 2000:
		server.advance(5.0)
		guard += 1
	_pump(20)

func test_snapshots_come_from_real_match_state() -> void:
	_boot()
	check(server.state is MatchState, "server holds a real MatchState")
	eq(clients[0].actor, a_id, "client A bound to leader")
	eq(clients[1].actor, b_id, "client B bound to faction-1 leader")
	var rebuilt: MatchState = MatchState.from_dict(clients[0].snapshot)
	eq(rebuilt.seed, 1234, "snapshot rebuilds into MatchState with same seed")
	eq(clients[0].snapshot, clients[1].snapshot, "both clients hold the same snapshot")
	eq(clients[0].snapshot, st.to_dict(), "snapshot equals server MatchState.to_dict() (wire round trip is lossless)")
	# NOTE: MatchState.from_dict(to_dict()) is not bit-identical (e.g. energy 0.0 -> 0); it is idempotent after one pass.
	var once: Dictionary = rebuilt.to_dict()
	eq(MatchState.from_dict(once).to_dict(), once, "from_dict/to_dict is stable after one pass")
	eq(rebuilt.holdings.size(), st.holdings.size(), "holdings preserved")

func test_duplicate_eat_applies_once_and_matches_local_rules() -> void:
	_boot()
	var before: int = int(st.actors[a_id]["inv"].get("lfg:item/ration", 0))
	check(before >= 2, "player starts with rations (%d)" % before)
	var seq: int = clients[0].submit(&"eat", {"item": "lfg:item/ration"})
	for _i in 4:
		clients[0].resend(seq)
	check(_until(func(): return clients[0].results.has(seq)), "answered")
	_pump(40)
	eq(int(st.actors[a_id]["inv"]["lfg:item/ration"]), before - 1, "exactly one ration eaten")
	check(clients[0].results[seq]["ok"], "ok")
	# the Rules module's own seq guard backs this up even if the server layer were bypassed
	var direct: Dictionary = Rules.apply(st, {"type": &"eat", "actor": a_id, "seq": seq, "args": {}})
	check(not direct["ok"], "Rules itself rejects the replayed seq")
	eq(int(st.actors[a_id]["inv"]["lfg:item/ration"]), before - 1, "still one eaten")

func test_peace_blocks_capture_and_attack_then_server_clock_opens_purge() -> void:
	_boot()
	var target_h: Dictionary = st.holdings[st.factions[2]["home"]]
	# put both leaders next to each other and A next to a rival holding (server-side test setup)
	st.actors[a_id]["hex"] = target_h["hex"]
	st.actors[b_id]["hex"] = target_h["hex"]
	var cap: int = clients[0].submit(&"capture", {"holding": target_h["id"]})
	var atk: int = clients[0].submit(&"attack", {"target": b_id})
	check(_until(func(): return clients[0].results.has(cap) and clients[0].results.has(atk)), "answered")
	eq(clients[0].results[cap]["error"], "not_purge", "capture refused in peace")
	eq(clients[0].results[atk]["error"], "not_purge", "PvP refused in peace")
	# spoof attempts
	clients[0]._send({"t": "cmd", "cmd": {"type": &"attack", "seq": 77, "phase": &"PURGE_ACTIVE", "args": {"target": b_id}}})
	var sp: int = clients[0].submit(&"attack", {"target": b_id, "phase": "PURGE_ACTIVE", "clock": {"day": 7, "time_of_day": 0.9}})
	check(_until(func(): return clients[0].results.has(77) and clients[0].results.has(sp)), "spoofs answered")
	eq(clients[0].results[77]["error"], "unknown_field", "unknown top-level field")
	eq(clients[0].results[sp]["error"], "not_purge", "args cannot alter phase")
	OS.delay_msec(300)
	_pump(20)
	eq(st.phase, &"PEACE", "wall-clock time does not advance the game")
	var hp_before: int = int(st.actors[b_id]["hp"])
	_to_purge()
	eq(st.phase, &"PURGE_ACTIVE", "server clock reached the purge")
	var atk2: int = clients[0].submit(&"attack", {"target": b_id})
	check(_until(func(): return clients[0].results.has(atk2)), "answered")
	check(clients[0].results[atk2]["ok"], "attack accepted once the server's clock says purge (%s)" % clients[0].results[atk2].get("error", ""))
	check(int(st.actors[b_id]["hp"]) < hp_before, "damage dealt")
	check(clients[1].events_log.any(func(e): return e["type"] == &"phase_changed"), "phase change reached client B")

func test_simultaneous_captures_conserve_items_and_ownership() -> void:
	_boot()
	var hid: int = -1
	for id in st.holdings:
		if int(st.holdings[id]["owner"]) == -1:
			hid = int(id)
			break
	check(hid != -1, "neutral holding exists")
	var h: Dictionary = st.holdings[hid]
	h["garrison"] = 0
	st.actors[a_id]["hex"] = h["hex"]
	st.actors[b_id]["hex"] = h["hex"]
	_to_purge()
	st.actors[a_id]["hex"] = h["hex"]
	st.actors[b_id]["hex"] = h["hex"]
	var before: Dictionary = _items_total()
	var faction_a: int = int(st.actors[a_id]["faction"])
	var faction_b: int = int(st.actors[b_id]["faction"])
	var sa: int = clients[0].submit(&"capture", {"holding": hid})
	var sb: int = clients[1].submit(&"capture", {"holding": hid})
	check(_until(func(): return clients[0].results.has(sa) and clients[1].results.has(sb)), "both answered")
	_pump(30)
	var all_events: Array = clients[0].events_log
	var cap_events: Array = all_events.filter(func(e): return e["type"] == &"holding_captured" or e["type"] == &"capture_failed")
	eq(cap_events.size(), 2, "each request resolved exactly once (serialised by the server)")
	var last_capture: Variant = null
	for e in cap_events:
		if e["type"] == &"holding_captured":
			last_capture = e
	var owner: int = int(st.holdings[hid]["owner"])
	if last_capture != null:
		eq(owner, int(last_capture["by"]), "final owner is the last successful capturer")
	else:
		eq(owner, -1, "no capture succeeded: owner unchanged")
	check(owner == -1 or owner == faction_a or owner == faction_b, "owner is one of the two contenders")
	eq(_items_total(), before, "every item conserved across actors, stores and drops")
	for k in st.actors[a_id]["inv"]:
		check(int(st.actors[a_id]["inv"][k]) >= 0 and int(st.actors[b_id]["inv"].get(k, 0)) >= 0, "no negative stacks")

func test_reconnect_after_server_restart_continues_seq() -> void:
	_boot()
	var s1: int = clients[0].submit(&"eat", {"item": "lfg:item/ration"})
	_until(func(): return clients[0].results.has(s1))
	var last: int = int(st.actors[a_id]["last_seq"])
	eq(last, s1, "Rules recorded the seq")
	clients[0].disconnect_now()
	server.stop()
	# new server process, same authoritative state, fresh session table
	server = NetServer.new()
	for _t in 20:
		port = 20000 + randi() % 20000
		if server.start(port, st, Rules) == OK:
			break
	var tok: String = server.issue_token(a_id)
	var c := NetClient.new()
	clients[0] = c
	c.connect_to("127.0.0.1", port, tok)
	check(_until(func(): return c.is_ready), "reconnected to restarted server")
	check(c.next_seq > last, "client seq resumes past Rules' last_seq (%d > %d)" % [c.next_seq, last])
	var s2: int = c.submit(&"eat", {"item": "lfg:item/ration"})
	_until(func(): return c.results.has(s2))
	check(c.results[s2]["ok"], "post-restart command applies")
