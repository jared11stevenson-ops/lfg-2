extends RulesTestBase
## Creature companions (data/companions.json, rules/companions.gd): six original creatures, solo-obtainable, PEACE helpers with a small bounded Purge role,
## commands adopt/feed/assign/dismiss, saved on the leader. Nothing needs a trade or another player; no combat power.

const KINDS: Array[String] = ["mossbun", "dewsnail", "truffler", "glowmoth", "brindlehen", "bristlepup"]
const WORDS: Array[String] = ["friendship", "reputation", "bond_level", "relationship", "betrayal_penalty"]

func _id(k: String) -> String:
	return "lfg:companion/" + k

func _poi(s: MatchState, poi_type: String) -> Dictionary:
	for p in s.world["pois"]:
		if String(p["type"]) == poi_type:
			return p
	return {}

## Puts the leader next to a POI of that type, discovered, and returns it.
func _visit(s: MatchState, poi_type: String) -> Dictionary:
	var p: Dictionary = _poi(s, poi_type)
	var a: Dictionary = s.actors[1]
	a["hex"] = p["hex"]
	if not (a.get("pois_seen", []) as Array).has(int(p["id"])):
		a["pois_seen"] = a.get("pois_seen", [])
		(a["pois_seen"] as Array).append(int(p["id"]))
	return p

func _adopt(s: MatchState, kind: String) -> Dictionary:
	return cmd(s, "adopt_companion", {"companion": _id(kind)})

func _home_hex(s: MatchState) -> Vector2i:
	return home(s)["hex"]

# ------------------------------------------------------------------ data
func test_six_original_creatures_each_with_a_solo_way_in() -> void:
	var order: Array = Content.companion_order()
	eq(order.size(), 6, "six companions")
	var names: Dictionary = {}
	for k in KINDS:
		var d: Dictionary = Content.companion(_id(k))
		check(not d.is_empty(), "%s exists" % k)
		names[String(d["name"])] = true
		check(String(d["blurb"]).length() > 30, "%s: a blurb" % k)
		check((d["colors"] as Array).size() == 3, "%s: three model colours" % k)
		check(not (d["obtain"] as Array).is_empty(), "%s: obtainable" % k)
		for o in d["obtain"]:
			match String(o["kind"]):
				"quest":
					check(not Content.quest(String(o["quest"])).is_empty(), "%s: the gift quest exists" % k)
					eq(String(Content.quest(String(o["quest"]))["reward"].get("companion", "")), _id(k), "%s: that quest really gives it" % k)
				"feed":
					check(Content.poi_types().has(String(o["poi"])), "%s: haunt %s is a POI type" % [k, o["poi"]])
					check(not Content.item(String(o["item"])).is_empty() and int(o["qty"]) >= 1, "%s: feeding item" % k)
					check(int(Content.item(String(o["item"])).get("food", 0)) > 0, "%s: only food is offered" % k)
					check(int(Content.crop(String(o["item"]).replace("item", "crop")).get("rank", 0)) <= 0 or Content.crop(String(o["item"]).replace("item", "crop")).is_empty(), "%s: no rank-gated crop needed" % k)
				_:
					check(false, "%s: unknown obtain kind %s" % [k, o["kind"]])
		for it in d["diet"]:
			check(not Content.item(String(it)).is_empty(), "%s eats a real item %s" % [k, it])
		check((d["diet"] as Array).has(String(d["fave"])), "%s: the favourite is on the menu" % k)
		check(d.has("follow") and d.has("post") and d.has("purge"), "%s: follow/post/purge blocks" % k)
		check(not d["purge"].has("damage") and not d["purge"].has("atk"), "%s: no combat power" % k)
		check(Companions.role_text(_id(k)) != "", "%s: role text" % k)
	eq(names.size(), 6, "six distinct names")
	for w in WORDS:
		check(not FileAccess.get_file_as_string("res://data/companions.json").to_lower().contains(w), "no %s in the data" % w)
		check(not FileAccess.get_file_as_string("res://rules/companions.gd").to_lower().contains(w), "no %s in the rules" % w)

