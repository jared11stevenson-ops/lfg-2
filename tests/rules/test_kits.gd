extends RulesTestBase
## Mechanics of the nine classes added in pass 1 (peace perk, purge ability, weakness).

func _ab(id: String) -> Dictionary:
	return {"ability": "lfg:ability/" + id}

func _freeze(s: MatchState, id: int) -> void:
	s.actors[id]["ai"]["state"] = "recovery"
	s.actors[id]["ai"]["t_rec"] = 1.0e9

func _enemy(s: MatchState, off: Vector2i, arch: String = "lfg:enemy/sporeling", frozen: bool = true) -> int:
	var id: int = Setup.spawn_enemy(s, arch, s.actors[1]["hex"] + off, false)
	if frozen:
		_freeze(s, id)
	return id

func _grove_hex(s: MatchState) -> Vector2i:
	for i in range(HexGrid.WIDTH * HexGrid.HEIGHT):
		var h: Vector2i = HexGrid.from_index(i)
		if int(s.world["terrain"][i]) == WorldGen.T_GROUND and WorldGen.biome_at(s.world, h) == "fungal_grove":
			return h
	return Vector2i(-9999, 0)

func _road_hex(s: MatchState) -> Vector2i:
	for i in range(HexGrid.WIDTH * HexGrid.HEIGHT):
		if int(s.world["road"][i]) == 1 and int(s.world["terrain"][i]) == WorldGen.T_GROUND:
			return HexGrid.from_index(i)
	return Vector2i(-9999, 0)

func _near_ai_home(s: MatchState, fid: int = 1) -> Dictionary:
	var h: Dictionary = s.holdings[int(s.factions[fid]["home"])]
	s.actors[1]["hex"] = h["hex"] + HexGrid.DIRS[0]
	return h

# ------------------------------------------------------------------ Tavi
func test_tavi_mine_yields_cools_down_and_is_exclusive() -> void:
	var s: MatchState = quiet("lfg:class/tavi")
	var p: Dictionary = s.actors[1]
	var j: MatchState = quiet("lfg:class/judd")
	eq(cmd(j, "use_ability", _ab("mine"))["error"], "unknown_ability", "Judd cannot mine")
	var biome: String = WorldGen.biome_at(s.world, p["hex"])
	var r: Dictionary = cmd(s, "use_ability", _ab("mine"))
	check(r["ok"], "mine: %s" % r["error"])
	var gained: int = Inv.count(p["inv"], "lfg:item/timber") + Inv.count(p["inv"], "lfg:item/stone")
	check(gained >= 3, "mining %s yields >=3 materials (%d)" % [biome, gained])
	eq(p["energy"], 92.0, "8 energy")
	eq(cmd(s, "use_ability", _ab("mine"))["error"], "cooldown", "12s cooldown")
	tick_all(s, 13.0, 1.0)
	check(cmd(s, "use_ability", _ab("mine"))["ok"], "mine again after cooldown")
	warp(s, 7, 0.7)
	p["cd"] = {}
	var before: String = snap(s)
	eq(cmd(s, "use_ability", _ab("mine"))["error"], "not_in_purge", "no mining in purge")
	eq(snap(s), before, "failed mine mutates nothing")

func test_tavi_sentinel_post_shoots_expires_and_is_unique() -> void:
	var s: MatchState = quiet("lfg:class/tavi")
	warp(s, 7, 0.7)
	var e: int = _enemy(s, Vector2i(2, 0))
	var r: Dictionary = cmd(s, "use_ability", {})
	check(r["ok"], "post: %s" % r["error"])
	eq(s.fx.size(), 1, "one post")
	eq(s.actors[1]["energy"], 75.0, "25 energy")
	var ev: Array = tick_all(s, 7.0, 1.0)
	check(count_type(ev, "fx_hit") >= 2, "turret fired (%d)" % count_type(ev, "fx_hit"))
	check(not s.actors[e]["alive"] or s.actors[e]["hp"] < 12, "enemy hurt by the post")
	tick_all(s, 25.0, 1.0)
	s.actors[1]["energy"] = 100.0
	var r2: Dictionary = cmd(s, "use_ability", {})
	check(r2["ok"], "second post after 30s: %s" % r2["error"])
	eq(s.fx.size(), 1, "max_active 1: oldest retired")
	var ev2: Array = tick_all(s, 50.0, 1.0)
	check(count_type(ev2, "fx_expired") >= 1 and s.fx.is_empty(), "post expires after 45s")

