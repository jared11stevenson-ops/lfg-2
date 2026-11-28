class_name BCHud
extends CanvasLayer
## Heads-up display: clock + speed, civ roster, selected-civ inspector, event log.

signal speed_changed(mult: float)
signal pause_toggled
signal civ_picked(idx: int)
signal overview_pressed

const KIND_COL := {
	"war": "#ff8a78", "trade": "#ffd35a", "birth": "#9ee6a8", "sys": "#8fa8ff", "peace": "#7ee0d0",
	"spy": "#d49bff", "death": "#9a8f80", "tech": "#7fd1ff", "info": "#d8ccb4",
}

var sim: BCSim
var day_label: Label
var phase_label: Label
var time_bar: ProgressBar
var world_label: Label
var roster: VBoxContainer
var roster_btns: Array = []
var inspector: RichTextLabel
var log_view: RichTextLabel
var pause_btn: Button
var speed_btns: Array = []
var selected := -1
var _accum := 0.0

func _panel(bg: Color = Color(0.06, 0.05, 0.08, 0.78)) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.set_corner_radius_all(8)
	s.set_border_width_all(1)
	s.border_color = Color(1, 1, 1, 0.10)
	s.content_margin_left = 12; s.content_margin_right = 12; s.content_margin_top = 8; s.content_margin_bottom = 8
	return s

func build(p_sim: BCSim) -> void:
	sim = p_sim
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	# ---- top bar
	var top := PanelContainer.new()
	top.add_theme_stylebox_override("panel", _panel())
	top.set_anchors_preset(Control.PRESET_TOP_WIDE)
	top.offset_left = 12; top.offset_right = -12; top.offset_top = 10
	root.add_child(top)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 14)
	top.add_child(hb)
	var title := Label.new()
	title.text = "THE WALL"
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color("ffd35a"))
	hb.add_child(title)
	day_label = Label.new(); day_label.add_theme_font_size_override("font_size", 18); hb.add_child(day_label)
	time_bar = ProgressBar.new()
	time_bar.custom_minimum_size = Vector2(220, 14)
	time_bar.max_value = 1.0; time_bar.show_percentage = false
	time_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	hb.add_child(time_bar)
	phase_label = Label.new(); phase_label.custom_minimum_size = Vector2(110, 0); hb.add_child(phase_label)
	pause_btn = Button.new(); pause_btn.text = "Pause"; pause_btn.pressed.connect(func(): pause_toggled.emit()); hb.add_child(pause_btn)
	for m in [1, 2, 4, 8, 20]:
		var b := Button.new(); b.text = "%dx" % m; b.toggle_mode = true
		b.pressed.connect(func(): speed_changed.emit(float(m)))
		hb.add_child(b); speed_btns.append([m, b])
	var ov := Button.new(); ov.text = "Overview"; ov.pressed.connect(func(): overview_pressed.emit()); hb.add_child(ov)
	var spacer := Control.new(); spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL; hb.add_child(spacer)
	world_label = Label.new(); world_label.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6)); hb.add_child(world_label)
	# ---- roster (left)
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", _panel())
	left.set_anchors_preset(Control.PRESET_LEFT_WIDE)
	left.offset_left = 12; left.offset_top = 72; left.offset_bottom = -250; left.offset_right = 214
	root.add_child(left)
	roster = VBoxContainer.new()
	roster.add_theme_constant_override("separation", 3)
	left.add_child(roster)
	var rt := Label.new(); rt.text = "CIVILIZATIONS"; rt.add_theme_font_size_override("font_size", 12)
	rt.add_theme_color_override("font_color", Color(0.7, 0.65, 0.55)); roster.add_child(rt)
	for i in 12:
		var b := Button.new()
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.flat = true
		var info: Dictionary = BCData.RACES[i] if i < BCData.RACES.size() else BCData.SEALED[i - BCData.RACES.size()]
		b.add_theme_color_override("font_color", info.color)
		b.add_theme_color_override("font_hover_color", Color.WHITE)
		b.pressed.connect(func(): civ_picked.emit(i))
		roster.add_child(b)
		roster_btns.append(b)
	# ---- inspector (right)
	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", _panel())
	right.set_anchors_preset(Control.PRESET_RIGHT_WIDE)
	right.offset_right = -12; right.offset_left = -372; right.offset_top = 72; right.offset_bottom = -250
	root.add_child(right)
	inspector = RichTextLabel.new()
	inspector.bbcode_enabled = true
	inspector.fit_content = false
	inspector.scroll_active = true
	right.add_child(inspector)
	# ---- event log (bottom)
	var bottom := PanelContainer.new()
	bottom.add_theme_stylebox_override("panel", _panel())
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	bottom.offset_left = 12; bottom.offset_right = -12; bottom.offset_bottom = -10; bottom.offset_top = -236
	root.add_child(bottom)
	log_view = RichTextLabel.new()
	log_view.bbcode_enabled = true
	log_view.scroll_following = true
	bottom.add_child(log_view)
	sim.event_logged.connect(_on_event)
	for ev in sim.events: _on_event(ev)
	refresh(true)

