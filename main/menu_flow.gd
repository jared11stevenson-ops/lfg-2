class_name MenuFlow
extends CanvasLayer
## Front-end controller: MainMenu -> ClassSelect -> (start) and the end screens. Owns no game logic; the lead listens:
##   new_match_requested(class_id, seed)  -> Rules.new_match + stage rebuild
##   continue_requested                   -> load the saved match
##   endless_requested                    -> keep playing after victory
##   quit_requested                       -> get_tree().quit()
##   options_changed(options)             -> stage.apply_options(options)
## Call show_menu(), show_game_over(info), show_victory(info) as the game moves between states.
signal new_match_requested(class_id: String, seed_value: int)
signal continue_requested
signal endless_requested
signal quit_requested
signal options_changed(options: Dictionary)
var main_menu: MainMenu
var class_select: ClassSelect
var end_screen: GameEndScreen

func _init() -> void:
	name = "MenuFlow"
	layer = 30
	main_menu = MainMenu.new()
	class_select = ClassSelect.new()
	end_screen = GameEndScreen.new()
	add_child(main_menu)
	add_child(class_select)
	add_child(end_screen)
	class_select.visible = false
	main_menu.new_match_pressed.connect(func() -> void:
		main_menu.visible = false
		class_select.visible = true)
	main_menu.continue_pressed.connect(func() -> void:
		hide_all()
		continue_requested.emit())
	main_menu.quit_pressed.connect(func() -> void: quit_requested.emit())
	main_menu.options_changed.connect(func(o: Dictionary) -> void: options_changed.emit(o))
	class_select.back_requested.connect(show_menu)
	class_select.start_requested.connect(func(cid: String, sd: int) -> void:
		hide_all()
		new_match_requested.emit(cid, sd))
	end_screen.new_match_requested.connect(func() -> void:
		end_screen.visible = false
		main_menu.visible = false
		class_select.visible = true)
	end_screen.menu_requested.connect(show_menu)
	end_screen.continue_endless_requested.connect(func() -> void:
		hide_all()
		endless_requested.emit())

func hide_all() -> void:
	main_menu.visible = false
	class_select.visible = false
	end_screen.visible = false
	visible = false

func show_menu() -> void:
	visible = true
	end_screen.visible = false
	class_select.visible = false
	main_menu.visible = true

func show_game_over(info: Dictionary) -> void:
	visible = true
	main_menu.visible = false
	class_select.visible = false
	end_screen.show_game_over(info)

func show_victory(info: Dictionary) -> void:
	visible = true
	main_menu.visible = false
	class_select.visible = false
	end_screen.show_victory(info)

## Route Rules events (match_over / victory) to the end screens. `extra` = {day, class_label, holdings, total_holdings}.
func handle_events(events: Array, extra: Dictionary = {}) -> void:
	for e in events:
		var t: StringName = e.get("type", &"")
		if t == &"match_over":
			var info: Dictionary = extra.duplicate()
			info["reason"] = e.get("reason", "")
			info["day"] = e.get("day", extra.get("day", 0))
			show_game_over(info)
		elif t == &"victory":
			var info2: Dictionary = extra.duplicate()
			info2["kind"] = e.get("kind", "")
			show_victory(info2)
