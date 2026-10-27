class_name SkillTreePanel
extends PanelBase
## Class skill tree: three branches (Economy / Purge / Hybrid), costs, prerequisites, drawbacks. No respec (the tree resets with the match).
## Pure view over Skills.panel_model(actor). Emits unlock_requested(node_id) only; the lead turns it into the unlock_skill command.
signal unlock_requested(node_id: String)
const BRANCH_TITLES: Dictionary = {"economy": "ECONOMY", "purge": "PURGE", "hybrid": "HYBRID"}
const BRANCH_COLORS: Dictionary = {"economy": Color("6fd3a0"), "purge": Color("ff6b6b"), "hybrid": Color("49c6e5")}
var model: Dictionary = {}
var points_label: Label
var cols: HBoxContainer
var buttons: Dictionary = {}       # node id -> Button
var info: Label

func _init() -> void:
	super("SKILLS", Vector2(1000, 620))
	points_label = _lbl("", 22, UiStyle.WARN, false)
	body.add_child(points_label)
	var sc: ScrollContainer = UiKit.scroll(380)
	body.add_child(sc)
	cols = HBoxContainer.new()
	cols.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cols.add_theme_constant_override("separation", 12)
	sc.add_child(cols)
	info = _lbl("Points come only from Purge deeds. Choices are permanent for this match.", 18, Color(1, 1, 1, 0.75), true)
	body.add_child(info)

func set_model(m: Dictionary) -> void:
	model = m
	UiKit.clear(cols)
	buttons.clear()
	title_label.text = "SKILLS - %s" % String(m.get("tree_name", "")).to_upper()
	points_label.text = "Skill points: %d      Nodes: %d / %d" % [int(m.get("points", 0)), int(m.get("taken", 0)), int(m.get("total", 0))]
	for b in ["economy", "purge", "hybrid"]:
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 8)
		cols.add_child(col)
		col.add_child(UiKit.heading(String(BRANCH_TITLES[b]), 24, BRANCH_COLORS[b]))
		for row in m.get("branches", {}).get(b, []):
			col.add_child(_node(row, BRANCH_COLORS[b]))

func _node(r: Dictionary, color: Color) -> Control:
	var st: String = String(r["state"])
	var label: String = "%s  [%d]" % [r["name"], int(r["cost"])]
	if bool(r["drawback"]):
		label += "  (trade-off)"
	var btn: Button = UiKit.button(label, UiStyle.GOOD if st == "taken" else (Color("b0407a") if bool(r["drawback"]) else color), Vector2(200, 56), 17)
	btn.disabled = st != "available"
	btn.tooltip_text = ", ".join(r["effects"]) + ("" if (r["requires"] as Array).is_empty() else "   needs: " + ", ".join(r["requires"]))
	var nid: String = String(r["id"])
	btn.pressed.connect(func() -> void: unlock_requested.emit(nid))
	buttons[nid] = btn
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 2)
	v.add_child(btn)
	var sub: String = ", ".join(r["effects"])
	if st == "locked":
		sub = "needs " + ", ".join(r["requires"])
	elif st == "taken":
		sub = "TAKEN: " + sub
	v.add_child(_lbl(sub, 14, Color(1, 1, 1, 0.75) if not bool(r["drawback"]) else UiStyle.BAD, true))
	return v

## A wrapping label (the shared UiStyle.label never wraps, and these panels carry sentences).
static func _lbl(text: String, size: int, color: Color = UiStyle.TEXT, _outline: bool = false) -> Label:
	var l: Label = UiStyle.label(text, size, color, false)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	l.custom_minimum_size = Vector2(160, 0)
	return l
