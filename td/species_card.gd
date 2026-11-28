extends Control
# First-sighting card for a species: slides in at the top of the screen with its portrait, types and one-line role.
const PuppetLib = preload("res://puppet_lib.gd")
const OUT := Color("1d1230")
var sprite := ""
var title := ""
var body := ""
var types := ""
var t := 0.0
const LIFE := 4.2

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	z_index = 55

func _process(delta: float) -> void:
	t += delta
	if t >= LIFE:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var slide := clampf(t / 0.4, 0.0, 1.0)
	var out := clampf((t - (LIFE - 0.5)) / 0.5, 0.0, 1.0)
	var e := 1.0 - pow(1.0 - slide, 3.0)
	var a := e * (1.0 - out)
	var r := Rect2(Vector2(330, 118 - 40.0 * (1.0 - e) - 40.0 * out), Vector2(620, 92))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.06, 0.18, 0.93 * a)
	sb.set_corner_radius_all(18)
	sb.set_border_width_all(3)
	sb.border_color = Color(0.62, 0.85, 1.0, a)
	draw_style_box(sb, r)
	PuppetLib.draw(self, sprite, "idle", int(t * 6.0), false, 0.42, r.position + Vector2(62, 74), Color(1, 1, 1, a))
	var f := ThemeDB.fallback_font
	var p := r.position
	draw_string_outline(f, p + Vector2(122, 30), "NEW: " + title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, 7, Color(OUT.r, OUT.g, OUT.b, a))
	draw_string(f, p + Vector2(122, 30), "NEW: " + title, HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color(1.0, 0.88, 0.4, a))
	draw_string(f, p + Vector2(122, 52), types, HORIZONTAL_ALIGNMENT_LEFT, 480, 16, Color(0.7, 0.9, 1.0, a))
	draw_string(f, p + Vector2(122, 76), body, HORIZONTAL_ALIGNMENT_LEFT, 480, 16, Color(0.92, 0.92, 1.0, a))
