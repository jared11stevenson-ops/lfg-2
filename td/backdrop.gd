extends Node2D
# Painterly "midnight painting" backdrop, baked once per level into a texture (see make()).
# Brushy gradient ground, glowing lanes, rune stones, hazard zones and per-biome scenery with thick outlines.
const Levels = preload("res://levels.gd")
const TypeChart = preload("res://type_chart.gd")
const OUT := Color("1d1230")
var level: Dictionary
var paths: Array = []
var items: Array = []

static func make(parent: Node, lv: Dictionary) -> SubViewport:
	var vp := SubViewport.new()
	vp.size = Vector2i(1280, 720)
	vp.transparent_bg = false
	vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	var bd = load("res://backdrop.gd").new()
	bd.level = lv
	bd.paths = Levels.to_paths(lv)
	vp.add_child(bd)
	parent.add_child(vp)
	return vp

func _dist(p: Vector2) -> float:
	var best := INF
	for path in paths:
		for i in path.size() - 1:
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, path[i], path[i + 1])))
	return best

func _poly(pts: PackedVector2Array, fill: Color, ow: float = 3.0) -> void:
	draw_colored_polygon(pts, fill)
	var cl := pts.duplicate()
	cl.append(pts[0])
	draw_polyline(cl, OUT, ow, true)

func _blob(p: Vector2, rx: float, ry: float, fill: Color, ow: float = 3.0) -> void:
	var pts := PackedVector2Array()
	for i in 24:
		var a := TAU * i / 24.0
		pts.append(p + Vector2(cos(a) * rx, sin(a) * ry))
	_poly(pts, fill, ow)

func _stroke(a: Vector2, b: Vector2, w: float, col: Color) -> void:
	draw_line(a, b, OUT, w + 5.0, true)
	draw_circle(a, w * 0.5 + 2.5, OUT)
	draw_circle(b, w * 0.5 + 2.5, OUT)
	draw_line(a, b, col, w, true)
	draw_circle(a, w * 0.5, col)
	draw_circle(b, w * 0.5, col)

func _draw() -> void:
	var c: Dictionary = level.colors
	var g1 := Color(c.g1)
	var g2 := Color(c.g2)
	var acc := Color(c.accent)
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(String(level.name))
	for i in 36:
		draw_rect(Rect2(0, i * 20, 1280, 21), g1.lerp(g2, float(i) / 35.0))
	# soft brush strokes
	for i in 320:
		var col := g1.lerp(g2, rng.randf()).lightened(rng.randf_range(-0.1, 0.12)) if rng.randf() < 0.75 else acc
		col.a = rng.randf_range(0.05, 0.13) if col != acc else rng.randf_range(0.03, 0.07)
		draw_set_transform(Vector2(rng.randf_range(0, 1280), rng.randf_range(0, 720)), rng.randf_range(-0.6, 0.6), Vector2(1.0, rng.randf_range(0.12, 0.3)))
		draw_circle(Vector2.ZERO, rng.randf_range(30, 90), col)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# moonlight pool
	var moon := Color(c.moon)
	for i in 14:
		draw_circle(Vector2(1060, 150), 40.0 + i * 26.0, Color(moon.r, moon.g, moon.b, 0.018))
	# lanes: glow, edge, fill, highlight, cobbles
	var glow := Color(c.glow)
	for path in paths:
		draw_polyline(path, Color(glow.r, glow.g, glow.b, 0.14), 112.0, true)
		draw_polyline(path, Color(glow.r, glow.g, glow.b, 0.12), 96.0, true)
	for path in paths:
		for p in path:
			draw_circle(p, 41.0, Color(c.edge))
		draw_polyline(path, Color(c.edge), 82.0, true)
	for path in paths:
		for p in path:
			draw_circle(p, 34.0, Color(c.path))
		draw_polyline(path, Color(c.path), 68.0, true)
	for path in paths:
		draw_polyline(path, Color(1, 1, 1, 0.12), 44.0, true)
	var crng := RandomNumberGenerator.new()
	crng.seed = 99
	for path in paths:
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var n := int(a.distance_to(b) / 26.0)
			for k in n:
				var q := a.lerp(b, float(k) / maxf(1.0, n)) + Vector2(crng.randf_range(-20, 20), crng.randf_range(-20, 20)) * 0.9
				draw_circle(q, crng.randf_range(2.0, 4.5), Color(0, 0, 0, 0.1))
	# zones
	for z in level.zones:
		_zone(Vector2(z.pos[0], z.pos[1]), float(z.r), String(z.kind))
	# rune stones
	for s in level.stones:
		_stone(Vector2(s[0], s[1]), String(s[2]))
	# scenery
	_scatter(rng)
	# vignette
	for i in 10:
		var inset := float(i) * 14.0
		var a := 0.07 * (1.0 - float(i) / 10.0)
		draw_rect(Rect2(0, 0, 1280, inset + 14.0), Color(0, 0, 0, a))
		draw_rect(Rect2(0, 720 - inset - 14.0, 1280, inset + 14.0), Color(0, 0, 0, a))
		draw_rect(Rect2(0, 0, inset + 14.0, 720), Color(0, 0, 0, a))
		draw_rect(Rect2(1280 - inset - 14.0, 0, inset + 14.0, 720), Color(0, 0, 0, a))

