extends RulesTestBase
## First-10-minutes experience: the "welcome" quest chain (data/quests/tutorial.json, data/tutorial.json). Teaches plant / water / harvest / eat / craft / build and
## previews the Purge; played here with the real commands for every class. Nothing forces friendship or trade, and no step waits for a crop to grow.

const UI_KEYS: Array[String] = ["plot", "craft", "bag", "build", "hold", "journal", "purge_guide"]

func _chain() -> Array:
	return Quests.tutorial_quests()

func _kinds() -> Dictionary:
	var out: Dictionary = {}
	for qid in _chain():
		for st in Content.quest(String(qid))["steps"]:
			out[String(st["kind"])] = int(out.get(String(st["kind"]), 0)) + 1
	return out

func _plant_somewhere(s: MatchState, crop: String) -> Vector2i:
	for hx in HexGrid.ring_within(home(s)["hex"], 2):
		if HexGrid.distance(hx, home(s)["hex"]) < 1:
			continue
		var r: Dictionary = cmd(s, "plant", {"crop": crop, "hex": hx})
		if r["ok"]:
			return hx
	return Vector2i(-9999, -9999)

## Plays the four chapters with real commands. Returns the list of command types used.
func _play(s: MatchState) -> Array:
	var used: Array = []
	var a: Dictionary = s.actors[1]
	var go: Callable = func(t: String, args: Dictionary) -> Dictionary:
		used.append(t)
		return cmd(s, t, args)
	a["hex"] = home(s)["hex"]
	# chapter 1
	var r: Dictionary = go.call("accept_quest", {"quest": "lfg:quest/tut_1_furrow"}) if Quests.state_of(a, "lfg:quest/tut_1_furrow") == "available" else {"ok": true}
	check(r["ok"], "accept 1: %s" % r.get("error", ""))
	var ripe: Vector2i = Vector2i(-9999, -9999)
	for k in s.plots.keys():
		if int(s.plots[k]["age"]) >= 2:
			var parts: PackedStringArray = (k as String).split(",")
			ripe = Vector2i(int(parts[0]), int(parts[1]))
	check(ripe.x != -9999, "a ripe patch waits by the gate")
	r = go.call("harvest", {"hex": ripe})
	check(r["ok"], "harvest the gift patch: %s" % r["error"])
	var spot: Vector2i = Vector2i(-9999, -9999)
	for hx in HexGrid.ring_within(home(s)["hex"], 2):
		if HexGrid.distance(hx, home(s)["hex"]) < 1:
			continue
		used.append("plant")
		var pr: Dictionary = cmd(s, "plant", {"crop": "lfg:crop/glowfruit", "hex": hx})
		if pr["ok"]:
			spot = hx
			break
	check(spot.x != -9999, "somewhere to plant a glowfruit seed")
	r = go.call("water", {"hex": spot})
	check(r["ok"], "water: %s" % r["error"])
	check(bool(Quests.rec_of(a, "lfg:quest/tut_1_furrow").get("ready", false)), "chapter 1 is ready")
	r = go.call("turn_in", {"quest": "lfg:quest/tut_1_furrow"})
	check(r["ok"], "hand in 1: %s" % r["error"])
	# chapter 2
	r = go.call("accept_quest", {"quest": "lfg:quest/tut_2_warm"})
	check(r["ok"], "accept 2: %s" % r["error"])
	r = go.call("craft", {"recipe": "lfg:recipe/ration_glowfruit"})
	check(r["ok"], "cook: %s" % r["error"])
	r = go.call("eat", {"item": "lfg:item/ration"})
	check(r["ok"], "eat: %s" % r["error"])
	r = go.call("turn_in", {"quest": "lfg:quest/tut_2_warm"})
	check(r["ok"], "hand in 2: %s" % r["error"])
	# chapter 3
	r = go.call("accept_quest", {"quest": "lfg:quest/tut_3_roof"})
	check(r["ok"], "accept 3: %s" % r["error"])
	r = go.call("build", {"holding": 1, "building": "lfg:building/well"})
	check(r["ok"], "build the well: %s" % r["error"])
	r = go.call("turn_in", {"quest": "lfg:quest/tut_3_roof"})
	check(r["ok"], "hand in 3: %s" % r["error"])
	# chapter 4
	r = go.call("accept_quest", {"quest": "lfg:quest/tut_4_dusk"})
	check(r["ok"], "accept 4: %s" % r["error"])
	r = go.call("ack_tutorial", {"topic": "purge_preview"})
	check(r["ok"], "read the guide: %s" % r["error"])
	r = go.call("build", {"holding": 1, "building": "lfg:building/wall"})
	check(r["ok"], "palisade: %s" % r["error"])
	r = go.call("turn_in", {"quest": "lfg:quest/tut_4_dusk"})
	check(r["ok"], "hand in 4: %s" % r["error"])
	return used

