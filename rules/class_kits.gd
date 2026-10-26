class_name ClassKits
extends RefCounted
## Abilities of the classes added in pass 1: Tavi, Pip, Sable, Quill, Forge, Nyx, Rook, Dune, Halo.
## Each handler validates fully, then mutates; returns "" or an error code. Energy/cooldown are charged by Abilities.use.
const MINE_TABLE: Dictionary = {
	"meadow": [2, 1], "shore": [1, 1], "fungal_grove": [2, 1], "ruins": [1, 3], "salt_flats": [0, 3], "highlands": [1, 3], "bog": [2, 0]}  # [timber, stone]
const CACHE_LIMIT := 3
const BLESS_RANGE := 3

static func _now(state: MatchState) -> float:
	return float(state.clock["elapsed"])

static func _ground(state: MatchState, h: Vector2i) -> bool:
	return int(state.world["terrain"][HexGrid.index(h)]) == WorldGen.T_GROUND

static func run(state: MatchState, a: Dictionary, ab: Dictionary, args: Dictionary, events: Array) -> String:
	match String(ab["id"]):
		"lfg:ability/mine": return _mine(state, a, ab, events)
		"lfg:ability/sentinel_post": return _post(state, a, ab, events)
		"lfg:ability/dash": return _dash(state, a, ab, args, events)
		"lfg:ability/snare": return _snare(state, a, ab, events)
		"lfg:ability/track": return _track(state, a, ab, events)
		"lfg:ability/truce": return _truce(state, a, ab, args, events)
		"lfg:ability/siege_ram": return _ram(state, a, ab, args, events)
		"lfg:ability/spore_swarm": return _swarm(state, a, ab, args, events)
		"lfg:ability/rally": return _rally(state, a, ab, events)
		"lfg:ability/cache": return _cache(state, a, ab, args, events)
		"lfg:ability/bless": return _bless(state, a, ab, args, events)
		"lfg:ability/ward": return _ward(state, a, ab, events)
	return "ability_not_implemented"

static func _mine(state: MatchState, a: Dictionary, ab: Dictionary, events: Array) -> String:
	if state.phase == &"PURGE_ACTIVE":
		return "not_in_purge"
	if not _ground(state, a["hex"]):
		return "bad_terrain"
	var t: Array = MINE_TABLE[WorldGen.biome_at(state.world, a["hex"])]
	var bonus: int = int(Combat.class_mod(a, "mine_bonus", 0))
	var gain: Dictionary = {}
	if int(t[0]) > 0:
		gain["lfg:item/timber"] = int(t[0]) + (bonus if int(t[0]) > 1 else 0)
	if int(t[1]) > 0:
		gain["lfg:item/stone"] = int(t[1]) + (bonus if int(t[1]) > 1 else 0)
	if gain.is_empty():
		return "nothing_here"
	if not Inv.can_carry(a, gain):
		return "no_room"
	Inv.add_all(a["inv"], gain)
	events.append({"type": &"ability_used", "actor": a["id"], "ability": ab["id"], "items": gain})
	return ""

static func _post(state: MatchState, a: Dictionary, ab: Dictionary, events: Array) -> String:
	if not _ground(state, a["hex"]):
		return "bad_terrain"
	var now: float = _now(state)
	var id: int = Fx.place(state, {"type": "post", "owner": a["id"], "faction": a["faction"], "hex": a["hex"], "until": MatchState.q(now + float(ab["duration"])),
		"next": MatchState.q(now + Fx.POST_PERIOD), "dmg": int(ab["damage"]), "range": int(ab["range"])}, int(ab["max_active"]), events)
	events.append({"type": &"ability_used", "actor": a["id"], "ability": ab["id"], "fx": id})
	return ""

static func _dash(state: MatchState, a: Dictionary, ab: Dictionary, args: Dictionary, events: Array) -> String:
	if Movement.rooted(state, a):
		return "rooted"
	var hv: Variant = CmdUtil.parse_hex(args.get("to"))
	if hv == null:
		return "bad_hex"
	var to: Vector2i = hv
	var rng: int = int(ab["range"])
	if to == a["hex"] or HexGrid.distance(a["hex"], to) > rng:
		return "too_far"
	if WorldGen.move_cost(state.world, to) <= 0.0:
		return "impassable"
	var w: Dictionary = state.world
	var path: Array[Vector2i] = HexGrid.find_path(a["hex"], to, func(h: Vector2i) -> float: return WorldGen.move_cost(w, h), 120)
	if path.is_empty() or path.size() > rng:
		return "no_path"
	for o in state.actors.values():
		if o["alive"] and int(o["id"]) != int(a["id"]) and o["hex"] == to:
			return "occupied"
	var tid: int = -1
	var dmg: int = 0
	if args.has("target"):
		tid = CmdUtil.parse_id(args["target"])
		var t: Dictionary = state.actors.get(tid, {})
		if t.is_empty() or not t["alive"] or tid == int(a["id"]):
			return "bad_target"
		if int(t["faction"]) == int(a["faction"]):
			return "friendly"
		if HexGrid.distance(to, t["hex"]) > 1:
			return "too_far"
		if t["kind"] != "enemy" and state.phase != &"PURGE_ACTIVE":
			return "not_purge"
		dmg = Combat.calc_damage(state, a, t, Combat.atk_of(state, a) * float(ab["strike_mult"]))
	a["hex"] = to
	a["move"] = {}
	events.append({"type": &"actor_moved", "actor": a["id"], "hex": to, "dash": true})
	Combat.add_effect(a, "evade", MatchState.q(_now(state) + float(ab["duration"])))
	events.append({"type": &"ability_used", "actor": a["id"], "ability": ab["id"], "to": to, "target": tid, "damage": dmg})
	if tid != -1:
		Combat.hurt(state, tid, dmg, int(a["id"]), events, "dash")
	return ""

