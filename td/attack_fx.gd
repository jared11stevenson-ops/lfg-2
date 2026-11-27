extends RefCounted
# Type-matched attack effects drawn on top of a defender while it attacks (k = 0 at the strike frame, 1 at the end).
# The creature's own pose supplies anticipation / strike / follow-through; these add the elemental payoff at the anchors
# baked into anim_meta.gd (mouth, lantern, spout, paw...). U is the screen size of one logical sprite pixel.

static func _a(meta: Dictionary, name: String, flip: bool, s: float, off: Vector2) -> Vector2:
	var a: Array = meta.get("anchors", {}).get(name, [40.0, -40.0])
	return off + Vector2((-1.0 if flip else 1.0) * float(a[0]), float(a[1])) * s

# A flame tongue: wide soft base, pointed tip. dir is a unit vector.
static func _flame(ci: CanvasItem, p: Vector2, dir: Vector2, len: float, w: float, col: Color) -> void:
	var n := Vector2(-dir.y, dir.x)
	var pts := PackedVector2Array([p + n * w * 0.5, p + dir * len * 0.45 + n * w * 0.62, p + dir * len + n * w * 0.05, p + dir * len * 0.62 - n * w * 0.3, p + dir * len * 0.3 - n * w * 0.55, p - n * w * 0.5])
	ci.draw_colored_polygon(pts, col)

static func _puff(ci: CanvasItem, p: Vector2, r: float, col: Color) -> void:
	ci.draw_circle(p, r, Color(col.r, col.g, col.b, col.a * 0.35))
	ci.draw_circle(p, r * 0.7, Color(col.r, col.g, col.b, col.a * 0.6))
	ci.draw_circle(p + Vector2(-r * 0.2, -r * 0.2), r * 0.35, Color(minf(1.0, col.r + 0.25), minf(1.0, col.g + 0.25), minf(1.0, col.b + 0.25), col.a * 0.7))

