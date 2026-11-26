extends RefCounted
# 2D cartoon puppet renderer. Creatures are lists of parts (see puppets.gd) drawn with thick outlines,
# noodle limbs, expressive eyes and per-part animation. Designed to be baked to sprite frames (tools/bake_puppets.gd).
const OUT := Color("2b1a3d")
static var _cols := {}
static var _ells := {}

static func C(s) -> Color:
	if s is Color:
		return s
	if not _cols.has(s):
		_cols[s] = Color(s)
	return _cols[s]

# ---- part constructors (used by puppets.gd) ----
static func A(kind: String, amp: float, cyc: float = 1.0, ph: float = 0.0, px: float = 0.0, py: float = 0.0, atk: float = 0.0) -> Dictionary:
	return {"k": kind, "amp": amp, "cyc": cyc, "ph": ph, "px": px, "py": py, "atk": atk}

static func E(x: float, y: float, rx: float, ry: float, col, o: Dictionary = {}) -> Dictionary:
	var d := {"t": "e", "x": x, "y": y, "rx": rx, "ry": ry, "c": col}
	d.merge(o)
	return d

static func P(pts: Array, col, o: Dictionary = {}) -> Dictionary:
	var d := {"t": "p", "pts": pts, "c": col}
	d.merge(o)
	return d

# Tube / noodle limb: pts are [x, y, width] triples.
static func T(pts: Array, col, o: Dictionary = {}) -> Dictionary:
	var d := {"t": "t", "pts": pts, "c": col}
	d.merge(o)
	return d

static func EYE(x: float, y: float, r: float, style: String = "round", o: Dictionary = {}) -> Dictionary:
	var d := {"t": "eye", "x": x, "y": y, "r": r, "style": style}
	d.merge(o)
	return d

static func MOUTH(x: float, y: float, w: float, mood: String = "smile", o: Dictionary = {}) -> Dictionary:
	var d := {"t": "mouth", "x": x, "y": y, "w": w, "mood": mood}
	d.merge(o)
	return d

# Spiky star / sun / flame burst: n points, outer radius r, inner ratio.
static func S(x: float, y: float, r: float, n: int, col, o: Dictionary = {}) -> Dictionary:
	var d := {"t": "s", "x": x, "y": y, "r": r, "n": n, "c": col}
	d.merge(o)
	return d

static func RING(x: float, y: float, r: float, w: float, col, o: Dictionary = {}) -> Dictionary:
	var d := {"t": "ring", "x": x, "y": y, "r": r, "w": w, "c": col}
	d.merge(o)
	return d

static func leg(pts: Array, col, ph: float, px: float, py: float, amp: float = 22.0) -> Dictionary:
	return T(pts, col, {"a": [A("rot", amp, 1.0, ph, px, py)], "hand": true})

# ---- geometry ----
static func _ell(rx: float, ry: float, wob: float, seed: float) -> PackedVector2Array:
	var key := "%.1f_%.1f_%.2f_%.1f" % [rx, ry, wob, seed]
	if _ells.has(key):
		return _ells[key]
	var pts := PackedVector2Array()
	var n := 30
	for i in n:
		var a := TAU * i / n
		var k := 1.0 + wob * (sin(a * 3.0 + seed) * 0.6 + sin(a * 5.0 + seed * 1.7) * 0.4)
		pts.append(Vector2(cos(a) * rx * k, sin(a) * ry * k))
	_ells[key] = pts
	return pts

