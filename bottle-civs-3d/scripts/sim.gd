class_name BCSim
extends RefCounted
## Headless simulation of interconnected bottled civilizations. No scene access here.
## Ported from the validated JS prototype (200-day soak tests, no collapses across seeds).

const DAY_LEN := 100.0
const DUSK := 0.72
const TRAVEL := 12.0
const DECISIONS := [0.0, 0.28, 0.5]
const JAR_W := 200.0
const JAR_H := 150.0
const SITES := {
	"farm": Vector2(38, 98), "wood": Vector2(40, 42), "mine": Vector2(162, 44), "craft": Vector2(152, 92),
	"study": Vector2(100, 36), "trade": Vector2(100, 90), "soldier": Vector2(96, 62),
}
const ROLE_RES := {"farm": "food", "wood": "wood", "mine": "ore", "craft": "goods", "study": "lore", "trade": "gold"}
const RAIDER_MIN := 3

class Citizen extends RefCounted:
	var id: int
	var home: int
	var loc: int
	var blood: Dictionary
	var age: float
	var role := "child"
	var pos := Vector2.ZERO
	var target := Vector2.ZERO
	var timer := 0.0
	var state := "idle"
	var xp := 0.0
	var face := 1
	var life_mul := 1.0
	var party = null
	var hidden := false
	var dead := ""

class Party extends RefCounted:
	var id: int
	var kind: String
	var from: int
	var to: int
	var members: Array = []
	var cargo: Dictionary = {}
	var p := 0.0
	var dir := 1
	var state := "out"
	var host_t := 0.0
	var loot: Dictionary = {}
	var captives: Array = []

class Civ extends RefCounted:
	var id: int
	var race: Dictionary
	var name: String
	var alive := true
	var citizens: Array = []
	var links: Array = []
	var rel: Dictionary = {}
	var war: Dictionary = {}
	var stock := {"food": 40.0, "wood": 25.0, "ore": 15.0, "goods": 10.0, "lore": 0.0, "gold": 12.0}
	var houses := 3
	var tech := 0
	var flash := ""
	var flash_t := 0.0
	var pending_births: Array = []
	var role_count: Dictionary = {}
	var launches := 0
	var last_raid: Dictionary = {}
	var allies: Dictionary = {}
	var policy := "balanced"
	var barracks := 0
	var walls := 0
	var wonder := 0            # days of work completed on the Great Work (0 = not started)
	var wonder_started := false
	var annexed_by := -1
	var special_cd := 0
	var war_cry := 0
	var guest_stance := "host"
	var stats := {"births": 0, "hybrid_births": 0, "deaths": 0, "kills": 0, "losses": 0, "raids": 0, "defended": 0,
		"trades": 0, "envoys": 0, "plunder": 0.0, "raised": 0}

var rng := RandomNumberGenerator.new()
var seed_value: int
var day := 1
var clock := 0.0
var locked := false
var next_id := 1
var events: Array = []
var parties: Array = []
var civs: Array = []
var links: Array = []
var decisions_done := 0
var stats := {"battles": 0, "trades": 0, "hybrids": 0, "envoys": 0, "spies": 0}
var event_serial := 0

const AP_MAX := 3
const WONDER_DAYS := 8
const POLICIES := {
	"balanced": {},
	"economy": {"farm": 1.3, "trade": 1.5, "wood": 1.2},
	"industry": {"mine": 1.7, "craft": 1.7, "wood": 1.4},
	"scholar": {"study": 2.4, "trade": 1.1},
	"military": {"soldier": 2.4},
}
var player := -1
var difficulty := 1          # 0 easy, 1 normal, 2 hard
var ap_max := AP_MAX
var ap := AP_MAX
var tactical_enabled := true
var pending_battle = null
var winner := -1
var win_kind := ""
var game_over_flag := false

signal world_event(title: String, text: String)
signal tactical_battle(party)
signal game_over(winner_id: int, kind: String)
signal event_logged(ev: Dictionary)
signal battle(civ_a: int, civ_b: int, night: bool)
signal birth(civ_id: int, hybrid: bool)

func _init(p_seed: int = -1) -> void:
	seed_value = p_seed if p_seed >= 0 else int(Time.get_ticks_usec() % 1000000007)
	rng.seed = seed_value
	for i in BCData.RACES.size():
		civs.append(_make_civ(BCData.RACES[i], i))
	links = _make_links()
	for c in civs:
		for l in links:
			if l.x == c.id: c.links.append(l.y)
			elif l.y == c.id: c.links.append(l.x)
	_init_relations()
	_assign_roles(true)
	log_event("Twelve jars sit on the Wall. Ten are awake; two stay sealed.", "sys")

func t() -> float: return clock / DAY_LEN
func r() -> float: return rng.randf()
func rr(a: float, b: float) -> float: return rng.randf_range(a, b)
func pick(arr: Array): return arr[rng.randi() % arr.size()]
func shuffled(arr: Array) -> Array:
	var a := arr.duplicate()
	for i in range(a.size() - 1, 0, -1):
		var j := rng.randi() % (i + 1)
		var tmp = a[i]; a[i] = a[j]; a[j] = tmp
	return a

func log_event(text: String, kind: String = "info", who: Array = []) -> void:
	var ev := {"day": day, "t": t(), "text": text, "kind": kind, "civs": who, "serial": event_serial}
	event_serial += 1
	events.append(ev)
	if events.size() > 300: events.pop_front()
	event_logged.emit(ev)

func _make_civ(race: Dictionary, id: int) -> Civ:
	var c := Civ.new()
	c.id = id; c.race = race; c.name = race.jar
	for i in 14:
		_spawn_citizen(c, {id: 1.0}, rr(3.0, float(race.traits.lifespan) * 0.5), -1)
	return c

func _make_links() -> Array:
	var out: Array = []
	var live := BCData.RACES.size()
	var seen := {}
	for i in live:
		var x := i % BCData.COLS
		var y := i / BCData.COLS
		for d in [Vector2i(1, 0), Vector2i(0, 1), Vector2i(1, 1), Vector2i(-1, 1)]:
			var nx: int = x + d.x
			var ny: int = y + d.y
			if nx < 0 or ny < 0 or nx >= BCData.COLS or ny >= BCData.ROWS: continue
			var j: int = ny * BCData.COLS + nx
			if j >= live: continue
			var key := "%d-%d" % [mini(i, j), maxi(i, j)]
			if seen.has(key): continue
			seen[key] = true
			out.append(Vector2i(i, j))
	return out

func _init_relations() -> void:
	for a in civs:
		for b in civs:
			if a == b: continue
			a.rel[b.id] = clampf(_base_rel(a, b) + rr(-12, 12), -90, 90)

func _base_rel(a: Civ, b: Civ) -> float:
	var v := 0.0
	if a.race.like.has(b.race.id): v += 35
	if a.race.dislike.has(b.race.id): v -= 35
	if b.race.like.has(a.race.id): v += 15
	if b.race.dislike.has(a.race.id): v -= 15
	return v

