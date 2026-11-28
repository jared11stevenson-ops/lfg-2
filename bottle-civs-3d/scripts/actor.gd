class_name BCActor
extends Node3D
## One animated 3D character (a third-party CC0 model). Animations come from shared libraries:
## KayKit Rig_Medium (kaykit characters + skeletons), Quaternius UAL (Elf/Orc/Imp/Puglin), or the model's own clips.

const ANIM_SRC := {
	"kaykit": ["res://assets/anims/Rig_Medium_General.glb", "res://assets/anims/Rig_Medium_MovementBasic.glb"],
	"ual": ["res://assets/anims/UAL1_Standard.glb"],
	"native": [],
}
# logical action -> candidate clip names per rig (first one present wins)
const CLIPS := {
	"kaykit": {
		"idle": ["Idle_A"], "idle2": ["Idle_B"], "walk": ["Walking_A"], "run": ["Running_A"],
		"work": ["Interact", "Use_Item"], "pick": ["PickUp"], "fight": ["Throw", "Hit_A"], "hit": ["Hit_A"],
		"death": ["Death_A"], "cheer": ["Spawn_Ground", "Jump_Idle"], "talk": ["Idle_B", "Interact"],
	},
	"ual": {
		"idle": ["Idle"], "idle2": ["Idle_Talking", "Idle"], "walk": ["Walk"], "run": ["Jog_Fwd"],
		"work": ["Interact"], "pick": ["PickUp_Table"], "fight": ["Sword_Attack", "Punch_Cross"], "hit": ["Hit_Chest"],
		"death": ["Death01"], "cheer": ["Dance"], "talk": ["Idle_Talking"],
	},
	"native": {
		"idle": ["Idle"], "idle2": ["Idle"], "walk": ["Walk"], "run": ["Run"],
		"work": ["Idle"], "pick": ["Idle"], "fight": ["Attack"], "hit": ["Jump"],
		"death": ["Death"], "cheer": ["Jump"], "talk": ["Idle"],
	},
}
const LOOPING := ["idle", "idle2", "walk", "run", "work", "pick", "talk"]

static var _src_cache := {}      # rig -> {clip name -> Animation}
static var _lib_cache := {}      # model path -> AnimationLibrary (retargeted)
static var _scene_cache := {}    # model path -> PackedScene

var race: Dictionary
var model: Node3D
var player: AnimationPlayer
var skeleton: Skeleton3D
var current := ""
var anim_lib: AnimationLibrary
var rig := "kaykit"
var rest_time := 0.0
var locked_until := 0.0          # one-shot animation lock (seconds, absolute engine time)

func setup(p_race: Dictionary) -> void:
	race = p_race
	rig = p_race.rig
	var path: String = p_race.model
	if not _scene_cache.has(path):
		_scene_cache[path] = load(path)
	model = (_scene_cache[path] as PackedScene).instantiate()
	add_child(model)
	var sq: Vector3 = p_race.get("squash", Vector3.ONE)
	# normalise any imported model to the race's target height (assets use wildly different units)
	var h := _model_height(model)
	var sc: float = float(p_race.height) * 1.7 * float(p_race.get("fix", 1.0)) / maxf(h, 0.0001)
	model.scale = Vector3(sc * sq.x, sc * sq.y, sc * sq.z)
	skeleton = _find_skeleton(model)
	_apply_tint()
	player = AnimationPlayer.new()
	player.name = "Anim"
	add_child(player)
	player.root_node = NodePath("..")
	if rig == "native":
		var native: AnimationPlayer = _find_player(model)
		if native != null:
			var lib := AnimationLibrary.new()
			var skel_path := String(get_path_to(skeleton))
			for n in native.get_animation_list():
				var a: Animation = native.get_animation(n).duplicate()
				for i in range(a.get_track_count() - 1, -1, -1):
					var bone := String(a.track_get_path(i).get_concatenated_subnames())
					if bone == "" or skeleton.find_bone(bone) < 0:
						a.remove_track(i)
					else:
						a.track_set_path(i, NodePath(skel_path + ":" + bone))
				lib.add_animation(n.get_slice("_", n.get_slice_count("_") - 1), a)
			native.queue_free()
			player.add_animation_library("", lib)
			anim_lib = lib
	else:
		if not _lib_cache.has(path):
			_lib_cache[path] = _build_library(path)
		anim_lib = _lib_cache[path]
		player.add_animation_library("", anim_lib)
	play("idle", randf() * 2.0)

