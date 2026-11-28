class_name CreatureArt
extends RefCounted
## Procedural creature illustration. Local space: creature faces +X. Everything is driven by the
## phenotype dictionary (so inherited anatomy is visible) and a pose dictionary (animation).
## pose: rot (heading, for world-space lighting), t (time), phase (gait), spd (0..1), turn (-1..1),
##       atk (0..1), hurt (0..1), flap (0..1), flying(bool), breath(0..1), eat(0..1)

static func hsh(seed_: int, i: int) -> float:
	var x := (seed_ * 73856093) ^ (i * 19349663) ^ 0x5bd1e995
	x = (x ^ (x >> 13)) * 1274126177
	x = x ^ (x >> 16)
	return float(absi(x) % 10007) / 10007.0

static func draw(item: CanvasItem, ph: Dictionary, pose: Dictionary) -> void:
	var rid := item.get_canvas_item()
	var rot: float = pose.get("rot", 0.0)
	_shadow(item, ph, pose)
	var under := Ink.Batch.new()
	var over := Ink.Batch.new()
	match ph["bp"]:
		Genome.BP.QUAD: _quad(item, rid, under, over, ph, pose, false)
		Genome.BP.REPTILE: _quad(item, rid, under, over, ph, pose, true)
		Genome.BP.ARACH: _arach(item, rid, under, over, ph, pose)
		Genome.BP.INSECT: _insect(item, rid, under, over, ph, pose)
		Genome.BP.AVIAN: _avian(item, rid, under, over, ph, pose)
		Genome.BP.AMPHIB: _amphib(item, rid, under, over, ph, pose)
		Genome.BP.FISH: _fish(item, rid, under, over, ph, pose)
	if pose.get("hurt", 0.0) > 0.01:
		var hh: float = pose["hurt"]
		var r: float = ph["L"] * 0.5
		item.draw_circle(Vector2.ZERO, r, Color(1, 0.3, 0.25, 0.35 * hh))

static func _shadow(item: CanvasItem, ph: Dictionary, pose: Dictionary) -> void:
	var rot: float = pose.get("rot", 0.0)
	var off := Vector2(3.0, 5.0).rotated(-rot)
	if pose.get("flying", false):
		off = Vector2(10.0, 18.0).rotated(-rot)
	var L: float = ph["L"]
	var pts := PackedVector2Array()
	for i in 20:
		var th := TAU * i / 20
		pts.append(off + Vector2(cos(th) * L * 0.5, sin(th) * ph["W"] * 1.05))
	item.draw_colored_polygon(pts, Color(0.05, 0.04, 0.12, 0.28 if not pose.get("flying", false) else 0.16))

# ---------------------------------------------------------------- helpers
static func _ik(hip: Vector2, foot: Vector2, l1: float, l2: float, side: float) -> Vector2:
	var d := hip.distance_to(foot)
	d = clampf(d, absf(l1 - l2) + 0.01, l1 + l2 - 0.01)
	var a := (l1 * l1 - l2 * l2 + d * d) / (2.0 * d)
	var h := sqrt(maxf(l1 * l1 - a * a, 0.0))
	var dir := (foot - hip).normalized()
	var mid := hip + dir * a
	return mid + Vector2(-dir.y, dir.x) * h * side

static func _eye(b: Ink.Batch, item: CanvasItem, p: Vector2, r: float, pal: Dictionary, rot: float, slit: bool = false) -> void:
	Ink.dome(b, p, r, r, 0.0, Color(0.96, 0.93, 0.82), rot, 12)
	Ink.dome(b, p + Vector2(r * 0.12, 0), r * 0.68, r * 0.68 * (0.45 if slit else 1.0), 0.0, pal["eye"], rot, 12)
	Ink.dome(b, p + Vector2(r * 0.18, 0), r * 0.38, r * 0.38 * (0.35 if slit else 1.0), 0.0, Color(0.05, 0.04, 0.08), rot, 10)

static func _eye_hi(item: CanvasItem, p: Vector2, r: float) -> void:
	item.draw_circle(p + Vector2(r * 0.05, -r * 0.3), maxf(r * 0.17, 0.5), Color(1, 1, 1, 0.9))

static func _line_w(ph: Dictionary) -> float:
	return clampf(ph["L"] * 0.026, 1.1, 3.4)

static func _pattern_fn(ph: Dictionary) -> Callable:
	var pal: Dictionary = ph["pal"]
	var kind: int = ph["pat"]
	var inten: float = ph["pat_i"]
	var dark: Color = pal["dark"]
	var acc: Color = pal["accent"]
	var seed_: int = ph.get("seed", 1)
	var cnt := 4 + int(hsh(seed_, 3) * 6.0)
	return func(t: float, u: float, col: Color) -> Color:
		match kind:
			1:  # stripes
				if sin(t * PI * cnt * 1.3) > 0.35:
					return col.lerp(dark, 0.35 + 0.5 * inten)
			3:  # dorsal saddle
				if absf(u) < 0.5 and t > 0.3 and t < 0.85:
					return col.lerp(acc, 0.35 + 0.45 * inten)
			4:  # tail/limb bands + dorsal line
				if t > 0.6 and sin(t * PI * 9.0) > 0.2:
					return col.lerp(dark, 0.55 * (0.4 + inten))
				if absf(u) < 0.14:
					return col.lerp(dark, 0.45)
		return col

