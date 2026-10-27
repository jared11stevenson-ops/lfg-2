class_name HudBinder
extends RefCounted
## MatchState (Rules) -> HUD model. Read-only; never mutates state.
static func model_from_state(state: Object, actor_id: int = -1) -> Dictionary:
	var clock: Dictionary = state.get("clock") if state.get("clock") is Dictionary else {}
	var pid: int = int(state.get("player_id")) if actor_id < 0 else actor_id
	var m: Dictionary = {
		"day": int(clock.get("day", 1)),
		"time_of_day": float(clock.get("time_of_day", 0.0)),
		"phase": StringName(str(state.get("phase"))),
		"rations": 0, "rations_per_day": 1, "class_label": "", "hp": 1.0, "hp_max": 1.0, "inventory": [],
	}
	var actors: Variant = state.get("actors")
	if not (actors is Dictionary) or not (actors as Dictionary).has(pid):
		return m
	var a: Dictionary = actors[pid]
	var cd: Dictionary = Content.class_def(String(a.get("class_id", "")))
	var nm: String = String(a.get("name", ""))
	var cname: String = String(cd.get("id", "")).get_slice("/", 1).capitalize()
	m["class_label"] = ("%s - %s" % [cname, String(cd.get("name", ""))]) if not cd.is_empty() else nm
	m["hp"] = float(a.get("hp", 1))
	m["hp_max"] = float(a.get("max_hp", 1))
	var fid: int = int(a.get("faction", 0))
	m["rations"] = Economy.rations_available(state as MatchState, fid)
	m["rations_per_day"] = maxi(Economy.persons(state as MatchState, fid), 1)
	var items: Array = []
	var inv: Dictionary = a.get("inv", {})
	var keys: Array = inv.keys()
	keys.sort()
	for k in keys:
		var it: Dictionary = Content.item(String(k))
		var nm2: String = String(it.get("name", String(k).get_slice("/", 1).capitalize()))
		items.append({"id": k, "name": nm2, "count": int(inv[k]), "color": Color.from_hsv(float(absi(hash(String(k))) % 360) / 360.0, 0.65, 1.0)})
	m["inventory"] = items
	var trk: Dictionary = Quests.tracker(state as MatchState, a)
	m["quest_tracker"] = "%s\n%s" % [String(trk["title"]), String(trk["text"])] if not trk.is_empty() else ""
	return m
