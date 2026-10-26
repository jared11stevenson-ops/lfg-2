class_name Persist
extends RefCounted
## Versioned match saves. Slots 0..99. Files under <root>/saves/.
## NOTE: sha256 detects accidental corruption only; it is not tamper protection (a player can edit
## local files). Server-side authority (net/) is the answer for anti-cheat, not this.
static var root: String = "user://"
const MAX_SLOT := 99

static func _base(slot: int) -> String:
	return root.path_join("saves/slot_%d.sav" % slot)

static func _tomb(slot: int) -> String:
	return root.path_join("saves/slot_%d.over" % slot)

static func _valid_slot(slot: int) -> bool:
	return slot >= 0 and slot <= MAX_SLOT

static func migrate(d: Dictionary) -> Dictionary:
	var r: Dictionary = SaveMigrations.run(d)
	return r["data"] if r["ok"] else {}

static func migrate_checked(d: Dictionary) -> Dictionary:
	return SaveMigrations.run(d)

## state: object with to_dict(), or a Dictionary. Refuses to write to a finished match.
static func save_match(slot: int, state: Variant) -> Dictionary:
	if not _valid_slot(slot):
		return {"ok": false, "error": "bad_slot"}
	if is_over(slot):
		return {"ok": false, "error": "match_over"}
	var sd: Variant = state.to_dict() if state is Object else state
	if not (sd is Dictionary):
		return {"ok": false, "error": "bad_state"}
	var saves := 1
	var prev: Dictionary = _best(slot)
	if prev["ok"]:
		saves = int(prev["data"].get("stats", {}).get("saves", 0)) + 1
	var data := {
		"save_version": SaveMigrations.CURRENT,
		"status": "active",
		"over_reason": "",
		"saved_at": int(Time.get_unix_time_from_system()),
		"stats": {"saves": saves},
		"state": sd,
	}
	return SafeFile.write(_base(slot), var_to_str(data))

static func _best(slot: int) -> Dictionary:
	var errors: Array[String] = []
	for c in SafeFile.read_candidates(_base(slot)):
		if not c["ok"]:
			errors.append("%s:%s" % [c["source"], c["error"]])
			continue
		var parsed: Variant = str_to_var(c["payload"])
		if not (parsed is Dictionary):
			errors.append("%s:bad_payload" % c["source"])
			continue
		var m: Dictionary = SaveMigrations.run(parsed)
		if not m["ok"]:
			errors.append("%s:%s" % [c["source"], m["error"]])
			continue
		return {"ok": true, "data": m["data"], "source": c["source"], "recovered": c["source"] != "primary", "errors": errors}
	return {"ok": false, "error": "no_valid_save" if errors.size() > 0 else "no_save", "errors": errors}

## -> {ok, error, state (MatchState or null if class unavailable), state_dict, source, recovered, errors}
static func load_match(slot: int) -> Dictionary:
	if not _valid_slot(slot):
		return {"ok": false, "error": "bad_slot"}
	if is_over(slot):
		return {"ok": false, "error": "match_over", "reason": over_reason(slot)}
	var b: Dictionary = _best(slot)
	if not b["ok"]:
		return b
	if b["data"].get("status", "active") == "over":
		return {"ok": false, "error": "match_over", "reason": b["data"].get("over_reason", "")}
	var sd: Dictionary = b["data"]["state"]
	var ms: Script = ClassLink.match_state()
	var st: Variant = null
	if ms != null and ms.has_method("from_dict"):
		st = ms.call("from_dict", sd)
	return {"ok": true, "state": st, "state_dict": sd, "source": b["source"], "recovered": b["recovered"], "errors": b["errors"], "stats": b["data"]["stats"]}

## Permadeath: a tombstone (separate file) outranks every save and backup, so a corrupted primary
## cannot fall back to an older backup and resurrect a dead leader.
static func mark_over(slot: int, reason: String) -> Dictionary:
	if not _valid_slot(slot):
		return {"ok": false, "error": "bad_slot"}
	var payload: String = JSON.stringify({"reason": reason, "at": int(Time.get_unix_time_from_system())})
	return SafeFile.write(_tomb(slot), payload, 0)

static func is_over(slot: int) -> bool:
	# any tombstone artifact (even unreadable) counts as over
	return FileAccess.file_exists(_tomb(slot))

static func over_reason(slot: int) -> String:
	for c in SafeFile.read_candidates(_tomb(slot), 0):
		if c["ok"]:
			var j := JSON.new()
			if j.parse(c["payload"]) == OK and j.data is Dictionary:
				return str(j.data.get("reason", ""))
	return "unknown"

## Feed rules events here; a match_over event permanently ends the slot's match.
static func handle_events(slot: int, events: Array) -> bool:
	for e in events:
		if e is Dictionary and e.get("type", &"") == &"match_over":
			mark_over(slot, str(e.get("reason", "")))
			return true
	return false

## Explicit player action: wipe the slot (including tombstone) to start a new match there.
static func clear_slot(slot: int) -> void:
	if not _valid_slot(slot):
		return
	SafeFile.delete_all(_base(slot))
	SafeFile.delete_all(_tomb(slot), 0)

static func list_slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in range(0, MAX_SLOT + 1):
		if is_over(s):
			out.append({"slot": s, "status": "over", "reason": over_reason(s)})
			continue
		if FileAccess.file_exists(_base(s)) or FileAccess.file_exists(SafeFile.backup_path(_base(s), 1)):
			var b: Dictionary = _best(s)
			out.append({"slot": s, "status": "active" if b["ok"] else "corrupt", "saved_at": int(b["data"].get("saved_at", 0)) if b["ok"] else 0})
	return out
