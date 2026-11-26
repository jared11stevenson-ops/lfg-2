extends Node2D
# One script, three behaviours keyed by def.id. Designs: docs/creatures_v1.md
#  tickindle (Ember/Forge): single-target burst, wind-up ramps attack speed, every 10th shot molten (2x).
#  dugloom   (Tide/Spirit): lantern pulse hits everything in range, slows it.
#  hutzin    (Verdant/Venom): poison stacks; stacks spread when a poisoned foe dies (see main.gd).
# TODO: molten burn patch, Spirit stealth reveal, evolutions.
const DrawUtil = preload("res://draw_util.gd")
const TypeChart = preload("res://type_chart.gd")
const ProjectileScript = preload("res://projectile.gd")
const MAX_WINDUP := 6

var def: Dictionary = {}
var cooldown := 0.0
var last_target_id := 0
var windup := 0
var shots := 0
var pulse_t := 0.0

func _process(delta: float) -> void:
	cooldown -= delta
	pulse_t = maxf(0.0, pulse_t - delta)
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
				var ramp := 1.0 + 0.15 * minf(windup, MAX_WINDUP) if id == "tickindle" else 1.0
				cooldown = 1.0 / (float(def.rate) * ramp)
	queue_redraw()

func _in_range() -> Array:
	var out := []
	for e in get_tree().get_nodes_in_group("enemies"):
		if not e.dead and not e.is_queued_for_deletion() and position.distance_to(e.position) <= float(def.range):
			out.append(e)
	return out

func _pick():
	var best = null
	for e in _in_range():
		if best == null or e.travelled > best.travelled:
			best = e
	return best

func _dugloom_tick() -> void:
	if cooldown > 0.0:
		return
	var hit := _in_range()
	if hit.is_empty():
		return
	cooldown = 1.0 / float(def.rate)
	pulse_t = 0.45
	for e in hit:
		e.apply_slow(float(def.slow), float(def.slow_t))
		e.take_damage(float(def.dmg) * TypeChart.best(def.types, e.types))

func _fire(t) -> void:
	shots += 1
	windup += 1
	var p = ProjectileScript.new()
	p.target = t
	p.dmg = float(def.dmg) * TypeChart.best(def.types, t.types)
	if def.id == "tickindle":
		p.molten = shots % 10 == 0
		if p.molten:
			p.dmg *= 2.0
	elif def.id == "hutzin":
		p.color = Color("b44bd8")
		p.effect = "poison"
		p.effect_n = int(def.stacks)
	p.position = position + Vector2(0, -10)
	get_parent().add_child(p)

func _draw() -> void:
	if get_local_mouse_position().length() < 32.0:
		draw_arc(Vector2.ZERO, float(def.range), 0, TAU, 64, Color(1, 1, 1, 0.5), 2.0, true)
	draw_set_transform(Vector2(0, 24), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 28, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match String(def.id):
		"tickindle": _draw_tickindle()
		"dugloom": _draw_dugloom()
		"hutzin": _draw_hutzin()

static func draw_icon(ci: CanvasItem, id: String, def_: Dictionary) -> void:
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
	var wl := clampf(float(windup) / MAX_WINDUP, 0.0, 1.0)
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
		ci.draw_arc(Vector2.ZERO, float(def.range) * k, 0, TAU, 64, Color(1.0, 0.95, 0.5, 0.6 * (1.0 - k)), 5.0, true)
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
