class_name Standing
extends RefCounted
## Standing, ranks, the Mark, Prosperity, upkeep/stability, the Purge Levy and scarcity (docs/INCENTIVES.md; numbers in data/ranks.json).
## Standing = holdings (by tier) + rations in reserve (capped) + Purge deeds that decay over ~3 weeks.
## Ranks give PRODUCTION, ACCESS and LOGISTICS only (never raw combat power) and are an anti-snowball when the crown is thin.
## Deeds are derived from the event stream (observe) and only count in PURGE_ACTIVE. Every deed also pays skill points to the faction leader.
const NO_MARK := -1

static func cfg() -> Dictionary:
	return Content.ranks_cfg()

static func deed_def(kind: String) -> Dictionary:
	return cfg().get("deeds", {}).get(kind, {})

# ------------------------------------------------------------------ small accessors
static func fac(state: MatchState, fid: int) -> Dictionary:
	return state.factions.get(fid, {})

static func rank_of(state: MatchState, fid: int) -> int:
	return int(fac(state, fid).get("rank", 0))

## Rank used for production/logistics: shrinks by one when the crown is thin.
static func eff_rank(state: MatchState, fid: int) -> int:
	var f: Dictionary = fac(state, fid)
	return int(f.get("eff_rank", f.get("rank", 0)))

static func rank_def(r: int) -> Dictionary:
	var arr: Array = cfg().get("ranks", [])
	return arr[clampi(r, 0, arr.size() - 1)] if not arr.is_empty() else {}

static func rank_name(r: int) -> String:
	var names: Array = cfg().get("names", [])
	return String(names[clampi(r, 0, names.size() - 1)]) if not names.is_empty() else str(r)

static func leader_of(state: MatchState, fid: int) -> Dictionary:
	return state.actors.get(int(fac(state, fid).get("leader", -1)), {})

static func skill_fx(state: MatchState, fid: int, key: String) -> float:
	var l: Dictionary = leader_of(state, fid)
	if l.is_empty() or not l["alive"]:
		return 0.0
	return float((l.get("skill_fx", {}) as Dictionary).get(key, 0.0))

static func mark_of(state: MatchState) -> int:
	return int(state.sim_acc.get("mark", NO_MARK))

static func is_marked(state: MatchState, fid: int) -> bool:
	return fid >= 0 and mark_of(state) == fid

# ------------------------------------------------------------------ effects of rank (production / access / logistics)
static func rank_ok(state: MatchState, fid: int, need: int) -> bool:
	return need <= 0 or rank_of(state, fid) >= need

static func plot_cap(state: MatchState, fid: int) -> int:
	return int(rank_def(eff_rank(state, fid)).get("plots", 10)) + int(skill_fx(state, fid, "plot_slots"))

static func growth_frac(state: MatchState, fid: int) -> float:
	return (float(rank_def(eff_rank(state, fid)).get("growth_pct", 0)) + skill_fx(state, fid, "growth_pct")) / 100.0

static func yield_bonus(state: MatchState, hold: Dictionary) -> int:
	var of: int = int(hold["owner"])
	if of < 0:
		return 0
	var y: int = int(rank_def(eff_rank(state, of)).get("yield", 0))
	for b in hold["buildings"]:
		y += int(Content.building(String(b)).get("yield_bonus", 0))
	var sc: Dictionary = cfg().get("scarcity", {})
	var wk: int = state.week() - int(sc.get("yield_start_week", 3))
	if wk > 0:
		y -= mini(int(sc.get("yield_loss_cap", 2)), 1 + (wk - 1) / int(sc.get("yield_week_step", 6)))
	if int(hold.get("stab", 100)) < int(cfg().get("stability", {}).get("weak", 40)):
		y -= int(cfg().get("stability", {}).get("weak_yield_loss", 1))
	return y

static func garrison_cap(state: MatchState, h: Dictionary) -> int:
	var cap: int = 4 + 4 * int(h["tier"])
	var of: int = int(h["owner"])
	if of >= 0:
		cap += int(rank_def(eff_rank(state, of)).get("garrison", 0)) + int(skill_fx(state, of, "garrison_cap"))
	return cap

