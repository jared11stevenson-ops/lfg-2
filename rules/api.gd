class_name Rules
extends RefCounted
## Public Rules API (frozen contract). Everything is deterministic given (seed, command stream, tick stream).
const COMMAND_TYPES: Array[StringName] = [&"move_intent", &"plant", &"water", &"harvest", &"craft", &"build", &"demolish", &"trade", &"eat",
	&"attack", &"use_ability", &"capture", &"steal", &"set_policy", &"rest", &"move_to_pos", &"sync_position",
	&"unlock_skill", &"scout", &"escort", &"truce", &"ransom", &"sabotage", &"interact_poi", &"accept_quest", &"abandon_quest", &"turn_in"]
const MAX_PATH := 160

static func new_match(seed: int, class_id: StringName, opts: Dictionary = {}) -> MatchState:
	return Setup.build(seed, class_id, opts)

static func tick(state: MatchState, dt: float) -> Array[Dictionary]:
	var events: Array = []
	Sim.run(state, dt, events)      # Sim.advance feeds each step's events to Standing.observe (deeds, skill points)
	var out: Array[Dictionary] = []
	for e in events:
		out.append(e)
	return out

static func _fail(err: String) -> Dictionary:
	return {"ok": false, "error": err, "events": [] as Array[Dictionary]}

static func apply(state: MatchState, cmd: Dictionary) -> Dictionary:
	if state == null:
		return _fail("no_state")
	if state.over:
		return _fail("match_over")
	if not cmd.has("type") or not cmd.has("actor") or not cmd.has("seq"):
		return _fail("malformed")
	var t_raw: Variant = cmd["type"]
	if typeof(t_raw) != TYPE_STRING_NAME and typeof(t_raw) != TYPE_STRING:
		return _fail("malformed")
	var t: StringName = StringName(String(t_raw))
	if not COMMAND_TYPES.has(t):
		return _fail("unknown_command")
	var aid: int = CmdUtil.parse_id(cmd["actor"])
	var a: Dictionary = state.actors.get(aid, {})
	if a.is_empty() or a["kind"] == "enemy":
		return _fail("unknown_actor")
	if not a["alive"]:
		return _fail("actor_dead")
	var seq: int = CmdUtil.parse_id(cmd["seq"])
	if seq < 1:
		return _fail("bad_seq")
	if seq <= int(a["last_seq"]):
		return _fail("duplicate_seq" if seq == int(a["last_seq"]) else "stale_seq")
	var args: Variant = cmd.get("args", {})
	if typeof(args) != TYPE_DICTIONARY:
		return _fail("malformed")
	var events: Array = []
	var err: String = _dispatch(state, a, t, args, events)
	if err != "":
		return _fail(err)
	a["last_seq"] = seq
	Standing.observe(state, events, 0)
	Pois.observe(state, events, 0)
	Quests.observe(state, events, 0, int(a["id"]))
	var out: Array[Dictionary] = []
	for e in events:
		out.append(e)
	return {"ok": true, "error": "", "events": out}

static func _dispatch(state: MatchState, a: Dictionary, t: StringName, args: Dictionary, events: Array) -> String:
	match t:
		&"move_intent": return _move(state, a, args)
		&"move_to_pos": return _move_to_pos(state, a, args)
		&"sync_position": return _sync(state, a, args, events)
		&"plant": return Farming.plant(state, a, args, events)
		&"water": return Farming.water(state, a, args, events)
		&"harvest": return Farming.harvest(state, a, args, events)
		&"craft": return Farming.craft(state, a, args, events)
		&"eat": return Farming.eat(state, a, args, events)
		&"build": return Economy.build(state, a, args, events)
		&"demolish": return Economy.demolish(state, a, args, events)
		&"trade": return Economy.trade(state, a, args, events)
		&"set_policy": return Economy.set_policy(state, a, args, events)
		&"rest": return Economy.rest(state, a, events)
		&"attack": return _attack(state, a, args, events)
		&"use_ability": return Abilities.use(state, a, args, events)
		&"capture": return Conquest.capture(state, a, args, events)
		&"steal": return Conquest.steal(state, a, args, events)
		&"unlock_skill": return Skills.unlock(state, a, args, events)
		&"scout": return PurgeActions.scout(state, a, args, events)
		&"escort": return PurgeActions.escort(state, a, args, events)
		&"truce": return PurgeActions.truce(state, a, args, events)
		&"ransom": return PurgeActions.ransom(state, a, args, events)
		&"sabotage": return PurgeActions.sabotage(state, a, args, events)
		&"interact_poi": return Pois.interact(state, a, args, events)
		&"accept_quest": return Quests.accept(state, a, args, events)
		&"abandon_quest": return Quests.abandon(state, a, args, events)
		&"turn_in": return Quests.turn_in(state, a, args, events)
	return "unknown_command"

