class_name ActorLayer
extends Node3D
## Renders non-player actors from Rules state: wild enemies (6 archetypes), AI faction leaders (raiders), plus decorative
## villagers and merchants at holdings. Reads state only. Draw-call budget: at most MAX_RIGS actor rigs within RANGE metres
## (about 5 meshes each) + MAX_NPC_HOLDINGS holdings of 1-2 NPC rigs; everything else is not instantiated.
signal player_hurt(amount: int)
signal enemy_nearby(count: int)
const RANGE := 150.0
const MAX_RIGS := 22
const MAX_NPC_HOLDINGS := 5
const CORPSE_SECONDS := 3.0
const MOVE_SPEED := 9.0

var world: WorldData
var fog: FogOfWar
var fx: CombatFx
var state: Object
var player: Node3D
var player_id: int = 1
var rigs: Dictionary = {} # actor id -> {rig:CharacterRig, pos:Vector3, dead_t:float}
var npcs: Dictionary = {} # holding id -> Array[CharacterRig]
var shadows: bool = false
var _refresh_t: float = 0.0

func _init() -> void:
	name = "ActorLayer"
	fx = CombatFx.new()
	add_child(fx)

func set_cast_shadows(on: bool) -> void:
	shadows = on
	for e in rigs.values():
		(e["rig"] as CharacterRig).set_cast_shadows(on)
	for list in npcs.values():
		for r in list:
			(r as CharacterRig).set_cast_shadows(on)

func bind_state(s: Object) -> void:
	state = s
	refresh()

func rig_for(actor_id: int) -> CharacterRig:
	return rigs[actor_id]["rig"] if rigs.has(actor_id) else null

func rig_count() -> int:
	return rigs.size()

func npc_rig_count() -> int:
	var n := 0
	for a in npcs.values():
		n += (a as Array).size()
	return n

func _actor_world_pos(a: Dictionary) -> Vector3:
	var id: int = int(a["id"])
	var c: Vector2
	if state is MatchState:
		c = Rules.actor_pos(state as MatchState, id) # smooth metres along the actor's path (same frame as HexMath)
	else:
		var off: Vector2i = HexMath.axial_to_offset(a["hex"])
		c = HexMath.offset_center(off.x, off.y)
	c += Vector2(float((id * 37) % 7) - 3.0, float((id * 53) % 7) - 3.0) * 0.5
	return Vector3(c.x, world.height_at(c.x, c.y) if world != null else 0.0, c.y)

func _visible_hex(a: Dictionary) -> bool:
	if fog == null:
		return true
	return fog.state_of(HexMath.axial_to_offset(a["hex"])) == FogOfWar.VISIBLE

func _is_drawn_kind(a: Dictionary) -> bool:
	var k: String = String(a.get("kind", ""))
	return k == "enemy" or k == "ai_leader"

func _make_rig(a: Dictionary) -> CharacterRig:
	if String(a["kind"]) == "enemy":
		return CharacterKit.build_enemy(String(a.get("archetype", "")))
	return CharacterKit.build_npc("raider", int(a.get("faction", 0)))

## Reconcile rigs with state. Cheap (one pass over actors); called every 0.25 s and after events.
func refresh() -> void:
	if state == null or world == null:
		return
	var actors: Variant = state.get("actors")
	if not (actors is Dictionary):
		return
	var pp := Vector3.ZERO
	if player != null:
		pp = player.position
	var cands: Array[Dictionary] = []
	for id in actors:
		var a: Dictionary = actors[id]
		if int(id) == player_id or not _is_drawn_kind(a):
			continue
		if not a["alive"] and not rigs.has(int(id)):
			continue
		var wp: Vector3 = _actor_world_pos(a)
		var d: float = Vector2(wp.x - pp.x, wp.z - pp.z).length()
		if d > RANGE and not rigs.has(int(id)):
			continue
		cands.append({"id": int(id), "a": a, "d": d, "wp": wp})
	cands.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["d"] < y["d"])
	var want: Dictionary = {}
	var n := 0
	for c in cands:
		if n >= MAX_RIGS:
			break
		var a2: Dictionary = c["a"]
		var id2: int = c["id"]
		var drawn: bool = _visible_hex(a2) or rigs.has(id2) and not a2["alive"]
		if c["d"] > RANGE * 1.15 or not drawn:
			continue
		want[id2] = true
		n += 1
		if not rigs.has(id2):
			if not a2["alive"]:
				continue
			var rig: CharacterRig = _make_rig(a2)
			add_child(rig)
			rig.set_cast_shadows(shadows)
			rig.position = c["wp"]
			rigs[id2] = {"rig": rig, "pos": c["wp"], "dead_t": 0.0}
		var entry: Dictionary = rigs[id2]
		entry["pos"] = c["wp"]
		if not a2["alive"]:
			(entry["rig"] as CharacterRig).play(&"death")
	for id3 in rigs.keys():
		if not want.has(id3):
			var r3: CharacterRig = rigs[id3]["rig"]
			r3.queue_free()
			rigs.erase(id3)
	_refresh_npcs()

