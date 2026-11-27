extends Node2D
# The Well's gold (Level 1): a pile of coins in the Well, one per remaining "life". When an enemy reaches the Well it
# snatches coins and bolts off the right edge with them overhead; the pile shrinks.
const PuppetLib = preload("res://puppet_lib.gd")
const OUT := Color("1d1230")
var well := Vector2(1190, 296)
var gold := 20
var max_gold := 20
var thieves: Array = []
var t := 0.0
var flash := 0.0

func _ready() -> void:
	z_index = 3

func set_gold(n: int) -> void:
	gold = clampi(n, 0, 99)
	max_gold = maxi(max_gold, gold)

func _coin_pos(i: int) -> Vector2:
	var a := float(i) * 2.39996
	var r := 4.8 * sqrt(float(i) + 0.6) * 1.95
	return well + Vector2(cos(a) * r, sin(a) * r * 0.62 - 6.0 - float(i % 3) * 1.5)

func steal(sprite: String, n: int, at: Vector2, scale_mul: float) -> void:
	flash = 1.0
	thieves.append({"sprite": sprite, "n": n, "p0": at, "age": 0.0, "scale": 0.56 * scale_mul, "from": _coin_pos(maxi(0, gold)), "seed": randf() * 6.0})

func _process(delta: float) -> void:
	t += delta
	flash = maxf(0.0, flash - delta * 2.2)
	for th in thieves:
		th.age += delta
	thieves = thieves.filter(func(th): return th.age < 1.35)
	queue_redraw()

func _coin(p: Vector2, s: float = 1.0, a: float = 1.0) -> void:
	draw_set_transform(p, 0.0, Vector2(1.0, 0.74) * s)
	draw_circle(Vector2.ZERO, 8.2, Color(OUT.r, OUT.g, OUT.b, a))
	draw_circle(Vector2.ZERO, 6.8, Color(0.96, 0.72, 0.16, a))
	draw_arc(Vector2.ZERO, 6.8, PI * 1.1, PI * 1.9, 10, Color(1.0, 0.92, 0.55, a), 2.0, true)
	draw_arc(Vector2.ZERO, 3.6, 0.0, TAU, 12, Color(0.78, 0.5, 0.08, a), 1.3, true)
	draw_circle(Vector2(-2.2, -2.2), 1.5, Color(1, 1, 1, 0.8 * a))
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _draw() -> void:
	# pile, back to front
	var idx: Array = range(gold)
	idx.sort_custom(func(a, b): return _coin_pos(a).y < _coin_pos(b).y)
	for i in idx:
		_coin(_coin_pos(i))
	if gold <= 3:
		draw_arc(well + Vector2(0, -8), 44.0, 0, TAU, 40, Color(1.0, 0.3, 0.3, 0.35 + 0.3 * sin(t * 8.0)), 3.0, true)
	if flash > 0.0:
		draw_circle(well + Vector2(0, -8), 56.0, Color(1.0, 0.35, 0.3, 0.28 * flash))
	for th in thieves:
		var u: float = th.age / 1.35
		var dir := Vector2(1.0, -0.32).normalized()
		var pos: Vector2 = th.p0 + dir * (40.0 + 230.0 * u * u) + Vector2(0, -absf(sin(th.age * 11.0)) * 8.0)
		var a := 1.0 - clampf((u - 0.72) / 0.28, 0.0, 1.0)
		PuppetLib.draw(self, th.sprite, "walk", int(th.age * 14.0) % 8, false, th.scale, pos, Color(1, 1, 1, a))
		var head := pos + Vector2(0, -78.0 * th.scale / 0.56 * 0.62)
		for k in int(th.n):
			var cpos := head + Vector2((k - (int(th.n) - 1) * 0.5) * 11.0, -float(k % 2) * 7.0)
			if th.age < 0.3:
				var kk: float = th.age / 0.3
				cpos = th.from.lerp(cpos, kk) + Vector2(0, -sin(kk * PI) * 34.0)
			_coin(cpos, 0.9, a)
