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

var _sessions: Dictionary = {}          # sha256(token) -> session dict
var _peers: Dictionary = {}             # ENetPacketPeer -> {key:String, since:float, fails:int}
var _last_snapshot_at: float = 0.0
var _last_save_at: float = 0.0
var _dirty: bool = false

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
	return OK

func stop() -> void:
	if host != null:
		for p in _peers.keys():
			(p as ENetPacketPeer).peer_disconnect_now(0)
		host.flush()
		host.destroy()
		host = null
	_peers.clear()

## Out-of-band invite: returns a secret token bound to `actor`.
func issue_token(actor: int) -> String:
	var tok: String = Crypto.new().generate_random_bytes(16).hex_encode()
	_sessions[tok.sha256_text()] = {"actor": actor, "peer": null, "last_seq": 0, "results": {}, "order": [],
		"tokens": float(bucket_capacity), "violations": 0}
	return tok

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
				_peers[peer] = {"key": "", "since": clock, "fails": 0}
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
		_broadcast({"t": "events", "events": events})
	for p in _peers.keys():
		var meta: Dictionary = _peers[p]
		if meta["key"] == "" and clock - meta["since"] > HELLO_TIMEOUT:
			_kick(p, "hello_timeout")
	if _dirty and clock - _last_snapshot_at >= snapshot_interval:
		_broadcast_snapshot()
	if persist_slot >= 0 and not match_over and clock - _last_save_at >= autosave_interval:
		Persist.save_match(persist_slot, state)
		_last_save_at = clock
	poll()
	return events

# ------------------------------------------------------------------ internals
func _send(peer: ENetPacketPeer, msg: Dictionary) -> void:
	peer.send(NetCodec.CHANNEL, NetCodec.encode(msg), ENetPacketPeer.FLAG_RELIABLE)

func _broadcast(msg: Dictionary) -> void:
	for p in _peers.keys():
		if _peers[p]["key"] != "":
			_send(p, msg)

func _broadcast_snapshot() -> void:
	_last_snapshot_at = clock
	_dirty = false
	_broadcast({"t": "snapshot", "state": state.call("to_dict"), "clock": clock})

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
	_peers.erase(peer)

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
				_send(peer, {"t": "snapshot", "state": state.call("to_dict"), "clock": clock})
		"ping":
			_send(peer, {"t": "pong", "clock": clock})

func _on_hello(peer: ENetPacketPeer, meta: Dictionary, msg: Dictionary) -> void:
	var tok: Variant = msg.get("token")
	var key: String = (tok as String).sha256_text() if tok is String else ""
	if key == "" or not _sessions.has(key):
		meta["fails"] += 1
		_send(peer, {"t": "reject", "reason": "bad_token"})
		if meta["fails"] >= MAX_HELLO_FAILS:
			_kick(peer, "bad_token")
		return
	var s: Dictionary = _sessions[key]
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
		"state": state.call("to_dict"), "match_over": match_over})

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
	var v: Dictionary = validate_cmd(raw, s["actor"])
	if not v["ok"]:
		_send(peer, {"t": "result", "seq": seq, "ok": false, "error": v["error"]})
		return
	var cmd: Dictionary = v["cmd"]
	seq = cmd["seq"]
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
		_broadcast({"t": "events", "events": events, "cause_seq": seq, "cause_actor": s["actor"]})

func _after_events(events: Array) -> void:
	for e in events:
		if e is Dictionary and e.get("type", &"") == &"match_over":
			match_over = true
	if persist_slot >= 0:
		Persist.handle_events(persist_slot, events)
	if match_over:
		_broadcast_snapshot()

## Pure validation; exposed for tests. Never mutates anything.
static func validate_cmd(raw: Variant, session_actor: int) -> Dictionary:
	if not (raw is Dictionary):
		return {"ok": false, "error": "bad_shape"}
	var c: Dictionary = raw
	for k in c.keys():
		if not (k is String or k is StringName) or not ["type", "actor", "seq", "args"].has(str(k)):
			return {"ok": false, "error": "unknown_field"}
	var ty: Variant = c.get("type")
	if not (ty is String or ty is StringName) or not ALLOWED_TYPES.has(StringName(ty)):
		return {"ok": false, "error": "bad_type"}
	if typeof(c.get("seq")) != TYPE_INT or int(c["seq"]) <= 0:
		return {"ok": false, "error": "bad_seq"}
	if c.has("actor") and (typeof(c["actor"]) != TYPE_INT or int(c["actor"]) != session_actor):
		return {"ok": false, "error": "actor_mismatch"}
	var args: Variant = c.get("args", {})
	if not (args is Dictionary) or not NetCodec.plain(args):
		return {"ok": false, "error": "bad_args"}
	return {"ok": true, "cmd": {"type": StringName(ty), "actor": session_actor, "seq": int(c["seq"]), "args": args}}
