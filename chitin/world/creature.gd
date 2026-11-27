class_name Creature
extends Actor
## One AI body for wildlife, hive drones, the Regent and Echoes. Behaviour is
## decided by role; allegiance is changed by SCENT (recruit / calm / enrage /
## flee) rather than by dialogue menus.

enum State { WANDER, CHASE, FLEE, CALM, ALLY, WINDUP }

var species_id := ""
var sp: Dictionary = {}
var world: Node3D
var state := State.WANDER
var target: Actor
var home := Vector3.ZERO
var wander_to := Vector3.ZERO
var state_time := 0.0
var attack_cd := 0.0
var scan_cd := 0.0
var last_source: Node
var damage := 5.0
var is_echo := false
var echo_data: Dictionary = {}
var echo_alleles: Array = []        # drops for revenants
var slam_cd := 5.0
var windup := 0.0
var enraged := false
var _r := 0.6

func radius_m() -> float:
	return _r

func setup_species(w: Node3D, id: String, pos: Vector3) -> void:
	world = w
	species_id = id
	sp = SpeciesDB.get_species(id)
	max_hp = sp.hp
	hp = max_hp
	damage = sp.damage
	move_speed = sp.speed
	team = "wild"
	home = pos
	global_position = pos
	_r = 0.55 * sp.scale
	visual = InsectMesh.build(InsectMesh.profile_from_species(id))
	_finish()

func setup_echo(w: Node3D, e: Dictionary, pos: Vector3) -> void:
	world = w
	is_echo = true
	echo_data = e
	species_id = "echo"
	var g := Echo.genome_of(e)
	var st := g.stats()
	sp = {"name": "Echo " + String(e.name), "role": "hunter", "sense": 16.0, "scale": 1.0,
		"want": Vector4(0.0, 0.6, 0.2, 0.5), "recruitable": false, "fearable": false, "bile": 25}
	max_hp = st.hp * 0.8
	hp = max_hp
	damage = st.damage
	move_speed = minf(st.speed, 5.2)
	armor = st.armor
	home = pos
	global_position = pos
	_r = 0.55
	var kin := Echo.disposition(e) == "kin"
	team = "echo_kin" if kin else "wild"
	state = State.ALLY if kin else State.WANDER
	visual = InsectMesh.build(InsectMesh.profile_from_genome(g))
	for s in 6:
		var a: Dictionary = g.express(s)
		if a.id != GeneDB.baseline(s):
			echo_alleles.append(a)
	_finish()

func _finish() -> void:
	collision_layer = 2
	collision_mask = 1
	add_to_group("creature")
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = _r
	sh.height = maxf(1.2 * float(sp.get("scale", 1.0)), _r * 2.2)
	cs.shape = sh
	cs.position.y = sh.height * 0.5
	add_child(cs)
	add_child(visual)
	wander_to = home
	if is_echo and team == "echo_kin":
		var tint := MeshInstance3D.new()
		var ring := TorusMesh.new()
		ring.inner_radius = 0.7
		ring.outer_radius = 0.85
		tint.mesh = ring
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(0.3, 1.0, 0.8)
		m.emission_enabled = true
		m.emission = Color(0.3, 1.0, 0.8)
		m.emission_energy_multiplier = 2.0
		tint.material_override = m
		tint.position.y = 0.05
		add_child(tint)

func is_hostile_to_player() -> bool:
	return team == "wild"

func _on_hurt(_dealt: float, source: Node) -> void:
	last_source = source
	if team == "wild" and source is Actor and sp.get("role", "") != "prey":
		target = source
		state = State.CHASE
	elif team == "wild" and sp.get("role", "") == "prey" and source is Actor:
		if species_id == "rust_beetle":
			target = source
			state = State.CHASE
			enraged = true
		else:
			state = State.FLEE
			state_time = 4.0
			target = source

## Called by the world when the player (or Scent Burst) emits a chord nearby.
func hear(chord: Vector4, power: float, src: Actor) -> int:
	if is_echo and team == "echo_kin":
		return Scent.Outcome.CALM
	var res := Scent.parley(sp, chord, power)
	match res.outcome:
		Scent.Outcome.RECRUIT:
			team = "echo_kin"
			state = State.ALLY
			target = null
			_tint_ally()
		Scent.Outcome.CALM:
			state = State.CALM
			state_time = 14.0
			target = null
		Scent.Outcome.FLEE:
			state = State.FLEE
			state_time = 6.0
			target = src
		Scent.Outcome.ENRAGE:
			if team == "wild":
				state = State.CHASE
				target = src
				enraged = true
	return res.outcome

func _tint_ally() -> void:
	var tint := MeshInstance3D.new()
	var ring := TorusMesh.new()
	ring.inner_radius = 0.6
	ring.outer_radius = 0.75
	tint.mesh = ring
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.3, 1.0, 0.8)
	m.emission_enabled = true
	m.emission = Color(0.3, 1.0, 0.8)
	m.emission_energy_multiplier = 2.0
	tint.material_override = m
	tint.position.y = 0.05
	tint.scale = Vector3.ONE * float(sp.get("scale", 1.0))
	add_child(tint)

func _physics_process(delta: float) -> void:
	if hp <= 0.0 or world == null:
		return
	_tick_status(delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	scan_cd -= delta
	state_time -= delta
	var want := Vector3.ZERO
	var speed := move_speed
	if windup > 0.0:
		windup -= delta
		if windup <= 0.0:
			_slam()
	elif root_time > 0.0:
		pass
	else:
		match state:
			State.WANDER: want = _wander(delta); speed *= 0.5
			State.CHASE: want = _chase()
			State.FLEE: want = _flee()
			State.CALM:
				if state_time <= 0.0:
					state = State.WANDER
			State.ALLY: want = _ally()
		if scan_cd <= 0.0:
			scan_cd = 0.25
			_scan()
	velocity.x = want.x * speed
	velocity.z = want.z * speed
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	global_position.y = maxf(global_position.y, 0.0)
	if want.length() > 0.1:
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-want.x, -want.z), 0.2)

