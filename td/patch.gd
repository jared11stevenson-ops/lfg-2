extends Node2D
# Burn patch left on the lane by molten Tickindle shots.
var life := 4.0
var radius := 40.0
var dps := 6.0

func _process(delta: float) -> void:
	life -= delta
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead and e.position.distance_to(position) <= radius:
			e.take_damage(dps * delta)
	if life <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var a := clampf(life / 4.0, 0.0, 1.0)
	var t := float(Time.get_ticks_msec()) / 120.0
	draw_circle(Vector2.ZERO, radius, Color(1.0, 0.35, 0.05, 0.28 * a))
	for i in 5:
		var o := Vector2(sin(t + i * 1.9), cos(t * 0.8 + i * 2.3)) * radius * 0.55
		draw_circle(o, 6.0 + 3.0 * sin(t + i), Color(1.0, 0.7, 0.2, 0.7 * a))
