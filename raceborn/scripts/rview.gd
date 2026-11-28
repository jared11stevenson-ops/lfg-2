extends Node3D
## World view, input and flow for Raceborn: Ages.
## Command line (after --):  --race=2 --leader=0 --seed=7  --shot=/tmp/a.png --autoplay=20 --select=city --lowfx

const SETTLER_MODEL := {"model": "res://assets/characters/outfits/Male_Peasant.gltf", "rig": "ual", "height": 0.9, "squash": Vector3.ONE}
const SCOUT_MODEL := {"model": "res://assets/characters/kaykit/Rogue_Hooded.glb", "rig": "kaykit", "height": 0.8, "squash": Vector3.ONE}

var g: RGame
var ui: RUI
var audio: BCAudio
var args := {}
var sun: DirectionalLight3D
var env: Environment

var tile_nodes: Array = []
var fog_mm: MultiMesh
var own_mm: MultiMesh
var city_nodes := {}
var unit_views := {}              # id -> {actor, ring, label, target}
var hl_pool: Array = []
var hl_mats := {}
var hover_hex: MeshInstance3D

var selected_unit: RGame.Unit = null
var selected_city: RGame.City = null
var skipped := {}
var started := false

# camera
var cam: Camera3D
var cam_target := Vector3(28, 0, 14)
var cam_dist := 34.0
var cam_yaw := 0.0
var g_target := Vector3(28, 0, 14)
var g_dist := 34.0
const PITCH := -58.0

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv := a.lstrip("-").split("=")
		args[kv[0]] = kv[1] if kv.size() > 1 else "1"
	_build_environment()
	cam = Camera3D.new()
	cam.fov = 38.0; cam.far = 300.0
	add_child(cam)
	audio = BCAudio.new()
	add_child(audio)
	ui = RUI.new()
	add_child(ui)
	ui.cmd.connect(_on_cmd)
	ui.start_game.connect(_begin)
	if args.has("race"):
		_begin(int(args.race), int(args.get("leader", 0)))
	else:
		ui.show_start()

func _build_environment() -> void:
	var we := WorldEnvironment.new()
	env = Environment.new()
	var sky := Sky.new()
	var psm := ProceduralSkyMaterial.new()
	psm.sky_top_color = Color(0.32, 0.5, 0.8)
	psm.sky_horizon_color = Color(0.7, 0.8, 0.9)
	psm.ground_horizon_color = Color(0.55, 0.62, 0.7)
	sky.sky_material = psm
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	env.ambient_light_energy = 0.7
	env.tonemap_mode = Environment.TONE_MAPPER_ACES
	env.tonemap_exposure = 0.9
	env.glow_enabled = true
	env.glow_intensity = 0.5
	if not args.has("lowfx"):
		env.ssao_enabled = true
		env.fog_enabled = true
		env.fog_light_color = Color(0.6, 0.7, 0.85)
		env.fog_density = 0.002
	env.adjustment_enabled = true
	env.adjustment_saturation = 1.1
	we.environment = env
	add_child(we)
	sun = DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55, -30, 0)
	sun.light_energy = 1.1
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 140.0
	add_child(sun)

# ------------------------------------------------------------------ game start
func _begin(race: int, leader: int) -> void:
	g = RGame.new()
	g.new_game(int(args.get("seed", randi() % 100000)), race, leader, 3)
	g.note.connect(_on_note)
	g.unit_moved.connect(_on_unit_moved)
	g.unit_removed.connect(_on_unit_removed)
	g.city_changed.connect(_on_city_changed)
	g.combat.connect(_on_combat)
	g.finished.connect(func(w, k): ui.show_game_over())
	_build_map()
	ui.build(g)
	started = true
	# focus on the start
	for u in g.units.values():
		if u.owner == 0:
			cam_target = Hex.world_v(u.pos); break
	g_target = cam_target
	for c in g.cities.values(): _on_city_changed(c)
	_refresh_fog()
	_sync_units(0.0, true)
	ui.refresh()
	_update_next()
	if args.has("shot"): _run_shot()