# ---------- citizens ----------
func _spawn_citizen(civ: Civ, blood: Dictionary, age: float, loc: int) -> Citizen:
	var home := _house_spot(civ)
	var c := Citizen.new()
	c.id = next_id; next_id += 1
	c.home = civ.id; c.loc = civ.id if loc < 0 else loc
	c.blood = blood; c.age = age
	c.pos = home; c.target = home
	c.timer = rr(0, 4)
	c.life_mul = rr(0.8, 1.2)
	civ.citizens.append(c)
	return c

func house_xy(i: int) -> Vector2:
	return Vector2(14.0 + float((i % 8) * 24 % 172) + 8.0, 124.0 + float((i / 8) % 2) * 12.0)

func _house_spot(civ: Civ) -> Vector2:
	return house_xy(rng.randi() % maxi(1, civ.houses))

func dominant(c: Citizen) -> int:
	var best := -1
	var bv := -1.0
	for k in c.blood:
		if c.blood[k] > bv: bv = c.blood[k]; best = k
	return best

func is_hybrid(c: Citizen) -> bool:
	return c.blood[dominant(c)] < 0.93

func mixed_mult(c: Citizen, key: String) -> float:
	var v := 0.0
	for k in c.blood: v += c.blood[k] * BCData.RACES[k].mult[key]
	return v * (1.06 if is_hybrid(c) else 1.0)

func is_adult(c: Citizen) -> bool: return c.age >= 2.0

func might_of(c: Citizen) -> float:
	var hp := 0.0
	for k in c.blood: hp += c.blood[k] * float(BCData.RACES[k].get("hp", 1.0))
	return mixed_mult(c, "might") * (0.75 + 0.25 * minf(2.0, 1.0 + c.xp)) * (0.6 + 0.4 * hp)

func remove_citizen(c: Citizen, cause: String = "dead") -> void:
	var civ: Civ = civs[c.home]
	civ.citizens.erase(c)
	if c.party != null: c.party.members.erase(c)
	civ.stats.deaths += 1
	c.dead = cause

func lifespan_of(c: Citizen) -> float:
	var v := 0.0
	for k in c.blood: v += c.blood[k] * BCData.RACES[k].traits.lifespan
	return v

func capacity(c: Civ) -> int: return 12 + c.houses * 4

func fertility_of(c: Citizen) -> float:
	var v := 0.0
	for k in c.blood: v += c.blood[k] * BCData.RACES[k].traits.fertility
	return v

# ---------- main loop ----------
func step(dt: float) -> void:
	if pending_battle != null or game_over_flag: return
	dt = minf(dt, 0.25)
	clock += dt
	if clock >= DAY_LEN:
		clock -= DAY_LEN
		_new_day()
	if not locked and t() >= DUSK:
		_lock_jars()
	if not locked:
		while decisions_done < DECISIONS.size() and t() >= DECISIONS[decisions_done]:
			decisions_done += 1
			_decide()
	_update_parties(dt)
	_update_citizens(dt)
	for c in civs:
		if c.flash_t > 0.0: c.flash_t -= dt

# ---------- dawn ----------
func _new_day() -> void:
	locked = false
	day += 1
	decisions_done = 0
	for c in civs: c.launches = 0
	_dawn_births()
	for p in parties:
		if p.state == "guest":
			p.state = "back"; p.p = 1.0; p.dir = -1
			for m in p.members: m.loc = -1
	for c in civs:
		if not c.alive: continue
		var eat := float(c.race.get("eats", 1.0))
		for cit in c.citizens.duplicate():
			cit.age += 1.0
			if cit.age > lifespan_of(cit) * cit.life_mul and r() < 0.5:
				remove_citizen(cit, "age")
				if c.race.id != "skeleton":
					log_event("%s: an elder of the %s passed away." % [c.name, c.race.name], "death", [c.id])
		var need := 0.0
		for cit in c.citizens: need += eat if is_adult(cit) else eat * 0.5
		c.stock.food -= need
		if c.stock.food < 0.0:
			var starve := mini(c.citizens.size() - 2, mini(ceili(-c.stock.food / 3.0), ceili(c.citizens.size() * 0.2)))
			c.stock.food = 0.0
			if starve > 0:
				for i in starve:
					var v = pick(c.citizens)
					if v != null and c.citizens.size() > 2: remove_citizen(v, "starved")
				log_event("%s starves: %d of the %s died of hunger." % [c.name, starve, c.race.name], "death", [c.id])
		var nt := int(floor(sqrt(c.stock.lore / 8.0) * float(c.race.get("techBonus", 1.0))))
		if nt > c.tech:
			c.tech = nt
			log_event("%s reaches tech level %d." % [c.name, nt], "tech", [c.id])
		if c.houses < 9 and c.citizens.size() >= capacity(c) - 3 and c.stock.wood >= 14.0 and c.stock.goods >= 6.0:
			c.stock.wood -= 14.0; c.stock.goods -= 6.0; c.houses += 1
		if c.race.get("brew", false) and c.stock.food > c.citizens.size() * 6.0:
			c.stock.food -= 10.0; c.stock.gold += 6.0
		var pop_now: int = c.citizens.size()
		if c.race.get("raiseDead", false):
			if c.stock.ore >= 3.0 and pop_now < capacity(c) and r() < minf(0.85, 0.2 + pop_now * 0.04):
				c.stock.ore -= 3.0
				_spawn_citizen(c, {c.id: 1.0}, 3.0, -1)
				c.stats.births += 1
		elif pop_now < capacity(c) * 0.45 and c.stock.food > 6.0 and r() < 0.6:
			_spawn_citizen(c, {c.id: 1.0}, 3.0, -1)
			if pop_now < 5: log_event("Wanderers settle in %s." % c.name, "sys", [c.id])
		if pop_now < 2:
			_spawn_citizen(c, {c.id: 1.0}, 3.0, -1)
			_spawn_citizen(c, {c.id: 1.0}, 3.0, -1)
		for o in civs:
			if o == c: continue
			if not o.alive: continue
			c.rel[o.id] += (_base_rel(c, o) - c.rel[o.id]) * 0.04
			if c.allies.has(o.id): c.rel[o.id] = maxf(c.rel[o.id], 45.0)
			if c.war.has(o.id) and day >= c.war[o.id]:
				c.war.erase(o.id); o.war.erase(c.id)
				c.rel[o.id] = maxf(c.rel[o.id], -10.0)
				o.rel[c.id] = maxf(o.rel[c.id], -10.0)
				log_event("%s and %s agree to a truce." % [c.name, o.name], "peace", [c.id, o.id])
	ap = ap_max
	for c in civs:
		if c.special_cd > 0: c.special_cd -= 1
		if c.war_cry > 0: c.war_cry -= 1
	_world_event()
	_assign_roles(false)
	log_event("Day %d dawns. The jars unlock." % day, "sys")
	_check_victory()

