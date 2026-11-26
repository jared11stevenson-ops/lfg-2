extends SceneTree
const TypeChart = preload("res://type_chart.gd")

func _init() -> void:
	var fails := 0
	var checks := [
		[TypeChart.mult("ember", ["verdant"]), 1.5],
		[TypeChart.mult("verdant", ["ember"]), 0.67],
		[TypeChart.mult("tide", ["ember", "forge"]), 1.5],
		[TypeChart.mult("umbra", ["gale"]), 1.0],
		[TypeChart.best(["ember", "forge"], ["verdant", "gale"]), 1.5],
	]
	for c in checks:
		if absf(c[0] - c[1]) > 0.001:
			fails += 1
			print("FAIL got ", c[0], " want ", c[1])
	print("type chart: ", checks.size() - fails, "/", checks.size(), " ok")
	quit(1 if fails > 0 else 0)