func test_each_role_family_exists_across_the_six() -> void:
	var fam: Dictionary = {}
	for k in KINDS:
		var d: Dictionary = Content.companion(_id(k))
		for r in d["follow"].keys():
			fam["follow_" + String(r)] = true
		for r in d["post"].keys():
			fam["post_" + String(r)] = true
		for r in d["purge"].keys():
			fam["purge_" + String(r)] = true
	for need in ["follow_carry", "follow_discover", "post_tend", "post_haul", "post_forage", "post_produce", "purge_defense", "purge_tend"]:
		check(fam.has(need), "a creature with %s" % need)

# ------------------------------------------------------------------ adopting
func test_adopt_by_feeding_at_the_haunt_consumes_the_food() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	eq(_adopt(s, "mossbun")["error"], "not_here", "not at a farm")
	_visit(s, "lfg:poi/derelict_farm")
	eq(_adopt(s, "mossbun")["error"], "insufficient_items", "no sporebeans in the pack")
	give(s, 1, {"lfg:item/sporebean": 3})
	var r: Dictionary = _adopt(s, "mossbun")
	check(r["ok"], "adopted: %s" % r["error"])
	eq(count_type(r["events"], "companion_adopted"), 1, "event")
	eq(Inv.count(a["inv"], "lfg:item/sporebean"), 0, "three sporebeans eaten")
	eq(Companions.list_of(a).size(), 1, "one companion")
	eq(String(Companions.list_of(a)[0]["post"]), "follow", "it follows")
	eq(_adopt(s, "mossbun")["error"], "already_have", "one of each")
	eq(_adopt(s, "nope")["error"], "unknown_companion", "unknown")

func test_not_discovered_or_too_far_and_guarded_haunts_refuse() -> void:
	var s: MatchState = quiet()
	var p: Dictionary = _poi(s, "lfg:poi/derelict_farm")
	s.actors[1]["hex"] = p["hex"]
	give(s, 1, {"lfg:item/sporebean": 3})
	eq(_adopt(s, "mossbun")["error"], "not_here", "undiscovered places do not count")
	_visit(s, "lfg:poi/derelict_farm")
	s.actors[1]["hex"] = p["hex"] + Vector2i(5, 0)
	eq(_adopt(s, "mossbun")["error"], "not_here", "too far")
	# a cave with living guards
	var cave: Dictionary = _visit(s, "lfg:poi/fungal_cave")
	give(s, 1, {"lfg:item/mushroom": 2})
	var ir: Dictionary = cmd(s, "interact_poi", {"poi": cave["id"]})
	check(ir["ok"], "wake the cave")
	eq(_adopt(s, "truffler")["error"], "not_here", "the sporelings are still there")
	for gid in s.poi_state[int(cave["id"])]["guards"]:
		Combat.kill(s, int(gid), 1, [])
	check(_adopt(s, "truffler")["ok"], "after the guards fall the cave is calm")

func test_every_creature_can_be_adopted_by_a_solo_leader_of_any_class() -> void:
	for cid in ["lfg:class/judd", "lfg:class/pip", "lfg:class/halo", "lfg:class/vex"]:
		var s: MatchState = quiet(String(cid))
		s.actors[1]["max_hp"] = 9999
		var got: int = 0
		for k in KINDS:
			var d: Dictionary = Content.companion(_id(k))
			var feed_opt: Dictionary = {}
			for o in d["obtain"]:
				if String(o["kind"]) == "feed":
					feed_opt = o
			if feed_opt.is_empty():
				continue
			var p: Dictionary = _visit(s, String(feed_opt["poi"]))
			for gid in s.poi_state.get(int(p["id"]), {}).get("guards", []):
				Combat.kill(s, int(gid), 1, [])
			give(s, 1, {String(feed_opt["item"]): int(feed_opt["qty"])})
			var r: Dictionary = _adopt(s, k)
			if r["error"] == "no_room_for_companion":
				Companions.list_of(s.actors[1]).pop_back()      # make room: this test is about the way in
				r = _adopt(s, k)
			check(r["ok"], "%s adopts %s (%s)" % [cid, k, r["error"]])
			got += 1
		eq(got, 6, "%s: six feeding routes (Mossbun has two ways in)" % cid)
	# Mossbun's other way in is the quest gift (see test_onboarding)

