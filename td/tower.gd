extends Node2D
# One script drives every defender. Behaviour is data: see creatures.gd (generated) for stats and upgrade trees.
# Modes: single/multi-target projectiles, ring pulses (pulse/nova), clouds, chains, auras (support), income.
const PuppetLib = preload("res://puppet_lib.gd")
const TypeChart = preload("res://type_chart.gd")
const ProjectileScript = preload("res://projectile.gd")
const PatchScript = preload("res://patch.gd")
const FxScript = preload("res://fx.gd")
const BoltScript = preload("res://bolt.gd")
const PoofScript = preload("res://poof.gd")
const Sfx = preload("res://sfx.gd")
const BASE_SCALE := 0.7
const MODES := ["first", "last", "strong"]
const DEFAULTS := {"multishot": 1, "multitarget": 1, "splash": 0.0, "splash_always": false, "molten_every": 10, "burn_patch": false, "patch_t": 4.0,
	"windup_max": 6, "pull": 0.0, "stun": 0.0, "poison_mul": 1.0, "vuln": false, "burst_every": 0, "spread_all": false, "max_stacks": 5, "stacks": 1,
	"slow": 1.0, "slow_t": 2.0, "chain_n": 0, "chain_range": 110.0, "hit_slow": 1.0, "hit_slow_t": 1.5, "hit_stun": 0.0, "crit_every": 0, "crit_mult": 3.0,
	"bounty": 0, "aura_range": 0.0, "aura_rate": 0.0, "aura_r": 150.0, "income": 0, "cloud": false, "cloud_slow": 0.8, "cloud_dps": 3.0, "cloud_r": 48.0,
	"cloud_t": 4.0, "wet": false, "wet_t": 4.0, "wet_mult": 1.4, "chill": 0, "curse": false, "curse_t": 5.0, "curse_mul": 1.25, "curse_echo": 0.0,
	"curse_spread": 0, "nova": false, "pulse": false, "stomp_burn": false}

var def: Dictionary = {}:
	set(v):
		def = v
		if def.has("mode"):
			target_mode = def.mode
		_rebuild()
var st: Dictionary = {}
var tiers := {"a": 0, "b": 0}
var spent := 0
var selected := false
var target_mode := "first"
var cooldown := 0.0
var last_target_id := 0
var windup := 0
var shots := 0
var pulse_t := 0.0
var atk_t := 0.0
var flip := false
var chilled_t := 0.0
var buff_rate := 1.0
var buff_range := 1.0
var buff_t := 0.0

func _ready() -> void:
	add_to_group("towers")

func _rebuild() -> void:
	st = def.duplicate(true)
	for k in DEFAULTS:
		if not st.has(k):
			st[k] = DEFAULTS[k]
	if def.has("upgrades"):
		for p in ["a", "b"]:
			for i in tiers[p]:
				_apply(def.upgrades[p][i])

func _apply(u: Dictionary) -> void:
	for k in u.get("add", {}):
		st[k] = st.get(k, 0) + u.add[k]
	for k in u.get("mul", {}):
		st[k] = st.get(k, 1.0) * u.mul[k]
	for k in u.get("set", {}):
		st[k] = u.set[k]

func next_upgrade(p: String) -> Dictionary:
	if not def.has("upgrades") or tiers[p] >= 4:
		return {}
	return def.upgrades[p][tiers[p]]

func blocked(p: String) -> bool:
	var other := "b" if p == "a" else "a"
	return tiers[p] + 1 >= 3 and tiers[other] >= 3

func buy(p: String) -> int:
	var u := next_upgrade(p)
	if u.is_empty() or blocked(p):
		return -1
	tiers[p] += 1
	spent += int(u.cost)
	_rebuild()
	return int(u.cost)

func _weather() -> float:
	var m = get_parent()
	return m.weather_mult(def.types) if m != null and m.has_method("weather_mult") else 1.0

func _stone_mult() -> float:
	var m = get_parent()
	return m.stone_mult(self) if m != null and m.has_method("stone_mult") else 1.0

func _mut(key: String, default: float = 1.0) -> float:
	var m = get_parent()
	return m.eff(key) if m != null and m.has_method("eff") else default

func rng() -> float:
	return float(st.range) * buff_range * (1.0 + (_stone_mult() - 1.0) * 0.5) * _mut("range")

func cycle_target() -> void:
	target_mode = MODES[(MODES.find(target_mode) + 1) % MODES.size()]