static func _star(r: float, n: int, inner: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n * 2:
		var a := PI * i / n - PI / 2.0
		var rr := r if i % 2 == 0 else r * inner
		pts.append(Vector2(cos(a), sin(a)) * rr)
	return pts

static func _rot_about(tf: Transform2D, ang: float, pv: Vector2) -> Transform2D:
	return tf * Transform2D(0.0, pv) * Transform2D(ang, Vector2.ZERO) * Transform2D(0.0, -pv)

static func _outlined(ci: CanvasItem, pts: PackedVector2Array, fill: Color, ow: float, outline_col: Color) -> void:
	ci.draw_colored_polygon(pts, fill)
	if ow > 0.0:
		var closed := pts.duplicate()
		closed.append(pts[0])
		ci.draw_polyline(closed, outline_col, ow, true)

# ---- main draw ----
# state: idle | walk | attack. t in [0,1). look: unit vector pupils glance toward. flash: 0..1 white overlay (hit).
static func draw(ci: CanvasItem, parts: Array, state: String, t: float, look: Vector2 = Vector2.ZERO, tint: Color = Color.WHITE) -> void:
	var ph := TAU * t
	var bob := 0.0
	var lean := 0.0
	var sx := 1.0
	var sy := 1.0
	var dx := 0.0
	match state:
		"walk":
			bob = -absf(sin(ph * 2.0)) * 4.0
			lean = sin(ph) * 0.05
			sy = 1.0 + 0.03 * sin(ph * 4.0)
			sx = 1.0 - 0.03 * sin(ph * 4.0)
		"attack":
			var k := sin(PI * t)
			dx = 7.0 * k
			sx = 1.0 + 0.1 * k
			sy = 1.0 - 0.09 * k
			bob = -2.0 * k
		_:
			bob = sin(ph) * 2.0
			sy = 1.0 + 0.025 * sin(ph)
			sx = 1.0 - 0.02 * sin(ph)
	var base := Transform2D(lean, Vector2(sx, sy), 0.0, Vector2(dx, bob))
	var blink := t > 0.9 and t < 0.96 and state != "attack"
	for p in parts:
		var tf := base
		for a in p.get("a", []):
			var amp: float = a.amp
			if state == "attack" and a.atk != 0.0:
				amp = a.atk
				var v := sin(PI * t) * amp
				tf = _apply_anim(tf, a, v)
				continue
			if state == "attack":
				amp *= 0.5
			var v2 := sin(ph * a.cyc + a.ph) * amp
			tf = _apply_anim(tf, a, v2)
		var rot := deg_to_rad(float(p.get("rot", 0.0)))
		match String(p.t):
			"e":
				tf = tf * Transform2D(rot, Vector2(float(p.x), float(p.y)))
				ci.draw_set_transform_matrix(tf)
				var pts := _ell(float(p.rx), float(p.ry), float(p.get("wob", 0.0)), float(p.get("seed", 0.0)))
				_outlined(ci, pts, C(p.c) * tint, float(p.get("ow", 3.0)), C(p.get("oc", OUT)))
			"p":
				tf = tf * Transform2D(rot, Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))))
				ci.draw_set_transform_matrix(tf)
				var pp := PackedVector2Array()
				for q in p.pts:
					pp.append(Vector2(q[0], q[1]))
				_outlined(ci, pp, C(p.c) * tint, float(p.get("ow", 3.0)), C(p.get("oc", OUT)))
			"s":
				tf = tf * Transform2D(rot, Vector2(float(p.x), float(p.y)))
				ci.draw_set_transform_matrix(tf)
				_outlined(ci, _star(float(p.r), int(p.n), float(p.get("in", 0.5))), C(p.c) * tint, float(p.get("ow", 2.5)), C(p.get("oc", OUT)))
			"ring":
				tf = tf * Transform2D(rot, Vector2(float(p.x), float(p.y)))
				ci.draw_set_transform_matrix(tf)
				var r := float(p.r)
				ci.draw_arc(Vector2.ZERO, r, 0, TAU, 36, OUT, float(p.w) + 5.0, true)
				ci.draw_arc(Vector2.ZERO, r, 0, TAU, 36, C(p.c) * tint, float(p.w), true)
			"t":
				tf = tf * Transform2D(rot, Vector2(float(p.get("x", 0.0)), float(p.get("y", 0.0))))
				ci.draw_set_transform_matrix(tf)
				_tube(ci, p, ph, state, C(p.c) * tint)
			"eye":
				tf = tf * Transform2D(rot, Vector2(float(p.x), float(p.y)))
				ci.draw_set_transform_matrix(tf)
				_eye(ci, p, look, blink or (state == "attack" and p.get("squint", false)))
			"mouth":
				tf = tf * Transform2D(rot, Vector2(float(p.x), float(p.y)))
				ci.draw_set_transform_matrix(tf)
				_mouth(ci, p, state, t)
	ci.draw_set_transform_matrix(Transform2D.IDENTITY)

