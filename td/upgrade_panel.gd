extends PanelContainer
# Bloons-style upgrade panel: two paths, four tiers each, only one path past tier 2.
const UiStyle = preload("res://ui_style.gd")
signal upgrade(path)
signal sell
signal cycle_target
var t
var title: Label
var sub: Label
var btn := {}
var tgt: Button
var sellb: Button

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
	title = Label.new()
	title.add_theme_font_size_override("font_size", 28)
	v.add_child(title)
	sub = Label.new()
	sub.add_theme_font_size_override("font_size", 16)
	sub.modulate = Color(1, 1, 1, 0.8)
	v.add_child(sub)
	for p in ["a", "b"]:
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 78)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 16)
		UiStyle.style_btn(b, Color("2f6b3a") if p == "a" else Color("2f5f8a"), Color("f0b43c"))
		b.pressed.connect(func(): upgrade.emit(p))
		v.add_child(b)
		btn[p] = b
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	tgt = Button.new()
	tgt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	UiStyle.style_btn(tgt, Color("4a4f66"), Color("4a4f66"))
	tgt.pressed.connect(func(): cycle_target.emit())
	row.add_child(tgt)
	sellb = Button.new()
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
	title.text = t.def.name
	sub.text = "%s    Tiers A%d / B%d" % [" / ".join(t.def.types.map(func(x): return x.capitalize())), t.tiers.a, t.tiers.b]
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
