extends Node2D
# One script, three creatures keyed by def.id. Designs: docs/creatures_v1.md. Upgrade data lives in creatures.gd.
#  tickindle (Ember/Forge): single-target burst, wind-up ramps attack speed, molten shots (2x) can leave burn patches / splash.
#  dugloom   (Tide/Spirit): lantern pulse hits everything in range: slow, optional stun and drag-back.
#  hutzin    (Verdant/Venom): poison stacks, splash, vulnerability, stomps; spread on death handled in main.gd.
const DrawUtil = preload("res://draw_util.gd")
const TypeChart = preload("res://type_chart.gd")
const ProjectileScript = preload("res://projectile.gd")
const PatchScript = preload("res://patch.gd")
const FxScript = preload("res://fx.gd")
const BoltScript = preload("res://bolt.gd")
const Sfx = preload("res://sfx.gd")
const SpriteLib = preload("res://sprite_lib.gd")
const SPRITE_SCALE := 34.0
const MODES := ["first", "last", "strong"]
const DEFAULTS := {"multishot": 1, "splash": 0.0, "molten_every": 10, "burn_patch": false, "windup_max": 6, "pull": 0.0,
	"stun": 0.0, "poison_mul": 1.0, "vuln": false, "burst_every": 0, "spread_all": false, "max_stacks": 5, "stacks": 1,
	"slow": 1.0, "slow_t": 2.0, "chain_n": 0, "chain_range": 110.0, "hit_slow": 1.0, "hit_slow_t": 1.5,
	"hit_stun": 0.0, "crit_every": 0, "crit_mult": 3.0}

var def: Dictionary = {}:
	set(v):
		def = v
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
var face := 2
var face_vec := Vector2.DOWN
var kick := 0.0

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

func _sprite_id() -> String:
	var base: String = def.get("sprite", def.id)
	var cand := base
	if tiers.a >= 3 and tiers.a >= tiers.b:
		cand = base + "_a"
	elif tiers.b >= 3:
		cand = base + "_b"
	return cand if SpriteLib.tex(cand, face) != null else base

func cycle_target() -> void:
	target_mode = MODES[(MODES.find(target_mode) + 1) % MODES.size()]

func _process(delta: float) -> void:
	cooldown -= delta
	pulse_t = maxf(0.0, pulse_t - delta)
	kick = maxf(0.0, kick - delta * 6.0)
	var id: String = def.id
	if id == "dugloom":
		_dugloom_tick()
	else:
		var t = _pick()
		if t == null:
			windup = 0
			last_target_id = 0
		else:
			if t.get_instance_id() != last_target_id:
				windup = 0
				last_target_id = t.get_instance_id()
			if cooldown <= 0.0:
				_fire(t)
				var ramp := 1.0 + 0.15 * minf(windup, int(st.windup_max)) if id == "tickindle" else 1.0
				cooldown = 1.0 / (float(st.rate) * ramp)
	queue_redraw()

func _in_range() -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead and not e.is_queued_for_deletion() and position.distance_to(e.position) <= float(st.range):
			out.append(e)
	return out

func _pick():
	var best = null
	for e in _in_range():
		if best == null:
			best = e
		elif target_mode == "first" and e.travelled > best.travelled:
			best = e
		elif target_mode == "last" and e.travelled < best.travelled:
			best = e
		elif target_mode == "strong" and e.hp > best.hp:
			best = e
	return best

func _dugloom_tick() -> void:
	if cooldown > 0.0:
		return
	var hit := _in_range()
	if hit.is_empty():
		return
	cooldown = 1.0 / float(st.rate)
	pulse_t = 0.45
	kick = 1.0
	Sfx.play(self, "pulse", -10.0, 120)
	for e in hit:
		var m := TypeChart.best(def.types, e.types)
		FxScript.pop(get_parent(), e, m)
		e.apply_slow(float(st.slow), float(st.slow_t))
		if float(st.stun) > 0.0:
			e.stun(float(st.stun))
		if float(st.pull) > 0.0:
			e.rewind(float(st.pull))
		e.take_damage(float(st.dmg) * m * _weather())

func _fire(t) -> void:
	shots += 1
	windup += 1
	Sfx.play(self, "shoot", -16.0, 45)
	face = SpriteLib.dir_from_angle((t.position - position).angle())
	face_vec = (t.position - position).normalized()
	kick = 1.0
	var molten: bool = def.id == "tickindle" and shots % int(st.molten_every) == 0
	var crit: bool = int(st.crit_every) > 0 and shots % int(st.crit_every) == 0
	for i in int(st.multishot):
		var p = ProjectileScript.new()
		p.target = t
		p.tower = self
		p.molten = molten or crit
		p.mult = TypeChart.best(def.types, t.types)
		p.dmg = float(st.dmg) * p.mult * _weather() * (2.0 if molten else (float(st.crit_mult) if crit else 1.0))
		if def.id == "hutzin":
			p.color = Color("b44bd8")
		p.position = position + Vector2(0, -10) + Vector2(0, i * 6)
		get_parent().add_child(p)