func _dawn_births() -> void:
	for c in civs:
		if not c.alive: continue
		for b in c.pending_births:
			var target: Civ = civs[b.home]
			_spawn_citizen(target, b.blood, 0.0, b.home)
			target.stats.births += 1
			if b.hybrid:
				target.stats.hybrid_births += 1
				stats.hybrids += 1
				log_event("A hybrid child of %s and %s is born in %s." % [BCData.RACES[b.a].name, BCData.RACES[b.b].name, target.name], "birth", [b.a, b.b])
			birth.emit(b.home, b.hybrid)
		c.pending_births = []
	for c in civs:
		if not c.alive: continue
		var fert: float = c.race.traits.fertility
		if fert <= 0.0: continue
		var adults: Array = c.citizens.filter(func(x): return is_adult(x) and x.loc == c.id)
		var room: int = capacity(c) - c.citizens.size()
		if room <= 0 or c.stock.food < c.citizens.size() * 1.5: continue
		var births := 0
		var pairs: int = adults.size() / 2
		for i in pairs:
			if births >= room: break
			if r() < fert * 1.6: births += 1
		for i in births:
			var a = pick(adults)
			_spawn_citizen(c, a.blood.duplicate(), 0.0, -1)
			c.stats.births += 1
			birth.emit(c.id, false)

func _assign_roles(initial: bool) -> void:
	for c in civs:
		if not c.alive: continue
		var adults: Array = c.citizens.filter(func(x): return is_adult(x))
		for x in c.citizens:
			if not is_adult(x): x.role = "child"
		var n := adults.size()
		if n == 0: continue
		var hunger := 1.0
		if c.stock.food < c.citizens.size() * 3.0: hunger = 2.6
		elif c.stock.food > c.citizens.size() * 8.0: hunger = 0.55
		var m: Dictionary = c.race.mult
		var at_war: bool = c.war.size() > 0
		var w_build := 1.6 if c.stock.wood < 20.0 else 1.0
		var shr := 1.4 if c.race.has("soldierShare") else 1.0
		var w := {
			"farm": 1.9 * m.food * hunger,
			"wood": 0.9 * m.wood * w_build,
			"mine": 0.9 * m.ore,
			"craft": 0.8 * m.goods,
			"study": 0.7 * m.lore,
			"trade": 0.55 * m.gold,
			"soldier": (0.25 + c.race.traits.aggression * 0.9 * shr) * (1.6 if at_war else 1.0) * m.might,
		}
		if c.race.id == "skeleton": w.farm = 0.4
		var pm: Dictionary = POLICIES.get(c.policy, {})
		for k in pm: w[k] *= pm[k]
		var sum := 0.0
		for k in w: sum += w[k]
		var quota := {}
		var left := n
		var rema: Array = []
		for k in w:
			var q: float = (w[k] / sum) * n
			quota[k] = int(floor(q)); left -= quota[k]
			rema.append([k, q - quota[k]])
		rema.sort_custom(func(a, b): return a[1] > b[1])
		for i in left: quota[rema[i % rema.size()][0]] += 1
		if quota.farm == 0 and c.race.id != "skeleton":
			quota.farm = 1
			var big := ""
			var bv := -1
			for k in quota:
				if quota[k] > bv: bv = quota[k]; big = k
			if big != "farm": quota[big] -= 1
		var free: Array = []
		var cnt := {}
		for a in adults:
			if not initial and quota.has(a.role) and quota[a.role] > cnt.get(a.role, 0):
				cnt[a.role] = cnt.get(a.role, 0) + 1
			else:
				free.append(a)
		for k in quota:
			while cnt.get(k, 0) < quota[k] and free.size() > 0:
				var a = free.pop_back()
				a.role = k
				cnt[k] = cnt.get(k, 0) + 1
		for a in free: a.role = "farm"
		c.role_count = cnt
		for a in adults: _set_work(a)

func _set_work(a: Citizen) -> void:
	var s: Vector2 = SITES.get(a.role, Vector2(100, 116))
	a.target = s + Vector2(rr(-14, 14), rr(-10, 10))
	a.state = "walk"
	a.timer = rr(2, 6)

# ---------- AI ----------
func surplus(c: Civ) -> Dictionary:
	var n := c.citizens.size()
	return {"food": c.stock.food - n * 4.0, "wood": c.stock.wood - 25.0, "ore": c.stock.ore - 20.0, "goods": c.stock.goods - 14.0, "lore": -999.0, "gold": -999.0}

func soldiers_of(c: Civ) -> Array:
	return c.citizens.filter(func(x): return x.role == "soldier" and x.loc == c.id and x.party == null)

func power(list: Array) -> float:
	var p := 0.0
	for x in list: p += might_of(x)
	return p

func _decide() -> void:
	for c in shuffled(civs):
		if not c.alive or c.id == player: continue
		if c.launches >= 1 and r() < 0.6: continue
		var choices: Array = [{"w": 0.9, "act": "none"}]
		var sold := soldiers_of(c)
		var my_pow := power(sold)
		var my_sur := surplus(c)
		for j_id in c.links:
			var o: Civ = civs[j_id]
			if not o.alive: continue
			var busy := false
			for p in parties:
				if p.from == c.id and p.to == j_id and p.state != "done": busy = true
			if busy: continue
			var rel: float = c.rel[j_id]
			var at_war: bool = c.war.has(j_id)
			var their_pow := power(o.citizens.filter(func(x): return x.role == "soldier" and x.loc == j_id)) + 0.2 * o.citizens.size()
			var o_sur := surplus(o)
			var give := ""
			var take := ""
			var gv := 6.0
			var tv := 6.0
			for res in BCData.RES:
				if my_sur[res] > gv: gv = my_sur[res]; give = res
			for res in BCData.RES:
				if res != give and o_sur[res] > tv: tv = o_sur[res]; take = res
			if not at_war and rel > -30:
				var wt: float = (0.5 if (give != "" and take != "") else 0.08) + c.race.traits.openness * 0.7 + c.race.traits.greed * 0.4 + (0.6 if c.race.has("tradeBonus") else 0.0) + rel / 150.0
				choices.append({"w": maxf(0.02, wt), "act": "trade", "to": j_id, "give": give, "take": take})
			if not c.allies.has(j_id) and day >= 4 and sold.size() >= RAIDER_MIN and o.citizens.size() >= 8 and c.last_raid.get(j_id, -1) != day and not (not o.war.has(c.id) and o.citizens.size() < c.citizens.size() * 0.35):
				var ratio := clampf(my_pow / maxf(2.0, their_pow), 0.3, 2.5)
				var hostile := 1.0 if rel < 20.0 else 0.12
				var need := (0.5 if c.stock.food < c.citizens.size() * 3.0 else 0.0) + (0.2 if c.race.traits.greed > 0.6 else 0.0)
				var wt: float = c.race.traits.aggression * 0.95 * ratio * hostile * (1.8 if at_war else 1.0) + need * hostile
				if j_id == player: wt *= [0.55, 1.0, 1.5][difficulty]
				if wt > 0.04: choices.append({"w": wt, "act": "raid", "to": j_id})
			if not at_war and rel > -10.0 and c.race.traits.fertility > 0.0 and o.race.traits.fertility > 0.0:
				var wt: float = c.race.traits.openness * (0.9 if rel > 10.0 else 0.25) * float(c.race.get("charm", 1.0)) * (1.3 if o.race.like.has(c.race.id) else 0.8)
				choices.append({"w": wt, "act": "envoy", "to": j_id})
			if c.race.get("spy", false) and rel < 60.0:
				choices.append({"w": 0.5 + c.race.traits.greed * 0.4, "act": "spy", "to": j_id})
		var total := 0.0
		for ch in choices: total += ch.w
		var roll := r() * total
		var chosen: Dictionary = choices[0]
		for ch in choices:
			roll -= ch.w
			if roll <= 0.0: chosen = ch; break
		if chosen.act != "none":
			_launch(c, chosen)
			c.launches += 1