# ------------------------------------------------------------------ map
func _build_map() -> void:
	var root := Node3D.new(); root.name = "Map"; add_child(root)
	var decor_rng := RandomNumberGenerator.new(); decor_rng.seed = g.seed_value
	for i in RData.MAP_W * RData.MAP_H:
		var c := i % RData.MAP_W
		var r := i / RData.MAP_W
		var tl: Dictionary = g.tiles[i]
		var n := Node3D.new()
		n.position = Hex.world(c, r)
		root.add_child(n)
		var base: Node3D = BCAssets.tile("hex_water" if tl.t == RData.T.OCEAN else "hex_grass")
		if tl.t != RData.T.OCEAN: BCAssets.tint_green(base)
		n.add_child(base)
		var d: Node3D = null
		match tl.t:
			RData.T.FOREST: d = BCAssets.nature(["trees_A_large", "trees_B_large", "trees_A_medium"][decor_rng.randi() % 3])
			RData.T.HILLS: d = BCAssets.nature(["hills_A", "hills_B", "hills_C"][decor_rng.randi() % 3])
			RData.T.MOUNTAIN: d = BCAssets.nature(["mountain_A_grass", "mountain_B_grass_trees", "mountain_C_grass"][decor_rng.randi() % 3])
		if d != null:
			d.rotation_degrees.y = float(decor_rng.randi() % 6) * 60.0
			n.add_child(d)
		var rs := _resource_node(tl)
		if rs != null: n.add_child(rs)
		tile_nodes.append(n)
	# fog + territory overlays (one MultiMesh each)
	var hexm := CylinderMesh.new()
	hexm.top_radius = 1.16; hexm.bottom_radius = 1.16; hexm.height = 0.04; hexm.radial_segments = 6
	fog_mm = _overlay_mm(hexm, 2.1)
	var hexo := CylinderMesh.new()
	hexo.top_radius = 1.08; hexo.bottom_radius = 1.08; hexo.height = 0.04; hexo.radial_segments = 6
	own_mm = _overlay_mm(hexo, 0.06)
	hover_hex = MeshInstance3D.new()
	hover_hex.mesh = hexo
	hover_hex.material_override = _hl_mat(Color(1, 1, 1), 0.35)
	hover_hex.visible = false
	add_child(hover_hex)

func _overlay_mm(mesh: Mesh, y: float) -> MultiMesh:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = mesh
	mm.instance_count = RData.MAP_W * RData.MAP_H
	for i in mm.instance_count:
		var p := Hex.world(i % RData.MAP_W, i / RData.MAP_W)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, deg_to_rad(30.0)), p + Vector3(0, y, 0)))
		mm.set_instance_color(i, Color(0, 0, 0, 0))
	var mi := MultiMeshInstance3D.new()
	mi.multimesh = mm
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	return mm

func _resource_node(tl: Dictionary) -> Node3D:
	var n: Node3D = null
	match tl.res:
		"wheat": n = BCAssets.building("building_grain", "neutral")
		"stone": n = BCAssets.nature("rock_single_A")
		"gems": n = BCAssets.prop("resource_stone")
		"fish": n = BCAssets.nature("waterplant_A")
		"relic": n = BCAssets.prop("crate_open")
	if n != null:
		n.position = Vector3(0.45, 0.0 if tl.t != RData.T.HILLS else 0.5, 0.35)
		n.scale = Vector3.ONE * (0.8 if tl.res != "wheat" else 0.9)
	return n