# ------------------------------------------------------------------ data
func test_chain_teaches_the_six_verbs_and_previews_the_purge() -> void:
	eq(_chain().size(), 4, "four short chapters")
	var kinds: Dictionary = _kinds()
	for k in ["plant", "water", "harvest", "eat", "craft", "build", "ack"]:
		check(kinds.has(k), "teaches %s" % k)
	var card: Dictionary = (Quests.tutorial_cfg()["topics"] as Dictionary)["purge_preview"]
	var txt: String = " ".join(card["lines"]).to_lower()
	check(txt.contains("purge") and txt.contains("never have to fight") and txt.contains("warning"), "the Purge card: what it is, that fighting is optional, that there is a Warning")
	check(String(card["button"]) != "" and String(card["title"]) != "", "card has a title and a button")
	for qid in _chain():
		var q: Dictionary = Content.quest(String(qid))
		eq(String(q["class"]), "", "%s is for every class" % qid)
		eq(String(q["line"]), "welcome", "line")
		check(bool(q.get("implemented", true)), "implemented")
		for st in q["steps"]:
			check(String(st.get("prompt", "")) != "", "%s: every step has a UI prompt" % qid)
			check(UI_KEYS.has(String(st.get("ui", ""))), "%s: a known highlight (%s)" % [qid, st.get("ui", "")])
			check(String(st["kind"]) != "trade" and not st.has("with_player") and not st.has("trade"), "%s: no trade step" % qid)
			if String(st["kind"]) == "ack":
				check(Quests.TUTORIAL_TOPICS.has(String(st["topic"])), "known topic")
				check((Quests.tutorial_cfg()["topics"] as Dictionary).has(String(st["topic"])), "the topic has a card")

func test_no_step_waits_for_a_crop_or_a_purge_and_nothing_needs_other_people() -> void:
	var kinds: Dictionary = _kinds()
	check(not kinds.has("survive_purge") and not kinds.has("purge_deed") and not kinds.has("defeat"), "no waiting for, or fighting in, the Purge")
	var first: Dictionary = Content.quest("lfg:quest/tut_1_furrow")
	check(bool(first["on_accept"]["plot"]["ready"]), "the harvest is a gifted, already ripe patch")
	eq(String(first["steps"][0]["kind"]), "harvest", "harvest comes first")
	var bad: Array = []
	for f in ["res://data/quests/tutorial.json", "res://data/tutorial.json"]:
		var t: String = FileAccess.get_file_as_string(f).to_lower()
		for w in ["friend", "trade", "reputation", "relationship", "bond", "merchant", "ally "]:
			if t.contains(w):
				bad.append("%s: %s" % [f, w])
	eq(bad, [], "no friendship or trade words in the tutorial")

# ------------------------------------------------------------------ playing it
func test_every_class_finishes_the_chain_with_real_commands_and_no_trade() -> void:
	for cid in Content.classes().keys():
		var s: MatchState = quiet(String(cid))
		var used: Array = _play(s)
		var a: Dictionary = s.actors[1]
		for qid in _chain():
			eq(Quests.state_of(a, String(qid)), "done", "%s: %s done" % [cid, qid])
		check(not used.has("trade"), "%s: no trade command was used" % cid)
		check(not Companions.find(a, "lfg:companion/mossbun").is_empty(), "%s: the Mossbun gift arrived" % cid)
		check((a["titles"] as Array).has("Hearth Keeper"), "%s: title" % cid)
		check(Quests.tutorial_model(s, a).is_empty(), "%s: nothing left to teach" % cid)

func test_gifts_are_paid_once_even_if_a_chapter_is_abandoned_and_retaken() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	cmd(s, "accept_quest", {"quest": "lfg:quest/tut_1_furrow"})
	var plots0: int = s.plots.size()
	check(plots0 >= 1, "the patch is there")
	cmd(s, "abandon_quest", {"quest": "lfg:quest/tut_1_furrow"})
	cmd(s, "accept_quest", {"quest": "lfg:quest/tut_1_furrow"})
	eq(s.plots.size(), plots0, "a second acceptance does not add a second patch")
	# the same for an item gift
	cmd(s, "accept_quest", {"quest": "lfg:quest/tut_1_furrow"})
	a["quests"]["lfg:quest/tut_1_furrow"] = {"st": "done"}
	cmd(s, "accept_quest", {"quest": "lfg:quest/tut_2_warm"})
	var g1: int = Inv.count(a["inv"], "lfg:item/glowfruit")
	cmd(s, "abandon_quest", {"quest": "lfg:quest/tut_2_warm"})
	cmd(s, "accept_quest", {"quest": "lfg:quest/tut_2_warm"})
	eq(Inv.count(a["inv"], "lfg:item/glowfruit"), g1, "the basket comes once")