func _zone(p: Vector2, r: float, kind: String) -> void:
	match kind:
		"bog":
			draw_circle(p, r, Color(0.1, 0.2, 0.1, 0.55))
			draw_circle(p, r * 0.8, Color(0.2, 0.35, 0.15, 0.6))
			for i in 6:
				draw_circle(p + Vector2(cos(i * 1.3), sin(i * 2.1)) * r * 0.5, 5.0, Color(0.7, 0.9, 0.4, 0.8))
		"ice":
			draw_circle(p, r, Color(0.75, 0.9, 1.0, 0.45))
			draw_circle(p, r * 0.7, Color(0.9, 0.97, 1.0, 0.5))
			for i in 4:
				draw_line(p, p + Vector2.from_angle(i * 1.6 + 0.4) * r * 0.9, Color(1, 1, 1, 0.8), 2.0, true)
		"burn":
			draw_circle(p, r, Color(0.2, 0.05, 0.05, 0.7))
			draw_circle(p, r * 0.75, Color(1.0, 0.35, 0.1, 0.5))
			for i in 5:
				draw_line(p, p + Vector2.from_angle(i * 1.3) * r * 0.8, Color(1.0, 0.75, 0.2, 0.9), 3.0, true)
		"belt":
			draw_circle(p, r, Color(0.15, 0.15, 0.2, 0.6))
			for i in 3:
				var x := p.x - 24.0 + i * 24.0
				draw_polyline(PackedVector2Array([Vector2(x - 8, p.y - 14), Vector2(x + 8, p.y), Vector2(x - 8, p.y + 14)]), Color(1.0, 0.85, 0.3), 5.0, true)

func _stone(p: Vector2, type: String) -> void:
	var col: Color = TypeChart.COLORS.get(type, Color.WHITE)
	for i in 4:
		draw_circle(p, 52.0 - i * 6.0, Color(col.r, col.g, col.b, 0.07))
	draw_arc(p, 42.0, 0, TAU, 40, OUT, 7.0, true)
	draw_arc(p, 42.0, 0, TAU, 40, col, 3.5, true)
	var pts := PackedVector2Array()
	for i in 10:
		var a := PI * i / 5.0 - PI / 2.0
		pts.append(p + Vector2.from_angle(a) * (22.0 if i % 2 == 0 else 9.0))
	draw_colored_polygon(pts, Color(col.r, col.g, col.b, 0.85))
	var cl := pts.duplicate()
	cl.append(pts[0])
	draw_polyline(cl, OUT, 2.0, true)