func _pick_members(c: Civ, role: String, n: int) -> Array:
	var pool: Array = c.citizens.filter(func(x): return x.loc == c.id and x.party == null and is_adult(x) and (role == "" or x.role == role))
	return shuffled(pool).slice(0, n)

func _launch(c: Civ, a: Dictionary) -> void:
	var o: Civ = civs[a.to]
	var members: Array = []
	var cargo := {}
	match a.act:
		"trade":
			members = _pick_members(c, "trade", 2)
			if members.is_empty(): members = _pick_members(c, "", 2)
			if a.give != "":
				var amt := minf(c.stock[a.give], maxf(5.0, floor(surplus(c)[a.give] * 0.6)))
				c.stock[a.give] -= amt
				cargo[a.give] = amt
			cargo["wantRes"] = a.take
		"raid":
			var s := soldiers_of(c)
			s.sort_custom(func(x, y): return might_of(x) > might_of(y))
			var k := clampi(ceili(s.size() * 0.7), RAIDER_MIN, 9)
			members = s.slice(0, k)
			if not c.war.has(a.to):
				c.war[a.to] = day + 3
				o.war[c.id] = day + 3
				c.rel[a.to] -= 25.0
				o.rel[c.id] -= 35.0
				log_event("%s declares war on %s!" % [c.name, o.name], "war", [c.id, a.to])
			c.stats.raids += 1
			c.last_raid[a.to] = day
		"envoy":
			members = _pick_members(c, "", 2)
			c.stats.envoys += 1; stats.envoys += 1
		"spy":
			members = _pick_members(c, "", 1)
			stats.spies += 1
	if members.is_empty(): return
	var p := Party.new()
	p.id = next_id; next_id += 1
	p.kind = a.act; p.from = c.id; p.to = a.to; p.members = members; p.cargo = cargo
	for m in members:
		m.party = p; m.loc = -1; m.hidden = false
	parties.append(p)
	var verb: String = {"trade": "sends a trade caravan to", "raid": "sends a raiding party against", "envoy": "sends envoys to", "spy": "sends a spy into"}[a.act]
	log_event("%s %s %s." % [c.name, verb, o.name], "war" if a.act == "raid" else "info", [c.id, a.to])

# ---------- parties ----------
func _update_parties(dt: float) -> void:
	for p in parties:
		if p.state == "done": continue
		if p.members.is_empty():
			p.state = "done"; continue
		if p.state == "out":
			p.p += dt / TRAVEL
			if p.p >= 1.0:
				p.p = 1.0
				_arrive(p)
		elif p.state == "host":
			p.host_t -= dt
			if p.host_t <= 0.0:
				p.state = "back"; p.dir = -1
				for m in p.members: m.loc = -1
		elif p.state == "back":
			p.p -= dt / TRAVEL
			if p.p <= 0.0:
				p.p = 0.0
				_homecoming(p)
	parties = parties.filter(func(p): return p.state != "done")

func _arrive(p: Party) -> void:
	var to: Civ = civs[p.to]
	var from: Civ = civs[p.from]
	p.state = "host"; p.host_t = 5.0
	for m in p.members:
		m.loc = p.to
		m.pos = Vector2(100, 140)
		m.target = Vector2(90 + rr(-10, 10), 100 + rr(-8, 8))
		m.state = "walk"
	match p.kind:
		"trade": _do_trade(p, from, to)
		"raid":
			if tactical_enabled and (p.from == player or p.to == player):
				p.host_t = 9999.0
				pending_battle = p
				tactical_battle.emit(p)
			else:
				_do_battle(p, from, to, false)
		"envoy":
			var gain := 8.0 * float(from.race.get("charm", 1.0)) * float(to.race.get("charm", 1.0))
			from.rel[to.id] += gain; to.rel[from.id] += gain
			p.host_t = 8.0
			to.flash = "trade"; to.flash_t = 2.0
		"spy": _do_spy(p, from, to)

func _homecoming(p: Party) -> void:
	var from: Civ = civs[p.from]
	for m in p.members:
		m.party = null; m.loc = from.id; m.pos = Vector2(100, 140); m.state = "idle"
		_set_work(m)
	for k in BCData.RES:
		if p.cargo.has(k): from.stock[k] += p.cargo[k]
		if p.loot.has(k):
			from.stock[k] += p.loot[k]; from.stats.plunder += p.loot[k]
	for cap in p.captives:
		var old: Civ = civs[cap.home]
		old.citizens.erase(cap)
		cap.home = from.id; cap.loc = from.id; cap.party = null; cap.role = "farm"; cap.pos = Vector2(100, 140)
		from.citizens.append(cap)
		_set_work(cap)
	p.state = "done"
	if p.kind == "trade":
		from.flash = "trade"; from.flash_t = 2.0

func _do_trade(p: Party, from: Civ, to: Civ) -> void:
	var bonus := float(from.race.get("tradeBonus", 1.0)) * float(to.race.get("tradeBonus", 1.0))
	var give := ""
	for k in p.cargo:
		if BCData.RES.has(k): give = k; break
	var want: String = p.cargo.get("wantRes", "")
	stats.trades += 1; from.stats.trades += 1; to.stats.trades += 1
	if give != "" and want != "":
		var amt: float = p.cargo[give]
		var back := floorf(minf(to.stock[want], amt * bonus * 0.9))
		to.stock[give] += amt; to.stock[want] -= back
		p.cargo = {want: back}
		log_event("%s swaps %d %s for %d %s with %s." % [from.name, int(amt), give, int(back), want, to.name], "trade", [from.id, to.id])
	elif give != "":
		var amt: float = p.cargo[give]
		to.stock[give] += amt
		var pay := minf(to.stock.gold, floorf(amt * 0.7 * bonus))
		to.stock.gold -= pay
		p.cargo = {"gold": pay}
		log_event("%s sells %d %s to %s for %d gold." % [from.name, int(amt), give, to.name, int(pay)], "trade", [from.id, to.id])
	else:
		p.cargo = {}
	p.cargo.erase("wantRes")
	from.rel[to.id] += 6.0; to.rel[from.id] += 6.0
	from.stock.gold += 1.0; to.stock.gold += 1.0
	to.flash = "trade"; to.flash_t = 2.5; from.flash = "trade"; from.flash_t = 2.5

