extends Node2D
# Enemy roster (see creatures.gd): shuckit (fodder), zapnose (fast), glomm (tank). All code-drawn placeholders.
const DrawUtil = preload("res://draw_util.gd")
signal died(e)
signal leaked(e)

var path: PackedVector2Array
var kind := "shuckit"
var seg := 0
var travelled := 0.0
var speed := 120.0
var hp := 18.0
var max_hp := 18.0
var types: Array = []
var reward := 5
var leak := 1
var boost_t := 0.0
var slow_t := 0.0
var slow_f := 1.0
var poison := 0
var poison_t := 0.0
var heading := 0.0
var wobble := 0.0
var dead := false

func setup(p: PackedVector2Array, d: Dictionary, wave: int) -> void:
	path = p
	kind = d.id
	hp = float(d.hp) + float(d.hp_wave) * wave
	max_hp = hp
	speed = float(d.speed)
	types = d.types
	reward = int(d.reward)
	leak = int(d.leak)

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
	wobble += delta * (9.0 if kind != "glomm" else 5.0)
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
	var big := kind == "glomm"
	if slow_t > 0.0:
		draw_circle(Vector2(0, 8), 30 if big else 24, Color(0.4, 0.8, 1.0, 0.3))
	if poison > 0:
		draw_circle(Vector2(0, 8), (26 if big else 18) + poison * 2, Color(0.6, 0.2, 0.8, 0.3))
	draw_set_transform(Vector2(0, 18 if big else 16), 0.0, Vector2(1.4 if big else 1.2, 0.4))
	draw_circle(Vector2.ZERO, 22 if big else 16, Color(0, 0, 0, 0.25))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	match kind:
		"zapnose": _draw_zapnose()
		"glomm": _draw_glomm()
		_: _draw_shuckit()
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	if hp < max_hp:
		var w := 48.0 if big else 34.0
		var y := -52.0 if big else -36.0
		draw_rect(Rect2(-w / 2, y, w, 6), Color(0, 0, 0, 0.6))
		draw_rect(Rect2(-w / 2 + 1, y + 1, (w - 2) * clampf(hp / max_hp, 0.0, 1.0), 4), Color("7bdc6a"))

# Shuckit: Umbra/Gale. Bat-eared fox + Black Shuck + broken umbrella.
func _draw_shuckit() -> void:
	var ink := Color("1d1b2a")
	var fur := Color("34314a")
	var rib := Color("6b6a86")
	var bob := Vector2(0, sin(wobble) * 2.0)
	draw_set_transform(Vector2.ZERO, heading, Vector2.ONE)
	if boost_t > 0.0:
		for i in 3:
			var y := -8.0 + i * 8.0
			draw_line(Vector2(-22, y), Vector2(-40, y), Color(0.8, 0.9, 1.0, 0.6), 2.0)
	DrawUtil.poly(self, PackedVector2Array([Vector2(-14, -3) + bob, Vector2(-30, 0) + bob, Vector2(-14, 4) + bob]), fur, ink, 2.5)
	for s in [-1.0, 1.0]:
		var ear := PackedVector2Array([Vector2(2, 8 * s), Vector2(-6, 34 * s), Vector2(14, 14 * s)])
		for i in ear.size():
			ear[i] += bob
		DrawUtil.poly(self, ear, fur, ink, 3.0)
		draw_line(Vector2(2, 9 * s) + bob, Vector2(-6, 33 * s) + bob, rib, 2.0)
	DrawUtil.disc(self, bob, 15.0, fur, ink, 3.5)
	DrawUtil.poly(self, PackedVector2Array([Vector2(12, -7), Vector2(26, 0), Vector2(12, 7)]), fur, ink, 3.0)
	for s in [-1.0, 1.0]:
		draw_circle(Vector2(9, 5 * s) + bob, 5.0, Color(1, 0.95, 0.6, 0.35))
		draw_circle(Vector2(9, 5 * s) + bob, 3.0, Color("fff3a0"))