func _scatter(rng: RandomNumberGenerator) -> void:
	var style := String(level.style)
	var placed: Array = []
	var tries := 0
	while placed.size() < 70 and tries < 900:
		tries += 1
		var p := Vector2(rng.randf_range(20, 1260), rng.randf_range(30, 700))
		if _dist(p) < 66.0 or (p.y > 598 and p.x < 940) or (p.y > 540 and p.x > 1040) or (p.y < 112 and p.x > 1060):
			continue
		var near := false
		for s in level.stones:
			if p.distance_to(Vector2(s[0], s[1])) < 56.0:
				near = true
		for q in placed:
			if p.distance_to(q) < 38.0:
				near = true
		if near:
			continue
		placed.append(p)
	placed.sort_custom(func(a, b): return a.y < b.y)
	for p in placed:
		_item(style, p, rng.randi() % 4, rng.randf_range(0.8, 1.25), rng)

func _item(style: String, p: Vector2, k: int, z: float, rng: RandomNumberGenerator) -> void:
	var acc := Color(level.colors.accent)
	match style:
		"meadow":
			match k:
				0: _lolly_tree(p, z, Color("3f9a6a"), Color("7a4a6a"))
				1: _mushroom(p, z, Color("e8503a"))
				2: _tuft(p, z, Color("7fd8a8"))
				_: _rock(p, z, Color("8a8aa8"))
		"snow":
			match k:
				0: _pine(p, z, Color("2f7a68"))
				1: _rock(p, z, Color("a8b8d8"))
				2: _crystal(p, z, Color("bfe8ff"))
				_: _mound(p, z, Color("f0f8ff"))
		"desert":
			match k:
				0: _cactus(p, z, Color("4a9a5a"))
				1: _rock(p, z, Color("b0704a"))
				2: _tuft(p, z, Color("e8a060"))
				_: _bones(p, z)
		"forest":
			match k:
				0: _twisted_tree(p, z, Color("2f5a4a"), Color("6a4a8a"))
				1: _mushroom(p, z, Color("40d8b0"))
				2: _tuft(p, z, Color("5ad8a0"))
				_: _lantern(p, z, Color("ffd06a"))
		"marsh":
			match k:
				0: _reeds(p, z, Color("9ab050"))
				1: _lily(p, z)
				2: _mushroom(p, z, Color("c8d850"))
				_: _stump(p, z, Color("6a5a3a"))
		"mesa":
			match k:
				0: _pillar(p, z, Color("8a7ab8"))
				1: _crystal(p, z, Color("ffe36a"))
				2: _tuft(p, z, Color("c8b8e8"))
				_: _flag(p, z)
		"factory":
			match k:
				0: _gear(p, z, Color("c8a050"))
				1: _barrel(p, z, Color("7a5a3a"))
				2: _lantern(p, z, Color("ffc860"))
				_: _pipe(p, z)
		"coast":
			match k:
				0: _coral(p, z, Color("ff9a8a"))
				1: _shell(p, z)
				2: _lantern(p, z, Color("9fffe0"))
				_: _rock(p, z, Color("5a8aa8"))
		"volcano":
			match k:
				0: _spire(p, z, Color("5a2a2a"))
				1: _crystal(p, z, Color("ff7a3a"))
				2: _vent(p, z)
				_: _rock(p, z, Color("6a3a3a"))
		_:
			match k:
				0: _crystal(p, z, Color("ff9ad8"))
				1: _mushroom(p, z, Color("9fffe0"))
				2: _spiral(p, z, acc)
				_: _pillar(p, z, Color("7a5aa8"))

# ---- scenery drawers ----
func _lolly_tree(p: Vector2, z: float, leaf: Color, trunk: Color) -> void:
	_stroke(p + Vector2(0, 6) * z, p + Vector2(4, -26) * z, 7.0 * z, trunk)
	_blob(p + Vector2(4, -42) * z, 22 * z, 20 * z, leaf)
	draw_arc(p + Vector2(4, -42) * z, 9 * z, 0.5, 4.8, 12, leaf.lightened(0.3), 3.0, true)

