class_name RulesTestBase
extends TestCase
## Shared helpers for rules tests.

func mk(class_id: String = "lfg:class/judd", sd: int = 11, opts: Dictionary = {}) -> MatchState:
	var o: Dictionary = {"day_seconds": 60.0}
	o.merge(opts, true)
	return Rules.new_match(sd, StringName(class_id), o)

func quiet(class_id: String = "lfg:class/judd", sd: int = 11) -> MatchState:
	return mk(class_id, sd, {"ai_enabled": false, "wild_enemies": false})

func cmd(s: MatchState, type: String, args: Dictionary = {}, actor: int = 1) -> Dictionary:
	var a: Dictionary = s.actors[actor]
	return Rules.apply(s, {"type": StringName(type), "actor": actor, "seq": int(a["last_seq"]) + 1, "args": args})

func snap(s: MatchState) -> String:
	return JSON.stringify(s.to_dict())

func warp(s: MatchState, day: int, tod: float = 0.0) -> void:
	s.clock["day"] = day
	s.clock["time_of_day"] = tod
	s.phase = Calendar.phase_for(day, tod)

func home(s: MatchState) -> Dictionary:
	return s.holdings[1]

func neighbor_plot(s: MatchState, i: int = 0) -> Vector2i:
	var hx: Vector2i = home(s)["hex"]
	return hx + HexGrid.DIRS[i]

func give(s: MatchState, actor: int, items: Dictionary) -> void:
	Inv.add_all(s.actors[actor]["inv"], items)

func types(events: Array) -> Array:
	var out: Array = []
	for e in events:
		out.append(String(e["type"]))
	return out

func count_type(events: Array, t: String) -> int:
	var n: int = 0
	for e in events:
		if String(e["type"]) == t:
			n += 1
	return n

func tick_all(s: MatchState, secs: float, step: float = 1.0) -> Array:
	var all: Array = []
	var left: float = secs
	while left > 1e-9:
		var d: float = minf(step, left)
		all.append_array(Rules.tick(s, d))
		left -= d
	return all
