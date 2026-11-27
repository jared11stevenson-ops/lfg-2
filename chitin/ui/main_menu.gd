class_name MainMenu
extends Control

signal new_game
signal continue_game

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.03, 0.05, 0.05)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var v := VBoxContainer.new()
	v.set_anchors_preset(Control.PRESET_CENTER)
	v.position = Vector2(-300, -240)
	v.custom_minimum_size = Vector2(600, 0)
	v.add_theme_constant_override("separation", 14)
	add_child(v)
	var t := Label.new()
	t.text = "C H I T I N"
	t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	t.add_theme_font_size_override("font_size", 72)
	t.add_theme_color_override("font_color", Color(0.95, 0.75, 0.3))
	v.add_child(t)
	var sub := Label.new()
	sub.text = "Molt of the Last Hive"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 26)
	v.add_child(sub)
	var blurb := Label.new()
	blurb.text = "The Molt unmade humanity. You are not one body but a bloodline:\neat to inherit, die to rebuild, and meet your past selves in the ruins."
	blurb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(blurb)
	var b1 := _btn("NEW LINEAGE", func(): new_game.emit())
	v.add_child(b1)
	var b2 := _btn("CONTINUE", func(): continue_game.emit())
	b2.disabled = not Lineage.has_save()
	v.add_child(b2)

func _btn(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(0, 64)
	b.add_theme_font_size_override("font_size", 24)
	b.pressed.connect(cb)
	return b