func test_tavi_is_slow_pip_is_fast_on_roads() -> void:
	var t: MatchState = quiet("lfg:class/tavi")
	var j: MatchState = quiet("lfg:class/judd")
	var p: MatchState = quiet("lfg:class/pip")
	var hx: Vector2i = t.actors[1]["hex"] + HexGrid.DIRS[0]
	for d in HexGrid.DIRS:
		var c: Vector2i = t.actors[1]["hex"] + d
		if int(t.world["road"][HexGrid.index(c)]) == 0 and WorldGen.move_cost(t.world, c) > 0.0:
			hx = c
			break
	var tj: float = Movement.step_secs(j, j.actors[1], hx)
	check(absf(Movement.step_secs(t, t.actors[1], hx) / tj - 1.35) < 0.01, "Tavi 35% slower")
	check(absf(Movement.step_secs(p, p.actors[1], hx) / tj - 0.9) < 0.01, "Pip 10% faster everywhere")
	var rd: Vector2i = _road_hex(j)
	check(rd.x != -9999, "world has roads")
	check(absf(Movement.step_secs(p, p.actors[1], rd) / Movement.step_secs(j, j.actors[1], rd) - 0.54) < 0.01, "Pip extra 40% on roads (0.9*0.6)")

# ------------------------------------------------------------------ Pip
func test_pip_carry_cap_blocks_hauling() -> void:
	var p: MatchState = quiet("lfg:class/pip")
	var j: MatchState = quiet("lfg:class/judd")
	for s in [p, j]:
		s.holdings[1]["store"]["lfg:item/ration"] = 100
	eq(Inv.carried(p.actors[1]), 18, "kit is 18 non-coin items")
	var before: String = snap(p)
	eq(cmd(p, "trade", {"holding": 1, "side": "withdraw", "item": "lfg:item/ration", "qty": 20})["error"], "no_room", "Pip cannot carry 38")
	eq(snap(p), before, "no mutation")
	check(cmd(p, "trade", {"holding": 1, "side": "withdraw", "item": "lfg:item/ration", "qty": 12})["ok"], "30 exactly fits")
	eq(Inv.carried(p.actors[1]), 30, "at cap")
	eq(cmd(p, "trade", {"holding": 1, "side": "withdraw", "item": "lfg:item/ration", "qty": 1})["error"], "no_room", "cap is hard")
	check(cmd(j, "trade", {"holding": 1, "side": "withdraw", "item": "lfg:item/ration", "qty": 20})["ok"], "Judd hauls 20")
	var n: Dictionary = {"lfg:item/coin": 500}
	give(p, 1, n)
	check(Inv.can_carry(p.actors[1], {"lfg:item/coin": 9000}), "coin has no weight")

func test_pip_dash_strikes_and_evades() -> void:
	var s: MatchState = quiet("lfg:class/pip")
	var p: Dictionary = s.actors[1]
	var e: int = _enemy(s, Vector2i(4, 0), "lfg:enemy/rootbrute")
	var to: Vector2i = p["hex"] + Vector2i(3, 0)
	eq(cmd(s, "use_ability", {"to": to + Vector2i(1, 0)})["error"], "too_far", "range 3")
	eq(cmd(s, "use_ability", {"to": p["hex"]})["error"], "too_far", "must move")
	eq(cmd(s, "use_ability", {"to": to, "target": 9999})["error"], "bad_target", "bad target")
	var hp0: int = s.actors[e]["hp"]
	var r: Dictionary = cmd(s, "use_ability", {"to": to, "target": e})
	check(r["ok"], "dash: %s" % r["error"])
	eq(p["hex"], to, "dashed")
	check(s.actors[e]["hp"] < hp0, "struck")
	eq(count_type(r["events"], "ability_used"), 1, "event")
	eq(p["energy"], 80.0, "20 energy")
	var ev: Array = []
	Combat.hurt(s, 1, 10, -1, ev, "t")
	eq(p["hp"], 75 - 6, "evade: -40% damage")
	eq(cmd(s, "use_ability", {"to": to + Vector2i(-1, 0)})["error"], "cooldown", "14s cooldown")
	tick_all(s, 5.0, 1.0)
	Combat.hurt(s, 1, 10, -1, ev, "t")
	eq(p["hp"], 75 - 6 - 10, "evade over after 4s")

func test_pip_dash_rejects_people_in_peace_and_blocked_hexes() -> void:
	var s: MatchState = quiet("lfg:class/pip")
	var ai_leader: int = int(s.factions[1]["leader"])
	var p: Dictionary = s.actors[1]
	var to: Vector2i = p["hex"] + Vector2i(2, 0)
	s.actors[ai_leader]["hex"] = to
	eq(cmd(s, "use_ability", {"to": to})["error"], "occupied", "cannot land on someone")
	s.actors[ai_leader]["hex"] = to + Vector2i(1, 0)
	var before: String = snap(s)
	eq(cmd(s, "use_ability", {"to": to, "target": ai_leader})["error"], "not_purge", "no striking people in peace")
	eq(snap(s), before, "nothing changed")
	check(cmd(s, "use_ability", {"to": to})["ok"], "plain dash works in peace")

