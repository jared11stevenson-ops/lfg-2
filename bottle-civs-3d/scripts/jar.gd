class_name BCJar
extends Node3D
## One glass-fronted terrarium on the Wall: hex-tile ground, KayKit buildings, animated citizens, a lid that
## seals every night and a lock rig. Visual state is driven entirely from BCSim.

const SX := 13.4            # world width of the sim's 0..200 x range
const SZ := 9.4             # world depth of the sim's 0..150 y range
const HALF_X := 7.7
const HALF_Z := 5.7
const H := 5.4
const MAX_ACTORS := 16

# [kind, name, sim_x, sim_y, scale, rot_deg]   kind: n=nature p=prop b=building(civ colour) t=tile override
const DECOR := {
	"forest": [["n", "trees_B_large", 10, 20, 1.5, 0], ["n", "trees_A_large", 70, 10, 1.4, 40], ["n", "trees_B_medium", 190, 14, 1.4, 10],
		["n", "trees_A_large", 14, 66, 1.4, 90], ["n", "trees_B_large", 186, 70, 1.5, 0], ["n", "trees_A_medium", 140, 12, 1.3, 20]],
	"mountain": [["n", "mountain_A_grass", 14, 16, 1.7, 0], ["n", "mountain_B_grass_trees", 184, 16, 1.7, 180], ["n", "hills_A", 100, 6, 1.5, 0],
		["n", "rock_single_C", 186, 84, 1.6, 30], ["n", "rock_single_A", 14, 78, 1.5, 0]],
	"town": [["p", "flag_blue", 60, 66, 1.6, 0], ["p", "flag_blue", 138, 66, 1.6, 0], ["n", "trees_A_small", 14, 70, 1.4, 0], ["n", "trees_B_small", 188, 62, 1.4, 0],
		["b", "building_well", 120, 112, 1.5, 0]],
	"swamp": [["n", "waterlily_A", 100, 118, 1.6, 0], ["n", "waterplant_B", 120, 108, 1.5, 0], ["n", "waterlily_B", 80, 112, 1.5, 0],
		["n", "trees_A_small", 190, 20, 1.4, 0], ["n", "waterplant_A", 60, 112, 1.5, 0]],
	"war": [["p", "tent", 22, 118, 1.7, 20], ["p", "tent", 176, 114, 1.7, -30], ["p", "weaponrack", 76, 72, 1.6, 0], ["p", "target", 124, 66, 1.6, 180],
		["p", "flag_red", 100, 14, 1.8, 0], ["n", "rock_single_B", 14, 20, 1.5, 0]],
	"scrap": [["p", "crate_A_big", 70, 104, 1.5, 12], ["p", "barrel", 116, 110, 1.5, 0], ["p", "wheelbarrow", 176, 70, 1.6, -40],
		["b", "building_scaffolding", 20, 20, 1.5, 0], ["p", "pallet", 60, 16, 1.5, 0], ["p", "crate_B_small", 186, 100, 1.5, 0]],
	"ruins": [["b", "building_destroyed", 24, 22, 1.7, 0], ["b", "building_destroyed", 176, 24, 1.7, 40], ["b", "building_dirt", 100, 108, 1.6, 0],
		["n", "rock_single_D", 14, 78, 1.5, 0], ["n", "rock_single_E", 188, 74, 1.4, 0]],
	"tavern": [["b", "building_tavern", 100, 14, 1.7, 0], ["p", "barrel", 64, 14, 1.6, 0], ["p", "barrel", 130, 18, 1.6, 0], ["n", "trees_A_medium", 14, 70, 1.4, 0]],
	"hell": [["n", "mountain_C", 16, 18, 1.7, 0], ["n", "rock_single_A", 184, 22, 1.7, 0], ["n", "rock_single_B", 188, 78, 1.5, 0],
		["b", "building_dirt", 100, 110, 1.6, 0], ["p", "flag_red", 56, 14, 1.8, 0]],
	"arcane": [["b", "building_tower_B", 24, 18, 1.6, 0], ["b", "building_tower_A", 178, 20, 1.6, 0], ["b", "building_well", 118, 112, 1.5, 0],
		["n", "trees_A_small", 14, 72, 1.4, 0]],
}

# Ground tiles replaced by water in swampy jars (row, col)
const WATER_TILES := {"swamp": [[4, 3], [4, 4], [5, 3], [5, 4], [4, 2], [5, 5]]}