func is_support() -> bool:
	return float(st.dmg) <= 0.0

func _process(delta: float) -> void:
	chilled_t = maxf(0.0, chilled_t - delta)
	cooldown -= delta * (0.75 if chilled_t > 0.0 else 1.0) * buff_rate
	pulse_t = maxf(0.0, pulse_t - delta)
	atk_t = maxf(0.0, atk_t - delta)
	buff_t -= delta
	if buff_t <= 0.0:
		buff_t = 0.3
		_refresh_buffs()
	if is_support():
		queue_redraw()
		return
	if bool(st.pulse) or bool(st.nova):
		_pulse_tick()
	else:
		var t = _pick()
		if t == null:
			windup = 0
			last_target_id = 0
		else:
			flip = t.position.x < position.x
			if t.get_instance_id() != last_target_id:
				windup = 0
				last_target_id = t.get_instance_id()
			if cooldown <= 0.0:
				_fire(t)
				var ramp := 1.0 + 0.15 * minf(windup, int(st.windup_max)) if def.id == "tickindle" else 1.0
				cooldown = 1.0 / (float(st.rate) * ramp)
	queue_redraw()

func _refresh_buffs() -> void:
	buff_rate = 1.0
	buff_range = 1.0
	for t in get_tree().get_nodes_in_group("towers"):
		if t == self:
			continue
		if (float(t.st.aura_rate) > 0.0 or float(t.st.aura_range) > 0.0) and position.distance_to(t.position) <= float(t.st.aura_r):
			buff_rate += float(t.st.aura_rate)
			buff_range += float(t.st.aura_range)
	buff_rate *= _mut("rate")

func _in_range() -> Array:
	var out := []
	var r := rng()
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead and not e.is_queued_for_deletion() and position.distance_to(e.position) <= r:
			out.append(e)
	return out

func _better(a, b) -> bool:
	match target_mode:
		"last": return a.travelled < b.travelled
		"strong": return a.hp > b.hp
	return a.travelled > b.travelled

func _pick():
	var best = null
	for e in _in_range():
		if best == null or _better(e, best):
			best = e
	return best

func _pick_many(n: int) -> Array:
	var cand := _in_range()
	cand.sort_custom(func(a, b): return _better(a, b))
	return cand.slice(0, n)

func _pulse_tick() -> void:
	if cooldown > 0.0:
		return
	var hit := _in_range()
	if hit.is_empty():
		return
	cooldown = 1.0 / float(st.rate)
	pulse_t = 0.45
	atk_t = 0.4
	Sfx.play(self, "pulse", -10.0, 120)
	var wx := _weather() * _stone_mult()
	for e in hit:
		var m := TypeChart.best(def.types, e.types)
		FxScript.pop(get_parent(), e, m)
		if bool(st.pulse):
			e.apply_slow(float(st.slow), float(st.slow_t))
			if float(st.stun) > 0.0:
				e.stun(float(st.stun))
		if float(st.hit_stun) > 0.0:
			e.stun(float(st.hit_stun))
		if bool(st.wet):
			e.wet_t = float(st.wet_t)
		if float(st.pull) > 0.0:
			e.rewind(float(st.pull))
		var d := float(st.dmg) * m * wx * _mut("dmg")
		if e.wet_t > 0.0 and "volt" in def.types:
			d *= float(st.wet_mult)
		e.take_damage(d)
	if bool(st.stomp_burn):
		var patch = PatchScript.new()
		patch.position = position
		patch.radius = rng() * 0.8
		patch.life = 3.0
		get_parent().add_child(patch)

func _fire(t) -> void:
	shots += 1
	windup += 1
	atk_t = 0.35
	Sfx.play(self, "shoot", -16.0, 45)
	var molten: bool = def.id == "tickindle" and shots % int(st.molten_every) == 0
	var crit: bool = int(st.crit_every) > 0 and shots % int(st.crit_every) == 0
	var targets: Array = _pick_many(int(st.multitarget)) if int(st.multitarget) > 1 else [t]
	for tg in targets:
		for i in int(st.multishot):
			var p = ProjectileScript.new()
			p.target = tg
			p.tower = self
			p.molten = molten or crit
			p.mult = TypeChart.best(def.types, tg.types)
			p.dmg = float(st.dmg) * p.mult * _weather() * _stone_mult() * _mut("dmg") * (2.0 if molten else (float(st.crit_mult) if crit else 1.0))
			if tg.wet_t > 0.0 and "volt" in def.types:
				p.dmg *= float(st.wet_mult)
			p.color = TypeChart.COLORS[def.types[0]]
			p.ptype = def.types[0]
			p.position = position + Vector2(0, -26) + Vector2(0, i * 6)
			get_parent().add_child(p)

