class_name Conquest
extends RefCounted
## Capture and steal. Only legal in PURGE_ACTIVE. Item moves are conserving (store -> inventory/store), never created or destroyed.
const MAX_COMMIT := 30
const STEAL_CAP := 5
const CAPTURE_RANGE := 1
const SUPPLY_RANGE := 14

static func _active(state: MatchState, h: Dictionary, key: String) -> bool:
	return float(h.get(key, 0.0)) > float(state.clock["elapsed"])

static func defender_power(state: MatchState, h: Dictionary) -> float:
	var p: float = float(h["garrison"]) * 3.0 + 2.0
	var breached: bool = _active(state, h, "breach")
	if not breached:
		for b in h["buildings"]:
			p += float(Content.building(String(b)).get("defense", 0))
	var of: int = int(h["owner"])
	if of >= 0:
		var l: Dictionary = state.actors.get(int(state.factions[of]["leader"]), {})
		if not l.is_empty() and l["alive"] and HexGrid.distance(l["hex"], h["hex"]) <= 2:
			p += float(l["atk"]) * 2.0
	if breached:
		p *= 0.75
	if _active(state, h, "rally"):
		p *= 1.4
	if _active(state, h, "ward"):
		p *= 1.5
	return p

static func attacker_power(state: MatchState, actor: Dictionary, commit: int, boost: float = 1.0) -> float:
	var base: float = 3.0
	if not actor.is_empty() and actor["kind"] != "party":
		base = Combat.atk_of(state, actor) * 2.0
	var pw: float = float(commit) * 3.0 * boost + base
	if not actor.is_empty() and Combat.has_effect(state, actor, "ram"):
		pw *= float(Combat.class_mod(actor, "siege_mult", 1.0))
	return pw

## Moves as much of `bundle` as fits (per item). Returns what moved.
static func move_fitting(from_inv: Dictionary, to_inv: Dictionary, bundle: Dictionary) -> Dictionary:
	var moved: Dictionary = {}
	for k in bundle.keys():
		var m: int = mini(int(bundle[k]), mini(int(from_inv.get(k, 0)), Inv.MAX_QTY - int(to_inv.get(k, 0))))
		if m > 0:
			moved[k] = m
	Inv.remove_all(from_inv, moved)
	Inv.add_all(to_inv, moved)
	return moved

static func _peaceful(state: MatchState, a: Dictionary) -> String:
	if int(Combat.class_mod(a, "pacifist", 0)) > 0:
		return "pacifist"
	if Combat.has_effect(state, a, "truce"):
		return "truce_active"
	return ""