static func _spots(item: CanvasItem, b: Ink.Batch, ph: Dictionary, spine: PackedVector2Array, widths: PackedFloat32Array, pose: Dictionary) -> void:
	if ph["pat"] != 2:
		return
	var pal: Dictionary = ph["pal"]
	var n := spine.size()
	var seed_: int = ph.get("seed", 1)
	var cnt := 6 + int(ph["pat_i"] * 14.0)
	for k in cnt:
		var i := 2 + int(hsh(seed_, k) * (n - 4))
		var u := (hsh(seed_, k + 99) - 0.5) * 1.5
		var p: Vector2 = spine[i] + Vector2(0, u * widths[i])
		var r: float = maxf(widths[i] * (0.12 + hsh(seed_, k + 7) * 0.2), 1.2)
		var sc: Color = pal["accent"].lerp(pal["dark"], 0.35)
		sc.a = 0.7
		item.draw_circle(p, r, sc)

static func _fur(item: CanvasItem, ph: Dictionary, left: PackedVector2Array, right: PackedVector2Array, pal: Dictionary) -> void:
	var f: float = ph["fur"]
	if f < 0.2:
		return
	var seed_: int = ph.get("seed", 1)
	var col: Color = pal["base"].darkened(0.1)
	col.a = 0.45
	var n := left.size()
	var len_: float = ph["L"] * (0.015 + 0.03 * f)
	for i in range(1, n - 1):
		if hsh(seed_, i) < 0.75 * f + 0.2:
			for side in [left, right]:
				var p: Vector2 = side[i]
				var dir: Vector2 = (side[mini(i + 1, n - 1)] - side[maxi(i - 1, 0)]).normalized()
				var nrm := Vector2(-dir.y, dir.x) * (-1.0 if side == left else 1.0)
				# tufts sweep backwards
				item.draw_line(p, p + nrm * len_ - dir * len_ * 0.6, col, maxf(1.0, ph["L"] * 0.02), true)

static func _paw(b: Ink.Batch, item: CanvasItem, p: Vector2, r: float, base: Color, rot: float, claw: float, lift: float) -> void:
	Ink.dome(b, p, r * (1.0 + lift * 0.25), r * (0.85 + lift * 0.2), 0.0, base.lightened(0.04 + lift * 0.1), rot, 10)
	if claw > 0.05:
		var ink := Ink.ink_color(base)
		for k in 3:
			var a := (k - 1) * 0.42
			item.draw_line(p + Vector2(cos(a), sin(a)) * r * 0.7, p + Vector2(cos(a), sin(a)) * (r * 0.7 + r * (0.5 + claw * 1.3)), Color(0.9, 0.88, 0.8), maxf(1.0, r * 0.28), true)

static func _undulate(t: float, phase: float, amp: float) -> float:
	return sin(t * 5.2 - phase) * amp * (0.25 + 0.75 * t)

