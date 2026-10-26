extends TestCase
const ROOT := "user://t_meta"

func before_each() -> void:
	_wipe(ROOT)
	Persist.root = ROOT

func after_each() -> void:
	_wipe(ROOT)

func _wipe(p: String) -> void:
	var d := DirAccess.open(p)
	if d == null:
		return
	for n in d.get_files():
		DirAccess.remove_absolute(p.path_join(n))

func test_unlock_save_load() -> void:
	var m: MetaStore = MetaStore.load_from()
	check(m.unlock("codex", "lfg:codex/glowfruit"), "unlock")
	check(not m.unlock("codex", "lfg:codex/glowfruit"), "dupe is no-op")
	check(m.unlock("titles", "lfg:title/survivor"), "title")
	check(m.equip_title("lfg:title/survivor"), "equip owned")
	check(not m.equip_title("lfg:title/stolen"), "cannot equip unowned")
	check(m.save()["ok"], "saved")
	check(FileAccess.file_exists(ROOT.path_join("meta.json")), "file is meta.json")
	var m2: MetaStore = MetaStore.load_from()
	check(m2.has("codex", "lfg:codex/glowfruit"), "persisted codex")
	eq(m2.data["equipped_title"], "lfg:title/survivor", "persisted equip")

func test_invalid_ids_rejected() -> void:
	var m: MetaStore = MetaStore.load_from()
	check(not m.unlock("codex", "glowfruit"), "no namespace")
	check(not m.unlock("codex", "lfg:title/x"), "wrong kind prefix")
	check(not m.unlock("gold", "lfg:codex/x"), "unknown kind")
	check(not m.unlock("codex", "lfg:codex/UPPER"), "bad charset")

func test_hand_edited_file_cannot_smuggle_power() -> void:
	var evil := {"version": 1, "codex": ["lfg:codex/ok", "lfg:codex/../../x", 5, {"a": 1}], "gold": 99999, "max_hp": 500,
		"starting_items": {"lfg:item/sword": 9}, "titles": [], "equipped_title": "lfg:title/notowned"}
	SafeFile.write(ROOT.path_join("meta.json"), JSON.stringify(evil))
	var m: MetaStore = MetaStore.load_from()
	eq(m.data["codex"], ["lfg:codex/ok"], "only valid ids kept")
	eq(m.data.keys().size(), 6, "only allowlisted keys")
	check(not m.data.has("gold") and not m.data.has("max_hp") and not m.data.has("starting_items"), "power fields dropped")
	eq(m.data["equipped_title"], "", "unowned title not equipped")

func test_data_is_strings_only() -> void:
	var m: MetaStore = MetaStore.load_from()
	m.unlock("codex", "lfg:codex/a")
	m.unlock("alt_starts", "lfg:altstart/judd_hermit")
	m.unlock("cosmetics", "lfg:cosmetic/hat1")
	var bad := false
	for k in m.data:
		var v: Variant = m.data[k]
		if v is Array:
			for x in v:
				if not (x is String):
					bad = true
		elif k != "version" and not (v is String):
			bad = true
	check(not bad, "no numeric/structured payloads in meta")

func test_match_opts_cosmetic_only_and_ownership_checked() -> void:
	var m: MetaStore = MetaStore.load_from()
	m.unlock("alt_starts", "lfg:altstart/judd_hermit")
	var o: Dictionary = m.match_opts("lfg:altstart/judd_hermit")
	eq(o["alt_start"], "lfg:altstart/judd_hermit", "owned alt start offered")
	check(not m.match_opts("lfg:altstart/other").has("alt_start"), "unowned alt start refused")
	for k in o.keys():
		check(["title", "cosmetics", "alt_start"].has(k), "opts key allowed: " + k)

func test_meta_independent_of_match_save_and_permadeath() -> void:
	var m: MetaStore = MetaStore.load_from()
	m.unlock("codex", "lfg:codex/a")
	m.save()
	Persist.save_match(0, {"x": 1})
	Persist.mark_over(0, "leader_died")
	Persist.clear_slot(0)
	check(MetaStore.load_from().has("codex", "lfg:codex/a"), "meta survives match death and slot wipe")
	var l: Dictionary = {"x": 1}
	Persist.save_match(1, l)
	var sd: Dictionary = Persist.load_match(1)["state_dict"]
	check(not sd.has("codex") and not sd.has("titles"), "match saves carry no meta")

func test_corrupt_meta_falls_back_to_backup_then_empty() -> void:
	var m: MetaStore = MetaStore.load_from()
	m.unlock("codex", "lfg:codex/a")
	m.save()
	m.unlock("codex", "lfg:codex/b")
	m.save()
	var f := FileAccess.open(ROOT.path_join("meta.json"), FileAccess.WRITE)
	f.store_string("{{{")
	f.close()
	var r: MetaStore = MetaStore.load_from()
	eq(r.data["codex"], ["lfg:codex/a"], "backup used")
	for s in [".bak1", ".bak2"]:
		var g := FileAccess.open(ROOT.path_join("meta.json" + s), FileAccess.WRITE)
		if g:
			g.store_string("x")
	eq(MetaStore.load_from().data["codex"], [], "all corrupt => empty, no crash")
