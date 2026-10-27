class_name AILeaders
extends RefCounted
## Class-aware brain for AI (and bot-run) faction leaders. The persona biases WHAT the faction does (AIFactions); the class decides HOW the leader
## acts: peace routine (dawn), Purge ability use with real arguments, joining raids/defence, tribute. Every ability goes through Abilities.use
## (the same code path as a player's use_ability command). Table: data/ai_kits.json. Bounded work: only runs at dawn, at the Purge start and
## inside sieges (a few calls per party per harass tick).
const TRIBUTE_RANGE := 24
const HOME_SYNC := 1

static func kit(l: Dictionary) -> Dictionary:
	return Content.ai_kit(String(l.get("class_id", "")))

static func leader_of(state: MatchState, fid: int) -> Dictionary:
	var l: Dictionary = Standing.leader_of(state, fid)
	return l if (not l.is_empty() and l["alive"]) else {}

static func tscale(state: MatchState) -> float:
	return clampf(state.day_seconds / 360.0, 0.1, 1.0)

static func home_of(state: MatchState, fid: int) -> Dictionary:
	var f: Dictionary = state.factions[fid]
	var h: Dictionary = state.holdings.get(int(f["home"]), {})
	if h.is_empty() or int(h["owner"]) != fid:
		var mine: Array[int] = state.holdings_of(fid)
		if mine.is_empty():
			return {}
		h = state.holdings[mine[0]]
		f["home"] = h["id"]
	return h

## Ordinary ability use with an optional per-ability attempt/failure log (state.opts.ai_log, used by the simulation harness).
static func cast(state: MatchState, l: Dictionary, args: Dictionary, events: Array) -> String:
	var res: String = Abilities.use(state, l, args, events)
	if bool(state.opts.get("ai_log", false)):
		var lg: Dictionary = state.sim_acc.get("ablog", {})
		var key: String = String(args.get("ability", "")).get_slice("/", 1)
		var row: Dictionary = lg.get(key, {})
		var rk: String = "ok" if res == "" else res
		row[rk] = int(row.get(rk, 0)) + 1
		lg[key] = row
		state.sim_acc["ablog"] = lg
	return res

# ------------------------------------------------------------------ peace (dawn)
static func dawn(state: MatchState, events: Array) -> void:
	var fids: Array = state.factions.keys()
	fids.sort()
	for fid in fids:
		var f: Dictionary = state.factions[fid]
		if not f["is_ai"] or not f["alive"]:
			continue
		var l: Dictionary = leader_of(state, int(fid))
		var home: Dictionary = home_of(state, int(fid))
		if l.is_empty() or home.is_empty():
			continue
		if int(l["ai"].get("party", -1)) == -1:
			l["hex"] = home["hex"]
		_recover_cache(state, l, home, events)
		_peace_routine(state, int(fid), l, home, events)

## Moves what one ability use produced out of the leader's pack into the home store, times `mult` (a whole working day of the same chore).
static func _deposit_gain(l: Dictionary, before: Dictionary, home: Dictionary, mult: int) -> void:
	var gain: Dictionary = {}
	for k in (l["inv"] as Dictionary).keys():
		var d: int = int(l["inv"][k]) - int(before.get(k, 0))
		if d > 0:
			gain[k] = d
	Inv.remove_all(l["inv"], gain)
	var fit: Dictionary = {}
	for k in gain.keys():
		var q: int = mini(int(gain[k]) * mult, Inv.MAX_QTY - Inv.count(home["store"], k))
		if q > 0:
			fit[k] = q
	Inv.add_all(home["store"], fit)

