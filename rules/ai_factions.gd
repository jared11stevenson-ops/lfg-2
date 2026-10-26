class_name AIFactions
extends RefCounted
## AI holdings with real raid parties. Acts ONLY from Rules.tick (never from apply, never when dt <= 0 or the match is over).
##  PEACE (dawn): farm, cook, mine, recruit, build (by persona), trade (traders), scout (fog-limited intel).
##  PURGE_ACTIVE: raiders/hoarders dispatch a PARTY ACTOR (kind "party") that marches over the hex map (A*, per-hex move cost, roads),
##  lays siege for SIEGE_SECS (garrison sorties hurt it; the player can kill it, reinforce, ram/ward, buy a truce), then resolves through
##  Conquest.resolve_capture / resolve_steal (conserving), and marches home carrying the loot. Survivors rejoin the garrison.
## Personas: raider (captures the best known weak target), hoarder (steals valuables with small parties, stockpiles),
##           trader (sells surplus/buys rations at merchants, hires mercenaries for the purge), turtle (walls/towers, double recruits, strong sorties).
## Targeting is fog-limited: a faction only knows holdings within VISION of its holdings (+tower vision) or PARTY_VISION of its parties,
## and plans from the garrison/defence snapshot taken when it last saw them (stale intel = failed raids).
const AI_PERIOD := 20.0
const ACT_COOLDOWN := 40.0
const RANGE := 14
const VISION := 8
const PARTY_VISION := 5
const HP_PER_TROOP := 6
const SIEGE_SECS := 14.0
const SORTIE_PERIOD := 3.0
const HARASS_PERIOD := 2.0
const MAX_PARTIES := 2
const MAX_DISPATCH := 3
const MAX_PATH_LEN := 36
const BUILD_ORDER: Dictionary = {
	"raider": ["lfg:building/wall", "lfg:building/barracks", "lfg:building/watchtower", "lfg:building/storehouse"],
	"hoarder": ["lfg:building/storehouse", "lfg:building/granary", "lfg:building/kitchen", "lfg:building/wall", "lfg:building/well"],
	"trader": ["lfg:building/storehouse", "lfg:building/kitchen", "lfg:building/sawmill", "lfg:building/watchtower"],
	"turtle": ["lfg:building/wall", "lfg:building/watchtower", "lfg:building/wall_stone", "lfg:building/barracks", "lfg:building/granary", "lfg:building/kitchen"]}
static var _routes: Dictionary = {}

## Fraction of a full-length day: parties, periods and sieges scale so a short test day still plays a whole purge.
static func tscale(state: MatchState) -> float:
	return clampf(state.day_seconds / 360.0, 0.1, 1.0)

static func period(state: MatchState) -> float:
	return AI_PERIOD * tscale(state)

static func parties_of(state: MatchState, fid: int) -> Array[int]:
	var out: Array[int] = []
	var ids: Array = state.actors.keys()
	ids.sort()
	for id in ids:
		var a: Dictionary = state.actors[id]
		if a["kind"] == "party" and (fid < 0 or int(a["faction"]) == fid):
			out.append(int(id))
	return out

static func has_parties(state: MatchState) -> bool:
	for a in state.actors.values():
		if a["kind"] == "party":
			return true
	return false

static func route(state: MatchState, from: Vector2i, to: Vector2i) -> Array[Vector2i]:
	var key: String = "%d:%d:%d" % [state.seed, HexGrid.index(from), HexGrid.index(to)]
	if _routes.has(key):
		var c: Array[Vector2i] = []
		c.assign(_routes[key])
		return c
	var w: Dictionary = state.world
	var p: Array[Vector2i] = HexGrid.find_path(from, to, func(h: Vector2i) -> float: return WorldGen.move_cost(w, h), 2500)
	if _routes.size() > 400:
		_routes.clear()
	_routes[key] = p.duplicate()
	return p