func _twisted_tree(p: Vector2, z: float, leaf: Color, trunk: Color) -> void:
	var pts := PackedVector2Array([p + Vector2(0, 8) * z, p + Vector2(10, -14) * z, p + Vector2(-8, -34) * z, p + Vector2(6, -52) * z])
	for i in pts.size() - 1:
		_stroke(pts[i], pts[i + 1], (9 - i * 2) * z, trunk)
	_blob(p + Vector2(6, -62) * z, 20 * z, 14 * z, leaf)
	draw_circle(p + Vector2(-2, -62) * z, 4 * z, Color(level.colors.accent))

func _pine(p: Vector2, z: float, leaf: Color) -> void:
	_stroke(p + Vector2(0, 8) * z, p + Vector2(0, -6) * z, 7 * z, Color("5a3a2a"))
	for k in 3:
		var w := (24 - k * 6) * z
		var y := (-4 - k * 16) * z
		_poly(PackedVector2Array([p + Vector2(-w, y), p + Vector2(w, y), p + Vector2(0, y - 24 * z)]), leaf, 3.0)
		draw_line(p + Vector2(-w * 0.55, y - 8 * z), p + Vector2(w * 0.55, y - 8 * z), Color(0.95, 0.98, 1.0), 4.0 * z, true)

func _mushroom(p: Vector2, z: float, cap: Color) -> void:
	_stroke(p + Vector2(0, 6) * z, p + Vector2(0, -8) * z, 8 * z, Color("f0e6d0"))
	_blob(p + Vector2(0, -14) * z, 16 * z, 11 * z, cap)
	for i in 3:
		draw_circle(p + Vector2(-8 + i * 8, -16 - (i % 2) * 4) * z, 2.6 * z, Color(1, 1, 1, 0.9))

func _tuft(p: Vector2, z: float, col: Color) -> void:
	for i in 4:
		_stroke(p + Vector2(i * 5 - 8, 4) * z, p + Vector2(i * 7 - 12, -14 - (i % 2) * 6) * z, 3.5 * z, col)

func _rock(p: Vector2, z: float, col: Color) -> void:
	_blob(p, 15 * z, 10 * z, col)
	draw_arc(p + Vector2(-3, -2) * z, 8 * z, 3.6, 5.2, 8, col.lightened(0.3), 2.5, true)

func _crystal(p: Vector2, z: float, col: Color) -> void:
	for i in 3:
		var h := (22 + (i % 2) * 12) * z
		var x := (i - 1) * 9 * z
		_poly(PackedVector2Array([p + Vector2(x - 5 * z, 6), p + Vector2(x, -h), p + Vector2(x + 5 * z, 6)]), col.lightened(i * 0.1), 2.5)

func _mound(p: Vector2, z: float, col: Color) -> void:
	_blob(p, 22 * z, 9 * z, col, 2.5)

func _cactus(p: Vector2, z: float, col: Color) -> void:
	_stroke(p + Vector2(0, 8) * z, p + Vector2(0, -30) * z, 11 * z, col)
	_stroke(p + Vector2(0, -8) * z, p + Vector2(-14, -14) * z, 7 * z, col)
	_stroke(p + Vector2(-14, -14) * z, p + Vector2(-14, -26) * z, 7 * z, col)
	_stroke(p + Vector2(0, -16) * z, p + Vector2(13, -22) * z, 7 * z, col)

func _bones(p: Vector2, z: float) -> void:
	_stroke(p + Vector2(-12, 0) * z, p + Vector2(12, -4) * z, 5 * z, Color("f0e6d0"))
	_blob(p + Vector2(-14, 0) * z, 5 * z, 4 * z, Color("f0e6d0"), 2.0)

func _reeds(p: Vector2, z: float, col: Color) -> void:
	for i in 5:
		var x := (i - 2) * 5 * z
		_stroke(p + Vector2(x, 8), p + Vector2(x + (i - 2) * 2, -26 - (i % 2) * 8) * z, 3 * z, col)
	_blob(p + Vector2(0, -34) * z, 4 * z, 8 * z, Color("6a4a2a"), 2.0)

func _lily(p: Vector2, z: float) -> void:
	_blob(p, 16 * z, 8 * z, Color("5aa850"))
	draw_circle(p + Vector2(4, -2) * z, 4 * z, Color("ff9ab0"))

