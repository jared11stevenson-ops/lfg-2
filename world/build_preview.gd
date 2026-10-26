class_name BuildPreview
extends Node3D
## Building placement ghost: hex footprint + toy-house ghost, green when valid, red when not.
## Validity = WorldData.can_build(hex) AND (optional) `extra_validator.call(hex) -> bool` (e.g. Rules check).
const VALID_COLOR := Color(0.25, 1.0, 0.45, 0.55)
const INVALID_COLOR := Color(1.0, 0.2, 0.25, 0.5)
var world: WorldData
var hex: Vector2i = Vector2i(-1, -1)
var valid: bool = false
var extra_validator: Callable = Callable()
var _foot: MeshInstance3D
var _ghost: MeshInstance3D
var _foot_mat: StandardMaterial3D
var _ghost_mat: StandardMaterial3D

func _init() -> void:
	name = "BuildPreview"
	visible = false
	_foot_mat = StandardMaterial3D.new()
	_foot_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_foot_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_foot_mat.vertex_color_use_as_albedo = true
	_foot_mat.cull_mode = BaseMaterial3D.CULL_DISABLED
	_foot_mat.no_depth_test = false
	_ghost_mat = StandardMaterial3D.new()
	_ghost_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	_ghost_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	_ghost_mat.albedo_color = VALID_COLOR
	_foot = MeshInstance3D.new()
	_foot.material_override = _foot_mat
	_foot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_foot)
	_ghost = MeshInstance3D.new()
	_ghost.mesh = Props.mesh_for(Props.T.HOUSE)
	_ghost.material_override = _ghost_mat
	_ghost.scale = Vector3.ONE * 1.6
	_ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_ghost)

## Swap the ghost for a building's model ("" restores the generic toy house).
func set_model(building_id: String) -> void:
	_ghost.mesh = BuildingModels.mesh_for(building_id) if building_id != "" else Props.mesh_for(Props.T.HOUSE)
	_ghost.scale = Vector3.ONE * (1.0 if building_id != "" else 1.6)

## Recompute validity for the current hex (inventory/state may have changed since show_at).
func revalidate() -> void:
	if not visible or not HexMath.in_bounds(hex):
		return
	var v: bool = is_valid_hex(hex)
	if v != valid:
		valid = v
		var col: Color = VALID_COLOR if valid else INVALID_COLOR
		_ghost_mat.albedo_color = col
		_foot.mesh = _footprint_mesh(col)

func is_valid_hex(c: Vector2i) -> bool:
	if world == null or not world.can_build(c):
		return false
	if extra_validator.is_valid():
		return bool(extra_validator.call(c))
	return true

func show_at(c: Vector2i) -> void:
	if c == hex and visible:
		return
	hex = c
	valid = is_valid_hex(c)
	visible = HexMath.in_bounds(c)
	if not visible:
		return
	var cen: Vector2 = HexMath.offset_center(c.x, c.y)
	position = Vector3(cen.x, world.height_at(cen.x, cen.y), cen.y)
	var col: Color = VALID_COLOR if valid else INVALID_COLOR
	_ghost_mat.albedo_color = col
	_foot.mesh = _footprint_mesh(col)

## Preview the hex ahead of the player (12 m in facing direction).
func follow(player: Node3D) -> void:
	var fwd := Vector3(-sin(player.rotation.y), 0, -cos(player.rotation.y))
	var p: Vector3 = player.position + fwd * 12.0
	show_at(HexMath.world_to_offset(p.x, p.z))

func confirm() -> Dictionary:
	return {"hex": hex, "valid": valid}

func hide_preview() -> void:
	visible = false
	hex = Vector2i(-1, -1)

func _footprint_mesh(col: Color) -> ArrayMesh:
	var k := MeshKit.new()
	var cen: Vector2 = HexMath.offset_center(hex.x, hex.y)
	var base_y: float = world.height_at(cen.x, cen.y)
	var rings := 3
	var inner := col
	inner.a = col.a * 0.55
	var edge := col
	edge.a = 0.95
	for s in 6:
		var a0: float = deg_to_rad(60.0 * float(s) - 30.0)
		var a1: float = deg_to_rad(60.0 * float(s + 1) - 30.0)
		for ring in rings:
			var f0: float = float(ring) / float(rings)
			var f1: float = float(ring + 1) / float(rings)
			var c0: Color = inner if ring < rings - 1 else edge
			var p00: Vector3 = _pt(cen, a0, f0, base_y)
			var p01: Vector3 = _pt(cen, a1, f0, base_y)
			var p10: Vector3 = _pt(cen, a0, f1, base_y)
			var p11: Vector3 = _pt(cen, a1, f1, base_y)
			var dn := Vector3(0, -50, 0)
			k.tri(p00, p10, p11, c0, p00 + dn)
			if ring > 0:
				k.tri(p00, p11, p01, c0, p00 + dn)
	return k.build()

func _pt(cen: Vector2, ang: float, f: float, base_y: float) -> Vector3:
	var r: float = HexMath.SIZE * 0.96 * f
	var x: float = cen.x + cos(ang) * r
	var z: float = cen.y + sin(ang) * r
	return Vector3(x - cen.x, world.height_at(x, z) - base_y + 0.2, z - cen.y)

func _process(_dt: float) -> void:
	if visible:
		_ghost.position.y = 0.0
		_ghost_mat.albedo_color.a = 0.55 + 0.15 * sin(Time.get_ticks_msec() * 0.008)
