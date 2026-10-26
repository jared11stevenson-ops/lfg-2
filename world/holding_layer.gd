class_name HoldingLayer
extends Node3D
## Building models placed around each holding from Rules state (state.holdings[id].buildings). One MultiMesh per
## building type, so draw calls = number of building kinds in use (3 today), however many holdings have them.
var world: WorldData
var material: ShaderMaterial
var counts: Dictionary = {} # building id -> instances
var placed_last: Array = [] # last placement list (inspectable; MultiMesh buffers are write-only on the dummy renderer)
var _mmis: Dictionary = {}

func _init() -> void:
	name = "HoldingLayer"
	material = ShaderMaterial.new()
	material.shader = load("res://world/shaders/world.gdshader")
	material.set_shader_parameter("hide_unseen", true)

func bind_fog(tex: Texture2D) -> void:
	material.set_shader_parameter("fow_tex", tex)

func _mmi(id: String) -> MultiMeshInstance3D:
	if _mmis.has(id):
		return _mmis[id]
	var mmi := MultiMeshInstance3D.new()
	mmi.name = "B_" + id.get_slice("/", 1)
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = BuildingModels.mesh_for(id)
	mmi.multimesh = mm
	mmi.material_override = material
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mmi)
	_mmis[id] = mmi
	return mmi

## placed: Array[{id:String(building), pos:Vector3, yaw:float}]
func set_buildings(placed: Array) -> void:
	placed_last = placed
	var by: Dictionary = {}
	for b in placed:
		var id: String = String(b["id"])
		if not by.has(id):
			by[id] = []
		(by[id] as Array).append(b)
	counts.clear()
	for id in _mmis.keys():
		if not by.has(id):
			(_mmis[id] as MultiMeshInstance3D).multimesh.instance_count = 0
	for id in by:
		var list: Array = by[id]
		var mm: MultiMesh = _mmi(id).multimesh
		mm.instance_count = list.size()
		counts[id] = list.size()
		for i in list.size():
			var b: Dictionary = list[i]
			mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(b["yaw"])), b["pos"]))

## Buildings stand on their Rules sites (holding.sites: "q,r" -> building id) when present; otherwise on the slot ring.
func sync_from_state(state: Object) -> void:
	var hs: Variant = state.get("holdings")
	if not (hs is Dictionary) or world == null:
		return
	var placed: Array = []
	var ids: Array = (hs as Dictionary).keys()
	ids.sort()
	for hid in ids:
		var h: Dictionary = hs[hid]
		var off: Vector2i = HexMath.axial_to_offset(h["hex"])
		var cen: Vector2 = HexMath.offset_center(off.x, off.y)
		var list: Array = (h.get("buildings", []) as Array).duplicate()
		var sites: Dictionary = h.get("sites", {})
		var skeys: Array = sites.keys()
		skeys.sort()
		for k in skeys:
			var bid: String = String(sites[k])
			if not list.has(bid):
				continue
			list.erase(bid)
			var parts: PackedStringArray = String(k).split(",")
			var c: Vector2 = BuildingModels.site_world(Vector2i(int(parts[0]), int(parts[1])))
			var p: Vector3 = Vector3(c.x, world.height_at(c.x, c.y), c.y)
			placed.append({"id": bid, "pos": p, "yaw": atan2(-(cen.x - p.x), -(cen.y - p.z))})
		for i in list.size():
			var p2: Vector3 = BuildingModels.slot_position(cen, i)
			p2.y = world.height_at(p2.x, p2.z)
			placed.append({"id": String(list[i]), "pos": p2, "yaw": atan2(-(cen.x - p2.x), -(cen.y - p2.z))})
	set_buildings(placed)
