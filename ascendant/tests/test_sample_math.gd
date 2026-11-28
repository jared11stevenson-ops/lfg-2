extends "res://tests/test_case.gd"
func test_rng_deterministic() -> void:
	var a := RandomNumberGenerator.new(); a.seed = 1234
	var b := RandomNumberGenerator.new(); b.seed = 1234
	for i in 50: assert_eq(a.randi(), b.randi(), "same seed same stream")
func test_hash_stable() -> void:
	assert_eq("ascendant".hash(), "ascendant".hash())
	assert_true("a".hash() != "b".hash())
