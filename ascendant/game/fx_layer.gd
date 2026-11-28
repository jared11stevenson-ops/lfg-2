class_name FxLayer
extends Node2D
## Lightweight world-space effects: rings, puffs, floating numbers.
var rings: Array = []
var texts: Array = []
func ring(p: Vector2, c: Color, r: float) -> void:
	rings.append({"p": p, "c": c, "r": r, "t": 0.0})
func text(p: Vector2, s: String, c: Color) -> void:
	texts.append({"p": p, "s": s, "c": c, "t": 0.0})
func _process(dt: float) -> void:
	for r in rings: r["t"] += dt * 2.2
	for t in texts: t["t"] += dt
	rings = rings.filter(func(r): return r["t"] < 1.0)
	texts = texts.filter(func(t): return t["t"] < 1.2)
	queue_redraw()
func _draw() -> void:
	for r in rings:
		var c: Color = r["c"]; c.a *= 1.0 - r["t"]
		draw_arc(r["p"], r["r"] * r["t"], 0, TAU, 32, c, 3.0, true)
	var f := ThemeDB.fallback_font
	for t in texts:
		var c: Color = t["c"]; c.a = 1.0 - t["t"] / 1.2
		draw_string(f, t["p"] + Vector2(-20, -30 - 40 * t["t"]), t["s"], HORIZONTAL_ALIGNMENT_LEFT, -1, 22, c)