static func _peace_routine(state: MatchState, fid: int, l: Dictionary, home: Dictionary, events: Array) -> void:
	var k: Dictionary = kit(l)
	match String(k.get("peace", "none")):
		"mine":
			var b: Dictionary = (l["inv"] as Dictionary).duplicate()
			if cast(state, l, {"ability": "lfg:ability/mine"}, events) == "":
				_deposit_gain(l, b, home, 3)
		"forage":
			var b2: Dictionary = (l["inv"] as Dictionary).duplicate()
			if cast(state, l, {"ability": "lfg:ability/forage"}, events) == "":
				_deposit_gain(l, b2, home, 3)
		"bless":
			if state.day_of_week() % 2 == 1:
				for hid in state.holdings_of(fid):
					var h: Dictionary = state.holdings[hid]
					if not Economy.blessed(state, h) and HexGrid.distance(l["hex"], h["hex"]) <= ClassKits.BLESS_RANGE:
						cast(state, l, {"ability": "lfg:ability/bless", "holding": hid}, events)
						break
		"tonic":
			var st: Dictionary = home["store"]
			var n: int = mini(3, mini(Inv.count(st, "lfg:item/mushroom"), Inv.count(st, "lfg:item/glowfruit")))
			if n > 0:
				Inv.remove_all(st, {"lfg:item/mushroom": n, "lfg:item/glowfruit": n})
				if int(l["hp"]) < int(l["max_hp"]):
					Combat.heal(l, 25)
					n -= 1
				if n > 0 and Inv.room_for(st, {Economy.COIN: 6 * n}):
					Inv.add_all(st, {Economy.COIN: 6 * n})      # the rest are sold to the NPC markets
		"gadgets":
			var st2: Dictionary = home["store"]
			if Inv.count(st2, "lfg:item/gadget") < 4 and Inv.has_all(st2, {"lfg:item/timber": 1, "lfg:item/stone": 1}):
				Inv.remove_all(st2, {"lfg:item/timber": 1, "lfg:item/stone": 1})
				Inv.add_all(st2, {"lfg:item/gadget": 3})
		"hunt":
			var meat: int = 2 * int(Combat.class_mod(l, "hunt_meat", 0))
			if meat > 0 and Inv.room_for(home["store"], {"lfg:item/game_meat": meat}):
				Inv.add_all(home["store"], {"lfg:item/game_meat": meat})
		"trade":
			var fence: int = int(round((float(Combat.class_mod(l, "sell_mult", 1.0)) - 1.0) * 10.0))
			if fence > 0 and Inv.room_for(home["store"], {Economy.COIN: fence}):
				Inv.add_all(home["store"], {Economy.COIN: fence})

# ------------------------------------------------------------------ Purge start: tribute, caches
static func purge_start(state: MatchState, events: Array) -> void:
	var fids: Array = state.factions.keys()
	fids.sort()
	for fid in fids:
		var f: Dictionary = state.factions[fid]
		if not f["is_ai"] or not f["alive"]:
			continue
		var l: Dictionary = leader_of(state, int(fid))
		var home: Dictionary = home_of(state, int(fid))
		if l.is_empty() or home.is_empty():
			continue
		_tribute(state, int(fid), l, home, events)
		if String(kit(l).get("cast", "")) == "cache":
			_stash(state, l, home, events)

static func _tribute(state: MatchState, fid: int, l: Dictionary, home: Dictionary, events: Array) -> void:
	var f: Dictionary = state.factions[fid]
	var k: Dictionary = kit(l)
	var diplomat: bool = int((k.get("bias", {}) as Dictionary).get("broker", 0)) > 0
	var persona: String = String(f["persona"])
	if persona == "raider" and not diplomat:
		return
	if int(f.get("tribute_week", -1)) == state.week():
		return
	var gift: int = 10 if String(k.get("role", "")) == "diplomat" else 15
	if Inv.count(home["store"], Economy.COIN) < gift + 6:
		return
	var best: int = -1
	var bd: int = 1 << 30
	var ids: Array = state.factions.keys()
	ids.sort()
	for gid in ids:
		var g: Dictionary = state.factions[gid]
		if int(gid) == fid or not g["alive"] or not g["is_ai"] or Standing.truced(state, fid, int(gid)):
			continue
		var gp: String = String(g["persona"])
		if gp != "raider" and gp != "hoarder":
			continue
		var gh: Dictionary = state.holdings.get(int(g["home"]), {})
		if gh.is_empty() or int(gh["owner"]) != int(gid):
			continue
		var d: int = HexGrid.distance(gh["hex"], home["hex"]) * (1 if gp == "raider" else 2)
		if d < bd and HexGrid.distance(gh["hex"], home["hex"]) <= TRIBUTE_RANGE:
			bd = d
			best = int(gid)
	if best == -1:
		return
	var gh2: Dictionary = state.holdings[int(state.factions[best]["home"])]
	var secs: float = (150.0 if String(k.get("role", "")) == "diplomat" else 100.0) * tscale(state)
	if PurgeActions.sign_truce(state, fid, best, int(gh2["id"]), home["store"], gift, secs) == "":
		f["tribute_week"] = state.week()
		events.append({"type": &"truce_signed", "actor": l["id"], "faction": best, "by": fid, "holding": gh2["id"], "ai": true,
			"until": state.factions[fid]["truces"][best]})

