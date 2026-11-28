class_name Civ
extends RefCounted
## Civilizations emerge from sapient demes. What they BUILD follows from anatomy:
## environmental operations (excavate, deposit, bind, weave, cultivate, redirect water ...) are scored
## from the species' genes; settlement forms and layers (surface / underground / aquatic / elevated)
## fall out of those scores and the terrain. No two species share a build menu.

const SHELTER_CAP := 70.0   # individuals housed per shelter (pop units are demographic, not heads)
const MAX_PER_REGION := 22

static func capabilities(g: PackedFloat32Array, bp: int) -> Dictionary:
	var T := func(n: String) -> float: return g[Genome.IDX[n]]
	var manip: float = T.call("c_manip"); var str_: float = T.call("strength")
	var caps := {
		"excavate": T.call("burrow") * (0.55 + 0.45 * str_),
		"deposit": (0.4 * str_ + 0.6 * manip) * (1.0 if bp != Genome.BP.FISH else 0.2),
		"bind": T.call("secrete") * 0.7 + manip * 0.3,
		"weave": T.call("secrete") * 0.5 + manip * 0.4 + T.call("limb") * 0.1,
		"cultivate": T.call("c_plan") * T.call("c_coop") * (1.2 - T.call("carniv")) + (0.25 if bp == Genome.BP.INSECT else 0.0),
		"water": T.call("aqua") * (0.5 * str_ + 0.5 * manip),
		"transport": T.call("speed") * 0.4 + T.call("c_coop") * 0.4 + (0.3 if bp == Genome.BP.AVIAN else 0.0),
		"reinforce": manip * T.call("c_plan"),
	}
	# layers: where this species prefers to live
	var lay := {"underground": T.call("burrow"), "aquatic": T.call("aqua") * (1.0 if bp != Genome.BP.AMPHIB else 0.7), "elevated": T.call("climb") * 0.8 + (0.6 if bp == Genome.BP.AVIAN else 0.0) + (0.3 if (bp == Genome.BP.ARACH) else 0.0), "surface": 0.45}
	caps["layers"] = lay
	var best := "surface"; var bv := -1.0
	for k in lay:
		if lay[k] > bv: bv = lay[k]; best = k
	caps["home_layer"] = best
	return caps

static func shelter_style(caps: Dictionary, bp: int) -> String:
	if bp == Genome.BP.INSECT and caps["excavate"] > 0.35 and caps["deposit"] > 0.25: return "hive_mound"
	if bp == Genome.BP.ARACH or (caps["bind"] > 0.55 and caps["home_layer"] == "elevated"): return "web_hall"
	if bp == Genome.BP.AVIAN: return "nest_cluster"
	if caps["water"] > 0.4 and caps["deposit"] > 0.3: return "lodge"
	if caps["excavate"] > 0.45: return "warren"
	if caps["deposit"] > 0.4: return "mound_hut"
	if caps["weave"] > 0.4: return "woven_hut"
	return "burrow_nook"

const COSTS := {"shelter": 8.0, "store": 6.0, "farm": 9.0, "water_work": 18.0, "road": 5.0, "defense": 12.0, "workshop": 14.0, "monument": 30.0}

static func found(sim: EcoSim, deme: Dictionary, r: int) -> Dictionary:
	var sp: int = deme["sp"]
	# a deme near a living civ of its own species joins it (one culture spreads; it does not re-found itself)
	for c in sim.civs:
		if c["collapsed"] < 0 and c["sp"] == sp:
			for cr in c["regions"]:
				if absi(cr % EcoSim.RW - r % EcoSim.RW) <= 3 and absi(cr / EcoSim.RW - r / EcoSim.RW) <= 3:
					if not c["regions"].has(r): c["regions"].append(r)
					deme["civ"] = c["id"]
					return c
	var bp: int = sim.species[sp]["bp"]
	var caps := capabilities(deme["g"], bp)
	var civ := {
		"id": sim.civs.size(), "sp": sp, "bp": bp, "name": _civ_name(sim, sp), "home": r, "regions": [r], "founded": sim.tick, "collapsed": -1,
		"caps": caps, "g": deme["g"].duplicate(), "know": {}, "structures": [], "bp_pts": 6.0, "pop": deme["n"],
		"culture": {"raided": 0, "flooded": 0, "famine": 0, "victory": 0, "traded": 0, "sky_raids": 0, "inventions": 0},
		"rel": {}, "famine_t": 0, "leader": _leader_name(sim), "leader_born": sim.tick, "law": "", "heirlooms": [], "state": "tribe",
	}
	deme["civ"] = civ["id"]
	sim.civs.append(civ)
	sim.events.append({"tick": sim.tick, "type": "civ", "text": "The %s found %s (%s dwellers)" % [sim.species[sp]["name"], civ["name"], caps["home_layer"]], "sp": sp, "region": r})
	return civ

