extends Node2D
# Capture sequence: the Lure orb arcs to the enemy, seals it, shakes three times, then bursts open (caught) or cracks (broke free).
const OUT := Color("1d1230")
const Sfx = preload("res://sfx.gd")
var enemy
var success := true
var from := Vector2(640, 700)
var done: Callable
var t := 0.0
var finished := false
const FLY := 0.38
const SHAKE := 1.05
var stars: Array = []
var hid := false

func _ready() -> void:
	z_index = 20
	for i in 12:
		stars.append(Vector2.from_angle(randf() * TAU) * randf_range(40.0, 110.0))

func _orb(p: Vector2, s: float, rot: float, a: float = 1.0) -> void:
	# Lure charm: teal crystal with a golden loop
	draw_set_transform(to_local(p), rot, Vector2(s, s))
	draw_arc(Vector2(0, -22), 8.0, 0, TAU, 14, Color(OUT.r, OUT.g, OUT.b, a), 5.0, true)
	draw_arc(Vector2(0, -22), 8.0, 0, TAU, 14, Color(1.0, 0.82, 0.3, a), 2.5, true)
	draw_colored_polygon(PackedVector2Array([Vector2(0, -20), Vector2(21, 0), Vector2(0, 24), Vector2(-21, 0)]), Color(OUT.r, OUT.g, OUT.b, a))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -16), Vector2(16, 0), Vector2(0, 19), Vector2(-16, 0)]), Color(0.25, 0.85, 0.75, a))
	draw_colored_polygon(PackedVector2Array([Vector2(0, -16), Vector2(-16, 0), Vector2(0, 3)]), Color(0.66, 1.0, 0.94, a))
	draw_line(Vector2(-16, 0), Vector2(16, 0), Color(1, 1, 1, 0.55 * a), 2.0)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _star(c: Vector2, r: float, col: Color) -> void:
	var pts := PackedVector2Array()
	for i in 10:
		var a := PI * i / 5.0 - PI / 2.0
		pts.append(c + Vector2.from_angle(a) * (r if i % 2 == 0 else r * 0.45))
	draw_colored_polygon(pts, col)
