class_name RUI
extends CanvasLayer
## All HUD and modal screens for Raceborn: Ages.

signal cmd(kind: String, arg)
signal start_game(race: int, leader: int)

var g: RGame
var root: Control
var top_label: Label
var age_bar: ProgressBar
var yields_label: Label
var research_label: Label
var notes_box: VBoxContainer
var sel_panel: PanelContainer
var sel_box: VBoxContainer
var next_btn: Button
var modal: Control = null
var tooltip: Label
var start_race := 2
var start_leader := 0
var last_sel_key := ""

const KIND_COL := {"good": Color("9ee6a8"), "bad": Color("ff8a78"), "war": Color("ff6a55"), "age": Color("ffd35a"), "info": Color("d8ccb4")}

func _style(bg: Color = Color(0.06, 0.05, 0.08, 0.86)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(8)
	s.set_border_width_all(1)
	s.border_color = Color(1, 0.85, 0.4, 0.3)
	s.content_margin_left = 12; s.content_margin_right = 12; s.content_margin_top = 8; s.content_margin_bottom = 8
	return s

func build(p_game: RGame) -> void:
	g = p_game
	layer = 10
	if root != null: root.queue_free()
	root = Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# top bar
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _style())
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 8; top.offset_right = -8; top.offset_top = 8
	root.add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	top.add_child(hb)
	top_label = Label.new(); top_label.add_theme_font_size_override("font_size", 16); hb.add_child(top_label)
	age_bar = ProgressBar.new(); age_bar.custom_minimum_size = Vector2(170, 12); age_bar.max_value = RData.AGE_TARGET; age_bar.show_percentage = false
	age_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER; hb.add_child(age_bar)
	yields_label = Label.new(); yields_label.add_theme_font_size_override("font_size", 16); hb.add_child(yields_label)
	research_label = Label.new(); research_label.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6)); hb.add_child(research_label)
	var sp := Control.new(); sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(sp)
	for e in [["Technology (T)", "tech"], ["Civics (C)", "civics"], ["Legacy (L)", "legacy"], ["Diplomacy (D)", "diplo"]]:
		var b := Button.new(); b.text = e[0]; b.pressed.connect(func(): cmd.emit("open", e[1])); hb.add_child(b)
	# notifications
	notes_box = VBoxContainer.new()
	notes_box.set_anchors_preset(Control.PRESET_TOP_LEFT)
	notes_box.offset_left = 12; notes_box.offset_top = 70
	notes_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(notes_box)
	# selection panel
	sel_panel = PanelContainer.new()
	sel_panel.add_theme_stylebox_override("panel", _style())
	sel_panel.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	sel_panel.offset_left = 8; sel_panel.offset_bottom = -8; sel_panel.offset_top = -240; sel_panel.offset_right = 430
	sel_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	sel_panel.visible = false
	root.add_child(sel_panel)
	var sc := ScrollContainer.new(); sel_panel.add_child(sc)
	sel_box = VBoxContainer.new(); sel_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(sel_box)
	# next / end turn
	next_btn = Button.new()
	next_btn.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	next_btn.offset_right = -12; next_btn.offset_bottom = -12; next_btn.offset_left = -230; next_btn.offset_top = -68
	next_btn.grow_vertical = Control.GROW_DIRECTION_BEGIN
	next_btn.add_theme_font_size_override("font_size", 22)
	next_btn.pressed.connect(func(): cmd.emit("next", null))
	root.add_child(next_btn)
	tooltip = Label.new()
	tooltip.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	tooltip.offset_right = -12; tooltip.offset_bottom = -76; tooltip.offset_left = -520; tooltip.offset_top = -130
	tooltip.grow_vertical = Control.GROW_DIRECTION_BEGIN
	tooltip.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tooltip.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65))
	tooltip.add_theme_color_override("font_outline_color", Color.BLACK)
	tooltip.add_theme_constant_override("outline_size", 6)
	root.add_child(tooltip)

func close_modal() -> void:
	if modal != null:
		modal.queue_free()
		modal = null