# ---------------------------------------------------------------- quadruped / reptile
static func _quad(item: CanvasItem, rid: RID, under: Ink.Batch, over: Ink.Batch, ph: Dictionary, pose: Dictionary, reptile: bool) -> void:
	var pal: Dictionary = ph["pal"]
	var rot: float = pose.get("rot", 0.0)
	var L: float = ph["L"]
	var W: float = ph["W"] * (0.8 if reptile else 1.0)
	var phase: float = pose.get("phase", 0.0)
	var spd: float = pose.get("spd", 0.0)
	var turn: float = pose.get("turn", 0.0)
	var atk: float = pose.get("atk", 0.0)
	var breath := sin(pose.get("t", 0.0) * 2.2) * 0.02
	var ink: Color = pal["ink"]
	var lw := _line_w(ph)
	var hf: float = 0.24 + 0.12 * ph["snout"] + (0.04 if reptile else 0.0)
	var hr: float = maxf(ph["head_r"], W * (0.8 if reptile else 0.95))
	var N := 18
	var spine := PackedVector2Array(); var widths := PackedFloat32Array()
	var amp := L * (0.07 if reptile else 0.025) * (0.3 + spd)
	for i in N:
		var t := float(i) / (N - 1)
		var x := L * (0.5 - t) + atk * L * 0.1 * (1.0 - t)
		var y := _undulate(t, phase, amp) + turn * L * 0.12 * t * t
		spine.append(Vector2(x, y))
		var w: float
		if t < hf:
			var k := t / hf
			if k < 0.7:
				w = hr * (0.2 + 0.85 * smoothstep(0.0, 1.0, k / 0.7))
				if ph["snout"] > 0.5: w = hr * (0.16 + 0.89 * pow(k / 0.7, 1.4))
			else:
				w = hr * lerpf(1.05, 0.7, smoothstep(0.0, 1.0, (k - 0.7) / 0.3))
		elif t < hf + 0.09:
			var k2 := (t - hf) / 0.09
			w = lerpf(hr * 0.7, W * 0.85, smoothstep(0.0, 1.0, k2))
		else:
			var k3 := (t - hf - 0.1) / (1.0 - hf - 0.1)
			w = W * (0.82 + 0.18 * sin(k3 * PI * 0.9)) * (1.0 - 0.6 * pow(k3, 3.0)) * (1.0 + breath)
		widths.append(maxf(w, 0.8))
	var spl := Ink.smooth(Array(spine), 3)
	var wl := PackedFloat32Array()
	for i in spl.size():
		var f := float(i) / (spl.size() - 1) * (N - 1)
		var i0 := int(f); var i1 := mini(i0 + 1, N - 1)
		wl.append(lerpf(widths[i0], widths[i1], f - i0))
	# --- tail (behind body)
	var tail_pts: Array = []
	var tl: float = ph["tail_len"]
	var tail_w := W * (0.5 if not ph["swims"] else 0.9)
	var rear: Vector2 = spine[N - 1]
	var tn := 8
	var tw := PackedFloat32Array()
	for i in tn:
		var t := float(i) / (tn - 1)
		var sway := sin(pose.get("t", 0.0) * 3.0 - t * 3.0 + phase * 0.5) * L * 0.07 * (0.3 + t) - turn * L * 0.12 * t
		tail_pts.append(rear + Vector2(-t * tl, sway + (L * 0.0)))
		var base_w := tail_w * (1.0 - 0.8 * t)
		if ph["swims"] and ph["aqua"] > 0.55:
			base_w = tail_w * (0.35 + 0.95 * pow(sin(clampf(t * 0.95 + 0.04, 0.0, 1.0) * PI), 0.7)) * (1.0 - 0.85 * pow(t, 4.0))
		elif ph["fur"] > 0.6 and not reptile:
			base_w = tail_w * (0.8 + 0.5 * sin(t * PI)) * (1.0 - 0.7 * pow(t, 2.5))
		tw.append(maxf(base_w, 0.8))
	var tsp := Ink.smooth(tail_pts, 3)
	var tws := PackedFloat32Array()
	for i in tsp.size():
		var f := float(i) / (tsp.size() - 1) * (tn - 1)
		var i0 := int(f); var i1 := mini(i0 + 1, tn - 1)
		tws.append(lerpf(tw[i0], tw[i1], f - i0))
	var tail_col: Color = pal["base"]
	var tr := Ink.strip(under, tsp, tws, tail_col.lerp(pal["dark"], 0.25), rot, Color(0, 0, 0, 0), _pattern_fn(ph) if ph["pat"] == 4 else Callable(), 5)
	# --- legs (under body)
	var stride: float = ph["limb_len"] * (0.45 if not reptile else 0.35)
	var l1: float = ph["limb_len"] * 0.55
	var l2: float = ph["limb_len"] * 0.62
	var lw0: float = ph["limb_w"] * 1.1
	var legs := [[0.4, 1, 0.0], [0.4, -1, PI], [0.78, 1, PI], [0.78, -1, 0.0]]
	var limb_col: Color = pal["base"].lerp(pal["dark"], 0.25)
	var splay := (1.5 if reptile else 1.0)
	for lg in legs:
		var ti: float = lg[0]
		var side: float = lg[1]
		var pi_ := int(ti * (N - 1))
		var sp: Vector2 = spine[pi_]
		var hip := sp + Vector2(0, side * widths[pi_] * 0.8)
		var ph_ := phase * 1.0 + float(lg[2])
		var swing: float = cos(ph_) * stride * (0.2 + spd)
		var lift := maxf(0.0, sin(ph_)) * spd
		var foot := Vector2(sp.x + swing, side * (widths[pi_] * 1.05 + ph["limb_len"] * 0.5 * splay)) + Vector2(0, 0)
		if reptile:
			foot.y += side * L * 0.04
		var knee := _ik(hip, foot, l1, l2, -side)
		Ink.limb(under, hip, knee, lw0 * 1.25, lw0 * 0.85, limb_col, rot)
		Ink.limb(under, knee, foot, lw0 * 0.85, lw0 * 0.7, limb_col, rot)
		_paw(under, item, foot, lw0 * (0.8 if not ph["swims"] else 1.15), limb_col.lightened(0.05), rot, ph["burrow"] if ph["burrow"] > 0.3 else 0.3, lift)
	# --- body
	var patfn := _pattern_fn(ph)
	var body := Ink.strip(over, spl, wl, pal["base"], rot, pal["belly"], patfn if ph["pat"] != 2 else Callable(), 5)
	# --- armor scutes
	if ph["armor"] > 0.72:
		var cnt := 5 + int(ph["armor"] * 6)
		for k in cnt:
			var t := lerpf(hf + 0.12, 0.92, float(k) / cnt)
			var i := int(t * (spl.size() - 1))
			var r := wl[i] * (0.55 + 0.15 * sin(k * 1.7))
			Ink.dome(over, spl[i], r * 0.9, r * 1.05, 0.0, pal["dark"].lightened(0.12 + ph["armor"] * 0.1), rot, 10)
	# --- head details
	var head_i := int(hf * 0.55 * (spl.size() - 1))
	var hp: Vector2 = spl[head_i]
	# ears (drawn behind the cranium so only the outer lobe shows)
	var er: float = ph["ear"]
	if er > 0.05:
		var ep: Vector2 = spl[int(hf * 0.8 * (spl.size() - 1))]
		for s in [-1, 1]:
			var elen: float = hr * (0.55 + 1.1 * er)
			var ex: Vector2 = ep + Vector2(-hr * 0.25, s * hr * 1.08)
			Ink.dome(under, ex, elen * 0.62, elen * 0.5, s * 0.9, pal["base"].lerp(pal["dark"], 0.15), rot, 14)
			Ink.dome(under, ex + Vector2(0, s * elen * 0.06), elen * 0.4, elen * 0.28, s * 0.9, pal["accent"].lightened(0.25), rot, 10)
	# eyes
	var er2: float = hr * (0.2 + 0.13 * ph["eye_size"])
	var eyepos := spl[int(hf * 0.66 * (spl.size() - 1))]
	var eyes_slit: bool = reptile or ph["pat"] == 1 and ph["climb"] > 0.5
	var epos := [eyepos + Vector2(0, hr * 0.62), eyepos + Vector2(0, -hr * 0.62)]
	# nose
	var nose_p: Vector2 = spl[0]
	Ink.dome(over, nose_p + Vector2(-hr * 0.15, 0), hr * 0.22, hr * 0.18, 0.0, Color(0.1, 0.07, 0.1), rot, 8)
	# flush batches then draw outlines + ink details on top in order
	under.flush(rid)
	Ink.outline_poly(item, tr["left"], tr["right"], ink, lw)
	over.flush(rid)
	Ink.outline_poly(item, body["left"], body["right"], ink, lw)
	_spots(item, over, ph, spl, wl, pose)
	var eb := Ink.Batch.new()
	for ep2 in epos:
		_eye(eb, item, ep2, er2, pal, rot, eyes_slit)
	eb.flush(rid)
	for ep2 in epos:
		_eye_hi(item, ep2, er2)
	_fur(item, ph, body["left"], body["right"], pal)
	if ph["snout"] > 0.3 and not reptile:  # whiskers
		for s in [-1, 1]:
			for k in 2:
				item.draw_line(spl[1] + Vector2(-hr * 0.1, s * hr * 0.2), spl[1] + Vector2(hr * 0.5, s * hr * (0.9 + k * 0.5)) + Vector2(-hr * 0.2, 0), Color(1, 1, 1, 0.55), 0.9, true)
	if reptile and fmod(pose.get("t", 0.0), 2.4) < 0.3:  # tongue flick
		var tp := spl[0] + Vector2(hr * 0.1, 0)
		item.draw_line(tp, tp + Vector2(hr * 1.2, 0), Color(0.85, 0.2, 0.3), 1.2, true)
		item.draw_line(tp + Vector2(hr * 1.2, 0), tp + Vector2(hr * 1.6, hr * 0.3), Color(0.85, 0.2, 0.3), 1.0, true)
		item.draw_line(tp + Vector2(hr * 1.2, 0), tp + Vector2(hr * 1.6, -hr * 0.3), Color(0.85, 0.2, 0.3), 1.0, true)