static func _civ_name(sim: EcoSim, sp: int) -> String:
	var a := ["Vess", "Orrin", "Thale", "Murr", "Quill", "Anse", "Dorn", "Ilke", "Sable", "Wren", "Corvé", "Nim", "Ashe", "Kell", "Brae"]
	var b := ["Hold", "Reach", "Commons", "Delve", "Weave", "Court", "Hollow", "Span", "Chorus", "Burrow"]
	return "%s %s" % [a[sim.rng.randi() % a.size()], b[sim.rng.randi() % b.size()]]

static func _leader_name(sim: EcoSim) -> String:
	var a := ["Ka", "Ti", "Mo", "Ra", "Su", "Vi", "Ne", "Lo", "Ba", "Ze"]
	return a[sim.rng.randi() % a.size()] + a[sim.rng.randi() % a.size()].to_lower() + ["n", "r", "s", "x", "l"][sim.rng.randi() % 5]

# ------------------------------------------------------------------ per-season step
static func step(sim: EcoSim, civ: Dictionary) -> void:
	if civ["collapsed"] >= 0: return
	# population & hunger from the living demes
	var pop := 0.0; var fed := 0.0; var cnt := 0
	for r in civ["regions"]:
		for d in sim.pops[r]:
			if d["sp"] == civ["sp"]:
				pop += d["n"]; fed += d["fed"]; cnt += 1
				d["civ"] = civ["id"]
	civ["pop"] = pop
	var fedm := fed / maxf(cnt, 1)
	if fedm < 0.45: civ["famine_t"] += 1
	else: civ["famine_t"] = maxi(civ["famine_t"] - 1, 0)
	if civ["famine_t"] == 6:
		civ["culture"]["famine"] += 1
		sim.events.append({"tick": sim.tick, "type": "famine", "text": "Famine grips %s" % civ["name"], "sp": civ["sp"], "region": civ["home"]})
	if pop < 12.0 or civ["famine_t"] > 30:
		_collapse(sim, civ, "starvation" if civ["famine_t"] > 30 else "attrition")
		return
	# leader succession
	if sim.tick - civ["leader_born"] > 80 + sim.rng.randi() % 40:
		var old: String = civ["leader"]
		civ["leader"] = _leader_name(sim); civ["leader_born"] = sim.tick
		sim.events.append({"tick": sim.tick, "type": "succession", "text": "%s succeeds %s as head of %s" % [civ["leader"], old, civ["name"]], "sp": civ["sp"], "region": civ["home"]})
	_discover(sim, civ)
	var caps: Dictionary = civ["caps"]
	var ops: float = (caps["excavate"] + caps["deposit"] + caps["bind"] + caps["weave"] + caps["reinforce"]) / 5.0
	civ["bp_pts"] += pop * 0.03 * (0.5 + ops * 1.5) * (1.0 if fedm > 0.6 else 0.4)
	_build(sim, civ, fedm)
	_decay(sim, civ)
	_effects(sim, civ)
	_expand(sim, civ, fedm)

static func _discover(sim: EcoSim, civ: Dictionary) -> void:
	var g: PackedFloat32Array = civ["g"]
	var rate := sqrt(civ["pop"]) * 0.012 * EcoSim.T(g, "c_curio") * (0.3 + EcoSim.T(g, "c_manip")) * (0.3 + EcoSim.T(g, "c_plan"))
	if sim.rng.randf() > rate: return
	var r: int = civ["regions"][sim.rng.randi() % civ["regions"].size()]
	var pool := Materials.available(sim.water[r], sim.trees[r], sim.elev[r], sim.soil[r], EcoSim.T(g, "secrete"), sim.temp[r] > 0.65 and sim.moist[r] < 0.3)
	var fn: String = Invention.FUNCS.keys()[sim.rng.randi() % Invention.FUNCS.size()]
	var design := Invention.best_design(fn, pool, g)
	if design.is_empty(): return
	# explorers sometimes try odd substitutions
	if sim.rng.randf() < 0.35:
		var roles: Array = design.keys()
		design[roles[sim.rng.randi() % roles.size()]] = pool[sim.rng.randi() % pool.size()]
	var res := Invention.evaluate(fn, design, g)
	if not res["ok"]: return
	var cur: Dictionary = civ["know"].get(fn, {})
	if cur.is_empty() or res["score"] > cur["score"] + 0.05:
		civ["know"][fn] = {"score": res["score"], "design": design, "tick": sim.tick, "name": Invention.design_name(fn, design)}
		civ["culture"]["inventions"] += 1
		sim.events.append({"tick": sim.tick, "type": "invention", "text": "%s devise the %s" % [civ["name"], Invention.design_name(fn, design)], "sp": civ["sp"], "region": r})