func _modal(title: String, width: int = 760) -> VBoxContainer:
	close_modal()
	modal = Control.new()
	modal.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(modal)
	var dim := ColorRect.new(); dim.color = Color(0, 0, 0, 0.55); dim.set_anchors_preset(Control.PRESET_FULL_RECT); modal.add_child(dim)
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _style(Color(0.05, 0.04, 0.07, 0.96)))
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.grow_horizontal = Control.GROW_DIRECTION_BOTH; panel.grow_vertical = Control.GROW_DIRECTION_BOTH
	panel.custom_minimum_size = Vector2(width, 0)
	modal.add_child(panel)
	var vb := VBoxContainer.new(); vb.add_theme_constant_override("separation", 8); panel.add_child(vb)
	var t := Label.new(); t.text = title; t.add_theme_font_size_override("font_size", 28); t.add_theme_color_override("font_color", Color("ffd35a")); vb.add_child(t)
	return vb

func _close_btn(vb: Control, text: String = "Close") -> void:
	var b := Button.new(); b.text = text; b.pressed.connect(close_modal); vb.add_child(b)

# ------------------------------------------------------------------ start screen
func show_start() -> void:
	var vb := _modal("RACEBORN: AGES", 980)
	var st := Label.new(); st.text = "Lead a people through three Ages - Antiquity, Exploration, Modern. At every Age you cast off your old race and take up a new one. Found cities, research, build armies, and write your Legacy."
	st.autowrap_mode = TextServer.AUTOWRAP_WORD; st.add_theme_color_override("font_color", Color(0.8, 0.75, 0.65)); vb.add_child(st)
	var lbl := Label.new(); lbl.text = "1. Choose your starting race"; vb.add_child(lbl)
	var grid := GridContainer.new(); grid.columns = 5; vb.add_child(grid)
	var group := ButtonGroup.new()
	for i in RData.RACES.size():
		var r: Dictionary = RData.RACES[i]
		var b := Button.new(); b.toggle_mode = true; b.button_group = group; b.button_pressed = (i == start_race)
		b.custom_minimum_size = Vector2(185, 70)
		b.text = "%s\n%s / %s" % [r.name, r.melee_unit, r.ubuilding[0]]
		b.add_theme_color_override("font_color", r.color)
		b.tooltip_text = r.blurb
		b.pressed.connect(func(): start_race = i; _refresh_start_blurb())
		grid.add_child(b)
	var blurb := Label.new(); blurb.name = "Blurb"; blurb.add_theme_color_override("font_color", Color(0.85, 0.8, 0.65)); vb.add_child(blurb)
	var l2 := Label.new(); l2.text = "2. Choose your leader"; vb.add_child(l2)
	var hb := HBoxContainer.new(); vb.add_child(hb)
	var g2 := ButtonGroup.new()
	for i in RData.LEADERS.size():
		var ld: Dictionary = RData.LEADERS[i]
		var b := Button.new(); b.toggle_mode = true; b.button_group = g2; b.button_pressed = (i == start_leader)
		b.text = "%s\n%s" % [ld.name, ld.desc]; b.custom_minimum_size = Vector2(230, 60)
		b.pressed.connect(func(): start_leader = i)
		hb.add_child(b)
	var go := Button.new(); go.text = "Begin"; go.add_theme_font_size_override("font_size", 22)
	go.pressed.connect(func(): close_modal(); start_game.emit(start_race, start_leader))
	vb.add_child(go)
	_refresh_start_blurb()

func _refresh_start_blurb() -> void:
	if modal == null: return
	var l := modal.find_child("Blurb", true, false)
	if l == null: return
	var r: Dictionary = RData.RACES[start_race]
	l.text = "%s - %s\nUnique: %s (melee), %s (ranged), %s (building)." % [r.name, r.blurb, r.melee_unit, r.ranged_unit, r.ubuilding[0]]

# ------------------------------------------------------------------ top bar / notes
func refresh() -> void:
	if g == null or g.players.is_empty(): return
	var p: RGame.Player = g.players[0]
	var rc: Dictionary = RData.RACES[p.race]
	top_label.text = "%s (%s)  |  Turn %d  |  %s Age" % [rc.name, RData.LEADERS[p.leader].name, g.turn, RData.AGE_NAMES[g.age]]
	age_bar.value = minf(p.age_progress, RData.AGE_TARGET)
	yields_label.text = "Gold %d (%+.0f)   Sci %+.0f   Cul %+.0f   Cities %d" % [p.gold, p.income.gold, p.income.sci, p.income.cul, g.city_of(p).size()]
	var rt := g.tech_by_id(p.research)
	var cv := g.civic_by_id(p.civic)
	var rs := "Research: %s %d/%d" % [rt[1], p.research_prog, g.tech_cost(p, rt)] if not rt.is_empty() else "Research: choose"
	var cs := "Civic: %s %d/%d" % [cv[1], p.civic_prog, cv[2]] if not cv.is_empty() else "Civic: choose"
	research_label.text = rs + "   " + cs
	next_btn.text = _next_text
	if g.transition != "" and modal == null: cmd.emit("transition", null)

