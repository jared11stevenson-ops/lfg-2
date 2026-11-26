extends Node2D
# Tickindle: Ember/Forge striker. Manul + Hephaestus's automatons + pocket watch.
# Wind-up: attack speed ramps while hitting the same target. Every 10th shot is molten (2x).
# TODO next pass: molten shot should leave a burn patch on the lane.
const DrawUtil = preload("res://draw_util.gd")
const TypeChart = preload("res://type_chart.gd")
const ProjectileScript = preload("res://projectile.gd")
const MAX_WINDUP := 6

var def: Dictionary = {}
var cooldown := 0.0
var last_target_id := 0
var windup := 0
var shots := 0

func _process(delta: float) -> void:
	cooldown -= delta
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
			cooldown = 1.0 / (float(def.rate) * (1.0 + 0.15 * minf(windup, MAX_WINDUP)))
	queue_redraw()

func _pick():
	var best = null
	for e in get_tree().get_nodes_in_group("enemies"):
		if e.dead or e.is_queued_for_deletion():
			continue
		if position.distance_to(e.position) > float(def.range):
			continue
		if best == null or e.travelled > best.travelled:
			best = e
	return best

func _fire(t) -> void:
	shots += 1
	windup += 1
	var molten := shots % 10 == 0
	var p = ProjectileScript.new()
	p.target = t
	p.molten = molten
	p.dmg = float(def.dmg) * TypeChart.best(def.types, t.types) * (2.0 if molten else 1.0)
	p.position = position + Vector2(0, -10)
	get_parent().add_child(p)

func _draw() -> void:
	var ink := Color("231f2b")
	var fur := Color("5a5566")
	var wl := clampf(float(windup) / MAX_WINDUP, 0.0, 1.0)
	if get_local_mouse_position().length() < 32.0:
		draw_arc(Vector2.ZERO, float(def.range), 0, TAU, 64, Color(1, 1, 1, 0.5), 2.0, true)
	draw_set_transform(Vector2(0, 24), 0.0, Vector2(1.0, 0.4))
	draw_circle(Vector2.ZERO, 28, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	# small wide-set ears
	for s in [-1.0, 1.0]:
		DrawUtil.poly(self, PackedVector2Array([Vector2(18 * s, -16), Vector2(27 * s, -36), Vector2(7 * s, -24)]), fur, ink, 3.0)
	DrawUtil.disc(self, Vector2.ZERO, 26.0, fur, ink, 4.0)
	# flat manul face
	for s in [-1.0, 1.0]:
		draw_circle(Vector2(13 * s, -7), 5.5, Color("f6e7a8"))
		draw_circle(Vector2(13 * s, -7), 2.5, ink)
		draw_line(Vector2(7 * s, -15), Vector2(19 * s, -12), ink, 2.5)
	DrawUtil.poly(self, PackedVector2Array([Vector2(-3, -1), Vector2(3, -1), Vector2(0, 3)]), Color("e59a9a"), ink, 1.5)
	# pocket-watch chest, glowing hotter with wind-up
	var c := Vector2(0, 14)
	draw_circle(c, 13 + 6 * wl, Color(1.0, 0.5, 0.1, 0.25 + 0.3 * wl))
	DrawUtil.disc(self, c, 10.0, Color("e8c15a"), Color("7a5a12"), 3.0)
	var a := float(Time.get_ticks_msec()) / 1000.0 * TAU * (1.0 + wl)
	draw_line(c, c + Vector2.from_angle(a) * 7.5, Color("c43c00"), 2.0)
	draw_line(c, c + Vector2.from_angle(-1.0) * 5.0, ink, 2.0)
