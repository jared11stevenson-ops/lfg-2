class_name Combat
extends RefCounted
## Damage, effects, death. Enemy telegraph logic is in enemy_ai.gd.

static func class_mod(a: Dictionary, key: String, default: Variant) -> Variant:
	var cd: Dictionary = Content.class_def(String(a.get("class_id", "")))
	if cd.is_empty():
		return default
	var base: Variant = cd.get("mods", {}).get(key, default)
	var fx: Variant = a.get("skill_fx")
	var qf: Variant = a.get("quest_fx")      # signature quest upgrades (rules/quests.gd), not subject to the skill-tree caps
	var has_s: bool = fx != null and (fx as Dictionary).has(key)
	var has_q: bool = qf != null and (qf as Dictionary).has(key)
	if not has_s and not has_q:
		return base
	var d: float = (float(fx[key]) if has_s else 0.0) + (float(qf[key]) if has_q else 0.0)
	if typeof(base) == TYPE_INT and d == floorf(d):
		return int(base) + int(d)
	return float(base) + d

static func has_effect(state: MatchState, a: Dictionary, id: String) -> bool:
	var now: float = float(state.clock["elapsed"])
	for e in a["effects"]:
		if e["id"] == id and float(e["until"]) > now:
			return true
	return false

static func add_effect(a: Dictionary, id: String, until: float, extra: Dictionary = {}) -> void:
	for e in a["effects"]:
		if e["id"] == id:
			e["until"] = until
			e.merge(extra, true)
			return
	var e2: Dictionary = {"id": id, "until": until}
	e2.merge(extra, true)
	a["effects"].append(e2)

const BUFF_CAP := 3

## Consumable boons ({kind:"atk"|"def", amount, secs}); one per kind, never stacking past BUFF_CAP.
static func add_buff(state: MatchState, a: Dictionary, spec: Dictionary) -> void:
	var id: String = "boon_" + String(spec["kind"])
	add_effect(a, id, MatchState.q(float(state.clock["elapsed"]) + float(spec["secs"])), {"amt": mini(int(spec["amount"]), BUFF_CAP)})

static func buff_amt(state: MatchState, a: Dictionary, kind: String) -> float:
	var now: float = float(state.clock["elapsed"])
	for e in a["effects"]:
		if e["id"] == "boon_" + kind and float(e["until"]) > now:
			return float(e.get("amt", 0))
	return 0.0

static func hungry(state: MatchState, a: Dictionary) -> bool:
	var f: Dictionary = state.factions.get(int(a["faction"]), {})
	return int(f.get("hunger_days", 0)) >= 1 and a["kind"] != "enemy"

## Nyx is "sickly" away from Fungal Groves (weakness). Returns the stat multiplier.
static func offgrove_mult(state: MatchState, a: Dictionary) -> float:
	var m: float = float(class_mod(a, "offgrove_mult", 1.0))
	if m == 1.0 or state.world.is_empty():
		return 1.0
	return 1.0 if WorldGen.biome_at(state.world, a["hex"]) == "fungal_grove" else m

## Energy regeneration multiplier (Nyx regains half as fast away from groves).
static func regen_mult(state: MatchState, a: Dictionary) -> float:
	if offgrove_mult(state, a) == 1.0:
		return 1.0
	return float(class_mod(a, "offgrove_regen", 1.0))

static func atk_of(state: MatchState, a: Dictionary) -> float:
	var v: float = float(a["atk"]) * float(class_mod(a, "atk_mult", 1.0)) * offgrove_mult(state, a)
	if has_effect(state, a, "rage"):
		v *= 1.5
	if has_effect(state, a, "rally"):
		v *= 1.25
	if hungry(state, a):
		v *= 0.8
	return v + buff_amt(state, a, "atk")

static func def_of(state: MatchState, a: Dictionary) -> float:
	var v: float = float(a["def"]) * offgrove_mult(state, a)
	if has_effect(state, a, "rage"):
		v *= 0.7
	if hungry(state, a):
		v *= 0.8
	return v + buff_amt(state, a, "def")

static func calc_damage(state: MatchState, attacker: Dictionary, target: Dictionary, base_atk_override: float = -1.0) -> int:
	var atk: float = atk_of(state, attacker) if base_atk_override < 0.0 else base_atk_override
	return maxi(1, int(round(atk - def_of(state, target))))

static func ready(state: MatchState, a: Dictionary, key: String) -> bool:
	return float(a["cd"].get(key, 0.0)) <= float(state.clock["elapsed"])

static func set_cd(state: MatchState, a: Dictionary, key: String, secs: float) -> void:
	a["cd"][key] = MatchState.q(float(state.clock["elapsed"]) + secs)

static func living(a: Dictionary) -> bool:
	return bool(a["alive"])

## Applies final damage (guard halves). Handles death. Returns actual damage dealt.
static func hurt(state: MatchState, target_id: int, amount: int, source_id: int, events: Array, tag: String = "") -> int:
	var t: Dictionary = state.actors.get(target_id, {})
	if t.is_empty() or not t["alive"] or amount <= 0:
		return 0
	var dmg: int = amount
	if has_effect(state, t, "guard"):
		dmg = maxi(1, dmg / 2)
	var m: float = float(class_mod(t, "dmg_taken_mult", 1.0))
	if has_effect(state, t, "evade"):
		m *= 0.6
	if has_effect(state, t, "ward"):
		m *= 0.6
	if m != 1.0:
		dmg = maxi(1, int(round(float(dmg) * m)))
	dmg = mini(dmg, int(t["hp"]))
	t["hp"] = int(t["hp"]) - dmg
	events.append({"type": &"actor_damaged", "actor": target_id, "source": source_id, "amount": dmg, "hp": t["hp"], "tag": tag})
	if int(t["hp"]) <= 0:
		kill(state, target_id, source_id, events)
	return dmg