func _on_event(ev: Dictionary) -> void:
	var col: String = KIND_COL.get(ev.kind, "#d8ccb4")
	log_view.append_text("[color=#8a7f6c]D%d[/color] [color=%s]%s[/color]\n" % [ev.day, col, ev.text])

func set_selected(i: int) -> void:
	selected = i
	_refresh_inspector()

func set_speed_ui(speed: float, paused: bool) -> void:
	pause_btn.text = "Resume" if paused else "Pause"
	for e in speed_btns: e[1].button_pressed = (not paused) and is_equal_approx(e[0], speed)

func refresh(force: bool = false) -> void:
	day_label.text = "Day %d" % sim.day
	time_bar.value = sim.t()
	phase_label.text = "locked (night)" if sim.locked else "open (day)"
	phase_label.add_theme_color_override("font_color", Color("ff8a78") if sim.locked else Color("9ee6a8"))
	world_label.text = "pop %d   battles %d   trades %d   hybrids %d" % [sim.total_pop(), sim.stats.battles, sim.stats.trades, sim.stats.hybrids]
	for i in 12:
		if i < sim.civs.size():
			var c: BCSim.Civ = sim.civs[i]
			var war := "  X" if c.war.size() > 0 else ""
			roster_btns[i].text = "%-12s %3d%s" % [c.name, c.citizens.size(), war]
		else:
			roster_btns[i].text = "%s  [sealed]" % BCData.SEALED[i - 10].jar
			roster_btns[i].disabled = false
	_refresh_inspector()

func _bar(v: float) -> String:
	var n := int(roundf(absf(v) / 10.0))
	return ("[color=#7ee59a]" if v >= 0 else "[color=#ff7a66]") + "|".repeat(n) + "[/color]"

func _refresh_inspector() -> void:
	if selected < 0:
		inspector.text = "[b]The Wall[/b]\n[color=#a89878]Twelve glass habitats, ten awake. By day the tubes between jars are open: caravans trade, raiders raid, envoys carry romance. At dusk every jar seals shut - whoever is still outside is locked in the neighbour's jar until dawn.\n\nClick a jar (or a name on the left) to inspect it.\nRight-drag orbit, wheel zoom, WASD pan, Esc overview.[/color]"
		return
	if selected >= sim.civs.size():
		var s: Dictionary = BCData.SEALED[selected - 10]
		inspector.text = "[b][color=#8b8ba8]%s[/color][/b]\n[color=#a89878]Sealed. The %s are not awake yet.[/color]" % [s.jar, s.name]
		return
	var c: BCSim.Civ = sim.civs[selected]
	var r: Dictionary = c.race
	var hy := 0
	for x in c.citizens:
		if sim.is_hybrid(x): hy += 1
	var t := "[font_size=22][b][color=%s]%s[/color][/b][/font_size]  [color=#a89878]%s[/color]\n" % [r.color.to_html(false), c.name, r.name]
	t += "[color=#c8bca0][b]%s.[/b] %s[/color]\n\n" % [r.skill, r.blurb]
	t += "Pop [b]%d[/b]/%d   Houses %d   Tech %d   Hybrids %d\n" % [c.citizens.size(), sim.capacity(c), c.houses, c.tech, hy]
	t += "Food %d  Wood %d  Ore %d  Goods %d  Lore %d  Gold %d\n" % [c.stock.food, c.stock.wood, c.stock.ore, c.stock.goods, c.stock.lore, c.stock.gold]
	var roles := ""
	for k in c.role_count: roles += "%s %d  " % [k, c.role_count[k]]
	t += "[color=#a89878]%s[/color]\n" % roles
	t += "[color=#a89878]births %d (hybrid %d) - raids %d - defended %d - kills %d / lost %d - trades %d[/color]\n\n" % [c.stats.births, c.stats.hybrid_births, c.stats.raids, c.stats.defended, c.stats.kills, c.stats.losses, c.stats.trades]
	t += "[b]Relations[/b]\n"
	var ls: Array = c.links.duplicate()
	ls.sort_custom(func(a, b): return c.rel[a] > c.rel[b])
	for j in ls:
		var o: BCSim.Civ = sim.civs[j]
		var w := " [color=#ff6a55]WAR[/color]" if c.war.has(j) else ""
		t += "[color=%s]%-11s[/color] %4d %s%s\n" % [o.race.color.to_html(false), o.race.name, int(c.rel[j]), _bar(c.rel[j]), w]
	inspector.text = t
