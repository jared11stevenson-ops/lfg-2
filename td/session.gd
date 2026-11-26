extends RefCounted
# Cross-scene state and save data (user://wellfall.cfg).
static var map_id := "mossgate"
static var best := {}
static var unlocked := {}   # ally tower id -> true
static var _loaded := false
static var no_save := false   # set by headless tests

static func load_save() -> void:
	if _loaded:
		return
	_loaded = true
	var cf := ConfigFile.new()
	if cf.load("user://wellfall.cfg") == OK:
		for k in cf.get_section_keys("best"):
			best[k] = int(cf.get_value("best", k, 0))
		for k in cf.get_section_keys("unlocked"):
			unlocked[k] = true

static func is_unlocked(def: Dictionary) -> bool:
	load_save()
	return not def.has("unlock") or unlocked.has(def.id)

static func record(map: String, wave: int, won: bool, unlock_id: String = "") -> void:
	load_save()
	if no_save:
		return
	if unlock_id != "":
		unlocked[unlock_id] = true
	_save()
	var score := wave + (100 if won else 0)
	if score > int(best.get(map, 0)):
		best[map] = score
		_save()

static func _save() -> void:
	var cf := ConfigFile.new()
	for k in best:
		cf.set_value("best", k, best[k])
	for k in unlocked:
		cf.set_value("unlocked", k, true)
	cf.save("user://wellfall.cfg")

static func best_text(map: String, total: int) -> String:
	load_save()
	var b := int(best.get(map, 0))
	if b >= 100:
		return "Cleared!"
	return "Best: wave %d/%d" % [b, total] if b > 0 else "Not played"
