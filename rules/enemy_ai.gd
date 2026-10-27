class_name EnemyAI
extends RefCounted
## Telegraphed enemy attacks. Each attack is data: windup (telegraph shown, target hex locked), hit (active window), recovery.
## The attack strikes the LOCKED HEX, so a target that leaves during windup is not damaged (dodgeable).
const SIM_RANGE := 22

static func engaged(state: MatchState) -> bool:
	for e in state.actors.values():
		if e["kind"] == "enemy" and e["alive"] and e["ai"]["state"] != "idle":
			return true
	return false

static func _nearest_target(state: MatchState, e: Dictionary, aggro: int) -> Dictionary:
	var best: Dictionary = {}
	var bd: int = 1 << 30
	var ids: Array = state.actors.keys()
	ids.sort()
	for id in ids:
		var t: Dictionary = state.actors[id]
		if t["kind"] == "enemy" or not t["alive"] or t["kind"] == "ai_leader" or t["kind"] == "party":
			continue
		var d: int = HexGrid.distance(e["hex"], t["hex"])
		if d >= bd or d > aggro + 12:
			continue
		# Sable is noisy, Rook is marked (weaknesses widen the notice radius); a Quill truce flag hides you.
		var reach: int = aggro + int(Combat.class_mod(t, "noise", 0)) + int(Combat.class_mod(t, "marked", 0))
		if d > reach or Combat.has_effect(state, t, "truce"):
			continue
		bd = d
		best = t
	return best

## Which attack a creature starts at distance `d`. Single-attack archetypes: always attacks[0] (when in range). Multi-attack (guardians): the next attack in
## rotation whose range reaches, skipping attacks that need a later phase (`min_phase`).
static func pick_attack(def: Dictionary, ai: Dictionary, d: int) -> Dictionary:
	var atks: Array = def["attacks"]
	if atks.size() == 1:
		return atks[0] if d <= int(atks[0]["range"]) else {}
	var phase: int = int(ai.get("phase", 0))
	var avail: Array = []
	for a in atks:
		if int(a.get("min_phase", 0)) <= phase:
			avail.append(a)
	var n: int = avail.size()
	var start: int = int(ai.get("rot", 0))
	for i in range(n):
		var cand: Dictionary = avail[(start + i) % n]
		if d <= int(cand["range"]):
			ai["rot"] = (start + i + 1) % n
			return cand
	return {}

## Guardian phases: crossing an hp fraction fires once (adds join the fight, a message for the HUD) and unlocks `min_phase` attacks.
static func _boss_phase(state: MatchState, e: Dictionary, def: Dictionary, events: Array) -> void:
	var phases: Array = def.get("phases", [])
	var ph: int = int(e["ai"].get("phase", 0))
	if ph >= phases.size():
		return
	var spec: Dictionary = phases[ph]
	if float(e["hp"]) > float(spec["hp_frac"]) * float(e["max_hp"]):
		return
	e["ai"]["phase"] = ph + 1
	var adds: Array = []
	var free: Array[Vector2i] = []
	for n in HexGrid.neighbors(e["hex"]):
		if WorldGen.move_cost(state.world, n) > 0.0:
			free.append(n)
	var gi: int = 0
	var keys: Array = (spec.get("adds", {}) as Dictionary).keys()
	keys.sort()
	for k in keys:
		for q in range(int(spec["adds"][k])):
			var hx: Vector2i = free[gi % free.size()] if not free.is_empty() else e["hex"]
			gi += 1
			var eid: int = Setup.spawn_enemy(state, String(k), hx, false)
			if eid != -1:
				state.actors[eid]["add_of"] = e["id"]
				adds.append(eid)
	events.append({"type": &"boss_phase", "enemy": e["id"], "phase": ph + 1, "text": String(spec.get("text", "")), "adds": adds, "name": def.get("name", "")})

## A guardian that has no one to fight within its leash walks home and mends (so it cannot be pulled across the map or farmed with hit-and-run).
static func _boss_home(state: MatchState, e: Dictionary, def: Dictionary, now: float, events: Array) -> void:
	var home: Vector2i = e.get("home", e["hex"])
	if e["hex"] != home:
		if now >= float(e["ai"]["next_move"]):
			var best: Vector2i = e["hex"]
			var bd: int = HexGrid.distance(e["hex"], home)
			for n in HexGrid.neighbors(e["hex"]):
				if WorldGen.move_cost(state.world, n) <= 0.0:
					continue
				var nd: int = HexGrid.distance(n, home)
				if nd < bd:
					bd = nd
					best = n
			if best != e["hex"]:
				e["hex"] = best
				e["ai"]["next_move"] = MatchState.q(now + float(def["sec_per_hex"]) * 0.6 * WorldGen.move_cost(state.world, best))
				events.append({"type": &"actor_moved", "actor": e["id"], "hex": best})
			else:
				e["ai"]["next_move"] = MatchState.q(now + 1.0)
	elif int(e["hp"]) < int(e["max_hp"]) and now >= float(e["ai"].get("mend_t", 0.0)):
		e["ai"]["mend_t"] = MatchState.q(now + 1.0)
		e["hp"] = mini(int(e["max_hp"]), int(e["hp"]) + maxi(1, int(e["max_hp"]) / 20))
		if int(e["hp"]) >= int(e["max_hp"]):
			e["ai"]["phase"] = 0       # a fully mended guardian starts over: phases, adds and rotation reset
			e["ai"]["rot"] = 0

