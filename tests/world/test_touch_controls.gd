extends TestCase
## On-screen controls driven with synthetic touch events (no real device involved).

func _tc() -> TouchControls:
	var t := TouchControls.new()
	t._ready() # built off-tree by the test runner
	return t

func _touch(idx: int, pos: Vector2, pressed: bool) -> InputEventScreenTouch:
	var e := InputEventScreenTouch.new()
	e.index = idx
	e.position = pos
	e.pressed = pressed
	return e

func _drag(idx: int, pos: Vector2, rel: Vector2) -> InputEventScreenDrag:
	var e := InputEventScreenDrag.new()
	e.index = idx
	e.position = pos
	e.relative = rel
	return e

func test_joystick_forward_back_left_right() -> void:
	var t: TouchControls = _tc()
	t._input(_touch(0, Vector2(200, 500), true))
	t._input(_drag(0, Vector2(200, 500 - 92), Vector2(0, -92)))
	check(t.move.y > 0.95 and absf(t.move.x) < 0.01, "drag up = forward (%s)" % str(t.move))
	t._input(_drag(0, Vector2(200 + 92, 500), Vector2(92, 92)))
	check(t.move.x > 0.95 and absf(t.move.y) < 0.01, "drag right = move right (%s)" % str(t.move))
	t._input(_drag(0, Vector2(200 - 40, 500 + 40), Vector2(-132, 40)))
	check(t.move.x < 0.0 and t.move.y < 0.0, "drag down-left = back-left (%s)" % str(t.move))
	check(t.move.length() <= 1.0001, "stick output clamped to 1")
	t._input(_touch(0, Vector2(160, 540), false))
	eq(t.move, Vector2.ZERO, "release zeroes the stick")
	t.free()

func test_deadzone() -> void:
	var t: TouchControls = _tc()
	t._input(_touch(0, Vector2(200, 500), true))
	t._input(_drag(0, Vector2(205, 500), Vector2(5, 0)))
	eq(t.move, Vector2.ZERO, "tiny drag inside the dead zone does nothing")
	t.free()

func test_buttons_emit_and_do_not_move_stick() -> void:
	var t: TouchControls = _tc()
	var got: Array[String] = []
	t.interact_pressed.connect(func() -> void: got.append("interact"))
	t.action_pressed.connect(func() -> void: got.append("action"))
	t.map_pressed.connect(func() -> void: got.append("map"))
	t.bag_pressed.connect(func() -> void: got.append("bag"))
	t.grid_pressed.connect(func() -> void: got.append("grid"))
	var i := 1
	for n in TouchControls.BUTTONS:
		t._input(_touch(i, t.button_rects[n]["c"], true))
		t._input(_touch(i, t.button_rects[n]["c"], false))
		i += 1
	eq(got, ["interact", "action", "map", "bag", "grid"], "each on-screen button emits its signal")
	eq(t.move, Vector2.ZERO, "button taps never move the stick")
	t.free()

func test_multitouch_move_and_button() -> void:
	var t: TouchControls = _tc()
	var hits := [0]
	t.interact_pressed.connect(func() -> void: hits[0] += 1)
	t._input(_touch(0, Vector2(180, 520), true))
	t._input(_drag(0, Vector2(180, 440), Vector2(0, -80)))
	t._input(_touch(1, t.button_rects["interact"]["c"], true))
	check(t.move.y > 0.8, "stick still held while pressing USE")
	eq(hits[0], 1, "USE fired while moving")
	t.free()

func test_camera_drag_and_pinch_in_free_area() -> void:
	var t: TouchControls = _tc()
	var drags: Array[Vector2] = []
	var zooms: Array[float] = []
	t.camera_dragged.connect(func(d: Vector2) -> void: drags.append(d))
	t.camera_zoomed.connect(func(z: float) -> void: zooms.append(z))
	t._input(_touch(5, Vector2(700, 300), true))
	t._input(_drag(5, Vector2(730, 300), Vector2(30, 0)))
	eq(drags.size(), 1, "one-finger drag on free area orbits camera")
	eq(t.move, Vector2.ZERO, "camera drag does not move the character")
	t._input(_touch(6, Vector2(800, 300), true))
	t._input(_drag(6, Vector2(900, 300), Vector2(100, 0)))
	check(zooms.size() > 0 and zooms[0] < 1.0, "pinch out zooms in (factor %s)" % str(zooms))
	t.free()

func test_keyboard_shortcuts() -> void:
	var t: TouchControls = _tc()
	var got: Array[String] = []
	t.interact_pressed.connect(func() -> void: got.append("e"))
	t.map_pressed.connect(func() -> void: got.append("m"))
	for k in [KEY_E, KEY_M]:
		var ev := InputEventKey.new()
		ev.physical_keycode = k
		ev.pressed = true
		t._input(ev)
	eq(got, ["e", "m"], "E and M map to interact and map")
	t.free()

func test_layout_fits_viewport_and_does_not_overlap() -> void:
	var t: TouchControls = _tc()
	var vs := Vector2(1280, 720)
	var names: Array = TouchControls.BUTTONS
	for n in names:
		var b: Dictionary = t.button_rects[n]
		var c: Vector2 = b["c"]
		var r: float = b["r"]
		check(c.x - r >= 0.0 and c.y - r >= 0.0 and c.x + r <= vs.x and c.y + r <= vs.y, "%s fully on screen" % n)
		check(r >= 30.0, "%s touch target >= 60 px across" % n)
	for i in names.size():
		for j in range(i + 1, names.size()):
			var a: Dictionary = t.button_rects[names[i]]
			var b2: Dictionary = t.button_rects[names[j]]
			check((a["c"] as Vector2).distance_to(b2["c"]) > float(a["r"]) + float(b2["r"]), "%s and %s do not overlap" % [names[i], names[j]])
	var joy: Vector2 = t._joy_idle_base
	check(joy.x - TouchControls.JOY_RADIUS >= 0.0 and joy.y + TouchControls.JOY_RADIUS <= vs.y, "joystick on screen")
	for n in names:
		check((t.button_rects[n]["c"] as Vector2).distance_to(joy) > TouchControls.JOY_RADIUS + float(t.button_rects[n]["r"]), "%s clear of joystick" % n)
	t.free()
