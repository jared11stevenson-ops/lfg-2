class_name NetServer
extends RefCounted
## Headless authoritative server over ENet. Holds the one real MatchState and applies the SAME
## Rules.apply / Rules.tick as local play. Clients never send state, time or events; only commands.
##
## What this is NOT: no accounts, no TLS/DTLS, no matchmaking, no hosting, no persistence of sessions
## across server restarts. Tokens are issued by whoever runs the server (issue_token) and travel in
## clear over ENet. Treat as LAN/dev scaffolding, not production auth.
const ALLOWED_TYPES: Array[StringName] = [&"move_intent", &"plant", &"water", &"harvest", &"craft", &"build", &"demolish",
	&"trade", &"eat", &"attack", &"use_ability", &"capture", &"steal", &"set_policy", &"rest"]
const MAX_TICK_STEP := 1.0
const RESULT_CACHE := 64
const MAX_SEQ_JUMP := 1000
const HELLO_TIMEOUT := 5.0
const MAX_HELLO_FAILS := 3
const MAX_VIOLATIONS := 50
const TOKEN_BYTES := 16                # 128-bit tokens from the OS CSPRNG (Crypto), stored only as sha256
const ADDR_WINDOW := 60.0

var rules: Script
var state: Object
var host: ENetConnection
var port: int = 0
var clock: float = 0.0                 # server clock (seconds); the ONLY time source for gating
var bucket_capacity: float = 20.0
var bucket_refill_per_s: float = 10.0
var snapshot_interval: float = 5.0
var persist_slot: int = -1              # >=0: autosave + permadeath tombstone through Persist
var autosave_interval: float = 30.0
var match_over: bool = false
var log: Array[String] = []
# --- hardening / anti-abuse (all times are SERVER-clock seconds)
var token_ttl: float = 6.0 * 3600.0        # default lifetime of an issued token (<=0: never expires)
var max_addr_fails: int = 12               # failed hellos per address per ADDR_WINDOW before that address is refused
var purge_disconnect_lock: float = 90.0    # see _mark_disconnect()
var filter_snapshots: bool = true          # per-viewer fog/inventory filtering (SnapshotFilter)
var vision_radius: int = 8
var move_min_interval: float = 0.15        # min spacing of move_intent per session
var audit_enabled: bool = true             # movement-speed audit of session actors
var audit_slack: int = 1                   # extra hexes tolerated per audit window (path accumulator carry)
var audit_log: Array[String] = []
var audit_exempt_events: Array[StringName] = [&"actor_teleported", &"actor_dashed"]
var frozen: bool = false                   # stop advancing game time (tests / maintenance); polling continues

var _sessions: Dictionary = {}          # sha256(token) -> session dict
var _peers: Dictionary = {}             # ENetPacketPeer -> {key:String, since:float, fails:int}
var _last_snapshot_at: float = 0.0
var _last_save_at: float = 0.0
var _dirty: bool = false
var _addr_fails: Dictionary = {}          # address -> {n:int, since:float}
var _audit: Dictionary = {}               # actor -> {hex:Variant, clock:float}
var _walk_sec_per_hex: float = 0.0
var _min_move_cost: float = 1.0
var _bank_cap: float = 0.0
var _allowed_cache: Array = []

func start(p_port: int, p_state: Object, p_rules: Script = null, bind: String = "127.0.0.1", max_clients: int = 16) -> int:
	state = p_state
	rules = p_rules if p_rules != null else ClassLink.rules()
	if rules == null or state == null:
		return ERR_UNCONFIGURED
	host = ENetConnection.new()
	var err: int = host.create_host_bound(bind, p_port, max_clients, 1)
	if err != OK:
		host = null
		return err
	port = p_port
	_init_audit()
	return OK

