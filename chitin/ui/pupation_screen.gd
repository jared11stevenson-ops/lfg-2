class_name PupationScreen
extends Control
## The chrysalis. Review the life that just ended, pick which alleles your
## next body inherits (from yourself, what you ate, or an Echo mate), spend
## Bile to lock slots against stress mutation, then Emerge.

signal emerged

var summary: Dictionary
var mate_index := -1
var latent: Array
var picks := {}                     # slot -> [optionIdxA, optionIdxB]
var options := {}                   # slot -> Array of option dicts
var locks := {}                     # slot -> bool
var rows_box: VBoxContainer
var preview: Label
var mate_pick: OptionButton
var emerge_btn: Button

func setup(s: Dictionary) -> void:
	summary = s
	latent = Lineage.latent.duplicate(true)

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color(0.05, 0.03, 0.02)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var scroll := ScrollContainer.new()
	scroll.set_anchors_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 20
	scroll.offset_top = 10
	scroll.offset_right = -20
	scroll.offset_bottom = -10
	add_child(scroll)
	var root := VBoxContainer.new()
	root.custom_minimum_size = Vector2(1100, 0)
	root.add_theme_constant_override("separation", 8)
	scroll.add_child(root)
	var title := Label.new()
	title.add_theme_font_size_override("font_size", 34)
	var echo: Dictionary = summary.get("echo", {})
	title.text = ("YOU DIED - " if summary.cause == "died" else "YOU MOLTED - ") + "Generation %d ends" % (Lineage.generation)
	root.add_child(title)
	var recap := Label.new()
	var disp := Echo.disposition(echo) if not echo.is_empty() else "?"
	recap.text = "Kills %d  |  Recruited %d  |  Calmed %d  |  Bile earned %d  |  Peak stress %d%%\nYour body lingers as an Echo: %s - a %s.  (%s)" % [
		summary.kills, summary.recruits, summary.calms, summary.bile, int(float(summary.stress) * 100),
		echo.get("name", "?"), "KIN who will fight beside your next self" if disp == "kin" else "REVENANT that will hunt you",
		"aggression %.0f%% / kinship %.0f%%" % [float(echo.get("aggression", 0)) * 100, float(echo.get("kinship", 0)) * 100]]
	recap.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(recap)
	var mrow := HBoxContainer.new()
	root.add_child(mrow)
	var ml := Label.new()
	ml.text = "Echo mate (cross your genes with a past self):  "
	mrow.add_child(ml)
	mate_pick = OptionButton.new()
	mate_pick.add_item("None - self only")
	for i in Lineage.echoes.size():
		var e: Dictionary = Lineage.echoes[i]
		mate_pick.add_item("%s (Gen %d, %s)" % [e.name, e.instar, Echo.disposition(e)])
	mate_pick.item_selected.connect(func(i): mate_index = i - 1; _rebuild(true))
	mrow.add_child(mate_pick)
	rows_box = VBoxContainer.new()
	rows_box.add_theme_constant_override("separation", 6)
	root.add_child(rows_box)
	preview = Label.new()
	preview.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	root.add_child(preview)
	emerge_btn = Button.new()
	emerge_btn.text = "EMERGE"
	emerge_btn.custom_minimum_size = Vector2(0, 70)
	emerge_btn.add_theme_font_size_override("font_size", 28)
	emerge_btn.pressed.connect(_emerge)
	root.add_child(emerge_btn)
	_rebuild(true)

func _mate_genome() -> Genome:
	if mate_index >= 0 and mate_index < Lineage.echoes.size():
		return Echo.genome_of(Lineage.echoes[mate_index])
	return null

func _label_for(o: Dictionary) -> String:
	var g := GeneDB.get_gene(o.id)
	var txt: String = g.name
	if o.mut > 0:
		txt += " +%d" % o.mut
	var mods: Array = []
	for k in g.get("mods", {}):
		mods.append("%s%+.0f" % [k, g.mods[k] * (1.0 + 0.35 * o.mut)])
	if g.has("ability"):
		mods.append("[%s]" % GeneDB.ABILITY_INFO[g.ability].name)
	return "%s  (%s)  <%s>" % [txt, ", ".join(mods), o.src]