func _do_spy(p: Party, from: Civ, to: Civ) -> void:
	var steal := floorf(to.stock.gold * rr(0.08, 0.2))
	to.stock.gold -= steal
	p.loot["gold"] = p.loot.get("gold", 0.0) + steal
	log_event("An Imp from %s sneaks into %s and steals %d gold." % [from.name, to.name, int(steal)], "spy", [from.id, to.id])
	if r() < 0.6:
		var others: Array = to.links.filter(func(j): return j != from.id)
		if not others.is_empty():
			var v: Civ = civs[pick(others)]
			to.rel[v.id] -= 22.0; v.rel[to.id] -= 22.0
			log_event("The crime is blamed on %s. Relations between %s and %s sour." % [v.name, to.name, v.name], "spy", [to.id, v.id])
	if r() < 0.25 and not p.members.is_empty():
		remove_citizen(p.members[0], "caught")
		log_event("The imp is caught and hanged in %s." % to.name, "death", [to.id])
	p.host_t = 3.0
	to.flash = "spy"; to.flash_t = 2.0

func _kill_pick(list: Array, frac: float) -> Array:
	var k := roundi(list.size() * frac)
	if frac > 0.05 and k == 0: k = 1
	return shuffled(list).slice(0, k)

func _do_battle(p: Party, from: Civ, to: Civ, night: bool) -> void:
	var atk: Array = p.members.duplicate()
	var def_sold: Array = to.citizens.filter(func(x): return x.role == "soldier" and x.loc == to.id and x.party == null)
	var def_other: Array = to.citizens.filter(func(x): return x.role != "soldier" and is_adult(x) and x.loc == to.id and x.party == null)
	var a_pow := power(atk) * (1.0 + from.tech * 0.06 + from.barracks * 0.12 + (0.25 if from.war_cry > 0 else 0.0)) * (0.75 if night else 1.0)
	var d_pow := (power(def_sold) + 0.22 * power(def_other)) * (1.0 + to.tech * 0.06 + to.barracks * 0.12 + to.walls * 0.12 + (0.25 if to.war_cry > 0 else 0.0)) * (1.3 if night else 1.15)
	a_pow = maxf(0.1, a_pow); d_pow = maxf(0.1, d_pow)
	var ratio := a_pow / d_pow
	var cf_d := clampf(0.32 * ratio * rr(0.7, 1.3), 0.04, 0.85)
	var cf_a := clampf(0.32 / ratio * rr(0.7, 1.3), 0.06, 0.95)
	var attacker_wins := cf_d > cf_a
	var a_dead := _kill_pick(atk, cf_a)
	var d_kill: Array = _kill_pick(def_sold, cf_d) + _kill_pick(def_other, cf_d * 0.35)
	_finish_battle(p, from, to, night, attacker_wins, a_dead, d_kill, ratio)

## Shared by auto-resolve and tactical battles: applies casualties, loot, captives and diplomacy fallout.
func _finish_battle(p: Party, from: Civ, to: Civ, night: bool, attacker_wins: bool, a_dead: Array, d_kill: Array, ratio: float) -> void:
	var atk: Array = p.members.duplicate()
	var d_set := {}
	for x in d_kill: d_set[x] = true
	var dead := 0
	for x in a_dead:
		remove_citizen(x, "battle"); from.stats.losses += 1; to.stats.kills += 1; dead += 1
	for x in d_set.keys():
		remove_citizen(x, "battle"); to.stats.losses += 1; from.stats.kills += 1; dead += 1
	stats.battles += 1
	from.rel[to.id] -= 12.0; to.rel[from.id] -= 18.0
	from.flash = "battle"; from.flash_t = 3.0; to.flash = "battle"; to.flash_t = 4.0
	for m in p.members: m.xp = minf(2.0, m.xp + 0.25)
	var msg := "%s: %s (%d) vs %s - %d raiders and %d defenders fall." % ["Night battle" if night else "Battle", from.name, atk.size(), to.name, a_dead.size(), d_set.size()]
	if attacker_wins:
		var frac := 0.18 * float(from.race.get("plunder", 1.0)) * clampf(ratio, 0.6, 1.8)
		for k in ["food", "goods", "gold", "ore", "wood"]:
			var take := floorf(to.stock[k] * frac * 0.8)
			to.stock[k] -= take
			p.loot[k] = p.loot.get(k, 0.0) + take
		var pool: Array = to.citizens.filter(func(x): return is_adult(x) and x.loc == to.id and x.party == null and x.role != "soldier")
		var cap_n := mini(pool.size(), 1 if r() < 0.5 else 2)
		for i in cap_n:
			var cc = pick(pool)
			if cc != null and not p.captives.has(cc):
				p.captives.append(cc); cc.party = p; cc.loc = -1
		msg += " %s wins and carries off loot%s." % [from.name, (" and %d captive(s)" % p.captives.size()) if p.captives.size() > 0 else ""]
		if dead > 0 and from.race.get("raiseDead", false): _raise_dead(from, ceili(d_set.size() * 0.6) + 1)
	else:
		msg += " %s holds the jar." % to.name
		to.stats.defended += 1
		if dead > 0 and to.race.get("raiseDead", false): _raise_dead(to, ceili(a_dead.size() * 0.6))
	log_event(msg, "war", [from.id, to.id])
	battle.emit(from.id, to.id, night)
	p.host_t = 0.0 if night else 6.0
	if not attacker_wins and from.war.has(to.id) and r() < 0.5:
		from.war[to.id] = mini(from.war[to.id], day + 1)
		to.war[from.id] = from.war[to.id]

func _raise_dead(civ: Civ, n: int) -> void:
	n = mini(n, maxi(0, capacity(civ) + 6 - civ.citizens.size()))
	if n <= 0: return
	for i in n:
		var s := _spawn_citizen(civ, {civ.id: 1.0}, 5.0, -1)
		s.role = "soldier"
		_set_work(s)
	civ.stats.raised += n
	log_event("%s raise %d fallen warriors as new skeletons." % [civ.name, n], "war", [civ.id])

# ---------- night ----------
func _lock_jars() -> void:
	locked = true
	log_event("Dusk. Every jar locks for the night.", "sys")
	for p in parties:
		if p.state == "done": continue
		if p.state == "out":
			if p.p < 0.5:
				p.state = "back"
				log_event("A %s party from %s turns back at dusk." % [p.kind, civs[p.from].name], "info", [p.from])
			else:
				p.p = 1.0
				_arrive_locked(p)
		elif p.state == "back":
			if p.p < 0.5:
				p.p = 0.0
				_homecoming(p)
			else:
				p.p = 1.0; p.dir = 1
				_become_guest(p)
		elif p.state == "host":
			_become_guest(p)
	parties = parties.filter(func(p): return p.state != "done")
	_night_mingle()

func _arrive_locked(p: Party) -> void:
	var from: Civ = civs[p.from]
	var to: Civ = civs[p.to]
	for m in p.members:
		m.loc = p.to; m.pos = Vector2(100, 130); m.state = "walk"
	match p.kind:
		"raid": _do_battle(p, from, to, true)
		"trade": _do_trade(p, from, to)
		"spy": _do_spy(p, from, to)
		"envoy":
			from.rel[to.id] += 6.0; to.rel[from.id] += 6.0
	if p.state != "done": _become_guest(p)