static func supply_range(state: MatchState, fid: int) -> int:
	return Conquest.SUPPLY_RANGE + int(rank_def(eff_rank(state, fid)).get("supply", 0)) + int(skill_fx(state, fid, "supply_range"))

static func carry_bonus(a: Dictionary) -> int:
	return int(rank_def(int(a.get("eff_rank", 0))).get("carry", 0))

## +x% better prices per rank (positive helps the actor).
static func price_pct(a: Dictionary) -> float:
	return float(rank_def(int(a.get("eff_rank", 0))).get("price_pct", 0)) / 100.0

static func prod_mult(state: MatchState) -> float:
	var sc: Dictionary = cfg().get("scarcity", {})
	return maxf(float(sc.get("prod_floor", 0.5)), 1.0 - float(sc.get("prod_loss_per_week", 0.02)) * float(state.week()))

# ------------------------------------------------------------------ score
static func _tier_idx(h: Dictionary) -> int:
	return clampi(int(h["tier"]), 0, 3)

static func deed_score(state: MatchState, f: Dictionary) -> float:
	var decay: float = float(cfg().get("decay_days", 21)) * state.day_seconds
	var now: float = float(state.clock["elapsed"])
	var t: float = 0.0
	for d in f.get("deeds", []):
		var age: float = now - float(d["deed_t"])
		if age < decay:
			t += float(d["w"]) * (1.0 - age / decay)
	return t

## Decayed weight of fighting deeds only (kill/capture/steal/defend/...). Lowers the Purge Levy.
static func fight_score(state: MatchState, f: Dictionary) -> float:
	var decay: float = float(cfg().get("decay_days", 21)) * state.day_seconds
	var now: float = float(state.clock["elapsed"])
	var defs: Dictionary = cfg().get("deeds", {})
	var t: float = 0.0
	for d in f.get("deeds", []):
		var age: float = now - float(d["deed_t"])
		if age < decay and bool(defs.get(String(d["k"]), {}).get("fight", false)):
			t += float(d["w"]) * (1.0 - age / decay)
	return t

static func holdings_score(state: MatchState, fid: int) -> float:
	var c: Dictionary = cfg()
	var hw: Array = c["holding_weight"]
	var rc: Array = c["ration_cap_per_holding"]
	var rw: float = float(c["ration_weight"])
	var s: float = 0.0
	for hid in state.holdings_of(fid):
		var h: Dictionary = state.holdings[hid]
		var ti: int = _tier_idx(h)
		s += float(hw[ti]) + rw * float(mini(Inv.count(h["store"], Economy.RATION), int(rc[ti])))
	return s

static func score(state: MatchState, fid: int) -> float:
	var f: Dictionary = fac(state, fid)
	if f.is_empty() or not f["alive"]:
		return 0.0
	return holdings_score(state, fid) + deed_score(state, f)

static func live_count(state: MatchState) -> int:
	var n: int = 0
	for f in state.factions.values():
		if f["alive"]:
			n += 1
	return n

## Thresholds scale with the number of live factions (fewer rivals left = a bigger crown is needed).
static func threshold_scale(state: MatchState) -> float:
	var c: Dictionary = cfg()
	var live: int = maxi(1, live_count(state))
	return clampf(sqrt(float(c["field_ref"]) / float(live)), float(c["threshold_scale_min"]), float(c["threshold_scale_max"]))

static func threshold(state: MatchState, r: int) -> float:
	var th: Array = cfg()["thresholds"]
	return float(th[clampi(r, 0, th.size() - 1)]) * (threshold_scale(state) if r > 0 else 1.0)

static func rank_for_score(state: MatchState, sc: float) -> int:
	var r: int = 0
	var th: Array = cfg()["thresholds"]
	var scale: float = threshold_scale(state)
	for i in range(1, th.size()):
		if sc >= float(th[i]) * scale:
			r = i
	return r

## Test/sim helper: pins a faction's rank (recomputed from standing at the next dawn).
static func set_rank(state: MatchState, fid: int, r: int) -> void:
	var f: Dictionary = fac(state, fid)
	f["rank"] = r
	f["eff_rank"] = r
	var l: Dictionary = leader_of(state, fid)
	if not l.is_empty():
		l["rank"] = r
		l["eff_rank"] = r

