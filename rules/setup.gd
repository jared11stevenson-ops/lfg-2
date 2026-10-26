class_name Setup
extends RefCounted
## Builds a fresh MatchState from a seed.

const AI_COUNT := 12
const WILD_COUNT := 24
const PERSONAS: Array[String] = ["raider", "hoarder", "trader", "turtle"]
const FACTION_NAMES: Array[String] = ["Ember Reeve", "Mosskin Compact", "The Gilded Spade", "Hollow Court", "Saltwind Clan", "Red Lantern Guild",
	"Thistle Pact", "Brine Brothers", "Ashen Plough", "Lantern Wardens", "Cinder Sowers", "The Last Furrow"]

static func make_actor(id: int, kind: String, faction: int, nm: String, hex: Vector2i, hp: int, atk: int, df: int, energy: int) -> Dictionary:
	return {"id": id, "kind": kind, "faction": faction, "name": nm, "class_id": "", "archetype": "", "hex": hex, "hp": hp, "max_hp": hp,
		"atk": atk, "def": df, "energy": float(energy), "max_energy": energy, "inv": {}, "cd": {}, "effects": [], "alive": true,
		"last_seq": 0, "move": {}, "sync_t": 0.0, "is_ai": faction >= 1 and kind != "enemy", "ai": {}}