# ------------------------------------------------------------------ Sable
func test_sable_is_noisy_judd_is_not() -> void:
	var sa: MatchState = quiet("lfg:class/sable")
	var j: MatchState = quiet("lfg:class/judd")
	for s in [sa, j]:
		var id: int = Setup.spawn_enemy(s, "lfg:enemy/sporeling", s.actors[1]["hex"] + Vector2i(9, 0), false)
		var e: Dictionary = s.actors[id]
		var found: Dictionary = EnemyAI._nearest_target(s, e, 7)
		if s == sa:
			check(not found.is_empty(), "sporeling (aggro 7) notices noisy Sable at 9")
		else:
			check(found.is_empty(), "but not Judd at 9")

func test_sable_snares_arm_root_and_cap_at_three() -> void:
	var s: MatchState = quiet("lfg:class/sable")
	var p: Dictionary = s.actors[1]
	var base: Vector2i = p["hex"]
	var hexes: Array[Vector2i] = []
	for i in range(4):
		p["hex"] = base + Vector2i(i, 0)
		p["cd"] = {}
		p["energy"] = 100.0
		var r: Dictionary = cmd(s, "use_ability", {})
		check(r["ok"], "snare %d: %s" % [i, r["error"]])
		hexes.append(p["hex"])
	eq(Fx.active_of(s, 1, "trap").size(), 3, "at most 3 traps (oldest retired)")
	for f in s.fx:
		check(f["hex"] != hexes[0], "oldest trap gone")
	p["hex"] = base + Vector2i(0, 5)
	var ens: int = Setup.spawn_enemy(s, "lfg:enemy/sporeling", hexes[3], false)
	_freeze(s, ens)
	var ev0: Array = tick_all(s, 1.0, 0.5)
	eq(count_type(ev0, "trap_sprung"), 0, "unarmed for 3s")
	var ev: Array = tick_all(s, 3.0, 0.5)
	eq(count_type(ev, "trap_sprung"), 1, "sprung once armed")
	check(Combat.has_effect(s, s.actors[ens], "rooted"), "enemy rooted")
	eq(s.actors[ens]["hp"], 4, "8 damage to a 12hp sporeling")
	eq(Fx.active_of(s, 1, "trap").size(), 2, "trap consumed")

func test_sable_track_and_hunt_meat() -> void:
	var s: MatchState = quiet("lfg:class/sable")
	var p: Dictionary = s.actors[1]
	eq(cmd(s, "use_ability", _ab("track"))["error"], "no_targets", "nothing to track")
	var e: int = _enemy(s, Vector2i(2, 0))
	var r: Dictionary = cmd(s, "use_ability", _ab("track"))
	check(r["ok"], "track: %s" % r["error"])
	var tracked: Array = r["events"][0]["tracked"]
	eq(tracked.size(), 1, "one creature tracked")
	eq(tracked[0]["id"], e, "it is the sporeling")
	var ev: Array = []
	Combat.kill(s, e, 1, ev)
	eq(Inv.count(p["inv"], "lfg:item/game_meat"), 2, "1 hunter meat + 1 tracking bonus")
	var rat0: int = Inv.count(p["inv"], "lfg:item/ration")
	check(cmd(s, "craft", {"recipe": "lfg:recipe/ration_game", "qty": 1})["ok"], "meat cooks to a ration")
	eq(Inv.count(p["inv"], "lfg:item/ration"), rat0 + 1, "2 meat -> 1 ration")
	var j: MatchState = quiet("lfg:class/judd")
	var e2: int = _enemy(j, Vector2i(2, 0))
	Combat.kill(j, e2, 1, [])
	eq(Inv.count(j.actors[1]["inv"], "lfg:item/game_meat"), 0, "Judd gets no meat")

