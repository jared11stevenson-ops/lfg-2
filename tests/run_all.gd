extends SceneTree
## Test runner. Discovers tests/**/test_*.gd (classes extending TestCase), runs each FILE in its own
## Godot process (isolation), prints per-suite and total counts, exits non-zero on any failure.
##   godot --headless --path . -s tests/run_all.gd [-- <substring filter>]
## Child mode (internal): -- --one res://tests/x/test_y.gd
const ROOT := "res://tests"

func _init() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	if args.size() >= 2 and args[0] == "--one":
		quit(_run_one(args[1]))
		return
	var filter: String = args[0] if args.size() > 0 else ""
	quit(_run_all(filter))

static func discover(dir_path: String = ROOT) -> Array[String]:
	var out: Array[String] = []
	var d := DirAccess.open(dir_path)
	if d == null:
		return out
	var names: Array[String] = []
	d.list_dir_begin()
	var n: String = d.get_next()
	while n != "":
		names.append(n)
		n = d.get_next()
	d.list_dir_end()
	names.sort()
	for name in names:
		var full: String = dir_path.path_join(name)
		if d.current_is_dir():
			pass
		if DirAccess.dir_exists_absolute(full):
			out.append_array(discover(full))
		elif name.begins_with("test_") and name.ends_with(".gd") and name != "test_case.gd":
			out.append(full)
	return out

func _run_all(filter: String) -> int:
	if not FileAccess.file_exists("res://.godot/global_script_class_cache.cfg"):
		# class_name registry is built by an import pass; do it once so `extends TestCase` resolves.
		var o: Array = []
		OS.execute(OS.get_executable_path(), ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--import"], o, true)
	var files: Array[String] = discover()
	var exe: String = OS.get_executable_path()
	var proj: String = ProjectSettings.globalize_path("res://")
	var tot_checks := 0
	var tot_fail := 0
	var tot_methods := 0
	var suites_failed := 0
	var suites := 0
	for f in files:
		if filter != "" and f.find(filter) == -1:
			continue
		suites += 1
		var out: Array = []
		var code: int = OS.execute(exe, ["--headless", "--path", proj, "-s", "res://tests/run_all.gd", "--", "--one", f], out, true)
		var text: String = "".join(out)
		var res: Dictionary = {}
		var fail_lines: Array[String] = []
		for line in text.split("\n"):
			if line.begins_with("SUITE|"):
				var p: PackedStringArray = line.split("|")
				res = {"methods": int(p[2]), "checks": int(p[3]), "fails": int(p[4])}
			elif line.begins_with("FAIL|") or line.begins_with("SCRIPT ERROR") or line.begins_with("ERROR"):
				fail_lines.append(line)
		var ok: bool = code == 0 and not res.is_empty() and res["fails"] == 0
		if res.is_empty():
			tot_fail += 1
			print("[FAIL] %s: no result (exit %d)" % [f, code])
			for l in text.split("\n").slice(0, 12):
				print("    " + l)
			suites_failed += 1
			continue
		tot_checks += res["checks"]
		tot_fail += res["fails"]
		tot_methods += res["methods"]
		print("[%s] %s: %d tests, %d checks, %d failed" % ["ok" if ok else "FAIL", f.trim_prefix("res://"), res["methods"], res["checks"], res["fails"]])
		if not ok:
			suites_failed += 1
			for l in fail_lines:
				print("    " + l)
	print("TOTAL: %d suites (%d failed), %d tests, %d checks, %d failures" % [suites, suites_failed, tot_methods, tot_checks, tot_fail])
	if suites == 0:
		print("no tests found")
		return 1
	return 0 if (suites_failed == 0 and tot_fail == 0) else 1

func _run_one(path: String) -> int:
	var script: Script = load(path) as Script
	if script == null or not script.can_instantiate():
		print("FAIL|%s|<load>|script failed to load/parse" % path)
		return 2
	var methods: Array[String] = []
	for m in script.get_script_method_list():
		var mn: String = m["name"]
		if mn.begins_with("test_"):
			methods.append(mn)
	methods.sort()
	var checks := 0
	var fails := 0
	for mn in methods:
		var inst: Variant = script.new()
		if not (inst is RefCounted and inst.get("failures") is Array and inst.has_method("check")):
			print("FAIL|%s|%s|class does not extend TestCase" % [path, mn])
			return 2
		var tc: Variant = inst
		if tc.has_method("before_each"):
			tc.call("before_each")
		tc.call(mn)
		if tc.has_method("after_each"):
			tc.call("after_each")
		checks += tc.checks
		fails += tc.failures.size()
		for msg in tc.failures:
			print("FAIL|%s|%s|%s" % [path, mn, msg])
	print("SUITE|%s|%d|%d|%d" % [path, methods.size(), checks, fails])
	return 0 if fails == 0 else 1
