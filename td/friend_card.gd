extends Control
# "New friend" reveal after the first capture of a species: card pops in, shows the creature and its types, then fades.
const PuppetLib = preload("res://puppet_lib.gd")
const OUT := Color("1d1230")
var sprite := ""
var title := ""
var subtitle := ""
var t := 0.0
const LIFE := 2.8

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	z_index = 60

func _process(delta: float) -> void:
	t += delta
	if t >= LIFE:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var k := minf(1.0, t / 0.35)
	var pop := 1.0 + 0.18 * sin(k * PI) * (1.0 - k)
	var a := 1.0 - clampf((t - (LIFE - 0.5)) / 0.5, 0.0, 1.0)
	var c := Vector2(640, 250)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.04, 0.02, 0.1, 0.45 * a * k))
	var r := Rect2(c + Vector2(-230, -110) * pop, Vector2(460, 220) * pop)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.2, 0.96 * a)
	sb.set_corner_radius_all(22)
	sb.set_border_width_all(4)
	sb.border_color = Color(1.0, 0.82, 0.3, a)
	draw_style_box(sb, r)
	for i in 8:
		var ang := float(i) / 8.0 * TAU + t * 0.8
		var rr := 70.0 + 14.0 * sin(t * 6.0 + i)
		draw_circle(c + Vector2(-120, 6) + Vector2.from_angle(ang) * rr, 3.0, Color(1.0, 0.9, 0.5, 0.7 * a))
	PuppetLib.draw(self, sprite, "idle", int(t * 6.0), false, 0.62 * pop, c + Vector2(-120, 40), Color(1, 1, 1, a))
	var f := ThemeDB.fallback_font
	draw_string_outline(f, c + Vector2(-30, -40), "NEW FRIEND!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, 8, Color(OUT.r, OUT.g, OUT.b, a))
	draw_string(f, c + Vector2(-30, -40), "NEW FRIEND!", HORIZONTAL_ALIGNMENT_LEFT, -1, 26, Color(1.0, 0.88, 0.4, a))
	draw_string_outline(f, c + Vector2(-30, 8), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, 9, Color(OUT.r, OUT.g, OUT.b, a))
	draw_string(f, c + Vector2(-30, 8), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 36, Color(1, 1, 1, a))
	draw_string(f, c + Vector2(-30, 44), subtitle, HORIZONTAL_ALIGNMENT_LEFT, 250, 18, Color(0.78, 0.85, 1.0, a))
	draw_string(f, c + Vector2(-30, 76), "Now in your shop and team", HORIZONTAL_ALIGNMENT_LEFT, 250, 16, Color(0.7, 1.0, 0.8, a))
