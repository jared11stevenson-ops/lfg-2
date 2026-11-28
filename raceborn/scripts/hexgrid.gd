class_name Hex
extends RefCounted
## Pointy-top, odd-r offset hex helpers (world spacing matches the KayKit hex tiles: 2.0 wide, 1.732 row step).

static func world(c: int, r: int) -> Vector3:
	return Vector3(float(c) * 2.0 + (1.0 if r % 2 == 1 else 0.0), 0.0, float(r) * 1.732)

static func world_v(p: Vector2i) -> Vector3: return world(p.x, p.y)

static func cube(c: int, r: int) -> Vector3i:
	var x := c - (r - (r & 1)) / 2
	return Vector3i(x, -x - r, r)

static func dist(a: Vector2i, b: Vector2i) -> int:
	var ca := cube(a.x, a.y)
	var cb := cube(b.x, b.y)
	return maxi(maxi(absi(ca.x - cb.x), absi(ca.y - cb.y)), absi(ca.z - cb.z))

static func neighbors(p: Vector2i, w: int, h: int) -> Array:
	var d: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(0, 1), Vector2i(-1, 1)] if p.y % 2 == 0 \
		else [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(0, 1)]
	var out: Array = []
	for v in d:
		var n: Vector2i = p + v
		if n.x >= 0 and n.x < w and n.y >= 0 and n.y < h: out.append(n)
	return out

static func ring(p: Vector2i, radius: int, w: int, h: int) -> Array:
	var out: Array = []
	for r in range(maxi(0, p.y - radius), mini(h, p.y + radius + 1)):
		for c in range(maxi(0, p.x - radius - 1), mini(w, p.x + radius + 2)):
			var q := Vector2i(c, r)
			if dist(p, q) <= radius: out.append(q)
	return out

## nearest hex to a world position (x, z)
static func from_world(x: float, z: float, w: int, h: int) -> Vector2i:
	var best := Vector2i(-1, -1)
	var bd := 1e9
	var r0 := clampi(int(round(z / 1.732)), 0, h - 1)
	for r in range(maxi(0, r0 - 1), mini(h, r0 + 2)):
		for c in range(maxi(0, int(x / 2.0) - 1), mini(w, int(x / 2.0) + 3)):
			var wp := world(c, r)
			var d := (wp.x - x) * (wp.x - x) + (wp.z - z) * (wp.z - z)
			if d < bd: bd = d; best = Vector2i(c, r)
	return best if bd < 1.4 else Vector2i(-1, -1)
