class_name RoadLayer
extends Node3D
## Roads as terrain-conforming ribbon meshes (cobble strip + darker verge + hex hub discs), one mesh per 8x8-hex chunk,
## instead of a colour tint on the terrain. Built from WorldData.road; ribbons run centre-to-centre between adjacent road hexes.
const CHUNK := 8
const WIDTH := 3.6
const VERGE := 0.7
const LIFT := 0.14
const SUBDIV := 5
var world: WorldData
var material: ShaderMaterial
var stats: Dictionary = {"chunks": 0, "segments": 0, "tris": 0, "road_hexes": 0}

func _init() -> void:
	name = "RoadLayer"
	material = ShaderMaterial.new()
	material.shader = load("res://world/shaders/world.gdshader")
	material.set_shader_parameter("hide_unseen", true)

func bind_fog(tex: Texture2D) -> void:
	material.set_shader_parameter("fow_tex", tex)

func build(w: WorldData) -> void:
	world = w
	for ch in get_children():
		ch.queue_free()
	var kits: Dictionary = {}
	var seg := 0
	var hexes := 0
	for r in HexMath.ROWS:
		for c in HexMath.COLS:
			var h := Vector2i(c, r)
			if not w.is_road(h):
				continue
			hexes += 1
			var key := Vector2i(c / CHUNK, r / CHUNK)
			if not kits.has(key):
				kits[key] = MeshKit.new()
			var kit: MeshKit = kits[key]
			var a: Vector2 = HexMath.offset_center(c, r)
			_hub(kit, a)
			for n in HexMath.neighbors(h):
				if w.is_road(n) and HexMath.idx(n) > HexMath.idx(h):
					_ribbon(kit, a, HexMath.offset_center(n.x, n.y))
					seg += 1
	var tris := 0
	for key in kits:
		var kit2: MeshKit = kits[key]
		tris += kit2.tri_count()
		var mi := MeshInstance3D.new()
		mi.name = "Road_%d_%d" % [key.x, key.y]
		mi.mesh = kit2.build()
		mi.material_override = material
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
	stats = {"chunks": kits.size(), "segments": seg, "tris": tris, "road_hexes": hexes}

func _y(p: Vector2) -> float:
	return world.height_at(p.x, p.y) + LIFT

func _hub(kit: MeshKit, c: Vector2) -> void:
	var dn := Vector3(0, -50, 0)
	var cen := Vector3(c.x, _y(c), c.y)
	for i in 8:
		var a0: float = TAU * float(i) / 8.0
		var a1: float = TAU * float(i + 1) / 8.0
		var p0 := Vector2(c.x + cos(a0) * WIDTH * 0.62, c.y + sin(a0) * WIDTH * 0.62)
		var p1 := Vector2(c.x + cos(a1) * WIDTH * 0.62, c.y + sin(a1) * WIDTH * 0.62)
		kit.tri(cen, Vector3(p0.x, _y(p0), p0.y), Vector3(p1.x, _y(p1), p1.y), Color("f0d9a8"), cen + dn)

func _ribbon(kit: MeshKit, a: Vector2, b: Vector2) -> void:
	var dir: Vector2 = (b - a)
	var len: float = dir.length()
	dir /= len
	var nrm := Vector2(-dir.y, dir.x)
	var dn := Vector3(0, -50, 0)
	for s in SUBDIV:
		var t0: float = float(s) / float(SUBDIV)
		var t1: float = float(s + 1) / float(SUBDIV)
		var p0: Vector2 = a.lerp(b, t0)
		var p1: Vector2 = a.lerp(b, t1)
		# verge (wide, dark) then cobble (narrow, light) lifted a hair higher
		for layer in 2:
			var half: float = WIDTH * 0.5 + (VERGE if layer == 0 else 0.0)
			var lift: float = 0.0 if layer == 0 else 0.03
			var col: Color = Color("b8895a") if layer == 0 else Color("f0d9a8")
			if layer == 1 and (s % 2 == 1):
				col = Color("e8cc98") # alternating cobble bands
			var l0: Vector2 = p0 - nrm * half
			var r0: Vector2 = p0 + nrm * half
			var l1: Vector2 = p1 - nrm * half
			var r1: Vector2 = p1 + nrm * half
			var v00 := Vector3(l0.x, _y(l0) + lift, l0.y)
			var v01 := Vector3(r0.x, _y(r0) + lift, r0.y)
			var v10 := Vector3(l1.x, _y(l1) + lift, l1.y)
			var v11 := Vector3(r1.x, _y(r1) + lift, r1.y)
			kit.tri(v00, v10, v11, col, v00 + dn)
			kit.tri(v00, v11, v01, col, v00 + dn)
