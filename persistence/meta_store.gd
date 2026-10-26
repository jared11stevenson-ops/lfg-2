class_name MetaStore
extends RefCounted
## Match-independent cosmetic meta-progression (user://meta.json): codex entries, titles, alt-start
## unlocks, cosmetics. Strict allowlist: only namespaced string ids in four known lists. No numbers,
## no stats, no inventory => nothing here can carry power into a match. Alt starts are only *ids*;
## the rules module is responsible for giving them the same power budget (see DESIGN.md).
const VERSION := 1
const KINDS: Array[String] = ["codex", "titles", "alt_starts", "cosmetics"]
const MAX_PER_KIND := 500
static var id_re: RegEx = null

var data: Dictionary = {}
var path: String = ""

static func _valid_id(kind: String, id: Variant) -> bool:
	if not (id is String) or (id as String).length() > 64:
		return false
	if id_re == null:
		id_re = RegEx.create_from_string("^lfg:(codex|title|altstart|cosmetic)/[a-z0-9_]+$")
	var prefix := {"codex": "lfg:codex/", "titles": "lfg:title/", "alt_starts": "lfg:altstart/", "cosmetics": "lfg:cosmetic/"}
	return id_re.search(id) != null and (id as String).begins_with(prefix[kind])

static func empty() -> Dictionary:
	return {"version": VERSION, "codex": [], "titles": [], "alt_starts": [], "cosmetics": [], "equipped_title": ""}

## Strips everything not on the allowlist. Never trusts file contents.
static func sanitize(raw: Variant) -> Dictionary:
	var out: Dictionary = empty()
	if not (raw is Dictionary):
		return out
	for k in KINDS:
		var seen := {}
		var lst: Variant = (raw as Dictionary).get(k, [])
		if lst is Array:
			for id in lst:
				if _valid_id(k, id) and not seen.has(id) and seen.size() < MAX_PER_KIND:
					seen[id] = true
					(out[k] as Array).append(id)
	var t: Variant = (raw as Dictionary).get("equipped_title", "")
	if t is String and (out["titles"] as Array).has(t):
		out["equipped_title"] = t
	return out

static func load_from(p: String = "") -> MetaStore:
	var m := MetaStore.new()
	m.path = p if p != "" else Persist.root.path_join("meta.json")
	m.data = empty()
	for c in SafeFile.read_candidates(m.path):
		if c["ok"]:
			var j := JSON.new()
			if j.parse(c["payload"]) == OK:
				m.data = sanitize(j.data)
				return m
	return m

func save() -> Dictionary:
	data = sanitize(data)
	return SafeFile.write(path, JSON.stringify(data))

func unlock(kind: String, id: String) -> bool:
	if not KINDS.has(kind) or not _valid_id(kind, id):
		return false
	var lst: Array = data[kind]
	if lst.has(id):
		return false
	if lst.size() >= MAX_PER_KIND:
		return false
	lst.append(id)
	return true

func has(kind: String, id: String) -> bool:
	return KINDS.has(kind) and (data[kind] as Array).has(id)

func equip_title(id: String) -> bool:
	if id != "" and not has("titles", id):
		return false
	data["equipped_title"] = id
	return true

## The only thing meta may contribute to a new match: cosmetic/option ids (never numbers).
func match_opts(chosen_alt_start: String = "") -> Dictionary:
	var o := {"title": data["equipped_title"], "cosmetics": (data["cosmetics"] as Array).duplicate()}
	if chosen_alt_start != "" and has("alt_starts", chosen_alt_start):
		o["alt_start"] = chosen_alt_start
	return o
