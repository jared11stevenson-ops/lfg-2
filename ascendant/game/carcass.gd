class_name Carcass
extends Node2D
var food := 1.0
var art_ph: Dictionary = {}
var age := 0.0
func _process(dt: float) -> void:
	age += dt
	if food <= 0.0 or age > 120.0: queue_free()
	queue_redraw()
func _draw() -> void:
	var r := 10.0 + 14.0 * minf(food, 1.0)
	var pal: Dictionary = art_ph.get("pal", {"base": Color(0.5, 0.3, 0.3), "ink": Color(0.1, 0.1, 0.15)})
	var a := clampf(1.0 - age / 120.0, 0.2, 1.0)
	draw_circle(Vector2(3, 4), r, Color(0, 0, 0, 0.2))
	draw_circle(Vector2.ZERO, r, Color(pal["base"].r * 0.8, pal["base"].g * 0.6, pal["base"].b * 0.6, a))
	draw_arc(Vector2.ZERO, r, 0, TAU, 20, pal["ink"], 2.0, true)
	for k in 5: draw_line(Vector2(cos(k) * r * 0.3, sin(k) * r * 0.3), Vector2(cos(k * 2.0) * r * 0.9, sin(k * 2.0) * r * 0.8), Color(0.9, 0.9, 0.85, a), 2.0)
