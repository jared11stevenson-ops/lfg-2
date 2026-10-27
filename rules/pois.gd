class_name Pois
extends RefCounted
## Points of interest (data/pois.json). Worldgen places them per biome (deterministic from the seed, stored in world["pois"]);
## the only mutable state is state.poi_state[id] = {claimed_week, week, prog, guards[]} and per-actor a["pois_seen"].
## Each POI has a small challenge (offering | effort | lamps | sequence | guard) and pays a loot roll once per WEEK (reason to return).
## Command: interact_poi {poi:int, pick?:int}. Events: poi_discovered poi_progress poi_guarded poi_claimed. Nothing needs another player.
const PERMS: Array = [[0, 1, 2], [0, 2, 1], [1, 0, 2], [1, 2, 0], [2, 0, 1], [2, 1, 0]]

static func radius() -> int:
	return int(Content.poi_cfg().get("discover_radius", 3))

# ------------------------------------------------------------------ worldgen
## Deterministic placement: per type, per biome affinity, away from holdings and from each other. world["pois"] = [{id,type,hex,biome}].
static func place(world: Dictionary, start: Vector2i, comp: Dictionary, sites: Array, s: int) -> Array[Dictionary]:
	var cfg: Dictionary = Content.poi_cfg()
	var rng := Rng.new(s ^ 0x0b01d00d)
	var cands: Array[Vector2i] = []
	for h in comp.keys():
		if int(world["terrain"][HexGrid.index(h)]) == WorldGen.T_GROUND:
			cands.append(h)
	cands.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return HexGrid.index(a) < HexGrid.index(b))
	var blocked: Dictionary = {}
	var hg: int = int(cfg.get("holding_gap", 3))
	for st in sites:
		for hx in HexGrid.ring_within(st["hex"], hg - 1):
			blocked[hx] = true
	for hx in HexGrid.ring_within(start, 4):
		blocked[hx] = true
	var gap: int = int(cfg.get("min_gap", 6))
	var out: Array[Dictionary] = []
	for t in cfg.get("types", []):
		var biomes: Array = t["biomes"]
		var placed: int = 0
		var want: int = int(t["count"])
		var floor_n: int = mini(2, want)
		for k in range(want):
			var pool: Array[Vector2i] = []
			var band: Array = t.get("near_start", []) if k == 0 else []
			for h in cands:
				if blocked.has(h) or not biomes.has(WorldGen.biome_at(world, h)):
					continue
				if not band.is_empty():
					var d: int = HexGrid.distance(h, start)
					if d < int(band[0]) or d > int(band[1]):
						continue
				pool.append(h)
			if pool.is_empty() and not band.is_empty():
				for h in cands:       # no fitting ground inside the band: any fitting ground
					if not blocked.has(h) and biomes.has(WorldGen.biome_at(world, h)):
						pool.append(h)
			if pool.is_empty() and placed < floor_n:
				for h in cands:       # a world without this biome still gets two (placed on any open ground)
					if not blocked.has(h):
						pool.append(h)
			if pool.is_empty():
				continue
			var hx2: Vector2i = pool[rng.rand_i(pool.size())]
			out.append({"id": out.size() + 1, "type": String(t["id"]), "hex": hx2, "biome": WorldGen.biome_at(world, hx2)})
			placed += 1
			for b in HexGrid.ring_within(hx2, gap - 1):
				blocked[b] = true
	var by_id: Dictionary = {}
	for p in out:
		by_id[int(p["id"])] = p
	world["poi_by_id"] = by_id
	return out

# ------------------------------------------------------------------ lookups
static func all(state: MatchState) -> Array:
	return state.world.get("pois", [])

static func get_poi(state: MatchState, id: int) -> Dictionary:
	return (state.world.get("poi_by_id", {}) as Dictionary).get(id, {})

static func type_def(poi: Dictionary) -> Dictionary:
	return Content.poi_types().get(String(poi.get("type", "")), {})

static func st_of(state: MatchState, id: int) -> Dictionary:
	return state.poi_state.get(id, {"claimed_week": -1, "week": -1, "prog": 0, "guards": []})

static func seen(a: Dictionary, id: int) -> bool:
	return (a.get("pois_seen", []) as Array).has(id)

static func available(state: MatchState, id: int) -> bool:
	return int(st_of(state, id)["claimed_week"]) < state.week()

