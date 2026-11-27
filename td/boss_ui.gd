extends Control
# Boss presentation: an intro banner (portrait + name + story line) and a named health bar while the boss lives.
const PuppetLib = preload("res://puppet_lib.gd")
const OUT := Color("1d1230")
var banner_t := 0.0
var title := ""
var sub := ""
var sprite := ""
var boss
var boss_name := ""
const BANNER_LIFE := 3.4

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)

func show_intro(name_: String, line: String, sprite_id: String) -> void:
	title = name_
	sub = line
	sprite = sprite_id
	banner_t = BANNER_LIFE

func track(e, name_: String) -> void:
	boss = e
	boss_name = name_

func _process(delta: float) -> void:
	banner_t = maxf(0.0, banner_t - delta)
	queue_redraw()

func _txt(s: String, pos: Vector2, fs: int, col: Color, w: float = -1.0, al := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var f := ThemeDB.fallback_font
	draw_string_outline(f, pos, s, al, w, fs, 8, OUT)
	draw_string(f, pos, s, al, w, fs, col)

func _draw() -> void:
	if banner_t > 0.0:
		var u := BANNER_LIFE - banner_t
		var slide := clampf(u / 0.35, 0.0, 1.0)
		var out := clampf((banner_t) / 0.4, 0.0, 1.0)
		var a := minf(slide, out)
		var ox := (1.0 - slide) * -500.0
		draw_rect(Rect2(0, 150, 1280, 118), Color(0.25, 0.03, 0.08, 0.82 * a))
		draw_rect(Rect2(0, 150, 1280, 4), Color(1.0, 0.45, 0.3, a))
		draw_rect(Rect2(0, 264, 1280, 4), Color(1.0, 0.45, 0.3, a))
		if sprite != "":
			PuppetLib.draw(self, sprite, "idle", int(u * 6.0), false, 1.15, Vector2(190 + ox, 262), Color(1, 1, 1, a))
		_txt("ELDER", Vector2(300 + ox, 190), 22, Color(1.0, 0.75, 0.6, a))
		_txt(title.to_upper(), Vector2(300 + ox, 236), 52, Color(1.0, 0.92, 0.8, a))
		if sub != "":
			draw_multiline_string(ThemeDB.fallback_font, Vector2(640 + ox, 196), sub, HORIZONTAL_ALIGNMENT_LEFT, 560.0, 17, 3, Color(1, 0.85, 0.8, a))
	if boss != null and is_instance_valid(boss) and not boss.dead:
		var r := clampf(boss.hp / boss.max_hp, 0.0, 1.0)
		var x := 380.0
		var y := 100.0
		draw_rect(Rect2(x - 4, y - 4, 528, 30), OUT)
		draw_rect(Rect2(x, y, 520, 22), Color(0.12, 0.08, 0.22))
		draw_rect(Rect2(x, y, 520.0 * r, 22), Color("5aa8ff"))
		draw_rect(Rect2(x, y, 520.0 * r, 8), Color(1, 1, 1, 0.25))
		if boss.shield > 0.0:
			draw_rect(Rect2(x, y - 7, minf(520.0, boss.shield / maxf(1.0, boss.max_hp) * 520.0), 5), Color("bfe8ff"))
		_txt(boss_name, Vector2(x, y + 18), 17, Color.WHITE, 520.0, HORIZONTAL_ALIGNMENT_CENTER)
