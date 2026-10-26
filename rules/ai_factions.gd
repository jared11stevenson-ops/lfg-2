class_name AIFactions
extends RefCounted
## Bounded simulation of AI holdings. Acts only from Rules.tick (never from apply, never when dt <= 0 or match over).
## Peace: farm, cook, ration, recruit. PURGE_ACTIVE: every AI_PERIOD each faction takes at most ONE action (raid or steal).
const AI_PERIOD := 20.0
const ACT_COOLDOWN := 40.0
const RANGE := 14

static func dawn(state: MatchState, events: Array) -> void:
	var fids: Array = state.factions.keys()
	fids.sort()
	for fid in fids:
		var f: Dictionary = state.factions[fid]
		if not f["is_ai"] or not f["alive"]:
			continue
		for hid in state.holdings_of(fid):
			var h: Dictionary = state.holdings[hid]
			var n: int = 2 + int(h["tier"]) + int(h["garrison"]) / 3
			var crop: String = "lfg:item/saltroot" if int(h["tier"]) >= 2 else "lfg:item/glowfruit"
			if Inv.room_for(h["store"], {crop: n}):
				Inv.add_all(h["store"], {crop: n})
			# cook crops into rations
			var cooked: int = 0
			for item in ["lfg:item/glowfruit", "lfg:item/saltroot"]:
				var per: int = 2 if item == "lfg:item/glowfruit" else 3
				var out: int = 1 if item == "lfg:item/glowfruit" else 2
				var batches: int = Inv.count(h["store"], item) / per
				if batches > 0 and Inv.room_for(h["store"], {"lfg:item/ration": batches * out}):
					Inv.remove_all(h["store"], {item: batches * per})
					Inv.add_all(h["store"], {"lfg:item/ration": batches * out})
					cooked += batches * out
			if cooked > 0:
				events.append({"type": &"ai_farmed", "faction": fid, "ai": true, "holding": hid, "rations": cooked})
			# recruit
			var cap: int = 4 + 4 * int(h["tier"])
			var rec: int = 2 if f["persona"] == "turtle" else 1
			if int(h["garrison"]) < cap and Inv.count(h["store"], "lfg:item/coin") >= 3 * rec:
				Inv.remove_all(h["store"], {"lfg:item/coin": 3 * rec})
				h["garrison"] = mini(cap, int(h["garrison"]) + rec)

static func _targets(state: MatchState, fid: int) -> Array[int]:
	var f: Dictionary = state.factions[fid]
	var home: Dictionary = state.holdings.get(int(f["home"]), {})
	var out: Array[int] = []
	if home.is_empty():
		return out
	var ids: Array = state.holdings.keys()
	ids.sort()
	for hid in ids:
		var h: Dictionary = state.holdings[hid]
		if int(h["owner"]) != fid and HexGrid.distance(h["hex"], home["hex"]) <= RANGE:
			out.append(int(hid))
	return out

static func purge_round(state: MatchState, events: Array) -> int:
	var acted: int = 0
	var now: float = float(state.clock["elapsed"])
	var fids: Array = state.factions.keys()
	fids.sort()
	for fid in fids:
		var f: Dictionary = state.factions[fid]
		if not f["is_ai"] or not f["alive"] or f["persona"] == "turtle":
			continue
		if float(f.get("next_act", 0.0)) > now:
			continue
		var home_id: int = int(f["home"])
		if not state.holdings.has(home_id) or int(state.holdings[home_id]["owner"]) != fid:
			var mine: Array[int] = state.holdings_of(fid)
			if mine.is_empty():
				continue
			home_id = mine[0]
			f["home"] = home_id
		var home: Dictionary = state.holdings[home_id]
		var tg: Array[int] = _targets(state, fid)
		if tg.is_empty():
			continue
		if f["persona"] == "raider":
			var best: int = -1
			var bp: float = 1e9
			for hid in tg:
				var dp: float = Conquest.defender_power(state, state.holdings[hid])
				if dp < bp:
					bp = dp
					best = hid
			var commit: int = mini(int(home["garrison"]) - 1, 8)
			if best != -1 and commit >= 2 and Conquest.attacker_power(state, {}, commit) >= 1.3 * bp:
				f["next_act"] = now + ACT_COOLDOWN
				Conquest.resolve_capture(state, fid, -1, best, home_id, commit, events)
				acted += 1
		elif f["persona"] == "thief":
			var pick_h: int = -1
			var pick_item: String = ""
			var pv: int = 0
			for hid in tg:
				var st: Dictionary = state.holdings[hid]["store"]
				var ks: Array = st.keys()
				ks.sort()
				for k in ks:
					var v: int = Content.item_value(String(k)) * mini(int(st[k]), Conquest.STEAL_CAP) - 2 * int(state.holdings[hid]["garrison"])
					if v > pv and Inv.room_for(home["store"], {k: mini(int(st[k]), Conquest.STEAL_CAP)}):
						pv = v
						pick_h = hid
						pick_item = String(k)
			if pick_h != -1:
				f["next_act"] = now + ACT_COOLDOWN * 0.5
				var q: int = mini(Inv.count(state.holdings[pick_h]["store"], pick_item), Conquest.STEAL_CAP)
				Conquest.resolve_steal(state, fid, -1, pick_h, pick_item, q, home["store"], events)
				acted += 1
	return acted