static func _count(civ: Dictionary, kind: String) -> int:
	var n := 0
	for s in civ["structures"]:
		if s["kind"] == kind and s["state"] == "alive": n += 1
	return n

static func _build(sim: EcoSim, civ: Dictionary, fedm: float) -> void:
	var caps: Dictionary = civ["caps"]
	var pop: float = civ["pop"]
	var shelters := _count(civ, "shelter")
	var need := ""
	var per_region := float(civ["structures"].size()) / maxf(civ["regions"].size(), 1)
	if per_region >= MAX_PER_REGION or civ["structures"].size() >= 160: return          # settlements fill their land; growth must come from expansion or tech
	if shelters * SHELTER_CAP * (1.0 + 0.12 * civ["know"].size()) < pop: need = "shelter"
	elif _count(civ, "store") < maxi(1, shelters / 3): need = "store"
	elif (fedm < 0.8 or _count(civ, "farm") < shelters / 4) and caps["cultivate"] > 0.28: need = "farm"
	elif caps["water"] > 0.4 and _count(civ, "water_work") < 1 and shelters >= 3: need = "water_work"
	elif civ["culture"]["raided"] + civ["culture"]["sky_raids"] > _count(civ, "defense") * 2 and shelters >= 2: need = "defense"
	elif civ["know"].size() > 2 and _count(civ, "workshop") < 1: need = "workshop"
	elif shelters > 3 and _count(civ, "road") < shelters / 2: need = "road"
	elif shelters > 8 and _count(civ, "monument") < 1: need = "monument"
	else: need = "shelter"
	var cost: float = COSTS[need]
	if civ["bp_pts"] < cost: return
	civ["bp_pts"] -= cost
	var style := _style_for(civ, need)
	var r: int = civ["regions"][sim.rng.randi() % civ["regions"].size()]
	var pos := _place(sim, civ, r, style)
	if pos == Vector2i(-1, -1): return
	civ["structures"].append({"kind": need, "style": style, "tile": pos, "region": r, "hp": 1.0, "state": "alive", "built": sim.tick, "age": 0, "civ": civ["id"], "layer": _layer_of(style)})
	if sim.tick - int(civ.get("last_build_ev", -99)) > 24:
		civ["last_build_ev"] = sim.tick
		sim.events.append({"tick": sim.tick, "type": "build", "text": "%s raise a %s" % [civ["name"], style.replace("_", " ")], "sp": civ["sp"], "region": r})

static func _layer_of(style: String) -> String:
	match style:
		"warren", "burrow_nook", "tunnel_net", "root_cellar": return "underground"
		"lodge", "dam", "canal", "fish_weir", "reed_raft_town": return "aquatic"
		"web_hall", "nest_cluster", "silk_line", "tripline_net", "canopy_walk", "watch_perch": return "elevated"
	return "surface"

static func _style_for(civ: Dictionary, need: String) -> String:
	var caps: Dictionary = civ["caps"]; var bp: int = civ["bp"]
	match need:
		"shelter": return shelter_style(caps, bp)
		"store": return "root_cellar" if caps["excavate"] > 0.4 else ("silk_cocoon_store" if caps["bind"] > 0.5 else "granary")
		"farm": return "fungus_garden" if bp == Genome.BP.INSECT else ("reed_paddy" if caps["water"] > 0.35 else "seed_plot")
		"water_work": return "dam" if caps["deposit"] > 0.3 else "canal"
		"road": return "tunnel_net" if caps["excavate"] > 0.5 else ("silk_line" if caps["bind"] > 0.5 else ("canopy_walk" if caps["home_layer"] == "elevated" else "trail"))
		"defense": return "tripline_net" if caps["bind"] > 0.45 else ("spike_ring" if caps["deposit"] > 0.3 else "thorn_hedge")
		"workshop": return "forge_hollow" if caps["excavate"] > 0.4 else "workbench"
		"monument": return "cairn_spire"
	return "burrow_nook"

