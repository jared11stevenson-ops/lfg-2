extends RefCounted
# Procedural sound effects: no audio assets, everything is synthesised into AudioStreamWAV at first use.
const RATE := 22050
static var _cache := {}
static var _pool: Array = []
static var _next := 0
static var _last := {}
const Session = preload("res://session.gd")

static func setup_buses() -> void:
	for nm in ["Music", "SFX"]:
		if AudioServer.get_bus_index(nm) < 0:
			AudioServer.add_bus()
			var i := AudioServer.get_bus_count() - 1
			AudioServer.set_bus_name(i, nm)
			AudioServer.set_bus_send(i, "Master")
	apply_volumes()

static func apply_volumes() -> void:
	Session.load_save()
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("Music"), linear_to_db(maxf(0.0001, float(Session.settings.music))))
	AudioServer.set_bus_volume_db(AudioServer.get_bus_index("SFX"), linear_to_db(maxf(0.0001, float(Session.settings.sfx))))

static func haptic(ms: int = 20) -> void:
	Session.load_save()
	if bool(Session.settings.haptics):
		Input.vibrate_handheld(ms)

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

# Per-species voices: [start Hz, end Hz, wave, length]. Small tonal quirks give each creature a sound personality.
const VOICES := {
	"tickindle": [180, 120, "saw", 0.16], "dugloom": [300, 200, "sine", 0.3], "hutzin": [700, 330, "square", 0.2], "shuckit": [520, 260, "saw", 0.18],
	"zapnose": [1200, 600, "square", 0.1], "glomm": [90, 60, "saw", 0.3], "hoardillo": [420, 300, "square", 0.14], "mirewick": [380, 760, "sine", 0.26],
	"gloamoth": [900, 1100, "sine", 0.2], "bogbard": [140, 110, "saw", 0.22], "quillwyrm": [640, 420, "square", 0.12], "drumbeak": [110, 70, "square", 0.2],
	"pyrelope": [760, 980, "square", 0.18], "mudskip": [240, 400, "saw", 0.2], "thornarok": [130, 90, "saw", 0.2], "ptarmitten": [1000, 780, "sine", 0.14],
	"tentbat": [1300, 1500, "sine", 0.1], "dumbomaton": [320, 320, "square", 0.16], "colukite": [880, 440, "saw", 0.16], "gilamancer": [200, 330, "saw", 0.24],
}

static func _file_for(name: String) -> String:
	var f := name.replace("|say", "").replace("|hurt", "_hurt").replace("|", "_")
	return "res://audio/%s.wav" % f

static func _make(name: String) -> AudioStreamWAV:
	var fp := _file_for(name)
	if ResourceLoader.exists(fp):
		return load(fp)
	if name.begins_with("v_"):
		var sp := name.substr(2)
		var v: Array = VOICES.get(sp.get_slice("|", 0), [400, 300, "square", 0.15])
		var hurt := sp.ends_with("|hurt")
		return _wav(_tone(float(v[0]) * (0.7 if hurt else 1.0), float(v[1]) * (0.55 if hurt else 1.0), float(v[3]) * (1.4 if hurt else 0.7), String(v[2]), 1.4, 0.35))
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
			p.bus = "SFX"
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

# ---- Music: a short chiptune loop synthesised at startup (11 kHz mono, ~13 s) ----
static var music_on := true
static var _music_player: AudioStreamPlayer
static var _music_stream: AudioStreamWAV

static func _note(freq: float, t: float, wave: String) -> float:
	var ph := fmod(t * freq, 1.0)
	match wave:
		"tri": return absf(ph * 4.0 - 2.0) - 1.0
		"sq": return 1.0 if ph < 0.5 else -1.0
	return sin(ph * TAU)