# ------------------------------------------------------------------ Quill
func test_quill_trades_better_than_judd() -> void:
	var q: MatchState = quiet("lfg:class/quill")
	var j: MatchState = quiet("lfg:class/judd")
	check(Economy.buy_price("lfg:item/ration", 1.0, q.actors[1]) < Economy.buy_price("lfg:item/ration", 1.0, j.actors[1]), "buys cheaper")
	check(Economy.sell_price(q.actors[1], "lfg:item/tonic") > Economy.sell_price(j.actors[1], "lfg:item/tonic"), "sells dearer")
	var mer: int = -1
	for hid in q.holdings.keys():
		if q.holdings[hid]["merchant"] and q.holdings[hid]["owner"] == -1:
			mer = hid
			break
	for s in [q, j]:
		s.actors[1]["hex"] = s.holdings[mer]["hex"]
		give(s, 1, {"lfg:item/coin": 100})
	var cq: int = Inv.count(q.actors[1]["inv"], "lfg:item/coin")
	var cj: int = Inv.count(j.actors[1]["inv"], "lfg:item/coin")
	check(cmd(q, "trade", {"holding": mer, "side": "buy", "item": "lfg:item/ration", "qty": 5})["ok"], "Quill buys")
	check(cmd(j, "trade", {"holding": mer, "side": "buy", "item": "lfg:item/ration", "qty": 5})["ok"], "Judd buys")
	check(cq - Inv.count(q.actors[1]["inv"], "lfg:item/coin") < cj - Inv.count(j.actors[1]["inv"], "lfg:item/coin"), "Quill paid less")
	var ev: Array = []
	Combat.hurt(q, 1, 10, -1, ev, "t")
	eq(q.actors[1]["hp"], 70 - 13, "fragile: +25% damage")

func test_quill_truce_flag_hides_blocks_violence_and_buys_peace() -> void:
	var s: MatchState = quiet("lfg:class/quill")
	var p: Dictionary = s.actors[1]
	warp(s, 7, 0.7)
	var e: int = _enemy(s, Vector2i(2, 0))
	var ai_leader: int = int(s.factions[1]["leader"])
	s.actors[ai_leader]["hex"] = p["hex"] + HexGrid.DIRS[0]
	check(not EnemyAI._nearest_target(s, s.actors[e], 7).is_empty(), "enemy sees Quill before the flag")
	var r: Dictionary = cmd(s, "use_ability", {})
	check(r["ok"], "truce: %s" % r["error"])
	check(EnemyAI._nearest_target(s, s.actors[e], 7).is_empty(), "enemy ignores flagged Quill")
	eq(cmd(s, "attack", {"target": ai_leader})["error"], "truce_active", "cannot attack under the flag")
	eq(cmd(s, "capture", {"holding": 1})["error"], "truce_active", "cannot capture")
	eq(cmd(s, "steal", {"holding": 1, "item": "lfg:item/ration", "qty": 1})["error"], "truce_active", "cannot steal")
	tick_all(s, 16.0, 1.0)
	check(not EnemyAI._nearest_target(s, s.actors[e], 7).is_empty(), "flag expired")
	# buying a faction truce needs reach and coin
	p["cd"] = {}
	var before: String = snap(s)
	eq(cmd(s, "use_ability", {"faction": 1})["error"], "too_far", "must stand at their holding")
	eq(snap(s), before, "no mutation")
	var h: Dictionary = _near_ai_home(s)
	p["inv"]["lfg:item/coin"] = 4
	before = snap(s)
	eq(cmd(s, "use_ability", {"faction": 1})["error"], "insufficient_items", "needs the 10 coin gift")
	eq(snap(s), before, "no mutation")
	p["inv"]["lfg:item/coin"] = 20
	var t0: Dictionary = Inv.world_totals(s)
	var r2: Dictionary = cmd(s, "use_ability", {"faction": 1})
	check(r2["ok"], "faction truce: %s" % r2["error"])
	eq(Inv.world_totals(s), t0, "gift conserved")
	check(float(s.factions[1]["truce_until"]) > float(s.clock["elapsed"]), "faction truce recorded")
	eq(cmd(s, "use_ability", {"faction": 0})["error"], "cooldown", "cooldown first")
	check(h["id"] > 0, "sanity")

# ------------------------------------------------------------------ Forge
func test_forge_builds_cheaper_and_is_slow() -> void:
	var f: MatchState = quiet("lfg:class/forge")
	var j: MatchState = quiet("lfg:class/judd")
	var wall: Dictionary = Content.building("lfg:building/wall")
	eq(Economy.build_cost(f.actors[1], wall), {"lfg:item/timber": 3, "lfg:item/stone": 2}, "Forge wall 3t 2s (rounded up)")
	eq(Economy.build_cost(j.actors[1], wall), {"lfg:item/timber": 4, "lfg:item/stone": 2}, "Judd wall 4t 2s")
	for s in [f, j]:
		give(s, 1, {"lfg:item/timber": 3, "lfg:item/stone": 2})
	check(cmd(f, "build", {"holding": 1, "building": "lfg:building/wall"})["ok"], "Forge builds with 3 timber")
	eq(cmd(j, "build", {"holding": 1, "building": "lfg:building/wall"})["error"], "insufficient_items", "Judd cannot with 3")
	var hx: Vector2i = f.actors[1]["hex"] + HexGrid.DIRS[0]
	check(Movement.step_secs(f, f.actors[1], hx) > Movement.step_secs(j, j.actors[1], hx), "Forge slow")

