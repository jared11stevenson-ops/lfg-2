class_name UiKit
extends RefCounted
## Small widget factory shared by every panel/screen: touch-sized buttons (>= 56 px), chips, item labels.
const MIN_TOUCH := 56.0

static func item_name(id: String) -> String:
	var it: Dictionary = Content.item(id)
	return String(it.get("name", id.get_slice("/", 1).capitalize()))

static func item_color(id: String) -> Color:
	return Color.from_hsv(float(absi(hash(id)) % 360) / 360.0, 0.6, 1.0)

static func clear(n: Node) -> void:
	for c in n.get_children():
		n.remove_child(c)
		c.queue_free()

static func button(text: String, color: Color = UiStyle.PURPLE, min_size: Vector2 = Vector2(120, MIN_TOUCH), font: int = 22) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(maxf(min_size.x, 0.0), maxf(min_size.y, MIN_TOUCH))
	b.focus_mode = Control.FOCUS_NONE
	b.add_theme_font_size_override("font_size", font)
	b.add_theme_color_override("font_color", UiStyle.TEXT)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.35))
	var n: StyleBoxFlat = UiStyle.box(color.darkened(0.25), color.lightened(0.2), 14, 2)
	var h: StyleBoxFlat = UiStyle.box(color, Color("ffffff"), 14, 3)
	var p: StyleBoxFlat = UiStyle.box(color.lightened(0.2), Color("ffffff"), 14, 3)
	var d: StyleBoxFlat = UiStyle.box(Color(0.2, 0.18, 0.26, 0.8), Color(1, 1, 1, 0.15), 14, 2)
	b.add_theme_stylebox_override("normal", n)
	b.add_theme_stylebox_override("hover", h)
	b.add_theme_stylebox_override("pressed", p)
	b.add_theme_stylebox_override("disabled", d)
	return b

static func chip(text: String, color: Color, font: int = 18) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.box(color.darkened(0.55), color, 10, 2))
	var l: Label = UiStyle.label(text, font, UiStyle.TEXT, false)
	p.add_child(l)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return p

## cost entries: [{item, name, need, have, ok}] -> HBox of chips (red when short).
static func cost_row(entries: Array) -> HBoxContainer:
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 6)
	for e in entries:
		var ok: bool = bool(e.get("ok", true))
		h.add_child(chip("%s %d/%d" % [e.get("name", "?"), int(e.get("have", 0)), int(e.get("need", 0))] if e.has("have") else "%s x%d" % [e.get("name", "?"), int(e.get("need", 0))], UiStyle.GOOD if ok else UiStyle.BAD))
	return h

static func heading(text: String, size: int = 26, color: Color = UiStyle.WARN) -> Label:
	return UiStyle.label(text, size, color)

static func card(color: Color = UiStyle.PANEL) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.box(color, Color(1, 1, 1, 0.25), 12, 2))
	return p

static func scroll(min_h: float = 300.0) -> ScrollContainer:
	var s := ScrollContainer.new()
	s.custom_minimum_size = Vector2(0, min_h)
	s.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	s.size_flags_vertical = Control.SIZE_EXPAND_FILL
	s.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return s

## Count buttons whose minimum height is below the touch target. Tests use it on every panel.
static func small_buttons(root: Node) -> Array[String]:
	var out: Array[String] = []
	var stack: Array[Node] = [root]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button and (n as Button).custom_minimum_size.y < MIN_TOUCH - 0.01:
			out.append((n as Button).text)
		stack.append_array(n.get_children())
	return out
