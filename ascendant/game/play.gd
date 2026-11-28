class_name PlayScene
extends Node2D
## The living world + the player's bloodline.
const SEASON_SECONDS := 45.0
var sim: EcoSim
var world: GameWorld
var cam: Camera2D
var critters: Array = []
var carcasses: Array = []
var player: Critter
var hud: Hud
var rng := RandomNumberGenerator.new()
var spawn_t := 0.0
var season_t := 0.0
var bloodline_id := 0
var heirs: Array = []          # critter ids queued as heirs
var chronicle: Array = []      # player-visible history lines
var observer := false
var mate_pick := 0
var mate_cands: Array = []
var deaths := 0
var generation := 1
var autoplay_input := true      # false => bots drive the player
var sim_busy := false
var backdrop := false
var focus := Vector2.ZERO
var known: Dictionary = {}     # invention knowledge of THIS bloodline
var craft_ui: CraftUI
var items: Array = []        # Items owned by the bloodline (see core/item.gd)
var sfx: Synth.Bank
var props: PropLayer
var structs: StructureLayer

func start_new(seed_: int, arch_id: String, history_ticks: int = 120) -> void:
	var s := EcoSim.new()
	s.generate(seed_)
	for i in history_ticks: s.step()
	start_from_sim(s, arch_id)

## Begin play on an already-generated (pre-historied) simulation.
func start_from_sim(s: EcoSim, arch_id: String, backdrop_mode: bool = false) -> void:
	sim = s
	rng.seed = sim.seed_ * 31 + 5
	backdrop = backdrop_mode
	world = GameWorld.new()
	add_child(world)
	world.build(sim)
	world.set_meta("critters", critters)
	world.set_meta("carcasses", carcasses)
	cam = Camera2D.new(); cam.position_smoothing_enabled = true; cam.position_smoothing_speed = 7.0
	add_child(cam)
	cam.enabled = true
	props = PropLayer.new(); props.world = world; props.cam = cam; props.z_index = 1
	world.add_child(props)
	sfx = Synth.Bank.new(); add_child(sfx); world.set_meta("sfx", sfx)
	structs = StructureLayer.new(); structs.world = world; structs.cam = cam; structs.z_index = 2
	world.add_child(structs)
	var layer := CanvasLayer.new(); layer.layer = 10
	add_child(layer)
	hud = Hud.new(); hud.play = self
	layer.add_child(hud)
	if backdrop:
		observer = true
		focus = world.region_center(sim.idx(EcoSim.RW / 2, EcoSim.RH / 2))
		cam.zoom = Vector2(0.9, 0.9); cam.position = focus
		_chronicle_new_events()
		_spawn_around(true)
		return
	_found_bloodline(arch_id)
	_spawn_around(true)

func _found_bloodline(arch_id: String) -> void:
	# pick the species derived from that archetype that is most abundant near a habitable region
	var best_r := -1; var best_sp := -1; var best_n := 0.0
	for r in EcoSim.RW * EcoSim.RH:
		for d in sim.pops[r]:
			if sim.species[d["sp"]]["arch"] == arch_id and d["n"] > best_n and sim.water[r] < 0.5 + (0.5 if arch_id in ["minnow", "pike"] else 0.0):
				best_n = d["n"]; best_r = r; best_sp = d["sp"]
	if best_r < 0:
		# archetype lost during history: take any living species instead (the world does not owe the player a species)
		for r in EcoSim.RW * EcoSim.RH:
			for d in sim.pops[r]:
				if d["n"] > best_n and sim.water[r] < 0.6: best_n = d["n"]; best_r = r; best_sp = d["sp"]
		chronicle.append("Your chosen species did not survive the ages. You wake as another.")
	var d0: Dictionary
	for d in sim.pops[best_r]:
		if d["sp"] == best_sp: d0 = d
	var bp: int = sim.species[best_sp]["bp"]
	var g: PackedFloat32Array = d0["g"].duplicate()
	var c := _make_critter(g, bp, best_sp, world.region_center(best_r), 0.45)
	c.is_player = true; c.bloodline = bloodline_id
	player = c
	cam.position = c.position
	_set_player_cam()

