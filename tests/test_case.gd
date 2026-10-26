class_name TestCase
extends RefCounted
var failures: Array[String] = []
var checks: int = 0
func check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)
func eq(a: Variant, b: Variant, msg: String) -> void:
	check(a == b, "%s (got %s, want %s)" % [msg, str(a), str(b)])
