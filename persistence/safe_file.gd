class_name SafeFile
extends RefCounted
## Atomic, checksummed, backup-rotated file storage.
## Envelope (JSON): {"format":1,"sha256":<hex of payload utf8>,"payload":<string>}.
## write(): temp file -> flush/close -> read-back verify -> rotate (cur->.bak1->.bak2) -> rename temp over cur.
const FORMAT := 1

static func checksum(payload: String) -> String:
	return payload.sha256_text()

static func backup_path(path: String, n: int) -> String:
	return "%s.bak%d" % [path, n]

static func write(path: String, payload: String, backups: int = 2) -> Dictionary:
	var dir: String = path.get_base_dir()
	if DirAccess.make_dir_recursive_absolute(dir) != OK and not DirAccess.dir_exists_absolute(dir):
		return {"ok": false, "error": "mkdir_failed"}
	var tmp: String = path + ".tmp"
	var env: String = JSON.stringify({"format": FORMAT, "sha256": checksum(payload), "payload": payload})
	var f := FileAccess.open(tmp, FileAccess.WRITE)
	if f == null:
		return {"ok": false, "error": "open_tmp_failed"}
	f.store_string(env)
	f.flush()
	f.close()
	var back: Dictionary = parse_envelope(_read_text(tmp))
	if not back["ok"] or back["payload"] != payload:
		DirAccess.remove_absolute(tmp)
		return {"ok": false, "error": "verify_failed"}
	# rotate backups only when the current file is itself valid; never replace a good backup with garbage
	if FileAccess.file_exists(path):
		var cur_ok: bool = parse_envelope(_read_text(path))["ok"]
		if cur_ok and backups > 0:
			for i in range(backups, 1, -1):
				var src: String = backup_path(path, i - 1)
				if FileAccess.file_exists(src):
					_rename(src, backup_path(path, i))
			_rename(path, backup_path(path, 1))
		elif not cur_ok:
			DirAccess.remove_absolute(path)
	if _rename(tmp, path) != OK:
		# try to restore
		if not FileAccess.file_exists(path) and FileAccess.file_exists(backup_path(path, 1)):
			_rename(backup_path(path, 1), path)
		return {"ok": false, "error": "rename_failed"}
	return {"ok": true}

static func _rename(a: String, b: String) -> int:
	if FileAccess.file_exists(b):
		DirAccess.remove_absolute(b)
	return DirAccess.rename_absolute(a, b)

static func _read_text(path: String) -> String:
	var f := FileAccess.open(path, FileAccess.READ)
	if f == null:
		return ""
	return f.get_as_text()

static func parse_envelope(text: String) -> Dictionary:
	if text == "":
		return {"ok": false, "error": "empty_or_missing"}
	var j := JSON.new()
	if j.parse(text) != OK or not (j.data is Dictionary):
		return {"ok": false, "error": "bad_json"}
	var d: Dictionary = j.data
	if int(d.get("format", -1)) != FORMAT or not (d.get("payload") is String) or not (d.get("sha256") is String):
		return {"ok": false, "error": "bad_envelope"}
	if checksum(d["payload"]) != d["sha256"]:
		return {"ok": false, "error": "checksum_mismatch"}
	return {"ok": true, "payload": d["payload"]}

## All candidates, newest first: [{source, ok, payload|error}]
static func read_candidates(path: String, backups: int = 2) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var names: Array[String] = ["primary"]
	var paths: Array[String] = [path]
	for i in range(1, backups + 1):
		names.append("backup%d" % i)
		paths.append(backup_path(path, i))
	for i in paths.size():
		if not FileAccess.file_exists(paths[i]):
			continue
		var r: Dictionary = parse_envelope(_read_text(paths[i]))
		r["source"] = names[i]
		out.append(r)
	return out

static func delete_all(path: String, backups: int = 2) -> void:
	for p in [path, path + ".tmp"] + range(1, backups + 1).map(func(i): return backup_path(path, i)):
		if FileAccess.file_exists(p):
			DirAccess.remove_absolute(p)
