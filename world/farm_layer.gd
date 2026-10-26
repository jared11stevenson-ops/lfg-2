class_name FarmLayer
extends Node3D
## Visuals for farm plots. One MultiMesh per growth stage (<= 6 draw calls for any number of plots).
## Gameplay truth lives in Rules; presentation calls set_plot()/remove_plot() from events or state sync.
enum Stage { TILLED, SEEDED, SPROUT, GROWING, RIPE, WILTED }
const STAGE_NAMES: Array[String] = ["Tilled", "Seeded", "Sprout", "Growing", "Ripe", "Wilted"]
const PLOT_SIZE := 5.0

var world: WorldData
var plots: Dictionary = {} # id -> {pos:Vector2, stage:int, watered:bool, tint:Color}
var material: ShaderMaterial
var _mmis: Array[MultiMeshInstance3D] = []
var _dirty := false

func _init() -> void:
	name = "FarmLayer"
	material = ShaderMaterial.new()
	material.shader = load("res://world/shaders/world.gdshader")
	material.set_shader_parameter("hide_unseen", true)
	for s in STAGE_NAMES.size():
		var mmi := MultiMeshInstance3D.new()
		mmi.name = "Plots_" + STAGE_NAMES[s]
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_colors = true
		mm.mesh = stage_mesh(s)
		mm.instance_count = 0
		mmi.multimesh = mm
		mmi.material_override = material
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mmi)
		_mmis.append(mmi)

func bind_fog(tex: Texture2D) -> void:
	material.set_shader_parameter("fow_tex", tex)

func slot_position(hex: Vector2i, slot: int) -> Vector2:
	var c: Vector2 = HexMath.offset_center(hex.x, hex.y)
	var offs: Array[Vector2] = [Vector2(-3.2, -2.6), Vector2(3.2, -2.6), Vector2(-3.2, 3.0), Vector2(3.2, 3.0)]
	return c + offs[slot % 4]

func set_plot(id: Variant, pos_xz: Vector2, stage: int, watered: bool = false, tint: Color = Color.WHITE) -> void:
	plots[id] = {"pos": pos_xz, "stage": clampi(stage, 0, STAGE_NAMES.size() - 1), "watered": watered, "tint": tint}
	_dirty = true

func remove_plot(id: Variant) -> void:
	if plots.erase(id):
		_dirty = true

func hex_has_plot(hex: Vector2i) -> bool:
	for p in plots.values():
		var pos: Vector2 = p["pos"]
		if HexMath.world_to_offset(pos.x, pos.y) == hex:
			return true
	return false

## Rebuild every plot from Rules state (state.plots: "q,r" -> {crop, age, watered, ...}). Cheap; call on crop events.
func sync_from_state(state: Object) -> void:
	var src: Variant = state.get("plots")
	if not (src is Dictionary):
		return
	var keep: Dictionary = {}
	for k in src:
		var p: Dictionary = src[k]
		var parts: PackedStringArray = String(k).split(",")
		var off: Vector2i = HexMath.axial_to_offset(Vector2i(int(parts[0]), int(parts[1])))
		var c: Vector2 = HexMath.offset_center(off.x, off.y)
		var grow_days: int = 3
		var crop: Variant = Content.crop(String(p.get("crop", "")))
		if crop is Dictionary and (crop as Dictionary).has("grow_days"):
			grow_days = maxi(int(crop["grow_days"]), 1)
		var st: int = stage_for_age(int(p.get("age", 0)), grow_days)
		var tint := Color.WHITE
		keep[k] = true
		if not plots.has(k) or plots[k]["stage"] != st or plots[k]["watered"] != bool(p.get("watered", false)):
			set_plot(k, c, st, bool(p.get("watered", false)), tint)
	for k in plots.keys():
		if not keep.has(k):
			remove_plot(k)

static func stage_for_age(age: int, grow_days: int) -> int:
	if age >= grow_days:
		return Stage.RIPE
	if age <= 0:
		return Stage.SEEDED
	var f: float = float(age) / float(grow_days)
	return Stage.SPROUT if f < 0.5 else Stage.GROWING

func stage_of(id: Variant) -> int:
	return plots[id]["stage"] if plots.has(id) else -1

func count_in_stage(s: int) -> int:
	var n := 0
	for p in plots.values():
		if p["stage"] == s:
			n += 1
	return n

func _process(_dt: float) -> void:
	if _dirty:
		rebuild()

