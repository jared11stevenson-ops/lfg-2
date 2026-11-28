class_name BCBattleView
extends Node3D
## Presents a BCBattle inside a jar: hex highlights, animated unit actors, hit text, and the command bar.

signal finished(attacker_wins: bool, atk_alive: Array, def_alive: Array, def_all: Array)

var battle: BCBattle
var jar: BCJar
var player_side := 0
var actors := {}             # Unit -> BCActor
var labels := {}             # Unit -> Label3D
var cells := {}              # Vector2i -> MeshInstance3D
var selected = null
var busy := false
var done := false
var ui: CanvasLayer
var status: Label
var info: Label
var btn_defend: Button
var btn_end: Button
var btn_auto: Button
var banner: Label
var mats := {}

func start(p_jar: BCJar, p_battle: BCBattle, p_player_side: int) -> void:
	jar = p_jar
	battle = p_battle
	player_side = p_player_side
	jar.battle_mode = true
	jar.add_child(self)
	_build_cells()
	_build_units()
	_build_ui()
	_update_ui()
	if battle.turn_side != player_side:
		_ai_turn()

func _mat(c: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, a)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 1.4
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _build_cells() -> void:
	mats = {"move": _mat(Color(0.3, 1.0, 0.5), 0.45), "attack": _mat(Color(1.0, 0.25, 0.2), 0.55),
		"select": _mat(Color(0.4, 0.7, 1.0), 0.55), "hover": _mat(Color(1.0, 0.9, 0.4), 0.35)}
	for r in BCBattle.ROWS:
		for c in BCBattle.COLS:
			var mi := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 1.05; cm.bottom_radius = 1.05; cm.height = 0.05; cm.radial_segments = 6
			mi.mesh = cm
			mi.rotation_degrees.y = 30.0
			mi.position = BCBattle.tile_pos(c, r) + Vector3(0, 0.08, 0)
			mi.visible = false
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mi)
			cells[Vector2i(c, r)] = mi

func _build_units() -> void:
	for u in battle.units:
		var a := BCActor.new()
		add_child(a)
		a.setup(BCData.RACES[u.race_idx])
		a.position = BCBattle.tile_pos(u.c, u.r)
		a.rotation.y = PI / 2.0 if u.side == 0 else -PI / 2.0
		actors[u] = a
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.font_size = 40
		l.pixel_size = 0.012
		l.outline_size = 10
		l.no_depth_test = true
		l.position = Vector3(0, 2.4, 0)
		a.add_child(l)
		labels[u] = l
		# team ring
		var ring := MeshInstance3D.new()
		var tm := TorusMesh.new(); tm.inner_radius = 0.62; tm.outer_radius = 0.78
		ring.mesh = tm
		var col: Color = BCData.RACES[battle.attacker_civ.id].color if u.side == 0 else BCData.RACES[battle.defender_civ.id].color
		ring.material_override = BCAssets.emissive(col, 2.5)
		ring.position = Vector3(0, 0.05, 0)
		a.add_child(ring)
	_refresh_labels()

func _refresh_labels() -> void:
	for u in battle.units:
		var l: Label3D = labels[u]
		l.visible = u.alive
		l.text = "%d/%d%s" % [maxi(0, ceili(u.hp)), ceili(u.max_hp), " [D]" if u.defending else ""]
		l.modulate = Color(0.6, 0.85, 1.0) if u.side == 0 else Color(1.0, 0.75, 0.5)
		if u.side == player_side and battle.turn_side == player_side and not u.acted:
			l.modulate = Color(1.0, 1.0, 0.5)

func _build_ui() -> void:
	ui = CanvasLayer.new()
	ui.layer = 20
	add_child(ui)
	var panel := PanelContainer.new()
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.05, 0.04, 0.07, 0.88); sb.set_corner_radius_all(8); sb.set_border_width_all(1); sb.border_color = Color(1, 0.4, 0.3, 0.5)
	sb.content_margin_left = 14; sb.content_margin_right = 14; sb.content_margin_top = 8; sb.content_margin_bottom = 8
	panel.add_theme_stylebox_override("panel", sb)
	panel.set_anchors_preset(Control.PRESET_CENTER_TOP)
	panel.offset_top = 70; panel.offset_left = -320; panel.offset_right = 320
	ui.add_child(panel)
	var vb := VBoxContainer.new()
	panel.add_child(vb)
	status = Label.new(); status.add_theme_font_size_override("font_size", 18); vb.add_child(status)
	info = Label.new(); info.add_theme_color_override("font_color", Color(0.75, 0.7, 0.6)); vb.add_child(info)
	var hb := HBoxContainer.new(); vb.add_child(hb)
	btn_defend = Button.new(); btn_defend.text = "Defend (halve damage)"; btn_defend.pressed.connect(_on_defend); hb.add_child(btn_defend)
	btn_end = Button.new(); btn_end.text = "End turn"; btn_end.pressed.connect(_on_end_turn); hb.add_child(btn_end)
	btn_auto = Button.new(); btn_auto.text = "Auto-resolve rest"; btn_auto.pressed.connect(_on_auto); hb.add_child(btn_auto)
	banner = Label.new()
	banner.add_theme_font_size_override("font_size", 54)
	banner.add_theme_color_override("font_outline_color", Color.BLACK)
	banner.add_theme_constant_override("outline_size", 12)
	banner.set_anchors_preset(Control.PRESET_CENTER)
	banner.grow_horizontal = Control.GROW_DIRECTION_BOTH
	banner.visible = false
	ui.add_child(banner)

