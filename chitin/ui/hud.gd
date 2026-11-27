class_name Hud
extends CanvasLayer
## In-life HUD: vitals, ability labels, toast feed and the Scent Composer.

var world: InstarWorld
var touch: TouchControls
var bars := {}
var info_label: Label
var toast_label: Label
var toast_time := 0.0
var scent_panel: PanelContainer
var sliders: Array = []
var target_label: Label
var hint_label: Label
var _hint_rng := RandomNumberGenerator.new()
var _hint_cd := 0.0

func bind(w: InstarWorld) -> void:
	world = w
	layer = 5
	_build_bars()
	touch = TouchControls.new()
	add_child(touch)
	for i in w.player.abilities.size():
		var id: String = w.player.abilities[i]
		touch.set_label("ability_%d" % (i + 1), GeneDB.ABILITY_INFO[id].name)
	_build_scent_panel()

func _build_bars() -> void:
	var box := VBoxContainer.new()
	box.position = Vector2(20, 14)
	box.custom_minimum_size = Vector2(300, 0)
	add_child(box)
	for spec in [["hp", "Vitality", Color(0.85, 0.2, 0.25)], ["stamina", "Ichor", Color(0.9, 0.75, 0.2)],
			["hunger", "Hunger", Color(0.4, 0.8, 0.3)], ["stress", "Stress", Color(0.7, 0.3, 0.9)]]:
		var pb := ProgressBar.new()
		pb.custom_minimum_size = Vector2(280, 18)
		pb.show_percentage = false
		pb.max_value = 100
		var sb := StyleBoxFlat.new()
		sb.bg_color = spec[2]
		pb.add_theme_stylebox_override("fill", sb)
		var l := Label.new()
		l.text = spec[1]
		l.add_theme_font_size_override("font_size", 13)
		l.position = Vector2(6, -1)
		pb.add_child(l)
		box.add_child(pb)
		bars[spec[0]] = pb
	info_label = Label.new()
	info_label.position = Vector2(20, 120)
	info_label.add_theme_font_size_override("font_size", 16)
	add_child(info_label)
	toast_label = Label.new()
	toast_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	toast_label.position = Vector2(-300, 20)
	toast_label.custom_minimum_size = Vector2(600, 0)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_font_size_override("font_size", 20)
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 6)
	add_child(toast_label)

func _build_scent_panel() -> void:
	scent_panel = PanelContainer.new()
	scent_panel.visible = false
	scent_panel.position = Vector2(20, 190)
	var v := VBoxContainer.new()
	scent_panel.add_child(v)
	var title := Label.new()
	title.text = "SCENT COMPOSER"
	v.add_child(title)
	var row := HBoxContainer.new()
	v.add_child(row)
	for i in 4:
		var col := VBoxContainer.new()
		var s := VSlider.new()
		s.min_value = 0.0
		s.max_value = 1.0
		s.step = 0.05
		s.value = 0.5
		s.custom_minimum_size = Vector2(46, 150)
		s.value_changed.connect(_on_chord_changed)
		col.add_child(s)
		var l := Label.new()
		l.text = Scent.CHANNEL_NAMES[i]
		l.add_theme_font_size_override("font_size", 12)
		col.add_child(l)
		row.add_child(col)
		sliders.append(s)
	target_label = Label.new()
	target_label.text = "No creature near."
	v.add_child(target_label)
	hint_label = Label.new()
	hint_label.add_theme_font_size_override("font_size", 12)
	v.add_child(hint_label)
	var emit := Button.new()
	emit.text = "EMIT SCENT (F)"
	emit.custom_minimum_size = Vector2(0, 54)
	emit.pressed.connect(func(): world.emit_scent(false))
	v.add_child(emit)
	add_child(scent_panel)

func _on_chord_changed(_v: float) -> void:
	world.chord = Vector4(sliders[0].value, sliders[1].value, sliders[2].value, sliders[3].value)

func toast(text: String) -> void:
	toast_label.text = text
	toast_time = 4.0

func _process(delta: float) -> void:
	if world == null or not is_instance_valid(world.player):
		return
	var p: Player = world.player
	bars.hp.value = p.hp / p.max_hp * 100.0
	bars.stamina.value = p.stamina / p.max_stamina * 100.0
	bars.hunger.value = p.hunger
	bars.stress.value = p.stress * 100.0
	var left: float = maxf(0.0, Lineage.INSTAR_SECONDS - float(Lineage.run.time))
	info_label.text = "Gen %d   Bile %d (+%d)   Time %d:%02d\nKills %d  Kin %d  Calmed %d   Latent genes %d" % [
		Lineage.generation, Lineage.bile, Lineage.run.bile, int(left) / 60, int(left) % 60,
		Lineage.run.kills, Lineage.run.recruits, Lineage.run.calms, Lineage.latent.size()]
	touch.set_hidden("molt", not world.near_chrysalis)
	toast_time -= delta
	toast_label.modulate.a = clampf(toast_time, 0.0, 1.0)
	if Input.is_action_just_pressed("scent_toggle"):
		scent_panel.visible = not scent_panel.visible
	if Input.is_action_just_pressed("emit"):
		world.emit_scent(false)
	# A held scent button toggles via action; edge-detect handled above
	if scent_panel.visible:
		_hint_cd -= delta
		if _hint_cd <= 0.0:
			_hint_cd = 0.5
			var c := world.nearest_creature(14.0)
			if c == null:
				target_label.text = "No creature near."
				hint_label.text = ""
			else:
				target_label.text = "Near: %s" % c.sp.get("name", "?")
				var h := Scent.reveal(c.sp, p.stats.scent, _hint_rng)
				hint_label.text = "Antennae sense want ~ F%.1f K%.1f H%.1f R%.1f" % [h.x, h.y, h.z, h.w]
