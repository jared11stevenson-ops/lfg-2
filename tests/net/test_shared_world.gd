extends TestCase
## Shared-world play across REAL PROCESSES: one dedicated server (net/server_main.gd, real MatchState/Rules) and two game
## clients (tests/net/shared_client.gd), each running the actual WorldStage scene fed by an OnlineSession. The clients plant, water,
## harvest, withdraw, build, trade, capture, steal and fight with ordinary commands; afterwards the server freezes and we compare
## what the server holds with what each client holds. Two Godot processes build the 77-chunk world, so this takes ~30-60 s.
const SEED := 4
const TIMEOUT_S := 200.0

var dir: String = ""
var pids: Array[int] = []

func _spawn(args: PackedStringArray, out_name: String) -> int:
	var quoted: PackedStringArray = []
	for a in args:
		quoted.append("'" + a.replace("'", "'\\''") + "'")
	var cmd := "exec '%s' %s > '%s' 2>&1" % [OS.get_executable_path(), " ".join(quoted), dir.path_join(out_name)]
	return OS.create_process("/bin/sh", ["-c", cmd])

func _flag(name: String) -> void:
	var f := FileAccess.open(dir.path_join(name), FileAccess.WRITE)
	f.store_string("1")
	f.close()

func _has(name: String) -> bool:
	return FileAccess.file_exists(dir.path_join(name))

func _wait_for(names: Array, timeout: float) -> bool:
	var end: int = Time.get_ticks_msec() + int(timeout * 1000.0)
	while Time.get_ticks_msec() < end:
		var all := true
		for n in names:
			if not _has(n):
				all = false
		if all:
			return true
		OS.delay_msec(150)
	return false

func _read_json(name: String) -> Dictionary:
	var j: Variant = JSON.parse_string(FileAccess.get_file_as_string(dir.path_join(name)))
	return j if j is Dictionary else {}

func _norm(d: Dictionary) -> Dictionary:
	var o := {}
	for k in d:
		o[k] = int(d[k])
	return o

func after_each() -> void:
	for p in pids:
		if OS.is_process_running(p):
			OS.kill(p)

