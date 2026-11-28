class_name RGame
extends RefCounted
## Rules and state of Raceborn: Ages. No scene access - the view and the AI both call into this.

const W := RData.MAP_W
const H := RData.MAP_H
const MAX_TURNS := 200

class Unit extends RefCounted:
	var id := 0
	var owner := 0
	var kind := "melee"            # settler, scout, melee, ranged
	var pos := Vector2i.ZERO
	var hp := 100.0
	var mp := 0
	var fortified := false
	var sleeping := false
	var path: Array = []
	var attacked := false
	var tier := 0

class City extends RefCounted:
	var id := 0
	var owner := 0
	var cname := ""
	var pos := Vector2i.ZERO
	var pop := 1
	var food := 0.0
	var prod := 0.0
	var producing := ""            # "" | settler | scout | melee | ranged | bld:<id> | ubld
	var buildings: Array = []
	var hp := 100.0
	var is_city := false
	var worked: Array = []
	var yields := {"food": 0.0, "prod": 0.0, "gold": 0.0, "sci": 0.0, "cul": 0.0}

class Player extends RefCounted:
	var id := 0
	var race := 0
	var leader := 0
	var is_ai := true
	var alive := true
	var gold := 60.0
	var techs := {}
	var civics := {}
	var research := ""
	var research_prog := 0.0
	var civic := ""
	var civic_prog := 0.0
	var legacy := {"mil": 0.0, "eco": 0.0, "cul": 0.0, "sci": 0.0}
	var tiers := {"mil": 0, "eco": 0, "cul": 0, "sci": 0}
	var age_progress := 0.0
	var temp_mods: Array = []      # [{mods:{}, turns:n}]
	var at_war := {}
	var war_turns := {}
	var explored := PackedByteArray()
	var visible := PackedByteArray()
	var kills := 0
	var income := {"gold": 0.0, "sci": 0.0, "cul": 0.0, "food": 0.0, "prod": 0.0}
	var past_races: Array = []
	var chosen_next := -1

var rng := RandomNumberGenerator.new()
var seed_value := 0
var tiles: Array = []            # [{t, res, owner, city}]
var players: Array = []
var cities := {}
var units := {}
var next_id := 1
var turn := 1
var age := 0
var game_over := false
var winner := -1
var win_kind := ""
var transition := ""             # "" | "crisis" | "race"
var crisis_id := -1
var notes: Array = []            # [{player, text, kind, pos}]

signal note(player: int, text: String, kind: String)
signal unit_moved(u: Unit, from: Vector2i, to: Vector2i)
signal combat(att_pos: Vector2i, def_pos: Vector2i, dmg: float, counter: float, killed: bool)
signal city_changed(c: City)
signal unit_removed(u: Unit)
signal age_transition
signal finished(winner: int, kind: String)

const CRISES := [
	["Plague", "A sickness spreads through the jars of your cities.", {"food": -0.25}, {"food": -0.10}],
	["Civil Unrest", "Your people grow restless and cynical.", {"cul": -0.30}, {"cul": -0.10}],
	["Famine", "Harvests fail across the realm.", {"food": -0.30, "gold": -0.10}, {"food": -0.12}],
	["Raider Wave", "Raiders weaken your garrisons.", {"melee": -0.20, "def": -0.15}, {"melee": -0.08}],
]

# ================================================================== setup
func new_game(p_seed: int, human_race: int, human_leader: int, n_ai: int = 3) -> void:
	seed_value = p_seed
	rng.seed = p_seed
	_gen_map()
	var free_races: Array = range(RData.RACES.size())
	free_races.erase(human_race)
	free_races.shuffle()
	for i in n_ai + 1:
		var p := Player.new()
		p.id = i
		p.race = human_race if i == 0 else free_races[i - 1]
		p.leader = human_leader if i == 0 else rng.randi() % RData.LEADERS.size()
		p.is_ai = i != 0
		p.explored.resize(W * H); p.visible.resize(W * H)
		players.append(p)
	var starts := _pick_starts(players.size())
	for i in players.size():
		var pos: Vector2i = starts[i]
		_spawn_unit(i, "settler", pos)
		_spawn_unit(i, "melee", pos)
		_spawn_unit(i, "ranged", pos)
		_spawn_unit(i, "scout", pos)
		pick_next_research(players[i]); pick_next_civic(players[i])
		update_visibility(players[i])
	# AI opening: found immediately
	for p in players:
		if p.is_ai:
			for u in units.values().duplicate():
				if u.owner == p.id and u.kind == "settler":
					found_city(u)
	age_notes("Antiquity begins. Found your first city with the Settler.", 0)

func age_notes(text: String, pid: int) -> void:
	note.emit(pid, text, "age")

func idx(p: Vector2i) -> int: return p.y * W + p.x
func inb(p: Vector2i) -> bool: return p.x >= 0 and p.y >= 0 and p.x < W and p.y < H
func tile(p: Vector2i) -> Dictionary: return tiles[p.y * W + p.x]
func race_of(p: Player) -> Dictionary: return RData.RACES[p.race]

