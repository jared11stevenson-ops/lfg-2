extends "res://tests/net/real_fixture.gd"
## LocalSession and OnlineSession expose one interface; the same command stream gives the same game.

func _plant_hex(actor: Dictionary) -> Vector2i:
	# a free ground hex within planting range of the actor's home
	for h in HexGrid.ring_within(actor["hex"], 2):
		if h != actor["hex"] and WorldGen.move_cost(st.world, h) > 0.0 and int(st.world["terrain"][HexGrid.index(h)]) == WorldGen.T_GROUND \
				and CmdUtil.holding_at(st, h) == -1 and (Content.crop("lfg:crop/glowfruit")["biomes"] as Array).has(WorldGen.biome_at(st.world, h)):
			return h
	return actor["hex"]

func _online(i: int) -> OnlineSession:
	var s := OnlineSession.join("127.0.0.1", port, tokens[i])
	return s

func _spin(sessions: Array, n: int = 30) -> void:
	for _i in n:
		server.poll()
		for s in sessions:
			(s as GameSession)._process(0.02)
		OS.delay_msec(1)

func _spin_until(sessions: Array, cond: Callable, n: int = 800) -> bool:
	for _i in n:
		_spin(sessions, 1)
		if cond.call():
			return true
	return false

func test_online_session_is_a_filtered_live_view() -> void:
	boot(60.0, {}, 1234, false)
	var sa := _online(0)
	var sb := _online(1)
	var sessions: Array = [sa, sb]
	var replaced := [0]
	sa.state_replaced.connect(func(): replaced[0] += 1)
	check(_spin_until(sessions, func(): return sa.is_ready() and sb.is_ready()), "both sessions joined")
	check(sa.is_online(), "is_online")
	eq(replaced[0], 1, "state_replaced once on join")
	eq(sa.state.player_id, a_id, "A's view: player_id is A")
	eq(sb.state.player_id, b_id, "B's view: player_id is B (not the server's player 1)")
	check(sa.state is MatchState, "a real MatchState the UI can read")
	var inst_before: int = sa.state.get_instance_id()
	# a command: pending ack, verdict later, events delivered AFTER the state already contains the result
	var hx: Vector2i = _plant_hex(st.actors[a_id])
	var planted_in_view := [false]
	var got_events := [0]
	sa.events_emitted.connect(func(evs: Array):
		for e in evs:
			if e["type"] == &"crop_planted":
				got_events[0] += 1
				planted_in_view[0] = sa.state.plots.has(MatchState.plot_key(hx)))
	var resolved := []
	sa.command_resolved.connect(func(seq: int, r: Dictionary): resolved.append([seq, r]))
	var r: Dictionary = sa.command(&"plant", {"crop": "lfg:crop/glowfruit", "hex": hx})
	eq(r.get("pending", false), true, "online submit is pending")
	check(_spin_until(sessions, func(): return got_events[0] > 0 and resolved.size() > 0), "verdict + events arrived")
	check(resolved[0][1]["ok"], "accepted")
	eq(planted_in_view[0], true, "events are delivered together with the state that contains their result")
	check(sb.state.plots.has(MatchState.plot_key(hx)) or _spin_until(sessions, func(): return sb.state.plots.has(MatchState.plot_key(hx))), "B sees A's crop")
	eq(sa.state.get_instance_id(), inst_before, "state object identity stable (updated in place)")
	# rejection path
	var failed := []
	sa.command_failed.connect(func(seq: int, e: String): failed.append(e))
	sa.command(&"harvest", {"hex": hx})
	check(_spin_until(sessions, func(): return failed.size() > 0), "rejection reported")
	eq(failed[0], "not_ready", "reason from the real rules")
	# filtered: B's coin is hidden from A's copy, own inventory present
	st.actors[b_id]["inv"]["lfg:item/coin"] = 515151
	server._broadcast_snapshot()
	_spin(sessions, 60)
	eq(int(sb.state.actors[b_id]["inv"].get("lfg:item/coin", 0)), 515151, "B sees own coin")
	eq(sa.state.actors[b_id]["inv"].size(), 0, "A cannot see B's inventory")
	eq(sa.snapshot().get("rng_state"), 0, "rng hidden")
	sa.close()
	sb.close()

