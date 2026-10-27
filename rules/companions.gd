class_name Companions
extends RefCounted
## Creature companions (data/companions.json): six original fungal/farm creatures that help in PEACE and have a small, bounded Purge role.
## State lives on the ACTOR: a["companions"] = [{kind, name, post:"follow"|"hold"|"rest", hold:int, fed_until:int, fed:bool, since:int}]. Old saves have none; every read tolerates that.
## Commands: adopt_companion {companion}, feed_companion {companion, item}, assign_companion {companion, mode:"follow"|"hold"|"rest", holding?}, dismiss_companion {companion}.
## Events: companion_adopted companion_fed companion_assigned companion_dismissed companion_hungry companion_work.
## Owner rules: nothing here needs a trade or another player, and there is no affinity meter of any kind. A companion is fed, it works; unfed, it rests (it never dies or leaves).
## Purge role is deliberately small: defence at the posted holding (capped per leader), tending Purgebloom. Companions never deal damage and never raise a leader's combat stats.

static func list_of(a: Dictionary) -> Array:
	return a.get("companions", [])

static func find(a: Dictionary, kind: String) -> Dictionary:
	for c in list_of(a):
		if String(c["kind"]) == kind:
			return c
	return {}

static func conf_i(key: String) -> int:
	return int(Content.companion_conf(key, 0))

static func is_player(a: Dictionary) -> bool:
	return a.get("kind", "") == "leader" and not bool(a.get("is_ai", false))

## Places for companions: the base plus every Kennel at an own holding, capped.
static func capacity(state: MatchState, a: Dictionary) -> int:
	var cap: int = conf_i("base_slots")
	for hid in state.holdings_of(int(a["faction"])):
		for b in state.holdings[hid]["buildings"]:
			cap += int(Content.building(String(b)).get("companion_slots", 0))
	return mini(cap, conf_i("max_slots"))

static func followers(a: Dictionary) -> int:
	var n: int = 0
	for c in list_of(a):
		if String(c["post"]) == "follow":
			n += 1
	return n

# ------------------------------------------------------------------ effects other rules read
## Extra carry capacity from fed followers (only matters to classes that have a pack limit, e.g. Pip).
static func carry_bonus(a: Dictionary) -> int:
	var n: int = 0
	for c in list_of(a):
		if String(c["post"]) == "follow" and bool(c.get("fed", false)):
			n += int(Content.companion(String(c["kind"])).get("follow", {}).get("carry", 0))
	return mini(n, conf_i("carry_cap"))

## Extra points-of-interest discovery radius from fed followers.
static func discover_bonus(a: Dictionary) -> int:
	var n: int = 0
	for c in list_of(a):
		if String(c["post"]) == "follow" and bool(c.get("fed", false)):
			n += int(Content.companion(String(c["kind"])).get("follow", {}).get("discover", 0))
	return mini(n, conf_i("discover_cap"))

## Purge defence a holding gets from the leader's fed companions posted there (or following within two hexes). Hard-capped; one garrison troop is worth 3.
static func defense_bonus(state: MatchState, h: Dictionary) -> float:
	var of: int = int(h["owner"])
	if of < 0 or not state.factions.has(of):
		return 0.0
	var l: Dictionary = state.actors.get(int(state.factions[of].get("leader", -1)), {})
	if l.is_empty() or not l["alive"] or list_of(l).is_empty():
		return 0.0
	var p: float = 0.0
	for c in list_of(l):
		if not bool(c.get("fed", false)):
			continue
		var here: bool = String(c["post"]) == "hold" and int(c["hold"]) == int(h["id"])
		if not here and String(c["post"]) == "follow":
			here = HexGrid.distance(l["hex"], h["hex"]) <= 2
		if here:
			p += float(Content.companion(String(c["kind"])).get("purge", {}).get("defense", 0))
	return minf(p, float(conf_i("purge_defense_cap")))

# ------------------------------------------------------------------ giving, commands
static func _new(kind: String, day: int, post: String) -> Dictionary:
	var d: Dictionary = Content.companion(kind)
	return {"kind": kind, "name": String(d.get("name", kind)), "post": post, "hold": -1, "fed_until": day + conf_i("feed_days") - 1, "fed": true, "since": day}

