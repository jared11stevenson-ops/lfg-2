class_name InstarWorld
extends Node3D
## One life, in one ruined district. Builds the whole 3D scene from data.

signal finished(cause: String)

var rng := RandomNumberGenerator.new()
var district: Dictionary
var player: Player
var cam: Camera3D
var hud                       # Hud
var lure_pos := Vector3.ZERO
var lure_time := 0.0
var chord := Vector4(0.5, 0.5, 0.5, 0.5)
var near_chrysalis := false
var chrysalis_pos := Vector3.ZERO
var tide_cd := 12.0
var tide_on := false
var ended := false
var _message_time := 0.0
var _boss_seen := false

func _ready() -> void:
	rng.seed = Lineage.district_seed * 31 + Lineage.generation
	district = DistrictGen.generate(Lineage.district_seed)
	Lineage.start_instar()
	_build_environment()
	_build_ground()
	_build_ruins()
	_build_chrysalis()
	_spawn_player()
	_spawn_wildlife()
	_spawn_echoes()
	_build_spores()
	cam = Camera3D.new()
	cam.fov = 50.0
	add_child(cam)
	cam.global_position = player.global_position + Vector3(0, 13, 8)
	cam.look_at(player.global_position)
	var Hud_script = load("res://ui/hud.gd")
	hud = Hud_script.new()
	add_child(hud)
	hud.bind(self)
	hud.toast("Generation %d  -  find prey, taste its genes, return to the chrysalis." % Lineage.generation)

func _process(delta: float) -> void:
	if ended:
		return
	Lineage.run["time"] = float(Lineage.run.time) + delta
	lure_time = maxf(0.0, lure_time - delta)
	if is_instance_valid(player):
		var target_pos := player.global_position + Vector3(0, 13, 8)
		cam.global_position = cam.global_position.lerp(target_pos, clampf(delta * 5.0, 0, 1))
		cam.look_at(player.global_position + Vector3(0, 0.5, 0), Vector3.UP)
		near_chrysalis = Vector2(player.global_position.x, player.global_position.z).distance_to(Vector2(chrysalis_pos.x, chrysalis_pos.z)) < 4.0
		if Input.is_action_just_pressed("molt") and near_chrysalis:
			finish("molted")
		Lineage.ecology.deposit(player.global_position.x, player.global_position.z, chord, 0.02 * delta)
	# The Tide: late in the life a roach swarm hunts you.
	var t: float = Lineage.run.time
	if t > Lineage.INSTAR_SECONDS * 0.7:
		if not tide_on:
			tide_on = true
			hud.toast("THE TIDE RISES - the swarm hunts you. Molt now.")
		tide_cd -= delta
		if tide_cd <= 0.0:
			tide_cd = 11.0
			_spawn_tide()
	if t > Lineage.INSTAR_SECONDS * 0.4 and not _boss_seen:
		_boss_seen = true
		hud.toast("The Cathedral Regent stirs in the north.")
	if player.hp <= 0.0 and not ended:
		finish("died")

func finish(cause: String) -> void:
	if ended:
		return
	ended = true
	finished.emit(cause)

# ------------------------------------------------------------------- build
func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.03, 0.04, 0.05)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.5, 0.6, 0.65)
	env.ambient_light_energy = 1.3
	env.fog_enabled = true
	env.fog_light_color = Color(0.12, 0.18, 0.16)
	env.fog_density = 0.008
	env.glow_enabled = true
	env.glow_intensity = 0.8
	env.glow_bloom = 0.1
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)
	var sun := DirectionalLight3D.new()
	sun.light_color = Color(0.55, 0.65, 0.8)
	sun.light_energy = 1.5
	sun.rotation_degrees = Vector3(-55, 35, 0)
	add_child(sun)