## Dune: stash a ration reserve in a hidden cache before the Purge (a real Fx cache via the ability), recovered at dawn.
static func _stash(state: MatchState, l: Dictionary, home: Dictionary, events: Array) -> void:
	var st: Dictionary = home["store"]
	var q: int = mini(8, Inv.count(st, Economy.RATION))
	if q < 4 or Inv.count(st, "lfg:item/gadget") < 1:
		return
	Inv.transfer(st, l["inv"], {Economy.RATION: q, "lfg:item/gadget": 1})
	var ab_hex: Vector2i = l["hex"]
	if cast(state, l, {"ability": "lfg:ability/cache", "items": {Economy.RATION: q}}, events) != "":
		Inv.transfer(l["inv"], st, {Economy.RATION: q, "lfg:item/gadget": 1})
	else:
		l["ai"]["cache_hex"] = ab_hex

static func _recover_cache(state: MatchState, l: Dictionary, home: Dictionary, events: Array) -> void:
	if not l["ai"].has("cache_hex"):
		return
	var hx: Vector2i = l["ai"]["cache_hex"]
	l["ai"].erase("cache_hex")
	var before: Dictionary = (l["inv"] as Dictionary).duplicate()
	if Fx.recover_cache(state, l, hx, events) == "":
		var gain: Dictionary = {}
		for k in (l["inv"] as Dictionary).keys():
			var d: int = int(l["inv"][k]) - int(before.get(k, 0))
			if d > 0:
				gain[k] = d
		Conquest.move_fitting(l["inv"], home["store"], gain)

# ------------------------------------------------------------------ raids: the leader marches with the party and can die
static func wants_to_join(state: MatchState, fid: int, l: Dictionary, mission: String, troops: int) -> bool:
	if l.is_empty() or int(l["ai"].get("party", -1)) != -1:
		return false
	var k: Dictionary = kit(l)
	if not bool(k.get("joins_raid", false)) or mission == "scout" or mission == "supply":
		return false
	if mission == "capture" and troops < 3:
		return false
	return float(l["hp"]) >= 0.7 * float(l["max_hp"])

static func join(state: MatchState, l: Dictionary, party: Dictionary) -> void:
	l["ai"]["party"] = party["id"]
	party["ai"]["leader"] = l["id"]
	l["hex"] = party["hex"]
	l["move"] = {}

## The leader returns to the home holding (or dies with the party's fate); called by AIFactions._disband.
static func release(state: MatchState, party: Dictionary, home_hex: Vector2i) -> void:
	var lid: int = int(party["ai"].get("leader", -1))
	if lid == -1:
		return
	var l: Dictionary = state.actors.get(lid, {})
	party["ai"]["leader"] = -1
	if l.is_empty():
		return
	l["ai"]["party"] = -1
	if l["alive"]:
		l["hex"] = home_hex

static func follow(state: MatchState, party: Dictionary) -> void:
	var lid: int = int(party["ai"].get("leader", -1))
	if lid == -1:
		return
	var l: Dictionary = state.actors.get(lid, {})
	if l.is_empty() or not l["alive"]:
		party["ai"]["leader"] = -1
		return
	l["hex"] = party["hex"]

