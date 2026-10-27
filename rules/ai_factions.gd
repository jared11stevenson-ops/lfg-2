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
const MAX_PARTIES := 2      # at the start; max_parties() grows with the weeks
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
	var scarce: float = Standing.prod_mult(state)
	for fid in fids:
		var f: Dictionary = state.factions[fid]
		if not f["is_ai"] or not f["alive"]:
			continue
		var persona: String = String(f["persona"])
		var lead: Dictionary = Standing.leader_of(state, int(fid))
		if not lead.is_empty() and not lead["alive"]:
			lead = {}
		var weak_st: int = int(Standing.cfg()["stability"]["weak"])
		for hid in state.holdings_of(fid):
			var h: Dictionary = state.holdings[hid]
			var n: int = 3 + 2 * int(h["garrison"]) + int(h["tier"]) + (2 if persona == "hoarder" else 0)
			if not lead.is_empty():
				n += 2 * int(Combat.class_mod(lead, "yield_bonus", 0))
				if int(Combat.class_mod(lead, "grove_growth", 0)) > 0 and WorldGen.biome_at(state.world, h["hex"]) == "fungal_grove":
					n = int(float(n) * 1.5)
			n += Standing.yield_bonus(state, h) * 2
			n = maxi(1, int(float(n) * scarce * (0.5 if int(h.get("stab", 100)) < weak_st else 1.0)))
			var crop: String = "lfg:item/saltroot" if int(h["tier"]) >= 2 else "lfg:item/glowfruit"
			if Inv.room_for(h["store"], {crop: n}):
				Inv.add_all(h["store"], {crop: n})
				Standing.note_output(state, int(fid), {crop: n})
			var mats: Dictionary = {"lfg:item/timber": 3 if persona == "trader" else 1}
			if int(h["tier"]) >= 1 or persona == "turtle" or persona == "trader":
				mats["lfg:item/stone"] = 2 if persona == "trader" else 1
			if Inv.room_for(h["store"], mats):
				Inv.add_all(h["store"], mats)
			var cooked: int = 0
			var cbonus: int = int(Combat.class_mod(lead, "ration_bonus", 0)) if not lead.is_empty() else 0
			for item in ["lfg:item/glowfruit", "lfg:item/saltroot", "lfg:item/game_meat"]:
				var per: int = 3 if item == "lfg:item/saltroot" else 2
				var out: int = 2 if item == "lfg:item/saltroot" else 1
				var batches: int = Inv.count(h["store"], item) / per
				if batches > 0 and Inv.room_for(h["store"], {"lfg:item/ration": batches * (out + cbonus)}):
					Inv.remove_all(h["store"], {item: batches * per})
					Inv.add_all(h["store"], {"lfg:item/ration": batches * (out + cbonus)})
					cooked += batches * (out + cbonus)
			if cooked > 0:
				events.append({"type": &"ai_farmed", "faction": fid, "ai": true, "holding": hid, "rations": cooked})
			salvage(state, h)
			var cap: int = Standing.garrison_cap(state, h)
			var rec: int = 2 if persona == "turtle" else 1
			var comfy: bool = persona != "hoarder" or Inv.count(h["store"], "lfg:item/ration") >= 3 * maxi(1, int(h["garrison"]))
			if persona == "trader" and Inv.count(h["store"], "lfg:item/coin") < 3 * rec + 8:
				comfy = false          # traders keep a coin reserve for the warning-day hiring
			var reserve: int = 9 if (persona != "raider" and state.day_of_week() >= 4 and int(hid) == int(f["home"])) else 0      # tribute money for the Purge
			if comfy and int(h["garrison"]) < cap and Inv.count(h["store"], "lfg:item/coin") >= 3 * rec + reserve:
				Inv.remove_all(h["store"], {"lfg:item/coin": 3 * rec})
				h["garrison"] = mini(cap, int(h["garrison"]) + rec)
			if persona == "turtle" or int(state.clock["day"]) % 2 == 0:
				_build(state, int(fid), persona, int(hid), events)
		if persona == "trader" or String(lead.get("class_id", "")) == "lfg:class/quill":
			_trade(state, int(fid), events)
			if state.day_of_week() == 6 and persona == "trader":
				_hire(state, int(fid), events)
		scout(state, int(fid))
	AILeaders.dawn(state, events)

