class_name EcoSim
extends RefCounted
## Population-level living ecosystem. One tick = one season. Regions hold demes of species
## (mean genome + genetic spread). Evolution here is real selection on the same genes that drive
## the creature's body, abilities and art: no scripted outcomes.

const RW := 32
const RH := 32
const MASS_BP := [1.0, 0.35, 0.03, 0.006, 0.12, 0.5, 0.4]
const GI := {}  # filled lazily

var seed_: int = 1
var rng := RandomNumberGenerator.new()
var tick: int = 0
# --- world (region grid)
var elev := PackedFloat32Array(); var moist := PackedFloat32Array(); var temp := PackedFloat32Array()
var water := PackedFloat32Array(); var trees := PackedFloat32Array(); var soil := PackedFloat32Array()
var fert := PackedFloat32Array(); var plant := PackedFloat32Array(); var plant_k := PackedFloat32Array()
var season_amp := PackedFloat32Array()
# --- life
var species: Array = []          # Dictionary: id,parent,bp,name,born,extinct,arch
var pops: Array = []             # per region: Array of deme Dictionaries
var events: Array = []           # {tick,type,text,sp,region}
var stats_hist: Array = []
var sapient_events: Array = []
var civs: Array = []
var last_global_split := -99
var stab := PackedFloat32Array()

func idx(x: int, y: int) -> int: return y * RW + x
func in_bounds(x: int, y: int) -> bool: return x >= 0 and y >= 0 and x < RW and y < RH

# ------------------------------------------------------------------ world generation
func generate(seed_in: int, founders: Array = Archetypes.LIST) -> void:
	seed_ = seed_in
	rng.seed = seed_
	var n := RW * RH
	for a in [elev, moist, temp, water, trees, soil, fert, plant, plant_k, season_amp, stab]:
		a.resize(n)
	var ne := FastNoiseLite.new(); ne.seed = seed_; ne.frequency = 0.045; ne.fractal_octaves = 4
	var nm := FastNoiseLite.new(); nm.seed = seed_ + 11; nm.frequency = 0.06; nm.fractal_octaves = 3
	var nt := FastNoiseLite.new(); nt.seed = seed_ + 23; nt.frequency = 0.03
	for y in RH:
		for x in RW:
			var i := idx(x, y)
			var e := ne.get_noise_2d(x, y) * 0.5 + 0.5
			# island-ish falloff keeps oceans at map edges
			var dx := (x - RW * 0.5) / (RW * 0.5); var dy := (y - RH * 0.5) / (RH * 0.5)
			e -= pow(clampf(sqrt(dx * dx + dy * dy), 0.0, 1.4), 2.6) * 0.38
			elev[i] = e
			moist[i] = clampf(nm.get_noise_2d(x, y) * 0.5 + 0.5, 0.0, 1.0)
			temp[i] = clampf(0.62 - (e - 0.4) * 0.5 + nt.get_noise_2d(x, y) * 0.5 + (y - RH * 0.5) / RH * 0.35, 0.0, 1.0)
	for i in n:
		var e := elev[i]
		var w := 0.0
		if e < 0.30: w = 1.0
		elif e < 0.34: w = 0.6 + (0.34 - e) * 10.0 * 0.4   # shallows / marsh
		elif moist[i] > 0.78 and e < 0.45: w = 0.4         # lakes / wet bogs
		water[i] = clampf(w, 0.0, 1.0)
		soil[i] = clampf(0.9 - maxf(e - 0.55, 0.0) * 2.0, 0.1, 1.0) * (0.3 if water[i] > 0.8 else 1.0)
		trees[i] = clampf((moist[i] - 0.35) * 1.6, 0.0, 1.0) * (1.0 - water[i]) * clampf(1.2 - absf(temp[i] - 0.55) * 1.8, 0.0, 1.0)
		fert[i] = clampf(moist[i] * 0.8 + 0.2, 0.0, 1.0) * clampf(1.1 - absf(temp[i] - 0.55) * 1.4, 0.1, 1.0) * (1.0 - water[i] * 0.4)
		plant_k[i] = 900.0 * fert[i] * (0.4 + 0.6 * soil[i]) * (1.0 + trees[i] * 0.5) + (400.0 * water[i] if water[i] > 0.3 else 0.0)  # algae/reeds
		plant[i] = plant_k[i] * 0.6
		season_amp[i] = clampf(absf(temp[i] - 0.5) * 1.2 + 0.1, 0.0, 1.0)
		stab[i] = 1.0
	pops.clear()
	for i in n: pops.append([])
	species.clear(); events.clear(); civs.clear(); sapient_events.clear(); tick = 0
	# seed founders into suitable regions
	for a in founders:
		var sid := _new_species(a["name"], a["bp"], -1, a["id"])
		var tries := 0; var placed := 0
		var want := 3 + rng.randi() % 3
		while placed < want and tries < 400:
			tries += 1
			var r := rng.randi() % n
			if _habitable_for(a["bp"], a["g"], r):
				var g := Archetypes.make_genome(a, rng, 0.03)
				_add_deme(r, sid, 30.0 + rng.randf() * 40.0 if a["bp"] != 3 else 400.0, g)
				placed += 1

