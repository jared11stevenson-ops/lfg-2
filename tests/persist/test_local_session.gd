extends TestCase
## LocalSession: autosave / continue / permadeath tombstone / meta hooks / menu API.
const OPTS := {"ai_enabled": false, "wild_enemies": false, "day_seconds": 60.0}

func before_each() -> void:
	Persist.root = "user://t_localsess"
	for s in range(0, 4):
		Persist.clear_slot(s)
	DirAccess.remove_absolute(ProjectSettings.globalize_path("user://t_localsess/meta.json"))
	for suffix in ["meta.json.bak1", "meta.json.bak2", "meta.json.tmp"]:
		DirAccess.remove_absolute(ProjectSettings.globalize_path("user://t_localsess/" + suffix))

func _meta() -> MetaStore:
	return MetaStore.load_from()

func test_new_game_saves_and_continue_restores() -> void:
	var s := LocalSession.new_game(77, &"lfg:class/judd", 1, OPTS)
	check(s.last_save.get("ok", false), "initial save written")
	var pid: int = s.actor_id
	var hx := Vector2i.ZERO
	for h in HexGrid.ring_within(s.state.actors[pid]["hex"], 2):
		if h != s.state.actors[pid]["hex"] and Rules.apply(s.state, {"type": &"plant", "actor": pid, "seq": 1, "args": {"crop": "lfg:crop/glowfruit", "hex": h}}).get("ok", false):
			hx = h
			break
	check(s.state.plots.size() == 1, "planted")
	s.tick(40.0)
	var r: Dictionary = s.save_now()
	check(r.get("ok", false), "manual save")
	var day: int = int(s.state.clock["day"])
	var inv: Dictionary = (s.state.actors[pid]["inv"] as Dictionary).duplicate()
	var c := LocalSession.continue_slot(1)
	check(c != null, "continue works")
	eq(c.state.plots.keys(), s.state.plots.keys(), "crop restored")
	eq(int(c.state.clock["day"]), day, "clock restored")
	eq(c.actor_id, pid, "actor restored")
	for k in inv:
		eq(int(c.state.actors[pid]["inv"].get(k, 0)), int(inv[k]), "inv %s" % k)
	# continuing keeps working with the Rules: next command uses a safe seq
	var res: Dictionary = c.command(&"water", {"hex": hx})
	check(res.get("ok", false), "command after continue accepted (seq %s)" % res.get("error", ""))

func test_autosave_interval_and_backups_are_atomic_files() -> void:
	var s := LocalSession.new_game(5, &"lfg:class/judd", 0, OPTS)
	s.autosave_interval = 5.0
	var before: int = s.saves_written
	for _i in 4:
		s.tick(2.0)
	check(s.saves_written >= before + 1, "periodic autosave fired (%d)" % (s.saves_written - before))
	for _i in 6:
		s.tick(5.0)
	check(FileAccess.file_exists(Persist.root.path_join("saves/slot_0.sav")), "primary exists")
	check(FileAccess.file_exists(SafeFile.backup_path(Persist.root.path_join("saves/slot_0.sav"), 1)), "rotating backup exists")
	check(not FileAccess.file_exists(Persist.root.path_join("saves/slot_0.sav.tmp")), "no temp file left behind")
	# day change forces a save
	var n: int = s.saves_written
	s.tick(60.0)
	check(s.saves_written > n, "day/phase boundary saves immediately")

func test_permadeath_tombstone_blocks_continue_and_resave() -> void:
	var s := LocalSession.new_game(9, &"lfg:class/judd", 2, OPTS)
	var ended := []
	s.session_ended.connect(func(why: String): ended.append(why))
	var evs: Array = []
	Combat.hurt(s.state, s.actor_id, 99999, -1, evs, "test")
	check(evs.any(func(e): return e["type"] == &"match_over"), "leader death produced match_over")
	s._handle(evs)
	check(Persist.is_over(2), "tombstone written")
	eq(ended.size(), 1, "session_ended emitted once")
	check(s.ended, "session flagged ended")
	eq(s.save_now().get("error", ""), "match_over", "no save after death")
	eq(s.submit({"type": &"rest", "actor": s.actor_id, "seq": 99, "args": {}}).get("error", ""), "match_over", "no commands after death")
	check(LocalSession.continue_slot(2) == null, "cannot continue a dead run")
	eq(LocalSession.last_error, "match_over", "reason exposed")
	# corrupting/deleting the primary must not resurrect the dead leader
	DirAccess.remove_absolute(ProjectSettings.globalize_path(Persist.root.path_join("saves/slot_2.sav")))
	check(LocalSession.continue_slot(2) == null, "still dead without the primary file")
	eq(MenuApi.continue_slot(), -1, "menu never offers a dead slot")
	var info: Dictionary = Persist.peek(2)
	eq(info["status"], "over", "menu summary says over")

