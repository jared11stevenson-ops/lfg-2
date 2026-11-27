class_name Player
extends Actor
## You. Your body is whatever your genome expresses.

var world: Node3D                 # InstarWorld
var genome: Genome
var stats: Dictionary
var abilities: Array = []
var cooldowns: Dictionary = {}
var stamina := 100.0
var max_stamina := 100.0
var hunger := 100.0
var stress := 0.0
var move_input := Vector2.ZERO    # set by touch controls (keyboard read here)
var facing := Vector3(0, 0, -1)
var attack_cd := 0.0
var dash_time := 0.0
var dash_vel := Vector3.ZERO
var regen_acc := 0.0

func setup(w: Node3D, g: Genome) -> void:
	world = w
	genome = g
	stats = g.stats()
	abilities = g.abilities().slice(0, 3)
	max_hp = stats.hp
	hp = max_hp
	armor = stats.armor
	move_speed = stats.speed
	max_stamina = stats.stamina
	stamina = max_stamina
	team = "player"
	collision_layer = 2
	collision_mask = 1
	add_to_group("player")
	var cs := CollisionShape3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = 0.5
	sh.height = 1.4
	cs.shape = sh
	cs.position.y = 0.7
	add_child(cs)
	visual = InsectMesh.build(InsectMesh.profile_from_genome(g))
	add_child(visual)

func ability_ready(id: String) -> bool:
	return cooldowns.get(id, 0.0) <= 0.0

func _on_hurt(dealt: float, _src: Node) -> void:
	stress = clampf(stress + dealt / maxf(1.0, max_hp) * 1.4, 0.0, 1.0)
	Lineage.run["damage_taken"] = float(Lineage.run.get("damage_taken", 0.0)) + dealt

func _physics_process(delta: float) -> void:
	if hp <= 0.0:
		return
	_tick_status(delta)
	attack_cd = maxf(0.0, attack_cd - delta)
	for k in cooldowns.keys():
		cooldowns[k] = maxf(0.0, cooldowns[k] - delta)
	stamina = minf(max_stamina, stamina + 12.0 * delta)
	stress = maxf(0.0, stress - 0.012 * delta)
	if stats.regen > 0.0:
		heal(stats.regen * delta)
	hunger = maxf(0.0, hunger - 0.17 * delta)
	if hunger <= 0.0:
		regen_acc += delta
		if regen_acc >= 1.0:
			regen_acc = 0.0
			take_damage(3.0)
	Lineage.run["stress"] = maxf(float(Lineage.run.get("stress", 0.0)), stress)

	var dir := move_input
	var kb := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if kb.length() > 0.1:
		dir = kb
	var wish := Vector3(dir.x, 0, dir.y)
	if dash_time > 0.0:
		dash_time -= delta
		velocity.x = dash_vel.x
		velocity.z = dash_vel.z
	elif root_time > 0.0:
		velocity.x = 0.0
		velocity.z = 0.0
	else:
		velocity.x = wish.x * move_speed
		velocity.z = wish.z * move_speed
	if wish.length() > 0.1:
		facing = wish.normalized()
		visual.rotation.y = lerp_angle(visual.rotation.y, atan2(-facing.x, -facing.z), 0.25)
	velocity.y = 0.0 if is_on_floor() else velocity.y - 20.0 * delta
	move_and_slide()
	global_position.y = maxf(global_position.y, 0.0)
	if Input.is_action_just_pressed("attack"):
		attack()
	for i in abilities.size():
		if Input.is_action_just_pressed("ability_%d" % (i + 1)):
			use_ability(abilities[i])
	# gait: legs drum while moving
	if visual and wish.length() > 0.1:
		visual.position.y = absf(sin(Time.get_ticks_msec() * 0.018)) * 0.06

# ---------------------------------------------------------------- combat
func enemies_in_cone(range_m: float, min_dot: float) -> Array:
	var out: Array = []
	for c in get_tree().get_nodes_in_group("creature"):
		if not is_instance_valid(c) or c.hp <= 0.0 or c.team == "player" or c.team == "echo_kin":
			continue
		var to: Vector3 = c.global_position - global_position
		to.y = 0.0
		var d := to.length()
		if d <= range_m + c.radius_m() and (d < 0.3 or to.normalized().dot(facing) >= min_dot):
			out.append(c)
	return out

func attack() -> void:
	if attack_cd > 0.0 or stamina < 6.0:
		return
	attack_cd = 0.42
	stamina -= 6.0
	for c in enemies_in_cone(2.4, 0.15):
		c.take_damage(stats.damage, self)
	if world:
		world.fx_slash(global_position + facing * 1.2)

func use_ability(id: String) -> void:
	var info: Dictionary = GeneDB.ABILITY_INFO[id]
	if not ability_ready(id) or stamina < info.cost:
		return
	stamina -= info.cost
	cooldowns[id] = info.cd
	match id:
		"acid_spit":
			var p := Projectile.new()
			p.damage = stats.damage * 1.5
			p.owner_team = "player"
			p.source = self
			p.velocity = facing * 16.0
			world.add_child(p)
			p.global_position = global_position + Vector3(0, 0.8, 0) + facing * 0.9
		"scent_burst":
			world.emit_scent(true)
		"regen_pulse":
			heal(max_hp * 0.35)
			world.fx_ring(global_position, 3.0, Color(0.2, 0.9, 0.5))
		"sting_lunge":
			dash_vel = facing * 14.0
			dash_time = 0.2
			for c in enemies_in_cone(4.2, 0.3):
				c.take_damage(stats.damage * 2.0, self)
		"bombard":
			world.fx_ring(global_position, 5.0, Color(1.0, 0.5, 0.1))
			for c in get_tree().get_nodes_in_group("creature"):
				if c.team != "player" and c.team != "echo_kin" and flat_dist(c) <= 5.0 + c.radius_m():
					c.take_damage(stats.damage * 2.4, self)
		"web_snare":
			world.fx_ring(global_position, 4.0, Color(0.95, 0.95, 0.9))
			for c in get_tree().get_nodes_in_group("creature"):
				if c.team != "player" and c.team != "echo_kin" and flat_dist(c) <= 4.0 + c.radius_m():
					c.root_time = 3.0
		"glow_lure":
			world.set_lure(global_position + facing * 6.0, 8.0)
		"carapace":
			invuln = 2.0
			world.fx_ring(global_position, 1.8, Color(0.3, 0.5, 1.0))
		"wing_dash":
			dash_vel = facing * 16.0
			dash_time = 0.2
			invuln = 0.35

func eat(amount: float) -> void:
	hunger = minf(100.0, hunger + amount)
