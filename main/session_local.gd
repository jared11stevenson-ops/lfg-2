class_name LocalSession
extends GameSession
## Rules run in this process. Adds: autosave into a Persist slot (atomic, rotating backups), permadeath tombstone,
## and meta hooks (codex on class first use, titles on victory).
##   var s := LocalSession.new_game(seed, &"lfg:class/judd", slot)       # slot -1 = no persistence
##   var s := LocalSession.continue_slot(slot)                            # null if missing/corrupt/over (see last_error)
##   add_child(s)  -> ticks itself from _process;  or call s.tick(dt) manually (tests, journey tools)
const AUTOSAVE_DEFAULT := 30.0

var slot: int = -1
var autosave_interval: float = AUTOSAVE_DEFAULT   # session-seconds of tick() time between periodic saves
var time_scale: float = 1.0
var paused: bool = false
var meta: MetaStore = null                        # null disables meta hooks
var unlocked: Array[String] = []                  # ids unlocked during this session (menu/toast can show them)
var last_save: Dictionary = {}
var saves_written: int = 0
static var last_error: String = ""
var _since_save: float = 0.0
var _dirty: bool = false

static func new_game(seed_value: int, class_id: StringName, p_slot: int = -1, opts: Dictionary = {}, p_meta: MetaStore = null) -> LocalSession:
	var s := LocalSession.new()
	s.slot = p_slot
	s.meta = p_meta
	if p_slot >= 0:
		Persist.clear_slot(p_slot)       # explicit "new game here": wipes an old save and any tombstone
	s.state = Rules.new_match(seed_value, class_id, opts)
	s.actor_id = int(s.state.get("player_id"))
	if s.meta != null:
		s.unlocked.append_array(MetaHooks.on_class_used(s.meta, String(class_id)))
	if p_slot >= 0:
		s.save_now()
	return s

static func continue_slot(p_slot: int, p_meta: MetaStore = null) -> LocalSession:
	var l: Dictionary = Persist.load_match(p_slot)
	if not l.get("ok", false) or l.get("state") == null:
		last_error = str(l.get("error", "no_state"))
		return null
	var s := LocalSession.new()
	s.slot = p_slot
	s.meta = p_meta
	s.state = l["state"]
	s.actor_id = int(s.state.get("player_id"))
	last_error = ""
	if s.meta != null:
		var acts: Dictionary = s.state.get("actors")
		s.unlocked.append_array(MetaHooks.on_class_used(s.meta, str(acts[s.actor_id].get("class_id", ""))))
	return s

func _process(dt: float) -> void:
	if not paused and not ended:
		tick(dt * time_scale)

func tick(dt: float) -> Array:
	if state == null or ended:
		return []
	var ev: Array = Rules.tick(state, dt)
	_since_save += dt
	if ev.size() > 0:
		_handle(ev)
	if slot >= 0 and not ended and (_since_save >= autosave_interval):
		save_now()
	return ev

func submit(cmd: Dictionary) -> Dictionary:
	if state == null:
		return {"ok": false, "error": "no_state", "events": []}
	if ended:
		return {"ok": false, "error": "match_over", "events": []}
	var seq: int = int(cmd.get("seq", 0))
	var res: Dictionary = Rules.apply(state, cmd)
	if res.get("ok", false):
		var ev: Array = res.get("events", [])
		if ev.size() > 0:
			_handle(ev)
	else:
		command_failed.emit(seq, str(res.get("error", "")))
	command_resolved.emit(seq, res)
	return res

func _handle(events: Array) -> void:
	var save_after: bool = false
	for e in events:
		var t: StringName = e.get("type", &"")
		if t == &"day_changed" or t == &"phase_changed" or t == &"holding_captured":
			save_after = true
	if slot >= 0:
		Persist.handle_events(slot, events)            # match_over -> tombstone, permanently
	if meta != null:
		unlocked.append_array(MetaHooks.on_events(meta, events))
	var over: bool = false
	var reason: String = ""
	for e in events:
		if e.get("type", &"") == &"match_over":
			over = true
			reason = str(e.get("reason", ""))
	events_emitted.emit(events)
	if over:
		_end("match_over:" + reason)
	elif save_after and slot >= 0:
		save_now()

## Atomic write (temp + verify + rename, 2 backups). Refused for a finished match (tombstone wins).
func save_now() -> Dictionary:
	if slot < 0 or state == null:
		return {"ok": false, "error": "no_slot"}
	if ended or bool(state.get("over")):
		return {"ok": false, "error": "match_over"}
	last_save = Persist.save_match(slot, state)
	_since_save = 0.0
	if last_save.get("ok", false):
		saves_written += 1
	return last_save

func close() -> void:
	save_now()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED or what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		save_now()
