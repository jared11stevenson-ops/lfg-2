extends TestCase
## Persistence tests. Uses an isolated root under user://, wiped before each test.
const ROOT := "user://t_persist"

func before_each() -> void:
	_wipe(ROOT)
	Persist.root = ROOT
	ClassLink.overrides = {}

func after_each() -> void:
	_wipe(ROOT)

func _wipe(p: String) -> void:
	var d := DirAccess.open(p)
	if d == null:
		return
	for n in d.get_files():
		DirAccess.remove_absolute(p.path_join(n))
	for n in d.get_directories():
		_wipe(p.path_join(n))
		DirAccess.remove_absolute(p.path_join(n))

func _state(n: int) -> Dictionary:
	return {"schema_version": 1, "seed": 42, "tick": n, "pos": Vector2i(n, -n), "inv": {"lfg:crop/glowfruit": n}}

func _w(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(text)
	f.close()

func _slot_file(slot: int, suffix: String = "") -> String:
	return ROOT.path_join("saves/slot_%d.sav%s" % [slot, suffix])

func test_roundtrip_preserves_types() -> void:
	var r: Dictionary = Persist.save_match(0, _state(5))
	check(r["ok"], "save ok")
	var l: Dictionary = Persist.load_match(0)
	check(l["ok"], "load ok")
	eq(l["state_dict"], _state(5), "state identical incl. Vector2i and int types")
	eq(l["source"], "primary", "from primary")
	check(not l["recovered"], "not recovered")

func test_no_tmp_left_and_backup_rotation() -> void:
	for i in range(1, 5):
		Persist.save_match(1, _state(i))
	check(not FileAccess.file_exists(_slot_file(1, ".tmp")), "tmp removed")
	check(FileAccess.file_exists(_slot_file(1, ".bak1")), "bak1 exists")
	check(FileAccess.file_exists(_slot_file(1, ".bak2")), "bak2 exists")
	check(not FileAccess.file_exists(_slot_file(1, ".bak3")), "only 2 backups kept")
	eq(Persist.load_match(1)["state_dict"]["tick"], 4, "latest loads")
	eq(Persist.load_match(1)["stats"]["saves"], 4, "save counter")

func test_corrupt_primary_falls_back_to_backup() -> void:
	Persist.save_match(2, _state(1))
	Persist.save_match(2, _state(2))
	_w(_slot_file(2), "{ this is not json")
	var l: Dictionary = Persist.load_match(2)
	check(l["ok"], "recovered")
	check(l["recovered"], "flagged recovered")
	eq(l["source"], "backup1", "from bak1")
	eq(l["state_dict"]["tick"], 1, "previous save")
	check(l["errors"].size() > 0, "reports the corruption")

func test_checksum_detects_bitflip() -> void:
	Persist.save_match(3, _state(1))
	Persist.save_match(3, _state(2))
	var f := FileAccess.open(_slot_file(3), FileAccess.READ)
	var t: String = f.get_as_text()
	f.close()
	var tampered: String = t.replace("tick", "tock")  # valid JSON, wrong checksum
	check(tampered != t, "tamper applied")
	_w(_slot_file(3), tampered)
	var l: Dictionary = Persist.load_match(3)
	eq(l["source"], "backup1", "checksum mismatch rejected, backup used")
	check(l["errors"][0].contains("checksum_mismatch"), "reason is checksum")

func test_all_corrupt_reports_error() -> void:
	Persist.save_match(4, _state(1))
	_w(_slot_file(4), "garbage")
	var l: Dictionary = Persist.load_match(4)
	check(not l["ok"], "fails")
	eq(l["error"], "no_valid_save", "error code")
	eq(Persist.load_match(77)["error"], "no_save", "missing slot")
	eq(Persist.load_match(100)["error"], "bad_slot", "bad slot")

func test_bad_primary_not_rotated_over_good_backup() -> void:
	Persist.save_match(5, _state(1))
	Persist.save_match(5, _state(2))  # bak1 = 1
	_w(_slot_file(5), "garbage")
	Persist.save_match(5, _state(3))  # primary corrupt: must NOT become bak1
	var d: Dictionary = Persist.load_match(5)
	eq(d["state_dict"]["tick"], 3, "new save loads")
	_w(_slot_file(5), "garbage")
	eq(Persist.load_match(5)["state_dict"]["tick"], 1, "good backup preserved, garbage not rotated in")

func test_truncated_file() -> void:
	Persist.save_match(6, _state(1))
	Persist.save_match(6, _state(2))
	var f := FileAccess.open(_slot_file(6), FileAccess.READ)
	var t: String = f.get_as_text()
	f.close()
	_w(_slot_file(6), t.substr(0, t.length() / 2))
	eq(Persist.load_match(6)["source"], "backup1", "truncated primary -> backup")

# ---- migrations ----
func test_migrate_v1_to_v2_to_v3_each_step() -> void:
	var v1 := {"save_version": 1, "over": true, "state": {"a": 1}}
	var v2: Dictionary = SaveMigrations.step(v1, 1)
	eq(v2["save_version"], 2, "v2 stamped")
	eq(v2["over_reason"], "legacy", "over flag -> reason")
	check(v2.has("saved_at"), "saved_at added")
	var v3: Dictionary = SaveMigrations.step(v2, 2)
	eq(v3["save_version"], 3, "v3 stamped")
	eq(v3["status"], "over", "over->status")
	check(not v3.has("over"), "over removed")
	eq(v3["stats"], {"saves": 0}, "stats added")
	eq(v1["save_version"], 1, "input not mutated")

func test_migrate_full_chain_and_unversioned() -> void:
	var m: Dictionary = Persist.migrate({"over": false, "state": {"x": 1}})  # no version => v1
	eq(m["save_version"], SaveMigrations.CURRENT, "to current")
	eq(m["status"], "active", "active")
	eq(m["state"], {"x": 1}, "state untouched")
	eq(Persist.migrate({"save_version": 99, "state": {}}), {}, "future version rejected")
	eq(Persist.migrate_checked({"save_version": 99, "state": {}})["error"], "too_new", "too_new")
	eq(Persist.migrate({"save_version": 1}), {}, "missing state rejected")
	eq(Persist.migrate({"save_version": 0, "state": {}}), {}, "version 0 rejected")

func test_load_old_v1_file_from_disk() -> void:
	var v1 := {"save_version": 1, "over": false, "state": _state(9)}
	SafeFile.write(_slot_file(8), var_to_str(v1))
	var l: Dictionary = Persist.load_match(8)
	check(l["ok"], "v1 file loads")
	eq(l["state_dict"]["tick"], 9, "content")
	# and a v1 file marked over by the old format cannot be resumed
	SafeFile.write(_slot_file(9), var_to_str({"save_version": 1, "over": true, "state": _state(1)}))
	eq(Persist.load_match(9)["error"], "match_over", "legacy over honoured")

func test_state_level_migration_hook() -> void:
	SaveMigrations.state_steps = {1: func(sd: Dictionary) -> Dictionary:
		var o: Dictionary = sd.duplicate(true)
		o["renamed"] = o.get("old", 0)
		o.erase("old")
		return o}
	SaveMigrations.state_target = 2
	var r: Dictionary = SaveMigrations.run({"save_version": 3, "status": "active", "stats": {"saves": 1}, "state": {"schema_version": 1, "old": 7}})
	SaveMigrations.state_steps = {}
	var gap: Dictionary = SaveMigrations.run({"save_version": 3, "state": {"schema_version": 1}})
	var newer: Dictionary = SaveMigrations.run({"save_version": 3, "state": {"schema_version": 5}})
	SaveMigrations.state_target = -1
	check(r["ok"], "state migrated")
	eq(r["data"]["state"], {"schema_version": 2, "renamed": 7}, "state step applied and stamped")
	eq(gap["error"], "no_state_migration_from_1", "missing step is an error, not a silent pass")
	eq(newer["error"], "state_too_new", "newer state rejected")

# ---- permadeath ----
func test_match_over_event_ends_slot_forever() -> void:
	Persist.save_match(10, _state(1))
	check(not Persist.handle_events(10, [{"type": &"crop_grown"}]), "unrelated event ignored")
	check(Persist.load_match(10)["ok"], "still resumable")
	check(Persist.handle_events(10, [{"type": &"match_over", "reason": "leader_died"}]), "match_over handled")
	var l: Dictionary = Persist.load_match(10)
	check(not l["ok"], "cannot resume")
	eq(l["error"], "match_over", "error code")
	eq(l["reason"], "leader_died", "reason kept")
	eq(Persist.save_match(10, _state(2))["error"], "match_over", "cannot overwrite finished match")

func test_corrupting_primary_cannot_resurrect_dead_match() -> void:
	Persist.save_match(11, _state(1))
	Persist.save_match(11, _state(2))
	Persist.mark_over(11, "leader_died")
	_w(_slot_file(11), "garbage")  # corrupt primary: backup1 is a perfectly valid alive save
	eq(Persist.load_match(11)["error"], "match_over", "backup fallback does not bypass tombstone")

func test_unreadable_tombstone_still_counts_as_over() -> void:
	Persist.save_match(12, _state(1))
	Persist.mark_over(12, "x")
	_w(ROOT.path_join("saves/slot_12.over"), "junk")
	check(Persist.is_over(12), "still over")
	eq(Persist.load_match(12)["error"], "match_over", "not resumable")

func test_clear_slot_allows_new_match_and_list_slots() -> void:
	Persist.save_match(13, _state(1))
	Persist.save_match(14, _state(1))
	Persist.mark_over(14, "starved_out")
	var ls: Array[Dictionary] = Persist.list_slots()
	eq(ls.size(), 2, "two slots listed")
	eq(ls[1]["status"], "over", "over listed")
	Persist.clear_slot(14)
	check(Persist.save_match(14, _state(7))["ok"], "fresh match after explicit clear")
	eq(Persist.load_match(14)["state_dict"]["tick"], 7, "new data")
	eq(Persist.load_match(14)["stats"]["saves"], 1, "stats reset")

# ---- state object path via injected MatchState ----
class FakeMS:
	extends RefCounted
	var d: Dictionary = {}
	func to_dict() -> Dictionary:
		return d
	static func from_dict(x: Dictionary) -> FakeMS:
		var m := FakeMS.new()
		m.d = x
		return m

func test_object_state_roundtrip_via_class_link() -> void:
	ClassLink.overrides = {"MatchState": FakeMS}
	var m := FakeMS.new()
	m.d = _state(3)
	check(Persist.save_match(15, m)["ok"], "object saved via to_dict")
	var l: Dictionary = Persist.load_match(15)
	check(l["state"] is FakeMS, "from_dict used")
	eq(l["state"].to_dict(), _state(3), "same data")
