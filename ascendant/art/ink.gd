class_name Ink
extends RefCounted
## "Illuminated Bestiary" drawing kit: painterly dome/strip meshes with hue-shifted lighting
## and hand-inked outlines. All creature, plant and structure art is built from these primitives.

const LIGHT := Vector3(-0.42, -0.62, 0.66)  # from upper-left, above
static var L: Vector3 = LIGHT.normalized()

## Hue-shifted painterly shading: shadows go cool/violet, lights go warm.
static func shade(base: Color, n: Vector3, rot: float = 0.0, amb: float = 0.0) -> Color:
	if rot != 0.0:
		var c := cos(rot); var s := sin(rot)
		n = Vector3(n.x * c - n.y * s, n.x * s + n.y * c, n.z)
	var d := clampf(n.dot(L), 0.0, 1.0)
	d = smoothstep(0.0, 0.95, d)
	var shadow := base.darkened(0.42).lerp(Color(0.16, 0.12, 0.34), 0.22)
	var lit := base.lightened(0.22).lerp(Color(1.0, 0.92, 0.62), 0.14)
	var c2 := shadow.lerp(lit, clampf(d + amb, 0.0, 1.0))
	# rim darkening toward silhouette gives a rounded, inked feel
	var rim := pow(1.0 - clampf(n.z, 0.0, 1.0), 2.5)
	c2 = c2.lerp(shadow.darkened(0.2), rim * 0.55)
	c2.a = base.a
	return c2

static func ink_color(base: Color) -> Color:
	var c := base.darkened(0.62)
	c = c.lerp(Color(0.09, 0.07, 0.15), 0.45)
	c.a = base.a
	return c

class Batch:
	extends RefCounted
	var pts := PackedVector2Array()
	var cols := PackedColorArray()
	var idx := PackedInt32Array()
	func vert(p: Vector2, c: Color) -> int:
		pts.append(p); cols.append(c)
		return pts.size() - 1
	func tri(a: int, b: int, c: int) -> void:
		idx.append(a); idx.append(b); idx.append(c)
	func quad(a: int, b: int, c: int, d: int) -> void:
		tri(a, b, c); tri(a, c, d)
	func flush(item: RID) -> void:
		if idx.size() > 0:
			RenderingServer.canvas_item_add_triangle_array(item, idx, pts, cols)
		pts.clear(); cols.clear(); idx.clear()

## Radial dome (ellipse) with volumetric shading. axis = angle of the local x-axis.
static func dome(b: Batch, c: Vector2, rx: float, ry: float, axis: float, base: Color, rot: float, seg: int = 20, pat: Callable = Callable()) -> void:
	var ca := cos(axis); var sa := sin(axis)
	var center := b.vert(c, shade(base, Vector3(0, 0, 1), rot))
	var rings := 3
	var prev: Array = []
	for r in range(1, rings + 1):
		var u := float(r) / rings
		var cur: Array = []
		for i in seg:
			var th := TAU * i / seg
			var lx := cos(th); var ly := sin(th)
			var p := Vector2(lx * rx * u, ly * ry * u)
			var wp := c + Vector2(p.x * ca - p.y * sa, p.x * sa + p.y * ca)
			var nz := sqrt(maxf(0.0, 1.0 - u * u))
			var nl := Vector3(lx * u, ly * u, nz)
			var nw := Vector3(nl.x * ca - nl.y * sa, nl.x * sa + nl.y * ca, nl.z)
			var col := base
			if pat.is_valid():
				col = pat.call(wp - c, base)
			cur.append(b.vert(wp, shade(col, nw, rot)))
		if r == 1:
			for i in seg:
				b.tri(center, cur[i], cur[(i + 1) % seg])
		else:
			for i in seg:
				var j := (i + 1) % seg
				b.quad(prev[i], cur[i], cur[j], prev[j])
		prev = cur

static func dome_outline(item: CanvasItem, c: Vector2, rx: float, ry: float, axis: float, col: Color, w: float = 1.6, seg: int = 28) -> void:
	var ca := cos(axis); var sa := sin(axis)
	var pts := PackedVector2Array()
	for i in seg + 1:
		var th := TAU * i / seg
		var p := Vector2(cos(th) * rx, sin(th) * ry)
		pts.append(c + Vector2(p.x * ca - p.y * sa, p.x * sa + p.y * ca))
	item.draw_polyline(pts, col, w, true)

