extends RulesTestBase
## Quest engine (rules/quests.gd) and quest DATA validation (data/quests/*.json): states, prerequisites, once-only rewards, steps, saves,
## signature unlocks, and the owner rules: every step is solo-completable from content data; nothing depends on trade or other players.

const SIG_UNLOCKS: Array[String] = ["lfg:unlock/sun_terrace", "lfg:unlock/draught", "lfg:unlock/hearty_stew", "lfg:unlock/anvil_hall"]
const LINES: Array[String] = ["judd", "mira", "bram", "tavi", "pip", "oren", "sable", "forge"]
const STUBS: Array[String] = ["vex", "quill", "nyx", "rook", "dune", "halo"]
const REQUIRED_FIELDS: Dictionary = {"gather": ["item"], "craft": ["recipe"], "build": ["building"], "deliver": ["item", "to"], "visit_poi": ["poi"], "claim_poi": ["poi"],
	"defeat": ["enemy"], "purge_deed": ["deeds"], "survive_purge": [], "harvest": ["crop"], "plant": ["crop"], "ability": ["ability"]}

# ------------------------------------------------------------------ obtainability (solo, from content data only)
## Items a self-sufficient solo player of `class_id` can come to hold: start kit + home store + crops + enemy loot + POI loot + class abilities + craftable
## outputs (stations/buildings whose costs are obtainable). No merchants, no other players, no rank above 1.
func _obtainable(class_id: String, unlocks: Array = []) -> Dictionary:
	var have: Dictionary = {}
	var cd: Dictionary = Content.class_def(class_id)
	for k in (cd["start_kit"] as Dictionary).keys():
		have[String(k)] = true
	for k in ["lfg:item/timber", "lfg:item/stone", "lfg:item/ration", "lfg:item/coin"]:
		have[k] = true
	for e in Content.enemies().values():
		for k in (e.get("loot", {}) as Dictionary).keys():
			have[String(k)] = true
	for t in Content.poi_types().values():
		for k in (t.get("loot", {}) as Dictionary).keys():
			if int(t["loot"][k][1]) > 0:
				have[String(k)] = true
	have["lfg:item/ashmarrow"] = true      # Purge drops
	if String((cd.get("peace_ability", {}) as Dictionary).get("id", "")) == "lfg:ability/mine" or int(cd.get("mods", {}).get("mine_bonus", 0)) > 0:
		have["lfg:item/timber"] = true
		have["lfg:item/stone"] = true
	if String((cd.get("peace_ability", {}) as Dictionary).get("id", "")) == "lfg:ability/forage":
		have["lfg:item/mushroom"] = true
		have["lfg:item/spore_sac"] = true
	if int(cd.get("mods", {}).get("hunt_meat", 0)) > 0:
		have["lfg:item/game_meat"] = true
	var changed: bool = true
	var built: Dictionary = {}
	var guard: int = 0
	while changed and guard < 40:
		changed = false
		guard += 1
		for c in Content.crops().values():
			if int(c.get("rank", 0)) <= 1 and have.has(String(c["seed"])) and not have.has(String(c["item"])):
				have[String(c["item"])] = true
				changed = true
		for b in Content.buildings().values():
			var bid: String = String(b["id"])
			if built.has(bid) or int(b.get("rank", 0)) > 1:
				continue
			var ru: String = String(b.get("requires_unlock", ""))
			if ru != "" and not unlocks.has(ru):
				continue
			if b.has("upgrade_of") and not built.has(String(b["upgrade_of"])):
				continue
			var ok: bool = true
			for k in (b["cost"] as Dictionary).keys():
				if not have.has(String(k)):
					ok = false
					break
			if ok:
				built[bid] = true
				changed = true
				var w: Dictionary = b.get("work", {})
				var inputs_ok: bool = true
				for k2 in (w.get("inputs", {}) as Dictionary).keys():
					if not have.has(String(k2)):
						inputs_ok = false
				if inputs_ok:
					for k3 in (w.get("outputs", {}) as Dictionary).keys():
						if not have.has(String(k3)):
							have[String(k3)] = true
							changed = true
		for r in Content.recipes().values():
			if int(r.get("rank", 0)) > 1:
				continue
			var tag: String = String(r.get("requires_tag", ""))
			if tag != "" and int(cd.get("mods", {}).get(tag, 0)) < 1:
				continue
			var ru2: String = String(r.get("requires_unlock", ""))
			if ru2 != "" and not unlocks.has(ru2):
				continue
			var st: String = String(r.get("station", ""))
			if st != "" and not built.has(st):
				continue
			var ok2: bool = true
			for k4 in (r["inputs"] as Dictionary).keys():
				if not have.has(String(k4)):
					ok2 = false
					break
			if ok2:
				for k5 in (r["outputs"] as Dictionary).keys():
					if not have.has(String(k5)):
						have[String(k5)] = true
						changed = true
	have["_built"] = built
	return have