func _static_box(pos: Vector3, size: Vector3, mat: Material, visible_mesh: bool = true) -> StaticBody3D:
	var sb := StaticBody3D.new()
	sb.collision_layer = 1
	sb.collision_mask = 0
	var cs := CollisionShape3D.new()
	var shape := BoxShape3D.new()
	shape.size = size
	cs.shape = shape
	sb.add_child(cs)
	if visible_mesh:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = size
		mi.mesh = bm
		mi.material_override = mat
		sb.add_child(mi)
	sb.position = pos
	add_child(sb)
	return sb

func _build_ground() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.24, 0.27, 0.23)
	m.roughness = 0.9
	var H := DistrictGen.HALF
	_static_box(Vector3(0, -0.5, 0), Vector3(H * 2 + 4, 1, H * 2 + 4), m)
	for w in [[Vector3(0, 3, -H - 1), Vector3(H * 2 + 4, 6, 2)], [Vector3(0, 3, H + 1), Vector3(H * 2 + 4, 6, 2)],
			[Vector3(-H - 1, 3, 0), Vector3(2, 6, H * 2 + 4)], [Vector3(H + 1, 3, 0), Vector3(2, 6, H * 2 + 4)]]:
		_static_box(w[0], w[1], m, false)

func _build_ruins() -> void:
	var mats: Array = []
	for c in [Color(0.36, 0.33, 0.3), Color(0.3, 0.33, 0.38), Color(0.4, 0.32, 0.26)]:
		var m := StandardMaterial3D.new()
		m.albedo_color = c
		m.roughness = 0.85
		mats.append(m)
	var glow_mat := StandardMaterial3D.new()
	glow_mat.albedo_color = Color(0.2, 1.0, 0.7)
	glow_mat.emission_enabled = true
	glow_mat.emission = Color(0.2, 1.0, 0.7)
	glow_mat.emission_energy_multiplier = 1.6
	var lights := 0
	for i in district.blocks.size():
		var b: Dictionary = district.blocks[i]
		var h: float = b.height
		_static_box(Vector3(b.pos.x, h * 0.5, b.pos.y), Vector3(b.size.x, h, b.size.y), mats[i % 3])
		# bioluminescent fungus band on some towers
		if i % 3 == 0:
			var band := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(b.size.x + 0.12, 0.3, b.size.y + 0.12)
			band.mesh = bm
			band.material_override = glow_mat
			band.position = Vector3(b.pos.x, h * 0.6, b.pos.y)
			add_child(band)
			if lights < 6:
				lights += 1
				var l := OmniLight3D.new()
				l.light_color = Color(0.3, 1.0, 0.75)
				l.light_energy = 1.2
				l.omni_range = 11.0
				l.position = Vector3(b.pos.x, h * 0.6 + 1.0, b.pos.y)
				add_child(l)

func _build_chrysalis() -> void:
	chrysalis_pos = Vector3(district.chrysalis.x, 0, district.chrysalis.y)
	var n := Node3D.new()
	n.position = chrysalis_pos
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 1.2
	sm.height = 3.2
	mi.mesh = sm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.75, 0.3, 0.8)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.6, 0.15)
	m.emission_energy_multiplier = 2.2
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mi.material_override = m
	mi.position.y = 1.6
	n.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.65, 0.2)
	l.light_energy = 2.0
	l.omni_range = 12.0
	l.position.y = 2.0
	n.add_child(l)
	add_child(n)

func _build_spores() -> void:
	var p := GPUParticles3D.new()
	p.amount = 160
	p.lifetime = 9.0
	p.visibility_aabb = AABB(Vector3(-40, -2, -40), Vector3(80, 20, 80))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(36, 0.5, 36)
	pm.gravity = Vector3(0.1, 0.25, 0.05)
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.6
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 60.0
	p.process_material = pm
	var q := SphereMesh.new()
	q.radius = 0.05
	q.height = 0.1
	q.radial_segments = 4
	q.rings = 2
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.7, 1.0, 0.8)
	sm.emission_enabled = true
	sm.emission = Color(0.6, 1.0, 0.8)
	sm.emission_energy_multiplier = 3.0
	q.material = sm
	p.draw_pass_1 = q
	p.position.y = 0.5
	add_child(p)

