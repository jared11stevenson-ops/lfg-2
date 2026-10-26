extends Node
## Autoload "Game": holds the active GameSession (local or online) and re-exposes state/events to presentation.
signal events_emitted(events: Array)
signal state_replaced()
var session: GameSession
var state: RefCounted
func use_session(s: GameSession) -> void:
	if session != null:
		session.close()
		session.queue_free()
	session = s
	add_child(s)
	state = s.state
	s.events_emitted.connect(func(e: Array) -> void: events_emitted.emit(e))
	s.state_replaced.connect(func() -> void:
		state = s.state
		state_replaced.emit())
func command(type: StringName, args: Dictionary = {}) -> Dictionary:
	return session.command(type, args) if session != null else {"ok": false, "error": "no_session"}
func submit(cmd: Dictionary) -> Dictionary:
	return session.submit(cmd) if session != null else {"ok": false, "error": "no_session"}
