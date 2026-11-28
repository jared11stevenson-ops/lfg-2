extends SceneTree
## godot --headless --script tools/test_game.gd -- <seed> <turns>
func _init():
	var a := OS.get_cmdline_user_args()
	var sd := int(a[0]) if a.size() > 0 else 1
	var turns := int(a[1]) if a.size() > 1 else 120
	var g := RGame.new()
	g.new_game(sd, 2, 0, 3)
	g.note.connect(func(p, t, k): if k in ["war", "age"] or "captured" in t: print("T", g.turn, " [p", p, "] ", t))
	var t0 := Time.get_ticks_msec()
	while not g.game_over and g.turn < turns:
		RAI.take_turn(g, g.players[0])
		g.end_turn()
		if g.transition == "crisis": g.resolve_crisis(false)
		if g.transition == "race":
			var fr := g.free_races()
			g.choose_race(fr[0])
	print("turn ", g.turn, " age ", g.age, " ms ", Time.get_ticks_msec() - t0, " over ", g.game_over, " winner ", g.winner, " ", g.win_kind)
	for p in g.players:
		var cs := g.city_of(p)
		var pop := 0
		for c in cs: pop += c.pop
		var mil := g.units.values().filter(func(u): return u.owner == p.id and (u.kind == "melee" or u.kind == "ranged")).size()
		print("p", p.id, " ", RData.RACES[p.race].name, " alive ", p.alive, " cities ", cs.size(), " pop ", pop, " mil ", mil, " gold ", int(p.gold), " techs ", p.techs.size(), " civics ", p.civics.size(), " legacy ", p.tiers, " score ", int(g.score(p)))
	quit()