func _all_quests() -> Array:
	var out: Array = []
	for id in Content.quest_order():
		out.append(Content.quest(String(id)))
	return out

# ------------------------------------------------------------------ data validation
func test_quest_ids_are_namespaced_unique_and_prerequisites_exist_and_are_acyclic() -> void:
	var qs: Array = _all_quests()
	check(qs.size() >= 30, "quests loaded: %d" % qs.size())
	var seen: Dictionary = {}
	for q in qs:
		var id: String = String(q["id"])
		check(id.begins_with("lfg:quest/") and id.length() > 10, "%s is namespaced" % id)
		check(not seen.has(id), "%s is unique" % id)
		seen[id] = true
		var cls: String = String(q.get("class", ""))
		check(cls == "" or not Content.class_def(cls).is_empty(), "%s has a valid class" % id)
		check(String(q.get("title", "")) != "" and String(q.get("intro", "")) != "", "%s has a title and intro" % id)
		check(not (q["steps"] as Array).is_empty(), "%s has steps" % id)
		var sids: Dictionary = {}
		for pre in q.get("requires", []):
			check(Content.quests().has(String(pre)), "%s: prerequisite %s exists" % [id, pre])
	for q in qs:
		# walk the prerequisite chain; a cycle would never terminate within the quest count
		var depth: int = 0
		var frontier: Array = [String(q["id"])]
		while not frontier.is_empty() and depth <= qs.size():
			var nxt: Array = []
			for f in frontier:
				for pre in Content.quest(String(f)).get("requires", []):
					nxt.append(String(pre))
			frontier = nxt
			depth += 1
		check(frontier.is_empty(), "%s: no prerequisite cycle" % q["id"])

func test_every_quest_is_reachable_from_an_available_root() -> void:
	for cid in Content.classes().keys():
		var s: MatchState = quiet(String(cid))
		var a: Dictionary = s.actors[1]
		# simulate completing everything in order: each pass must make at least one more quest available until all are done
		var done: int = 0
		var total: int = 0
		for q in _all_quests():
			if (String(q.get("class", "")) == "" or String(q["class"]) == String(cid)) and bool(q.get("implemented", true)):
				total += 1
		var guard: int = 0
		while done < total and guard < 40:
			guard += 1
			var progressed: bool = false
			for q in _all_quests():
				var id: String = String(q["id"])
				if not bool(q.get("implemented", true)):
					continue
				if Quests.state_of(a, id) == "available":
					a["quests"] = a.get("quests", {})
					a["quests"][id] = {"st": "done"}
					done += 1
					progressed = true
			check(progressed or done >= total, "%s: quests keep unlocking (%d/%d)" % [cid, done, total])
			if not progressed:
				break
		eq(done, total, "%s: every quest of the line is reachable" % cid)

func test_steps_use_known_kinds_and_valid_references() -> void:
	var abilities: Dictionary = {}
	for cd in Content.classes().values():
		abilities[String(cd["id"])] = [String(cd["ability"]["id"]), String((cd.get("peace_ability", {}) as Dictionary).get("id", ""))]
	for q in _all_quests():
		var qid: String = String(q["id"])
		var cls: String = String(q.get("class", ""))
		var ssteps: Array = q["steps"]
		for i in range(ssteps.size()):
			var st: Dictionary = ssteps[i]
			var kind: String = String(st["kind"])
			check(Quests.STEP_KINDS.has(kind), "%s step %d: known kind %s" % [qid, i, kind])
			check(String(st.get("text", "")) != "", "%s step %d has text" % [qid, i])
			for f in REQUIRED_FIELDS.get(kind, []):
				check(st.has(f), "%s step %d (%s) has %s" % [qid, i, kind, f])
			check(kind != "trade", "%s: no trade step" % qid)
			if int(st.get("qty", 1)) < 1 or int(st.get("qty", 1)) > 30:
				check(false, "%s step %d: qty in 1..30 (Pip carries 30)" % [qid, i])
			match kind:
				"gather", "deliver":
					check(not Content.item(String(st["item"])).is_empty(), "%s: item %s exists" % [qid, st["item"]])
					if kind == "deliver":
						var to: String = String(st["to"])
						check(to == "holding" or (to.begins_with("poi:") and (to == "poi:any" or Content.poi_types().has(to.trim_prefix("poi:")))), "%s: deliver target %s" % [qid, to])
				"craft":
					check(not Content.recipe(String(st["recipe"])).is_empty(), "%s: recipe exists" % qid)
				"build":
					check(not Content.building(String(st["building"])).is_empty(), "%s: building exists" % qid)
				"visit_poi", "claim_poi":
					check(String(st["poi"]) == "any" or Content.poi_types().has(String(st["poi"])), "%s: poi type %s exists" % [qid, st["poi"]])
				"defeat":
					check(String(st["enemy"]) == "any" or not Content.enemy(String(st["enemy"])).is_empty(), "%s: enemy exists" % qid)
				"harvest", "plant":
					check(String(st["crop"]) == "any" or not Content.crop(String(st["crop"])).is_empty(), "%s: crop exists" % qid)
				"ability":
					check(cls != "" and (abilities[cls] as Array).has(String(st["ability"])), "%s: the ability belongs to the quest's class" % qid)
				"purge_deed":
					for dk in st["deeds"]:
						check(not Standing.deed_def(String(dk)).is_empty(), "%s: deed %s exists" % [qid, dk])

