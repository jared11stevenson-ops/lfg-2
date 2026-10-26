class_name PanelBase
extends PanelContainer
## Centered landscape modal panel: title bar, close button (touch-sized), scrollable body. Pure view; signals only.
signal closed
var title_label: Label
var close_btn: Button
var body: VBoxContainer
var status: Label

func _init(title: String = "", size: Vector2 = Vector2(820, 540)) -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_CENTER)
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -size.x * 0.5
	offset_right = size.x * 0.5
	offset_top = -size.y * 0.5
	offset_bottom = size.y * 0.5
	custom_minimum_size = size
	add_theme_stylebox_override("panel", UiStyle.box(Color(0.08, 0.04, 0.16, 0.95), UiStyle.PANEL_EDGE, 20, 3))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 8)
	add_child(v)
	var bar := HBoxContainer.new()
	v.add_child(bar)
	title_label = UiKit.heading(title, 32)
	title_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	bar.add_child(title_label)
	close_btn = UiKit.button("X", UiStyle.BAD, Vector2(64, 56), 26)
	close_btn.pressed.connect(close)
	bar.add_child(close_btn)
	body = VBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 8)
	v.add_child(body)
	status = UiStyle.label("", 20, UiStyle.TEXT, false)
	v.add_child(status)

func open() -> void:
	visible = true

func close() -> void:
	if visible:
		visible = false
		closed.emit()

func set_status(text: String, color: Color = UiStyle.TEXT) -> void:
	status.text = text
	status.add_theme_color_override("font_color", color)