# ------------------------------------------------------------------ init / dawn recompute
static func init_state(state: MatchState) -> void:
	for fid in state.factions.keys():
		var f: Dictionary = state.factions[fid]
		for k in ["rank", "eff_rank"]:
			if not f.has(k):
				f[k] = 0
		for k2 in ["deeds", "pcap", "dcount", "scouted", "escorted"]:
			if not f.has(k2):
				f[k2] = [] if (k2 == "deeds" or k2 == "scouted" or k2 == "escorted") else {}
		if not f.has("last_deed"):
			f["last_deed"] = 0.0
		if not f.has("truces"):
			f["truces"] = {}
	for h in state.holdings.values():
		if not h.has("stab"):
			h["stab"] = 100
	if not state.sim_acc.has("mark"):
		state.sim_acc["mark"] = NO_MARK
	recompute(state, [], false)

static func thin_crown(state: MatchState, fid: int) -> bool:
	var tc: Dictionary = cfg().get("thin_crown", {})
	var need: int = Economy.persons(state, fid) * int(tc.get("ration_days", 3))
	if Economy.rations_available(state, fid) < need:
		return true
	var minst: int = int(tc.get("min_stability", 40))
	for hid in state.holdings_of(fid):
		if int(state.holdings[hid].get("stab", 100)) < minst:
			return true
	return false

## Recomputes score, rank, thin-crown, the Mark and Prosperity. Called at every dawn (and once at setup).
static func recompute(state: MatchState, events: Array, emit: bool = true) -> void:
	var c: Dictionary = cfg()
	var decay: float = float(c.get("decay_days", 21)) * state.day_seconds
	var now: float = float(state.clock["elapsed"])
	var top: int = NO_MARK
	var top_s: float = -1.0
	var fids: Array = state.factions.keys()
	fids.sort()
	for fid in fids:
		var f: Dictionary = state.factions[fid]
		if not f["alive"]:
			continue
		var keep: Array = []
		for d in f.get("deeds", []):
			if now - float(d["deed_t"]) < decay:
				keep.append(d)
		f["deeds"] = keep
		var sc: float = score(state, fid)
		f["standing"] = MatchState.q(sc)
		var old: int = int(f.get("rank", 0))
		var r: int = rank_for_score(state, sc)
		f["rank"] = r
		var eff: int = maxi(0, r - int(c["thin_crown"]["rank_loss"])) if (r > 0 and thin_crown(state, fid)) else r
		f["eff_rank"] = eff
		f["thin"] = eff < r
		var l: Dictionary = leader_of(state, fid)
		if not l.is_empty():
			l["rank"] = r
			l["eff_rank"] = eff
		if emit and r != old:
			events.append({"type": &"rank_changed", "faction": fid, "from": old, "to": r, "name": rank_name(r), "ai": bool(f["is_ai"])})
		if r >= int(c["mark"]["min_rank"]) and sc > top_s:
			top_s = sc
			top = int(fid)
		f["prosperity"] = prosperity(state, int(fid), emit)
	var old_mark: int = mark_of(state)
	state.sim_acc["mark"] = top
	if emit and top != old_mark:
		events.append({"type": &"mark_changed", "from": old_mark, "faction": top})

# ------------------------------------------------------------------ prosperity (non-ending thriving score)
static func note_output(state: MatchState, fid: int, items: Dictionary) -> void:
	var f: Dictionary = fac(state, fid)
	if f.is_empty():
		return
	var v: int = 0
	for k in items.keys():
		v += Content.item_value(String(k)) * int(items[k])
	f["out_day"] = int(f.get("out_day", 0)) + v