func _refresh_npcs() -> void:
	var pp := Vector3.ZERO
	if player != null:
		pp = player.position
	var near: Array[Dictionary] = []
	for h in world.holdings:
		var c: Vector2 = HexMath.offset_center(h["hex"].x, h["hex"].y)
		var d: float = Vector2(c.x - pp.x, c.y - pp.z).length()
		if d < 90.0 and (fog == null or fog.is_explored(h["hex"])):
			near.append({"h": h, "d": d})
	near.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["d"] < y["d"])
	var keep: Dictionary = {}
	for i in mini(near.size(), MAX_NPC_HOLDINGS):
		var h: Dictionary = near[i]["h"]
		var hid: int = int(h["id"])
		keep[hid] = true
		if npcs.has(hid):
			continue
		var list: Array = []
		var cen: Vector2 = HexMath.offset_center(h["hex"].x, h["hex"].y)
		var merchant: bool = int(h.get("owner", 0)) == -1
		var count: int = 1 if merchant else 2
		for k in count:
			var rig: CharacterRig = CharacterKit.build_npc("merchant" if merchant else "villager", hid + k)
			add_child(rig)
			rig.set_cast_shadows(shadows)
			var ang: float = float(hid * 3 + k * 5)
			var px: float = cen.x + cos(ang) * (4.5 + 2.0 * float(k))
			var pz: float = cen.y + sin(ang) * (4.5 + 2.0 * float(k)) + 3.0
			rig.position = Vector3(px, world.height_at(px, pz), pz)
			rig.rotation.y = ang
			list.append(rig)
		npcs[hid] = list
	for hid2 in npcs.keys():
		if not keep.has(hid2):
			for r in npcs[hid2]:
				(r as Node).queue_free()
			npcs.erase(hid2)

func on_events(events: Array) -> void:
	var dirty := false
	for e in events:
		match e.get("type", &""):
			&"actor_damaged":
				var id: int = int(e.get("actor", -1))
				var amount: int = int(e.get("amount", 0))
				var to_player: bool = id == player_id
				var rig: CharacterRig = rig_for(id)
				if to_player:
					player_hurt.emit(amount)
					var pr: Variant = player.get("_rig") if player != null else null
					if pr is CharacterRig:
						(pr as CharacterRig).play(&"hurt")
					if player != null:
						fx.spawn_number(player.position + Vector3(0, 3.0, 0), amount, true)
				elif rig != null:
					rig.play(&"hurt")
					fx.spawn_number(rig.position + Vector3(0, rig.nominal_height + 0.5, 0), amount, false)
			&"actor_attacked":
				var rg: CharacterRig = rig_for(int(e.get("actor", -1)))
				if rg != null:
					rg.play(&"attack")
					var tgt: Variant = _target_pos(int(e.get("target", -1)))
					if tgt is Vector3:
						_face(rg, tgt)
				elif int(e.get("actor", -1)) == player_id and player != null and player.has_method("play_attack"):
					player.call("play_attack")
			&"actor_died":
				var rd: CharacterRig = rig_for(int(e.get("actor", -1)))
				if rd != null:
					rd.play(&"death")
				dirty = true
			&"enemy_telegraph":
				var rt: CharacterRig = rig_for(int(e.get("enemy", -1)))
				if rt != null and e.has("target_hex"):
					var off: Vector2i = HexMath.axial_to_offset(e["target_hex"])
					var c: Vector2 = HexMath.offset_center(off.x, off.y)
					_face(rt, Vector3(c.x, 0, c.y))
					rt.play(&"attack")
					rt.anim_t = -float(e.get("windup", 0.0)) # hold the wind-up pose until the hit lands
			&"actor_moved", &"ability_used":
				pass
	if dirty:
		refresh()

func _target_pos(id: int) -> Variant:
	if rigs.has(id):
		return (rigs[id]["rig"] as Node3D).position
	if id == player_id and player != null:
		return player.position
	return null

func _face(rig: Node3D, p: Vector3) -> void:
	var d := Vector2(p.x - rig.position.x, p.z - rig.position.z)
	if d.length() > 0.1:
		rig.rotation.y = atan2(-d.x, -d.y)

## Positions of living enemies within `max_dist` of the player (feeds the screen-edge danger indicator).
func threat_positions(max_dist: float = 60.0) -> Array[Vector3]:
	var out: Array[Vector3] = []
	if player == null:
		return out
	for id in rigs:
		var r: CharacterRig = rigs[id]["rig"]
		if r.dead or r.look_id.begins_with("npc/"):
			continue
		if Vector2(r.position.x - player.position.x, r.position.z - player.position.z).length() <= max_dist:
			out.append(r.position)
	return out

func _process(dt: float) -> void:
	_refresh_t -= dt
	if _refresh_t <= 0.0:
		_refresh_t = 0.25
		refresh()
	var near := 0
	for id in rigs.keys():
		var entry: Dictionary = rigs[id]
		var rig: CharacterRig = entry["rig"]
		var target: Vector3 = entry["pos"]
		var before: Vector3 = rig.position
		if not rig.dead:
			var to: Vector3 = target - rig.position
			to.y = 0.0
			var step: float = MOVE_SPEED * dt
			if to.length() > step:
				rig.position += to.normalized() * step
			else:
				rig.position = Vector3(target.x, rig.position.y, target.z)
			rig.position.y = world.height_at(rig.position.x, rig.position.z) if world != null else 0.0
			var mv := Vector2(rig.position.x - before.x, rig.position.z - before.z)
			rig.speed01 = clampf(mv.length() / maxf(dt, 0.0001) / MOVE_SPEED, 0.0, 1.0)
			if mv.length() > 0.001 and rig.anim != &"attack":
				rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-mv.x, -mv.y), clampf(10.0 * dt, 0.0, 1.0))
			near += 1
		else:
			entry["dead_t"] = float(entry["dead_t"]) + dt
			if float(entry["dead_t"]) > CORPSE_SECONDS:
				rig.queue_free()
				rigs.erase(id)
	enemy_nearby.emit(near)