var sim: BCSim
var idx := 0
var race: Dictionary
var sealed := false
var lid_pivot: Node3D
var lid_open := 1.0
var light: OmniLight3D
var actor_root: Node3D
var props_root: Node3D
var actors := {}                    # citizen id -> BCActor
var house_nodes: Array = []
var tech_nodes := {}
var led: MeshInstance3D
var led_mat: StandardMaterial3D
var plaque: Label3D
var info_label: Label3D
var bolts: Array = []
var lock_light: MeshInstance3D
var lock_mat: StandardMaterial3D
var glass_mats: Array = []
var fx_flash := 0.0
var fx_kind := ""
var prev_flash_t := 0.0
var sparks: CPUParticles3D
var shake := 0.0
var pending_actor_budget := 2
var rect_aabb: AABB
var selected := false
var battle_mode := false
var dead_civ := false
var hovered := false
var ring: MeshInstance3D

func setup(p_sim: BCSim, p_idx: int) -> void:
	sim = p_sim
	idx = p_idx
	sealed = idx >= BCData.RACES.size()
	race = BCData.SEALED[idx - BCData.RACES.size()] if sealed else BCData.RACES[idx]
	name = "Jar_%d" % idx
	_build_base()
	_build_glass_and_frame()
	if sealed:
		_build_sealed()
	else:
		_build_ground()
		_build_settlement()
	actor_root = Node3D.new(); actor_root.name = "Actors"; add_child(actor_root)
	_build_light_and_fx()
	rect_aabb = AABB(Vector3(-HALF_X - 0.6, -1.6, -HALF_Z - 0.6), Vector3(HALF_X * 2 + 1.2, H + 2.2, HALF_Z * 2 + 1.2))

# world position for a sim-space point
func to_local_pos(p: Vector2) -> Vector3:
	return Vector3((p.x / BCSim.JAR_W - 0.5) * SX, 0.0, (p.y / BCSim.JAR_H - 0.5) * SZ)

# ---------------------------------------------------------------- construction
func _build_base() -> void:
	var metal := BCAssets.pbr("metal_plate", Vector3(0.5, 0.5, 0.5))
	var slab := BCAssets.box(Vector3(HALF_X * 2 + 1.6, 1.2, HALF_Z * 2 + 1.6), metal, Vector3(0, -1.6, 0))
	add_child(slab)
	var skirt := BCAssets.box(Vector3(HALF_X * 2 + 2.0, 0.5, HALF_Z * 2 + 2.0), BCAssets.pbr("blue_metal_plate", Vector3(0.4, 0.4, 0.4)), Vector3(0, -2.4, 0))
	add_child(skirt)

func _build_ground() -> void:
	var water: Array = WATER_TILES.get(race.decor, [])
	var root := Node3D.new(); root.name = "Ground"; add_child(root)
	for r in 6:
		for c in 7:
			var x := float(c - 3) * 2.0 + (0.5 if r % 2 == 1 else -0.5)
			var z := (float(r) - 2.5) * 1.732
			var is_water := false
			for w in water:
				if w[0] == r and w[1] == c: is_water = true
			var t := BCAssets.tile("hex_water" if is_water else "hex_grass")
			t.position = Vector3(x, 0, z)
			if not is_water: BCAssets.tint_green(t)
			root.add_child(t)