static func prosperity(state: MatchState, fid: int, roll: bool = false) -> Dictionary:
	var c: Dictionary = cfg()
	var f: Dictionary = fac(state, fid)
	var out_ema: float = float(f.get("out_ema", 0.0))
	if roll:
		out_ema = out_ema * float(c["prosperity"]["output_decay"]) + float(f.get("out_day", 0))
		f["out_ema"] = MatchState.q(out_ema)
		f["out_day"] = 0
	var persons: int = maxi(1, Economy.persons(state, fid))
	var rations: int = Economy.rations_available(state, fid)
	var coin: int = 0
	var hscore: int = 0
	for hid in state.holdings_of(fid):
		var h: Dictionary = state.holdings[hid]
		coin += Inv.count(h["store"], Economy.COIN)
		hscore += int(c["holding_weight"][_tier_idx(h)]) * 2
	var reserves: int = mini(rations, 60) + mini(coin, 100) / 5
	var days: float = float(rations) / float(persons)
	var total: int = int(round(out_ema)) + reserves + hscore
	var thriving: bool = bool(f.get("alive", false)) and int(f.get("hunger_days", 0)) == 0 and days >= float(c["prosperity"]["ration_days_secure"]) \
		and hscore > 0 and total >= int(c["prosperity"]["thriving_min"])
	return {"score": total, "output": int(round(out_ema)), "reserves": reserves, "holdings": hscore, "ration_days": MatchState.q(days), "thriving": thriving}

# ------------------------------------------------------------------ deeds
static func truced(state: MatchState, a: int, b: int) -> bool:
	var f: Dictionary = fac(state, a)
	return not f.is_empty() and float((f.get("truces", {}) as Dictionary).get(b, 0.0)) > float(state.clock["elapsed"])

## Records one deed for faction `fid` (only in PURGE_ACTIVE). Returns true when it counted (caps are per Purge).
static func record(state: MatchState, fid: int, kind: String, events: Array, victim_faction: int = -1, actor: int = -1) -> bool:
	var f: Dictionary = fac(state, fid)
	var d: Dictionary = deed_def(kind)
	if f.is_empty() or d.is_empty() or not f["alive"] or state.phase != &"PURGE_ACTIVE":
		return false
	var pcap: Dictionary = f.get("pcap", {})
	var cap: int = int(d.get("cap", 0))
	if cap > 0 and int(pcap.get(kind, 0)) >= cap:
		return false
	pcap[kind] = int(pcap.get(kind, 0)) + 1
	f["pcap"] = pcap
	var mult: float = 1.0
	var marked: bool = victim_faction >= 0 and victim_faction != fid and is_marked(state, victim_faction) and bool(d.get("fight", false))
	if marked:
		mult = float(cfg()["mark"]["bounty_mult"])
	var st: int = int(ceil(float(d["standing"]) * mult - 1e-9))
	var sp: int = int(ceil(float(d["sp"]) * mult - 1e-9))
	var deeds: Array = f["deeds"]
	deeds.append({"k": kind, "w": st, "deed_t": float(state.clock["elapsed"])})
	var hc: int = int(cfg().get("history_cap", 60))
	while deeds.size() > hc:
		deeds.remove_at(0)
	f["last_deed"] = float(state.clock["elapsed"])
	var dc: Dictionary = f["dcount"]
	dc[kind] = int(dc.get(kind, 0)) + 1
	events.append({"type": &"deed", "faction": fid, "kind": kind, "label": d.get("label", kind), "standing": st, "sp": sp, "victim": victim_faction, "marked": marked,
		"actor": actor, "ai": bool(f["is_ai"])})
	Skills.grant(state, fid, sp, kind, events)
	return true

