extends "res://tests/net/net_fixture.gd"

func _ready_clients() -> void:
	connect_client(0)
	connect_client(1)
	check(until(func(): return clients[0].is_ready and clients[1].is_ready), "both clients welcomed")

func test_validate_cmd_pure() -> void:
	var ok: Dictionary = NetServer.validate_cmd({"type": &"eat", "seq": 1, "args": {}}, 3)
	check(ok["ok"], "minimal cmd ok")
	eq(ok["cmd"]["actor"], 3, "actor bound from session, not client")
	eq(NetServer.validate_cmd({"type": &"eat", "seq": 1, "actor": 4}, 3)["error"], "actor_mismatch", "spoofed actor")
	eq(NetServer.validate_cmd({"type": &"eat", "seq": 1, "time": 5}, 3)["error"], "unknown_field", "client-supplied time field")
	eq(NetServer.validate_cmd({"type": &"tick", "seq": 1}, 3)["error"], "bad_type", "tick is not a client command")
	eq(NetServer.validate_cmd({"type": &"eat", "seq": "1"}, 3)["error"], "bad_seq", "string seq")
	eq(NetServer.validate_cmd({"type": &"eat", "seq": 0}, 3)["error"], "bad_seq", "zero seq")
	eq(NetServer.validate_cmd({"type": &"eat", "seq": 1.0}, 3)["error"], "bad_seq", "float seq")
	eq(NetServer.validate_cmd({"type": &"eat", "seq": 1, "args": 5}, 3)["error"], "bad_args", "non-dict args")
	eq(NetServer.validate_cmd({"type": &"eat", "seq": 1, "args": {"a": Node.new()}}, 3)["error"], "bad_args", "object in args")
	eq(NetServer.validate_cmd({"type": &"eat", "seq": 1, "args": {"a": {"b": {"c": {"d": {"e": {"f": 1}}}}}}}, 3)["error"], "bad_args", "too deep")
	eq(NetServer.validate_cmd({"type": &"eat", "seq": 1, "args": {"x": NAN}}, 3)["error"], "bad_args", "NaN")
	eq(NetServer.validate_cmd("nope", 3)["error"], "bad_shape", "non-dict")
	check(NetCodec.decode(PackedByteArray([1, 2, 3])).is_empty(), "garbage bytes decode to empty")
	check(NetCodec.decode(var_to_bytes([1, 2])).is_empty(), "non-dict decode to empty")

func test_two_clients_get_real_state_snapshot() -> void:
	boot()
	_ready_clients()
	eq(clients[0].actor, 0, "client0 bound to actor 0")
	eq(clients[1].actor, 1, "client1 bound to actor 1")
	eq(clients[0].snapshot, server.state.to_dict(), "snapshot equals server MatchState.to_dict")
	var rebuilt: Object = Fake.FakeState.from_dict(clients[1].snapshot)
	eq(rebuilt.to_dict(), server.state.to_dict(), "client can rebuild MatchState from snapshot")

func test_command_applied_by_server_rules_and_events_broadcast() -> void:
	boot()
	_ready_clients()
	var seq: int = clients[0].submit(&"eat")
	check(until(func(): return clients[0].results.has(seq) and clients[1].events_log.size() > 0), "result + broadcast")
	check(clients[0].results[seq]["ok"], "ok")
	eq(server.state.actors[0]["inv"][Fake.RATION], 4, "server state mutated by Rules.apply")
	eq(clients[1].events_log[0]["type"], &"ate", "other client sees event")
	var bad: int = clients[0].submit(&"trade", {"to": 1, "item": Fake.COIN, "qty": 5})
	until(func(): return clients[0].results.has(bad))
	check(not clients[0].results[bad]["ok"], "rules rejection propagates")
	eq(clients[0].results[bad]["error"], "insufficient", "error text")
	eq(server.state.actors[0]["inv"][Fake.COIN], 0, "failed command mutated nothing")