## Smooth (Catmull-Rom) resample of a polyline.
static func smooth(pts: Array, per: int = 4) -> PackedVector2Array:
	var out := PackedVector2Array()
	var n := pts.size()
	if n < 3:
		for p in pts: out.append(p)
		return out
	for i in n - 1:
		var p0: Vector2 = pts[maxi(i - 1, 0)]
		var p1: Vector2 = pts[i]
		var p2: Vector2 = pts[i + 1]
		var p3: Vector2 = pts[mini(i + 2, n - 1)]
		for k in per:
			var t := float(k) / per
			var t2 := t * t; var t3 := t2 * t
			out.append(0.5 * ((2.0 * p1) + (-p0 + p2) * t + (2.0 * p0 - 5.0 * p1 + 4.0 * p2 - p3) * t2 + (-p0 + 3.0 * p1 - 3.0 * p2 + p3) * t3))
	out.append(pts[n - 1])
	return out

## Body strip along a spine with per-point half-width. rows lateral subdivisions.
## Returns {left:PackedVector2Array, right:PackedVector2Array} for outlining.
static func strip(b: Batch, spine: PackedVector2Array, widths: PackedFloat32Array, base: Color, rot: float, belly: Color = Color(0, 0, 0, 0), pat: Callable = Callable(), rows: int = 5) -> Dictionary:
	var n := spine.size()
	var left := PackedVector2Array(); var right := PackedVector2Array()
	var grid: Array = []
	for i in n:
		var dir: Vector2
		if i == 0: dir = spine[1] - spine[0]
		elif i == n - 1: dir = spine[n - 1] - spine[n - 2]
		else: dir = spine[i + 1] - spine[i - 1]
		dir = dir.normalized()
		var lat := Vector2(-dir.y, dir.x)
		var row: Array = []
		for r in rows:
			var u := -1.0 + 2.0 * float(r) / (rows - 1)  # -1..1 across the body
			var p := spine[i] + lat * (u * widths[i])
			var nz := sqrt(maxf(0.0, 1.0 - u * u))
			var nl := lat * u
			var col := base
			if belly.a > 0.0:
				# belly side = lateral edges lighten toward belly colour
				col = base.lerp(belly, smoothstep(0.55, 1.0, absf(u)) * 0.85)
			if pat.is_valid():
				col = pat.call(float(i) / (n - 1), u, col)
			row.append(b.vert(p, shade(col, Vector3(nl.x, nl.y, nz), rot)))
			if r == 0: left.append(p)
			if r == rows - 1: right.append(p)
		grid.append(row)
	for i in n - 1:
		for r in rows - 1:
			b.quad(grid[i][r], grid[i + 1][r], grid[i + 1][r + 1], grid[i][r + 1])
	return {"left": left, "right": right}

## Tapered limb segment (capsule-like) between two points.
static func limb(b: Batch, a: Vector2, c: Vector2, wa: float, wc: float, base: Color, rot: float) -> void:
	var sp := PackedVector2Array([a, a.lerp(c, 0.5), c])
	var ws := PackedFloat32Array([wa, (wa + wc) * 0.5, wc])
	strip(b, sp, ws, base, rot, Color(0, 0, 0, 0), Callable(), 3)

static func outline_poly(item: CanvasItem, left: PackedVector2Array, right: PackedVector2Array, col: Color, w: float) -> void:
	var pts := PackedVector2Array()
	pts.append_array(left)
	var r2 := right.duplicate()
	r2.reverse()
	pts.append_array(r2)
	if pts.size() > 2:
		pts.append(pts[0])
		item.draw_polyline(pts, col, w, true)

## Harmonised palette from three heritable colour loci. Constrains saturation/value to a
## "dusk watercolour" gamut so random genetics cannot yield garish or muddy animals.
static func palette(hue: float, sat: float, val: float, acc: float, pat_i: float) -> Dictionary:
	var h := fmod(hue, 1.0)
	var s := lerpf(0.18, 0.62, sat)
	var v := lerpf(0.34, 0.78, val)
	var base := Color.from_hsv(h, s, v)
	var belly := Color.from_hsv(fmod(h + 0.03, 1.0), s * 0.45, minf(v + 0.28, 0.95))
	# accent snaps to harmony angles: analogous / split-complement / complement
	var snaps := [0.08, -0.08, 0.42, -0.42, 0.5]
	var ang: float = snaps[int(acc * 4.999)]
	var accent := Color.from_hsv(fmod(h + ang + 1.0, 1.0), clampf(s * 0.9 + 0.12, 0.0, 0.8), clampf(v + 0.12, 0.3, 0.92))
	var dark := base.darkened(0.35)
	var eye := Color.from_hsv(fmod(h + 0.5, 1.0), 0.55, 0.9)
	return {"base": base, "belly": belly, "accent": accent, "dark": dark, "ink": ink_color(base), "eye": eye}
