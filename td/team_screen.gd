extends Control
# Team screen: collection with levels/XP/moves, pick up to 6 for runs, spend gold (Rare Candy, Lure Pack).
const Creatures = preload("res://creatures.gd")
const Session = preload("res://session.gd")
const Moves = preload("res://moves.gd")
const PuppetLib = preload("res://puppet_lib.gd")
const UiStyle = preload("res://ui_style.gd")
const TypeChart = preload("res://type_chart.gd")
const Sfx = preload("res://sfx.gd")
signal closed
const RESERVE := 60   # warn when a purchase leaves less gold than this
const LURE_COST := 60
var sel := ""
var grid: Control
var detail: Label
var team_lbl: Label
var gold_lbl: Label
var toggle_btn: Button
var candy_btn: Button
var lure_btn: Button
var msg: Label

func _ready() -> void:
	size = Vector2(1280, 720)
	var bg := ColorRect.new()
	bg.color = Color(0.04, 0.03, 0.12, 1.0)
	bg.size = size
	add_child(bg)
	var t := _lbl("Your Team", Vector2(40, 22), 34, Color("ffe08a"))
	team_lbl = _lbl("", Vector2(40, 70), 20, Color("c9d4ff"))
	gold_lbl = _lbl("", Vector2(900, 28), 26, Color("ffd23a"))
	var back := _btn("Back", Vector2(1120, 20), Vector2(130, 46), 20, Color("3a4a6b"), func(): closed.emit())
	add_child(back)
	grid = Control.new()
	add_child(grid)
	detail = _lbl("", Vector2(700, 110), 20, Color.WHITE)
	detail.size = Vector2(540, 380)
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toggle_btn = _btn("", Vector2(700, 520), Vector2(250, 50), 20, Color("2f6b3a"), _toggle)
	candy_btn = _btn("", Vector2(960, 520), Vector2(290, 50), 18, Color("8a4fc0"), _candy)
	lure_btn = _btn("", Vector2(700, 584), Vector2(250, 50), 18, Color("c4852b"), _lures)
	msg = _lbl("", Vector2(700, 650), 18, Color("9fffa0"))
	for b in [toggle_btn, candy_btn, lure_btn]:
		add_child(b)
	refresh()

func _lbl(text: String, pos: Vector2, fs: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.position = pos
	l.add_theme_font_size_override("font_size", fs)
	l.add_theme_color_override("font_color", col)
	add_child(l)
	return l

func _btn(text: String, pos: Vector2, sz: Vector2, fs: int, col: Color, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = sz
	b.add_theme_font_size_override("font_size", fs)
	b.pressed.connect(cb)
	UiStyle.style_btn(b, col, col)
	return b

func owned() -> Array:
	var out := []
	for k in Creatures.TOWERS:
		if Session.tower_open(Creatures.TOWERS[k]):
			out.append(k)
	return out

func refresh() -> void:
	var team := Session.team_ids()
	var own := owned()
	if sel == "" or not sel in own:
		sel = own[0]
	team_lbl.text = "Team %d/%d. Tap a creature, then add or remove it. Captured creatures stay yours forever." % [team.size(), Session.TEAM_MAX]
	gold_lbl.text = "Gold %d" % Session.gold
	for c in grid.get_children():
		c.queue_free()
	for i in own.size():
		var id: String = own[i]
		var d: Dictionary = Creatures.TOWERS[id]
		var b := Button.new()
		b.toggle_mode = true
		b.text = "%s\nLv %d%s" % [d.name, Session.level_of(id), "   ★" if id in team else ""]
		b.icon = PuppetLib.tex(d.sprite, "idle", 0)
		b.expand_icon = true
		b.add_theme_constant_override("icon_max_width", 52)
		b.add_theme_font_size_override("font_size", 15)
		b.size = Vector2(196, 92)
		b.position = Vector2(40 + (i % 3) * 208, 110 + (i / 3) * 102)
		b.set_pressed_no_signal(id == sel)
		b.pressed.connect(func(): sel = id; Sfx.play(self, "click"); refresh())
		UiStyle.style_btn(b, Color("2f6b3a") if id in team else Color("3a3f5a"), Color("d9892a"))
		grid.add_child(b)
	for j in range(own.size(), mini(Session.TEAM_MAX, own.size() + 3)):
		var ph := Button.new()
		ph.text = "?\nCapture to unlock"
		ph.disabled = true
		ph.add_theme_font_size_override("font_size", 15)
		ph.size = Vector2(196, 92)
		ph.position = Vector2(40 + (j % 3) * 208, 110 + (j / 3) * 102)
		UiStyle.style_btn(ph, Color("22243a"), Color("3a3f5a"))
		grid.add_child(ph)
	var d: Dictionary = Creatures.TOWERS[sel]
	var l := Session.level_of(sel)
	var xp := int(Session.xp.get(sel, 0))
	var txt := "%s   Lv %d%s\nTypes: %s\n" % [d.name, l, "" if l < Session.MAX_LEVEL else " (MAX)", " / ".join(PackedStringArray(Array(d.types).map(func(t): return String(t).capitalize())))]
	if l < Session.MAX_LEVEL:
		txt += "Exp %d / %d to unlock Lv %d%s\n" % [xp, Session.xp_for_level(l + 1), l + 1, "  READY" if Session.xp_ready(sel) else ""]
	txt += "Attack: %s   Power %.0f   Cooldown %.1fs   Accuracy 100%%   %s\n" % [String(d.types[0]).capitalize(), float(d.dmg) * Session.level_mult(sel), 1.0 / maxf(0.1, float(d.rate)), Moves.category(String(d.types[0]))]
	if "ember" in d.types:
		txt += "Burn chance 10% (burn damage over time)\n"
	txt += "Damage x%.2f   Speed x%.2f\n\nMoves:\n" % [Session.level_mult(sel), 1.0 + 0.03 * (l - 1)]
	for m in Moves.for_type(String(d.types[0])):
		txt += "  %s Lv %d  %s (%s)\n" % ["✔" if l >= int(m.lvl) else "·", m.lvl, m.name, m.desc]
	detail.text = txt
	toggle_btn.text = "Remove from team" if sel in team else "Add to team"
	if l >= Session.MAX_LEVEL:
		candy_btn.text = "Max level"
	else:
		candy_btn.text = "Level up to %d: %d gold%s" % [l + 1, Session.level_cost(sel), "" if Session.xp_ready(sel) else "  (needs Exp)"]
	lure_btn.text = "Lure Pack +2 (%d gold)" % LURE_COST
	candy_btn.disabled = l >= Session.MAX_LEVEL
	lure_btn.disabled = Session.gold < LURE_COST

func _toggle() -> void:
	msg.text = "" if Session.toggle_team(sel) else "Team needs 1 to %d creatures." % Session.TEAM_MAX
	refresh()

func _candy() -> void:
	var cost := Session.level_cost(sel)
	var why := Session.buy_level(sel)
	if why != "":
		msg.text = why
	else:
		msg.text = "%s grew to Lv %d!" % [Creatures.TOWERS[sel].name, Session.level_of(sel)]
		if Session.gold < RESERVE:
			msg.text += "  Careful: only %d gold left for Lures." % Session.gold
		Sfx.play(self, "up")
	refresh()

func _lures() -> void:
	if Session.spend_gold(LURE_COST):
		Session.lure_bonus += 2
		Session.save_prefs()
		msg.text = "+2 Lures for your next run (now +%d)." % Session.lure_bonus
		Sfx.play(self, "coin")
	refresh()