func _set_player_cam() -> void:
	var L: float = player.ph["L"]
	var z := clampf(90.0 / L, 0.9, 2.2)
	cam.zoom = Vector2(z, z)

func _make_critter(g: PackedFloat32Array, bp: int, sp: int, pos: Vector2, age_frac: float = -1.0) -> Critter:
	var c := Critter.new()
	c.setup(g, bp, sp, sim.species[sp]["name"], world, age_frac)
	c.position = world.random_land_near(pos, 120.0, rng, bp == Genome.BP.FISH)
	if bp == Genome.BP.FISH and not world.is_water(c.position): c.position = pos
	world.add_child(c)
	critters.append(c)
	c.died.connect(_on_died)
	return c

func _on_died(c: Critter, killer) -> void:
	critters.erase(c)
	deaths += 1
	var r := world.region_of(c.position)
	for d in sim.pops[r]:
		if d["sp"] == c.sp: d["n"] = maxf(d["n"] - 1.0, 0.0); break
	if c.mass > 0.003 and c.carniv < 2.0:
		var cc := Carcass.new()
		cc.position = c.position; cc.food = clampf(0.4 + c.mass * 2.0, 0.4, 3.0); cc.art_ph = c.ph
		world.add_child(cc); carcasses.append(cc)
		cc.tree_exited.connect(func(): carcasses.erase(cc))
	if sfx and is_instance_valid(player) and c.position.distance_to(player.position) < 600.0: sfx.play("death", 0.5, 1.0 / (0.6 + c.mass))
	if c == player:
		_player_died(killer)

func _player_died(killer) -> void:
	var how := "old age" if killer == null else ("killed by a " + (killer as Critter).sp_name if killer is Critter else "unknown")
	chronicle.append("Gen %d died (%s)." % [generation, how])
	# eligible heir: living offspring of the bloodline, adults first
	var best: Critter = null
	for c in critters:
		if is_instance_valid(c) and c.bloodline == bloodline_id and c != player and not c.is_queued_for_deletion():
			if best == null or c.maturity() > best.maturity(): best = c
	if best:
		for it in items:
			it.transfer(best.display_name(), "inherited", sim.tick)
		best.inv = player.inv.duplicate()
		if not player.weapon.is_empty(): equip(best, player.weapon["item"])
		_become(best)
		chronicle.append("Your heir takes up the line (gen %d)." % generation)
	else:
		# bloodline ended: pick any wild animal nearby and found a new lineage
		bloodline_id += 1
		var pick: Critter = null; var bd := 1e9
		for c in critters:
			if is_instance_valid(c) and not c.is_queued_for_deletion() and c.is_adult():
				var d: float = c.position.distance_to(player.position)
				if d < bd: bd = d; pick = c
		generation = 1
		chronicle.append("Your line is extinct. A new bloodline begins...")
		if pick: _become(pick, true)
		else: observer = true

func _become(c: Critter, new_line: bool = false) -> void:
	var old := player
	player = c; c.is_player = true; c.bloodline = bloodline_id
	if not new_line: generation += 1
	_set_player_cam()
	c.age_s = maxf(c.age_s, c.life_s * 0.12 * 0.6)

func _process(dt: float) -> void:
	if not sim: return
	if sfx and is_instance_valid(player):
		var wet := 1.0 if world.is_water(player.position) else 0.0
		sfx.set_beds(0.35, 0.1 + 0.4 * wet)
	critters = critters.filter(func(c): return is_instance_valid(c))
	world.set_meta("critters", critters)
	spawn_t -= dt
	if spawn_t <= 0.0:
		spawn_t = 0.6
		_spawn_around(false)
	season_t += dt
	if season_t >= (SEASON_SECONDS if not backdrop else 9.0):
		season_t = 0.0
		sim.step()
		_chronicle_new_events()
	if is_instance_valid(player):
		cam.position = player.position
		if autoplay_input: _player_input(dt)
	elif observer:
		if backdrop or true:
			focus += Vector2(cos(Time.get_ticks_msec() * 0.00004), sin(Time.get_ticks_msec() * 0.00003)) * 18.0 * dt
			cam.position = focus