static func _place(sim: EcoSim, civ: Dictionary, r: int, style: String) -> Vector2i:
	var aquatic := _layer_of(style) == "aquatic"
	var cx := (r % EcoSim.RW) * 8 + 4; var cy := (r / EcoSim.RW) * 8 + 4
	for k in 40:
		var rad := 1.5 + k * 0.18
		var a := sim.rng.randf() * TAU
		var t := Vector2i(clampi(cx + int(cos(a) * rad * 2.0), (r % EcoSim.RW) * 8, (r % EcoSim.RW) * 8 + 7), clampi(cy + int(sin(a) * rad * 2.0), (r / EcoSim.RW) * 8, (r / EcoSim.RW) * 8 + 7))
		var taken := false
		for s in civ["structures"]:
			if s["tile"] == t: taken = true; break
		if taken: continue
		var wat: float = sim.water[r]
		if aquatic != (wat > 0.35) and style != "dam": continue
		return t
	return Vector2i(-1, -1)

static func _decay(sim: EcoSim, civ: Dictionary) -> void:
	var care := 1.0 if civ["pop"] > 20 else 0.4
	for s in civ["structures"]:
		s["age"] += 1
		if s["state"] != "alive": continue
		var rate: float = 0.004 * (1.4 if s["layer"] == "elevated" else 1.0) * (1.0 + (1.0 - civ["caps"]["reinforce"]) * 0.5)
		s["hp"] -= rate * (1.0 - 0.7 * care * minf(civ["bp_pts"] / 10.0 + 0.3, 1.0))
		if s["hp"] <= 0.0: s["state"] = "ruin"; s["hp"] = 0.4

static func _effects(sim: EcoSim, civ: Dictionary) -> void:
	for s in civ["structures"]:
		if s["state"] != "alive": continue
		var r: int = s["region"]
		match s["style"]:
			"dam", "canal":
				if sim.water[r] < 0.9 and sim.tick % 4 == 0:
					sim.water[r] = minf(sim.water[r] + 0.02, 0.9); sim.trees[r] = maxf(sim.trees[r] - 0.01, 0.0)
					_harm_region(sim, civ, r, "flooded", "layer", "underground", 0.02)
			"tunnel_net", "warren", "hive_mound":
				sim.stab[r] = maxf(sim.stab[r] - 0.004, 0.0)
				if sim.stab[r] < 0.5:
					_harm_region(sim, civ, r, "collapse", "layer", "surface", 0.03)
			"seed_plot", "reed_paddy", "fungus_garden":
				sim.plant_k[r] = minf(sim.plant_k[r] * 1.002, 2600.0)
				sim.trees[r] = maxf(sim.trees[r] - 0.003, 0.0)

## Infrastructure harms other civs' structures in the same region (and records who did it).
static func _harm_region(sim: EcoSim, culprit: Dictionary, r: int, kind: String, key: String, val: String, dmg: float) -> void:
	for other in sim.civs:
		if other["id"] == culprit["id"] or other["collapsed"] >= 0: continue
		for s in other["structures"]:
			if s["region"] == r and s["state"] == "alive" and s[key] == val:
				s["hp"] -= dmg
				if sim.tick - int(other.get("harm_ev_" + kind, -99)) > 40:
					other["harm_ev_" + kind] = sim.tick
					other["culture"]["flooded"] += 1
					other["rel"][culprit["id"]] = float(other["rel"].get(culprit["id"], 0.0)) - 0.4
					sim.events.append({"tick": sim.tick, "type": "harm", "text": "%s's %s damages %s's %s" % [culprit["name"], "waterworks" if kind == "flooded" else "tunnels", other["name"], "burrows" if kind == "flooded" else "surface halls"], "sp": culprit["sp"], "region": r})

static func _expand(sim: EcoSim, civ: Dictionary, fedm: float) -> void:
	if civ["pop"] < 60.0 * civ["regions"].size() or fedm < 0.75 or sim.tick % 6 != 0: return
	var r: int = civ["regions"][sim.rng.randi() % civ["regions"].size()]
	var x: int = r % EcoSim.RW + [1, -1, 0, 0][sim.rng.randi() % 4]; var y: int = r / EcoSim.RW + [0, 0, 1, -1][sim.rng.randi() % 4]
	if not sim.in_bounds(x, y): return
	var nr := sim.idx(x, y)
	if civ["regions"].has(nr) or not sim._habitable_for(civ["bp"], {}, nr): return
	civ["regions"].append(nr)
	sim.events.append({"tick": sim.tick, "type": "expand", "text": "%s settle a new region" % civ["name"], "sp": civ["sp"], "region": nr})

