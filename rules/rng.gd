class_name Rng
extends RefCounted
## Tiny deterministic 48-bit LCG. State stays < 2^48 so it survives JSON (doubles) round trips.
const MASK := (1 << 48) - 1
var state: int = 1

func _init(seed_value: int = 1) -> void:
	state = ((seed_value * 6364136223846793005 + 1442695040888963407) >> 8) & MASK
	if state == 0:
		state = 1
	next_u32()

func next_u32() -> int:
	state = (state * 25214903917 + 11) & MASK
	return (state >> 16) & 0xFFFFFFFF

func rand_f() -> float:
	return float(next_u32()) / 4294967296.0

func rand_i(n: int) -> int:
	## uniform int in [0, n)
	if n <= 1:
		return 0
	return int(rand_f() * float(n))

static func hash2(x: int, y: int, s: int) -> float:
	var h: int = (x * 374761393 + y * 668265263 + s * 1442695041) & 0xFFFFFFFF
	h = ((h ^ (h >> 13)) * 1274126177) & 0xFFFFFFFF
	h = h ^ (h >> 16)
	return float(h) / 4294967295.0
