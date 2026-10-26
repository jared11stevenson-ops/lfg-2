extends TestCase
## Shared harness (not a suite itself: no test_ methods). Real ENet over localhost, one process.
const Fake := preload("res://tests/net/fake_rules.gd")
var server: NetServer
var clients: Array[NetClient] = []
var port: int = 0
var tokens: Array[String] = []

func boot(n_players: int = 2) -> void:
	ClassLink.overrides = {"Rules": Fake, "MatchState": Fake.FakeState}
	Persist.root = "user://t_net"
	server = NetServer.new()
	var st: Object = Fake.new_match(7, &"lfg:class/judd")
	for tries in 20:
		port = 20000 + randi() % 20000
		if server.start(port, st, Fake) == OK:
			break
	for i in n_players:
		tokens.append(server.issue_token(i))

func connect_client(i: int) -> NetClient:
	var c := NetClient.new()
	c.connect_to("127.0.0.1", port, tokens[i])
	clients.append(c)
	return c

func pump(n: int = 20) -> void:
	for _i in n:
		server.poll()
		for c in clients:
			c.poll()
		OS.delay_msec(1)

func until(cond: Callable, max_iter: int = 400) -> bool:
	for _i in max_iter:
		pump(1)
		if cond.call():
			return true
	return false

func after_each() -> void:
	for c in clients:
		c.disconnect_now()
	clients.clear()
	if server != null:
		server.stop()
	ClassLink.overrides = {}