## AI factions pick up anything left lying near their holdings (loot of beaten raiders, ashmarrow).
static func salvage(state: MatchState, h: Dictionary) -> void:
	if state.drops.is_empty():
		return
	for k in state.drops.keys().duplicate():
		var parts: PackedStringArray = (k as String).split(",")
		if HexGrid.distance(Vector2i(int(parts[0]), int(parts[1])), h["hex"]) <= 3:
			Conquest.move_fitting(state.drops[k], h["store"], state.drops[k].duplicate())
			if (state.drops[k] as Dictionary).is_empty():
				state.drops.erase(k)

static func _build(state: MatchState, fid: int, persona: String, hid: int, events: Array) -> void:
	var h: Dictionary = state.holdings[hid]
	var lead: Dictionary = Standing.leader_of(state, fid)
	if not lead.is_empty() and not lead["alive"]:
		lead = {}
	var order: Array = (BUILD_ORDER.get(persona, []) as Array).duplicate()
	if Standing.rank_of(state, fid) >= 2:
		order.append_array(["lfg:building/shrine"])
	if Standing.rank_of(state, fid) >= 3:
		order.append_array(["lfg:building/greenhouse"])
	for bid in order:
		var b: Dictionary = Content.building(String(bid))
		if not Standing.rank_ok(state, fid, int(b.get("rank", 0))):
			continue
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
		var cost: Dictionary = Economy.build_cost(lead, b)
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
	var tl: Dictionary = Standing.leader_of(state, fid)
	if not tl.is_empty() and not tl["alive"]:
		tl = {}
	# sell surplus goods
	var sold: int = 0
	for item in ["lfg:item/saltroot", "lfg:item/timber", "lfg:item/stone", "lfg:item/glowfruit"]:
		var keep: int = 10 if item == "lfg:item/glowfruit" else 4
		var q: int = Inv.count(st, item) - keep
		if q <= 0:
			continue
		var pm: float = Economy.price_mult(mer, item)
		var unit: int = Economy.sell_price(tl, item, pm)
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
		var unit2: int = Economy.buy_price("lfg:item/ration", pm2, tl)
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
	var v: int = VISION + 2 * mini(state.week(), 8)      # factions learn the map as the weeks pass
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

static func max_parties(state: MatchState) -> int:
	return mini(4, MAX_PARTIES + state.week() / 12)

static func max_dispatch(state: MatchState) -> int:
	var e: Dictionary = Standing.cfg()["escalation"]
	return mini(int(e["dispatch_cap"]), int(e["dispatch_base"]) + state.week() / int(e["dispatch_week_div"]))

## Party size grows with the weeks (each Purge is larger than the last).
static func party_cap(state: MatchState) -> int:
	var e: Dictionary = Standing.cfg()["escalation"]
	return mini(int(e["party_cap"]), int(e["party_cap_base"]) + state.week() / int(e["party_week_div"]))

## The persona the faction acts as: passive personas that have grown strong turn ambitious later (the way out of a permanent stalemate).
static func effective_persona(state: MatchState, fid: int) -> String:
	var f: Dictionary = state.factions[fid]
	var p: String = String(f["persona"])
	var l: Dictionary = Standing.leader_of(state, fid)
	if not l.is_empty() and int(Combat.class_mod(l, "pacifist", 0)) > 0:
		return "turtle"          # a pacifist class never raids, whatever the persona says
	if p != "raider" and state.week() >= 6 and Standing.rank_of(state, fid) >= 3:
		return "raider"
	if p != "raider" and state.week() >= 8:
		for hid in state.holdings_of(fid):
			if int(state.holdings[hid]["garrison"]) >= 16:
				return "raider"      # a fat standing army does not sit idle forever
	return p

