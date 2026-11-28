class_name ApprovedRegistry
extends RefCounted
## Runtime access to assets/generators. ONLY manifests that are state==approved AND pass the gate
## (reviewer != creator, evidence images present, floors met, no critical failures) are visible.
## Quarantined/rejected/invalid manifests are invisible: callers get null/false.
const Gate := preload("res://assets/asset_gate_lib.gd")
var _approved: Dictionary = {}   # id -> manifest
var _refused: Dictionary = {}    # id -> errors (for tooling)

func _init(dir: String = "res://assets/manifest") -> void:
	reload(dir)

func reload(dir: String = "res://assets/manifest") -> void:
	_approved.clear(); _refused.clear()
	var gate = Gate.new()
	var d := DirAccess.open(dir)
	if d == null: return
	for f in d.get_files():
		if not f.ends_with(".json") or f.begins_with("_"): continue
		var m: Dictionary = gate.load_manifest(dir + "/" + f)
		if m.is_empty() or not m.has("id"): continue
		if m.get("state", "") != "approved": continue
		var r: Dictionary = gate.validate(m)
		if r["ok"]: _approved[m["id"]] = m
		else: _refused[m["id"]] = r["errors"]

func is_approved(id: String) -> bool: return _approved.has(id)
func get_manifest(id: String) -> Dictionary: return _approved.get(id, {})
## Generator script path for an approved asset, "" if not approved.
func generator_path(id: String) -> String: return str(_approved.get(id, {}).get("generator", ""))
func list_ids(family: String = "") -> Array:
	var out: Array = []
	for id in _approved:
		if family == "" or _approved[id]["family"] == family: out.append(id)
	out.sort(); return out
## Manifests that claim approval but fail the gate (should be empty in a healthy repo).
func fraudulent_approvals() -> Dictionary: return _refused
