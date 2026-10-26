extends SceneTree
## Headless dedicated server entry point (dev/LAN use):
##   godot --headless --path . -s net/server_main.gd -- --port 7777 --seed 1 --class lfg:class/judd --players 2 [--slot 0]
## Prints one token per player slot to stdout. No auth beyond those tokens; no TLS; no process supervision.
var server: NetServer
var last_ms: int = 0

func _init() -> void:
	var port := 7777
	var seed_v := 1
	var cls := "lfg:class/judd"
	var players := 2
	var slot := -1
	var a: PackedStringArray = OS.get_cmdline_user_args()
	var i := 0
	while i < a.size() - 1:
		match a[i]:
			"--port": port = int(a[i + 1])
			"--seed": seed_v = int(a[i + 1])
			"--class": cls = a[i + 1]
			"--players": players = int(a[i + 1])
			"--slot": slot = int(a[i + 1])
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
		st = rules.call("new_match", seed_v, StringName(cls), {})
	server = NetServer.new()
	server.persist_slot = slot
	var err: int = server.start(port, st, rules, "0.0.0.0")
	if err != OK:
		printerr("cannot bind port %d: %d" % [port, err])
		quit(1)
		return
	for p in players:
		print("TOKEN actor=%d %s" % [p, server.issue_token(p)])
	print("listening on %d" % port)
	last_ms = Time.get_ticks_msec()

func _process(_dt: float) -> bool:
	var now: int = Time.get_ticks_msec()
	server.poll()
	server.advance(float(now - last_ms) / 1000.0)
	last_ms = now
	return false