# ---------------------------------------------------------------- arachnid
static func _arach(item: CanvasItem, rid: RID, under: Ink.Batch, over: Ink.Batch, ph: Dictionary, pose: Dictionary) -> void:
	var pal: Dictionary = ph["pal"]
	var rot: float = pose.get("rot", 0.0)
	var L: float = ph["L"]
	var phase: float = pose.get("phase", 0.0)
	var spd: float = pose.get("spd", 0.0)
	var ink: Color = pal["ink"]
	var lw := _line_w(ph)
	var ct := Vector2(L * 0.2, 0)            # cephalothorax
	var ab := Vector2(-L * 0.22, 0)          # abdomen
	var crx: float = L * 0.2; var cry: float = L * 0.17
	var arx: float = L * (0.27 + 0.05 * ph["W"] / L * 4.0); var ary: float = L * (0.22 + 0.1 * ph["armor"])
	# legs: 4 per side, 3 bone IK-ish (femur up, tibia down)
	var ll: float = ph["limb_len"] * 1.45
	var leg_w: float = maxf(ph["limb_w"] * 0.5, 1.0)
	var limb_col: Color = pal["base"].lerp(pal["dark"], 0.35)
	for side in [-1, 1]:
		for k in 4:
			var ang: float = lerpf(0.75, 2.45, float(k) / 3.0)  # radial around body front->back
			var ph_ := phase * 1.0 + (PI if (k + (0 if side > 0 else 1)) % 2 == 0 else 0.0)
			var reach := ll * (1.0 + 0.1 * sin(k))
			var dir := Vector2(cos(ang - 0.5 * (k - 1.5) * 0.18), side * sin(ang))
			var anchor := ct + Vector2(-crx * 0.1 + (k - 1.5) * -crx * 0.16, side * cry * 0.6)
			var foot := anchor + dir * reach * 1.15 + Vector2(cos(ph_) * reach * 0.18 * (0.15 + spd), 0)
			var mid := anchor + Vector2(dir.x * reach * 0.45, side * reach * 0.62 + side * reach * 0.0) + Vector2(0, side * (4.0 + 3.0 * maxf(0.0, sin(ph_)) * spd))
			Ink.limb(under, anchor, mid, leg_w * 1.5, leg_w * 1.1, limb_col, rot)
			Ink.limb(under, mid, foot, leg_w * 1.1, leg_w * 0.5, limb_col.darkened(0.1), rot)
			Ink.dome(under, mid, leg_w * 1.2, leg_w * 1.2, 0.0, limb_col.lightened(0.1), rot, 8)
	under.flush(rid)
	# abdomen with markings
	var patfn := func(p: Vector2, col: Color) -> Color:
		match ph["pat"]:
			1:
				if sin(p.x * 0.5 / maxf(L * 0.05, 1.0) * 3.0) > 0.4: return col.lerp(pal["dark"], 0.5)
			3, 4:
				if absf(p.y) < ary * 0.3 and p.x < arx * 0.6: return col.lerp(pal["accent"], 0.7)
			2:
				if fmod(absf(p.x) * 0.15 + absf(p.y) * 0.11, 2.0) < 0.5: return col.lerp(pal["accent"], 0.5)
		return col
	Ink.dome(over, ab, arx, ary, 0.0, pal["base"], rot, 24, patfn)
	Ink.dome(over, ct, crx, cry, 0.0, pal["base"].lerp(pal["dark"], 0.15), rot, 20)
	# waist
	Ink.dome(over, (ct + ab) * 0.5 + Vector2(L * 0.01, 0), L * 0.06, L * 0.06, 0.0, pal["dark"], rot, 10)
	over.flush(rid)
	Ink.dome_outline(item, ab, arx, ary, 0.0, ink, lw)
	Ink.dome_outline(item, ct, crx, cry, 0.0, ink, lw)
	# eyes cluster + fangs
	var eb := Ink.Batch.new()
	var er: float = cry * 0.17 * (0.6 + ph["eye_size"])
	for k in 4:
		for s in [-1, 1]:
			var p := ct + Vector2(crx * (0.62 - 0.12 * (k % 2)), s * cry * (0.18 + 0.2 * (k / 2.0)))
			Ink.dome(eb, p, er * (1.0 if k < 2 else 0.7), er * (1.0 if k < 2 else 0.7), 0.0, Color(0.07, 0.05, 0.1), rot, 8)
	eb.flush(rid)
	for s in [-1, 1]:
		var fp := ct + Vector2(crx * 0.95, s * cry * 0.2)
		item.draw_line(fp, fp + Vector2(cry * 0.55, s * cry * 0.18), Color(0.85, 0.78, 0.6), maxf(lw, 1.4), true)
		var pp := ct + Vector2(crx * 0.8, s * cry * 0.55)   # pedipalps
		item.draw_line(pp, pp + Vector2(cry * 0.7, s * cry * 0.2), limb_col.lightened(0.15), maxf(leg_w, 1.2), true)
	for k in 5:
		_eye_hi(item, ct + Vector2(crx * 0.6, (k - 2) * cry * 0.16), er * 0.7)