# ---------------------------------------------------------------- peace
static func dawn(state: MatchState, events: Array) -> void:
	var fids: Array = state.factions.keys()
	fids.sort()
	for fid in fids:
		var f: Dictionary = state.factions[fid]
		if not f["is_ai"] or not f["alive"]:
			continue
		var persona: String = String(f["persona"])
		for hid in state.holdings_of(fid):
			var h: Dictionary = state.holdings[hid]
			var n: int = 3 + 2 * int(h["garrison"]) + int(h["tier"]) + (2 if persona == "hoarder" else 0)
			var crop: String = "lfg:item/saltroot" if int(h["tier"]) >= 2 else "lfg:item/glowfruit"
			if Inv.room_for(h["store"], {crop: n}):
				Inv.add_all(h["store"], {crop: n})
			var mats: Dictionary = {"lfg:item/timber": 3 if persona == "trader" else 1}
			if int(h["tier"]) >= 1 or persona == "turtle" or persona == "trader":
				mats["lfg:item/stone"] = 2 if persona == "trader" else 1
			if Inv.room_for(h["store"], mats):
				Inv.add_all(h["store"], mats)
			var cooked: int = 0
			for item in ["lfg:item/glowfruit", "lfg:item/saltroot"]:
				var per: int = 2 if item == "lfg:item/glowfruit" else 3
				var out: int = 1 if item == "lfg:item/glowfruit" else 2
				var batches: int = Inv.count(h["store"], item) / per
				if batches > 0 and Inv.room_for(h["store"], {"lfg:item/ration": batches * out}):
					Inv.remove_all(h["store"], {item: batches * per})
					Inv.add_all(h["store"], {"lfg:item/ration": batches * out})
					cooked += batches * out
			if cooked > 0:
				events.append({"type": &"ai_farmed", "faction": fid, "ai": true, "holding": hid, "rations": cooked})
			var cap: int = 4 + 4 * int(h["tier"])
			var rec: int = 2 if persona == "turtle" else 1
			var comfy: bool = persona != "hoarder" or Inv.count(h["store"], "lfg:item/ration") >= 3 * maxi(1, int(h["garrison"]))
			if persona == "trader" and Inv.count(h["store"], "lfg:item/coin") < 3 * rec + 8:
				comfy = false          # traders keep a coin reserve for the warning-day hiring
			if comfy and int(h["garrison"]) < cap and Inv.count(h["store"], "lfg:item/coin") >= 3 * rec:
				Inv.remove_all(h["store"], {"lfg:item/coin": 3 * rec})
				h["garrison"] = mini(cap, int(h["garrison"]) + rec)
			if persona == "turtle" or int(state.clock["day"]) % 2 == 0:
				_build(state, int(fid), persona, int(hid), events)
		if persona == "trader":
			_trade(state, int(fid), events)
			if state.day_of_week() == 6:
				_hire(state, int(fid), events)
		scout(state, int(fid))

static func _build(state: MatchState, fid: int, persona: String, hid: int, events: Array) -> void:
	var h: Dictionary = state.holdings[hid]
	for bid in BUILD_ORDER.get(persona, []):
		var b: Dictionary = Content.building(String(bid))
		var bl: Array = h["buildings"]
		if b.has("upgrade_of"):
			if not bl.has(b["upgrade_of"]):
				continue
		else:
			var have: int = 0
			for x in bl:
				if Economy.group_of(Content.building(String(x))) == Economy.group_of(b):
					have += 1
			if have >= int(b["max"]):
				continue
		var cost: Dictionary = Economy.build_cost({}, b)
		if not Inv.has_all(h["store"], cost):
			continue
		if b.has("upgrade_of"):
			Inv.remove_all(h["store"], cost)
			bl[bl.find(b["upgrade_of"])] = b["id"]
			var sites: Dictionary = h.get("sites", {})
			for k in sites.keys():
				if sites[k] == b["upgrade_of"]:
					sites[k] = b["id"]
					break
		else:
			var ps: Variant = Economy.pick_site(state, h)
			if ps == null:
				continue
			Inv.remove_all(h["store"], cost)
			bl.append(b["id"])
			if not h.has("sites"):
				h["sites"] = {}
			h["sites"][Economy.site_key(ps)] = b["id"]
		events.append({"type": &"ai_built", "faction": fid, "ai": true, "holding": hid, "building": b["id"]})
		return

