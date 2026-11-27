extends Node2D
# Defeat animation: the creature's sprite pops up, squashes and spins away, fading into stars.
const PuppetLib = preload("res://puppet_lib.gd")
var sprite := "shuckit"
var flip := false
var sc := 0.56
var tint := Color.WHITE
var t := 0.0
const LIFE := 0.55
var stars: Array = []
var lift := 0.0

func _ready() -> void:
	z_index = 9
	for i in 5:
		stars.append(Vector2.from_angle(randf() * TAU) * randf_range(22.0, 52.0))

func _process(delta: float) -> void:
	t += delta
	if t > LIFE:
		queue_free()
	queue_redraw()

func _draw() -> void:
	var k := t / LIFE
	# 0..0.25: pop up and stretch; then squash, spin and shrink
	var up := sin(minf(k / 0.45, 1.0) * PI) * 26.0
	var stretch := 1.0 + 0.22 * sin(minf(k / 0.25, 1.0) * PI) - 0.5 * maxf(0.0, k - 0.5) * 2.0
	var s := sc * maxf(0.05, 1.0 - 0.9 * pow(k, 2.2))
	var rot := (-1.0 if flip else 1.0) * k * 2.2
	var a := 1.0 - pow(k, 3.0)
	var squash := Vector2(1.0 / maxf(0.5, stretch), stretch)
	PuppetLib.draw(self, sprite, "idle", 0, flip, s, Vector2(0, 8 - up - lift), Color(tint.r, tint.g, tint.b, a).lerp(Color(1, 0.8, 0.8, a), 0.35), rot, squash)
	for st in stars:
		var p: Vector2 = st * k + Vector2(0, -up * 0.5 - 18.0)
		var r := 4.5 * (1.0 - k) + 1.0
		var pts := PackedVector2Array()
		for i in 8:
			var ang := PI * i / 4.0 - PI / 2.0 + k * 3.0
			pts.append(p + Vector2.from_angle(ang) * (r if i % 2 == 0 else r * 0.45))
		draw_colored_polygon(pts, Color(1.0, 0.92, 0.5, 1.0 - k))
