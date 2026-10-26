class_name ClassLink
extends RefCounted
## Late-bound lookup of Stream A's `Rules` and `MatchState` scripts so persistence/net do not hard-depend
## on them at parse time. Tests may inject overrides (e.g. a fake) via `overrides`.
static var overrides: Dictionary = {}  # "Rules" / "MatchState" -> Script

const FALLBACK_PATHS := {
	"Rules": ["res://rules/api.gd"],
	"MatchState": ["res://rules/match_state.gd", "res://rules/state.gd"],
}

static func script_for(cls: String) -> Script:
	if overrides.has(cls):
		return overrides[cls]
	for e in ProjectSettings.get_global_class_list():
		if e.get("class", "") == cls:
			return load(e["path"]) as Script
	for p in FALLBACK_PATHS.get(cls, []):
		if ResourceLoader.exists(p):
			var s: Script = load(p) as Script
			if s != null and cls == "Rules":
				return s
			if s != null and cls == "MatchState":
				return s
	return null

static func rules() -> Script:
	return script_for("Rules")

static func match_state() -> Script:
	return script_for("MatchState")
