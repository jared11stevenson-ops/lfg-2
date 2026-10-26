extends TestCase
## Persistence against the REAL MatchState/Rules (no fake).
const ROOT := "user://t_persist_real"

func before_each() -> void:
	Persist.root = ROOT
	ClassLink.overrides = {}
	Persist.clear_slot(0)
	Persist.clear_slot(1)

func after_each() -> void:
	Persist.clear_slot(0)
	Persist.clear_slot(1)

func _match() -> MatchState:
	return Rules.new_match(99, &"lfg:class/judd", {"ai_enabled": false, "wild_enemies": false})

func test_real_state_saves_and_loads_through_class_link() -> void:
	var st: MatchState = _match()
	Rules.tick(st, 12.0)
	Rules.apply(st, {"type": &"eat", "actor": 1, "seq": 1, "args": {"item": "lfg:item/ration"}})
	check(Persist.save_match(0, st)["ok"], "saved")
	var l: Dictionary = Persist.load_match(0)
	check(l["ok"], "loaded")
	check(l["state"] is MatchState, "rebuilt as real MatchState")
	var once: Dictionary = (l["state"] as MatchState).to_dict()
	eq(int(once["actors"]["1"]["last_seq"]), 1, "applied seq persisted")
	eq(once["actors"]["1"]["inv"]["lfg:item/ration"], st.actors[1]["inv"]["lfg:item/ration"], "inventory persisted")
	eq(once["clock"]["elapsed"], st.clock["elapsed"], "clock persisted")
	# resumed state keeps working under Rules
	var r: Dictionary = Rules.apply(l["state"], {"type": &"eat", "actor": 1, "seq": 2, "args": {"item": "lfg:item/ration"}})
	check(r["ok"], "loaded state accepts new commands")
	var dup: Dictionary = Rules.apply(l["state"], {"type": &"eat", "actor": 1, "seq": 2, "args": {}})
	check(not dup["ok"], "and still rejects replayed seq")

func test_real_leader_death_event_ends_the_slot() -> void:
	var st: MatchState = _match()
	Persist.save_match(1, st)
	var events: Array = []
	Combat.hurt(st, 1, 100000, -1, events, "test")
	var over: Array = events.filter(func(e): return e["type"] == &"match_over")
	check(over.size() > 0, "real rules emit match_over on leader death")
	check(Persist.handle_events(1, events), "handled")
	eq(Persist.load_match(1)["error"], "match_over", "dead leader's match cannot be resumed")
	check(not Persist.save_match(1, st)["ok"], "and cannot be overwritten")