# ---------------------------------------------------------------- purge: decisions
## One decision round. Returns the number of parties dispatched (<= max_dispatch). Called at purge start and every period().
static func purge_round(state: MatchState, events: Array) -> int:
	var acted: int = 0
	var now: float = float(state.clock["elapsed"])
	var fids: Array = state.factions.keys()
	fids.sort()
	# rotate the start so the same faction does not always get the dispatch slots
	var rot: int = int(now / maxf(period(state), 0.01)) % maxi(1, fids.size())
	fids = fids.slice(rot) + fids.slice(0, rot)
	var limit: int = max_dispatch(state)
	for fid in fids:
		if acted >= limit:
			break
		var f: Dictionary = state.factions[fid]
		if not f["is_ai"] or not f["alive"]:
			continue
		var persona: String = effective_persona(state, int(fid))
		if float(f.get("next_act", 0.0)) > now:
			continue
		var np: int = parties_of(state, int(fid)).size()
		var raid_cap: int = 1 if persona == "hoarder" else max_parties(state)
		if persona != "raider" and persona != "hoarder":
			raid_cap = 0
		var lead0: Dictionary = Standing.leader_of(state, int(fid))
		var pacifist: bool = not lead0.is_empty() and int(Combat.class_mod(lead0, "pacifist", 0)) > 0
		if pacifist:
			raid_cap = 0
		elif raid_cap == 0 and state.week() >= 3 and (_bias(state, int(fid), "capture") >= 2 or _bias(state, int(fid), "steal") >= 2):
			raid_cap = 1       # the class, not the persona, decides: a warlord or a thief raids even in a trader's or turtle's cloak
		if np >= max_parties(state):
			continue
		var home_id: int = int(f["home"])
		if not state.holdings.has(home_id) or int(state.holdings[home_id]["owner"]) != fid:
			var mine: Array[int] = state.holdings_of(fid)
			if mine.is_empty():
				continue
			home_id = mine[0]
			f["home"] = home_id
		scout(state, int(fid))
		var did: bool = false
		if np < raid_cap:
			did = _plan(state, int(fid), persona, home_id, events)
		if not did and np == 0:
			did = _plan_support(state, int(fid), persona, home_id, events)
		if did:
			acted += 1
	return acted

static func _bias(state: MatchState, fid: int, key: String) -> int:
	var l: Dictionary = Standing.leader_of(state, fid)
	if l.is_empty():
		return 0
	return int((AILeaders.kit(l).get("bias", {}) as Dictionary).get(key, 0))

static func _plan(state: MatchState, fid: int, persona: String, home_id: int, events: Array) -> bool:
	var order: Array = ["capture", "steal"] if persona == "raider" else ["steal", "capture"]
	# staging holdings: the home plus the best-garrisoned holdings (a raider with six holdings does not raid from its weakest)
	var stage: Array[int] = [home_id]
	for hid in state.holdings_of(fid):
		if hid != home_id and int(state.holdings[hid]["garrison"]) >= 5 and stage.size() < 7:
			stage.append(hid)
	for sid in stage:
		for m in order:
			if m == "steal" and persona == "raider" and _bias(state, fid, "steal") < 1:
				continue        # raiders only fall back on theft when their class is a thief's
			if m == "steal" and persona != "raider" and persona != "hoarder" and _bias(state, fid, "steal") < 2:
				continue
			if m == "capture" and persona != "raider" and _bias(state, fid, "capture") < 2:
				continue        # thieving personas only take holdings when their class is a warlord's
			if _try(state, fid, m, sid, events):
				return true
	return false

## Decapitation: can a party of `commit` kill the leader at its own holding during one siege? (leaders are killable; a dead leader eliminates the faction)
static func _strike_ok(state: MatchState, h: Dictionary, commit: int) -> bool:
	var of: int = int(h["owner"])
	if of < 0 or int(state.factions[of]["home"]) != int(h["id"]):
		return false
	var v: Dictionary = state.actors.get(int(state.factions[of]["leader"]), {})
	if v.is_empty() or not v["alive"] or HexGrid.distance(v["hex"], h["hex"]) > 1:
		return false
	var ticks: float = SIEGE_SECS / (HARASS_PERIOD + 0.5 / tscale(state))
	var g: float = float(h["garrison"])
	var per: float = float(maxi(1, 2 + commit - int(v["def"]))) * (1.0 - clampf(g / (g + 2.0 * float(commit)), 0.0, 0.7))
	return ticks * per >= 0.9 * float(v["max_hp"])