func _gen_map() -> void:
	var elev := FastNoiseLite.new()
	elev.seed = seed_value; elev.frequency = 0.09; elev.fractal_octaves = 3
	var moist := FastNoiseLite.new()
	moist.seed = seed_value + 77; moist.frequency = 0.14
	tiles.clear()
	for r in H:
		for c in W:
			# push the map border toward ocean
			var edge := minf(minf(float(c), float(W - 1 - c)) / 4.0, minf(float(r), float(H - 1 - r)) / 3.0)
			var e: float = elev.get_noise_2d(float(c), float(r)) + clampf(edge, 0.0, 1.0) * 0.5 - 0.35
			var t := RData.T.GRASS
			if e < -0.05: t = RData.T.OCEAN
			elif e > 0.52: t = RData.T.MOUNTAIN
			elif e > 0.34: t = RData.T.HILLS
			elif moist.get_noise_2d(float(c), float(r)) > 0.18: t = RData.T.FOREST
			tiles.append({"t": t, "res": "", "owner": -1, "city": -1})
	for r in H:
		for c in W:
			var tl: Dictionary = tiles[r * W + c]
			var roll := rng.randf()
			if tl.t == RData.T.GRASS:
				if roll < 0.07: tl.res = "wheat"
				elif roll < 0.09: tl.res = "relic"
			elif tl.t == RData.T.HILLS:
				if roll < 0.12: tl.res = "stone"
				elif roll < 0.18: tl.res = "gems"
			elif tl.t == RData.T.OCEAN:
				var near_land := false
				for n in Hex.neighbors(Vector2i(c, r), W, H):
					if tiles[n.y * W + n.x].t != RData.T.OCEAN: near_land = true
				if near_land and roll < 0.14: tl.res = "fish"

func _land_ok(p: Vector2i) -> bool:
	var t: int = tile(p).t
	return t == RData.T.GRASS or t == RData.T.FOREST or t == RData.T.HILLS

func _pick_starts(n: int) -> Array:
	var best: Array = []
	var best_score := -1.0
	for attempt in 300:
		var pick: Array = []
		for i in n:
			var p := Vector2i(rng.randi_range(3, W - 4), rng.randi_range(3, H - 4))
			var good: bool = tile(p).t == RData.T.GRASS
			var land := 0
			for q in Hex.ring(p, 2, W, H):
				if _land_ok(q): land += 1
			if not good or land < 12: continue
			pick.append(p)
		if pick.size() < n: continue
		var md := 1e9
		for i in n:
			for j in range(i + 1, n):
				md = minf(md, float(Hex.dist(pick[i], pick[j])))
		if md > best_score: best_score = md; best = pick
	if best.is_empty():
		# fallback: carve guaranteed land
		for i in n:
			var p := Vector2i(4 + (i % 2) * (W - 9), 4 + (i / 2) * (H - 9))
			for q in Hex.ring(p, 2, W, H): tiles[q.y * W + q.x].t = RData.T.GRASS; tiles[q.y * W + q.x].res = ""
			best.append(p)
	return best

# ================================================================== units
func _spawn_unit(owner: int, kind: String, pos: Vector2i) -> Unit:
	var u := Unit.new()
	u.id = next_id; next_id += 1
	u.owner = owner; u.kind = kind; u.pos = pos
	u.tier = age
	u.hp = max_hp(u)
	u.mp = max_mp(u)
	units[u.id] = u
	return u

func max_hp(u: Unit) -> float:
	var m := mods(players[u.owner])
	return 100.0 * (1.0 + m.get("hp", 0.0))

func max_mp(u: Unit) -> int:
	return {"settler": 2, "scout": 4, "melee": 2, "ranged": 2}[u.kind]

func unit_name(u: Unit) -> String:
	var rc := race_of(players[u.owner])
	match u.kind:
		"settler": return "Settler"
		"scout": return "Scout"
		"melee": return rc.melee_unit
		_: return rc.ranged_unit

func unit_at(p: Vector2i, owner_filter: int = -2) -> Array:
	var out: Array = []
	for u in units.values():
		if u.pos == p and (owner_filter == -2 or u.owner == owner_filter): out.append(u)
	return out

func enemy_units_at(p: Vector2i, me: int) -> Array:
	return unit_at(p).filter(func(u): return u.owner != me and players[me].at_war.has(u.owner))

func city_at(p: Vector2i) -> City:
	var id: int = tile(p).city
	return cities.get(id, null)

func strength(u: Unit, attacking: bool) -> float:
	var p: Player = players[u.owner]
	var m := mods(p)
	if u.kind == "settler": return 1.0
	if u.kind == "scout": return 5.0
	var base: Array = RData.UNIT_TIERS[u.kind][mini(u.tier, 2)]
	var s: float = base[0] if attacking else base[1]
	s *= 1.0 + m.get("melee" if u.kind == "melee" else "ranged", 0.0)
	if not attacking:
		s *= 1.0 + m.get("def", 0.0) + RData.TERRAIN[tile(u.pos).t][5]
		if u.fortified: s *= 1.2
	s *= 0.5 + 0.5 * (u.hp / max_hp(u))
	return s