func _spawn_player() -> void:
	player = Player.new()
	add_child(player)
	player.setup(self, Lineage.genome)
	player.global_position = Vector3(district.spawn.x, 0.2, district.spawn.y)
	player.died.connect(func(_a): pass)

func _spawn_wildlife() -> void:
	var nest_count := {}
	for n in district.nests:
		nest_count[n.species] = nest_count.get(n.species, 0) + 1
	var total := 0
	for n in district.nests:
		var id: String = n.species
		var pop := Lineage.ecology.population_of(id)
		var per := int(round(float(pop) * 0.3 / nest_count[id]))
		if id == "cathedral_regent":
			per = 1
		per = clampi(per, 1 if pop >= 2 else 0, 5)
		for i in per:
			if total >= 46:
				return
			total += 1
			var off := Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
			spawn_creature(id, Vector3(n.pos.x, 0.2, n.pos.y) + off)

func spawn_creature(id: String, pos: Vector3) -> Creature:
	var c := Creature.new()
	add_child(c)
	c.setup_species(self, id, pos)
	c.died.connect(_on_creature_died)
	return c

func _spawn_echoes() -> void:
	var shown := 0
	for e in Lineage.echoes:
		if shown >= 3:
			break
		shown += 1
		var kin := Echo.disposition(e) == "kin"
		var pos := Vector3(district.spawn.x + rng.randf_range(-4, 4), 0.2, district.spawn.y - 5) if kin \
			else Vector3(district.nests[shown].pos.x, 0.2, district.nests[shown].pos.y)
		var c := Creature.new()
		add_child(c)
		c.setup_echo(self, e, pos)
		c.died.connect(_on_creature_died)

func _spawn_tide() -> void:
	for i in 3:
		var a := rng.randf() * TAU
		var pos := player.global_position + Vector3(cos(a), 0, sin(a)) * 18.0
		pos.x = clampf(pos.x, -DistrictGen.HALF + 2, DistrictGen.HALF - 2)
		pos.z = clampf(pos.z, -DistrictGen.HALF + 2, DistrictGen.HALF - 2)
		var c := spawn_creature("gutter_roach", pos)
		c.target = player
		c.state = Creature.State.CHASE
		c.enraged = true

# ------------------------------------------------------------------ events
func _on_creature_died(a: Actor) -> void:
	var c: Creature = a
	var credited: bool = c.last_source == player or (is_instance_valid(c.last_source) and c.last_source is Creature and c.last_source.team == "echo_kin")
	if credited and c.team == "wild":
		Lineage.run["kills"] = int(Lineage.run.kills) + 1
		Lineage.run["bile"] = int(Lineage.run.bile) + int(c.sp.get("bile", 5))
		if not c.is_echo:
			Lineage.ecology.apply_kill(c.species_id)
		player.eat(14.0)
		hud.toast("+%d bile  (%s)" % [int(c.sp.get("bile", 5)), c.sp.get("name", "?")])
	var drops: Array = c.die_drop() if (credited or c.team == "wild") else []
	var n := 0
	for al in drops:
		_spawn_orb(c.global_position + Vector3(n * 0.8 - 0.4, 0.5, 0), al)
		n += 1
	if c.species_id == "cathedral_regent":
		hud.toast("THE REGENT FALLS. The district exhales.")
		Lineage.run["bile"] = int(Lineage.run.bile) + 40
	c.queue_free()

