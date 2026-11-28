extends SceneTree
func _initialize():
	var t0 := Time.get_ticks_msec()
	var ps := PlayScene.new(); ps.autoplay_input = false
	root.add_child(ps)
	var sim := EcoSim.new(); sim.generate(3); print("gen ", Time.get_ticks_msec()-t0)
	for i in 60: sim.step()
	print("60 ticks ", Time.get_ticks_msec()-t0)
	var w := GameWorld.new(); root.add_child(w); w.build(sim)
	print("build ", Time.get_ticks_msec()-t0)
	quit()
