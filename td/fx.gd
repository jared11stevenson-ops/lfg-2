extends Node2D
# Floating combat text ("Super!" / "Resisted").
var text := ""
var color := Color.WHITE
var t := 0.0

func _process(delta: float) -> void:
	t += delta
	position.y -= 34.0 * delta
	modulate.a = clampf(1.0 - t / 0.9, 0.0, 1.0)
	if t > 0.9:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var f := ThemeDB.fallback_font
	draw_string_outline(f, Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 80, 20, 6, Color.BLACK)
	draw_string(f, Vector2(-40, 0), text, HORIZONTAL_ALIGNMENT_CENTER, 80, 20, color)

static func pop(parent: Node, pos: Vector2, mult: float) -> void:
	if absf(mult - 1.0) < 0.05:
		return
	var f = load("res://fx.gd").new()
	f.text = "Super!" if mult > 1.0 else "Resisted"
	f.color = Color("ffe35a") if mult > 1.0 else Color("b8c2d6")
	f.position = pos + Vector2(0, -34)
	parent.add_child(f)
