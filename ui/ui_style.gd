class_name UiStyle
extends RefCounted
## Shared look for the HUD: chunky rounded panels, saturated accents. No imported assets.
const INK := Color("1d1030")
const PANEL := Color(0.10, 0.06, 0.18, 0.78)
const PANEL_EDGE := Color("ffe9b0")
const TEXT := Color("fff6e6")
const GOOD := Color("19e0c8")
const WARN := Color("ffc61a")
const BAD := Color("ff2f5f")
const PURPLE := Color("8f5cff")

const PHASE_COLORS: Dictionary = {
	&"PEACE": Color("0f9d8a"),
	&"WARNING": Color("f2a900"),
	&"PURGE_ACTIVE": Color("c4122f"),
	&"RESOLUTION": Color("7a47c8"),
}
const PHASE_TEXT_COLORS: Dictionary = {
	&"PEACE": Color("ffffff"),
	&"WARNING": Color("2a1600"),
	&"PURGE_ACTIVE": Color("ffffff"),
	&"RESOLUTION": Color("ffffff"),
}
const PHASE_TITLES: Dictionary = {
	&"PEACE": "PEACE",
	&"WARNING": "WARNING",
	&"PURGE_ACTIVE": "PURGE",
	&"RESOLUTION": "RESOLUTION",
}

static func box(bg: Color, edge: Color = PANEL_EDGE, radius: int = 14, border: int = 2) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = bg
	s.border_color = edge
	s.set_border_width_all(border)
	s.set_corner_radius_all(radius)
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 6
	s.content_margin_bottom = 6
	return s

static func label(text: String, size: int, color: Color = TEXT, bold_outline: bool = true) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	if bold_outline:
		l.add_theme_color_override("font_outline_color", INK)
		l.add_theme_constant_override("outline_size", maxi(3, size / 7))
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return l