func _build_glass_and_frame() -> void:
	var gm := BCAssets.glass(Color(race.color.r * 0.4 + 0.5, race.color.g * 0.4 + 0.55, race.color.b * 0.4 + 0.6, 0.11))
	glass_mats.append(gm)
	var wall_t := 0.06
	var sides := [
		[Vector3(HALF_X * 2, H, wall_t), Vector3(0, H / 2, HALF_Z)],
		[Vector3(HALF_X * 2, H, wall_t), Vector3(0, H / 2, -HALF_Z)],
		[Vector3(wall_t, H, HALF_Z * 2), Vector3(HALF_X, H / 2, 0)],
		[Vector3(wall_t, H, HALF_Z * 2), Vector3(-HALF_X, H / 2, 0)],
	]
	for s in sides:
		var g := BCAssets.box(s[0], gm, s[1])
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(g)
	var frame_mat := BCAssets.pbr("metal_plate", Vector3(0.4, 0.4, 0.4), Color(0.8, 0.85, 0.95))
	for sx in [-1, 1]:
		for sz in [-1, 1]:
			add_child(BCAssets.box(Vector3(0.45, H + 0.2, 0.45), frame_mat, Vector3(sx * HALF_X, H / 2, sz * HALF_Z)))
	for sz in [-1, 1]:
		add_child(BCAssets.box(Vector3(HALF_X * 2 + 0.45, 0.35, 0.45), frame_mat, Vector3(0, H, sz * HALF_Z)))
	for sx in [-1, 1]:
		add_child(BCAssets.box(Vector3(0.45, 0.35, HALF_Z * 2), frame_mat, Vector3(sx * HALF_X, H, 0)))
	# glowing LED strip along the front rim in the civ colour
	led_mat = BCAssets.emissive(race.color, 1.0)
	led = BCAssets.box(Vector3(HALF_X * 2 - 0.4, 0.14, 0.1), led_mat, Vector3(0, H + 0.2, HALF_Z + 0.26))
	add_child(led)
	# lid: hinged at the back edge, seals at dusk
	lid_pivot = Node3D.new(); lid_pivot.position = Vector3(0, H + 0.2, -HALF_Z)
	add_child(lid_pivot)
	var lid := BCAssets.box(Vector3(HALF_X * 2 + 0.2, 0.12, HALF_Z * 2 + 0.2), BCAssets.glass(Color(0.75, 0.92, 1.0, 0.22)), Vector3(0, 0, HALF_Z))
	lid.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	lid_pivot.add_child(lid)
	var lid_frame_mat := BCAssets.pbr("blue_metal_plate", Vector3(0.4, 0.4, 0.4))
	lid.add_child(BCAssets.box(Vector3(HALF_X * 2 + 0.3, 0.2, 0.3), lid_frame_mat, Vector3(0, 0.05, HALF_Z)))
	lid.add_child(BCAssets.box(Vector3(HALF_X * 2 + 0.3, 0.2, 0.3), lid_frame_mat, Vector3(0, 0.05, -HALF_Z)))
	# two bolts that slide into the front posts when locked
	var bolt_mat := BCAssets.pbr("metal_plate", Vector3(0.3, 0.3, 0.3), Color(1.0, 0.85, 0.5))
	for sx in [-1, 1]:
		var b := BCAssets.box(Vector3(1.8, 0.32, 0.32), bolt_mat, Vector3(sx * (HALF_X - 0.8), H + 0.2, HALF_Z + 0.55))
		add_child(b)
		bolts.append(b)
	# padlock + status lamp
	lock_mat = BCAssets.emissive(Color(0.2, 1.0, 0.45), 3.0)
	lock_light = MeshInstance3D.new()
	var sph := SphereMesh.new(); sph.radius = 0.28; sph.height = 0.56
	lock_light.mesh = sph; lock_light.material_override = lock_mat
	lock_light.position = Vector3(0, H + 0.2, HALF_Z + 0.5)
	add_child(lock_light)
	# nameplate
	plaque = Label3D.new()
	plaque.text = race.jar.to_upper()
	plaque.font_size = 96
	plaque.pixel_size = 0.014
	plaque.modulate = race.color.lightened(0.25)
	plaque.outline_modulate = Color(0, 0, 0, 0.9)
	plaque.outline_size = 22
	plaque.position = Vector3(0, -1.55, HALF_Z + 0.9)
	plaque.rotation_degrees = Vector3(-8, 0, 0)
	plaque.shaded = false
	add_child(plaque)
	info_label = Label3D.new()
	info_label.font_size = 56
	info_label.pixel_size = 0.012
	info_label.modulate = Color(0.85, 0.82, 0.74)
	info_label.outline_size = 14
	info_label.position = Vector3(0, -2.35, HALF_Z + 1.1)
	info_label.rotation_degrees = Vector3(-8, 0, 0)
	info_label.shaded = false
	add_child(info_label)
	# selection ring
	ring = MeshInstance3D.new()
	var tm := TorusMesh.new(); tm.inner_radius = 9.2; tm.outer_radius = 9.5
	ring.mesh = tm
	ring.material_override = BCAssets.emissive(Color(1.0, 0.85, 0.35), 3.0)
	ring.scale = Vector3(1.0, 0.15, 0.75)
	ring.position = Vector3(0, -2.8, 0)
	ring.visible = false
	add_child(ring)