func _init_audit() -> void:
	_walk_sec_per_hex = 0.0
	var sim: Script = ClassLink.script_for("Sim")
	var wg: Script = ClassLink.script_for("WorldGen")
	var hg: Script = ClassLink.script_for("HexGrid")
	var w: Variant = state.get("world")
	if sim == null or wg == null or hg == null or not (w is Dictionary) or (w as Dictionary).is_empty():
		return
	var consts: Dictionary = sim.get_script_constant_map()
	if not consts.has("WALK_SEC_PER_HEX"):
		return
	_walk_sec_per_hex = float(consts["WALK_SEC_PER_HEX"])
	var best: float = 99.0
	var n: int = int(hg.get_script_constant_map().get("WIDTH", 84)) * int(hg.get_script_constant_map().get("HEIGHT", 54))
	for i in n:
		var c: float = float(wg.call("move_cost", w, hg.call("from_index", i)))
		if c > 0.0 and c < best:
			best = c
	_min_move_cost = best if best < 99.0 else 1.0
	var mv: Script = ClassLink.script_for("Movement")
	_bank_cap = 0.0
	if mv != null:
		var mc: Dictionary = mv.get_script_constant_map()
		_bank_cap = float(mc.get("SYNC_MAX_BANK", 0.0)) + float(mc.get("SYNC_SLACK", 0.0))

func stop() -> void:
	if host != null:
		for p in _peers.keys():
			(p as ENetPacketPeer).peer_disconnect_now(0)
		host.flush()
		host.destroy()
		host = null
	_peers.clear()

## Out-of-band invite: returns a secret 128-bit random token bound to `actor`, valid for `ttl` server-seconds
## (default `token_ttl`; ttl<=0 with token_ttl<=0 means no expiry). Only sha256(token) is kept server-side.
func issue_token(actor: int, ttl: float = -1.0) -> String:
	var tok: String = Crypto.new().generate_random_bytes(TOKEN_BYTES).hex_encode()
	var life: float = ttl if ttl > 0.0 else token_ttl
	_sessions[tok.sha256_text()] = {"actor": actor, "peer": null, "last_seq": 0, "results": {}, "order": [],
		"tokens": float(bucket_capacity), "violations": 0, "expires": (clock + life) if life > 0.0 else -1.0,
		"lock_until": -1.0, "last_move_at": -100.0}
	return tok

## Extend a live token (server-side decision, e.g. on an authenticated heartbeat from the host app).
func renew_token(tok: String, ttl: float = -1.0) -> bool:
	var s: Variant = _sessions.get(tok.sha256_text())
	if s == null:
		return false
	var life: float = ttl if ttl > 0.0 else token_ttl
	s["expires"] = (clock + life) if life > 0.0 else -1.0
	return true

func _expired(s: Dictionary) -> bool:
	return float(s["expires"]) >= 0.0 and clock >= float(s["expires"])

static func token_shape_ok(tok: Variant) -> bool:
	if not (tok is String) or (tok as String).length() != TOKEN_BYTES * 2:
		return false
	for c in (tok as String):
		if not "0123456789abcdef".contains(c):
			return false
	return true

func revoke_token(tok: String) -> void:
	var s: Variant = _sessions.get(tok.sha256_text())
	if s != null and s["peer"] != null:
		_kick(s["peer"], "revoked")
	_sessions.erase(tok.sha256_text())

func is_connected_actor(actor: int) -> bool:
	for s in _sessions.values():
		if s["actor"] == actor and s["peer"] != null:
			return true
	return false

func session_for_token(tok: String) -> Dictionary:
	return _sessions.get(tok.sha256_text(), {})

# ------------------------------------------------------------------ loop
func poll() -> void:
	if host == null:
		return
	for _i in 256:
		var ev: Array = host.service(0)
		var t: int = ev[0]
		if t == ENetConnection.EVENT_NONE:
			break
		var peer: ENetPacketPeer = ev[1]
		match t:
			ENetConnection.EVENT_CONNECT:
				var ip: String = peer.get_remote_address()
				if _addr_locked(ip):
					peer.peer_disconnect_now(0)
					continue
				_peers[peer] = {"key": "", "since": clock, "fails": 0, "ip": ip}
			ENetConnection.EVENT_DISCONNECT:
				_on_disconnect(peer)
			ENetConnection.EVENT_RECEIVE:
				_on_packet(peer, peer.get_packet())
			ENetConnection.EVENT_ERROR:
				_on_disconnect(peer)

