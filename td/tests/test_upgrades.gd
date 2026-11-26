extends SceneTree
# Upgrade rules: tier cap, one-path-past-tier-2 rule, sell value bookkeeping, stat application.
const TowerScript = preload("res://tower.gd")
const Creatures = preload("res://creatures.gd")

func _init() -> void:
	var fails := 0
	var n := 0
	for id in Creatures.TOWERS:
		var t = TowerScript.new()
		t.def = Creatures.TOWERS[id]
		# buy A,A,A (tier 3) then B must be limited to tier 2
		for ch in "aaa":
			t.buy(ch)
		var b_ok := 0
		for ch in "bbbb":
			if t.buy(ch) >= 0:
				b_ok += 1
		n += 1
		if t.tiers.a != 3 or b_ok != 2 or t.tiers.b != 2:
			fails += 1
			print("FAIL ", id, " rule: a=", t.tiers.a, " b=", t.tiers.b)
		# tier 4 on A still allowed
		n += 1
		if t.buy("a") < 0 or t.tiers.a != 4:
			fails += 1
			print("FAIL ", id, " cannot reach A4")
		n += 1
		if t.buy("a") >= 0:
			fails += 1
			print("FAIL ", id, " exceeded tier 4")
		# spent equals sum of costs
		var total := 0
		for i in 4:
			total += int(Creatures.TOWERS[id].upgrades.a[i].cost)
		for i in 2:
			total += int(Creatures.TOWERS[id].upgrades.b[i].cost)
		n += 1
		if t.spent != total:
			fails += 1
			print("FAIL ", id, " spent ", t.spent, " != ", total)
		t.free()
	# stat application: Hot Iron (+30% dmg) on Tickindle
	var tk = TowerScript.new()
	tk.def = Creatures.TOWERS.tickindle
	var base := float(tk.st.dmg)
	tk.buy("b")
	n += 1
	if absf(float(tk.st.dmg) - base * 1.3) > 0.001:
		fails += 1
		print("FAIL Hot Iron dmg ", tk.st.dmg)
	tk.free()
	print("upgrades: ", n - fails, "/", n, " ok")
	quit(1 if fails > 0 else 0)
