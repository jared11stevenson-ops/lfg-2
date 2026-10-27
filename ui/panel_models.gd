class_name PanelModels
extends RefCounted
## MatchState -> view models for the playable panels. READ ONLY: nothing here mutates state or calls Rules.apply.
## Placement/affordability checks mirror Economy.build/trade/craft preconditions (tests assert they agree with Rules).
const BUILD_RANGE := 3
const REASONS: Dictionary = {
	"": "Ready",
	"no_own_holding_nearby": "Stand within 3 hexes of one of your holdings",
	"building_limit": "Limit reached at this holding",
	"insufficient_items": "Not enough materials",
	"blocked": "Can't build on this ground",
	"unknown_building": "Unknown building",
	"plot_here": "A crop plot is in the way",
	"needs_base_building": "Build the base building first",
	"site_out_of_range": "Aim 1-2 hexes from the village centre",
	"bad_terrain": "Only open ground can be built on",
	"occupied": "Something already stands there",
	"no_site": "No free building site left",
	"class_required": "Your class can't make this",
	"not_near_own_holding": "Craft near one of your holdings",
	"too_far": "Walk up to the merchant",
	"market_closed": "The market is closed during the Purge",
	"locked_building": "Learn it from a class questline first",
	"locked_recipe": "Learn it from a class questline first",
	"needs_station": "Needs a crafting station at your holding",
	"rank_required": "Needs a higher Standing rank",
}

static func reason_text(r: String) -> String:
	return String(REASONS.get(r, r.replace("_", " ").capitalize()))

static func _actor(state: Object, actor_id: int) -> Dictionary:
	var actors: Dictionary = state.get("actors")
	var id: int = int(state.get("player_id")) if actor_id < 0 else actor_id
	return actors.get(id, {})

static func inventory_of(state: Object, actor_id: int = -1) -> Dictionary:
	return _actor(state, actor_id).get("inv", {})

static func bundle_entries(bundle: Dictionary, have: Dictionary, mult: int = 1) -> Array:
	var out: Array = []
	var keys: Array = bundle.keys()
	keys.sort()
	for k in keys:
		var need: int = int(bundle[k]) * mult
		var h: int = int(have.get(k, 0))
		out.append({"item": String(k), "name": UiKit.item_name(String(k)), "need": need, "have": h, "ok": h >= need})
	return out

## Nearest own holding within `max_d` hexes of an axial hex -> id or -1.
static func own_holding_near(state: Object, axial_hex: Vector2i, max_d: int = BUILD_RANGE) -> int:
	var a: Dictionary = _actor(state, -1)
	var fac: int = int(a.get("faction", 0))
	var best: int = -1
	var bd: int = 999
	var hs: Dictionary = state.get("holdings")
	var ids: Array = hs.keys()
	ids.sort()
	for id in ids:
		var h: Dictionary = hs[id]
		if int(h["owner"]) != fac:
			continue
		var d: int = HexGrid.distance(axial_hex, h["hex"])
		if d <= max_d and d < bd:
			bd = d
			best = int(id)
	return best

## Can the player build `building_id` with the ghost on `axial_hex` right now? -> {valid, reason, holding_id, hex, upgrade}
## Mirrors Economy.build: actor within 3 hexes of an own holding, group limit, site_free (1-2 hexes from that holding, ground,
## unoccupied), class-discounted cost. Upgrades (`upgrade_of`) need the base building and no site. `world_ok` is the
## presentation terrain check (WorldData.can_build), `plot_here` the farm-layer check.
static func check_placement(state: Object, building_id: String, axial_hex: Vector2i, world_ok: bool = true, plot_here: bool = false) -> Dictionary:
	var b: Dictionary = Content.building(building_id)
	if b.is_empty():
		return {"valid": false, "reason": "unknown_building", "holding_id": -1, "hex": axial_hex, "upgrade": false}
	var a: Dictionary = _actor(state, -1)
	var hid: int = own_holding_near(state, a.get("hex", axial_hex))
	if hid < 0:
		return {"valid": false, "reason": "no_own_holding_nearby", "holding_id": -1, "hex": axial_hex, "upgrade": b.has("upgrade_of")}
	var h: Dictionary = state.get("holdings")[hid]
	var up: bool = b.has("upgrade_of")
	var bl: Array = h["buildings"]
	var cost: Dictionary = Economy.build_cost(a, b)
	if up:
		var r_up: String = ""
		if not bl.has(String(b["upgrade_of"])):
			r_up = "needs_base_building"
		elif not Inv.has_all(a["inv"], cost):
			r_up = "insufficient_items"
		return {"valid": r_up == "", "reason": r_up, "holding_id": hid, "hex": axial_hex, "upgrade": true}
	var have: int = 0
	for x in bl:
		if Economy.group_of(Content.building(String(x))) == Economy.group_of(b):
			have += 1
	var reason: String = ""
	if have >= int(b["max"]):
		reason = "building_limit"
	elif not world_ok:
		reason = "blocked"
	elif plot_here:
		reason = "plot_here"
	else:
		reason = Economy.site_free(state as MatchState, h, axial_hex)
		if reason == "" and not Inv.has_all(a["inv"], cost):
			reason = "insufficient_items"
	return {"valid": reason == "", "reason": reason, "holding_id": hid, "hex": axial_hex, "upgrade": false}

