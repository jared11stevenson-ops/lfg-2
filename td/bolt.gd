extends Node2D
# Lightning arc between two points (Zapnose chain).
var a := Vector2.ZERO
var b := Vector2.ZERO
var t := 0.0
var pts := PackedVector2Array()

func _ready() -> void:
	var n := 6
	for i in n + 1:
		var k := float(i) / n
		var p := a.lerp(b, k)
		if i > 0 and i < n:
			p += (b - a).orthogonal().normalized() * randf_range(-10.0, 10.0)
		pts.append(p)

func _process(delta: float) -> void:
	t += delta
	if t > 0.18:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var al := 1.0 - t / 0.18
	var local := PackedVector2Array()
	for p in pts:
		local.append(to_local(p))
	draw_polyline(local, Color(0.6, 0.8, 1.0, 0.5 * al), 9.0, true)
	draw_polyline(local, Color(1, 1, 0.8, al), 3.0, true)
