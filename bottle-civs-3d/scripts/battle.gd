class_name BCBattle
extends RefCounted
## Turn-based tactical battle on the jar's hex grid (7 columns x 6 rows, odd-r offset, pointy-top).
## Pure logic: the presenter (battle_view.gd) draws it and feeds clicks in.

const COLS := 7
const ROWS := 6
const MAX_ROUNDS := 10

class Unit extends RefCounted:
	var cit
	var side := 0               # 0 = attacker, 1 = defender
	var c := 0
	var r := 0
	var hp := 10.0
	var max_hp := 10.0
	var atk := 3.0
	var move := 3
	var reach := 1
	var defending := false
	var moved := false
	var acted := false
	var alive := true
	var race_idx := 0
	var militia := false

var sim: BCSim
var party: BCSim.Party
var attacker_civ: BCSim.Civ
var defender_civ: BCSim.Civ
var units: Array = []
var turn_side := 0
var round_no := 1
var log_lines: Array = []
var finished := false
var attacker_wins := false
var rng := RandomNumberGenerator.new()

func _init(p_sim: BCSim, p_party: BCSim.Party) -> void:
	sim = p_sim
	party = p_party
	rng.seed = sim.rng.randi()
	attacker_civ = sim.civs[party.from]
	defender_civ = sim.civs[party.to]
	_spawn(party.members, 0)
	var def_sold: Array = defender_civ.citizens.filter(func(x): return x.role == "soldier" and x.loc == defender_civ.id and x.party == null)
	var picked: Array = def_sold.duplicate()
	picked.sort_custom(func(a, b): return sim.might_of(a) > sim.might_of(b))
	picked = picked.slice(0, 6)
	var militia := false
	if picked.size() < 3:
		var others: Array = defender_civ.citizens.filter(func(x): return x.role != "soldier" and sim.is_adult(x) and x.loc == defender_civ.id and x.party == null)
		others = sim.shuffled(others)
		for x in others.slice(0, 3 - picked.size()): picked.append(x)
		militia = true
	_spawn(picked, 1, militia)

func _spawn(list: Array, side: int, militia_fill: bool = false) -> void:
	var members: Array = list.duplicate()
	members.sort_custom(func(a, b): return sim.might_of(a) > sim.might_of(b))
	members = members.slice(0, 6)
	var col_set: Array = [0, 1] if side == 0 else [5, 6]
	var rows: Array = [1, 3, 2, 4, 0, 5]
	for i in members.size():
		var m = members[i]
		var u := Unit.new()
		u.cit = m
		u.side = side
		u.c = col_set[(i / 3) % 2] if side == 0 else col_set[(i / 3) % 2]
		u.r = rows[i % 6]
		var race: Dictionary = BCData.RACES[sim.dominant(m)]
		u.race_idx = sim.dominant(m)
		var civ: BCSim.Civ = attacker_civ if side == 0 else defender_civ
		var tech_mul := 1.0 + civ.tech * 0.06 + civ.barracks * 0.12
		var hpm := float(race.get("hp", 1.0))
		u.max_hp = 14.0 * (0.6 + 0.4 * hpm)
		u.hp = u.max_hp
		u.atk = 3.2 * sim.might_of(m) * tech_mul
		u.move = 3
		if race.id == "ogre": u.move = 2
		if race.id == "imp": u.move = 4
		if race.id == "elf" or race.id == "wizard":
			u.reach = 3; u.move = 2; u.atk *= 0.9
		if militia_fill and side == 1 and m.role != "soldier":
			u.militia = true; u.atk *= 0.7
		# avoid stacking
		while get_unit_at(u.c, u.r) != null: u.r = (u.r + 1) % ROWS
		units.append(u)

# ------------------------------------------------------------------ grid helpers
static func tile_pos(c: int, r: int) -> Vector3:
	return Vector3(float(c - 3) * 2.0 + (0.5 if r % 2 == 1 else -0.5), 0.0, (float(r) - 2.5) * 1.732)

static func to_cube(c: int, r: int) -> Vector3i:
	var x := c - (r - (r & 1)) / 2
	return Vector3i(x, -x - r, r)

static func dist(a: Vector2i, b: Vector2i) -> int:
	var ca := to_cube(a.x, a.y)
	var cb := to_cube(b.x, b.y)
	return maxi(maxi(absi(ca.x - cb.x), absi(ca.y - cb.y)), absi(ca.z - cb.z))

static func neighbors(c: int, r: int) -> Array:
	var d: Array = [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, -1), Vector2i(-1, -1), Vector2i(0, 1), Vector2i(-1, 1)] if r % 2 == 0 \
		else [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(1, -1), Vector2i(0, -1), Vector2i(1, 1), Vector2i(0, 1)]
	var out: Array = []
	for v in d:
		var nc: int = c + v.x
		var nr: int = r + v.y
		if nc >= 0 and nc < COLS and nr >= 0 and nr < ROWS: out.append(Vector2i(nc, nr))
	return out

func get_unit_at(c: int, r: int):
	for u in units:
		if u.alive and u.c == c and u.r == r: return u
	return null

func living(side: int) -> Array:
	return units.filter(func(u): return u.alive and u.side == side)