static func _collapse(sim: EcoSim, civ: Dictionary, why: String) -> void:
	civ["collapsed"] = sim.tick
	for s in civ["structures"]:
		if s["state"] == "alive": s["state"] = "ruin"; s["hp"] = minf(s["hp"], 0.8)
	sim.events.append({"tick": sim.tick, "type": "collapse", "text": "%s collapses (%s); %d structures stand abandoned" % [civ["name"], why, civ["structures"].size()], "sp": civ["sp"], "region": civ["home"]})

## Knowledge and conflict between neighbouring civilizations.
static func interact(sim: EcoSim) -> void:
	var live := []
	for c in sim.civs:
		if c["collapsed"] < 0: live.append(c)
	for i in live.size():
		for j in range(i + 1, live.size()):
			var a: Dictionary = live[i]; var b: Dictionary = live[j]
			var close := false
			for ra in a["regions"]:
				for rb in b["regions"]:
					if absi(ra % EcoSim.RW - rb % EcoSim.RW) <= 2 and absi(ra / EcoSim.RW - rb / EcoSim.RW) <= 2: close = true
			if not close: continue
			var rel: float = float(a["rel"].get(b["id"], 0.0))
			# trade: complementary knowledge or materials drifts relations up and spreads techniques
			var gain := false
			for fn in b["know"]:
				if not a["know"].has(fn) and sim.rng.randf() < 0.03 + 0.02 * EcoSim.T(a["g"], "c_comm"):
					# learning requires a body that can use the technique
					if Invention.evaluate(fn, b["know"][fn]["design"], a["g"])["ok"]:
						a["know"][fn] = b["know"][fn].duplicate(); a["know"][fn]["learned_from"] = b["name"]
						a["culture"]["traded"] += 1; gain = true
						sim.events.append({"tick": sim.tick, "type": "trade", "text": "%s learn the %s from %s" % [a["name"], b["know"][fn]["name"], b["name"]], "sp": a["sp"], "region": a["home"]})
			if gain: rel += 0.1
			a["rel"][b["id"]] = clampf(rel, -2.0, 2.0)
			b["rel"][a["id"]] = clampf(float(b["rel"].get(a["id"], 0.0)), -2.0, 2.0)
			# war when hostile
			if float(a["rel"][b["id"]]) < -0.7 and sim.rng.randf() < 0.1:
				_raid(sim, a, b)
			elif float(b["rel"][a["id"]]) < -0.7 and sim.rng.randf() < 0.1:
				_raid(sim, b, a)

static func _raid(sim: EcoSim, att: Dictionary, dfn: Dictionary) -> void:
	var sa: float = att["pop"] * (0.5 + EcoSim.T(att["g"], "aggr")) * (1.0 + 0.3 * att["know"].size())
	var sd: float = dfn["pop"] * (0.5 + EcoSim.T(dfn["g"], "aggr") * 0.5) * (1.0 + 0.3 * dfn["know"].size()) * (1.0 + 0.25 * _count(dfn, "defense"))
	var win := sa * sim.rng.randf_range(0.7, 1.3) > sd * sim.rng.randf_range(0.7, 1.3)
	var w: Dictionary = att if win else dfn; var l: Dictionary = dfn if win else att
	l["culture"]["raided"] += 1
	if att["bp"] == Genome.BP.AVIAN: dfn["culture"]["sky_raids"] += 1
	w["culture"]["victory"] += 1
	for r in l["regions"]:
		for d in sim.pops[r]:
			if d["sp"] == l["sp"]: d["n"] *= 0.8
	var fn_list: Array = l["know"].keys()
	if not fn_list.is_empty():
		var fn: String = fn_list[sim.rng.randi() % fn_list.size()]
		if not w["know"].has(fn) and Invention.evaluate(fn, l["know"][fn]["design"], w["g"])["ok"]:
			w["know"][fn] = l["know"][fn].duplicate()
			sim.events.append({"tick": sim.tick, "type": "theft", "text": "%s seize the secret of the %s" % [w["name"], l["know"][fn]["name"]], "sp": w["sp"], "region": w["home"]})
	for s in l["structures"]:
		if s["state"] == "alive" and sim.rng.randf() < 0.15: s["hp"] -= 0.5
	l["rel"][w["id"]] = float(l["rel"].get(w["id"], 0.0)) - 0.2
	sim.events.append({"tick": sim.tick, "type": "war", "text": "%s defeat %s in battle" % [w["name"], l["name"]], "sp": w["sp"], "region": l["home"]})