func test_forge_ram_breaks_defences_and_boosts_capture() -> void:
	var s: MatchState = quiet("lfg:class/forge")
	var p: Dictionary = s.actors[1]
	var h: Dictionary = _near_ai_home(s)
	h["buildings"] = ["lfg:building/wall", "lfg:building/watchtower"]
	eq(cmd(s, "use_ability", {"holding": h["id"]})["error"], "not_purge", "only in purge")
	warp(s, 7, 0.7)
	var dp0: float = Conquest.defender_power(s, h)
	p["hex"] = h["hex"] + Vector2i(3, 0)
	eq(cmd(s, "use_ability", {"holding": h["id"]})["error"], "too_far", "must be adjacent")
	p["hex"] = h["hex"] + HexGrid.DIRS[0]
	eq(cmd(s, "use_ability", {"holding": 1})["error"], "already_yours", "not your own")
	var ap0: float = Conquest.attacker_power(s, p, 4)
	var r: Dictionary = cmd(s, "use_ability", {"holding": h["id"]})
	check(r["ok"], "ram: %s" % r["error"])
	eq((h["buildings"] as Array).size(), 1, "strongest defence (watchtower 3 vs wall 4) removes the wall")
	check(not (h["buildings"] as Array).has("lfg:building/wall"), "wall gone")
	check(Conquest.defender_power(s, h) < dp0 * 0.8, "breach weakens defence (%f -> %f)" % [dp0, Conquest.defender_power(s, h)])
	check(Conquest.attacker_power(s, p, 4) > ap0 * 1.4, "next capture +50%")
	tick_all(s, 31.0, 1.0)
	check(Conquest.attacker_power(s, p, 4) <= ap0 * 1.01, "ram effect expires")
	eq(cmd(s, "use_ability", {"holding": h["id"]})["error"], "cooldown", "45s cooldown")

# ------------------------------------------------------------------ Nyx
func test_nyx_grows_groves_twice_as_fast() -> void:
	var n: MatchState = quiet("lfg:class/nyx")
	var j: MatchState = quiet("lfg:class/judd")
	var g: Vector2i = _grove_hex(n)
	check(g.x != -9999, "world has a grove")
	var key: String = MatchState.plot_key(g)
	for s in [n, j]:
		s.plots[key] = {"crop": "lfg:crop/sporebean", "age": 0, "watered": false, "dry_days": 0, "holding": 1}
		Farming.dawn_crops(s, [])
	eq(n.plots[key]["age"], 2, "Nyx grove plot +2/day")
	eq(j.plots[key]["age"], 1, "Judd +1/day")
	var meadow: Vector2i = n.actors[1]["hex"] + HexGrid.DIRS[0]
	n.plots[MatchState.plot_key(meadow)] = {"crop": "lfg:crop/glowfruit", "age": 0, "watered": true, "dry_days": 0, "holding": 1}
	Farming.dawn_crops(n, [])
	eq(n.plots[MatchState.plot_key(meadow)]["age"], 1, "no bonus outside groves")

func test_nyx_sickly_outside_groves_and_swarm_radius() -> void:
	var s: MatchState = quiet("lfg:class/nyx")
	var p: Dictionary = s.actors[1]
	var g: Vector2i = _grove_hex(s)
	var atk_off: float = Combat.atk_of(s, p)
	var def_off: float = Combat.def_of(s, p)
	p["hex"] = g
	check(Combat.atk_of(s, p) > atk_off, "stronger in a grove")
	check(absf(atk_off / Combat.atk_of(s, p) - 0.75) < 0.001, "-25% outside")
	p["hex"] = s.actors[1]["hex"]
	p["hex"] = g + Vector2i(0, 0)
	p["energy"] = 0.0
	tick_all(s, 4.0, 1.0)
	var in_grove: float = p["energy"]
	p["hex"] = Vector2i(0, 0)
	for hid in s.holdings.keys():
		if WorldGen.biome_at(s.world, s.holdings[hid]["hex"]) != "fungal_grove":
			p["hex"] = s.holdings[hid]["hex"]
			break
	p["energy"] = 0.0
	tick_all(s, 4.0, 1.0)
	check(p["energy"] <= in_grove * 0.55, "half energy regen off-grove (%f vs %f)" % [p["energy"], in_grove])
	check(def_off >= 0.0, "def sane")

