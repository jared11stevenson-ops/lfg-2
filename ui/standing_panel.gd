class_name StandingPanel
extends PanelBase
## STANDING: rank and what the next rank unlocks, Prosperity, the Purge Levy due, the Marked faction, recent deeds and skill points.
## Pure view over Standing.hud_model(state, faction): set_model(model). Emits skill_tree_requested only; it never touches Rules.
signal skill_tree_requested
const RANK_COLORS: Array[Color] = [Color("9a8fb0"), Color("6fd3a0"), Color("49c6e5"), Color("ffd24a"), Color("ff8a3c"), Color("ff4fa3")]
var model: Dictionary = {}
var box: VBoxContainer
var rank_label: Label
var standing_bar: ProgressBar
var next_label: Label
var levy_label: Label
var mark_label: Label
var prosperity_label: Label
var thin_label: Label
var deeds_box: VBoxContainer
var skill_btn: Button
var thriving_chip: Control

func _init() -> void:
	super("STANDING", Vector2(900, 600))
	var sc: ScrollContainer = UiKit.scroll(400)
	body.add_child(sc)
	box = VBoxContainer.new()
	box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	box.add_theme_constant_override("separation", 10)
	sc.add_child(box)
	rank_label = UiKit.heading("", 34)
	box.add_child(rank_label)
	standing_bar = ProgressBar.new()
	standing_bar.custom_minimum_size = Vector2(0, 28)
	standing_bar.show_percentage = false
	box.add_child(standing_bar)
	next_label = _lbl("", 20, UiStyle.TEXT, false)
	box.add_child(next_label)
	thin_label = _lbl("", 20, UiStyle.BAD, false)
	box.add_child(thin_label)
	prosperity_label = _lbl("", 20, UiStyle.TEXT, false)
	box.add_child(prosperity_label)
	levy_label = _lbl("", 20, UiStyle.WARN, false)
	box.add_child(levy_label)
	mark_label = _lbl("", 20, UiStyle.TEXT, false)
	box.add_child(mark_label)
	box.add_child(UiKit.heading("RECENT DEEDS (they fade after three weeks)", 20))
	deeds_box = VBoxContainer.new()
	deeds_box.add_theme_constant_override("separation", 4)
	box.add_child(deeds_box)
	skill_btn = UiKit.button("SKILL TREE", UiStyle.PURPLE, Vector2(320, 56), 22)
	skill_btn.pressed.connect(func() -> void: skill_tree_requested.emit())
	box.add_child(skill_btn)

func set_model(m: Dictionary) -> void:
	model = m
	if m.is_empty():
		rank_label.text = "No standing yet."
		return
	var r: int = int(m["rank"])
	rank_label.text = "RANK %d - %s" % [r, String(m["rank_name"]).to_upper()]
	rank_label.add_theme_color_override("font_color", RANK_COLORS[clampi(r, 0, RANK_COLORS.size() - 1)])
	var top: bool = float(m["next_threshold"]) <= 0.0
	standing_bar.max_value = maxf(1.0, float(m["next_threshold"])) if not top else 1.0
	standing_bar.value = minf(float(m["standing"]), standing_bar.max_value) if not top else 1.0
	if top:
		next_label.text = "Standing %.1f. You hold the highest rank." % float(m["standing"])
	else:
		next_label.text = "Standing %.1f of %.1f for %s (%.1f to go). Unlocks: %s" % [float(m["standing"]), float(m["next_threshold"]), m["next_rank_name"], float(m["to_next"]), m["next_unlock"]]
	thin_label.text = "THIN CROWN: your rations or a holding's stability are low, so rank buffs are one step smaller." if bool(m.get("thin_crown", false)) else ""
	thin_label.visible = thin_label.text != ""
	var p: Dictionary = m.get("prosperity", {})
	prosperity_label.text = "Prosperity %d   (output %d, reserves %d, holdings %d)   %s" % [int(p.get("score", 0)), int(p.get("output", 0)), int(p.get("reserves", 0)), int(p.get("holdings", 0)),
		"THRIVING" if bool(p.get("thriving", false)) else "not yet thriving"]
	prosperity_label.add_theme_color_override("font_color", UiStyle.GOOD if bool(p.get("thriving", false)) else UiStyle.TEXT)
	var lv: Dictionary = m.get("levy", {})
	var days: int = int(m.get("days_to_purge", 0))
	levy_label.text = "Purge Levy after this Purge: %d rations + %d coin (%d%% off for fighting and defending). Purge in %d day(s)." % [int(lv.get("rations", 0)), int(lv.get("coin", 0)),
		int(round(float(lv.get("reduction", 0.0)) * 100.0)), days]
	var mk: Dictionary = m.get("marked", {})
	if int(mk.get("faction", -1)) < 0:
		mark_label.text = "Nobody is Marked."
		mark_label.add_theme_color_override("font_color", UiStyle.TEXT)
	elif bool(mk.get("is_you", false)):
		mark_label.text = "YOU are Marked: raiders and beasts will come for you, and striking you pays a bounty."
		mark_label.add_theme_color_override("font_color", UiStyle.BAD)
	else:
		mark_label.text = "Marked: %s. Striking them pays a bounty." % String(mk.get("name", "?"))
		mark_label.add_theme_color_override("font_color", UiStyle.WARN)
	UiKit.clear(deeds_box)
	var deeds: Array = m.get("recent_deeds", [])
	if deeds.is_empty():
		deeds_box.add_child(_lbl("None yet. Scouting, escorting, brokering, healing, defending or fighting during the Purge all count.", 18, Color(1, 1, 1, 0.7), false))
	for d in deeds:
		deeds_box.add_child(_lbl("%s   +%d   %.1f days ago" % [d["label"], int(d["standing"]), float(d["age_days"])], 18, UiStyle.TEXT, false))
	skill_btn.text = "SKILL TREE   (%d point%s)" % [int(m.get("skill_points", 0)), "" if int(m.get("skill_points", 0)) == 1 else "s"]
	set_status("Ranks buff production, access and logistics - never combat.", Color(1, 1, 1, 0.7))

## A wrapping label (the shared UiStyle.label never wraps, and these panels carry sentences).
static func _lbl(text: String, size: int, color: Color = UiStyle.TEXT, _outline: bool = false) -> Label:
	var l: Label = UiStyle.label(text, size, color, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(160, 0)
	return l
