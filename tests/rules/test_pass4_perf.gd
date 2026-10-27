extends RulesTestBase
## CPU per tick stays under 3 ms on average with the pass 4 systems running: six companions at work, a guardian fight, ten new buildings producing.
## (Debug build, headless, shared CI box: a generous bound, not a benchmark. The numbers are printed.)

const BUDGET_US := 3000.0

func _avg_us(s: MatchState, ticks: int, dt: float) -> float:
	var t0: int = Time.get_ticks_usec()
	for i in range(ticks):
		Rules.tick(s, dt)
	return float(Time.get_ticks_usec() - t0) / float(ticks)

func _load_up(s: MatchState) -> void:
	var a: Dictionary = s.actors[1]
	a["max_hp"] = 99999
	a["hp"] = 99999
	for k in Content.companion_order():
		Companions.give(s, a, String(k), [])
		var c: Dictionary = Companions.find(a, String(k))
		c["post"] = "hold"
		c["hold"] = 1
		c["fed_until"] = 999
		c["fed"] = true
	for n in ["kennel", "seed_bank", "compost_heap", "spore_bed", "ward_stones", "rest_hall", "guardian_hall", "bastion", "foraging_den", "apiary", "alembic", "rift_anvil", "seed_press"]:
		(home(s)["buildings"] as Array).append("lfg:building/" + n)
	for i in range(6):
		var hx: Vector2i = neighbor_plot(s, i)
		s.plots[MatchState.plot_key(hx)] = {"crop": "lfg:crop/glowfruit", "age": 0, "watered": false, "dry_days": 0, "holding": 1}

func test_average_tick_under_three_milliseconds_in_peace() -> void:
	var s: MatchState = mk("lfg:class/judd", 11, {"day_seconds": 120.0})
	_load_up(s)
	var us: float = _avg_us(s, 1200, 1.0 / 30.0)
	print("pass4 perf: peace tick avg %.0f us" % us)
	check(us < BUDGET_US, "peace: %.0f us per tick (budget %.0f)" % [us, BUDGET_US])

func test_average_tick_under_three_milliseconds_through_dawns() -> void:
	var s: MatchState = mk("lfg:class/judd", 11, {"day_seconds": 6.0})      # a dawn every 6 s: companions work 200x more often than in play
	_load_up(s)
	var us: float = _avg_us(s, 1500, 0.1)
	print("pass4 perf: dawn-heavy tick avg %.0f us" % us)
	check(us < BUDGET_US, "dawns: %.0f us per tick (budget %.0f)" % [us, BUDGET_US])

func test_average_tick_under_three_milliseconds_in_a_guardian_fight() -> void:
	var s: MatchState = quiet()
	_load_up(s)
	var arena: Dictionary = {}
	for p in s.world["pois"]:
		if String(p["type"]) == "lfg:poi/arena_fungal_grove":
			arena = p
	s.actors[1]["hex"] = arena["hex"]
	cmd(s, "interact_poi", {"poi": arena["id"]})
	var boss: Dictionary = {}
	for e in s.actors.values():
		if e["kind"] == "enemy":
			boss = e
	boss["hp"] = 99999
	boss["max_hp"] = 99999
	var us: float = _avg_us(s, 1500, 0.1)
	print("pass4 perf: boss fight tick avg %.0f us (adds %d)" % [us, s.actors.size()])
	check(us < BUDGET_US, "boss fight: %.0f us per tick (budget %.0f)" % [us, BUDGET_US])
	check(boss["alive"], "the fight really ran")

func test_companion_dawn_and_panel_model_are_cheap() -> void:
	var s: MatchState = quiet()
	_load_up(s)
	var t0: int = Time.get_ticks_usec()
	for i in range(200):
		Companions.dawn(s, [])
	var dawn_us: float = float(Time.get_ticks_usec() - t0) / 200.0
	t0 = Time.get_ticks_usec()
	for i in range(200):
		Companions.panel_model(s, s.actors[1])
		Guardians.nearest_boss(s, s.actors[1])
	var view_us: float = float(Time.get_ticks_usec() - t0) / 200.0
	print("pass4 perf: Companions.dawn %.0f us, panel_model+nearest_boss %.0f us" % [dawn_us, view_us])
	check(dawn_us < BUDGET_US, "six companions at dawn: %.0f us" % dawn_us)
	check(view_us < BUDGET_US, "view models: %.0f us" % view_us)