func _stump(p: Vector2, z: float, col: Color) -> void:
	_blob(p + Vector2(0, 4), 12 * z, 7 * z, col)
	_blob(p + Vector2(0, -6) * z, 12 * z, 7 * z, col.lightened(0.15))

func _pillar(p: Vector2, z: float, col: Color) -> void:
	_poly(PackedVector2Array([p + Vector2(-14, 6) * z, p + Vector2(-10, -40) * z, p + Vector2(12, -44) * z, p + Vector2(16, 6) * z]), col, 3.0)
	draw_line(p + Vector2(-8, -28) * z, p + Vector2(10, -30) * z, col.lightened(0.25), 3.0 * z, true)

func _flag(p: Vector2, z: float) -> void:
	_stroke(p + Vector2(0, 8) * z, p + Vector2(0, -34) * z, 4 * z, Color("6a4a2a"))
	_poly(PackedVector2Array([p + Vector2(0, -34) * z, p + Vector2(22, -28) * z, p + Vector2(0, -18) * z]), Color("ffe36a"), 2.5)

func _gear(p: Vector2, z: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 16:
		var a := TAU * i / 16.0
		pts.append(p + Vector2.from_angle(a) * (16.0 if i % 2 == 0 else 12.0) * z)
	_poly(pts, col, 2.5)
	draw_circle(p, 5 * z, OUT)

func _barrel(p: Vector2, z: float, col: Color) -> void:
	_blob(p, 11 * z, 14 * z, col)
	draw_line(p + Vector2(-11, -4) * z, p + Vector2(11, -4) * z, OUT, 2.5, true)
	draw_line(p + Vector2(-11, 5) * z, p + Vector2(11, 5) * z, OUT, 2.5, true)

func _pipe(p: Vector2, z: float) -> void:
	_stroke(p + Vector2(-18, 0) * z, p + Vector2(6, 0) * z, 9 * z, Color("7a7a8a"))
	_stroke(p + Vector2(6, 0) * z, p + Vector2(6, -18) * z, 9 * z, Color("7a7a8a"))

func _lantern(p: Vector2, z: float, col: Color) -> void:
	_stroke(p + Vector2(0, 8) * z, p + Vector2(0, -26) * z, 4 * z, Color("3a2a4a"))
	draw_circle(p + Vector2(0, -34) * z, 18 * z, Color(col.r, col.g, col.b, 0.2))
	_blob(p + Vector2(0, -34) * z, 7 * z, 9 * z, col)

func _coral(p: Vector2, z: float, col: Color) -> void:
	_stroke(p + Vector2(0, 6) * z, p + Vector2(0, -20) * z, 6 * z, col)
	_stroke(p + Vector2(0, -10) * z, p + Vector2(-12, -24) * z, 5 * z, col)
	_stroke(p + Vector2(0, -14) * z, p + Vector2(12, -28) * z, 5 * z, col)

func _shell(p: Vector2, z: float) -> void:
	_blob(p, 13 * z, 9 * z, Color("f4d8c8"))
	draw_arc(p, 7 * z, 0.2, 5.0, 12, OUT, 2.0, true)

func _spire(p: Vector2, z: float, col: Color) -> void:
	_poly(PackedVector2Array([p + Vector2(-14, 6) * z, p + Vector2(-4, -36) * z, p + Vector2(4, -16) * z, p + Vector2(12, -30) * z, p + Vector2(18, 6) * z]), col, 3.0)
	draw_line(p + Vector2(-2, -10) * z, p + Vector2(4, 2) * z, Color(1.0, 0.5, 0.2), 3.0, true)

func _vent(p: Vector2, z: float) -> void:
	_blob(p, 16 * z, 8 * z, Color("4a2222"))
	_blob(p, 9 * z, 4 * z, Color("ff7a3a"), 2.0)

func _spiral(p: Vector2, z: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 30:
		var a := i * 0.45
		pts.append(p + Vector2(cos(a), sin(a)) * (2.0 + i * 0.5) * z + Vector2(0, -14))
	draw_polyline(pts, OUT, 7.0, true)
	draw_polyline(pts, col, 3.5, true)