func test_nyx_spore_swarm_poisons_hostiles_only() -> void:
	var s: MatchState = quiet("lfg:class/nyx")
	var p: Dictionary = s.actors[1]
	warp(s, 7, 0.7)
	p["hex"] = _grove_hex(s)
	var e1: int = Setup.spawn_enemy(s, "lfg:enemy/rootbrute", p["hex"] + Vector2i(3, 0), false)
	var e2: int = Setup.spawn_enemy(s, "lfg:enemy/rootbrute", p["hex"] + Vector2i(3, 1), false)
	var far: int = Setup.spawn_enemy(s, "lfg:enemy/rootbrute", p["hex"] + Vector2i(-4, 0), false)
	for id in [e1, e2, far]:
		_freeze(s, id)
	eq(cmd(s, "use_ability", {"at": p["hex"] + Vector2i(5, 0)})["error"], "too_far", "range 4")
	var r: Dictionary = cmd(s, "use_ability", {"at": p["hex"] + Vector2i(3, 0)})
	check(r["ok"], "swarm: %s" % r["error"])
	check(WorldGen.biome_at(s.world, p["hex"] + Vector2i(3, 0)) != "", "biome known")
	tick_all(s, 9.0, 1.0)
	var hp1: int = s.actors[e1]["hp"]
	check(hp1 < 60, "centre enemy poisoned (%d)" % hp1)
	eq(s.actors[far]["hp"], 60, "outside untouched")
	eq(s.actors[1]["hp"], s.actors[1]["max_hp"], "caster untouched")
	check(s.fx.is_empty(), "cloud dissipates after 8s")

# ------------------------------------------------------------------ Rook
func test_rook_upkeep_discount_and_marked_weakness() -> void:
	var r: MatchState = quiet("lfg:class/rook")
	var j: MatchState = quiet("lfg:class/judd")
	for s in [r, j]:
		s.holdings[1]["garrison"] = 10
	eq(Economy.persons(j, 0), 11, "Judd 1+10")
	eq(Economy.persons(r, 0), 10, "Rook 1+round(9.0): upkeep 0.9 since pass 3b")
	var at9: int = Setup.spawn_enemy(r, "lfg:enemy/sporeling", r.actors[1]["hex"] + Vector2i(9, 0), false)
	var at10: int = Setup.spawn_enemy(r, "lfg:enemy/sporeling", r.actors[1]["hex"] + Vector2i(10, 0), false)
	check(not EnemyAI._nearest_target(r, r.actors[at9], 7).is_empty(), "marked: aggro 7 reaches 9")
	check(EnemyAI._nearest_target(r, r.actors[at10], 7).is_empty(), "but not 10")
	var jp: int = Setup.spawn_enemy(j, "lfg:enemy/sporeling", j.actors[1]["hex"] + Vector2i(8, 0), false)
	check(EnemyAI._nearest_target(j, j.actors[jp], 7).is_empty(), "Judd at 8 is not noticed")

func test_rook_rally_boosts_defence_attack_and_dispatch() -> void:
	var s: MatchState = quiet("lfg:class/rook")
	var p: Dictionary = s.actors[1]
	warp(s, 7, 0.7)
	var h1: Dictionary = s.holdings[1]
	var far: Dictionary = s.holdings[int(s.factions[1]["home"])]
	var dp0: float = Conquest.defender_power(s, h1)
	var atk0: float = Combat.atk_of(s, p)
	var r: Dictionary = cmd(s, "use_ability", {})
	check(r["ok"], "rally: %s" % r["error"])
	check(absf(Conquest.defender_power(s, h1) / dp0 - 1.4) < 0.001, "+40% defence at home")
	check(absf(Combat.atk_of(s, p) / atk0 - 1.25) < 0.001, "+25% attack")
	check(not Conquest._active(s, far, "rally"), "far holdings are not rallied")
	eq(r["events"][0]["holdings"], [1], "event lists rallied holdings")
	var base: float = Conquest.attacker_power(s, {}, 6)
	var boosted: float = Conquest.attacker_power(s, {}, 6, 1.25)
	check(boosted > base, "rallied troops hit harder")
	tick_all(s, 21.0, 1.0)
	check(not Conquest._active(s, h1, "rally"), "rally ends after 20s")
	eq(cmd(s, "use_ability", {})["error"], "cooldown", "60s cooldown")

