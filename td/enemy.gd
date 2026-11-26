extends Node2D
# Shuckit: Umbra/Gale fodder. Bat-eared fox + Black Shuck + broken umbrella.
const DrawUtil = preload("res://draw_util.gd")
signal died(e)
signal leaked(e)

var path: PackedVector2Array
var seg := 0
var travelled := 0.0
var speed := 120.0
var hp := 18.0
var max_hp := 18.0
var types: Array = []
var reward := 5
var boost_t := 0.0
var slow_t := 0.0
var slow_f := 1.0
var poison := 0
var poison_t := 0.0
var heading := 0.0
var wobble := 0.0
var dead := false

func setup(p: PackedVector2Array, hp_: float, speed_: float, types_: Array, reward_: int) -> void:
	path = p
	hp = hp_
	max_hp = hp_
	speed = speed_
	types = types_
	reward = reward_

func _ready() -> void:
	add_to_group("enemies")
	position = path[0]
	wobble = randf() * TAU

func boost(t: float) -> void:
	boost_t = maxf(boost_t, t)

func apply_slow(f: float, t: float) -> void:
	slow_f = minf(slow_f if slow_t > 0.0 else 1.0, f)
	slow_t = maxf(slow_t, t)

func add_poison(n: int) -> void:
	poison = mini(poison + n, 5)
	poison_t = 4.0

func _process(delta: float) -> void:
	if dead:
		return
	boost_t = maxf(0.0, boost_t - delta)
	slow_t = maxf(0.0, slow_t - delta)
	poison_t = maxf(0.0, poison_t - delta)
	if poison_t <= 0.0:
		poison = 0
	if poison > 0:
		take_damage(2.5 * poison * delta)
		if dead:
			return
	if seg + 1 >= path.size():
		dead = true
		leaked.emit(self)
		queue_free()
		return
	var target := path[seg + 1]
	var step := speed * (1.3 if boost_t > 0.0 else 1.0) * (slow_f if slow_t > 0.0 else 1.0) * delta
	var d := position.distance_to(target)
	heading = (target - position).angle()
	if step >= d:
		position = target
		seg += 1
		travelled += d
	else:
		position += position.direction_to(target) * step
		travelled += step
	wobble += delta * 9.0
	queue_redraw()

func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	if hp <= 0.0:
		dead = true
		died.emit(self)
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var ink := Color("1d1b2a")
	var fur := Color("34314a")
	var rib := Color("6b6a86")
	var bob := Vector2(0, sin(wobble) * 2.0)
	if slow_t > 0.0:
		draw_circle(Vector2(0, 8), 24, Color(0.4, 0.8, 1.0, 0.3))
	if poison > 0:
		draw_circle(Vector2(0, 8), 18 + poison * 2, Color(0.6, 0.2, 0.8, 0.3))
	# shadow
	draw_set_transform(Vector2(0, 16), 0.0, Vector2(1.2, 0.4))
	draw_circle(Vector2.ZERO, 16, Color(0, 0, 0, 0.25))
	# gale streaks when boosted
	draw_set_transform(Vector2.ZERO, heading, Vector2.ONE)
	if boost_t > 0.0:
		for i in 3:
			var y := -8.0 + i * 8.0
			draw_line(Vector2(-22, y), Vector2(-40, y), Color(0.8, 0.9, 1.0, 0.6), 2.0)
	# tail wisp
	DrawUtil.poly(self, PackedVector2Array([Vector2(-14, -3) + bob, Vector2(-30, 0) + bob, Vector2(-14, 4) + bob]), fur, ink, 2.5)
	# ears: torn umbrella panels
	for s in [-1.0, 1.0]:
		var ear := PackedVector2Array([Vector2(2, 8 * s), Vector2(-6, 34 * s), Vector2(14, 14 * s)]) 
		for i in ear.size():
			ear[i] += bob
		DrawUtil.poly(self, ear, fur, ink, 3.0)
		draw_line(Vector2(2, 9 * s) + bob, Vector2(-6, 33 * s) + bob, rib, 2.0)
	# body + head
	DrawUtil.disc(self, Vector2(0, 0) + bob, 15.0, fur, ink, 3.5)
	DrawUtil.poly(self, PackedVector2Array([Vector2(12, -7), Vector2(26, 0), Vector2(12, 7)]) , fur, ink, 3.0)
	# glowing eyes
	for s in [-1.0, 1.0]:
		draw_circle(Vector2(9, 5 * s) + bob, 5.0, Color(1, 0.95, 0.6, 0.35))
		draw_circle(Vector2(9, 5 * s) + bob, 3.0, Color("fff3a0"))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hp < max_hp:
		var w := 34.0
		draw_rect(Rect2(-w / 2, -36, w, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2 + 1, -35, (w - 2) * clampf(hp / max_hp, 0.0, 1.0), 4), Color("7bdc6a"))
