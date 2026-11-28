class_name BCAudio
extends Node
## CC0 sound: Kenney RPG sound effects + OpenGameArt music (see assets/CREDITS.md).

static var instance: BCAudio
var day_music: AudioStreamPlayer
var night_music: AudioStreamPlayer
var cache := {}
var muted := false
var day_f := 1.0

func _ready() -> void:
	instance = self
	name = "Audio"
	day_music = _music("res://assets/audio/music/TownTheme.mp3")
	night_music = _music("res://assets/audio/music/CrystalCave.mp3")

func _music(path: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	var st = load(path)
	if st is AudioStreamMP3: st.loop = true
	p.stream = st
	p.volume_db = -60.0
	add_child(p)
	if st != null: p.play()
	return p

static func sfx(sound: String, vol_db: float = -6.0, pitch: float = 1.0) -> void:
	if instance == null or instance.muted: return
	instance._play(sound, vol_db, pitch)

func _play(sound: String, vol_db: float, pitch: float) -> void:
	if not cache.has(sound):
		cache[sound] = load("res://assets/audio/sfx/%s.ogg" % sound)
	if cache[sound] == null: return
	var p := AudioStreamPlayer.new()
	p.stream = cache[sound]
	p.volume_db = vol_db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()

func set_day_factor(f: float, dt: float) -> void:
	day_f = lerpf(day_f, f, minf(1.0, dt * 0.8))
	var base := -60.0 if muted else -15.0
	if day_music != null: day_music.volume_db = lerpf(-60.0, base, day_f) if not muted else -80.0
	if night_music != null: night_music.volume_db = lerpf(-60.0, base + 1.0, 1.0 - day_f) if not muted else -80.0

func toggle_mute() -> void:
	muted = not muted
