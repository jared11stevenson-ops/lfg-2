extends SceneTree
## Why isn't mind emerging? Print the top cognition demes and which gates they fail.
func _initialize():
	var seed_ := 10
	for a in OS.get_cmdline_user_args(): if a.begins_with("seed="): seed_ = int(a.substr(5))
	var s := EcoSim.new(); s.generate(seed_)
	for i in 500: s.step()
	var rows := []
	for r in EcoSim.RW * EcoSim.RH:
		for d in s.pops[r]:
			rows.append([s.cog_index(d["g"]), d, r])
	rows.sort_custom(func(a, b): return a[0] > b[0])
	for k in 8:
		var ci: float = rows[k][0]; var d: Dictionary = rows[k][1]; var g: PackedFloat32Array = d["g"]
		print("%s ci=%.2f n=%.0f fed=%.2f social=%.2f manip=%.2f comm=%.2f coop=%.2f learn=%.2f mem=%.2f plan=%.2f ratchet=%.1f" % [s.species[d["sp"]]["name"], ci, d["n"], d["fed"], EcoSim.T(g,"social"), EcoSim.T(g,"c_manip"), EcoSim.T(g,"c_comm"), EcoSim.T(g,"c_coop"), EcoSim.T(g,"c_learn"), EcoSim.T(g,"c_memory"), EcoSim.T(g,"c_plan"), d["ratchet"]])
	quit()