func _spawn_orb(pos: Vector3, allele: Dictionary) -> void:
	var orb := Area3D.new()
	orb.collision_layer = 0
	orb.collision_mask = 2
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 1.0
	cs.shape = sh
	orb.add_child(cs)
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.25
	sm.height = 0.5
	mi.mesh = sm
	var gcol: Color = GeneDB.get_gene(allele.id).get("color", Color.WHITE).lightened(0.4)
	var mat := StandardMaterial3D.new()
	mat.albedo_color = gcol
	mat.emission_enabled = true
	mat.emission = gcol
	mat.emission_energy_multiplier = 3.0
	mi.material_override = mat
	orb.add_child(mi)
	var l := OmniLight3D.new()
	l.light_color = gcol
	l.omni_range = 4.0
	orb.add_child(l)
	add_child(orb)
	orb.global_position = pos
	orb.body_entered.connect(func(b):
		if b == player and is_instance_valid(orb):
			var base: Dictionary = GeneDB.get_gene(allele.id)
			Lineage.add_latent(allele)
			hud.toast("Tasted: %s%s - latent until your next molt." % [base.name, " +%d" % allele.mut if allele.mut > 0 else ""])
			orb.queue_free())

# -------------------------------------------------------------------- scent
func nearest_creature(radius: float) -> Creature:
	var best: Creature = null
	var bd := radius
	for c in get_tree().get_nodes_in_group("creature"):
		if is_instance_valid(c) and c.hp > 0.0 and c.team == "wild":
			var d := player.flat_dist(c)
			if d < bd:
				bd = d
				best = c
	return best

## Emit the current chord. Normal emission affects the nearest creature in
## range; a Scent Burst (gland ability) affects everything around you.
func emit_scent(burst: bool = false) -> Dictionary:
	var power: float = player.stats.scent
	var radius := 5.0 + power * 3.0
	if burst:
		radius *= 2.0
	var results: Array = []
	var targets: Array = []
	if burst:
		for c in get_tree().get_nodes_in_group("creature"):
			if is_instance_valid(c) and c.hp > 0.0 and c.team == "wild" and player.flat_dist(c) <= radius:
				targets.append(c)
	else:
		var n := nearest_creature(radius)
		if n != null:
			targets.append(n)
	Lineage.ecology.deposit(player.global_position.x, player.global_position.z, chord, 0.6)
	var run_scent: Array = Lineage.run.scent
	for i in 4:
		run_scent[i] = lerpf(run_scent[i], chord[i], 0.2)
	Lineage.run["parleys"] = int(Lineage.run.parleys) + 1
	for c in targets:
		var o: int = c.hear(chord, power, player)
		results.append({"name": c.sp.get("name", "?"), "outcome": o})
		if o == Scent.Outcome.RECRUIT:
			Lineage.run["recruits"] = int(Lineage.run.recruits) + 1
		elif o == Scent.Outcome.CALM:
			Lineage.run["calms"] = int(Lineage.run.calms) + 1
	fx_ring(player.global_position, radius * (0.5 if not burst else 0.4), Color(chord.x, chord.y, chord.w, 1.0))
	if hud:
		if results.is_empty():
			hud.toast("Your scent drifts unanswered.")
		else:
			var bits: Array = []
			for r in results:
				bits.append("%s: %s" % [r.name, Scent.outcome_name(r.outcome)])
			hud.toast("  |  ".join(bits))
	return {"results": results}

func set_lure(pos: Vector3, secs: float) -> void:
	lure_pos = pos
	lure_time = secs
	fx_ring(pos, 2.0, Color(0.3, 0.95, 0.85), secs)

# ---------------------------------------------------------------------- fx
func fx_ring(pos: Vector3, radius: float, color: Color, life: float = 0.5) -> void:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.9
	t.outer_radius = 1.0
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.albedo_color = color
	m.emission_enabled = true
	m.emission = color
	m.emission_energy_multiplier = 2.5
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mi.material_override = m
	mi.position = Vector3(pos.x, 0.15, pos.z)
	mi.scale = Vector3.ONE * 0.2
	add_child(mi)
	var tw := create_tween()
	tw.tween_property(mi, "scale", Vector3(radius, 1.0, radius), life)
	tw.tween_callback(mi.queue_free)

func fx_slash(pos: Vector3) -> void:
	fx_ring(pos, 1.3, Color(1.0, 0.9, 0.7), 0.18)