func _update_ui() -> void:
	var mine := battle.turn_side == player_side
	var a := battle.attacker_civ.name
	var d := battle.defender_civ.name
	status.text = "%s attacks %s  -  Round %d/%d  -  %s" % [a, d, battle.round_no, BCBattle.MAX_ROUNDS, "YOUR TURN" if mine else "Enemy turn..."]
	status.add_theme_color_override("font_color", Color(0.6, 1.0, 0.6) if mine else Color(1.0, 0.6, 0.5))
	if selected != null:
		info.text = "Selected: HP %d/%d  ATK %.1f  Move %d  Range %d%s. Click green to move, red to attack." % [ceili(selected.hp), ceili(selected.max_hp), selected.atk, selected.move, selected.reach, "  (militia)" if selected.militia else ""]
	else:
		info.text = "Click one of your units (yellow numbers). Flanking (+25%) when an ally is adjacent to the target."
	btn_defend.disabled = busy or not mine or selected == null or selected.acted
	btn_end.disabled = busy or not mine
	btn_auto.disabled = busy or done
	_refresh_labels()

func _clear_cells() -> void:
	for k in cells: cells[k].visible = false

func _show_cells() -> void:
	_clear_cells()
	if selected == null or battle.turn_side != player_side: return
	var sc: MeshInstance3D = cells[Vector2i(selected.c, selected.r)]
	sc.material_override = mats.select; sc.visible = true
	for cell in battle.reachable(selected):
		var m: MeshInstance3D = cells[cell]
		m.material_override = mats.move; m.visible = true
	if not selected.acted:
		for t in battle.can_attack_now(selected):
			var m2: MeshInstance3D = cells[Vector2i(t.c, t.r)]
			m2.material_override = mats.attack; m2.visible = true
		# also targets reachable after moving are shown when you click a move cell

func _pick_cell(from: Vector3, dir: Vector3):
	var plane := Plane(Vector3.UP, jar.global_position.y + 0.08)
	var hit = plane.intersects_ray(from, dir)
	if hit == null: return null
	var local: Vector3 = jar.to_local(hit)
	var best = null
	var bd := 1.2
	for r in BCBattle.ROWS:
		for c in BCBattle.COLS:
			var d := Vector2(local.x, local.z).distance_to(Vector2(BCBattle.tile_pos(c, r).x, BCBattle.tile_pos(c, r).z))
			if d < bd: bd = d; best = Vector2i(c, r)
	return best

func handle_click(from: Vector3, dir: Vector3) -> void:
	if busy or done or battle.turn_side != player_side: return
	var cell = _pick_cell(from, dir)
	if cell == null: return
	var occ = battle.get_unit_at(cell.x, cell.y)
	if occ != null and occ.side == player_side:
		if not occ.acted:
			selected = occ
			_show_cells(); _update_ui()
		return
	if selected == null: return
	if occ != null and occ.side != player_side:
		if not selected.acted and battle.can_attack_now(selected).has(occ):
			await _do_attack(selected, occ)
		return
	if battle.reachable(selected).has(cell):
		await _do_move(selected, cell)

func _do_move(u: BCBattle.Unit, cell: Vector2i) -> void:
	busy = true
	var a: BCActor = actors[u]
	var old_cell := Vector2i(u.c, u.r)
	if battle.move_unit(u, cell.x, cell.y):
		_clear_cells()
		var dest := BCBattle.tile_pos(cell.x, cell.y)
		var steps := maxi(1, BCBattle.dist(Vector2i(cell.x, cell.y), old_cell))
		var d := dest - a.position
		if Vector2(d.x, d.z).length() > 0.01: a.rotation.y = atan2(d.x, d.z)
		a.play("walk")
		var tw := create_tween()
		tw.tween_property(a, "position", dest, 0.25 + 0.2 * float(steps))
		await tw.finished
		a.play("idle")
	busy = false
	if u.side == player_side:
		_show_cells()
		_update_ui()