func unit_range(u: Unit) -> int:
	return 2 if u.kind == "ranged" else 1

## Tiles a unit can reach this turn (Dijkstra by terrain cost, limited by remaining movement).
func reachable(u: Unit) -> Dictionary:
	var best := {u.pos: 0}
	var frontier: Array = [u.pos]
	while not frontier.is_empty():
		var cur: Vector2i = frontier.pop_front()
		for n in Hex.neighbors(cur, W, H):
			var cost := _enter_cost(u, n)
			if cost < 0: continue
			var total: int = best[cur] + cost
			if total > u.mp: total = u.mp if best[cur] < u.mp else 999
			if total > u.mp: continue
			if not best.has(n) or total < best[n]:
				best[n] = total
				frontier.append(n)
	best.erase(u.pos)
	return best

func _enter_cost(u: Unit, p: Vector2i) -> int:
	var t: int = tile(p).t
	if t == RData.T.OCEAN or t == RData.T.MOUNTAIN: return -1
	for o in unit_at(p):
		if o.owner != u.owner: return -1
	var c := city_at(p)
	if c != null and c.owner != u.owner: return -1
	return RData.TERRAIN[t][4]

func find_path(u: Unit, dest: Vector2i) -> Array:
	var dist_map := {u.pos: 0}
	var prev := {}
	var open: Array = [u.pos]
	while not open.is_empty():
		var bi := 0
		for i in open.size():
			if dist_map[open[i]] < dist_map[open[bi]]: bi = i
		var cur: Vector2i = open.pop_at(bi)
		if cur == dest: break
		for n in Hex.neighbors(cur, W, H):
			var cost := _enter_cost(u, n)
			if cost < 0: continue
			var nd: int = dist_map[cur] + cost
			if not dist_map.has(n) or nd < dist_map[n]:
				dist_map[n] = nd; prev[n] = cur
				if not open.has(n): open.append(n)
	if not dist_map.has(dest): return []
	var path: Array = []
	var c: Vector2i = dest
	while c != u.pos:
		path.push_front(c)
		c = prev[c]
	return path

func set_goto(u: Unit, dest: Vector2i) -> bool:
	var path := find_path(u, dest)
	if path.is_empty(): return false
	u.path = path
	u.fortified = false; u.sleeping = false
	advance_unit(u)
	return true

func advance_unit(u: Unit) -> void:
	while not u.path.is_empty() and u.mp > 0:
		var nxt: Vector2i = u.path[0]
		var cost := _enter_cost(u, nxt)
		if cost < 0:
			u.path.clear(); return
		if cost > u.mp and u.mp < max_mp(u): return      # wait for a fresh turn
		u.path.pop_front()
		var from := u.pos
		u.pos = nxt
		u.mp = maxi(0, u.mp - cost)
		unit_moved.emit(u, from, nxt)
		_after_move(u)

func _after_move(u: Unit) -> void:
	var p: Player = players[u.owner]
	if not p.is_ai: update_visibility(p)

# ------------------------------------------------------------------ combat
func can_attack(u: Unit, target: Vector2i) -> bool:
	if u.kind == "settler" or u.kind == "scout" or u.mp <= 0 or u.attacked: return false
	var d := Hex.dist(u.pos, target)
	if d > unit_range(u) or d == 0: return false
	var p: Player = players[u.owner]
	if not enemy_units_at(target, u.owner).is_empty(): return true
	var c := city_at(target)
	return c != null and c.owner != u.owner and p.at_war.has(c.owner)