static func capture(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	if state.phase != &"PURGE_ACTIVE":
		return "not_purge"
	var pe: String = _peaceful(state, a)
	if pe != "":
		return pe
	var hid: int = CmdUtil.parse_id(args.get("holding"))
	if not state.holdings.has(hid):
		return "unknown_holding"
	var h: Dictionary = state.holdings[hid]
	if int(h["owner"]) == int(a["faction"]):
		return "already_yours"
	if HexGrid.distance(a["hex"], h["hex"]) > CAPTURE_RANGE:
		return "too_far"
	var commit: int = 0
	if args.has("commit"):
		var c: Variant = args["commit"]
		if typeof(c) == TYPE_FLOAT and c == floorf(c):
			c = int(c)
		if typeof(c) != TYPE_INT or c < 0 or c > MAX_COMMIT:
			return "bad_commit"
		commit = c
	var from_id: int = -1
	if commit > 0:
		from_id = CmdUtil.parse_id(args.get("from", -1))
		if from_id == -1:
			from_id = CmdUtil.nearest_owned_holding(state, int(a["faction"]), h["hex"], Standing.supply_range(state, int(a["faction"])))
		if not state.holdings.has(from_id) or int(state.holdings[from_id]["owner"]) != int(a["faction"]):
			return "bad_source"
		if HexGrid.distance(state.holdings[from_id]["hex"], h["hex"]) > Standing.supply_range(state, int(a["faction"])):
			return "source_too_far"
		if int(state.holdings[from_id]["garrison"]) < commit:
			return "insufficient_troops"
	if not Combat.ready(state, a, "capture"):
		return "cooldown"
	Combat.set_cd(state, a, "capture", 10.0)
	resolve_capture(state, int(a["faction"]), int(a["id"]), hid, from_id, commit, events)
	return ""

## Shared by command + AI. Returns true when the holding changed hands.
static func resolve_capture(state: MatchState, fid: int, actor_id: int, hid: int, from_id: int, commit: int, events: Array) -> bool:
	var h: Dictionary = state.holdings[hid]
	var actor: Dictionary = state.actors.get(actor_id, {})
	var is_ai: bool = bool(state.factions[fid]["is_ai"])
	var boost: float = 1.0
	if from_id != -1 and _active(state, state.holdings[from_id], "rally"):
		boost = 1.25
	var att: float = attacker_power(state, actor, commit, boost) * (0.8 + 0.4 * state.rand_f())
	var dfn: float = defender_power(state, h) * (0.8 + 0.4 * state.rand_f())
	var prev_owner: int = int(h["owner"])
	if from_id != -1 and commit > 0:
		state.holdings[from_id]["garrison"] = int(state.holdings[from_id]["garrison"]) - commit
	if att > dfn:
		var lost: int = mini(commit, int(ceil(float(commit) * dfn / att * 0.5)))
		var survivors: int = commit - lost
		h["owner"] = fid
		h["garrison"] = maxi(1, survivors)
		var loot_src: Dictionary = h["store"]
		var half: Dictionary = {}
		var shield: float = 0.0
		for b in h["buildings"]:
			shield = maxf(shield, float(Content.building(String(b)).get("loot_shield", 0.0)))
		for k in loot_src.keys():
			var q: int = int(loot_src[k]) / 2
			if k == Economy.RATION and shield > 0.0:
				q = int(float(q) * (1.0 - shield))
			if q > 0:
				half[k] = q
		var moved: Dictionary = {}
		if not actor.is_empty():
			moved = move_fitting(loot_src, actor["inv"], half)
		else:
			var home: int = int(state.factions[fid]["home"])
			if state.holdings.has(home) and home != hid and int(state.holdings[home]["owner"]) == fid:
				moved = move_fitting(loot_src, state.holdings[home]["store"], half)
		if is_ai:
			state.factions[fid]["spoils"] = int(state.factions[fid].get("spoils", 0)) + Inv.total(moved)
		events.append({"type": &"holding_captured", "holding": hid, "by": fid, "from": prev_owner, "ai": is_ai, "actor": actor_id, "loot": moved, "faction_name": state.factions[fid]["name"]})
		if prev_owner >= 0:
			_check_faction_alive(state, prev_owner, events)
		Economy.check_victory(state, events)
		if prev_owner == 0 or fid == 0:
			Economy.check_starved_out(state, events)
		return true
	var lost2: int = mini(commit, int(ceil(float(commit) * 0.6)))
	h["garrison"] = maxi(0, int(h["garrison"]) - int(ceil(float(h["garrison"]) * 0.3)))
	events.append({"type": &"capture_failed", "holding": hid, "by": fid, "ai": is_ai, "actor": actor_id, "troops_lost": lost2})
	if from_id != -1 and commit > lost2:
		state.holdings[from_id]["garrison"] = int(state.holdings[from_id]["garrison"]) + (commit - lost2)
	return false

static func _check_faction_alive(state: MatchState, fid: int, events: Array) -> void:
	if not state.factions.has(fid) or (fid == 0 and not state.player().is_empty()):
		return
	if state.holdings_of(fid).is_empty():
		Combat.eliminate_faction(state, fid, events)
		var l: Dictionary = state.actors.get(int(state.factions[fid]["leader"]), {})
		if not l.is_empty():
			l["alive"] = false

static func steal_chance(state: MatchState, actor: Dictionary, h: Dictionary) -> float:
	var c: float = 0.35 - 0.04 * float(h["garrison"])
	if not actor.is_empty():
		c += float(Combat.class_mod(actor, "steal_bonus", 0.0))
	for b in h["buildings"]:
		c -= float(Content.building(String(b)).get("steal_guard", 0.0))
	if _active(state, h, "ward"):
		c -= 0.25
	if _active(state, h, "alert"):
		c -= 0.15         # a robbed/raided holding is on its guard for 30s
	return clampf(c, 0.05, 0.95)

static func steal(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	if state.phase != &"PURGE_ACTIVE":
		return "not_purge"
	var pe: String = _peaceful(state, a)
	if pe != "":
		return pe
	var hid: int = CmdUtil.parse_id(args.get("holding"))
	if not state.holdings.has(hid):
		return "unknown_holding"
	var h: Dictionary = state.holdings[hid]
	if int(h["owner"]) == int(a["faction"]):
		return "already_yours"
	if HexGrid.distance(a["hex"], h["hex"]) > CAPTURE_RANGE:
		return "too_far"
	var item: String = CmdUtil.s(args.get("item", ""))
	if Content.item(item).is_empty():
		return "unknown_item"
	var q: int = Inv.parse_qty(args.get("qty"))
	if q < 0 or q > STEAL_CAP:
		return "bad_quantity"
	if not Inv.has_all(h["store"], {item: q}):
		return "insufficient_stock"
	if not Inv.can_carry(a, {item: q}):
		return "no_room"
	if not Combat.ready(state, a, "steal"):
		return "cooldown"
	Combat.set_cd(state, a, "steal", 6.0)
	resolve_steal(state, int(a["faction"]), int(a["id"]), hid, item, q, a["inv"], events)
	return ""

## Rolls the risk; on success moves goods from the store into dest_inv. Returns true on success.
static func resolve_steal(state: MatchState, fid: int, actor_id: int, hid: int, item: String, qty: int, dest: Dictionary, events: Array) -> bool:
	var h: Dictionary = state.holdings[hid]
	var actor: Dictionary = state.actors.get(actor_id, {})
	var is_ai: bool = bool(state.factions[fid]["is_ai"])
	var chance: float = steal_chance(state, actor, h)
	if state.rand_f() < chance:
		Inv.transfer(h["store"], dest, {item: qty})
		if is_ai:
			state.factions[fid]["spoils"] = int(state.factions[fid].get("spoils", 0)) + qty
		events.append({"type": &"item_stolen", "holding": hid, "by": fid, "ai": is_ai, "actor": actor_id, "item": item, "qty": qty, "chance": chance})
		return true
	h["alert"] = MatchState.q(float(state.clock["elapsed"]) + 30.0)
	events.append({"type": &"steal_failed", "holding": hid, "by": fid, "ai": is_ai, "actor": actor_id, "item": item, "qty": qty, "chance": chance})
	if not actor.is_empty():
		var dmg: int = 2
		var cd: Dictionary = Content.class_def(String(actor["class_id"]))
		if not cd.is_empty():
			dmg = int(cd["ability"].get("fail_damage", 2))
		Combat.hurt(state, actor_id, dmg, -1, events, "caught_stealing")
	return false