func test_duplicate_requests_apply_once() -> void:
	boot()
	_ready_clients()
	var before: int = Fake.total(server.state, Fake.RATION)
	var seq: int = clients[0].submit(&"trade", {"to": 1, "item": Fake.RATION, "qty": 2})
	clients[0].resend(seq)
	clients[0].resend(seq)
	check(until(func(): return clients[0].results.has(seq)), "got result")
	pump(30)
	eq(server.state.actors[0]["inv"][Fake.RATION], 3, "sender debited once")
	eq(server.state.actors[1]["inv"][Fake.RATION], 7, "receiver credited once")
	eq(Fake.total(server.state, Fake.RATION), before, "total conserved")
	# replay long after: still idempotent, and flagged duplicate
	var dup_seen := [false]
	clients[0].result_received.connect(func(s: int, r: Dictionary): if s == seq and r.get("duplicate", false): dup_seen[0] = true)
	clients[0].pending[seq] = {"type": &"trade", "actor": 0, "seq": seq, "args": {"to": 1, "item": Fake.RATION, "qty": 2}}
	clients[0].resend(seq)
	until(func(): return dup_seen[0])
	check(dup_seen[0], "replay answered from cache")
	eq(server.state.actors[0]["inv"][Fake.RATION], 3, "still debited once")

func test_stale_and_out_of_window_seq_rejected() -> void:
	boot()
	_ready_clients()
	var c: NetClient = clients[0]
	c.next_seq = 10
	var s10: int = c.submit(&"eat")
	until(func(): return c.results.has(s10))
	c.next_seq = 5
	var s5: int = c.submit(&"eat")
	until(func(): return c.results.has(s5))
	eq(c.results[s5]["error"], "stale_seq", "older unseen seq rejected")
	c.next_seq = 10 + NetServer.MAX_SEQ_JUMP + 5
	var sj: int = c.submit(&"eat")
	until(func(): return c.results.has(sj))
	eq(c.results[sj]["error"], "seq_jump", "huge jump rejected")
	eq(server.state.actors[0]["inv"][Fake.RATION], 4, "only the first eat applied")

func test_simultaneous_captures_conserve_ownership_and_items() -> void:
	boot()
	_ready_clients()
	var before: int = Fake.total(server.state, Fake.COIN)
	# both packets are in flight before the server polls: genuinely simultaneous from the server's view
	var s0: int = clients[0].submit(&"capture", {"holding": 0})
	var s1: int = clients[1].submit(&"capture", {"holding": 0})
	check(until(func(): return clients[0].results.has(s0) and clients[1].results.has(s1)), "both answered")
	var oks: int = int(clients[0].results[s0]["ok"]) + int(clients[1].results[s1]["ok"])
	eq(oks, 1, "exactly one capture succeeds")
	var owner: int = server.state.holdings[0]["owner"]
	check(owner == 0 or owner == 1, "single owner")
	eq(clients[owner].results[s0 if owner == 0 else s1]["ok"], true, "winner is the owner")
	eq(server.state.actors[owner]["inv"][Fake.COIN], 10, "loot granted once")
	eq(server.state.actors[1 - owner]["inv"][Fake.COIN], 0, "loser got nothing")
	eq(Fake.total(server.state, Fake.COIN), before, "coin conserved")
	var caps := 0
	for e in clients[0].events_log:
		if e["type"] == &"holding_captured":
			caps += 1
	eq(caps, 1, "one capture event broadcast")

