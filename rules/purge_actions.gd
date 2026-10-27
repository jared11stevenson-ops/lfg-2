class_name PurgeActions
extends RefCounted
## Ordinary commands that give every playstyle a Purge route (docs/INCENTIVES.md "many valid ways to participate"):
##   scout {holding}            look over a rival holding (pacifist-legal)           -> deed "scout"
##   escort {holding, qty}      carry rations to an outlying own holding (pacifist)   -> deed "escort"
##   truce {faction}            pay a rival to stand down for a while (pacifist)      -> deed "broker"
##   ransom {target}            spare a beaten enemy leader for coin (non-lethal)     -> deed "ransom"
##   sabotage {holding}         burn a rival's stores (risk roll)                     -> deed "sabotage"
## None of these needs another player or a trade. Deeds only count during PURGE_ACTIVE (Standing.observe turns the events into deeds).
const SCOUT_RANGE := 3
const ESCORT_MIN_DIST := 5
const ESCORT_MIN_QTY := 3
const TRUCE_GIFT := 15
const TRUCE_SECS := 45.0
const TRUCE_RANGE := 3
const RANSOM_HP_FRAC := 0.4
const RANSOM_MAX := 30
const SABOTAGE_BURN := 5

static func _tscale(state: MatchState) -> float:
	return clampf(state.day_seconds / 360.0, 0.1, 1.0)