var _next_text := "End Turn"
func set_next_text(t: String) -> void:
	_next_text = t
	if next_btn != null: next_btn.text = t

func add_note(text: String, kind: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", KIND_COL.get(kind, Color.WHITE))
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	notes_box.add_child(l)
	while notes_box.get_child_count() > 8: notes_box.get_child(0).queue_free(); notes_box.remove_child(notes_box.get_child(0))
	var tw := create_tween()
	tw.tween_interval(9.0)
	tw.tween_property(l, "modulate:a", 0.0, 1.5)
	tw.tween_callback(l.queue_free)

func set_tooltip(t: String) -> void:
	if tooltip != null: tooltip.text = t

# ------------------------------------------------------------------ selection panel
func _btn(parent: Node, text: String, kind: String, arg = null, tip: String = "") -> Button:
	var b := Button.new()
	b.text = text
	b.tooltip_text = tip
	b.pressed.connect(func(): cmd.emit(kind, arg))
	parent.add_child(b)
	return b

func show_selection(unit: RGame.Unit, city: RGame.City) -> void:
	var key := ""
	if unit != null: key = "u%d:%d:%d:%s" % [unit.id, unit.mp, int(unit.hp), str(unit.fortified)]
	elif city != null: key = "c%d:%d:%s:%d:%d:%d" % [city.id, city.pop, city.producing, int(city.prod), city.buildings.size(), int(g.players[0].gold)]
	if key == last_sel_key: return
	last_sel_key = key
	for ch in sel_box.get_children(): ch.queue_free()
	if unit == null and city == null:
		sel_panel.visible = false
		return
	sel_panel.visible = true
	var p: RGame.Player = g.players[0]
	if unit != null:
		var t := Label.new()
		t.text = "%s  HP %d/%d  Moves %d/%d%s" % [g.unit_name(unit), unit.hp, g.max_hp(unit), unit.mp, g.max_mp(unit), "  (fortified)" if unit.fortified else ""]
		t.add_theme_font_size_override("font_size", 17)
		sel_box.add_child(t)
		if unit.kind == "melee" or unit.kind == "ranged":
			var a := Label.new(); a.text = "Attack %d  Defense %d  Range %d" % [g.strength(unit, true), g.strength(unit, false), g.unit_range(unit)]
			a.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6)); sel_box.add_child(a)
		var hb := HFlowContainer.new(); sel_box.add_child(hb)
		if unit.kind == "settler": _btn(hb, "Found City (B)", "found", null, "Cities must be 3+ tiles apart; first is your capital, others are towns.")
		_btn(hb, "Fortify (F)", "fortify")
		_btn(hb, "Sleep (S)", "sleep")
		_btn(hb, "Skip (Space)", "skip")
		var h := Label.new(); h.text = "Right-click a tile to move or attack."; h.add_theme_color_override("font_color", Color(0.6, 0.57, 0.5)); sel_box.add_child(h)
		return
	var c := city
	var cap := "City" if c.is_city else "Town"
	var t2 := Label.new()
	t2.text = "%s (%s)  Pop %d  HP %d" % [c.cname, cap, c.pop, c.hp]
	t2.add_theme_font_size_override("font_size", 17); sel_box.add_child(t2)
	var y := Label.new()
	y.text = "Food %+.1f  Prod %.1f  Gold %.1f  Sci %.1f  Cul %.1f" % [c.yields.food - c.pop * 2.0, c.yields.prod, c.yields.gold, c.yields.sci, c.yields.cul]
	y.add_theme_color_override("font_color", Color(0.78, 0.74, 0.62)); sel_box.add_child(y)
	if not c.buildings.is_empty():
		var bl := Label.new(); var names: Array = []
		for b in c.buildings: names.append(RData.RACES[p.race].ubuilding[0] if b == "ubld" else RData.BUILDINGS[b][0])
		bl.text = "Built: " + ", ".join(names); bl.add_theme_color_override("font_color", Color(0.6, 0.57, 0.5)); sel_box.add_child(bl)
	var cur := "Producing: " + (g.item_name(c, c.producing) + " %d/%d" % [c.prod, g.item_cost(c, c.producing)] if c.producing != "" else "nothing")
	var cl := Label.new(); cl.text = cur; sel_box.add_child(cl)
	var hb2 := HFlowContainer.new(); sel_box.add_child(hb2)
	if c.producing != "": _btn(hb2, "Buy (%d gold)" % g.buy_cost(c), "buy", null).disabled = p.gold < g.buy_cost(c)
	if not c.is_city: _btn(hb2, "Upgrade to City (80g, pop 3)", "upgrade").disabled = (c.pop < 3 or p.gold < 80.0)
	var pl := Label.new(); pl.text = "Produce:" if c.is_city else "Towns cannot produce - buy items with gold:"; pl.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55)); sel_box.add_child(pl)
	var hb3 := HFlowContainer.new(); sel_box.add_child(hb3)
	for item in g.available_items(c):
		_btn(hb3, "%s (%d)" % [g.item_name(c, item), g.item_cost(c, item)], "prod", item)