static func _trade(state: MatchState, fid: int, events: Array) -> void:
	var home: Dictionary = state.holdings.get(int(state.factions[fid]["home"]), {})
	if home.is_empty() or int(home["owner"]) != fid:
		return
	var best: int = -1
	var bd: int = 13
	for hid in state.holdings.keys():
		var m: Dictionary = state.holdings[hid]
		if m["merchant"] and int(m["owner"]) == -1:
			var d: int = HexGrid.distance(m["hex"], home["hex"])
			if d < bd:
				bd = d
				best = int(hid)
	if best == -1:
		return
	var mer: Dictionary = state.holdings[best]
	var st: Dictionary = home["store"]
	# sell surplus goods
	var sold: int = 0
	for item in ["lfg:item/saltroot", "lfg:item/timber", "lfg:item/stone", "lfg:item/glowfruit"]:
		var keep: int = 10 if item == "lfg:item/glowfruit" else 4
		var q: int = Inv.count(st, item) - keep
		if q <= 0:
			continue
		var pm: float = Economy.price_mult(mer, item)
		var unit: int = Economy.sell_price({}, item, pm)
		q = mini(q, Inv.count(mer["store"], "lfg:item/coin") / maxi(1, unit))
		q = mini(q, 12)
		if q > 0 and Inv.room_for(mer["store"], {item: q}) and Inv.room_for(st, {"lfg:item/coin": q * unit}):
			Economy._bump_price(mer, item, q, false)
			Inv.transfer(st, mer["store"], {item: q})
			Inv.transfer(mer["store"], st, {"lfg:item/coin": q * unit})
			sold += q
	# buy rations when short
	var bought: int = 0
	var need: int = Economy.persons(state, fid) * 2
	var have: int = Economy.rations_available(state, fid)
	if have < need:
		var pm2: float = Economy.price_mult(mer, "lfg:item/ration")
		var unit2: int = Economy.buy_price("lfg:item/ration", pm2)
		var q2: int = mini(mini(need - have, 8), Inv.count(st, "lfg:item/coin") / unit2)
		q2 = mini(q2, Inv.count(mer["store"], "lfg:item/ration"))
		if q2 > 0 and Inv.room_for(st, {"lfg:item/ration": q2}):
			Economy._bump_price(mer, "lfg:item/ration", q2, true)
			Inv.transfer(st, mer["store"], {"lfg:item/coin": q2 * unit2})
			Inv.transfer(mer["store"], st, {"lfg:item/ration": q2})
			bought = q2
	if sold > 0 or bought > 0:
		events.append({"type": &"ai_traded", "faction": fid, "by": fid, "ai": true, "holding": best, "sold": sold, "bought": bought})

# ---------------------------------------------------------------- fog / intel
static func vision_of(state: MatchState, h: Dictionary) -> int:
	var v: int = VISION + 2 * mini(state.week(), 4)      # factions learn the map as the weeks pass
	for b in h["buildings"]:
		v = maxi(v, int(Content.building(String(b)).get("vision", 0)) + 4)
	return v

## Refreshes what faction `fid` can currently see. Intel keeps the snapshot (garrison/defence/loot) from the last sighting.
static func scout(state: MatchState, fid: int) -> void:
	var f: Dictionary = state.factions[fid]
	var intel: Dictionary = f.get("intel", {})
	var srcs: Array = []
	for hid in state.holdings_of(fid):
		srcs.append([state.holdings[hid]["hex"], vision_of(state, state.holdings[hid])])
	for pid in parties_of(state, fid):
		srcs.append([state.actors[pid]["hex"], PARTY_VISION])
	var now: float = float(state.clock["elapsed"])
	var ids: Array = state.holdings.keys()
	ids.sort()
	for hid in ids:
		var h: Dictionary = state.holdings[hid]
		if int(h["owner"]) == fid:
			intel.erase(hid)
			continue
		var seen: bool = false
		for s in srcs:
			if HexGrid.distance(h["hex"], s[0]) <= int(s[1]):
				seen = true
				break
		if not seen:
			continue
		var best_item: String = ""
		var best_val: int = 0
		var bq: int = 0
		for k in h["store"].keys():
			if k == "lfg:item/coin":
				continue
			var q: int = mini(int(h["store"][k]), Conquest.STEAL_CAP)
			var v: int = Content.item_value(String(k)) * q
			if v > best_val or (v == best_val and String(k) < best_item):
				best_val = v
				best_item = String(k)
				bq = q
		intel[hid] = {"owner": int(h["owner"]), "garrison": int(h["garrison"]), "def": int(round(Conquest.defender_power(state, h))), "tier": int(h["tier"]),
			"item": best_item, "qty": bq, "val": best_val, "seen_t": now}
	f["intel"] = intel

