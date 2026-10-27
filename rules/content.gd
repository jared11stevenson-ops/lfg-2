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

static func item(id: String) -> Dictionary: return items().get(id, {})
static func crop(id: String) -> Dictionary: return crops().get(id, {})
static func recipe(id: String) -> Dictionary: return recipes().get(id, {})
static func building(id: String) -> Dictionary: return buildings().get(id, {})
static func class_def(id: String) -> Dictionary: return classes().get(id, {})
static func enemy(id: String) -> Dictionary: return enemies().get(id, {})
static func item_value(id: String) -> int: return int(item(id).get("value", 0))
static func biome_index(name: String) -> int: return BIOMES.find(name)
