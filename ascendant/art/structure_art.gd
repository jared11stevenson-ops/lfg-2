class_name StructureArt
extends RefCounted
## Procedural architecture. Every style is built from the same ink/dome kit as creatures.
## s: structure dict; pal: builder's palette; ruin 0..1 (0 = pristine, 1 = fallen to rubble).

static func hsh(a: int, b: int) -> float:
	var x := (a * 73856093) ^ (b * 19349663)
	x = (x ^ (x >> 13)) * 1274126177
	return float(absi(x ^ (x >> 16)) % 10007) / 10007.0

static func _earth(pal: Dictionary, k: float) -> Color:
	return Color(0.52, 0.38, 0.26).lerp(pal["base"], 0.25).lightened(k)

static func draw(item: CanvasItem, s: Dictionary, pal: Dictionary, t: float, tile_px: float, seed_: int) -> void:
	var rid := item.get_canvas_item()
	var ruin: float = 0.0 if s["state"] == "alive" else 1.0 - float(s["hp"]) * 0.5
	var b := Ink.Batch.new()
	var ink: Color = Ink.ink_color(pal["base"])
	var sc := 1.0 + 0.0
	var style: String = s["style"]
	var rr := hsh(seed_, 7)
	# desaturate + weather for ruins
	var tint := func(c: Color) -> Color:
		if ruin <= 0.0: return c
		var g := (c.r + c.g + c.b) / 3.0
		return c.lerp(Color(g, g, g * 1.05), 0.55 * ruin).darkened(0.1 * ruin)
	var ground := Color(0.04, 0.04, 0.1, 0.25)
	var R := 30.0
	match style:
		"warren", "burrow_nook", "mound_hut":
			var rad := R * (1.0 if style == "warren" else 0.7)
			Ink.dome(b, Vector2(4, 6), rad * 1.1, rad * 0.9, 0.0, ground, 0.0, 14)
			Ink.dome(b, Vector2.ZERO, rad, rad * 0.85, rr * 3.0, tint.call(_earth(pal, 0.05)), 0.0, 16)
			b.flush(rid)
			Ink.dome_outline(item, Vector2.ZERO, rad, rad * 0.85, rr * 3.0, ink, 2.0, 18)
			var holes := 2 if style == "warren" else 1
			for k in holes:
				var hp := Vector2(cos(k * 2.6 + rr * 5.0), sin(k * 2.6 + rr * 5.0)) * rad * 0.42
				item.draw_circle(hp, rad * 0.2, Color(0.05, 0.03, 0.06))
				item.draw_arc(hp, rad * 0.2, 0, TAU, 12, _earth(pal, 0.3), 3.0, true)
		"hive_mound":
			Ink.dome(b, Vector2(5, 8), R * 1.3, R * 1.1, 0.0, ground, 0.0, 14)
			for k in 4:
				var rad := R * (1.15 - 0.22 * k)
				Ink.dome(b, Vector2(0, -k * 6.0), rad, rad * 0.9, 0.0, tint.call(_earth(pal, 0.04 * k)), 0.0, 16)
			b.flush(rid)
			for k in 4: Ink.dome_outline(item, Vector2(0, -k * 6.0), R * (1.15 - 0.22 * k), R * (1.15 - 0.22 * k) * 0.9, 0.0, ink, 1.6, 16)
			for k in 7:
				var a := k * 0.9 + rr
				item.draw_circle(Vector2(cos(a), sin(a)) * R * (0.3 + 0.1 * (k % 3)) + Vector2(0, -8), 2.6, Color(0.04, 0.02, 0.05))
		"lodge":
			Ink.dome(b, Vector2(6, 9), R * 1.4, R * 1.2, 0.0, ground, 0.0, 14)
			Ink.dome(b, Vector2.ZERO, R * 1.15, R, 0.0, tint.call(Color(0.42, 0.3, 0.2)), 0.0, 18)
			b.flush(rid)
			for k in 26:
				var a := hsh(seed_, k) * TAU; var d := R * (0.2 + 0.8 * hsh(seed_, k + 40))
				var p := Vector2(cos(a), sin(a)) * d
				item.draw_line(p, p + Vector2(cos(a + 1.3), sin(a + 1.3)) * 18.0, Color(0.3, 0.2, 0.12).lerp(Color(0.6, 0.45, 0.3), hsh(seed_, k + 9)), 3.0, true)
			Ink.dome_outline(item, Vector2.ZERO, R * 1.15, R, 0.0, ink, 2.0, 20)
		"web_hall", "silk_cocoon_store", "tripline_net", "silk_line":
			var web := Color(0.92, 0.95, 1.0, 0.8 if ruin < 0.5 else 0.35)
			var spokes := 10 if style != "silk_line" else 3
			var rad := R * (1.7 if style == "web_hall" else 1.2)
			for k in spokes:
				var a := TAU * k / spokes + rr
				var tip := Vector2(cos(a), sin(a)) * rad
				item.draw_line(Vector2.ZERO, tip, web, 1.4, true)
				item.draw_circle(tip, 3.0, web)
			for ring in 5:
				var pts := PackedVector2Array()
				for k in spokes + 1:
					var a := TAU * k / spokes + rr
					pts.append(Vector2(cos(a), sin(a)) * rad * (0.2 + ring * 0.18) * (1.0 + 0.08 * sin(t * 1.5 + k)))
				item.draw_polyline(pts, web, 1.1, true)
			if style == "silk_cocoon_store":
				for k in 3:
					Ink.dome(b, Vector2(cos(k * 2.1) * 12, sin(k * 2.1) * 12), 8, 11, k, tint.call(Color(0.9, 0.9, 0.85)), 0.0, 10)
				b.flush(rid)
			elif style == "web_hall":
				Ink.dome(b, Vector2.ZERO, 14, 12, 0.0, tint.call(pal["base"].lightened(0.3)), 0.0, 12)
				b.flush(rid)
				Ink.dome_outline(item, Vector2.ZERO, 14, 12, 0.0, ink, 1.6, 12)
		"nest_cluster", "watch_perch", "canopy_walk":
			for k in 3:
				var c := Vector2(cos(k * 2.1 + rr) * 20, sin(k * 2.1 + rr) * 16)
				Ink.dome(b, c + Vector2(8, 12), 22, 20, 0.0, ground, 0.0, 12)
				Ink.dome(b, c, 22, 20, 0.0, tint.call(Color(0.48, 0.36, 0.22)), 0.0, 14)
				Ink.dome(b, c, 12, 11, 0.0, tint.call(Color(0.25, 0.2, 0.15)), 0.0, 12)
			b.flush(rid)
			for k in 3:
				var c := Vector2(cos(k * 2.1 + rr) * 20, sin(k * 2.1 + rr) * 16)
				for j in 14:
					var a := j * 0.45 + k
					item.draw_line(c + Vector2(cos(a), sin(a)) * 8, c + Vector2(cos(a + 0.6), sin(a + 0.6)) * 21, Color(0.35, 0.24, 0.14), 2.0, true)
				Ink.dome_outline(item, c, 22, 20, 0.0, ink, 1.8, 14)
		"woven_hut":
			Ink.dome(b, Vector2(5, 7), R, R * 0.85, 0.0, ground, 0.0, 12)
			Ink.dome(b, Vector2.ZERO, R * 0.85, R * 0.75, 0.0, tint.call(Color(0.7, 0.62, 0.35)), 0.0, 14)
			b.flush(rid)
			for k in 12:
				var a := TAU * k / 12.0
				item.draw_line(Vector2(cos(a), sin(a)) * R * 0.2, Vector2(cos(a), sin(a)) * R * 0.8, Color(0.5, 0.42, 0.2, 0.7), 1.6, true)
			Ink.dome_outline(item, Vector2.ZERO, R * 0.85, R * 0.75, 0.0, ink, 2.0, 16)
		"root_cellar", "granary", "tunnel_net":
			Ink.dome(b, Vector2.ZERO, R * 0.7, R * 0.55, 0.0, tint.call(_earth(pal, 0.1)), 0.0, 12)
			b.flush(rid)
			item.draw_rect(Rect2(-9, -7, 18, 14), tint.call(Color(0.35, 0.25, 0.16)))
			item.draw_rect(Rect2(-9, -7, 18, 14), ink, false, 2.0)
			if style == "tunnel_net":
				for k in 4:
					var a := k * 1.6 + rr
					item.draw_line(Vector2.ZERO, Vector2(cos(a), sin(a)) * 44, Color(0.15, 0.1, 0.08, 0.35), 5.0, true)
		"fungus_garden", "seed_plot", "reed_paddy":
			var col := Color(0.62, 0.55, 0.78) if style == "fungus_garden" else (Color(0.4, 0.62, 0.4) if style == "reed_paddy" else Color(0.75, 0.62, 0.3))
			Ink.dome(b, Vector2.ZERO, R * 1.1, R * 0.9, 0.0, tint.call(Color(0.32, 0.24, 0.16)), 0.0, 14)
			b.flush(rid)
			for row in 4:
				for cc in 5:
					var p := Vector2(-22 + cc * 11, -18 + row * 12)
					var sway := sin(t * 1.3 + cc + row) * 1.5
					if style == "fungus_garden": 
						item.draw_circle(p, 4.5, tint.call(col)); item.draw_circle(p + Vector2(0, -1), 2.2, tint.call(col.lightened(0.3)))
					else: item.draw_line(p, p + Vector2(sway, -12), tint.call(col), 2.2, true)
			item.draw_rect(Rect2(-R * 1.1 * 0.8, -R * 0.9 * 0.8, R * 1.8, R * 1.45), ink, false, 1.8)
		"dam", "canal":
			var sc2 := 1.0
			for k in 9:
				var x := -52.0 + k * 13.0
				var y := sin(k * 0.6 + rr) * 5.0
				var logc: Color = tint.call(Color(0.36, 0.25, 0.16).lerp(Color(0.5, 0.36, 0.24), hsh(seed_, k)))
				Ink.dome(b, Vector2(x, y), 11, 6.5, 0.4 * (k % 3 - 1), logc, 0.0, 10)
			b.flush(rid)
			for k in 9: item.draw_arc(Vector2(-52.0 + k * 13.0, sin(k * 0.6 + rr) * 5.0), 7.0, 0, TAU, 10, ink, 1.4, true)
			item.draw_arc(Vector2(0, 14), 60, 0.2, PI - 0.2, 18, Color(0.5, 0.75, 0.8, 0.5), 3.0, true)
		"fish_weir", "reed_raft_town":
			for k in 10: item.draw_line(Vector2(-40 + k * 8.0, -12), Vector2(-40 + k * 8.0, 12), tint.call(Color(0.5, 0.4, 0.25)), 3.0, true)
		"trail":
			for k in 7: item.draw_circle(Vector2(-30 + k * 10.0, sin(k + rr * 4) * 4), 3.0, Color(0.74, 0.66, 0.5, 0.55))
		"spike_ring", "thorn_hedge":
			for k in 16:
				var a := TAU * k / 16.0; var p := Vector2(cos(a), sin(a)) * R * 1.1
				item.draw_line(p, p + Vector2(cos(a), sin(a)) * 14, tint.call(Color(0.35, 0.27, 0.18)), 3.0, true)
				item.draw_circle(p, 3.0, tint.call(Color(0.3, 0.22, 0.15)))
		"forge_hollow", "workbench":
			Ink.dome(b, Vector2.ZERO, R * 0.9, R * 0.75, 0.0, tint.call(_earth(pal, -0.05)), 0.0, 14)
			Ink.dome(b, Vector2(0, 2), R * 0.4, R * 0.3, 0.0, Color(0.12, 0.08, 0.08), 0.0, 10)
			b.flush(rid)
			for k in 6: item.draw_circle(Vector2(cos(k * 1.2) * 20, sin(k * 1.2) * 14), 4, tint.call(Color(0.6, 0.55, 0.5)))
		"cairn_spire":
			for k in 6:
				var rad := 18.0 - k * 2.6
				Ink.dome(b, Vector2(0, -k * 7.0), rad, rad * 0.8, 0.0, tint.call(Color(0.62, 0.58, 0.55).lightened(0.03 * k)), 0.0, 12)
			b.flush(rid)
			for k in 6: Ink.dome_outline(item, Vector2(0, -k * 7.0), 18.0 - k * 2.6, (18.0 - k * 2.6) * 0.8, 0.0, ink, 1.4, 12)
		_:
			Ink.dome(b, Vector2.ZERO, R * 0.7, R * 0.6, 0.0, tint.call(_earth(pal, 0.0)), 0.0, 12)
			b.flush(rid)
			Ink.dome_outline(item, Vector2.ZERO, R * 0.7, R * 0.6, 0.0, ink, 2.0, 14)
	# ruin dressing: cracks, rubble, moss
	if ruin > 0.0:
		for k in 5:
			var a := hsh(seed_, k + 70) * TAU
			var p := Vector2(cos(a), sin(a)) * R * (0.3 + 0.8 * hsh(seed_, k + 80))
			item.draw_line(p, p + Vector2(cos(a + 2.0), sin(a + 2.0)) * 10, Color(0.08, 0.06, 0.1, 0.7), 1.6, true)
			Ink.dome(b, p + Vector2(0, 6), 5.5, 4.5, a, Color(0.5, 0.48, 0.45), 0.0, 8)
		b.flush(rid)
		for k in int(10 + ruin * 14):
			var a2 := hsh(seed_, k + 120) * TAU; var d := R * hsh(seed_, k + 150) * 1.2
			item.draw_circle(Vector2(cos(a2), sin(a2)) * d, 2.0 + 3.0 * hsh(seed_, k), Color(0.32, 0.5, 0.28, 0.55 * ruin))