static func _marked_near(state: MatchState, hex: Vector2i) -> bool:
	var p: Dictionary = state.player()
	return not p.is_empty() and p["alive"] and int(Combat.class_mod(p, "marked", 0)) > 0 and HexGrid.distance(p["hex"], hex) <= 8

# ---------------------------------------------------------------- purge: decisions
## One decision round. Returns the number of parties dispatched (<= MAX_DISPATCH). Called at purge start and every period().
static func purge_round(state: MatchState, events: Array) -> int:
	var acted: int = 0
	var now: float = float(state.clock["elapsed"])
	var fids: Array = state.factions.keys()
	fids.sort()
	# rotate the start so the same faction does not always get the dispatch slots
	var rot: int = int(now / maxf(period(state), 0.01)) % maxi(1, fids.size())
	fids = fids.slice(rot) + fids.slice(0, rot)
	for fid in fids:
		if acted >= MAX_DISPATCH:
			break
		var f: Dictionary = state.factions[fid]
		if not f["is_ai"] or not f["alive"]:
			continue
		var persona: String = String(f["persona"])
		if persona != "raider" and persona != "hoarder":
			continue
		if float(f.get("next_act", 0.0)) > now or parties_of(state, int(fid)).size() >= (1 if persona == "hoarder" else MAX_PARTIES):
			continue
		var home_id: int = int(f["home"])
		if not state.holdings.has(home_id) or int(state.holdings[home_id]["owner"]) != fid:
			var mine: Array[int] = state.holdings_of(fid)
			if mine.is_empty():
				continue
			home_id = mine[0]
			f["home"] = home_id
		scout(state, int(fid))
		if _plan(state, int(fid), persona, home_id, events):
			acted += 1
	return acted

static func _plan(state: MatchState, fid: int, persona: String, home_id: int, events: Array) -> bool:
	var f: Dictionary = state.factions[fid]
	var home: Dictionary = state.holdings[home_id]
	var now: float = float(state.clock["elapsed"])
	var truced: bool = float(f.get("truce_until", 0.0)) > now
	var cands: Array = []   # [score, hid]
	var intel: Dictionary = f.get("intel", {})
	var ids: Array = intel.keys()
	ids.sort()
	var spare: int = int(home["garrison"]) - 2
	for hid in ids:
		var e: Dictionary = intel[hid]
		var h: Dictionary = state.holdings.get(hid, {})
		if h.is_empty() or int(h["owner"]) == fid:
			continue
		if HexGrid.distance(h["hex"], home["hex"]) > RANGE + 2 * mini(state.week(), 4):
			continue
		if truced and int(h["owner"]) == 0:
			continue
		var bonus: float = 1.25 if _marked_near(state, h["hex"]) else 1.0
		if persona == "raider":
			var commit: int = mini(spare, 8)
			if commit < 2:
				continue
			var est: float = float(e["def"])
			var power: float = Conquest.attacker_power(state, {}, commit)
			if power < 1.3 * est:
				continue
			var value: float = float(e["val"]) + 6.0 * float(int(e["tier"]) + 1) + (4.0 if int(h["owner"]) >= 0 else 0.0)
			cands.append([value / maxf(est, 1.0) * bonus, hid])
		else:
			if spare < 1 or int(e["garrison"]) > 6 or int(e["qty"]) <= 0:
				continue
			var gain: float = float(e["val"]) - 2.0 * float(e["garrison"])
			if gain <= 0.0:
				continue
			cands.append([gain * bonus, hid])
	cands.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0] or (x[0] == y[0] and x[1] < y[1]))
	var tries: int = 0
	for c in cands:
		tries += 1
		if tries > 3:
			break
		var hid2: int = int(c[1])
		var e2: Dictionary = intel[hid2]
		if persona == "raider":
			var commit2: int = mini(spare, 8)
			if _dispatch(state, fid, home_id, hid2, "capture", commit2, "", 0, events):
				return true
		else:
			if _dispatch(state, fid, home_id, hid2, "steal", mini(2, spare), String(e2["item"]), int(e2["qty"]), events):
				return true
	return false