# ------------------------------------------------------------------ sieges: melee exchange + class kit
static func _free_neighbor(state: MatchState, foe_hex: Vector2i, from_hex: Vector2i, rng: int) -> Variant:
	for n in HexGrid.neighbors(foe_hex):
		if WorldGen.move_cost(state.world, n) <= 0.0 or HexGrid.distance(from_hex, n) > rng:
			continue
		var taken: bool = false
		for o in state.actors.values():
			if o["alive"] and o["hex"] == n and o["kind"] != "enemy":
				taken = true
				break
		if not taken:
			return n
	return null

## One leader acts against `foe` (an adjacent hostile actor or {}). `ctx` = {holding:int} for siege abilities. Returns nothing; all effects via Rules code.
static func siege_cast(state: MatchState, l: Dictionary, foe: Dictionary, ctx: Dictionary, events: Array) -> void:
	if l.is_empty() or not l["alive"] or not l["is_ai"]:
		return
	var k: Dictionary = kit(l)
	var which: String = String(k.get("cast", "none"))
	var hpf: float = float(l["hp"]) / maxf(1.0, float(l["max_hp"]))
	var has_foe: bool = not foe.is_empty() and foe["alive"]
	match which:
		"guard":
			if has_foe and hpf < 0.9:
				cast(state, l, {"ability": "lfg:ability/guard"}, events)
		"rage":
			if has_foe and hpf > 0.45:
				cast(state, l, {"ability": "lfg:ability/rage"}, events)
		"plague_cloud":
			if has_foe:
				cast(state, l, {"ability": "lfg:ability/plague_cloud"}, events)
		"sentinel_post":
			if has_foe:
				cast(state, l, {"ability": "lfg:ability/sentinel_post"}, events)
		"snare":
			if has_foe:
				cast(state, l, {"ability": "lfg:ability/snare"}, events)
		"field_dressing":
			if hpf < 0.75:
				cast(state, l, {"ability": "lfg:ability/field_dressing", "target": l["id"]}, events)
		"pickpocket":
			if has_foe and not (foe["inv"] as Dictionary).is_empty():
				cast(state, l, {"ability": "lfg:ability/pickpocket", "target": foe["id"]}, events)
		"dash":
			if has_foe and HexGrid.distance(l["hex"], foe["hex"]) <= 1:
				var to: Variant = _free_neighbor(state, foe["hex"], l["hex"], 3)
				if to != null:
					cast(state, l, {"ability": "lfg:ability/dash", "to": to, "target": foe["id"]}, events)
		"spore_swarm":
			if has_foe:
				cast(state, l, {"ability": "lfg:ability/spore_swarm", "at": foe["hex"]}, events)
		"rally":
			cast(state, l, {"ability": "lfg:ability/rally"}, events)
		"ward":
			if has_foe:
				cast(state, l, {"ability": "lfg:ability/ward"}, events)
		"siege_ram":
			if ctx.has("holding"):
				cast(state, l, {"ability": "lfg:ability/siege_ram", "holding": ctx["holding"]}, events)

## Leader-on-leader exchange used by AIFactions._defend: returns the victim list it touched (for tests).
static func melee(state: MatchState, attacker: Dictionary, victim: Dictionary, events: Array) -> void:
	if attacker.is_empty() or victim.is_empty() or not attacker["alive"] or not victim["alive"]:
		return
	if not Combat.ready(state, attacker, "attack"):
		return
	Combat.set_cd(state, attacker, "attack", 1.0)
	Combat.hurt(state, int(victim["id"]), Combat.calc_damage(state, attacker, victim), int(attacker["id"]), events, "leader_duel")

## At each settle every living leader recovers a share of its health (the player already did).
static func recover(state: MatchState) -> void:
	for f in state.factions.values():
		if not f["alive"]:
			continue
		var l: Dictionary = state.actors.get(int(f["leader"]), {})
		if not l.is_empty() and l["alive"] and l["kind"] == "ai_leader":
			Combat.heal(l, int(int(l["max_hp"]) * 0.3))