func test_two_stage_clients_share_one_authoritative_world() -> void:
	dir = ProjectSettings.globalize_path("user://t_shared_%d" % (randi() % 1000000))
	DirAccess.make_dir_recursive_absolute(dir)
	var proj: String = ProjectSettings.globalize_path("res://")
	var port: int = 20000 + randi() % 20000
	var t0: int = Time.get_ticks_msec()
	pids.append(_spawn(PackedStringArray(["--headless", "--path", proj, "-s", "net/server_main.gd", "--", "--port", str(port), "--seed", str(SEED),
		"--players", "2", "--dir", dir, "--day-seconds", "600", "--ai", "0", "--wild", "0", "--timescale", "200", "--purge-scale", "20", "--max-seconds", "300", "--hold", "1"]), "server.out"))
	check(_wait_for(["ready.flag"], 60.0), "server up")
	for role in ["A", "B"]:
		pids.append(_spawn(PackedStringArray(["--headless", "--path", proj, "-s", "tests/net/shared_client.gd", "--", "--role", role, "--dir", dir]), role + ".out"))
	check(_wait_for(["A.ready", "B.ready"], 90.0), "both clients built their WorldStage")
	_flag("go.flag")
	var done: bool = _wait_for(["A.done", "B.done"], TIMEOUT_S)
	check(done, "both client scripts finished (A trace: %s | B trace: %s)" % [FileAccess.get_file_as_string(dir.path_join("A.trace")).right(300), FileAccess.get_file_as_string(dir.path_join("B.trace")).right(300)])
	_flag("freeze.flag")
	check(_wait_for(["frozen.flag", "A.view", "B.view"], 90.0), "server froze and both clients dumped their view")
	_flag("stop.flag")
	print("shared-world run: %.1f s wall, 3 processes" % (float(Time.get_ticks_msec() - t0) / 1000.0))
	if not (_has("A.view") and _has("B.view") and _has("final.state")):
		return
	var va: Dictionary = _read_json("A.view")
	var vb: Dictionary = _read_json("B.view")
	var server_state: Dictionary = str_to_var(FileAccess.get_file_as_string(dir.path_join("final.state")))
	var sa: Dictionary = str_to_var(FileAccess.get_file_as_string(dir.path_join("A.snapshot")))
	var sb: Dictionary = str_to_var(FileAccess.get_file_as_string(dir.path_join("B.snapshot")))
	var a_id: int = int(va["actor"])
	var b_id: int = int(vb["actor"])
	# --- both processes really ran the WorldStage scene against the server
	eq(va["errors"], [], "A: no script errors / timeouts")
	eq(vb["errors"], [], "B: no script errors / timeouts")
	eq(va["stage_started"], true, "A: WorldStage built")
	eq(vb["stage_started"], true, "B: WorldStage built")
	eq(va["player_id"], a_id, "A's local state treats A as the player")
	eq(vb["player_id"], b_id, "B's local state treats B as the player (not server player 1)")
	check(b_id != a_id, "different actors")
	eq(va["fogged_rival_at_start"], true, "A started with the rival fogged and inventory-less")
	eq(vb["fogged_rival_at_start"], true, "B started with the rival fogged and inventory-less")
	# --- state comparison: each client's final snapshot is exactly the server's state filtered for that viewer
	check(sa == SnapshotFilter.for_actor(server_state, a_id), "A's view == server state filtered for A (exact)")
	check(sb == SnapshotFilter.for_actor(server_state, b_id), "B's view == server state filtered for B (exact)")
	eq(sa["plots"], server_state["plots"], "A sees exactly the server's crops")
	eq(sb["plots"], server_state["plots"], "B sees exactly the server's crops")
	eq(sa["clock"], server_state["clock"], "same clock")
	eq(sb["phase"], server_state["phase"], "same phase")
	# --- everyone saw everyone's farming, construction, trading, capture attempts and combat (events are shared)
	for v in [va, vb]:
		var ev: Dictionary = v["events"]
		check(int(ev.get("crop_planted", 0)) >= 2 and int(ev.get("crop_harvested", 0)) >= 2, "%s saw A's planting and harvest" % v["role"])
		check(int(ev.get("built", 0)) >= 1, "%s saw the construction" % v["role"])
		check(int(ev.get("traded", 0)) >= 2, "%s saw the trades" % v["role"])
		check(int(ev.get("actor_attacked", 0)) >= 2, "%s saw combat (%s)" % [v["role"], str(ev.get("actor_attacked", 0))])
		check(int(ev.get("ate", 0)) >= 1, "%s saw B eat" % v["role"])
		eq(int(v["leaked_items"]), 0, "%s received no item payloads from the other faction's actions" % v["role"])
		check(int(v["peak_stage_plots"]) >= 2, "%s's WorldStage farm layer displayed the crops (%d)" % [v["role"], int(v["peak_stage_plots"])])
	check(int(vb["peak_foreign_plots"]) >= 2, "B's state contained A's crops while growing (%d)" % int(vb["peak_foreign_plots"]))
	check(int(vb["peak_stage_plots"]) >= 2, "B's stage drew A's crops")
	eq(va["events"]["actor_attacked"], vb["events"]["actor_attacked"], "both counted the same attacks")
	eq(va["events"]["crop_planted"], vb["events"]["crop_planted"], "same planting events")
	# construction is public, in both views and on the server
	var home_a: String = str(int(server_state["factions"]["0"]["home"]))
	check((server_state["holdings"][home_a]["buildings"] as Array).has("lfg:building/wall"), "server: wall built")
	check((sb["holdings"][home_a]["buildings"] as Array).has("lfg:building/wall"), "B can see A's construction")
	# --- inventories
	eq(_norm(sa["actors"][str(a_id)]["inv"]), _norm(server_state["actors"][str(a_id)]["inv"]), "A's own inventory equals the server's")
	eq(_norm(sb["actors"][str(b_id)]["inv"]), _norm(server_state["actors"][str(b_id)]["inv"]), "B's own inventory equals the server's")
	eq(sa["actors"][str(b_id)]["inv"], {}, "A cannot see B's inventory")
	eq(sb["actors"][str(a_id)]["inv"], {}, "B cannot see A's inventory")
	check(int(server_state["actors"][str(a_id)]["inv"].get("lfg:item/sporebean_seed", 0)) >= 4, "A's trade (bought a seed) is on the server")
	var rival_home: String = str(int(server_state["factions"]["1"]["home"]))
	eq(sa["holdings"][rival_home]["store"], {}, "A cannot see B's home store")
	check(not (server_state["holdings"][rival_home]["store"] as Dictionary).is_empty(), "(the server's copy is not empty)")
	eq(sa["rng_state"], 0, "A cannot see the rng")
	# --- combat: hp seen equals hp on the server (both were within sight)
	for id in [a_id, b_id]:
		eq(int(sa["actors"][str(id)]["hp"]), int(server_state["actors"][str(id)]["hp"]), "A sees actor %d's hp as the server has it" % id)
		eq(int(sb["actors"][str(id)]["hp"]), int(server_state["actors"][str(id)]["hp"]), "B sees actor %d's hp as the server has it" % id)
		check(int(server_state["actors"][str(id)]["hp"]) < int(server_state["actors"][str(id)]["max_hp"]), "actor %d took damage" % id)
	eq(sa["actors"][str(b_id)]["hex"], server_state["actors"][str(b_id)]["hex"], "A sees B's real position (in sight)")
	# --- captures: both clients saw the same ones; at most one successful transfer per holding; owners match the server
	eq(va["captures"], vb["captures"], "capture events identical for both clients")
	var owner_by_event: Dictionary = {}
	var wins := 0
	for c in va["captures"]:
		if c["type"] == "holding_captured":
			wins += 1
			check(not owner_by_event.has(int(c["holding"])), "no duplicate capture of holding %d" % int(c["holding"]))
			owner_by_event[int(c["holding"])] = int(c["by"])
	for hid in owner_by_event:
		var k: String = str(int(hid))
		eq(int(server_state["holdings"][k]["owner"]), int(owner_by_event[hid]), "server owner of %s == last capture event" % k)
		eq(int(sa["holdings"][k]["owner"]), int(owner_by_event[hid]), "A's view of %s" % k)
		eq(int(sb["holdings"][k]["owner"]), int(owner_by_event[hid]), "B's view of %s" % k)
	check(va["captures"].size() >= 1, "at least one capture attempt resolved (win or fail)")