func test_capacity_two_then_kennel_then_cap() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	eq(Companions.capacity(s, a), 2, "two places at the start")
	for k in ["mossbun", "dewsnail"]:
		eq(Companions.give(s, a, _id(k), []), "", "give %s" % k)
	_visit(s, "lfg:poi/fungal_cave")
	give(s, 1, {"lfg:item/mushroom": 2})
	eq(_adopt(s, "truffler")["error"], "no_room_for_companion", "full")
	home(s)["buildings"].append("lfg:building/kennel")
	eq(Companions.capacity(s, a), 4, "a kennel adds two")
	check(_adopt(s, "truffler")["ok"], "now there is room")
	# a second holding with a kennel, and the hard cap
	for hid in s.holdings.keys():
		if int(hid) != 1:
			s.holdings[hid]["owner"] = 0
			s.holdings[hid]["buildings"].append("lfg:building/kennel")
	eq(Companions.capacity(s, a), 6, "never more than six")

# ------------------------------------------------------------------ feeding, assigning, dismissing
func test_feed_rules() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	Companions.give(s, a, _id("mossbun"), [])
	var c: Dictionary = Companions.find(a, _id("mossbun"))
	eq(cmd(s, "feed_companion", {"companion": _id("mossbun"), "item": "lfg:item/ration"})["error"], "wont_eat", "mossbun does not eat rations")
	eq(cmd(s, "feed_companion", {"companion": _id("mossbun"), "item": "lfg:item/sporebean"})["error"], "insufficient_items", "none in the pack")
	eq(cmd(s, "feed_companion", {"companion": _id("nobody"), "item": "lfg:item/sporebean"})["error"], "no_such_companion", "not owned")
	give(s, 1, {"lfg:item/sporebean": 9, "lfg:item/glowfruit": 2})
	var f0: int = int(c["fed_until"])
	check(cmd(s, "feed_companion", {"companion": _id("mossbun"), "item": "lfg:item/glowfruit"})["ok"], "glowfruit is fine")
	eq(int(c["fed_until"]), f0 + 3, "three more days")
	check(cmd(s, "feed_companion", {"companion": _id("mossbun"), "item": "lfg:item/sporebean"})["ok"], "its favourite")
	eq(int(c["fed_until"]), f0 + 3 + 6, "the favourite lasts six days")
	var guard: int = 0
	while cmd(s, "feed_companion", {"companion": _id("mossbun"), "item": "lfg:item/sporebean"})["ok"] and guard < 10:
		guard += 1
	check(int(c["fed_until"]) <= int(s.clock["day"]) + 13, "banked food is capped at two weeks")
	eq(cmd(s, "feed_companion", {"companion": _id("mossbun"), "item": "lfg:item/sporebean"})["error"], "already_full", "full")

func test_assign_follow_hold_rest_and_limits() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	for k in ["mossbun", "dewsnail", "truffler"]:
		Companions.give(s, a, _id(k), [])
	eq(Companions.followers(a), 2, "the third one stayed behind")
	eq(String(Companions.find(a, _id("truffler"))["post"]), "rest", "resting")
	eq(cmd(s, "assign_companion", {"companion": _id("truffler"), "mode": "follow"})["error"], "followers_full", "two followers at most")
	check(cmd(s, "assign_companion", {"companion": _id("mossbun"), "mode": "rest"})["ok"], "rest")
	check(cmd(s, "assign_companion", {"companion": _id("truffler"), "mode": "follow"})["ok"], "now it fits")
	eq(cmd(s, "assign_companion", {"companion": _id("mossbun"), "mode": "hold"})["error"], "unknown_holding", "which holding?")
	eq(cmd(s, "assign_companion", {"companion": _id("mossbun"), "mode": "hold", "holding": 9999})["error"], "unknown_holding", "no such holding")
	var other: int = -1
	for hid in s.holdings.keys():
		if int(s.holdings[hid]["owner"]) != 0:
			other = int(hid)
			break
	eq(cmd(s, "assign_companion", {"companion": _id("mossbun"), "mode": "hold", "holding": other})["error"], "not_yours", "not your holding")
	a["hex"] = _home_hex(s) + Vector2i(6, 0)
	eq(cmd(s, "assign_companion", {"companion": _id("mossbun"), "mode": "hold", "holding": 1})["error"], "not_near_own_holding", "too far")
	a["hex"] = _home_hex(s)
	var r: Dictionary = cmd(s, "assign_companion", {"companion": _id("mossbun"), "mode": "hold", "holding": 1})
	check(r["ok"], "posted: %s" % r["error"])
	eq(int(Companions.find(a, _id("mossbun"))["hold"]), 1, "at holding 1")
	eq(cmd(s, "assign_companion", {"companion": _id("mossbun"), "mode": "dance"})["error"], "bad_mode", "bad mode")
	eq(count_type(r["events"], "companion_assigned"), 1, "event")

