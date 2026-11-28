
extends RefCounted
## Base class for tests. Methods named test_* are run by run_all.gd.
var tree_root: Node = null
var passes := 0
var failures: Array[String] = []

func check(cond: bool, msg: String = "") -> void:
	if cond: passes += 1
	else: failures.append(msg if msg != "" else "check failed")

func assert_eq(a, b, msg: String = "") -> void:
	if a == b: passes += 1
	else: failures.append("%s expected %s got %s" % [msg, str(b), str(a)])

func assert_true(c: bool, msg: String = "") -> void: check(c, msg)
func assert_false(c: bool, msg: String = "") -> void: check(not c, msg)
func assert_near(a: float, b: float, eps := 0.0001, msg: String = "") -> void:
	check(absf(a - b) <= eps, "%s expected ~%s got %s" % [msg, str(b), str(a)])