static func scout(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	if state.phase != &"PURGE_ACTIVE":
		return "not_purge"
	var hid: int = CmdUtil.parse_id(args.get("holding"))
	if not state.holdings.has(hid):
		return "unknown_holding"
	var h: Dictionary = state.holdings[hid]
	var fid: int = int(a["faction"])
	if int(h["owner"]) == fid:
		return "already_yours"
	if int(h["owner"]) < 0:
		return "no_rival"
	if HexGrid.distance(a["hex"], h["hex"]) > SCOUT_RANGE:
		return "too_far"
	var f: Dictionary = state.factions[fid]
	var seen: Array = f.get("scouted", [])
	if seen.has(hid):
		return "already_scouted"
	if not Combat.ready(state, a, "scout"):
		return "cooldown"
	Combat.set_cd(state, a, "scout", 8.0)
	seen.append(hid)
	f["scouted"] = seen
	events.append({"type": &"scouted", "faction": fid, "actor": a["id"], "holding": hid, "owner": h["owner"], "garrison": h["garrison"],
		"defense": int(round(Conquest.defender_power(state, h)))})
	return ""

static func escort(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	if state.phase != &"PURGE_ACTIVE":
		return "not_purge"
	var hid: int = CmdUtil.parse_id(args.get("holding"))
	if not state.holdings.has(hid):
		return "unknown_holding"
	var h: Dictionary = state.holdings[hid]
	var fid: int = int(a["faction"])
	if int(h["owner"]) != fid:
		return "not_yours"
	if HexGrid.distance(a["hex"], h["hex"]) > 1:
		return "too_far"
	var home: Dictionary = state.holdings.get(int(state.factions[fid]["home"]), {})
	if home.is_empty() or HexGrid.distance(home["hex"], h["hex"]) < ESCORT_MIN_DIST:
		return "not_outlying"
	var q: int = Inv.parse_qty(args.get("qty"))
	if q < ESCORT_MIN_QTY:
		return "bad_quantity"
	var f: Dictionary = state.factions[fid]
	var done: Array = f.get("escorted", [])
	if done.has(hid):
		return "already_escorted"
	var err: String = Inv.transfer(a["inv"], h["store"], {Economy.RATION: q})
	if err != "":
		return err
	done.append(hid)
	f["escorted"] = done
	events.append({"type": &"escorted", "faction": fid, "actor": a["id"], "holding": hid, "qty": q})
	return ""

## Shared by the command and by AI envoys. Mutual truce for `secs`; gift moves from `payer_inv` into the rival's nearest store (conserved).
static func sign_truce(state: MatchState, fid: int, rival: int, hid: int, payer_inv: Dictionary, gift: int, secs: float) -> String:
	var rf: Dictionary = state.factions.get(rival, {})
	if rf.is_empty() or rival == fid or not rf["alive"]:
		return "bad_faction"
	var coin: Dictionary = {Economy.COIN: gift}
	if not Inv.has_all(payer_inv, coin):
		return "insufficient_items"
	if not Inv.room_for(state.holdings[hid]["store"], coin):
		return "no_room"
	Inv.transfer(payer_inv, state.holdings[hid]["store"], coin)
	var until: float = MatchState.q(float(state.clock["elapsed"]) + secs)
	for pair in [[fid, rival], [rival, fid]]:
		var tr: Dictionary = state.factions[int(pair[0])].get("truces", {})
		tr[int(pair[1])] = until
		state.factions[int(pair[0])]["truces"] = tr
	if rival != 0 and bool(rf["is_ai"]):
		rf["truce_until"] = until if fid == 0 else float(rf.get("truce_until", 0.0))
	return ""

static func truce(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	if state.phase != &"PURGE_ACTIVE" and state.phase != &"WARNING":
		return "not_purge"
	var rival: int = CmdUtil.parse_id(args.get("faction"))
	var rf: Dictionary = state.factions.get(rival, {})
	if rf.is_empty() or rival == int(a["faction"]) or not rf["alive"] or not rf["is_ai"]:
		return "bad_faction"
	var hid: int = CmdUtil.nearest_owned_holding(state, rival, a["hex"], TRUCE_RANGE)
	if hid == -1:
		return "too_far"
	if Standing.truced(state, int(a["faction"]), rival):
		return "already_truced"
	var err: String = sign_truce(state, int(a["faction"]), rival, hid, a["inv"], TRUCE_GIFT, TRUCE_SECS * _tscale(state))
	if err != "":
		return err
	events.append({"type": &"truce_signed", "actor": a["id"], "faction": rival, "by": a["faction"], "holding": hid,
		"until": state.factions[int(a["faction"])]["truces"][rival]})
	return ""

static func ransom(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	if state.phase != &"PURGE_ACTIVE":
		return "not_purge"
	var tid: int = CmdUtil.parse_id(args.get("target"))
	var t: Dictionary = state.actors.get(tid, {})
	if t.is_empty() or not t["alive"] or tid == int(a["id"]) or (t["kind"] != "leader" and t["kind"] != "ai_leader"):
		return "bad_target"
	if int(t["faction"]) == int(a["faction"]):
		return "friendly"
	if HexGrid.distance(a["hex"], t["hex"]) > 1:
		return "too_far"
	if float(t["hp"]) > float(t["max_hp"]) * RANSOM_HP_FRAC:
		return "not_beaten"
	var vf: Dictionary = state.factions[int(t["faction"])]
	if int(vf.get("ransomed_week", -1)) == state.week():
		return "already_ransomed"
	if not Combat.ready(state, a, "ransom"):
		return "cooldown"
	Combat.set_cd(state, a, "ransom", 10.0)
	# the ransom: the captive's own purse first, then their nearest store (coin moves, nothing is minted)
	var want: int = RANSOM_MAX
	var got: int = 0
	var take: int = mini(want, Inv.count(t["inv"], Economy.COIN))
	if take > 0:
		Inv.remove_all(t["inv"], {Economy.COIN: take})
		got += take
	var hid: int = CmdUtil.nearest_owned_holding(state, int(t["faction"]), t["hex"], 99)
	if hid != -1 and got < want:
		var st: Dictionary = state.holdings[hid]["store"]
		var t2: int = mini(want - got, Inv.count(st, Economy.COIN) / 2)
		if t2 > 0:
			Inv.remove_all(st, {Economy.COIN: t2})
			got += t2
	got = mini(got, Inv.MAX_QTY - Inv.count(a["inv"], Economy.COIN))
	Inv.add_all(a["inv"], {Economy.COIN: got})
	vf["ransomed_week"] = state.week()
	# the spared leader and the captor's faction stand down for a while
	var until: float = MatchState.q(float(state.clock["elapsed"]) + TRUCE_SECS * _tscale(state))
	for pair in [[int(a["faction"]), int(t["faction"])], [int(t["faction"]), int(a["faction"])]]:
		var tr: Dictionary = state.factions[int(pair[0])].get("truces", {})
		tr[int(pair[1])] = until
		state.factions[int(pair[0])]["truces"] = tr
	events.append({"type": &"ransomed", "faction": a["faction"], "actor": a["id"], "target": tid, "victim_faction": t["faction"], "coin": got})
	return ""

static func sabotage(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	if state.phase != &"PURGE_ACTIVE":
		return "not_purge"
	if int(Combat.class_mod(a, "pacifist", 0)) > 0:
		return "pacifist"
	if Combat.has_effect(state, a, "truce"):
		return "truce_active"
	var hid: int = CmdUtil.parse_id(args.get("holding"))
	if not state.holdings.has(hid):
		return "unknown_holding"
	var h: Dictionary = state.holdings[hid]
	var fid: int = int(a["faction"])
	if int(h["owner"]) == fid:
		return "already_yours"
	if int(h["owner"]) < 0:
		return "no_rival"
	if HexGrid.distance(a["hex"], h["hex"]) > Conquest.CAPTURE_RANGE:
		return "too_far"
	if Standing.truced(state, fid, int(h["owner"])):
		return "truce_active"
	if Inv.count(h["store"], Economy.RATION) < 1:
		return "nothing_to_burn"
	if not Combat.ready(state, a, "sabotage"):
		return "cooldown"
	Combat.set_cd(state, a, "sabotage", 20.0)
	if state.rand_f() < Conquest.steal_chance(state, a, h):
		var burn: int = mini(SABOTAGE_BURN, Inv.count(h["store"], Economy.RATION))
		Inv.remove_all(h["store"], {Economy.RATION: burn})
		h["alert"] = MatchState.q(float(state.clock["elapsed"]) + 30.0)
		events.append({"type": &"sabotaged", "faction": fid, "actor": a["id"], "holding": hid, "burned": burn})
		return ""
	h["alert"] = MatchState.q(float(state.clock["elapsed"]) + 30.0)
	events.append({"type": &"sabotage_failed", "faction": fid, "actor": a["id"], "holding": hid})
	Combat.hurt(state, int(a["id"]), 3, -1, events, "caught_sabotage")
	return ""