func test_local_and_online_sessions_play_the_same_game() -> void:
	boot(60.0, {}, 1234, false)
	var local := LocalSession.new_game(1234, &"lfg:class/judd", -1, {"ai_enabled": false, "wild_enemies": false, "day_seconds": 60.0})
	var on := _online(0)
	var sessions: Array = [on]
	check(_spin_until(sessions, func(): return on.is_ready()), "joined")
	eq(local.actor_id, on.actor_id, "same actor")
	var hx: Vector2i = _plant_hex(st.actors[a_id])
	var stream: Array = [
		[&"plant", {"crop": "lfg:crop/glowfruit", "hex": hx}],
		[&"water", {"hex": hx}],
		[&"eat", {"item": "lfg:item/ration"}],
		[&"harvest", {"hex": hx}],                      # rejected: not ready (both)
		[&"plant", {"crop": "lfg:crop/glowfruit", "hex": hx}]]   # rejected: occupied (both)
	var local_res: Array = []
	var online_res: Array = []
	var seqs: Array = []
	for c in stream:
		local_res.append(local.command(c[0], c[1]))
		seqs.append(on.command(c[0], c[1])["seq"])
		_spin(sessions, 12)           # give the move/seq throttles nothing to fight; one command per ~12 spins
	var resolved := {}
	on.command_resolved.connect(func(seq, r): resolved[seq] = r)
	check(_spin_until(sessions, func(): return on.client.results.size() >= stream.size()), "all answered")
	for i in stream.size():
		var o: Dictionary = on.client.results[seqs[i]]
		eq(o["ok"], local_res[i]["ok"], "cmd %d verdict equal (local %s / online %s)" % [i, local_res[i]["error"], o["error"]])
		eq(o["error"], local_res[i]["error"], "cmd %d same error" % i)
	_spin(sessions, 60)
	server._broadcast_snapshot()
	_spin(sessions, 60)
	eq(on.state.plots.keys(), local.state.plots.keys(), "same plots")
	var norm := func(d: Dictionary) -> Dictionary:
		var o := {}
		for k in d:
			o[k] = int(d[k])      # Rules' start kit holds floats (JSON); snapshots hold ints: same quantities
		return o
	eq(norm.call(on.state.actors[a_id]["inv"]), norm.call(local.state.actors[a_id]["inv"]), "same inventory")
	on.close()

func test_online_session_reconnects_and_ends_on_fatal_reasons() -> void:
	boot(60.0, {}, 1234, false)
	var sa := _online(0)
	var sessions: Array = [sa]
	check(_spin_until(sessions, func(): return sa.is_ready()), "joined")
	var lost := []
	sa.connection_lost.connect(func(r: String): lost.append(r))
	var inst: int = sa.state.get_instance_id()
	# transient drop (server closes the socket with a non-fatal reason)
	var peer: ENetPacketPeer = null
	for p in server._peers:
		peer = p
	server._kick(peer, "maintenance")
	check(_spin_until(sessions, func(): return lost.size() > 0), "drop noticed")
	check(not sa.ended, "non-fatal reason: session stays alive")
	var joined := [0]
	sa.joined.connect(func(_a): joined[0] += 1)
	for _i in 200:
		_spin(sessions, 5)
		sa._process(0.1)
		if joined[0] > 0:
			break
	check(joined[0] > 0, "auto-reconnected with the same token")
	eq(sa.state.get_instance_id(), inst, "same state object after reconnect")
	var r: Dictionary = sa.command(&"eat", {"item": "lfg:item/ration"})
	check(r.get("pending", false), "commands flow again")
	# fatal: token expires
	var short: String = server.issue_token(b_id, 5.0)
	var sb := OnlineSession.join("127.0.0.1", port, short)
	sessions.append(sb)
	check(_spin_until(sessions, func(): return sb.is_ready()), "B joined on a short token")
	server.advance(6.0)
	var ended := []
	sb.session_ended.connect(func(why: String): ended.append(why))
	check(_spin_until(sessions, func(): return ended.size() > 0), "session ended")
	eq(ended[0], "disconnected:token_expired", "fatal reason is reported, no reconnect loop")
	eq(sb.command(&"eat").get("error", ""), "session_ended", "no commands after the end")
	sa.close()
