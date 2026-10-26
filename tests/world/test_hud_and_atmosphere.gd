extends TestCase
## HUD banner/phase colours, rations warning, prompt, inventory; atmosphere phase looks.

## The test runner executes inside SceneTree._init (no main loop yet), so nodes are built
## without entering the tree: _ready() is invoked by hand.
func _hud() -> Hud:
	var h := Hud.new()
	h._ready()
	return h

func _base(phase: StringName) -> Dictionary:
	return {"day": 3, "time_of_day": 0.4, "phase": phase, "rations": 12, "rations_per_day": 4, "class_label": "Judd - Farmer", "hp": 50.0, "hp_max": 100.0, "prompt": "", "inventory": []}

func test_phase_banner_text_and_colours() -> void:
	var h: Hud = _hud()
	var seen := {}
	for ph in [&"PEACE", &"WARNING", &"PURGE_ACTIVE", &"RESOLUTION"]:
		h.set_model(_base(ph))
		check(h.banner_title.text.contains(UiStyle.PHASE_TITLES[ph]), "banner shows %s" % ph)
		var c: Color = h._banner_style.bg_color
		check(c.is_equal_approx(UiStyle.PHASE_COLORS[ph]), "banner colour for %s" % ph)
		seen[c.to_html()] = true
	eq(seen.size(), 4, "each phase has a distinct banner colour")
	var pm: ShaderMaterial = h.purge_veil.material
	h.set_model(_base(&"PURGE_ACTIVE"))
	eq(float(pm.get_shader_parameter("amount")), 1.0, "purge veil on during purge")
	h.set_model(_base(&"PEACE"))
	eq(float(pm.get_shader_parameter("amount")), 0.0, "purge veil off in peace")
	check(h.banner_title.text.begins_with("DAY 3"), "day number shown")
	h.free()

func test_rations_class_hp_prompt() -> void:
	var h: Hud = _hud()
	h.set_model(_base(&"PEACE"))
	check(h.rations_label.text.contains("12"), "rations count")
	check(h.rations_sub.text.contains("3.0"), "days of food = 3.0 (%s)" % h.rations_sub.text)
	eq(h.class_label.text, "JUDD - FARMER", "class label upper-cased")
	eq(h.hp_bar.value, 50.0, "hp bar value")
	eq(h.prompt_chip.visible, false, "no prompt -> hidden")
	var m: Dictionary = _base(&"PEACE")
	m["prompt"] = "[E]  Harvest"
	m["rations"] = 2
	h.set_model(m)
	eq(h.prompt_chip.visible, true, "prompt shown")
	eq(h.prompt_label.text, "[E]  Harvest", "prompt text")
	check(h.rations_label.get_theme_color("font_color").is_equal_approx(UiStyle.BAD), "starving warning colour when < 1 day")
	h.free()

func test_inventory_hotbar_and_bag() -> void:
	var h: Hud = _hud()
	var m: Dictionary = _base(&"PEACE")
	var inv: Array = []
	for i in 8:
		inv.append({"id": "x%d" % i, "name": "Item%d" % i, "count": i + 1, "color": Color.RED})
	m["inventory"] = inv
	h.set_model(m)
	var shown := 0
	for i in Hud.HOTBAR_SLOTS:
		var sw: ColorRect = h.hotbar.get_child(i).get_child(0).get_node("Swatch")
		if sw.visible:
			shown += 1
	eq(shown, Hud.HOTBAR_SLOTS, "hotbar filled up to its slot count")
	h.set_bag_open(true)
	eq(h.bag_panel.visible, true, "bag opens")
	h.toggle_bag()
	eq(h.bag_panel.visible, false, "bag toggles closed")
	h.free()

func test_hud_fits_landscape_phone() -> void:
	var h: Hud = _hud()
	h.set_model(_base(&"PEACE"))
	var vs := Vector2(1280, 720)
	# banner is centred, 380 wide: leaves both top corners free for class + rations chips
	check(absf(h.banner.offset_left + h.banner.offset_right) < 1.0, "banner horizontally centred")
	check(h.banner.offset_right - h.banner.offset_left <= vs.x * 0.35, "banner leaves room for corner chips")
	h.free()

func test_atmosphere_purge_is_red_violet_and_blends() -> void:
	var a := Atmosphere.new()
	a.set_phase(&"PEACE", true)
	a.set_time_of_day(0.5)
	a._apply(0.0)
	var peace_fog: Color = a.env.fog_light_color
	var peace_sun: Color = a.sun.light_color
	eq(a.purge_amount, 0.0, "peace purge amount 0")
	a.set_phase(&"PURGE_ACTIVE", true)
	a._apply(0.0)
	eq(a.purge_amount, 1.0, "purge amount 1")
	var fog: Color = a.env.fog_light_color
	check(fog.g < fog.r and fog.g < fog.b, "purge fog is violet/magenta (g lowest)")
	check(fog.v < peace_fog.v, "purge fog darker than peace")
	check(a.sun.light_color.r > a.sun.light_color.g, "purge sun reddish")
	check(not a.sun.light_color.is_equal_approx(peace_sun), "sun colour shifts")
	# smooth blend back to peace
	a.set_phase(&"PEACE")
	var prev: float = a.purge_amount
	a._apply(0.1)
	check(a.purge_amount < prev and a.purge_amount > 0.0, "purge amount eases out, not a snap")
	for i in 200:
		a._apply(0.1)
	check(a.purge_amount < 0.01, "converges to peace")
	a.free()

func test_atmosphere_daylight_arc() -> void:
	var a := Atmosphere.new()
	a.set_phase(&"PEACE", true)
	a.set_time_of_day(0.5)
	a._apply(0.0)
	var noon: float = a.sun.light_energy
	a.set_time_of_day(0.02)
	a._apply(0.0)
	check(a.sun.light_energy < noon, "night dimmer than noon")
	a.free()

func test_tilt_shift_nodes() -> void:
	var t := TiltShift.new()
	check(t.rect.material is ShaderMaterial, "tilt shift has shader")
	t.enabled = false
	eq(t.rect.visible, false, "can be disabled to save fill-rate")
	t.free()