# Called by the projectile on arrival.
func resolve_hit(p, t) -> void:
	FxScript.pop(get_parent(), t, p.mult)
	if def.id == "hutzin":
		t.add_poison(int(st.stacks), float(st.poison_mul), int(st.max_stacks), bool(st.spread_all))
		if bool(st.vuln):
			t.vuln_t = 4.0
	t.take_damage(p.dmg)
	if def.id == "tickindle" and p.molten and bool(st.burn_patch):
		var patch = PatchScript.new()
		patch.position = t.position
		get_parent().add_child(patch)
	if float(st.hit_slow) < 1.0:
		t.apply_slow(float(st.hit_slow), float(st.hit_slow_t))
	if float(st.hit_stun) > 0.0:
		t.stun(float(st.hit_stun))
	if int(st.chain_n) > 0:
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
	var splash := float(st.splash)
	if splash > 0.0 and (def.id == "hutzin" or def.id == "ally_glomm" or p.molten):
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

func _draw() -> void:
	if selected:
		draw_circle(Vector2.ZERO, float(st.range), Color(1, 1, 1, 0.07))
		draw_arc(Vector2.ZERO, float(st.range), 0, TAU, 64, Color(1, 1, 1, 0.85), 3.0, true)
	elif get_local_mouse_position().length() < 32.0:
		draw_arc(Vector2.ZERO, float(st.range), 0, TAU, 64, Color(1, 1, 1, 0.5), 2.0, true)
	draw_set_transform(Vector2(0, 24), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 28, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var total: int = tiers.a + tiers.b
	if total >= 3:
		var ac := Color(1.0, 0.7, 0.25) if tiers.a >= tiers.b else Color(0.4, 0.85, 1.0)
		var pulse := 0.5 + 0.5 * sin(float(Time.get_ticks_msec()) / 350.0)
		draw_set_transform(Vector2(0, 24), 0.0, Vector2(1.0, 0.4))
		draw_arc(Vector2.ZERO, 34 + pulse * 4, 0, TAU, 40, Color(ac.r, ac.g, ac.b, 0.6), 4.0 + (3.0 if total >= 6 else 0.0), true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if SpriteLib.draw(self, _sprite_id(), face, SPRITE_SCALE * (1.0 + 0.07 * kick + 0.03 * (tiers.a + tiers.b)), Vector2(0, 14.0 * sin(float(Time.get_ticks_msec()) / 400.0 + position.x) * 0.2 + 6) - face_vec * 5.0 * kick):
		pass
	else:
		match String(def.id):
			"tickindle": _draw_tickindle()
			"dugloom": _draw_dugloom()
			"hutzin": _draw_hutzin()
	for i in tiers.a:
		draw_circle(Vector2(-14 + i * 8, 34), 3.0, Color("ffb347"))
	for i in tiers.b:
		draw_circle(Vector2(6 + i * 8, 34), 3.0, Color("6fd3ff"))

static func draw_icon(ci: CanvasItem, id: String, def_: Dictionary) -> void:
	if SpriteLib.draw(ci, def_.get("sprite", id), 2, SPRITE_SCALE):
		return
	# Used by the UI cards: draws the creature into any CanvasItem at its origin.
	var t = load("res://tower.gd").new()
	t.def = def_
	match id:
		"tickindle": t._draw_tickindle_on(ci)
		"dugloom": t._draw_dugloom_on(ci)
		"hutzin": t._draw_hutzin_on(ci)
	t.free()

func _draw_tickindle() -> void:
	_draw_tickindle_on(self)

func _draw_dugloom() -> void:
	_draw_dugloom_on(self)

func _draw_hutzin() -> void:
	_draw_hutzin_on(self)

func _draw_tickindle_on(ci: CanvasItem) -> void:
	var ink := Color("231f2b")
	var fur := Color("5a5566")
	var wl := clampf(float(windup) / float(st.windup_max), 0.0, 1.0)
	for s in [-1.0, 1.0]:
		DrawUtil.poly(ci, PackedVector2Array([Vector2(18 * s, -16), Vector2(27 * s, -36), Vector2(7 * s, -24)]), fur, ink, 3.0)
	DrawUtil.disc(ci, Vector2.ZERO, 26.0, fur, ink, 4.0)
	for s in [-1.0, 1.0]:
		ci.draw_circle(Vector2(13 * s, -7), 5.5, Color("f6e7a8"))
		ci.draw_circle(Vector2(13 * s, -7), 2.5, ink)
		ci.draw_line(Vector2(7 * s, -15), Vector2(19 * s, -12), ink, 2.5)
	DrawUtil.poly(ci, PackedVector2Array([Vector2(-3, -1), Vector2(3, -1), Vector2(0, 3)]), Color("e59a9a"), ink, 1.5)
	var c := Vector2(0, 14)
	ci.draw_circle(c, 13 + 6 * wl, Color(1.0, 0.5, 0.1, 0.25 + 0.3 * wl))
	DrawUtil.disc(ci, c, 10.0, Color("e8c15a"), Color("7a5a12"), 3.0)
	var a := float(Time.get_ticks_msec()) / 1000.0 * TAU * (1.0 + wl)
	ci.draw_line(c, c + Vector2.from_angle(a) * 7.5, Color("c43c00"), 2.0)
	ci.draw_line(c, c + Vector2.from_angle(-1.0) * 5.0, ink, 2.0)

func _draw_dugloom_on(ci: CanvasItem) -> void:
	var ink := Color("0f2a33")
	var hide := Color("5f9fb0")
	if pulse_t > 0.0:
		var k := 1.0 - pulse_t / 0.45
		ci.draw_arc(Vector2.ZERO, float(st.range) * k, 0, TAU, 64, Color(1.0, 0.95, 0.5, 0.6 * (1.0 - k)), 5.0, true)
	# tail fluke
	DrawUtil.poly(ci, PackedVector2Array([Vector2(-18, 12), Vector2(-40, 2), Vector2(-34, 16), Vector2(-40, 30)]), hide, ink, 3.0)
	# flippers
	for s in [-1.0, 1.0]:
		DrawUtil.poly(ci, PackedVector2Array([Vector2(8 * s, 12), Vector2(26 * s, 24), Vector2(12 * s, 26)]), hide, ink, 3.0)
	DrawUtil.disc(ci, Vector2(0, 4), 25.0, hide, ink, 4.0)
	# whiskered snout
	DrawUtil.disc(ci, Vector2(0, 10), 12.0, Color("d9ecef"), ink, 3.0)
	for s in [-1.0, 1.0]:
		ci.draw_circle(Vector2(5 * s, 8), 1.8, ink)
		ci.draw_circle(Vector2(13 * s, -4), 3.2, Color("0b1d22"))
		ci.draw_circle(Vector2(14 * s, -5), 1.1, Color.WHITE)
	# lantern on head, pulses
	var glow := 0.5 + 0.2 * sin(float(Time.get_ticks_msec()) / 300.0) + (0.4 if pulse_t > 0.0 else 0.0)
	ci.draw_circle(Vector2(0, -28), 16, Color(1.0, 0.9, 0.4, 0.25 * glow))
	DrawUtil.poly(ci, PackedVector2Array([Vector2(-7, -22), Vector2(7, -22), Vector2(5, -36), Vector2(-5, -36)]), Color(1.0, 0.92, 0.5), ink, 2.5)
	ci.draw_line(Vector2(0, -36), Vector2(0, -41), ink, 2.5)

func _draw_hutzin_on(ci: CanvasItem) -> void:
	var ink := Color("1d2a14")
	var feather := Color("7a9a3a")
	# crest
	for i in 3:
		var x := -8.0 + i * 8.0
		DrawUtil.poly(ci, PackedVector2Array([Vector2(x - 4, -18), Vector2(x, -38 + abs(i - 1) * 6), Vector2(x + 4, -18)]), Color("e0632b"), ink, 2.5)
	DrawUtil.disc(ci, Vector2.ZERO, 24.0, feather, ink, 4.0)
	# beak + eyes
	DrawUtil.poly(ci, PackedVector2Array([Vector2(-6, -2), Vector2(6, -2), Vector2(0, 9)]), Color("f2b84b"), ink, 2.5)
	for s in [-1.0, 1.0]:
		ci.draw_circle(Vector2(11 * s, -9), 5.0, Color("5ac8d6"))
		ci.draw_circle(Vector2(11 * s, -9), 2.2, ink)
	# teapot-cottage on its back: roof, door, spout steam
	var steam := float(Time.get_ticks_msec()) / 500.0
	DrawUtil.poly(ci, PackedVector2Array([Vector2(-14, 4), Vector2(14, 4), Vector2(14, 22), Vector2(-14, 22)]), Color("9a6b3c"), ink, 3.0)
	DrawUtil.poly(ci, PackedVector2Array([Vector2(-18, 5), Vector2(0, -8), Vector2(18, 5)]), Color("c14a4a"), ink, 3.0)
	ci.draw_rect(Rect2(-4, 12, 8, 10), Color("3b2412"))
	for i in 3:
		var ph := fmod(steam + i * 0.7, 2.0) / 2.0
		ci.draw_circle(Vector2(16 + sin(steam + i) * 3.0, 6 - ph * 22), 3.0 + ph * 3.0, Color(0.75, 0.4, 0.9, 0.5 * (1.0 - ph)))
	# chicken legs
	for s in [-1.0, 1.0]:
		ci.draw_line(Vector2(8 * s, 24), Vector2(10 * s, 32), Color("e0a23b"), 3.0)
