extends Control
# Icon HUD: coins, lives hearts, wave pips, next-wave creature preview (or enemies remaining), weather chip, event badge.
const PuppetLib = preload("res://puppet_lib.gd")
const Creatures = preload("res://creatures.gd")
const Weather = preload("res://weather.gd")
const Rules = preload("res://rules.gd")
const Levels = preload("res://levels.gd")
const OUT := Color("1d1230")
var m
var panel_sb: StyleBoxFlat
var coins_shown := 0.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(960, 130)
	panel_sb = StyleBoxFlat.new()
	panel_sb.bg_color = Color(0.08, 0.06, 0.16, 0.78)
	panel_sb.set_corner_radius_all(16)
	panel_sb.set_border_width_all(3)
	panel_sb.border_color = Color("3a2a5a")

var _acc := 0.0
func _process(delta: float) -> void:
	_acc += delta
	if _acc < (0.05 if m != null and m.Session.low_gfx() else 0.033):
		return   # redraw at ~30 Hz (20 Hz in low graphics): text shaping is the HUD's main cost
	delta = _acc
	_acc = 0.0
	if m != null:
		coins_shown = lerpf(coins_shown, float(m.coins), clampf(delta * 10.0, 0.0, 1.0))
		if absf(coins_shown - m.coins) < 0.6:
			coins_shown = float(m.coins)
	queue_redraw()

func _txt(s: String, pos: Vector2, size_px: int, col: Color) -> void:
	var f := ThemeDB.fallback_font
	draw_string_outline(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, 7, OUT)
	draw_string(f, pos, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px, col)

func _coin(p: Vector2) -> void:
	draw_circle(p, 15.0, OUT)
	draw_circle(p, 12.5, Color("ffd23a"))
	draw_circle(p, 8.0, Color("f0a81c"))
	draw_circle(p + Vector2(-3, -3), 3.0, Color(1, 1, 1, 0.8))

func _pile(p: Vector2, k: float = 1.0) -> void:
	for i in 3:
		var c := p + Vector2(0, (2 - i) * -5.0 + 6.0) * k
		draw_set_transform(c, 0.0, Vector2(1.0, 0.6) * k)
		draw_circle(Vector2.ZERO, 12.0, OUT)
		draw_circle(Vector2.ZERO, 10.0, Color("f4b928"))
		draw_arc(Vector2.ZERO, 10.0, PI * 1.1, PI * 1.9, 10, Color(1, 0.93, 0.6), 2.5, true)
		draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

func _orb_icon(p: Vector2) -> void:
	# Lure charm: a glowing teal crystal on a golden loop (not a ball)
	draw_arc(p + Vector2(0, -13), 5.5, 0, TAU, 14, OUT, 4.0, true)
	draw_arc(p + Vector2(0, -13), 5.5, 0, TAU, 14, Color("ffd23a"), 2.0, true)
	var gem := PackedVector2Array([p + Vector2(0, -10), p + Vector2(11, 0), p + Vector2(0, 14), p + Vector2(-11, 0)])
	var gem_o := PackedVector2Array([p + Vector2(0, -13), p + Vector2(14, 0), p + Vector2(0, 17), p + Vector2(-14, 0)])
	draw_colored_polygon(gem_o, OUT)
	draw_colored_polygon(gem, Color("3fd8c0"))
	draw_colored_polygon(PackedVector2Array([p + Vector2(0, -10), p + Vector2(-11, 0), p + Vector2(0, 2)]), Color("a8fff0"))
	draw_line(p + Vector2(-11, 0), p + Vector2(11, 0), Color(1, 1, 1, 0.55), 1.5)

func _heart(p: Vector2, col: Color, k: float = 1.0) -> void:
	var s := k
	draw_circle(p + Vector2(-6, -3) * s, 9.0 * s, OUT)
	draw_circle(p + Vector2(6, -3) * s, 9.0 * s, OUT)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-15, 1) * s, p + Vector2(15, 1) * s, p + Vector2(0, 18) * s]), OUT)
	draw_circle(p + Vector2(-6, -3) * s, 7.0 * s, col)
	draw_circle(p + Vector2(6, -3) * s, 7.0 * s, col)
	draw_colored_polygon(PackedVector2Array([p + Vector2(-12.5, 1) * s, p + Vector2(12.5, 1) * s, p + Vector2(0, 15) * s]), col)
	draw_circle(p + Vector2(-8, -6) * s, 2.5 * s, Color(1, 1, 1, 0.7))

