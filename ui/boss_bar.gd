class_name BossBar
extends Control
## Region guardian health bar: name, a chunky health bar with a notch at each phase change, and a flashing "incoming" line while an attack winds up (the ground marker
## shows WHERE, this says WHAT and WHEN). Pure view: set_model(Guardians.nearest_boss(...)) with {} to hide. Touch-sized text, no input.
var model: Dictionary = {}
var name_label: Label
var bar_back: Panel
var bar_fill: Panel
var warn_label: Label
var _fill_style: StyleBoxFlat
const WIDTH := 520.0

func _init() -> void:
	name = "BossBar"
	visible = false
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	anchor_left = 0.5
	anchor_right = 0.5
	offset_left = -WIDTH * 0.5
	offset_right = WIDTH * 0.5
	offset_top = 262
	offset_bottom = 356
	name_label = UiStyle.label("", 24, UiStyle.WARN)
	name_label.position = Vector2(0, 0)
	add_child(name_label)
	bar_back = Panel.new()
	bar_back.position = Vector2(0, 34)
	bar_back.size = Vector2(WIDTH, 22)
	bar_back.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar_back.add_theme_stylebox_override("panel", UiStyle.box(Color(0.1, 0.04, 0.14, 0.85), UiStyle.PANEL_EDGE, 8, 2))
	add_child(bar_back)
	bar_fill = Panel.new()
	bar_fill.position = Vector2(3, 37)
	bar_fill.size = Vector2(WIDTH - 6, 16)
	bar_fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fill_style = UiStyle.box(UiStyle.BAD, UiStyle.BAD, 6, 0)
	bar_fill.add_theme_stylebox_override("panel", _fill_style)
	add_child(bar_fill)
	warn_label = UiStyle.label("", 22, UiStyle.BAD)
	warn_label.position = Vector2(0, 60)
	add_child(warn_label)

static func pretty(attack: String) -> String:
	return attack.replace("_", " ").capitalize()

func set_model(m: Dictionary) -> void:
	model = m
	visible = not m.is_empty()
	if m.is_empty():
		return
	name_label.text = String(m["name"]).to_upper() + ("   (enraged)" if int(m.get("phase", 0)) > 0 else "")
	var f: float = clampf(float(m["hp"]) / maxf(1.0, float(m["max_hp"])), 0.0, 1.0)
	bar_fill.size.x = (WIDTH - 6.0) * f
	bar_fill.visible = f > 0.0
	_fill_style.bg_color = UiStyle.WARN if int(m.get("phase", 0)) > 0 else UiStyle.BAD
	var att: String = String(m.get("attack", ""))
	warn_label.text = ("!  %s  !" % pretty(att)) if att != "" and float(m.get("windup_left", 0.0)) > 0.0 else ""
