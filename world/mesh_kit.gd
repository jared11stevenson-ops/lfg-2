class_name MeshKit
extends RefCounted
## Tiny flat-shaded, vertex-coloured mesh builder. Every triangle gets its own face normal.
var verts: PackedVector3Array = PackedVector3Array()
var norms: PackedVector3Array = PackedVector3Array()
var cols: PackedColorArray = PackedColorArray()

func tri_count() -> int:
	return verts.size() / 3

## Add a triangle. `inside` is a point on the interior side; the winding is fixed so the face points away from it.
func tri(a: Vector3, b: Vector3, c: Vector3, col: Color, inside: Vector3 = Vector3(INF, INF, INF)) -> void:
	var n: Vector3 = (c - a).cross(b - a)
	if n.length_squared() < 1e-12:
		return
	n = n.normalized()
	var flip := false
	if inside.x != INF:
		flip = n.dot((a + b + c) / 3.0 - inside) < 0.0
	if flip:
		var t: Vector3 = b
		b = c
		c = t
		n = -n
	verts.append(a)
	verts.append(b)
	verts.append(c)
	norms.append(n)
	norms.append(n)
	norms.append(n)
	cols.append(col)
	cols.append(col)
	cols.append(col)

func quad(a: Vector3, b: Vector3, c: Vector3, d: Vector3, col: Color, inside: Vector3 = Vector3(INF, INF, INF)) -> void:
	tri(a, b, c, col, inside)
	tri(a, c, d, col, inside)

## Frustum with n sides from (y0,r0) to (y1,r1) around (cx,cz). Caps optional.
func frustum(center: Vector3, y0: float, r0: float, y1: float, r1: float, sides: int, col: Color, col_top: Color = Color(0, 0, 0, 0), cap_top: bool = true, cap_bottom: bool = false, rot: float = 0.0) -> void:
	var mid := Vector3(center.x, center.y + (y0 + y1) * 0.5, center.z)
	var top_col: Color = col if col_top.a == 0.0 else col_top
	for i in sides:
		var a0: float = rot + TAU * float(i) / float(sides)
		var a1: float = rot + TAU * float(i + 1) / float(sides)
		var b0 := Vector3(center.x + cos(a0) * r0, center.y + y0, center.z + sin(a0) * r0)
		var b1 := Vector3(center.x + cos(a1) * r0, center.y + y0, center.z + sin(a1) * r0)
		var t0 := Vector3(center.x + cos(a0) * r1, center.y + y1, center.z + sin(a0) * r1)
		var t1 := Vector3(center.x + cos(a1) * r1, center.y + y1, center.z + sin(a1) * r1)
		quad(b0, b1, t1, t0, col, mid)
		if cap_top and r1 > 0.0:
			tri(t0, t1, Vector3(center.x, center.y + y1, center.z), top_col, mid)
		elif r1 <= 0.0:
			pass
		if cap_bottom:
			tri(b0, b1, Vector3(center.x, center.y + y0, center.z), col, mid)

func box(center: Vector3, size: Vector3, col: Color, col_top: Color = Color(0, 0, 0, 0)) -> void:
	var h: Vector3 = size * 0.5
	var tcol: Color = col if col_top.a == 0.0 else col_top
	var p: Array[Vector3] = []
	for i in 8:
		p.append(center + Vector3(h.x if (i & 1) else -h.x, h.y if (i & 2) else -h.y, h.z if (i & 4) else -h.z))
	# faces: -x,+x,-y,+y,-z,+z
	quad(p[0], p[2], p[6], p[4], col, center)
	quad(p[1], p[3], p[7], p[5], col, center)
	quad(p[0], p[1], p[5], p[4], col, center)
	quad(p[2], p[3], p[7], p[6], tcol, center)
	quad(p[0], p[1], p[3], p[2], col, center)
	quad(p[4], p[5], p[7], p[6], col, center)

## Square-based roof pyramid / prism-free hip roof.
func pyramid(base_center: Vector3, half_x: float, half_z: float, height: float, col: Color, col_b: Color = Color(0, 0, 0, 0)) -> void:
	var apex: Vector3 = base_center + Vector3(0, height, 0)
	var c: Array[Vector3] = [
		base_center + Vector3(-half_x, 0, -half_z), base_center + Vector3(half_x, 0, -half_z),
		base_center + Vector3(half_x, 0, half_z), base_center + Vector3(-half_x, 0, half_z)]
	var inside: Vector3 = base_center + Vector3(0, height * 0.3, 0)
	var cb: Color = col if col_b.a == 0.0 else col_b
	for i in 4:
		tri(c[i], c[(i + 1) % 4], apex, col if i % 2 == 0 else cb, inside)

