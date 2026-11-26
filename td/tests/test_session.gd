extends SceneTree
# Star scoring, ally unlocks and level gating (writes then deletes a real user://wellfall.cfg).
const Session = preload("res://session.gd")
var fails := 0
var n := 0

func _check(c: bool, msg: String) -> void:
	n += 1
	if not c:
		fails += 1
		print("FAIL ", msg)

func _init() -> void:
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://wellfall.cfg"))
	Session.no_save = false
	Session._loaded = true
	Session.stars = {}
	Session.unlocked = {}
	Session.dev_all = false
	Session.diff = "normal"
	Session.muts = []
	Session.daily = false
	_check(Session.level_open("mossgate"), "level 1 open")
	_check(not Session.level_open("frostrun"), "level 2 locked at start")
	var r := Session.record_win("mossgate", 10, 12, 20, false)
	_check(r.stars == 2, "2 stars with >=50% lives on Normal")
	_check("ally_shuckit" in r.allies, "clearing mossgate befriends Shuckit")
	_check(Session.level_open("frostrun"), "level 2 opens after clearing level 1")
	var r3 := Session.record_win("frostrun", 10, 18, 20, false)
	_check(r3.stars == 2 and "ally_glomm" in r3.allies and not "ally_ptarmitten" in r3.allies, "frostrun 2 stars: Glomm only")
	Session.diff = "hard"
	var r4 := Session.record_win("frostrun", 10, 18, 20, false)
	_check(r4.stars == 3 and "ally_ptarmitten" in r4.allies, "3 stars on Hard befriends bonus Ptarmitten")
	Session.diff = "normal"
	Session.muts = ["swift", "tough"]
	var r5 := Session.record_win("emberflats", 10, 3, 20, false)
	_check(r5.stars == 2, "2+ mutators adds a star even with few lives")
	_check(int(Session.stars["frostrun"]) == 3, "best stars kept")
	var Creatures = load("res://creatures.gd")
	_check(Session.tower_open(Creatures.TOWERS.ally_shuckit), "unlocked ally available in shop")
	_check(not Session.tower_open(Creatures.TOWERS.ally_gilamancer), "locked ally unavailable")
	_check(Session.tower_open(Creatures.TOWERS.tickindle), "starters always available")
	Session.dev_all = true
	_check(Session.tower_open(Creatures.TOWERS.ally_gilamancer), "dev_all unlocks everything")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://wellfall.cfg"))
	print("session: ", n - fails, "/", n, " ok")
	quit(1 if fails > 0 else 0)
