extends Node2D
const DrawUtil = preload("res://draw_util.gd")
var target: Node2D
var dmg := 1.0
var molten := false
var speed := 620.0

func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.is_queued_for_deletion():
		queue_free()
		return
	var d := position.distance_to(target.position)
	var step := speed * delta
	if step >= d:
		target.take_damage(dmg)
		queue_free()
		return
	position += position.direction_to(target.position) * step
	queue_redraw()

func _draw() -> void:
	var c := Color("ffd23a") if molten else Color("ff8a2b")
	var r := 9.0 if molten else 5.0
	draw_circle(Vector2.ZERO, r + 4.0, Color(c.r, c.g, c.b, 0.3))
	DrawUtil.disc(self, Vector2.ZERO, r, c, Color("7a2a00"), 2.0)
