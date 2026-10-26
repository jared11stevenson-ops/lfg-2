class_name TouchControls
extends CanvasLayer
## Landscape on-screen controls: floating left joystick, right-hand action buttons, drag-to-orbit camera and
## pinch zoom in the free area. Also maps keyboard shortcuts to the same signals so desktop == phone.
## Works with emulate_touch_from_mouse (project setting), so mouse clicks drive it on desktop too.
signal interact_pressed
signal action_pressed
signal map_pressed
signal bag_pressed
signal grid_pressed
signal camera_dragged(delta: Vector2)
signal camera_zoomed(factor: float)

const JOY_RADIUS := 92.0
const DEADZONE := 0.12
const BUTTONS: Array[String] = ["interact", "action", "map", "bag", "grid"]

var move: Vector2 = Vector2.ZERO # x right, y forward
var button_rects: Dictionary = {} # name -> {c:Vector2, r:float, label:String, color:Color}
var _canvas: Control
var _joy_idx: int = -1
var _joy_base: Vector2 = Vector2.ZERO
var _joy_knob: Vector2 = Vector2.ZERO
var _btn_idx: Dictionary = {} # touch index -> button name
var _cam_touches: Dictionary = {} # index -> last position
var _pinch_prev: float = 0.0
var visible_ui: bool = true

func _init() -> void:
	name = "TouchControls"
	layer = 8

func _ready() -> void:
	_canvas = Control.new()
	_canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_canvas.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_canvas.draw.connect(_draw_ui)
	_canvas.resized.connect(_layout)
	add_child(_canvas)
	_layout()

func _viewport_size() -> Vector2:
	return get_viewport().get_visible_rect().size if is_inside_tree() else Vector2(1280, 720)

func _safe_margin() -> Vector2:
	if OS.has_feature("mobile"):
		var win: Vector2i = DisplayServer.window_get_size()
		var area: Rect2i = DisplayServer.get_display_safe_area()
		var vs: Vector2 = _viewport_size()
		var sx: float = vs.x / maxf(float(win.x), 1.0)
		return Vector2(maxf(float(area.position.x) * sx, 0.0), 0.0)
	return Vector2.ZERO

func _layout() -> void:
	var vs: Vector2 = _viewport_size()
	var m: Vector2 = _safe_margin()
	button_rects.clear()
	var right: float = vs.x - 24.0 - m.x
	var bottom: float = vs.y - 24.0
	button_rects["interact"] = {"c": Vector2(right - 70, bottom - 80), "r": 66.0, "label": "USE", "color": Color("19e0c8")}
	button_rects["action"] = {"c": Vector2(right - 215, bottom - 52), "r": 52.0, "label": "HIT", "color": Color("ff2fb5")}
	button_rects["bag"] = {"c": Vector2(right - 185, bottom - 190), "r": 40.0, "label": "BAG", "color": Color("ffc61a")}
	button_rects["map"] = {"c": Vector2(right - 60, bottom - 215), "r": 40.0, "label": "MAP", "color": Color("8f5cff")}
	button_rects["grid"] = {"c": Vector2(right - 300, bottom - 150), "r": 34.0, "label": "HEX", "color": Color("ff7a2f")}
	_joy_idle_base = Vector2(150.0 + m.x, vs.y - 160.0)
	if _joy_idx == -1:
		_joy_base = _joy_idle_base
		_joy_knob = _joy_base
	_canvas.queue_redraw()

var _joy_idle_base: Vector2 = Vector2(150, 560)

func _button_at(p: Vector2) -> String:
	for n in BUTTONS:
		var b: Dictionary = button_rects[n]
		if p.distance_to(b["c"]) <= b["r"] + 12.0:
			return n
	return ""

func _emit_button(n: String) -> void:
	match n:
		"interact": interact_pressed.emit()
		"action": action_pressed.emit()
		"map": map_pressed.emit()
		"bag": bag_pressed.emit()
		"grid": grid_pressed.emit()