# ---------------------------------------------------------------- insect
static func _insect(item: CanvasItem, rid: RID, under: Ink.Batch, over: Ink.Batch, ph: Dictionary, pose: Dictionary) -> void:
	var pal: Dictionary = ph["pal"]
	var rot: float = pose.get("rot", 0.0)
	var L: float = ph["L"]
	var phase: float = pose.get("phase", 0.0)
	var spd: float = pose.get("spd", 0.0)
	var ink: Color = pal["ink"]
	var lw := _line_w(ph)
	var hd := Vector2(L * 0.38, 0); var th := Vector2(L * 0.08, 0); var ab := Vector2(-L * 0.28, sin(phase * 0.5) * L * 0.02 * spd)
	var hrx: float = L * 0.15 * (0.8 + ph["head_r"] / L * 4.0); var hry := hrx * 0.95
	var trx := L * 0.17; var try_ := L * 0.13
	var arx := L * 0.3 * lerpf(0.85, 1.2, ph["W"] / L * 4.0); var ary := L * 0.17 * lerpf(0.9, 1.3, ph["armor"])
	var limb_col: Color = pal["dark"].lerp(pal["base"], 0.3)
	var lw0 := maxf(ph["limb_w"] * 0.55, 1.1)
	var ll: float = ph["limb_len"] * 1.15
	# legs 3 per side, tripod gait
	for side in [-1, 1]:
		for k in 3:
			var anchor := th + Vector2((1 - k) * trx * 0.55, side * try_ * 0.6)
			var ph_ := phase + (PI if (k + (0 if side > 0 else 1)) % 2 == 0 else 0.0)
			var ang: float = [0.45, 1.5, 2.45][k]
			var dir := Vector2(cos(ang) * (1.0 if k != 2 else 1.0) * (1.0 if k < 2 else -1.0) * 0.0 + (0.7 if k == 0 else (0.0 if k == 1 else -0.7)), side * 1.0).normalized()
			var foot := anchor + dir * ll * 1.5 + Vector2(cos(ph_) * ll * 0.25 * (0.2 + spd), 0)
			var knee := anchor + Vector2(dir.x * ll * 0.5, side * ll * 0.78) + Vector2(0, side * 3.0 * maxf(0.0, sin(ph_)) * spd)
			Ink.limb(under, anchor, knee, lw0 * 1.3, lw0, limb_col, rot)
			Ink.limb(under, knee, foot, lw0, lw0 * 0.55, limb_col, rot)
			Ink.dome(under, knee, lw0 * 1.1, lw0 * 1.1, 0.0, limb_col.lightened(0.12), rot, 8)
	under.flush(rid)
	# antennae
	var asz: float = lerpf(0.55, 1.25, clampf(ph["smell"] / 360.0, 0.0, 1.0))
	for s in [-1, 1]:
		var ap := hd + Vector2(hrx * 0.7, s * hry * 0.4)
		var wob := sin(pose.get("t", 0.0) * 4.0 + s) * 0.12
		var mid := ap + Vector2(L * 0.14 * asz, s * L * 0.1 * asz + wob * L * 0.1)
		var tip := mid + Vector2(L * 0.12 * asz, s * L * 0.07 * asz - wob * L * 0.1)
		var apts := Ink.smooth([ap, mid, tip], 5)
		item.draw_polyline(apts, ink, maxf(lw * 0.8, 1.0), true)
	# wings (translucent)
	if ph["flies"]:
		var fl: float = 0.6 + 0.4 * sin(pose.get("t", 0.0) * 40.0) * (1.0 if pose.get("flying", false) else 0.15)
		for s in [-1, 1]:
			var wp := PackedVector2Array()
			for i in 16:
				var a := TAU * i / 16
				wp.append(th + Vector2(-L * 0.18 + cos(a) * L * 0.34, s * (try_ * 0.8 + (sin(a) * 0.5 + 0.5) * L * 0.55 * fl)))
			item.draw_colored_polygon(wp, Color(pal["accent"].r, pal["accent"].g, pal["accent"].b, 0.28))
			item.draw_polyline(wp, Color(ink.r, ink.g, ink.b, 0.5), 1.0, true)
	# body segments
	var armor_col: Color = pal["base"]
	var patfn := func(p: Vector2, col: Color) -> Color:
		if ph["pat"] == 1 and sin(p.x * 0.55) > 0.3: return col.lerp(pal["dark"], 0.6)
		if ph["pat"] == 3 and absf(p.y) < ary * 0.4: return col.lerp(pal["accent"], 0.6)
		return col
	Ink.dome(over, ab, arx, ary, 0.0, armor_col, rot, 22, patfn)
	Ink.dome(over, th, trx, try_, 0.0, armor_col.lerp(pal["dark"], 0.12), rot, 18)
	Ink.dome(over, hd, hrx, hry, 0.0, armor_col.lerp(pal["dark"], 0.08), rot, 18)
	over.flush(rid)
	Ink.dome_outline(item, ab, arx, ary, 0.0, ink, lw)
	Ink.dome_outline(item, th, trx, try_, 0.0, ink, lw)
	Ink.dome_outline(item, hd, hrx, hry, 0.0, ink, lw)
	# compound eyes + mandibles
	var eb := Ink.Batch.new()
	for s in [-1, 1]:
		Ink.dome(eb, hd + Vector2(hrx * 0.1, s * hry * 0.62), hrx * 0.38 * (0.7 + ph["eye_size"] * 0.5), hry * 0.42, 0.0, Color(0.12, 0.07, 0.1), rot, 10)
	eb.flush(rid)
	for s in [-1, 1]:
		_eye_hi(item, hd + Vector2(hrx * 0.1, s * hry * 0.62), hrx * 0.38)
		var mp := hd + Vector2(hrx * 0.95, s * hry * 0.28)
		var mlen := hrx * (0.5 + 0.9 * clampf(ph["bite"] / 2.0, 0.0, 1.0))
		item.draw_polyline(Ink.smooth([mp, mp + Vector2(mlen * 0.6, s * mlen * 0.1), mp + Vector2(mlen, -s * mlen * 0.35)], 4), Color(0.92, 0.84, 0.66), maxf(lw * 0.9, 1.2), true)