## Traders (warning day) pay a merchant town to hire up to 3 mercenaries per holding. The wage is transferred, not destroyed.
static func _hire(state: MatchState, fid: int, events: Array) -> void:
	var home: Dictionary = state.holdings.get(int(state.factions[fid]["home"]), {})
	if home.is_empty():
		return
	var mer: Dictionary = {}
	var bd: int = 13
	for m in state.holdings.values():
		if m["merchant"] and int(m["owner"]) == -1 and HexGrid.distance(m["hex"], home["hex"]) < bd:
			bd = HexGrid.distance(m["hex"], home["hex"])
			mer = m
	if mer.is_empty():
		return
	for hid in state.holdings_of(fid):
		var h: Dictionary = state.holdings[hid]
		var cap: int = 4 + 4 * int(h["tier"])
		var n: int = mini(mini(3, cap - int(h["garrison"])), Inv.count(h["store"], "lfg:item/coin") / 4)
		if n > 0 and Inv.room_for(mer["store"], {"lfg:item/coin": 4 * n}):
			Inv.transfer(h["store"], mer["store"], {"lfg:item/coin": 4 * n})
			h["garrison"] = int(h["garrison"]) + n
			events.append({"type": &"ai_hired", "faction": fid, "by": fid, "ai": true, "holding": hid, "count": n})

static func _dispatch(state: MatchState, fid: int, home_id: int, target_id: int, mission: String, troops: int, item: String, qty: int, events: Array) -> bool:
	var home: Dictionary = state.holdings[home_id]
	var target: Dictionary = state.holdings[target_id]
	if troops < 1:
		return false
	var path: Array[Vector2i] = route(state, home["hex"], target["hex"])
	if path.is_empty() or path.size() > MAX_PATH_LEN + 4 * mini(state.week(), 4):
		return false
	var f: Dictionary = state.factions[fid]
	var now: float = float(state.clock["elapsed"])
	home["garrison"] = int(home["garrison"]) - troops
	var pid: int = state.new_id()
	var p: Dictionary = Setup.make_actor(pid, "party", fid, "%s %s" % [f["name"], "Raiders" if mission == "capture" else "Thieves"], home["hex"], troops * HP_PER_TROOP, 2, 1, 0)
	p["speed_mult"] = MatchState.q(tscale(state))
	p["ai"] = {"state": "march", "mission": mission, "target": target_id, "home": home_id, "troops": troops, "item": item, "qty": qty,
		"warned": false, "retry": 0, "scout_t": now + 3.0, "hit_t": 0.0, "sortie_t": 0.0, "siege_end": 0.0}
	p["move"] = {"path": path, "acc": 0.0}
	state.actors[pid] = p
	f["next_act"] = MatchState.q(now + ACT_COOLDOWN * tscale(state))
	var eta: float = 0.0
	for h in path:
		eta += Movement.step_secs(state, p, h)
	events.append({"type": &"party_dispatched", "party": pid, "by": fid, "ai": true, "faction_name": f["name"], "from": home_id, "target": target_id,
		"mission": mission, "troops": troops, "eta": MatchState.q(eta), "hex": home["hex"]})
	return true

# ---------------------------------------------------------------- purge: parties each tick
static func warn_radius(h: Dictionary) -> int:
	var r: int = 3
	for b in h["buildings"]:
		r = maxi(r, int(Content.building(String(b)).get("vision", 0)))
	return r

static func troops_of(a: Dictionary) -> int:
	return maxi(0, (int(a["hp"]) + HP_PER_TROOP - 1) / HP_PER_TROOP)