func _habitable_for(bp: int, tmpl: Dictionary, r: int) -> bool:
	var w := water[r]
	var aquatic: bool = bp == Genome.BP.FISH
	if aquatic: return w > 0.35
	if w > 0.92: return false
	if bp == Genome.BP.AMPHIB: return w > 0.15 or moist[r] > 0.5
	return true

func _new_species(nm: String, bp: int, parent: int, arch: String) -> int:
	var id := species.size()
	species.append({"id": id, "parent": parent, "bp": bp, "name": nm, "born": tick, "extinct": -1, "arch": arch, "peak": 0.0})
	return id

func _add_deme(r: int, sp: int, n: float, g: PackedFloat32Array, sd: float = 0.05) -> Dictionary:
	var d := {"sp": sp, "n": n, "g": g.duplicate(), "sd": sd, "ratchet": 0.0, "fed": 0.7, "civ": -1, "know": 0.0, "age": 0}
	pops[r].append(d)
	return d

# ------------------------------------------------------------------ trait helpers (hot path)
static func T(g: PackedFloat32Array, name: String) -> float:
	return g[Genome.IDX[name]]

func mass_of(g: PackedFloat32Array, bp: int) -> float:
	return pow(0.3 + T(g, "size") * 1.5, 3.0) * MASS_BP[bp] * (0.8 + T(g, "girth") * 0.8)

func upkeep_of(g: PackedFloat32Array, bp: int, m: float) -> float:
	return 0.35 * pow(m, 0.75) * (0.7 + 0.8 * T(g, "metab")) * (1.0 + 0.9 * Genome.brain_cost(g)) * (1.0 + 0.3 * T(g, "armor")) + 0.002

# ------------------------------------------------------------------ main step
func step() -> void:
	tick += 1
	var season := (tick % 4)
	var sphase := sin(season / 4.0 * TAU)
	var n := RW * RH
	for r in n:
		_step_region(r, sphase)
	_migrate()
	for c in civs: Civ.step(self, c)
	if tick % 3 == 0: Civ.interact(self)
	if tick % 6 == 0:
		_speciate()
	_cull()
	if tick % 4 == 0:
		_record()