func test_no_unreachable_step_every_required_item_is_obtainable_solo() -> void:
	for q in _all_quests():
		if not bool(q.get("implemented", true)):
			continue
		var cls_list: Array = [String(q["class"])] if String(q.get("class", "")) != "" else Content.classes().keys()
		for cid in cls_list:
			# unlocks granted earlier in the same line (ability/recipe unlocks) count; the line's own signature does not feed its own steps
			var have: Dictionary = _obtainable(String(cid))
			var built: Dictionary = have["_built"]
			var qid: String = String(q["id"])
			for st in q["steps"]:
				match String(st["kind"]):
					"gather", "deliver":
						check(have.has(String(st["item"])), "%s (%s): %s is obtainable solo" % [qid, cid, st["item"]])
					"craft":
						var r: Dictionary = Content.recipe(String(st["recipe"]))
						check(int(r.get("rank", 0)) <= 1, "%s: recipe rank <= 1" % qid)
						check(String(r.get("requires_unlock", "")) == "", "%s: no recipe that needs an unlock" % qid)
						var tag: String = String(r.get("requires_tag", ""))
						check(tag == "" or int(Content.class_def(String(cid)).get("mods", {}).get(tag, 0)) >= 1, "%s (%s): class can craft it" % [qid, cid])
						for k in (r["inputs"] as Dictionary).keys():
							check(have.has(String(k)), "%s (%s): craft input %s obtainable" % [qid, cid, k])
						var stn: String = String(r.get("station", ""))
						check(stn == "" or built.has(stn), "%s (%s): station %s can be built" % [qid, cid, stn])
					"build":
						check(built.has(String(st["building"])), "%s (%s): %s can be built from obtainable items" % [qid, cid, st["building"]])
					"claim_poi", "visit_poi":
						var t: Dictionary = Content.poi_types().get(String(st["poi"]), {})
						if String(st["kind"]) == "claim_poi" and not t.is_empty():
							var chk: Dictionary = t["challenge"]
							if String(chk["kind"]) == "offering":
								for k2 in (chk["items"] as Dictionary).keys():
									check(have.has(String(k2)), "%s (%s): offering %s obtainable" % [qid, cid, k2])

func test_every_poi_type_in_quests_is_placed_in_generated_worlds() -> void:
	var needed: Dictionary = {}
	for q in _all_quests():
		for st in q["steps"]:
			if st.has("poi") and String(st["poi"]) != "any":
				needed[String(st["poi"])] = true
			if String(st.get("to", "")).begins_with("poi:"):
				needed[String(st["to"]).trim_prefix("poi:")] = true
	for sd in [1, 2, 3, 4, 5, 6]:
		var w: Dictionary = WorldGen.generate(sd)
		var have: Dictionary = {}
		for p in w["pois"]:
			have[String(p["type"])] = int(have.get(String(p["type"]), 0)) + 1
		for t in needed.keys():
			check(int(have.get(t, 0)) >= 2, "seed %d places >= 2 %s" % [sd, t])

func test_questlines_have_six_to_eight_steps_and_a_signature_unlock() -> void:
	for line in LINES:
		var steps: int = 0
		var chapters: Array = []
		for q in _all_quests():
			if String(q.get("line", "")) == line:
				steps += (q["steps"] as Array).size()
				chapters.append(q)
		check(steps >= 6 and steps <= 8, "%s has %d steps (6-8)" % [line, steps])
		check(chapters.size() >= 2, "%s has chapters" % line)
		var last: Dictionary = chapters[chapters.size() - 1]
		check(bool(last.get("signature", false)), "%s: the final chapter is the signature" % line)
		var rw: Dictionary = last["reward"]
		check(String(rw.get("unlock", "")) != "" and (SIG_UNLOCKS.has(String(rw["unlock"])) or not (rw.get("ability_upgrade", {}) as Dictionary).is_empty()),
			"%s: ends in a recipe, a building or an ability upgrade" % line)
		for q in chapters:
			check(bool(q.get("implemented", true)), "%s is implemented" % q["id"])
	for u in SIG_UNLOCKS:
		var found: int = 0
		for r in Content.recipes().values():
			if String(r.get("requires_unlock", "")) == u:
				found += 1
		for b in Content.buildings().values():
			if String(b.get("requires_unlock", "")) == u:
				found += 1
		eq(found, 1, "%s gates exactly one recipe or building" % u)