# ------------------------------------------------------------------ tech / civics
func show_research(civics: bool) -> void:
	var p: RGame.Player = g.players[0]
	var vb := _modal("Civics (culture)" if civics else "Technology (science)", 720)
	var list: Array = g.available_civics(p) if civics else g.available_techs(p)
	if list.is_empty():
		var l := Label.new(); l.text = "Everything in this Age is complete."; vb.add_child(l)
	for e in list:
		var cost: float = float(e[2]) if civics else g.tech_cost(p, e)
		var eff: Array = []
		var m: Dictionary = e[3] if civics else e[4]
		for k in m: eff.append("%+d%% %s" % [m[k] * 100.0, k])
		var unlock := ""
		if not civics and not e[3].is_empty(): unlock = "  Unlocks: " + ", ".join(e[3].map(func(b): return RData.BUILDINGS[b][0]))
		var cur: bool = (p.civic == e[0]) if civics else (p.research == e[0])
		var b := Button.new()
		b.text = "%s%s  -  %d   [%s]%s" % ["> " if cur else "", e[1], cost, ", ".join(eff), unlock]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): cmd.emit("civic" if civics else "research", e[0]); close_modal())
		vb.add_child(b)
	_close_btn(vb)

# ------------------------------------------------------------------ legacy
func show_legacy() -> void:
	var p: RGame.Player = g.players[0]
	var vb := _modal("Legacy", 640)
	var info := Label.new(); info.text = "Legacy paths grow as you play and persist across Ages. Each tier grants a permanent +8% bonus. The Age ends when its progress bar fills; Legacy points decide the final score."
	info.autowrap_mode = TextServer.AUTOWRAP_WORD; info.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6)); vb.add_child(info)
	var names := {"mil": "Military (kills, conquests)", "eco": "Economic (gold, buildings)", "cul": "Cultural (culture, civics)", "sci": "Scientific (science, techs)"}
	for k in ["mil", "eco", "cul", "sci"]:
		var hb := HBoxContainer.new(); vb.add_child(hb)
		var l := Label.new(); l.text = "%s  tier %d/3" % [names[k], p.tiers[k]]; l.custom_minimum_size = Vector2(300, 0); hb.add_child(l)
		var pb := ProgressBar.new(); pb.max_value = 90.0; pb.value = minf(90.0, p.legacy[k]); pb.custom_minimum_size = Vector2(240, 16); pb.show_percentage = false
		pb.size_flags_vertical = Control.SIZE_SHRINK_CENTER; hb.add_child(pb)
		var v := Label.new(); v.text = " %d" % p.legacy[k]; hb.add_child(v)
	var sc := Label.new(); sc.text = "Score: %d" % g.score(p); sc.add_theme_font_size_override("font_size", 20); vb.add_child(sc)
	var hist := Label.new(); var races: Array = []
	for r in p.past_races: races.append(RData.RACES[r].name)
	hist.text = "Past peoples: " + (", ".join(races) if not races.is_empty() else "none yet"); vb.add_child(hist)
	_close_btn(vb)