func _step_region(r: int, sphase: float) -> void:
	var ds: Array = pops[r]
	# --- plants
	var tmod := clampf(1.0 - absf(temp[r] + sphase * 0.12 * season_amp[r] - 0.58) * 1.8, 0.05, 1.0)
	var B := plant[r]; var K := maxf(plant_k[r], 1.0)
	B += (0.55 * tmod * (0.4 + moist[r])) * B * (1.0 - B / K) + K * 0.012
	if ds.is_empty():
		plant[r] = minf(B, K)
		return
	# --- gather deme stats
	var cnt := ds.size()
	var mass := PackedFloat32Array(); var upk := PackedFloat32Array(); var carn := PackedFloat32Array()
	var bps := PackedInt32Array()
	mass.resize(cnt); upk.resize(cnt); carn.resize(cnt); bps.resize(cnt)
	var herb_demand := 0.0; var prey_total := 0.0; var pred_n := 0.0; var nonpred_n := 0.0
	var pv := 0.0; var ps := 0.0; var pw := 0.0
	for i in cnt:
		var d: Dictionary = ds[i]
		var g: PackedFloat32Array = d["g"]
		var bp: int = species[d["sp"]]["bp"]
		bps[i] = bp
		mass[i] = mass_of(g, bp); upk[i] = upkeep_of(g, bp, mass[i]); carn[i] = T(g, "carniv")
		herb_demand += d["n"] * upk[i] * (1.0 - carn[i])
		if carn[i] < 0.75:
			prey_total += d["n"] * mass[i]
		if carn[i] > 0.45:
			pred_n += d["n"] * carn[i] * (0.5 + T(g, "aggr")) * minf(mass[i] * 8.0 + 0.05, 1.0)
			pv += d["n"] * T(g, "vision"); ps += d["n"] * T(g, "speed"); pw += d["n"]
		else:
			nonpred_n += d["n"]
	var avail := B * 0.7
	var plant_fed := 1.0 if herb_demand <= 0.0 else minf(1.0, avail / herb_demand)
	B -= minf(avail, herb_demand)
	plant[r] = clampf(B, 0.0, K * 1.2)
	var pred_v := pv / maxf(pw, 1.0); var pred_s := ps / maxf(pw, 1.0)
	var pressure := clampf(pred_n / (nonpred_n * 0.25 + 8.0), 0.0, 1.5)
	# --- predation
	var meal := PackedFloat32Array(); meal.resize(cnt); meal.fill(0.0)
	var lost := PackedFloat32Array(); lost.resize(cnt); lost.fill(0.0)   # prey energy lost
	var E := PackedFloat32Array(); E.resize(cnt)
	var Etot := 0.0
	for j in cnt:
		E[j] = ds[j]["n"] * mass[j];
	for i in cnt:
		if carn[i] < 0.12: continue
		var di: Dictionary = ds[i]
		var gi: PackedFloat32Array = di["g"]
		var Di: float = di["n"] * upk[i] * carn[i]
		if Di <= 0.0: continue
		var elig := 0.0
		var wts := PackedFloat32Array(); wts.resize(cnt); wts.fill(0.0)
		for j in cnt:
			if j == i or ds[j]["sp"] == di["sp"]: continue
			if mass[j] > mass[i] * 2.5 or mass[j] < mass[i] * 0.0008: continue
			var gj: PackedFloat32Array = ds[j]["g"]
			var s := 0.45 + 0.9 * (T(gi, "speed") - T(gj, "speed")) + 0.45 * (T(gi, "vision") - T(gj, "camo") * 0.8) - 0.55 * T(gj, "armor") - 0.5 * T(gj, "burrow") * 0.5 + 0.3 * T(gi, "aggr") * 0.5 + 0.25 * T(gi, "c_coop") * T(gi, "social")
			s = clampf(s, 0.02, 0.95)
			# aquatic/terrestrial separation
			var aq_i := T(gi, "aqua"); var aq_j := T(gj, "aqua")
			var overlap := 1.0 - absf(aq_i - aq_j) * 0.8
			if bps[j] == Genome.BP.FISH and bps[i] != Genome.BP.FISH and aq_i < 0.5: overlap *= 0.4
			if bps[i] == Genome.BP.FISH and bps[j] != Genome.BP.FISH: overlap *= 0.6
			var w := E[j] * s * maxf(overlap, 0.05)
			wts[j] = w; elig += w
		if elig <= 0.0: continue
		var take := minf(Di * 1.0, elig * 0.5)      # type-II saturation on available catch
		for j in cnt:
			if wts[j] > 0.0:
				var f := take * wts[j] / elig
				f = minf(f, E[j] * 0.55 - lost[j])
				if f > 0.0:
					lost[j] += f; meal[i] += f * 0.8   # 20% inefficiency
	# --- demography + selection
	var ctx := {"temp": temp[r], "water": water[r], "trees": trees[r], "soil": soil[r], "plant": clampf(B / K, 0.0, 1.0),
		"pressure": pressure, "pred_v": pred_v, "pred_s": pred_s, "amp": season_amp[r], "div": clampf(cnt / 8.0, 0.0, 1.0),
		"prey": clampf(prey_total / 300.0, 0.0, 1.0), "scar": 1.0 - plant_fed}
	var dead := []
	for i in cnt:
		var d: Dictionary = ds[i]
		var g: PackedFloat32Array = d["g"]
		var nn: float = d["n"]
		var cr := carn[i]
		var Dp := nn * upk[i]
		var fed_plant := plant_fed
		var fed_meat := 1.0 if cr <= 0.01 else clampf(meal[i] / maxf(nn * upk[i] * cr, 0.0001), 0.0, 1.0)
		var fed := (1.0 - cr) * fed_plant + cr * fed_meat
		# omnivores buffer: if meat short they eat plants a bit
		if cr > 0.1 and cr < 0.8:
			fed = maxf(fed, plant_fed * 0.55 * (1.0 - cr) + fed_meat * cr)
		d["fed"] = lerpf(d["fed"], fed, 0.5)
		var ls := lerpf(0.6, 1.6, T(g, "lifespan")) * (1.0 + 0.4 * (1.0 - T(g, "metab")))
		# environment stress
		var tt := temp[r] + sphase * 0.12 * season_amp[r]
		var stress := maxf(0.0, tt - 0.5) * (1.0 - T(g, "heat")) + maxf(0.0, 0.5 - tt) * (1.0 - T(g, "cold"))
		var aqs := 0.0
		if bps[i] == Genome.BP.FISH: aqs = 0.0 if water[r] > 0.35 else 1.0
		else: aqs = maxf(0.0, water[r] - 0.7) * (1.0 - T(g, "aqua")) * 1.2 + maxf(0.0, 0.25 - water[r]) * T(g, "aqua") * 0.4
		if bps[i] == Genome.BP.AMPHIB: aqs += maxf(0.0, 0.3 - moist[r]) * 0.8
		var mort := 0.03 / ls + pow(1.0 - d["fed"], 1.5) * 0.5 + stress * 0.25 + aqs * 0.25
		var predl := lost[i] / maxf(mass[i], 0.0001)
		var fert := (0.5 + T(g, "fertility") * 1.5) / (0.5 + pow(mass[i], 0.3))
		var birth := 0.16 * fert * clampf((d["fed"] - 0.55) / 0.45, 0.0, 1.0) * (1.0 - clampf(nn / (plant_k[r] * 4.0 / maxf(upk[i], 0.001) + 1.0), 0.0, 1.0) * 0.0)
		# social species reproduce better near conspecific mass; Allee effect for tiny demes
		if nn < 6.0: birth *= 0.5 + nn / 12.0
		var newn := nn * (1.0 - clampf(mort, 0.0, 0.95)) + nn * birth - predl
		d["n"] = maxf(newn, 0.0)
		d["age"] += 1
		_select(d, ctx, bps[i], r)
		_cognition_step(d, r, bps[i])
		if d["n"] < 0.8: dead.append(d)
	for d in dead:
		ds.erase(d)