func attack(u: Unit, target: Vector2i) -> bool:
	if not can_attack(u, target): return false
	var enemies := enemy_units_at(target, u.owner)
	var dmg_to_def := 0.0
	var dmg_to_att := 0.0
	var killed := false
	var melee := u.kind == "melee"
	var a := strength(u, true)
	u.fortified = false; u.sleeping = false; u.path.clear()
	if not enemies.is_empty():
		var defender: Unit = enemies[0]
		for e in enemies:
			if strength(e, false) > strength(defender, false): defender = e
		var d := strength(defender, false)
		var city := city_at(target)
		if city != null and city.is_city: d *= 1.15
		dmg_to_def = 30.0 * pow(1.041, a - d) * rng.randf_range(0.85, 1.15)
		defender.hp -= dmg_to_def
		if melee and defender.kind != "scout" and defender.kind != "settler":
			dmg_to_att = 30.0 * pow(1.041, d - a) * rng.randf_range(0.85, 1.15) * 0.8
			u.hp -= dmg_to_att
		if defender.hp <= 0.0:
			killed = true
			_kill(defender, u)
	else:
		var c: City = city_at(target)
		var d := 24.0 + c.pop * 3.0 + (10.0 if c.buildings.has("walls") else 0.0)
		d *= 1.0 + mods(players[c.owner]).get("def", 0.0)
		dmg_to_def = 30.0 * pow(1.041, a - d) * rng.randf_range(0.85, 1.15)
		c.hp -= dmg_to_def
		if melee:
			dmg_to_att = 30.0 * pow(1.041, d - a) * rng.randf_range(0.7, 1.0) * 0.6
			u.hp -= dmg_to_att
		if c.hp <= 0.0 and melee and enemy_units_at(target, u.owner).is_empty():
			capture_city(c, u.owner)
			killed = true
			var from := u.pos
			u.pos = target
			unit_moved.emit(u, from, target)
	u.mp = 0
	u.attacked = true
	combat.emit(u.pos if killed and melee else u.pos, target, dmg_to_def, dmg_to_att, killed)
	if u.hp <= 0.0 and units.has(u.id):
		_remove_unit(u)
	elif killed and melee and u.pos != target and enemy_units_at(target, u.owner).is_empty() and city_at(target) == null and _enter_cost(u, target) >= 0:
		var from2 := u.pos
		u.pos = target
		unit_moved.emit(u, from2, target)
	if not players[u.owner].is_ai: update_visibility(players[u.owner])
	return true

func _kill(dead: Unit, by: Unit) -> void:
	var p: Player = players[by.owner]
	var m := mods(p)
	p.kills += 1
	add_legacy(p, "mil", 2.0)
	if m.get("kill_cul", 0.0) > 0.0: p.legacy.cul += m.kill_cul
	if m.get("plunder", 0.0) > 0.0: p.gold += 10.0
	var pos := dead.pos
	_remove_unit(dead)
	if m.get("raise", 0.0) > 0.0 and rng.randf() < m.raise and (dead.kind == "melee" or dead.kind == "ranged"):
		var nu := _spawn_unit(by.owner, dead.kind, pos)
		nu.hp = 50.0
		note.emit(by.owner, "A fallen foe rises to fight for you.", "good")

func _remove_unit(u: Unit) -> void:
	units.erase(u.id)
	unit_removed.emit(u)

func capture_city(c: City, new_owner: int) -> void:
	var old: int = c.owner
	var np: Player = players[new_owner]
	c.owner = new_owner
	c.hp = 30.0
	c.pop = maxi(1, c.pop - 1)
	c.producing = ""
	c.prod = 0.0
	c.buildings = c.buildings.filter(func(b): return rng.randf() < 0.6)
	for t in tiles:
		if t.city == c.id and t.owner != -1: pass
	for q in Hex.ring(c.pos, 2, W, H):
		var tl: Dictionary = tile(q)
		if tl.owner == old: tl.owner = new_owner
	add_legacy(np, "mil", 6.0)
	note.emit(new_owner, "%s captured!" % c.cname, "good")
	note.emit(old, "%s was captured by the %s!" % [c.cname, RData.RACES[np.race].name], "bad")
	city_changed.emit(c)
	_check_eliminated(old)
	if not np.is_ai: update_visibility(np)

func _check_eliminated(pid: int) -> void:
	var p: Player = players[pid]
	for c in cities.values():
		if c.owner == pid: return
	for u in units.values():
		if u.owner == pid and u.kind == "settler": return
	p.alive = false
	for u in units.values().duplicate():
		if u.owner == pid: _remove_unit(u)
	note.emit(0, "The %s have been eliminated!" % RData.RACES[p.race].name, "war")
	var alive := players.filter(func(x): return x.alive)
	if alive.size() == 1: _finish(alive[0].id, "domination")
	elif not players[0].alive: _finish(-1, "eliminated")

# ------------------------------------------------------------------ cities
func found_city(u: Unit) -> City:
	if u.kind != "settler": return null
	var p: Player = players[u.owner]
	var tl: Dictionary = tile(u.pos)
	if tl.t == RData.T.OCEAN or tl.t == RData.T.MOUNTAIN or tl.city != -1: return null
	if tl.owner != -1 and tl.owner != u.owner: return null
	for c in cities.values():
		if Hex.dist(c.pos, u.pos) < 3: return null
	var city := City.new()
	city.id = next_id; next_id += 1
	city.owner = u.owner
	city.pos = u.pos
	city.cname = _city_name(p)
	city.is_city = not cities.values().any(func(c): return c.owner == u.owner)
	city.hp = 100.0
	cities[city.id] = city
	tl.city = city.id
	for q in Hex.ring(u.pos, 2, W, H):
		var qt: Dictionary = tile(q)
		if qt.owner == -1: qt.owner = u.owner
	_remove_unit(u)
	note.emit(u.owner, "%s founded." % city.cname, "good")
	city_changed.emit(city)
	if not p.is_ai: update_visibility(p)
	return city

