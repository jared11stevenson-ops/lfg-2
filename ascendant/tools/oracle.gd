extends SceneTree
## ORACLE: run many deterministic worlds headless and report outcomes.
## godot --headless --path . -s res://tools/oracle.gd -- seeds=6 ticks=400 out=docs/oracle/run.json
func _initialize():
	var args := {"seeds": "4", "ticks": "300", "out": "", "first": "1"}
	for a in OS.get_cmdline_user_args():
		var kv := a.split("=")
		if kv.size() == 2: args[kv[0]] = kv[1]
	var results := []
	for s in int(args["seeds"]):
		var seed_ := int(args["first"]) + s
		var sim := EcoSim.new()
		sim.generate(seed_)
		var t0 := Time.get_ticks_msec()
		var series := []
		for t in int(args["ticks"]):
			sim.step()
			if t % 50 == 49:
				var rec: Dictionary = sim.stats_hist[sim.stats_hist.size() - 1]
				series.append(rec.duplicate())
		var ms := Time.get_ticks_msec() - t0
		var alive := 0; var ext := 0
		for sp in sim.species:
			if sp["extinct"] < 0: alive += 1
			else: ext += 1
		var spec_events := 0; var ext_events := 0
		for e in sim.events:
			if e["type"] == "speciation": spec_events += 1
		var first_dawn := -1
		var dawn_names := []
		for ev in sim.sapient_events:
			if first_dawn < 0: first_dawn = ev["tick"]
			dawn_names.append(sim.species[ev["sp"]]["name"])
		var res := {"seed": seed_, "alive": alive, "extinct": ext, "speciations": spec_events, "sapient": sim.sapient_events.size(), "first_dawn": first_dawn, "dawn_species": dawn_names, "ms": ms, "ms_per_tick": float(ms) / int(args["ticks"]), "series": series}
		results.append(res)
		print("seed %d: alive=%d ext=%d spec=%d dawn=%d@%d %s | %.1f ms/tick | final total=%.0f maxci=%.2f" % [seed_, alive, ext, spec_events, sim.sapient_events.size(), first_dawn, str(dawn_names), res["ms_per_tick"], series[-1]["total"], series[-1]["max_ci"]])
	if args["out"] != "":
		DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://" + args["out"].get_base_dir()))
		var f := FileAccess.open("res://" + args["out"], FileAccess.WRITE)
		f.store_string(JSON.stringify(results, "  "))
	quit()