static func _make_music(variant: int = 0) -> AudioStreamWAV:
	var rate := 11025
	var bpm: float = [112.0, 100.0, 124.0, 92.0][variant % 4]
	var beat := 60.0 / bpm
	var sets := [
		[[261.63, 329.63, 392.0], [220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [196.0, 246.94, 293.66]],
		[[220.0, 261.63, 329.63], [174.61, 220.0, 261.63], [261.63, 329.63, 392.0], [196.0, 246.94, 293.66]],
		[[246.94, 311.13, 369.99], [207.65, 261.63, 311.13], [185.0, 233.08, 277.18], [220.0, 277.18, 329.63]],
		[[196.0, 246.94, 293.66], [164.81, 196.0, 246.94], [220.0, 261.63, 329.63], [174.61, 220.0, 261.63]]]
	var chords: Array = sets[variant % 4]
	var bass := [65.41, 55.0, 43.65, 49.0]
	var melody := [0, 2, 4, 2, 4, 7, 4, 2, 0, 2, 4, 7, 9, 7, 4, 2]
	var pent := [0, 2, 4, 7, 9]
	var bars := 8
	var total := int(bars * 4 * beat * rate)
	var data := PackedFloat32Array()
	data.resize(total)
	for i in total:
		var t := float(i) / rate
		var b := int(t / (beat * 4.0))
		var chord: Array = chords[b % 4]
		var step := int(t / (beat * 0.5)) % 16
		var bt := fmod(t, beat * 0.5) / (beat * 0.5)
		var s := 0.0
		# arpeggio
		var af: float = chord[(int(t / (beat * 0.5))) % 3] * 2.0
		s += _note(af, t, "sq") * 0.07 * (1.0 - bt * 0.6)
		# bass on beats
		var bb := fmod(t, beat) / beat
		s += _note(bass[b % 4], t, "tri") * 0.22 * (1.0 - bb * 0.5)
		# melody (second half of each 2 bars)
		if b % 2 == 1 or b >= 4:
			var deg: int = melody[step]
			var mf: float = 523.25 * pow(2.0, float(pent[deg % 5] + 12 * (deg / 5)) / 12.0)
			s += _note(mf, t, "sq") * 0.05 * (1.0 - bt * 0.7)
		data[i] = s
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS
	w.mix_rate = rate
	w.stereo = false
	var by := PackedByteArray()
	by.resize(total * 2)
	for i in total:
		by.encode_s16(i * 2, int(clampf(data[i], -1.0, 1.0) * 32767.0))
	w.data = by
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD
	w.loop_begin = 0
	w.loop_end = total
	return w

static var _music_variant := -1

static func voice(n: Node, species: String, hurt: bool = false, vol_db: float = -14.0) -> void:
	play(n, "v_" + species + ("|hurt" if hurt else "|say"), vol_db, 120)

static var _drums_player: AudioStreamPlayer
static var _amb_player: AudioStreamPlayer

static func _looped(path: String) -> AudioStreamWAV:
	var d := (load(path) as AudioStreamWAV).duplicate() as AudioStreamWAV
	d.loop_mode = AudioStreamWAV.LOOP_FORWARD
	d.loop_begin = 0
	d.loop_end = int(round(d.get_length() * float(d.mix_rate)))
	return d

static func _mk_player(n: Node, stream: AudioStreamWAV, db: float) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "Music"
	p.stream = stream
	p.volume_db = db
	n.get_tree().root.add_child.call_deferred(p)
	return p

static func start_music(n: Node, variant: int = 0) -> void:
	setup_buses()
	if ResourceLoader.exists("res://audio/music_base.wav"):
		if _music_player == null or not is_instance_valid(_music_player):
			_music_player = _mk_player(n, _looped("res://audio/music_base.wav"), -11.0)
			_drums_player = _mk_player(n, _looped("res://audio/music_drums.wav"), -60.0)
			_amb_player = _mk_player(n, _looped("res://audio/ambient.wav"), -60.0)
		if music_on:
			_play_music.call_deferred()
		return
	if _music_player == null or not is_instance_valid(_music_player):
		_music_player = AudioStreamPlayer.new()
		_music_player.bus = "Music"
		n.get_tree().root.add_child.call_deferred(_music_player)
		if _music_stream == null or _music_variant != variant:
			_music_stream = _make_music(variant)
			_music_variant = variant
		_music_player.stream = _music_stream
		_music_player.volume_db = -14.0
	if music_on:
		_play_music.call_deferred()

static func _play_music() -> void:
	for p in [_music_player, _drums_player, _amb_player]:
		if is_instance_valid(p) and p.is_inside_tree() and not p.playing:
			p.play()

# Battle intensity: the drum layer fades in while a wave is running.
static func set_battle(on: bool) -> void:
	if is_instance_valid(_drums_player) and _drums_player.is_inside_tree():
		_drums_player.create_tween().tween_property(_drums_player, "volume_db", -9.0 if on else -60.0, 1.6)

# Ambient bed (crickets, wind, chimes) for the battle scene; off in menus.
static func set_ambient(on: bool) -> void:
	if is_instance_valid(_amb_player) and _amb_player.is_inside_tree():
		_amb_player.create_tween().tween_property(_amb_player, "volume_db", -13.0 if on else -60.0, 1.2)

static func toggle_sound(n: Node) -> bool:
	music_on = not music_on
	AudioServer.set_bus_mute(0, not music_on)
	return music_on
