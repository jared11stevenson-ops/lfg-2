extends RefCounted
## TEMP FAKE of Stream A's Rules/MatchState contract (docs/INTERFACES.md), used only until rules/api.gd
## exists. Deliberately tiny but it has the real shape: MatchState with to_dict/from_dict, Rules.apply/tick,
## phase driven only by tick(), conservation-checked inventories.
class FakeState:
	extends RefCounted
	var schema_version: int = 1
	var seed: int = 0
	var clock: Dictionary = {"day": 1, "time_of_day": 0.0}
	var phase: StringName = &"PEACE"
	var actors: Dictionary = {}
	var holdings: Dictionary = {}
	var world: Dictionary = {}
	var rng_state: int = 0
	func to_dict() -> Dictionary:
		return {"schema_version": schema_version, "seed": seed, "clock": clock.duplicate(true), "phase": phase,
			"actors": actors.duplicate(true), "holdings": holdings.duplicate(true), "world": world.duplicate(true), "rng_state": rng_state}
	static func from_dict(d: Dictionary) -> FakeState:
		var s := FakeState.new()
		s.schema_version = d["schema_version"]
		s.seed = d["seed"]
		s.clock = d["clock"].duplicate(true)
		s.phase = d["phase"]
		s.actors = d["actors"].duplicate(true)
		s.holdings = d["holdings"].duplicate(true)
		s.world = d["world"].duplicate(true)
		s.rng_state = d["rng_state"]
		return s

const COIN := "lfg:item/coin"
const RATION := "lfg:item/ration"

static func new_match(p_seed: int, _class_id: StringName, _opts: Dictionary = {}) -> FakeState:
	var s := FakeState.new()
	s.seed = p_seed
	s.actors = {0: {"hp": 30, "inv": {RATION: 5, COIN: 0}}, 1: {"hp": 30, "inv": {RATION: 5, COIN: 0}}}
	s.holdings = {0: {"owner": -1, "store": {COIN: 10}}, 1: {"owner": 0, "store": {COIN: 0}}, 2: {"owner": 1, "store": {COIN: 7}}}
	return s

static func total(s: FakeState, item: String) -> int:
	var n := 0
	for a in s.actors.values():
		n += int(a["inv"].get(item, 0))
	for h in s.holdings.values():
		n += int(h["store"].get(item, 0))
	return n

static func _fail(msg: String) -> Dictionary:
	return {"ok": false, "error": msg, "events": []}

static func apply(s: FakeState, cmd: Dictionary) -> Dictionary:
	var actor: int = cmd.get("actor", -1)
	if not s.actors.has(actor):
		return _fail("no_actor")
	var a: Dictionary = s.actors[actor]
	var args: Dictionary = cmd.get("args", {})
	match cmd.get("type"):
		&"eat":
			if int(a["inv"][RATION]) < 1:
				return _fail("no_ration")
			a["inv"][RATION] -= 1
			return {"ok": true, "error": "", "events": [{"type": &"ate", "actor": actor}]}
		&"capture":
			var hid: Variant = args.get("holding")
			if not (hid is int) or not s.holdings.has(hid):
				return _fail("no_holding")
			var h: Dictionary = s.holdings[hid]
			if h["owner"] == actor:
				return _fail("already_yours")
			if h["owner"] != -1 and s.phase != &"PURGE_ACTIVE":
				return _fail("peace_protected")
			for item in h["store"]:
				a["inv"][item] = int(a["inv"].get(item, 0)) + int(h["store"][item])
				h["store"][item] = 0
			h["owner"] = actor
			return {"ok": true, "error": "", "events": [{"type": &"holding_captured", "holding": hid, "by": actor}]}
		&"attack":
			var tid: Variant = args.get("target")
			if not (tid is int) or not s.actors.has(tid) or tid == actor:
				return _fail("bad_target")
			if s.phase != &"PURGE_ACTIVE":
				return _fail("peace_no_pvp")
			var t: Dictionary = s.actors[tid]
			t["hp"] = int(t["hp"]) - 10
			var ev: Array[Dictionary] = [{"type": &"actor_damaged", "actor": tid}]
			if t["hp"] <= 0:
				ev.append({"type": &"actor_died", "actor": tid})
				ev.append({"type": &"match_over", "reason": "leader_died"})
			return {"ok": true, "error": "", "events": ev}
		&"trade":
			var to: Variant = args.get("to")
			var item: Variant = args.get("item")
			var qty: Variant = args.get("qty")
			if not (to is int) or not s.actors.has(to) or to == actor or not (item is String) or not (qty is int) or qty <= 0 or qty > 1000:
				return _fail("bad_trade")
			if int(a["inv"].get(item, 0)) < qty:
				return _fail("insufficient")
			a["inv"][item] -= qty
			s.actors[to]["inv"][item] = int(s.actors[to]["inv"].get(item, 0)) + qty
			return {"ok": true, "error": "", "events": [{"type": &"traded", "from": actor, "to": to}]}
	return _fail("unsupported")

static func tick(s: FakeState, dt: float) -> Array[Dictionary]:
	var ev: Array[Dictionary] = []
	s.clock["time_of_day"] += dt
	var t: float = s.clock["time_of_day"]
	var want: StringName = &"PEACE"
	if t >= 10.0 and t < 20.0:
		want = &"PURGE_ACTIVE"
	elif t >= 20.0:
		s.clock["time_of_day"] = fmod(t, 20.0)
		s.clock["day"] += 1
	if want != s.phase:
		s.phase = want
		ev.append({"type": &"phase_changed", "phase": want})
	return ev
