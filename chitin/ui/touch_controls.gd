class_name TouchControls
extends Control
## Multi-touch twin-stick overlay drawn in code. Handles raw touch events by
## index (so thumbs never fight), and presses real InputMap actions so the same
## player code runs on phone and keyboard. Desktop mouse is emulated as touch.

var move := Vector2.ZERO
var stick_id := -1
var stick_origin := Vector2.ZERO
var stick_pos := Vector2.ZERO
var buttons := {}      # action -> {pos:Vector2 (from bottom-right), r:float, label:String, id:int}
const STICK_R := 90.0

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = get_viewport_rect().size
	get_viewport().size_changed.connect(func(): size = get_viewport_rect().size; queue_redraw())
	buttons = {
		"attack": {"pos": Vector2(150, 150), "r": 74.0, "label": "BITE", "id": -1},
		"ability_1": {"pos": Vector2(290, 90), "r": 52.0, "label": "", "id": -1},
		"ability_2": {"pos": Vector2(250, 220), "r": 52.0, "label": "", "id": -1},
		"ability_3": {"pos": Vector2(110, 290), "r": 52.0, "label": "", "id": -1},
		"scent_toggle": {"pos": Vector2(380, 80), "r": 46.0, "label": "SCENT", "id": -1},
		"molt": {"pos": Vector2(60, 440), "r": 62.0, "label": "MOLT", "id": -1, "hidden": true},
	}

func set_label(action: String, text: String) -> void:
	if buttons.has(action):
		buttons[action].label = text
		queue_redraw()

func set_hidden(action: String, h: bool) -> void:
	if buttons.has(action):
		buttons[action]["hidden"] = h
		queue_redraw()

func _btn_center(b: Dictionary) -> Vector2:
	var s := size
	return Vector2(s.x - b.pos.x, s.y - b.pos.y)

func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		var p: Vector2 = event.position
		if event.pressed:
			for a in buttons:
				var b: Dictionary = buttons[a]
				if b.get("hidden", false) or b.label == "":
					continue
				if p.distance_to(_btn_center(b)) <= b.r + 12.0:
					b.id = event.index
					Input.action_press(a)
					queue_redraw()
					get_viewport().set_input_as_handled()
					return
			if p.x < size.x * 0.45 and stick_id == -1:
				stick_id = event.index
				stick_origin = p
				stick_pos = p
				get_viewport().set_input_as_handled()
		else:
			if event.index == stick_id:
				stick_id = -1
				move = Vector2.ZERO
			for a in buttons:
				if buttons[a].id == event.index:
					buttons[a].id = -1
					Input.action_release(a)
			queue_redraw()
	elif event is InputEventScreenDrag and event.index == stick_id:
		stick_pos = event.position
		var d := stick_pos - stick_origin
		if d.length() > STICK_R:
			d = d.normalized() * STICK_R
			stick_pos = stick_origin + d
		move = d / STICK_R
		queue_redraw()

func _draw() -> void:
	if stick_id != -1:
		draw_circle(stick_origin, STICK_R, Color(1, 1, 1, 0.08))
		draw_arc(stick_origin, STICK_R, 0, TAU, 32, Color(0.5, 1.0, 0.8, 0.5), 3.0)
		draw_circle(stick_pos, 34.0, Color(0.5, 1.0, 0.8, 0.45))
	else:
		var hint := Vector2(150, size.y - 150)
		draw_arc(hint, STICK_R, 0, TAU, 32, Color(0.5, 1.0, 0.8, 0.15), 2.0)
	var font := ThemeDB.fallback_font
	for a in buttons:
		var b: Dictionary = buttons[a]
		if b.get("hidden", false) or b.label == "":
			continue
		var c := _btn_center(b)
		var held: bool = b.id != -1
		var col := Color(0.9, 0.5, 0.2) if a == "attack" else (Color(1.0, 0.8, 0.3) if a == "molt" else Color(0.5, 0.9, 0.8))
		draw_circle(c, b.r, Color(col.r, col.g, col.b, 0.5 if held else 0.22))
		draw_arc(c, b.r, 0, TAU, 32, Color(col.r, col.g, col.b, 0.9), 3.0)
		var fs := 22 if b.label.length() <= 5 else 17
		var w := font.get_string_size(b.label, HORIZONTAL_ALIGNMENT_CENTER, -1, fs).x
		draw_string(font, c + Vector2(-w * 0.5, fs * 0.35), b.label, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color(1, 1, 1, 0.95))
