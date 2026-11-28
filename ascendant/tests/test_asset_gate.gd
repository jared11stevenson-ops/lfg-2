extends "res://tests/test_case.gd"
const Gate := preload("res://assets/asset_gate_lib.gd")
const Reg := preload("res://assets/approved_registry.gd")
const DIR := "res://tests/fixtures/manifests/"
func _v(name: String) -> Dictionary:
	var g = Gate.new(); return g.validate(g.load_manifest(DIR + name + ".json"))
func _has(r: Dictionary, frag: String) -> bool:
	for e in r["errors"]: if str(e).contains(frag): return true
	return false
func test_good_pass() -> void:
	assert_true(_v("approved_good")["ok"], "good static: " + str(_v("approved_good")["errors"]))
	assert_true(_v("approved_runtime_good")["ok"], "good runtime: " + str(_v("approved_runtime_good")["errors"]))
	assert_true(_v("quarantined_ok")["ok"])
func test_rejections() -> void:
	var r := _v("fail_self_approved"); assert_false(r["ok"]); assert_true(_has(r, "reviewer == creator"), "case-insens self approval")
	r = _v("fail_missing_image"); assert_false(r["ok"]); assert_true(_has(r, "evidence image missing"))
	r = _v("fail_tiny_image"); assert_false(r["ok"]); assert_true(_has(r, "too small"))
	r = _v("fail_vague_evidence"); assert_false(r["ok"]); assert_true(_has(r, "specific written evidence"))
	r = _v("fail_average_hides_low"); assert_false(r["ok"]); assert_true(_has(r, "below floor") and _has(r, "average"), "avg-hiding named")
	r = _v("fail_critical"); assert_false(r["ok"]); assert_true(_has(r, "critical failure"))
	r = _v("fail_runtime_no_output_space"); assert_false(r["ok"]); assert_true(_has(r, "validated_output_space"))
func test_mutations() -> void:
	var g = Gate.new()
	var m: Dictionary = g.load_manifest(DIR + "approved_good.json")
	var a := m.duplicate(true); a.erase("reviewer"); assert_false(g.validate(a)["ok"])
	a = m.duplicate(true); a["scores"].erase("cohesion"); assert_false(g.validate(a)["ok"])
	a = m.duplicate(true); a["average_score"] = 9.9; assert_false(g.validate(a)["ok"])
	a = m.duplicate(true); a["state"] = "bogus"; assert_false(g.validate(a)["ok"])
	a = m.duplicate(true); a.erase("critical_failures"); assert_false(g.validate(a)["ok"])
func test_registry_only_approved() -> void:
	var reg = Reg.new(DIR)
	assert_true(reg.is_approved("fx.creature.good"))
	assert_true(reg.is_approved("fx.gen.good"))
	assert_eq(reg.generator_path("fx.gen.good"), "res://tests/fixtures/dummy_gen.gd")
	for bad in ["fx.bad.self", "fx.bad.noimg", "fx.bad.hidden", "fx.bad.crit", "fx.q.ok", "fx.bad.gen", "nonexistent"]:
		assert_false(reg.is_approved(bad), bad)
		assert_eq(reg.generator_path(bad), "")
	assert_true(reg.fraudulent_approvals().has("fx.bad.self"), "fraud list reports self-approval")
	assert_eq(reg.list_ids().size(), 2)