func rebuild() -> void:
	_dirty = false
	for s in STAGE_NAMES.size():
		var list: Array[Dictionary] = []
		for p in plots.values():
			if p["stage"] == s:
				list.append(p)
		var mm: MultiMesh = _mmis[s].multimesh
		mm.instance_count = list.size()
		for i in list.size():
			var p: Dictionary = list[i]
			var pos: Vector2 = p["pos"]
			var y: float = world.height_at(pos.x, pos.y) if world != null else 0.0
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, Vector3(pos.x, y, pos.y)))
			var tint: Color = p["tint"]
			if p["watered"]:
				tint = Color(tint.r * 0.62, tint.g * 0.66, tint.b * 0.78)
			mm.set_instance_color(i, tint)

static var _stage_cache: Dictionary = {}
static func stage_mesh(stage: int) -> ArrayMesh:
	if _stage_cache.has(stage):
		return _stage_cache[stage]
	var k := MeshKit.new()
	var h: float = PLOT_SIZE * 0.5
	# wooden frame + soil bed
	var soil := Color("9a6a3e") if stage != FarmLayer.Stage.WILTED else Color("7f6a54")
	k.box(Vector3(0, 0.12, 0), Vector3(PLOT_SIZE, 0.24, PLOT_SIZE), soil, soil.lightened(0.08))
	var frame := Color("6d4a2e")
	k.box(Vector3(0, 0.22, -h), Vector3(PLOT_SIZE + 0.3, 0.36, 0.22), frame)
	k.box(Vector3(0, 0.22, h), Vector3(PLOT_SIZE + 0.3, 0.36, 0.22), frame)
	k.box(Vector3(-h, 0.22, 0), Vector3(0.22, 0.36, PLOT_SIZE), frame)
	k.box(Vector3(h, 0.22, 0), Vector3(0.22, 0.36, PLOT_SIZE), frame)
	for row in 3:
		var z: float = (float(row) - 1.0) * 1.5
		k.box(Vector3(0, 0.3, z), Vector3(PLOT_SIZE - 0.7, 0.2, 0.6), Color("7b4e2a"), Color("8a5a30"))
		for i in 4:
			var x: float = -1.65 + float(i) * 1.1
			var base := Vector3(x, 0.4, z)
			match stage:
				Stage.SEEDED:
					k.dome(base, 0.16, 0.8, 1, 5, Color("e8d8a0"))
				Stage.SPROUT:
					k.pyramid(base, 0.14, 0.04, 0.55, Color("7fe05a"), Color("a8f06a"))
					k.pyramid(base, 0.04, 0.14, 0.45, Color("7fe05a"), Color("a8f06a"))
				Stage.GROWING:
					k.frustum(base, 0.0, 0.07, 0.9, 0.05, 4, Color("3fc08a"), Color("6fe0a0"))
					k.dome(base + Vector3(0, 0.55, 0), 0.38, 0.7, 1, 6, Color("2fa87a"), Color("2fa87a"))
					k.dome(base + Vector3(0, 0.95, 0), 0.14, 1.0, 1, 5, Color("e6ff2e"))
				Stage.RIPE:
					k.frustum(base, 0.0, 0.08, 1.2, 0.06, 4, Color("2f9a6a"), Color("4fb88a"))
					k.dome(base + Vector3(0, 0.7, 0), 0.5, 0.7, 1, 6, Color("2fa87a"), Color("2fa87a"))
					var orb: Color = Color("ff2fb5") if (i + row) % 2 == 0 else Color("ffe82e")
					k.blob(base + Vector3(0, 1.45, 0), Vector3(0.36, 0.36, 0.36), 3 + i + row * 7, orb, orb.lightened(0.4))
				Stage.WILTED:
					k.frustum(base, 0.0, 0.06, 0.45, 0.05, 4, Color("8a7a4a"), Color("8a7a4a"))
					k.pyramid(base + Vector3(0.18, 0.2, 0), 0.2, 0.04, 0.2, Color("6a5a38"))
	if stage == Stage.RIPE:
		# glowing gold corner posts so ripe plots read from afar
		for sx in [-1.0, 1.0]:
			for sz in [-1.0, 1.0]:
				k.frustum(Vector3(sx * h, 0.0, sz * h), 0.0, 0.14, 1.1, 0.08, 4, Color("ffd24a"), Color("fff08a"))
	var m: ArrayMesh = k.build()
	_stage_cache[stage] = m
	return m