## Turns the event stream of one step/command into deeds. Called by Rules.tick/apply with the events produced since `from`.
static func observe(state: MatchState, events: Array, from: int = 0) -> void:
	if state.phase != &"PURGE_ACTIVE":
		return
	var n: int = events.size()
	for i in range(from, n):
		var e: Dictionary = events[i]
		match e.get("type", &""):
			&"actor_died":
				_on_death(state, e, events)
			&"holding_captured":
				record(state, int(e["by"]), "capture", events, int(e.get("from", -1)), int(e.get("actor", -1)))
			&"item_stolen":
				var h: Dictionary = state.holdings.get(int(e["holding"]), {})
				record(state, int(e["by"]), "steal", events, int(h.get("owner", -1)), int(e.get("actor", -1)))
			&"capture_failed":
				var h2: Dictionary = state.holdings.get(int(e["holding"]), {})
				if not h2.is_empty() and int(h2["owner"]) >= 0 and int(h2["owner"]) != int(e["by"]):
					record(state, int(h2["owner"]), "defend", events, int(e["by"]))
			&"steal_failed":
				var h3: Dictionary = state.holdings.get(int(e["holding"]), {})
				if not h3.is_empty() and int(h3["owner"]) >= 0 and int(h3["owner"]) != int(e["by"]):
					record(state, int(h3["owner"]), "defend", events, int(e["by"]))
			&"ability_used":
				if int(e.get("healed", 0)) >= 5 and e.has("target"):
					var a: Dictionary = state.actors.get(int(e["actor"]), {})
					if not a.is_empty():
						record(state, int(a["faction"]), "heal", events, -1, int(e["actor"]))
				elif e.has("tracked"):
					var a2: Dictionary = state.actors.get(int(e["actor"]), {})
					if not a2.is_empty():
						record(state, int(a2["faction"]), "scout", events, -1, int(e["actor"]))
			&"truce_signed":
				var a3: Dictionary = state.actors.get(int(e.get("actor", -1)), {})
				var fid3: int = int(a3["faction"]) if not a3.is_empty() else int(e.get("by", -1))
				if fid3 >= 0:
					record(state, fid3, "broker", events, -1, int(e.get("actor", -1)))
			&"scouted":
				record(state, int(e["faction"]), "scout", events, -1, int(e.get("actor", -1)))
			&"escorted":
				record(state, int(e["faction"]), "escort", events, -1, int(e.get("actor", -1)))
			&"ransomed":
				record(state, int(e["faction"]), "ransom", events, int(e.get("victim_faction", -1)), int(e.get("actor", -1)))
			&"sabotaged":
				var h4: Dictionary = state.holdings.get(int(e["holding"]), {})
				record(state, int(e["faction"]), "sabotage", events, int(h4.get("owner", -1)), int(e.get("actor", -1)))

static func _on_death(state: MatchState, e: Dictionary, events: Array) -> void:
	var vk: String = String(e.get("kind", ""))
	var vf: int = int(e.get("faction", -1))
	var killer: Dictionary = state.actors.get(int(e.get("killer", -1)), {})
	var kf: int = int(killer["faction"]) if (not killer.is_empty() and killer["kind"] != "enemy") else -1
	if kf >= 0 and kf == vf:
		kf = -1
	if vk == "leader" or vk == "ai_leader":
		if kf >= 0:
			record(state, kf, "kill_leader", events, vf, int(e["killer"]))
	elif vk == "party":
		if kf >= 0:
			var near: bool = CmdUtil.nearest_owned_holding(state, kf, e["hex"], 3) != -1
			record(state, kf, "defend" if near else "kill_raider", events, vf, int(e["killer"]))
		else:
			var seen: Dictionary = {}
			for hid in state.holdings.keys():
				var h: Dictionary = state.holdings[hid]
				var of: int = int(h["owner"])
				if of >= 0 and of != vf and not seen.has(of) and HexGrid.distance(h["hex"], e["hex"]) <= 2:
					seen[of] = true
					record(state, of, "defend", events, vf)
	elif vk == "enemy" and kf >= 0:
		var victim: Dictionary = state.actors.get(int(e["actor"]), {})
		var wave: bool = bool(victim.get("wave", false))
		record(state, kf, "kill_raider" if wave else "kill_wild", events, -1, int(e["killer"]))

# ------------------------------------------------------------------ dawn: upkeep, stability, spoilage, idle bleed
static func upkeep_cost(state: MatchState, fid: int) -> int:
	var u: Dictionary = cfg()["upkeep"]
	var n: int = state.holdings_of(fid).size()
	if n <= int(u["free_holdings"]):
		return 0
	var base: float = pow(float(n), float(u["coin_exp"])) / float(u["coin_div"])
	var l: Dictionary = leader_of(state, fid)
	var m: float = 1.0
	if not l.is_empty() and l["alive"]:
		m = float(Combat.class_mod(l, "upkeep_mult", 1.0))
	m *= 1.0 - skill_fx(state, fid, "upkeep_pct") / 100.0
	return int(floor(base * m))

