class_name DistrictGen
extends RefCounted
## Deterministic ruined-district layout from a seed: collapsed towers, a
## chrysalis pod to molt in, and nests for each species.

const HALF := 36.0   # district is 72m x 72m (matches Ecology grid: 24 cells * 3m)

static func generate(seed_value: int) -> Dictionary:
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value
	var spawn := Vector2(rng.randf_range(-6, 6), HALF - 8.0)
	var chrysalis := Vector2(rng.randf_range(-18, 18), -HALF + 9.0)
	var blocks: Array = []
	var tries := 0
	while blocks.size() < 34 and tries < 600:
		tries += 1
		var size := Vector2(rng.randf_range(3.0, 8.0), rng.randf_range(3.0, 8.0))
		var pos := Vector2(rng.randf_range(-HALF + 4, HALF - 4), rng.randf_range(-HALF + 4, HALF - 4))
		if pos.distance_to(spawn) < 9.0 or pos.distance_to(chrysalis) < 8.0:
			continue
		var ok := true
		for b in blocks:
			if absf(pos.x - b.pos.x) < (size.x + b.size.x) * 0.5 + 3.0 and absf(pos.y - b.pos.y) < (size.y + b.size.y) * 0.5 + 3.0:
				ok = false
				break
		if ok:
			blocks.append({"pos": pos, "size": size, "height": rng.randf_range(2.5, 11.0)})
	var nests: Array = []
	for id in SpeciesDB.ids():
		var cnt := 1 if id == "cathedral_regent" else 2
		for _i in cnt:
			var p := Vector2.ZERO
			for _t in 30:
				p = Vector2(rng.randf_range(-HALF + 5, HALF - 5), rng.randf_range(-HALF + 5, HALF - 8))
				if id == "cathedral_regent":
					p = Vector2(rng.randf_range(-8, 8), rng.randf_range(-HALF + 14, -HALF + 20))
				if p.distance_to(spawn) > 14.0 and not _inside_block(p, blocks):
					break
			nests.append({"species": id, "pos": p})
	return {"seed": seed_value, "spawn": spawn, "chrysalis": chrysalis, "blocks": blocks, "nests": nests}

static func _inside_block(p: Vector2, blocks: Array) -> bool:
	for b in blocks:
		if absf(p.x - b.pos.x) < b.size.x * 0.5 + 1.5 and absf(p.y - b.pos.y) < b.size.y * 0.5 + 1.5:
			return true
	return false