func _model_height(m: Node3D) -> float:
	var lo := INF
	var hi := -INF
	var inv := m.transform.affine_inverse() if m.is_inside_tree() else Transform3D.IDENTITY
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var n: MeshInstance3D = mi
		var t := Transform3D.IDENTITY
		var cur: Node = n
		while cur != null and cur != m.get_parent():
			if cur is Node3D: t = (cur as Node3D).transform * t
			cur = cur.get_parent()
		var bb: AABB = t * n.get_aabb()
		lo = minf(lo, bb.position.y); hi = maxf(hi, bb.end.y)
	return (hi - lo) if hi > lo else 1.0

func _apply_tint() -> void:
	if not race.has("tint"): return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m: MeshInstance3D = mi
		for s in m.mesh.get_surface_count():
			var base: Material = m.get_active_material(s)
			if base is StandardMaterial3D:
				var mat: StandardMaterial3D = base.duplicate()
				mat.albedo_color = mat.albedo_color * race.tint
				m.set_surface_override_material(s, mat)

func _find_skeleton(n: Node) -> Skeleton3D:
	var l := n.find_children("*", "Skeleton3D", true, false)
	return l[0] if l.size() > 0 else null

func _find_player(n: Node) -> AnimationPlayer:
	var l := n.find_children("*", "AnimationPlayer", true, false)
	return l[0] if l.size() > 0 else null

static func _source_clips(rig_name: String) -> Dictionary:
	if _src_cache.has(rig_name): return _src_cache[rig_name]
	var out := {}
	for p in ANIM_SRC[rig_name]:
		var inst: Node = (load(p) as PackedScene).instantiate()
		var ap: AnimationPlayer = inst.find_children("*", "AnimationPlayer", true, false)[0]
		for n in ap.get_animation_list():
			out[n] = ap.get_animation(n)
		inst.free()
	_src_cache[rig_name] = out
	return out

# Rewrite every bone track of the shared clips so it drives THIS model's skeleton.
func _build_library(path: String) -> AnimationLibrary:
	var lib := AnimationLibrary.new()
	if skeleton == null: return lib
	var skel_path := String(get_path_to(skeleton))
	var wanted := {}
	for key in CLIPS[rig]:
		for clip in CLIPS[rig][key]: wanted[clip] = true
	var src := _source_clips(rig)
	for clip in wanted:
		if not src.has(clip): continue
		var a: Animation = src[clip].duplicate()
		for i in range(a.get_track_count() - 1, -1, -1):
			var tp := a.track_get_path(i)
			var bone := String(tp.get_concatenated_subnames())
			if bone == "" or skeleton.find_bone(bone) < 0:
				a.remove_track(i)
				continue
			a.track_set_path(i, NodePath(skel_path + ":" + bone))
		a.loop_mode = Animation.LOOP_NONE
		lib.add_animation(clip, a)
	return lib

func _resolve(action: String) -> String:
	var names: Array = CLIPS[rig].get(action, [])
	for n in names:
		if anim_lib != null and anim_lib.has_animation(n): return n
	return ""

func play(action: String, offset: float = 0.0, blend: float = 0.2) -> void:
	if player == null: return
	var clip := _resolve(action)
	if clip == "": return
	var key := action
	if key == current: return
	current = key
	var a: Animation = anim_lib.get_animation(clip)
	a.loop_mode = Animation.LOOP_LINEAR if LOOPING.has(action) else Animation.LOOP_NONE
	player.play(clip, blend)
	if offset > 0.0 and a.length > 0.0: player.seek(fmod(offset, a.length), true)

func play_once(action: String, hold: float = 0.0) -> void:
	current = ""
	play(action)
	locked_until = Time.get_ticks_msec() / 1000.0 + hold

func is_locked() -> bool:
	return Time.get_ticks_msec() / 1000.0 < locked_until

func set_speed(s: float) -> void:
	if player != null: player.speed_scale = s
