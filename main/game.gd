extends Node
## Autoload "Game": bridge between Rules (pure) and presentation.
signal events_emitted(events: Array)
signal state_replaced()
var state: RefCounted
func submit(cmd: Dictionary) -> Dictionary:
	var res: Dictionary = Rules.apply(state, cmd)
	if res.get("ok", false):
		events_emitted.emit(res.get("events", []))
	return res
func _process(dt: float) -> void:
	if state != null:
		var ev: Array = Rules.tick(state, dt)
		if ev.size() > 0:
			events_emitted.emit(ev)