static func heal(a: Dictionary, amount: int) -> int:
	var before: int = int(a["hp"])
	a["hp"] = mini(int(a["max_hp"]), before + amount)
	return int(a["hp"]) - before

static func kill(state: MatchState, target_id: int, killer_id: int, events: Array) -> void:
	var t: Dictionary = state.actors.get(target_id, {})
	if t.is_empty() or not t["alive"]:
		return
	t["alive"] = false
	t["hp"] = 0
	t["move"] = {}
	var carried: Dictionary = t["inv"].duplicate()
	t["inv"] = {}
	var loot: Dictionary = {}
	if t["kind"] == "enemy":
		loot = Content.enemy(String(t["archetype"])).get("loot", {}).duplicate()
		var kr: Dictionary = state.actors.get(killer_id, {})
		if not kr.is_empty() and int(class_mod(kr, "hunt_meat", 0)) > 0:
			loot["lfg:item/game_meat"] = int(loot.get("lfg:item/game_meat", 0)) + int(class_mod(kr, "hunt_meat", 0)) + (1 if has_effect(state, kr, "tracking") else 0)
	if (t["kind"] == "enemy" and bool(t.get("wave", false))) or t["kind"] == "party":
		# Purge-only material: raiders and wave beasts drop ashmarrow (feeds rank-gated recipes).
		loot["lfg:item/ashmarrow"] = 1 + (1 if state.rand_f() < 0.5 else 0)
	var dropped_to: String = "none"
	var all: Dictionary = carried.duplicate()
	Inv.add_all(all, loot)
	if not all.is_empty():
		var killer: Dictionary = state.actors.get(killer_id, {})
		if not killer.is_empty() and killer["alive"] and Inv.can_carry(killer, all) and HexGrid.distance(killer["hex"], t["hex"]) <= 3:
			Inv.add_all(killer["inv"], all)
			dropped_to = "killer"
		else:
			var k: String = MatchState.plot_key(t["hex"])
			var cur: Dictionary = state.drops.get(k, {})
			Inv.add_all(cur, all)
			state.drops[k] = cur
			dropped_to = "ground"
	events.append({"type": &"actor_died", "actor": target_id, "kind": t["kind"], "faction": t["faction"], "killer": killer_id, "hex": t["hex"], "items": all, "items_to": dropped_to})
	if target_id == state.player_id:
		end_match(state, "leader_died", events)
	elif t["kind"] == "ai_leader" or (t["kind"] == "leader" and int(t["faction"]) >= 0):
		eliminate_faction(state, int(t["faction"]), events, _heir_of(state, int(t["faction"]), killer_id))

## The AI faction that struck a leader down inherits its leaderless realm (pass 3b: the holdings used to fall to neutral, and the last survivor of a hunt could never
## retake 20+ unowned villages before the match ended). A player's kill, an unknown source, famine or revolt still leave the holdings unowned.
static func _heir_of(state: MatchState, fid: int, killer_id: int) -> int:
	var k: Dictionary = state.actors.get(killer_id, {})
	if k.is_empty():
		return -1
	var kf: int = int(k.get("faction", -1))
	if kf < 0 or kf == fid or not state.factions.has(kf) or not state.factions[kf]["alive"] or not bool(state.factions[kf]["is_ai"]):
		return -1
	return kf

static func eliminate_faction(state: MatchState, fid: int, events: Array, heir: int = -1) -> void:
	var f: Dictionary = state.factions.get(fid, {})
	if f.is_empty() or not f["alive"]:
		return
	f["alive"] = false
	for hid in state.holdings_of(fid):
		state.holdings[hid]["owner"] = heir
		if heir >= 0:
			state.holdings[hid]["stab"] = 60
			state.holdings[hid]["pacified_until"] = int(state.clock["day"]) + 3
		state.holdings[hid]["garrison"] = maxi(1, int(state.holdings[hid]["garrison"]) / 3)      # a leaderless garrison routs
		var keep: Array = []
		for b in state.holdings[hid]["buildings"]:
			if float(Content.building(String(b)).get("defense", 0)) <= 0.0:
				keep.append(b)
		var sites: Dictionary = state.holdings[hid].get("sites", {})
		for k in sites.keys().duplicate():
			if not keep.has(sites[k]):
				sites.erase(k)
		state.holdings[hid]["buildings"] = keep      # its walls and towers fall with it
	events.append({"type": &"faction_eliminated", "faction": fid, "ai": bool(f["is_ai"]), "heir": heir})
	Economy.check_victory(state, events)

static func end_match(state: MatchState, reason: String, events: Array) -> void:
	if state.over:
		return
	state.over = true
	state.result = {"reason": reason, "day": state.clock["day"]}
	events.append({"type": &"match_over", "reason": reason, "day": state.clock["day"]})