func test_auth_and_binding() -> void:
	boot()
	var bad := NetClient.new()
	bad.connect_to("127.0.0.1", port, "deadbeef")
	clients.append(bad)
	pump(40)
	check(not bad.is_ready, "bad token never welcomed")
	var seq: int = bad.submit(&"eat")
	pump(40)
	check(not bad.results.has(seq) or not bad.results[seq]["ok"], "unauthenticated command not applied")
	eq(server.state.actors[0]["inv"][Fake.RATION], 5, "no mutation")
	var good: NetClient = connect_client(1)
	until(func(): return good.is_ready)
	var spoof: Dictionary = {"type": &"eat", "actor": 0, "seq": 1, "args": {}}
	good._send({"t": "cmd", "cmd": spoof})
	check(until(func(): return good.results.has(1)), "answered")
	eq(good.results[1]["error"], "actor_mismatch", "cannot act as another actor")
	eq(server.state.actors[0]["inv"][Fake.RATION], 5, "victim untouched")
	server.revoke_token(tokens[1])
	pump(30)
	check(not good.is_ready, "revoked token kicked")

func test_garbage_and_oversize_packets_do_not_crash_and_kick() -> void:
	boot()
	var c: NetClient = connect_client(0)
	until(func(): return c.is_ready)
	for i in 5:
		c.peer.send(0, PackedByteArray([9, 9, 9, i]), ENetPacketPeer.FLAG_RELIABLE)
	pump(30)
	c.peer.send(0, var_to_bytes({"t": "cmd", "pad": "x".repeat(NetCodec.MAX_PACKET + 10)}), ENetPacketPeer.FLAG_RELIABLE)
	pump(40)
	check(not c.is_ready or c.last_bye != "", "oversize connection dropped")
	check(server.state != null and server.state.actors.size() == 2, "server still sound")

func test_rate_limit_uses_server_clock() -> void:
	boot()
	_ready_clients()
	var c: NetClient = clients[0]
	var sent: Array[int] = []
	for i in 40:
		sent.append(c.submit(&"eat"))
	pump(100)
	# 5 rations => at most 5 successes regardless; count rate-limit rejections via server bucket state
	var s: Dictionary = server.session_for_token(tokens[0])
	check(s["violations"] >= 15, "over-limit packets were counted (%d)" % s["violations"])
	check(s["tokens"] < 1.0, "bucket empty without server time passing")
	var rations: int = server.state.actors[0]["inv"][Fake.RATION]
	check(rations >= 0 and rations <= 5, "state sane")
	# wall-clock waiting does not refill it
	OS.delay_msec(300)
	pump(10)
	check(s["tokens"] < 1.0, "wall-clock does not refill")
	server.advance(1.0)
	check(s["tokens"] >= 9.0, "server clock refills bucket (%f)" % s["tokens"])

func test_disconnect_and_reconnect_resumes_same_actor() -> void:
	boot()
	_ready_clients()
	var c: NetClient = clients[0]
	var s1: int = c.submit(&"eat")
	until(func(): return c.results.has(s1))
	c.disconnect_now()
	check(until(func(): return not server.is_connected_actor(0)), "server notices disconnect")
	eq(server.state.actors[0]["inv"][Fake.RATION], 4, "state persists while offline")
	# command sent while offline is queued client-side and replayed after reconnect (twice, on purpose)
	var s2: int = c.submit(&"eat")
	eq(c.pending.size(), 1, "pending while offline")
	c.reconnect()
	check(until(func(): return c.is_ready), "welcomed again")
	eq(c.actor, 0, "same actor")
	c.resend_all()
	c.resend_all()
	check(until(func(): return c.results.has(s2)), "replayed command answered")
	pump(20)
	eq(server.state.actors[0]["inv"][Fake.RATION], 3, "applied exactly once despite replays")
	check(c.next_seq > s2, "seq continues")

func test_second_connection_with_same_token_replaces_first() -> void:
	boot()
	var a: NetClient = connect_client(0)
	until(func(): return a.is_ready)
	var b: NetClient = connect_client(0)
	check(until(func(): return b.is_ready), "new socket welcomed")
	check(until(func(): return a.last_bye == "replaced"), "old socket told it was replaced")
	var seq: int = b.submit(&"eat")
	until(func(): return b.results.has(seq))
	check(b.results[seq]["ok"], "new socket works")