static func build_model(state: Object, actor_id: int = -1) -> Dictionary:
	var a: Dictionary = _actor(state, actor_id)
	var inv: Dictionary = a.get("inv", {})
	var near: int = own_holding_near(state, a.get("hex", Vector2i.ZERO))
	var rows: Array = []
	var ids: Array = Content.buildings().keys()
	ids.sort()
	for id in ids:
		var b: Dictionary = Content.building(String(id))
		var up: bool = b.has("upgrade_of")
		var here: int = 0
		var bl: Array = state.get("holdings")[near]["buildings"] if near >= 0 else []
		for x in bl:
			if Economy.group_of(Content.building(String(x))) == Economy.group_of(b):
				here += 1
		var cost_d: Dictionary = Economy.build_cost(a, b)
		var cost: Array = bundle_entries(cost_d, inv)
		var afford: bool = Inv.has_all(inv, cost_d)
		var reason: String = ""
		if not Quests.unlocked(a, String(b.get("requires_unlock", ""))):
			reason = "locked_building"
		elif near < 0:
			reason = "no_own_holding_nearby"
		elif up and not bl.has(String(b["upgrade_of"])):
			reason = "needs_base_building"
		elif up and bl.has(String(id)):
			reason = "building_limit"
		elif not up and here >= int(b["max"]):
			reason = "building_limit"
		elif not afford:
			reason = "insufficient_items"
		rows.append({"id": String(id), "name": String(b["name"]), "cost": cost, "afford": afford, "max": int(b["max"]), "count_here": here,
			"reason": reason, "info": _building_info(b), "buildable": reason == "", "upgrade": up,
			"upgrade_of": String(b.get("upgrade_of", "")), "group": Economy.group_of(b)})
	return {"holding_id": near, "holding_name": String(state.get("holdings")[near]["name"]) if near >= 0 else "", "rows": rows}

static func _building_info(b: Dictionary) -> String:
	var bits: Array[String] = []
	if b.has("upgrade_of"):
		bits.append("Upgrade of %s" % String(Content.building(String(b["upgrade_of"])).get("name", "?")))
	if b.has("defense"):
		bits.append("Defense +%d" % int(b["defense"]))
	if b.has("vision"):
		bits.append("Sees %d hexes" % int(b["vision"]))
	if b.has("recruit_per_day"):
		bits.append("Recruits %d/day for %d coin" % [int(b["recruit_per_day"]), int(b.get("recruit_coin", 0))])
	if b.has("steal_guard"):
		bits.append("Thieves %d%% less likely" % int(round(float(b["steal_guard"]) * 100.0)))
	if b.has("loot_shield"):
		bits.append("Loot -%d%%" % int(round(float(b["loot_shield"]) * 100.0)))
	if b.has("work"):
		var w: Dictionary = b["work"]
		if w.has("outputs"):
			var o: Array[String] = []
			for k in (w["outputs"] as Dictionary).keys():
				o.append("%s +%d/day" % [UiKit.item_name(String(k)), int(w["outputs"][k])])
			bits.append(", ".join(o))
		if w.has("batches"):
			bits.append("Cooks %d ration batches/day" % int(w["batches"]))
		if bool(w.get("waters", false)):
			bits.append("Waters nearby plots" if int(w.get("waters_range", 0)) == 0 else "Waters plots up to %d hexes away" % int(w["waters_range"]))
		if w.has("inputs"):
			var i: Array[String] = []
			for k in (w["inputs"] as Dictionary).keys():
				i.append("%s x%d" % [UiKit.item_name(String(k)), int(w["inputs"][k])])
			bits.append("uses " + ", ".join(i) + " a day")
	if bool(b.get("station", false)):
		bits.append("Crafting station")
	if b.has("yield_bonus"):
		bits.append("Harvest +%d" % int(b["yield_bonus"]))
	if b.has("garrison_cap"):
		bits.append("Garrison cap +%d" % int(b["garrison_cap"]))
	if b.has("standing_bonus"):
		bits.append("Standing +%d" % int(b["standing_bonus"]))
	if b.has("spoil_cut"):
		bits.append("Spoilage halved")
	if b.has("heal_leader"):
		bits.append("Heals the leader %d%% each dawn" % int(round(float(b["heal_leader"]) * 100.0)))
	if b.has("levy_cut"):
		bits.append("Purge Levy -%d%%" % int(round(float(b["levy_cut"]) * 100.0)))
	if String(b.get("requires_unlock", "")) != "":
		bits.append("Questline reward")
	return ", ".join(bits)