func _city_name(p: Player) -> String:
	var names := ["Aldoria", "Brightmere", "Cinderfall", "Dunmarrow", "Eldenwick", "Frostreach", "Greywatch", "Highmoor", "Ironvale", "Jadeport", "Kestrel", "Larkhaven", "Mistgate", "Nightbloom", "Oakenhold", "Pinecrest"]
	var rname: String = RData.RACES[p.race].name
	var n := cities.values().filter(func(c): return c.owner == p.id).size()
	return "%s %s" % [rname.trim_suffix("s"), names[(p.id * 5 + n * 3 + int(seed_value)) % names.size()]]

func city_of(p: Player) -> Array: return cities.values().filter(func(c): return c.owner == p.id)

func item_cost(c: City, item: String) -> int:
	var m := mods(players[c.owner])
	var uc: float = 1.0 + m.get("unit_cost", 0.0)
	if item == "settler": return int(RData.SETTLER_COST * (1.0 + m.get("settler_cost", 0.0)) * uc)
	if item == "scout": return int(RData.SCOUT_COST * uc)
	if item == "melee" or item == "ranged": return int(RData.UNIT_TIERS[item][mini(age, 2)][2] * uc)
	if item == "ubld": return int(RData.RACES[players[c.owner].race].ubuilding[6])
	if item.begins_with("bld:"): return int(RData.BUILDINGS[item.substr(4)][1])
	return 9999

func item_name(c: City, item: String) -> String:
	var rc: Dictionary = RData.RACES[players[c.owner].race]
	match item:
		"settler": return "Settler"
		"scout": return "Scout"
		"melee": return rc.melee_unit
		"ranged": return rc.ranged_unit
		"ubld": return rc.ubuilding[0]
	if item.begins_with("bld:"): return RData.BUILDINGS[item.substr(4)][0]
	return "-"

func available_items(c: City) -> Array:
	var p: Player = players[c.owner]
	var out: Array = ["settler", "scout", "melee", "ranged"]
	for id in RData.BUILDINGS:
		var b: Array = RData.BUILDINGS[id]
		if c.buildings.has(id): continue
		if b[7] != "" and not p.techs.has(b[7]): continue
		if id == "walls" and not c.is_city: continue
		out.append("bld:" + id)
	if not c.buildings.has("ubld"): out.append("ubld")
	return out

func set_production(c: City, item: String) -> bool:
	if not available_items(c).has(item): return false
	if c.producing != item: c.prod = c.prod * 0.5 if c.producing != "" else c.prod
	c.producing = item
	return true

func buy_cost(c: City) -> int:
	if c.producing == "": return 0
	var m := mods(players[c.owner])
	var left := maxf(0.0, float(item_cost(c, c.producing)) - c.prod)
	return int(ceil(left * 2.2 * (1.0 + m.get("buy", 0.0)))) + 5

func buy(c: City) -> bool:
	var p: Player = players[c.owner]
	var cost := buy_cost(c)
	if c.producing == "" or p.gold < cost: return false
	p.gold -= cost
	c.prod = float(item_cost(c, c.producing))
	return true

func upgrade_town(c: City) -> bool:
	var p: Player = players[c.owner]
	if c.is_city or c.pop < 3 or p.gold < 80.0: return false
	p.gold -= 80.0
	c.is_city = true
	note.emit(c.owner, "%s grows into a city." % c.cname, "good")
	city_changed.emit(c)
	return true

# ================================================================== yields
func mods(p: Player) -> Dictionary:
	var out := {}
	var add := func(d: Dictionary):
		for k in d: out[k] = out.get(k, 0.0) + float(d[k])
	var rc: Dictionary = RData.RACES[p.race]
	add.call(rc.mods)
	add.call(rc.age_mods[mini(age, 2)])
	add.call(RData.LEADERS[p.leader].mods)
	for a in RData.TECHS:
		for t in a:
			if p.techs.has(t[0]): add.call(t[4])
	for a in RData.CIVICS:
		for cv in a:
			if p.civics.has(cv[0]): add.call(cv[3])
	var tier_bonus := {"mil": {"melee": 0.08, "ranged": 0.08}, "eco": {"gold": 0.08}, "cul": {"cul": 0.08}, "sci": {"sci": 0.08}}
	for path in p.tiers:
		for i in p.tiers[path]: add.call(tier_bonus[path])
	for tm in p.temp_mods: add.call(tm.mods)
	return out

func tile_yield(p: Vector2i) -> Dictionary:
	var tl: Dictionary = tile(p)
	var t: Array = RData.TERRAIN[tl.t]
	var y := {"food": float(t[1]), "prod": float(t[2]), "gold": float(t[3]), "sci": 0.0, "cul": 0.0}
	if tl.res != "":
		var r: Array = RData.RESOURCES[tl.res]
		y.food += r[2]; y.prod += r[3]; y.gold += r[4]; y.sci += r[5]; y.cul += r[6]
	return y

