extends Control
# Big animated wave title: slides in with a bounce, holds, fades. Final waves get a red tint and a subtitle.
var title := "Wave 1"
var sub := ""
var tint := Color(1, 1, 1)
var t := 0.0
const LIFE := 1.9

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	z_index = 50

func _process(delta: float) -> void:
	t += delta
	if t >= LIFE:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var k := clampf(t / 0.35, 0.0, 1.0)
	var out := clampf((t - (LIFE - 0.45)) / 0.45, 0.0, 1.0)
	var a := (1.0 - out) * minf(1.0, t / 0.15)
	var s := 1.0 + 0.35 * pow(1.0 - k, 2.0)
	var f := ThemeDB.fallback_font
	var cx := 640.0
	var y := 305.0 - 30.0 * out
	# soft band behind the text
	draw_rect(Rect2(0, y - 54, 1280, 84), Color(0.05, 0.03, 0.12, 0.5 * a))
	draw_rect(Rect2(0, y - 54, 1280, 3), Color(tint.r, tint.g, tint.b, 0.7 * a))
	draw_rect(Rect2(0, y + 27, 1280, 3), Color(tint.r, tint.g, tint.b, 0.7 * a))
	var fs := int(54.0 * s)
	var w := f.get_string_size(title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string_outline(f, Vector2(cx - w * 0.5, y + 10), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 12, Color(0.1, 0.05, 0.2, a))
	draw_string(f, Vector2(cx - w * 0.5, y + 10), title, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(tint.r, tint.g, tint.b, a))
	if sub != "":
		var w2 := f.get_string_size(sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20).x
		draw_string(f, Vector2(cx - w2 * 0.5, y + 52), sub, HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color(1, 0.92, 0.8, a * minf(1.0, maxf(0.0, (t - 0.3) / 0.3))))
