class_name Economy
extends RefCounted
## Trade (buy/sell/deposit/withdraw), buildings, policies, daily rations/starvation, win/loss checks.
const COIN := "lfg:item/coin"
const RATION := "lfg:item/ration"
const TRADE_RANGE := 1
const STARVE_DESERT_DAYS := 3

const PRICE_MIN := 0.5
const PRICE_MAX := 2.5
const PRICE_STEP := 1.03     # per unit traded
const PRICE_DRIFT := 0.25    # fraction of the gap to the supply target closed each dawn
const BUILD_RADIUS := 2

static func price_mult(h: Dictionary, item: String) -> float:
	return float(h.get("prices", {}).get(item, 1.0))

static func buy_price(item: String, mult: float = 1.0, a: Dictionary = {}) -> int:
	var cm: float = float(Combat.class_mod(a, "buy_mult", 1.0)) if not a.is_empty() else 1.0
	var rk: float = 1.0 - (Standing.price_pct(a) if not a.is_empty() else 0.0)
	return maxi(1, int(ceil(float(Content.item_value(item)) * 1.25 * mult * cm * rk - 1e-9)))

static func sell_price(a: Dictionary, item: String, mult: float = 1.0) -> int:
	var rk: float = 1.0 + (Standing.price_pct(a) if not a.is_empty() else 0.0)
	return maxi(1, int(floor(float(Content.item_value(item)) * 0.6 * mult * float(Combat.class_mod(a, "sell_mult", 1.0)) * rk + 1e-9)))

static func _bump_price(h: Dictionary, item: String, q: int, up: bool) -> void:
	if not h.has("prices"):
		h["prices"] = {}
	var m: float = price_mult(h, item) * pow(PRICE_STEP if up else 1.0 / PRICE_STEP, float(q))
	h["prices"][item] = MatchState.q(clampf(m, PRICE_MIN, PRICE_MAX))

## Merchants restock-drift: price chases scarcity (stock below its baseline = dearer, glut = cheaper).
static func drift_prices(state: MatchState) -> void:
	for hid in state.holdings.keys():
		var h: Dictionary = state.holdings[hid]
		if not (h["merchant"] and int(h["owner"]) == -1):
			continue
		var base: Dictionary = h.get("base_stock", {})
		for item in base.keys():
			if item == COIN:
				continue
			var ref: float = maxf(1.0, float(base[item]))
			var target: float = clampf(sqrt(ref / (float(Inv.count(h["store"], item)) + 1.0)), PRICE_MIN, PRICE_MAX)
			var cur: float = price_mult(h, item)
			var nm: float = MatchState.q(cur + (target - cur) * PRICE_DRIFT)
			if absf(nm - 1.0) < 0.005:
				if h.has("prices"):
					(h["prices"] as Dictionary).erase(item)
			else:
				if not h.has("prices"):
					h["prices"] = {}
				h["prices"][item] = nm

