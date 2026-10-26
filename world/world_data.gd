class_name WorldData
extends RefCounted
## Presentation-side snapshot of the static world: per-hex biome + a continuous height grid.
## Produced by StubWorldGen (TEMP) until Stream A's rules/ commits world data, then by an adapter.
const CELL := 4.0 # metres per heightfield cell
const ORIGIN := Vector2(-8.0, -12.0)
const NX := 340
const NZ := 190
const WATER_LEVEL := 0.0
const WALK_MIN_HEIGHT := 0.18
const MAX_WALK_SLOPE := 0.95 # rise/run; steeper than this is a cliff
const T_GROUND := 0 # same codes as rules/worldgen.gd
const T_SHALLOW := 1
const T_DEEP := 2
const T_CLIFF := 3

var world_seed: int = 0
var biome: PackedByteArray = PackedByteArray() # HexMath.COLS*ROWS, Biomes.B
var terrain: PackedByteArray = PackedByteArray() # T_* per hex (empty = all ground)
var road: PackedByteArray = PackedByteArray() # 0/1 per hex
var heights: PackedFloat32Array = PackedFloat32Array() # (NX+1)*(NZ+1)
var holdings: Array[Dictionary] = [] # {hex:Vector2i, name:String, owner:int}
var start_hex: Vector2i = Vector2i(42, 27)

func biome_hex(c: Vector2i) -> int:
	if not HexMath.in_bounds(c):
		return Biomes.B.WATER
	return biome[HexMath.idx(c)]

func terrain_hex(c: Vector2i) -> int:
	if terrain.size() == 0 or not HexMath.in_bounds(c):
		return T_GROUND if terrain.size() == 0 else T_DEEP
	return terrain[HexMath.idx(c)]

func is_road(c: Vector2i) -> bool:
	return road.size() > 0 and HexMath.in_bounds(c) and road[HexMath.idx(c)] == 1

func biome_at(x: float, z: float) -> int:
	return biome_hex(HexMath.world_to_offset(x, z))

func is_water_hex(c: Vector2i) -> bool:
	return biome_hex(c) == Biomes.B.WATER

func hex_center3(c: Vector2i) -> Vector3:
	var p: Vector2 = HexMath.offset_center(c.x, c.y)
	return Vector3(p.x, height_at(p.x, p.y), p.y)

func _h(ix: int, iz: int) -> float:
	ix = clampi(ix, 0, NX)
	iz = clampi(iz, 0, NZ)
	return heights[iz * (NX + 1) + ix]

## Height consistent with the rendered triangles (diagonal (i,j)-(i+1,j+1)).
func height_at(x: float, z: float) -> float:
	var gx: float = (x - ORIGIN.x) / CELL
	var gz: float = (z - ORIGIN.y) / CELL
	var ix: int = clampi(int(floorf(gx)), 0, NX - 1)
	var iz: int = clampi(int(floorf(gz)), 0, NZ - 1)
	var fx: float = clampf(gx - float(ix), 0.0, 1.0)
	var fz: float = clampf(gz - float(iz), 0.0, 1.0)
	var h00: float = _h(ix, iz)
	var h10: float = _h(ix + 1, iz)
	var h01: float = _h(ix, iz + 1)
	var h11: float = _h(ix + 1, iz + 1)
	if fx >= fz:
		return h00 + (h10 - h00) * fx + (h11 - h10) * fz
	return h00 + (h11 - h01) * fx + (h01 - h00) * fz

func slope_at(x: float, z: float) -> float:
	var e: float = 1.5
	var dx: float = (height_at(x + e, z) - height_at(x - e, z)) / (2.0 * e)
	var dz: float = (height_at(x, z + e) - height_at(x, z - e)) / (2.0 * e)
	return sqrt(dx * dx + dz * dz)

## True where a character may stand: on a land hex, above water, not on a cliff face.
func walkable(x: float, z: float) -> bool:
	var c: Vector2i = HexMath.world_to_offset(x, z)
	if not HexMath.in_bounds(c) or biome[HexMath.idx(c)] == Biomes.B.WATER:
		return false
	var t: int = terrain_hex(c)
	if t == T_DEEP or t == T_CLIFF:
		return false
	if height_at(x, z) < (WALK_MIN_HEIGHT if t != T_SHALLOW else -0.75): # shallows are wadeable
		return false
	return slope_at(x, z) <= MAX_WALK_SLOPE

func holding_at(c: Vector2i) -> int:
	for i in holdings.size():
		if holdings[i]["hex"] == c:
			return i
	return -1

## Building is allowed on dry, gentle land that is not already a holding hex.
func can_build(c: Vector2i) -> bool:
	if not HexMath.in_bounds(c) or biome_hex(c) == Biomes.B.WATER or terrain_hex(c) != T_GROUND:
		return false
	var p: Vector2 = HexMath.offset_center(c.x, c.y)
	if height_at(p.x, p.y) < WALK_MIN_HEIGHT or slope_at(p.x, p.y) > 0.45:
		return false
	return holding_at(c) < 0
