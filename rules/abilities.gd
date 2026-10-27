class_name Abilities
extends RefCounted
## use_ability. Fully implemented: Judd (guard), Mira (plague_cloud), Bram (rage + forage), Vex (pickpocket), Oren (field_dressing).
## Tavi/Pip/Sable/Quill/Forge/Nyx/Rook/Dune/Halo live in class_kits.gd. A class with implemented:false is rejected with "ability_not_implemented".

static func ability_for(cd: Dictionary, id: String) -> Dictionary:
	var main: Dictionary = cd.get("ability", {})
	if id == "" or id == String(main.get("id", "")):
		return main
	var peace: Dictionary = cd.get("peace_ability", {})
	if not peace.is_empty() and id == String(peace["id"]):
		return peace
	return {}

static func use(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	var cd: Dictionary = Content.class_def(String(a["class_id"]))
	if cd.is_empty():
		return "no_class"
	var ab: Dictionary = ability_for(cd, CmdUtil.s(args.get("ability", "")))
	if ab.is_empty():
		return "unknown_ability"
	ab = Skills.tune_ability(a, ab)
	if not bool(cd.get("implemented", false)):
		return "ability_not_implemented"
	var key: String = "ab:" + String(ab["id"])
	if not Combat.ready(state, a, key):
		return "cooldown"
	if float(a["energy"]) < float(ab["energy"]):
		return "no_energy"
	var now: float = float(state.clock["elapsed"])
	var aid: String = String(ab["id"])
	var res: String = ""
	match aid:
		"lfg:ability/guard":
			Combat.add_effect(a, "guard", MatchState.q(now + float(ab["duration"])))
		"lfg:ability/rage":
			var cost: int = int(ab["hp_cost"])
			if int(a["hp"]) <= cost:
				return "too_weak"
			a["hp"] = int(a["hp"]) - cost
			Combat.add_effect(a, "rage", MatchState.q(now + float(ab["duration"])))
		"lfg:ability/plague_cloud":
			var hit: Array[int] = []
			var ids: Array = state.actors.keys()
			ids.sort()
			for id in ids:
				var o: Dictionary = state.actors[id]
				if not o["alive"] or int(o["id"]) == int(a["id"]) or int(o["faction"]) == int(a["faction"]):
					continue
				if HexGrid.distance(o["hex"], a["hex"]) > int(ab["radius"]):
					continue
				if o["kind"] != "enemy" and state.phase != &"PURGE_ACTIVE":
					continue
				hit.append(int(id))
			if hit.is_empty():
				return "no_targets"
			for id in hit:
				Combat.add_effect(state.actors[id], "poison", MatchState.q(now + float(ab["duration"])), {"dps": int(ab["dps"]), "next": MatchState.q(now + 1.0), "source": a["id"]})
			events.append({"type": &"ability_used", "actor": a["id"], "ability": aid, "targets": hit})
		"lfg:ability/forage":
			if state.phase == &"PURGE_ACTIVE":
				return "not_in_purge"
			var idx: int = HexGrid.index(a["hex"])
			if int(state.world["terrain"][idx]) != WorldGen.T_GROUND:
				return "bad_terrain"
			var b: String = WorldGen.biome_at(state.world, a["hex"])
			var gain: Dictionary = {"lfg:item/mushroom": 1 + state.rand_i(2) + int(Combat.class_mod(a, "forage_bonus", 0))}
			if (b == "fungal_grove" or b == "bog") and state.rand_f() < 0.4:
				gain["lfg:item/spore_sac"] = 1
			if not Inv.can_carry(a, gain):
				return "no_room"
			Inv.add_all(a["inv"], gain)
			events.append({"type": &"ability_used", "actor": a["id"], "ability": aid, "items": gain})
		"lfg:ability/pickpocket":
			if state.phase != &"PURGE_ACTIVE":
				return "not_purge"
			var t: Dictionary = state.actors.get(CmdUtil.parse_id(args.get("target")), {})
			if t.is_empty() or not t["alive"] or int(t["id"]) == int(a["id"]):
				return "bad_target"
			if int(t["faction"]) == int(a["faction"]) or t["kind"] == "enemy":
				return "bad_target"
			if HexGrid.distance(t["hex"], a["hex"]) > 1:
				return "too_far"
			var pick: String = ""
			var bv: int = -1
			var keys: Array = t["inv"].keys()
			keys.sort()
			for k in keys:
				if Content.item_value(String(k)) > bv:
					bv = Content.item_value(String(k))
					pick = String(k)
			if pick == "":
				return "nothing_to_steal"
			if not Inv.can_carry(a, {pick: 1}):
				return "no_room"
			Combat.set_cd(state, a, key, float(ab["cooldown"]))
			a["energy"] = MatchState.q(float(a["energy"]) - float(ab["energy"]))
			if state.rand_f() < 0.5 + float(Combat.class_mod(a, "steal_bonus", 0.0)):
				Inv.transfer(t["inv"], a["inv"], {pick: 1})
				events.append({"type": &"ability_used", "actor": a["id"], "ability": aid, "target": t["id"], "item": pick, "success": true})
			else:
				events.append({"type": &"ability_used", "actor": a["id"], "ability": aid, "target": t["id"], "success": false})
				Combat.hurt(state, int(a["id"]), int(ab["fail_damage"]), int(t["id"]), events, "caught_stealing")
			return ""
		"lfg:ability/field_dressing":
			var tid: int = int(a["id"])
			if args.has("target"):
				tid = CmdUtil.parse_id(args["target"])
			var t2: Dictionary = state.actors.get(tid, {})
			if t2.is_empty() or not t2["alive"] or t2["kind"] == "enemy":
				return "bad_target"
			if int(t2["faction"]) != int(a["faction"]):
				return "bad_target"
			if tid != int(a["id"]) and HexGrid.distance(t2["hex"], a["hex"]) > 1:
				return "too_far"
			if int(t2["hp"]) >= int(t2["max_hp"]):
				return "full_health"
			var healed: int = Combat.heal(t2, int(ab["heal"]))
			events.append({"type": &"ability_used", "actor": a["id"], "ability": aid, "target": tid, "healed": healed})
		_:
			res = ClassKits.run(state, a, ab, args, events)
	if res != "":
		return res
	Combat.set_cd(state, a, key, float(ab["cooldown"]))
	a["energy"] = MatchState.q(float(a["energy"]) - float(ab["energy"]))
	if aid == "lfg:ability/guard" or aid == "lfg:ability/rage":
		events.append({"type": &"ability_used", "actor": a["id"], "ability": aid})
	return ""
