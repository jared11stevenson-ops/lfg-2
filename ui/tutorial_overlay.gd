class_name TutorialOverlay
extends Control
## First-days guide. A slim banner under the top bar that says what to do next and where to look, plus a modal TutorialCard for "read this" steps.
## Pure view over Quests.tutorial_model(state, actor): set_model(model) ({} hides everything). It never calls Rules and never blocks play; it emits
##   accept_requested(quest_id)      -> UiCommands.accept_quest (the offer button; UiPanels re-emits it as quest_accept_requested)
##   ack_requested(topic)            -> UiCommands.ack_tutorial
##   highlight_changed(ui_key)       -> UiPanels pulses the matching toolbar button ("craft" "build" "hold" "journal"; "plot" "bag" "purge_guide" have no button)
##   skipped                         -> the player switched the tips off for this session (nothing is stored in the match)
signal accept_requested(quest_id: String)
signal ack_requested(topic: String)
signal highlight_changed(ui_key: String)
signal skipped
var model: Dictionary = {}
var banner: PanelContainer
var chapter_label: Label
var text_label: Label
var prompt_label: Label
var progress_label: Label
var begin_btn: Button
var skip_btn: Button
var card: TutorialCard
var highlight: String = ""
var muted: bool = false
var _shown_card_topic: String = ""

func _init() -> void:
	name = "TutorialOverlay"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	banner = PanelContainer.new()
	banner.visible = false
	banner.mouse_filter = Control.MOUSE_FILTER_PASS
	banner.anchor_left = 0.5
	banner.anchor_right = 0.5
	banner.offset_left = -330
	banner.offset_right = 330
	banner.offset_top = 118      # just under the phase banner
	banner.offset_bottom = 256
	banner.add_theme_stylebox_override("panel", UiStyle.box(Color(0.08, 0.04, 0.16, 0.9), UiStyle.GOOD, 16, 3))
	add_child(banner)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	banner.add_child(v)
	chapter_label = UiStyle.label("", 16, UiStyle.GOOD, false)
	v.add_child(chapter_label)
	text_label = _wrap("", 22, UiStyle.TEXT)
	v.add_child(text_label)
	prompt_label = _wrap("", 17, UiStyle.WARN)
	v.add_child(prompt_label)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	v.add_child(row)
	progress_label = UiStyle.label("", 17, Color(1, 1, 1, 0.8), false)
	progress_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(progress_label)
	begin_btn = UiKit.button("BEGIN", UiStyle.GOOD, Vector2(140, 56), 20)
	begin_btn.pressed.connect(func() -> void: accept_requested.emit(String(model.get("quest", ""))))
	row.add_child(begin_btn)
	skip_btn = UiKit.button("HIDE TIPS", UiStyle.PURPLE, Vector2(150, 56), 17)
	skip_btn.pressed.connect(func() -> void:
		muted = true
		_apply()
		skipped.emit())
	row.add_child(skip_btn)
	card = TutorialCard.new()
	add_child(card)
	card.confirmed.connect(func(t: String) -> void: ack_requested.emit(t))

static func _wrap(text: String, size: int, color: Color) -> Label:
	var l: Label = UiStyle.label(text, size, color, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(300, 0)
	return l

func set_model(m: Dictionary) -> void:
	model = m
	_apply()

func is_showing() -> bool:
	return banner.visible

func card_open() -> bool:
	return card.visible

func _apply() -> void:
	var hide: bool = model.is_empty() or muted
	banner.visible = not hide
	if hide:
		card.visible = false
		_shown_card_topic = ""
		_set_highlight("")
		return
	chapter_label.text = "FIRST DAYS  -  chapter %d of %d  -  %s" % [int(model["chapter"]), int(model["chapters"]), String(model["title"])]
	text_label.text = String(model["text"])
	prompt_label.text = String(model["prompt"])
	var phase: String = String(model["phase"])
	begin_btn.visible = phase == "offer"
	progress_label.text = ""
	if phase == "active":
		progress_label.text = "Step %d of %d" % [int(model["index"]) + 1, int(model["steps"])] + (("   (%d/%d)" % [int(model["progress"]), int(model["qty"])]) if int(model["qty"]) > 1 else "")
	elif phase == "ready":
		progress_label.text = "Chapter finished"
	var topic: String = String(model.get("topic", ""))
	if phase == "active" and topic != "" and not (model.get("card", {}) as Dictionary).is_empty():
		if _shown_card_topic != topic:
			_shown_card_topic = topic
			card.show_topic(topic, model["card"])
	else:
		_shown_card_topic = ""
		if card.visible:
			card.visible = false
	_set_highlight(String(model.get("ui", "")))

func _set_highlight(key: String) -> void:
	if key == highlight:
		return
	highlight = key
	highlight_changed.emit(key)
