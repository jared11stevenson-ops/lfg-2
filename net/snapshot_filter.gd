class_name SnapshotFilter
extends RefCounted
## Per-viewer filtering of the server's encoded state (MatchState.to_dict() form: string keys, hexes as {"_v":[q,r]}).
## What a client MAY see (fog-aware minimum):
##   - everything about its own faction (actors, inventories, holding stores)
##   - all plots (crops are public), all holdings' position/owner/tier/garrison/buildings (construction is public)
##   - neutral merchants' stock (public market)
##   - other factions' actors only within `radius` hexes of any of the viewer's units/holdings; those carry NO inventory,
##     NO cooldowns, NO AI internals. Faction leaders outside vision are fogged stubs (hex = FOG_HEX, hp hidden).
##   - wild enemies only inside vision; ground drops only inside vision
## What it may NOT see: other factions' inventories and holding stores, rng_state (would predict capture/steal rolls),
## AI persona/hunger/ration policy, internal timers.
## Honest limit: positions of other factions' holdings and plots are global; events are not range-filtered (only stripped of item payloads).
const FOG_HEX := {"_v": [-9999, -9999]}
const SECRET_EVENT_KEYS: Array[String] = ["items", "loot", "coin", "refund"]

static func decode_hex(v: Variant) -> Variant:
	if v is Vector2i:
		return v
	if v is Dictionary and (v as Dictionary).has("_v"):
		var p: Array = v["_v"]
		return Vector2i(int(p[0]), int(p[1]))
	return null

static func hex_distance(a: Vector2i, b: Vector2i) -> int:
	var dq: int = a.x - b.x
	var dr: int = a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2

static func viewer_faction(d: Dictionary, actor: int) -> int:
	var actors: Variant = d.get("actors")
	if actors is Dictionary and (actors as Dictionary).has(str(actor)):
		return int(actors[str(actor)].get("faction", -99))
	return -99

static func _in_vision(h: Variant, sources: Array[Vector2i], radius: int) -> bool:
	var hx: Variant = decode_hex(h)
	if hx == null:
		return false
	for s in sources:
		if hex_distance(s, hx) <= radius:
			return true
	return false

## Returns a filtered COPY (input is not mutated). Passthrough when the dict does not have the real MatchState shape.
static func for_actor(d: Dictionary, actor: int, radius: int = 8) -> Dictionary:
	var actors: Variant = d.get("actors")
	var holdings: Variant = d.get("holdings")
	if not (actors is Dictionary) or not (holdings is Dictionary) or not (actors as Dictionary).has(str(actor)):
		return d
	var fid: int = viewer_faction(d, actor)
	var sources: Array[Vector2i] = []
	for a in (actors as Dictionary).values():
		if int(a.get("faction", -99)) == fid and a.get("alive", false) and a.get("kind", "") != "enemy":
			var hx: Variant = decode_hex(a.get("hex"))
			if hx != null:
				sources.append(hx)
	for h in (holdings as Dictionary).values():
		if int(h.get("owner", -99)) == fid:
			var hx2: Variant = decode_hex(h.get("hex"))
			if hx2 != null:
				sources.append(hx2)
	var leaders: Dictionary = {}
	var factions: Variant = d.get("factions", {})
	var fout: Dictionary = {}
	if factions is Dictionary:
		for k in (factions as Dictionary).keys():
			var f: Dictionary = (factions[k] as Dictionary).duplicate()
			leaders[int(f.get("leader", -1))] = true
			if int(f.get("id", int(k))) != fid:
				for secret in ["persona", "hunger_days", "ration_policy"]:
					f.erase(secret)
			fout[k] = f
	var out: Dictionary = d.duplicate(false)
	var aout: Dictionary = {}
	for k in (actors as Dictionary).keys():
		var a: Dictionary = actors[k]
		if int(a.get("faction", -99)) == fid:
			aout[k] = a
			continue
		var seen: bool = _in_vision(a.get("hex"), sources, radius)
		var red: Dictionary = a.duplicate(false)
		red["inv"] = {}
		red["cd"] = {}
		red["ai"] = {}
		red["last_seq"] = 0
		red["inv_hidden"] = true
		if seen:
			aout[k] = red
		elif leaders.has(int(a.get("id", -1))):
			red["hex"] = FOG_HEX.duplicate(true)
			red["hp"] = int(a.get("max_hp", 1))
			red["move"] = {}
			red["effects"] = []
			red["fogged"] = true
			aout[k] = red
		# else: out of sight and not a leader -> omitted entirely
	out["actors"] = aout
	var hout: Dictionary = {}
	for k in (holdings as Dictionary).keys():
		var h: Dictionary = holdings[k]
		var owner: int = int(h.get("owner", -1))
		if owner == fid or owner == -1:
			hout[k] = h
		else:
			var hr: Dictionary = h.duplicate(false)
			hr["store"] = {}
			hr["store_hidden"] = true
			hout[k] = hr
	out["holdings"] = hout
	out["factions"] = fout
	var dr: Variant = d.get("drops", {})
	if dr is Dictionary:
		var dout: Dictionary = {}
		for key in (dr as Dictionary).keys():
			var parts: PackedStringArray = String(key).split(",")
			if parts.size() == 2 and _in_vision({"_v": [int(parts[0]), int(parts[1])]}, sources, radius):
				dout[key] = dr[key]
		out["drops"] = dout
	out["rng_state"] = 0
	out["sim_acc"] = {}
	out["ai_t"] = 0
	return out

## Events: strip item payloads from actions performed by other factions. `actors` = live state.actors (int keys).
static func events_for(events: Array, viewer_fid: int, actors: Dictionary) -> Array:
	if viewer_fid == -99:
		return events
	var out: Array = []
	for e in events:
		if not (e is Dictionary):
			continue
		var ef: int = -99
		if e.has("actor") and e["actor"] is int and actors.has(e["actor"]):
			ef = int(actors[e["actor"]].get("faction", -99))
		elif e.has("by"):
			ef = int(e["by"])
		elif e.has("faction"):
			ef = int(e["faction"])
		if ef == viewer_fid:
			out.append(e)
			continue
		var c: Dictionary = (e as Dictionary).duplicate(false)
		for k in SECRET_EVENT_KEYS:
			c.erase(k)
		out.append(c)
	return out
