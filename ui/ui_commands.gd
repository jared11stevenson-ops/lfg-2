class_name UiCommands
extends RefCounted
## Turns panel signals into Rules command dictionaries (type + args). The lead only has to add actor + seq and call
## Game.submit(). Pure functions, no state access.
## `hex` (axial Vector2i) is the site the ghost sat on; omit/Vector2i(-9999,-9999) for upgrades and auto-site.
static func build(building_id: String, holding_id: int, hex: Vector2i = Vector2i(-9999, -9999)) -> Dictionary:
	var args: Dictionary = {"holding": holding_id, "building": building_id}
	if hex.x != -9999 and not Content.building(building_id).has("upgrade_of"):
		args["hex"] = hex
	return {"type": &"build", "args": args}

static func demolish(holding_id: int, building_id: String) -> Dictionary:
	return {"type": &"demolish", "args": {"holding": holding_id, "building": building_id}}

static func craft(recipe_id: String, qty: int) -> Dictionary:
	return {"type": &"craft", "args": {"recipe": recipe_id, "qty": qty}}

static func trade(holding_id: int, side: String, item: String, qty: int) -> Dictionary:
	return {"type": &"trade", "args": {"holding": holding_id, "side": side, "item": item, "qty": qty}}

static func policy(key: String, value: String, holding_id: int = -1) -> Dictionary:
	var args: Dictionary = {"key": key, "value": value}
	if key == "stance":
		args["holding"] = holding_id
	return {"type": &"set_policy", "args": args}

static func ability(ability_id: String) -> Dictionary:
	return {"type": &"use_ability", "args": {"ability": ability_id}}

static func accept_quest(quest_id: String) -> Dictionary:
	return {"type": &"accept_quest", "args": {"quest": quest_id}}

static func abandon_quest(quest_id: String) -> Dictionary:
	return {"type": &"abandon_quest", "args": {"quest": quest_id}}

static func turn_in(quest_id: String) -> Dictionary:
	return {"type": &"turn_in", "args": {"quest": quest_id}}

## pick: -1 for challenges without one (offering / effort / guard), else the lamp or plate index 0..2.
static func interact_poi(poi_id: int, pick: int = -1) -> Dictionary:
	var args: Dictionary = {"poi": poi_id}
	if pick >= 0:
		args["pick"] = pick
	return {"type": &"interact_poi", "args": args}

static func adopt_companion(kind: String) -> Dictionary:
	return {"type": &"adopt_companion", "args": {"companion": kind}}

static func feed_companion(kind: String, item: String) -> Dictionary:
	return {"type": &"feed_companion", "args": {"companion": kind, "item": item}}

## mode: "follow" | "rest" | "hold" (hold needs the holding id).
static func assign_companion(kind: String, mode: String, holding_id: int = -1) -> Dictionary:
	var args: Dictionary = {"companion": kind, "mode": mode}
	if mode == "hold":
		args["holding"] = holding_id
	return {"type": &"assign_companion", "args": args}

static func dismiss_companion(kind: String) -> Dictionary:
	return {"type": &"dismiss_companion", "args": {"companion": kind}}

## topic: one of Quests.TUTORIAL_TOPICS (the card the player just read).
static func ack_tutorial(topic: String) -> Dictionary:
	return {"type": &"ack_tutorial", "args": {"topic": topic}}

## Wrap with actor + seq for Game.submit().
static func wrap(cmd: Dictionary, actor: int, seq: int) -> Dictionary:
	return {"type": cmd["type"], "actor": actor, "seq": seq, "args": cmd["args"]}
