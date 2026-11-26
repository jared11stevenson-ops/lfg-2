extends Node2D
# Death poof: expanding ring plus sparks.
var t := 0.0
var col := Color.WHITE
var sparks: Array = []
const LIFE := 0.55

func _ready() -> void:
	for i in 9:
		sparks.append(Vector2.from_angle(randf() * TAU) * randf_range(28.0, 90.0))

func _process(delta: float) -> void:
	t += delta
	if t > LIFE:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var k := t / LIFE
	draw_arc(Vector2.ZERO, 8.0 + 46.0 * k, 0, TAU, 32, Color(col.r, col.g, col.b, 0.7 * (1.0 - k)), 5.0 * (1.0 - k) + 1.0, true)
	draw_circle(Vector2.ZERO, 22.0 * (1.0 - k), Color(1, 1, 1, 0.5 * (1.0 - k)))
	for s in sparks:
		draw_circle(s * k, 4.0 * (1.0 - k) + 1.0, Color(col.r, col.g, col.b, 1.0 - k))