## Advance the authoritative simulation. This is the only thing that moves game time.
func advance(dt: float) -> Array:
	if dt <= 0.0:
		return []
	if frozen:
		poll()
		return []
	clock += dt
	for s in _sessions.values():
		s["tokens"] = minf(bucket_capacity, s["tokens"] + bucket_refill_per_s * dt)
	var events: Array = []
	var left: float = dt
	while left > 0.0 and not match_over:
		var step: float = minf(left, MAX_TICK_STEP)   # big jumps are fed to Rules in bounded steps
		left -= step
		var ev: Array = rules.call("tick", state, step)
		if ev.size() > 0:
			events.append_array(ev)
			_dirty = true
			_after_events(ev)
	if events.size() > 0:
		_broadcast_events(events, {})
	_expire_sessions()
	if audit_enabled:
		_audit_movement(events)
	for p in _peers.keys():
		var meta: Dictionary = _peers[p]
		if meta["key"] == "" and clock - meta["since"] > HELLO_TIMEOUT:
			_kick(p, "hello_timeout")
	if _dirty and clock - _last_snapshot_at >= snapshot_interval:
		_broadcast_snapshot()
	if persist_slot >= 0 and not match_over and clock - _last_save_at >= autosave_interval:
		Persist.save_match(persist_slot, state)
		_last_save_at = clock
	for a in _addr_fails.keys():
		if clock - float(_addr_fails[a]["since"]) > ADDR_WINDOW:
			_addr_fails.erase(a)
	poll()
	return events

## Call after a deliberate out-of-band edit of actor positions (tests, admin tools) so the audit does not revert it.
func audit_forget() -> void:
	_audit.clear()

func _expire_sessions() -> void:
	for key in _sessions.keys():
		var s: Dictionary = _sessions[key]
		if not _expired(s):
			continue
		if s["peer"] != null:
			_kick(s["peer"], "token_expired")      # session record stays so the reason stays "token_expired"

## Movement audit (independent of Rules' own validation). Budget model: every session actor earns 1 budget-second per
## server second (capped at `_bank_cap`, mirroring Rules' banked-time allowance for position sync) and each hex it
## ends up displaced costs WALK_SEC_PER_HEX * cheapest terrain cost * the actor's fastest class multiplier. If the
## displacement since the last audit costs more than budget + `audit_slack` hexes, the move is reverted, logged in
## `audit_log`, and nothing else changes. It deliberately uses the CHEAPEST legal cost, so it never false-positives
## on legal play; it only catches teleports / speed hacks / rules bugs that Rules' own checks missed.
func _audit_movement(events: Array) -> void:
	if _walk_sec_per_hex <= 0.0:
		return
	var hg: Script = ClassLink.script_for("HexGrid")
	var acts: Variant = state.get("actors")
	if hg == null or not (acts is Dictionary):
		return
	for e in events:
		if e is Dictionary and audit_exempt_events.has(e.get("type", &"")) and _audit.has(int(e.get("actor", -1))):
			_audit.erase(int(e["actor"]))
	var cb: Script = ClassLink.script_for("Combat")
	for s in _sessions.values():
		var aid: int = int(s["actor"])
		if not (acts as Dictionary).has(aid):
			continue
		var a: Dictionary = acts[aid]
		if not (a.get("hex") is Vector2i) or not a.get("alive", true):
			continue
		if not _audit.has(aid):
			_audit[aid] = {"hex": a["hex"], "clock": clock, "budget": 0.0}
			continue
		var w: Dictionary = _audit[aid]
		w["budget"] = minf(_bank_cap, float(w["budget"]) + (clock - float(w["clock"])))
		w["clock"] = clock
		var moved: int = int(hg.call("distance", w["hex"], a["hex"]))
		if moved > 0:
			var mult: float = 1.0
			if cb != null:
				mult = minf(1.0, float(cb.call("class_mod", a, "walk_mult", 1.0))) * minf(1.0, float(cb.call("class_mod", a, "road_mult", 1.0)))
			var per_hex: float = _walk_sec_per_hex * _min_move_cost * mult
			var need: float = float(moved) * per_hex
			if need > float(w["budget"]) + per_hex * float(audit_slack) + 1e-6:
				var msg := "speed actor=%d moved=%d hexes cost=%.1fs budget=%.1fs" % [aid, moved, need, w["budget"]]
				audit_log.append(msg)
				log.append(msg)
				a["hex"] = w["hex"]
				a["move"] = {}
				_dirty = true
			else:
				w["budget"] = maxf(0.0, float(w["budget"]) - need)
				w["hex"] = a["hex"]

