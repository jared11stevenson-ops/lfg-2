class_name Walk
extends RefCounted
## Terrain locomotion without physics bodies: the heightfield *is* the collision.
## Blocks entry to water hexes / below-shore ground and cliff faces; slides along obstacles per-axis.
const MAX_SUBSTEP := 0.25 # metres per sub-step so thin cliffs cannot be tunnelled

## Returns the new position (y snapped to ground). `delta_xz` is the desired displacement this frame.
static func step(w: WorldData, pos: Vector3, delta_xz: Vector2) -> Vector3:
	var dist: float = delta_xz.length()
	if dist < 1e-6:
		return Vector3(pos.x, w.height_at(pos.x, pos.z), pos.z)
	var n: int = maxi(1, int(ceilf(dist / MAX_SUBSTEP)))
	var sub: Vector2 = delta_xz / float(n)
	var p := Vector2(pos.x, pos.z)
	for _i in n:
		if _can_move(w, p, p + sub):
			p += sub
		elif _can_move(w, p, p + Vector2(sub.x, 0.0)):
			p.x += sub.x
		elif _can_move(w, p, p + Vector2(0.0, sub.y)):
			p.y += sub.y
		else:
			break
	return Vector3(p.x, w.height_at(p.x, p.y), p.y)

static func _can_move(w: WorldData, a: Vector2, b: Vector2) -> bool:
	if not w.walkable(b.x, b.y):
		return false
	var rise: float = absf(w.height_at(b.x, b.y) - w.height_at(a.x, a.y))
	var run: float = maxf(a.distance_to(b), 0.001)
	return rise / run <= WorldData.MAX_WALK_SLOPE * 1.15

## Nearest walkable position to a hex centre (spiral search) - used for spawning.
static func find_spawn(w: WorldData, hex: Vector2i) -> Vector3:
	var c: Vector2 = HexMath.offset_center(hex.x, hex.y)
	for ring in range(0, 12):
		for k in range(0, 16 if ring > 0 else 1):
			var a: float = TAU * float(k) / 16.0
			var p: Vector2 = c + Vector2(cos(a), sin(a)) * float(ring) * 2.0
			if w.walkable(p.x, p.y):
				return Vector3(p.x, w.height_at(p.x, p.y), p.y)
	return Vector3(c.x, w.height_at(c.x, c.y), c.y)