# ------------------------------------------------------------------ Dune
func test_dune_gadgets_and_cheap_gadget_buildings() -> void:
	var d: MatchState = quiet("lfg:class/dune")
	var j: MatchState = quiet("lfg:class/judd")
	for s in [d, j]:
		give(s, 1, {"lfg:item/timber": 1, "lfg:item/stone": 1})
	eq(cmd(j, "craft", {"recipe": "lfg:recipe/gadget"})["error"], "class_required", "only tinkers")
	check(cmd(d, "craft", {"recipe": "lfg:recipe/gadget"})["ok"], "Dune crafts")
	eq(Inv.count(d.actors[1]["inv"], "lfg:item/gadget"), 5, "2 kit + 3 crafted")
	var well: Dictionary = Content.building("lfg:building/well")
	eq(Economy.build_cost(d.actors[1], well), {"lfg:item/timber": 2, "lfg:item/stone": 2}, "half-price well")
	eq(Economy.build_cost(j.actors[1], well), {"lfg:item/timber": 3, "lfg:item/stone": 4}, "full price for Judd")
	var wall: Dictionary = Content.building("lfg:building/wall")
	eq(Economy.build_cost(d.actors[1], wall), {"lfg:item/timber": 4, "lfg:item/stone": 2}, "walls are not gadgets")
	var ev: Array = []
	Combat.hurt(d, 1, 10, -1, ev, "t")
	eq(d.actors[1]["hp"], 80 - 13, "weak armour +25%")

func test_dune_cache_hides_items_conserves_and_recovers() -> void:
	var s: MatchState = quiet("lfg:class/dune")
	var p: Dictionary = s.actors[1]
	give(s, 1, {"lfg:item/ration": 10})
	var t0: Dictionary = Inv.world_totals(s)
	var before: String = snap(s)
	eq(cmd(s, "use_ability", {"items": {"lfg:item/ration": 13}})["error"], "too_many_items", "max 12")
	eq(cmd(s, "use_ability", {"items": {"lfg:item/ration": 99}})["error"], "too_many_items", "99 is too many")
	eq(cmd(s, "use_ability", {"items": {"lfg:item/mushroom": 1}})["error"], "insufficient_items", "cannot cache what you lack")
	eq(cmd(s, "use_ability", {})["error"], "bad_bundle", "needs items")
	eq(snap(s), before, "failed attempts mutate nothing")
	var r: Dictionary = cmd(s, "use_ability", {"items": {"lfg:item/ration": 8, "lfg:item/coin": 4}})
	check(r["ok"], "cache: %s" % r["error"])
	var t1: Dictionary = Inv.world_totals(s)
	var want: Dictionary = t0.duplicate()
	Inv.remove_all(want, {"lfg:item/gadget": 1})
	eq(t1, want, "only the gadget is spent; cached goods still counted")
	eq(Inv.count(p["inv"], "lfg:item/ration"), 8, "16-8 left in the pack")
	var hex: Vector2i = p["hex"]
	eq(cmd(s, "use_ability", {"items": {"lfg:item/ration": 1}})["error"], "cooldown", "cooldown first")
	# another faction cannot take it; the owner digs it up
	var other: int = int(s.factions[1]["leader"])
	s.actors[other]["hex"] = hex
	check(Fx.cache_at(s, 0, hex) and not Fx.cache_at(s, 1, hex), "cache belongs to faction 0")
	check(Fx.recover_cache(s, s.actors[other], hex, [])  == "nothing_to_harvest", "rival finds nothing")
	var rec: Dictionary = cmd(s, "harvest", {"hex": hex})
	check(rec["ok"], "recover: %s" % rec["error"])
	eq(Inv.count(p["inv"], "lfg:item/ration"), 16, "all back")
	eq(Inv.world_totals(s), want, "conserved after recovery")
	check(s.fx.is_empty(), "cache removed")

func test_dune_cache_limit_and_gadget_cost() -> void:
	var s: MatchState = quiet("lfg:class/dune")
	var p: Dictionary = s.actors[1]
	give(s, 1, {"lfg:item/gadget": 5, "lfg:item/ration": 20})
	var base: Vector2i = p["hex"]
	for i in range(3):
		p["hex"] = base + Vector2i(0, 0) + HexGrid.DIRS[i]
		p["cd"] = {}
		p["energy"] = 100.0
		check(cmd(s, "use_ability", {"items": {"lfg:item/ration": 1}})["ok"], "cache %d" % i)
	p["hex"] = base + HexGrid.DIRS[3]
	p["cd"] = {}
	eq(cmd(s, "use_ability", {"items": {"lfg:item/ration": 1}})["error"], "cache_limit", "3 caches max")
	p["hex"] = base + HexGrid.DIRS[0]
	eq(cmd(s, "use_ability", {"items": {"lfg:item/ration": 1}})["error"], "occupied", "one per hex")

