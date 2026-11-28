extends Node2D
# Victory confetti: batched into three multiline calls per frame, so it costs almost nothing.
var parts: Array = []
var t := 0.0
const LIFE := 4.0
const COLS := [Color("ffd23a"), Color("7fe8ff"), Color("ff9ad8")]

func _ready() -> void:
	z_index = 45
	var r := RandomNumberGenerator.new()
	r.randomize()
	for i in 90:
		parts.append({"x": r.randf_range(0, 1280), "y": r.randf_range(-400, -20), "vy": r.randf_range(140, 300), "ph": r.randf() * TAU, "c": i % 3})

func _process(delta: float) -> void:
	t += delta
	if t >= LIFE:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var a := 1.0 - clampf((t - (LIFE - 0.8)) / 0.8, 0.0, 1.0)
	for c in 3:
		var pts := PackedVector2Array()
		for p in parts:
			if p.c != c:
				continue
			var y: float = p.y + p.vy * t
			if y > 740.0:
				continue
			var x: float = p.x + sin(t * 3.0 + p.ph) * 22.0
			pts.append(Vector2(x - 4.0, y)); pts.append(Vector2(x + 4.0, y + sin(t * 8.0 + p.ph) * 3.0))
		if pts.size() > 0:
			draw_multiline(pts, Color(COLS[c].r, COLS[c].g, COLS[c].b, a), 5.0)
