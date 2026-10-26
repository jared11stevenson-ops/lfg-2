extends "res://tests/net/real_fixture.gd"
## Anti-abuse + per-viewer filtering against the REAL Rules/MatchState over real sockets.

func _far_walkable(from: Vector2i, dist: int) -> Vector2i:
	for h in HexGrid.ring_within(from, dist):
		if HexGrid.distance(from, h) == dist and WorldGen.move_cost(st.world, h) > 0.0:
			return h
	return from

# ------------------------------------------------------------ filtering
func test_snapshot_hides_other_factions_inventory_and_rng() -> void:
	boot()
	st.actors[b_id]["inv"]["lfg:item/coin"] = 424242
	var rival_home: Dictionary = st.holdings[st.factions[1]["home"]]
	rival_home["store"]["lfg:item/timber"] = 313131
	server._broadcast_snapshot()
	until(func(): return str(clients[0].snapshot).find("313131") == -1 and clients[0].server_clock > 0.0, 50)
	pump(30)
	var sa: Dictionary = clients[0].snapshot
	var sb: Dictionary = clients[1].snapshot
	check(str(sa).find("424242") == -1, "A never receives B's coin total")
	check(str(sa).find("313131") == -1, "A never receives B's home store")
	check(str(sb).find("424242") != -1, "B sees its own coin")
	check(str(sb).find("313131") != -1, "B sees its own holding store")
	eq(sa["rng_state"], 0, "rng_state hidden (cannot predict capture/steal rolls)")
	check(not sa["actors"][str(a_id)]["inv"].is_empty(), "own inventory visible to self")
	var bs: Dictionary = sa["actors"][str(b_id)]
	eq(bs.get("fogged", false), true, "far rival leader is a fogged stub")
	eq(bs["inv"], {}, "stub has no inventory")
	var rh: Dictionary = sa["holdings"][str(rival_home["id"])]
	eq(rh["store"], {}, "rival store hidden")
	eq(rh["store_hidden"], true, "flagged hidden")
	eq(rh["owner"], 1, "ownership is public")
	# merchants' stock is a public market
	var merchant: Dictionary = {}
	for h in st.holdings.values():
		if int(h["owner"]) == -1:
			merchant = h
			break
	check(not sa["holdings"][str(merchant["id"])]["store"].is_empty(), "merchant stock visible")
	# the filter hid nothing about own faction and left the input untouched
	var full: Dictionary = st.to_dict()
	var f2: Dictionary = SnapshotFilter.for_actor(full, a_id)
	eq(full["actors"][str(b_id)]["inv"]["lfg:item/coin"], 424242, "filter copied, input not mutated")
	check(f2 != full, "filtered differs")

func test_vision_reveals_nearby_rival_without_inventory() -> void:
	boot()
	st.actors[b_id]["inv"]["lfg:item/coin"] = 777777
	st.actors[b_id]["hex"] = st.actors[a_id]["hex"] + Vector2i(2, 0)
	server.audit_forget()
	var snap: Dictionary = SnapshotFilter.for_actor(st.to_dict(), a_id)
	var bs: Dictionary = snap["actors"][str(b_id)]
	check(not bs.has("fogged"), "adjacent rival is visible")
	eq(bs["hex"], {"_v": [st.actors[b_id]["hex"].x, st.actors[b_id]["hex"].y]}, "real position")
	eq(bs["inv"], {}, "but inventory still hidden")
	eq(bs["hp"], st.actors[b_id]["hp"], "hp visible in sight (combat readable)")
	check(str(snap).find("777777") == -1, "no leak anywhere")
	# distance agrees with the rules' own hex math
	for i in 50:
		var p := Vector2i(randi() % 40 - 20, randi() % 40 - 20)
		var q := Vector2i(randi() % 40 - 20, randi() % 40 - 20)
		eq(SnapshotFilter.hex_distance(p, q), HexGrid.distance(p, q), "hex distance matches HexGrid")

func test_events_from_other_factions_lose_item_payloads() -> void:
	boot()
	var evs: Array = [
		{"type": &"crop_harvested", "actor": b_id, "hex": Vector2i(1, 1), "items": {"lfg:item/glowfruit": 3}},
		{"type": &"crop_harvested", "actor": a_id, "hex": Vector2i(1, 2), "items": {"lfg:item/glowfruit": 3}},
		{"type": &"holding_captured", "holding": 5, "by": 1, "loot": {"lfg:item/coin": 9}}]
	var out: Array = SnapshotFilter.events_for(evs, 0, st.actors)
	check(not out[0].has("items"), "rival's yield stripped")
	check(out[1].has("items"), "own yield kept")
	check(not out[2].has("loot"), "rival's loot stripped")
	check(evs[0].has("items"), "input untouched")