func _draw() -> void:
	if m == null:
		return
	var t := Time.get_ticks_msec() / 1000.0
	draw_style_box(panel_sb, Rect2(8, 6, 560, 112))
	# row 1: coins, lives, wave pips
	_coin(Vector2(34, 30))
	_txt(str(int(round(coins_shown))), Vector2(54, 40), 28, Color("fff3b0"))
	var low: bool = m.lives <= maxi(3, m.lives_start / 4)
	var hcol := Color("ff5a6a") if not low else Color(1.0, 0.25 + 0.2 * sin(t * 8.0), 0.3)
	if m.lv.get("steal", false):
		_pile(Vector2(150, 28), 1.0 + (0.1 * sin(t * 8.0) if low else 0.0))
		_txt(str(maxi(0, m.lives)), Vector2(172, 40), 28, Color.WHITE if not low else Color(1.0, 0.45, 0.4))
	else:
		_heart(Vector2(150, 28), hcol, 1.0 + (0.1 * sin(t * 8.0) if low else 0.0))
		_txt(str(maxi(0, m.lives)), Vector2(172, 40), 28, Color.WHITE)
	_orb_icon(Vector2(246, 28))
	_txt(str(m.lures), Vector2(264, 40), 26, Color("ffe08a") if m.lures > 0 else Color("8a7a9a"))
	_txt("Lures", Vector2(284, 38), 16, Color("a8fff0"))
	var total := Levels.TOTAL_WAVES
	for i in total:
		var c := Vector2(332 + i * 22, 30)
		var done: bool = i < m.wave - (1 if m.wave_running else 0)
		var cur: bool = i == m.wave - 1 and m.wave_running
		draw_circle(c, 9.0, OUT)
		draw_circle(c, 6.5, Color("ffd23a") if done else (Color("ff8a2b") if cur else Color("3a3060")))
	if m.endless:
		_txt("Endless  %d" % m.wave, Vector2(296, 44), 20, Color("ffd23a"))
	# row 2: next wave preview / remaining
	var y := 98.0
	if not m.wave_running and (m.endless or m.wave < total):
		_txt("Next", Vector2(20, 82), 18, Color("c8b8f0"))
		var counts := {}
		for k in m._plan(m.wave + 1):
			var key := String(k).replace("boss:", "").replace("champion:", "")
			counts[key] = counts.get(key, 0) + 1
		var x := 76.0
		for k in counts:
			var ed: Dictionary = Creatures.ENEMIES.get(k, {})
			var tint_c := Color(String(ed.tint)) if ed.has("tint") else Color.WHITE
			PuppetLib.draw(self, String(ed.get("sprite", k)), "idle", int(t * 5.0), false, 0.24 * float(ed.get("scale", 1.0)), Vector2(x + 16, y), tint_c)
			_txt("x%d" % counts[k], Vector2(x + 34, 94), 17, Color.WHITE)
			x += 82.0
			if x > 520.0:
				break
	elif m.wave_running:
		var left: int = m.to_spawn + m.enemy_list.size()
		_txt("Enemies left: %d" % left, Vector2(20, 90), 22, Color("ffe8b0"))
	# weather chip + event
	var wid: String = m.weather if m.wave_running else String(m.lv.weather[m.wave % m.lv.weather.size()])
	var wname := String(Weather.WEATHER[wid].label).get_slice(":", 0)
	var chip := Rect2(584, 10, 190, 34)
	draw_style_box(panel_sb, chip)
	_txt(wname, Vector2(596, 36), 20, Color("bfe8ff"))
	var nt: int = m.get_tree().get_nodes_in_group("towers").size()
	var cap: int = m.tower_cap()
	var chip2 := Rect2(784, 10, 176, 34)
	draw_style_box(panel_sb, chip2)
	_txt("Towers %d/%d" % [nt, cap], Vector2(796, 36), 20, Color("ff9a8a") if nt >= cap else Color("c8f0b8"))
	if not m.bounty.is_empty():
		var chip3 := Rect2(784, 50, 176, 30)
		draw_style_box(panel_sb, chip3)
		var done: bool = m.bounty_done()
		var prog: int = mini(m.bounty_progress(), int(m.bounty.target))
		_txt(("Bounty done +%d" % int(m.bounty.reward)) if done else "%s %d/%d" % [String(m.bounty.label), prog, int(m.bounty.target)], Vector2(794, 72), 14, Color("ffe36a") if done else Color("e8d8ff"))
	if m.tier > 0:
		_txt("Replay Tier %d" % m.tier, Vector2(584, 130), 18, Color("ffd23a"))
	if m.event_id != "":
		_txt(String(Rules.EVENTS[m.event_id].name), Vector2(584, 70), 22, Color("ffd23a"))
		_txt(String(Rules.EVENTS[m.event_id].get("desc", "")), Vector2(584, 92), 16, Color("ffe8b0"))
	if m.Session.diff != "normal":
		_txt(String(Rules.DIFFICULTY[m.Session.diff].name), Vector2(584, 100), 20, Color("ff9a8a"))