static func _take_coin(state: MatchState, fid: int, amount: int) -> int:
	## Pays up to `amount` coin out of the faction's stores (home first). Returns what is still owed.
	var left: int = amount
	var hs: Array[int] = state.holdings_of(fid)
	var home: int = int(fac(state, fid).get("home", -1))
	if hs.has(home):
		hs.erase(home)
		hs.push_front(home)
	for hid in hs:
		if left <= 0:
			break
		var st: Dictionary = state.holdings[hid]["store"]
		var t: int = mini(left, Inv.count(st, Economy.COIN))
		if t > 0:
			Inv.remove_all(st, {Economy.COIN: t})
			left -= t
	return left

static func _take_item(state: MatchState, fid: int, item: String, amount: int) -> int:
	var left: int = amount
	var hs: Array[int] = state.holdings_of(fid)
	var home: int = int(fac(state, fid).get("home", -1))
	if hs.has(home):
		hs.erase(home)
		hs.push_front(home)
	for hid in hs:
		if left <= 0:
			break
		var st: Dictionary = state.holdings[hid]["store"]
		var t: int = mini(left, Inv.count(st, item))
		if t > 0:
			Inv.remove_all(st, {item: t})
			left -= t
	return left

const PERISHABLE: Array[String] = ["lfg:item/ration", "lfg:item/glowfruit", "lfg:item/sporebean", "lfg:item/saltroot", "lfg:item/glowfruit_prime",
	"lfg:item/moonbean", "lfg:item/mushroom", "lfg:item/game_meat"]

static func dawn_upkeep(state: MatchState, events: Array) -> void:
	var c: Dictionary = cfg()
	var u: Dictionary = c["upkeep"]
	var sb: Dictionary = c["stability"]
	var sc: Dictionary = c["scarcity"]
	var wk: int = state.week()
	var fids: Array = state.factions.keys()
	fids.sort()
	var now: float = float(state.clock["elapsed"])
	for fid in fids:
		var f: Dictionary = state.factions[fid]
		if not f["alive"]:
			continue
		var hs: Array[int] = state.holdings_of(int(fid))
		var n: int = hs.size()
		if n == 0:
			continue
		# income (tax) from stable holdings
		for hid in hs:
			var h: Dictionary = state.holdings[hid]
			if int(h.get("stab", 100)) >= int(sb["weak"]) and Inv.room_for(h["store"], {Economy.COIN: 3}):
				Inv.add_all(h["store"], {Economy.COIN: int(u["income_per_tier"]) * clampi(int(h["tier"]), 1, 3)})
		# upkeep
		var cost: int = upkeep_cost(state, int(fid))
		var owed: int = _take_coin(state, int(fid), cost) if cost > 0 else 0
		f["upkeep_unpaid"] = owed > 0
		if cost > 0:
			events.append({"type": &"upkeep_paid", "faction": fid, "ai": bool(f["is_ai"]), "cost": cost, "unpaid": owed})
		# stability
		var home: Dictionary = state.holdings.get(int(f["home"]), {})
		if home.is_empty() or int(home["owner"]) != int(fid):
			home = state.holdings[hs[0]]
		for hid in hs:
			var h2: Dictionary = state.holdings[hid]
			var target: int = int(sb["start"])
			var dist: int = HexGrid.distance(h2["hex"], home["hex"])
			target -= maxi(0, dist - int(sb["dist_free"])) * int(sb["dist_per_hex"])
			target -= maxi(0, n - int(sb["extra_free"])) * int(sb["per_extra_holding"])
			target -= mini(3, int(f.get("hunger_days", 0))) * int(sb["hunger_per_day"])
			if owed > 0:
				target -= int(u["stab_unpaid"])
			target = clampi(target, 0, 100)
			var cur: int = int(h2.get("stab", 100))
			var step: int = int(sb["step"])
			h2["stab"] = cur + clampi(target - cur, -step, step)
			if int(h2["stab"]) <= int(sb["revolt_at"]) and int(hid) != int(home["id"]) and state.rand_f() < float(sb["revolt_chance"]):
				h2["owner"] = -1
				h2["garrison"] = maxi(0, int(h2["garrison"]) / 2)
				h2["stab"] = 60
				events.append({"type": &"holding_revolted", "holding": hid, "faction": fid, "ai": bool(f["is_ai"])})
		# idle bleed: passive single-holding factions
		hs = state.holdings_of(int(fid))
		if hs.size() == 1:
			var idle: float = now - float(f.get("last_deed", 0.0))
			var ib: Dictionary = c["idle_bleed"]
			if idle > float(ib["idle_days"]) * state.day_seconds and not is_marked(state, int(fid)):
				var amt: int = mini(int(ib["cap"]), int(ib["ration_base"]) + wk / int(ib["week_div"]))
				var hh: Dictionary = state.holdings[hs[0]]
				var short: int = _take_item(state, int(fid), Economy.RATION, amt) + _take_coin(state, int(fid), amt)
				if short > 0 and int(hh["garrison"]) > 0:
					hh["garrison"] = int(hh["garrison"]) - 1
				events.append({"type": &"idle_bleed", "faction": fid, "ai": bool(f["is_ai"]), "amount": amt, "short": short})
		# peacetime spoilage (scarcity drift)
		var rate: float = minf(float(sc["spoil_cap"]), float(sc["spoil_base"]) * float(wk + 1))
		for hid in state.holdings_of(int(fid)):
			var h3: Dictionary = state.holdings[hid]
			var r: float = rate * (float(sc["granary_cut"]) if (h3["buildings"] as Array).has("lfg:building/granary") else 1.0)
			for item in PERISHABLE:
				var cnt: int = Inv.count(h3["store"], item)
				var over: int = cnt - int(sc["spoil_floor"])
				if over > 0:
					var loss: int = int(floor(float(over) * r))
					if loss > 0:
						Inv.remove_all(h3["store"], {item: loss})