func _become_guest(p: Party) -> void:
	p.state = "guest"
	for m in p.members:
		m.loc = p.to
		m.target = Vector2(70 + rr(0, 60), 100 + rr(-6, 14))
		m.state = "walk"
	if p.members.size() > 0:
		log_event("%d traveller(s) from %s are locked in %s overnight." % [p.members.size(), civs[p.from].name, civs[p.to].name], "info", [p.from, p.to])

func _night_mingle() -> void:
	for p in parties:
		if p.state != "guest": continue
		var host: Civ = civs[p.to]
		var from: Civ = civs[p.from]
		if from.war.has(host.id): continue
		if host.guest_stance == "hostage":
			var n: int = p.members.size()
			host.stock.gold += 10.0 * n
			from.rel[host.id] -= 15.0; host.rel[from.id] -= 6.0
			log_event("%s holds %d traveller(s) of %s hostage overnight and demands ransom." % [host.name, n, from.name], "war", [host.id, from.id])
			continue
		var rel: float = from.rel[host.id]
		for g in p.members:
			if not is_adult(g) or fertility_of(g) <= 0.0: continue
			var mates: Array = host.citizens.filter(func(h): return is_adult(h) and h.loc == host.id and h.party == null and fertility_of(h) > 0.0)
			if mates.is_empty(): continue
			var chance := clampf(0.1 + rel / 220.0 + float(from.race.get("charm", 1.0)) * 0.04, 0.0, 0.55)
			if r() < chance:
				var mate = pick(mates)
				var blood := {}
				for k in g.blood: blood[k] = blood.get(k, 0.0) + g.blood[k] / 2.0
				for k in mate.blood: blood[k] = blood.get(k, 0.0) + mate.blood[k] / 2.0
				var home_id: int = host.id if r() < 0.55 else from.id
				var a := dominant(g)
				var b := dominant(mate)
				var dest: Civ = civs[home_id]
				dest.pending_births.append({"home": home_id, "blood": blood, "hybrid": a != b, "a": a, "b": b})
				from.rel[host.id] += 3.0; host.rel[from.id] += 3.0

# ---------- citizens ----------
func _update_citizens(dt: float) -> void:
	for civ in civs:
		for c in civ.citizens:
			if c.loc < 0: continue
			var visitor: bool = c.loc != c.home
			if locked and not visitor:
				if c.state != "sleep" and c.state != "gohome":
					c.target = _house_spot(civ); c.state = "gohome"
			elif not locked and (c.state == "sleep" or c.state == "gohome"):
				c.hidden = false
				_set_work(c)
			var d: Vector2 = c.target - c.pos
			var dist := d.length()
			if dist > 1.2 and c.state != "sleep" and c.state != "work":
				var sp := (26.0 if c.state == "gohome" else 20.0) * (0.8 if c.role == "child" else 1.0)
				c.pos += d / dist * sp * dt
				if absf(d.x) > 0.5: c.face = 1 if d.x > 0 else -1
			elif c.state == "walk":
				c.state = "work"; c.timer = rr(4, 7)
			elif c.state == "gohome":
				c.state = "sleep"; c.hidden = true
			elif c.state == "work":
				c.timer -= dt
				if c.timer <= 0.0:
					_produce(civ, c)
					c.timer = rr(5, 7)
					if c.role == "child" or r() < 0.3: _jitter(c)
			elif c.state == "idle":
				c.timer -= dt
				if c.timer <= 0.0: _jitter(c)

func _jitter(c: Citizen) -> void:
	var base: Vector2 = SITES.get(c.role, Vector2(100, 118))
	c.target = base + Vector2(rr(-16, 16), rr(-10, 10))
	c.state = "walk"
	if c.role == "child": c.timer = rr(2, 5)

func _produce(civ: Civ, c: Citizen) -> void:
	if c.loc != c.home or locked: return
	var tech_m := 1.0 + civ.tech * 0.06
	if c.role == "soldier":
		c.xp = minf(2.0, c.xp + 0.02); civ.stock.food -= 0.05
		return
	if not ROLE_RES.has(c.role): return
	var res: String = ROLE_RES[c.role]
	var base: float = {"food": 0.55, "wood": 0.5, "ore": 0.45, "goods": 0.45, "lore": 0.35, "gold": 0.4}[res]
	var amt := base * mixed_mult(c, res) * tech_m
	if c.role == "craft":
		if civ.stock.ore >= 0.5 and civ.stock.wood >= 0.3:
			civ.stock.ore -= 0.5; civ.stock.wood -= 0.3; amt *= 1.5
		else:
			amt *= 0.4
	civ.stock[res] += amt

func total_pop() -> int:
	var n := 0
	for c in civs: n += c.citizens.size()
	return n


# =====================================================================================
# Player layer: action points, policy, building, diplomacy, annexation, victory
# =====================================================================================
func set_difficulty(d: int) -> void:
	difficulty = clampi(d, 0, 2)
	ap_max = 4 if difficulty == 0 else AP_MAX
	ap = ap_max

func set_player(id: int) -> void:
	player = id
	ap = ap_max
	if id >= 0:
		log_event("You rule %s, home of the %s. You have %d actions each day." % [civs[id].name, civs[id].race.name, ap_max], "sys", [id])

func pc() -> Civ: return civs[player] if player >= 0 else null

func _res(ok: bool, msg: String) -> Dictionary:
	return {"ok": ok, "msg": msg}

func _spend() -> bool:
	if ap <= 0: return false
	ap -= 1
	return true

func _pay(c: Civ, cost: Dictionary) -> bool:
	for k in cost:
		if c.stock[k] < cost[k]: return false
	for k in cost: c.stock[k] -= cost[k]
	return true

func _cost_text(cost: Dictionary) -> String:
	var parts: Array = []
	for k in cost: parts.append("%d %s" % [cost[k], k])
	return ", ".join(parts)

func act_policy(pol: String) -> Dictionary:
	var c := pc()
	if c == null or not POLICIES.has(pol): return _res(false, "No such policy.")
	c.policy = pol
	_assign_roles(false)
	log_event("%s adopts a %s policy." % [c.name, pol], "sys", [c.id])
	return _res(true, "Policy set to %s." % pol)

const BUILD_COST := {
	"house": {"wood": 14, "goods": 6},
	"barracks": {"ore": 20, "wood": 15, "goods": 8},
	"walls": {"ore": 25, "goods": 15},
	"wonder": {"gold": 220, "goods": 140, "lore": 140},
}

func act_build(kind: String) -> Dictionary:
	var c := pc()
	if c == null or not BUILD_COST.has(kind): return _res(false, "Unknown project.")
	if ap <= 0: return _res(false, "No actions left today.")
	match kind:
		"house": if c.houses >= 9: return _res(false, "No room for more houses.")
		"barracks": if c.barracks >= 5: return _res(false, "Barracks are fully upgraded.")
		"walls": if c.walls >= 5: return _res(false, "Walls are fully upgraded.")
		"wonder":
			if c.wonder_started: return _res(false, "The Great Work is already underway.")
			if c.tech < 5: return _res(false, "Needs tech level 5.")
	if not _pay(c, BUILD_COST[kind]): return _res(false, "Needs %s." % _cost_text(BUILD_COST[kind]))
	_spend()
	match kind:
		"house": c.houses += 1
		"barracks": c.barracks += 1
		"walls": c.walls += 1
		"wonder":
			c.wonder_started = true
			log_event("%s begins the Great Work! %d days to completion." % [c.name, WONDER_DAYS], "tech", [c.id])
	return _res(true, "Built: %s." % kind)