## Low-poly dome (upper hemisphere, squashable) built from rings.
func dome(center: Vector3, radius: float, squash: float, rings: int, sides: int, col: Color, col_rim: Color = Color(0, 0, 0, 0)) -> void:
	var inside: Vector3 = center + Vector3(0, radius * squash * 0.2, 0)
	var rim_col: Color = col if col_rim.a == 0.0 else col_rim
	var prev: Array[Vector3] = []
	for i in sides:
		var a: float = TAU * float(i) / float(sides)
		prev.append(center + Vector3(cos(a) * radius, 0, sin(a) * radius))
	for ring in range(1, rings + 1):
		var el: float = (PI * 0.5) * float(ring) / float(rings)
		var y: float = sin(el) * radius * squash
		var rr: float = cos(el) * radius
		var cur: Array[Vector3] = []
		for i in sides:
			var a2: float = TAU * float(i) / float(sides)
			cur.append(center + Vector3(cos(a2) * rr, y, sin(a2) * rr))
		var cc: Color = rim_col.lerp(col, float(ring) / float(rings)) if ring == 1 else col
		for i in sides:
			var j: int = (i + 1) % sides
			if ring == rings:
				tri(prev[i], prev[j], cur[i], cc, inside)
			else:
				quad(prev[i], prev[j], cur[j], cur[i], cc, inside)
		prev = cur

## Low-poly blob (jittered icosa-like sphere) for rocks.
func blob(center: Vector3, radius: Vector3, seed_i: int, col: Color, col_top: Color) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_i
	var sides := 6
	var rings := 2
	var pts: Array = []
	for rg in range(0, rings + 1):
		var el: float = -0.25 * PI + (PI * 0.75) * float(rg) / float(rings)
		var row: Array[Vector3] = []
		for i in sides:
			var a: float = TAU * float(i) / float(sides) + rng.randf() * 0.4
			var j: float = 0.8 + rng.randf() * 0.4
			row.append(center + Vector3(cos(a) * cos(el) * radius.x * j, sin(el) * radius.y * j, sin(a) * cos(el) * radius.z * j))
		pts.append(row)
	var top: Vector3 = center + Vector3(0, radius.y * (0.9 + rng.randf() * 0.2), 0)
	var bot: Vector3 = center + Vector3(0, -radius.y * 0.4, 0)
	for rg in rings:
		for i in sides:
			var j2: int = (i + 1) % sides
			quad(pts[rg][i], pts[rg][j2], pts[rg + 1][j2], pts[rg + 1][i], col, center)
	for i in sides:
		var j3: int = (i + 1) % sides
		tri(pts[rings][i], pts[rings][j3], top, col_top, center)
		tri(pts[0][i], pts[0][j3], bot, col, center)

## Flat horizontal ring (annulus) with thickness, e.g. a halo.
func ring(center: Vector3, r_in: float, r_out: float, thick: float, sides: int, col: Color) -> void:
	for i in sides:
		var a0: float = TAU * float(i) / float(sides)
		var a1: float = TAU * float(i + 1) / float(sides)
		var d0 := Vector3(cos(a0), 0, sin(a0))
		var d1 := Vector3(cos(a1), 0, sin(a1))
		var up := Vector3(0, thick * 0.5, 0)
		var mid: Vector3 = center + (d0 + d1) * 0.5 * (r_in + r_out) * 0.5
		quad(center + d0 * r_in + up, center + d1 * r_in + up, center + d1 * r_out + up, center + d0 * r_out + up, col, mid)
		quad(center + d0 * r_in - up, center + d0 * r_out - up, center + d1 * r_out - up, center + d1 * r_in - up, col, mid)
		quad(center + d0 * r_out - up, center + d0 * r_out + up, center + d1 * r_out + up, center + d1 * r_out - up, col, mid)
		quad(center + d0 * r_in - up, center + d1 * r_in - up, center + d1 * r_in + up, center + d0 * r_in + up, col, mid)

## Bounding box of all vertices (for scale/silhouette checks).
func bounds() -> AABB:
	if verts.size() == 0:
		return AABB()
	var lo: Vector3 = verts[0]
	var hi: Vector3 = verts[0]
	for v in verts:
		lo = lo.min(v)
		hi = hi.max(v)
	return AABB(lo, hi - lo)

## Append another kit translated by `offset` (merge small parts into one draw call).
func append_kit(other: MeshKit, offset: Vector3 = Vector3.ZERO) -> void:
	for i in other.verts.size():
		verts.append(other.verts[i] + offset)
		norms.append(other.norms[i])
		cols.append(other.cols[i])

func build() -> ArrayMesh:
	var m := ArrayMesh.new()
	if verts.size() == 0:
		return m
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	m.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return m
