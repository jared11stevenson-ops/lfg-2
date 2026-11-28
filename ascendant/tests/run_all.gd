extends SceneTree
## Usage: godot --headless --path ascendant -s res://tests/run_all.gd [-- filter]
func _init() -> void:
	var filter := ""
	var args := OS.get_cmdline_user_args()
	if args.size() > 0: filter = args[0]
	var files: Array[String] = []
	var d := DirAccess.open("res://tests")
	for f in d.get_files():
		if f.begins_with("test_") and f.ends_with(".gd") and f != "test_case.gd" and (filter == "" or f.contains(filter)):
			files.append(f)
	files.sort()
	var tp := 0; var tf := 0
	for f in files:
		var s = load("res://tests/" + f)
		if s == null or not s.can_instantiate():
			print("FAIL  %s (parse error)" % f); tf += 1; continue
		if s == null:
			print("FAIL  %s (load error)" % f); tf += 1; continue
		var t = s.new()
		t.tree_root = root
		for m in t.get_method_list():
			var n: String = m["name"]
			if not n.begins_with("test_"): continue
			var before_p: int = t.passes; var before_f: int = t.failures.size()
			t.call(n)
			var np: int = t.passes - before_p; var nf: int = t.failures.size() - before_f
			tp += np; tf += nf
			if np + nf == 0:
				tf += 1; print("FAIL  %s::%s (0 checks: method errored or asserted nothing)" % [f, n]); continue
			print("%s  %s::%s (%d checks)" % ["PASS" if nf == 0 else "FAIL", f, n, np + nf])
			for i in range(before_f, t.failures.size()): print("      - " + t.failures[i])
	print("TOTAL passed=%d failed=%d files=%d" % [tp, tf, files.size()])
	quit(1 if tf > 0 or files.is_empty() else 0)
