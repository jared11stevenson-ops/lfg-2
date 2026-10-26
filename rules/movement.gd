class_name Movement
extends RefCounted
## Authoritative movement: per-hex time, smooth world position, and validated position sync (anti-teleport).
const SYNC_SLACK := 2.0       # seconds of jitter tolerance per sync call
const SYNC_MAX_BANK := 10.0   # idle time that can be "banked" toward a later burst
const SYNC_MAX_NODES := 600
const SYNC_MAX_HEXES := 8

static func walk_mult(state: MatchState, a: Dictionary) -> float:
	var m: float = float(Combat.class_mod(a, "walk_mult", 1.0)) * float(a.get("speed_mult", 1.0))
	if Combat.hungry(state, a):
		m *= 1.0 + 0.15 * float(mini(int(state.factions[int(a["faction"])].get("hunger_days", 0)), 3))
	return m

## Seconds the actor needs to ENTER hex h.
static func step_secs(state: MatchState, a: Dictionary, h: Vector2i) -> float:
	var c: float = WorldGen.move_cost(state.world, h)
	if c <= 0.0:
		return 0.0
	if int(state.world["road"][HexGrid.index(h)]) == 1:
		c *= float(Combat.class_mod(a, "road_mult", 1.0))
	return c * Sim.WALK_SEC_PER_HEX * walk_mult(state, a)

## Smooth server position in metres (interpolates toward the next hex of the active path).
static func world_pos(state: MatchState, a: Dictionary) -> Vector2:
	var base: Vector2 = HexGrid.to_world(a["hex"])
	var mv: Dictionary = a.get("move", {})
	if mv.is_empty() or (mv["path"] as Array).is_empty():
		return base
	var nxt: Vector2i = (mv["path"] as Array)[0]
	var need: float = step_secs(state, a, nxt)
	if need <= 0.0:
		return base
	var f: float = clampf(float(mv["acc"]) / need, 0.0, 1.0)
	return base.lerp(HexGrid.to_world(nxt), f)

static func rooted(state: MatchState, a: Dictionary) -> bool:
	return Combat.has_effect(state, a, "rooted")

static func bank(state: MatchState, a: Dictionary) -> float:
	var el: float = float(state.clock["elapsed"])
	return clampf(el - float(a.get("sync_t", 0.0)), -SYNC_SLACK, SYNC_MAX_BANK)

## Presentation reports the hex the (client-side, smoothly walking) leader stands on. Accepted only if a
## passable path exists and its walking time fits the time budget earned since the last sync (+ slack).
## Teleports and speed hacks are rejected with "too_fast"; nothing is mutated on failure.
static func sync_position(state: MatchState, a: Dictionary, to: Vector2i, events: Array) -> String:
	if not HexGrid.in_bounds(to):
		return "bad_hex"
	if to == a["hex"]:
		return ""
	if rooted(state, a):
		return "rooted"
	if WorldGen.move_cost(state.world, to) <= 0.0:
		return "impassable"
	if HexGrid.distance(a["hex"], to) > SYNC_MAX_HEXES:
		return "too_fast"
	var w: Dictionary = state.world
	var path: Array[Vector2i] = HexGrid.find_path(a["hex"], to, func(h: Vector2i) -> float: return WorldGen.move_cost(w, h), SYNC_MAX_NODES)
	if path.is_empty():
		return "no_path"
	var cost: float = 0.0
	for h in path:
		cost += step_secs(state, a, h)
	var b: float = bank(state, a)
	if cost > b + SYNC_SLACK + 1e-9:
		return "too_fast"
	a["sync_t"] = MatchState.q(float(state.clock["elapsed"]) - maxf(-SYNC_SLACK, b - cost))
	a["hex"] = to
	a["move"] = {}
	events.append({"type": &"actor_moved", "actor": a["id"], "hex": to, "synced": true})
	return ""