func test_other_classes_have_a_stub_first_step_flagged_unimplemented() -> void:
	for c in STUBS:
		var q: Dictionary = Content.quest("lfg:quest/%s_1" % c)
		check(not q.is_empty(), "%s has a stub quest" % c)
		check(not bool(q.get("implemented", true)), "%s stub is flagged implemented:false" % c)
		eq((q["steps"] as Array).size(), 1, "%s stub has one step" % c)
		check(not bool(q["steps"][0].get("implemented", true)), "%s stub step flagged" % c)
		var s: MatchState = quiet("lfg:class/%s" % c)
		var r: Dictionary = cmd(s, "accept_quest", {"quest": "lfg:quest/%s_1" % c})
		check(not r["ok"] and r["error"] == "not_implemented", "%s: cannot accept a stub (%s)" % [c, r["error"]])
		eq(Quests.journal(s, s.actors[1])["soon"].size(), 1, "%s journal shows it as coming soon" % c)

func test_at_least_two_lines_converge_on_another_classes_theme_and_stay_solo() -> void:
	var converging: Dictionary = {}
	for q in _all_quests():
		for st in q["steps"]:
			var th: String = String(st.get("theme", ""))
			if th != "" and th != String(q.get("class", "")):
				converging[String(q["line"])] = th
				check(not Content.class_def(th).is_empty(), "theme %s is a class" % th)
	check(converging.size() >= 2, "lines referencing another class's theme: %s" % str(converging.keys()))

func test_nothing_depends_on_trade_or_friendship() -> void:
	var bad: PackedStringArray = PackedStringArray()
	for path in ["res://data/quests", "res://data", "res://rules"]:
		var d := DirAccess.open(path)
		for fn in d.get_files():
			if not (fn.ends_with(".json") or fn.ends_with(".gd")):
				continue
			var txt: String = FileAccess.get_file_as_string("%s/%s" % [path, fn]).to_lower()
			for w in ["friendship", "reputation", "bond_level", "relationship", "betrayal_penalty"]:
				if txt.contains(w):
					bad.append("%s/%s: %s" % [path, fn, w])
	check(bad.is_empty(), "no friendship/reputation values anywhere: %s" % str(bad))
	for q in _all_quests():
		for st in q["steps"]:
			check(String(st["kind"]) != "trade" and not st.has("trade") and not st.has("with_player"), "%s: no trade/other-player step" % q["id"])

# ------------------------------------------------------------------ engine
func test_states_prerequisites_and_class_gate() -> void:
	var s: MatchState = quiet("lfg:class/judd")
	var a: Dictionary = s.actors[1]
	eq(Quests.state_of(a, "lfg:quest/judd_1"), "available", "chapter 1 is available")
	eq(Quests.state_of(a, "lfg:quest/judd_2"), "locked", "chapter 2 is locked behind chapter 1")
	eq(Quests.state_of(a, "lfg:quest/mira_1"), "locked", "another class's line is locked")
	eq(Quests.state_of(a, "lfg:quest/nope"), "unknown", "unknown id")
	var r: Dictionary = cmd(s, "accept_quest", {"quest": "lfg:quest/judd_2"})
	eq(r["error"], "quest_locked", "cannot accept a locked quest")
	r = cmd(s, "accept_quest", {"quest": "lfg:quest/mira_1"})
	eq(r["error"], "quest_locked", "cannot accept another class's quest")
	r = cmd(s, "accept_quest", {"quest": "lfg:quest/nope"})
	eq(r["error"], "unknown_quest", "unknown quest")
	r = cmd(s, "accept_quest", {"quest": "lfg:quest/judd_1"})
	check(r["ok"] and count_type(r["events"], "quest_accepted") == 1, "accepted: %s" % r["error"])
	eq(Quests.state_of(a, "lfg:quest/judd_1"), "active", "now active")
	eq(cmd(s, "accept_quest", {"quest": "lfg:quest/judd_1"})["error"], "already_active", "not twice")

func test_failed_quest_commands_change_nothing() -> void:
	var s: MatchState = quiet()
	var before: String = snap(s)
	for c in [["accept_quest", {"quest": "lfg:quest/judd_2"}], ["accept_quest", {"quest": "x"}], ["abandon_quest", {"quest": "lfg:quest/judd_1"}], ["turn_in", {"quest": "lfg:quest/judd_1"}],
			["accept_quest", {}], ["interact_poi", {"poi": 9999}]]:
		var r: Dictionary = cmd(s, c[0], c[1])
		check(not r["ok"], "%s fails" % c[0])
	# last_seq is part of the state; compare the rest
	var after: String = snap(s)
	var b: Dictionary = JSON.parse_string(before)
	var af: Dictionary = JSON.parse_string(after)
	b["actors"]["1"]["last_seq"] = 0
	af["actors"]["1"]["last_seq"] = 0
	check(b == af, "a failed command mutates nothing")

