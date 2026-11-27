extends Node2D
# Coins pop out of a defeated enemy and arc toward the coin counter (top-left).
var n := 4
var t := 0.0
var bits: Array = []
const LIFE := 0.8
const TARGET := Vector2(40, 30)

func _ready() -> void:
	z_index = 12
	for i in n:
		bits.append({"v": Vector2(randf_range(-60, 60), randf_range(-120, -60)), "d": randf_range(0.0, 0.12)})

func _process(delta: float) -> void:
	t += delta
	if t > LIFE + 0.15:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var target := TARGET - global_position
	for b in bits:
		var u := clampf((t - b.d) / LIFE, 0.0, 1.0)
		if u <= 0.0:
			continue
		var pop := Vector2(b.v.x * u, b.v.y * u + 260.0 * u * u * (1.0 - u))
		var p := pop.lerp(target, u * u * u)
		var a := 1.0 - maxf(0.0, (u - 0.85) / 0.15)
		draw_set_transform(p, 0.0, Vector2(1.0, 0.8))
		draw_circle(Vector2.ZERO, 7.5, Color(0.11, 0.07, 0.19, a))
		draw_circle(Vector2.ZERO, 6.0, Color(0.96, 0.72, 0.16, a))
		draw_circle(Vector2(-2, -2), 1.8, Color(1, 1, 1, 0.8 * a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
