class_name TutorialCard
extends PanelBase
## A short modal explainer (data/tutorial.json topics): title, a few lines, one button. Pure view: show_topic(topic, card) then it emits confirmed(topic) when the
## player taps the button; the overlay turns that into the ack_tutorial command. Used for the Purge preview in the first-days chapters.
signal confirmed(topic: String)
var topic: String = ""
var lines_box: VBoxContainer
var ok_btn: Button

func _init() -> void:
	super("", Vector2(760, 470))
	lines_box = VBoxContainer.new()
	lines_box.add_theme_constant_override("separation", 10)
	lines_box.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(lines_box)
	ok_btn = UiKit.button("Got it", UiStyle.GOOD, Vector2(260, 64), 26)
	ok_btn.pressed.connect(func() -> void:
		var t: String = topic
		close()
		confirmed.emit(t))
	body.add_child(ok_btn)
	close_btn.visible = false      # the only way out is the button: the card is the lesson

func show_topic(t: String, card: Dictionary) -> void:
	topic = t
	title_label.text = String(card.get("title", "")).to_upper()
	ok_btn.text = String(card.get("button", "Got it"))
	UiKit.clear(lines_box)
	for ln in card.get("lines", []):
		var l: Label = UiStyle.label("-  " + String(ln), 22, UiStyle.TEXT, false)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		l.custom_minimum_size = Vector2(300, 0)
		lines_box.add_child(l)
	open()