func _refresh_fog() -> void:
	var p: RGame.Player = g.players[0]
	for i in tile_nodes.size():
		var explored: bool = p.explored[i] == 1
		var vis: bool = p.visible[i] == 1
		fog_mm.set_instance_color(i, Color(0.02, 0.03, 0.05, 1.0) if not explored else (Color(0.04, 0.05, 0.1, 0.45) if not vis else Color(0, 0, 0, 0)))
		var tl: Dictionary = g.tiles[i]
		if explored and tl.owner >= 0:
			var col: Color = RData.RACES[g.players[tl.owner].race].color
			own_mm.set_instance_color(i, Color(col.r, col.g, col.b, 0.32))
		else:
			own_mm.set_instance_color(i, Color(0, 0, 0, 0))
	for id in city_nodes:
		var c: RGame.City = g.cities[id]
		city_nodes[id].visible = p.explored[g.idx(c.pos)] == 1

func _hl_mat(c: Color, a: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(c.r, c.g, c.b, a)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	return m

func _show_range() -> void:
	for h in hl_pool: h.visible = false
	if selected_unit == null: return
	var u := selected_unit
	var tiles_to_mark: Array = []
	for p in g.reachable(u).keys(): tiles_to_mark.append([p, "move"])
	for q in Hex.ring(u.pos, g.unit_range(u), g.W, g.H):
		if g.can_attack(u, q): tiles_to_mark.append([q, "atk"])
	tiles_to_mark.append([u.pos, "sel"])
	while hl_pool.size() < tiles_to_mark.size():
		var mi := MeshInstance3D.new()
		var cm := CylinderMesh.new(); cm.top_radius = 1.0; cm.bottom_radius = 1.0; cm.height = 0.04; cm.radial_segments = 6
		mi.mesh = cm; mi.rotation_degrees.y = 30.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)
		hl_pool.append(mi)
	if hl_mats.is_empty():
		hl_mats = {"move": _hl_mat(Color(0.3, 1.0, 0.5), 0.35), "atk": _hl_mat(Color(1.0, 0.25, 0.2), 0.5), "sel": _hl_mat(Color(1.0, 0.9, 0.3), 0.45)}
	for i in tiles_to_mark.size():
		var h: MeshInstance3D = hl_pool[i]
		h.material_override = hl_mats[tiles_to_mark[i][1]]
		h.position = Hex.world_v(tiles_to_mark[i][0]) + Vector3(0, 0.12, 0)
		h.visible = true

# ------------------------------------------------------------------ cities
func _on_city_changed(c: RGame.City) -> void:
	if not city_nodes.has(c.id):
		var n := Node3D.new()
		add_child(n)
		n.position = Hex.world_v(c.pos)
		city_nodes[c.id] = n
	var n2: Node3D = city_nodes[c.id]
	for ch in n2.get_children(): ch.queue_free()
	var col: String = RData.RACES[g.players[c.owner].race].bcolor
	var center: Node3D = BCAssets.building("building_castle" if c.is_city else "building_home_A", col)
	center.scale = Vector3.ONE * (1.0 if c.is_city else 1.3)
	n2.add_child(center)
	var offs := [Vector3(0.8, 0, 0.55), Vector3(-0.8, 0, 0.55), Vector3(0.85, 0, -0.5), Vector3(-0.85, 0, -0.5), Vector3(0, 0, 0.9)]
	var i := 0
	for b in c.buildings:
		if i >= offs.size(): break
		var mesh: String = "building_tavern" if b == "ubld" else RData.BUILDINGS[b][8]
		var bn := BCAssets.building(mesh, col)
		bn.position = offs[i]; bn.scale = Vector3.ONE * 0.75
		n2.add_child(bn); i += 1
	var l := Label3D.new()
	l.text = "%s [%d]" % [c.cname, c.pop]
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 40; l.pixel_size = 0.012; l.outline_size = 12; l.no_depth_test = true
	l.modulate = RData.RACES[g.players[c.owner].race].color.lightened(0.35)
	l.position = Vector3(0, 4.6 if c.is_city else 2.6, 0)
	n2.add_child(l)
	if g.players[0].explored.size() > 0: n2.visible = g.players[0].explored[g.idx(c.pos)] == 1

