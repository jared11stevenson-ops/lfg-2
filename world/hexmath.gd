class_name HexMath
extends RefCounted
## Presentation-side hex <-> world conversion (pointy-top, odd-r offset, axial q,r).
## Mirrors the contract in docs/INTERFACES.md (84x54, odd-r). rules/hexgrid.gd is the authority for
## gameplay; this is only for placing things in 3D. 1 hex = 16 m flat-to-flat.
const COLS := 84
const ROWS := 54
const HEX_W := 16.0
const SIZE := 16.0 / 1.7320508075688772 # centre to corner
const ROW_H := 1.5 * (16.0 / 1.7320508075688772)
const APOTHEM := 8.0

static func offset_center(col: int, row: int) -> Vector2:
	return Vector2(HEX_W * (float(col) + 0.5 * float(row & 1)), ROW_H * float(row))

static func world_to_offset(x: float, z: float) -> Vector2i:
	var qf: float = x / HEX_W - z / (2.0 * ROW_H)
	var rf: float = z / ROW_H
	var sf: float = -qf - rf
	var rq: float = roundf(qf)
	var rr: float = roundf(rf)
	var rs: float = roundf(sf)
	var dq: float = absf(rq - qf)
	var dr: float = absf(rr - rf)
	var ds: float = absf(rs - sf)
	if dq > dr and dq > ds:
		rq = -rr - rs
	elif dr > ds:
		rr = -rq - rs
	var q: int = int(rq)
	var r: int = int(rr)
	return Vector2i(q + ((r - (r & 1)) >> 1), r)

static func in_bounds(c: Vector2i) -> bool:
	return c.x >= 0 and c.y >= 0 and c.x < COLS and c.y < ROWS

static func idx(c: Vector2i) -> int:
	return c.y * COLS + c.x

static func offset_to_axial(c: Vector2i) -> Vector2i:
	return Vector2i(c.x - ((c.y - (c.y & 1)) >> 1), c.y)

static func axial_to_offset(a: Vector2i) -> Vector2i:
	return Vector2i(a.x + ((a.y - (a.y & 1)) >> 1), a.y)

const _AX_DIRS: Array[Vector2i] = [Vector2i(1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(0, 1)]

static func neighbors(c: Vector2i) -> Array[Vector2i]:
	var a: Vector2i = offset_to_axial(c)
	var out: Array[Vector2i] = []
	for d in _AX_DIRS:
		var n: Vector2i = axial_to_offset(a + d)
		if in_bounds(n):
			out.append(n)
	return out

static func distance(a: Vector2i, b: Vector2i) -> int:
	var p: Vector2i = offset_to_axial(a)
	var q: Vector2i = offset_to_axial(b)
	var dq: int = p.x - q.x
	var dr: int = p.y - q.y
	return (absi(dq) + absi(dr) + absi(dq + dr)) / 2

static func world_extent() -> Rect2:
	return Rect2(-HEX_W * 0.5, -SIZE, HEX_W * (COLS + 0.5), ROW_H * (ROWS - 1) + 2.0 * SIZE)