var _ev_seen := 0
func _chronicle_new_events() -> void:
	while _ev_seen < sim.events.size():
		var e: Dictionary = sim.events[_ev_seen]; _ev_seen += 1
		chronicle.append("Y%d: %s" % [sim.tick / 4, e["text"]])
	if chronicle.size() > 60: chronicle = chronicle.slice(-60)

func year() -> int: return sim.tick / 4
func season_name() -> String: return ["Thaw", "Bloom", "Harvest", "Frost"][sim.tick % 4]

func _player_input(dt: float) -> void:
	var p := player
	var dir := Vector2.ZERO
	if Input.is_key_pressed(KEY_W) or Input.is_key_pressed(KEY_UP): dir.y -= 1
	if Input.is_key_pressed(KEY_S) or Input.is_key_pressed(KEY_DOWN): dir.y += 1
	if Input.is_key_pressed(KEY_A) or Input.is_key_pressed(KEY_LEFT): dir.x -= 1
	if Input.is_key_pressed(KEY_D) or Input.is_key_pressed(KEY_RIGHT): dir.x += 1
	p.move_dir = dir.normalized()
	var mp := get_global_mouse_position()
	p.aim = (mp - p.position).angle(); p.use_aim = true
	if Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT) or Input.is_key_pressed(KEY_SPACE):
		if p.start_attack(): sfx.play("swing", 0.5)
	if Input.is_key_pressed(KEY_SHIFT): p.dodge()
	if Input.is_key_pressed(KEY_G): gather(p, dt); p.move_dir *= 0.2
	if Input.is_key_pressed(KEY_E):
		if p.carniv > 0.2 and p.eat_carcass(dt): pass
		else: p._graze(dt)
		p.move_dir *= 0.2

func _unhandled_key_input(ev: InputEvent) -> void:
	if not (ev is InputEventKey and ev.pressed and not ev.echo) or not is_instance_valid(player): return
	match ev.keycode:
		KEY_Q:
			if player.use_ability(): sfx.play("swing", 0.6, 0.7)
		KEY_Z: mate_pick += 1
		KEY_R: try_mate(player)
		KEY_TAB: observer = not observer
		KEY_C: _toggle_craft("craft")
		KEY_I: _toggle_craft("items")
		KEY_F: _secrete(player)

func _toggle_craft(tab: String) -> void:
	if craft_ui:
		craft_ui.queue_free(); craft_ui = null; get_tree().paused = false; return
	craft_ui = CraftUI.new(); craft_ui.play = self; craft_ui.tab = tab; craft_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	craft_ui.closed.connect(func(): craft_ui.queue_free(); craft_ui = null; get_tree().paused = false)
	hud.get_parent().add_child(craft_ui)
	get_tree().paused = true

func equip(c: Critter, it: Item) -> void:
	if it == null:
		c.weapon = {}; return
	var reach: float = {"pierce": 24.0, "cut": 10.0, "pound": 6.0, "dig": 8.0}.get(it.func_id, 0.0)
	var power: float = it.power() * {"pierce": 1.0, "cut": 1.1, "pound": 1.3, "dig": 0.6}.get(it.func_id, 0.3) + 0.0
	c.weapon = {"item": it, "reach": reach, "power": maxf(power, 0.0)}

## Gather raw materials from the ground you stand on (physical limits: carrying capacity, body type).
func gather(p: Critter, dt: float) -> void:
	p.set_meta("gather_t", float(p.get_meta("gather_t", 0.0)) + dt)
	if float(p.get_meta("gather_t")) < 1.0: return
	p.set_meta("gather_t", 0.0)
	if p.inv_count() >= p.carry_cap():
		world.fx_text(p.position, "can't carry more", Color(1, 0.7, 0.5)); return
	var t := world.tile_of(p.position)
	var ti := t.y * GameWorld.TW + t.x
	var e := world.elev[ti]; var tr := world.tree_n[ti]
	var opts: Array = []
	for cc in carcasses:
		if is_instance_valid(cc) and cc.position.distance_to(p.position) < 60.0: opts.append_array(["bone", "chitin", "fur"])
	if e < 0.38: opts.append_array(["reed", "clay", "shell", "mud"])
	if tr > 0.1: opts.append_array(["wood", "leaf", "resin"] if tr > 0.5 else ["wood", "leaf"])
	if e > 0.58: opts.append_array(["stone", "flint", "flint"])
	if opts.is_empty(): opts.append_array(["fiber", "mud"])
	var m: String = opts[rng.randi() % opts.size()]
	if m == "resin" and tr < 0.5: m = "wood"
	p.inv[m] = p.inv.get(m, 0) + 1
	p.train("c_spatial", 0.002)
	world.fx_text(p.position, "+ " + m, Color(0.85, 0.95, 0.7))