# ------------------------------------------------------------------ units
func _make_view(u: RGame.Unit) -> Dictionary:
	var rc: Dictionary = RData.RACES[g.players[u.owner].race]
	var model: Dictionary = SETTLER_MODEL if u.kind == "settler" else (SCOUT_MODEL if u.kind == "scout" else rc)
	var a := BCActor.new()
	add_child(a)
	a.setup(model)
	a.scale = Vector3.ONE * 0.85
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 0.55; tm.outer_radius = 0.7
	ring.mesh = tm
	ring.material_override = BCAssets.emissive(rc.color, 2.2)
	ring.position = Vector3(0, 0.05, 0)
	a.add_child(ring)
	var l := Label3D.new()
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 30; l.pixel_size = 0.012; l.outline_size = 10; l.no_depth_test = true
	l.position = Vector3(0, 2.1, 0)
	a.add_child(l)
	a.position = _unit_world(u)
	return {"actor": a, "ring": ring, "label": l, "target": a.position, "kind": u.kind, "race": g.players[u.owner].race}

func _unit_world(u: RGame.Unit) -> Vector3:
	var p := Hex.world_v(u.pos)
	var others := g.unit_at(u.pos, u.owner)
	var k := others.find(u)
	p.x += (float(k) * 0.55) - 0.2 if others.size() > 1 else 0.0
	if g.tile(u.pos).t == RData.T.HILLS: p.y += 0.55
	if g.city_at(u.pos) != null: p.z += 1.0
	return p

func _sync_units(dt: float, snap: bool = false) -> void:
	var human: RGame.Player = g.players[0]
	for id in g.units:
		var u: RGame.Unit = g.units[id]
		if not unit_views.has(id):
			unit_views[id] = _make_view(u)
		var v: Dictionary = unit_views[id]
		var a: BCActor = v.actor
		var tgt := _unit_world(u)
		v.target = tgt
		var d: Vector3 = tgt - a.position
		var moving := d.length() > 0.08
		if snap: a.position = tgt
		elif moving:
			a.position += d.normalized() * minf(d.length(), 5.5 * dt)
			a.rotation.y = lerp_angle(a.rotation.y, atan2(d.x, d.z), minf(1.0, dt * 10.0))
		if not a.is_locked(): a.play("walk" if moving else ("idle2" if u.fortified else "idle"))
		var show: bool = u.owner == 0 or human.visible[g.idx(u.pos)] == 1
		a.visible = show
		var sel: bool = selected_unit != null and selected_unit.id == id
		(v.ring as MeshInstance3D).scale = Vector3.ONE * (1.35 if sel else 1.0)
		var lbl: Label3D = v.label
		lbl.visible = show and (u.hp < g.max_hp(u) - 1.0 or sel)
		lbl.text = "%d" % u.hp
		lbl.modulate = Color(0.6, 1.0, 0.6) if u.hp > 60.0 else Color(1.0, 0.7, 0.4)
	for id in unit_views.keys():
		if not g.units.has(id): _drop_view(id)

func _drop_view(id) -> void:
	if not unit_views.has(id): return
	var v: Dictionary = unit_views[id]
	var a: BCActor = v.actor
	unit_views.erase(id)
	a.play_once("death", 2.0)
	var tw := create_tween()
	tw.tween_interval(1.0)
	tw.tween_property(a, "scale", Vector3.ONE * 0.01, 0.4)
	tw.tween_callback(a.queue_free)

func _on_unit_moved(u: RGame.Unit, from: Vector2i, to: Vector2i) -> void:
	if u.owner == 0 and started: _refresh_fog()

func _on_unit_removed(u: RGame.Unit) -> void:
	if selected_unit == u: _deselect()

func _on_combat(att: Vector2i, def: Vector2i, dmg: float, counter: float, killed: bool) -> void:
	_float(def, "-%d" % int(dmg), Color(1.0, 0.45, 0.35))
	if counter > 0.5: _float(att, "-%d" % int(counter), Color(1.0, 0.8, 0.4))
	BCAudio.sfx("knifeSlice", -6.0)
	for u in g.unit_at(att):
		if unit_views.has(u.id): (unit_views[u.id].actor as BCActor).play_once("fight", 0.9)
	if killed: BCAudio.sfx("chop", -8.0, 0.8)

