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

func _orb_pos() -> Vector2:
	if not is_instance_valid(enemy):
		return from
	var to: Vector2 = enemy.position + Vector2(0, -26)
	if t < FLY:
		var k := t / FLY
		var p := from.lerp(to, k)
		p.y -= sin(k * PI) * 110.0
		return p
	return to

func _process(delta: float) -> void:
	t += delta
	if not hid and t >= FLY and is_instance_valid(enemy):
		hid = true
		enemy.visible = false
		Sfx.play(self, "click", -4.0)
	if not finished and t >= FLY + SHAKE + 0.25:
		finished = true
		if is_instance_valid(enemy):
			enemy.visible = true
		done.call(success)
	if t > FLY + SHAKE + 0.85:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var p := _orb_pos()
	var base := Color("ffd23a")
	if t < FLY:
		for i in 5:
			var tp := p - Vector2(0, 0) * 0.0 + Vector2(-8.0 * i, 3.0 * i).rotated(0.4)
			draw_circle(to_local(tp), 6.0 - i, Color(base.r, base.g, base.b, 0.5 - i * 0.09))
		_orb(p, 1.0, 0.0)
		return
	var u := t - FLY
	if u < SHAKE:
		var wob := sin(u * 22.0) * (0.35 * (1.0 - u / SHAKE) + 0.12) * (1.0 if int(u / 0.33) % 2 == 0 else 0.25)
		_orb(p, 1.0 + 0.08 * sin(u * 18.0), wob)
		for i in 3:
			if u > 0.33 * (i + 1) - 0.05 and u < 0.33 * (i + 1) + 0.15:
				draw_circle(to_local(p), 16.0 + 10.0 * (u - 0.33 * (i + 1) + 0.05) * 5.0, Color(1, 1, 1, 0.25))
		return
	var k := (u - SHAKE) / 0.85
	if success:
		draw_arc(to_local(p), 10.0 + 70.0 * k, 0, TAU, 40, Color(1, 0.85, 0.3, 0.9 * (1.0 - k)), 6.0 * (1.0 - k) + 1.0, true)
		for s in stars:
			_star(to_local(p) + s * k, 7.0 * (1.0 - k) + 2.0, Color(1, 0.95, 0.5, 1.0 - k))
	else:
		draw_arc(to_local(p), 10.0 + 40.0 * k, 0, TAU, 28, Color(1, 0.4, 0.4, 0.8 * (1.0 - k)), 4.0 * (1.0 - k) + 1.0, true)
		_orb(p, 1.0 + k, 0.0, 1.0 - k)

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