func compute_city(c: City, taken: Dictionary) -> void:
	var p: Player = players[c.owner]
	var m := mods(p)
	var y := {"food": 1.0, "prod": 2.0, "gold": 2.0, "sci": 1.0 + c.pop * 0.5, "cul": 1.0}
	var cy := tile_yield(c.pos)
	for k in y: y[k] += cy[k] * (1.0 if k != "food" else 0.5)
	var cands: Array = []
	for q in Hex.ring(c.pos, 2, W, H):
		var tl: Dictionary = tile(q)
		if q == c.pos or tl.owner != c.owner or tl.t == RData.T.MOUNTAIN or taken.has(q): continue
		if not enemy_units_at(q, c.owner).is_empty(): continue
		var ty := tile_yield(q)
		var score: float = ty.food * 1.0 + ty.prod * 1.6 + ty.gold * 0.7 + ty.sci + ty.cul
		if tl.t == RData.T.OCEAN and p.race == 3: ty.food += 1.0; score += 1.0
		cands.append([score, q, ty])
	cands.sort_custom(func(a, b): return a[0] > b[0])
	c.worked = []
	for i in mini(c.pop, cands.size()):
		var e: Array = cands[i]
		c.worked.append(e[1]); taken[e[1]] = true
		for k in y: y[k] += e[2][k]
	var rc: Dictionary = RData.RACES[p.race]
	for bid in c.buildings:
		if bid == "ubld":
			var u: Array = rc.ubuilding
			y.food += u[1]; y.prod += u[2]; y.gold += u[3]; y.sci += u[4]; y.cul += u[5]
		else:
			var b: Array = RData.BUILDINGS[bid]
			y.food += b[2]; y.prod += b[3]; y.gold += b[4]; y.sci += b[5]; y.cul += b[6]
	y.food *= 1.0 + m.get("food", 0.0)
	y.prod *= 1.0 + m.get("prod", 0.0)
	y.gold *= 1.0 + m.get("gold", 0.0)
	y.sci *= 1.0 + m.get("sci", 0.0)
	y.cul *= 1.0 + m.get("cul", 0.0)
	if not c.is_city:                    # towns turn production into gold and cannot build
		y.gold += y.prod
		y.prod = 0.0
	c.yields = y

# ================================================================== research
func tech_cost(p: Player, t: Array) -> float:
	return float(t[2]) * (1.0 + mods(p).get("tech_cost", 0.0))

func available_techs(p: Player) -> Array:
	return RData.TECHS[mini(age, 2)].filter(func(t): return not p.techs.has(t[0]))

func available_civics(p: Player) -> Array:
	return RData.CIVICS[mini(age, 2)].filter(func(t): return not p.civics.has(t[0]))

func pick_next_research(p: Player) -> void:
	var a := available_techs(p)
	if a.is_empty(): p.research = ""; return
	p.research = a[0][0]

func pick_next_civic(p: Player) -> void:
	var a := available_civics(p)
	if a.is_empty(): p.civic = ""; return
	p.civic = a[0][0]

func set_research(p: Player, id: String) -> void:
	if available_techs(p).any(func(t): return t[0] == id): p.research = id; p.research_prog = 0.0 if p.research_prog < 1.0 else p.research_prog

func set_civic(p: Player, id: String) -> void:
	if available_civics(p).any(func(t): return t[0] == id): p.civic = id

func tech_by_id(id: String) -> Array:
	for a in RData.TECHS:
		for t in a:
			if t[0] == id: return t
	return []

func civic_by_id(id: String) -> Array:
	for a in RData.CIVICS:
		for t in a:
			if t[0] == id: return t
	return []

func add_legacy(p: Player, path: String, amount: float) -> void:
	p.legacy[path] += amount
	var thresholds := [20.0, 50.0, 90.0]
	while p.tiers[path] < 3 and p.legacy[path] >= thresholds[p.tiers[path]]:
		p.tiers[path] += 1
		var names := {"mil": "Military", "eco": "Economic", "cul": "Cultural", "sci": "Scientific"}
		note.emit(p.id, "Legacy: %s path tier %d reached! (+8%% permanent bonus)" % [names[path], p.tiers[path]], "good")

# ================================================================== diplomacy
func declare_war(a: int, b: int) -> void:
	if a == b or players[a].at_war.has(b): return
	players[a].at_war[b] = true; players[b].at_war[a] = true
	players[a].war_turns[b] = 0; players[b].war_turns[a] = 0
	note.emit(a, "You declare war on the %s!" % RData.RACES[players[b].race].name, "war")
	note.emit(b, "The %s declare war on you!" % RData.RACES[players[a].race].name, "war")

func make_peace(a: int, b: int) -> void:
	players[a].at_war.erase(b); players[b].at_war.erase(a)
	note.emit(a, "Peace with the %s." % RData.RACES[players[b].race].name, "good")
	note.emit(b, "Peace with the %s." % RData.RACES[players[a].race].name, "good")

func power(p: Player) -> float:
	var s := 0.0
	for u in units.values():
		if u.owner == p.id and (u.kind == "melee" or u.kind == "ranged"): s += strength(u, true) * (u.hp / 100.0)
	return s + city_of(p).size() * 20.0