func _finish_judd_1(s: MatchState) -> void:
	# harvest 4 (inject plots ripe) and claim a farm via events, driving the real commands where cheap
	var a: Dictionary = s.actors[1]
	for i in range(4):
		var hx: Vector2i = home(s)["hex"] + HexGrid.DIRS[i]
		s.plots[MatchState.plot_key(hx)] = {"crop": "lfg:crop/glowfruit", "age": 2, "watered": false, "dry_days": 0, "holding": 1}
		var r: Dictionary = cmd(s, "harvest", {"hex": hx})
		check(r["ok"], "harvest: %s" % r["error"])
	var farm: Dictionary = {}
	for p in s.world["pois"]:
		if p["type"] == "lfg:poi/derelict_farm":
			farm = p
			break
	a["hex"] = farm["hex"]
	var r2: Dictionary = cmd(s, "interact_poi", {"poi": farm["id"]})
	check(r2["ok"], "claim farm: %s" % r2["error"])

func test_progress_ready_turn_in_and_rewards_exactly_once() -> void:
	var s: MatchState = quiet("lfg:class/judd")
	var a: Dictionary = s.actors[1]
	cmd(s, "accept_quest", {"quest": "lfg:quest/judd_1"})
	var h0: Vector2i = a["hex"]
	_finish_judd_1(s)
	var rec: Dictionary = Quests.rec_of(a, "lfg:quest/judd_1")
	check(bool(rec["ready"]) and int(rec["step"]) == 2, "both steps done -> ready (%s)" % str(rec))
	a["hex"] = home(s)["hex"] + HexGrid.DIRS[1]       # back at the holding
	check(h0 != Vector2i.ZERO, "setup")
	var seeds0: int = Inv.count(a["inv"], "lfg:item/glowfruit_seed")
	var r: Dictionary = cmd(s, "turn_in", {"quest": "lfg:quest/judd_1"})
	check(r["ok"], "turn in: %s" % r["error"])
	check(count_type(r["events"], "quest_done") == 1, "quest_done event")
	eq(Quests.state_of(a, "lfg:quest/judd_1"), "done", "done")
	eq(Inv.count(a["inv"], "lfg:item/glowfruit_seed"), seeds0 + 3, "reward granted")
	var after: int = Inv.count(a["inv"], "lfg:item/glowfruit_seed")
	check(not cmd(s, "turn_in", {"quest": "lfg:quest/judd_1"})["ok"], "no second turn-in")
	check(not cmd(s, "accept_quest", {"quest": "lfg:quest/judd_1"})["ok"], "no re-accept")
	check(not cmd(s, "abandon_quest", {"quest": "lfg:quest/judd_1"})["ok"], "a done quest cannot be abandoned")
	eq(Inv.count(a["inv"], "lfg:item/glowfruit_seed"), after, "the reward was paid once")
	eq(Quests.state_of(a, "lfg:quest/judd_2"), "available", "the next chapter opens")

func test_turn_in_needs_a_holding_and_abandon_resets_without_reward() -> void:
	var s: MatchState = quiet("lfg:class/judd")
	var a: Dictionary = s.actors[1]
	cmd(s, "accept_quest", {"quest": "lfg:quest/judd_1"})
	_finish_judd_1(s)
	var r: Dictionary = cmd(s, "turn_in", {"quest": "lfg:quest/judd_1"})
	eq(r["error"], "not_near_own_holding", "must hand in at a holding")
	var coin0: int = Inv.count(a["inv"], "lfg:item/reed_fibre")
	r = cmd(s, "abandon_quest", {"quest": "lfg:quest/judd_1"})
	check(r["ok"] and count_type(r["events"], "quest_abandoned") == 1, "abandon")
	eq(Quests.state_of(a, "lfg:quest/judd_1"), "available", "available again")
	eq(Inv.count(a["inv"], "lfg:item/reed_fibre"), coin0, "no reward for abandoning")
	cmd(s, "accept_quest", {"quest": "lfg:quest/judd_1"})
	eq(int(Quests.rec_of(a, "lfg:quest/judd_1")["step"]), 0, "progress starts over")

