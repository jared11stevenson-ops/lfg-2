class_name CmdUtil
extends RefCounted
## Shared command-argument parsing and proximity helpers.

static func parse_hex(v: Variant) -> Variant:
	## Accepts Vector2i or [q, r] (JSON-friendly). Returns Vector2i or null; bounds checked.
	var h: Vector2i
	if typeof(v) == TYPE_VECTOR2I:
		h = v
	elif typeof(v) == TYPE_ARRAY and (v as Array).size() == 2:
		var a: Variant = v[0]
		var b: Variant = v[1]
		for x in [a, b]:
			if typeof(x) != TYPE_INT and not (typeof(x) == TYPE_FLOAT and x == floorf(x)):
				return null
		h = Vector2i(int(a), int(b))
	elif typeof(v) == TYPE_DICTIONARY and v.has("_v"):
		return parse_hex(v["_v"])
	else:
		return null
	if not HexGrid.in_bounds(h):
		return null
	return h

static func parse_id(v: Variant) -> int:
	if typeof(v) == TYPE_INT:
		return v
	if typeof(v) == TYPE_FLOAT and v == floorf(v):
		return int(v)
	return -1

static func nearest_owned_holding(state: MatchState, faction: int, hex: Vector2i, max_dist: int) -> int:
	var best: int = -1
	var bd: int = 1 << 30
	for hid in state.holdings_of(faction):
		var d: int = HexGrid.distance(state.holdings[hid]["hex"], hex)
		if d <= max_dist and d < bd:
			bd = d
			best = hid
	return best

static func holding_at(state: MatchState, hex: Vector2i) -> int:
	for hid in state.holdings.keys():
		if state.holdings[hid]["hex"] == hex:
			return int(hid)
	return -1

static func policy_value(v: Variant) -> String:
	return String(v) if typeof(v) in [TYPE_STRING, TYPE_STRING_NAME] else ""