## Hands a companion to the leader whatever the capacity (quest gifts). "" or an error.
static func give(state: MatchState, a: Dictionary, kind: String, events: Array, via: String = "gift") -> String:
	if Content.companion(kind).is_empty():
		return "unknown_companion"
	if not find(a, kind).is_empty():
		return "already_have"
	if not a.has("companions"):
		a["companions"] = []
	var post: String = "follow" if followers(a) < conf_i("followers") else "rest"
	(a["companions"] as Array).append(_new(kind, int(state.clock["day"]), post))
	events.append({"type": &"companion_adopted", "actor": a["id"], "companion": kind, "name": Content.companion(kind).get("name", ""), "via": via, "post": post})
	return ""

## Feeding spots: the nearest discovered, guard-free POI of the wanted type within range. -> POI id or -1.
static func _haunt(state: MatchState, a: Dictionary, poi_type: String) -> int:
	var rng: int = conf_i("adopt_range")
	for p in Pois.all(state):
		if String(p["type"]) != poi_type or not Pois.seen(a, int(p["id"])):
			continue
		if HexGrid.distance(a["hex"], p["hex"]) > rng:
			continue
		if Pois._guards_alive(state, Pois.st_of(state, int(p["id"]))) > 0:
			continue
		return int(p["id"])
	return -1

## Which `feed` obtain option is available right now: {} when none. Used by adopt and by the panel hint.
static func obtain_option(state: MatchState, a: Dictionary, kind: String) -> Dictionary:
	for o in Content.companion(kind).get("obtain", []):
		if String(o["kind"]) == "feed" and _haunt(state, a, String(o["poi"])) != -1:
			return o
	return {}

