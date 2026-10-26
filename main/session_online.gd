class_name OnlineSession
extends GameSession
## Rules run on a remote authoritative server (net/server.gd). This node never simulates: it sends commands,
## applies the fog-filtered snapshots the server pushes into one persistent MatchState, and re-emits server events.
##   var s := OnlineSession.join("host", 7777, token)     # then add_child(s); wait for `joined` (or state != null)
##   s.command(&"plant", {...}) -> {"ok": true, "pending": true, "seq": n}; verdict via command_resolved / command_failed
## `state` is the viewer's copy: other factions' inventories are empty, far rivals are fogged stubs, state.player_id == actor_id.
signal joined(actor: int)
signal connection_lost(reason: String)

const FATAL_REASONS: Array[String] = ["token_expired", "bad_token", "revoked", "replaced", "malformed", "oversize", "rate_limit_abuse", "unauthenticated"]
var client: NetClient
var max_reconnects: int = 8
var auto_reconnect: bool = true
var snapshot_request_min_interval: float = 0.12
var locked_for: float = 0.0              # >0: server says commands are locked (disconnect-during-Purge policy)
var snapshots_applied: int = 0
var last_snapshot: Dictionary = {}
var _types: Dictionary = {}              # seq -> command type (for diagnostics)
var _event_buf: Array = []
var _want_snapshot: bool = false
var _since_req: float = 0.0
var _reconnects: int = 0
var _retry_in: float = -1.0
var _first: bool = true

static func join(addr: String, port: int, token: String) -> OnlineSession:
	var s := OnlineSession.new()
	s.client = NetClient.new()
	s.client.welcomed.connect(s._on_welcomed)
	s.client.snapshot_received.connect(s._on_snapshot)
	s.client.events_received.connect(s._on_events)
	s.client.result_received.connect(s._on_result)
	s.client.disconnected.connect(s._on_disconnected)
	if s.client.connect_to(addr, port, token) != OK:
		s._end("cannot_connect")
	return s

func is_online() -> bool:
	return true

func is_ready() -> bool:
	return client != null and client.is_ready and state != null

func submit(cmd: Dictionary) -> Dictionary:
	if ended:
		return {"ok": false, "error": "session_ended", "events": []}
	if not is_ready():
		return {"ok": false, "error": "not_connected", "events": []}
	var args: Dictionary = cmd.get("args", {}) if cmd.get("args", {}) is Dictionary else {}
	var seq: int = client.submit(StringName(str(cmd.get("type", ""))), args)
	_types[seq] = str(cmd.get("type", ""))
	return {"ok": true, "pending": true, "seq": seq, "events": []}

## Online seqs are owned by the NetClient (server dedupes on them); keep base.next_seq() consistent anyway.
func next_seq() -> int:
	return client.next_seq if client != null else 1

func snapshot() -> Dictionary:
	return last_snapshot

func close() -> void:
	ended = true
	if client != null:
		client.disconnect_now()

func _process(dt: float) -> void:
	if client == null or ended:
		return
	client.poll()
	_since_req += dt
	if _want_snapshot and client.is_ready and _since_req >= snapshot_request_min_interval:
		_want_snapshot = false
		_since_req = 0.0
		client.request_snapshot()
	if _retry_in >= 0.0:
		_retry_in -= dt
		if _retry_in < 0.0:
			_retry_in = -1.0
			client.reconnect()

func _on_welcomed(actor: int) -> void:
	actor_id = actor
	locked_for = client.locked_for
	_reconnects = 0
	client.resend_all()                      # anything that never got an answer; server dedupes by seq
	joined.emit(actor)

func _on_snapshot(snap: Dictionary) -> void:
	last_snapshot = snap
	snapshots_applied += 1
	var replaced: bool = false
	if state == null or int(state.get("seed")) != int(snap.get("seed", -1)):
		state = MatchState.from_dict(snap)            # regenerates the world once
		replaced = true
	else:
		_apply_in_place(snap)
	(state as MatchState).player_id = actor_id         # the viewer is "the player" in this copy
	if replaced:
		state_replaced.emit()
	else:
		state_updated.emit()
	if _event_buf.size() > 0:
		var evs: Array = _event_buf
		_event_buf = []
		events_emitted.emit(evs)
	if bool(snap.get("over", false)):
		_end("match_over:" + str((snap.get("result", {}) as Dictionary).get("reason", "")))

## Same decode MatchState.from_dict uses, minus world regeneration, keeping object identity stable for the UI.
func _apply_in_place(snap: Dictionary) -> void:
	var s: MatchState = state
	for f in MatchState.SAVE_FIELDS:
		if snap.has(f):
			s.set(f, MatchState._dec(snap[f]))
	s.phase = StringName(String(s.phase))
	s.day_seconds = float(s.day_seconds)
	s.clock["time_of_day"] = float(s.clock["time_of_day"])
	s.clock["day_t"] = float(s.clock.get("day_t", float(s.clock["time_of_day"]) * s.day_seconds))
	s.clock["elapsed"] = float(s.clock["elapsed"])
	s.ai_t = float(s.ai_t)

func _on_events(evs: Array) -> void:
	_event_buf.append_array(evs)
	_want_snapshot = true                    # so the buffered events get delivered next to a fresh state

func _on_result(seq: int, res: Dictionary) -> void:
	if not res.get("ok", false):
		command_failed.emit(seq, str(res.get("error", "")))
	else:
		_want_snapshot = true
	command_resolved.emit(seq, res)
	_types.erase(seq)

func _on_disconnected(reason: String) -> void:
	connection_lost.emit(reason)
	if ended:
		return
	if FATAL_REASONS.has(reason) or not auto_reconnect or _reconnects >= max_reconnects:
		_end("disconnected:" + reason)
		return
	_reconnects += 1
	_retry_in = minf(8.0, pow(2.0, float(_reconnects - 1)) * 0.5)
