class_name Hud
extends Control
## Illuminated-manuscript HUD: parchment panels, ink outlines, gem bars.
var play: PlayScene
const PARCH := Color(0.93, 0.87, 0.72, 0.92)
const INK := Color(0.16, 0.12, 0.2)
const GOLD := Color(0.78, 0.6, 0.22)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE

func _process(_dt: float) -> void:
	queue_redraw()

func _panel(r: Rect2, a: float = 1.0) -> void:
	var sh := r; sh.position += Vector2(3, 4)
	draw_rect(sh, Color(0, 0, 0, 0.25 * a))
	draw_rect(r, Color(PARCH.r, PARCH.g, PARCH.b, PARCH.a * a))
	draw_rect(r, INK, false, 2.0)
	draw_rect(r.grow(-4), Color(GOLD.r, GOLD.g, GOLD.b, 0.6), false, 1.0)

func _bar(p: Vector2, w: float, v: float, col: Color, label: String) -> void:
	var f := ThemeDB.fallback_font
	draw_rect(Rect2(p, Vector2(w, 12)), Color(0.2, 0.15, 0.2, 0.5))
	draw_rect(Rect2(p, Vector2(w * clampf(v, 0, 1), 12)), col)
	draw_rect(Rect2(p + Vector2(0, 1), Vector2(w * clampf(v, 0, 1), 4)), Color(1, 1, 1, 0.25))
	draw_rect(Rect2(p, Vector2(w, 12)), INK, false, 1.5)
	draw_string(f, p + Vector2(w + 8, 11), label, HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK)

func _draw() -> void:
	if play == null or play.sim == null or play.backdrop: return
	var f := ThemeDB.fallback_font
	var p := play.player
	if is_instance_valid(p):
		_panel(Rect2(14, 14, 300, 128))
		draw_string(f, Vector2(26, 38), p.sp_name, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, INK)
		var stage := "juvenile" if not p.is_adult() else ("elder" if p.age_s > p.life_s * 0.75 else "adult")
		draw_string(f, Vector2(26, 56), "Generation %d  ·  %s  ·  %d kills" % [play.generation, stage, p.kills], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK.lightened(0.2))
		_bar(Vector2(26, 66), 170, p.hp / p.hp_max, Color(0.78, 0.24, 0.26), "HP %d" % int(p.hp))
		_bar(Vector2(26, 84), 170, p.energy, Color(0.88, 0.62, 0.2), "Fed")
		_bar(Vector2(26, 102), 170, p.stamina, Color(0.35, 0.65, 0.4), "Stamina")
		_bar(Vector2(26, 120), 170, p.age_s / p.life_s, Color(0.45, 0.4, 0.7), "Age")
		# ability bar
		var abil := [["LMB", "Strike", p.cooldown / 0.6], ["Shift", "Dodge", 1.0 - p.stamina if p.stamina < 0.25 else 0.0], ["Q", p.ability_name(), p.abil_cd / 3.5], ["R", "Mate", p.mate_cd / 25.0], ["E", "Graze/Eat", 0.0]]
		var x0 := size.x * 0.5 - abil.size() * 52.0
		for i in abil.size():
			var r := Rect2(x0 + i * 104, size.y - 78, 98, 62)
			_panel(r, 0.95)
			draw_string(f, r.position + Vector2(8, 22), abil[i][0], HORIZONTAL_ALIGNMENT_LEFT, -1, 16, GOLD.darkened(0.3))
			draw_string(f, r.position + Vector2(8, 46), abil[i][1], HORIZONTAL_ALIGNMENT_LEFT, 90, 12, INK)
			var cd: float = clampf(abil[i][2], 0, 1)
			if cd > 0.0: draw_rect(Rect2(r.position + Vector2(0, 62 * (1.0 - cd)), Vector2(98, 62 * cd)), Color(0.1, 0.1, 0.2, 0.35))
	# world clock + stats
	var alive := 0
	for s in play.sim.species: if s["extinct"] < 0: alive += 1
	var tr := Rect2(size.x - 250, 14, 236, 70)
	_panel(tr)
	draw_string(f, tr.position + Vector2(12, 26), "Year %d · %s" % [play.year(), play.season_name()], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, INK)
	draw_string(f, tr.position + Vector2(12, 46), "%d species alive · %d lost" % [alive, play.sim.species.size() - alive], HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK.lightened(0.2))
	draw_string(f, tr.position + Vector2(12, 62), "%d dawns of mind" % play.sim.sapient_events.size(), HORIZONTAL_ALIGNMENT_LEFT, -1, 12, INK.lightened(0.2))
	# chronicle
	var lines: Array = play.chronicle.slice(-5)
	if lines.size() > 0:
		var cr := Rect2(14, size.y - 28 - lines.size() * 18, 440, 20 + lines.size() * 18)
		_panel(cr, 0.8)
		for i in lines.size():
			draw_string(f, cr.position + Vector2(12, 22 + i * 18), lines[i], HORIZONTAL_ALIGNMENT_LEFT, 420, 12, INK)
	if not is_instance_valid(p) and play.observer:
		draw_string(f, Vector2(size.x * 0.5 - 120, 60), "OBSERVING THE WORLD", HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color(1, 1, 1))