static func draw(ci: CanvasItem, who: String, types: Array, meta: Dictionary, k: float, flip: bool, s: float, off: Vector2) -> void:
	if k < 0.0 or k > 1.0 or meta.is_empty():
		return
	var d := -1.0 if flip else 1.0
	var u := s * 1.35
	var fade := 1.0 - k
	match who:
		"tickindle":    # Ember/Forge: a cone of flame from the mouth, tail flare, hot sparks kicked up at the paws
			var m := _a(meta, "muzzle", flip, s, off)
			var grow := sin(minf(1.0, k * 1.6) * PI * 0.5)
			for i in 5:
				var ang := (-0.42 + 0.21 * i)
				var dir := Vector2(cos(ang) * d, sin(ang))
				var L := (26.0 + 22.0 * (1.0 - absf(i - 2) * 0.28)) * u * (0.45 + 0.8 * grow)
				_flame(ci, m, dir, L, 15.0 * u * fade + 3.0 * u, Color(1.0, 0.42, 0.08, 0.8 * fade))
				_flame(ci, m, dir, L * 0.7, 8.0 * u * fade + 2.0 * u, Color(1.0, 0.82, 0.28, 0.9 * fade))
			ci.draw_circle(m, (10.0 - 6.0 * k) * u, Color(1.0, 0.97, 0.7, 0.9 * fade))
			var f := _a(meta, "flame", flip, s, off)
			ci.draw_circle(f, (16.0 + 14.0 * sin(k * PI)) * u, Color(1.0, 0.5, 0.12, 0.28 * fade))
			ci.draw_circle(f, (9.0 + 8.0 * sin(k * PI)) * u, Color(1.0, 0.85, 0.35, 0.4 * fade))
			var pw := _a(meta, "paw", flip, s, off)
			for i in 6:
				var a2 := -PI * (0.12 + 0.15 * i)
				var q := pw + Vector2(cos(a2) * d, sin(a2)) * (5.0 + 26.0 * k) * u + Vector2(0, 14.0 * k * k) * u
				ci.draw_circle(q, (2.6 - 1.8 * k) * u, Color(1.0, 0.82, 0.3, 0.95 * fade))
		"dugloom":      # Tide/Spirit: lantern flare, expanding rings of spirit light, a water ripple on the ground, rising droplets
			var l := _a(meta, "lantern", flip, s, off)
			for i in 6:
				ci.draw_circle(l, (30.0 - i * 4.0 + 6.0 * sin(k * PI)) * u, Color(1.0, 0.95, 0.65, 0.055 * fade * (i + 1)))
			for i in 3:
				var kk := clampf(k * 1.35 - 0.2 * i, 0.0, 1.0)
				ci.draw_arc(l, (10.0 + 62.0 * kk) * u, 0, TAU, 44, Color(0.72, 1.0, 0.95, 0.65 * (1.0 - kk)), 3.0 * u * (1.0 - 0.4 * kk), true)
			var g := off + Vector2(0, 2)
			ci.draw_set_transform(g, 0.0, Vector2(1.0, 0.38))
			for i in 2:
				var kk2 := clampf(k * 1.2 - 0.18 * i, 0.0, 1.0)
				ci.draw_arc(Vector2.ZERO, (24.0 + 80.0 * kk2) * u, 0, TAU, 44, Color(0.45, 0.85, 1.0, 0.6 * (1.0 - kk2)), 4.5 * u, true)
			ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
			for i in 7:
				var a3 := -PI * (0.08 + 0.14 * i)
				var pos := l + Vector2(cos(a3), sin(a3)) * (10.0 + 36.0 * k) * u + Vector2(0, 26.0 * k * k) * u
				ci.draw_circle(pos, (2.8 - 1.8 * k) * u, Color(0.65, 0.92, 1.0, 0.9 * fade))
		"hutzin":       # Verdant/Venom: green and violet spore cloud blown from the beak, steam burst from the spout
			var m2 := _a(meta, "muzzle", flip, s, off)
			for i in 9:
				var a4 := -0.5 + 0.13 * i
				var spread := 6.0 + 34.0 * k
				var pos2 := m2 + Vector2(cos(a4) * d, sin(a4)) * spread * u * (0.5 + 0.08 * i) + Vector2(0, -8.0 * k) * u
				var col := Color(0.5, 0.92, 0.3, 1.0 * fade) if i % 2 == 0 else Color(0.62, 0.3, 0.85, 1.0 * fade)
				_puff(ci, pos2, (10.0 + 12.0 * k) * u, col)
			var sp := _a(meta, "spout", flip, s, off)
			for i in 4:
				_puff(ci, sp + Vector2(sin(k * 5.0 + i * 1.7) * 7.0, -9.0 * i - 46.0 * k) * u, (5.0 + 3.5 * k + i) * u, Color(0.93, 0.96, 0.93, 0.7 * fade))
		"shuckit":      # Umbra/Gale: a shadow crescent where the bite lands and short wind streaks behind it
			var m3 := _a(meta, "muzzle", flip, s, off)
			var c := m3 + Vector2(-4.0 * d, 2.0) * u
			var rad := (15.0 + 20.0 * k) * u
			var a0 := -1.15
			var a1 := 1.15
			var sa := (PI - a1) if flip else a0
			var ea := (PI - a0) if flip else a1
			ci.draw_arc(c, rad, sa, ea, 20, Color(0.2, 0.1, 0.4, 0.55 * fade), 11.0 * u * fade + 2.0, true)
			ci.draw_arc(c, rad, sa, ea, 20, Color(0.75, 0.55, 1.0, 0.8 * fade), 4.5 * u * fade + 1.0, true)
			for i in 3:
				var y := -9.0 + 9.0 * i
				ci.draw_line(m3 + Vector2((-6.0 - 18.0 * k) * d, y) * u, m3 + Vector2((-28.0 - 40.0 * k) * d, y + 1.0) * u, Color(0.82, 0.95, 0.9, 0.7 * fade), 2.0 * u, true)