# ------------------------------------------------------------ tokens
func test_tokens_are_128_bit_random_unique_and_hashed() -> void:
	boot(60.0, {}, 1234, false)
	var seen: Dictionary = {}
	for i in 500:
		var t: String = server.issue_token(a_id)
		check(NetServer.token_shape_ok(t), "32 lowercase hex chars (128 bits)")
		seen[t] = true
		check(not server._sessions.has(t), "plaintext token is not a session key")
	eq(seen.size(), 500, "no duplicates in 500 draws")
	check(not NetServer.token_shape_ok("abc"), "short token rejected by shape")
	check(not NetServer.token_shape_ok("G".repeat(32)), "non-hex rejected")
	var bits := 0
	for t in seen.keys():
		for c in (t as String):
			bits += "0123456789abcdef".find(c)
	var mean: float = float(bits) / (500.0 * 32.0)
	check(mean > 6.5 and mean < 8.5, "hex digit mean looks uniform (%.2f ~ 7.5)" % mean)

func test_token_expiry_blocks_hello_and_kicks_live_session() -> void:
	boot(60.0, {}, 1234, false)
	var short: String = server.issue_token(a_id, 10.0)
	var c := connect_client(0, short)
	check(until(func(): return c.is_ready), "welcomed before expiry")
	server.advance(5.0)
	pump(10)
	check(c.is_ready, "still valid at 5s")
	server.advance(6.0)
	check(until(func(): return not c.is_ready), "kicked after expiry")
	eq(c.last_bye, "token_expired", "reason reported")
	var c2 := connect_client(0, short)
	until(func(): return c2.last_bye != "")
	eq(c2.last_bye, "token_expired", "expired token cannot re-auth")
	check(not c2.is_ready, "not welcomed")
	var renewed: String = server.issue_token(a_id, 10.0)
	server.advance(8.0)
	check(server.renew_token(renewed, 100.0), "renewed")
	server.advance(50.0)
	var c3 := connect_client(0, renewed)
	check(until(func(): return c3.is_ready), "renewed token still works")

func test_bad_token_flood_locks_out_address() -> void:
	boot(60.0, {}, 1234, false)
	server.max_addr_fails = 4
	for i in 4:
		var bad := connect_client(0, "0".repeat(32))
		until(func(): return bad.last_bye != "", 100)
	var good := connect_client(0, tokens[0])
	pump(80)
	check(not good.is_ready, "address locked out: even a valid token is refused during the window")
	server.advance(61.0)
	var later := connect_client(0, tokens[0])
	check(until(func(): return later.is_ready), "lockout lapses after the window")

# ------------------------------------------------------------ disconnect during purge
func test_disconnect_during_purge_stays_vulnerable_and_locked() -> void:
	boot(600.0)
	server.purge_disconnect_lock = 90.0
	to_phase(&"PURGE_ACTIVE")
	# put B next to A (server-side setup) and give A a queued walk it must not complete
	st.actors[b_id]["hex"] = st.actors[a_id]["hex"] + Vector2i(1, 0)
	server.audit_forget()
	var far: Vector2i = _far_walkable(st.actors[a_id]["hex"], 8)
	var r: Dictionary = cmd(0, &"move_intent", {"to": far})
	check(r.get("ok", false), "A starts walking away (%s)" % r.get("error", ""))
	check(not (st.actors[a_id]["move"] as Dictionary).is_empty(), "path queued")
	var hp0: int = int(st.actors[a_id]["hp"])
	var pos0: Vector2i = st.actors[a_id]["hex"]
	clients[0].disconnect_now()
	check(until(func(): return not server.is_connected_actor(a_id)), "server saw the disconnect")
	check((st.actors[a_id]["move"] as Dictionary).is_empty(), "queued path cleared: idle, no running to safety")
	eq(st.actors[a_id]["hex"], pos0, "stays where it was")
	check(st.actors[a_id]["alive"], "actor still in the world")
	# B can hit the offline actor: no free escape
	var hit: Dictionary = cmd(1, &"attack", {"target": a_id})
	check(hit.get("ok", false), "offline actor is attackable (%s)" % hit.get("error", ""))
	check(int(st.actors[a_id]["hp"]) < hp0, "damage applied to the offline actor")
	# immediate reconnect: allowed, but commands are locked
	var c: NetClient = connect_client(0)
	check(until(func(): return c.is_ready), "reconnect allowed")
	clients[0] = c
	var res: Dictionary = cmd(0, &"move_intent", {"to": far})
	eq(res.get("error", ""), "purge_disconnect_lock", "no free escape by reconnecting")
	check(float(res.get("locked_for", 0.0)) > 60.0, "lock time reported (%s)" % str(res.get("locked_for")))
	server.advance(30.0)
	pump(10)
	eq(cmd(0, &"move_intent", {"to": far}).get("error", ""), "purge_disconnect_lock", "still locked at +30s")
	server.advance(65.0)
	pump(10)
	check(st.phase == &"PURGE_ACTIVE", "purge still running (long day)")
	var ok: Dictionary = cmd(0, &"move_intent", {"to": far})
	check(ok.get("ok", false), "lock expires after N seconds (%s)" % ok.get("error", ""))