# ------------------------------------------------------------------ diplomacy
func show_diplomacy() -> void:
	var p: RGame.Player = g.players[0]
	var vb := _modal("Diplomacy", 700)
	for o in g.players:
		if o.id == 0: continue
		var hb := HBoxContainer.new(); vb.add_child(hb)
		var rc: Dictionary = RData.RACES[o.race]
		var l := Label.new()
		var stt := "ELIMINATED" if not o.alive else ("AT WAR (%d turns)" % p.war_turns.get(o.id, 0) if p.at_war.has(o.id) else "Peace")
		l.text = "%s (%s)  cities %d  power %d  score %d  -  %s" % [rc.name, RData.LEADERS[o.leader].name, g.city_of(o).size(), g.power(o), g.score(o), stt]
		l.add_theme_color_override("font_color", rc.color)
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hb.add_child(l)
		if o.alive:
			if p.at_war.has(o.id):
				var b := Button.new(); b.text = "Propose peace"; b.pressed.connect(func(): cmd.emit("peace", o.id); close_modal()); hb.add_child(b)
			else:
				var b2 := Button.new(); b2.text = "Declare war"; b2.pressed.connect(func(): cmd.emit("war", o.id); close_modal()); hb.add_child(b2)
	_close_btn(vb)

# ------------------------------------------------------------------ age transition
func show_transition() -> void:
	if g.transition == "crisis":
		var cr: Array = RGame.CRISES[g.crisis_id]
		var vb := _modal("The %s Age ends: %s" % [RData.AGE_NAMES[g.age], cr[0]], 720)
		var l := Label.new(); l.text = cr[1] + "\nEvery empire is affected for 6 turns. Your people look to you."; l.autowrap_mode = TextServer.AUTOWRAP_WORD; vb.add_child(l)
		var b1 := Button.new(); b1.text = "Endure it (%s)" % _mods_text(cr[2]); b1.pressed.connect(func(): cmd.emit("crisis", false)); vb.add_child(b1)
		var b2 := Button.new(); b2.text = "Spend 60 gold to soften the blow (%s)" % _mods_text(cr[3]); b2.disabled = g.players[0].gold < 60.0
		b2.pressed.connect(func(): cmd.emit("crisis", true)); vb.add_child(b2)
	elif g.transition == "race":
		var vb2 := _modal("A new Age: choose your people", 980)
		var l2 := Label.new(); l2.text = "Your cities and Legacy endure, but your people change. Choose the race that will lead the %s Age." % RData.AGE_NAMES[mini(g.age + 1, 2)]
		l2.autowrap_mode = TextServer.AUTOWRAP_WORD; vb2.add_child(l2)
		var grid := GridContainer.new(); grid.columns = 3; vb2.add_child(grid)
		for i in g.free_races():
			var r: Dictionary = RData.RACES[i]
			var b := Button.new(); b.custom_minimum_size = Vector2(300, 96)
			var am: Dictionary = r.age_mods[mini(g.age + 1, 2)]
			b.text = "%s\n%s\nUnique: %s, %s, %s\nThis Age: %s" % [r.name, r.blurb, r.melee_unit, r.ranged_unit, r.ubuilding[0], _mods_text(am) if not am.is_empty() else "-"]
			b.add_theme_color_override("font_color", r.color)
			b.autowrap_mode = TextServer.AUTOWRAP_WORD
			b.pressed.connect(func(): cmd.emit("race", i))
			grid.add_child(b)

func _mods_text(m: Dictionary) -> String:
	var parts: Array = []
	for k in m: parts.append("%+d%% %s" % [m[k] * 100.0, k])
	return ", ".join(parts)

# ------------------------------------------------------------------ game over
func show_game_over() -> void:
	var good: bool = g.winner == 0
	var vb := _modal("VICTORY" if good else "DEFEAT", 640)
	var kinds := {"score": "The final Age is over. Scores decide.", "domination": "One empire remains.", "eliminated": "Your people are gone."}
	var l := Label.new(); l.text = kinds.get(g.win_kind, "") + "\nWinner: %s" % (RData.RACES[g.players[g.winner].race].name if g.winner >= 0 else "none"); vb.add_child(l)
	var rows := g.players.duplicate()
	rows.sort_custom(func(a, b): return g.score(a) > g.score(b))
	for p in rows:
		var t := Label.new(); t.text = "%s - %d points (%d cities)" % [RData.RACES[p.race].name, g.score(p), g.city_of(p).size()]
		t.add_theme_color_override("font_color", RData.RACES[p.race].color); vb.add_child(t)
	var b := Button.new(); b.text = "New game"; b.pressed.connect(func(): cmd.emit("restart", null)); vb.add_child(b)
