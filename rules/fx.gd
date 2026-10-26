class_name Fx
extends RefCounted
## World effects placed by class abilities: sentinel posts (turret), snare traps, spore zones, smuggler caches.
## Stored in state.fx (saved). Every entry: {id, type, owner(actor id), faction, hex, ...}. Float keys must be listed in MatchState.FLOAT_KEYS.
const POST_PERIOD := 2.0
const ZONE_PERIOD := 1.0

static func hostile_to(state: MatchState, faction: int, o: Dictionary) -> bool:
	if not o["alive"] or int(o["faction"]) == faction:
		return false
	if o["kind"] == "enemy":
		return true
	return state.phase == &"PURGE_ACTIVE"

static func active_of(state: MatchState, owner: int, type: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for f in state.fx:
		if f["type"] == type and int(f["owner"]) == owner:
			out.append(f)
	return out

## Adds an effect; if the owner already has max_active of this type the oldest is retired (event fx_expired).
static func place(state: MatchState, fx: Dictionary, max_active: int, events: Array) -> int:
	var mine: Array[Dictionary] = active_of(state, int(fx["owner"]), String(fx["type"]))
	while mine.size() >= max_active and not mine.is_empty():
		var old: Dictionary = mine.pop_front()
		state.fx.erase(old)
		events.append({"type": &"fx_expired", "id": old["id"], "fx": old["type"], "hex": old["hex"]})
	fx["id"] = state.new_id()
	state.fx.append(fx)
	events.append({"type": &"fx_placed", "id": fx["id"], "fx": fx["type"], "hex": fx["hex"], "owner": fx["owner"]})
	return int(fx["id"])

static func step(state: MatchState, events: Array) -> void:
	if state.fx.is_empty():
		return
	var now: float = float(state.clock["elapsed"])
	var keep: Array = []
	var ids: Array = state.actors.keys()
	ids.sort()
	for f in state.fx:
		var t: String = f["type"]
		if t == "cache":
			keep.append(f)
			continue
		if float(f["until"]) <= now:
			events.append({"type": &"fx_expired", "id": f["id"], "fx": t, "hex": f["hex"]})
			continue
		var consumed: bool = false
		if t == "post" and float(f["next"]) <= now:
			f["next"] = MatchState.q(now + POST_PERIOD)
			var best: int = -1
			var bd: int = int(f["range"]) + 1
			for id in ids:
				var o: Dictionary = state.actors[id]
				if not hostile_to(state, int(f["faction"]), o):
					continue
				var d: int = HexGrid.distance(o["hex"], f["hex"])
				if d < bd:
					bd = d
					best = int(id)
			if best != -1:
				events.append({"type": &"fx_hit", "id": f["id"], "fx": t, "target": best, "damage": f["dmg"]})
				Combat.hurt(state, best, int(f["dmg"]), int(f["owner"]), events, "sentinel")
		elif t == "trap" and float(f["arm_at"]) <= now:
			for id in ids:
				var o2: Dictionary = state.actors[id]
				if o2["hex"] == f["hex"] and hostile_to(state, int(f["faction"]), o2) and o2["kind"] != "ai_leader":
					Combat.add_effect(o2, "rooted", MatchState.q(now + float(f["root"])))
					events.append({"type": &"trap_sprung", "id": f["id"], "target": int(id), "hex": f["hex"], "root": f["root"]})
					Combat.hurt(state, int(id), int(f["dmg"]), int(f["owner"]), events, "snare")
					consumed = true
					break
		elif t == "zone" and float(f["next"]) <= now:
			f["next"] = MatchState.q(now + ZONE_PERIOD)
			for id in ids:
				var o3: Dictionary = state.actors[id]
				if hostile_to(state, int(f["faction"]), o3) and HexGrid.distance(o3["hex"], f["hex"]) <= int(f["radius"]):
					Combat.hurt(state, int(id), int(f["dps"]), int(f["owner"]), events, "spores")
		if consumed:
			continue
		keep.append(f)
	state.fx = keep

## Dune: dig up an own cache on this hex into the pack. Returns "" or an error code. Mutates nothing on failure.
static func recover_cache(state: MatchState, a: Dictionary, hex: Vector2i, events: Array) -> String:
	for f in state.fx:
		if f["type"] == "cache" and f["hex"] == hex and int(f["faction"]) == int(a["faction"]):
			if not Inv.can_carry(a, f["items"]):
				return "no_room"
			Inv.add_all(a["inv"], f["items"])
			state.fx.erase(f)
			events.append({"type": &"cache_recovered", "actor": a["id"], "hex": hex, "items": f["items"]})
			return ""
	return "nothing_to_harvest"

static func cache_at(state: MatchState, faction: int, hex: Vector2i) -> bool:
	for f in state.fx:
		if f["type"] == "cache" and f["hex"] == hex and int(f["faction"]) == faction:
			return true
	return false
