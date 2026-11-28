class_name Synth
extends RefCounted
## Procedural sound: every effect is synthesized at startup from oscillators + filtered noise.
const SR := 22050
static var cache: Dictionary = {}

static func _wav(samples: PackedFloat32Array, loop: bool = false) -> AudioStreamWAV:
	var w := AudioStreamWAV.new()
	w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = SR; w.stereo = false
	var b := PackedByteArray(); b.resize(samples.size() * 2)
	for i in samples.size():
		b.encode_s16(i * 2, int(clampf(samples[i], -1.0, 1.0) * 32000.0))
	w.data = b
	if loop:
		w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_begin = 0; w.loop_end = samples.size()
	return w

static func _env(t: float, a: float, d: float) -> float:
	return minf(t / maxf(a, 0.0001), 1.0) * exp(-t / maxf(d, 0.0001))

static func make(kind: String) -> AudioStreamWAV:
	if cache.has(kind): return cache[kind]
	var rng := RandomNumberGenerator.new(); rng.seed = hash(kind)
	var n := int(SR * 0.4); var out := PackedFloat32Array()
	var loop := false
	match kind:
		"bite":
			n = int(SR * 0.16); out.resize(n); var lp := 0.0
			for i in n:
				var t := float(i) / SR; lp = lerpf(lp, rng.randf_range(-1, 1), 0.35)
				out[i] = (lp * 0.8 + sin(TAU * 140.0 * t) * 0.5) * _env(t, 0.002, 0.045)
		"hit":
			n = int(SR * 0.22); out.resize(n)
			for i in n:
				var t := float(i) / SR
				out[i] = (sin(TAU * (90.0 - 40.0 * t) * t) * 0.9 + rng.randf_range(-0.3, 0.3)) * _env(t, 0.001, 0.07)
		"swing":
			n = int(SR * 0.18); out.resize(n); var lp2 := 0.0
			for i in n:
				var t := float(i) / SR; lp2 = lerpf(lp2, rng.randf_range(-1, 1), 0.12 + t * 1.5)
				out[i] = lp2 * 0.6 * sin(PI * t / 0.18)
		"step":
			n = int(SR * 0.08); out.resize(n); var lp3 := 0.0
			for i in n:
				var t := float(i) / SR; lp3 = lerpf(lp3, rng.randf_range(-1, 1), 0.2)
				out[i] = lp3 * 0.35 * _env(t, 0.002, 0.02)
		"chirp":
			n = int(SR * 0.25); out.resize(n)
			for i in n:
				var t := float(i) / SR
				var f := 2400.0 + 1400.0 * sin(t * 40.0) + 600.0 * t * 10.0
				out[i] = sin(TAU * f * t) * 0.3 * _env(t, 0.01, 0.08)
		"chime":
			n = int(SR * 0.9); out.resize(n)
			for i in n:
				var t := float(i) / SR
				out[i] = (sin(TAU * 659.0 * t) + 0.6 * sin(TAU * 988.0 * t) + 0.35 * sin(TAU * 1318.0 * t)) * 0.22 * _env(t, 0.005, 0.28)
		"click":
			n = int(SR * 0.05); out.resize(n)
			for i in n:
				var t := float(i) / SR
				out[i] = sin(TAU * 900.0 * t) * 0.3 * _env(t, 0.001, 0.012)
		"death":
			n = int(SR * 0.9); out.resize(n)
			for i in n:
				var t := float(i) / SR
				out[i] = (sin(TAU * (220.0 - 150.0 * t) * t) * 0.5 + sin(TAU * (110.0 - 60.0 * t) * t) * 0.4) * _env(t, 0.01, 0.35)
		"wind":
			loop = true; n = SR * 4; out.resize(n); var lp4 := 0.0
			for i in n:
				var t := float(i) / SR; lp4 = lerpf(lp4, rng.randf_range(-1, 1), 0.04)
				var swell := 0.6 + 0.4 * sin(TAU * t / 4.0)       # period divides loop: seamless
				out[i] = lp4 * 0.55 * swell
		"water":
			loop = true; n = SR * 4; out.resize(n); var lp5 := 0.0
			for i in n:
				var t := float(i) / SR; lp5 = lerpf(lp5, rng.randf_range(-1, 1), 0.09)
				out[i] = lp5 * 0.4 * (0.7 + 0.3 * sin(TAU * t * 2.0 / 4.0 * 3.0))
		_:
			out.resize(n)
	var w := _wav(out, loop)
	cache[kind] = w
	return w

## Voice pool owned by a scene; 2D-positioned one-shots + looping beds.
class Bank extends Node:
	var voices: Array = []
	var beds: Dictionary = {}
	func _ready() -> void:
		for i in 12:
			var p := AudioStreamPlayer.new(); add_child(p); voices.append(p)
		for k in ["wind", "water"]:
			var p := AudioStreamPlayer.new(); p.stream = Synth.make(k); p.volume_db = -80.0; add_child(p); p.play(); beds[k] = p
	func play(kind: String, vol: float = 1.0, pitch: float = 1.0) -> void:
		var v: AudioStreamPlayer = null
		for p in voices: if not p.playing: v = p; break
		if v == null: return
		v.stream = Synth.make(kind); v.pitch_scale = pitch * randf_range(0.93, 1.07)
		v.volume_db = linear_to_db(clampf(vol * Settings.sfx, 0.0001, 1.0)); v.play()
	func set_beds(wind: float, water: float) -> void:
		if beds.is_empty(): return
		beds["wind"].volume_db = linear_to_db(clampf(wind * Settings.music, 0.0001, 1.0))
		beds["water"].volume_db = linear_to_db(clampf(water * Settings.music, 0.0001, 1.0))
