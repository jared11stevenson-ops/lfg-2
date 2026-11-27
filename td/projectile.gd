extends Node2D
var target: Node2D
var tower
var dmg := 1.0
var molten := false
var speed := 620.0
var color := Color("ff8a2b")
var mult := 1.0
var trail: Array = []
var ptype := ""
var dir := Vector2.RIGHT

func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		queue_free()
		return
	var d := position.distance_to(target.position)
	var step := speed * delta
	if step >= d:
		if is_instance_valid(tower):
			tower.resolve_hit(self, target)
		else:
			target.take_damage(dmg)
		queue_free()
		return
	trail.append(global_position)
	if trail.size() > 7:
		trail.pop_front()
	dir = position.direction_to(target.position)
	position += dir * step
	queue_redraw()

func _draw() -> void:
	var c := Color("ffd23a") if molten else color
	for gi in 3:
		draw_circle(Vector2.ZERO, 16.0 - gi * 4.0, Color(c.r, c.g, c.b, 0.08 + 0.06 * gi))
	var k := 1.5 if molten else 1.0
	for i in trail.size():
		var a := float(i + 1) / (trail.size() + 1)
		draw_circle(to_local(trail[i]), (4.0 + (4.0 if molten else 0.0)) * a, Color(c.r, c.g, c.b, 0.35 * a))
	draw_set_transform(Vector2.ZERO, dir.angle(), Vector2(k, k))
	var ol := Color("2b1a3d")
	match ptype:
		"ember", "forge":
			_poly([Vector2(10, 0), Vector2(-2, -7), Vector2(-14, 0), Vector2(-2, 7)], c, ol)
			_poly([Vector2(5, 0), Vector2(-3, -3), Vector2(-8, 0), Vector2(-3, 3)], Color("fff0a0"), Color(0, 0, 0, 0))
		"tide":
			draw_circle(Vector2.ZERO, 8.0, ol)
			draw_circle(Vector2.ZERO, 6.5, Color(c.r, c.g, c.b, 0.75))
			draw_circle(Vector2(-2, -2), 2.0, Color.WHITE)
		"verdant":
			_poly([Vector2(10, 0), Vector2(0, -6), Vector2(-9, 0), Vector2(0, 6)], c, ol)
			draw_line(Vector2(9, 0), Vector2(-8, 0), Color("2a6a2a"), 1.5)
		"volt":
			draw_polyline(PackedVector2Array([Vector2(-11, 3), Vector2(-4, -5), Vector2(2, 3), Vector2(11, -3)]), ol, 6.0, true)
			draw_polyline(PackedVector2Array([Vector2(-11, 3), Vector2(-4, -5), Vector2(2, 3), Vector2(11, -3)]), c, 3.0, true)
		"stone":
			_poly([Vector2(7, -3), Vector2(3, -7), Vector2(-5, -5), Vector2(-8, 1), Vector2(-2, 7), Vector2(6, 4)], c, ol)
		"frost":
			for a in 3:
				var d := Vector2.from_angle(a * PI / 3.0) * 8.0
				draw_line(-d, d, ol, 5.0, true)
				draw_line(-d, d, c, 2.5, true)
		"gale":
			draw_arc(Vector2.ZERO, 6.0, 0.5, 5.2, 12, ol, 5.0, true)
			draw_arc(Vector2.ZERO, 6.0, 0.5, 5.2, 12, c, 2.5, true)
		"venom":
			_poly([Vector2(9, 0), Vector2(-4, -6), Vector2(-8, 0), Vector2(-4, 6)], c, ol)
			draw_circle(Vector2(-3, -2), 1.8, Color(1, 1, 1, 0.8))
		"umbra":
			draw_circle(Vector2.ZERO, 8.0, Color(c.r, c.g, c.b, 0.35))
			draw_circle(Vector2.ZERO, 5.5, Color("1a1030"))
			draw_arc(Vector2.ZERO, 5.5, 0, TAU, 14, c, 1.8, true)
		"aether":
			_poly([Vector2(10, 0), Vector2(2, -3), Vector2(0, -10), Vector2(-3, -2), Vector2(-10, 0), Vector2(-3, 2), Vector2(0, 10), Vector2(2, 3)], c, ol)
		"spirit":
			draw_circle(Vector2(-6, 0), 3.0, Color(c.r, c.g, c.b, 0.4))
			draw_circle(Vector2.ZERO, 6.0, ol)
			draw_circle(Vector2.ZERO, 4.5, c)
		_:
			draw_circle(Vector2.ZERO, 6.5, ol)
			draw_circle(Vector2.ZERO, 5.0, c)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _poly(pts: Array, fill: Color, outline: Color) -> void:
	var pp := PackedVector2Array(pts)
	draw_colored_polygon(pp, fill)
	if outline.a > 0.0:
		var cl := pp.duplicate()
		cl.append(pp[0])
		draw_polyline(cl, outline, 2.0, true)
