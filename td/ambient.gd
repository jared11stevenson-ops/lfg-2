extends Node2D
# Living-map overlay for levels with painted art: pulsing Well glow, drifting fireflies, motes rising from the Well.
# Drawn additively on top of the baked backdrop.
var well := Vector2(1190, 300)
var glow := Color("ffe9a8")
var flies: Array = []
var motes: Array = []
var t := 0.0
const PALETTE := [Color("e8ff8a"), Color("9ff0ff"), Color("ffe08a")]

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
	for i in 18:
		var u := float(i) / 18.0
		var a := 0.02 * (1.0 - u) * (1.0 - u) * (0.75 + 0.5 * k)
		draw_circle(well + Vector2(0, -4), 22.0 + u * 120.0 + k * 6.0, Color(glow.r, glow.g, glow.b, a))
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
