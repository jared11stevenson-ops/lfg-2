class_name Critter
extends Node2D
## One living individual. Body, speed, bite, senses all come from its genome via Phenotype.
signal died(c: Critter, killer)
static var next_id := 1
var id := 0
var genome: PackedFloat32Array
var bp := 0
var sp := 0
var sp_name := ""
var ph: Dictionary = {}
var art: CreatureNode
var world: GameWorld
var hp := 10.0; var hp_max := 10.0; var energy := 0.8; var stamina := 1.0
var age_s := 0.0; var life_s := 600.0   # seconds of game time; adulthood at 12%
var vel := Vector2.ZERO
var heading := 0.0
var turn := 0.0
var state := "wander"
var target: Critter = null
var wander_to := Vector2.ZERO
var is_player := false
var bloodline := -1
var gen := 0
var parents := [0, 0]
var cooldown := 0.0; var windup := 0.0; var dodge_t := 0.0; var stun := 0.0; var abil_cd := 0.0
var lunge := 0.0; var hurt := 0.0; var eat_t := 0.0
var flying := false; var burrowed := false; var buff_t := 0.0
var carniv := 0.0; var mass := 0.1
var rng := RandomNumberGenerator.new()
var kills := 0
var weapon: Dictionary = {}   # equipped: {item: Item, reach, power}
var inv: Dictionary = {}      # material -> count
var given_name := ""
var civ_id := -1
var practice: Dictionary = {}   # gene -> accumulated practice (shapes offspring)
var mate_cd := 0.0
var think_t := 0.0
var aggro_to: Critter = null
var aim := 0.0
var use_aim := false

func setup(g: PackedFloat32Array, bp_: int, sp_: int, name_: String, w: GameWorld, age_frac: float = -1.0) -> Critter:
	id = Critter.next_id; Critter.next_id += 1
	genome = g; bp = bp_; sp = sp_; sp_name = name_; world = w
	ph = Phenotype.build(g, bp)
	ph["seed"] = id
	rng.seed = id * 7919 + sp
	carniv = ph["carniv"]; mass = ph["mass"]
	hp_max = ph["hp"]; hp = hp_max
	life_s = 700.0 * ph["lifespan"]
	age_s = life_s * (rng.randf_range(0.15, 0.6) if age_frac < 0.0 else age_frac)
	energy = rng.randf_range(0.5, 0.9)
	art = CreatureNode.new()
	art.ph = ph
	add_child(art)
	heading = rng.randf() * TAU
	wander_to = position
	return self

func display_name() -> String:
	if given_name == "":
		var a := ["Ka", "Ti", "Mo", "Ra", "Su", "Vi", "Ne", "Lo", "Ba", "Ze", "Qu", "Wi"]
		var b := ["r", "n", "l", "x", "s", "m", "th", "k"]
		given_name = a[id % a.size()] + a[(id * 7 + 3) % a.size()].to_lower() + b[(id * 5) % b.size()]
	return given_name

func train(gene: String, amt: float) -> void:
	practice[gene] = minf(float(practice.get(gene, 0.0)) + amt, 0.12)

func carry_cap() -> int:
	return clampi(int(3 + 10.0 * ph["strength"] * (0.5 + ph["dex"]) * (0.6 if ph["flies"] else 1.0)), 2, 24)
func inv_count() -> int:
	var n := 0
	for k in inv: n += inv[k]
	return n

func maturity() -> float: return clampf(age_s / (life_s * 0.12), 0.0, 1.0)
func is_adult() -> bool: return maturity() >= 1.0
func body_scale() -> float: return lerpf(0.55, 1.0, maturity())
func radius() -> float: return ph["L"] * 0.32 * body_scale()
func max_speed() -> float:
	var s: float = ph["speed"] * (0.55 + 0.45 * maturity())
	if flying: s *= 1.5
	elif world.is_water(position):
		s *= 1.25 if ph["swims"] else (0.4 if not flying else 1.0)
	elif ph["bp"] == Genome.BP.FISH: s *= 0.2
	if stun > 0.0: s *= 0.25
	if burrowed: s *= 0.6
	if energy < 0.15: s *= 0.6
	return s
func targetable() -> bool: return not burrowed and dodge_t <= 0.0

# ------------------------------------------------------------------ actions
func start_attack() -> bool:
	if cooldown > 0.0 or windup > 0.0 or stun > 0.0 or flying or stamina < 0.12: return false
	windup = 0.16 if is_player else 0.45
	stamina -= 0.12
	return true