func _place(kind: String, nm: String, sx: float, sy: float, sc: float, rot: float, parent: Node3D = null) -> Node3D:
	var n: Node3D
	match kind:
		"n": n = BCAssets.nature(nm)
		"p": n = BCAssets.prop(nm)
		_: n = BCAssets.building(nm, race.bcolor)
	n.position = to_local_pos(Vector2(sx, sy))
	n.rotation_degrees.y = rot
	n.scale = Vector3.ONE * sc
	(parent if parent != null else props_root).add_child(n)
	return n

func _build_settlement() -> void:
	props_root = Node3D.new(); props_root.name = "Settlement"; add_child(props_root)
	# production sites (stand-in front of each building so workers never clip into it)
	_place("b", "building_grain", 30, 92, 1.4, 0)
	_place("b", "building_grain", 50, 98, 1.4, 0)
	_place("b", "building_windmill", 20, 78, 1.35, 0)
	_place("b", "building_lumbermill", 40, 28, 1.4, 0)
	_place("n", "trees_A_large", 62, 24, 1.3, 0)
	_place("b", "building_mine", 162, 30, 1.45, 0)
	_place("n", "rock_single_A", 182, 54, 1.4, 0)
	_place("b", "building_blacksmith", 152, 78, 1.45, 0)
	_place("p", "crate_A_big", 172, 90, 1.5, 30)
	_place("b", "building_church", 100, 22, 1.45, 0)
	_place("b", "building_market", 100, 76, 1.5, 0)
	_place("b", "building_barracks", 80, 48, 1.4, 0)
	_place("p", "flag_" + _flag_color(), 118, 52, 1.7, 0)
	for d in DECOR.get(race.decor, []):
		_place(d[0], d[1], d[2], d[3], d[4], d[5])
	# houses are built progressively as the civ grows
	for i in 9:
		var h := sim.house_xy(i)
		var n := _place("b", "building_home_A" if i % 2 == 0 else "building_home_B", h.x, h.y - 14.0, 1.5, 0)
		n.visible = false
		house_nodes.append(n)
	# upgrades unlocked with tech
	var up := {
		"tower_l": ["b", "building_tower_A", 8, 8, 1.5, 0, 2],
		"tower_r": ["b", "building_tower_B", 192, 8, 1.5, 0, 3],
		"castle": ["b", "building_castle", 100, 4, 1.35, 0, 5],
		"wall_l": ["b", "building_tower_base", 60, 8, 1.4, 0, 4],
		"wall_r": ["b", "building_tower_base", 140, 8, 1.4, 0, 4],
	}
	for k in up:
		var u: Array = up[k]
		var n := _place(u[0], u[1], u[2], u[3], u[4], u[5])
		n.visible = false
		tech_nodes[k] = [n, u[6]]

func _flag_color() -> String:
	return {"blue": "blue", "green": "green", "red": "red", "yellow": "yellow"}.get(race.bcolor, "red")

func _build_sealed() -> void:
	var fog := BCAssets.box(Vector3(HALF_X * 2 - 0.2, H - 0.4, HALF_Z * 2 - 0.2), BCAssets.glass(Color(0.1, 0.1, 0.2, 0.82)), Vector3(0, H / 2, 0))
	fog.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(fog)
	var a := BCActor.new()
	add_child(a)
	a.setup(race)
	a.position = Vector3(0, 0.1, 0)
	a.scale = Vector3.ONE * 5.5
	a.set_speed(0.25)
	for mi in a.model.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = BCAssets.emissive(Color(0.02, 0.02, 0.05), 0.0)
	var chain_mat := BCAssets.pbr("metal_plate", Vector3(0.3, 0.3, 0.3))
	for s in [-1, 1]:
		var c := BCAssets.box(Vector3(HALF_X * 2.6, 0.35, 0.35), chain_mat, Vector3(0, H / 2, HALF_Z + 0.4))
		c.rotation_degrees.z = s * 22.0
		add_child(c)
	var seal := Label3D.new()
	seal.text = "SEALED"
	seal.font_size = 150; seal.pixel_size = 0.02
	seal.modulate = Color(1.0, 0.3, 0.25)
	seal.outline_size = 26
	seal.shaded = false
	seal.position = Vector3(0, H / 2 + 0.6, HALF_Z + 0.9)
	add_child(seal)

