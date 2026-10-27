class_name Content
extends RefCounted
## Loads data/*.json once. All ids namespaced `lfg:<kind>/<name>`.

const BIOMES: Array[String] = ["meadow", "shore", "fungal_grove", "ruins", "salt_flats", "highlands", "bog"]
const BIOME_COST: Array[float] = [1.0, 1.2, 1.3, 1.1, 1.1, 1.8, 2.0]
static var _cache: Dictionary = {}

static func _load(file: String, key: String) -> Dictionary:
	if _cache.has(key):
		return _cache[key]
	var out: Dictionary = {}
	var f := FileAccess.open("res://data/%s.json" % file, FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			var arr: Array = parsed.get(key, [])
			for e in arr:
				out[String(e["id"])] = e
	_cache[key] = out
	return out

static func items() -> Dictionary: return _load("items", "items")
static func crops() -> Dictionary: return _load("crops", "crops")
static func recipes() -> Dictionary: return _load("recipes", "recipes")
static func buildings() -> Dictionary: return _load("buildings", "buildings")
static func classes() -> Dictionary: return _load("classes", "classes")
static func enemies() -> Dictionary: return _load("enemies", "enemies")

## data/ranks.json (Standing, ranks, upkeep, levy, scarcity). Not an id-keyed list, so cached whole.
static func ranks_cfg() -> Dictionary:
	if _cache.has("ranks_cfg"):
		return _cache["ranks_cfg"]
	var out: Dictionary = {}
	var f := FileAccess.open("res://data/ranks.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			out = parsed
	_cache["ranks_cfg"] = out
	return out

## data/skill_trees.json: {caps:{key:[min,max]}, trees:{class_id:{name, nodes:{id:node}, order:[ids]}}}
static func skill_data() -> Dictionary:
	if _cache.has("skill_data"):
		return _cache["skill_data"]
	var out: Dictionary = {"caps": {}, "trees": {}}
	var f := FileAccess.open("res://data/skill_trees.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			out["caps"] = parsed.get("caps", {})
			for t in parsed.get("trees", []):
				var nodes: Dictionary = {}
				var order: Array = []
				for n in t["nodes"]:
					nodes[String(n["id"])] = n
					order.append(String(n["id"]))
				out["trees"][String(t["class"])] = {"name": t.get("name", ""), "nodes": nodes, "order": order}
	_cache["skill_data"] = out
	return out

## data/ai_kits.json: how AI leaders use their class (rules/ai_leaders.gd).
static func ai_kit(class_id: String) -> Dictionary:
	if not _cache.has("ai_kits"):
		var out: Dictionary = {}
		var f := FileAccess.open("res://data/ai_kits.json", FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				out = parsed.get("classes", {})
		_cache["ai_kits"] = out
	return _cache["ai_kits"].get(class_id, {})

## data/pois.json: {discover_radius, min_gap, holding_gap, types:[...]}. poi_types() is id-keyed (file order kept in poi_type_order()).
static func poi_cfg() -> Dictionary:
	if _cache.has("poi_cfg"):
		return _cache["poi_cfg"]
	var out: Dictionary = {"types": []}
	var f := FileAccess.open("res://data/pois.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			out = parsed
	# Pass 4: the region guardians' arenas are POI types appended AFTER the regular seven (worldgen places types in file order from one
	# RNG stream, so every pre-pass-4 placement is unchanged).
	var types: Array = (out.get("types", []) as Array).duplicate()
	types.append_array(guardian_cfg().get("arenas", []))
	out["types"] = types
	_cache["poi_cfg"] = out
	return out

static func poi_types() -> Dictionary:
	if not _cache.has("poi_types"):
		var d: Dictionary = {}
		for t in poi_cfg().get("types", []):
			d[String(t["id"])] = t
		_cache["poi_types"] = d
	return _cache["poi_types"]

static func poi_type_order() -> Array:
	var out: Array = []
	for t in poi_cfg().get("types", []):
		out.append(String(t["id"]))
	return out

## data/quests/index.json lists the quest files ({"files": ["judd.json", ...]}); each file is {"quests": [...]}. Quest order = file order.
static func quests() -> Dictionary:
	if not _cache.has("quests"):
		var d: Dictionary = {}
		var order: Array = []
		var idx := FileAccess.open("res://data/quests/index.json", FileAccess.READ)
		if idx != null:
			var ip: Variant = JSON.parse_string(idx.get_as_text())
			if ip is Dictionary:
				for fn in ip.get("files", []):
					var f := FileAccess.open("res://data/quests/%s" % String(fn), FileAccess.READ)
					if f == null:
						continue
					var parsed: Variant = JSON.parse_string(f.get_as_text())
					if parsed is Dictionary:
						for q in parsed.get("quests", []):
							d[String(q["id"])] = q
							order.append(String(q["id"]))
		_cache["quests"] = d
		_cache["quest_order"] = order
	return _cache["quests"]

static func quest_order() -> Array:
	quests()
	return _cache.get("quest_order", [])

static func quest(id: String) -> Dictionary: return quests().get(id, {})

## data/guardians.json: {enemies:[boss archetypes], arenas:[POI types]}. Boss archetypes are NOT in enemies() (they never join the wild/wave pool);
## Content.enemy() finds both.
static func guardian_cfg() -> Dictionary:
	if _cache.has("guardian_cfg"):
		return _cache["guardian_cfg"]
	var out: Dictionary = {"enemies": [], "arenas": []}
	var f := FileAccess.open("res://data/guardians.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			out = parsed
	_cache["guardian_cfg"] = out
	return out

static func guardians() -> Dictionary:
	if not _cache.has("guardians"):
		var d: Dictionary = {}
		for e in guardian_cfg().get("enemies", []):
			d[String(e["id"])] = e
		_cache["guardians"] = d
	return _cache["guardians"]

## Guardian ids in file order (meadow, shore, grove, ruins, salt flats, highlands, bog).
static func guardian_order() -> Array:
	var out: Array = []
	for e in guardian_cfg().get("enemies", []):
		out.append(String(e["id"]))
	return out

## data/companions.json: {config, companions[]}. companions() is id-keyed; companion_order() keeps file order.
static func companion_cfg() -> Dictionary:
	if _cache.has("companion_cfg"):
		return _cache["companion_cfg"]
	var out: Dictionary = {"config": {}, "companions": []}
	var f := FileAccess.open("res://data/companions.json", FileAccess.READ)
	if f != null:
		var parsed: Variant = JSON.parse_string(f.get_as_text())
		if parsed is Dictionary:
			out = parsed
	_cache["companion_cfg"] = out
	return out

static func companions() -> Dictionary:
	if not _cache.has("companions"):
		var d: Dictionary = {}
		for c in companion_cfg().get("companions", []):
			d[String(c["id"])] = c
		_cache["companions"] = d
	return _cache["companions"]

static func companion_order() -> Array:
	var out: Array = []
	for c in companion_cfg().get("companions", []):
		out.append(String(c["id"]))
	return out

static func companion(id: String) -> Dictionary: return companions().get(id, {})
static func companion_conf(key: String, default: Variant = 0) -> Variant: return companion_cfg().get("config", {}).get(key, default)

static func item(id: String) -> Dictionary: return items().get(id, {})
static func crop(id: String) -> Dictionary: return crops().get(id, {})
static func recipe(id: String) -> Dictionary: return recipes().get(id, {})
static func building(id: String) -> Dictionary: return buildings().get(id, {})
static func class_def(id: String) -> Dictionary: return classes().get(id, {})
static func enemy(id: String) -> Dictionary:
	var e: Dictionary = enemies().get(id, {})
	return e if not e.is_empty() else guardians().get(id, {})
static func item_value(id: String) -> int: return int(item(id).get("value", 0))
static func biome_index(name: String) -> int: return BIOMES.find(name)