func test_dismiss_frees_the_place() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	Companions.give(s, a, _id("mossbun"), [])
	eq(cmd(s, "dismiss_companion", {"companion": _id("dewsnail")})["error"], "no_such_companion", "not owned")
	var r: Dictionary = cmd(s, "dismiss_companion", {"companion": _id("mossbun")})
	check(r["ok"], "dismissed")
	eq(Companions.list_of(a).size(), 0, "gone")
	eq(count_type(r["events"], "companion_dismissed"), 1, "event")
	var s2: MatchState = quiet()
	var before: String = snap(s2)
	cmd(s2, "dismiss_companion", {"companion": _id("mossbun")})
	cmd(s2, "adopt_companion", {"companion": _id("mossbun")})
	cmd(s2, "assign_companion", {"companion": _id("mossbun"), "mode": "follow"})
	cmd(s2, "feed_companion", {"companion": _id("mossbun"), "item": "lfg:item/ration"})
	var b: Dictionary = JSON.parse_string(before)
	var af: Dictionary = JSON.parse_string(snap(s2))
	b["actors"]["1"]["last_seq"] = 0
	af["actors"]["1"]["last_seq"] = 0
	check(b == af, "failed companion commands change nothing")

# ------------------------------------------------------------------ what they do in peace
func _post(s: MatchState, kind: String, hid: int = 1) -> void:
	Companions.give(s, s.actors[1], _id(kind), [])
	var c: Dictionary = Companions.find(s.actors[1], _id(kind))
	c["post"] = "hold"
	c["hold"] = hid

func test_dewsnail_waters_plots_before_they_would_wither() -> void:
	var s: MatchState = quiet()
	_post(s, "dewsnail")
	var keys: Array = []
	for i in range(4):
		var hx: Vector2i = neighbor_plot(s, i)
		s.plots[MatchState.plot_key(hx)] = {"crop": "lfg:crop/glowfruit", "age": 0, "watered": false, "dry_days": 0, "holding": 1}
		keys.append(MatchState.plot_key(hx))
	var ev: Array = []
	Sim.dawn(s, ev)
	var watered_work: int = 0
	for e in ev:
		if String(e["type"]) == "companion_work" and String(e["work"]) == "tend":
			watered_work = int(e["plots"])
	eq(watered_work, 3, "three plots a dawn")
	var grown: int = 0
	var dry: int = 0
	for k in keys:
		if int(s.plots[k]["age"]) == 1:
			grown += 1
		else:
			dry += 1
			eq(int(s.plots[k]["dry_days"]), 1, "the fourth went thirsty")
	eq(grown, 3, "three plots grew")
	eq(dry, 1, "one did not")

func test_hauler_forager_and_hen_bring_things_home() -> void:
	var s: MatchState = quiet()
	var store: Dictionary = home(s)["store"]
	_post(s, "mossbun")
	_post(s, "truffler")
	_post(s, "brindlehen")
	var e0: int = Inv.count(store, "lfg:item/egg")
	var total0: int = Inv.total(store)
	var ev: Array = []
	Companions.dawn(s, ev)
	eq(Inv.count(store, "lfg:item/egg"), e0 + 1, "an egg")
	var brought: int = 0
	for e in ev:
		if String(e["type"]) == "companion_work" and String(e["work"]) == "bring":
			for k in (e["items"] as Dictionary).keys():
				brought += int(e["items"][k])
	eq(brought, 3, "three things in all (haul 1, forage 1, egg 1)")
	eq(Inv.total(store) - total0 + _eaten(ev), 3, "the larder grew by exactly what they brought")

## Rations/foods the companions ate from the store at this dawn (so the larder arithmetic stays honest).
func _eaten(ev: Array) -> int:
	var n: int = 0
	for e in ev:
		if String(e["type"]) == "companion_fed" and bool(e.get("auto", false)):
			n += 1
	return n

