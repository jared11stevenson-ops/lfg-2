class_name PropLayer
extends Node2D
## Procedural flora & landmarks, deterministic per world cell, drawn only inside the camera view.
const CELL := 56.0
var world: GameWorld
var cam: Camera2D
var last_key := Vector2i(-9999, -9999)
var t := 0.0

func _process(dt: float) -> void:
	t += dt
	queue_redraw()

static func h(ix: int, iy: int, k: int) -> float:
	var x := (ix * 73856093) ^ (iy * 19349663) ^ (k * 83492791)
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return float(absi(x) % 100003) / 100003.0

func _draw() -> void:
	if world == null or cam == null: return
	var vp := get_viewport_rect().size / cam.zoom
	var c := cam.get_screen_center_position()
	var x0 := int(floor((c.x - vp.x * 0.5 - 140.0) / CELL)); var x1 := int(ceil((c.x + vp.x * 0.5 + 140.0) / CELL))
	var y0 := int(floor((c.y - vp.y * 0.5 - 140.0) / CELL)); var y1 := int(ceil((c.y + vp.y * 0.5 + 140.0) / CELL))
	var rid := get_canvas_item()
	var under := Ink.Batch.new()
	var over := Ink.Batch.new()
	var lines: Array = []
	for iy in range(y0, y1 + 1):
		for ix in range(x0, x1 + 1):
			var p := Vector2((ix + h(ix, iy, 1)) * CELL, (iy + h(ix, iy, 2)) * CELL)
			if p.x < 20 or p.y < 20 or p.x > world.world_px() - 20 or p.y > world.world_px() - 20: continue
			var tl := world.tile_of(p)
			var ti := tl.y * GameWorld.TW + tl.x
			var e := world.elev[ti]
			var m := world.data_img.get_pixel(tl.x, tl.y)
			var moist := m.g; var temp := m.a
			var r1 := h(ix, iy, 3); var r2 := h(ix, iy, 4); var r3 := h(ix, iy, 5)
			if e < 0.325:
				continue
			if e < 0.36 and r1 < 0.55:
				_reeds(under, over, lines, p, r2, r3, moist)       # shoreline reeds
			elif world.tree_n[ti] > 0.0 and r1 < world.tree_n[ti] * 0.3 + 0.02:
				_tree(under, over, p, r2, r3, moist, temp)
			elif e > 0.62 and r1 < 0.16:
				_rock(under, over, p, r2, r3)
			elif r1 < 0.28:
				_flower(over, p, r2, r3, moist, temp)
			elif r1 < 0.5:
				lines.append([p, r2, moist])
	under.flush(rid)
	# grass tufts as inked strokes
	for L in lines:
		var p: Vector2 = L[0]
		var gc := Color(0.2 + 0.15 * (1.0 - L[2]), 0.42 + 0.1 * L[2], 0.2, 0.55)
		for k in 3:
			var a: float = -PI / 2 + (k - 1) * 0.5 + (L[1] - 0.5) * 0.4 + sin(t * 1.5 + p.x * 0.05) * 0.06
			draw_line(p, p + Vector2(cos(a), sin(a)) * (10.0 + 6.0 * L[1]), gc, 1.8, true)
	over.flush(rid)

func _tree(u: Ink.Batch, o: Ink.Batch, p: Vector2, r2: float, r3: float, moist: float, temp: float) -> void:
	var rad := 30.0 + 34.0 * r2
	var hue := lerpf(0.34, 0.2, clampf(1.0 - moist, 0.0, 1.0)) + (r3 - 0.5) * 0.04
	if temp < 0.3: hue = 0.42
	var base := Color.from_hsv(hue, 0.6, 0.5 + 0.2 * r3)
	# soft cast shadow
	var sh := Color(0.04, 0.05, 0.12, 0.3)
	Ink.dome(u, p + Vector2(14, 20), rad * 1.05, rad * 0.9, 0.0, sh, 0.0, 14)
	# canopy: layered leaf-clump domes (ink-outlined)
	var n := 6
	for k in n:
		var a := TAU * k / n + r3 * 3.0
		var c := p + Vector2(cos(a), sin(a)) * rad * 0.42
		Ink.dome(o, c, rad * 0.55, rad * 0.5, a, base.lerp(Color.from_hsv(hue + 0.03, 0.6, 0.6), k % 3 * 0.18), 0.0, 14)
	Ink.dome(o, p, rad * 0.62, rad * 0.6, 0.0, base.lightened(0.1), 0.0, 14)
	for k in 9:
		var q := p + Vector2(cos(k * 2.4 + r3 * 5.0), sin(k * 2.4 + r3 * 5.0)) * rad * (0.2 + 0.07 * k)
		draw_circle(q, 2.2, Color(base.r + 0.25, base.g + 0.3, base.b + 0.05, 0.55))
	for k in n:
		var a := TAU * k / n + r3 * 3.0
		var c := p + Vector2(cos(a), sin(a)) * rad * 0.42
		draw_arc(c, rad * 0.5, a - 1.2, a + 1.2, 8, Ink.ink_color(base), 1.6, true)

func _rock(u: Ink.Batch, o: Ink.Batch, p: Vector2, r2: float, r3: float) -> void:
	var rad := 14.0 + 26.0 * r2
	var base := Color(0.5, 0.47, 0.5).lerp(Color(0.55, 0.5, 0.42), r3)
	Ink.dome(u, p + Vector2(5, 7), rad * 1.1, rad * 0.8, 0.0, Color(0.05, 0.05, 0.12, 0.28), 0.0, 12)
	Ink.dome(o, p, rad, rad * (0.7 + 0.2 * r3), r3 * 3.0, base, 0.0, 10)
	Ink.dome_outline(self, p, rad, rad * (0.7 + 0.2 * r3), r3 * 3.0, Ink.ink_color(base), 2.0, 14)

func _reeds(u: Ink.Batch, o: Ink.Batch, lines: Array, p: Vector2, r2: float, r3: float, moist: float) -> void:
	for k in 5:
		var q := p + Vector2((k - 2) * 7.0, (r2 - 0.5) * 12.0)
		var sway := sin(t * 1.3 + q.x * 0.07 + k) * 4.0
		var top := q + Vector2(sway, -30.0 - 16.0 * h(int(q.x), int(q.y), k))
		draw_line(q, top, Color(0.35, 0.5, 0.28), 2.0, true)
		if k % 2 == 0: draw_line(top + Vector2(0, 2), top + Vector2(0, -12), Color(0.45, 0.28, 0.18), 5.0, true)

func _flower(o: Ink.Batch, p: Vector2, r2: float, r3: float, moist: float, temp: float) -> void:
	var col := Color.from_hsv(fmod(r3 * 1.7, 1.0), 0.55, 0.95)
	var rr := 3.0 + 2.5 * r2
	for k in 5:
		var a := TAU * k / 5.0
		draw_circle(p + Vector2(cos(a), sin(a)) * rr, rr * 0.75, col)
	draw_circle(p, rr * 0.7, Color(1.0, 0.85, 0.3))