static func _try(state: MatchState, fid: int, mission: String, home_id: int, events: Array) -> bool:
	var f: Dictionary = state.factions[fid]
	var home: Dictionary = state.holdings[home_id]
	var now: float = float(state.clock["elapsed"])
	var truced: bool = float(f.get("truce_until", 0.0)) > now
	var cands: Array = []   # [score, hid]
	var intel: Dictionary = f.get("intel", {})
	var ids: Array = intel.keys()
	ids.sort()
	var spare: int = int(home["garrison"]) - 2
	var pc: int = party_cap(state)
	var mk: float = float(Standing.cfg()["mark"]["ai_target_mult"])
	for hid in ids:
		var e: Dictionary = intel[hid]
		var h: Dictionary = state.holdings.get(hid, {})
		if h.is_empty() or int(h["owner"]) == fid:
			continue
		if HexGrid.distance(h["hex"], home["hex"]) > RANGE + 2 * mini(state.week(), 8):
			continue
		if truced and int(h["owner"]) == 0:
			continue
		if int(h["owner"]) >= 0 and Standing.truced(state, fid, int(h["owner"])):
			continue
		var bonus: float = 1.25 if _marked_near(state, h["hex"]) else 1.0
		if int(h["owner"]) >= 0 and Standing.is_marked(state, int(h["owner"])):
			bonus *= mk
		if mission == "capture":
			var commit: int = mini(spare, pc)
			if commit < 2:
				continue
			var est: float = float(e["def"])
			var power: float = Conquest.attacker_power(state, {}, commit)
			if power < 1.3 * est:
				if _strike_ok(state, h, commit):
					cands.append([2.5 * bonus, hid, true])      # decapitation strike (ranked like an ordinary raid, not above it)
				continue
			var value: float = float(e["val"]) + 6.0 * float(int(e["tier"]) + 1) + (4.0 if int(h["owner"]) >= 0 else 0.0)
			cands.append([value / maxf(est, 1.0) * bonus, hid, false])
		else:
			if spare < 1 or int(e["garrison"]) > 6 or int(e["qty"]) <= 0:
				continue
			var gain: float = float(e["val"]) - 2.0 * float(e["garrison"])
			if gain <= 0.0:
				continue
			cands.append([gain * bonus, hid, false])
	cands.sort_custom(func(x: Array, y: Array) -> bool: return x[0] > y[0] or (x[0] == y[0] and x[1] < y[1]))
	var tries: int = 0
	for c in cands:
		tries += 1
		if tries > 3:
			break
		var hid2: int = int(c[1])
		var e2: Dictionary = intel[hid2]
		if mission == "capture":
			if _dispatch(state, fid, home_id, hid2, "capture", mini(spare, pc), "", 0, events, bool(c[2])):
				return true
		else:
			if _dispatch(state, fid, home_id, hid2, "steal", mini(2, spare), String(e2["item"]), int(e2["qty"]), events):
				return true
	return false

## Non-raiding Purge routes (these earn deeds, which is how passive personas avoid the idle bleed): resupply an outlying holding, or scout a rival.
static func _plan_support(state: MatchState, fid: int, persona: String, home_id: int, events: Array) -> bool:
	var f: Dictionary = state.factions[fid]
	var home: Dictionary = state.holdings[home_id]
	var spare: int = int(home["garrison"]) - 2
	if spare < 1:
		return false
	var pcap: Dictionary = f.get("pcap", {})
	var sup_w: int = _bias(state, fid, "supply") + (2 if persona == "turtle" or persona == "hoarder" else 1)
	var scout_w: int = _bias(state, fid, "scout") + (2 if persona == "trader" else 1) + _bias(state, fid, "broker")
	var order: Array = ["supply", "scout"] if sup_w >= scout_w else ["scout", "supply"]
	for m in order:
		if m == "supply" and int(pcap.get("escort", 0)) < int(Standing.deed_def("escort")["cap"]):
			var best: int = -1
			var bd: int = 1 << 30
			for hid in state.holdings_of(fid):
				var h: Dictionary = state.holdings[hid]
				var d: int = HexGrid.distance(h["hex"], home["hex"])
				if int(hid) == home_id or d < PurgeActions.ESCORT_MIN_DIST or d > 18 or (f.get("escorted", []) as Array).has(hid):
					continue
				if d < bd:
					bd = d
					best = int(hid)
			if best != -1 and Inv.count(home["store"], "lfg:item/ration") >= 10:
				if _dispatch(state, fid, home_id, best, "supply", 1, "lfg:item/ration", 6, events):
					return true
		elif m == "scout" and int(pcap.get("scout", 0)) < int(Standing.deed_def("scout")["cap"]):
			var intel: Dictionary = f.get("intel", {})
			var ids: Array = intel.keys()
			ids.sort()
			var best2: int = -1
			var bd2: int = 1 << 30
			for hid in ids:
				var h2: Dictionary = state.holdings.get(hid, {})
				if h2.is_empty() or int(h2["owner"]) < 0 or int(h2["owner"]) == fid or (f.get("scouted", []) as Array).has(hid):
					continue
				if Standing.truced(state, fid, int(h2["owner"])):
					continue
				var d2: int = HexGrid.distance(h2["hex"], home["hex"])
				if d2 <= 18 and d2 < bd2:
					bd2 = d2
					best2 = int(hid)
			if best2 != -1 and _dispatch(state, fid, home_id, best2, "scout", 1, "", 0, events):
				return true
	return false

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
		var cap: int = Standing.garrison_cap(state, h)
		var n: int = mini(mini(3, cap - int(h["garrison"])), Inv.count(h["store"], "lfg:item/coin") / 4)
		if n > 0 and Inv.room_for(mer["store"], {"lfg:item/coin": 4 * n}):
			Inv.transfer(h["store"], mer["store"], {"lfg:item/coin": 4 * n})
			h["garrison"] = int(h["garrison"]) + n
			events.append({"type": &"ai_hired", "faction": fid, "by": fid, "ai": true, "holding": hid, "count": n})

