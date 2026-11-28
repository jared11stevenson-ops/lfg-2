extends SceneTree
## Headless bot playthrough: godot --headless --script tools/playtest.gd -- <player> <seed> <days>
var sim: BCSim
var battles_played := 0
var aggressive := false
func _init():
	var a := OS.get_cmdline_user_args()
	var pl := int(a[0]) if a.size() > 0 else 2
	var sd := int(a[1]) if a.size() > 1 else 1
	var days := int(a[2]) if a.size() > 2 else 120
	aggressive = a.size() > 3
	sim = BCSim.new(sd)
	sim.set_player(pl)
	sim.tactical_battle.connect(_on_battle)
	sim.game_over.connect(func(w, k): print("GAME OVER winner=", w, " kind=", k, " day=", sim.day))
	var last_day := 0
	var steps := 0
	while sim.day <= days and not sim.game_over_flag:
		if sim.pending_battle == null: sim.step(0.1)
		steps += 1
		if sim.day != last_day:
			last_day = sim.day
			_bot_turn(pl)
		if steps > 2000000: break
	var me: BCSim.Civ = sim.civs[pl]
	print("end day ", sim.day, " pop ", me.citizens.size(), " houses ", me.houses, " tech ", me.tech, " barracks ", me.barracks, " allies ", me.allies.keys(), " battles_played ", battles_played, " alive_others ", sim.civs.filter(func(c): return c.alive).size() - 1)
	print("wonder ", me.wonder_started, " ", me.wonder, " stock ", me.stock)
	quit()

func _on_battle(p):
	var b := BCBattle.new(sim, p)
	b.auto_finish()
	battles_played += 1
	sim.resolve_tactical(b.survivors(0), b.survivors(1), b.all_citizens(1), b.attacker_wins)

func _bot_turn(pl: int) -> void:
	var me: BCSim.Civ = sim.civs[pl]
	if sim.day == 2: print(sim.act_policy("scholar").msg)
	var tries := 0
	while sim.ap > 0 and tries < 8:
		tries += 1
		var r: Dictionary
		if aggressive and sim.day > 6 and tries % 2 == 1 and sim.soldiers_of(me).size() >= 3:
			var tt: int = me.links[tries % me.links.size()]
			r = sim.act_diplo("raid", tt)
		elif me.houses < 9 and me.citizens.size() >= sim.capacity(me) - 4: r = sim.act_build("house")
		elif me.tech >= 5 and not me.wonder_started: r = sim.act_build("wonder")
		else:
			var t: int = me.links[tries % me.links.size()]
			if me.rel[t] >= 55 and not me.allies.has(t): r = sim.act_diplo("ally", t)
			elif me.rel[t] > -20: r = sim.act_diplo("trade" if tries % 2 == 0 else "envoy", t)
			else: r = sim.act_diplo("gift", t)
		if r.ok and sim.day % 10 == 0: print("day ", sim.day, " ", r.msg)
