class_name Economy
extends RefCounted
## Trade (buy/sell/deposit/withdraw), buildings, policies, daily rations/starvation, win/loss checks.
const COIN := "lfg:item/coin"
const RATION := "lfg:item/ration"
const TRADE_RANGE := 1
const STARVE_DESERT_DAYS := 3
const DOMINION_FRACTION := 0.6

static func buy_price(item: String) -> int:
	return int(ceil(float(Content.item_value(item)) * 1.25))

static func sell_price(a: Dictionary, item: String) -> int:
	return maxi(1, int(floor(float(Content.item_value(item)) * 0.6 * float(Combat.class_mod(a, "sell_mult", 1.0)))))

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
		var cost: int = buy_price(item) * q
		if cost > Inv.MAX_QTY:
			return "bad_quantity"
		if not Inv.has_all(h["store"], {item: q}):
			return "merchant_out_of_stock"
		if not Inv.has_all(a["inv"], {COIN: cost}):
			return "insufficient_coin"
		if not Inv.room_for(a["inv"], {item: q}) or not Inv.room_for(h["store"], {COIN: cost}):
			return "no_room"
		Inv.remove_all(a["inv"], {COIN: cost})
		Inv.add_all(h["store"], {COIN: cost})
		Inv.remove_all(h["store"], {item: q})
		Inv.add_all(a["inv"], {item: q})
		events.append({"type": &"traded", "actor": a["id"], "holding": hid, "side": "buy", "item": item, "qty": q, "coin": cost})
		return ""
	var gain: int = sell_price(a, item) * q
	if gain > Inv.MAX_QTY:
		return "bad_quantity"
	if not Inv.has_all(a["inv"], {item: q}):
		return "insufficient_items"
	if not Inv.has_all(h["store"], {COIN: gain}):
		return "merchant_out_of_coin"
	if not Inv.room_for(h["store"], {item: q}) or not Inv.room_for(a["inv"], {COIN: gain}):
		return "no_room"
	Inv.remove_all(a["inv"], {item: q})
	Inv.add_all(h["store"], {item: q})
	Inv.remove_all(h["store"], {COIN: gain})
	Inv.add_all(a["inv"], {COIN: gain})
	events.append({"type": &"traded", "actor": a["id"], "holding": hid, "side": "sell", "item": item, "qty": q, "coin": gain})
	return ""

static func _own_near(state: MatchState, a: Dictionary, args: Dictionary) -> int:
	var hid: int = CmdUtil.parse_id(args.get("holding"))
	if not state.holdings.has(hid):
		return -1
	var h: Dictionary = state.holdings[hid]
	if int(h["owner"]) != int(a["faction"]) or HexGrid.distance(a["hex"], h["hex"]) > 3:
		return -2
	return hid

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
	var have: int = 0
	for x in h["buildings"]:
		if x == b["id"]:
			have += 1
	if have >= int(b["max"]):
		return "building_limit"
	if not Inv.has_all(a["inv"], b["cost"]):
		return "insufficient_items"
	Inv.remove_all(a["inv"], b["cost"])
	h["buildings"].append(b["id"])
	events.append({"type": &"built", "actor": a["id"], "holding": hid, "building": b["id"]})
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
	if not Inv.room_for(a["inv"], refund):
		return "no_room"
	(h["buildings"] as Array).erase(bid)
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
	var leader: Dictionary = state.actors.get(int(f["leader"]), {})
	if not leader.is_empty() and leader["alive"]:
		n += int(Combat.class_mod(leader, "ration_need", 1))
	for hid in state.holdings_of(fid):
		n += int(state.holdings[hid]["garrison"])
	return n

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
		var cap: int = 4 + 4 * int(h["tier"])
		if int(h["garrison"]) < cap and Inv.has_all(h["store"], {COIN: int(b["recruit_coin"])}):
			Inv.remove_all(h["store"], {COIN: int(b["recruit_coin"])})
			h["garrison"] = int(h["garrison"]) + int(b["recruit_per_day"])
			events.append({"type": &"recruited", "holding": hid, "garrison": h["garrison"]})

# ---------- win / loss ----------
static func check_victory(state: MatchState, events: Array) -> void:
	if state.won != "" or state.over:
		return
	var total: int = state.holdings.size()
	var mine: int = state.holdings_of(0).size()
	if total > 0 and float(mine) >= DOMINION_FRACTION * float(total):
		state.won = "dominion"
		events.append({"type": &"victory", "kind": "dominion", "holdings": mine, "total": total})

static func check_starved_out(state: MatchState, events: Array) -> void:
	if state.over:
		return
	var leader: Dictionary = state.player()
	if state.holdings_of(0).is_empty() and Inv.count(leader["inv"], RATION) == 0:
		Combat.end_match(state, "starved_out", events)