# ------------------------------------------------------------------ fitness / selection
func fitness(g: PackedFloat32Array, bp: int, c: Dictionary) -> float:
	var f := 0.0
	var tt: float = c["temp"]
	f -= (maxf(0.0, tt - 0.5) * (1.0 - T(g, "heat")) + maxf(0.0, 0.5 - tt) * (1.0 - T(g, "cold"))) * 1.4
	var w: float = c["water"]
	if bp != Genome.BP.FISH:
		f += (w - 0.35) * (T(g, "aqua") - 0.4) * 0.9
	f -= T(g, "aqua") * 0.08 * (1.0 - w) if bp != Genome.BP.FISH else 0.0
	var cr := T(g, "carniv")
	var size := T(g, "size")
	# foraging
	var plantf: float = c["plant"]
	f += (1.0 - cr) * plantf * (0.45 + 0.3 * T(g, "smell") + 0.15 * T(g, "c_spatial")) * 0.9
	f -= (1.0 - cr) * c["scar"] * size * 0.7
	var hunt := 0.4 * T(g, "speed") + 0.3 * T(g, "vision") + 0.3 * T(g, "aggr") + 0.2 * T(g, "c_coop") * T(g, "social") + 0.25 * T(g, "strength")
	f += cr * c["prey"] * hunt * 1.2
	# predation avoidance
	var pp: float = c["pressure"]
	var def: float = 0.4 * T(g, "speed") * (1.0 - c["pred_s"] * 0.3) + 0.35 * T(g, "camo") * (1.0 - c["pred_v"] * 0.6) + 0.35 * T(g, "armor") + 0.25 * (T(g, "hearing") + T(g, "vision")) * 0.5 + 0.3 * T(g, "burrow") * c["soil"] + 0.3 * T(g, "climb") * c["trees"] + 0.25 * T(g, "social") * (0.5 + T(g, "c_comm")) + 0.25 * T(g, "toxin")
	f += pp * def * 1.1
	# costs (every adaptation is paid for)
	f -= size * size * 0.35 * (0.5 + T(g, "metab"))
	f -= T(g, "armor") * 0.32 + T(g, "toxin") * 0.18 + T(g, "burrow") * 0.1 + T(g, "speed") * 0.14 + T(g, "vision") * 0.06 + T(g, "secrete") * 0.05
	f -= (1.0 - T(g, "lifespan")) * 0.05 + T(g, "lifespan") * T(g, "fertility") * 0.2
	f -= Genome.brain_cost(g) * (0.55 + 0.5 * c["scar"])
	# cognition benefits are niche-dependent (never universally superior)
	var complex: float = 0.35 * c["div"] + 0.35 * c["amp"] + 0.3 * (1.0 - plantf)
	var omni := 1.0 - absf(cr - 0.5) * 2.0
	f += complex * (0.35 * T(g, "c_spatial") + 0.3 * T(g, "c_memory") + 0.2 * T(g, "c_curio") + 0.2 * T(g, "c_learn") * 0.8) * 1.1
	f += T(g, "social") * (0.3 * T(g, "c_comm") * T(g, "c_coop")) * (0.3 + pp) * 1.2
	f += omni * T(g, "c_manip") * T(g, "limb") * complex * 0.9
	f += T(g, "c_plan") * c["amp"] * 0.35
	return f