func _wander(delta: float) -> Vector3:
	if flat_to(wander_to) < 1.0 or state_time <= -3.0:
		state_time = 0.0
		var a := randf() * TAU
		wander_to = home + Vector3(cos(a), 0, sin(a)) * randf_range(2.0, 7.0)
	# lures draw wildlife (not drones, not the Regent)
	if world.lure_time > 0.0 and sp.get("role", "") in ["prey", "pack", "hunter", "ambush"]:
		wander_to = world.lure_pos
	var d := wander_to - global_position
	d.y = 0.0
	return d.normalized() if d.length() > 0.5 else Vector3.ZERO

func flat_to(p: Vector3) -> float:
	var d := p - global_position
	d.y = 0.0
	return d.length()

func _chase() -> Vector3:
	if not is_instance_valid(target) or target.hp <= 0.0:
		target = null
		state = State.ALLY if team == "echo_kin" else State.WANDER
		return Vector3.ZERO
	var to := target.global_position - global_position
	to.y = 0.0
	var d := to.length()
	var reach := 1.5 * maxf(1.0, float(sp.get("scale", 1.0)) * 0.7) + target.radius_m_safe()
	if sp.get("role", "") == "regent" and d < 7.0 and slam_cd <= 0.0 and windup <= 0.0:
		windup = 1.1
		slam_cd = 6.0
		world.fx_ring(global_position, 6.0, Color(1.0, 0.2, 0.3), 1.1)
		return Vector3.ZERO
	slam_cd -= get_physics_process_delta_time()
	if d <= reach:
		if attack_cd <= 0.0:
			attack_cd = 0.9 if sp.get("role", "") != "ambush" else 0.6
			target.take_damage(damage, self)
		return Vector3.ZERO
	if team == "wild" and d > float(sp.get("sense", 10.0)) * 2.2 and not enraged:
		state = State.WANDER
		target = null
	return to.normalized()

func _slam() -> void:
	for a in get_tree().get_nodes_in_group("player") + get_tree().get_nodes_in_group("creature"):
		if a == self or not (a is Actor):
			continue
		var friendly: bool = (team == "wild") == (a.team == "wild")
		if not friendly and flat_dist(a) <= 6.0:
			a.take_damage(damage * 1.6, self)

func _flee() -> Vector3:
	if state_time <= 0.0:
		state = State.WANDER
		return Vector3.ZERO
	if not is_instance_valid(target):
		return Vector3.ZERO
	var away := global_position - target.global_position
	away.y = 0.0
	return away.normalized()

func _ally() -> Vector3:
	var p: Actor = world.player
	if not is_instance_valid(p) or p.hp <= 0.0:
		return Vector3.ZERO
	var best: Actor = null
	var best_d := 9.0
	for c in get_tree().get_nodes_in_group("creature"):
		if c != self and is_instance_valid(c) and c.team == "wild" and c.hp > 0.0:
			var d := flat_dist(c)
			if d < best_d:
				best_d = d
				best = c
	if best != null:
		target = best
		return _chase_target(best)
	var to := p.global_position - global_position
	to.y = 0.0
	return to.normalized() if to.length() > 3.5 else Vector3.ZERO

func _chase_target(t: Actor) -> Vector3:
	var to := t.global_position - global_position
	to.y = 0.0
	if to.length() <= 1.6 + t.radius_m_safe():
		if attack_cd <= 0.0:
			attack_cd = 0.9
			t.take_damage(damage, self)
		return Vector3.ZERO
	return to.normalized()

func _scan() -> void:
	if team != "wild" or state == State.CHASE or state == State.FLEE or state == State.CALM:
		return
	var role: String = sp.get("role", "prey")
	var p: Actor = world.player
	var sense: float = float(sp.get("sense", 10.0))
	var stealth: float = p.stats.stealth if is_instance_valid(p) else 0.0
	var seen_range := sense * (1.0 - stealth)
	# wild creatures also fight the player's allies
	var best: Actor = null
	var best_d := 1e9
	if is_instance_valid(p) and p.hp > 0.0:
		var dp := flat_dist(p)
		if dp <= seen_range:
			best = p
			best_d = dp
	for c in get_tree().get_nodes_in_group("creature"):
		if c != self and is_instance_valid(c) and c.team == "echo_kin" and c.hp > 0.0:
			var d := flat_dist(c)
			if d < seen_range * 0.7 and d < best_d:
				best = c
				best_d = d
	if best == null:
		return
	match role:
		"prey":
			if best_d < seen_range * 0.6:
				state = State.FLEE
				state_time = 3.0
				target = best
		"ambush":
			if best_d < 6.0:
				state = State.CHASE
				target = best
		_:
			state = State.CHASE
			target = best

func die_drop() -> Array:
	var alleles: Array = []
	if is_echo:
		for a in echo_alleles:
			alleles.append(a)
		return alleles
	var rng: RandomNumberGenerator = world.rng
	var n := 3 if sp.get("elite", false) else (1 if rng.randf() < 0.6 else 0)
	for i in n:
		alleles.append(Genome.make_allele(SpeciesDB.roll_gene(species_id, rng), 1 if sp.get("elite", false) and i == 0 else 0))
	return alleles
