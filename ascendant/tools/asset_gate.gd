extends SceneTree
## godot --headless --path ascendant -s res://tools/asset_gate.gd [-- manifest_dir_or_file]
## Exit 1 if any manifest claiming state=approved fails the gate, or any manifest is malformed.
func _init() -> void:
	var Gate = load("res://assets/asset_gate_lib.gd")
	var gate = Gate.new()
	var args := OS.get_cmdline_user_args()
	var target := args[0] if args.size() > 0 else "res://assets/manifest"
	var files: Array[String] = []
	if target.ends_with(".json"): files.append(target)
	else:
		var d := DirAccess.open(target)
		if d: for f in d.get_files():
			if f.ends_with(".json") and not f.begins_with("_"): files.append(target + "/" + f)
	files.sort()
	var bad := 0; var counts := {"approved": 0, "quarantined": 0, "rejected": 0}
	for p in files:
		var m: Dictionary = gate.load_manifest(p)
		if m.is_empty(): print("FAIL  %s: unparseable" % p); bad += 1; continue
		var r: Dictionary = gate.validate(m)
		counts[m.get("state", "?")] = counts.get(m.get("state", "?"), 0) + 1
		if r["ok"]: print("OK    %s [%s]" % [p, m.get("state")])
		else:
			bad += 1; print("FAIL  %s [%s]" % [p, m.get("state", "?")])
			for e in r["errors"]: print("      - " + e)
	print("GATE manifests=%d approved=%s quarantined=%s rejected=%s failed=%d" % [files.size(), counts["approved"], counts["quarantined"], counts["rejected"], bad])
	quit(1 if bad > 0 else 0)
