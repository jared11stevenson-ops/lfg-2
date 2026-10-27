class_name PoiLayer
extends Node3D
## Points of interest in the 3D world: one MultiMesh per prop type (7) plus two beacon needles (gold = rewards waiting this week, grey = spent).
## Only DISCOVERED points are drawn (the fog shader also hides them in unexplored hexes). Rules truth: state.world["pois"], state.poi_state, actor["pois_seen"].
var world: WorldData
var material: ShaderMaterial
var counts: Dictionary = {}          # prop key -> instances (inspectable by tests; MultiMesh buffers are write-only on the dummy renderer)
var placed_last: Array = []          # [{id, prop, pos:Vector3, yaw, available}]
var show_all: bool = false           # debug / capture: draw undiscovered points too
var _mmis: Dictionary = {}

func _init() -> void:
	name = "PoiLayer"
	material = ShaderMaterial.new()
	material.shader = load("res://world/shaders/world.gdshader")
	material.set_shader_parameter("hide_unseen", true)

func bind_fog(tex: Texture2D) -> void:
	material.set_shader_parameter("fow_tex", tex)

func _mmi(key: String) -> MultiMeshInstance3D:
	if _mmis.has(key):
		return _mmis[key]
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "P_" + key
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = PoiModels.mesh_for(key)
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_mmis[key] = mmi
	return mmi

## placed: Array[{id:int, prop:String, pos:Vector3, yaw:float, available:bool}]
func set_pois(placed: Array) -> void:
	placed_last = placed
	var by: Dictionary = {}
	for p in placed:
		var key: String = String(p["prop"])
		if not by.has(key):
			by[key] = []
		(by[key] as Array).append(Transform3D(Basis(Vector3.UP, float(p["yaw"])), p["pos"]))
		var bk: String = "beacon_on" if bool(p["available"]) else "beacon_off"
		if not by.has(bk):
			by[bk] = []
		(by[bk] as Array).append(Transform3D(Basis(Vector3.UP, 0.0), p["pos"]))
	counts.clear()
	for key in _mmis.keys():
		if not by.has(key):
			(_mmis[key] as MultiMeshInstance3D).multimesh.instance_count = 0
	for key in by:
		var list: Array = by[key]
		var mm: MultiMesh = _mmi(key).multimesh
		mm.instance_count = list.size()
		counts[key] = list.size()
		for i in list.size():
			mm.set_instance_transform(i, list[i])

## From Rules state: the player's discovered points (or all of them with show_all), standing on the terrain.
func sync_from_state(state: Object) -> void:
	if world == null:
		return
	var w: Variant = state.get("world")
	if not (w is Dictionary):
		return
	var actors: Variant = state.get("actors")
	var pa: Dictionary = (actors as Dictionary).get(int(state.get("player_id")), {}) if actors is Dictionary else {}
	var seen: Array = pa.get("pois_seen", [])
	var ps: Variant = state.get("poi_state")
	var week: int = (int(state.get("clock")["day"]) - 1) / 7
	var placed: Array = []
	for p in (w as Dictionary).get("pois", []):
		var id: int = int(p["id"])
		if not show_all and not seen.has(id):
			continue
		var off: Vector2i = HexMath.axial_to_offset(p["hex"])
		var c: Vector2 = HexMath.offset_center(off.x, off.y)
		var claimed: int = int((ps as Dictionary).get(id, {}).get("claimed_week", -1)) if ps is Dictionary else -1
		var t: Dictionary = Content.poi_types().get(String(p["type"]), {})
		placed.append({"id": id, "prop": String(t.get("prop", "hut")), "pos": Vector3(c.x, world.height_at(c.x, c.y), c.y), "yaw": float(id % 7) * 0.9, "available": claimed < week})
	set_pois(placed)

## Closest point within `range_m` of a world position -> {id, prop, dist} or {}. The interact prompt uses it.
func nearest(pos: Vector3, range_m: float = 9.0) -> Dictionary:
	var best: Dictionary = {}
	var bd: float = range_m
	for p in placed_last:
		var d: float = Vector2(pos.x, pos.z).distance_to(Vector2((p["pos"] as Vector3).x, (p["pos"] as Vector3).z))
		if d < bd:
			bd = d
			best = {"id": p["id"], "prop": p["prop"], "dist": d, "available": p["available"]}
	return best