# ---------------------------------------------------------------- avian
static func _avian(item: CanvasItem, rid: RID, under: Ink.Batch, over: Ink.Batch, ph: Dictionary, pose: Dictionary) -> void:
	var pal: Dictionary = ph["pal"]
	var rot: float = pose.get("rot", 0.0)
	var L: float = ph["L"]
	var flying: bool = pose.get("flying", false)
	var flap: float = pose.get("flap", 0.0)
	var spd: float = pose.get("spd", 0.0)
	var phase: float = pose.get("phase", 0.0)
	var ink: Color = pal["ink"]
	var lw := _line_w(ph)
	var bx := Vector2(-L * 0.02, 0)
	var brx := L * 0.34; var bry := L * 0.2 * lerpf(0.9, 1.25, ph["W"] / L * 4.0)
	var head := Vector2(L * 0.3, 0)
	var hr: float = ph["head_r"] * 1.15
	# feet (hopping)
	if not flying:
		for s in [-1, 1]:
			var hop := sin(phase + (PI if s > 0 else 0.0)) * L * 0.1 * spd
			var fp := Vector2(L * 0.0 + hop, s * bry * 0.55)
			item.draw_line(fp, fp + Vector2(L * 0.15, 0), pal["accent"].darkened(0.1), maxf(lw * 1.1, 1.4), true)
			for k in 3:
				item.draw_line(fp + Vector2(L * 0.15, 0), fp + Vector2(L * 0.24, (k - 1) * L * 0.04), pal["accent"].darkened(0.1), maxf(lw * 0.8, 1.1), true)
	# tail fan
	var tl: float = ph["tail_len"] * 0.8 + L * 0.18
	var fan := 3 + int(ph["armor"] * 0)
	var tcol: Color = pal["base"].lerp(pal["dark"], 0.35)
	for i in 7:
		var a := (float(i) / 6.0 - 0.5) * (0.55 + 0.35 * spd) + sin(pose.get("t", 0.0) * 2.0) * 0.04
		var p0 := bx + Vector2(-brx * 0.8, 0)
		var p1 := p0 + Vector2(cos(PI + a), sin(PI + a)) * tl
		Ink.limb(under, p0, p1, L * 0.035, L * 0.055, tcol.lerp(pal["accent"], 0.12 if i % 2 == 0 else 0.0), rot)
	under.flush(rid)
	# wings
	var wspan: float = L * (0.7 + 1.0 * ph["wing"])
	var wcol: Color = pal["base"].lerp(pal["dark"], 0.18)
	for s in [-1, 1]:
		var shoulder := bx + Vector2(L * 0.1, s * bry * 0.7)
		if flying:
			var fa := sin(pose.get("t", 0.0) * 14.0) * 0.5 * (0.4 + flap)
			var wl := wspan * (0.85 + 0.15 * cos(pose.get("t", 0.0) * 14.0))
			var tip := shoulder + Vector2(-wl * 0.25, s * wl * 0.55 * cos(fa))
			# primaries fan
			for k in 7:
				var f := float(k) / 6.0
				var root := shoulder.lerp(tip, f * 0.7) + Vector2(-f * L * 0.2, 0)
				var ft := root + Vector2(-wl * (0.45 - f * 0.2), s * wl * (0.1 + (1.0 - f) * 0.35 * cos(fa)))
				Ink.limb(over, root, ft, L * 0.06, L * 0.035, wcol.lerp(pal["accent"], 0.15 * f), rot)
			Ink.dome(over, shoulder + Vector2(-L * 0.12, s * wl * 0.13), L * 0.2, wl * 0.2, s * 0.9, wcol, rot, 14)
		else:
			# folded wing: layered feather ovals lying along the flank
			for k in 5:
				var f := float(k) / 4.0
				var c := bx + Vector2(L * 0.12 - f * L * 0.38, s * (bry * 0.62 - f * bry * 0.1))
				Ink.dome(over, c, L * (0.2 - 0.02 * f), L * 0.09, s * 0.12, wcol.lerp(pal["accent"], 0.08 * f).lightened(0.03 * (4 - k)), rot, 12)
	Ink.dome(over, bx, brx, bry, 0.0, pal["base"], rot, 22, func(p: Vector2, col: Color) -> Color:
		return col.lerp(pal["belly"], smoothstep(0.1, 1.0, p.x / (brx * 1.0) + 0.5) * 0.6))
	# re-draw wings over body for flying/folded: simple second pass of folded wings
	if not flying:
		for s in [-1, 1]:
			for k in 5:
				var f := float(k) / 4.0
				var c := bx + Vector2(L * 0.12 - f * L * 0.38, s * (bry * 0.5 - f * bry * 0.1))
				Ink.dome(over, c, L * (0.2 - 0.02 * f), L * 0.085, s * 0.1, wcol.lerp(pal["accent"], 0.1 * f).lightened(0.02 * (4 - k)), rot, 12)
	Ink.dome(over, head, hr, hr * 0.92, 0.0, pal["base"].lerp(pal["dark"], 0.1), rot, 18)
	over.flush(rid)
	Ink.dome_outline(item, bx, brx, bry, 0.0, ink, lw)
	Ink.dome_outline(item, head, hr, hr * 0.92, 0.0, ink, lw)
	# beak
	var bl: float = hr * (0.9 + 0.9 * ph["snout"])
	var bpts := PackedVector2Array([head + Vector2(hr * 0.75, -hr * 0.42), head + Vector2(hr * 0.75 + bl, 0), head + Vector2(hr * 0.75, hr * 0.42)])
	item.draw_colored_polygon(bpts, pal["accent"].lerp(Color(0.95, 0.8, 0.3), 0.35))
	item.draw_polyline(PackedVector2Array([bpts[0], bpts[1], bpts[2], bpts[0]]), ink, lw, true)
	item.draw_line(head + Vector2(hr * 0.8, 0), head + Vector2(hr * 0.75 + bl * 0.9, 0), ink, maxf(lw * 0.6, 0.8), true)
	var eb := Ink.Batch.new()
	for s in [-1, 1]:
		Ink.dome(eb, head + Vector2(hr * 0.3, s * hr * 0.6), hr * 0.28, hr * 0.28, 0.0, pal["eye"], rot, 10)
		Ink.dome(eb, head + Vector2(hr * 0.35, s * hr * 0.6), hr * 0.15, hr * 0.15, 0.0, Color(0.05, 0.04, 0.08), rot, 8)
	eb.flush(rid)
	for s in [-1, 1]:
		_eye_hi(item, head + Vector2(hr * 0.3, s * hr * 0.6), hr * 0.28)

