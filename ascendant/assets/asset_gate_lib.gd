extends RefCounted
## Asset quarantine gate: pure validation of a manifest Dictionary. No class_name on purpose
## (headless runs without an editor import do not register global classes); use preload().
const REQUIRED_CATEGORIES := ["silhouette", "palette", "readability", "cohesion", "distinctiveness", "technical"]
const SCORE_FLOOR := 6.0          # every category must be >= this on a 0..10 scale
const MIN_EVIDENCE_CHARS := 40
const MIN_IMAGE_SIDE := 64
const STATES := ["quarantined", "approved", "rejected"]
const KINDS := ["static", "runtime_generator"]
const VAGUE := ["looks good", "good", "fine", "ok", "nice", "great", "looks fine", "n/a", "none", "todo", "tbd"]

## Returns {"ok": bool, "errors": Array[String], "warnings": Array[String]}.
## "ok" for a state=approved manifest means the approval is legitimate.
## For quarantined/rejected manifests ok means structurally valid (they never grant access).
func validate(m: Dictionary) -> Dictionary:
	var errs: Array[String] = []
	var warns: Array[String] = []
	for k in ["id", "family", "kind", "generator", "state", "creator"]:
		if not m.has(k) or str(m[k]).strip_edges() == "":
			errs.append("missing required field '%s'" % k)
	if m.has("state") and not (m["state"] in STATES):
		errs.append("invalid state '%s'" % str(m["state"]))
	if m.has("kind") and not (m["kind"] in KINDS):
		errs.append("invalid kind '%s'" % str(m["kind"]))
	if m.get("kind", "") == "runtime_generator" and not m.has("seed") and not m.has("params"):
		errs.append("runtime_generator needs seed or params")
	if not errs.is_empty():
		return _res(errs, warns)
	var state: String = m["state"]
	var scores = m.get("scores", {})
	if not (scores is Dictionary): errs.append("scores must be an object"); scores = {}
	# Structural checks on any score present, regardless of state.
	for cat in scores:
		var e = scores[cat]
		if not (e is Dictionary) or not e.has("score") or not (e["score"] is float or e["score"] is int):
			errs.append("score '%s' malformed (need {score:number, evidence:string})" % cat); continue
		if float(e["score"]) < 0.0 or float(e["score"]) > 10.0:
			errs.append("score '%s' out of range 0..10" % cat)
		var ev := str(e.get("evidence", "")).strip_edges()
		if ev.length() < MIN_EVIDENCE_CHARS or ev.to_lower() in VAGUE:
			errs.append("score '%s' lacks specific written evidence (>= %d chars, not generic)" % [cat, MIN_EVIDENCE_CHARS])
	if state != "approved":
		if state == "rejected" and str(m.get("rejection_reason", "")).strip_edges() == "":
			errs.append("rejected manifest needs rejection_reason")
		return _res(errs, warns)
	# ---- approval rules ----
	var reviewer := str(m.get("reviewer", "")).strip_edges()
	if reviewer == "":
		errs.append("approved without reviewer")
	elif reviewer.to_lower() == str(m["creator"]).strip_edges().to_lower():
		errs.append("reviewer == creator: creator may not be sole approver")
	var crit = m.get("critical_failures", null)
	if crit == null or not (crit is Array):
		errs.append("critical_failures must be present as a list (empty if none)")
	elif not crit.is_empty():
		errs.append("critical failure(s) block approval: %s" % str(crit))
	var imgs = m.get("evidence_images", [])
	if not (imgs is Array) or imgs.is_empty():
		errs.append("approval requires at least one rendered evidence image")
	else:
		for p in imgs:
			var perr := _check_image(str(p))
			if perr != "": errs.append(perr)
	for cat in REQUIRED_CATEGORIES:
		if not scores.has(cat): errs.append("missing score category '%s'" % cat)
	var sum := 0.0; var n := 0; var below: Array = []
	for cat in scores:
		if scores[cat] is Dictionary and scores[cat].has("score"):
			var s := float(scores[cat]["score"]); sum += s; n += 1
			if s < SCORE_FLOOR: below.append("%s=%s" % [cat, str(s)])
	if not below.is_empty():
		var avg := sum / maxf(n, 1)
		var msg := "categories below floor %s: %s" % [str(SCORE_FLOOR), ", ".join(below)]
		if avg >= SCORE_FLOOR: msg += " (average %.2f would have hidden this)" % avg
		errs.append(msg)
	if m.has("average_score") and n > 0 and absf(float(m["average_score"]) - sum / n) > 0.05:
		errs.append("declared average_score %.2f does not match computed %.2f" % [float(m["average_score"]), sum / n])
	if m["kind"] == "runtime_generator":
		var vos = m.get("validated_output_space", null)
		if not (vos is Dictionary):
			errs.append("runtime_generator approval requires validated_output_space object")
		else:
			if str(vos.get("description", "")).strip_edges().length() < MIN_EVIDENCE_CHARS:
				errs.append("validated_output_space.description too thin")
			if int(vos.get("outputs_validated", 0)) < 1:
				errs.append("validated_output_space.outputs_validated must be >= 1")
			if vos.get("deterministic_check_passed", false) != true:
				errs.append("validated_output_space.deterministic_check_passed must be true")
	return _res(errs, warns)

func _check_image(p: String) -> String:
	if not (p.begins_with("res://") or p.begins_with("user://")) or not FileAccess.file_exists(p):
		return "evidence image missing: %s" % p
	var img := Image.new()
	if img.load(ProjectSettings.globalize_path(p)) != OK:
		return "evidence image unreadable: %s" % p
	if img.get_width() < MIN_IMAGE_SIDE or img.get_height() < MIN_IMAGE_SIDE:
		return "evidence image too small (<%dpx): %s" % [MIN_IMAGE_SIDE, p]
	return ""

func _res(errs: Array[String], warns: Array[String]) -> Dictionary:
	return {"ok": errs.is_empty(), "errors": errs, "warnings": warns}

func load_manifest(path: String) -> Dictionary:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null: return {}
	var d = JSON.parse_string(f.get_as_text())
	return d if d is Dictionary else {}