func _input(event: InputEvent) -> void:
	if not visible_ui:
		return
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			var btn: String = _button_at(t.position)
			if btn != "":
				_btn_idx[t.index] = btn
				_emit_button(btn)
			elif _joy_idx == -1 and t.position.x < _viewport_size().x * 0.45 and t.position.y > _viewport_size().y * 0.2:
				_joy_idx = t.index
				_joy_base = t.position
				_joy_knob = t.position
				move = Vector2.ZERO
			else:
				_cam_touches[t.index] = t.position
				_pinch_prev = _pinch_dist()
		else:
			_btn_idx.erase(t.index)
			_cam_touches.erase(t.index)
			_pinch_prev = 0.0
			if t.index == _joy_idx:
				_joy_idx = -1
				move = Vector2.ZERO
				_joy_base = _joy_idle_base
				_joy_knob = _joy_base
		_canvas.queue_redraw()
	elif event is InputEventScreenDrag:
		var d := event as InputEventScreenDrag
		if d.index == _joy_idx:
			var off: Vector2 = (d.position - _joy_base).limit_length(JOY_RADIUS)
			_joy_knob = _joy_base + off
			var v: Vector2 = off / JOY_RADIUS
			if v.length() < DEADZONE:
				v = Vector2.ZERO
			move = Vector2(v.x, -v.y)
			_canvas.queue_redraw()
		elif _cam_touches.has(d.index):
			_cam_touches[d.index] = d.position
			if _cam_touches.size() >= 2:
				var pd: float = _pinch_dist()
				if _pinch_prev > 1.0 and pd > 1.0:
					camera_zoomed.emit(_pinch_prev / pd)
				_pinch_prev = pd
			else:
				camera_dragged.emit(d.relative)
	elif event is InputEventKey and event.pressed and not event.echo:
		match (event as InputEventKey).physical_keycode:
			KEY_E: interact_pressed.emit()
			KEY_F: action_pressed.emit()
			KEY_M: map_pressed.emit()
			KEY_I: bag_pressed.emit()
			KEY_G: grid_pressed.emit()

func _pinch_dist() -> float:
	if _cam_touches.size() < 2:
		return 0.0
	var ks: Array = _cam_touches.keys()
	return (_cam_touches[ks[0]] as Vector2).distance_to(_cam_touches[ks[1]])

func _draw_ui() -> void:
	if not visible_ui:
		return
	var font: Font = ThemeDB.fallback_font
	# joystick
	var active: bool = _joy_idx != -1
	_canvas.draw_circle(_joy_base, JOY_RADIUS, Color(1, 1, 1, 0.10 if not active else 0.18))
	_canvas.draw_arc(_joy_base, JOY_RADIUS, 0.0, TAU, 40, Color(1, 1, 1, 0.45), 3.0, true)
	_canvas.draw_circle(_joy_knob, 38.0, Color(1.0, 0.95, 0.75, 0.55 if active else 0.35))
	_canvas.draw_arc(_joy_knob, 38.0, 0.0, TAU, 28, Color(1, 1, 1, 0.8), 3.0, true)
	for n in BUTTONS:
		var b: Dictionary = button_rects[n]
		var pressed: bool = _btn_idx.values().has(n)
		var col: Color = b["color"]
		_canvas.draw_circle(b["c"], b["r"], Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 0.78 if not pressed else 0.95))
		_canvas.draw_arc(b["c"], b["r"], 0.0, TAU, 36, col.lightened(0.2 if not pressed else 0.6), 4.0, true)
		var fs: int = int(b["r"] * 0.5)
		var ts: Vector2 = font.get_string_size(b["label"], HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		_canvas.draw_string_outline(font, b["c"] + Vector2(-ts.x * 0.5, ts.y * 0.28), b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color("1d1030"))
		_canvas.draw_string(font, b["c"] + Vector2(-ts.x * 0.5, ts.y * 0.28), b["label"], HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff6e6"))
