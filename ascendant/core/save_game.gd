class_name SaveGame
extends RefCounted
## Whole-world save: simulation + the player's bloodline (living kin) + carried items.
const DIR := "user://saves"
static func path(slot: String) -> String: return "%s/%s.ascend" % [DIR, slot]
static func exists(slot: String) -> bool: return FileAccess.file_exists(path(slot))

static func write(slot: String, play: PlayScene) -> bool:
	DirAccess.make_dir_recursive_absolute(DIR)
	var kin := []
	for c in play.critters:
		if is_instance_valid(c) and (c.bloodline >= 0 or c == play.player):
			kin.append(_critter_dict(c))
	var d := {"v": 1, "sim": play.sim.save_dict(), "kin": kin, "player_id": play.player.id if is_instance_valid(play.player) else -1,
		"generation": play.generation, "bloodline": play.bloodline_id, "chronicle": play.chronicle, "season_t": play.season_t, "deaths": play.deaths, "ev_seen": play._ev_seen,
		"items": play.items.map(func(i): return i.to_dict()), "stamp": Time.get_datetime_string_from_system(), "year": play.year()}
	var f := FileAccess.open(path(slot) + ".tmp", FileAccess.WRITE)
	if f == null: return false
	f.store_var(d, false)
	f.close()
	DirAccess.rename_absolute(path(slot) + ".tmp", path(slot))
	return true

static func _critter_dict(c: Critter) -> Dictionary:
	return {"id": c.id, "g": c.genome, "bp": c.bp, "sp": c.sp, "pos": c.position, "age": c.age_s, "hp": c.hp, "energy": c.energy, "bloodline": c.bloodline, "gen": c.gen,
		"parents": c.parents, "kills": c.kills, "weapon": c.weapon.get("id", -1)}

static func read(slot: String) -> Dictionary:
	if not exists(slot): return {}
	var f := FileAccess.open(path(slot), FileAccess.READ)
	var d = f.get_var(false)
	return d if d is Dictionary else {}

static func summary(slot: String) -> String:
	var d := read(slot)
	if d.is_empty(): return ""
	return "Year %d · seed %d · generation %d · %s" % [d.get("year", 0), d["sim"]["seed"], d["generation"], d["stamp"]]
