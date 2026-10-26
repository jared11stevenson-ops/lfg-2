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
	var bd: int = aggro + 1
	var ids: Array = state.actors.keys()
	ids.sort()
	for id in ids:
		var t: Dictionary = state.actors[id]
		if t["kind"] == "enemy" or not t["alive"] or t["kind"] == "ai_leader":
			continue
		var d: int = HexGrid.distance(e["hex"], t["hex"])
		if d < bd:
			bd = d
			best = t
	return best

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
		var guard: int = 0
		while guard < 4:
			guard += 1
			var st: String = ai["state"]
			if st == "idle":
				var t: Dictionary = _nearest_target(state, e, int(def["aggro"]))
				if t.is_empty():
					break
				var atk: Dictionary = def["attacks"][0]
				var d: int = HexGrid.distance(e["hex"], t["hex"])
				if d <= int(atk["range"]):
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
				elif now >= float(ai["next_move"]):
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
