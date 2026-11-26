extends SceneTree
const TypeChart = preload("res://type_chart.gd")

func _init() -> void:
	var fails := 0
	var n := 0
	var beaten := {}
	for t in TypeChart.TYPES:
		beaten[t] = 0
	for t in TypeChart.TYPES:
		n += 1
		if TypeChart.BEATS[t].size() != 2 or t in TypeChart.BEATS[t]:
			fails += 1
			print("FAIL beats list for ", t)
		for d in TypeChart.BEATS[t]:
			beaten[d] += 1
			if t in TypeChart.BEATS[d]:
				fails += 1
				print("FAIL mutual advantage ", t, " ", d)
	for t in TypeChart.TYPES:
		n += 1
		if beaten[t] != 2:
			fails += 1
			print("FAIL ", t, " beaten by ", beaten[t])
	var checks := [
		[TypeChart.mult("ember", ["verdant"]), 1.5],
		[TypeChart.mult("verdant", ["ember"]), 0.67],
		[TypeChart.mult("tide", ["ember", "forge"]), 1.5],
		[TypeChart.mult("umbra", ["gale"]), 1.0],
		[TypeChart.best(["tide", "spirit"], ["umbra", "gale"]), 1.5],
		[TypeChart.best(["ember", "forge"], ["stone", "frost"]), 1.5],
	]
	for c in checks:
		n += 1
		if absf(c[0] - c[1]) > 0.001:
			fails += 1
			print("FAIL got ", c[0], " want ", c[1])
	print("type chart: ", n - fails, "/", n, " ok")
	quit(1 if fails > 0 else 0)