func _do_attack(u: BCBattle.Unit, t: BCBattle.Unit) -> void:
	busy = true
	_clear_cells()
	var a: BCActor = actors[u]
	var ta: BCActor = actors[t]
	var d := ta.position - a.position
	if Vector2(d.x, d.z).length() > 0.01: a.rotation.y = atan2(d.x, d.z)
	a.play_once("fight", 0.9)
	await get_tree().create_timer(0.45).timeout
	var res := battle.attack(u, t)
	_float_text(ta.position, "-%d" % ceili(res.dmg), Color(1.0, 0.45, 0.35))
	ta.play_once("hit" if ta.is_inside_tree() else "idle", 0.5)
	if res.killed: _kill_visual(t)
	if res.counter > 0.0:
		await get_tree().create_timer(0.35).timeout
		_float_text(a.position, "-%d" % ceili(res.counter), Color(1.0, 0.8, 0.4))
		if res.counter_killed: _kill_visual(u)
	await get_tree().create_timer(0.5).timeout
	busy = false
	selected = null if (u.side == player_side) else selected
	_clear_cells()
	_update_ui()
	_check_finish()

func _kill_visual(u: BCBattle.Unit) -> void:
	var a: BCActor = actors[u]
	a.play_once("death", 3.0)
	var tw := create_tween()
	tw.tween_interval(1.4)
	tw.tween_property(a, "scale", Vector3.ONE * 0.01, 0.5)

func _float_text(pos: Vector3, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text
	l.font_size = 64
	l.pixel_size = 0.014
	l.modulate = col
	l.outline_size = 14
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.position = pos + Vector3(0, 2.6, 0)
	add_child(l)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y + 1.2, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)

func _on_defend() -> void:
	if busy or selected == null: return
	battle.defend(selected)
	_float_text(actors[selected].position, "Brace!", Color(0.6, 0.85, 1.0))
	selected = null
	_clear_cells(); _update_ui()

func _on_end_turn() -> void:
	if busy or battle.turn_side != player_side: return
	selected = null
	_clear_cells()
	battle.end_turn()
	_update_ui()
	if not _check_finish() and battle.turn_side != player_side:
		_ai_turn()

func _on_auto() -> void:
	if done: return
	battle.auto_finish()
	for u in battle.units:
		if not u.alive and actors[u].scale.x > 0.5: _kill_visual(u)
		else: actors[u].position = BCBattle.tile_pos(u.c, u.r)
	_clear_cells(); _update_ui()
	_check_finish()

func _ai_turn() -> void:
	busy = true
	_update_ui()
	await get_tree().create_timer(0.6).timeout
	for u in battle.living(battle.turn_side).duplicate():
		if battle.finished or done: break
		if not u.alive: continue
		var plan := battle.ai_plan(u)
		if plan.move != null:
			busy = false
			await _do_move(u, plan.move)
			busy = true
			await get_tree().create_timer(0.15).timeout
		if plan.target != null and plan.target.alive and BCBattle.dist(Vector2i(u.c, u.r), Vector2i(plan.target.c, plan.target.r)) <= u.reach:
			busy = false
			await _do_attack(u, plan.target)
			busy = true
		elif plan.defend:
			battle.defend(u)
			_float_text(actors[u].position, "Brace!", Color(0.6, 0.85, 1.0))
		if _check_finish(): return
	if battle.finished or done: return
	battle.end_turn()
	busy = false
	_update_ui()
	if not _check_finish() and battle.turn_side != player_side:
		_ai_turn()

func _check_finish() -> bool:
	if done: return true
	if not battle.finished: return false
	done = true
	busy = true
	var won := (battle.attacker_wins and player_side == 0) or ((not battle.attacker_wins) and player_side == 1)
	banner.text = "VICTORY" if won else "DEFEAT"
	banner.add_theme_color_override("font_color", Color(0.5, 1.0, 0.5) if won else Color(1.0, 0.45, 0.4))
	banner.visible = true
	_update_ui()
	_close_later()
	return true

func _close_later() -> void:
	await get_tree().create_timer(2.2).timeout
	jar.battle_mode = false
	finished.emit(battle.attacker_wins, battle.survivors(0), battle.survivors(1), battle.all_citizens(1))
	queue_free()
