class_name RulesWorldAdapter
extends RefCounted
## Converts Stream A's MatchState.world (rules/worldgen.gd dictionary) into the presentation WorldData.
## Biome ids line up with Biomes.B for 0..6; terrain codes are the same T_* values as WorldGen.
static func from_world_dict(w: Dictionary, seed_value: int = 0, holding_owners: Dictionary = {}) -> WorldData:
	var d := WorldData.new()
	d.world_seed = seed_value
	var n: int = HexMath.COLS * HexMath.ROWS
	d.biome.resize(n)
	d.terrain = (w["terrain"] as PackedByteArray).duplicate()
	d.road = (w["road"] as PackedByteArray).duplicate()
	var src_biome: PackedByteArray = w["biome"]
	for i in n:
		var t: int = d.terrain[i]
		d.biome[i] = Biomes.B.WATER if t == WorldData.T_DEEP else mini(src_biome[i], Biomes.B.BOG)
	var start_axial: Variant = w.get("start", Vector2i(-1, -1))
	if start_axial is Vector2i and start_axial.x != -9999:
		d.start_hex = HexMath.axial_to_offset(start_axial)
	d.holdings = []
	for s in w.get("sites", []):
		var hex_off: Vector2i = HexMath.axial_to_offset(s["hex"])
		d.holdings.append({"hex": hex_off, "name": String(s.get("name", "?")), "owner": int(holding_owners.get(int(s.get("id", 0)), 0)), "id": int(s.get("id", 0)), "tier": int(s.get("tier", 1))})
	TerrainHeights.build(d, w.get("elevation", PackedByteArray()))
	return d

## Convenience: build from a live MatchState (owners filled from state.holdings).
static func from_state(state: Object) -> WorldData:
	var owners: Dictionary = {}
	var hs: Variant = state.get("holdings")
	if hs is Dictionary:
		for id in hs:
			owners[int(id)] = int(hs[id].get("owner", 0))
	return from_world_dict(state.get("world"), int(state.get("seed")), owners)