static func adopt(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	if not is_player(a):
		return "unknown_actor"
	var kind: String = CmdUtil.s(args.get("companion", ""))
	var d: Dictionary = Content.companion(kind)
	if d.is_empty():
		return "unknown_companion"
	if not find(a, kind).is_empty():
		return "already_have"
	if list_of(a).size() >= capacity(state, a):
		return "no_room_for_companion"
	var opt: Dictionary = obtain_option(state, a, kind)
	if opt.is_empty():
		return "not_here"
	var cost: Dictionary = {String(opt["item"]): int(opt["qty"])}
	if not Inv.has_all(a["inv"], cost):
		return "insufficient_items"
	Inv.remove_all(a["inv"], cost)
	return give(state, a, kind, events, "feed")

static func _fed_days(c: Dictionary, item: String) -> int:
	var d: Dictionary = Content.companion(String(c["kind"]))
	return conf_i("fave_days") if String(d.get("fave", "")) == item else conf_i("feed_days")

static func _eats(d: Dictionary, item: String) -> bool:
	return (d.get("diet", []) as Array).has(item)

static func feed(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	if not is_player(a):
		return "unknown_actor"
	var c: Dictionary = find(a, CmdUtil.s(args.get("companion", "")))
	if c.is_empty():
		return "no_such_companion"
	var item: String = CmdUtil.s(args.get("item", ""))
	var d: Dictionary = Content.companion(String(c["kind"]))
	if Content.item(item).is_empty() or not _eats(d, item):
		return "wont_eat"
	if not Inv.has_all(a["inv"], {item: 1}):
		return "insufficient_items"
	var day: int = int(state.clock["day"])
	if int(c["fed_until"]) >= day + conf_i("max_fed_days") - 1:
		return "already_full"
	Inv.remove_all(a["inv"], {item: 1})
	var base: int = maxi(int(c["fed_until"]), day - 1)
	c["fed_until"] = mini(base + _fed_days(c, item), day + conf_i("max_fed_days") - 1)
	c["fed"] = true
	events.append({"type": &"companion_fed", "actor": a["id"], "companion": c["kind"], "item": item, "fed_until": c["fed_until"]})
	return ""

static func assign(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	if not is_player(a):
		return "unknown_actor"
	var c: Dictionary = find(a, CmdUtil.s(args.get("companion", "")))
	if c.is_empty():
		return "no_such_companion"
	var mode: String = CmdUtil.s(args.get("mode", ""))
	match mode:
		"follow":
			if String(c["post"]) != "follow" and followers(a) >= conf_i("followers"):
				return "followers_full"
			c["post"] = "follow"
			c["hold"] = -1
		"rest":
			c["post"] = "rest"
			c["hold"] = -1
		"hold":
			var hid: int = CmdUtil.parse_id(args.get("holding"))
			if not state.holdings.has(hid):
				return "unknown_holding"
			var h: Dictionary = state.holdings[hid]
			if int(h["owner"]) != int(a["faction"]):
				return "not_yours"
			if HexGrid.distance(a["hex"], h["hex"]) > 3:
				return "not_near_own_holding"
			c["post"] = "hold"
			c["hold"] = hid
		_:
			return "bad_mode"
	events.append({"type": &"companion_assigned", "actor": a["id"], "companion": c["kind"], "mode": mode, "holding": int(c["hold"])})
	return ""

static func dismiss(state: MatchState, a: Dictionary, args: Dictionary, events: Array) -> String:
	if not is_player(a):
		return "unknown_actor"
	var kind: String = CmdUtil.s(args.get("companion", ""))
	var c: Dictionary = find(a, kind)
	if c.is_empty():
		return "no_such_companion"
	(a["companions"] as Array).erase(c)
	events.append({"type": &"companion_dismissed", "actor": a["id"], "companion": kind})
	return ""

# ------------------------------------------------------------------ daily work and the Purge
static func _best_food(d: Dictionary, inv: Dictionary) -> String:
	var fave: String = String(d.get("fave", ""))
	if fave != "" and Inv.count(inv, fave) > 0:
		return fave
	for it in d.get("diet", []):
		if Inv.count(inv, String(it)) > 0:
			return String(it)
	return ""

static func _den_bonus(h: Dictionary) -> int:
	var n: int = 0
	for b in h["buildings"]:
		n += int(Content.building(String(b)).get("companion_forage", 0))
	return n

static func _forage_item(state: MatchState, h: Dictionary, c: Dictionary, k: int, day: int) -> String:
	var biome: String = WorldGen.biome_at(state.world, h["hex"])
	var r: float = Rng.hash2(int(h["id"]) * 31 + k, day * 977 + String(c["kind"]).length(), state.seed)
	if r < 0.55:
		return "lfg:item/mushroom"
	if r < 0.75 and (biome == "fungal_grove" or biome == "bog"):
		return "lfg:item/spore_sac"
	if r < 0.85 and (biome == "shore" or biome == "bog" or biome == "meadow"):
		return "lfg:item/reed_fibre"
	if r < 0.92:
		return "lfg:item/amber_resin"
	return "lfg:item/timber"

static func _work(state: MatchState, a: Dictionary, c: Dictionary, h: Dictionary, day: int, events: Array) -> void:
	var post: Dictionary = Content.companion(String(c["kind"])).get("post", {})
	var store: Dictionary = h["store"]
	var got: Dictionary = {}
	if post.has("tend"):
		var n: int = 0
		var keys: Array = state.plots.keys()
		keys.sort()
		for k in keys:
			if n >= int(post["tend"]):
				break
			var p: Dictionary = state.plots[k]
			if int(p["holding"]) != int(h["id"]) or bool(p["watered"]):
				continue
			var crop: Dictionary = Content.crop(String(p["crop"]))
			if bool(crop.get("purge_only", false)) or not bool(crop["needs_water"]):
				continue
			p["watered"] = true
			n += 1
		if n > 0:
			events.append({"type": &"companion_work", "actor": a["id"], "companion": c["kind"], "work": "tend", "plots": n, "holding": h["id"]})
	if post.has("haul"):
		var it: String = "lfg:item/timber" if day % 2 == 0 else "lfg:item/stone"
		Inv.add_all(got, {it: int(post["haul"])})
	if post.has("forage"):
		var cnt: int = int(post["forage"]) + _den_bonus(h)
		for i in range(cnt):
			Inv.add_all(got, {_forage_item(state, h, c, i, day): 1})
	if post.has("produce"):
		for k2 in (post["produce"] as Dictionary).keys():
			Inv.add_all(got, {String(k2): int(post["produce"][k2])})
	if not got.is_empty() and Inv.room_for(store, got):
		Inv.add_all(store, got)
		Standing.note_output(state, int(h["owner"]), got)
		events.append({"type": &"companion_work", "actor": a["id"], "companion": c["kind"], "work": "bring", "items": got, "holding": h["id"]})

## Dawn: feed from the nearest larder (the holding store for posted companions, the leader's pack for followers), then the posted ones work.
static func dawn(state: MatchState, events: Array) -> void:
	var day: int = int(state.clock["day"])
	var ids: Array = state.actors.keys()
	ids.sort()
	for id in ids:
		var a: Dictionary = state.actors[id]
		if not a["alive"] or not is_player(a) or list_of(a).is_empty():
			continue
		for c in list_of(a):
			var d: Dictionary = Content.companion(String(c["kind"]))
			var h: Dictionary = {}
			if String(c["post"]) == "hold":
				h = state.holdings.get(int(c["hold"]), {})
				if h.is_empty() or int(h["owner"]) != int(a["faction"]):
					c["post"] = "rest"       # the holding is gone: the creature goes to ground until you call it
					c["hold"] = -1
					h = {}
			var was_fed: bool = bool(c.get("fed", false))
			if int(c["fed_until"]) < day:
				var larder: Dictionary = h["store"] if not h.is_empty() else a["inv"]
				var food: String = _best_food(d, larder)
				if food != "":
					Inv.remove_all(larder, {food: 1})
					c["fed_until"] = day - 1 + _fed_days(c, food)
					events.append({"type": &"companion_fed", "actor": a["id"], "companion": c["kind"], "item": food, "fed_until": c["fed_until"], "auto": true})
			c["fed"] = int(c["fed_until"]) >= day
			if was_fed and not bool(c["fed"]):
				events.append({"type": &"companion_hungry", "actor": a["id"], "companion": c["kind"], "name": c.get("name", "")})
			if bool(c["fed"]) and not h.is_empty():
				_work(state, a, c, h, day, events)

## The Purge begins: Dewsnail-style companions tend the posted holding's Purgebloom (the only way a pacifist keeps it growing).
static func purge_start(state: MatchState, events: Array) -> void:
	for id in state.actors.keys():
		var a: Dictionary = state.actors[id]
		if not a["alive"] or not is_player(a) or list_of(a).is_empty():
			continue
		for c in list_of(a):
			if not bool(c.get("fed", false)) or String(c["post"]) != "hold":
				continue
			var cap: int = int(Content.companion(String(c["kind"])).get("purge", {}).get("tend", 0))
			if cap <= 0:
				continue
			var n: int = 0
			var keys: Array = state.plots.keys()
			keys.sort()
			for k in keys:
				var p: Dictionary = state.plots[k]
				if n >= cap or int(p["holding"]) != int(c["hold"]) or bool(p.get("tended", false)):
					continue
				if bool(Content.crop(String(p["crop"])).get("purge_only", false)):
					p["tended"] = true
					n += 1
			if n > 0:
				events.append({"type": &"companion_work", "actor": a["id"], "companion": c["kind"], "work": "tend_purge", "plots": n, "holding": c["hold"]})

# ------------------------------------------------------------------ view model (read only; ui/companion_panel.gd renders it)
static func role_text(kind: String) -> String:
	var d: Dictionary = Content.companion(kind)
	var parts: Array[String] = []
	var f: Dictionary = d.get("follow", {})
	var p: Dictionary = d.get("post", {})
	var u: Dictionary = d.get("purge", {})
	if int(f.get("carry", 0)) > 0:
		parts.append("Following: +%d pack room" % int(f["carry"]))
	if int(f.get("discover", 0)) > 0:
		parts.append("Following: spots places %d hexes farther" % int(f["discover"]))
	if p.has("tend"):
		parts.append("At a holding: waters %d plots a dawn" % int(p["tend"]))
	if p.has("haul"):
		parts.append("At a holding: hauls %d timber or stone a dawn" % int(p["haul"]))
	if p.has("forage"):
		parts.append("At a holding: forages %d find a dawn" % int(p["forage"]))
	if p.has("produce"):
		parts.append("At a holding: lays an egg a dawn")
	if int(u.get("defense", 0)) > 0:
		parts.append("Purge: steadies the garrison (+%d defence)" % int(u["defense"]))
	if int(u.get("tend", 0)) > 0:
		parts.append("Purge: tends %d Purgebloom" % int(u["tend"]))
	return "; ".join(parts)

static func _item_name(id: String) -> String:
	return String(Content.item(id).get("name", id.get_slice("/", 1)))

static func panel_model(state: MatchState, a: Dictionary) -> Dictionary:
	var day: int = int(state.clock["day"])
	var owned: Array = []
	for c in list_of(a):
		var d: Dictionary = Content.companion(String(c["kind"]))
		var hn: String = ""
		if String(c["post"]) == "hold" and state.holdings.has(int(c["hold"])):
			hn = String(state.holdings[int(c["hold"])]["name"])
		var fave: String = String(d.get("fave", ""))
		owned.append({"kind": String(c["kind"]), "name": String(c["name"]), "blurb": String(d.get("blurb", "")), "post": String(c["post"]), "hold": int(c["hold"]), "hold_name": hn,
			"fed": bool(c.get("fed", false)), "days_fed": maxi(0, int(c["fed_until"]) - day + 1), "role": role_text(String(c["kind"])), "fave": _item_name(fave),
			"diet": (d.get("diet", []) as Array).duplicate(), "colors": d.get("colors", [])})
	var wild: Array = []
	for kind in Content.companion_order():
		if not find(a, String(kind)).is_empty():
			continue
		var d2: Dictionary = Content.companion(String(kind))
		var hints: Array = []
		for o in d2.get("obtain", []):
			hints.append(String(o.get("hint", "")))
		wild.append({"kind": String(kind), "name": String(d2["name"]), "blurb": String(d2.get("blurb", "")), "hints": hints, "role": role_text(String(kind)),
			"here": not obtain_option(state, a, String(kind)).is_empty(), "colors": d2.get("colors", [])})
	var holds: Array = []
	for hid in state.holdings_of(int(a["faction"])):
		holds.append({"id": hid, "name": String(state.holdings[hid]["name"]), "near": HexGrid.distance(a["hex"], state.holdings[hid]["hex"]) <= 3})
	var pack: Dictionary = {}
	for kind2 in Content.companion_order():
		for it in Content.companion(String(kind2)).get("diet", []):
			pack[String(it)] = Inv.count(a["inv"], String(it))
	return {"slots_used": list_of(a).size(), "slots": capacity(state, a), "followers": followers(a), "followers_max": conf_i("followers"), "owned": owned, "wild": wild, "holdings": holds, "pack": pack}

## Tracker line for the HUD: "Mossbun, Dewsnail" with a ! when someone is hungry. "" when none.
static func summary(a: Dictionary) -> String:
	var parts: Array[String] = []
	for c in list_of(a):
		parts.append(String(c["name"]) + ("" if bool(c.get("fed", false)) else " (hungry)"))
	return ", ".join(parts)

static func toast_for(e: Dictionary) -> Dictionary:
	match String(e.get("type", "")):
		"companion_adopted":
			return {"title": "%s joins you" % String(e.get("name", "A friend")), "body": "Open PETS to feed and assign it.", "kind": "good"}
		"companion_hungry":
			return {"title": "%s is hungry" % String(e.get("name", "")), "body": "Feed it from PETS, or leave food in its holding.", "kind": "warn"}
		"companion_work":
			if String(e.get("work", "")) == "bring":
				var parts: Array = []
				for k in (e.get("items", {}) as Dictionary).keys():
					parts.append("%s x%d" % [_item_name(String(k)), int(e["items"][k])])
				return {"title": "A companion brought back", "body": ", ".join(parts), "kind": "good"}
			if String(e.get("work", "")) == "tend":
				return {"title": "A companion watered %d plots" % int(e.get("plots", 0)), "body": "", "kind": "good"}
	return {}