func _build_light_and_fx() -> void:
	light = OmniLight3D.new()
	light.position = Vector3(0, H - 0.6, 0)
	light.omni_range = 16.0
	light.light_color = race.color.lerp(Color.WHITE, 0.45)
	light.light_energy = 1.2
	light.shadow_enabled = false
	add_child(light)
	sparks = CPUParticles3D.new()
	sparks.emitting = false
	sparks.one_shot = true
	sparks.amount = 70
	sparks.lifetime = 1.4
	sparks.explosiveness = 0.9
	sparks.direction = Vector3.UP
	sparks.spread = 70.0
	sparks.initial_velocity_min = 3.0
	sparks.initial_velocity_max = 7.5
	sparks.gravity = Vector3(0, -7, 0)
	var sm := SphereMesh.new(); sm.radius = 0.09; sm.height = 0.18
	sparks.mesh = sm
	sparks.position = Vector3(0, 1.0, 0)
	add_child(sparks)

# ---------------------------------------------------------------- per-frame
func update_visuals(dt: float, time_now: float) -> void:
	var locked := sim.locked
	# lid & bolts
	var target_open := 0.0 if locked else 1.0
	if selected and not locked: target_open = 1.0
	lid_open = move_toward(lid_open, target_open, dt * 0.6)
	var eased := lid_open * lid_open * (3.0 - 2.0 * lid_open)
	lid_pivot.scale.z = lerpf(1.0, 0.04, eased)
	for b in bolts:
		var side := 1.0 if b.position.x > 0 else -1.0
		b.position.x = side * lerpf(HALF_X - 0.8, HALF_X + 0.1, 1.0 - eased)
	if led_mat != null:
		var c: Color = Color(1.0, 0.25, 0.2) if (locked and lid_open < 0.9) else race.color
		led_mat.albedo_color = led_mat.albedo_color.lerp(c, minf(1.0, dt * 4.0))
		led_mat.emission = led_mat.albedo_color
	if lock_mat != null:
		var lc := Color(1.0, 0.18, 0.12) if lid_open < 0.5 else Color(0.2, 1.0, 0.45)
		lock_mat.albedo_color = lc; lock_mat.emission = lc
	if sealed:
		return
	var civ: BCSim.Civ = sim.civs[idx]
	# interior light: brighter and warmer at night
	var le := 0.4
	if locked: le = 1.7 + 0.2 * sin(time_now * 1.7 + idx)
	var lc2: Color = race.color.lerp(Color(1.0, 0.82, 0.55), 0.55) if locked else race.color.lerp(Color.WHITE, 0.55)
	light.light_energy = lerpf(light.light_energy, le, minf(1.0, dt * 3.0))
	light.light_color = light.light_color.lerp(lc2, minf(1.0, dt * 3.0))
	# houses and tech upgrades
	for i in house_nodes.size():
		var want: bool = i < civ.houses
		if house_nodes[i].visible != want:
			house_nodes[i].visible = want
	for k in tech_nodes:
		var e: Array = tech_nodes[k]
		var want2: bool = civ.tech >= e[1]
		if e[0].visible != want2: e[0].visible = want2
	# flashes (battle / trade / spy)
	if civ.flash_t > prev_flash_t + 0.01 and civ.flash != "":
		_start_fx(civ.flash)
	prev_flash_t = civ.flash_t
	if fx_flash > 0.0:
		fx_flash -= dt
		var pulse := 0.5 + 0.5 * sin(time_now * 22.0)
		match fx_kind:
			"battle":
				light.light_color = Color(1.0, 0.25, 0.15)
				light.light_energy += 4.0 * pulse
				shake = 0.06 * pulse
			"spy":
				light.light_color = Color(0.75, 0.25, 1.0); light.light_energy += 2.5 * pulse
			"trade":
				light.light_color = Color(1.0, 0.85, 0.3); light.light_energy += 2.0 * pulse
	else:
		shake = 0.0
	if info_label != null:
		var war := " | AT WAR" if civ.war.size() > 0 else ""
		info_label.text = "%s  pop %d%s" % [race.name, civ.citizens.size(), war]
		info_label.modulate = Color(1.0, 0.5, 0.45) if civ.war.size() > 0 else Color(0.85, 0.82, 0.74)
	ring.visible = selected or hovered
	ring.material_override.albedo_color = Color(1.0, 0.85, 0.35) if selected else Color(1, 1, 1)
	ring.material_override.emission = ring.material_override.albedo_color
	if battle_mode or not civ.alive:
		actor_root.visible = false
		if not civ.alive: _mark_annexed()
		return
	actor_root.visible = true
	_sync_actors(dt, civ)

