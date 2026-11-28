class_name Settings
extends RefCounted
## Persistent user settings (user://settings.cfg).
static var master := 0.8
static var sfx := 0.8
static var music := 0.5
static var ui_scale := 1.0
static var show_numbers := true
static var hints := true
static var reduce_motion := false
static var high_contrast := false
const PATH := "user://settings.cfg"
static func load_all() -> void:
	var c := ConfigFile.new()
	if c.load(PATH) != OK: return
	master = c.get_value("audio", "master", master); sfx = c.get_value("audio", "sfx", sfx); music = c.get_value("audio", "music", music)
	ui_scale = c.get_value("ui", "scale", ui_scale); show_numbers = c.get_value("ui", "numbers", show_numbers); hints = c.get_value("ui", "hints", hints)
	reduce_motion = c.get_value("access", "reduce_motion", reduce_motion); high_contrast = c.get_value("access", "high_contrast", high_contrast)
static func save_all() -> void:
	var c := ConfigFile.new()
	c.set_value("audio", "master", master); c.set_value("audio", "sfx", sfx); c.set_value("audio", "music", music)
	c.set_value("ui", "scale", ui_scale); c.set_value("ui", "numbers", show_numbers); c.set_value("ui", "hints", hints)
	c.set_value("access", "reduce_motion", reduce_motion); c.set_value("access", "high_contrast", high_contrast)
	c.save(PATH)
static func apply() -> void:
	var bus := AudioServer.get_bus_index("Master")
	if bus >= 0: AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(master, 0.0001)))
