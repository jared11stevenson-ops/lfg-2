extends SceneTree
# UI interaction smoke test: real mouse events place, select, upgrade and sell a defender; menu data flows work.
const Session = preload("res://session.gd")
var main
var frames := 0
var fails := 0

func _click(p: Vector2) -> void:
	var ev := InputEventMouseButton.new()
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = true
	ev.position = p
	main._unhandled_input(ev)

func _check(cond: bool, msg: String) -> void:
	if not cond:
		fails += 1
		print("FAIL ", msg)

func _initialize() -> void:
	Session.no_save = true
	Session.level_id = "gloamwood"
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _process(_d: float) -> bool:
	frames += 1
	if frames == 3:
		var c0: int = main.coins
		_click(Vector2(500, 300))   # a valid ground spot (also near a stone)
		var towers := get_nodes_in_group("towers")
		_check(towers.size() == 1, "tower placed by click")
		_check(main.coins < c0, "coins spent on placement")
		_click(Vector2(380, 190))   # on the lane: must be rejected
		_check(get_nodes_in_group("towers").size() == 1, "placement on lane rejected")
		var t = towers[0]
		_click(t.position)          # select
		_check(main.sel_tower == t and main.panel.visible, "tower selected, panel visible")
		main.coins = 5000
		main._on_upgrade("a")
		main._on_upgrade("a")
		_check(t.tiers.a == 2, "upgrades bought via panel")
		var c1: int = main.coins
		main._on_sell()
		_check(main.coins > c1, "sell refunds coins")
		_check(get_nodes_in_group("towers").size() == 0 or t.is_queued_for_deletion(), "tower removed after sell")
		main._start_wave()
		_check(main.wave == 1 and main.wave_running, "wave starts")
	if frames == 200:
		_check(get_nodes_in_group("enemies").size() > 0, "enemies spawned")
		print("ui: ", "ok" if fails == 0 else "%d failures" % fails)
		quit(1 if fails > 0 else 0)
	return false
