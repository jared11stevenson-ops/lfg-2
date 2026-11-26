extends RefCounted

static func style_btn(b: Button, col: Color, sel: Color) -> void:
	var table := {"normal": col, "hover": col.lightened(0.15), "pressed": sel, "hover_pressed": sel.lightened(0.1), "disabled": col.darkened(0.4), "focus": col}
	for st in table:
		var sb := StyleBoxFlat.new()
		sb.bg_color = table[st]
		sb.set_corner_radius_all(12)
		sb.set_border_width_all(3)
		sb.border_color = Color("1b2a1b")
		sb.content_margin_left = 10
		sb.content_margin_right = 10
		sb.shadow_size = 3
		sb.shadow_color = Color(0, 0, 0, 0.35)
		b.add_theme_stylebox_override(st, sb)
	for c in ["font_color", "font_hover_color", "font_focus_color"]:
		b.add_theme_color_override(c, Color("ffffff"))
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.45))
	b.add_theme_color_override("font_outline_color", Color("1d1230"))
	b.add_theme_constant_override("outline_size", 4)
	b.add_theme_color_override("font_pressed_color", Color("ffffff"))
	b.add_theme_color_override("font_hover_pressed_color", Color("ffffff"))