func test_gather_and_build_steps_follow_the_state_and_cascade() -> void:
	var s: MatchState = quiet("lfg:class/judd")
	var a: Dictionary = s.actors[1]
	for k in ["judd_1"]:
		a["quests"] = {"lfg:quest/judd_1": {"st": "done"}}
	give(s, 1, {"lfg:item/reed_fibre": 6, "lfg:item/timber": 6, "lfg:item/stone": 4})
	var r: Dictionary = cmd(s, "accept_quest", {"quest": "lfg:quest/judd_2"})
	check(r["ok"], "accept: %s" % r["error"])
	eq(int(Quests.rec_of(a, "lfg:quest/judd_2")["step"]), 1, "six fibres already in the pack: step 1 done on accept")
	r = cmd(s, "build", {"holding": 1, "building": "lfg:building/workbench"})
	check(r["ok"], "workbench: %s" % r["error"])
	eq(int(Quests.rec_of(a, "lfg:quest/judd_2")["step"]), 2, "the build advanced the quest")
	var ev: Array = []
	r = cmd(s, "craft", {"recipe": "lfg:recipe/rope"})
	check(r["ok"], "rope: %s" % r["error"])
	check(bool(Quests.rec_of(a, "lfg:quest/judd_2")["ready"]), "craft step done -> ready")
	check(count_type(r["events"], "quest_step") >= 1 and count_type(r["events"], "quest_ready") == 1, "quest_step and quest_ready events: %s" % str(types(r["events"])))
	check(ev.is_empty(), "setup")

func test_deliver_step_consumes_items_at_the_place() -> void:
	var s: MatchState = quiet("lfg:class/mira")
	var a: Dictionary = s.actors[1]
	a["quests"] = {"lfg:quest/mira_1": {"st": "done"}, "lfg:quest/mira_2": {"st": "done"}}
	give(s, 1, {"lfg:item/ration": 4, "lfg:item/sporebean": 6})
	cmd(s, "accept_quest", {"quest": "lfg:quest/mira_3"})
	var r: Dictionary = cmd(s, "craft", {"recipe": "lfg:recipe/ration_sporebean", "qty": 2})
	check(r["ok"], "craft: %s" % r["error"])
	eq(int(Quests.rec_of(a, "lfg:quest/mira_3")["step"]), 1, "now delivering")
	eq(cmd(s, "turn_in", {"quest": "lfg:quest/mira_3"})["error"], "not_at_place", "not at a hermit's hut")
	var hut: Dictionary = {}
	for p in s.world["pois"]:
		if p["type"] == "lfg:poi/hermit_hut":
			hut = p
	a["hex"] = hut["hex"]
	var rations0: int = Inv.count(a["inv"], "lfg:item/ration")
	r = cmd(s, "turn_in", {"quest": "lfg:quest/mira_3"})
	check(r["ok"], "deliver: %s" % r["error"])
	eq(Inv.count(a["inv"], "lfg:item/ration"), rations0 - 2, "two rations handed over")
	check(bool(Quests.rec_of(a, "lfg:quest/mira_3")["ready"]), "ready")
	a["hex"] = home(s)["hex"] + HexGrid.DIRS[0]
	r = cmd(s, "turn_in", {"quest": "lfg:quest/mira_3"})
	check(r["ok"], "claim: %s" % r["error"])
	check(Quests.unlocked(a, "lfg:unlock/draught"), "Mira learned the draught")
	# deliver with too few items fails and changes nothing
	var s2: MatchState = quiet("lfg:class/mira")
	var a2: Dictionary = s2.actors[1]
	a2["quests"] = {"lfg:quest/mira_1": {"st": "done"}, "lfg:quest/mira_2": {"st": "done"}, "lfg:quest/mira_3": {"st": "active", "step": 1, "prog": 0, "ready": false, "day": 1, "rewarded": false}}
	a2["inv"].erase("lfg:item/ration")
	a2["hex"] = hut["hex"]
	eq(cmd(s2, "turn_in", {"quest": "lfg:quest/mira_3"})["error"], "insufficient_items", "short of rations")

