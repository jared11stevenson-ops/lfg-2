extends RefCounted

static func poly(ci: CanvasItem, pts: PackedVector2Array, fill: Color, line: Color, w: float = 3.0) -> void:
	ci.draw_colored_polygon(pts, fill)
	var closed := pts.duplicate()
	closed.append(pts[0])
	ci.draw_polyline(closed, line, w, true)

static func disc(ci: CanvasItem, c: Vector2, r: float, fill: Color, line: Color, w: float = 3.0) -> void:
	ci.draw_circle(c, r + w * 0.5, line)
	ci.draw_circle(c, r - w * 0.5, fill)