func _secrete(p: Critter) -> void:
	var sec: float = p.ph["secrete"]
	if sec < 0.45 or p.energy < 0.25 or p.inv_count() >= p.carry_cap():
		world.fx_text(p.position, "can't secrete" if sec < 0.45 else "too tired/full", Color(1, 0.8, 0.6)); return
	var m := "silk" if p.bp == Genome.BP.ARACH or sec > 0.7 else "wax"
	p.inv[m] = p.inv.get(m, 0) + 1; p.energy -= 0.12
	world.fx_text(p.position, "+ " + m, Color(0.95, 0.95, 1.0))

func mate_candidates(p: Critter) -> Array:
	var out: Array = []
	for c in critters:
		var o: Critter = c
		if o == p or not is_instance_valid(o) or o.sp != p.sp or not o.is_adult() or o.mate_cd > 0.0 or o.energy < 0.4: continue
		if p.position.distance_to(o.position) < 220.0 + p.radius(): out.append(o)
	out.sort_custom(func(a, b): return a.position.distance_to(p.position) < b.position.distance_to(p.position))
	return out

## The three traits where a prospective mate differs most from you (what you'd be choosing).
func mate_traits(p: Critter, o: Critter) -> Array:
	var diffs: Array = []
	for n in ["size", "speed", "strength", "armor", "vision", "smell", "toxin", "camo", "c_manip", "c_comm", "c_coop", "c_plan", "c_learn", "metab", "lifespan", "fertility", "burrow", "aqua", "climb"]:
		var d: float = Genome.get_g(o.genome, n) - Genome.get_g(p.genome, n)
		diffs.append([n, d])
	diffs.sort_custom(func(a, b): return absf(a[1]) > absf(b[1]))
	return diffs.slice(0, 3)

func try_mate(p: Critter) -> bool:
	if p.mate_cd > 0.0 or not p.is_adult() or p.energy < 0.45: return false
	var cands := mate_candidates(p)
	var best: Critter = null
	if not cands.is_empty(): best = cands[mate_pick % cands.size()]
	if best == null:
		world.fx_text(p.position, "no mate near", Color(1, 0.8, 0.5)); return false
	var litter := clampi(int(round(0.8 + p.ph["bite"] * 0.0 + Genome.get_g(p.genome, "fertility") * 3.0 / (0.6 + p.mass * 0.4))), 1, 5)
	for i in litter:
		var g := Genome.cross(p.genome, best.genome, rng)
		# practice shapes the young: what the parent trained leans the offspring that way (bounded)
		for gn in p.practice: Genome.set_g(g, gn, Genome.get_g(g, gn) + float(p.practice[gn]) * 0.5)
		g = Genome.mutate(g, p.bp, rng, 0.14, 0.05)
		var kid := _make_critter(g, p.bp, p.sp, p.position + Vector2(rng.randf_range(-30, 30), rng.randf_range(-30, 30)), 0.0)
		kid.bloodline = p.bloodline if p.bloodline >= 0 else -1
		kid.gen = p.gen + 1; kid.parents = [p.id, best.id]
		kid.energy = 0.7
	if not p.practice.is_empty(): chronicle.append("Your practiced skills echo in the young."); p.practice.clear()
	p.mate_cd = 25.0; best.mate_cd = 25.0; p.energy -= 0.25; best.energy -= 0.2
	world.fx_text(p.position, "%d young!" % litter, Color(1, 0.7, 0.8))
	for d in sim.pops[world.region_of(p.position)]:
		if d["sp"] == p.sp: d["n"] += litter
	return true

