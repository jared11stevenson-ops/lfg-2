class_name SaveMigrations
extends RefCounted
## Explicit, individually tested save-envelope migrations. Envelope key "save_version" (absent => 1).
##   v1: {state, over:bool}
##   v2: + over_reason:String, saved_at:int
##   v3: `over` replaced by status:"active"|"over"; + stats:{saves:int}
## State-internal migrations (MatchState.schema_version) are registered by Stream A's version via
## `state_steps` {from_version:int -> Callable(state_dict)->state_dict}; target in `state_target` (-1 = none).
const CURRENT := 3
static var state_steps: Dictionary = {}
static var state_target: int = -1

static func step(d: Dictionary, from: int) -> Dictionary:
	var o: Dictionary = d.duplicate(true)
	match from:
		1:
			o["over_reason"] = "legacy" if o.get("over", false) else ""
			o["saved_at"] = 0
			o["save_version"] = 2
		2:
			o["status"] = "over" if o.get("over", false) else "active"
			o.erase("over")
			o["stats"] = {"saves": 0}
			o["save_version"] = 3
		_:
			return {}
	return o

## {ok, error, data}
static func run(d: Dictionary) -> Dictionary:
	var v: int = int(d.get("save_version", 1))
	if v < 1:
		return {"ok": false, "error": "bad_version"}
	if v > CURRENT:
		return {"ok": false, "error": "too_new"}
	var o: Dictionary = d.duplicate(true)
	while v < CURRENT:
		o = step(o, v)
		if o.is_empty():
			return {"ok": false, "error": "no_migration_from_%d" % v}
		v = int(o["save_version"])
	if not (o.get("state") is Dictionary):
		return {"ok": false, "error": "missing_state"}
	if state_target >= 0:
		var sd: Dictionary = o["state"]
		var sv: int = int(sd.get("schema_version", 1))
		if sv > state_target:
			return {"ok": false, "error": "state_too_new"}
		while sv < state_target:
			if not state_steps.has(sv):
				return {"ok": false, "error": "no_state_migration_from_%d" % sv}
			sd = (state_steps[sv] as Callable).call(sd)
			sd["schema_version"] = sv + 1
			sv += 1
		o["state"] = sd
	return {"ok": true, "data": o}
