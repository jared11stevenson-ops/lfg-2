extends SceneTree
## Playtest bot: uses the same player-facing APIs (gather, CraftUI, equip, attack) to craft and fight.
func _initialize():
	var ps := PlayScene.new(); ps.autoplay_input = false
	root.add_child(ps)
	ps.start_new(9, "squirrel", 60)
	var p := ps.player
	var found := 0
	# walk the world looking for terrain that yields a cutting/piercing design (bot explores like a player would)
	for step in 400:
		p.position = ps.world.region_center(ps.rng.randi() % (EcoSim.RW * EcoSim.RH)) + Vector2(ps.rng.randf_range(-100, 100), ps.rng.randf_range(-100, 100))
		for k in 3: ps.gather(p, 1.1)
		if p.inv_count() >= p.carry_cap(): break
	print("inventory: ", p.inv, " cap=", p.carry_cap(), " manip=", Genome.get_g(p.genome, "c_manip"))
	ps._toggle_craft("craft")
	var ui: CraftUI = ps.craft_ui
	await process_frame
	var pool := []
	for m in p.inv: if p.inv[m] > 0: pool.append(m)
	var made := 0
	for fi in ui.func_ids.size():
		ui.sel_func = fi
		var d := Invention.best_design(ui.func_ids[fi], pool, p.genome)
		ui.design = d
		var r := ui._eval()
		print("%s %s -> ok=%s score=%.2f %s" % [ui.func_ids[fi], str(d), r["ok"], r["score"], str(r["reasons"])])
		if r["ok"] and ui._has_mats(): ui._press("make", 1); made += 1
	print("made items: ", ps.items.size(), " known: ", ps.known.keys())
	if ps.items.size() > 0:
		ps.equip(p, ps.items[0])
		# fight: spawn a prey creature adjacent and strike until it dies
		var target: Critter = null
		for c in ps.critters:
			if c != p and c.mass < p.mass * 3.0: target = c; break
		if target:
			target.position = p.position + Vector2(40, 0); p.aim = 0.0; p.heading = 0.0
			for i in 60:
				p.cooldown = 0.0; p.stamina = 1.0
				p.start_attack()
				for f in 20: p.tick(0.02)
				if target.is_queued_for_deletion() or target.hp <= 0: break
			print("target dead: ", target.is_queued_for_deletion(), " item kills=", ps.items[0].kills, " tier=", ps.items[0].legend_tier(), " history=", ps.items[0].history.size())
	ui.tab = "items"; ui._rebuild()
	for i in 5: await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://captures/craft_items.png")
	ui.tab = "craft"; ui.sel_func = 1; ui.design = Invention.best_design("pierce", pool, p.genome); ui._rebuild()
	for i in 5: await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://captures/craft_bench.png")
	quit()
