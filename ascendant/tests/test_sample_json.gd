extends "res://tests/test_case.gd"
func test_json_roundtrip() -> void:
	var d := {"a": 1, "b": [1, 2, 3], "c": {"x": "y"}}
	var back = JSON.parse_string(JSON.stringify(d))
	assert_eq(back["b"].size(), 3)
	assert_eq(back["c"]["x"], "y")
func test_negative_catches() -> void:
	assert_false(JSON.parse_string("{bad") is Dictionary)
