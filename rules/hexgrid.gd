class_name HexGrid
extends RefCounted
## Axial hex coordinates Vector2i(q, r); storage is 84x54 odd-r offset (pointy-top rows shoved right on odd rows).
## Index = row * WIDTH + col where row = r and col = q + (r - (r & 1)) / 2.

const WIDTH := 84
const HEIGHT := 54
const DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]
const HEX_METERS := 16.0

static func to_offset(h: Vector2i) -> Vector2i:
	return Vector2i(h.x + (h.y - (h.y & 1)) / 2, h.y)

static func from_offset(col: int, row: int) -> Vector2i:
	return Vector2i(col - (row - (row & 1)) / 2, row)

static func in_bounds(h: Vector2i) -> bool:
	var o: Vector2i = to_offset(h)
	return o.x >= 0 and o.x < WIDTH and o.y >= 0 and o.y < HEIGHT

static func index(h: Vector2i) -> int:
	var o: Vector2i = to_offset(h)
	return o.y * WIDTH + o.x

static func from_index(i: int) -> Vector2i:
	return from_offset(i % WIDTH, i / WIDTH)

static func distance(a: Vector2i, b: Vector2i) -> int:
	var dq: int = a.x - b.x
	var dr: int = a.y - b.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2

static func neighbors(h: Vector2i, bounded: bool = true) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	for d in DIRS:
		var n: Vector2i = h + d
		if not bounded or in_bounds(n):
			out.append(n)
	return out

static func ring_within(h: Vector2i, radius: int) -> Array[Vector2i]:
	## All in-bounds hexes with distance <= radius (including h).
	var out: Array[Vector2i] = []
	for dq in range(-radius, radius + 1):
		for dr in range(maxi(-radius, -dq - radius), mini(radius, -dq + radius) + 1):
			var n := Vector2i(h.x + dq, h.y + dr)
			if in_bounds(n):
				out.append(n)
	return out

static func line(a: Vector2i, b: Vector2i) -> Array[Vector2i]:
	var n: int = distance(a, b)
	var out: Array[Vector2i] = []
	if n == 0:
		out.append(a)
		return out
	for i in range(n + 1):
		var t: float = float(i) / float(n)
		# nudge to break ties consistently
		var fq: float = lerpf(a.x + 1e-6, b.x + 1e-6, t)
		var fr: float = lerpf(a.y + 1e-6, b.y + 1e-6, t)
		out.append(_round(fq, fr))
	return out

static func _round(fq: float, fr: float) -> Vector2i:
	var fs: float = -fq - fr
	var q: float = roundf(fq)
	var r: float = roundf(fr)
	var s: float = roundf(fs)
	var dq: float = absf(q - fq)
	var dr: float = absf(r - fr)
	var ds: float = absf(s - fs)
	if dq > dr and dq > ds:
		q = -r - s
	elif dr > ds:
		r = -q - s
	return Vector2i(int(q), int(r))

## World-space centre of a hex in metres (x east, y = south), pointy-top, 16 m wide.
static func to_world(h: Vector2i) -> Vector2:
	var w: float = HEX_METERS
	return Vector2(w * (h.x + h.y * 0.5), w * 0.8660254 * h.y)

## Inverse of to_world: hex containing world point (metres).
static func from_world(p: Vector2) -> Vector2i:
	var r: float = p.y / (HEX_METERS * 0.8660254)
	var q: float = p.x / HEX_METERS - r * 0.5
	return _round(q, r)

## A* path. cost_fn(hex)->float (<=0 or INF means impassable). Returns [] if none; path excludes start, includes goal.
static func find_path(start: Vector2i, goal: Vector2i, cost_fn: Callable, max_nodes: int = 6000) -> Array[Vector2i]:
	var empty: Array[Vector2i] = []
	if not in_bounds(start) or not in_bounds(goal):
		return empty
	if start == goal:
		return empty
	if float(cost_fn.call(goal)) <= 0.0:
		return empty
	var g: Dictionary = {start: 0.0}
	var came: Dictionary = {}
	var open: Array[Vector2i] = [start]
	var f: Dictionary = {start: float(distance(start, goal)) * 0.5}
	var closed: Dictionary = {}
	var expanded: int = 0
	while not open.is_empty():
		var bi: int = 0
		var bf: float = f[open[0]]
		for i in range(1, open.size()):
			var fv: float = f[open[i]]
			if fv < bf or (fv == bf and (open[i].y < open[bi].y or (open[i].y == open[bi].y and open[i].x < open[bi].x))):
				bf = fv
				bi = i
		var cur: Vector2i = open[bi]
		open.remove_at(bi)
		if cur == goal:
			var path: Array[Vector2i] = []
			var c: Vector2i = goal
			while c != start:
				path.push_front(c)
				c = came[c]
			return path
		closed[cur] = true
		expanded += 1
		if expanded > max_nodes:
			break
		for n in neighbors(cur):
			if closed.has(n):
				continue
			var step: float = float(cost_fn.call(n))
			if step <= 0.0 or is_inf(step):
				continue
			var ng: float = float(g[cur]) + step
			if not g.has(n) or ng < float(g[n]):
				g[n] = ng
				came[n] = cur
				f[n] = ng + float(distance(n, goal)) * 0.5
				if not open.has(n):
					open.append(n)
	return empty
