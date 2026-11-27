extends SceneTree
# Level data sanity: paths valid, stones/zones off the lanes, rosters reference real species, towers' unlocks reference real levels.
const Levels = preload("res://levels.gd")
const Creatures = preload("res://creatures.gd")
const Rules = preload("res://rules.gd")
const Waves = preload("res://waves.gd")

func _dist(p: Vector2, paths: Array) -> float:
	var best := INF
	for path in paths:
		for i in path.size() - 1:
			best = minf(best, p.distance_to(Geometry2D.get_closest_point_to_segment(p, path[i], path[i + 1])))
	return best

func _init() -> void:
	var fails := 0
	var n := 0
	var species_seen := {}
	for id in Levels.ORDER:
		var lv: Dictionary = Levels.LEVELS[id]
		var paths := Levels.to_paths(lv)
		for st in lv.stones:
			n += 1
			var d := _dist(Vector2(st[0], st[1]), paths)
			if d < 68.0 or st[0] < 40 or st[0] > 1240 or st[1] < 80 or st[1] > 590 or (st[1] > 560 and st[0] < 940):
				fails += 1
				print("FAIL ", id, " stone ", st, " dist ", d)
		for z in lv.zones:
			n += 1
			if _dist(Vector2(z.pos[0], z.pos[1]), paths) > 8.0:
				fails += 1
				print("FAIL ", id, " zone off lane ", z)
		for r in lv.roster:
			n += 1
			species_seen[r[0]] = true
			if not Creatures.ENEMIES.has(r[0]):
				fails += 1
				print("FAIL ", id, " unknown species ", r[0])
		n += 1
		if String(lv.boss) != "" and not Creatures.ENEMIES.has(lv.boss):
			fails += 1
			print("FAIL ", id, " unknown boss")
		# waves generate without error and boss wave contains the boss
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for w in range(1, 12):
			var q := Waves.build(lv, w, rng, 1.0)
			n += 1
			if q.is_empty() or (w == 10 and String(lv.boss) != "" and not ("boss:" + lv.boss) in q):
				fails += 1
				print("FAIL ", id, " wave ", w, " bad: ", q.size())
	for tid in Creatures.TOWERS:
		var t: Dictionary = Creatures.TOWERS[tid]
		if t.has("unlock"):
			n += 1
			var base := String(t.unlock).rstrip("2")
			if not Levels.LEVELS.has(base):
				fails += 1
				print("FAIL tower ", tid, " unlock ", t.unlock)
	n += 1
	if species_seen.size() < 17:
		print("note: roster covers ", species_seen.size(), "/17 species across levels")
	print("levels: ", n - fails, "/", n, " ok; species ", species_seen.size(), "; towers ", Creatures.TOWERS.size(), "; enemies ", Creatures.ENEMIES.size())
	quit(1 if fails > 0 else 0)
