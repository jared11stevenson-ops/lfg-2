class_name Quests
extends RefCounted
## Quest engine (data/quests/*.json, listed by data/quests/index.json). Quest state lives on the ACTOR: a["quests"][id] = {st:"active"|"done", step, prog, ready, day, rewarded}.
## A quest with no record is "locked" (prerequisite quest not done / wrong class) or "available". Old saves have no a["quests"]; every read tolerates that.
## Commands: accept_quest {quest}, abandon_quest {quest}, turn_in {quest}. Events: quest_accepted quest_step quest_ready quest_done quest_abandoned.
## Step kinds (see STEP_KINDS): gather (possession), build (state), visit_poi (state), craft/harvest/plant/ability/defeat/claim_poi/purge_deed/survive_purge (events),
## deliver (consumed by turn_in). Rewards are granted exactly once, at completion. Every step is solo-completable (tests/rules/test_quests.gd validates the data).
const MAX_ACTIVE := 6
const STEP_KINDS: Array[String] = ["gather", "craft", "build", "deliver", "visit_poi", "claim_poi", "defeat", "purge_deed", "survive_purge", "harvest", "plant", "ability",
	"water", "eat", "ack", "adopt", "guardian"]      # pass 4: the first-days chapters (water/eat/ack) and the creature/guardian chapters (adopt/guardian)
## Topics the UI may acknowledge with `ack_tutorial` (data/tutorial.json holds their text). A quest step of kind "ack" waits for one.
const TUTORIAL_TOPICS: Array[String] = ["purge_preview", "controls", "journal", "companions"]
const STATE_KINDS: Array[String] = ["gather", "build", "visit_poi"]       # satisfied by looking at the state, not by an event
const TURN_IN_RANGE := 3

static func def(id: String) -> Dictionary:
	return Content.quest(id)

static func rec_of(a: Dictionary, qid: String) -> Dictionary:
	return (a.get("quests", {}) as Dictionary).get(qid, {})

static func is_player(a: Dictionary) -> bool:
	return a.get("kind", "") == "leader" and not bool(a.get("is_ai", false))

static func unlocked(a: Dictionary, unlock_id: String) -> bool:
	return unlock_id == "" or (a.get("unlocks", []) as Array).has(unlock_id)

# ------------------------------------------------------------------ states
## "unknown" | "locked" | "available" | "active" | "done"
static func state_of(a: Dictionary, qid: String) -> String:
	var q: Dictionary = def(qid)
	if q.is_empty():
		return "unknown"
	var r: Dictionary = rec_of(a, qid)
	if not r.is_empty():
		return String(r["st"])
	var cls: String = String(q.get("class", ""))
	if cls != "" and cls != String(a.get("class_id", "")):
		return "locked"
	for pre in q.get("requires", []):
		if state_of(a, String(pre)) != "done":
			return "locked"
	return "available"

static func active_count(a: Dictionary) -> int:
	var n: int = 0
	for r in (a.get("quests", {}) as Dictionary).values():
		if r["st"] == "active":
			n += 1
	return n

static func step_def(q: Dictionary, idx: int) -> Dictionary:
	var steps: Array = q.get("steps", [])
	return steps[idx] if idx >= 0 and idx < steps.size() else {}

static func qty_of(step: Dictionary) -> int:
	return maxi(1, int(step.get("qty", 1)))