func _do_lunge() -> void:
	lunge = 0.18
	var dir := Vector2.RIGHT.rotated(heading)
	vel += dir * max_speed() * 1.6
	var reach: float = ph["L"] * 0.62 * body_scale() + (weapon.get("reach", 0.0) if not weapon.is_empty() else 0.0)
	var dmg: float = ph["bite"] * 5.0 * (0.5 + 0.5 * maturity()) * (1.0 + (weapon.get("power", 0.0) if not weapon.is_empty() else 0.0))
	if buff_t > 0.0: dmg *= 2.0; buff_t = 0.0
	var hit := false
	for c in world.get_meta("critters") as Array:
		var o: Critter = c
		if o == self or not is_instance_valid(o) or not o.targetable(): continue
		var d := o.position - position
		if d.length() > reach + o.radius(): continue
		if absf(angle_difference(heading, d.angle())) > 1.0: continue
		var was := o.hp
		o.take_hit(dmg, self, dir * 220.0 * (1.0 + ph["strength"] * 0.2))
		hit = true
		if not weapon.is_empty():
			var it: Item = weapon["item"]
			it.wear = minf(it.wear + 0.004, 1.0)
			if o.hp <= 0.0 or o.is_queued_for_deletion():
				it.record_kill(o.sp_name, int(world.sim.tick))
				world.fx_text(o.position, it.display_name() + " claims another", Color(1.0, 0.85, 0.4))
	cooldown = 0.45 if is_player else 1.1 - 0.4 * ph["bite"] / 2.0
	if hit and not weapon.is_empty():
		weapon["hits"] = int(weapon.get("hits", 0)) + 1

func take_hit(dmg: float, from, knock: Vector2) -> void:
	if not targetable(): return
	var armor: float = ph["armor"]
	var d := dmg * (1.0 - 0.6 * armor) * (0.8 if burrowed else 1.0)
	hp -= d; hurt = 1.0
	if world.has_meta("sfx"): (world.get_meta("sfx") as Synth.Bank).play("hit" if d > 2.0 else "bite", 0.7, 1.0 / (0.6 + mass))
	if world.get_meta("show_numbers", true) and (from is Critter and ((from as Critter).is_player or is_player)): world.fx_text(position, str(int(d)), Color(1, 0.9, 0.6) if not is_player else Color(1, 0.4, 0.4))
	vel += knock / maxf(mass * 4.0 + 1.0, 1.0)
	if from is Critter:
		aggro_to = from
		if civ_id >= 0 and (from as Critter).is_player: world.call("civ_provoked", civ_id, self)
		if state != "flee" and carniv < 0.5 and rng.randf() < 0.7: state = "flee"; target = from
	if from is Critter and is_player == false and ph["toxin"] > 0.5 and rng.randf() < 0.5:
		(from as Critter).stun = maxf((from as Critter).stun, 0.8 * ph["toxin"])
	if hp <= 0.0: die(from)

func die(killer) -> void:
	if is_queued_for_deletion(): return
	if killer is Critter: (killer as Critter).kills += 1
	died.emit(self, killer)
	queue_free()

func dodge() -> bool:
	if stamina < 0.25 or dodge_t > 0.0 or stun > 0.0: return false
	stamina -= 0.25; dodge_t = 0.28
	vel = Vector2.RIGHT.rotated(heading if vel.length() < 20.0 else vel.angle()) * max_speed() * 2.4
	return true

## Anatomy-specific special ability (never the same for every body)
func ability_name() -> String:
	if ph["flies"]: return "Take flight"
	if ph["secrete"] > 0.5 and bp == Genome.BP.ARACH: return "Silk shot"
	if bp == Genome.BP.AMPHIB: return "Tongue lash"
	if ph["digs"]: return "Burrow ambush"
	if bp == Genome.BP.FISH: return "Tail burst"
	return "Pounce"

