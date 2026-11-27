extends Control
# Illustrated story pages shown before a level: speaker sprite + text. Tap to continue, Skip to close.
const PuppetLib = preload("res://puppet_lib.gd")
const UiStyle = preload("res://ui_style.gd")
const OUT := Color("1d1230")
signal finished
var pages: Array = []   # [[text, sprite_id], ...]
var idx := 0
var t := 0.0
var shown := 0.0

func _ready() -> void:
	size = Vector2(1280, 720)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var skip := Button.new()
	skip.text = "Skip"
	skip.position = Vector2(1120, 24)
	skip.size = Vector2(120, 44)
	skip.add_theme_font_size_override("font_size", 20)
	UiStyle.style_btn(skip, Color("3a4a6b"), Color("3a4a6b"))
	skip.pressed.connect(_close)
	add_child(skip)

func _process(delta: float) -> void:
	t += delta
	shown += delta * 55.0
	queue_redraw()

func _gui_input(ev: InputEvent) -> void:
	if (ev is InputEventMouseButton and ev.pressed) or (ev is InputEventScreenTouch and ev.pressed):
		var full: int = String(pages[idx][0]).length()
		if shown < full:
			shown = full
		else:
			idx += 1
			shown = 0.0
			if idx >= pages.size():
				_close()

func _close() -> void:
	finished.emit()
	queue_free()

func _draw() -> void:
	if idx >= pages.size():
		return
	var f := ThemeDB.fallback_font
	draw_rect(Rect2(0, 0, 1280, 720), Color(0.02, 0.0, 0.09, 0.94))
	var sprite_id: String = pages[idx][1]
	var bob := sin(t * 2.2) * 5.0
	PuppetLib.draw(self, sprite_id, "idle", int(t * 6.0), false, 1.7, Vector2(640, 380 + bob))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.07, 0.2, 0.96)
	sb.set_corner_radius_all(24)
	sb.set_border_width_all(4)
	sb.border_color = Color("f0b43c")
	draw_style_box(sb, Rect2(140, 450, 1000, 200))
	var text: String = pages[idx][0]
	var part := text.substr(0, int(shown))
	draw_multiline_string(f, Vector2(180, 500), part, HORIZONTAL_ALIGNMENT_LEFT, 920.0, 26, 4, Color("f2ecff"))
	var more := "Tap to continue" if idx < pages.size() - 1 else "Tap to begin"
	if shown >= text.length():
		draw_string(f, Vector2(140, 636), more, HORIZONTAL_ALIGNMENT_RIGHT, 970.0, 18, Color(1, 0.9, 0.5, 0.6 + 0.4 * sin(t * 4.0)))
	draw_string(f, Vector2(640, 90), "Page %d/%d" % [idx + 1, pages.size()], HORIZONTAL_ALIGNMENT_CENTER, 200.0, 18, Color(1, 1, 1, 0.4))
