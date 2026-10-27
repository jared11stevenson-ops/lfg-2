class_name CompanionLayer
extends Node3D
## Draws the player's companions: followers trail the leader (back-left / back-right, hopping to keep up), posted ones potter about their holding while you are near.
## Reads state only (Rules: actor["companions"]). At most 6 rigs, 3-6 meshes each. Hungry ones sit down (stop moving) and shrink a little so the player notices.
const FOLLOW_GAP := 2.6
const FOLLOW_SPEED := 8.5
const TELEPORT_DIST := 40.0
const POST_RANGE := 110.0
const VIEW_SCALE := 1.45      # the camera sits 46 m up: a 1 m creature must still read on a phone
var world: WorldData
var player: Node3D
var state: Object
var rigs: Dictionary = {}          # kind -> {rig:CharacterRig, target:Vector3, mode:String, idx:int, fed:bool}
var _t: float = 0.0
var _sync_t: float = 0.0

func _init() -> void:
	name = "CompanionLayer"

func bind_state(s: Object) -> void:
	state = s
	sync()

func rig_for(kind: String) -> CharacterRig:
	return rigs[kind]["rig"] if rigs.has(kind) else null

func rig_count() -> int:
	return rigs.size()

func _leader() -> Dictionary:
	if state == null:
		return {}
	var acts: Variant = state.get("actors")
	if not (acts is Dictionary):
		return {}
	return (acts as Dictionary).get(int(state.get("player_id")), {})

func _ground(p: Vector3) -> float:
	return world.height_at(p.x, p.z) if world != null else 0.0

## Reconcile rigs with the leader's companion list. Cheap; called on events and every half second.
func sync() -> void:
	var a: Dictionary = _leader()
	var list: Array = a.get("companions", [])
	var want: Dictionary = {}
	var follow_i: int = 0
	var post_i: Dictionary = {}
	for c in list:
		var kind: String = String(c["kind"])
		var mode: String = String(c["post"])
		var pp: Vector3 = player.position if player != null else Vector3.ZERO
		var target: Vector3 = pp
		var idx: int = 0
		if mode == "follow":
			idx = follow_i
			follow_i += 1
			var side: float = -1.0 if idx % 2 == 0 else 1.0
			var yaw: float = player.rotation.y if player != null else 0.0
			var off: Vector3 = Basis(Vector3.UP, yaw) * Vector3(side * 1.6, 0.0, FOLLOW_GAP + 1.0 * float(idx / 2))
			target = pp + off
		elif mode == "hold" and world != null and state != null:
			var h: Dictionary = (state.get("holdings") as Dictionary).get(int(c["hold"]), {})
			if h.is_empty():
				continue
			var off2: Vector2i = HexMath.axial_to_offset(h["hex"])
			var cen: Vector2 = HexMath.offset_center(off2.x, off2.y)
			var n: int = int(post_i.get(int(c["hold"]), 0))
			post_i[int(c["hold"])] = n + 1
			var ang: float = float(int(c["hold"]) * 2 + n * 2) + 0.7
			target = Vector3(cen.x + cos(ang) * 6.0, 0.0, cen.y + sin(ang) * 6.0)
			if Vector2(target.x - pp.x, target.z - pp.z).length() > POST_RANGE:
				continue
		else:
			continue      # resting: indoors
		target.y = _ground(target)
		want[kind] = true
		if not rigs.has(kind):
			var rig: CharacterRig = CompanionModels.build(kind)
			add_child(rig)
			rig.position = target
			rigs[kind] = {"rig": rig, "target": target, "mode": mode, "idx": idx, "fed": bool(c.get("fed", false)), "wander": float(randi() % 628) / 100.0}
		var e: Dictionary = rigs[kind]
		e["target"] = target
		e["mode"] = mode
		e["idx"] = idx
		e["fed"] = bool(c.get("fed", false))
		(e["rig"] as CharacterRig).scale = Vector3.ONE * VIEW_SCALE * (1.0 if bool(c.get("fed", false)) else 0.82)
	for k in rigs.keys():
		if not want.has(k):
			(rigs[k]["rig"] as Node).queue_free()
			rigs.erase(k)

func on_events(events: Array) -> void:
	for e in events:
		match String(e.get("type", "")):
			"companion_adopted", "companion_assigned", "companion_dismissed", "companion_fed", "companion_hungry":
				sync()
				return

func _process(dt: float) -> void:
	_t += dt
	_sync_t -= dt
	if _sync_t <= 0.0:
		_sync_t = 0.5
		sync()
	for kind in rigs.keys():
		var e: Dictionary = rigs[kind]
		var rig: CharacterRig = e["rig"]
		var before: Vector3 = rig.position
		var tgt: Vector3 = e["target"]
		if String(e["mode"]) == "hold":
			e["wander"] = float(e["wander"]) + dt * 0.4
			tgt += Vector3(cos(float(e["wander"])), 0.0, sin(float(e["wander"]))) * 1.6
		if not bool(e["fed"]):
			tgt = before      # a hungry creature sits where it is
		var to: Vector3 = tgt - rig.position
		to.y = 0.0
		var dist: float = to.length()
		if dist > TELEPORT_DIST:
			rig.position = tgt
		elif dist > 0.25:
			var spd: float = FOLLOW_SPEED * clampf(dist / 4.0, 0.25, 1.4)
			rig.position += to.normalized() * minf(spd * dt, dist)
		rig.position.y = _ground(rig.position)
		var mv := Vector2(rig.position.x - before.x, rig.position.z - before.z)
		rig.speed01 = clampf(mv.length() / maxf(dt, 0.0001) / FOLLOW_SPEED, 0.0, 1.0)
		if mv.length() > 0.002:
			rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-mv.x, -mv.y), clampf(9.0 * dt, 0.0, 1.0))
		elif player != null and String(e["mode"]) == "follow":
			var look := Vector2(player.position.x - rig.position.x, player.position.z - rig.position.z)
			if look.length() > 0.5:
				rig.rotation.y = lerp_angle(rig.rotation.y, atan2(-look.x, -look.y), clampf(4.0 * dt, 0.0, 1.0))