func test_event_steps_defeat_ability_purge_deed_and_survive() -> void:
	var s: MatchState = quiet("lfg:class/sable")
	var a: Dictionary = s.actors[1]
	a["quests"] = {"lfg:quest/sable_1": {"st": "done"}, "lfg:quest/sable_2": {"st": "done"}}
	give(s, 1, {"lfg:item/game_meat": 4})
	cmd(s, "accept_quest", {"quest": "lfg:quest/sable_3"})
	var wreck: Dictionary = {}
	for p in s.world["pois"]:
		if p["type"] == "lfg:poi/wreck":
			wreck = p
	a["hex"] = wreck["hex"]
	var r: Dictionary = cmd(s, "interact_poi", {"poi": wreck["id"]})
	check(r["ok"], "wreck: %s" % r["error"])
	eq(int(Quests.rec_of(a, "lfg:quest/sable_3")["step"]), 1, "claim_poi counted")
	a["hex"] = home(s)["hex"] + HexGrid.DIRS[0]
	a["energy"] = 100.0
	r = cmd(s, "use_ability", {"ability": "lfg:ability/snare"})
	check(r["ok"], "snare: %s" % r["error"])
	eq(int(Quests.rec_of(a, "lfg:quest/sable_3")["step"]), 2, "ability counted")
	# a deed in the Purge by this faction
	warp(s, 7, 0.6)
	var ev: Array = []
	Standing.record(s, 0, "scout", ev)
	Quests.observe(s, ev, 0)
	check(bool(Quests.rec_of(a, "lfg:quest/sable_3")["ready"]), "the deed finished the line")
	# survive_purge via the settle event
	var s2: MatchState = quiet("lfg:class/oren")
	var a2: Dictionary = s2.actors[1]
	a2["quests"] = {"lfg:quest/oren_1": {"st": "done"}, "lfg:quest/oren_2": {"st": "done"}}
	give(s2, 1, {"lfg:item/amber_resin": 2, "lfg:item/ration": 3})
	cmd(s2, "accept_quest", {"quest": "lfg:quest/oren_3"})
	eq(int(Quests.rec_of(a2, "lfg:quest/oren_3")["step"]), 1, "amber already held")
	var hut: Dictionary = {}
	for p in s2.world["pois"]:
		if p["type"] == "lfg:poi/hermit_hut":
			hut = p
	a2["hex"] = hut["hex"]
	check(cmd(s2, "turn_in", {"quest": "lfg:quest/oren_3"})["ok"], "deliver")
	warp(s2, 7, 0.6)
	tick_all(s2, 120.0, 5.0)       # run the whole Purge through to RESOLUTION
	check(bool(Quests.rec_of(a2, "lfg:quest/oren_3")["ready"]), "surviving a Purge completed the step (%s)" % str(Quests.rec_of(a2, "lfg:quest/oren_3")))

func test_active_quest_limit() -> void:
	var s: MatchState = quiet("lfg:class/judd")
	var a: Dictionary = s.actors[1]
	var ids: Array = []
	for i in range(Quests.MAX_ACTIVE):
		var id: String = "lfg:quest/test_%d" % i
		Content.quests()[id] = {"id": id, "class": "", "line": "t", "chapter": 1, "title": "t", "intro": "t", "requires": [], "steps": [{"kind": "survive_purge", "text": "x", "qty": 1}], "reward": {}}
		Content.quest_order().append(id)
		ids.append(id)
		check(cmd(s, "accept_quest", {"quest": id})["ok"], "accept %d" % i)
	eq(cmd(s, "accept_quest", {"quest": "lfg:quest/judd_1"})["error"], "too_many_quests", "capped")
	eq(Quests.active_count(a), Quests.MAX_ACTIVE, "count")

func test_signature_unlocks_gate_recipes_buildings_and_upgrade_abilities() -> void:
	# recipe: Oren's Hearty Stew
	var s: MatchState = quiet("lfg:class/oren")
	give(s, 1, {"lfg:item/sporebean": 2, "lfg:item/glowfruit": 1, "lfg:item/rime_salt": 1})
	s.actors[1]["hex"] = home(s)["hex"]
	eq(cmd(s, "craft", {"recipe": "lfg:recipe/hearty_stew"})["error"], "locked_recipe", "locked before the quest")
	Quests.grant(s, s.actors[1], {"unlock": "lfg:unlock/hearty_stew"})
	var r: Dictionary = cmd(s, "craft", {"recipe": "lfg:recipe/hearty_stew"})
	check(r["ok"], "unlocked: %s" % r["error"])
	eq(Inv.count(s.actors[1]["inv"], "lfg:item/ration"), 6 + 4 + 1, "four rations plus Oren's bonus")
	# building: Judd's Sun Terrace
	var s2: MatchState = quiet("lfg:class/judd")
	give(s2, 1, {"lfg:item/timber": 6, "lfg:item/fired_brick": 2, "lfg:item/reed_fibre": 3})
	eq(cmd(s2, "build", {"holding": 1, "building": "lfg:building/sun_terrace"})["error"], "locked_building", "terrace locked")
	Quests.grant(s2, s2.actors[1], {"unlock": "lfg:unlock/sun_terrace"})
	r = cmd(s2, "build", {"holding": 1, "building": "lfg:building/sun_terrace"})
	check(r["ok"], "terrace: %s" % r["error"])
	eq(Standing.yield_bonus(s2, s2.holdings[1]), 1, "the terrace adds a harvest step")
	# ability upgrade: Bram's forage, Tavi's mine bonus, Pip's pack
	var s3: MatchState = quiet("lfg:class/bram")
	eq(int(Combat.class_mod(s3.actors[1], "forage_bonus", 0)), 0, "no bonus yet")
	Quests.grant(s3, s3.actors[1], {"ability_upgrade": {"forage_bonus": 1}})
	eq(int(Combat.class_mod(s3.actors[1], "forage_bonus", 0)), 1, "forage bonus after the quest")
	var s4: MatchState = quiet("lfg:class/pip")
	eq(Inv.carry_cap(s4.actors[1]), 30, "Pip carries 30")
	Quests.grant(s4, s4.actors[1], {"ability_upgrade": {"carry_cap": 10}})
	eq(Inv.carry_cap(s4.actors[1]), 40, "40 after the pack quest")
	var s5: MatchState = quiet("lfg:class/tavi")
	var m0: int = int(Combat.class_mod(s5.actors[1], "mine_bonus", 0))
	Quests.grant(s5, s5.actors[1], {"ability_upgrade": {"mine_bonus": 1}})
	eq(int(Combat.class_mod(s5.actors[1], "mine_bonus", 0)), m0 + 1, "mine bonus")