# ------------------------------------------------------------------ internals
func _send(peer: ENetPacketPeer, msg: Dictionary) -> void:
	peer.send(NetCodec.CHANNEL, NetCodec.encode(msg), ENetPacketPeer.FLAG_RELIABLE)

func _broadcast(msg: Dictionary) -> void:
	for p in _peers.keys():
		if _peers[p]["key"] != "":
			_send(p, msg)

func _snapshot_for(actor: int) -> Dictionary:
	var d: Dictionary = state.call("to_dict")
	return SnapshotFilter.for_actor(d, actor, vision_radius) if filter_snapshots else d

func _send_snapshot(peer: ENetPacketPeer, s: Dictionary) -> void:
	_send(peer, {"t": "snapshot", "state": _snapshot_for(int(s["actor"])), "clock": clock})

func _broadcast_snapshot() -> void:
	_last_snapshot_at = clock
	_dirty = false
	for p in _peers.keys():
		var key: String = _peers[p]["key"]
		if key != "" and _sessions.has(key):
			_send_snapshot(p, _sessions[key])

func _broadcast_events(events: Array, extra: Dictionary) -> void:
	var acts: Variant = state.get("actors")
	for p in _peers.keys():
		var key: String = _peers[p]["key"]
		if key == "" or not _sessions.has(key):
			continue
		var evs: Array = events
		if filter_snapshots and acts is Dictionary:
			var aid: int = int(_sessions[key]["actor"])
			if (acts as Dictionary).has(aid):
				evs = SnapshotFilter.events_for(events, int(acts[aid].get("faction", -99)), acts)
		var m := {"t": "events", "events": evs}
		m.merge(extra)
		_send(p, m)

func _kick(peer: ENetPacketPeer, reason: String) -> void:
	_send(peer, {"t": "bye", "reason": reason})
	peer.peer_disconnect_later(0)
	_on_disconnect(peer)

func _on_disconnect(peer: ENetPacketPeer) -> void:
	var meta: Variant = _peers.get(peer)
	if meta == null:
		return
	if meta["key"] != "" and _sessions.has(meta["key"]) and _sessions[meta["key"]]["peer"] == peer:
		_sessions[meta["key"]]["peer"] = null
		_mark_disconnect(_sessions[meta["key"]])
	_peers.erase(peer)

## DISCONNECT-DURING-PURGE POLICY. If a seated player's connection ends while the phase is PURGE_ACTIVE:
##  1. the actor is NOT removed, hidden or protected: it stays in the world as an ordinary attackable unit;
##  2. its queued path is cleared, so it stands idle where it was (no running to safety after pulling the plug);
##  3. for `purge_disconnect_lock` server-seconds (or until the Purge ends, whichever is first) the session accepts
##     NO commands, even after an immediate reconnect ("purge_disconnect_lock"). Reconnecting is allowed, escaping is not.
## A rejected-by-lock command does not consume its seq. A Purge ending (phase change) lifts the lock early.
func _mark_disconnect(s: Dictionary) -> void:
	if match_over or purge_disconnect_lock <= 0.0 or state.get("phase") != &"PURGE_ACTIVE":
		return
	s["lock_until"] = clock + purge_disconnect_lock
	var acts: Variant = state.get("actors")
	if acts is Dictionary and (acts as Dictionary).has(int(s["actor"])):
		(acts[int(s["actor"])] as Dictionary)["move"] = {}
	_dirty = true
	log.append("purge_disconnect actor=%d lock_until=%.1f" % [int(s["actor"]), s["lock_until"]])

func lock_remaining(s: Dictionary) -> float:
	if float(s["lock_until"]) <= clock or state.get("phase") != &"PURGE_ACTIVE":
		return 0.0
	return float(s["lock_until"]) - clock