func test_server_clock_gates_purge_pvp() -> void:
	boot()
	_ready_clients()
	var atk: int = clients[0].submit(&"attack", {"target": 1})
	until(func(): return clients[0].results.has(atk))
	eq(clients[0].results[atk]["error"], "peace_no_pvp", "PvP refused in peace")
	# client tries to smuggle time/phase in every place it can
	clients[0]._send({"t": "cmd", "cmd": {"type": &"attack", "seq": 50, "time": 15.0, "phase": &"PURGE_ACTIVE", "args": {"target": 1}}})
	var seq: int = clients[0].submit(&"attack", {"target": 1, "phase": &"PURGE_ACTIVE", "time": 15.0, "clock": {"time_of_day": 15.0}})
	until(func(): return clients[0].results.has(50) and clients[0].results.has(seq))
	eq(clients[0].results[50]["error"], "unknown_field", "extra top-level fields rejected")
	eq(clients[0].results[seq]["error"], "peace_no_pvp", "args cannot change the phase")
	eq(server.state.actors[1]["hp"], 30, "no damage")
	# wall-clock passing in the test process does not advance the game
	OS.delay_msec(300)
	pump(20)
	eq(server.state.phase, &"PEACE", "phase is server-tick driven only")
	# only server.advance moves the clock
	server.advance(11.0)
	pump(20)
	eq(server.state.phase, &"PURGE_ACTIVE", "server clock enters purge")
	check(until(func(): return clients[1].events_log.any(func(e): return e["type"] == &"phase_changed")), "phase change broadcast")
	var atk2: int = clients[0].submit(&"attack", {"target": 1})
	until(func(): return clients[0].results.has(atk2))
	check(clients[0].results[atk2]["ok"], "attack allowed once the SERVER clock says purge")
	eq(server.state.actors[1]["hp"], 20, "damage applied")
	server.advance(10.0)
	pump(10)
	eq(server.state.phase, &"PEACE", "purge ends by server clock")
	var atk3: int = clients[0].submit(&"attack", {"target": 1})
	until(func(): return clients[0].results.has(atk3))
	eq(clients[0].results[atk3]["error"], "peace_no_pvp", "refused again after purge")

func test_hello_timeout_kicks_silent_connections() -> void:
	boot()
	var raw := NetClient.new()
	raw.host = ENetConnection.new()
	raw.host.create_host(1, 1)
	raw.peer = raw.host.connect_to_host("127.0.0.1", port, 1)
	clients.append(raw)
	pump(30)
	eq(server._peers.size(), 1, "connected but silent")
	server.advance(NetServer.HELLO_TIMEOUT + 1.0)
	eq(server._peers.size(), 0, "dropped after timeout on server clock")

func test_match_over_blocks_commands_and_writes_tombstone() -> void:
	boot()
	Persist.root = "user://t_net"
	Persist.clear_slot(3)
	server.persist_slot = 3
	Persist.save_match(3, server.state)
	_ready_clients()
	server.advance(11.0)
	for i in 3:
		var s: int = clients[0].submit(&"attack", {"target": 1})
		until(func(): return clients[0].results.has(s))
	pump(20)
	check(server.match_over, "server marks match over")
	check(clients[0].events_log.any(func(e): return e["type"] == &"match_over"), "match_over event delivered")
	check(Persist.is_over(3), "tombstone written through Persist")
	eq(Persist.load_match(3)["error"], "match_over", "cannot resume")
	var s2: int = clients[1].submit(&"eat")
	until(func(): return clients[1].results.has(s2))
	eq(clients[1].results[s2]["error"], "match_over", "no commands after match over")
	Persist.clear_slot(3)

func test_autosave_through_persist() -> void:
	boot()
	Persist.root = "user://t_net"
	Persist.clear_slot(4)
	server.persist_slot = 4
	server.advance(server.autosave_interval + 1.0)
	var l: Dictionary = Persist.load_match(4)
	check(l["ok"], "autosave wrote a loadable file")
	check(l["state"] is Fake.FakeState, "reloaded as MatchState class")
	Persist.clear_slot(4)