func _rebuild(reset_picks: bool) -> void:
	for c in rows_box.get_children():
		c.queue_free()
	var mate := _mate_genome()
	var auto := Pupation.auto_picks(Lineage.genome, latent, mate)
	for s in 6:
		options[s] = Pupation.options_for(s, Lineage.genome, latent, mate)
		if reset_picks:
			var ia := 0
			var ib := 0
			for i in options[s].size():
				if options[s][i].id == auto[s][0].id and options[s][i].mut == auto[s][0].mut:
					ia = i
				if options[s][i].id == auto[s][1].id and options[s][i].mut == auto[s][1].mut:
					ib = i
			picks[s] = [ia, ib]
			locks[s] = false
		var row := HBoxContainer.new()
		var l := Label.new()
		l.text = GeneDB.SLOT_NAMES[s]
		l.custom_minimum_size = Vector2(90, 0)
		row.add_child(l)
		for k in 2:
			var ob := OptionButton.new()
			ob.custom_minimum_size = Vector2(430, 44)
			for o in options[s]:
				ob.add_item(_label_for(o))
			ob.select(clampi(picks[s][k], 0, options[s].size() - 1))
			var slot := s
			var which := k
			ob.item_selected.connect(func(i): picks[slot][which] = i; _refresh())
			row.add_child(ob)
		var lk := CheckBox.new()
		lk.text = "Lock (%d bile)" % Pupation.LOCK_COST
		lk.button_pressed = locks[s]
		var sl := s
		lk.toggled.connect(func(on): locks[sl] = on; _refresh())
		row.add_child(lk)
		rows_box.add_child(row)
	_refresh()

func _chosen() -> Dictionary:
	var out := {}
	for s in 6:
		out[s] = [options[s][clampi(picks[s][0], 0, options[s].size() - 1)], options[s][clampi(picks[s][1], 0, options[s].size() - 1)]]
	return out

func _lock_list() -> Array:
	var out: Array = []
	for s in locks:
		if locks[s]:
			out.append(s)
	return out

func _lock_cost() -> int:
	return _lock_list().size() * Pupation.LOCK_COST

func _refresh() -> void:
	var g := Pupation.finalize(_chosen(), 0.0, [0, 1, 2, 3, 4, 5], RandomNumberGenerator.new())
	var st := g.stats()
	var ab: Array = g.abilities().map(func(a): return GeneDB.ABILITY_INFO[a].name)
	var rate := Pupation.mutation_rate(float(summary.stress))
	preview.text = "Predicted body: HP %.0f  Dmg %.0f  Speed %.1f  Armor %.0f  Sense %.0f  Scent %.1f   Abilities: %s\nMutation chance per allele %.0f%% (from your %d%% stress; Lock slots to protect them).  Bile %d, locks cost %d." % [
		st.hp, st.damage, st.speed, st.armor, st.sense, st.scent, ", ".join(ab) if ab.size() > 0 else "none",
		rate * 100.0, int(float(summary.stress) * 100), Lineage.bile, _lock_cost()]
	emerge_btn.disabled = _lock_cost() > Lineage.bile

func _emerge() -> void:
	var rng := Lineage.rng
	var g := Pupation.finalize(_chosen(), float(summary.stress), _lock_list(), rng)
	# Used latent genes are consumed; unused stay in the gut.
	var used := {}
	for s in 6:
		for o in _chosen()[s]:
			if o.src == "eaten":
				used[o.id + str(o.mut)] = true
	var remaining: Array = []
	for a in Lineage.latent:
		if not used.has(a.id + str(a.mut)):
			remaining.append(a)
	Lineage.latent = remaining
	Lineage.complete_pupation(g, _lock_cost())
	emerged.emit()