func use_ability() -> bool:
	if abil_cd > 0.0 or stun > 0.0: return false
	var dir := Vector2.RIGHT.rotated(heading)
	match ability_name():
		"Take flight":
			flying = not flying; abil_cd = 0.6; return true
		"Silk shot":
			if stamina < 0.3: return false
			stamina -= 0.3; abil_cd = 3.5
			for c in world.get_meta("critters") as Array:
				var o: Critter = c
				if o == self or not is_instance_valid(o): continue
				var d := o.position - position
				if d.length() < 220.0 and absf(angle_difference(heading, d.angle())) < 0.5:
					o.stun = 2.2; o.hurt = 0.3
			world.call("fx_ring", position + dir * 100.0, Color(0.9, 0.95, 1.0, 0.8), 90.0)
			return true
		"Tongue lash":
			if stamina < 0.3: return false
			stamina -= 0.3; abil_cd = 3.0
			var best: Critter = null; var bd := 260.0
			for c in world.get_meta("critters") as Array:
				var o: Critter = c
				if o == self or not is_instance_valid(o) or not o.targetable(): continue
				var d := o.position - position
				if d.length() < bd and absf(angle_difference(heading, d.angle())) < 0.5 and o.mass < mass * 1.8 + 0.01:
					best = o; bd = d.length()
			if best: best.position = position + dir * (radius() + best.radius() + 4.0); best.take_hit(ph["bite"] * 3.0, self, Vector2.ZERO); best.stun = 0.8
			world.call("fx_ring", position + dir * 120.0, Color(0.9, 0.4, 0.5, 0.8), 70.0)
			return true
		"Burrow ambush":
			if not burrowed:
				burrowed = true; abil_cd = 0.5
			else:
				burrowed = false; buff_t = 3.0; abil_cd = 3.0
			return true
		"Tail burst":
			stamina -= 0.2; abil_cd = 2.5; vel = dir * max_speed() * 3.0; return true
		_:
			if stamina < 0.3: return false
			stamina -= 0.3; abil_cd = 3.0; vel = dir * max_speed() * 3.4; buff_t = 1.2; lunge = 0.25; return true

# ------------------------------------------------------------------ simulation
func _process(dt: float) -> void:
	tick(dt)

func tick(dt: float) -> void:
	age_s += dt
	if age_s > life_s: die(null); return
	cooldown = maxf(cooldown - dt, 0.0); abil_cd = maxf(abil_cd - dt, 0.0); stun = maxf(stun - dt, 0.0)
	dodge_t = maxf(dodge_t - dt, 0.0); hurt = maxf(hurt - dt * 2.0, 0.0); buff_t = maxf(buff_t - dt, 0.0); mate_cd = maxf(mate_cd - dt, 0.0)
	lunge = maxf(lunge - dt, 0.0)
	stamina = minf(stamina + dt * (0.25 if not (flying or burrowed) else 0.05), 1.0)
	if windup > 0.0:
		windup -= dt
		if windup <= 0.0: _do_lunge()
	# metabolism
	var drain: float = ph["upkeep"] * 0.0016 * (2.2 if flying else 1.0) * (1.0 + vel.length() / maxf(ph["speed"], 1.0) * 0.6)
	energy -= drain * dt * 4.0
	if energy <= 0.0:
		energy = 0.0
		hp -= dt * 0.6
		if hp <= 0.0: die(null); return
	elif energy > 0.5 and hp < hp_max:
		hp = minf(hp + dt * 0.25 * ph["hp"] / 30.0, hp_max)
	if not is_player: _think(dt)
	_move(dt)
	# environment hazards
	var wat := world.is_water(position)
	if wat and not ph["swims"] and not flying and world.deep_water(position):
		stamina -= dt * 0.35
		if stamina <= 0.0: hp -= dt * 2.0
	if not wat and bp == Genome.BP.FISH:
		hp -= dt * 1.5
		if hp <= 0.0: die(null)
	# art pose
	var spd := clampf(vel.length() / maxf(ph["speed"], 1.0), 0.0, 1.5)
	art.pose["spd"] = spd
	art.pose["phase"] = art.pose.get("phase", 0.0) + dt * (4.0 + 9.0 * spd) * (1.0 if bp != Genome.BP.FISH else 0.7)
	art.pose["t"] = art.pose.get("t", 0.0) + dt
	art.pose["turn"] = lerpf(art.pose.get("turn", 0.0), clampf(turn, -1.0, 1.0), 0.2)
	art.pose["flying"] = flying
	art.pose["flap"] = 1.0 if flying else 0.0
	art.pose["hurt"] = hurt
	art.pose["atk"] = (1.0 - windup / 0.45) * 0.8 if windup > 0.0 else (lunge / 0.18 if lunge > 0.0 else 0.0)
	art.rotation = heading
	art.scale = Vector2.ONE * body_scale()
	art.modulate = Color(1, 1, 1, 0.35 if burrowed else (0.55 if dodge_t > 0.0 else 1.0))
	art.queue_redraw()
	z_index = 20 if flying else int(position.y / 40.0)

var move_dir := Vector2.ZERO   # desired direction (unit or zero), set by AI / player
func _move(dt: float) -> void:
	var ms := max_speed()
	var want := move_dir * ms
	if stun > 0.0 and not is_player: want = Vector2.ZERO
	vel = vel.lerp(want, clampf(dt * (7.0 if dodge_t <= 0.0 else 1.0), 0.0, 1.0))
	if use_aim:
		heading = lerp_angle(heading, aim, clampf(dt * 14.0, 0.0, 1.0)); turn = 0.0
	elif vel.length() > 8.0 and (windup <= 0.0):
		var ta := vel.angle()
		var d := angle_difference(heading, ta)
		turn = d
		heading += clampf(d, -dt * 9.0, dt * 9.0)
	else:
		turn = 0.0
	var np := position + vel * dt
	var lim := world.world_px() - 20.0
	np = np.clamp(Vector2(20, 20), Vector2(lim, lim))
	# fish cannot leave water
	if bp == Genome.BP.FISH and not world.is_water(np): vel = Vector2.ZERO; np = position
	position = np