func _start_fx(kind: String) -> void:
	fx_kind = kind
	fx_flash = 2.2 if kind != "battle" else 3.5
	var col: Color = {"battle": Color(1.0, 0.35, 0.2), "spy": Color(0.8, 0.35, 1.0), "trade": Color(1.0, 0.85, 0.3)}.get(kind, Color.WHITE)
	var mat := BCAssets.emissive(col, 4.0)
	sparks.mesh.surface_set_material(0, mat)
	sparks.restart()
	sparks.emitting = true
	if kind == "battle":
		for id in actors:
			var a: BCActor = actors[id]
			if a.get_meta("role", "") == "soldier" and randf() < 0.9:
				a.play_once("fight", 3.0)

func _sync_actors(dt: float, civ: BCSim.Civ) -> void:
	# who is physically inside this jar right now
	var present: Array = []
	for c in sim.civs:
		for cit in c.citizens:
			if cit.loc == idx and not cit.hidden:
				present.append(cit)
	present.sort_custom(func(a, b): return a.id < b.id)
	if present.size() > MAX_ACTORS: present.resize(MAX_ACTORS)
	var keep := {}
	for cit in present: keep[cit.id] = true
	for id in actors.keys():
		if not keep.has(id):
			(actors[id] as Node).queue_free()
			actors.erase(id)
	pending_actor_budget = 2
	for cit in present:
		var a: BCActor
		if actors.has(cit.id):
			a = actors[cit.id]
		else:
			if pending_actor_budget <= 0: continue
			pending_actor_budget -= 1
			a = _make_actor(cit)
			actors[cit.id] = a
		_drive_actor(a, cit, dt)

func _make_actor(cit: BCSim.Citizen) -> BCActor:
	var a := BCActor.new()
	actor_root.add_child(a)
	a.setup(BCData.RACES[sim.dominant(cit)])
	a.position = to_local_pos(cit.pos)
	if sim.is_hybrid(cit):
		var keys := cit.blood.keys()
		keys.sort_custom(func(x, y): return cit.blood[x] > cit.blood[y])
		for i in mini(3, keys.size()):
			var m := MeshInstance3D.new()
			var s := SphereMesh.new(); s.radius = 0.07; s.height = 0.14
			m.mesh = s
			m.material_override = BCAssets.emissive(BCData.RACES[keys[i]].color, 3.5)
			m.position = Vector3((float(i) - 1.0) * 0.17, 1.12, 0)
			a.add_child(m)
	return a

func _drive_actor(a: BCActor, cit: BCSim.Citizen, dt: float) -> void:
	var tgt := to_local_pos(cit.pos)
	var d := tgt - a.position
	var moving := cit.state == "walk" or cit.state == "gohome"
	a.position = a.position.lerp(tgt, minf(1.0, dt * 10.0))
	if Vector2(d.x, d.z).length() > 0.02:
		var want := atan2(d.x, d.z)
		a.rotation.y = lerp_angle(a.rotation.y, want, minf(1.0, dt * 9.0))
	var s := 0.72 if cit.age < 2.0 else 1.0
	a.scale = a.scale.lerp(Vector3.ONE * s, minf(1.0, dt * 4.0))
	a.set_meta("role", cit.role)
	if a.is_locked(): return
	var visitor := cit.loc != cit.home
	if moving:
		a.play("walk")
	else:
		match cit.role:
			"farm": a.play("pick")
			"wood", "mine", "craft": a.play("work")
			"study", "trade": a.play("talk")
			"soldier": a.play("idle2")
			_: a.play("idle")
		if visitor and sim.locked: a.play("talk")

func _mark_annexed() -> void:
	if dead_civ: return
	dead_civ = true
	for id in actors.keys():
		(actors[id] as Node).queue_free()
	actors.clear()
	plaque.text = race.jar.to_upper() + " (ANNEXED)"
	plaque.modulate = Color(0.55, 0.55, 0.6)
	led_mat.albedo_color = Color(0.3, 0.3, 0.35)