func test_new_match_option_starts_the_chain_and_default_does_not() -> void:
	var s: MatchState = mk("lfg:class/judd", 11, {"tutorial": true, "ai_enabled": false, "wild_enemies": false})
	eq(Quests.state_of(s.actors[1], "lfg:quest/tut_1_furrow"), "active", "accepted at the start")
	eq(Quests.tutorial_model(s, s.actors[1])["phase"], "active", "model: active")
	var d: MatchState = quiet()
	eq(Quests.state_of(d.actors[1], "lfg:quest/tut_1_furrow"), "available", "available by default")
	var m: Dictionary = Quests.tutorial_model(d, d.actors[1])
	eq(m["phase"], "offer", "model: offer")
	eq(m["quest"], "lfg:quest/tut_1_furrow", "first chapter offered")
	check(String(m["prompt"]) != "", "the offer has a prompt")

func test_tutorial_model_walks_through_offer_active_ready_and_card() -> void:
	var s: MatchState = quiet()
	var a: Dictionary = s.actors[1]
	cmd(s, "accept_quest", {"quest": "lfg:quest/tut_1_furrow"})
	var m: Dictionary = Quests.tutorial_model(s, a)
	eq(m["phase"], "active", "active")
	eq(m["ui"], "plot", "highlight the plots")
	eq(int(m["chapter"]), 1, "chapter 1 of 4")
	eq(int(m["chapters"]), 4, "of four")
	eq(int(m["steps"]), 3, "three steps")
	# fast-forward to chapter 4's ack step
	for q in ["lfg:quest/tut_1_furrow", "lfg:quest/tut_2_warm", "lfg:quest/tut_3_roof"]:
		a["quests"][q] = {"st": "done"}
	cmd(s, "accept_quest", {"quest": "lfg:quest/tut_4_dusk"})
	m = Quests.tutorial_model(s, a)
	eq(m["topic"], "purge_preview", "waiting for the guide")
	eq(m["ui"], "purge_guide", "highlight")
	check(not (m["card"] as Dictionary).is_empty() and (m["card"]["lines"] as Array).size() >= 3, "the card is attached")
	cmd(s, "ack_tutorial", {"topic": "purge_preview"})
	m = Quests.tutorial_model(s, a)
	eq(m["ui"], "build", "next: the palisade")
	cmd(s, "build", {"holding": 1, "building": "lfg:building/wall"})
	m = Quests.tutorial_model(s, a)
	eq(m["phase"], "ready", "ready to hand in")
	eq(m["ui"], "journal", "points at the journal")
	a["tutorial_off"] = true
	check(Quests.tutorial_model(s, a).is_empty(), "the player can switch it off")

func test_ack_tutorial_validates_and_is_idempotent() -> void:
	var s: MatchState = quiet()
	eq(cmd(s, "ack_tutorial", {"topic": "nonsense"})["error"], "unknown_topic", "unknown topic")
	eq(cmd(s, "ack_tutorial", {})["error"], "unknown_topic", "no topic")
	check(cmd(s, "ack_tutorial", {"topic": "controls"})["ok"], "controls")
	check(cmd(s, "ack_tutorial", {"topic": "controls"})["ok"], "again")
	eq((s.actors[1]["tutorial_seen"] as Array).size(), 1, "recorded once")
	cmd(s, "accept_quest", {"quest": "lfg:quest/tut_1_furrow"})
	cmd(s, "ack_tutorial", {"topic": "purge_preview"})
	eq(int(Quests.rec_of(s.actors[1], "lfg:quest/tut_1_furrow")["step"]), 0, "an ack does not skip other steps")
	check("ack_tutorial" in Rules.COMMAND_TYPES, "in the command list")

func test_chain_survives_a_save_and_old_saves_have_no_tutorial_fields() -> void:
	var s: MatchState = quiet()
	cmd(s, "accept_quest", {"quest": "lfg:quest/tut_1_furrow"})
	var s2: MatchState = MatchState.from_dict(JSON.parse_string(JSON.stringify(s.to_dict())))
	check(same(s, s2), "round trip")
	eq(Quests.tutorial_model(s2, s2.actors[1])["phase"], "active", "still on chapter 1")
	var old: MatchState = quiet()
	check(not old.actors[1].has("tutorial_seen") and not old.actors[1].has("gifted"), "no extra fields until used")
