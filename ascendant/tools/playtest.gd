extends SceneTree
## Autonomous playtest: bots with different playstyles drive the player through the same APIs as a human.
## godot --headless -s res://tools/playtest.gd -- secs=300 species=vole,stoat styles=hunter,cautious out=docs/playtest/run.json
var ps: PlayScene
func _initialize():
	var args := {"secs": "240", "species": "vole,stoat,rook,weaver", "styles": "hunter,cautious,breeder,inventor", "out": "", "seed": "41"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2: args[kv[0]] = kv[1]
	var results := []
	for sp in args["species"].split(","):
		for style in args["styles"].split(","):
			var r := _run(sp, style, float(args["secs"]), int(args["seed"]))
			results.append(r)
			print("%-8s %-9s survived=%5.0fs deaths=%d maxgen=%d kills=%d items=%d known=%s ended=%s cause=%s" % [sp, style, r["alive_s"], r["deaths"], r["max_gen"], r["kills"], r["items"], str(r["known"]), r["end_state"], str(r["causes"])])
	if args["out"] != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + args["out"].get_base_dir()))
		FileAccess.open("res://" + args["out"], FileAccess.WRITE).store_string(JSON.stringify(results, "  "))
	quit()

func _run(arch: String, style: String, secs: float, seed_: int) -> Dictionary:
	ps = PlayScene.new(); ps.autoplay_input = false
	root.add_child(ps)
	ps.start_new(seed_, arch, 60)
	var t := 0.0; var dt := 0.05
	var causes := {}
	var max_gen := 1; var kills := 0; var steps := 0
	var rng := RandomNumberGenerator.new(); rng.seed = seed_
	var dir_t := 0.0; var dir := Vector2.RIGHT
	var last_deaths := 0
	while t < secs:
		t += dt; steps += 1
		var p := ps.player
		if is_instance_valid(p) and not p.is_queued_for_deletion():
			_bot(p, style, dt, rng, dir_t, dir)
			dir_t -= dt
			if dir_t <= 0.0: dir_t = rng.randf_range(2.0, 5.0); dir = Vector2.RIGHT.rotated(rng.randf() * TAU)
			if p.state == "x": pass
		ps._process(dt)
		for c in ps.critters:
			if is_instance_valid(c): c.tick(dt)
		max_gen = maxi(max_gen, ps.generation)
		if ps.deaths != last_deaths:
			last_deaths = ps.deaths
		if ps.observer and not is_instance_valid(ps.player): break
	for line in ps.chronicle:
		if line.contains("died ("):
			var k: String = line.substr(line.find("(") + 1, line.find(")") - line.find("(") - 1)
			causes[k] = causes.get(k, 0) + 1
	var k_total := 0
	if is_instance_valid(ps.player): k_total = ps.player.kills
	var res := {"species": arch, "style": style, "alive_s": t, "deaths": ps.deaths, "max_gen": max_gen, "kills": k_total, "items": ps.items.size(), "known": ps.known.keys(), "causes": causes, "end_state": "observer" if ps.observer else "playing", "steps": steps, "critters": ps.critters.size()}
	ps.queue_free()
	return res

func _bot(p: Critter, style: String, dt: float, rng: RandomNumberGenerator, dir_t: float, dir: Vector2) -> void:
	p.use_aim = false
	var threat: Critter = null; var prey: Critter = null; var td := 400.0; var pd := 500.0
	for c in ps.critters:
		var o: Critter = c
		if o == p or not is_instance_valid(o) or o.sp == p.sp: continue
		var d := p.position.distance_to(o.position)
		if o.carniv > 0.55 and o.mass > p.mass * 0.6 and d < td: threat = o; td = d
		if o.carniv < 0.8 and o.mass < p.mass * 2.0 and o.mass > p.mass * 0.02 and d < pd and o.civ_id < 0: prey = o; pd = d
	var hungry := p.energy < 0.55
	p.move_dir = dir * 0.6
	# survival reflexes shared by all styles
	if threat and style != "hunter":
		p.move_dir = (p.position - threat.position).normalized()
		if td < 120.0: p.dodge()
		return
	if hungry:
		if p.carniv > 0.45 and prey:
			_chase(p, prey)
			return
		if ps.carcasses.size() > 0 and p.carniv > 0.2:
			var best: Carcass = null; var bd := 600.0
			for cc in ps.carcasses:
				if is_instance_valid(cc) and cc.position.distance_to(p.position) < bd: bd = cc.position.distance_to(p.position); best = cc
			if best:
				p.move_dir = (best.position - p.position).normalized()
				if bd < p.radius() + 30.0: p.eat_carcass(dt); p.move_dir = Vector2.ZERO
				return
		p.move_dir = Vector2.ZERO; p._graze(dt)     # graze where it stands
		return
	match style:
		"hunter":
			if prey: _chase(p, prey)
		"breeder":
			ps.mate_pick = 0
			if ps.try_mate(p): pass
		"inventor":
			if p.inv_count() < 6:
				ps.gather(p, dt)
				p.move_dir = dir * 0.2
			else:
				_craft_all(p)
			if prey and p.carniv > 0.4: _chase(p, prey)
		_:
			pass
	if p.is_adult() and rng.randf() < 0.002: ps.try_mate(p)
	var cands := ps.mate_candidates(p)
	if style == "breeder" and not cands.is_empty():
		var o: Critter = cands[0]
		p.move_dir = (o.position - p.position).normalized() * 0.6

func _chase(p: Critter, prey: Critter) -> void:
	var d := prey.position - p.position
	p.move_dir = d.normalized(); p.aim = d.angle(); p.use_aim = true; p.heading = d.angle()
	if d.length() < p.ph["L"] * 0.6 + prey.radius(): p.start_attack()

func _craft_all(p: Critter) -> void:
	var pool := []
	for m in p.inv: if p.inv[m] > 0: pool.append(m)
	for fn in Invention.FUNCS:
		var d := Invention.best_design(fn, pool, p.genome)
		if d.is_empty(): continue
		var r := Invention.evaluate(fn, d, p.genome)
		var need := {}
		for role in d: need[d[role]] = need.get(d[role], 0) + 1
		var have := true
		for m in need: if p.inv.get(m, 0) < need[m]: have = false
		if r["ok"] and have:
			for m in need: p.inv[m] -= need[m]
			var it := Item.create(fn, d, r["score"], p.display_name(), ps.sim.tick, p.sp_name)
			ps.items.append(it)
			if not ps.known.has(fn): ps.known[fn] = {"score": r["score"], "design": d, "name": it.name}
			p.train("c_manip", 0.012)
			if fn in ["pierce", "cut", "pound"] and p.weapon.is_empty(): ps.equip(p, it)
			return