static func _dispatch(state: MatchState, fid: int, home_id: int, target_id: int, mission: String, troops: int, item: String, qty: int, events: Array, strike: bool = false) -> bool:
	var home: Dictionary = state.holdings[home_id]
	var target: Dictionary = state.holdings[target_id]
	if troops < 1:
		return false
	var path: Array[Vector2i] = route(state, home["hex"], target["hex"])
	if path.is_empty() or path.size() > MAX_PATH_LEN + 4 * mini(state.week(), 8):
		return false
	var f: Dictionary = state.factions[fid]
	var now: float = float(state.clock["elapsed"])
	home["garrison"] = int(home["garrison"]) - troops
	var pid: int = state.new_id()
	var label: String = "Raiders" if mission == "capture" else ("Thieves" if mission == "steal" else ("Scouts" if mission == "scout" else "Supply Train"))
	var p: Dictionary = Setup.make_actor(pid, "party", fid, "%s %s" % [f["name"], label], home["hex"], troops * HP_PER_TROOP, 2, 1, 0)
	p["speed_mult"] = MatchState.q(tscale(state))
	p["ai"] = {"state": "march", "mission": mission, "target": target_id, "home": home_id, "troops": troops, "item": item, "qty": qty,
		"warned": false, "retry": 0, "scout_t": now + 3.0, "hit_t": 0.0, "sortie_t": 0.0, "siege_end": 0.0, "leader": -1, "strike": strike}
	if mission == "supply":
		var cargo: Dictionary = {item: mini(qty, Inv.count(home["store"], item))}
		Inv.transfer(home["store"], p["inv"], cargo)
	p["move"] = {"path": path, "acc": 0.0}
	state.actors[pid] = p
	f["next_act"] = MatchState.q(now + maxf(15.0, ACT_COOLDOWN / (1.0 + float(state.week()) / 12.0)) * tscale(state))
	var lead: Dictionary = AILeaders.leader_of(state, fid)
	if (mission == "capture" or mission == "steal") and AILeaders.wants_to_join(state, fid, lead, mission, troops) and HexGrid.distance(lead["hex"], home["hex"]) <= 1:
		AILeaders.join(state, lead, p)
	var eta: float = 0.0
	for h in path:
		eta += Movement.step_secs(state, p, h)
	events.append({"type": &"party_dispatched", "party": pid, "by": fid, "ai": true, "faction_name": f["name"], "from": home_id, "target": target_id,
		"mission": mission, "troops": troops, "eta": MatchState.q(eta), "hex": home["hex"], "leader": int(p["ai"]["leader"])})
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
			_release_leader(state, a)
			if a["ai"]["state"] == "siege":
				AILeaders.recall(state, int(a["ai"]["target"]))
			state.actors.erase(id)
			continue
		var ai: Dictionary = a["ai"]
		var fid: int = int(a["faction"])
		if state.phase != &"PURGE_ACTIVE" or not state.factions[fid]["alive"]:
			_disband(state, a, events, "recalled")
			continue
		if int(ai.get("leader", -1)) != -1:
			AILeaders.follow(state, a)
		if now >= float(ai["scout_t"]):
			ai["scout_t"] = MatchState.q(now + 3.0 * ts + 0.5)
			scout(state, fid)
		var st: String = ai["state"]
		if st == "march":
			var t: Dictionary = state.holdings[int(ai["target"])]
			var mission: String = String(ai["mission"])
			if int(t["owner"]) == fid and mission != "supply":
				_go_home(state, a, events)
				continue
			if int(t["owner"]) >= 0 and int(t["owner"]) != fid and Standing.truced(state, fid, int(t["owner"])):
				_go_home(state, a, events)
				continue
			var d: int = HexGrid.distance(a["hex"], t["hex"])
			if mission == "scout":
				if d <= PurgeActions.SCOUT_RANGE:
					var sc: Array = state.factions[fid].get("scouted", [])
					if not sc.has(int(t["id"])):
						sc.append(int(t["id"]))
					state.factions[fid]["scouted"] = sc
					events.append({"type": &"scouted", "faction": fid, "actor": id, "holding": t["id"], "owner": t["owner"], "garrison": t["garrison"],
						"defense": int(round(Conquest.defender_power(state, t))), "ai": true})
					_go_home(state, a, events)
					continue
			elif mission == "supply":
				if int(t["owner"]) != fid:
					_go_home(state, a, events)
					continue
				if d <= 1:
					events.append({"type": &"escorted", "faction": fid, "actor": id, "holding": t["id"], "qty": Inv.count(a["inv"], "lfg:item/ration"), "ai": true})
					ai["home"] = int(t["id"])
					ai["state"] = "return"
					ai["troops"] = troops_of(a)
					_disband(state, a, events, "delivered")
					continue
			if not bool(ai["warned"]) and int(t["owner"]) == 0 and d <= warn_radius(t) and (mission == "capture" or mission == "steal"):
				ai["warned"] = true
				events.append({"type": &"raid_warning", "party": id, "holding": t["id"], "by": fid, "ai": true, "mission": ai["mission"], "troops": troops_of(a),
					"hex": a["hex"], "distance": d})
			if d <= 1 and (mission == "capture" or mission == "steal"):
				ai["state"] = "siege"
				ai["siege_end"] = MatchState.q(now + SIEGE_SECS * ts)
				a["move"] = {}
				events.append({"type": &"party_arrived", "party": id, "holding": t["id"], "by": fid, "ai": true, "hex": a["hex"], "troops": troops_of(a)})
				AILeaders.defend_call(state, a)
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
			if int(t2["owner"]) >= 0 and Standing.truced(state, fid, int(t2["owner"])):
				_go_home(state, a, events)
				continue
			_defend(state, a, events, now, ts)
			if not a["alive"]:
				continue
			if st == "siege" and ai["state"] == "siege" and now >= float(ai["siege_end"]):
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