## Cells a unit can step to (BFS, blocked by living units).
func reachable(u: Unit) -> Array:
	if u.moved or u.acted: return []
	var seen := {Vector2i(u.c, u.r): 0}
	var frontier: Array = [Vector2i(u.c, u.r)]
	var out: Array = []
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		if seen[cur] >= u.move: continue
		for n in neighbors(cur.x, cur.y):
			if seen.has(n) or get_unit_at(n.x, n.y) != null: continue
			seen[n] = seen[cur] + 1
			frontier.append(n)
			out.append(n)
	return out

func targets_from(u: Unit, from_c: int, from_r: int) -> Array:
	var out: Array = []
	for e in living(1 - u.side):
		if dist(Vector2i(from_c, from_r), Vector2i(e.c, e.r)) <= u.reach: out.append(e)
	return out

func can_attack_now(u: Unit) -> Array:
	if u.acted: return []
	return targets_from(u, u.c, u.r)

# ------------------------------------------------------------------ actions
func move_unit(u: Unit, c: int, r: int) -> bool:
	if u.moved or u.acted or not reachable(u).has(Vector2i(c, r)): return false
	u.c = c; u.r = r
	u.moved = true
	return true

## returns {dmg, counter, killed, counter_killed}
func attack(u: Unit, t: Unit) -> Dictionary:
	var res := {"dmg": 0.0, "counter": 0.0, "killed": false, "counter_killed": false}
	if u.acted or not t.alive: return res
	var flank := 1.0
	for ally in living(u.side):
		if ally != u and dist(Vector2i(ally.c, ally.r), Vector2i(t.c, t.r)) == 1: flank = 1.25
	var wall := 1.0
	if t.side == 1: wall = 1.0 + defender_civ.walls * 0.12
	var dmg := u.atk * rng.randf_range(0.85, 1.15) * flank / wall
	if t.defending: dmg *= 0.5
	t.hp -= dmg
	res.dmg = dmg
	u.acted = true
	u.defending = false
	if t.hp <= 0.0:
		t.alive = false
		res.killed = true
	elif u.reach == 1 and dist(Vector2i(u.c, u.r), Vector2i(t.c, t.r)) == 1:
		var cd := t.atk * 0.45 * rng.randf_range(0.8, 1.2)
		u.hp -= cd
		res.counter = cd
		if u.hp <= 0.0:
			u.alive = false
			res.counter_killed = true
	_check_end()
	return res

func defend(u: Unit) -> void:
	if u.acted: return
	u.acted = true
	u.defending = true

func end_turn() -> void:
	if finished: return
	for u in units:
		u.moved = false
		u.acted = false
	turn_side = 1 - turn_side
	# defending stance lasts until that unit's next turn
	for u in units:
		if u.side == turn_side: u.defending = false
	if turn_side == 0:
		round_no += 1
		if round_no > MAX_ROUNDS:
			finished = true
			attacker_wins = false

func _check_end() -> void:
	if living(1).is_empty():
		finished = true; attacker_wins = true
	elif living(0).is_empty():
		finished = true; attacker_wins = false

# ------------------------------------------------------------------ AI
## Plans one unit's action. Returns {"move": Vector2i or null, "target": Unit or null, "defend": bool}
func ai_plan(u: Unit) -> Dictionary:
	var plan := {"move": null, "target": null, "defend": false}
	var foes := living(1 - u.side)
	if foes.is_empty(): return plan
	var in_reach := can_attack_now(u)
	if not in_reach.is_empty():
		plan.target = _weakest(in_reach)
		return plan
	# move toward the nearest foe
	var best = null
	var best_d := 999
	var nearest = null
	var nd := 999
	for f in foes:
		var d := dist(Vector2i(u.c, u.r), Vector2i(f.c, f.r))
		if d < nd: nd = d; nearest = f
	for cell in reachable(u):
		var d := dist(cell, Vector2i(nearest.c, nearest.r))
		# ranged units like to keep their distance at max reach
		var score := d
		if u.reach > 1 and d < u.reach: score += 3
		if score < best_d: best_d = score; best = cell
	if best != null and best_d < nd:
		plan.move = best
		var tg := targets_from(u, best.x, best.y)
		if not tg.is_empty(): plan.target = _weakest(tg)
	elif u.hp < u.max_hp * 0.4:
		plan.defend = true
	return plan

func _weakest(list: Array):
	var w = list[0]
	for e in list:
		if e.hp < w.hp: w = e
	return w

## Instant resolution when the player picks "auto" mid-battle: simulate remaining turns with the AI on both sides.
func auto_finish() -> void:
	var guard := 0
	while not finished and guard < 400:
		guard += 1
		for u in living(turn_side):
			if finished: break
			var plan := ai_plan(u)
			if plan.move != null: move_unit(u, plan.move.x, plan.move.y)
			if plan.target != null and plan.target.alive and dist(Vector2i(u.c, u.r), Vector2i(plan.target.c, plan.target.r)) <= u.reach: attack(u, plan.target)
			elif plan.defend: defend(u)
		if not finished: end_turn()

func survivors(side: int) -> Array:
	return living(side).map(func(u): return u.cit)

func all_citizens(side: int) -> Array:
	return units.filter(func(u): return u.side == side).map(func(u): return u.cit)