static func _move(state: MatchState, a: Dictionary, args: Dictionary) -> String:
	if args.get("stop", false) == true:
		a["move"] = {}
		return ""
	var hv: Variant = CmdUtil.parse_hex(args.get("to"))
	if hv == null:
		return "bad_hex"
	var to: Vector2i = hv
	if to == a["hex"]:
		return "already_there"
	if WorldGen.move_cost(state.world, to) <= 0.0:
		return "impassable"
	var w: Dictionary = state.world
	var path: Array[Vector2i] = HexGrid.find_path(a["hex"], to, func(h: Vector2i) -> float: return WorldGen.move_cost(w, h))
	if path.is_empty():
		return "no_path"
	if path.size() > MAX_PATH:
		return "too_far"
	a["move"] = {"path": path, "acc": 0.0}
	return ""

## Walk toward a world position (metres, x east / y south, see HexGrid.to_world). Same rules as move_intent.
static func _move_to_pos(state: MatchState, a: Dictionary, args: Dictionary) -> String:
	var p: Variant = args.get("pos")
	if typeof(p) == TYPE_VECTOR2:
		p = [p.x, p.y]
	if typeof(p) != TYPE_ARRAY or (p as Array).size() != 2:
		return "bad_pos"
	for c in p:
		if (typeof(c) != TYPE_INT and typeof(c) != TYPE_FLOAT) or is_nan(float(c)) or is_inf(float(c)) or absf(float(c)) > 100000.0:
			return "bad_pos"
	var h: Vector2i = HexGrid.from_world(Vector2(float(p[0]), float(p[1])))
	if not HexGrid.in_bounds(h):
		return "bad_hex"
	return _move(state, a, {"to": h})

## Presentation-driven leader position: {hex:[q,r]}. Validated against speed/path (Movement.sync_position).
static func _sync(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	var hv: Variant = CmdUtil.parse_hex(args.get("hex"))
	if hv == null:
		return "bad_hex"
	return Movement.sync_position(state, a, hv, events)

## Smooth authoritative position in metres for any actor (interpolates along its walking path).
static func actor_pos(state: MatchState, actor_id: int) -> Vector2:
	var a: Dictionary = state.actors.get(actor_id, {})
	return Vector2.ZERO if a.is_empty() else Movement.world_pos(state, a)

static func _attack(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	var tid: int = CmdUtil.parse_id(args.get("target"))
	var t: Dictionary = state.actors.get(tid, {})
	if t.is_empty() or not t["alive"] or tid == int(a["id"]):
		return "bad_target"
	if int(t["faction"]) == int(a["faction"]):
		return "friendly"
	if t["kind"] != "enemy":
		if int(Combat.class_mod(a, "pacifist", 0)) > 0:
			return "pacifist"
		if Combat.has_effect(state, a, "truce"):
			return "truce_active"
	if HexGrid.distance(a["hex"], t["hex"]) > 1:
		return "too_far"
	if t["kind"] != "enemy" and state.phase != &"PURGE_ACTIVE":
		return "not_purge"
	if not Combat.ready(state, a, "attack"):
		return "cooldown"
	Combat.set_cd(state, a, "attack", 1.0)
	var dmg: int = Combat.calc_damage(state, a, t)
	events.append({"type": &"actor_attacked", "actor": a["id"], "target": tid, "damage": dmg})
	Combat.hurt(state, tid, dmg, int(a["id"]), events, "attack")
	return ""