static func craft_model(state: Object, actor_id: int = -1) -> Dictionary:
	var a: Dictionary = _actor(state, actor_id)
	var inv: Dictionary = a.get("inv", {})
	var near: bool = CmdUtil.nearest_owned_holding(state as MatchState, int(a.get("faction", 0)), a.get("hex", Vector2i.ZERO), 3) != -1
	var rows: Array = []
	var ids: Array = Content.recipes().keys()
	ids.sort()
	for id in ids:
		var r: Dictionary = Content.recipe(String(id))
		var tag: String = String(r.get("requires_tag", ""))
		var class_ok: bool = tag == "" or int(Combat.class_mod(a, tag, 0)) >= 1
		var unlocked: bool = Quests.unlocked(a, String(r.get("requires_unlock", "")))
		var near_h: int = CmdUtil.nearest_owned_holding(state as MatchState, int(a.get("faction", 0)), a.get("hex", Vector2i.ZERO), 3)
		var station_ok: bool = String(r.get("station", "")) == "" or (near_h != -1 and (state.get("holdings")[near_h]["buildings"] as Array).has(String(r["station"])))
		var inputs: Array = bundle_entries(r["inputs"], inv)
		var maxq: int = 99
		for e in inputs:
			maxq = mini(maxq, int(e["have"]) / maxi(int(e["need"]), 1))
		var reason: String = ""
		if not class_ok:
			reason = "class_required"
		elif not unlocked:
			reason = "locked_recipe"
		elif not near:
			reason = "not_near_own_holding"
		elif not station_ok:
			reason = "needs_station"
		elif maxq < 1:
			reason = "insufficient_items"
		var outs: Array = []
		for k in (r["outputs"] as Dictionary).keys():
			outs.append({"item": String(k), "name": UiKit.item_name(String(k)), "qty": int(r["outputs"][k])})
		rows.append({"id": String(id), "name": String(r["name"]), "inputs": inputs, "outputs": outs, "max_qty": maxi(maxq, 0), "reason": reason, "craftable": reason == ""})
	return {"near_holding": near, "rows": rows}

static func trade_model(state: Object, holding_id: int, actor_id: int = -1) -> Dictionary:
	var a: Dictionary = _actor(state, actor_id)
	var hs: Dictionary = state.get("holdings")
	if not hs.has(holding_id):
		return {"ok": false, "reason": "unknown_holding", "buy": [], "sell": [], "coin": 0, "merchant_coin": 0, "holding_name": ""}
	var h: Dictionary = hs[holding_id]
	var inv: Dictionary = a.get("inv", {})
	var coin: int = Inv.count(inv, Economy.COIN)
	var is_merchant: bool = bool(h.get("merchant", false)) and int(h["owner"]) == -1
	var in_range: bool = HexGrid.distance(a.get("hex", Vector2i.ZERO), h["hex"]) <= Economy.TRADE_RANGE
	var buy: Array = []
	var sell: Array = []
	var keys: Array = (h["store"] as Dictionary).keys()
	keys.sort()
	for k in keys:
		if k == Economy.COIN or int(h["store"][k]) <= 0:
			continue
		var price: int = Economy.buy_price(String(k), Economy.price_mult(h, String(k)), a)
		buy.append({"item": String(k), "name": UiKit.item_name(String(k)), "price": price, "stock": int(h["store"][k]), "affordable": coin >= price})
	var ik: Array = inv.keys()
	ik.sort()
	for k in ik:
		if k == Economy.COIN or int(inv[k]) <= 0:
			continue
		sell.append({"item": String(k), "name": UiKit.item_name(String(k)), "price": Economy.sell_price(a, String(k), Economy.price_mult(h, String(k))), "have": int(inv[k])})
	var reason: String = ""
	if not is_merchant:
		reason = "not_a_merchant"
	elif state.get("phase") == &"PURGE_ACTIVE":
		reason = "market_closed"
	elif not in_range:
		reason = "too_far"
	return {"ok": reason == "", "reason": reason, "holding_name": String(h["name"]), "holding_id": holding_id, "buy": buy, "sell": sell, "coin": coin,
		"merchant_coin": Inv.count(h["store"], Economy.COIN)}

