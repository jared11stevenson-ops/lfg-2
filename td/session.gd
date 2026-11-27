extends RefCounted
# Cross-scene state and save data (user://wellfall.cfg): run config, stars, unlocked allies.
const Levels = preload("res://levels.gd")
const Rules = preload("res://rules.gd")
static var level_id := "mossgate"
static var diff := "normal"
static var muts: Array = []
static var run_seed := 0
static var daily := false
static var stars := {}          # level -> 0..3
static var best_wave := {}      # level -> best wave reached
static var unlocked := {}       # ally tower id -> true
static var xp := {}             # tower id -> banked XP (levels creatures up across runs)
const MAX_LEVEL := 20
static var dev_all := false     # testing: unlock everything
static var _loaded := false
static var settings := {"music": 0.8, "sfx": 0.9, "haptics": true, "shake": true, "tutorial_done": false}
static var no_save := false     # set by headless tests

static func load_save() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load("user://wellfall.cfg") == OK:
		for k in cf.get_section_keys("stars"):
			stars[k] = int(cf.get_value("stars", k, 0))
		for k in cf.get_section_keys("best"):
			best_wave[k] = int(cf.get_value("best", k, 0))
		for k in cf.get_section_keys("unlocked"):
			unlocked[k] = true
		for k in cf.get_section_keys("xp"):
			xp[k] = int(cf.get_value("xp", k, 0))
		dev_all = bool(cf.get_value("settings", "dev_all", false))
		for k in settings:
			settings[k] = cf.get_value("prefs", k, settings[k])

static func _save() -> void:
	if no_save:
		return
	var cf := ConfigFile.new()
	for k in stars:
		cf.set_value("stars", k, stars[k])
	for k in best_wave:
		cf.set_value("best", k, best_wave[k])
	for k in unlocked:
		cf.set_value("unlocked", k, true)
	for k in xp:
		cf.set_value("xp", k, xp[k])
	cf.set_value("settings", "dev_all", dev_all)
	for k in settings:
		cf.set_value("prefs", k, settings[k])
	cf.save("user://wellfall.cfg")

static func save_prefs() -> void:
	_save()

static func set_dev_all(v: bool) -> void:
	dev_all = v
	_save()

static func level_open(id: String) -> bool:
	load_save()
	if dev_all:
		return true
	var i := Levels.ORDER.find(id)
	return i <= 0 or int(stars.get(Levels.ORDER[i - 1], 0)) >= 1

static func tower_open(def: Dictionary) -> bool:
	load_save()
	return dev_all or not def.has("unlock") or unlocked.has(def.id)

static func ally_for(level: String, three_star: bool) -> Array:
	var out := []
	var Creatures = load("res://creatures.gd")
	for k in Creatures.TOWERS:
		var u := String(Creatures.TOWERS[k].get("unlock", ""))
		if u == level or (three_star and u == level + "2"):
			out.append(k)
	return out

# Score stars for a win: 1 clear, +1 if >=50% lives left, +1 if hard+ or 2+ mutators. Returns the newly unlocked ally ids.
static func record_win(level: String, wave: int, lives_left: int, lives_start: int, endless: bool) -> Dictionary:
	load_save()
	var s := 1
	if lives_left * 2 >= lives_start:
		s += 1
	if diff in ["hard", "nightmare"] or muts.size() >= 2:
		s += 1
	var new_allies: Array = []
	if not no_save and not daily:
		for a in ally_for(level, s >= 3):
			if not unlocked.has(a):
				unlocked[a] = true
				new_allies.append(a)
		stars[level] = maxi(int(stars.get(level, 0)), s)
		best_wave[level] = maxi(int(best_wave.get(level, 0)), wave)
		_save()
	return {"stars": s, "allies": new_allies}

static func record_loss(level: String, wave: int) -> void:
	load_save()
	if not no_save and wave > int(best_wave.get(level, 0)):
		best_wave[level] = wave
		_save()

# ---- creature levels (Pokemon-style): XP is banked per species and permanently boosts its stats ----
static func level_of(id: String) -> int:
	return clampi(1 + int(sqrt(float(xp.get(id, 0)) / 30.0)), 1, MAX_LEVEL)

static func xp_for_level(l: int) -> int:
	return 30 * (l - 1) * (l - 1)

static func level_mult(id: String) -> float:
	return 1.0 + 0.06 * float(level_of(id) - 1)

# Adds XP, returns [old_level, new_level].
static func add_xp(id: String, amount: int) -> Array:
	load_save()
	var before := level_of(id)
	xp[id] = int(xp.get(id, 0)) + amount
	_save()
	return [before, level_of(id)]

# Tower id a captured wild species becomes (starters keep their id, others are "ally_<species>").
static func tower_for(species: String) -> String:
	var C = load("res://creatures.gd")
	if C.TOWERS.has("ally_" + species):
		return "ally_" + species
	return species if C.TOWERS.has(species) else ""

# Returns true if this is a brand-new creature for the collection.
static func capture(species: String) -> bool:
	load_save()
	var id := tower_for(species)
	if id == "" or unlocked.has(id):
		return false
	unlocked[id] = true
	_save()
	return true

static func score_mult() -> float:
	return float(Rules.combine(diff, muts).score)

# Call once per scene: makes the custom cartoon font the default for draw_string() too.
static func init_ui() -> void:
	var f = load("res://art/fonts/LilitaOne-Regular.ttf")
	if f != null:
		ThemeDB.fallback_font = f
