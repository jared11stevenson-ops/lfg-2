extends Node2D
# Lingering ground effect: burn patch (Tickindle/Pyrelope/Thornarok) or dusk cloud (Gloamoth).
var life := 4.0
var max_life := 4.0
var radius := 40.0
var dps := 6.0
var slow := 1.0
var kind := "burn"

func _ready() -> void:
	max_life = life

func _process(delta: float) -> void:
	life -= delta
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead and e.position.distance_to(position) <= radius:
			e.take_damage(dps * delta)
			if slow < 1.0:
				e.apply_slow(slow, 0.4)
	if life <= 0.0:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var a := clampf(life / max_life, 0.0, 1.0)
	var t := float(Time.get_ticks_msec()) / 120.0
	if kind == "cloud":
		draw_circle(Vector2.ZERO, radius, Color(0.35, 0.25, 0.6, 0.30 * a))
		for i in 6:
			var o := Vector2(sin(t * 0.4 + i * 1.7), cos(t * 0.3 + i * 2.1)) * radius * 0.55
			draw_circle(o, radius * 0.38, Color(0.5, 0.4, 0.8, 0.28 * a))
		for i in 4:
			var o2 := Vector2(sin(t * 0.7 + i * 2.4), cos(t * 0.6 + i * 1.3)) * radius * 0.7
			draw_circle(o2, 2.5, Color(1.0, 0.95, 0.6, 0.9 * a))
	else:
		draw_circle(Vector2.ZERO, radius, Color(1.0, 0.35, 0.05, 0.28 * a))
		for i in 5:
			var o := Vector2(sin(t + i * 1.9), cos(t * 0.8 + i * 2.3)) * radius * 0.55
			draw_circle(o, 6.0 + 3.0 * sin(t + i), Color(1.0, 0.7, 0.2, 0.7 * a))
