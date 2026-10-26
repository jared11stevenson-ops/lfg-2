class_name GameSession
extends Node
## One interface for "the game being played", whether the rules run in this process (LocalSession) or on a remote
## authoritative server (OnlineSession). Presentation/main code talks ONLY to this.
##
##   state            MatchState the UI reads. Local: THE authoritative object. Online: this viewer's fog-filtered copy
##                    (same instance for the whole session; updated in place; state.player_id == actor_id).
##   command(type, args) -> Dictionary     build {type, actor, seq, args} with a correct seq and submit it
##   submit(cmd) -> Dictionary             Local: Rules.apply result {ok, error, events}, synchronous.
##                                         Online: {"ok": true, "pending": true, "seq": n} immediately; the verdict arrives via
##                                         command_resolved(seq, result) / command_failed(seq, error). An online result with
##                                         "pending" == true only means "sent", never "accepted".
##   snapshot() -> Dictionary              encoded state (MatchState.to_dict() form; online: filtered for this viewer)
## Signals (both implementations emit exactly the same ones):
##   events_emitted(events)     gameplay events, ALREADY reflected in `state` when delivered (online delivers them with the
##                              next snapshot so stage.on_events(events, session.state) is consistent)
##   state_replaced()           `state` is a brand new object / world (start, continue, reconnect-after-restart)
##   state_updated()            online only: a newer snapshot was applied in place (cheap; farm/HUD may resync)
##   command_resolved(seq, r)   verdict for a submitted command (local emits it too, synchronously)
##   command_failed(seq, err)   rejection (also reported by command_resolved with ok=false)
##   session_ended(reason)      match over, or online connection lost for good
signal events_emitted(events: Array)
signal state_replaced()
signal state_updated()
signal command_resolved(seq: int, result: Dictionary)
signal command_failed(seq: int, error: String)
signal session_ended(reason: String)

var state: RefCounted
var actor_id: int = 1
var ended: bool = false
var end_reason: String = ""
var _seq: int = 0

func is_online() -> bool:
	return false

## Next unused seq for this actor (never collides with the actor's last accepted seq).
func next_seq() -> int:
	var last: int = 0
	if state != null:
		var acts: Variant = state.get("actors")
		if acts is Dictionary and (acts as Dictionary).has(actor_id):
			last = int(acts[actor_id].get("last_seq", 0))
	_seq = maxi(_seq, last) + 1
	return _seq

func command(type: StringName, args: Dictionary = {}) -> Dictionary:
	return submit({"type": type, "actor": actor_id, "seq": next_seq(), "args": args})

func submit(_cmd: Dictionary) -> Dictionary:
	return {"ok": false, "error": "not_implemented"}

func snapshot() -> Dictionary:
	return state.call("to_dict") if state != null else {}

func close() -> void:
	pass

func _end(reason: String) -> void:
	if ended:
		return
	ended = true
	end_reason = reason
	session_ended.emit(reason)