static func party_step(state: MatchState, events: Array) -> void:
	var ids: Array = parties_of(state, -1)
	if ids.is_empty():
		return
	var now: float = float(state.clock["elapsed"])
	var ts: float = tscale(state)
	for id in ids:
		var a: Dictionary = state.actors[id]
		if not a["alive"]:
			state.actors.erase(id)
			continue
		var ai: Dictionary = a["ai"]
		var fid: int = int(a["faction"])
		if state.phase != &"PURGE_ACTIVE" or not state.factions[fid]["alive"]:
			_disband(state, a, events, "recalled")
			continue
		if now >= float(ai["scout_t"]):
			ai["scout_t"] = MatchState.q(now + 3.0 * ts + 0.5)
			scout(state, fid)
		var st: String = ai["state"]
		if st == "march":
			var t: Dictionary = state.holdings[int(ai["target"])]
			if int(t["owner"]) == fid:
				_go_home(state, a, events)
				continue
			var d: int = HexGrid.distance(a["hex"], t["hex"])
			if not bool(ai["warned"]) and int(t["owner"]) == 0 and d <= warn_radius(t):
				ai["warned"] = true
				events.append({"type": &"raid_warning", "party": id, "holding": t["id"], "by": fid, "ai": true, "mission": ai["mission"], "troops": troops_of(a),
					"hex": a["hex"], "distance": d})
			if d <= 1:
				ai["state"] = "siege"
				ai["siege_end"] = MatchState.q(now + SIEGE_SECS * ts)
				a["move"] = {}
				events.append({"type": &"party_arrived", "party": id, "holding": t["id"], "by": fid, "ai": true, "hex": a["hex"], "troops": troops_of(a)})
			elif (a["move"] as Dictionary).is_empty() and not Movement.rooted(state, a):
				ai["retry"] = int(ai["retry"]) + 1
				var path: Array[Vector2i] = route(state, a["hex"], t["hex"]) if int(ai["retry"]) <= 3 else []
				if path.is_empty():
					_go_home(state, a, events)
				else:
					a["move"] = {"path": path, "acc": 0.0}
		elif st == "siege":
			var t2: Dictionary = state.holdings[int(ai["target"])]
			if int(t2["owner"]) == fid:
				_go_home(state, a, events)
				continue
			_defend(state, a, events, now, ts)
			if not a["alive"]:
				continue
			if now >= float(ai["siege_end"]):
				_resolve(state, a, events)
		else: # return
			var home: Dictionary = state.holdings.get(int(ai["home"]), {})
			if home.is_empty() or int(home["owner"]) != fid:
				var mine: Array[int] = state.holdings_of(fid)
				if mine.is_empty():
					_disband(state, a, events, "homeless")
					continue
				ai["home"] = mine[0]
				home = state.holdings[mine[0]]
				a["move"] = {}
			if HexGrid.distance(a["hex"], home["hex"]) <= 1:
				_disband(state, a, events, "home")
			elif (a["move"] as Dictionary).is_empty():
				var rp: Array[Vector2i] = route(state, a["hex"], home["hex"])
				if rp.is_empty():
					_disband(state, a, events, "lost")
				else:
					a["move"] = {"path": rp, "acc": 0.0}

## Garrison sorties from every holding within 2 hexes (except the party's own) wound the party; the party harasses a nearby hostile leader.
static func _defend(state: MatchState, a: Dictionary, events: Array, now: float, ts: float) -> void:
	var ai: Dictionary = a["ai"]
	var fid: int = int(a["faction"])
	if now >= float(ai["sortie_t"]):
		ai["sortie_t"] = MatchState.q(now + SORTIE_PERIOD * ts + 0.5)
		var total: int = 0
		for h in state.holdings.values():
			if int(h["owner"]) == fid or int(h["garrison"]) < 2 or HexGrid.distance(h["hex"], a["hex"]) > 2:
				continue
			var per: float = 1.0
			if int(h["owner"]) >= 0 and state.factions[int(h["owner"])]["persona"] == "turtle":
				per = 2.0
			if Conquest._active(state, h, "rally"):
				per *= 1.4
			total += int(float(h["garrison"]) * per)
		if total > 0:
			events.append({"type": &"sortie", "party": a["id"], "damage": total, "by": fid})
			Combat.hurt(state, int(a["id"]), total, -1, events, "sortie")
			if not a["alive"]:
				return
	if now >= float(ai["hit_t"]):
		ai["hit_t"] = MatchState.q(now + HARASS_PERIOD * ts + 0.5)
		var p: Dictionary = state.player()
		if not p.is_empty() and p["alive"] and int(p["faction"]) != fid and HexGrid.distance(p["hex"], a["hex"]) <= 1 and not Combat.has_effect(state, p, "truce"):
			var dmg: int = maxi(1, 2 + troops_of(a) / 2 - int(Combat.def_of(state, p)))
			Combat.hurt(state, int(p["id"]), dmg, int(a["id"]), events, "raid_party")