## A leader inside a garrisoned holding is shielded by its troops (up to 70% of the blows); an empty fort leaves it exposed.
static func _bodyguard(state: MatchState, leader: Dictionary, party: Dictionary) -> float:
	var hid: int = CmdUtil.holding_at(state, leader["hex"])
	if hid == -1 or int(state.holdings[hid]["owner"]) != int(leader["faction"]):
		return 0.0
	var g: float = float(state.holdings[hid]["garrison"])
	return clampf(g / (g + 2.0 * float(troops_of(party))), 0.0, 0.7)

static func _party_leader(state: MatchState, a: Dictionary) -> Dictionary:
	var lid: int = int(a["ai"].get("leader", -1))
	if lid == -1:
		return {}
	var l: Dictionary = state.actors.get(lid, {})
	return l if (not l.is_empty() and l["alive"]) else {}

static func _release_leader(state: MatchState, a: Dictionary) -> void:
	if int(a["ai"].get("leader", -1)) == -1:
		return
	var home: Dictionary = state.holdings.get(int(a["ai"].get("home", -1)), {})
	AILeaders.release(state, a, home["hex"] if not home.is_empty() else a["hex"])

## Garrison sorties from every holding within 2 hexes (except the party's own) wound the party (and the leader marching with it);
## leaders on both sides trade blows and use their class kit; the party also harasses any hostile leader next to it.
static func _defend(state: MatchState, a: Dictionary, events: Array, now: float, ts: float) -> void:
	var ai: Dictionary = a["ai"]
	var fid: int = int(a["faction"])
	var lead: Dictionary = _party_leader(state, a)
	if now >= float(ai["sortie_t"]):
		ai["sortie_t"] = MatchState.q(now + SORTIE_PERIOD * ts + 0.5)
		var total: int = 0
		var best_f: int = -1
		var best_c: int = 0
		for h in state.holdings.values():
			if int(h["owner"]) == fid or int(h["garrison"]) < 2 or HexGrid.distance(h["hex"], a["hex"]) > 2:
				continue
			var per: float = 1.0
			if int(h["owner"]) >= 0 and state.factions[int(h["owner"])]["persona"] == "turtle":
				per = 2.0
			if Conquest._active(state, h, "rally"):
				per *= 1.4
			var c: int = int(float(h["garrison"]) * per)
			total += c
			if c > best_c and int(h["owner"]) >= 0:
				best_c = c
				best_f = int(h["owner"])
		if total > 0:
			events.append({"type": &"sortie", "party": a["id"], "damage": total, "by": fid})
			if not lead.is_empty():
				var src: int = int(state.factions[best_f]["leader"]) if best_f >= 0 else -1
				Combat.hurt(state, int(lead["id"]), maxi(1, total / 4), src, events, "sortie")
			Combat.hurt(state, int(a["id"]), total, -1, events, "sortie")
			if not a["alive"]:
				return
	if now >= float(ai["hit_t"]):
		ai["hit_t"] = MatchState.q(now + HARASS_PERIOD * ts + 0.5)
		_harass(state, a, events)
		if not a["alive"]:
			return
		lead = _party_leader(state, a)
		if not lead.is_empty() and float(lead["hp"]) < 0.4 * float(lead["max_hp"]):
			_go_home(state, a, events)