# Called by the projectile on arrival.
func resolve_hit(p, t) -> void:
	var sp = PoofScript.new()
	sp.col = TypeChart.COLORS[def.types[0]]
	sp.position = t.position
	sp.scale = Vector2(0.45, 0.45)
	get_parent().add_child(sp)
	FxScript.pop(get_parent(), t, p.mult)
	if def.id == "hutzin":
		t.add_poison(int(st.stacks), float(st.poison_mul), int(st.max_stacks), bool(st.spread_all))
		if bool(st.vuln):
			t.vuln_t = 4.0
	if bool(st.wet):
		t.wet_t = float(st.wet_t)
	if int(st.chill) > 0:
		t.add_chill(int(st.chill))
	if int(st.bounty) > 0 and get_parent().has_method("add_coins"):
		get_parent().add_coins(int(st.bounty), t.position)
	if bool(st.curse):
		_curse(t, p)
	t.take_damage(p.dmg)
	if bool(st.burn_patch) and (p.molten or def.id != "tickindle"):
		_spawn_patch(t.position, "burn")
	if bool(st.cloud):
		_spawn_patch(t.position, "cloud")
	if float(st.hit_slow) < 1.0:
		t.apply_slow(float(st.hit_slow), float(st.hit_slow_t))
	if float(st.hit_stun) > 0.0:
		t.stun(float(st.hit_stun))
	if int(st.chain_n) > 0:
		_chain(t, p)
	var splash := float(st.splash)
	if splash > 0.0 and (bool(st.splash_always) or p.molten):
		for o in get_tree().get_nodes_in_group("enemies"):
			if o != t and not o.dead and o.position.distance_to(t.position) <= splash:
				if def.id == "hutzin":
					o.add_poison(1, float(st.poison_mul), int(st.max_stacks), bool(st.spread_all))
				o.take_damage(p.dmg * 0.6)
	if def.id == "hutzin" and int(st.burst_every) > 0 and shots % int(st.burst_every) == 0:
		for o in get_tree().get_nodes_in_group("enemies"):
			if not o.dead and o.position.distance_to(t.position) <= 110.0:
				o.add_poison(3, float(st.poison_mul), int(st.max_stacks), bool(st.spread_all))
				o.take_damage(12.0)

func _spawn_patch(pos: Vector2, kind: String) -> void:
	var patch = PatchScript.new()
	patch.position = pos
	patch.kind = kind
	if kind == "cloud":
		patch.radius = float(st.cloud_r)
		patch.life = float(st.cloud_t)
		patch.dps = float(st.cloud_dps)
		patch.slow = float(st.cloud_slow)
	else:
		patch.life = float(st.patch_t)
	get_parent().add_child(patch)

func _chain(t, p) -> void:
	var cur = t
	var hit_list := [t]
	for i in int(st.chain_n):
		var nxt = null
		for o in get_tree().get_nodes_in_group("enemies"):
			if o.dead or o in hit_list or o.position.distance_to(cur.position) > float(st.chain_range):
				continue
			if nxt == null or o.position.distance_to(cur.position) < nxt.position.distance_to(cur.position):
				nxt = o
		if nxt == null:
			break
		var bolt = BoltScript.new()
		bolt.a = cur.position
		bolt.b = nxt.position
		get_parent().add_child(bolt)
		nxt.take_damage(p.dmg * pow(0.75, i + 1))
		if float(st.hit_stun) > 0.0:
			nxt.stun(float(st.hit_stun))
		hit_list.append(nxt)
		cur = nxt

func _curse(t, p) -> void:
	t.vuln_t = float(st.curse_t)
	t.vuln_f = float(st.curse_mul)
	if float(st.curse_echo) > 0.0:
		for o in get_tree().get_nodes_in_group("enemies"):
			if o != t and not o.dead and o.vuln_t > 0.0 and o.position.distance_to(t.position) < 140.0:
				o.take_damage(p.dmg * float(st.curse_echo))
	var n := int(st.curse_spread)
	if n > 0:
		for o in get_tree().get_nodes_in_group("enemies"):
			if n <= 0:
				break
			if o != t and not o.dead and o.vuln_t <= 0.0 and o.position.distance_to(t.position) < 120.0:
				o.vuln_t = float(st.curse_t)
				o.vuln_f = float(st.curse_mul)
				n -= 1