# Zapnose: Volt/Aether. Elephantnose fish + Nikola Tesla + doorbell.
func _draw_zapnose() -> void:
	var ink := Color("141a3d")
	var body := Color("2f45b0")
	var bob := Vector2(0, sin(wobble) * 2.0)
	draw_set_transform(Vector2.ZERO, heading, Vector2.ONE)
	DrawUtil.poly(self, PackedVector2Array([Vector2(-10, 0), Vector2(-30, -10), Vector2(-26, 0), Vector2(-30, 10)]) , body, ink, 3.0)
	draw_set_transform(bob, heading, Vector2(1.5, 0.85))
	DrawUtil.disc(self, Vector2.ZERO, 13.0, body, ink, 3.5)
	draw_set_transform(bob, heading, Vector2.ONE)
	for i in 3:
		draw_line(Vector2(-6 + i * 6, -9), Vector2(-3 + i * 6, 9), Color("ffd23a"), 2.5)
	# long mobile "nose" ending in a doorbell button
	var nose := PackedVector2Array([Vector2(16, 0), Vector2(26, -4), Vector2(34, -2), Vector2(40, -8)])
	draw_polyline(nose, ink, 8.0, true)
	draw_polyline(nose, Color("6c8cff"), 4.0, true)
	DrawUtil.disc(self, Vector2(42, -9), 4.0, Color("ffd23a"), ink, 2.0)
	draw_circle(Vector2(8, -3), 3.5, Color.WHITE)
	draw_circle(Vector2(9, -3), 1.6, ink)
	# crackling sparks
	var tm := float(Time.get_ticks_msec()) / 90.0
	for i in 2:
		var o := Vector2(sin(tm + i * 3.1), cos(tm * 1.3 + i)) * 4.0
		draw_polyline(PackedVector2Array([Vector2(-4, -12) + o, Vector2(0, -18) + o, Vector2(-2, -22) + o, Vector2(4, -28) + o]), Color("fff3a0"), 2.0, true)

# Glomm: Stone/Frost. Yeti crab + Golem of Prague + snow globe.
func _draw_glomm() -> void:
	var ink := Color("1c2433")
	var stone := Color("7f8da6")
	var fur := Color("e8f0f7")
	var bob := Vector2(0, sin(wobble) * 2.5)
	# hairy claws
	for s in [-1.0, 1.0]:
		var c := Vector2(32 * s, 4) + bob
		DrawUtil.disc(self, c, 11.0, fur, ink, 3.5)
		for i in 4:
			var a := -PI / 2 + (i - 1.5) * 0.7
			DrawUtil.poly(self, PackedVector2Array([c + Vector2.from_angle(a - 0.2) * 10, c + Vector2.from_angle(a) * 19, c + Vector2.from_angle(a + 0.2) * 10]), fur, ink, 2.0)
	# stubby legs
	for i in 3:
		for s in [-1.0, 1.0]:
			draw_line(Vector2(12 * s, 14) + bob, Vector2((22 + i * 3) * s, 22 + (i - 1) * 4), ink, 5.0)
	DrawUtil.disc(self, bob, 27.0, stone, ink, 4.5)
	# carved clay-golem brow and glowing eyes
	DrawUtil.poly(self, PackedVector2Array([Vector2(-18, -4) + bob, Vector2(18, -4) + bob, Vector2(14, 2) + bob, Vector2(-14, 2) + bob]), Color("5a6679"), ink, 2.5)
	for s in [-1.0, 1.0]:
		draw_circle(Vector2(9 * s, -1) + bob, 3.5, Color("9be7ff"))
	draw_line(Vector2(-10, 12) + bob, Vector2(10, 12) + bob, ink, 3.0)
	# snow globe on its back
	var g := Vector2(0, -26) + bob
	DrawUtil.poly(self, PackedVector2Array([g + Vector2(-9, 8), g + Vector2(9, 8), g + Vector2(7, 14), g + Vector2(-7, 14)]), Color("a2763a"), ink, 2.5)
	draw_circle(g, 14.0 + 1.5, ink)
	draw_circle(g, 14.0 - 1.0, Color(0.7, 0.9, 1.0, 0.75))
	var tm := float(Time.get_ticks_msec()) / 700.0
	for i in 6:
		draw_circle(g + Vector2(sin(tm * 1.3 + i * 1.7) * 8.0, fmod(tm + i * 0.37, 1.0) * 18.0 - 9.0), 1.6, Color.WHITE)
