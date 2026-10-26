extends TestCase
## Shared harness (not a suite: no test_ methods). Real ENet on 127.0.0.1, one process, REAL Rules + MatchState.
## Actor A = player leader (faction 0), actor B = faction 1's leader. AI/wild enemies off unless opts say otherwise.
var server: NetServer
var clients: Array[NetClient] = []
var port: int = 0
var tokens: Array[String] = []
var st: MatchState
var a_id: int = 1
var b_id: int = -1

func boot(day_seconds: float = 60.0, extra_opts: Dictionary = {}, seed_v: int = 1234, connect_clients: bool = true) -> void:
	ClassLink.overrides = {}
	var o := {"ai_enabled": false, "wild_enemies": false, "day_seconds": day_seconds}
	o.merge(extra_opts, true)
	st = Rules.new_match(seed_v, &"lfg:class/judd", o)
	b_id = int(st.factions[1]["leader"])
	server = NetServer.new()
	for _t in 20:
		port = 20000 + randi() % 20000
		if server.start(port, st, Rules) == OK:
			break
	tokens = [server.issue_token(a_id), server.issue_token(b_id)]
	if connect_clients:
		for i in 2:
			connect_client(i)
		check(until(func(): return clients[0].is_ready and clients[1].is_ready), "both clients welcomed")

func connect_client(i: int, tok: String = "") -> NetClient:
	var c := NetClient.new()
	c.connect_to("127.0.0.1", port, tok if tok != "" else tokens[i])
	clients.append(c)
	return c

func after_each() -> void:
	for c in clients:
		c.disconnect_now()
	clients.clear()
	if server != null:
		server.stop()

func pump(n: int = 20) -> void:
	for _i in n:
		server.poll()
		for c in clients:
			c.poll()
		OS.delay_msec(1)

func until(cond: Callable, max_iter: int = 600) -> bool:
	for _i in max_iter:
		pump(1)
		if cond.call():
			return true
	return false

func to_phase(p: StringName) -> void:
	var guard := 0
	while st.phase != p and guard < 4000:
		server.advance(5.0)
		guard += 1
	pump(20)

## Submit and wait for the answer.
func cmd(i: int, type: StringName, args: Dictionary = {}) -> Dictionary:
	var seq: int = clients[i].submit(type, args)
	until(func(): return clients[i].results.has(seq))
	return clients[i].results.get(seq, {"ok": false, "error": "no_answer"})

func items_total() -> Dictionary:
	var t: Dictionary = {}
	for a in st.actors.values():
		for k in a["inv"]:
			t[k] = int(t.get(k, 0)) + int(a["inv"][k])
	for h in st.holdings.values():
		for k in h["store"]:
			t[k] = int(t.get(k, 0)) + int(h["store"][k])
	for d in st.drops.values():
		for k in d:
			t[k] = int(t.get(k, 0)) + int(d[k])
	return t