func _float(tile_pos: Vector2i, text: String, col: Color) -> void:
	var l := Label3D.new()
	l.text = text; l.font_size = 64; l.pixel_size = 0.014; l.modulate = col; l.outline_size = 14
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true
	add_child(l)
	l.position = Hex.world_v(tile_pos) + Vector3(0, 2.4, 0)
	var tw := create_tween()
	tw.tween_property(l, "position:y", l.position.y + 1.4, 0.9)
	tw.parallel().tween_property(l, "modulate:a", 0.0, 0.9)
	tw.tween_callback(l.queue_free)

func _on_note(pid: int, text: String, kind: String) -> void:
	if pid == 0 and started: ui.add_note(text, kind)

# ------------------------------------------------------------------ selection / orders
func _deselect() -> void:
	selected_unit = null; selected_city = null
	_show_range()
	ui.show_selection(null, null)

func _select_unit(u: RGame.Unit) -> void:
	selected_unit = u; selected_city = null
	_show_range()
	ui.last_sel_key = ""
	ui.show_selection(u, null)

func _select_city(c: RGame.City) -> void:
	selected_city = c; selected_unit = null
	_show_range()
	ui.last_sel_key = ""
	ui.show_selection(null, c)

func _tile_under(mouse: Vector2) -> Vector2i:
	var from := cam.project_ray_origin(mouse)
	var dir := cam.project_ray_normal(mouse)
	var hit = Plane(Vector3.UP, 0.3).intersects_ray(from, dir)
	if hit == null: return Vector2i(-1, -1)
	return Hex.from_world(hit.x, hit.z, g.W, g.H)

func _left_click(pos: Vector2i) -> void:
	if pos.x < 0: _deselect(); return
	var mine := g.unit_at(pos, 0)
	var mil := mine.filter(func(u): return u.kind == "melee" or u.kind == "ranged")
	var cand: Array = mil if not mil.is_empty() else mine
	if not cand.is_empty():
		var i := cand.find(selected_unit)
		_select_unit(cand[(i + 1) % cand.size()])
		return
	var c := g.city_at(pos)
	if c != null and c.owner == 0:
		_select_city(c)
		return
	_deselect()
	if g.players[0].explored[g.idx(pos)] == 1:
		var tl: Dictionary = g.tile(pos)
		var info: String = "%s" % RData.TERRAIN[tl.t][0]
		if tl.res != "": info += " - " + RData.RESOURCES[tl.res][0]
		var foes := g.unit_at(pos).filter(func(u): return u.owner != 0 and g.players[0].visible[g.idx(pos)] == 1)
		if not foes.is_empty(): info += " | %s (%s) HP %d" % [g.unit_name(foes[0]), RData.RACES[g.players[foes[0].owner].race].name, foes[0].hp]
		var cc := g.city_at(pos)
		if cc != null and cc.owner != 0: info += " | %s (%s)" % [cc.cname, RData.RACES[g.players[cc.owner].race].name]
		ui.set_tooltip(info)

func _right_click(pos: Vector2i) -> void:
	var u := selected_unit
	if u == null or pos.x < 0 or u.owner != 0: return
	if g.can_attack(u, pos):
		g.attack(u, pos)
	elif g.set_goto(u, pos):
		pass
	else:
		ui.set_tooltip("Cannot move there.")
	_after_action()

func _after_action() -> void:
	_refresh_fog()
	_show_range()
	ui.last_sel_key = ""
	ui.show_selection(selected_unit, selected_city)
	ui.refresh()
	_update_next()

# ------------------------------------------------------------------ turn flow
func _attention():
	if g == null: return null
	for c in g.city_of(g.players[0]):
		if c.is_city and c.producing == "": return c
	for u in g.units.values():
		if u.owner == 0 and u.mp > 0 and not u.fortified and not u.sleeping and u.path.is_empty() and skipped.get(u.id, -1) != g.turn:
			return u
	return null

