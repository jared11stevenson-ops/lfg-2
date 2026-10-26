class_name UiCommands
extends RefCounted
## Turns panel signals into Rules command dictionaries (type + args). The lead only has to add actor + seq and call
## Game.submit(). Pure functions, no state access.
static func build(building_id: String, holding_id: int) -> Dictionary:
	return {"type": &"build", "args": {"holding": holding_id, "building": building_id}}

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

## Wrap with actor + seq for Game.submit().
static func wrap(cmd: Dictionary, actor: int, seq: int) -> Dictionary:
	return {"type": cmd["type"], "actor": actor, "seq": seq, "args": cmd["args"]}
