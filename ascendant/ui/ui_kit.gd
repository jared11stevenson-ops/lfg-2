class_name UiKit
extends RefCounted
## Parchment-and-ink widgets shared by every menu.
const PARCH := Color(0.93, 0.87, 0.72)
const INK := Color(0.16, 0.12, 0.2)
const GOLD := Color(0.78, 0.6, 0.22)
const RUST := Color(0.66, 0.27, 0.2)

## Controls parented to a CanvasLayer get no layout rect: pin them to the viewport explicitly.
static func fit(c: Control) -> void:
	var apply := func(): c.position = Vector2.ZERO; c.size = c.get_viewport_rect().size
	apply.call()
	c.get_viewport().size_changed.connect(apply)

static func panel(c: CanvasItem, r: Rect2, a: float = 0.95) -> void:
	var sh := r; sh.position += Vector2(4, 6)
	c.draw_rect(sh, Color(0, 0, 0, 0.3 * a))
	c.draw_rect(r, Color(PARCH.r, PARCH.g, PARCH.b, a))
	c.draw_rect(r, INK, false, 2.5)
	c.draw_rect(r.grow(-5), Color(GOLD.r, GOLD.g, GOLD.b, 0.7), false, 1.2)
	for k in 4:  # corner flourishes
		var cx := r.position.x + (r.size.x if k % 2 == 1 else 0.0); var cy := r.position.y + (r.size.y if k >= 2 else 0.0)
		c.draw_circle(Vector2(cx, cy), 5.0, GOLD); c.draw_arc(Vector2(cx, cy), 5.0, 0, TAU, 10, INK, 1.5, true)

static func text_c(c: CanvasItem, s: String, p: Vector2, size: int, col: Color, w: float = -1.0, align: int = HORIZONTAL_ALIGNMENT_LEFT) -> void:
	c.draw_string(ThemeDB.fallback_font, p, s, align, w, size, col)

static func title_text(c: CanvasItem, s: String, p: Vector2, size: int) -> void:
	var f := ThemeDB.fallback_font
	for o in [Vector2(3, 5), Vector2(-2, 3), Vector2(2, -2)]:
		c.draw_string(f, p + o, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.05, 0.03, 0.1, 0.8))
	c.draw_string(f, p, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color(0.97, 0.9, 0.7))

## Hit-tested button list helper used by menus (immediate-mode style).
class Btn:
	var rect: Rect2
	var label: String
	var id: String
	var enabled := true
	var hover := false

static func draw_btn(c: CanvasItem, b: Btn, t: float) -> void:
	var r := b.rect
	var lift := 3.0 if b.hover and b.enabled else 0.0
	r.position.y -= lift
	var a := 1.0 if b.enabled else 0.5
	c.draw_rect(Rect2(r.position + Vector2(3, 5 + lift), r.size), Color(0, 0, 0, 0.35 * a))
	var fill := PARCH.lerp(Color(1.0, 0.95, 0.75), 0.6 if b.hover else 0.0)
	c.draw_rect(r, Color(fill.r, fill.g, fill.b, a))
	c.draw_rect(r, INK, false, 2.5)
	c.draw_rect(r.grow(-4), Color(GOLD.r, GOLD.g, GOLD.b, 0.8 if b.hover else 0.45), false, 1.2)
	var f := ThemeDB.fallback_font
	var ts := f.get_string_size(b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22)
	c.draw_string(f, r.position + Vector2((r.size.x - ts.x) * 0.5, r.size.y * 0.5 + 8), b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, INK if b.enabled else INK.lightened(0.4))

static func slider(c: CanvasItem, r: Rect2, v: float, label: String) -> void:
	text_c(c, label, r.position + Vector2(0, -6), 15, INK)
	c.draw_rect(Rect2(r.position + Vector2(0, 6), Vector2(r.size.x, 8)), Color(0.3, 0.22, 0.2, 0.45))
	c.draw_rect(Rect2(r.position + Vector2(0, 6), Vector2(r.size.x * v, 8)), GOLD)
	c.draw_rect(Rect2(r.position + Vector2(0, 6), Vector2(r.size.x, 8)), INK, false, 1.5)
	c.draw_circle(r.position + Vector2(r.size.x * v, 10), 9, PARCH); c.draw_arc(r.position + Vector2(r.size.x * v, 10), 9, 0, TAU, 14, INK, 2.0, true)

static func checkbox(c: CanvasItem, p: Vector2, on: bool, label: String) -> void:
	c.draw_rect(Rect2(p, Vector2(22, 22)), PARCH); c.draw_rect(Rect2(p, Vector2(22, 22)), INK, false, 2.0)
	if on:
		c.draw_line(p + Vector2(4, 11), p + Vector2(10, 17), RUST, 3.0, true); c.draw_line(p + Vector2(10, 17), p + Vector2(19, 4), RUST, 3.0, true)
	text_c(c, label, p + Vector2(32, 17), 17, INK)
