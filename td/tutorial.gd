extends Control
# Guided first run (Mossgate only): teaches placing, starting a wave, type matchups, upgrading and a second creature.
const Session = preload("res://session.gd")
var m
var step := "intro"
var label: Label
var box: PanelContainer
var targets: Array = []     # Rect2 in screen space to highlight
var timer := 0.0
var hint_seen_super := false
var taught_capture := false
var resume := "second"

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	size = Vector2(1280, 720)
	box = PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.09, 0.07, 0.16, 0.94)
	sb.set_corner_radius_all(16)
	sb.set_border_width_all(3)
	sb.border_color = Color("f0b43c")
	sb.set_content_margin_all(14)
	box.add_theme_stylebox_override("panel", sb)
	label = Label.new()
	label.add_theme_font_size_override("font_size", 21)
	label.custom_minimum_size = Vector2(560, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(label)
	add_child(box)
	box.position = Vector2(16, 520)
	_enter("intro")

func _say(text: String, rects: Array = []) -> void:
	label.text = text
	targets = rects
	box.size = Vector2(0, 0)
	box.position = Vector2(16, 520)

func _enter(s: String) -> void:
	step = s
	timer = 0.0
	var card: Control = m.cards.get("tickindle")
	match s:
		"intro":
			_say("Welcome, Wellkeeper!\nWild Shuckits are after the Well's gold. Each one that reaches the Well steals coins and runs. Keep your 20 coins for 10 waves!")
		"place":
			_say("Tap Tickindle below, then tap a glowing rune stone to preview where to place it.", [card.get_global_rect()] + _stone_rects())
		"confirm":
			_say("Tap the ghost again to place it. Stones boost whoever stands on them: +15%, or +30% on a stone that matches your creature's type (Tickindle is Ember, so orange).", _pending_rect())
		"start":
			_say("Press Start wave to let the first creatures come.", [m.start_btn.get_global_rect()])
		"watch":
			_say("Your creature fights on its own. Watch for \"Super!\": that is a type advantage with bonus damage.")
		"upgrade":
			_say("Wave cleared! Tap your creature to open its upgrades.", _tower_rects())
		"buy":
			_say("Pick an upgrade path. Two paths, four tiers each. Spend your coins!")
		"second":
			_say("Place a second Tickindle. More firepower on the lane means fewer leaks.", [m.cards.get("tickindle").get_global_rect()])
		"capture":
			_say("This one is worn out! Tap it to throw a Lure. A captured creature is yours for good, and it fights for you.", _capturable_rects())
		"done":
			_say("You are ready. The Well is yours to hold. Good luck!")

func _capturable_rects() -> Array:
	var out := []
	for e in m.get_tree().get_nodes_in_group("enemies"):
		if e.capturable:
			out.append(Rect2(e.position - Vector2(46, 78), Vector2(92, 100)))
	return out

func _stone_rects() -> Array:
	var out := []
	for s in m.stones:
		out.append(Rect2(s.pos - Vector2(48, 48), Vector2(96, 96)))
	return out

func _pending_rect() -> Array:
	return [Rect2(m.pending - Vector2(48, 48), Vector2(96, 96))] if m.has_pending else []

func _tower_rects() -> Array:
	var out := []
	for t in m.get_tree().get_nodes_in_group("towers"):
		out.append(Rect2(t.position - Vector2(44, 70), Vector2(88, 100)))
	return out

func _process(delta: float) -> void:
	if m == null:
		return
	timer += delta
	var towers: int = m.get_tree().get_nodes_in_group("towers").size()
	if not taught_capture and step in ["watch", "upgrade", "buy", "second", "done"] and not _capturable_rects().is_empty():
		taught_capture = true
		resume = step
		_enter("capture")
	if m.wave >= 3 and step in ["intro", "place", "confirm", "start", "watch"]:
		_enter("done")   # the player is clearly past the basics; never leave a stale prompt on screen
	match step:
		"capture":
			targets = _capturable_rects()
			if m.captures_run > 0 or timer > 14.0 or (targets.is_empty() and timer > 2.0):
				_enter(resume)
		"intro":
			if timer > 4.5:
				_enter("place")
		"place":
			if towers >= 1:
				_enter("start")
			elif m.has_pending:
				_enter("confirm")
			else:
				targets = [m.cards.get("tickindle").get_global_rect()] + _stone_rects()
		"confirm":
			targets = _pending_rect()
			if towers >= 1:
				_enter("start")
			elif not m.has_pending:
				_enter("place")
		"start":
			if m.wave_running:
				_enter("watch")
		"watch":
			if not m.wave_running:
				_enter("upgrade")
		"upgrade":
			targets = _tower_rects()
			if m.sel_tower != null:
				_enter("buy")
		"buy":
			var tiers := 0
			for t in m.get_tree().get_nodes_in_group("towers"):
				tiers += t.tiers.a + t.tiers.b
			if tiers >= 1 or timer > 14.0:
				_enter("second")
		"second":
			if towers >= 2 or timer > 25.0:
				_enter("done")
		"done":
			if timer > 4.0:
				Session.settings["tutorial_done"] = true
				Session.save_prefs()
				queue_free()
	queue_redraw()

func _draw() -> void:
	var pulse := 0.5 + 0.5 * sin(Time.get_ticks_msec() / 220.0)
	for r in targets:
		var rr: Rect2 = r.grow(4.0 + pulse * 4.0)
		draw_rect(rr, Color(1, 0.9, 0.4, 0.18 + 0.15 * pulse))
		draw_rect(rr, Color(1, 0.9, 0.4, 0.9), false, 4.0)