func _select(d: Dictionary, ctx: Dictionary, bp: int, r: int) -> void:
	var g: PackedFloat32Array = d["g"]
	var sd: float = d["sd"]
	var K := 4
	var vs: Array = []; var fs := PackedFloat32Array()
	for k in K:
		var v := g.duplicate()
		for i in Genome.N:
			v[i] = clampf(g[i] + rng.randfn(0.0, sd), 0.0, 1.0)
		Genome.constrain(v, bp)
		vs.append(v); fs.append(fitness(v, bp, ctx))
	var mean_f := 0.0
	for f in fs: mean_f += f
	mean_f /= K
	var var_f := 0.0
	for f in fs: var_f += (f - mean_f) * (f - mean_f)
	var sf := sqrt(var_f / K) + 0.02
	var lr := 0.9
	for i in Genome.N:
		var step_ := 0.0
		for k in K:
			step_ += (fs[k] - mean_f) / sf * (vs[k][i] - g[i])
		g[i] = clampf(g[i] + lr * step_ / K * 0.5, 0.0, 1.0)
	# drift: small demes wander
	var nn: float = d["n"]
	var drift := sd * 0.9 / sqrt(maxf(nn, 2.0))
	for i in Genome.N:
		g[i] = clampf(g[i] + rng.randfn(0.0, drift), 0.0, 1.0)
	Genome.constrain(g, bp)
	d["g"] = g
	d["sd"] = clampf(sd * 0.992 + 0.0007 + (0.0006 if nn > 50.0 else 0.0), 0.02, 0.075)

# ------------------------------------------------------------------ intelligence
func cog_index(g: PackedFloat32Array) -> float:
	# multidimensional capability gate: weakest critical dimensions matter, not the mean
	var comm := T(g, "c_comm"); var coop := T(g, "c_coop"); var manip := T(g, "c_manip")
	var learn := T(g, "c_learn"); var mem := T(g, "c_memory"); var plan := T(g, "c_plan")
	return pow(maxf(comm, 0.01) * maxf(coop, 0.01) * maxf(learn, 0.01) * maxf(mem, 0.01), 0.25) * (0.5 + 0.5 * manip) * (0.7 + 0.3 * plan)

