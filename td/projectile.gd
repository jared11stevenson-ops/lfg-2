extends Node2D
var target: Node2D
var tower
var dmg := 1.0
var molten := false
var speed := 620.0
var color := Color("ff8a2b")
var mult := 1.0
var trail: Array = []

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
	position += position.direction_to(target.position) * step
	queue_redraw()

func _draw() -> void:
	var c := Color("ffd23a") if molten else color
	for i in trail.size():
		var a := float(i + 1) / (trail.size() + 1)
		draw_circle(to_local(trail[i]), (4.0 + (4.0 if molten else 0.0)) * a, Color(c.r, c.g, c.b, 0.35 * a))
	var r := 9.0 if molten else 5.0
	draw_circle(Vector2.ZERO, r + 4.0, Color(c.r, c.g, c.b, 0.3))
	draw_circle(Vector2.ZERO, r + 1.5, Color("2b1a3d"))
	draw_circle(Vector2.ZERO, r, c)
	draw_circle(Vector2(-r * 0.25, -r * 0.25), r * 0.3, Color(1, 1, 1, 0.8))