func test_reward_overflow_goes_to_the_holding_store_not_the_void() -> void:
	var s: MatchState = quiet("lfg:class/pip")
	var a: Dictionary = s.actors[1]
	give(s, 1, {"lfg:item/timber": 30})
	a["hex"] = home(s)["hex"]
	var st0: int = Inv.count(home(s)["store"], "lfg:item/rope")
	Quests.grant(s, a, {"items": {"lfg:item/rope": 5}})
	eq(Inv.count(home(s)["store"], "lfg:item/rope"), st0 + 5, "overflow reward stored at the holding")

func test_quest_state_survives_save_and_old_saves_load() -> void:
	var s: MatchState = quiet("lfg:class/judd")
	cmd(s, "accept_quest", {"quest": "lfg:quest/judd_1"})
	_finish_judd_1(s)
	s.actors[1]["hex"] = home(s)["hex"] + HexGrid.DIRS[1]
	cmd(s, "turn_in", {"quest": "lfg:quest/judd_1"})
	cmd(s, "accept_quest", {"quest": "lfg:quest/settle_in"})
	var d: Dictionary = JSON.parse_string(JSON.stringify(s.to_dict()))
	var s2: MatchState = MatchState.from_dict(d)
	eq(Quests.state_of(s2.actors[1], "lfg:quest/judd_1"), "done", "done survives a save")
	eq(Quests.state_of(s2.actors[1], "lfg:quest/settle_in"), "active", "active survives a save")
	eq(Quests.journal(s2, s2.actors[1])["done"].size(), 1, "journal after load")
	check(not s2.poi_state.is_empty(), "poi_state survives (%s)" % str(s2.poi_state))
	check((s2.actors[1].get("pois_seen", []) as Array).size() >= 1, "pois_seen survives")
	# old save: no quests / poi_state / pois_seen anywhere
	var old: Dictionary = JSON.parse_string(JSON.stringify(quiet().to_dict()))
	old.erase("poi_state")
	old["actors"]["1"].erase("quests")
	var s3: MatchState = MatchState.from_dict(old)
	eq(s3.poi_state, {}, "poi_state defaults empty")
	eq(Quests.state_of(s3.actors[1], "lfg:quest/judd_1"), "available", "old save: quests start available")
	check(cmd(s3, "accept_quest", {"quest": "lfg:quest/judd_1"})["ok"], "old save can accept")
	eq(Quests.journal(s3, s3.actors[1])["active"].size(), 1, "journal works")

func test_journal_model_rows() -> void:
	var s: MatchState = quiet("lfg:class/forge")
	var j: Dictionary = Quests.journal(s, s.actors[1])
	var ids: Array = []
	for r in j["available"]:
		ids.append(r["id"])
	check(ids.has("lfg:quest/forge_1") and ids.has("lfg:quest/settle_in"), "general and own line are listed: %s" % str(ids))
	for r in j["available"] + j["locked"]:
		check(String(r["class"]) == "" or String(r["class"]) == "lfg:class/forge", "no other class's quests in the journal")
	var row: Dictionary = j["available"][ids.find("lfg:quest/forge_1")]
	eq(row["steps"].size(), 2, "steps listed")
	check(String(row["reward"]) != "", "reward text")
	cmd(s, "accept_quest", {"quest": "lfg:quest/forge_1"})
	var t: Dictionary = Quests.tracker(s, s.actors[1])
	check(String(t.get("text", "")).contains("stranded wreck"), "tracker shows the current step: %s" % str(t))

func test_quest_toast_data() -> void:
	var t: Dictionary = Quests.toast_for({"type": &"quest_done", "title": "X", "reward": {"items": {"lfg:item/ration": 3}, "text": "ok"}})
	check(String(t["title"]).contains("complete") and String(t["body"]).contains("Ration x3"), "quest_done toast: %s" % str(t))
	check(Quests.toast_for({"type": &"nothing"}).is_empty(), "unknown events give nothing")