func test_foraging_den_adds_one_find() -> void:
	var s: MatchState = quiet()
	_post(s, "truffler")
	var ev: Array = []
	Sim.dawn(s, ev)
	var base: int = 0
	for e in ev:
		if String(e["type"]) == "companion_work" and String(e["work"]) == "bring":
			for k in (e["items"] as Dictionary).keys():
				base += int(e["items"][k])
	eq(base, 1, "one find without a den")
	home(s)["buildings"].append("lfg:building/foraging_den")
	var ev2: Array = []
	Sim.dawn(s, ev2)
	var more: int = 0
	for e in ev2:
		if String(e["type"]) == "companion_work" and String(e["work"]) == "bring":
			for k in (e["items"] as Dictionary).keys():
				more += int(e["items"][k])
	eq(more, 2, "a den: two finds")

func test_unfed_companions_rest_and_hungry_event_fires_once() -> void:
	var s: MatchState = quiet()
	_post(s, "brindlehen")
	var c: Dictionary = Companions.find(s.actors[1], _id("brindlehen"))
	c["fed_until"] = 0
	c["fed"] = true
	var store: Dictionary = home(s)["store"]
	Inv.remove_all(store, {"lfg:item/sporebean": Inv.count(store, "lfg:item/sporebean"), "lfg:item/saltroot": Inv.count(store, "lfg:item/saltroot"), "lfg:item/glowfruit": Inv.count(store, "lfg:item/glowfruit")})
	warp(s, 3)
	var ev: Array = []
	Companions.dawn(s, ev)
	eq(count_type(ev, "companion_hungry"), 1, "hungry")
	eq(Inv.count(store, "lfg:item/egg"), 0, "no egg for a hungry hen")
	check(not bool(c["fed"]), "flag")
	var ev2: Array = []
	Companions.dawn(s, ev2)
	eq(count_type(ev2, "companion_hungry"), 0, "told once")
	check(Companions.summary(s.actors[1]).contains("hungry"), "the tracker says so")

func test_posted_companions_eat_from_the_holding_store_and_followers_from_the_pack() -> void:
	var s: MatchState = quiet()
	_post(s, "brindlehen")
	Companions.give(s, s.actors[1], _id("mossbun"), [])
	for c in Companions.list_of(s.actors[1]):
		c["fed_until"] = 0
	home(s)["store"]["lfg:item/saltroot"] = 2
	give(s, 1, {"lfg:item/sporebean": 1})
	warp(s, 4)
	var ev: Array = []
	Companions.dawn(s, ev)
	eq(count_type(ev, "companion_fed"), 2, "both ate")
	eq(Inv.count(home(s)["store"], "lfg:item/saltroot"), 1, "the hen's favourite came from the larder")
	eq(Inv.count(s.actors[1]["inv"], "lfg:item/sporebean"), 0, "the follower ate from the pack")
	for c in Companions.list_of(s.actors[1]):
		check(int(c["fed_until"]) >= 4, "fed through today")

func test_a_lost_holding_sends_the_creature_to_rest_not_away() -> void:
	var s: MatchState = quiet()
	_post(s, "dewsnail")
	home(s)["owner"] = -1
	Companions.dawn(s, [])
	eq(String(Companions.find(s.actors[1], _id("dewsnail"))["post"]), "rest", "rests")

func test_dawn_through_the_sim_runs_the_work() -> void:
	var s: MatchState = mk("lfg:class/judd", 11, {"ai_enabled": false, "wild_enemies": false, "day_seconds": 20.0})
	_post(s, "brindlehen")
	tick_all(s, 21.0, 1.0)      # one full day: the dawn hook is wired into Sim
	check(Inv.count(home(s)["store"], "lfg:item/egg") >= 1, "the hen laid through the real dawn")