static func _hash(state: MatchState, id: int, salt: int, week: int) -> float:
	return Rng.hash2(id * 131 + salt, week * 7919 + 17, state.seed)

## This week's loot for a POI: {item: qty}. Pure function of (seed, poi, week); safe to preview.
static func roll_loot(state: MatchState, poi: Dictionary, week: int) -> Dictionary:
	var t: Dictionary = type_def(poi)
	var loot: Dictionary = {}
	var keys: Array = (t.get("loot", {}) as Dictionary).keys()
	keys.sort()
	for i in range(keys.size()):
		var rg: Array = t["loot"][keys[i]]
		var lo: int = int(rg[0])
		var hi: int = int(rg[1])
		var q: int = clampi(lo + int(floor(_hash(state, int(poi["id"]), i + 1, week) * float(hi - lo + 1))), lo, hi)
		if q > 0:
			loot[String(keys[i])] = q
	return loot

static func lamp_target(state: MatchState, poi: Dictionary, week: int) -> int:
	return 1 + int(floor(_hash(state, int(poi["id"]), 91, week) * 7.0)) % 7       # 1..7, never "all dark"

static func seq_order(state: MatchState, poi: Dictionary, week: int) -> Array:
	return PERMS[int(floor(_hash(state, int(poi["id"]), 92, week) * 6.0)) % 6]

## What the carving/lintel shows: the puzzle answer for this week (shown once the POI is discovered).
static func hint(state: MatchState, poi: Dictionary) -> Dictionary:
	var kind: String = String(type_def(poi).get("challenge", {}).get("kind", ""))
	var wk: int = state.week()
	if kind == "lamps":
		var m: int = lamp_target(state, poi, wk)
		return {"kind": kind, "lit": [(m & 1) != 0, (m & 2) != 0, (m & 4) != 0]}
	if kind == "sequence":
		return {"kind": kind, "order": (seq_order(state, poi, wk) as Array).duplicate()}
	return {"kind": kind}

# ------------------------------------------------------------------ discovery (fog of war)
## Called for every moved player leader: reveals POIs within the discover radius once and pays the small one-off reward.
static func discover_near(state: MatchState, a: Dictionary, events: Array) -> void:
	var pois: Array = all(state)
	if pois.is_empty():
		return
	var r: int = radius() + Companions.discover_bonus(a)
	for p in pois:
		var d: int = HexGrid.distance(a["hex"], p["hex"])
		if d > r or seen(a, int(p["id"])):
			continue
		if not a.has("pois_seen"):
			a["pois_seen"] = []
		(a["pois_seen"] as Array).append(int(p["id"]))
		var t: Dictionary = type_def(p)
		var reward: Dictionary = {}
		for k in (t.get("discover", {}) as Dictionary).keys():
			reward[String(k)] = int(t["discover"][k])
		if not reward.is_empty() and Inv.can_carry(a, reward):
			Inv.add_all(a["inv"], reward)
		else:
			reward = {}
		events.append({"type": &"poi_discovered", "actor": a["id"], "poi": p["id"], "poi_type": p["type"], "name": t.get("name", "?"), "hex": p["hex"],
			"flavor": t.get("flavor", ""), "reward": reward, "ai": false})

static func observe(state: MatchState, events: Array, from: int) -> void:
	if state.world.get("pois", []).is_empty():
		return
	var n: int = events.size()
	for i in range(from, n):
		var e: Dictionary = events[i]
		if e.get("type", &"") != &"actor_moved":
			continue
		var a: Dictionary = state.actors.get(int(e["actor"]), {})
		if not a.is_empty() and a["kind"] == "leader" and a["alive"]:
			discover_near(state, a, events)

# ------------------------------------------------------------------ command: interact_poi
static func _guards_alive(state: MatchState, st: Dictionary) -> int:
	var n: int = 0
	for gid in st.get("guards", []):
		var g: Dictionary = state.actors.get(int(gid), {})
		if not g.is_empty() and g["alive"]:
			n += 1
	return n

