extends Node2D
# Living-map overlay for levels with painted art: pulsing Well glow, drifting fireflies, motes rising from the Well.
# Drawn additively on top of the baked backdrop.
var well := Vector2(1190, 300)
var glow := Color("ffe9a8")
var flies: Array = []
var motes: Array = []
var t := 0.0
static var _glow_tex: GradientTexture2D
const PALETTE := [Color("e8ff8a"), Color("9ff0ff"), Color("ffe08a")]

static func _glow() -> GradientTexture2D:
	if _glow_tex == null:
		var g := Gradient.new()
		g.offsets = PackedFloat32Array([0.0, 0.35, 0.7, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.34), Color(1, 1, 1, 0.16), Color(1, 1, 1, 0.045), Color(1, 1, 1, 0.0)])
		_glow_tex = GradientTexture2D.new()
		_glow_tex.gradient = g
		_glow_tex.fill = GradientTexture2D.FILL_RADIAL
		_glow_tex.fill_from = Vector2(0.5, 0.5)
		_glow_tex.fill_to = Vector2(1.0, 0.5)
		_glow_tex.width = 128
		_glow_tex.height = 128
	return _glow_tex

func _ready() -> void:
	z_index = 2
	var m := CanvasItemMaterial.new()
	m.blend_mode = CanvasItemMaterial.BLEND_MODE_ADD
	material = m
	var r := RandomNumberGenerator.new()
	r.seed = 77
	for i in 34:
		flies.append({"p": Vector2(r.randf_range(40, 1240), r.randf_range(90, 690)), "ph": r.randf() * TAU, "sp": r.randf_range(0.25, 0.7), "r": r.randf_range(14, 44), "c": PALETTE[i % 3]})
	for i in 16:
		motes.append({"ph": r.randf(), "x": r.randf_range(-34, 34), "sp": r.randf_range(0.12, 0.22)})

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _draw() -> void:
	var k := 0.5 + 0.5 * sin(t * 1.6)
	var R := 142.0 + k * 6.0
	draw_texture_rect(_glow(), Rect2(well + Vector2(0, -4) - Vector2(R, R), Vector2(R, R) * 2.0), false, Color(glow.r, glow.g, glow.b, 0.75 + 0.5 * k))
	for m in motes:
		var u := fmod(t * m.sp + m.ph, 1.0)
		var p: Vector2 = well + Vector2(m.x * (0.4 + u), -10.0 - u * 120.0 + sin(t * 2.0 + m.ph * 9.0) * 6.0)
		draw_circle(p, 2.2 * (1.0 - u) + 0.6, Color(glow.r, glow.g, glow.b, 0.7 * (1.0 - u)))
	for f in flies:
		var p: Vector2 = f.p + Vector2(sin(t * f.sp + f.ph), cos(t * f.sp * 1.3 + f.ph)) * f.r
		var a := 0.3 + 0.7 * maxf(0.0, sin(t * 1.7 + f.ph * 3.0))
		var c: Color = f.c
		draw_circle(p, 6.0, Color(c.r, c.g, c.b, 0.10 * a))
		draw_circle(p, 2.0, Color(c.r, c.g, c.b, 0.9 * a))