# ------------------------------------------------------------------ following effects
func test_follower_carry_bonus_only_when_fed_and_following() -> void:
	var s: MatchState = quiet("lfg:class/pip")
	var a: Dictionary = s.actors[1]
	var base: int = Inv.carry_cap(a)
	check(base > 0, "Pip has a pack limit")
	Companions.give(s, a, _id("mossbun"), [])
	eq(Inv.carry_cap(a), base + 10, "+10 with Mossbun at heel")
	Companions.give(s, a, _id("truffler"), [])
	eq(Inv.carry_cap(a), base + 14, "capped at +14")
	Companions.find(a, _id("mossbun"))["fed"] = false
	eq(Inv.carry_cap(a), base + 4, "a hungry one carries nothing")
	Companions.find(a, _id("truffler"))["post"] = "rest"
	eq(Inv.carry_cap(a), base, "a resting one carries nothing")
	var j: MatchState = quiet("lfg:class/judd")
	Companions.give(j, j.actors[1], _id("mossbun"), [])
	eq(Inv.carry_cap(j.actors[1]), 0, "classes without a pack limit stay unlimited")

func test_glowmoth_finds_places_farther_away() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	var p: Dictionary = {}
	for q in s.world["pois"]:
		if String(q["type"]) == "lfg:poi/shrine":
			p = q
			break
	var r: int = Pois.radius()
	var start: Vector2i = p["hex"]
	var away: Vector2i = Vector2i(-9999, -9999)
	for d in HexGrid.ring_within(start, r + 2):
		if HexGrid.distance(d, start) == r + 2 and HexGrid.in_bounds(d) and WorldGen.move_cost(s.world, d) > 0.0:
			away = d
			break
	a["hex"] = away
	a["pois_seen"] = []
	var ev: Array = []
	Pois.discover_near(s, a, ev)
	check(not (a["pois_seen"] as Array).has(int(p["id"])), "not seen without the moth")
	Companions.give(s, a, _id("glowmoth"), [])
	Pois.discover_near(s, a, ev)
	check((a["pois_seen"] as Array).has(int(p["id"])), "seen with the moth")

# ------------------------------------------------------------------ the Purge role is small and bounded
func test_defense_bonus_is_small_capped_and_player_only() -> void:
	var s: MatchState = quiet()
	var h: Dictionary = home(s)
	var base: float = Conquest.defender_power(s, h)
	_post(s, "bristlepup")
	eq(Conquest.defender_power(s, h), base + 3.0, "Bristlepup steadies the garrison by 3 (one troop)")
	_post(s, "glowmoth")
	_post(s, "truffler")
	var sum_uncapped: float = 3.0 + 2.0 + 1.0
	eq(sum_uncapped, 6.0, "the three together hit the cap exactly")
	eq(Conquest.defender_power(s, h), base + 6.0, "capped at 6")
	home(s)["buildings"].append("lfg:building/kennel")
	_post(s, "mossbun")
	_post(s, "dewsnail")
	eq(Conquest.defender_power(s, h), base + 6.0, "still capped with five posted")
	Companions.find(s.actors[1], _id("bristlepup"))["fed"] = false
	check(Conquest.defender_power(s, h) < base + 6.0 + 0.01, "a hungry one does not count")
	for hid in s.holdings.keys():
		if int(s.holdings[hid]["owner"]) > 0:
			var before: float = Conquest.defender_power(s, s.holdings[hid])
			eq(Companions.defense_bonus(s, s.holdings[hid]), 0.0, "AI holdings never get a bonus")
			eq(before, Conquest.defender_power(s, s.holdings[hid]), "unchanged")
			break

func test_following_companions_count_near_a_holding_only() -> void:
	var s: MatchState = quiet()
	var h: Dictionary = home(s)
	Companions.give(s, s.actors[1], _id("bristlepup"), [])
	var base: float = Companions.defense_bonus(s, h)
	eq(base, 3.0, "at the door")
	s.actors[1]["hex"] = h["hex"] + Vector2i(5, 0)
	eq(Companions.defense_bonus(s, h), 0.0, "away with the leader it does not help")

func test_companions_add_no_combat_power() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	var snap_stats: Array = [a["atk"], a["def"], a["max_hp"], Combat.atk_of(s, a), Combat.def_of(s, a)]
	var actors0: int = s.actors.size()
	for k in KINDS:
		Companions.give(s, a, _id(k), [])
	eq([a["atk"], a["def"], a["max_hp"], Combat.atk_of(s, a), Combat.def_of(s, a)], snap_stats, "stats are exactly the same")
	eq(s.actors.size(), actors0, "companions are not actors: nothing can be targeted or killed")
	var e: int = Setup.spawn_enemy(s, "lfg:enemy/rootbrute", a["hex"] + HexGrid.DIRS[0], false)
	var dmg: int = Combat.calc_damage(s, a, s.actors[e])
	eq(dmg, maxi(1, int(round(float(a["atk"]) * float(Combat.class_mod(a, "atk_mult", 1.0)) - float(s.actors[e]["def"])))), "the same damage with a full kennel")

