class_name GameEndScreen
extends Control
## Permadeath (game over) and victory screens. Signals only: new_match_requested, menu_requested, continue_endless_requested.
signal new_match_requested
signal menu_requested
signal continue_endless_requested
const REASON_TEXT: Dictionary = {
	"leader_died": "Your leader has fallen.",
	"starved_out": "Starved out: no holdings, no rations, no way to farm.",
}
const VICTORY_TEXT: Dictionary = {
	"dominion": "DOMINION - you hold most of the frontier.",
	"crowned": "CROWNED - you outlasted twelve Purges.",
}
var kind: StringName = &""
var title_label: Label
var reason_label: Label
var stats_label: Label
var primary_btn: Button
var menu_btn: Button
var panel: PanelContainer
var veil: ColorRect

func _init() -> void:
	name = "GameEndScreen"
	visible = false
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil = ColorRect.new()
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(veil)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.anchor_left = 0.5
	panel.anchor_right = 0.5
	panel.anchor_top = 0.5
	panel.anchor_bottom = 0.5
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_top = -230
	panel.offset_bottom = 230
	add_child(panel)
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 14)
	panel.add_child(v)
	title_label = UiStyle.label("", 76)
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(title_label)
	reason_label = UiStyle.label("", 26)
	reason_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(reason_label)
	stats_label = UiStyle.label("", 22, UiStyle.TEXT, false)
	stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(stats_label)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	v.add_child(row)
	primary_btn = UiKit.button("NEW MATCH", UiStyle.GOOD, Vector2(300, 68), 28)
	row.add_child(primary_btn)
	menu_btn = UiKit.button("MAIN MENU", UiStyle.PURPLE, Vector2(260, 68), 28)
	menu_btn.pressed.connect(func() -> void: menu_requested.emit())
	row.add_child(menu_btn)
	primary_btn.pressed.connect(_on_primary)

## info: {reason, day, class_label, holdings, total_holdings}
func show_game_over(info: Dictionary) -> void:
	kind = &"game_over"
	veil.color = Color(0.25, 0.0, 0.05, 0.82)
	panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.12, 0.02, 0.06, 0.96), UiStyle.BAD, 22, 4))
	title_label.text = "YOU DIED"
	title_label.add_theme_color_override("font_color", UiStyle.BAD)
	reason_label.text = String(REASON_TEXT.get(String(info.get("reason", "")), String(info.get("reason", "")).replace("_", " ").capitalize())) + "\nPermadeath: this world is over."
	stats_label.text = _stats(info)
	primary_btn.text = "NEW MATCH"
	visible = true

## info: {kind:"dominion"|"crowned", day, class_label, holdings, total_holdings}
func show_victory(info: Dictionary) -> void:
	kind = &"victory"
	veil.color = Color(0.05, 0.12, 0.2, 0.78)
	panel.add_theme_stylebox_override("panel", UiStyle.box(Color(0.05, 0.12, 0.16, 0.96), UiStyle.GOOD, 22, 4))
	title_label.text = "VICTORY"
	title_label.add_theme_color_override("font_color", Color("ffe84a"))
	reason_label.text = String(VICTORY_TEXT.get(String(info.get("kind", "")), "You won."))
	stats_label.text = _stats(info)
	primary_btn.text = "CONTINUE (ENDLESS)"
	visible = true

func _stats(info: Dictionary) -> String:
	var bits: Array[String] = []
	if info.has("day"):
		bits.append("Day %d" % int(info["day"]))
	if String(info.get("class_label", "")) != "":
		bits.append(String(info["class_label"]))
	if info.has("holdings"):
		bits.append("%d of %d holdings" % [int(info["holdings"]), int(info.get("total_holdings", 0))])
	return "   |   ".join(bits)

func _on_primary() -> void:
	if kind == &"victory":
		visible = false
		continue_endless_requested.emit()
	else:
		new_match_requested.emit()

## Convenience: feed Rules events straight in. Returns true if a screen was shown.
func handle_event(e: Dictionary, extra: Dictionary = {}) -> bool:
	var info: Dictionary = extra.duplicate()
	match e.get("type", &""):
		&"match_over":
			info["reason"] = e.get("reason", "")
			info["day"] = e.get("day", info.get("day", 0))
			show_game_over(info)
			return true
		&"victory":
			info["kind"] = e.get("kind", "")
			show_victory(info)
			return true
	return false
