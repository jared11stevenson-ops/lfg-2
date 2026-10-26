extends TestCase
## Day/night colour cycle, shadow opt-in, rules-clock mapping, water night uniform.

func _lum(c: Color) -> float:
	return 0.299 * c.r + 0.587 * c.g + 0.114 * c.b

func test_weights_continuous_and_bounded() -> void:
	var prev: Dictionary = Atmosphere.tod_weights(0.0)
	var t := 0.0
	var worst := 0.0
	while t < 1.0:
		t += 0.002
		var w: Dictionary = Atmosphere.tod_weights(t)
		for k in ["night", "dawn", "dusk"]:
			worst = maxf(worst, absf(float(w[k]) - float(prev[k])))
			check(float(w[k]) >= 0.0 and float(w[k]) <= 1.0001, "%s in 0..1 at %.3f" % [k, t])
		prev = w
	check(worst < 0.06, "no colour pops across the day (max step %.3f)" % worst)
	check(float(Atmosphere.tod_weights(0.5)["night"]) == 0.0, "noon is not night")
	check(float(Atmosphere.tod_weights(0.0)["night"]) > 0.99, "midnight is night")
	check(float(Atmosphere.tod_weights(0.2)["dawn"]) > 0.95, "dawn peaks at 0.2")
	check(float(Atmosphere.tod_weights(0.8)["dusk"]) > 0.95, "dusk peaks at 0.8")

func test_colours_noon_dusk_night() -> void:
	var look: Dictionary = Atmosphere.LOOKS[&"PEACE"]
	var noon: Dictionary = Atmosphere.tod_colors(look["sun"], look["amb"], look["fog"], 0.5)
	var dusk: Dictionary = Atmosphere.tod_colors(look["sun"], look["amb"], look["fog"], 0.8)
	var night: Dictionary = Atmosphere.tod_colors(look["sun"], look["amb"], look["fog"], 0.0)
	check(_lum(noon["fog"]) > _lum(night["fog"]) + 0.3, "sky is much brighter at noon than at night")
	check((night["fog"] as Color).b > (night["fog"] as Color).r, "night is blue")
	check((dusk["sun"] as Color).r > (dusk["sun"] as Color).b, "dusk sun is warm")
	check((dusk["fog"] as Color).r > (noon["fog"] as Color).r * 0.9 and (dusk["fog"] as Color).b != (noon["fog"] as Color).b, "dusk shifts the fog")
	check(_lum(noon["amb"]) > _lum(night["amb"]), "ambient dims at night")
	var fogs: Dictionary = {}
	for t in [0.0, 0.2, 0.5, 0.8, 0.9]:
		fogs[(Atmosphere.tod_colors(look["sun"], look["amb"], look["fog"], t)["fog"] as Color).to_html()] = true
	eq(fogs.size(), 5, "five different skies across the day")

func test_atmosphere_applies_cycle_and_night_amount() -> void:
	var a := Atmosphere.new()
	a.set_phase(&"PEACE", true)
	a.set_time_of_day(0.5)
	a._apply(10.0)
	var noon_sky: Color = a.env.background_color
	eq(a.night_amount, 0.0, "no night at noon")
	a.set_time_of_day(0.97)
	a._apply(10.0)
	check(a.night_amount > 0.9, "night amount high at 0.97 (%.2f)" % a.night_amount)
	check(_lum(a.env.background_color) < _lum(noon_sky) - 0.25, "background darkens at night")
	check(a.sun.light_energy < 1.0, "sun dims at night")
	a.free()

func test_rules_clock_mapping_makes_purge_a_night() -> void:
	var dusk: float = Atmosphere.visual_tod(Calendar.PURGE_START_TOD)
	check(float(Atmosphere.tod_weights(dusk)["dusk"]) > 0.6 or float(Atmosphere.tod_weights(dusk)["night"]) > 0.2, "Purge start looks like dusk")
	var mid: float = Atmosphere.visual_tod(0.75)
	check(float(Atmosphere.tod_weights(mid)["night"]) > 0.9, "the middle of the Purge is dark")
	var morning: float = Atmosphere.visual_tod(0.02)
	check(float(Atmosphere.tod_weights(morning)["night"]) < 0.3, "a new day starts bright")

func test_shadows_are_opt_in() -> void:
	var a := Atmosphere.new()
	eq(a.sun.shadow_enabled, false, "shadows off by default")
	a.shadows_enabled = true
	eq(a.sun.shadow_enabled, true, "toggle on")
	a.shadows_enabled = false
	eq(a.sun.shadow_enabled, false, "toggle off")
	a.free()
	var v := WorldView.new()
	var mmi := MultiMeshInstance3D.new()
	v.add_child(mmi)
	v.set_cast_shadows(true)
	eq(mmi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_ON, "view casters on")
	v.set_cast_shadows(false)
	eq(mmi.cast_shadow, GeometryInstance3D.SHADOW_CASTING_SETTING_OFF, "view casters off")
	var rig: CharacterRig = CharacterKit.build_class("lfg:class/judd")
	rig.set_cast_shadows(true)
	var on_count := 0
	for p in rig.parts:
		if ((p["node"] as Node3D).get_child(0) as MeshInstance3D).cast_shadow == GeometryInstance3D.SHADOW_CASTING_SETTING_ON:
			on_count += 1
	eq(on_count, rig.parts.size(), "rig parts cast when enabled")
	rig.free()
	v.free()

func test_water_shader_has_night_and_glints() -> void:
	var src: String = FileAccess.get_file_as_string("res://world/shaders/water.gdshader")
	check(src.contains("uniform float night"), "water dims at night")
	check(src.contains("glint"), "water has twinkling glints")
	var v := WorldView.new()
	v.set_night_amount(0.7)
	eq(float(v.water_mat.get_shader_parameter("night")), 0.7, "night uniform set")
	v.free()