func _sprite_id() -> String:
	var base: String = def.get("sprite", def.id)
	var cand := base
	if tiers.a >= 3 and tiers.a >= tiers.b:
		cand = base + "_a"
	elif tiers.b >= 3:
		cand = base + "_b"
	return cand if PuppetLib.tex(cand, "idle", 0) != null else base

static func draw_icon(ci: CanvasItem, id: String, def_: Dictionary) -> void:
	PuppetLib.draw(ci, def_.get("sprite", id), "idle", int(Time.get_ticks_msec() / 160.0), false, BASE_SCALE)

func _draw() -> void:
	var r := rng()
	if selected:
		draw_circle(Vector2.ZERO, r, Color(1, 1, 1, 0.07))
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(1, 1, 1, 0.85), 3.0, true)
	elif get_local_mouse_position().length() < 36.0:
		draw_arc(Vector2.ZERO, r, 0, TAU, 64, Color(1, 1, 1, 0.5), 2.0, true)
	if float(st.aura_r) > 0.0 and (float(st.aura_rate) > 0.0 or float(st.aura_range) > 0.0):
		draw_arc(Vector2.ZERO, float(st.aura_r), 0, TAU, 48, Color(1.0, 0.9, 0.4, 0.25), 2.0, true)
	if pulse_t > 0.0:
		var k := 1.0 - pulse_t / 0.45
		draw_arc(Vector2.ZERO, r * k, 0, TAU, 64, Color(1.0, 0.95, 0.5, 0.6 * (1.0 - k)), 5.0, true)
	var total: int = tiers.a + tiers.b
	if total >= 3:
		var ac := Color(1.0, 0.7, 0.25) if tiers.a >= tiers.b else Color(0.4, 0.85, 1.0)
		var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 350.0)
		draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.0, 0.4))
		draw_arc(Vector2.ZERO, 36 + pulse * 4, 0, TAU, 40, Color(ac.r, ac.g, ac.b, 0.6), 4.0 + (3.0 if total >= 6 else 0.0), true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	draw_set_transform(Vector2(0, 8), 0.0, Vector2(1.2, 0.4))
	draw_circle(Vector2.ZERO, 24, Color(0, 0, 0, 0.3))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var state := "attack" if atk_t > 0.0 else "idle"
	var frame := int((1.0 - atk_t / 0.4) * 5.0) if atk_t > 0.0 else int(Time.get_ticks_msec() / 170.0 + position.x)
	var sc := BASE_SCALE * (1.0 + 0.04 * total)
	if not PuppetLib.draw(self, _sprite_id(), state, frame, flip, sc, Vector2(0, 8), Color.WHITE if chilled_t <= 0.0 else Color(0.7, 0.85, 1.0)):
		draw_circle(Vector2(0, -20), 20, TypeChart.COLORS[def.types[0]])
	_draw_emote()
	for i in tiers.a:
		draw_circle(Vector2(-14 + i * 8, 20), 3.0, Color("ffb347"))
	for i in tiers.b:
		draw_circle(Vector2(6 + i * 8, 20), 3.0, Color("6fd3ff"))

# Idle personality: now and then a defender pipes up with a little emote above its head.
const EMOTES := ["♪", "!", "?", "...", "♥", "zZ"]
func _draw_emote() -> void:
	var ph := fmod(float(Time.get_ticks_msec()) / 1000.0 * 0.11 + position.x * 0.0173 + position.y * 0.0091, 1.0)
	if ph < 0.1 and atk_t <= 0.0:
		var idx := int(position.x * 7.0 + position.y * 3.0 + floor(float(Time.get_ticks_msec()) / 9000.0)) % EMOTES.size()
		var k := ph / 0.1
		var f := ThemeDB.fallback_font
		var pos := Vector2(-6, -86 * BASE_SCALE / 0.62 - 10 - k * 10)
		draw_string_outline(f, pos, EMOTES[idx], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 6, Color("1d1230"))
		draw_string(f, pos, EMOTES[idx], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1, 1.0 - k * 0.6))
