extends Node2D
# Impact burst where a shot lands: a flash ring plus a few type-coloured sparks. Frees itself after 0.3 s.
var col := Color("ffd23a")
var t := 0.0
var seeds: Array = []
const LIFE := 0.3

func _ready() -> void:
	z_index = 12
	for i in 7:
		seeds.append(Vector2.from_angle(randf() * TAU) * randf_range(0.6, 1.0))

func _process(delta: float) -> void:
	t += delta
	if t >= LIFE:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var k := t / LIFE
	var a := 1.0 - k
	draw_arc(Vector2.ZERO, 6.0 + 22.0 * k, 0, TAU, 20, Color(col.r, col.g, col.b, 0.8 * a), 3.0 * a + 1.0, true)
	draw_circle(Vector2.ZERO, (7.0 - 5.0 * k), Color(1, 1, 1, 0.85 * a))
	for s in seeds:
		var p: Vector2 = s * (6.0 + 26.0 * k)
		draw_circle(p, 2.8 * a + 0.4, Color(col.r, col.g, col.b, a))