func test_meta_hooks_codex_and_titles() -> void:
	var m: MetaStore = _meta()
	var s := LocalSession.new_game(3, &"lfg:class/judd", -1, OPTS, m)
	check(m.has("codex", "lfg:codex/class_judd"), "codex entry on class first use")
	eq(s.unlocked, ["lfg:codex/class_judd"] as Array[String], "reported to the caller")
	var again := LocalSession.new_game(4, &"lfg:class/judd", -1, OPTS, m)
	eq(again.unlocked.size(), 0, "second use unlocks nothing new")
	var s2 := LocalSession.new_game(3, &"lfg:class/mira", -1, OPTS, m)
	check(m.has("codex", "lfg:codex/class_mira"), "another class adds its own entry")
	s.tick(0.1)
	s._handle([{"type": &"victory", "kind": "dominion"}])
	check(m.has("titles", "lfg:title/dominion"), "title on win")
	s._handle([{"type": &"victory", "kind": "crowned"}])
	check(m.has("titles", "lfg:title/crowned"), "crowned title")
	var disk: MetaStore = MetaStore.load_from()
	check(disk.has("titles", "lfg:title/dominion") and disk.has("codex", "lfg:codex/class_judd"), "persisted to meta.json")
	check(MetaHooks.on_events(m, [{"type": &"victory", "kind": "<script>"}]).is_empty(), "unknown kind ignored")
	check(MetaHooks.codex_id_for_class("lfg:class/Ev il!") == "lfg:codex/class_ev_il_", "ids sanitised to the allowlist")
	# losing does not grant titles and meta survives a dead run
	var dead := LocalSession.new_game(11, &"lfg:class/judd", 3, OPTS, m)
	var evs: Array = []
	Combat.hurt(dead.state, dead.actor_id, 99999, -1, evs, "test")
	dead._handle(evs)
	check(MetaStore.load_from().has("codex", "lfg:codex/class_judd"), "meta untouched by permadeath")

func test_menu_api() -> void:
	eq(MenuApi.continue_slot(), -1, "nothing to continue yet")
	eq(MenuApi.free_slot(), 0, "slot 0 free")
	LocalSession.new_game(21, &"lfg:class/judd", 0, OPTS)
	OS.delay_msec(1100)         # saved_at has 1 s resolution: make slot 1 strictly newer
	var b := LocalSession.new_game(22, &"lfg:class/mira", 1, OPTS)
	b.tick(1.0)
	b.save_now()
	eq(MenuApi.continue_slot(), 1, "latest active slot")
	eq(MenuApi.free_slot(), 2, "next free slot")
	var rows: Array[Dictionary] = MenuApi.slots()
	eq(rows.size(), 2, "two used slots")
	eq(rows[0]["class_id"], "lfg:class/judd", "class shown")
	eq(rows[1]["class_id"], "lfg:class/mira", "class shown")
	eq(rows[1]["status"], "active", "status")
	check(rows[0]["day"] >= 1 and rows[0]["seed"] == 21, "day and seed")
	MenuApi.delete_slot(0)
	eq(MenuApi.slots().size(), 1, "deleted")
	check(MenuApi.equip_title("lfg:title/none") == false, "cannot equip a title you do not own")
	var m: MetaStore = MenuApi.meta()
	m.unlock("titles", "lfg:title/crowned")
	m.save()
	check(MenuApi.equip_title("lfg:title/crowned"), "equip owned title")
	eq(MenuApi.new_match_opts()["title"], "lfg:title/crowned", "title flows into match opts as an id only")
