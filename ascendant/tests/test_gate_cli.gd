extends "res://tests/test_case.gd"
func test_real_manifests_clean() -> void:
	# The shipped manifest dir must contain no approved-but-invalid manifests.
	var Reg = load("res://assets/approved_registry.gd")
	var reg = Reg.new("res://assets/manifest")
	assert_eq(reg.fraudulent_approvals().size(), 0, "no fraudulent approvals in assets/manifest")
