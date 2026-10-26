class_name Inv
extends RefCounted
## Validated item transactions. All-or-nothing: functions that mutate only run after full validation.
const MAX_QTY := 9999

## Returns the quantity as int when valid (integral, 1..MAX_QTY), else -1. Rejects fractional/negative/zero/overflow/non-numbers.
static func parse_qty(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return v if (v > 0 and v <= MAX_QTY) else -1
	if typeof(v) == TYPE_FLOAT:
		var f: float = v
		if is_nan(f) or is_inf(f) or f != floorf(f):
			return -1
		if f > 0.0 and f <= float(MAX_QTY):
			return int(f)
	return -1

## {ok:bool, bundle:Dictionary{String:int}, error:String}
static func parse_bundle(v: Variant) -> Dictionary:
	if not (v is Dictionary) or (v as Dictionary).is_empty():
		return {"ok": false, "bundle": {}, "error": "bad_bundle"}
	var out: Dictionary = {}
	for k in (v as Dictionary).keys():
		var id: String = String(k)
		if Content.item(id).is_empty():
			return {"ok": false, "bundle": {}, "error": "unknown_item"}
		var q: int = parse_qty(v[k])
		if q < 0:
			return {"ok": false, "bundle": {}, "error": "bad_quantity"}
		out[id] = q
	return {"ok": true, "bundle": out, "error": ""}

static func count(inv: Dictionary, item: String) -> int:
	return int(inv.get(item, 0))

static func has_all(inv: Dictionary, bundle: Dictionary) -> bool:
	for k in bundle.keys():
		if int(inv.get(k, 0)) < int(bundle[k]):
			return false
	return true

static func room_for(inv: Dictionary, bundle: Dictionary) -> bool:
	for k in bundle.keys():
		if int(inv.get(k, 0)) + int(bundle[k]) > MAX_QTY:
			return false
	return true

## Unchecked primitives; callers MUST validate first (has_all / room_for).
static func add_all(inv: Dictionary, bundle: Dictionary) -> void:
	for k in bundle.keys():
		inv[k] = int(inv.get(k, 0)) + int(bundle[k])

static func remove_all(inv: Dictionary, bundle: Dictionary) -> void:
	for k in bundle.keys():
		var left: int = int(inv.get(k, 0)) - int(bundle[k])
		if left <= 0:
			inv.erase(k)
		else:
			inv[k] = left

## Carry limit (Pip): non-coin units an actor may hold. Classes without "carry_cap" are unlimited.
static func carry_cap(a: Dictionary) -> int:
	return int(Combat.class_mod(a, "carry_cap", 0))

static func carried(a: Dictionary) -> int:
	var n: int = 0
	for k in (a["inv"] as Dictionary).keys():
		if String(k) != "lfg:item/coin":
			n += int(a["inv"][k])
	return n

## True when `add` (net of `remove`) fits the actor's pack and per-item cap.
static func can_carry(a: Dictionary, add: Dictionary, remove: Dictionary = {}) -> bool:
	var probe: Dictionary = (a["inv"] as Dictionary).duplicate()
	remove_all(probe, remove)
	if not room_for(probe, add):
		return false
	var cap: int = carry_cap(a)
	if cap <= 0:
		return true
	var n: int = 0
	for k in probe.keys():
		if String(k) != "lfg:item/coin":
			n += int(probe[k])
	for k in add.keys():
		if String(k) != "lfg:item/coin":
			n += int(add[k])
	return n <= cap

## Atomic move between two DIFFERENT containers. Returns "" on success or an error with nothing changed.
static func transfer(from_inv: Dictionary, to_inv: Dictionary, bundle: Dictionary) -> String:
	if not has_all(from_inv, bundle):
		return "insufficient_items"
	if not room_for(to_inv, bundle):
		return "no_room"
	remove_all(from_inv, bundle)
	add_all(to_inv, bundle)
	return ""

static func total(inv: Dictionary) -> int:
	var t: int = 0
	for k in inv.keys():
		t += int(inv[k])
	return t

## Sum of every item across all containers in a match (for conservation tests).
static func world_totals(state: MatchState) -> Dictionary:
	var t: Dictionary = {}
	for id in state.actors.keys():
		add_all(t, state.actors[id]["inv"])
	for id in state.holdings.keys():
		add_all(t, state.holdings[id]["store"])
	for k in state.drops.keys():
		add_all(t, state.drops[k])
	for fx in state.fx:
		if fx.has("items"):
			add_all(t, fx["items"])
	return t