static func _snare(state: MatchState, a: Dictionary, ab: Dictionary, events: Array) -> String:
	if not _ground(state, a["hex"]):
		return "bad_terrain"
	for f in state.fx:
		if f["type"] == "trap" and f["hex"] == a["hex"]:
			return "occupied"
	var now: float = _now(state)
	var id: int = Fx.place(state, {"type": "trap", "owner": a["id"], "faction": a["faction"], "hex": a["hex"], "until": MatchState.q(now + float(ab["duration"])),
		"arm_at": MatchState.q(now + float(ab["arm"])), "dmg": int(ab["damage"]), "root": float(ab["root"])}, int(ab["max_active"]), events)
	events.append({"type": &"ability_used", "actor": a["id"], "ability": ab["id"], "fx": id})
	return ""

static func _track(state: MatchState, a: Dictionary, ab: Dictionary, events: Array) -> String:
	var found: Array = []
	var ids: Array = state.actors.keys()
	ids.sort()
	for id in ids:
		var o: Dictionary = state.actors[id]
		if o["kind"] == "enemy" and o["alive"] and HexGrid.distance(o["hex"], a["hex"]) <= int(ab["radius"]):
			found.append({"id": id, "hex": o["hex"], "archetype": o["archetype"], "hp": o["hp"]})
	if found.is_empty():
		return "no_targets"
	Combat.add_effect(a, "tracking", MatchState.q(_now(state) + float(ab["duration"])))
	events.append({"type": &"ability_used", "actor": a["id"], "ability": ab["id"], "tracked": found})
	return ""

static func _truce(state: MatchState, a: Dictionary, ab: Dictionary, args: Dictionary, events: Array) -> String:
	var now: float = _now(state)
	var fid: int = -1
	var hid: int = -1
	if args.has("faction"):
		fid = CmdUtil.parse_id(args["faction"])
		var f: Dictionary = state.factions.get(fid, {})
		if f.is_empty() or fid == int(a["faction"]) or not f["alive"] or not f["is_ai"]:
			return "bad_faction"
		hid = CmdUtil.nearest_owned_holding(state, fid, a["hex"], int(ab["range"]))
		if hid == -1:
			return "too_far"
		var gift: Dictionary = {"lfg:item/coin": int(ab["gift"])}
		if not Inv.has_all(a["inv"], gift):
			return "insufficient_items"
		if not Inv.room_for(state.holdings[hid]["store"], gift):
			return "no_room"
		Inv.remove_all(a["inv"], gift)
		Inv.add_all(state.holdings[hid]["store"], gift)
		f["truce_until"] = MatchState.q(now + float(ab["faction_secs"]))
		events.append({"type": &"truce_signed", "actor": a["id"], "faction": fid, "holding": hid, "until": f["truce_until"]})
	Combat.add_effect(a, "truce", MatchState.q(now + float(ab["duration"])))
	events.append({"type": &"ability_used", "actor": a["id"], "ability": ab["id"], "faction": fid})
	return ""

static func _ram(state: MatchState, a: Dictionary, ab: Dictionary, args: Dictionary, events: Array) -> String:
	if state.phase != &"PURGE_ACTIVE":
		return "not_purge"
	var hid: int = CmdUtil.parse_id(args.get("holding"))
	if not state.holdings.has(hid):
		return "unknown_holding"
	var h: Dictionary = state.holdings[hid]
	if int(h["owner"]) == int(a["faction"]):
		return "already_yours"
	if HexGrid.distance(a["hex"], h["hex"]) > Conquest.CAPTURE_RANGE:
		return "too_far"
	var now: float = _now(state)
	var best: String = ""
	var bd: float = 0.0
	for b in h["buildings"]:
		var d: float = float(Content.building(String(b)).get("defense", 0))
		if d > bd:
			bd = d
			best = String(b)
	if best != "":
		(h["buildings"] as Array).erase(best)
	h["breach"] = MatchState.q(now + float(ab["duration"]))
	Combat.add_effect(a, "ram", MatchState.q(now + float(ab["duration"])))
	events.append({"type": &"ability_used", "actor": a["id"], "ability": ab["id"], "holding": hid, "destroyed": best, "breach_until": h["breach"]})
	return ""

