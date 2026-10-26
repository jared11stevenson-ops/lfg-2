extends SceneTree
## Headless dedicated server entry point (dev/LAN use):
##   godot --headless --path . -s net/server_main.gd -- --port 7777 --seed 1 --class lfg:class/judd --players 2 [--slot 0]
## Player i is bound to the leader of faction i (faction 0 = the human start, faction 1.. = rival leaders).
## Tokens are printed to stdout ("TOKEN actor=<id> <token>") and, with --dir, written to <dir>/tokens.json.
## Test/CI options:
##   --dir <path>          control dir: writes tokens.json + ready.flag; polls stop.flag (quit) and freeze.flag
##                         (stop advancing time, push a final snapshot, write final.state = var_to_str(to_dict) + frozen.flag)
##   --day-seconds N       length of one in-game day (default 360)      --ai 0|1  --wild 0|1  (default 1/1)
##   --timescale X         game seconds per real second (default 1)     --purge-scale Y  scale used while PURGE_ACTIVE (default = X)
##   --hold 1              with --dir: keep game time frozen (sockets still served) until <dir>/go.flag exists
##   --max-seconds N       safety: quit after N real seconds
## No auth beyond those tokens; no TLS; no process supervision.
var server: NetServer
var last_ms: int = 0
var timescale: float = 1.0
var purge_scale: float = -1.0
var dir: String = ""
var started_ms: int = 0
var max_seconds: float = 0.0
var frozen_done: bool = false
var hold: bool = false

func _init() -> void:
	var port := 7777
	var seed_v := 1
	var cls := "lfg:class/judd"
	var players := 2
	var slot := -1
	var day_seconds := 360.0
	var ai := 1
	var wild := 1
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var i := 0
	while i < a.size() - 1:
		match a[i]:
			"--port": port = int(a[i + 1])
			"--seed": seed_v = int(a[i + 1])
			"--class": cls = a[i + 1]
			"--players": players = int(a[i + 1])
			"--slot": slot = int(a[i + 1])
			"--dir": dir = a[i + 1]
			"--day-seconds": day_seconds = float(a[i + 1])
			"--ai": ai = int(a[i + 1])
			"--wild": wild = int(a[i + 1])
			"--timescale": timescale = float(a[i + 1])
			"--purge-scale": purge_scale = float(a[i + 1])
			"--max-seconds": max_seconds = float(a[i + 1])
			"--hold": hold = int(a[i + 1]) == 1
		i += 2
	var rules: Script = ClassLink.rules()
	if rules == null:
		printerr("rules module not found")
		quit(2)
		return
	var st: Object = null
	if slot >= 0:
		var l: Dictionary = Persist.load_match(slot)
		if l.get("ok", false):
			st = l["state"]
		elif l.get("error", "") == "match_over":
			printerr("match in slot %d is over (%s); refusing to resume" % [slot, l.get("reason", "")])
			quit(3)
			return
	if st == null:
		st = rules.call("new_match", seed_v, StringName(cls), {"ai_enabled": ai == 1, "wild_enemies": wild == 1, "day_seconds": day_seconds})
	server = NetServer.new()
	server.persist_slot = slot
	var err: int = server.start(port, st, rules, "0.0.0.0")
	if err != OK:
		printerr("cannot bind port %d: %d" % [port, err])
		quit(1)
		return
	var toks: Dictionary = {}
	var factions: Variant = st.get("factions")
	for p in players:
		var actor: int = p
		if factions is Dictionary and (factions as Dictionary).has(p):
			actor = int(factions[p]["leader"])
		var tok: String = server.issue_token(actor)
		toks[str(p)] = {"actor": actor, "token": tok}
		print("TOKEN actor=%d %s" % [actor, tok])
	print("listening on %d" % port)
	started_ms = Time.get_ticks_msec()
	last_ms = started_ms
	if hold and dir != "":
		server.frozen = true
	if dir != "":
		_write(dir.path_join("tokens.json"), JSON.stringify({"port": port, "players": toks}))
		_write(dir.path_join("ready.flag"), "1")

static func _write(path: String, text: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	if f != null:
		f.store_string(text)
		f.close()

func _process(_dt: float) -> bool:
	var now: int = Time.get_ticks_msec()
	var real: float = float(now - last_ms) / 1000.0
	last_ms = now
	if max_seconds > 0.0 and float(now - started_ms) / 1000.0 > max_seconds:
		quit(4)
		return true
	if dir != "":
		if FileAccess.file_exists(dir.path_join("stop.flag")):
			server.stop()
			quit(0)
			return true
		if hold and server.frozen and not frozen_done and FileAccess.file_exists(dir.path_join("go.flag")):
			server.frozen = false
			hold = false
			last_ms = Time.get_ticks_msec()
			real = 0.0
		if FileAccess.file_exists(dir.path_join("freeze.flag")) and not frozen_done:
			server.poll()
			server.frozen = true
			server._broadcast_snapshot()
			_write(dir.path_join("final.state"), var_to_str(server.state.call("to_dict")))
			_write(dir.path_join("final.log"), "\n".join(server.log) + "\naudit=" + str(server.audit_log))
			_write(dir.path_join("frozen.flag"), "1")
			frozen_done = true
	var scale: float = timescale
	if purge_scale > 0.0 and server.state.get("phase") == &"PURGE_ACTIVE":
		scale = purge_scale
	server.snapshot_interval = maxf(0.25, 0.2 * scale)       # ~5 snapshots per real second
	server.poll()
	server.advance(real * scale)
	return false