func _cognition_step(d: Dictionary, r: int, bp: int) -> void:
	var g: PackedFloat32Array = d["g"]
	var ci := cog_index(g)
	var nn: float = d["n"]
	var ok: bool = ci > 0.3 and nn > 25.0 and d["fed"] > 0.75 and T(g, "social") > 0.35
	if ok:
		d["ratchet"] += ci * ci * 3.5
	else:
		d["ratchet"] = maxf(d["ratchet"] - 1.5, 0.0)
	if d["civ"] < 0 and d["ratchet"] > 50.0 and ci > 0.38 and nn > 40.0 and (T(g, "c_manip") > 0.3 or T(g, "secrete") > 0.5 or T(g, "burrow") > 0.5):
		d["civ"] = sapient_events.size()
		var ev := {"tick": tick, "region": r, "sp": d["sp"], "ci": ci, "n": nn}
		Civ.found(self, d, r)
		sapient_events.append(ev)
		events.append({"tick": tick, "type": "dawn", "text": "%s awaken to shared culture" % species[d["sp"]]["name"], "sp": d["sp"], "region": r})

# ------------------------------------------------------------------ migration / speciation
func _migrate() -> void:
	var moves: Array = []
	for r in RW * RH:
		var ds: Array = pops[r]
		for d in ds:
			var g: PackedFloat32Array = d["g"]
			var bp: int = species[d["sp"]]["bp"]
			var mob := 0.02 + 0.07 * T(g, "speed") + (0.06 if bp == Genome.BP.AVIAN else 0.0) + (0.03 if d["fed"] < 0.6 else 0.0)
			var x := r % RW; var y := r / RW
			var best := -1; var bests := -1.0
			for k in 4:
				var nx: int = x + [1, -1, 0, 0][k]; var ny: int = y + [0, 0, 1, -1][k]
				if not in_bounds(nx, ny): continue
				var nr := idx(nx, ny)
				if not _habitable_for(bp, {}, nr): continue
				if bp != Genome.BP.FISH and T(g, "aqua") < 0.5 and bp != Genome.BP.AVIAN and water[nr] > 0.8: continue
				var sc := plant[nr] / maxf(plant_k[nr], 1.0) + rng.randf() * 0.4
				if sc > bests: bests = sc; best = nr
			if best >= 0 and rng.randf() < mob and d["n"] > 3.0:
				moves.append([r, d, best, d["n"] * mob * 0.6])
	for m in moves:
		var r: int = m[0]; var d: Dictionary = m[1]; var tgt: int = m[2]; var amt: float = m[3]
		if not pops[r].has(d): continue
		d["n"] -= amt
		var found := false
		for e in pops[tgt]:
			if e["sp"] == d["sp"]:
				var tot: float = e["n"] + amt
				var eg: PackedFloat32Array = e["g"]
				var dg: PackedFloat32Array = d["g"]
				for i in Genome.N:
					eg[i] = (eg[i] * e["n"] + dg[i] * amt) / tot   # gene flow
				e["n"] = tot; e["sd"] = maxf(e["sd"], d["sd"] * 0.9)
				found = true
				break
		if not found:
			var nd := _add_deme(tgt, d["sp"], amt, d["g"], d["sd"])
			nd["fed"] = d["fed"]

func _speciate() -> void:
	# gather demes per species
	var by_sp := {}
	for r in RW * RH:
		for d in pops[r]:
			if not by_sp.has(d["sp"]): by_sp[d["sp"]] = []
			by_sp[d["sp"]].append([r, d])
	for sp in by_sp:
		var list: Array = by_sp[sp]
		if list.size() < 2: continue
		# union-find over adjacency + genetic compatibility
		var parent := {}
		for i in list.size(): parent[i] = i
		var find := func(x: int) -> int:
			while parent[x] != x:
				parent[x] = parent[parent[x]]
				x = parent[x]
			return x
		for i in list.size():
			for j in range(i + 1, list.size()):
				var ri: int = list[i][0]; var rj: int = list[j][0]
				var dx := absi(ri % RW - rj % RW); var dy := absi(ri / RW - rj / RW)
				if dx <= 1 and dy <= 1:
					if Genome.distance(list[i][1]["g"], list[j][1]["g"]) < 0.13:
						var a: int = find.call(i); var b: int = find.call(j)
						if a != b: parent[a] = b
		var comps := {}
		for i in list.size():
			var c: int = find.call(i)
			if not comps.has(c): comps[c] = []
			comps[c].append(list[i])
		if comps.size() < 2: continue
		var arr: Array = comps.values()
		arr.sort_custom(func(a, b): return _comp_n(a) > _comp_n(b))
		var main: Array = arr[0]
		var main_mean := _comp_mean(main)
		for ci in range(1, arr.size()):
			var comp: Array = arr[ci]
			if _comp_n(comp) < 40.0 or tick - last_global_split < 10: continue
			if tick - int(species[sp].get('last_split', -999)) < 160: continue
			if Genome.distance(main_mean, _comp_mean(comp)) < 0.2: continue
			species[sp]['last_split'] = tick; last_global_split = tick
			var bp: int = species[sp]["bp"]
			var nm := _species_name(species[sp]["name"], _comp_mean(comp), main_mean, bp)
			var nsp := _new_species(nm, bp, sp, species[sp]["arch"])
			for e in comp:
				e[1]["sp"] = nsp
			events.append({"tick": tick, "type": "speciation", "text": "%s diverges from %s" % [nm, species[sp]["name"]], "sp": nsp, "region": comp[0][0]})