static func _harass(state: MatchState, a: Dictionary, events: Array) -> void:
	var ai: Dictionary = a["ai"]
	var fid: int = int(a["faction"])
	var lead: Dictionary = _party_leader(state, a)
	var foe: Dictionary = {}
	var fkeys: Array = state.factions.keys()
	fkeys.sort()
	for f2 in fkeys:
		if int(f2) == fid or not state.factions[f2]["alive"] or Standing.truced(state, fid, int(f2)):
			continue
		var v: Dictionary = state.actors.get(int(state.factions[f2]["leader"]), {})
		if v.is_empty() or not v["alive"] or (v["kind"] != "leader" and v["kind"] != "ai_leader"):
			continue
		if HexGrid.distance(v["hex"], a["hex"]) > 1 or Combat.has_effect(state, v, "truce"):
			continue
		var dmg: int = maxi(1, 2 + troops_of(a) / 2 - int(Combat.def_of(state, v)))
		if v["kind"] == "ai_leader":
			dmg = maxi(1, 2 + troops_of(a) - int(Combat.def_of(state, v)))       # an AI leader stands and fights; it does not kite like a player
			dmg = maxi(1, int(round(float(dmg) * (1.0 - _bodyguard(state, v, a)))))
		Combat.hurt(state, int(v["id"]), dmg, int(lead["id"]) if not lead.is_empty() else int(a["id"]), events, "raid_party")
		if foe.is_empty():
			foe = v
		if v["alive"] and v["kind"] == "ai_leader":
			Combat.hurt(state, int(a["id"]), Combat.calc_damage(state, v, a), int(v["id"]), events, "leader_defence")
			AILeaders.siege_cast(state, v, a, {}, events)
			if not a["alive"]:
				return
		if v["alive"] and not lead.is_empty():
			AILeaders.melee(state, lead, v, events)
	if not lead.is_empty() and lead["alive"]:
		AILeaders.siege_cast(state, lead, foe, {"holding": int(ai["target"])}, events)

static func _resolve(state: MatchState, a: Dictionary, events: Array) -> void:
	var ai: Dictionary = a["ai"]
	var fid: int = int(a["faction"])
	var tid: int = int(ai["target"])
	var troops: int = troops_of(a)
	if troops < 1:
		Combat.kill(state, int(a["id"]), -1, events)
		return
	if ai["mission"] == "capture" and bool(ai.get("strike", false)) \
			and Conquest.attacker_power(state, {}, troops) < 1.2 * Conquest.defender_power(state, state.holdings[tid]):
		_go_home(state, a, events)       # a decapitation raid: it came for the leader, not the walls
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
	if ai["state"] == "siege":
		AILeaders.recall(state, int(ai["target"]))
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
	AILeaders.release(state, a, dest["hex"] if not dest.is_empty() else a["hex"])
	if ai["state"] == "siege":
		AILeaders.recall(state, int(ai["target"]))
	state.actors.erase(int(a["id"]))
	events.append({"type": &"party_returned", "party": a["id"], "by": fid, "ai": true, "reason": reason, "troops": troops, "loot": stored})