# ------------------------------------------------------------------ the weekly Purge Levy (after RESOLUTION begins)
static func levy_due(state: MatchState, fid: int) -> Dictionary:
	var lv: Dictionary = cfg()["levy"]
	var f: Dictionary = fac(state, fid)
	var hs: Array[int] = state.holdings_of(fid)
	var r: float = 0.0
	var co: float = 0.0
	var shrine: bool = false
	for hid in hs:
		var h: Dictionary = state.holdings[hid]
		r += float(lv["ration_base"]) + float(lv["ration_per_tier"]) * float(h["tier"])
		co += float(lv["coin_base"]) + float(lv["coin_per_tier"]) * float(h["tier"])
		for b in h["buildings"]:
			if float(Content.building(String(b)).get("levy_cut", 0.0)) > 0.0:
				shrine = true
	var growth: float = minf(float(lv["week_growth_cap"]), 1.0 + float(lv["week_growth"]) * float(state.week()))
	var red: float = clampf(fight_score(state, f) / (float(lv["fight_div"]) * float(maxi(1, hs.size()))), 0.0, float(lv["reduction_cap"]))
	if shrine:
		red += float(lv["shrine_cut"])
	red += skill_fx(state, fid, "levy_pct") / 100.0
	red = clampf(red, 0.0, 0.9)
	return {"rations": int(ceil(r * growth * (1.0 - red) - 1e-9)), "coin": int(ceil(co * growth * (1.0 - red) - 1e-9)), "reduction": MatchState.q(red),
		"fight": MatchState.q(fight_score(state, f))}

static func charge_levy(state: MatchState, events: Array) -> void:
	var lv: Dictionary = cfg()["levy"]
	var fids: Array = state.factions.keys()
	fids.sort()
	for fid in fids:
		var f: Dictionary = state.factions[fid]
		if not f["alive"] or state.holdings_of(int(fid)).is_empty():
			continue
		var due: Dictionary = levy_due(state, int(fid))
		var lr: int = _take_item(state, int(fid), Economy.RATION, int(due["rations"]))
		var lc: int = _take_coin(state, int(fid), int(due["coin"]))
		if lr > 0 or lc > 0:
			for hid in state.holdings_of(int(fid)):
				var h: Dictionary = state.holdings[hid]
				h["stab"] = maxi(0, int(h.get("stab", 100)) - int(lv["unpaid_stab"]))
			var home: Dictionary = state.holdings.get(int(f["home"]), {})
			if not home.is_empty() and int(home["owner"]) == int(fid) and int(home["garrison"]) > 1:
				home["garrison"] = int(home["garrison"]) - 1
		events.append({"type": &"levy_paid", "faction": fid, "ai": bool(f["is_ai"]), "rations": int(due["rations"]) - lr, "coin": int(due["coin"]) - lc,
			"unpaid_rations": lr, "unpaid_coin": lc, "reduction": due["reduction"]})
		f["pcap"] = {}
		f["scouted"] = []
		f["escorted"] = []