func _comp_n(c: Array) -> float:
	var s := 0.0
	for e in c: s += e[1]["n"]
	return s

func _comp_mean(c: Array) -> PackedFloat32Array:
	var m := Genome.blank(); m.fill(0.0)
	var tot := 0.0
	for e in c:
		var g: PackedFloat32Array = e[1]["g"]; var w: float = e[1]["n"]
		for i in Genome.N: m[i] += g[i] * w
		tot += w
	for i in Genome.N: m[i] /= maxf(tot, 0.0001)
	return m

func _species_name(base: String, g: PackedFloat32Array, ref: PackedFloat32Array, bp: int) -> String:
	# name from the trait that diverged most (names stay tied to real differences)
	var best := ""; var bd := 0.0
	var tags := {"size": ["Greater", "Lesser"], "speed": ["Swift", "Slow"], "burrow": ["Delving", "Surface"], "aqua": ["Marsh", "Upland"], "climb": ["Canopy", "Ground"],
		"armor": ["Plated", "Soft"], "camo": ["Veiled", "Bright"], "carniv": ["Hunting", "Grazing"], "heat": ["Sunward", "Shade"], "cold": ["Frost", "Thaw"], "vision": ["Keen", "Dim"], "toxin": ["Venom", "Mild"]}
	for k in tags:
		var d := T(g, k) - T(ref, k)
		if absf(d) > bd: bd = absf(d); best = tags[k][0] if d > 0 else tags[k][1]
	var root := base
	for pre in ["Greater ", "Lesser ", "Swift ", "Slow ", "Delving ", "Surface ", "Marsh ", "Upland ", "Canopy ", "Ground ", "Plated ", "Soft ", "Veiled ", "Bright ", "Hunting ", "Grazing ", "Sunward ", "Shade ", "Frost ", "Thaw ", "Keen ", "Dim ", "Venom ", "Mild "]:
		if root.begins_with(pre): root = root.substr(pre.length())
	return "%s %s" % [best if best != "" else "Variant", root]

func _cull() -> void:
	var alive := {}
	for r in RW * RH:
		for d in pops[r]:
			alive[d["sp"]] = true
	for s in species:
		if s["extinct"] < 0 and not alive.has(s["id"]) and s["born"] < tick:
			s["extinct"] = tick
			events.append({"tick": tick, "type": "extinction", "text": "%s are extinct" % s["name"], "sp": s["id"], "region": -1})

# ------------------------------------------------------------------ analytics
func totals() -> Dictionary:
	var tot := {}
	for r in RW * RH:
		for d in pops[r]:
			tot[d["sp"]] = tot.get(d["sp"], 0.0) + d["n"]
	return tot

func _record() -> void:
	var tot := totals()
	var maxci := 0.0
	var ratch := 0.0
	for r in RW * RH:
		for d in pops[r]:
			var ci := cog_index(d["g"])
			if ci > maxci: maxci = ci
			if d["ratchet"] > ratch: ratch = d["ratchet"]
	stats_hist.append({"tick": tick, "species": tot.size(), "total": tot.values().reduce(func(a, b): return a + b, 0.0), "max_ci": maxci, "max_ratchet": ratch, "sapient": sapient_events.size(), "ever": species.size()})