func _link_ok(c: Civ, t: int) -> bool:
	return t >= 0 and t < civs.size() and civs[t].alive and c.links.has(t)

func _busy(a: int, b: int) -> bool:
	for p in parties:
		if p.from == a and p.to == b and p.state != "done": return true
	return false

func act_diplo(kind: String, t: int) -> Dictionary:
	var c := pc()
	if c == null: return _res(false, "Spectating.")
	if ap <= 0: return _res(false, "No actions left today.")
	if locked: return _res(false, "The jars are locked for the night.")
	if not _link_ok(c, t): return _res(false, "That jar is not connected to yours.")
	var o: Civ = civs[t]
	var at_war: bool = c.war.has(t)
	match kind:
		"trade":
			if at_war: return _res(false, "You are at war.")
			if _busy(c.id, t): return _res(false, "A party is already on its way.")
			var mine := surplus(c)
			var theirs := surplus(o)
			var give := ""; var take := ""; var gv := 4.0; var tv := 4.0
			for res in BCData.RES:
				if mine[res] > gv: gv = mine[res]; give = res
			for res in BCData.RES:
				if res != give and theirs[res] > tv: tv = theirs[res]; take = res
			if give == "": return _res(false, "You have no surplus to trade.")
			_spend()
			_launch(c, {"act": "trade", "to": t, "give": give, "take": take})
			return _res(true, "A caravan sets out to %s." % o.name)
		"envoy":
			if at_war: return _res(false, "You are at war.")
			if _busy(c.id, t): return _res(false, "A party is already on its way.")
			_spend()
			_launch(c, {"act": "envoy", "to": t})
			return _res(true, "Envoys depart for %s." % o.name)
		"gift":
			if c.stock.gold < 20: return _res(false, "A gift costs 20 gold.")
			c.stock.gold -= 20; o.stock.gold += 20
			_spend()
			c.rel[t] += 14.0; o.rel[c.id] += 14.0
			log_event("%s sends a gift of gold to %s." % [c.name, o.name], "trade", [c.id, t])
			return _res(true, "Gift delivered (+relations).")
		"ally":
			if c.allies.has(t): return _res(false, "Already allied.")
			if at_war: return _res(false, "You are at war.")
			if c.rel[t] < 55.0: return _res(false, "They do not trust you enough (needs 55 relations).")
			if c.stock.gold < 10: return _res(false, "An alliance feast costs 10 gold.")
			c.stock.gold -= 10
			_spend()
			if r() < 0.45 + o.race.traits.openness * 0.5:
				c.allies[t] = true; o.allies[c.id] = true
				c.rel[t] += 10.0; o.rel[c.id] += 10.0
				log_event("%s and %s sign an alliance!" % [c.name, o.name], "peace", [c.id, t])
				return _res(true, "Alliance sealed with the %s." % o.race.name)
			return _res(false, "They decline for now.")
		"break":
			if not c.allies.has(t): return _res(false, "Not allied.")
			_spend()
			c.allies.erase(t); o.allies.erase(c.id)
			c.rel[t] -= 30.0; o.rel[c.id] -= 30.0
			log_event("%s breaks its alliance with %s." % [c.name, o.name], "war", [c.id, t])
			return _res(true, "Alliance broken.")
		"war":
			if at_war: return _res(false, "Already at war.")
			_spend()
			c.allies.erase(t); o.allies.erase(c.id)
			c.war[t] = day + 3; o.war[c.id] = day + 3
			c.rel[t] -= 40.0; o.rel[c.id] -= 40.0
			log_event("%s declares war on %s!" % [c.name, o.name], "war", [c.id, t])
			return _res(true, "War declared on %s." % o.name)
		"peace":
			if not at_war: return _res(false, "You are not at war.")
			_spend()
			var chance := 0.3 + clampf((c.rel[t] + 60.0) / 200.0, 0.0, 0.4) + (0.2 if o.race.traits.aggression < 0.4 else 0.0)
			if r() < chance:
				c.war.erase(t); o.war.erase(c.id)
				c.rel[t] = maxf(c.rel[t], -10.0); o.rel[c.id] = maxf(o.rel[c.id], -10.0)
				log_event("%s and %s agree to a truce." % [c.name, o.name], "peace", [c.id, t])
				return _res(true, "Truce agreed.")
			return _res(false, "%s refuse your offer." % o.race.name)
		"raid":
			if c.allies.has(t): return _res(false, "They are your ally.")
			if _busy(c.id, t): return _res(false, "A party is already on its way.")
			if soldiers_of(c).size() < RAIDER_MIN: return _res(false, "You need at least %d soldiers at home." % RAIDER_MIN)
			_spend()
			_launch(c, {"act": "raid", "to": t})
			return _res(true, "Your warband marches on %s." % o.name)
		"spy":
			if not c.race.get("spy", false): return _res(false, "Only Imps can spy.")
			if _busy(c.id, t): return _res(false, "A party is already on its way.")
			_spend()
			_launch(c, {"act": "spy", "to": t})
			return _res(true, "A spy slips into %s." % o.name)
		"annex":
			if not at_war: return _res(false, "You can only annex a civilization you are at war with.")
			if o.citizens.size() > 14: return _res(false, "They are too populous to annex (14 or fewer).")
			if power(soldiers_of(c)) < 1.5 * (power(soldiers_of(o)) + 1.0): return _res(false, "Your soldiers are not strong enough.")
			_spend()
			_annex(c, o)
			return _res(true, "%s is annexed." % o.name)
	return _res(false, "Unknown action.")

func _annex(c: Civ, t: Civ) -> void:
	for p in parties.duplicate():
		if p.from == t.id:
			for m in p.members: m.party = null
			p.members = []
			p.state = "done"
		elif p.to == t.id:
			p.state = "back"; p.dir = -1
			for m in p.members: m.loc = -1
	for cit in t.citizens.duplicate():
		t.citizens.erase(cit)
		cit.home = c.id; cit.loc = c.id; cit.party = null; cit.role = "farm"; cit.pos = Vector2(100, 140)
		c.citizens.append(cit)
		_set_work(cit)
	for k in t.stock:
		c.stock[k] += t.stock[k] * 0.5
		t.stock[k] = 0.0
	t.alive = false
	t.annexed_by = c.id
	for o in civs:
		o.allies.erase(t.id); o.war.erase(t.id)
	log_event("%s has been annexed by %s." % [t.name, c.name], "war", [c.id, t.id])