static func _resolve(state: MatchState, a: Dictionary, events: Array) -> void:
	var ai: Dictionary = a["ai"]
	var fid: int = int(a["faction"])
	var tid: int = int(ai["target"])
	var troops: int = troops_of(a)
	if troops < 1:
		Combat.kill(state, int(a["id"]), -1, events)
		return
	if ai["mission"] == "capture":
		var won: bool = Conquest.resolve_capture(state, fid, int(a["id"]), tid, -1, troops, events)
		if won:
			a["hp"] = mini(int(a["hp"]), HP_PER_TROOP)     # troops stay as the new garrison; a courier carries the loot
			ai["troops"] = 0
		else:
			var lost: int = mini(troops, int(ceil(float(troops) * 0.6)))
			a["hp"] = (troops - lost) * HP_PER_TROOP
			ai["troops"] = troops - lost
			if int(a["hp"]) <= 0:
				a["hp"] = 0
				a["alive"] = false
				events.append({"type": &"actor_died", "actor": a["id"], "kind": "party", "faction": fid, "killer": -1, "hex": a["hex"], "items": {}, "items_to": "none"})
				return
	else:
		var item: String = String(ai["item"])
		var q: int = mini(int(ai["qty"]), Inv.count(state.holdings[tid]["store"], item))
		if q > 0:
			Conquest.resolve_steal(state, fid, int(a["id"]), tid, item, q, a["inv"], events)
		ai["troops"] = troops_of(a)
		if not a["alive"]:
			return
	_go_home(state, a, events, true)

static func _go_home(state: MatchState, a: Dictionary, events: Array, keep_troops: bool = false) -> void:
	var ai: Dictionary = a["ai"]
	if not keep_troops and ai["state"] != "return":
		ai["troops"] = troops_of(a)
	ai["state"] = "return"
	a["move"] = {}
	var fid: int = int(a["faction"])
	var home: Dictionary = state.holdings.get(int(ai["home"]), {})
	if home.is_empty() or int(home["owner"]) != fid:
		var mine: Array[int] = state.holdings_of(fid)
		if mine.is_empty():
			_disband(state, a, events, "homeless")
			return
		ai["home"] = mine[0]
		home = state.holdings[mine[0]]
	if (a["inv"] as Dictionary).is_empty() and int(ai.get("troops", 0)) <= 0:
		_disband(state, a, events, "spent")
		return
	if HexGrid.distance(a["hex"], home["hex"]) <= 1:
		_disband(state, a, events, "home")
		return
	var rp: Array[Vector2i] = route(state, a["hex"], home["hex"])
	if rp.is_empty():
		_disband(state, a, events, "lost")
		return
	a["move"] = {"path": rp, "acc": 0.0}
	events.append({"type": &"party_returning", "party": a["id"], "by": fid, "ai": true, "troops": int(ai.get("troops", 0)), "loot": a["inv"].duplicate()})

## Removes the party. Survivors rejoin a garrison and the loot lands in that store (overflow and orphaned loot drops on the ground). Conserving.
static func _disband(state: MatchState, a: Dictionary, events: Array, reason: String) -> void:
	var fid: int = int(a["faction"])
	var ai: Dictionary = a["ai"]
	var dest: Dictionary = state.holdings.get(int(ai["home"]), {})
	if dest.is_empty() or int(dest["owner"]) != fid:
		dest = {}
		var mine: Array[int] = state.holdings_of(fid)
		if not mine.is_empty():
			dest = state.holdings[mine[0]]
	var troops: int = int(ai.get("troops", 0)) if ai["state"] == "return" else troops_of(a)
	if not a["alive"]:
		troops = 0
	var loot: Dictionary = (a["inv"] as Dictionary).duplicate()
	var stored: Dictionary = {}
	if not dest.is_empty():
		stored = Conquest.move_fitting(a["inv"], dest["store"], loot)
		dest["garrison"] = int(dest["garrison"]) + troops
	else:
		troops = 0
	var rest: Dictionary = a["inv"]
	if not rest.is_empty():
		var k: String = MatchState.plot_key(a["hex"])
		var cur: Dictionary = state.drops.get(k, {})
		Inv.add_all(cur, rest)
		state.drops[k] = cur
		a["inv"] = {}
	state.actors.erase(int(a["id"]))
	events.append({"type": &"party_returned", "party": a["id"], "by": fid, "ai": true, "reason": reason, "troops": troops, "loot": stored})
