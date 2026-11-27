extends SceneTree
# A corrupt or hand-edited save must never crash the game: it falls back to defaults.
var ok := 0
var bad := 0
func _check(c: bool, msg: String) -> void:
	if c:
		ok += 1
	else:
		bad += 1
		print("FAIL: " + msg)

func _initialize() -> void:
	var S = load("res://session.gd")
	var f := FileAccess.open("user://wellfall.cfg", FileAccess.WRITE)
	f.store_string("[stars]\nmossgate=banana\n[xp]\ntickindle=-5\n[profile]\ngold=\"lots\"\nteam=\",,ghost,,tickindle\"\n[prefs]\nmusic=\"loud\"\ngarbage{{{")
	f.close()
	S.load_save()
	_check(int(S.stars.get("mossgate", 0)) >= 0, "bad star value tolerated")
	_check(S.level_of("tickindle") >= 1, "negative xp still gives level >= 1")
	_check(S.gold >= 0, "non-numeric gold tolerated")
	_check(S.team_ids().size() >= 1, "garbage team falls back to a usable team")
	var ok2 := true
	var v = S.settings.get("music", 0.8)
	_check(typeof(v) == TYPE_FLOAT or typeof(v) == TYPE_INT or typeof(v) == TYPE_STRING, "settings loaded without crashing")
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://wellfall.cfg"))
	print("corrupt: %d/%d ok" % [ok, ok + bad])
	quit(0 if bad == 0 else 1)
