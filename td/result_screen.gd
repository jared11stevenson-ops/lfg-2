extends Control
# Victory / defeat screen: animated stars, run summary, befriended creatures.
const PuppetLib = preload("res://puppet_lib.gd")
const OUT := Color("1d1230")
var t := 0.0
var won := true
var stars := 0
var title := ""
var lines: Array = []
var ally_sprites: Array = []
var ally_names: Array = []
var tip := ""
var panel_sb: StyleBoxFlat

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.1, 0.07, 0.2, 0.97)
	panel_sb.set_corner_radius_all(26)
	panel_sb.set_border_width_all(5)
	panel_sb.border_color = Color("f0b43c") if won else Color("8a5a6a")

func _process(delta: float) -> void:
	t += delta
	queue_redraw()

func _txt(s: String, pos: Vector2, size_px: int, col: Color, align := HORIZONTAL_ALIGNMENT_CENTER, w: float = 600.0) -> void:
	var f := ThemeDB.fallback_font
	draw_string_outline(f, pos, s, align, w, size_px, 8, OUT)
	draw_string(f, pos, s, align, w, size_px, col)

func _star(c: Vector2, r: float, fill: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := PI * i / 5.0 - PI / 2.0
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, fill)
	var cl := pts.duplicate()
	cl.append(pts[0])
	draw_polyline(cl, OUT, 5.0, true)

func _draw() -> void:
	var fade := clampf(t * 3.0, 0.0, 1.0)
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.0, 0.08, 0.6 * fade))
	var slide := (1.0 - clampf(t * 2.2, 0.0, 1.0))
	var oy := slide * slide * 120.0
	draw_style_box(panel_sb, Rect2(340, 70 + oy, 600, 430))
	_txt(title, Vector2(340, 150 + oy), 58, Color("ffe36a") if won else Color("ffb0b8"))
	if won:
		for i in 3:
			var k := clampf((t - 0.55 - i * 0.45) * 3.5, 0.0, 1.0)
			var pop := 1.0 + 0.35 * sin(k * PI) if k < 1.0 else 1.0
			var c := Vector2(540 + i * 100, 235 + oy)
			_star(c, 40.0 * k * pop, Color("ffd23a") if i < stars else Color("3a2f5a"))
	var y := 320.0 + oy
	for l in lines:
		_txt(String(l), Vector2(340, y), 24, Color("e8e0ff"))
		y += 34.0
	if not won and tip != "":
		_txt(tip, Vector2(380, y + 10), 20, Color("c8b8f0"), HORIZONTAL_ALIGNMENT_CENTER, 520.0)
	if not ally_sprites.is_empty() and t > 1.9:
		var n := ally_sprites.size()
		_txt("New friends!", Vector2(340, 404 + oy), 24, Color("9fffa0"))
		for i in n:
			var x := 640.0 - (n - 1) * 70.0 + i * 140.0
			PuppetLib.draw(self, ally_sprites[i], "idle", int(t * 6.0 + i), false, 0.62, Vector2(x, 480 + oy))