static func interact(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	if a["kind"] != "leader":
		return "unknown_actor"
	var pid: int = CmdUtil.parse_id(args.get("poi"))
	var poi: Dictionary = get_poi(state, pid)
	if poi.is_empty():
		return "unknown_poi"
	if state.phase == &"PURGE_ACTIVE":
		return "purge_closed"
	if HexGrid.distance(a["hex"], poi["hex"]) > 1:
		return "too_far"
	var t: Dictionary = type_def(poi)
	var ch: Dictionary = t["challenge"]
	var week: int = state.week()
	var st: Dictionary = st_of(state, pid).duplicate(true)
	if int(st["claimed_week"]) >= week:
		return "already_claimed"
	if int(st["week"]) != week:
		st["week"] = week
		st["prog"] = 0
	var kind: String = String(ch["kind"])
	var loot: Dictionary = roll_loot(state, poi, week)
	var cost: Dictionary = {}
	var energy: float = 0.0
	var progress_only: bool = false
	var wrong: bool = false
	var spawn: bool = false
	match kind:
		"offering":
			for k in (ch["items"] as Dictionary).keys():
				cost[String(k)] = int(ch["items"][k])
			if not Inv.has_all(a["inv"], cost):
				return "need_offering"
		"effort":
			energy = float(ch["energy"])
			if float(a["energy"]) < energy:
				return "no_energy"
		"lamps", "sequence":
			var pick: int = CmdUtil.parse_id(args.get("pick"))
			if pick < 0 or pick > 2:
				return "bad_pick"
			if kind == "lamps":
				st["prog"] = int(st["prog"]) ^ (1 << pick)
				progress_only = int(st["prog"]) != lamp_target(state, poi, week)
			else:
				var order: Array = seq_order(state, poi, week)
				if int(order[int(st["prog"])]) == pick:
					st["prog"] = int(st["prog"]) + 1
					progress_only = int(st["prog"]) < 3
				else:
					st["prog"] = 0
					wrong = true
					progress_only = true
		"guard":
			if (st["guards"] as Array).is_empty():
				spawn = true
				progress_only = true
			elif _guards_alive(state, st) > 0:
				return "guard_alive"
	if not progress_only and not Inv.can_carry(a, loot, cost):
		return "no_room"
	# ---- validated: mutate
	discover_near(state, a, events)      # standing at the door counts as having found it
	if spawn:
		var ids: Array = []
		var free: Array[Vector2i] = []
		for n in HexGrid.neighbors(poi["hex"]):
			if WorldGen.move_cost(state.world, n) > 0.0:
				free.append(n)
		var gi: int = 0
		for arch in ch["guards"]:
			var hx: Vector2i = free[gi % free.size()] if not free.is_empty() else poi["hex"]
			gi += 1
			var eid: int = Setup.spawn_enemy(state, String(arch), hx, false)
			if eid != -1:
				state.actors[eid]["poi"] = pid
				ids.append(eid)
		st["guards"] = ids
		state.poi_state[pid] = st
		events.append({"type": &"poi_guarded", "actor": a["id"], "poi": pid, "guards": ids, "text": ch.get("text", "")})
		return ""
	if energy > 0.0:
		a["energy"] = MatchState.q(float(a["energy"]) - energy)
	if not cost.is_empty():
		Inv.remove_all(a["inv"], cost)
	if progress_only:
		state.poi_state[pid] = st
		events.append({"type": &"poi_progress", "actor": a["id"], "poi": pid, "kind": kind, "prog": st["prog"], "ok": not wrong})
		if wrong:
			Combat.hurt(state, int(a["id"]), int(ch.get("trap_damage", 3)), -1, events, "trap")
		return ""
	st["claimed_week"] = week
	st["prog"] = 0
	st["guards"] = []
	state.poi_state[pid] = st
	Inv.add_all(a["inv"], loot)
	events.append({"type": &"poi_claimed", "actor": a["id"], "poi": pid, "poi_type": poi["type"], "name": t.get("name", "?"), "items": loot, "week": week, "ai": false})
	if t.has("guardian"):
		_guardian_defeated(state, a, poi, t, events)
	return ""

## A region guardian was beaten (the arena claim). The FIRST defeat per leader pays guardian.first once: a guaranteed T4 material, the unlock that gates the next
## tier (stations, buildings) and a title. Later weeks only pay the weekly loot roll above.
static func _guardian_defeated(state: MatchState, a: Dictionary, poi: Dictionary, t: Dictionary, events: Array) -> void:
	var g: Dictionary = t["guardian"]
	var gid: String = String(g["biome"])
	if not a.has("guardians"):
		a["guardians"] = []
	var first: bool = not (a["guardians"] as Array).has(gid)
	var pay: Dictionary = {}
	if first:
		(a["guardians"] as Array).append(gid)
		var fr: Dictionary = g.get("first", {})
		for k in (fr.get("items", {}) as Dictionary).keys():
			pay[String(k)] = int(fr["items"][k])
		Quests.grant(state, a, {"items": pay, "unlock": String(fr.get("unlock", "")), "title": String(fr.get("title", ""))})
	events.append({"type": &"guardian_defeated", "actor": a["id"], "poi": int(poi["id"]), "guardian": gid, "name": String(t.get("name", "")), "first": first, "bonus": pay,
		"unlock": String(g.get("first", {}).get("unlock", "")) if first else "", "week": state.week()})

# ------------------------------------------------------------------ view models (read only)
## One POI as the UI needs it: {id, type, name, hex, biome, discovered, available, kind, text, hint, prog, guards_alive, flavor}.
static func info(state: MatchState, a: Dictionary, pid: int) -> Dictionary:
	var poi: Dictionary = get_poi(state, pid)
	if poi.is_empty():
		return {}
	var t: Dictionary = type_def(poi)
	var st: Dictionary = st_of(state, pid)
	var disc: bool = seen(a, pid)
	return {"id": pid, "type": poi["type"], "prop": t.get("prop", ""), "name": t.get("name", "?") if disc else "Something unexplored", "hex": poi["hex"], "biome": poi["biome"], "discovered": disc,
		"available": available(state, pid), "kind": t["challenge"]["kind"], "text": t["challenge"].get("text", "") if disc else "", "flavor": t.get("flavor", "") if disc else "",
		"hint": hint(state, poi) if disc else {}, "prog": int(st["prog"]) if int(st["week"]) == state.week() else 0, "guards_alive": _guards_alive(state, st),
		"loot_types": (t.get("loot", {}) as Dictionary).keys() if disc else [], "arena": t.has("guardian"), "summoned": not (st.get("guards", []) as Array).is_empty()}

## Strategic-map markers: discovered POIs only (fog of war).
static func markers(state: MatchState, a: Dictionary) -> Array:
	var out: Array = []
	for p in all(state):
		if seen(a, int(p["id"])):
			out.append({"id": int(p["id"]), "type": String(p["type"]), "prop": type_def(p).get("prop", ""), "name": type_def(p).get("name", "?"), "hex": p["hex"],
				"available": available(state, int(p["id"]))})
	return out

## Nearest discovered-or-not POI within `max_d` hexes of the actor (for the interact prompt) -> poi dict or {}.
static func nearest(state: MatchState, a: Dictionary, max_d: int = 1) -> Dictionary:
	var best: Dictionary = {}
	var bd: int = 999
	for p in all(state):
		var d: int = HexGrid.distance(a["hex"], p["hex"])
		if d <= max_d and d < bd:
			bd = d
			best = p
	return best

## Toast data for the HUD from a poi_* event: {title, body, kind, color_key}. The lead feeds Hud.toast with it.
static func toast_for(e: Dictionary) -> Dictionary:
	match String(e.get("type", "")):
		"poi_discovered":
			var rw: Array = []
			for k in (e.get("reward", {}) as Dictionary).keys():
				rw.append("%s x%d" % [String(k).get_slice("/", 1).replace("_", " "), int(e["reward"][k])])
			return {"title": "Discovered: %s" % String(e.get("name", "?")), "body": String(e.get("flavor", "")) + (("  Found " + ", ".join(rw)) if not rw.is_empty() else ""), "kind": "good", "poi": e.get("poi", -1)}
		"poi_claimed":
			var parts: Array = []
			for k in (e.get("items", {}) as Dictionary).keys():
				parts.append("%s x%d" % [String(k).get_slice("/", 1).replace("_", " "), int(e["items"][k])])
			return {"title": "%s yields" % String(e.get("name", "?")), "body": ", ".join(parts) + ". It will have more next week.", "kind": "good", "poi": e.get("poi", -1)}
		"poi_guarded":
			return {"title": "Something guards this place", "body": String(e.get("text", "")), "kind": "warn", "poi": e.get("poi", -1)}
		"poi_progress":
			return {"title": "The mechanism clicks" if bool(e.get("ok", true)) else "Wrong! The old trap snaps", "body": "", "kind": "info" if bool(e.get("ok", true)) else "bad", "poi": e.get("poi", -1)}
	return {}