static func build(seed_value: int, class_id: StringName, opts: Dictionary) -> MatchState:
	var s := MatchState.new()
	s.seed = seed_value
	s.opts = opts.duplicate(true)
	s.day_seconds = float(opts.get("day_seconds", 360.0))
	s.world = WorldGen.generate(seed_value)
	var rng := Rng.new(seed_value ^ 0x1badb002)
	s.rng_state = rng.state
	var sites: Array = s.world["sites"]
	var start: Vector2i = s.world["start"]
	# AI home selection: greedy farthest-spread among sites >= 12 from start.
	var ai_sites: Array[int] = []
	var pool: Array[int] = []
	for k in range(1, sites.size()):
		if HexGrid.distance(start, sites[k]["hex"]) >= 12:
			pool.append(k)
	var pick_n: int = mini(AI_COUNT, pool.size())
	while ai_sites.size() < pick_n:
		var best: int = -1
		var bd: int = -1
		for k in pool:
			if ai_sites.has(k):
				continue
			var md: int = HexGrid.distance(start, sites[k]["hex"])
			for a in ai_sites:
				md = mini(md, HexGrid.distance(sites[a]["hex"], sites[k]["hex"]))
			md = md * 8 + rng.rand_i(8)
			if md > bd:
				bd = md
				best = k
		ai_sites.append(best)
	# Holdings
	for k in range(sites.size()):
		var st: Dictionary = sites[k]
		var owner: int = -1
		if k == 0:
			owner = 0
		elif ai_sites.has(k):
			owner = ai_sites.find(k) + 1
		var tier: int = int(st["tier"])
		var h: Dictionary = {"id": int(st["id"]), "name": st["name"], "hex": st["hex"], "tier": tier, "owner": owner, "store": {}, "garrison": 1 + tier,
			"buildings": [], "ration_policy": "full", "stance": "defend", "merchant": owner == -1}
		if owner == 0:
			h["garrison"] = 3
			h["store"] = {"lfg:item/timber": 10, "lfg:item/stone": 6, "lfg:item/ration": 4, "lfg:item/coin": 10}
		elif owner > 0:
			h["garrison"] = 3 + tier
			h["store"] = {"lfg:item/ration": 8, "lfg:item/glowfruit": 6, "lfg:item/saltroot": 2, "lfg:item/coin": 12, "lfg:item/timber": 4}
		else:
			h["store"] = {"lfg:item/glowfruit_seed": 12, "lfg:item/sporebean_seed": 12, "lfg:item/saltroot_seed": 8, "lfg:item/ration": 10,
				"lfg:item/timber": 10, "lfg:item/stone": 8, "lfg:item/coin": 60, "lfg:item/mushroom": 4}
		if owner == -1:
			h["base_stock"] = h["store"].duplicate()
		s.holdings[h["id"]] = h
	s.next_id = 100
	# Player
	var cd: Dictionary = Content.class_def(String(class_id))
	if cd.is_empty():
		cd = Content.class_def("lfg:class/judd")
		class_id = &"lfg:class/judd"
	var stt: Dictionary = cd["stats"]
	var hp: int = int(round(float(stt["hp"]) * float(cd.get("mods", {}).get("max_hp_mult", 1.0))))
	var p: Dictionary = make_actor(1, "leader", 0, "Leader", start, hp, int(stt["atk"]), int(stt["def"]), int(stt["energy"]))
	p["class_id"] = String(class_id)
	p["inv"] = cd["start_kit"].duplicate()
	s.actors[1] = p
	s.player_id = 1
	s.factions[0] = {"id": 0, "name": "You", "is_ai": false, "leader": 1, "home": 1, "alive": true, "hunger_days": 0, "persona": "player"}
	# AI factions
	var personas: Array[String] = []
	for i in range(AI_COUNT):
		personas.append(PERSONAS[i % PERSONAS.size()])
	for i in range(personas.size() - 1, 0, -1):
		var j: int = rng.rand_i(i + 1)
		var tmp: String = personas[i]
		personas[i] = personas[j]
		personas[j] = tmp
	for i in range(ai_sites.size()):
		var fid: int = i + 1
		var home: Dictionary = s.holdings[int(sites[ai_sites[i]]["id"])]
		var la: Dictionary = make_actor(0, "ai_leader", fid, FACTION_NAMES[i] + " Leader", home["hex"], 60, 5, 1, 100)
		la["id"] = s.new_id()
		s.actors[la["id"]] = la
		s.factions[fid] = {"id": fid, "name": FACTION_NAMES[i], "is_ai": true, "leader": la["id"], "home": home["id"], "alive": true, "hunger_days": 0, "persona": personas[i]}
	# Wild enemies
	if bool(opts.get("wild_enemies", true)):
		var comp: Dictionary = WorldGen.flood(s.world, start)
		var cells: Array[Vector2i] = []
		for h in comp.keys():
			if HexGrid.distance(h, start) >= 12 and int(s.world["terrain"][HexGrid.index(h)]) == WorldGen.T_GROUND:
				cells.append(h)
		cells.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return HexGrid.index(a) < HexGrid.index(b))
		var kinds: Array = Content.enemies().keys()
		kinds.sort()
		for k in range(WILD_COUNT):
			if cells.is_empty():
				break
			var hx: Vector2i = cells[rng.rand_i(cells.size())]
			var b: String = WorldGen.biome_at(s.world, hx)
			var fits: Array[String] = []
			for kid in kinds:
				if (Content.enemy(kid)["biomes"] as Array).has(b):
					fits.append(kid)
			var arch: String = fits[rng.rand_i(fits.size())] if not fits.is_empty() else "lfg:enemy/sporeling"
			spawn_enemy(s, arch, hx, false)
	s.rng_state = rng.state
	return s

static func spawn_enemy(s: MatchState, archetype: String, hex: Vector2i, wave: bool) -> int:
	var d: Dictionary = Content.enemy(archetype)
	if d.is_empty():
		return -1
	var e: Dictionary = make_actor(s.new_id(), "enemy", -2, String(d["name"]), hex, int(d["hp"]), 0, int(d["def"]), 0)
	e["archetype"] = archetype
	e["wave"] = wave
	e["ai"] = {"state": "idle", "attack": "", "target_hex": hex, "t_hit": 0.0, "t_end": 0.0, "hit_done": [], "next_move": 0.0}
	s.actors[e["id"]] = e
	return int(e["id"])
