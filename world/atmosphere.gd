class_name Atmosphere
extends Node3D
## Sun, ambient, fog and background. Phase changes blend smoothly; PURGE_ACTIVE goes ominous red/violet.
const LOOKS: Dictionary = {
	&"PEACE": {"sun": Color("fff0dc"), "sun_e": 1.19, "amb": Color("b9a8dc"), "amb_e": 0.87, "fog": Color("f1cdbd"), "fog_d": 0.0026, "sat": 1.0, "purge": 0.0},
	&"WARNING": {"sun": Color("ffbe80"), "sun_e": 1.12, "amb": Color("b890c0"), "amb_e": 0.77, "fog": Color("e9a07e"), "fog_d": 0.0036, "sat": 1.08, "purge": 0.25},
	&"PURGE_ACTIVE": {"sun": Color("d04088"), "sun_e": 0.7, "amb": Color("7a50e8"), "amb_e": 1.25, "fog": Color("3d0b4a"), "fog_d": 0.0056, "sat": 1.1, "purge": 1.0},
	&"RESOLUTION": {"sun": Color("e3c8ff"), "sun_e": 1.12, "amb": Color("9a88d8"), "amb_e": 0.77, "fog": Color("b58bd0"), "fog_d": 0.0038, "sat": 1.05, "purge": 0.3},
}
var phase: StringName = &"PEACE"
var time_of_day: float = 0.5 # 0..1 across the in-game day
var purge_amount: float = 0.0 # smoothed 0..1, read by presentation (HUD, water tint)
var env: Environment
var sun: DirectionalLight3D
var world_env: WorldEnvironment
var _cur: Dictionary = {}
var blend_speed: float = 1.6
var shadows_enabled: bool = false:
	set(v):
		shadows_enabled = v
		if sun != null:
			sun.shadow_enabled = v

func _init() -> void:
	name = "Atmosphere"
	env = Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.fog_enabled = true
	env.fog_sky_affect = 1.0
	env.adjustment_enabled = true
	env.tonemap_mode = Environment.TONE_MAPPER_LINEAR
	world_env = WorldEnvironment.new()
	world_env.environment = env
	add_child(world_env)
	sun = DirectionalLight3D.new()
	sun.name = "Sun"
	sun.shadow_enabled = false
	sun.directional_shadow_max_distance = 120.0
	add_child(sun)
	_cur = (LOOKS[&"PEACE"] as Dictionary).duplicate()
	_apply(1.0)

func set_phase(p: StringName, instant: bool = false) -> void:
	if not LOOKS.has(p):
		push_warning("Atmosphere: unknown phase %s" % p)
		return
	phase = p
	if instant:
		_cur = (LOOKS[p] as Dictionary).duplicate()
		purge_amount = _cur["purge"]
		_apply(1.0)

func set_time_of_day(t: float) -> void:
	time_of_day = fposmod(t, 1.0)

func _process(dt: float) -> void:
	_apply(dt)

func _apply(dt: float) -> void:
	var tgt: Dictionary = LOOKS[phase]
	var k: float = clampf(dt * blend_speed, 0.0, 1.0)
	for key in ["sun", "amb", "fog"]:
		_cur[key] = (_cur[key] as Color).lerp(tgt[key], k)
	for key in ["sun_e", "amb_e", "fog_d", "sat", "purge"]:
		_cur[key] = lerpf(_cur[key], tgt[key], k)
	purge_amount = _cur["purge"]
	# daylight arc: sun climbs from the east, sets in the west; dim at night.
	var day: float = clampf((time_of_day - 0.2) / 0.6, 0.0, 1.0)
	var elev: float = deg_to_rad(14.0 + 48.0 * sin(day * PI))
	var azim: float = lerpf(deg_to_rad(80.0), deg_to_rad(280.0), day)
	sun.rotation = Vector3(-elev, azim, 0.0)
	var daylight: float = smoothstep(0.1, 0.3, time_of_day) * (1.0 - smoothstep(0.78, 0.95, time_of_day))
	var night_dim: float = lerpf(0.35, 1.0, daylight)
	sun.light_color = _cur["sun"]
	sun.light_energy = _cur["sun_e"] * night_dim
	env.ambient_light_color = _cur["amb"]
	env.ambient_light_energy = _cur["amb_e"] * lerpf(0.7, 1.0, daylight)
	var fogc: Color = _cur["fog"]
	env.fog_light_color = fogc.darkened((1.0 - night_dim) * 0.8)
	env.background_color = env.fog_light_color
	env.fog_density = _cur["fog_d"]
	env.adjustment_saturation = _cur["sat"]