func _think(dt: float) -> void:
	think_t -= dt
	if think_t > 0.0 and state != "attack": 
		_act(dt)
		return
	think_t = rng.randf_range(0.15, 0.35)
	var crit: Array = world.get_meta("critters")
	var sight: float = ph["sight"] * 0.8
	var threat: Critter = null; var td := 1e9
	var prey: Critter = null; var pd := 1e9
	for c in crit:
		var o: Critter = c
		if o == self or not is_instance_valid(o) or o.sp == sp or not o.targetable(): continue
		var d := position.distance_to(o.position)
		if d > sight: continue
		var seen: float = d * (1.0 + o.ph["camo"] * 1.2)
		if seen > sight: continue
		if o.carniv > 0.55 and o.mass > mass * 0.4 and o.energy < 0.85 + 0.3 and d < td and (carniv < 0.55 or o.mass > mass * 1.4) : threat = o; td = d
		if carniv > 0.45 and o.carniv < 0.75 and o.mass < mass * 2.2 and o.mass > mass * 0.002 and (energy < 0.7 + 0.28 * carniv) and d < pd: prey = o; pd = d
	if aggro_to and is_instance_valid(aggro_to) and carniv > 0.45 and aggro_to.mass < mass * 3.0:
		prey = aggro_to; pd = position.distance_to(aggro_to.position)
	if threat and (carniv < 0.55 or threat.mass > mass * 1.4):
		state = "flee"; target = threat
	elif prey:
		state = "hunt"; target = prey
	elif state == "flee" or state == "hunt":
		state = "wander"; target = null
	if state == "wander" or state == "graze":
		if energy < 0.55 and carniv < 0.8 and rng.randf() < 0.6: state = "graze"
		elif position.distance_to(wander_to) < 24.0 or rng.randf() < 0.05:
			wander_to = world.random_land_near(position, 260.0, rng, bp == Genome.BP.FISH)
			if civ_id >= 0 and rng.randf() < 0.75:
				var home := world.civ_spot(civ_id, rng)
				if home != Vector2.ZERO: wander_to = home + Vector2(rng.randf_range(-70, 70), rng.randf_range(-70, 70))
			state = "wander" if rng.randf() < 0.6 else "graze"
	_act(dt)

func _act(dt: float) -> void:
	match state:
		"flee":
			if target and is_instance_valid(target):
				move_dir = (position - target.position).normalized()
				if position.distance_to(target.position) > ph["sight"]: state = "wander"
			else: state = "wander"
		"hunt":
			if target and is_instance_valid(target):
				var d := target.position - position
				move_dir = d.normalized()
				heading = lerp_angle(heading, d.angle(), clampf(dt * 8.0, 0, 1))
				if d.length() < ph["L"] * 0.55 + target.radius() and cooldown <= 0.0 and windup <= 0.0:
					start_attack()
			else: state = "wander"
		"graze":
			move_dir = Vector2.ZERO
			if not world.is_water(position) or ph["swims"]:
				_graze(dt)
		_:
			var d := wander_to - position
			move_dir = d.normalized() * 0.5 if d.length() > 8.0 else Vector2.ZERO

func eat_carcass(dt: float) -> bool:
	for c in world.get_meta("carcasses") as Array:
		var cc = c
		if is_instance_valid(cc) and cc.position.distance_to(position) < radius() + 30.0 and cc.food > 0.0:
			var take := minf(cc.food, dt * 0.25)
			cc.food -= take; energy = minf(energy + take * 2.5 / (0.3 + mass * 0.5), 1.0)
			eat_t += dt
			return true
	return false

func _graze(dt: float) -> void:
	if carniv > 0.2 and eat_carcass(dt): return
	eat_t += dt
	var r := world.region_of(position)
	var plants: float = world.sim.plant[r] / maxf(world.sim.plant_k[r], 1.0)
	var gain: float = dt * 0.05 * (1.0 - carniv) * plants * (0.4 + ph["smell"] / 600.0)
	energy = minf(energy + gain, 1.0)
	if gain > 0.0: world.sim.plant[r] = maxf(world.sim.plant[r] - gain * 20.0, 0.0)