func _spawn_around(initial: bool) -> void:
	var pr := world.region_of(player.position if is_instance_valid(player) else focus)
	var px := pr % EcoSim.RW; var py := pr / EcoSim.RW
	var have := {}
	for c in critters:
		var k: String = "%d_%d" % [world.region_of(c.position), c.sp]
		have[k] = have.get(k, 0) + 1
	var cap := 90
	for dy in range(-2, 3):
		for dx in range(-2, 3):
			var x := px + dx; var y := py + dy
			if not sim.in_bounds(x, y): continue
			var r := sim.idx(x, y)
			for d in sim.pops[r]:
				var tiny := sim.mass_of(d["g"], sim.species[d["sp"]]["bp"]) < 0.004
				var want := clampi(int(ceil(log(d["n"] + 1.0) / log(3.0))), 1, 3 if not tiny else 2)
				var k := "%d_%d" % [r, d["sp"]]
				var cur: int = have.get(k, 0)
				while cur < want and critters.size() < cap:
					var bp: int = sim.species[d["sp"]]["bp"]
					var g: PackedFloat32Array = d["g"].duplicate()
					for i in Genome.N: g[i] = clampf(g[i] + rng.randfn(0.0, d["sd"]), 0.0, 1.0)
					Genome.constrain(g, bp)
					var c := _make_critter(g, bp, d["sp"], world.region_center(r), -1.0)
					c.position = world.random_land_near(world.region_center(r), 120.0, rng, bp == Genome.BP.FISH)
					cur += 1
					if is_instance_valid(player) and c.position.distance_to(player.position) < 260.0 and not backdrop:
						c.position += (c.position - player.position).normalized() * 260.0
	# despawn far critters (their demes persist in the simulation)
	var anchor := player.position if is_instance_valid(player) else focus
	if true:
		for c in critters:
			var cc: Critter = c
			if cc != player and cc.bloodline < 0 and cc.position.distance_to(anchor) > 2300.0:
				cc.died.disconnect(_on_died)
				critters.erase(cc); cc.queue_free()

## Resume from a SaveGame dictionary.
func load_game(d: Dictionary) -> void:
	sim = EcoSim.new()
	sim.load_dict(d["sim"])
	rng.seed = sim.seed_ * 31 + sim.tick
	world = GameWorld.new(); add_child(world); world.build(sim)
	world.set_meta("critters", critters); world.set_meta("carcasses", carcasses)
	cam = Camera2D.new(); cam.position_smoothing_enabled = true; cam.position_smoothing_speed = 7.0
	add_child(cam); cam.enabled = true
	props = PropLayer.new(); props.world = world; props.cam = cam; props.z_index = 1; world.add_child(props)
	structs = StructureLayer.new(); structs.world = world; structs.cam = cam; structs.z_index = 2; world.add_child(structs)
	var layer := CanvasLayer.new(); layer.layer = 10; add_child(layer)
	hud = Hud.new(); hud.play = self; layer.add_child(hud)
	generation = d["generation"]; bloodline_id = d["bloodline"]; chronicle = d["chronicle"]; season_t = d["season_t"]; deaths = d["deaths"]; _ev_seen = d["ev_seen"]
	for idict in d["items"]: items.append(Item.from_dict(idict))
	for k in d["kin"]:
		var c := Critter.new()
		c.setup(k["g"], k["bp"], k["sp"], sim.species[k["sp"]]["name"], world, 0.5)
		c.id = k["id"]; Critter.next_id = maxi(Critter.next_id, c.id + 1)
		c.position = k["pos"]; c.age_s = k["age"]; c.hp = k["hp"]; c.energy = k["energy"]; c.bloodline = k["bloodline"]; c.gen = k["gen"]; c.parents = k["parents"]; c.kills = k["kills"]
		world.add_child(c); critters.append(c); c.died.connect(_on_died)
		if c.id == d["player_id"]:
			c.is_player = true; player = c
	if player == null: observer = true
	else:
		cam.position = player.position; _set_player_cam()
	_spawn_around(true)