## The Purge targets the Marked: beasts and raiders bleed the garrisons of a Marked AI faction (a human Mark gets bigger waves instead).
static func mark_pressure(state: MatchState, events: Array) -> void:
	var m: int = mark_of(state)
	var f: Dictionary = fac(state, m)
	if f.is_empty() or not f["alive"] or not f["is_ai"]:
		return
	var lost: int = 0
	for hid in state.holdings_of(m):
		var h: Dictionary = state.holdings[hid]
		var d: int = mini(int(h["garrison"]) - 1, maxi(1, int(h["garrison"]) / 8))
		if d > 0:
			h["garrison"] = int(h["garrison"]) - d
			lost += d
	if lost > 0:
		events.append({"type": &"mark_pressure", "faction": m, "troops_lost": lost})

# ------------------------------------------------------------------ HUD model (the lead wires this into the HUD / standing panel)
static func next_unlock(r: int) -> String:
	return String(rank_def(r + 1).get("unlock", "")) if r < (cfg().get("ranks", []) as Array).size() - 1 else ""

static func hud_model(state: MatchState, fid: int = 0) -> Dictionary:
	var f: Dictionary = fac(state, fid)
	if f.is_empty():
		return {}
	var r: int = int(f.get("rank", 0))
	var maxr: int = (cfg()["thresholds"] as Array).size() - 1
	var sc: float = score(state, fid)
	var nxt_th: float = threshold(state, r + 1) if r < maxr else 0.0
	var now: float = float(state.clock["elapsed"])
	var recent: Array = []
	var deeds: Array = f.get("deeds", [])
	for i in range(deeds.size() - 1, maxi(-1, deeds.size() - 9), -1):
		var d: Dictionary = deeds[i]
		recent.append({"kind": d["k"], "label": deed_def(String(d["k"])).get("label", d["k"]), "standing": d["w"], "age_days": MatchState.q((now - float(d["deed_t"])) / state.day_seconds)})
	var m: int = mark_of(state)
	var l: Dictionary = leader_of(state, fid)
	var lv: Dictionary = levy_due(state, fid)
	var days_to_purge: int = ((7 - state.day_of_week()) + 7) % 7
	return {"faction": fid, "rank": r, "rank_name": rank_name(r), "eff_rank": int(f.get("eff_rank", r)), "thin_crown": bool(f.get("thin", false)),
		"standing": MatchState.q(sc), "next_rank": mini(r + 1, maxr), "next_rank_name": rank_name(mini(r + 1, maxr)), "next_threshold": MatchState.q(nxt_th),
		"to_next": MatchState.q(maxf(0.0, nxt_th - sc)) if r < maxr else 0.0, "next_unlock": next_unlock(r),
		"prosperity": f.get("prosperity", prosperity(state, fid)), "thriving": bool(f.get("prosperity", {}).get("thriving", false)),
		"recent_deeds": recent, "deed_counts": f.get("dcount", {}).duplicate(), "levy": lv, "days_to_purge": days_to_purge,
		"upkeep_coin": upkeep_cost(state, fid),
		"marked": {"faction": m, "name": String(state.factions[m]["name"]) if state.factions.has(m) else "", "is_you": m == fid},
		"skill_points": int(l.get("sp", 0)) if not l.is_empty() else 0, "nodes_taken": (l.get("nodes", []) as Array).size() if not l.is_empty() else 0,
		"live_factions": live_count(state), "holdings": state.holdings_of(fid).size(), "total_holdings": state.holdings.size()}