# ---------------------------------------------------------------- amphibian
static func _amphib(item: CanvasItem, rid: RID, under: Ink.Batch, over: Ink.Batch, ph: Dictionary, pose: Dictionary) -> void:
	var pal: Dictionary = ph["pal"]
	var rot: float = pose.get("rot", 0.0)
	var L: float = ph["L"]
	var spd: float = pose.get("spd", 0.0)
	var phase: float = pose.get("phase", 0.0)
	var ink: Color = pal["ink"]
	var lw := _line_w(ph)
	var hop := maxf(0.0, sin(phase)) * spd
	var limb_col: Color = pal["base"].lerp(pal["dark"], 0.2)
	var brx := L * 0.3; var bry := L * 0.27 * lerpf(0.9, 1.2, ph["W"] / L * 4.0)
	var bc := Vector2(-L * 0.12, 0)
	var head := Vector2(L * 0.22, 0)
	var hrx := L * 0.25; var hry := L * 0.25
	var lw0: float = ph["limb_w"]
	var ll: float = ph["limb_len"] * 1.2
	for s in [-1, 1]:
		# hind leg: folded Z, extends on hop
		var hip := bc + Vector2(-brx * 0.5, s * bry * 0.7)
		var ext := 0.35 + 0.65 * hop
		var foot := hip + Vector2(-ll * (0.5 + 0.9 * ext), s * ll * (0.95 - 0.45 * ext))
		var knee := hip + Vector2(ll * (0.15 - 0.2 * ext), s * ll * (0.85 + 0.1 * ext))
		Ink.limb(under, hip, knee, lw0 * 2.0, lw0 * 1.3, limb_col, rot)
		Ink.limb(under, knee, foot, lw0 * 1.3, lw0 * 0.9, limb_col, rot)
		# webbed foot fan
		var fwide: float = lw0 * (2.2 + 4.0 * ph["aqua"])
		for k in 4:
			var a := (k - 1.5) * 0.45
			var tip: Vector2 = foot + Vector2(-cos(a), s * sin(absf(a)) * 0.6 * 0 + (k - 1.5) * 0.45 * s * 0.0).normalized() * fwide * 1.4 + Vector2(0, (k - 1.5) * fwide * 0.65)
			Ink.limb(under, foot, tip, lw0 * 0.6, lw0 * 0.45, limb_col.lightened(0.06), rot)
		# fore leg
		var fh := bc + Vector2(brx * 0.7, s * bry * 0.75)
		var ff := fh + Vector2(ll * 0.35 + cos(phase) * ll * 0.15 * spd, s * ll * 0.55)
		var fk := _ik(fh, ff, ll * 0.4, ll * 0.4, -s)
		Ink.limb(under, fh, fk, lw0 * 1.2, lw0, limb_col, rot)
		Ink.limb(under, fk, ff, lw0, lw0 * 0.7, limb_col, rot)
		for k in 3:
			Ink.limb(under, ff, ff + Vector2(lw0 * 1.6, (k - 1) * lw0 * 1.0), lw0 * 0.5, lw0 * 0.35, limb_col.lightened(0.1), rot)
	under.flush(rid)
	var patfn := func(p: Vector2, col: Color) -> Color:
		var n := sin(p.x * 0.31) * sin(p.y * 0.37 + p.x * 0.11)
		if ph["pat"] == 2 and n > 0.35: return col.lerp(pal["accent"], 0.55)
		if ph["pat"] == 1 and sin(p.x * 0.45) > 0.4: return col.lerp(pal["dark"], 0.5)
		if ph["pat"] >= 3 and absf(p.y) < bry * 0.35: return col.lerp(pal["accent"], 0.5)
		return col
	Ink.dome(over, bc, brx, bry, 0.0, pal["base"], rot, 24, patfn)
	# throat sac pulse
	var br := 1.0 + sin(pose.get("t", 0.0) * 3.0) * 0.06
	Ink.dome(over, head, hrx * br, hry * br, 0.0, pal["base"].lerp(pal["dark"], 0.06), rot, 24, patfn)
	over.flush(rid)
	Ink.dome_outline(item, bc, brx, bry, 0.0, ink, lw)
	Ink.dome_outline(item, head, hrx * br, hry * br, 0.0, ink, lw)
	# bulging eyes on top
	var eb := Ink.Batch.new()
	var er: float = hry * (0.3 + 0.15 * ph["eye_size"])
	for s in [-1, 1]:
		var ep := head + Vector2(hrx * 0.1, s * hry * 0.62)
		Ink.dome(eb, ep, er * 1.15, er * 1.15, 0.0, pal["base"].lerp(pal["dark"], 0.1), rot, 12)
		Ink.dome(eb, ep + Vector2(er * 0.1, 0), er * 0.85, er * 0.85, 0.0, pal["eye"], rot, 12)
		Ink.dome(eb, ep + Vector2(er * 0.15, 0), er * 0.5, er * 0.18, PI / 2.0, Color(0.05, 0.04, 0.08), rot, 10)
	eb.flush(rid)
	for s in [-1, 1]:
		var ep := head + Vector2(hrx * 0.1, s * hry * 0.62)
		item.draw_arc(ep, er * 1.15, 0, TAU, 14, ink, lw * 0.9, true)
		_eye_hi(item, ep, er)
	# mouth line + nostrils
	item.draw_arc(head + Vector2(hrx * 0.35, 0), hry * 0.7, -1.1, 1.1, 14, ink, maxf(lw * 0.8, 1.0), true)
	for s in [-1, 1]:
		item.draw_circle(head + Vector2(hrx * 0.85, s * hry * 0.17), maxf(hry * 0.04, 0.7), ink)

