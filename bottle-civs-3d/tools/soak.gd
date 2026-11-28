extends SceneTree
## godot --headless --script tools/soak.gd -- 150 3
func _init():
	var a := OS.get_cmdline_user_args()
	var days := int(a[0]) if a.size() > 0 else 100
	var seed_v := int(a[1]) if a.size() > 1 else 1
	var sim := BCSim.new(seed_v)
	var t0 := Time.get_ticks_msec()
	var steps := 0
	while sim.day <= days:
		sim.step(0.1); steps += 1
		if steps % 400 == 0:
			for c in sim.civs:
				for k in c.stock:
					assert(is_finite(c.stock[k]), "non-finite stock")
	var ms := Time.get_ticks_msec() - t0
	print("seed %d: %d days, %d steps, %d ms (%.0fx realtime)" % [seed_v, days, steps, ms, float(steps) * 0.1 / (float(ms) / 1000.0)])
	for c in sim.civs:
		print("%-12s pop %3d food %5d gold %5d tech %2d births %3d/%2d raids %2d def %2d trades %3d k/l %d/%d war %d" % [c.name, c.citizens.size(), c.stock.food, c.stock.gold, c.tech, c.stats.births, c.stats.hybrid_births, c.stats.raids, c.stats.defended, c.stats.trades, c.stats.kills, c.stats.losses, c.war.size()])
	print("world ", sim.stats, " pop ", sim.total_pop())
	quit()
