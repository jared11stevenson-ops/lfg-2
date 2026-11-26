extends RefCounted
# Procedural sound effects: no audio assets, everything is synthesised into AudioStreamWAV at first use.
const RATE := 22050
static var _cache := {}
static var _pool: Array = []
static var _next := 0
static var _last := {}

static func _tone(f0: float, f1: float, dur: float, wave: String, decay: float, vol: float = 0.55) -> PackedFloat32Array:
	var n := int(dur * RATE)
	var out := PackedFloat32Array()
	out.resize(n)
	var ph := 0.0
	for i in n:
		var k := float(i) / n
		ph += TAU * lerpf(f0, f1, k) / RATE
		var s := 0.0
		match wave:
			"square": s = 1.0 if sin(ph) >= 0.0 else -1.0
			"saw": s = fmod(ph / TAU, 1.0) * 2.0 - 1.0
			"noise": s = randf() * 2.0 - 1.0
			_: s = sin(ph)
		out[i] = s * pow(1.0 - k, decay) * vol
	return out

static func _seq(notes: Array, wave: String, decay: float = 1.5) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	for n in notes:
		out.append_array(_tone(n[0], n[0], n[1], wave, decay))
	return out

static func _wav(data: PackedFloat32Array) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = RATE
	w.stereo = false
	var b := PackedByteArray()
	b.resize(data.size() * 2)
	for i in data.size():
		b.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32767.0))
	w.data = b
	return w

static func _make(name: String) -> AudioStreamWAV:
	match name:
		"shoot": return _wav(_tone(900, 480, 0.09, "square", 1.6, 0.3))
		"pulse": return _wav(_tone(260, 720, 0.28, "sine", 1.2))
		"hit": return _wav(_tone(220, 120, 0.05, "noise", 1.0, 0.35))
		"pop": return _wav(_tone(520, 90, 0.2, "noise", 2.2, 0.4))
		"coin": return _wav(_seq([[988, 0.05], [1319, 0.1]], "square", 1.2))
		"up": return _wav(_seq([[523, 0.07], [659, 0.07], [784, 0.07], [1047, 0.16]], "square", 1.0))
		"place": return _wav(_tone(300, 520, 0.1, "sine", 1.2))
		"leak": return _wav(_tone(180, 55, 0.4, "saw", 1.0, 0.5))
		"horn": return _wav(_seq([[220, 0.18], [330, 0.32]], "saw", 0.9))
		"boss": return _wav(_seq([[110, 0.3], [98, 0.3], [82, 0.6]], "saw", 0.7))
		"win": return _wav(_seq([[523, 0.12], [659, 0.12], [784, 0.12], [1047, 0.4]], "square", 1.0))
		"lose": return _wav(_seq([[392, 0.2], [330, 0.2], [262, 0.2], [196, 0.6]], "saw", 1.0))
		"click": return _wav(_tone(700, 700, 0.04, "square", 1.0, 0.3))
	return _wav(_tone(440, 440, 0.05, "sine", 1.0))

# min_gap: ms between plays of the same sound, so rapid events don't machine-gun.
static func play(n: Node, name: String, vol_db: float = -8.0, min_gap: int = 0) -> void:
	var now := Time.get_ticks_msec()
	if min_gap > 0 and now - int(_last.get(name, -9999)) < min_gap:
		return
	_last[name] = now
	if _pool.is_empty() or not is_instance_valid(_pool[0]):
		_pool.clear()
		for i in 14:
			var p := AudioStreamPlayer.new()
			n.get_tree().root.add_child(p)
			_pool.append(p)
	if not _cache.has(name):
		_cache[name] = _make(name)
	var pl: AudioStreamPlayer = _pool[_next % _pool.size()]
	_next += 1
	pl.stream = _cache[name]
	pl.volume_db = vol_db
	pl.pitch_scale = randf_range(0.95, 1.05)
	pl.play()