func propose_peace(a: int, b: int) -> bool:
	var pa: Player = players[a]
	var pb: Player = players[b]
	if not pa.at_war.has(b): return false
	if pa.war_turns.get(b, 0) < 4: return false
	var ratio := power(pb) / maxf(1.0, power(pa))
	var chance := 0.35 + (0.3 if ratio < 0.9 else 0.0) - (0.2 if ratio > 1.6 else 0.0)
	if rng.randf() < chance:
		make_peace(a, b)
		return true
	return false

# ================================================================== visibility
func update_visibility(p: Player) -> void:
	for i in p.visible.size(): p.visible[i] = 0
	var m := mods(p)
	for c in cities.values():
		if c.owner == p.id:
			for q in Hex.ring(c.pos, 3, W, H): _see(p, q)
	for u in units.values():
		if u.owner == p.id:
			var r := 2 + (1 if u.kind == "scout" else 0) + int(m.get("sight", 0.0))
			for q in Hex.ring(u.pos, r, W, H): _see(p, q)

func _see(p: Player, q: Vector2i) -> void:
	var i := idx(q)
	p.visible[i] = 1
	p.explored[i] = 1

# ================================================================== turn flow
func start_player_turn(p: Player) -> void:
	# movement refresh and unit orders
	for u in units.values().duplicate():
		if u.owner != p.id: continue
		u.mp = max_mp(u)
		u.attacked = false
		if u.hp < max_hp(u):
			var c := city_at(u.pos)
			var heal := 5.0
			if c != null and c.owner == p.id: heal = 20.0
			elif tile(u.pos).owner == p.id: heal = 10.0
			elif u.fortified: heal = 8.0
			u.hp = minf(max_hp(u), u.hp + heal)
		if not u.path.is_empty(): advance_unit(u)

func process_economy(p: Player) -> void:
	var m_before := mods(p)
	var taken := {}
	var tot := {"gold": 0.0, "sci": 0.0, "cul": 0.0, "food": 0.0, "prod": 0.0}
	for c in city_of(p):
		compute_city(c, taken)
		for k in tot: tot[k] += c.yields[k]
		# growth
		var surplus: float = c.yields.food - c.pop * 2.0
		c.food += surplus * (1.0 + m_before.get("growth", 0.0)) if surplus > 0.0 else surplus
		var need: float = 12.0 + c.pop * 7.0
		if c.food >= need:
			c.food -= need; c.pop += 1
			note.emit(p.id, "%s grows to %d." % [c.cname, c.pop], "info")
		elif c.food < -10.0 and c.pop > 1:
			c.food = 0.0; c.pop -= 1
			note.emit(p.id, "%s is starving!" % c.cname, "bad")
		if c.hp < 100.0: c.hp = minf(100.0, c.hp + 12.0)
		# production
		if c.producing != "":
			c.prod += c.yields.prod
			var cost := float(item_cost(c, c.producing))
			if c.prod >= cost: _complete(c, cost)
		elif c.is_city and not p.is_ai:
			note.emit(p.id, "%s has nothing in production." % c.cname, "info")
		city_changed.emit(c)
	var upkeep := 0.0
	if m_before.get("no_upkeep", 0.0) <= 0.0:
		var n := units.values().filter(func(u): return u.owner == p.id and u.kind != "settler").size()
		upkeep = maxf(0.0, float(n - 6)) * 1.0
	p.gold += tot.gold - upkeep
	p.income = {"gold": tot.gold - upkeep, "sci": tot.sci, "cul": tot.cul, "food": tot.food, "prod": tot.prod}
	# research
	if p.research != "":
		p.research_prog += tot.sci
		var t := tech_by_id(p.research)
		if not t.is_empty() and p.research_prog >= tech_cost(p, t):
			p.research_prog -= tech_cost(p, t)
			p.techs[t[0]] = true
			p.age_progress += 3.0
			add_legacy(p, "sci", 4.0)
			note.emit(p.id, "Technology discovered: %s." % t[1], "good")
			pick_next_research(p)
	elif not available_techs(p).is_empty(): pick_next_research(p)
	if p.civic != "":
		p.civic_prog += tot.cul
		var cv := civic_by_id(p.civic)
		if not cv.is_empty() and p.civic_prog >= float(cv[2]):
			p.civic_prog -= float(cv[2])
			p.civics[cv[0]] = true
			p.age_progress += 3.0
			add_legacy(p, "cul", 4.0)
			note.emit(p.id, "Civic adopted: %s." % cv[1], "good")
			pick_next_civic(p)
	elif not available_civics(p).is_empty(): pick_next_civic(p)
	add_legacy(p, "sci", tot.sci / 12.0)
	add_legacy(p, "cul", tot.cul / 12.0)
	add_legacy(p, "eco", maxf(0.0, tot.gold) / 14.0)
	var lm := mods(p)
	p.age_progress += (1.6 + cities.size() * 0.0) * (1.0 + lm.get("age", 0.0))
	for tm in p.temp_mods.duplicate():
		tm.turns -= 1
		if tm.turns <= 0: p.temp_mods.erase(tm)
	for o in p.war_turns.keys(): p.war_turns[o] += 1
	if not p.is_ai: update_visibility(p)