func _addr_locked(ip: String) -> bool:
	var e: Variant = _addr_fails.get(ip)
	return e != null and int(e["n"]) >= max_addr_fails and clock - float(e["since"]) <= ADDR_WINDOW

func _addr_fail(peer: ENetPacketPeer) -> void:
	var ip: String = String(_peers[peer].get("ip", ""))
	var e: Dictionary = _addr_fails.get(ip, {"n": 0, "since": clock})
	if clock - float(e["since"]) > ADDR_WINDOW:
		e = {"n": 0, "since": clock}
	e["n"] = int(e["n"]) + 1
	_addr_fails[ip] = e

func _on_packet(peer: ENetPacketPeer, bytes: PackedByteArray) -> void:
	if not _peers.has(peer):
		return
	if bytes.size() > NetCodec.MAX_PACKET:
		_kick(peer, "oversize")
		return
	var msg: Dictionary = NetCodec.decode(bytes)
	if msg.is_empty():
		_peers[peer]["fails"] += 1
		if _peers[peer]["fails"] >= MAX_HELLO_FAILS:
			_kick(peer, "malformed")
		return
	var meta: Dictionary = _peers[peer]
	var t: String = msg["t"]
	if t == "hello":
		_on_hello(peer, meta, msg)
		return
	if meta["key"] == "":
		_send(peer, {"t": "reject", "reason": "unauthenticated"})
		meta["fails"] += 1
		if meta["fails"] >= MAX_HELLO_FAILS:
			_kick(peer, "unauthenticated")
		return
	var s: Dictionary = _sessions[meta["key"]]
	match t:
		"cmd":
			_on_cmd(peer, s, msg)
		"snap":
			if _take(s):
				_send_snapshot(peer, s)
		"ping":
			_send(peer, {"t": "pong", "clock": clock})

func _on_hello(peer: ENetPacketPeer, meta: Dictionary, msg: Dictionary) -> void:
	var tok: Variant = msg.get("token")
	var key: String = (tok as String).sha256_text() if token_shape_ok(tok) else ""
	if key == "" or not _sessions.has(key):
		meta["fails"] += 1
		_addr_fail(peer)
		_send(peer, {"t": "reject", "reason": "bad_token"})
		if meta["fails"] >= MAX_HELLO_FAILS or _addr_locked(String(meta.get("ip", ""))):
			_kick(peer, "bad_token")
		return
	var s: Dictionary = _sessions[key]
	if _expired(s):
		_send(peer, {"t": "reject", "reason": "token_expired"})
		_kick(peer, "token_expired")
		return
	var old: Variant = s["peer"]
	if old != null and old != peer:
		_kick(old, "replaced")           # reconnect from a new socket wins; old binding is dropped
	meta["key"] = key
	s["peer"] = peer
	# After a server restart the session is fresh but the state remembers the actor's last applied seq.
	var acts: Variant = state.get("actors")
	if acts is Dictionary and (acts as Dictionary).has(s["actor"]) and (acts[s["actor"]] as Dictionary).has("last_seq"):
		s["last_seq"] = maxi(int(s["last_seq"]), int(acts[s["actor"]]["last_seq"]))
	_send(peer, {"t": "welcome", "actor": s["actor"], "last_seq": s["last_seq"], "clock": clock,
		"state": _snapshot_for(int(s["actor"])), "match_over": match_over, "locked_for": lock_remaining(s)})

## token bucket on the server clock; every command packet (including duplicates) costs 1
func _take(s: Dictionary) -> bool:
	if s["tokens"] >= 1.0:
		s["tokens"] -= 1.0
		return true
	s["violations"] += 1
	if s["violations"] >= MAX_VIOLATIONS and s["peer"] != null:
		_kick(s["peer"], "rate_limit_abuse")
	return false

