extends SceneTree
# Economy-aware bot: earns and spends coins like a player. Usage:
#  godot --headless --path td --fixed-fps 60 -s tests/sim_bot.gd -- level=mossgate diff=normal seed=3 skill=0.5
# skill 1.0 = always the best-covering spot and tight spending; 0.0 = random valid spots and sloppy upgrades.
var main
var frames := 0
var act_t := 0.0
var skill := 0.6
var rng := RandomNumberGenerator.new()
var spots: Array = []
var order := ["tickindle", "dugloom", "tickindle", "hutzin", "dugloom", "hutzin"]
var placed_count := 0
var lives_log := []
var last_wave := 0
var last_lives := 0

func _initialize() -> void:
	var S = load("res://session.gd")
	S.no_save = true
	S.settings["tutorial_done"] = true
	var seed_v := 1
	for a in OS.get_cmdline_user_args():
		var k: String = a.get_slice("=", 0)
		var v: String = a.get_slice("=", 1)
		match k:
			"level": S.level_id = v
			"diff": S.diff = v
			"mut": S.muts = Array(v.split(","))
			"seed": seed_v = int(v); S.run_seed = seed_v
			"skill": skill = float(v)
	rng.seed = seed_v * 7919
	var open_order := []
	var C = load("res://creatures.gd")
	for id in order:
		if S.tower_open(C.TOWERS[id]):
			open_order.append(id)
	order = open_order
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _rank_spots() -> void:
	var samples: Array = []
	for path in main.paths:
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var cnt := int(a.distance_to(b) / 30.0)
			for k in cnt:
				samples.append(a.lerp(b, float(k) / maxf(1.0, cnt)))
	var stone_pos: Array = main.stones.map(func(q): return q.pos)
	var cands: Array = []
	for s in stone_pos:
		cands.append(s)
	var x := 40
	while x < 1240:
		var y := 90
		while y < 590:
			cands.append(Vector2(x, y))
			y += 30
		x += 30
	var scored: Array = []
	for p in cands:
		if not main._valid_spot(p):
			continue
		var c := 0
		for s in samples:
			if p.distance_to(s) < 170.0:
				c += 1
		scored.append([c + (30 if p in stone_pos else 0), p])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	spots = scored

func _free_spot() -> Variant:
	var k := int(round((1.0 - skill) * 14.0))
	var pool: Array = []
	for sc in spots:
		var ok := true
		for t in get_nodes_in_group("towers"):
			if t.position.distance_to(sc[1]) < 70.0:
				ok = false
				break
		if ok:
			pool.append(sc[1])
		if pool.size() > k:
			break
	if pool.is_empty():
		return null
	return pool[rng.randi() % pool.size()] if k > 0 else pool[0]

func _act() -> void:
	var Cr = load("res://creatures.gd")
	var towers := get_nodes_in_group("towers")
	var want := 2 + int(main.wave * 0.7 * (0.6 + skill * 0.6))
	# buy a new defender if we are below target and can afford it, else upgrade
	if towers.size() < want:
		var id: String = order[placed_count % order.size()]
		var d: Dictionary = Cr.TOWERS[id]
		if main.coins >= int(d.cost):
			var p = _free_spot()
			if p != null:
				main._place(d, p)
				placed_count += 1
				return
	# upgrade: prefer the cheapest available tier on the least-upgraded tower, mixing paths
	var best = null
	var best_cost := 99999
	for t in towers:
		for path in ["a", "b"]:
			var u: Dictionary = t.next_upgrade(path)
			if u.is_empty() or t.blocked(path):
				continue
			var depth: int = t.tiers.a + t.tiers.b
			var score := int(u.cost) + depth * int(60 * skill)
			if skill < 0.5 and rng.randf() < 0.3:
				score += 400
			if score < best_cost and main.coins >= int(u.cost):
				best_cost = score
				best = [t, path]
	if best != null:
		main.sel_tower = best[0]
		main._on_upgrade(best[1])
		main.sel_tower = null

func _process(delta: float) -> bool:
	frames += 1
	if frames == 3:
		_rank_spots()
	if main.wave != last_wave:
		if last_wave > 0 and main.lives < last_lives:
			lives_log.append("w%d:-%d" % [last_wave, last_lives - main.lives])
		last_wave = main.wave
		last_lives = main.lives
	act_t -= delta
	if act_t <= 0.0 and main.state == "play":
		act_t = 0.4 + (1.0 - skill) * 1.2
		_act()
		if not main.wave_running and main.coins < 60 + (1.0 - skill) * 80 or (not main.wave_running and frames > 200):
			main._start_wave()
	if main.state != "play" or frames > 60 * 1200:
		print("RESULT seed=", main.run_seed, " skill=", skill, " level=", main.lv.name, " state=", main.state, " wave=", main.wave, " lives=", main.lives, "/", main.lives_start, " towers=", get_nodes_in_group("towers").size(), " leaks=", lives_log)
		quit(0 if main.state == "won" else 1)
	return false