# ------------------------------------------------------------------ Halo
func test_halo_is_a_pacifist_to_people_only() -> void:
	var s: MatchState = quiet("lfg:class/halo")
	var p: Dictionary = s.actors[1]
	warp(s, 7, 0.7)
	var ai_leader: int = int(s.factions[1]["leader"])
	s.actors[ai_leader]["hex"] = p["hex"] + HexGrid.DIRS[0]
	var before: String = snap(s)
	eq(cmd(s, "attack", {"target": ai_leader})["error"], "pacifist", "no attacking people")
	eq(cmd(s, "capture", {"holding": 5})["error"], "pacifist", "no capture")
	eq(cmd(s, "steal", {"holding": 5, "item": "lfg:item/ration", "qty": 1})["error"], "pacifist", "no stealing")
	eq(snap(s), before, "nothing mutated")
	var e: int = _enemy(s, HexGrid.DIRS[3])
	var r: Dictionary = cmd(s, "attack", {"target": e})
	check(r["ok"], "wild creatures are fair game: %s" % r["error"])

func test_halo_bless_boosts_yield_feeds_garrison_and_expires() -> void:
	var s: MatchState = quiet("lfg:class/halo")
	var p: Dictionary = s.actors[1]
	var hx: Vector2i = s.holdings[1]["hex"] + HexGrid.DIRS[0]
	s.plots[MatchState.plot_key(hx)] = {"crop": "lfg:crop/glowfruit", "age": 2, "watered": false, "dry_days": 0, "holding": 1}
	var plain: MatchState = quiet("lfg:class/judd")
	plain.plots[MatchState.plot_key(hx)] = {"crop": "lfg:crop/glowfruit", "age": 2, "watered": false, "dry_days": 0, "holding": 1}
	var base_yield: int = int(Content.crop("lfg:crop/glowfruit")["yield"]) + int(Content.crop("lfg:crop/glowfruit")["biome_bonus"].get(WorldGen.biome_at(s.world, hx), 0))
	eq(cmd(s, "use_ability", {"ability": "lfg:ability/bless", "holding": s.holdings_of(1)[0]})["error"], "not_yours", "only own holdings (a rival's stays theirs)")
	eq(cmd(s, "use_ability", {"ability": "lfg:ability/bless", "holding": 5})["error"], "too_far", "an unowned village must be in reach (pass 3b: Halo's hamlets)")
	eq(Economy.persons(s, 0), 4, "1 + garrison 3 before blessing")
	var r: Dictionary = cmd(s, "use_ability", {"ability": "lfg:ability/bless", "holding": 1})
	check(r["ok"], "bless: %s" % r["error"])
	eq(Economy.persons(s, 0), 1, "blessed garrison eats nothing")
	eq(cmd(s, "use_ability", {"ability": "lfg:ability/bless", "holding": 1})["error"], "cooldown", "cooldown")
	p["cd"] = {}
	eq(cmd(s, "use_ability", {"ability": "lfg:ability/bless", "holding": 1})["error"], "already_blessed", "no stacking")
	check(cmd(s, "harvest", {"hex": hx})["ok"], "harvest")
	eq(Inv.count(p["inv"], "lfg:item/glowfruit"), base_yield + 1, "+1 yield on blessed land")
	warp(s, 3, 0.1)
	eq(Economy.persons(s, 0), 1, "still blessed on day 3 (cast day 1, 2 days)")
	warp(s, 4, 0.1)
	eq(Economy.persons(s, 0), 4, "blessing over on day 4")
	p["cd"] = {}
	check(cmd(s, "use_ability", {"ability": "lfg:ability/bless", "holding": 1})["ok"], "can bless again once it lapsed")

func test_halo_ward_shields_people_and_holdings() -> void:
	var s: MatchState = quiet("lfg:class/halo")
	var p: Dictionary = s.actors[1]
	warp(s, 7, 0.7)
	var h: Dictionary = s.holdings[1]
	var dp0: float = Conquest.defender_power(s, h)
	var sc0: float = Conquest.steal_chance(s, {}, h)
	var r: Dictionary = cmd(s, "use_ability", {})
	check(r["ok"], "ward: %s" % r["error"])
	check(absf(Conquest.defender_power(s, h) / dp0 - 1.5) < 0.001, "+50% defence")
	check(Conquest.steal_chance(s, {}, h) < sc0, "harder to rob")
	var ev: Array = []
	Combat.hurt(s, 1, 10, -1, ev, "t")
	eq(p["hp"], 95 - 6, "-40% damage")
	tick_all(s, 16.0, 1.0)
	Combat.hurt(s, 1, 10, -1, ev, "t")
	eq(p["hp"], 95 - 6 - 10, "ward ends after 15s")
	check(absf(Conquest.defender_power(s, h) - dp0) < 0.01, "holding back to normal")
