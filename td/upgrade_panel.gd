extends PanelContainer
# Bloons-style upgrade panel: two paths, four tiers each, only one path past tier 2.
const UiStyle = preload("res://ui_style.gd")
const PuppetLib = preload("res://puppet_lib.gd")
const Moves = preload("res://moves.gd")
const Session = preload("res://session.gd")
signal upgrade(path)
signal sell
signal cycle_target
var t
var title: Label
var sub: Label
var btn := {}
var tgt: Button
var sellb: Button
var portrait: TextureRect
var xpbar: ProgressBar
var xplbl: Label
var moves_lbl: Label

func _ready() -> void:
	custom_minimum_size = Vector2(380, 0)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.13, 0.11, 0.94)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(4)
	sb.border_color = Color("f0b43c")
	sb.set_content_margin_all(12)
	add_theme_stylebox_override("panel", sb)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	v.add_child(head)
	portrait = TextureRect.new()
	portrait.custom_minimum_size = Vector2(84, 84)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	head.add_child(portrait)
	var hv := VBoxContainer.new()
	hv.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(hv)
	title = Label.new()
	title.add_theme_font_size_override("font_size", 28)
	hv.add_child(title)
	sub = Label.new()
	sub.add_theme_font_size_override("font_size", 16)
	sub.modulate = Color(1, 1, 1, 0.8)
	hv.add_child(sub)
	xpbar = ProgressBar.new()
	xpbar.custom_minimum_size = Vector2(0, 12)
	xpbar.show_percentage = false
	var bg := StyleBoxFlat.new(); bg.bg_color = Color(0.05, 0.05, 0.12); bg.set_corner_radius_all(6)
	var fg := StyleBoxFlat.new(); fg.bg_color = Color("6fd0ff"); fg.set_corner_radius_all(6)
	xpbar.add_theme_stylebox_override("background", bg)
	xpbar.add_theme_stylebox_override("fill", fg)
	v.add_child(xpbar)
	xplbl = Label.new()
	xplbl.add_theme_font_size_override("font_size", 14)
	xplbl.modulate = Color("9fe8ff")
	v.add_child(xplbl)
	moves_lbl = Label.new()
	moves_lbl.add_theme_font_size_override("font_size", 14)
	moves_lbl.modulate = Color(1, 1, 1, 0.85)
	v.add_child(moves_lbl)
	for p in ["a", "b"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 78)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 16)
		UiStyle.style_btn(b, Color("2f6b3a") if p == "a" else Color("2f5f8a"), Color("d9892a"))
		b.pressed.connect(func(): upgrade.emit(p))
		v.add_child(b)
		btn[p] = b
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	tgt = Button.new()
	tgt.custom_minimum_size = Vector2(0, 54)
	tgt.add_theme_font_size_override("font_size", 20)
	tgt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.style_btn(tgt, Color("4a4f66"), Color("4a4f66"))
	tgt.pressed.connect(func(): cycle_target.emit())
	row.add_child(tgt)
	sellb = Button.new()
	sellb.custom_minimum_size = Vector2(0, 54)
	sellb.add_theme_font_size_override("font_size", 20)
	sellb.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.style_btn(sellb, Color("a63d3d"), Color("a63d3d"))
	sellb.pressed.connect(func(): sell.emit())
	row.add_child(sellb)
	visible = false

func show_for(tower, coins: int) -> void:
	t = tower
	visible = true
	refresh(coins)

func refresh(coins: int) -> void:
	if t == null or not is_instance_valid(t):
		return
	title.text = "%s  Lv %d" % [t.def.name, t.lvl]
	var full: Texture2D = PuppetLib.tex(String(t.def.get("sprite", t.def.id)), "idle", 0)
	if full != null:
		var at := AtlasTexture.new()
		at.atlas = full
		var sc := full.get_width() / 192.0
		at.region = Rect2(25 * sc, 55 * sc, 150 * sc, 130 * sc)
		portrait.texture = at
	var id := String(t.def.id)
	var run_xp: int = int(t.get_parent().run_xp.get(id, 0)) if t.get_parent() != null and "run_xp" in t.get_parent() else 0
	var xp: int = int(Session.xp.get(id, 0)) + run_xp
	var lo := Session.xp_for_level(t.lvl)
	var hi := Session.xp_for_level(t.lvl + 1)
	if t.lvl >= Session.MAX_LEVEL:
		xpbar.value = 1.0; xplbl.text = "Max level"
	else:
		xpbar.max_value = float(hi - lo); xpbar.value = clampf(float(xp - lo), 0.0, float(hi - lo))
		xplbl.text = "XP %d / %d   (banked at the end of the run)" % [maxi(0, xp - lo), hi - lo]
	var ml := ""
	for mv in Moves.for_type(String(t.def.types[0])):
		ml += "%s %s  %s%s\n" % ["✔" if t.lvl >= int(mv.lvl) else "·", mv.name, mv.desc, "" if t.lvl >= int(mv.lvl) else "  (Lv %d)" % int(mv.lvl)]
	moves_lbl.text = ml.strip_edges()
	sub.text = "%s    Tiers A%d / B%d\nDmg %.0f   Speed %.1f/s   Range %.0f" % [" / ".join(t.def.types.map(func(x): return x.capitalize())), t.tiers.a, t.tiers.b, float(t.st.dmg), float(t.st.rate), float(t.st.range)]
	for p in ["a", "b"]:
		var u: Dictionary = t.next_upgrade(p)
		var b: Button = btn[p]
		if u.is_empty():
			b.text = "Path %s: MAXED" % p.to_upper()
			b.disabled = true
		elif t.blocked(p):
			b.text = "Path %s: locked\n(other path is tier 3+)" % p.to_upper()
			b.disabled = true
		else:
			b.text = "%s   [%d]\n%s" % [u.name, u.cost, u.desc]
			b.disabled = coins < int(u.cost)
	tgt.text = "Target: %s" % t.target_mode.capitalize()
	sellb.text = "Sell +%d" % int(t.spent * 0.7)
