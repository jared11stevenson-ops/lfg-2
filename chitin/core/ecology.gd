class_name Ecology
extends RefCounted
## The district is a living system, not a spawn table. Populations follow a
## logistic-growth / predation model advanced once per Molt (and your kills
## perturb it). A 4-channel pheromone grid records where YOU smelled like what,
## and decays while diffusing - echoes and wildlife read it.

const GRID := 24
const CELL := 3.0          # metres per grid cell (district is GRID*CELL wide)

var pops: Dictionary = {}                 # species_id -> float population
var grid := PackedFloat32Array()          # GRID*GRID*4
var tick_count := 0

func _init() -> void:
	grid.resize(GRID * GRID * 4)
	grid.fill(0.0)
	for id in SpeciesDB.ids():
		var sp := SpeciesDB.get_species(id)
		pops[id] = float(sp.k) * (0.5 if sp.role in ["prey", "pack"] else 0.35)
	pops["cathedral_regent"] = 1.0

func step(rng: RandomNumberGenerator, steps: int = 1) -> void:
	for _i in steps:
		var delta: Dictionary = {}
		for id in pops:
			var sp := SpeciesDB.get_species(id)
			if id == "cathedral_regent":
				delta[id] = 0.0
				continue
			var n: float = pops[id]
			var growth: float = sp.r * n * (1.0 - n / sp.k)
			# predation on this species
			var eaten := 0.0
			for pid in pops:
				var psp := SpeciesDB.get_species(pid)
				if (psp.eats as Array).has(id):
					eaten += 0.012 * pops[pid] * n / maxf(1.0, sp.k * 0.5)
			# hunters fatten and breed only if they have prey
			var food := 0.0
			for fid in sp.eats:
				food += pops.get(fid, 0.0)
			var starvation := 0.0
			if not (sp.eats as Array).is_empty():
				starvation = 0.06 * n * clampf(1.0 - food / (sp.k * 1.5), 0.0, 1.0)
			delta[id] = growth - eaten - starvation + rng.randf_range(-0.1, 0.1)
		for id in delta:
			var sp := SpeciesDB.get_species(id)
			pops[id] = clampf(pops[id] + delta[id], 0.5 if id != "cathedral_regent" else 1.0, sp.k * 1.2)
		decay_diffuse()
		tick_count += 1

## Called when the player kills something: overhunting depresses future numbers.
func apply_kill(species_id: String, n: int = 1) -> void:
	if pops.has(species_id) and species_id != "cathedral_regent":
		pops[species_id] = maxf(0.5, pops[species_id] - float(n) * 0.8)

func population_of(species_id: String) -> int:
	return int(round(pops.get(species_id, 0.0)))

# --- pheromone grid ---------------------------------------------------------
static func cell_of(x: float, z: float) -> Vector2i:
	var half := GRID * CELL * 0.5
	return Vector2i(clampi(int((x + half) / CELL), 0, GRID - 1), clampi(int((z + half) / CELL), 0, GRID - 1))

func deposit(x: float, z: float, chord: Vector4, amount: float) -> void:
	var c := cell_of(x, z)
	var i := (c.y * GRID + c.x) * 4
	grid[i] = minf(1.0, grid[i] + chord.x * amount)
	grid[i + 1] = minf(1.0, grid[i + 1] + chord.y * amount)
	grid[i + 2] = minf(1.0, grid[i + 2] + chord.z * amount)
	grid[i + 3] = minf(1.0, grid[i + 3] + chord.w * amount)

func sample(x: float, z: float) -> Vector4:
	var c := cell_of(x, z)
	var i := (c.y * GRID + c.x) * 4
	return Vector4(grid[i], grid[i + 1], grid[i + 2], grid[i + 3])

func total_scent() -> float:
	var t := 0.0
	for v in grid:
		t += v
	return t

func decay_diffuse() -> void:
	var out := PackedFloat32Array()
	out.resize(grid.size())
	for y in GRID:
		for x in GRID:
			for ch in 4:
				var here := grid[(y * GRID + x) * 4 + ch]
				var acc := here * 0.5
				var cnt := 0.5
				for off in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
					var nx: int = x + off.x
					var ny: int = y + off.y
					if nx >= 0 and ny >= 0 and nx < GRID and ny < GRID:
						acc += grid[(ny * GRID + nx) * 4 + ch] * 0.125
						cnt += 0.125
				out[(y * GRID + x) * 4 + ch] = acc / cnt * 0.92
	grid = out

func to_dict() -> Dictionary:
	return {"pops": pops.duplicate(), "grid": Array(grid), "tick": tick_count}

static func from_dict(d: Dictionary) -> Ecology:
	var e := Ecology.new()
	for id in d.get("pops", {}):
		if e.pops.has(id):
			e.pops[id] = float(d.pops[id])
	var g: Array = d.get("grid", [])
	if g.size() == e.grid.size():
		for i in g.size():
			e.grid[i] = float(g[i])
	e.tick_count = int(d.get("tick", 0))
	return e