func _update_next() -> void:
	var a = _attention()
	if g.game_over: ui.set_next_text("Game over")
	elif a == null: ui.set_next_text("End Turn (%d)" % g.turn)
	elif a is RGame.City: ui.set_next_text("Choose production: %s" % a.cname)
	else: ui.set_next_text("Next unit: %s" % g.unit_name(a))

func _focus(pos: Vector2i) -> void:
	g_target = Hex.world_v(pos)

func _next() -> void:
	if g.game_over or g.transition != "": return
	var a = _attention()
	if a == null:
		_end_turn()
	elif a is RGame.City:
		_select_city(a); _focus(a.pos)
	else:
		_select_unit(a); _focus(a.pos)

func _end_turn() -> void:
	_deselect()
	skipped.clear()
	BCAudio.sfx("bookFlip1", -6.0)
	g.end_turn()
	_refresh_fog()
	ui.refresh()
	_update_next()
	if g.transition == "":
		var a = _attention()
		if a != null: _next()

func _on_cmd(kind: String, arg) -> void:
	var p: RGame.Player = g.players[0]
	match kind:
		"next": _next()
		"open":
			match arg:
				"tech": ui.show_research(false)
				"civics": ui.show_research(true)
				"legacy": ui.show_legacy()
				"diplo": ui.show_diplomacy()
		"research": g.set_research(p, arg); ui.refresh()
		"civic": g.set_civic(p, arg); ui.refresh()
		"found":
			if selected_unit != null and selected_unit.kind == "settler":
				var pos := selected_unit.pos
				var city := g.found_city(selected_unit)
				if city == null: ui.set_tooltip("Cannot found a city here (3+ tiles from other cities, on land).")
				else:
					BCAudio.sfx("doorOpen_1", -4.0)
					_deselect(); _select_city(city)
		"fortify":
			if selected_unit != null: selected_unit.fortified = true; _deselect()
		"sleep":
			if selected_unit != null: selected_unit.sleeping = true; _deselect()
		"skip":
			if selected_unit != null: skipped[selected_unit.id] = g.turn; _deselect()
		"prod":
			if selected_city != null: g.set_production(selected_city, arg)
		"buy":
			if selected_city != null and g.buy(selected_city): BCAudio.sfx("handleCoins", -6.0)
		"upgrade":
			if selected_city != null: g.upgrade_town(selected_city)
		"war": g.declare_war(0, arg)
		"peace":
			if g.propose_peace(0, arg): ui.set_tooltip("They accept peace.")
			else: ui.set_tooltip("They refuse (war must last 4+ turns; they must feel pressed).")
		"transition": ui.show_transition()
		"crisis":
			g.resolve_crisis(arg)
			ui.show_transition()
		"race":
			g.choose_race(arg)
			ui.close_modal()
			_rebuild_after_age()
		"restart": get_tree().reload_current_scene()
	if kind in ["found", "fortify", "sleep", "skip", "prod", "buy", "upgrade", "war", "peace", "research", "civic"]:
		_after_action()
	if g.game_over and kind != "restart": pass

func _rebuild_after_age() -> void:
	for id in unit_views.keys():
		(unit_views[id].actor as Node).queue_free()
	unit_views.clear()
	for c in g.cities.values(): _on_city_changed(c)
	_refresh_fog()
	ui.refresh()
	_update_next()