# ---- tactical battle resolution -------------------------------------------------
func resolve_tactical(atk_alive: Array, def_alive: Array, def_all: Array, attacker_wins: bool) -> void:
	var p: Party = pending_battle
	if p == null: return
	pending_battle = null
	var from: Civ = civs[p.from]
	var to: Civ = civs[p.to]
	var a_dead: Array = p.members.filter(func(x): return not atk_alive.has(x))
	var d_dead: Array = def_all.filter(func(x): return not def_alive.has(x))
	_finish_battle(p, from, to, false, attacker_wins, a_dead, d_dead, 1.0)
	p.host_t = 6.0

func auto_resolve_pending() -> void:
	var p: Party = pending_battle
	if p == null: return
	pending_battle = null
	_do_battle(p, civs[p.from], civs[p.to], false)
	p.host_t = 6.0

# ---- victory ---------------------------------------------------------------------
func _end_game(w: int, kind: String) -> void:
	if game_over_flag: return
	game_over_flag = true
	winner = w
	win_kind = kind
	log_event("GAME OVER: %s" % kind, "sys")
	game_over.emit(w, kind)

func _check_victory() -> void:
	if game_over_flag: return
	for c in civs:
		if not c.alive: continue
		if c.wonder_started:
			if c.citizens.size() < 8: c.wonder = maxi(0, c.wonder - 1)
			else: c.wonder += 1
			if c.wonder >= WONDER_DAYS:
				log_event("%s completes the Great Work!" % c.name, "tech", [c.id])
				_end_game(c.id, "wonder")
				return
		elif c.id != player and c.tech >= 5 and c.stock.gold >= 220 and c.stock.goods >= 140 and c.stock.lore >= 140 and r() < [0.08, 0.2, 0.35][difficulty]:
			_pay(c, BUILD_COST.wonder)
			c.wonder_started = true
			log_event("%s begins the Great Work! Stop them before day %d." % [c.name, day + WONDER_DAYS], "tech", [c.id])
	if player < 0: return
	var me: Civ = civs[player]
	if not me.alive or me.citizens.size() <= 1:
		_end_game(-1, "extinction")
		return
	var others := 0
	var bound := 0
	var conquered := 0
	for c in civs:
		if c == me: continue
		if not c.alive:
			conquered += 1
			continue
		others += 1
		if me.allies.has(c.id): bound += 1
	if others == 0 or (bound == others and conquered + bound >= civs.size() - 1 and bound >= 1):
		_end_game(player, "domination" if bound == 0 else "concord")


# ---- race specials (player, 1 action, 3-day recharge) ---------------------------------
const SPECIALS := {
	"elf": ["Verdant Bloom", "+80 food, +15 lore"],
	"dwarf": ["Mother Lode", "+50 ore, +20 goods"],
	"human": ["Grand Market", "+40 gold, +6 relations with every neighbour"],
	"lizard": ["Mass Hatching", "up to 4 new citizens"],
	"orc": ["War Cry", "+25% army strength for 2 days"],
	"goblin": ["Salvage Run", "+40 goods, +25 wood"],
	"skeleton": ["Raise Legion", "6 ore: 3 new skeleton soldiers"],
	"ogre": ["Ale Feast", "40 food: +30 gold, +8 relations with neighbours"],
	"imp": ["Sow Discord", "neighbours quarrel (-15 relations), +20 gold"],
	"wizard": ["Arcane Surge", "+80 lore"],
}

func special_info(c: Civ) -> Array: return SPECIALS.get(c.race.id, ["-", ""])

func act_special() -> Dictionary:
	var c := pc()
	if c == null: return _res(false, "Spectating.")
	if ap <= 0: return _res(false, "No actions left today.")
	if locked: return _res(false, "The jars are locked for the night.")
	if c.special_cd > 0: return _res(false, "%s is recharging (%d day(s))." % [special_info(c)[0], c.special_cd])
	var live_links: Array = c.links.filter(func(j): return civs[j].alive)
	match c.race.id:
		"elf": c.stock.food += 80.0; c.stock.lore += 15.0
		"dwarf": c.stock.ore += 50.0; c.stock.goods += 20.0
		"human":
			c.stock.gold += 40.0
			for j in live_links: c.rel[j] += 6.0; civs[j].rel[c.id] += 6.0
		"lizard":
			var room: int = mini(4, capacity(c) - c.citizens.size())
			if room <= 0: return _res(false, "No room for hatchlings.")
			for i in room: _spawn_citizen(c, {c.id: 1.0}, 2.0, -1)
		"orc":
			c.war_cry = 2
			for x in c.citizens: x.xp = minf(2.0, x.xp + 0.5)
		"goblin": c.stock.goods += 40.0; c.stock.wood += 25.0
		"skeleton":
			if c.stock.ore < 6.0: return _res(false, "Needs 6 ore.")
			c.stock.ore -= 6.0
			_raise_dead(c, 3)
		"ogre":
			if c.stock.food < 40.0: return _res(false, "Needs 40 food.")
			c.stock.food -= 40.0; c.stock.gold += 30.0
			for j in live_links: c.rel[j] += 8.0; civs[j].rel[c.id] += 8.0
		"imp":
			c.stock.gold += 20.0
			var pool := live_links.duplicate()
			for i in 3:
				if pool.size() < 2: break
				var a: int = pick(pool)
				var b: int = pick(pool)
				if a != b and civs[a].links.has(b):
					civs[a].rel[b] -= 15.0; civs[b].rel[a] -= 15.0
		"wizard": c.stock.lore += 80.0
	_spend()
	c.special_cd = 3
	var info := special_info(c)
	log_event("%s uses %s!" % [c.name, info[0]], "tech", [c.id])
	c.flash = "trade"; c.flash_t = 2.5
	return _res(true, "%s: %s." % [info[0], info[1]])

func act_stance(stance: String) -> Dictionary:
	var c := pc()
	if c == null or not (stance in ["host", "hostage"]): return _res(false, "?")
	c.guest_stance = stance
	return _res(true, "Guests will be %s." % ("treated as guests" if stance == "host" else "held for ransom"))

# ---- the Wall-keeper's whims ------------------------------------------------------------
func _world_event() -> void:
	if r() > 0.3: return
	var live: Array = civs.filter(func(c): return c.alive)
	if live.is_empty(): return
	var c: Civ = pick(live)
	var title := ""
	var text := ""
	match rng.randi() % 5:
		0:
			c.stock.food += 60.0
			title = "Crumbs from above"; text = "A giant hand drops crumbs over %s: +60 food." % c.name
		1:
			var n: int = mini(2, maxi(0, c.citizens.size() - 4))
			for i in n: remove_citizen(pick(c.citizens), "shaken")
			c.flash = "battle"; c.flash_t = 3.0
			title = "The jar is shaken"; text = "Something shakes %s. %d citizen(s) are lost." % [c.name, n]
		2:
			c.stock.lore += 35.0
			title = "A beam of light"; text = "A sunbeam through the glass inspires %s: +35 lore." % c.name
		3:
			for o in live: o.stock.food *= 0.85
			title = "Cold snap"; text = "The room goes cold. Every jar loses 15% of its food."
		4:
			c.stock.gold += 50.0
			title = "Glittering debris"; text = "Something shiny falls into %s: +50 gold." % c.name
	log_event("%s - %s" % [title, text], "sys", [c.id])
	world_event.emit(title, text)
