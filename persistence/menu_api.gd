class_name MenuApi
extends RefCounted
## Small, UI-agnostic API for the main menu (returns plain data; no nodes, no scenes).
##   MenuApi.slots()                 -> Array[Dictionary] one entry per used slot (see Persist.peek)
##   MenuApi.continue_slot()         -> int  most recently saved ACTIVE slot, or -1 (dead/over slots never qualify)
##   MenuApi.free_slot()             -> int  first unused slot 0..MAX_SLOT, or -1
##   MenuApi.delete_slot(slot)       wipes save + backups + tombstone (explicit player action, e.g. after a loss)
##   MenuApi.codex()/titles()        -> Array[String] unlocked ids ; MenuApi.equip_title(id)
##   MenuApi.new_match_opts(alt)     -> Dictionary cosmetic options for Rules.new_match (never power)
## Starting a game is LocalSession.new_game(...) / LocalSession.continue_slot(slot) (main/session_local.gd).

static func slots() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for s in Persist.list_slots():
		out.append(Persist.peek(int(s["slot"])))
	return out

static func continue_slot() -> int:
	var best: int = -1
	var best_t: int = -1
	for s in Persist.list_slots():
		if s["status"] == "active":
			var p: Dictionary = Persist.peek(int(s["slot"]))
			if p.get("ok", false) and int(p["saved_at"]) >= best_t:
				best_t = int(p["saved_at"])
				best = int(s["slot"])
	return best

static func free_slot() -> int:
	for s in range(0, Persist.MAX_SLOT + 1):
		if not Persist.slot_in_use(s):
			return s
	return -1

static func delete_slot(slot: int) -> void:
	Persist.clear_slot(slot)

static func meta() -> MetaStore:
	return MetaStore.load_from()

static func codex() -> Array:
	return (meta().data["codex"] as Array).duplicate()

static func titles() -> Array:
	return (meta().data["titles"] as Array).duplicate()

static func equip_title(id: String) -> bool:
	var m: MetaStore = meta()
	if not m.equip_title(id):
		return false
	m.save()
	return true

static func new_match_opts(alt_start: String = "") -> Dictionary:
	return meta().match_opts(alt_start)