# ------------------------------------------------------------------ loop & input
func _process(dt: float) -> void:
	if not started: return
	audio.set_day_factor(1.0, dt)
	_sync_units(dt)
	var pan := Vector3.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): pan.z -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): pan.z += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): pan.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): pan.x += 1
	if Input.is_key_pressed(KEY_Q): cam_yaw += 60.0 * dt
	if Input.is_key_pressed(KEY_E): cam_yaw -= 60.0 * dt
	if pan != Vector3.ZERO:
		g_target += Basis(Vector3.UP, deg_to_rad(cam_yaw)) * pan.normalized() * dt * (g_dist * 0.9)
	g_target.x = clampf(g_target.x, 0.0, 58.0); g_target.z = clampf(g_target.z, 0.0, 31.0)
	var k := minf(1.0, dt * 6.0)
	cam_target = cam_target.lerp(g_target, k)
	cam_dist = lerpf(cam_dist, g_dist, k)
	var b := Basis.from_euler(Vector3(deg_to_rad(PITCH), deg_to_rad(cam_yaw), 0.0))
	cam.global_transform = Transform3D(b, cam_target + b * Vector3(0, 0, cam_dist))
	if selected_unit != null or selected_city != null:
		ui.show_selection(selected_unit, selected_city)

func _unhandled_input(ev: InputEvent) -> void:
	if not started or g == null: return
	if ev is InputEventMouseButton and ev.pressed:
		match ev.button_index:
			MOUSE_BUTTON_WHEEL_UP: g_dist = clampf(g_dist * 0.9, 12.0, 70.0)
			MOUSE_BUTTON_WHEEL_DOWN: g_dist = clampf(g_dist * 1.1, 12.0, 70.0)
			MOUSE_BUTTON_LEFT: _left_click(_tile_under(ev.position))
			MOUSE_BUTTON_RIGHT: _right_click(_tile_under(ev.position))
	elif ev is InputEventMouseMotion:
		if ev.button_mask & MOUSE_BUTTON_MASK_MIDDLE:
			var b := Basis(Vector3.UP, deg_to_rad(cam_yaw))
			g_target += b * Vector3(-ev.relative.x, 0, -ev.relative.y) * g_dist * 0.002
		var h := _tile_under(ev.position)
		hover_hex.visible = h.x >= 0
		if h.x >= 0: hover_hex.position = Hex.world_v(h) + Vector3(0, 0.1, 0)
	elif ev is InputEventKey and ev.pressed:
		match ev.keycode:
			KEY_SPACE, KEY_ENTER: _next()
			KEY_B: _on_cmd("found", null)
			KEY_F: _on_cmd("fortify", null)
			KEY_S:
				if not ev.shift_pressed and selected_unit != null and false: pass
			KEY_T: ui.show_research(false)
			KEY_C: ui.show_research(true)
			KEY_L: ui.show_legacy()
			KEY_D: ui.show_diplomacy()
			KEY_ESCAPE:
				if ui.modal != null: ui.close_modal()
				else: _deselect()
			KEY_M: audio.toggle_mute()

# ------------------------------------------------------------------ screenshots (testing)
func _run_shot() -> void:
	var n := int(args.get("autoplay", 0))
	for i in n:
		RAI.take_turn(g, g.players[0])
		g.end_turn()
		if g.transition == "crisis": g.resolve_crisis(false)
		if g.transition == "race": g.choose_race(g.free_races()[0])
	_rebuild_after_age()
	for p in g.players: g.update_visibility(p) if p.id == 0 else null
	if args.has("reveal"):
		for i in g.players[0].explored.size(): g.players[0].explored[i] = 1; g.players[0].visible[i] = 1
	_refresh_fog()
	var mine := g.city_of(g.players[0])
	if args.has("select") and not mine.is_empty():
		_select_city(mine[0]); cam_target = Hex.world_v(mine[0].pos); g_target = cam_target
	elif not mine.is_empty():
		cam_target = Hex.world_v(mine[0].pos); g_target = cam_target
	if args.has("dist"): g_dist = float(args.dist); cam_dist = g_dist
	if args.has("far"): g_target = Vector3(28, 0, 14); cam_target = g_target; g_dist = 62.0; cam_dist = 62.0
	if args.has("research"): ui.show_research(false)
	if args.has("transition"):
		g.transition = "race"; ui.show_transition()
	for i in int(args.get("frames", 40)): await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png(args.shot)
	print("shot saved turn ", g.turn, " age ", g.age, " cities ", g.cities.size(), " units ", g.units.size())
	get_tree().quit()