func _complete(c: City, cost: float) -> void:
	var p: Player = players[c.owner]
	var item := c.producing
	c.prod -= cost
	match item:
		"settler":
			if c.pop < 2: c.prod += cost; note.emit(p.id, "%s needs 2 population to build a Settler." % c.cname, "bad"); return
			c.pop -= 1
			_spawn_unit(c.owner, "settler", c.pos)
			note.emit(p.id, "%s trained a Settler." % c.cname, "good")
		"scout", "melee", "ranged":
			var u := _spawn_unit(c.owner, item, c.pos)
			note.emit(p.id, "%s trained: %s." % [c.cname, unit_name(u)], "good")
		"ubld":
			c.buildings.append("ubld"); add_legacy(p, "eco", 2.0)
			note.emit(p.id, "%s built the %s." % [c.cname, RData.RACES[p.race].ubuilding[0]], "good")
		_:
			if item.begins_with("bld:"):
				c.buildings.append(item.substr(4)); add_legacy(p, "eco", 2.0)
				note.emit(p.id, "%s built %s." % [c.cname, RData.BUILDINGS[item.substr(4)][0]], "good")
	c.producing = ""
	if p.is_ai: pass

## Ends the human turn, runs AI players, advances economy for everybody, handles ages.
func end_turn() -> void:
	if game_over or transition != "": return
	var human: Player = players[0]
	process_economy(human)
	for p in players:
		if p.is_ai and p.alive:
			RAI.take_turn(self, p)
			process_economy(p)
	turn += 1
	for p in players:
		if p.alive: start_player_turn(p)
	_check_age()
	if turn > MAX_TURNS and not game_over: _finish_by_score()
	if not game_over and transition == "":
		update_visibility(human)

func _check_age() -> void:
	var triggered := false
	for p in players:
		if p.alive and p.age_progress >= RData.AGE_TARGET: triggered = true
	if not triggered: return
	if age >= 2:
		_finish_by_score()
		return
	transition = "crisis"
	crisis_id = rng.randi() % CRISES.size()
	age_transition.emit()

func resolve_crisis(mitigate: bool) -> void:
	if transition != "crisis": return
	var h: Player = players[0]
	var cr: Array = CRISES[crisis_id]
	if mitigate and h.gold >= 60.0:
		h.gold -= 60.0
		h.temp_mods.append({"mods": cr[3], "turns": 6})
	else:
		h.temp_mods.append({"mods": cr[2], "turns": 6})
	for p in players:
		if p.is_ai: p.temp_mods.append({"mods": cr[2], "turns": 6})
	transition = "race"

func free_races() -> Array:
	var taken := {}
	for p in players:
		if p.alive and p.id != 0: taken[p.race] = true
	var out: Array = []
	for i in RData.RACES.size():
		if not taken.has(i) and i != players[0].race: out.append(i)
	return out

func choose_race(race_idx: int) -> void:
	if transition != "race": return
	var human: Player = players[0]
	if not free_races().has(race_idx): return
	human.past_races.append(human.race)
	human.race = race_idx
	for p in players:
		if p.is_ai and p.alive:
			var opts := free_races().filter(func(i): return i != race_idx)
			var taken := {}
			for q in players:
				if q != p and q.id != 0: taken[q.race] = true
			opts = opts.filter(func(i): return not taken.has(i))
			if not opts.is_empty():
				p.past_races.append(p.race)
				p.race = opts[rng.randi() % opts.size()]
	age += 1
	transition = ""
	for p in players:
		p.age_progress = 0.0
		pick_next_research(p); pick_next_civic(p)
	for u in units.values():
		u.tier = age
		u.hp = minf(max_hp(u), u.hp + 30.0)
	for c in cities.values():
		if c.owner == 0 or true: city_changed.emit(c)
	note.emit(0, "The %s Age begins. You now lead the %s." % [RData.AGE_NAMES[age], RData.RACES[human.race].name], "age")
	age_notes("Age of %s" % RData.AGE_NAMES[age], 0)

# ================================================================== end of game
func score(p: Player) -> float:
	var s := 0.0
	for k in p.legacy: s += p.legacy[k]
	for c in city_of(p): s += 5.0 + c.pop * 1.5 + c.buildings.size() * 2.0
	s += p.techs.size() * 2.0 + p.civics.size() * 2.0 + p.kills
	return s

func _finish_by_score() -> void:
	var best := 0
	var bs := -1.0
	for p in players:
		var s := score(p)
		if p.alive and s > bs: bs = s; best = p.id
	_finish(best, "score")

func _finish(w: int, kind: String) -> void:
	if game_over: return
	game_over = true
	winner = w
	win_kind = kind
	finished.emit(w, kind)