static func _apply_anim(tf: Transform2D, a: Dictionary, v: float) -> Transform2D:
	match String(a.k):
		"rot":
			return _rot_about(tf, deg_to_rad(v), Vector2(a.px, a.py))
		"dy":
			return tf * Transform2D(0.0, Vector2(0.0, v))
		"dx":
			return tf * Transform2D(0.0, Vector2(v, 0.0))
		"sq":
			return tf * Transform2D(0.0, Vector2(a.px, a.py)) * Transform2D(0.0, Vector2(1.0 + v, 1.0 - v), 0.0, Vector2.ZERO) * Transform2D(0.0, Vector2(-a.px, -a.py))
	return tf

static func _tube(ci: CanvasItem, p: Dictionary, ph: float, state: String, fill: Color) -> void:
	var pts: Array = p.pts
	var wave := float(p.get("wave", 0.0))
	var wcyc := float(p.get("wcyc", 1.0))
	if state == "attack":
		wave *= 1.6
	var line := PackedVector2Array()
	var widths: Array = []
	for i in pts.size():
		var q: Array = pts[i]
		var k := float(i) / maxf(1.0, pts.size() - 1.0)
		var off := sin(ph * wcyc - k * 3.2) * wave * k
		line.append(Vector2(q[0], q[1] + off))
		widths.append(float(q[2]))
	var oc := C(p.get("oc", OUT))
	var ow := float(p.get("ow", 3.0))
	for pass_i in 2:
		for i in line.size() - 1:
			var w: float = (widths[i] + widths[i + 1]) * 0.5
			var col := oc if pass_i == 0 else fill
			ci.draw_line(line[i], line[i + 1], col, w + (ow * 2.0 if pass_i == 0 else 0.0), true)
		for i in line.size():
			var w2: float = widths[i]
			ci.draw_circle(line[i], w2 * 0.5 + (ow if pass_i == 0 else 0.0), oc if pass_i == 0 else fill)
	if p.get("hand", false):
		var e := line[line.size() - 1]
		var rr := float(widths[widths.size() - 1]) * 0.9
		ci.draw_circle(e, rr + ow, oc)
		ci.draw_circle(e, rr, fill)

static func _eye(ci: CanvasItem, p: Dictionary, look: Vector2, blink: bool) -> void:
	var r := float(p.r)
	var style := String(p.style)
	var pv := look * r * 0.35
	if blink:
		ci.draw_line(Vector2(-r, 0), Vector2(r, 0), OUT, 4.0, true)
		return
	match style:
		"dot":
			ci.draw_circle(Vector2.ZERO, r * 0.55 + 2.0, OUT)
			ci.draw_circle(pv * 0.4 + Vector2(-r * 0.15, -r * 0.2), r * 0.18, Color.WHITE)
		"bug":
			ci.draw_circle(Vector2.ZERO, r + 2.5, OUT)
			ci.draw_circle(Vector2.ZERO, r, Color.WHITE)
			ci.draw_circle(pv * 1.2, r * 0.32, OUT)
			ci.draw_circle(pv * 1.2 + Vector2(-r * 0.1, -r * 0.12), r * 0.1, Color.WHITE)
		"sleepy":
			ci.draw_circle(Vector2.ZERO, r + 2.5, OUT)
			ci.draw_circle(Vector2.ZERO, r, C(p.get("iris", "#fff6d8")))
			ci.draw_circle(pv + Vector2(0, r * 0.2), r * 0.45, OUT)
			ci.draw_rect(Rect2(-r - 3, -r - 3, r * 2 + 6, r * 1.05), C(p.get("lid", "#7a6a8a")))
			ci.draw_line(Vector2(-r - 2, -r * 0.05), Vector2(r + 2, -r * 0.05), OUT, 3.0, true)
		"angry":
			ci.draw_circle(Vector2.ZERO, r + 2.5, OUT)
			ci.draw_circle(Vector2.ZERO, r, C(p.get("iris", "#ffe36a")))
			ci.draw_circle(pv, r * 0.42, OUT)
			ci.draw_circle(pv + Vector2(-r * 0.12, -r * 0.14), r * 0.12, Color.WHITE)
			var s := -1.0 if bool(p.get("flip", false)) else 1.0
			ci.draw_line(Vector2(-r - 3, -r * 0.9 * s), Vector2(r + 3, -r * 0.1 * s), OUT, 5.0, true)
		"glow":
			ci.draw_circle(Vector2.ZERO, r + 4.0, Color(1, 1, 0.5, 0.35))
			ci.draw_circle(Vector2.ZERO, r + 2.5, OUT)
			ci.draw_circle(Vector2.ZERO, r, C(p.get("iris", "#fff3a0")))
			ci.draw_circle(pv * 0.6, r * 0.3, OUT)
		_:
			ci.draw_circle(Vector2.ZERO, r + 2.5, OUT)
			ci.draw_circle(Vector2.ZERO, r, Color.WHITE)
			ci.draw_circle(pv, r * 0.5, C(p.get("iris", "#2b1a3d")))
			ci.draw_circle(pv + Vector2(-r * 0.15, -r * 0.18), r * 0.16, Color.WHITE)