func test_purge_end_lifts_lock_and_peace_disconnect_has_no_lock() -> void:
	boot(60.0)
	# peace disconnect: no lock
	clients[1].disconnect_now()
	until(func(): return not server.is_connected_actor(b_id))
	var c: NetClient = connect_client(1)
	until(func(): return c.is_ready)
	clients[1] = c
	var far: Vector2i = _far_walkable(st.actors[b_id]["hex"], 3)
	check(cmd(1, &"move_intent", {"to": far}).get("ok", false), "no lock when disconnecting in peace")
	# purge disconnect, then the purge ends -> lock lifted early
	server.purge_disconnect_lock = 100000.0
	to_phase(&"PURGE_ACTIVE")
	clients[0].disconnect_now()
	until(func(): return not server.is_connected_actor(a_id))
	var a2: NetClient = connect_client(0)
	until(func(): return a2.is_ready)
	clients[0] = a2
	eq(cmd(0, &"set_policy", {"key": "ration", "value": "half"}).get("error", ""), "purge_disconnect_lock", "locked inside the purge")
	to_phase(&"RESOLUTION")
	check(st.phase != &"PURGE_ACTIVE", "purge over")
	check(cmd(0, &"set_policy", {"key": "ration", "value": "half"}).get("ok", false), "lock lifted when the purge ends")

# ------------------------------------------------------------ movement
func test_move_rate_limit_and_legal_walk_not_flagged() -> void:
	boot()
	var far: Vector2i = _far_walkable(st.actors[a_id]["hex"], 6)
	var s1: int = clients[0].submit(&"move_intent", {"to": far})
	var s2: int = clients[0].submit(&"move_intent", {"to": far})
	until(func(): return clients[0].results.has(s1) and clients[0].results.has(s2))
	check(clients[0].results[s1].get("ok", false), "first move accepted")
	eq(clients[0].results[s2]["error"], "move_rate", "move_intent spam throttled")
	for _i in 120:
		server.advance(1.0)
		pump(1)
	eq(server.audit_log.size(), 0, "legal walking is never flagged")
	check(HexGrid.distance(st.actors[a_id]["hex"], far) < 6 or st.actors[a_id]["hex"] == far, "actually walked")

func test_teleport_is_reverted_by_audit() -> void:
	boot()
	server.advance(2.0)
	var home: Vector2i = st.actors[a_id]["hex"]
	st.actors[a_id]["hex"] = home + Vector2i(30, 0)       # simulated memory edit / rules bug
	server.advance(1.0)
	eq(st.actors[a_id]["hex"], home, "teleport reverted to last audited hex")
	check(server.audit_log.size() == 1, "logged: %s" % str(server.audit_log))
	# a modest legal-looking jump after banking idle time (<= rules' sync bank) is tolerated
	server.advance(10.0)
	var near: Vector2i = home + Vector2i(1, 0)
	st.actors[a_id]["hex"] = near
	server.advance(1.0)
	eq(st.actors[a_id]["hex"], near, "1-hex step accepted")
	eq(server.audit_log.size(), 1, "no new violation")
