class_name MetaHooks
extends RefCounted
## Gameplay -> meta-progression hooks (cosmetic only; MetaStore enforces the id allowlist, never numbers).
##   class first use  -> codex entry  lfg:codex/class_<name>
##   victory (win)    -> title        lfg:title/total_conquest (only when the PLAYER faction is the winner)
## All functions return the ids newly unlocked and save only when something changed.

static func codex_id_for_class(class_id: String) -> String:
	var tail: String = class_id.get_slice("/", 1) if class_id.contains("/") else class_id
	var clean := ""
	for c in tail.to_lower():
		clean += c if ("abcdefghijklmnopqrstuvwxyz0123456789_".contains(c)) else "_"
	return "lfg:codex/class_" + clean

static func on_class_used(meta: MetaStore, class_id: String) -> Array[String]:
	var out: Array[String] = []
	if meta == null or class_id == "":
		return out
	var id: String = codex_id_for_class(class_id)
	if meta.unlock("codex", id):
		out.append(id)
		meta.save()
	return out

static func title_for_victory(kind: String) -> String:
	match kind:
		"total_conquest": return "lfg:title/total_conquest"
	return ""

## Feed the same event arrays the UI gets. Only `victory` events matter today.
static func on_events(meta: MetaStore, events: Array) -> Array[String]:
	var out: Array[String] = []
	if meta == null:
		return out
	for e in events:
		if e is Dictionary and e.get("type", &"") == &"victory":
			if e.has("player") and not bool(e["player"]):
				continue      # a rival faction's conquest earns the player nothing
			var t: String = title_for_victory(str(e.get("kind", "")))
			if t != "" and meta.unlock("titles", t):
				out.append(t)
	if out.size() > 0:
		meta.save()
	return out
