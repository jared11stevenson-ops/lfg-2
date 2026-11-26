extends RefCounted
# Procedural wave generator. Budget grows each wave; species are drawn by weight from the level roster, so
# every run differs (seeded for the daily challenge). New species get an introduction on their first wave.
const Levels = preload("res://levels.gd")
const Creatures = preload("res://creatures.gd")

static func budget(w: int) -> float:
	return 8.0 + 5.2 * pow(float(w), 1.3)

# Returns an Array of species ids (boss appears as "boss:<species>").
static func build(level: Dictionary, w: int, rng: RandomNumberGenerator, count_mult: float, endless_boss_every: int = 5) -> Array:
	var avail: Array = []
	for r in level.roster:
		if int(r[1]) <= w:
			avail.append(r)
	var q: Array = []
	# introduction: first appearance of a species gets 2 guaranteed spawns
	for r in avail:
		if int(r[1]) == w and w > 1:
			q.append(r[0])
			q.append(r[0])
	var left := budget(w) * count_mult
	for id in q:
		left -= float(Creatures.ENEMIES[id].cost)
	var guard := 0
	while left > 0.4 and guard < 400:
		guard += 1
		var total := 0.0
		var cands: Array = []
		for r in avail:
			if float(Creatures.ENEMIES[r[0]].cost) <= left + 0.5:
				cands.append(r)
				total += float(r[2])
		if cands.is_empty():
			break
		var pick := rng.randf() * total
		for r in cands:
			pick -= float(r[2])
			if pick <= 0.0:
				q.append(r[0])
				left -= float(Creatures.ENEMIES[r[0]].cost)
				break
	# shuffle with the seeded RNG
	for i in range(q.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = q[i]
		q[i] = q[j]
		q[j] = tmp
	var is_boss_wave := w == Levels.TOTAL_WAVES or (w > Levels.TOTAL_WAVES and (w - Levels.TOTAL_WAVES) % endless_boss_every == 0)
	if is_boss_wave:
		q.insert(q.size() / 2, "boss:" + String(level.boss))
	return q

static func boss_def(level: Dictionary, species: String, w: int) -> Dictionary:
	var d: Dictionary = Creatures.ENEMIES[species].duplicate(true)
	d.id = "boss"
	d.sprite = species
	d.name = "Elder " + String(d.name)
	d.boss = true
	d.scale = 1.9
	d.hp = (float(d.hp) + float(d.hp_wave) * 10.0) * 11.0
	d.hp_wave = float(d.hp) * 0.06 * maxi(0, w - Levels.TOTAL_WAVES + 1)
	d.speed = float(d.speed) * 0.75
	d.reward = 200
	d.leak = 10
	for k in level.get("boss_extra", {}):
		d[k] = level.boss_extra[k]
	return d