# ---------------------------------------------------------------- fish
static func _fish(item: CanvasItem, rid: RID, under: Ink.Batch, over: Ink.Batch, ph: Dictionary, pose: Dictionary) -> void:
	var pal: Dictionary = ph["pal"]
	var rot: float = pose.get("rot", 0.0)
	var L: float = ph["L"]
	var phase: float = pose.get("phase", 0.0)
	var spd: float = pose.get("spd", 0.0)
	var ink: Color = pal["ink"]
	var lw := _line_w(ph)
	var N := 16
	var spine := PackedVector2Array(); var widths := PackedFloat32Array()
	var W: float = ph["W"] * 1.1
	for i in N:
		var t := float(i) / (N - 1)
		var y := sin(t * 4.2 - phase) * L * 0.07 * (0.15 + spd) * (0.2 + t)
		spine.append(Vector2(L * (0.5 - t), y))
		widths.append(maxf(W * (pow(sin(clampf(t * 0.88 + 0.06, 0.0, 1.0) * PI), 0.8)) * (1.0 - 0.45 * t * t), 0.8))
	var tail_base := spine[N - 1]
	var tf: float = L * (0.2 + 0.25 * ph["tail_len"] / L)
	var fin_col: Color = pal["accent"].lerp(pal["base"], 0.3)
	# tail fin
	var tfp := PackedVector2Array([tail_base, tail_base + Vector2(-tf * 0.9, tf * 0.7), tail_base + Vector2(-tf * 0.6, 0), tail_base + Vector2(-tf * 0.9, -tf * 0.7)])
	item.draw_colored_polygon(tfp, Color(fin_col.r, fin_col.g, fin_col.b, 0.85))
	item.draw_polyline(PackedVector2Array([tfp[0], tfp[1], tfp[2], tfp[3], tfp[0]]), ink, lw, true)
	for s in [-1, 1]:
		var pf := spine[4] + Vector2(0, s * widths[4] * 0.8)
		var flapa := sin(pose.get("t", 0.0) * 5.0) * 0.3
		var pts := PackedVector2Array([pf, pf + Vector2(-L * 0.18, s * L * (0.2 + flapa * 0.1)), pf + Vector2(-L * 0.28, s * L * 0.05)])
		item.draw_colored_polygon(pts, Color(fin_col.r, fin_col.g, fin_col.b, 0.8))
		item.draw_polyline(PackedVector2Array([pts[0], pts[1], pts[2], pts[0]]), ink, lw * 0.8, true)
	var spl := Ink.smooth(Array(spine), 3)
	var wl := PackedFloat32Array()
	for i in spl.size():
		var f := float(i) / (spl.size() - 1) * (N - 1)
		var i0 := int(f); var i1 := mini(i0 + 1, N - 1)
		wl.append(lerpf(widths[i0], widths[i1], f - i0))
	var body := Ink.strip(over, spl, wl, pal["base"], rot, pal["belly"], _pattern_fn(ph), 5)
	# scale arcs
	over.flush(rid)
	Ink.outline_poly(item, body["left"], body["right"], ink, lw)
	var sc := Color(pal["dark"].r, pal["dark"].g, pal["dark"].b, 0.35)
	for i in range(6, spl.size() - 4, 2):
		for k in [-0.5, 0.0, 0.5]:
			item.draw_arc(spl[i] + Vector2(0, k * wl[i]), wl[i] * 0.4, -0.9, 0.9, 6, sc, 1.0, true)
	var ep := spl[4] + Vector2(0, W * 0.5)
	var eb := Ink.Batch.new()
	for s in [-1, 1]:
		_eye(eb, item, spl[3] + Vector2(0, s * wl[3] * 0.6), maxf(W * 0.28, 2.0) * (0.6 + 0.5 * ph["eye_size"]), pal, rot)
	eb.flush(rid)