func test_dewsnail_tends_purgebloom_when_the_purge_begins() -> void:
	var s: MatchState = quiet()
	_post(s, "dewsnail")
	var hx: Vector2i = home(s)["hex"] + HexGrid.DIRS[0] * 3
	for i in range(4):
		var h2: Vector2i = home(s)["hex"] + HexGrid.DIRS[i] * 2
		s.plots[MatchState.plot_key(h2)] = {"crop": "lfg:crop/purgebloom", "age": 0, "watered": false, "dry_days": 0, "holding": 1}
	var ev: Array = []
	Companions.purge_start(s, ev)
	var tended: int = 0
	for k in s.plots.keys():
		if bool(s.plots[k].get("tended", false)):
			tended += 1
	eq(tended, 3, "three blooms tended")
	eq(count_type(ev, "companion_work"), 1, "event")

# ------------------------------------------------------------------ saves and old saves
func test_companions_survive_a_save_and_old_saves_load() -> void:
	var s: MatchState = quiet()
	_post(s, "mossbun")
	Companions.give(s, s.actors[1], _id("glowmoth"), [])
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var s2: MatchState = MatchState.from_dict(d)
	check(same(s, s2), "round trip keeps everything")
	eq(Companions.list_of(s2.actors[1]).size(), 2, "both there")
	eq(int(Companions.find(s2.actors[1], _id("mossbun"))["hold"]), 1, "ints stay ints")
	# an old save has no "companions" key at all
	var old: MatchState = quiet()
	check(not old.actors[1].has("companions"), "fresh leaders carry no field")
	eq(Companions.list_of(old.actors[1]).size(), 0, "reads tolerate it")
	eq(Companions.capacity(old, old.actors[1]), 2, "capacity works")
	eq(Companions.carry_bonus(old.actors[1]), 0, "carry")
	eq(Companions.discover_bonus(old.actors[1]), 0, "discover")
	var m: Dictionary = Companions.panel_model(old, old.actors[1])
	eq((m["wild"] as Array).size(), 6, "six to meet")
	eq((m["owned"] as Array).size(), 0, "none owned")
	tick_all(old, 5.0, 1.0)
	check(old.actors[1]["alive"], "the sim runs")

func test_panel_model_describes_owned_and_wild() -> void:
	var s: MatchState = quiet()
	_post(s, "dewsnail")
	Companions.give(s, s.actors[1], _id("mossbun"), [])
	var m: Dictionary = Companions.panel_model(s, s.actors[1])
	eq(int(m["slots_used"]), 2, "two used")
	eq(int(m["slots"]), 2, "of two")
	eq((m["owned"] as Array).size(), 2, "owned rows")
	eq((m["wild"] as Array).size(), 4, "wild rows")
	for row in m["owned"]:
		check(String(row["role"]) != "" and String(row["name"]) != "" and (row["diet"] as Array).size() > 0, "owned row complete")
	var dew: Dictionary = {}
	for row in m["owned"]:
		if String(row["kind"]) == _id("dewsnail"):
			dew = row
	eq(String(dew["hold_name"]), String(home(s)["name"]), "posted at home")
	for row in m["wild"]:
		check((row["hints"] as Array).size() >= 1 and String(row["hints"][0]) != "", "every wild creature says how to meet it")
	check((m["holdings"] as Array).size() >= 1, "holdings to post to")

func test_companions_do_not_perturb_the_ai_world() -> void:
	# a match with AI on: the player's creatures must not change anything for the AI factions (they have none)
	var a: MatchState = mk("lfg:class/judd", 11, {"wild_enemies": false})
	var b: MatchState = mk("lfg:class/judd", 11, {"wild_enemies": false})
	Companions.give(b, b.actors[1], _id("mossbun"), [])
	tick_all(a, 20.0, 1.0)
	tick_all(b, 20.0, 1.0)
	for fid in a.factions.keys():
		if int(fid) > 0:
			eq(JSON.stringify(a.factions[fid]), JSON.stringify(b.factions[fid]), "faction %d unchanged" % fid)