# ------------------------------------------------------------------ commands
static func accept(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	if not is_player(a):
		return "unknown_actor"
	var qid: String = CmdUtil.s(args.get("quest", ""))
	var st: String = state_of(a, qid)
	if st == "unknown":
		return "unknown_quest"
	if st == "locked":
		return "quest_locked"
	if st == "active":
		return "already_active"
	if st == "done":
		return "already_done"
	var q: Dictionary = def(qid)
	if not bool(q.get("implemented", true)):
		return "not_implemented"
	if active_count(a) >= MAX_ACTIVE:
		return "too_many_quests"
	if not a.has("quests"):
		a["quests"] = {}
	a["quests"][qid] = {"st": "active", "step": 0, "prog": 0, "ready": false, "day": int(state.clock["day"]), "rewarded": false}
	events.append({"type": &"quest_accepted", "actor": a["id"], "quest": qid, "title": q.get("title", qid)})
	_on_accept(state, a, q, events)
	settle(state, a, qid, events)
	return ""

## on_accept {items:{...}, plot:{crop, ready}}: a gift to get the chapter going (a basket, a ripe patch waiting by the gate). Never trade; nothing is taken.
static func _on_accept(state: MatchState, a: Dictionary, q: Dictionary, events: Array) -> void:
	var oa: Dictionary = q.get("on_accept", {})
	if oa.is_empty():
		return
	if (a.get("gifted", []) as Array).has(String(q["id"])):
		return      # abandon and re-accept does not pay the gift twice
	if not a.has("gifted"):
		a["gifted"] = []
	(a["gifted"] as Array).append(String(q["id"]))
	if oa.has("items"):
		grant(state, a, {"items": oa["items"]})
	if oa.has("plot"):
		var hid: int = CmdUtil.nearest_owned_holding(state, int(a["faction"]), a["hex"], 6)
		if hid == -1:
			hid = int(state.holdings_of(int(a["faction"]))[0]) if not state.holdings_of(int(a["faction"])).is_empty() else -1
		if hid != -1:
			var spot: Variant = free_plot_hex(state, state.holdings[hid])
			var crop: Dictionary = Content.crop(String(oa["plot"].get("crop", "")))
			if spot != null and not crop.is_empty():
				var age: int = int(crop["grow_days"]) if bool(oa["plot"].get("ready", false)) else 0
				state.plots[MatchState.plot_key(spot)] = {"crop": crop["id"], "age": age, "watered": false, "dry_days": 0, "holding": hid}
				events.append({"type": &"crop_planted", "actor": -1, "hex": spot, "crop": crop["id"], "gift": true})

## A hex next to a holding where a gifted plot can stand (ground, free of plots, holdings and buildings). null when the ring is full.
static func free_plot_hex(state: MatchState, hold: Dictionary) -> Variant:
	var cands: Array[Vector2i] = HexGrid.ring_within(hold["hex"], 2)
	cands.sort_custom(func(x: Vector2i, y: Vector2i) -> bool:
		var dx: int = HexGrid.distance(x, hold["hex"])
		var dy: int = HexGrid.distance(y, hold["hex"])
		return dx < dy or (dx == dy and HexGrid.index(x) < HexGrid.index(y)))
	for c in cands:
		if HexGrid.distance(c, hold["hex"]) < 1:
			continue
		if Economy.site_free(state, hold, c) == "" and not state.plots.has(MatchState.plot_key(c)) and not state.drops.has(MatchState.plot_key(c)):
			return c
	return null

## ack_tutorial {topic}: the UI says the player has read a tutorial card. Credits "ack" steps; harmless otherwise.
static func ack_tutorial(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	if not is_player(a):
		return "unknown_actor"
	var topic: String = CmdUtil.s(args.get("topic", ""))
	if not TUTORIAL_TOPICS.has(topic):
		return "unknown_topic"
	if not a.has("tutorial_seen"):
		a["tutorial_seen"] = []
	if not (a["tutorial_seen"] as Array).has(topic):
		(a["tutorial_seen"] as Array).append(topic)
	events.append({"type": &"tutorial_ack", "actor": a["id"], "topic": topic})
	return ""

static func abandon(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	var qid: String = CmdUtil.s(args.get("quest", ""))
	var r: Dictionary = rec_of(a, qid)
	if r.is_empty() or r["st"] != "active":
		return "not_active"
	(a["quests"] as Dictionary).erase(qid)
	events.append({"type": &"quest_abandoned", "actor": a["id"], "quest": qid})
	return ""

static func _near_own_holding(state: MatchState, a: Dictionary) -> bool:
	return CmdUtil.nearest_owned_holding(state, int(a["faction"]), a["hex"], TURN_IN_RANGE) != -1

## turn_in: hands in a finished quest at an own holding (claims the reward), or delivers the items of a `deliver` step.
static func turn_in(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	var qid: String = CmdUtil.s(args.get("quest", ""))
	var r: Dictionary = rec_of(a, qid)
	if r.is_empty() or r["st"] != "active":
		return "not_active"
	var q: Dictionary = def(qid)
	if bool(r["ready"]):
		if not _near_own_holding(state, a):
			return "not_near_own_holding"
		return complete(state, a, qid, events)
	var step: Dictionary = step_def(q, int(r["step"]))
	if String(step.get("kind", "")) != "deliver":
		return "nothing_to_turn_in"
	var to: String = String(step.get("to", "holding"))
	if to == "holding":
		if not _near_own_holding(state, a):
			return "not_near_own_holding"
	else:
		var want: String = to.trim_prefix("poi:")
		var ok: bool = false
		for p in Pois.all(state):
			if (want == "any" or String(p["type"]) == want) and HexGrid.distance(a["hex"], p["hex"]) <= 1:
				ok = true
				break
		if not ok:
			return "not_at_place"
	var need: Dictionary = {String(step["item"]): qty_of(step)}
	if not Inv.has_all(a["inv"], need):
		return "insufficient_items"
	Inv.remove_all(a["inv"], need)
	finish_step(state, a, qid, events)
	return ""

# ------------------------------------------------------------------ progress
static func finish_step(state: MatchState, a: Dictionary, qid: String, events: Array) -> void:
	var r: Dictionary = rec_of(a, qid)
	var q: Dictionary = def(qid)
	var idx: int = int(r["step"])
	r["step"] = idx + 1
	r["prog"] = 0
	var total: int = (q.get("steps", []) as Array).size()
	events.append({"type": &"quest_step", "actor": a["id"], "quest": qid, "step": idx, "text": step_def(q, idx).get("text", ""), "steps": total,
		"next": step_def(q, idx + 1).get("text", "") if idx + 1 < total else ""})
	if idx + 1 >= total:
		r["ready"] = true
		events.append({"type": &"quest_ready", "actor": a["id"], "quest": qid, "title": q.get("title", qid)})
	else:
		settle(state, a, qid, events)

## True when a state-based step is currently met; also reports its progress count.
static func _state_progress(state: MatchState, a: Dictionary, step: Dictionary) -> int:
	match String(step.get("kind", "")):
		"gather":
			return Inv.count(a["inv"], String(step["item"]))
		"build":
			for hid in state.holdings_of(int(a["faction"])):
				if (state.holdings[hid]["buildings"] as Array).has(String(step["building"])):
					return 1
			return 0
		"visit_poi":
			var want: String = String(step.get("poi", "any"))
			var n: int = 0
			for pid in a.get("pois_seen", []):
				var p: Dictionary = Pois.get_poi(state, int(pid))
				if not p.is_empty() and (want == "any" or String(p["type"]) == want):
					n += 1
			return n
	return 0

## Advances through any state-based steps that are already satisfied (cascades).
static func settle(state: MatchState, a: Dictionary, qid: String, events: Array) -> void:
	var guard: int = 0
	while guard < 16:
		guard += 1
		var r: Dictionary = rec_of(a, qid)
		if r.is_empty() or r["st"] != "active" or bool(r["ready"]):
			return
		var step: Dictionary = step_def(def(qid), int(r["step"]))
		var kind: String = String(step.get("kind", ""))
		if not STATE_KINDS.has(kind):
			return
		var have: int = _state_progress(state, a, step)
		r["prog"] = mini(have, qty_of(step))
		if have < qty_of(step):
			return
		finish_step(state, a, qid, events)

static func _credit(state: MatchState, a: Dictionary, qid: String, amount: int, events: Array) -> void:
	var r: Dictionary = rec_of(a, qid)
	var step: Dictionary = step_def(def(qid), int(r["step"]))
	r["prog"] = int(r["prog"]) + amount
	if int(r["prog"]) >= qty_of(step):
		finish_step(state, a, qid, events)

static func _matches(step: Dictionary, e: Dictionary, state: MatchState) -> int:
	## amount to credit when event `e` advances `step` (0 = no match)
	var ty: String = String(e.get("type", ""))
	match String(step.get("kind", "")):
		"craft":
			if ty == "item_crafted" and String(e.get("recipe", "")) == String(step["recipe"]):
				return maxi(1, int(e.get("qty", 1)))
		"harvest":
			if ty == "crop_harvested" and (String(step.get("crop", "any")) == "any" or String(e.get("crop", "")) == String(step["crop"])):
				return 1
		"plant":
			if ty == "crop_planted" and (String(step.get("crop", "any")) == "any" or String(e.get("crop", "")) == String(step["crop"])):
				return 1
		"ability":
			if ty == "ability_used" and String(e.get("ability", "")) == String(step["ability"]):
				return 1
		"claim_poi":
			if ty == "poi_claimed" and (String(step.get("poi", "any")) == "any" or String(e.get("poi_type", "")) == String(step["poi"])):
				return 1
		"defeat":
			if ty == "actor_died" and String(e.get("kind", "")) == "enemy":
				var v: Dictionary = state.actors.get(int(e["actor"]), {})
				if not v.is_empty() and (String(step.get("enemy", "any")) == "any" or String(v.get("archetype", "")) == String(step["enemy"])):
					return 1
		"purge_deed":
			if ty == "deed" and (step.get("deeds", []) as Array).has(String(e.get("kind", ""))):
				return 1
		"survive_purge":
			if ty == "purge_resolved":
				return 1
		"water":
			if ty == "crop_watered" and not bool(e.get("tended", false)):
				return 1
		"eat":
			if ty == "ate" and (String(step.get("item", "any")) == "any" or String(e.get("item", "")) == String(step["item"])):
				return maxi(1, int(e.get("qty", 1)))
		"ack":
			if ty == "tutorial_ack" and String(e.get("topic", "")) == String(step["topic"]):
				return 1
		"adopt":
			if ty == "companion_adopted" and (String(step.get("companion", "any")) == "any" or String(e.get("companion", "")) == String(step["companion"])):
				return 1
		"guardian":
			if ty == "guardian_defeated" and (String(step.get("guardian", "any")) == "any" or String(e.get("guardian", "")) == String(step["guardian"])):
				return 1
	return 0

## Event hook: credits the leaders' active quests. `from` = first event of this step/command. Cheap when nothing relevant happened.
static func observe(state: MatchState, events: Array, from: int, actor_hint: int = -1) -> void:
	var n: int = events.size()
	if n <= from and actor_hint < 0:
		return
	var touched: Dictionary = {}     # actor id -> true
	var credits: Array = []          # [actor id, event]
	for i in range(from, n):
		var e: Dictionary = events[i]
		var ty: String = String(e.get("type", ""))
		match ty:
			"item_crafted", "crop_harvested", "crop_planted", "ability_used", "poi_claimed", "poi_discovered", "built", "crop_watered", "ate", "tutorial_ack", "companion_adopted", "guardian_defeated":
				touched[int(e.get("actor", -1))] = true
				credits.append([int(e.get("actor", -1)), e])
			"actor_died":
				var kid: int = int(e.get("killer", -1))
				if kid >= 0:
					touched[kid] = true
					credits.append([kid, e])
			"deed":
				var l: Dictionary = Standing.leader_of(state, int(e.get("faction", -1)))
				if not l.is_empty():
					touched[int(l["id"])] = true
					credits.append([int(l["id"]), e])
			"purge_resolved":
				for id in state.actors.keys():
					var pa: Dictionary = state.actors[id]
					if is_player(pa) and pa["alive"]:
						touched[int(id)] = true
						credits.append([int(id), e])
	if actor_hint >= 0:
		touched[actor_hint] = true
	for pair in credits:
		var a: Dictionary = state.actors.get(int(pair[0]), {})
		if a.is_empty() or not is_player(a) or not a.has("quests"):
			continue
		var book: Dictionary = a["quests"]
		var ids: Array = book.keys()
		ids.sort()
		for qid in ids:
			var r: Dictionary = book[qid]
			if r["st"] != "active" or bool(r["ready"]):
				continue
			var amt: int = _matches(step_def(def(String(qid)), int(r["step"])), pair[1], state)
			if amt > 0:
				_credit(state, a, String(qid), amt, events)
	for aid in touched.keys():
		var a2: Dictionary = state.actors.get(int(aid), {})
		if a2.is_empty() or not is_player(a2) or not a2.has("quests"):
			continue
		var ids2: Array = (a2["quests"] as Dictionary).keys()
		ids2.sort()
		for qid2 in ids2:
			settle(state, a2, String(qid2), events)

# ------------------------------------------------------------------ rewards (exactly once)
static func complete(state: MatchState, a: Dictionary, qid: String, events: Array) -> String:
	var r: Dictionary = rec_of(a, qid)
	if r.is_empty() or r["st"] != "active" or bool(r.get("rewarded", false)):
		return "not_active"
	var q: Dictionary = def(qid)
	r["st"] = "done"
	r["rewarded"] = true
	r["ready"] = false
	var rw: Dictionary = q.get("reward", {})
	grant(state, a, rw)
	if String(rw.get("companion", "")) != "":
		Companions.give(state, a, String(rw["companion"]), events, "quest")
	events.append({"type": &"quest_done", "actor": a["id"], "quest": qid, "title": q.get("title", qid), "reward": rw.duplicate(true), "line": q.get("line", ""),
		"signature": bool(q.get("signature", false))})
	return ""

static func grant(state: MatchState, a: Dictionary, rw: Dictionary) -> void:
	var items: Dictionary = {}
	for k in (rw.get("items", {}) as Dictionary).keys():
		items[String(k)] = int(rw["items"][k])
	if not items.is_empty():
		if Inv.can_carry(a, items):
			Inv.add_all(a["inv"], items)
		else:
			var hid: int = CmdUtil.nearest_owned_holding(state, int(a["faction"]), a["hex"], 6)
			if hid != -1 and Inv.room_for(state.holdings[hid]["store"], items):
				Inv.add_all(state.holdings[hid]["store"], items)
			else:
				var k2: String = MatchState.plot_key(a["hex"])
				var cur: Dictionary = state.drops.get(k2, {})
				Inv.add_all(cur, items)
				state.drops[k2] = cur
	var un: String = String(rw.get("unlock", ""))
	if un != "":
		if not a.has("unlocks"):
			a["unlocks"] = []
		if not (a["unlocks"] as Array).has(un):
			(a["unlocks"] as Array).append(un)
	var up: Dictionary = rw.get("ability_upgrade", {})
	if not up.is_empty():
		if not a.has("quest_fx"):
			a["quest_fx"] = {}
		for k3 in up.keys():
			var cur_v: float = float(a["quest_fx"].get(k3, 0.0)) + float(up[k3])
			a["quest_fx"][k3] = int(cur_v) if cur_v == floorf(cur_v) else MatchState.q(cur_v)
	var title: String = String(rw.get("title", ""))
	if title != "":
		if not a.has("titles"):
			a["titles"] = []
		if not (a["titles"] as Array).has(title):
			(a["titles"] as Array).append(title)

# ------------------------------------------------------------------ view model (read only; ui/quest_panel.gd renders it)
static func _step_row(state: MatchState, a: Dictionary, q: Dictionary, r: Dictionary, idx: int) -> Dictionary:
	var s: Dictionary = step_def(q, idx)
	var cur: int = int(r.get("step", 0)) if not r.is_empty() else -1
	var done: bool = (not r.is_empty()) and (idx < cur or r["st"] == "done" or bool(r.get("ready", false)))
	var prog: int = 0
	if not r.is_empty() and idx == cur and not done:
		prog = _state_progress(state, a, s) if STATE_KINDS.has(String(s.get("kind", ""))) else int(r.get("prog", 0))
	return {"index": idx, "text": String(s.get("text", "")), "kind": String(s.get("kind", "")), "done": done, "current": (not r.is_empty()) and idx == cur and not done,
		"progress": mini(prog, qty_of(s)), "qty": qty_of(s), "theme": String(s.get("theme", "")), "item": String(s.get("item", "")),
		"prompt": String(s.get("prompt", "")), "ui": String(s.get("ui", "")), "topic": String(s.get("topic", ""))}

static func reward_text(rw: Dictionary) -> String:
	var parts: Array[String] = []
	for k in (rw.get("items", {}) as Dictionary).keys():
		parts.append("%s x%d" % [String(Content.item(String(k)).get("name", String(k).get_slice("/", 1))), int(rw["items"][k])])
	if String(rw.get("text", "")) != "":
		parts.append(String(rw["text"]))
	return ", ".join(parts)

static func row(state: MatchState, a: Dictionary, qid: String) -> Dictionary:
	var q: Dictionary = def(qid)
	var st: String = state_of(a, qid)
	var r: Dictionary = rec_of(a, qid)
	var steps: Array = []
	for i in range((q.get("steps", []) as Array).size()):
		steps.append(_step_row(state, a, q, r, i))
	var rw: Dictionary = q.get("reward", {})
	return {"id": qid, "title": String(q.get("title", qid)), "line": String(q.get("line", "")), "chapter": int(q.get("chapter", 1)), "intro": String(q.get("intro", "")),
		"state": st, "ready": bool(r.get("ready", false)), "implemented": bool(q.get("implemented", true)), "signature": bool(q.get("signature", false)),
		"steps": steps, "step_index": int(r.get("step", 0)) if not r.is_empty() else 0, "reward": reward_text(rw), "unlock": String(rw.get("unlock", "")),
		"class": String(q.get("class", "")), "requires": (q.get("requires", []) as Array).duplicate()}

## Journal for one actor: only quests that apply to its class (general ones + its own line). Sorted by file order.
static func journal(state: MatchState, a: Dictionary) -> Dictionary:
	var out: Dictionary = {"active": [], "available": [], "locked": [], "done": [], "soon": [], "titles": (a.get("titles", []) as Array).duplicate(),
		"unlocks": (a.get("unlocks", []) as Array).duplicate(), "guardians": Guardians.progress(state, a)}
	for qid in Content.quest_order():
		var q: Dictionary = def(String(qid))
		var cls: String = String(q.get("class", ""))
		if cls != "" and cls != String(a.get("class_id", "")):
			continue
		var rw: Dictionary = row(state, a, String(qid))
		if not rw["implemented"]:
			out["soon"].append(rw)
		else:
			out[rw["state"]].append(rw)
	return out

## One-line summary for the HUD tracker: the first active quest's current step.
static func tracker(state: MatchState, a: Dictionary) -> Dictionary:
	var ids: Array = (a.get("quests", {}) as Dictionary).keys()
	ids.sort()
	for qid in ids:
		var r: Dictionary = a["quests"][qid]
		if r["st"] == "active":
			var q: Dictionary = def(String(qid))
			if bool(r["ready"]):
				return {"quest": qid, "title": q.get("title", ""), "text": "Return to a holding and hand in the quest.", "ready": true}
			var rw: Dictionary = _step_row(state, a, q, r, int(r["step"]))
			return {"quest": qid, "title": q.get("title", ""), "text": "%s (%d/%d)" % [rw["text"], rw["progress"], rw["qty"]] if rw["qty"] > 1 else rw["text"], "ready": false}
	return {}

# ------------------------------------------------------------------ first-days tutorial (line "welcome"; ui/tutorial_overlay.gd renders this)
static func tutorial_cfg() -> Dictionary:
	if not Content._cache.has("tutorial_cfg"):
		var out: Dictionary = {"topics": {}}
		var f := FileAccess.open("res://data/tutorial.json", FileAccess.READ)
		if f != null:
			var parsed: Variant = JSON.parse_string(f.get_as_text())
			if parsed is Dictionary:
				out = parsed
		Content._cache["tutorial_cfg"] = out
	return Content._cache["tutorial_cfg"]

static func tutorial_quests() -> Array:
	var out: Array = []
	for qid in Content.quest_order():
		if String(Content.quest(String(qid)).get("line", "")) == "welcome":
			out.append(String(qid))
	return out

## What the tutorial overlay should show now: {} when the chapters are finished (or the player skipped them), else
## {phase:"offer"|"active"|"ready", quest, title, intro, text, prompt, ui, index, steps, progress, qty, topic, card:{title,lines,button}, chapter, chapters}.
static func tutorial_model(state: MatchState, a: Dictionary) -> Dictionary:
	if bool(a.get("tutorial_off", false)):
		return {}
	var ids: Array = tutorial_quests()
	for i in range(ids.size()):
		var qid: String = String(ids[i])
		var st: String = state_of(a, qid)
		if st == "done":
			continue
		var q: Dictionary = def(qid)
		var m: Dictionary = {"quest": qid, "title": String(q.get("title", "")), "intro": String(q.get("intro", "")), "chapter": i + 1, "chapters": ids.size(), "phase": "offer",
			"text": "", "prompt": "", "ui": "", "index": 0, "steps": (q.get("steps", []) as Array).size(), "progress": 0, "qty": 1, "topic": "", "card": {}}
		if st == "available":
			m["text"] = String(q.get("intro", ""))
			m["prompt"] = "Open the JOURNAL and accept the chapter, or press Begin."
			m["ui"] = "journal"
			return m
		if st != "active":
			return {}
		var r: Dictionary = rec_of(a, qid)
		if bool(r.get("ready", false)):
			m["phase"] = "ready"
			m["text"] = "Chapter finished."
			m["prompt"] = "Walk back to a holding and open the JOURNAL to hand it in."
			m["ui"] = "journal"
			return m
		var row: Dictionary = _step_row(state, a, q, r, int(r["step"]))
		m["phase"] = "active"
		m["index"] = int(r["step"])
		m["text"] = String(row["text"])
		m["prompt"] = String(row["prompt"])
		m["ui"] = String(row["ui"])
		m["progress"] = int(row["progress"])
		m["qty"] = int(row["qty"])
		m["topic"] = String(row["topic"])
		if m["topic"] != "":
			m["card"] = (tutorial_cfg().get("topics", {}) as Dictionary).get(m["topic"], {})
		return m
	return {}

static func toast_for(e: Dictionary) -> Dictionary:
	match String(e.get("type", "")):
		"quest_accepted":
			return {"title": "Quest: %s" % String(e.get("title", "")), "body": "", "kind": "info"}
		"quest_step":
			return {"title": "Step done", "body": String(e.get("next", "")) if String(e.get("next", "")) != "" else "Return to a holding to hand in the quest.", "kind": "good"}
		"quest_ready":
			return {"title": "%s: ready to hand in" % String(e.get("title", "")), "body": "Visit one of your holdings.", "kind": "good"}
		"quest_done":
			return {"title": "Quest complete: %s" % String(e.get("title", "")), "body": reward_text(e.get("reward", {})), "kind": "good"}
	return {}