static func trade(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	if state.phase == &"PURGE_ACTIVE":
		return "market_closed"
	var hid: int = CmdUtil.parse_id(args.get("holding"))
	if not state.holdings.has(hid):
		return "unknown_holding"
	var h: Dictionary = state.holdings[hid]
	if HexGrid.distance(a["hex"], h["hex"]) > TRADE_RANGE:
		return "too_far"
	var side: String = CmdUtil.s(args.get("side", ""))
	var item: String = CmdUtil.s(args.get("item", ""))
	if Content.item(item).is_empty():
		return "unknown_item"
	var q: int = Inv.parse_qty(args.get("qty"))
	if q < 0:
		return "bad_quantity"
	var mine: bool = int(h["owner"]) == int(a["faction"])
	if side == "deposit" or side == "withdraw":
		if not mine:
			return "not_yours"
		var err: String = ""
		if side == "deposit":
			err = Inv.transfer(a["inv"], h["store"], {item: q})
		else:
			if not Inv.can_carry(a, {item: q}):
				return "no_room" if Inv.has_all(h["store"], {item: q}) else "insufficient_items"
			err = Inv.transfer(h["store"], a["inv"], {item: q})
		if err == "":
			events.append({"type": &"stored" if side == "deposit" else &"withdrawn", "actor": a["id"], "holding": hid, "item": item, "qty": q})
		return err
	if side != "buy" and side != "sell":
		return "bad_side"
	if item == COIN:
		return "not_tradable"
	if not (h["merchant"] and int(h["owner"]) == -1):
		return "not_a_merchant"
	if side == "buy":
		var pm: float = price_mult(h, item)
		var cost: int = buy_price(item, pm, a) * q
		if cost > Inv.MAX_QTY:
			return "bad_quantity"
		if not Inv.has_all(h["store"], {item: q}):
			return "merchant_out_of_stock"
		if not Inv.has_all(a["inv"], {COIN: cost}):
			return "insufficient_coin"
		if not Inv.can_carry(a, {item: q}, {COIN: cost}) or not Inv.room_for(h["store"], {COIN: cost}):
			return "no_room"
		_bump_price(h, item, q, true)
		Inv.remove_all(a["inv"], {COIN: cost})
		Inv.add_all(h["store"], {COIN: cost})
		Inv.remove_all(h["store"], {item: q})
		Inv.add_all(a["inv"], {item: q})
		events.append({"type": &"traded", "actor": a["id"], "holding": hid, "side": "buy", "item": item, "qty": q, "coin": cost, "price": cost / q})
		return ""
	var gain: int = sell_price(a, item, price_mult(h, item)) * q
	if gain > Inv.MAX_QTY:
		return "bad_quantity"
	if not Inv.has_all(a["inv"], {item: q}):
		return "insufficient_items"
	if not Inv.has_all(h["store"], {COIN: gain}):
		return "merchant_out_of_coin"
	if not Inv.room_for(h["store"], {item: q}) or not Inv.room_for(a["inv"], {COIN: gain}):
		return "no_room"
	_bump_price(h, item, q, false)
	Inv.remove_all(a["inv"], {item: q})
	Inv.add_all(h["store"], {item: q})
	Inv.remove_all(h["store"], {COIN: gain})
	Inv.add_all(a["inv"], {COIN: gain})
	events.append({"type": &"traded", "actor": a["id"], "holding": hid, "side": "sell", "item": item, "qty": q, "coin": gain, "price": gain / q})
	return ""

static func _own_near(state: MatchState, a: Dictionary, args: Dictionary) -> int:
	var hid: int = CmdUtil.parse_id(args.get("holding"))
	if not state.holdings.has(hid):
		return -1
	var h: Dictionary = state.holdings[hid]
	if int(h["owner"]) != int(a["faction"]) or HexGrid.distance(a["hex"], h["hex"]) > 3:
		return -2
	return hid

static func blessed(state: MatchState, h: Dictionary) -> bool:
	return int(h.get("blessed_day", 0)) >= int(state.clock["day"])

static func group_of(b: Dictionary) -> String:
	return String(b.get("group", b["id"]))

## Cost after class discounts (Forge -25% everything, Dune -50% gadget buildings); never below 1 per listed item.
static func build_cost(a: Dictionary, b: Dictionary) -> Dictionary:
	var m: float = 1.0
	if not a.is_empty():
		m = float(Combat.class_mod(a, "build_cost_mult", 1.0))
		if bool(b.get("gadget", false)):
			m *= float(Combat.class_mod(a, "gadget_build_mult", 1.0))
	var out: Dictionary = {}
	for k in (b["cost"] as Dictionary).keys():
		out[k] = maxi(1, int(ceil(float(b["cost"][k]) * m - 1e-9)))
	return out

static func site_key(h: Vector2i) -> String:
	return MatchState.plot_key(h)

static func site_free(state: MatchState, hold: Dictionary, hx: Vector2i) -> String:
	## "" when a building may stand on hx, else the reason.
	if not HexGrid.in_bounds(hx):
		return "bad_hex"
	var d: int = HexGrid.distance(hx, hold["hex"])
	if d < 1 or d > BUILD_RADIUS:
		return "site_out_of_range"
	if int(state.world["terrain"][HexGrid.index(hx)]) != WorldGen.T_GROUND:
		return "bad_terrain"
	if state.plots.has(site_key(hx)) or CmdUtil.holding_at(state, hx) != -1:
		return "occupied"
	for o in state.holdings.values():
		if (o.get("sites", {}) as Dictionary).has(site_key(hx)):
			return "occupied"
	if Fx.cache_at(state, int(hold["owner"]), hx):
		return "occupied"
	return ""

static func pick_site(state: MatchState, hold: Dictionary) -> Variant:
	var cands: Array[Vector2i] = HexGrid.ring_within(hold["hex"], BUILD_RADIUS)
	cands.sort_custom(func(x: Vector2i, y: Vector2i) -> bool:
		var dx: int = HexGrid.distance(x, hold["hex"])
		var dy: int = HexGrid.distance(y, hold["hex"])
		return dx < dy or (dx == dy and HexGrid.index(x) < HexGrid.index(y)))
	for c in cands:
		if site_free(state, hold, c) == "":
			return c
	return null

static func build(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	var hid: int = _own_near(state, a, args)
	if hid == -1:
		return "unknown_holding"
	if hid == -2:
		return "not_near_own_holding"
	var b: Dictionary = Content.building(CmdUtil.s(args.get("building", "")))
	if b.is_empty():
		return "unknown_building"
	var h: Dictionary = state.holdings[hid]
	var bl: Array = h["buildings"]
	if not Standing.rank_ok(state, int(a["faction"]), int(b.get("rank", 0))):
		return "rank_required"
	var cost: Dictionary = build_cost(a, b)
	if b.has("upgrade_of"):
		# Upgrade: replaces the base building in place (keeps its site).
		if not bl.has(b["upgrade_of"]):
			return "needs_base_building"
		if args.has("hex"):
			return "upgrade_has_no_site"
		if not Inv.has_all(a["inv"], cost):
			return "insufficient_items"
		Inv.remove_all(a["inv"], cost)
		bl[bl.find(b["upgrade_of"])] = b["id"]
		var sites: Dictionary = h.get("sites", {})
		for k in sites.keys():
			if sites[k] == b["upgrade_of"]:
				sites[k] = b["id"]
				break
		events.append({"type": &"built", "actor": a["id"], "holding": hid, "building": b["id"], "upgrade": true})
		return ""
	var have: int = 0
	for x in bl:
		if group_of(Content.building(String(x))) == group_of(b):
			have += 1
	if have >= int(b["max"]):
		return "building_limit"
	var site: Vector2i
	if args.has("hex"):
		var hv: Variant = CmdUtil.parse_hex(args["hex"])
		if hv == null:
			return "bad_hex"
		site = hv
		var why: String = site_free(state, h, site)
		if why != "":
			return why
	else:
		var ps: Variant = pick_site(state, h)
		if ps == null:
			return "no_site"
		site = ps
	if not Inv.has_all(a["inv"], cost):
		return "insufficient_items"
	Inv.remove_all(a["inv"], cost)
	bl.append(b["id"])
	if not h.has("sites"):
		h["sites"] = {}
	h["sites"][site_key(site)] = b["id"]
	events.append({"type": &"built", "actor": a["id"], "holding": hid, "building": b["id"], "hex": site})
	return ""

static func demolish(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	var hid: int = _own_near(state, a, args)
	if hid == -1:
		return "unknown_holding"
	if hid == -2:
		return "not_near_own_holding"
	var bid: String = CmdUtil.s(args.get("building", ""))
	var h: Dictionary = state.holdings[hid]
	if not (h["buildings"] as Array).has(bid):
		return "no_such_building"
	var refund: Dictionary = {}
	for k in Content.building(bid)["cost"].keys():
		var r: int = int(Content.building(bid)["cost"][k]) / 2
		if r > 0:
			refund[k] = r
	if not Inv.can_carry(a, refund):
		return "no_room"
	(h["buildings"] as Array).erase(bid)
	var sites: Dictionary = h.get("sites", {})
	for k in sites.keys():
		if sites[k] == bid:
			sites.erase(k)
			break
	Inv.add_all(a["inv"], refund)
	events.append({"type": &"demolished", "actor": a["id"], "holding": hid, "building": bid, "refund": refund})
	return ""

static func set_policy(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	var key: String = CmdUtil.s(args.get("key", ""))
	var val: String = CmdUtil.policy_value(args.get("value"))
	if key == "ration":
		if not ["full", "half", "none"].has(val):
			return "bad_value"
		state.factions[int(a["faction"])]["ration_policy"] = val
		events.append({"type": &"policy_set", "faction": a["faction"], "key": key, "value": val})
		return ""
	if key == "stance":
		var hid: int = CmdUtil.parse_id(args.get("holding"))
		if not state.holdings.has(hid) or int(state.holdings[hid]["owner"]) != int(a["faction"]):
			return "not_yours"
		if not ["defend", "raid"].has(val):
			return "bad_value"
		state.holdings[hid]["stance"] = val
		events.append({"type": &"policy_set", "faction": a["faction"], "key": key, "holding": hid, "value": val})
		return ""
	return "bad_key"

static func rest(state: MatchState, a: Dictionary, events: Array) -> String:
	if not Combat.ready(state, a, "rest"):
		return "cooldown"
	for o in state.actors.values():
		if o["kind"] == "enemy" and o["alive"] and HexGrid.distance(o["hex"], a["hex"]) <= 4:
			return "enemies_near"
	Combat.set_cd(state, a, "rest", 30.0)
	var healed: int = Combat.heal(a, 10)
	a["energy"] = minf(float(a["max_energy"]), float(a["energy"]) + 30.0)
	events.append({"type": &"rested", "actor": a["id"], "healed": healed})
	return ""

# ---------- daily: rations, recruiting ----------
static func persons(state: MatchState, fid: int) -> int:
	var f: Dictionary = state.factions[fid]
	var n: int = 0
	var up: float = 1.0
	var leader: Dictionary = state.actors.get(int(f["leader"]), {})
	if not leader.is_empty() and leader["alive"]:
		n += int(Combat.class_mod(leader, "ration_need", 1))
		up = float(Combat.class_mod(leader, "upkeep_mult", 1.0))
	var g: int = 0
	for hid in state.holdings_of(fid):
		if not blessed(state, state.holdings[hid]):
			g += int(state.holdings[hid]["garrison"])
	return n + (g if up == 1.0 else int(round(float(g) * up)))

static func rations_available(state: MatchState, fid: int) -> int:
	var f: Dictionary = state.factions[fid]
	var t: int = 0
	var leader: Dictionary = state.actors.get(int(f["leader"]), {})
	if not leader.is_empty() and leader["alive"]:
		t += Inv.count(leader["inv"], RATION)
	for hid in state.holdings_of(fid):
		t += Inv.count(state.holdings[hid]["store"], RATION)
	return t

static func feed_faction(state: MatchState, fid: int, events: Array) -> void:
	var f: Dictionary = state.factions[fid]
	if not f["alive"]:
		return
	var need: int = persons(state, fid)
	var policy: String = String(f.get("ration_policy", "full"))
	var target: int = need
	if policy == "half":
		target = (need + 1) / 2
	elif policy == "none":
		target = 0
	var remaining: int = mini(target, rations_available(state, fid))
	var eaten: int = remaining
	var leader: Dictionary = state.actors.get(int(f["leader"]), {})
	if remaining > 0 and not leader.is_empty() and leader["alive"]:
		var t: int = mini(remaining, Inv.count(leader["inv"], RATION))
		if t > 0:
			Inv.remove_all(leader["inv"], {RATION: t})
			remaining -= t
	for hid in state.holdings_of(fid):
		if remaining <= 0:
			break
		var st: Dictionary = state.holdings[hid]["store"]
		var t2: int = mini(remaining, Inv.count(st, RATION))
		if t2 > 0:
			Inv.remove_all(st, {RATION: t2})
			remaining -= t2
	events.append({"type": &"rations_eaten", "faction": fid, "ai": bool(f["is_ai"]), "eaten": eaten, "need": need})
	if eaten >= need:
		f["hunger_days"] = 0
		return
	f["hunger_days"] = int(f["hunger_days"]) + 1
	events.append({"type": &"starving", "faction": fid, "ai": bool(f["is_ai"]), "days": f["hunger_days"], "short": need - eaten})
	if int(f["hunger_days"]) >= STARVE_DESERT_DAYS:
		for hid in state.holdings_of(fid):
			var h: Dictionary = state.holdings[hid]
			var g: int = int(h["garrison"])
			if g > 0:
				var lost: int = maxi(1, int(ceil(float(g) / 3.0)))
				h["garrison"] = g - lost
				events.append({"type": &"desertion", "faction": fid, "ai": bool(f["is_ai"]), "holding": hid, "count": lost})

static func dawn_recruit(state: MatchState, events: Array) -> void:
	for hid in state.holdings.keys():
		var h: Dictionary = state.holdings[hid]
		if int(h["owner"]) < 0 or not (h["buildings"] as Array).has("lfg:building/barracks"):
			continue
		if int(state.factions[int(h["owner"])]["hunger_days"]) > 0:
			continue
		var b: Dictionary = Content.building("lfg:building/barracks")
		var cap: int = Standing.garrison_cap(state, h)
		if int(h["garrison"]) < cap and Inv.has_all(h["store"], {COIN: int(b["recruit_coin"])}):
			Inv.remove_all(h["store"], {COIN: int(b["recruit_coin"])})
			h["garrison"] = int(h["garrison"]) + int(b["recruit_per_day"])
			events.append({"type": &"recruited", "holding": hid, "garrison": h["garrison"]})

# ---------- win / loss ----------
## Total Conquest is the ONLY win: every rival leader dead/eliminated AND one faction owns every holding on the map.
## Emits victory{kind:"total_conquest", faction, player}. Playing on (Endless) stays possible; the event fires once.
static func check_victory(state: MatchState, events: Array) -> void:
	if state.won != "" or state.over:
		return
	var winner: int = -1
	for fid in state.factions.keys():
		if state.factions[fid]["alive"]:
			if winner != -1:
				return
			winner = int(fid)
	if winner == -1:
		return
	for h in state.holdings.values():
		if int(h["owner"]) != winner:
			return
	state.won = "total_conquest"
	events.append({"type": &"victory", "kind": "total_conquest", "faction": winner, "player": winner == 0, "holdings": state.holdings.size(),
		"day": state.clock["day"], "faction_name": state.factions[winner]["name"]})

static func check_starved_out(state: MatchState, events: Array) -> void:
	if state.over:
		return
	var leader: Dictionary = state.player()
	if leader.is_empty():
		return
	if state.holdings_of(0).is_empty() and Inv.count(leader["inv"], RATION) == 0:
		Combat.end_match(state, "starved_out", events)


# ---------- production buildings (run at dawn, before crops grow) ----------
static func working(state: MatchState, h: Dictionary, work: Dictionary) -> bool:
	if int(h["owner"]) < 0:
		return false
	if int(state.factions[int(h["owner"])].get("hunger_days", 0)) > 0:
		return false      # a starving faction does no work
	if int(h.get("stab", 100)) < int(Standing.cfg().get("stability", {}).get("weak", 40)) and int(state.clock["day"]) % 2 == 0:
		return false      # unstable holdings produce less
	return int(h["garrison"]) >= int(work.get("min_garrison", 0))

static func dawn_buildings(state: MatchState, events: Array) -> void:
	var ids: Array = state.holdings.keys()
	ids.sort()
	for hid in ids:
		var h: Dictionary = state.holdings[hid]
		if int(h["owner"]) < 0 or (h["buildings"] as Array).is_empty():
			continue
		for bid in h["buildings"]:
			var b: Dictionary = Content.building(String(bid))
			var w: Dictionary = b.get("work", {})
			if w.is_empty() or not working(state, h, w):
				continue
			if w.has("waters"):
				var n: int = 0
				var keys: Array = state.plots.keys()
				keys.sort()
				for k in keys:
					var p: Dictionary = state.plots[k]
					if int(p["holding"]) == int(hid) and not bool(p["watered"]) and bool(Content.crop(String(p["crop"]))["needs_water"]):
						p["watered"] = true
						n += 1
				if n > 0:
					events.append({"type": &"well_watered", "holding": hid, "plots": n})
			if w.has("outputs"):
				var out: Dictionary = w["outputs"]
				if Inv.room_for(h["store"], out):
					Inv.add_all(h["store"], out)
					Standing.note_output(state, int(h["owner"]), out)
					events.append({"type": &"produced", "holding": hid, "building": bid, "items": out})
			if w.has("batches"):
				var made: int = cook_store(h["store"], int(w["batches"]), int(w.get("bonus_ration", 0)))
				if made > 0:
					events.append({"type": &"produced", "holding": hid, "building": bid, "items": {RATION: made}})

## Cooks up to `batches` ration recipes from a store (best yield first). Returns rations made. Inputs -> outputs only.
static func cook_store(store: Dictionary, batches: int, bonus: int) -> int:
	var order: Array = ["lfg:recipe/ration_saltroot", "lfg:recipe/ration_glowfruit", "lfg:recipe/ration_game", "lfg:recipe/ration_sporebean"]
	var made: int = 0
	var left: int = batches
	for rid in order:
		if left <= 0:
			break
		var r: Dictionary = Content.recipe(rid)
		while left > 0 and Inv.has_all(store, r["inputs"]):
			var out: int = int(r["outputs"][RATION]) + bonus
			if not Inv.room_for(store, {RATION: out}):
				return made
			Inv.remove_all(store, r["inputs"])
			Inv.add_all(store, {RATION: out})
			made += out
			left -= 1
	return made