func _on_cmd(peer: ENetPacketPeer, s: Dictionary, msg: Dictionary) -> void:
	var raw: Variant = msg.get("cmd")
	var seq: int = -1
	if raw is Dictionary and (raw as Dictionary).get("seq") is int:
		seq = raw["seq"]
	if not _take(s):
		_send(peer, {"t": "result", "seq": seq, "ok": false, "error": "rate_limited", "retry": true})
		return
	var v: Dictionary = validate_cmd(raw, s["actor"], _allowed())
	if not v["ok"]:
		_send(peer, {"t": "result", "seq": seq, "ok": false, "error": v["error"]})
		return
	var cmd: Dictionary = v["cmd"]
	seq = cmd["seq"]
	var lock: float = lock_remaining(s)
	if lock > 0.0:
		_send(peer, {"t": "result", "seq": seq, "ok": false, "error": "purge_disconnect_lock", "locked_for": lock})
		return
	var tname: String = String(cmd["type"])
	if (tname.begins_with("move") or tname.contains("sync")) and not (cmd["args"] as Dictionary).get("stop", false) and not s["results"].has(seq):
		if clock - float(s["last_move_at"]) < move_min_interval:
			_send(peer, {"t": "result", "seq": seq, "ok": false, "error": "move_rate"})
			return
		s["last_move_at"] = clock
	var results: Dictionary = s["results"]
	if results.has(seq):
		var cached: Dictionary = results[seq].duplicate()
		cached["duplicate"] = true
		_send(peer, cached)             # idempotent: replay the stored answer, mutate nothing
		return
	if seq <= s["last_seq"]:
		_send(peer, {"t": "result", "seq": seq, "ok": false, "error": "stale_seq"})
		return
	if seq > s["last_seq"] + MAX_SEQ_JUMP:
		_send(peer, {"t": "result", "seq": seq, "ok": false, "error": "seq_jump"})
		return
	s["last_seq"] = seq
	var res: Dictionary
	if match_over:
		res = {"ok": false, "error": "match_over", "events": []}
	else:
		res = rules.call("apply", state, cmd)
	var out := {"t": "result", "seq": seq, "ok": bool(res.get("ok", false)), "error": str(res.get("error", ""))}
	results[seq] = out
	(s["order"] as Array).append(seq)
	while (s["order"] as Array).size() > RESULT_CACHE:
		results.erase((s["order"] as Array).pop_front())
	_send(peer, out)
	var events: Array = res.get("events", [])
	if out["ok"] and events.size() > 0:
		_dirty = true
		_after_events(events)
		_broadcast_events(events, {"cause_seq": seq, "cause_actor": s["actor"]})

func _after_events(events: Array) -> void:
	for e in events:
		if e is Dictionary and e.get("type", &"") == &"match_over":
			match_over = true
	if persist_slot >= 0:
		Persist.handle_events(persist_slot, events)
	if match_over:
		_broadcast_snapshot()

## Command types: whatever the loaded Rules module declares (COMMAND_TYPES), else the default list.
func _allowed() -> Array:
	if _allowed_cache.is_empty():
		var c: Variant = rules.get_script_constant_map().get("COMMAND_TYPES")
		_allowed_cache = c if (c is Array and not (c as Array).is_empty()) else ALLOWED_TYPES
	return _allowed_cache

## Pure validation; exposed for tests. Never mutates anything.
static func validate_cmd(raw: Variant, session_actor: int, allowed: Array = ALLOWED_TYPES) -> Dictionary:
	if not (raw is Dictionary):
		return {"ok": false, "error": "bad_shape"}
	var c: Dictionary = raw
	for k in c.keys():
		if not (k is String or k is StringName) or not ["type", "actor", "seq", "args"].has(str(k)):
			return {"ok": false, "error": "unknown_field"}
	var ty: Variant = c.get("type")
	if not (ty is String or ty is StringName) or not allowed.has(StringName(ty)):
		return {"ok": false, "error": "bad_type"}
	if typeof(c.get("seq")) != TYPE_INT or int(c["seq"]) <= 0:
		return {"ok": false, "error": "bad_seq"}
	if c.has("actor") and (typeof(c["actor"]) != TYPE_INT or int(c["actor"]) != session_actor):
		return {"ok": false, "error": "actor_mismatch"}
	var args: Variant = c.get("args", {})
	if not (args is Dictionary) or not NetCodec.plain(args):
		return {"ok": false, "error": "bad_args"}
	return {"ok": true, "cmd": {"type": StringName(ty), "actor": session_actor, "seq": int(c["seq"]), "args": args}}
