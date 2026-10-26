class_name NetClient
extends RefCounted
## Client library: connect with a token, submit commands, receive results/events/snapshots.
## It never simulates; `snapshot` is the last full state dict the server sent.
signal welcomed(actor: int)
signal disconnected(reason: String)
signal events_received(events: Array)
signal snapshot_received(state: Dictionary)
signal result_received(seq: int, result: Dictionary)

var host: ENetConnection
var peer: ENetPacketPeer
var addr: String = ""
var port: int = 0
var token: String = ""
var actor: int = -1
var is_ready: bool = false             # welcomed by server
var next_seq: int = 1
var pending: Dictionary = {}           # seq -> cmd awaiting a result
var results: Dictionary = {}           # seq -> result dict
var snapshot: Dictionary = {}
var server_clock: float = 0.0
var events_log: Array = []
var last_bye: String = ""
var match_over: bool = false

func connect_to(p_addr: String, p_port: int, p_token: String) -> int:
	addr = p_addr
	port = p_port
	token = p_token
	_close()
	host = ENetConnection.new()
	var err: int = host.create_host(1, 1)
	if err != OK:
		return err
	peer = host.connect_to_host(addr, port, 1)
	return OK if peer != null else ERR_CANT_CONNECT

func reconnect() -> int:
	return connect_to(addr, port, token)

func _close() -> void:
	if host != null:
		if peer != null:
			peer.peer_disconnect_now(0)
		host.flush()
		host.destroy()
	host = null
	peer = null
	is_ready = false

func disconnect_now() -> void:
	_close()

func submit(type: StringName, args: Dictionary = {}) -> int:
	var seq: int = next_seq
	next_seq += 1
	var cmd := {"type": type, "actor": actor, "seq": seq, "args": args}
	pending[seq] = cmd
	_send_cmd(cmd)
	return seq

## Re-send a command verbatim (same seq). Server dedupes; used after reconnect or on timeout.
func resend(seq: int) -> void:
	if pending.has(seq):
		_send_cmd(pending[seq])

func resend_all() -> void:
	for s in pending.keys():
		resend(s)

func request_snapshot() -> void:
	_send({"t": "snap"})

func _send_cmd(cmd: Dictionary) -> void:
	_send({"t": "cmd", "cmd": cmd})

func _send(msg: Dictionary) -> void:
	if peer != null and peer.get_state() == ENetPacketPeer.STATE_CONNECTED:
		peer.send(NetCodec.CHANNEL, NetCodec.encode(msg), ENetPacketPeer.FLAG_RELIABLE)

func poll() -> void:
	if host == null:
		return
	for _i in 256:
		var ev: Array = host.service(0)
		var t: int = ev[0]
		if t == ENetConnection.EVENT_NONE:
			break
		match t:
			ENetConnection.EVENT_CONNECT:
				_send({"t": "hello", "token": token})
			ENetConnection.EVENT_DISCONNECT, ENetConnection.EVENT_ERROR:
				is_ready = false
				disconnected.emit(last_bye)
				return
			ENetConnection.EVENT_RECEIVE:
				_on_msg(NetCodec.decode((ev[1] as ENetPacketPeer).get_packet()))

func _on_msg(m: Dictionary) -> void:
	if m.is_empty():
		return
	match m["t"]:
		"welcome":
			actor = m["actor"]
			snapshot = m["state"]
			server_clock = m["clock"]
			match_over = m.get("match_over", false)
			is_ready = true
			# server remembers last accepted seq; continue after it so we never collide
			next_seq = maxi(next_seq, int(m["last_seq"]) + 1)
			welcomed.emit(actor)
			snapshot_received.emit(snapshot)
		"result":
			var seq: int = m["seq"]
			if m.get("retry", false):
				return                      # rate limited: stays pending, caller may resend
			results[seq] = m
			pending.erase(seq)
			result_received.emit(seq, m)
		"events":
			events_log.append_array(m["events"])
			events_received.emit(m["events"])
		"snapshot":
			snapshot = m["state"]
			server_clock = m["clock"]
			snapshot_received.emit(snapshot)
		"pong":
			server_clock = m["clock"]
		"bye":
			last_bye = m["reason"]
		"reject":
			last_bye = m["reason"]
