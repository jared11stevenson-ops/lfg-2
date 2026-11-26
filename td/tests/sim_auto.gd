extends SceneTree
# Auto-placing balance sim. Usage:
#  godot --headless --path td --fixed-fps 60 -s tests/sim_auto.gd -- level=lastwell diff=normal n=10 tiers=2 seed=5 loadout=tickindle,dugloom,ally_zapnose
# Places n towers (free) at the best-covering valid spots (stones first), buys `tiers` upgrades each, plays all waves.
var main
var frames := 0
var placed := false
var n := 10
var tiers := 2
var loadout: Array = []
var verbose := false

func _initialize() -> void:
	var S = load("res://session.gd")
	S.no_save = true
	for a in OS.get_cmdline_user_args():
		var k: String = a.get_slice("=", 0)
		var v: String = a.get_slice("=", 1)
		match k:
			"level": S.level_id = v
			"diff": S.diff = v
			"mut": S.muts = Array(v.split(","))
			"seed": S.run_seed = int(v)
			"n": n = int(v)
			"tiers": tiers = int(v)
			"loadout": loadout = Array(v.split(","))
			"v": verbose = true
	if loadout.is_empty():
		loadout = ["tickindle", "dugloom", "hutzin", "ally_shuckit", "ally_zapnose", "ally_glomm", "ally_hoardillo", "ally_gloamoth", "ally_quillwyrm", "ally_pyrelope"]
	main = load("res://main.tscn").instantiate()
	root.add_child(main)

func _place() -> void:
	var samples: Array = []
	for path in main.paths:
		for i in path.size() - 1:
			var a: Vector2 = path[i]
			var b: Vector2 = path[i + 1]
			var cnt := int(a.distance_to(b) / 30.0)
			for k in cnt:
				samples.append(a.lerp(b, float(k) / maxf(1.0, cnt)))
	var cands: Array = []
	for s in main.stones:
		cands.append(s.pos)
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
		scored.append([c + (25 if p in main.stones.map(func(q): return q.pos) else 0), p])
	scored.sort_custom(func(a, b): return a[0] > b[0])
	var chosen: Array = []
	for sc in scored:
		if chosen.size() >= n:
			break
		var ok := true
		for q in chosen:
			if sc[1].distance_to(q) < 78.0:
				ok = false
		if ok:
			chosen.append(sc[1])
	var Cr = load("res://creatures.gd")
	for i in chosen.size():
		var t = load("res://tower.gd").new()
		t.def = Cr.TOWERS[loadout[i % loadout.size()]]
		t.position = chosen[i]
		main.add_child(t)
		for j in tiers:
			t.buy("a" if (i + j) % 3 != 0 else "b")
	if verbose:
		print("placed ", chosen.size(), " towers")

func _process(_d: float) -> bool:
	frames += 1
	if not placed and frames == 3:
		placed = true
		_place()
	if placed and main.state == "play" and not main.wave_running:
		main._start_wave()
	if main.state != "play" or frames > 60 * 900:
		print("RESULT level=", main.lv.name, " state=", main.state, " wave=", main.wave, " lives=", main.lives, "/", main.lives_start, " sec=", frames / 60)
		quit(0 if main.state == "won" else 1)
	return false
