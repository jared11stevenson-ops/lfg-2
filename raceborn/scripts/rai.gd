class_name RAI
extends RefCounted
## Computer players. Uses the same rules API as the human (no hidden bonuses except full map knowledge).

static func take_turn(g: RGame, p: RGame.Player) -> void:
	_diplomacy(g, p)
	_cities(g, p)
	var enemy_units: Array = []
	var enemy_cities: Array = []
	for o in g.players:
		if o != p and o.alive and p.at_war.has(o.id):
			for u in g.units.values():
				if u.owner == o.id: enemy_units.append(u)
			for c in g.cities.values():
				if c.owner == o.id: enemy_cities.append(c)
	var mine: Array = g.units.values().filter(func(u): return u.owner == p.id)
	for u in mine:
		if not g.units.has(u.id): continue
		match u.kind:
			"settler": _settler(g, p, u)
			"scout": _scout(g, p, u)
			_: _military(g, p, u, enemy_units, enemy_cities)

static func _diplomacy(g: RGame, p: RGame.Player) -> void:
	for o in g.players:
		if o == p or not o.alive: continue
		if p.at_war.has(o.id):
			if p.war_turns.get(o.id, 0) > 8 and g.rng.randf() < 0.12:
				if o.is_ai: g.propose_peace(p.id, o.id)
		elif g.turn >= 18 and g.rng.randf() < 0.025:
			var ratio := g.power(p) / maxf(1.0, g.power(o))
			var aggressive := 0.0
			if g.race_of(p).id in ["orc", "skeleton", "ogre", "goblin"]: aggressive = 0.4
			if ratio + aggressive > 1.4 and p.at_war.size() < 1:
				g.declare_war(p.id, o.id)

static func _cities(g: RGame, p: RGame.Player) -> void:
	var my_cities := g.city_of(p)
	var settlers := g.units.values().filter(func(u): return u.owner == p.id and u.kind == "settler").size()
	var building_settler := my_cities.filter(func(c): return c.producing == "settler").size()
	var limit := 4 + g.age * 2
	for c in my_cities:
		var defenders := g.unit_at(c.pos, p.id).filter(func(u): return u.kind == "melee" or u.kind == "ranged").size()
		if c.producing == "":
			var pick := ""
			if defenders < 1: pick = "melee"
			elif c.is_city and my_cities.size() + settlers + building_settler < limit and c.pop >= 2 and g.turn < 150:
				pick = "settler"; building_settler += 1
			else:
				for b in ["bld:workshop", "bld:granary", "bld:library", "bld:market", "ubld", "bld:temple", "bld:walls"]:
					if g.available_items(c).has(b) and (b != "bld:walls" or p.at_war.size() > 0):
						pick = b; break
				if pick == "": pick = "ranged" if defenders >= 1 and g.rng.randf() < 0.5 else "melee"
			g.set_production(c, pick)
		if not c.is_city:
			if p.gold > 150.0 and c.pop >= 3: g.upgrade_town(c)
			elif c.producing != "" and p.gold > g.buy_cost(c) + 40.0: g.buy(c)

static func _settler(g: RGame, p: RGame.Player, u: RGame.Unit) -> void:
	if g.city_of(p).is_empty():
		g.found_city(u); return
	var target := Vector2i(-1, -1)
	var best := -999.0
	for i in 40:
		var q := Vector2i(g.rng.randi_range(1, g.W - 2), g.rng.randi_range(1, g.H - 2))
		var tl: Dictionary = g.tile(q)
		if tl.t == RData.T.OCEAN or tl.t == RData.T.MOUNTAIN or tl.city != -1: continue
		if tl.owner != -1 and tl.owner != p.id: continue
		var ok := true
		for c in g.cities.values():
			if Hex.dist(c.pos, q) < 3: ok = false
		if not ok: continue
		var d := Hex.dist(u.pos, q)
		if d > 9: continue
		var score := 0.0
		for r in Hex.ring(q, 2, g.W, g.H):
			var y := g.tile_yield(r)
			score += y.food * 1.3 + y.prod + y.gold * 0.7
		score -= d * 1.5
		if score > best: best = score; target = q
	if target.x < 0:
		g.found_city(u); return
	if u.pos == target:
		g.found_city(u)
	else:
		g.set_goto(u, target)
		if u.pos == target and u.mp >= 0: g.found_city(u)

static func _scout(g: RGame, p: RGame.Player, u: RGame.Unit) -> void:
	if not u.path.is_empty(): return
	for i in 6:
		var q := Vector2i(g.rng.randi_range(1, g.W - 2), g.rng.randi_range(1, g.H - 2))
		if g._enter_cost(u, q) >= 0 and Hex.dist(u.pos, q) <= 8:
			if g.set_goto(u, q): return

static func _military(g: RGame, p: RGame.Player, u: RGame.Unit, enemy_units: Array, enemy_cities: Array) -> void:
	# target selection
	var target := Vector2i(-1, -1)
	var bd := 9999
	for e in enemy_units:
		var d := Hex.dist(u.pos, e.pos)
		if d < bd: bd = d; target = e.pos
	for c in enemy_cities:
		var d := Hex.dist(u.pos, c.pos) + 2
		if d < bd: bd = d; target = c.pos
	if target.x >= 0 and bd < 14 and u.hp > 45.0:
		if g.can_attack(u, target):
			g.attack(u, target); return
		# approach: choose a neighbour tile of the target we can path to
		var best_n := Vector2i(-1, -1)
		var best_d := 9999
		for n in Hex.neighbors(target, g.W, g.H):
			if g._enter_cost(u, n) < 0: continue
			var d := Hex.dist(u.pos, n)
			if d < best_d: best_d = d; best_n = n
		if best_n.x >= 0 and best_n != u.pos:
			g.set_goto(u, best_n)
			if g.can_attack(u, target): g.attack(u, target)
		elif best_n == u.pos and g.can_attack(u, target):
			g.attack(u, target)
		return
	# peacetime: garrison cities
	var here := g.city_at(u.pos)
	if here != null and here.owner == p.id:
		var def_here := g.unit_at(u.pos, p.id).filter(func(x): return x.kind == "melee" or x.kind == "ranged").size()
		if def_here <= 2:
			u.fortified = true; return
	for c in g.city_of(p):
		var def_c := g.unit_at(c.pos, p.id).filter(func(x): return x.kind == "melee" or x.kind == "ranged").size()
		if def_c < 1:
			g.set_goto(u, c.pos); return
	u.fortified = true
