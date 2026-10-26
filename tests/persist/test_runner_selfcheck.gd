extends TestCase
func test_runner_discovers() -> void:
	var f: Array[String] = load("res://tests/run_all.gd").discover()
	check(f.size() >= 1, "discovers at least itself")
	check(f.has("res://tests/test_selfcheck.gd"), "finds self")
func test_eq() -> void:
	eq(1 + 1, 2, "math")
