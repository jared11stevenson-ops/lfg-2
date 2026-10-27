class_name Farming
extends RefCounted
## plant / water / harvest / craft / eat. Each handler returns "" on success or an error code; validation completes before any mutation.
const OUTDOOR_MIN := 2     # Purge-only crops need tending outdoors, away from the walls
const PLANT_RANGE := 3
const TEND_RANGE := 2

static func plots_of(state: MatchState, hid: int) -> int:
	var n: int = 0
	for k in state.plots.keys():
		if int(state.plots[k]["holding"]) == hid:
			n += 1
	return n

static func plant(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	var crop: Dictionary = Content.crop(CmdUtil.s(args.get("crop", "")))
	if crop.is_empty():
		return "unknown_crop"
	if not Standing.rank_ok(state, int(a["faction"]), int(crop.get("rank", 0))):
		return "rank_required"
	var hv: Variant = CmdUtil.parse_hex(args.get("hex"))
	if hv == null:
		return "bad_hex"
	var h: Vector2i = hv
	if HexGrid.distance(a["hex"], h) > PLANT_RANGE:
		return "too_far"
	var idx: int = HexGrid.index(h)
	if int(state.world["terrain"][idx]) != WorldGen.T_GROUND:
		return "bad_terrain"
	if not (crop["biomes"] as Array).has(WorldGen.biome_at(state.world, h)):
		return "bad_biome"
	if state.plots.has(MatchState.plot_key(h)):
		return "occupied"
	if CmdUtil.holding_at(state, h) != -1:
		return "occupied"
	for oh in state.holdings.values():
		if (oh.get("sites", {}) as Dictionary).has(MatchState.plot_key(h)):
			return "occupied"
	var hid: int = CmdUtil.nearest_owned_holding(state, int(a["faction"]), h, PLANT_RANGE)
	if hid == -1:
		return "not_near_own_holding"
	if plots_of(state, hid) >= Standing.plot_cap(state, int(a["faction"])):
		return "plot_limit"
	if bool(crop.get("purge_only", false)) and HexGrid.distance(h, state.holdings[hid]["hex"]) < OUTDOOR_MIN:
		return "needs_outdoors"
	var cost: Dictionary = {String(crop["seed"]): 1}
	if not Inv.has_all(a["inv"], cost):
		return "no_seed"
	Inv.remove_all(a["inv"], cost)
	state.plots[MatchState.plot_key(h)] = {"crop": crop["id"], "age": 0, "watered": false, "dry_days": 0, "holding": hid}
	events.append({"type": &"crop_planted", "actor": a["id"], "hex": h, "crop": crop["id"]})
	return ""

static func water(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	var hv: Variant = CmdUtil.parse_hex(args.get("hex"))
	if hv == null:
		return "bad_hex"
	var h: Vector2i = hv
	var p: Dictionary = state.plots.get(MatchState.plot_key(h), {})
	if p.is_empty():
		return "no_plot"
	if HexGrid.distance(a["hex"], h) > TEND_RANGE:
		return "too_far"
	if int(state.holdings[int(p["holding"])]["owner"]) != int(a["faction"]):
		return "not_yours"
	var wc: Dictionary = Content.crop(String(p["crop"]))
	if bool(wc.get("purge_only", false)):
		# tending: only in the Purge; it is what lets the bloom grow one stage when the Purge resolves
		if state.phase != &"PURGE_ACTIVE":
			return "purge_only"
		if bool(p.get("tended", false)):
			return "already_watered"
		p["tended"] = true
		events.append({"type": &"crop_watered", "actor": a["id"], "hex": h, "tended": true})
		return ""
	if not bool(wc["needs_water"]):
		return "not_needed"
	if bool(p["watered"]):
		return "already_watered"
	p["watered"] = true
	events.append({"type": &"crop_watered", "actor": a["id"], "hex": h})
	return ""

static func harvest(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	var hv: Variant = CmdUtil.parse_hex(args.get("hex"))
	if hv == null:
		return "bad_hex"
	var h: Vector2i = hv
	var key: String = MatchState.plot_key(h)
	if state.plots.has(key):
		var p: Dictionary = state.plots[key]
		var crop: Dictionary = Content.crop(String(p["crop"]))
		if HexGrid.distance(a["hex"], h) > TEND_RANGE:
			return "too_far"
		if int(state.holdings[int(p["holding"])]["owner"]) != int(a["faction"]):
			return "not_yours"
		if int(p["age"]) < int(crop["grow_days"]):
			return "not_ready"
		var hold: Dictionary = state.holdings[int(p["holding"])]
		var biome: String = WorldGen.biome_at(state.world, h)
		var yield_n: int = int(crop["yield"]) + int(crop.get("biome_bonus", {}).get(biome, 0)) + int(Combat.class_mod(a, "yield_bonus", 0)) \
			+ Standing.yield_bonus(state, hold)
		if Economy.blessed(state, hold):
			yield_n += 1
		if biome == "fungal_grove" and int(Combat.class_mod(a, "grove_growth", 0)) > 0:
			yield_n += 1
		yield_n = maxi(1, yield_n)
		var gain: Dictionary = {String(crop["item"]): yield_n}
		Inv.add_all(gain, {String(crop["seed"]): 1})
		if not Inv.can_carry(a, gain):
			return "no_room"
		Inv.add_all(a["inv"], gain)
		Standing.note_output(state, int(a["faction"]), {String(crop["item"]): yield_n})
		state.plots.erase(key)
		events.append({"type": &"crop_harvested", "actor": a["id"], "hex": h, "crop": crop["id"], "items": gain})
		return ""
	if state.drops.has(key):
		if HexGrid.distance(a["hex"], h) > 1:
			return "too_far"
		var d: Dictionary = state.drops[key]
		if not Inv.can_carry(a, d):
			return "no_room"
		Inv.add_all(a["inv"], d)
		state.drops.erase(key)
		events.append({"type": &"items_picked_up", "actor": a["id"], "hex": h, "items": d})
		return ""
	if Fx.cache_at(state, int(a["faction"]), h) and HexGrid.distance(a["hex"], h) <= 1:
		return Fx.recover_cache(state, a, h, events)
	return "nothing_to_harvest"

static func craft(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	var r: Dictionary = Content.recipe(CmdUtil.s(args.get("recipe", "")))
	if r.is_empty():
		return "unknown_recipe"
	var n: int = 1
	if args.has("qty"):
		n = Inv.parse_qty(args["qty"])
		if n < 0 or n > 99:
			return "bad_quantity"
	if not Standing.rank_ok(state, int(a["faction"]), int(r.get("rank", 0))):
		return "rank_required"
	var tag: String = String(r.get("requires_tag", ""))
	if tag != "" and int(Combat.class_mod(a, tag, 0)) < 1:
		return "class_required"
	if not Quests.unlocked(a, String(r.get("requires_unlock", ""))):
		return "locked_recipe"
	var near_h: int = CmdUtil.nearest_owned_holding(state, int(a["faction"]), a["hex"], 3)
	if near_h == -1:
		return "not_near_own_holding"
	if String(r.get("station", "")) != "" and not (state.holdings[near_h]["buildings"] as Array).has(String(r["station"])):
		return "needs_station"
	var cost: Dictionary = {}
	for k in (r["inputs"] as Dictionary).keys():
		cost[k] = int(r["inputs"][k]) * n
	var out: Dictionary = {}
	for k in (r["outputs"] as Dictionary).keys():
		out[k] = int(r["outputs"][k]) * n
	if (r.get("tags", []) as Array).has("ration"):
		out["lfg:item/ration"] = int(out.get("lfg:item/ration", 0)) + int(Combat.class_mod(a, "ration_bonus", 0))
	if not Inv.has_all(a["inv"], cost):
		return "insufficient_items"
	# room check against the post-consumption inventory
	if not Inv.can_carry(a, out, cost):
		return "no_room"
	Inv.remove_all(a["inv"], cost)
	Inv.add_all(a["inv"], out)
	events.append({"type": &"item_crafted", "actor": a["id"], "recipe": r["id"], "qty": n, "items": out})
	return ""

static func eat(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	var item: String = CmdUtil.s(args.get("item", "lfg:item/ration"))
	var def: Dictionary = Content.item(item)
	if def.is_empty() or not def.has("food"):
		return "not_food"
	var n: int = 1
	if args.has("qty"):
		n = Inv.parse_qty(args["qty"])
		if n < 0 or n > 20:
			return "bad_quantity"
	if not Inv.has_all(a["inv"], {item: n}):
		return "insufficient_items"
	Inv.remove_all(a["inv"], {item: n})
	var healed: int = Combat.heal(a, int(def["food"]) * n)
	if bool(def.get("ration", false)):
		var f: Dictionary = state.factions[int(a["faction"])]
		f["hunger_days"] = maxi(0, int(f["hunger_days"]) - n)
	events.append({"type": &"ate", "actor": a["id"], "item": item, "qty": n, "healed": healed})
	return ""

## Daily growth. Called once at each dawn.
static func dawn_crops(state: MatchState, events: Array) -> void:
	var dead: Array[String] = []
	var keys: Array = state.plots.keys()
	keys.sort()
	for k in keys:
		var p: Dictionary = state.plots[k]
		var crop: Dictionary = Content.crop(String(p["crop"]))
		if bool(crop.get("purge_only", false)):
			continue      # grows only through tended Purges (purge_growth)
		var grew: bool = true
		if bool(crop["needs_water"]) and not bool(p["watered"]):
			grew = false
			p["dry_days"] = int(p["dry_days"]) + 1
			if int(p["dry_days"]) >= 3 and int(p["age"]) < int(crop["grow_days"]):
				dead.append(k)
		else:
			p["dry_days"] = 0
		p["watered"] = false
		if grew and int(p["age"]) < int(crop["grow_days"]):
			p["age"] = int(p["age"]) + 1
			if int(p["age"]) < int(crop["grow_days"]) and _grove_boost(state, k, p):
				p["age"] = int(p["age"]) + 1
			if int(p["age"]) < int(crop["grow_days"]):
				var gf: float = Standing.growth_frac(state, int(state.holdings[int(p["holding"])]["owner"]))
				if gf > 0.0:
					p["gx"] = float(p.get("gx", 0.0)) + gf
					if float(p["gx"]) >= 1.0:
						p["gx"] = float(p["gx"]) - 1.0
						p["age"] = int(p["age"]) + 1
			if int(p["age"]) >= int(crop["grow_days"]):
				var parts: PackedStringArray = (k as String).split(",")
				events.append({"type": &"crop_grown", "hex": Vector2i(int(parts[0]), int(parts[1])), "crop": crop["id"]})
	for k in dead:
		state.plots.erase(k)
		events.append({"type": &"crop_withered", "key": k})

## Nyx: a plot of hers in a Fungal Grove grows two days per day.
static func _grove_boost(state: MatchState, key: String, p: Dictionary) -> bool:
	var hold: Dictionary = state.holdings.get(int(p["holding"]), {})
	if hold.is_empty() or int(hold["owner"]) < 0:
		return false
	var leader: Dictionary = state.actors.get(int(state.factions[int(hold["owner"])]["leader"]), {})
	if leader.is_empty() or not leader["alive"] or int(Combat.class_mod(leader, "grove_growth", 0)) < 1:
		return false
	var parts: PackedStringArray = key.split(",")
	return WorldGen.biome_at(state.world, Vector2i(int(parts[0]), int(parts[1]))) == "fungal_grove"

## Called once when a Purge resolves: tended Purgebloom plots grow one stage; untended ones do not.
static func purge_growth(state: MatchState, events: Array) -> void:
	var keys: Array = state.plots.keys()
	keys.sort()
	for k in keys:
		var p: Dictionary = state.plots[k]
		var crop: Dictionary = Content.crop(String(p["crop"]))
		if not bool(crop.get("purge_only", false)):
			continue
		if bool(p.get("tended", false)) and int(p["age"]) < int(crop["grow_days"]):
			p["age"] = int(p["age"]) + 1
			if int(p["age"]) >= int(crop["grow_days"]):
				var parts: PackedStringArray = (k as String).split(",")
				events.append({"type": &"crop_grown", "hex": Vector2i(int(parts[0]), int(parts[1])), "crop": crop["id"]})
		p["tended"] = false