## Nearest merchant holding within `max_d` hexes of the player -> id or -1.
static func merchant_near(state: Object, max_d: int = 1, actor_id: int = -1) -> int:
	var a: Dictionary = _actor(state, actor_id)
	var best: int = -1
	var bd: int = 999
	var hs: Dictionary = state.get("holdings")
	var ids: Array = hs.keys()
	ids.sort()
	for id in ids:
		var h: Dictionary = hs[id]
		if not (bool(h.get("merchant", false)) and int(h["owner"]) == -1):
			continue
		var d: int = HexGrid.distance(a.get("hex", Vector2i.ZERO), h["hex"])
		if d <= max_d and d < bd:
			bd = d
			best = int(id)
	return best

## Rations policy + days of food under each policy.
static func policy_model(state: Object, actor_id: int = -1) -> Dictionary:
	var a: Dictionary = _actor(state, actor_id)
	var fid: int = int(a.get("faction", 0))
	var f: Dictionary = state.get("factions")[fid]
	var persons: int = Economy.persons(state as MatchState, fid)
	var rations: int = Economy.rations_available(state as MatchState, fid)
	var opts: Array = []
	for v in ["full", "half", "none"]:
		var per_day: int = persons if v == "full" else ((persons + 1) / 2 if v == "half" else 0)
		var days: float = 99.0 if per_day == 0 else float(rations) / float(per_day)
		var note: String = "Everyone eats" if v == "full" else ("Half rations: hunger builds slowly" if v == "half" else "No food issued: starvation and desertion")
		opts.append({"value": v, "per_day": per_day, "days": days, "note": note})
	var stances: Array = []
	var hs: Dictionary = state.get("holdings")
	var ids: Array = hs.keys()
	ids.sort()
	for id in ids:
		if int(hs[id]["owner"]) == fid:
			stances.append({"holding_id": int(id), "name": String(hs[id]["name"]), "stance": String(hs[id].get("stance", "defend")), "garrison": int(hs[id]["garrison"])})
	return {"policy": String(f.get("ration_policy", "full")), "persons": persons, "rations": rations, "options": opts, "stances": stances, "hunger_days": int(f.get("hunger_days", 0))}

## One row per own holding with shortage flags ("rations", "undefended", "coin", "starving").
static func holdings_model(state: Object, actor_id: int = -1) -> Dictionary:
	var a: Dictionary = _actor(state, actor_id)
	var fid: int = int(a.get("faction", 0))
	var f: Dictionary = state.get("factions")[fid]
	var hs: Dictionary = state.get("holdings")
	var ids: Array = hs.keys()
	ids.sort()
	var rows: Array = []
	var short_total: int = 0
	for id in ids:
		var h: Dictionary = hs[id]
		if int(h["owner"]) != fid:
			continue
		var store: Dictionary = h["store"]
		var garrison: int = int(h["garrison"])
		var rat: int = Inv.count(store, Economy.RATION)
		var days: float = 99.0 if garrison <= 0 else float(rat) / float(garrison)
		var flags: Array[String] = []
		if garrison > 0 and days < 1.0:
			flags.append("rations")
		if garrison <= 0:
			flags.append("undefended")
		if (h["buildings"] as Array).has("lfg:building/barracks") and Inv.count(store, Economy.COIN) < int(Content.building("lfg:building/barracks").get("recruit_coin", 0)):
			flags.append("coin")
		if int(f.get("hunger_days", 0)) > 0:
			flags.append("starving")
		short_total += flags.size()
		var items: Array = []
		var keys: Array = store.keys()
		keys.sort()
		for k in keys:
			if int(store[k]) > 0:
				items.append({"item": String(k), "name": UiKit.item_name(String(k)), "count": int(store[k])})
		var near: bool = HexGrid.distance(a.get("hex", Vector2i.ZERO), h["hex"]) <= Economy.TRADE_RANGE
		rows.append({"id": int(id), "name": String(h["name"]), "tier": int(h["tier"]), "garrison": garrison, "ration_days": days, "rations": rat,
			"items": items, "buildings": (h["buildings"] as Array).duplicate(), "flags": flags, "near": near, "player_rations": Inv.count(a.get("inv", {}), Economy.RATION)})
	return {"rows": rows, "shortages": short_total, "hunger_days": int(f.get("hunger_days", 0))}