static func _swarm(state: MatchState, a: Dictionary, ab: Dictionary, args: Dictionary, events: Array) -> String:
	var at: Vector2i = a["hex"]
	if args.has("at"):
		var hv: Variant = CmdUtil.parse_hex(args["at"])
		if hv == null:
			return "bad_hex"
		at = hv
	if HexGrid.distance(a["hex"], at) > int(ab["range"]):
		return "too_far"
	var grove: bool = WorldGen.biome_at(state.world, at) == "fungal_grove"
	var radius: int = int(ab["radius"]) if grove else maxi(1, int(ab["radius"]) - 1)
	var now: float = _now(state)
	var id: int = Fx.place(state, {"type": "zone", "owner": a["id"], "faction": a["faction"], "hex": at, "until": MatchState.q(now + float(ab["duration"])),
		"next": MatchState.q(now + Fx.ZONE_PERIOD), "radius": radius, "dps": int(ab["dps"])}, 2, events)
	events.append({"type": &"ability_used", "actor": a["id"], "ability": ab["id"], "fx": id, "at": at, "radius": radius})
	return ""

static func _rally(state: MatchState, a: Dictionary, ab: Dictionary, events: Array) -> String:
	var now: float = _now(state)
	var until: float = MatchState.q(now + float(ab["duration"]))
	var lifted: Array[int] = []
	for hid in state.holdings_of(int(a["faction"])):
		if HexGrid.distance(state.holdings[hid]["hex"], a["hex"]) <= int(ab["radius"]):
			state.holdings[hid]["rally"] = until
			lifted.append(hid)
	Combat.add_effect(a, "rally", until)
	events.append({"type": &"ability_used", "actor": a["id"], "ability": ab["id"], "holdings": lifted})
	return ""

static func _cache(state: MatchState, a: Dictionary, ab: Dictionary, args: Dictionary, events: Array) -> String:
	var pb: Dictionary = Inv.parse_bundle(args.get("items"))
	if not pb["ok"]:
		return pb["error"]
	var bundle: Dictionary = pb["bundle"]
	if Inv.total(bundle) > int(ab["max_items"]):
		return "too_many_items"
	if not _ground(state, a["hex"]):
		return "bad_terrain"
	var mine: int = 0
	for f in state.fx:
		if f["type"] == "cache":
			if f["hex"] == a["hex"]:
				return "occupied"
			if int(f["faction"]) == int(a["faction"]):
				mine += 1
	if mine >= CACHE_LIMIT:
		return "cache_limit"
	var need: Dictionary = bundle.duplicate()
	Inv.add_all(need, {"lfg:item/gadget": 1})
	if not Inv.has_all(a["inv"], need):
		return "insufficient_items"
	Inv.remove_all(a["inv"], need)
	var id: int = Fx.place(state, {"type": "cache", "owner": a["id"], "faction": a["faction"], "hex": a["hex"], "items": bundle}, 99, events)
	events.append({"type": &"ability_used", "actor": a["id"], "ability": ab["id"], "fx": id, "items": bundle})
	return ""

static func _bless(state: MatchState, a: Dictionary, ab: Dictionary, args: Dictionary, events: Array) -> String:
	if state.phase == &"PURGE_ACTIVE":
		return "not_in_purge"
	var hid: int = CmdUtil.parse_id(args.get("holding"))
	if not state.holdings.has(hid):
		return "unknown_holding"
	var h: Dictionary = state.holdings[hid]
	if int(h["owner"]) != int(a["faction"]):
		return "not_yours"
	if HexGrid.distance(a["hex"], h["hex"]) > BLESS_RANGE:
		return "too_far"
	if Economy.blessed(state, h):
		return "already_blessed"
	h["blessed_day"] = int(state.clock["day"]) + int(ab["days"])
	events.append({"type": &"ability_used", "actor": a["id"], "ability": ab["id"], "holding": hid, "until_day": h["blessed_day"]})
	return ""

static func _ward(state: MatchState, a: Dictionary, ab: Dictionary, events: Array) -> String:
	var now: float = _now(state)
	var until: float = MatchState.q(now + float(ab["duration"]))
	var covered: Array[int] = []
	var ids: Array = state.actors.keys()
	ids.sort()
	for id in ids:
		var o: Dictionary = state.actors[id]
		if o["alive"] and o["kind"] != "enemy" and int(o["faction"]) == int(a["faction"]) and HexGrid.distance(o["hex"], a["hex"]) <= int(ab["radius"]):
			Combat.add_effect(o, "ward", until)
			covered.append(int(id))
	var hs: Array[int] = []
	for hid in state.holdings_of(int(a["faction"])):
		if HexGrid.distance(state.holdings[hid]["hex"], a["hex"]) <= int(ab["radius"]):
			state.holdings[hid]["ward"] = until
			hs.append(hid)
	events.append({"type": &"ability_used", "actor": a["id"], "ability": ab["id"], "actors": covered, "holdings": hs})
	return ""
