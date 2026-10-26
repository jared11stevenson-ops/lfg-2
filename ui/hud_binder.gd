class_name HudBinder
extends RefCounted
## Duck-typed MatchState -> HUD model. Tolerant of fields not existing yet (Stream A is concurrent);
## anything missing falls back to a neutral default instead of erroring.
static func _get(o: Variant, key: String, default: Variant) -> Variant:
	if o is Dictionary:
		return (o as Dictionary).get(key, default)
	if o is Object:
		var v: Variant = (o as Object).get(key)
		return default if v == null else v
	return default

static func model_from_state(state: Object, actor_id: int = 0) -> Dictionary:
	var clock: Variant = _get(state, "clock", {})
	var m: Dictionary = {
		"day": int(_get(clock, "day", 1)),
		"time_of_day": float(_get(clock, "time_of_day", 0.0)),
		"phase": StringName(str(_get(state, "phase", &"PEACE"))),
		"rations": 0, "rations_per_day": 1, "class_label": "", "hp": 1.0, "hp_max": 1.0, "inventory": [], "prompt": "",
	}
	var actors: Variant = _get(state, "actors", null)
	var a: Variant = null
	if actors is Dictionary:
		a = (actors as Dictionary).get(actor_id, (actors as Dictionary).get(str(actor_id), null))
	elif actors is Array and actor_id < (actors as Array).size():
		a = (actors as Array)[actor_id]
	if a != null:
		m["class_label"] = str(_get(a, "class_label", _get(a, "class_id", "")))
		m["hp"] = float(_get(a, "hp", 1.0))
		m["hp_max"] = float(_get(a, "hp_max", _get(a, "max_hp", 1.0)))
		var inv: Variant = _get(a, "inventory", {})
		var rations: int = 0
		var items: Array = []
		if inv is Dictionary:
			for k in inv:
				var cnt: int = int(inv[k])
				if str(k).ends_with("ration"):
					rations += cnt
				items.append({"id": k, "name": str(k).get_slice("/", 1) if str(k).contains("/") else str(k), "count": cnt, "color": Color.from_hsv(fmod(float(hash(k) & 0xff) / 255.0, 1.0), 0.7, 1.0)})
		m["inventory"] = items
		m["rations"] = rations
	return m