static func _mouth(ci: CanvasItem, p: Dictionary, state: String, t: float) -> void:
	var w := float(p.w)
	var mood := String(p.mood)
	if state == "attack":
		mood = String(p.get("atk", "o"))
	match mood:
		"smile":
			ci.draw_arc(Vector2(0, -w * 0.3), w * 0.6, 0.35, PI - 0.35, 12, OUT, 3.5, true)
		"grin":
			var pts := PackedVector2Array([Vector2(-w * 0.6, 0), Vector2(w * 0.6, 0), Vector2(w * 0.4, w * 0.4), Vector2(0, w * 0.55), Vector2(-w * 0.4, w * 0.4)])
			_outlined(ci, pts, Color("5a1030"), 3.0, OUT)
			ci.draw_rect(Rect2(-w * 0.45, 0, w * 0.9, w * 0.14), Color.WHITE)
		"o":
			ci.draw_circle(Vector2.ZERO, w * 0.36 + 2.5, OUT)
			ci.draw_circle(Vector2.ZERO, w * 0.36, Color("5a1030"))
		"frown":
			ci.draw_arc(Vector2(0, w * 0.5), w * 0.6, PI + 0.4, TAU - 0.4, 12, OUT, 3.5, true)
		"fang":
			ci.draw_arc(Vector2(0, -w * 0.3), w * 0.6, 0.35, PI - 0.35, 12, OUT, 3.5, true)
			for s in [-1.0, 1.0]:
				_outlined(ci, PackedVector2Array([Vector2(w * 0.3 * s - 3, 2), Vector2(w * 0.3 * s + 3, 2), Vector2(w * 0.3 * s, 9)]), Color.WHITE, 1.8, OUT)
		"tongue":
			ci.draw_arc(Vector2(0, -w * 0.3), w * 0.6, 0.35, PI - 0.35, 12, OUT, 3.5, true)
			_outlined(ci, _ell(w * 0.22, w * 0.3, 0.0, 0.0) + PackedVector2Array([]), Color("ff7a9a"), 2.5, OUT) if false else ci.draw_circle(Vector2(w * 0.2, w * 0.3), w * 0.2, Color("ff7a9a"))
		"flat":
			ci.draw_line(Vector2(-w * 0.5, 0), Vector2(w * 0.5, 0), OUT, 3.5, true)
		"zig":
			ci.draw_polyline(PackedVector2Array([Vector2(-w * 0.6, 0), Vector2(-w * 0.3, w * 0.25), Vector2(0, 0), Vector2(w * 0.3, w * 0.25), Vector2(w * 0.6, 0)]), OUT, 3.5, true)