static func step(state: MatchState, events: Array) -> void:
	var now: float = float(state.clock["elapsed"])
	var p: Dictionary = state.player()
	var ids: Array = state.actors.keys()
	ids.sort()
	for id in ids:
		var e: Dictionary = state.actors[id]
		if e["kind"] != "enemy" or not e["alive"]:
			continue
		if not p.is_empty() and HexGrid.distance(p["hex"], e["hex"]) > SIM_RANGE and e["ai"]["state"] == "idle":
			continue
		var def: Dictionary = Content.enemy(String(e["archetype"]))
		var ai: Dictionary = e["ai"]
		if e.has("add_of"):
			var boss: Dictionary = state.actors.get(int(e["add_of"]), {})
			if boss.is_empty() or not boss["alive"]:
				e["alive"] = false      # a guardian's summoned helpers vanish with it (erased at the next resolution)
				e["hp"] = 0
				continue
		var is_boss: bool = bool(def.get("boss", false))
		if is_boss and ai["state"] == "idle":
			_boss_phase(state, e, def, events)
		var guard: int = 0
		while guard < 4:
			guard += 1
			var st: String = ai["state"]
			if st == "idle":
				var t: Dictionary = _nearest_target(state, e, int(def["aggro"]))
				if is_boss and not t.is_empty() and HexGrid.distance(t["hex"], e.get("home", e["hex"])) > int(def.get("leash", 8)):
					t = {}      # beyond the leash the guardian does not give chase
				if t.is_empty():
					if is_boss:
						_boss_home(state, e, def, now, events)
					break
				var d: int = HexGrid.distance(e["hex"], t["hex"])
				var atk: Dictionary = pick_attack(def, ai, d)
				if not atk.is_empty():
					var th: Vector2i = e["hex"] if atk["shape"] == "self_aoe" else t["hex"]
					ai["state"] = "windup"
					ai["attack"] = atk["id"]
					ai["target_hex"] = th
					ai["t_hit"] = MatchState.q(now + float(atk["windup"]))
					ai["t_end"] = MatchState.q(now + float(atk["windup"]) + float(atk["hit"]))
					ai["t_rec"] = MatchState.q(float(ai["t_end"]) + float(atk["recovery"]))
					ai["hit_done"] = []
					events.append({"type": &"enemy_telegraph", "enemy": e["id"], "attack": atk["id"], "shape": atk["shape"], "target_hex": th,
						"radius": atk["radius"], "windup": atk["windup"], "hit": atk["hit"], "recovery": atk["recovery"], "hit_at": ai["t_hit"]})
				elif now >= float(ai["next_move"]) and not Movement.rooted(state, e):
					var best: Vector2i = e["hex"]
					var bd: int = d
					for n in HexGrid.neighbors(e["hex"]):
						if WorldGen.move_cost(state.world, n) <= 0.0:
							continue
						var nd: int = HexGrid.distance(n, t["hex"])
						if nd < bd:
							bd = nd
							best = n
					if best != e["hex"]:
						e["hex"] = best
						ai["next_move"] = MatchState.q(now + float(def["sec_per_hex"]) * WorldGen.move_cost(state.world, best))
						events.append({"type": &"actor_moved", "actor": e["id"], "hex": best})
					else:
						ai["next_move"] = now + 1.0
				break
			elif st == "windup":
				if now >= float(ai["t_hit"]):
					ai["state"] = "active"
					continue
				break
			elif st == "active":
				var atk2: Dictionary = {}
				for a in def["attacks"]:
					if a["id"] == ai["attack"]:
						atk2 = a
				for tid in state.actors.keys():
					var t2: Dictionary = state.actors[tid]
					if t2["kind"] == "enemy" or not t2["alive"] or (ai["hit_done"] as Array).has(tid):
						continue
					if HexGrid.distance(t2["hex"], ai["target_hex"]) <= int(atk2["radius"]):
						(ai["hit_done"] as Array).append(tid)
						var dmg: int = maxi(1, int(atk2["damage"]) - int(Combat.def_of(state, t2) * 0.5))
						events.append({"type": &"enemy_hit", "enemy": e["id"], "attack": atk2["id"], "target": tid, "damage": dmg})
						Combat.hurt(state, int(tid), dmg, int(e["id"]), events, String(atk2["id"]))
						if atk2.has("poison_dps") and state.actors[tid]["alive"]:
							Combat.add_effect(state.actors[tid], "poison", MatchState.q(now + float(atk2["poison_secs"])), {"dps": int(atk2["poison_dps"]), "next": MatchState.q(now + 1.0), "source": e["id"]})
				if now >= float(ai["t_end"]):
					ai["state"] = "recovery"
					continue
				break
			else: # recovery
				if now >= float(ai["t_rec"]):
					ai["state"] = "idle"
					ai["hit_done"] = []
				break
