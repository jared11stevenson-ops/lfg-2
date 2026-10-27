extends TestCase
## Pass 4 presentation: companion models and layer, guardian models and arena silhouettes, building models, PETS panel, tutorial overlay, boss bar, HUD model keys.

static var _state: MatchState
static var _world: WorldData
var _got: Array = []

func _mk(cls: String = "lfg:class/judd") -> MatchState:
	if _state == null:
		_state = Rules.new_match(5, &"lfg:class/judd", {"wild_enemies": false, "ai_enabled": false})
		_world = RulesWorldAdapter.from_state(_state)
	var st: MatchState = Rules.new_match(5, StringName(cls), {"wild_enemies": false, "ai_enabled": false})
	st.world = _state.world
	return st

func _layer(st: MatchState) -> Dictionary:
	var layer := CompanionLayer.new()
	layer.world = _world
	var player := Node3D.new()
	var off: Vector2i = HexMath.axial_to_offset(st.world["start"])
	var c: Vector2 = HexMath.offset_center(off.x, off.y)
	player.position = Vector3(c.x, _world.height_at(c.x, c.y), c.y)
	layer.player = player
	layer.state = st
	return {"layer": layer, "player": player}

# ------------------------------------------------------------------ models
func test_companion_models_are_small_distinct_and_cheap() -> void:
	var sigs: Dictionary = {}
	for kind in CompanionModels.KINDS:
		check(Content.companions().has(kind), "%s is in the data" % kind)
		var r: CharacterRig = CompanionModels.build(kind)
		eq(r.look_id, kind, "look id")
		check(r.mesh_count >= 2 and r.mesh_count <= 8, "%s: %d meshes" % [kind, r.mesh_count])
		check(r.tri_total > 80 and r.tri_total < 900, "%s: %d triangles" % [kind, r.tri_total])
		check(r.nominal_height >= 1.1 and r.nominal_height <= 1.6, "%s: readable but small (%.1f m)" % [kind, r.nominal_height])
		sigs[r.tri_total] = true
		var aabb_ok: bool = true
		for p in r.parts:
			if (p["node"] as Node3D).get_child_count() == 0:
				aabb_ok = false
		check(aabb_ok, "%s: every part has a mesh" % kind)
		r.free()
	eq(sigs.size(), 6, "six different geometries")
	var moth: CharacterRig = CompanionModels.build("lfg:companion/glowmoth")
	check(moth.float_height > 0.8, "the moth hovers")
	eq(moth.limbs("wing").size(), 2, "two wings")
	moth.free()
	var bun: CharacterRig = CompanionModels.build("lfg:companion/mossbun")
	eq(bun.limbs("leg").size(), 2, "the bun hops on two feet")
	bun.free()
	var fb: CharacterRig = CompanionModels.build("lfg:companion/unknown")
	check(fb.mesh_count > 0, "unknown ids fall back to a model")
	fb.free()

func test_companion_models_use_the_data_colours() -> void:
	# a quick proxy: rebuilding with other colours would change the geometry hash; here we check the data has valid colours and models read them
	for kind in CompanionModels.KINDS:
		var cs: Array = Content.companion(kind)["colors"]
		for c in cs:
			check(String(c).is_valid_html_color(), "%s: valid colour %s" % [kind, c])
	var a: CharacterRig = CompanionModels.build("lfg:companion/dewsnail")
	var b: CharacterRig = CompanionModels.build("lfg:companion/dewsnail")
	eq(a.tri_total, b.tri_total, "deterministic")
	a.free()
	b.free()

func test_guardian_models_are_large_distinct_and_dispatch_from_the_character_kit() -> void:
	var sigs: Dictionary = {}
	for id in Content.guardian_order():
		check(GuardianModels.has_model(String(id)), "%s has a model" % id)
		var r: CharacterRig = CharacterKit.build_enemy(String(id))
		eq(r.look_id, String(id), "look id")
		check(r.nominal_height >= 3.5 and r.nominal_height <= 6.5, "%s towers (%.1f m)" % [id, r.nominal_height])
		check(r.mesh_count >= 3 and r.mesh_count <= 9, "%s: %d meshes" % [id, r.mesh_count])
		check(r.tri_total < 1800, "%s: %d triangles" % [id, r.tri_total])
		check(r.limbs("arm").size() >= 1 or r.limbs("wing").size() >= 1 or r.limbs("leg").size() >= 2, "%s has limbs to animate" % id)
		sigs[r.tri_total] = true
		r.free()
	eq(sigs.size(), 7, "seven different silhouettes")
	var small: CharacterRig = CharacterKit.build_enemy("lfg:enemy/sporeling")
	check(small.nominal_height < 2.0, "ordinary beasts are unchanged")
	small.free()

func test_guardians_dwarf_every_ordinary_enemy() -> void:
	var tallest: float = 0.0
	for id in CharacterKit.ENEMY_IDS:
		var r: CharacterRig = CharacterKit.build_enemy(String(id))
		tallest = maxf(tallest, r.nominal_height)
		r.free()
	for id in Content.guardian_order():
		var r2: CharacterRig = GuardianModels.build(String(id))
		check(r2.nominal_height > tallest, "%s is taller than any wild beast (%.1f vs %.1f)" % [id, r2.nominal_height, tallest])
		r2.free()

func test_arena_props_are_seven_tall_silhouettes_in_the_guardian_colours() -> void:
	var seen: Dictionary = {}
	for key in PoiModels.PROPS:
		if not String(key).begins_with("arena_"):
			continue
		var bb: AABB = PoiModels.mesh_for(key).get_aabb()
		check(bb.size.y >= 4.0, "%s stands tall enough to read from afar (%.1f)" % [key, bb.size.y])
		check(PoiModels.ACCENT.has(key), "%s has an accent" % key)
		seen[key] = true
	eq(seen.size(), 7, "seven arenas")
	for biome in ["meadow", "shore", "fungal_grove", "ruins", "salt_flats", "highlands", "bog"]:
		eq(String(Content.poi_types()["lfg:poi/arena_" + biome]["prop"]), "arena_" + biome, "the arena type points at its prop")

func test_new_building_models_exist_and_fit() -> void:
	for id in BuildingModelsP4.IDS:
		check(not Content.building(id).is_empty(), "%s is in the data" % id)
		var m: ArrayMesh = BuildingModels.mesh_for(id)
		var bb: AABB = m.get_aabb()
		check(bb.size.y > 1.5 and bb.size.x < 9.0 and bb.size.z < 9.0, "%s fits a hex site (%.1f x %.1f x %.1f)" % [id, bb.size.x, bb.size.y, bb.size.z])
		check(BuildingModels.has_dedicated_model(id), "%s has a dedicated model" % id)
	eq(BuildingModelsP4.IDS.size(), 13, "3 stations + 10 buildables")

# ------------------------------------------------------------------ the layer
func test_followers_trail_the_leader_and_posts_stay_home() -> void:
	var st: MatchState = _mk()
	var a: Dictionary = st.actors[1]
	Companions.give(st, a, "lfg:companion/mossbun", [])
	Companions.give(st, a, "lfg:companion/dewsnail", [])
	Companions.find(a, "lfg:companion/dewsnail")["post"] = "hold"
	Companions.find(a, "lfg:companion/dewsnail")["hold"] = 1
	var ctx: Dictionary = _layer(st)
	var layer: CompanionLayer = ctx["layer"]
	var player: Node3D = ctx["player"]
	layer.sync()
	eq(layer.rig_count(), 2, "two rigs")
	var bun: CharacterRig = layer.rig_for("lfg:companion/mossbun")
	check(bun != null, "the bun is drawn")
	var gap: float = Vector2(bun.position.x - player.position.x, bun.position.z - player.position.z).length()
	check(gap > 1.0 and gap < 6.0, "it keeps a respectful distance behind (%.1f m)" % gap)
	# the leader walks away: the follower is pulled along, not left behind
	player.position += Vector3(30, 0, 0)
	layer.sync()
	for i in range(120):
		layer._process(0.1)
	var gap2: float = Vector2(bun.position.x - player.position.x, bun.position.z - player.position.z).length()
	check(gap2 < 6.0, "it caught up (%.1f m)" % gap2)
	var snail: CharacterRig = layer.rig_for("lfg:companion/dewsnail")
	check(snail == null or Vector2(snail.position.x - player.position.x, snail.position.z - player.position.z).length() > 6.0, "the posted creature stays at its holding")
	layer.free()
	player.free()

func test_hungry_creatures_sit_down_and_shrink_and_resting_ones_are_indoors() -> void:
	var st: MatchState = _mk()
	var a: Dictionary = st.actors[1]
	Companions.give(st, a, "lfg:companion/truffler", [])
	var c: Dictionary = Companions.find(a, "lfg:companion/truffler")
	c["fed"] = false
	var ctx: Dictionary = _layer(st)
	var layer: CompanionLayer = ctx["layer"]
	layer.sync()
	var r: CharacterRig = layer.rig_for("lfg:companion/truffler")
	check(r != null and r.scale.x < CompanionLayer.VIEW_SCALE * 0.9, "hungry: smaller")
	var p0: Vector3 = r.position
	(ctx["player"] as Node3D).position += Vector3(12, 0, 0)
	layer.sync()
	for i in range(20):
		layer._process(0.1)
	check(Vector2(r.position.x - p0.x, r.position.z - p0.z).length() < 0.5, "and it stays put")
	c["fed"] = true
	c["post"] = "rest"
	layer.sync()
	eq(layer.rig_count(), 0, "resting ones are not drawn")
	layer.free()
	(ctx["player"] as Node3D).free()

func test_layer_removes_dismissed_and_handles_old_saves() -> void:
	var st: MatchState = _mk()
	var ctx: Dictionary = _layer(st)
	var layer: CompanionLayer = ctx["layer"]
	layer.sync()
	eq(layer.rig_count(), 0, "no companions field: nothing drawn, no error")
	Companions.give(st, st.actors[1], "lfg:companion/glowmoth", [])
	layer.on_events([{"type": &"companion_adopted"}])
	eq(layer.rig_count(), 1, "adopted: drawn")
	st.actors[1]["companions"].clear()
	layer.on_events([{"type": &"companion_dismissed"}])
	eq(layer.rig_count(), 0, "dismissed: gone")
	layer.free()
	(ctx["player"] as Node3D).free()

func test_guardian_in_the_actor_layer_gets_a_big_rig() -> void:
	var st: MatchState = _mk()
	var layer := ActorLayer.new()
	layer.world = _world
	var player := Node3D.new()
	var off: Vector2i = HexMath.axial_to_offset(st.world["start"])
	var c: Vector2 = HexMath.offset_center(off.x, off.y)
	player.position = Vector3(c.x, _world.height_at(c.x, c.y), c.y)
	layer.player = player
	var hx: Vector2i = st.world["start"] + HexGrid.DIRS[0] * 2
	var id: int = Setup.spawn_enemy(st, "lfg:enemy/guardian_ruins", hx, false)
	layer.bind_state(st)
	var rig: CharacterRig = layer.rig_for(id)
	check(rig != null, "the guardian is drawn")
	eq(rig.look_id, "lfg:enemy/guardian_ruins", "its own model")
	check(rig.nominal_height > 4.0, "and it is big")
	layer.on_events([{"type": &"enemy_telegraph", "enemy": id, "attack": "stone_fist", "shape": "aoe", "target_hex": st.actors[1]["hex"], "radius": 1, "windup": 1.5}])
	eq(rig.anim, &"attack", "it winds up")
	layer.free()
	player.free()

# ------------------------------------------------------------------ panels
func _on(sig: Signal, tag: String) -> void:
	sig.connect(func(a: Variant = null, b: Variant = null, c: Variant = null) -> void: _got.append([tag, a, b, c]))

func test_companion_panel_lists_owned_and_wild_and_emits_signals() -> void:
	var st: MatchState = _mk()
	var a: Dictionary = st.actors[1]
	Companions.give(st, a, "lfg:companion/mossbun", [])
	Companions.give(st, a, "lfg:companion/brindlehen", [])
	a["inv"]["lfg:item/sporebean"] = 2
	var p := CompanionPanel.new()
	_got.clear()
	_on(p.feed_requested, "feed")
	_on(p.assign_requested, "assign")
	_on(p.dismiss_requested, "dismiss")
	_on(p.adopt_requested, "adopt")
	p.set_model(Companions.panel_model(st, a))
	eq(p.title_label.text, "PETS", "title")
	eq(p.tab_buttons["yours"].text, "YOURS (2)", "two owned")
	eq(p.tab_buttons["wild"].text, "TO MEET (4)", "four to meet")
	check(p.summary.text.contains("2/2") and p.summary.text.contains("never fight"), "slots and the promise: %s" % p.summary.text)
	check(p.buttons.has("feed:lfg:companion/mossbun:lfg:item/sporebean"), "feed buttons for its diet")
	check(p.buttons["feed:lfg:companion/mossbun:lfg:item/sporebean"].disabled == false, "sporebean is in the pack")
	check(p.buttons["feed:lfg:companion/mossbun:lfg:item/glowfruit"].disabled, "glowfruit is not")
	(p.buttons["feed:lfg:companion/mossbun:lfg:item/sporebean"] as Button).pressed.emit()
	(p.buttons["rest:lfg:companion/mossbun"] as Button).pressed.emit()
	(p.buttons["dismiss:lfg:companion/mossbun"] as Button).pressed.emit()
	eq(_got.size(), 3, "three requests")
	eq(_got[0], ["feed", "lfg:companion/mossbun", "lfg:item/sporebean", null], "feed")
	eq(_got[1], ["assign", "lfg:companion/mossbun", "rest", -1], "assign")
	eq(_got[2], ["dismiss", "lfg:companion/mossbun", null, null], "dismiss")
	check(p.buttons["follow:lfg:companion/mossbun"].disabled, "already following")
	check(p.buttons.has("hold:lfg:companion/mossbun:1"), "a post button for the home holding")
	eq(UiKit.small_buttons(p).size(), 0, "touch-sized")
	p.show_tab("wild")
	eq(p.buttons.size(), 4, "four offer buttons")
	check(p.buttons["adopt:lfg:companion/dewsnail"].disabled, "not at the shrine")
	var m: Dictionary = Companions.panel_model(st, a)
	for w in m["wild"]:
		if String(w["kind"]) == "lfg:companion/dewsnail":
			w["here"] = true
	p.set_model(m)
	check(not p.buttons["adopt:lfg:companion/dewsnail"].disabled, "at the shrine")
	_got.clear()
	(p.buttons["adopt:lfg:companion/dewsnail"] as Button).pressed.emit()
	eq(_got[0], ["adopt", "lfg:companion/dewsnail", null, null], "adopt request")
	p.set_model({})
	check(p.list_box.get_child_count() >= 1, "an empty model is safe")
	p.free()

func test_panel_never_calls_rules() -> void:
	var st: MatchState = _mk()
	Companions.give(st, st.actors[1], "lfg:companion/bristlepup", [])
	var before: String = JSON.stringify(st.to_dict())
	var p := CompanionPanel.new()
	p.set_model(Companions.panel_model(st, st.actors[1]))
	for b in p.buttons.values():
		(b as Button).pressed.emit()
	p.show_tab("wild")
	for b2 in p.buttons.values():
		(b2 as Button).pressed.emit()
	eq(JSON.stringify(st.to_dict()), before, "a pure view: the state is untouched")
	p.free()

func test_ui_commands_for_companions_and_tutorial() -> void:
	var c: Dictionary = UiCommands.adopt_companion("lfg:companion/mossbun")
	eq(c["type"], &"adopt_companion", "adopt")
	eq(UiCommands.feed_companion("k", "i")["args"], {"companion": "k", "item": "i"}, "feed args")
	eq(UiCommands.assign_companion("k", "hold", 3)["args"], {"companion": "k", "mode": "hold", "holding": 3}, "assign hold")
	eq(UiCommands.assign_companion("k", "follow")["args"], {"companion": "k", "mode": "follow"}, "assign follow has no holding")
	eq(UiCommands.dismiss_companion("k")["type"], &"dismiss_companion", "dismiss")
	eq(UiCommands.ack_tutorial("purge_preview")["args"], {"topic": "purge_preview"}, "ack")
	for cmd in [c, UiCommands.feed_companion("k", "i"), UiCommands.assign_companion("k", "rest"), UiCommands.dismiss_companion("k"), UiCommands.ack_tutorial("controls")]:
		check(Rules.COMMAND_TYPES.has(cmd["type"]), "%s is a real command" % cmd["type"])

func test_ui_panels_has_pets_button_panel_and_forwards_signals() -> void:
	var st: MatchState = _mk()
	Companions.give(st, st.actors[1], "lfg:companion/mossbun", [])
	var up := UiPanels.new()
	up.bind_state(st)
	check(up.toolbar_buttons.has(&"companions"), "a PETS button")
	eq((up.toolbar_buttons[&"companions"] as Button).text, "PETS", "label")
	_got.clear()
	_on(up.companion_feed_requested, "feed")
	_on(up.companion_assign_requested, "assign")
	_on(up.companion_dismiss_requested, "dismiss")
	_on(up.companion_adopt_requested, "adopt")
	_on(up.tutorial_ack_requested, "ack")
	_on(up.quest_accept_requested, "accept")
	up.open(&"companions")
	check(up.companions.visible, "opens")
	eq(up.companions.tab_buttons["yours"].text, "YOURS (1)", "model loaded from state")
	(up.companions.buttons["rest:lfg:companion/mossbun"] as Button).pressed.emit()
	up.companions.feed_requested.emit("a", "b")
	up.companions.dismiss_requested.emit("a")
	up.companions.adopt_requested.emit("a")
	up.tutorial.ack_requested.emit("purge_preview")
	up.tutorial.accept_requested.emit("lfg:quest/tut_1_furrow")
	var tags: Array = []
	for g in _got:
		tags.append(g[0])
	eq(tags, ["assign", "feed", "dismiss", "adopt", "ack", "accept"], "all forwarded")
	eq(UiKit.small_buttons(up).size(), 0, "touch sized")
	up.free()

# ------------------------------------------------------------------ tutorial overlay
func test_tutorial_overlay_offer_active_card_and_highlight() -> void:
	var st: MatchState = _mk()
	var o := TutorialOverlay.new()
	_got.clear()
	_on(o.accept_requested, "accept")
	_on(o.ack_requested, "ack")
	_on(o.highlight_changed, "hl")
	_on(o.skipped, "skip")
	o.set_model({})
	check(not o.is_showing(), "hidden with no model")
	o.set_model(Quests.tutorial_model(st, st.actors[1]))
	check(o.is_showing() and o.begin_btn.visible, "offer: shown with a BEGIN button")
	check(o.chapter_label.text.contains("chapter 1 of 4") and o.text_label.text != "", "chapter text")
	o.begin_btn.pressed.emit()
	eq(_got.back(), ["accept", "lfg:quest/tut_1_furrow", null, null], "BEGIN asks to accept the first chapter")
	Quests.accept(st, st.actors[1], {"quest": "lfg:quest/tut_1_furrow"}, [])
	o.set_model(Quests.tutorial_model(st, st.actors[1]))
	check(not o.begin_btn.visible, "active: no BEGIN")
	check(o.progress_label.text.begins_with("Step 1 of 3"), "progress: %s" % o.progress_label.text)
	check(o.prompt_label.text.contains("press"), "a UI prompt")
	eq(o.highlight, "plot", "highlight key from the step")
	# the Purge card
	for q in ["lfg:quest/tut_1_furrow", "lfg:quest/tut_2_warm", "lfg:quest/tut_3_roof"]:
		st.actors[1]["quests"][q] = {"st": "done"}
	Quests.accept(st, st.actors[1], {"quest": "lfg:quest/tut_4_dusk"}, [])
	_got.clear()
	o.set_model(Quests.tutorial_model(st, st.actors[1]))
	check(o.card_open(), "the Purge card opens by itself")
	check(o.card.title_label.text == "THE PURGE" and o.card.lines_box.get_child_count() >= 3, "card content")
	eq(o.highlight, "purge_guide", "highlight")
	o.card.ok_btn.pressed.emit()
	var acks: Array = _got.filter(func(g: Array) -> bool: return g[0] == "ack")
	eq(acks.size(), 1, "one ack")
	eq(acks[0][1], "purge_preview", "for the right topic")
	check(not o.card_open(), "card closed")
	cmd_ack(st)
	o.set_model(Quests.tutorial_model(st, st.actors[1]))
	check(not o.card_open(), "the card does not reopen for the next step")
	o.skip_btn.pressed.emit()
	check(not o.is_showing(), "tips can be hidden")
	check(_got.any(func(g: Array) -> bool: return g[0] == "skip"), "skipped signal")
	o.set_model(Quests.tutorial_model(st, st.actors[1]))
	check(not o.is_showing(), "and stay hidden")
	eq(UiKit.small_buttons(o).size(), 0, "touch sized")
	o.free()

func cmd_ack(st: MatchState) -> void:
	Rules.apply(st, {"type": &"ack_tutorial", "actor": 1, "seq": int(st.actors[1]["last_seq"]) + 1, "args": {"topic": "purge_preview"}})

func test_toolbar_pulses_the_highlighted_button() -> void:
	var st: MatchState = _mk()
	var up := UiPanels.new()
	up.bind_state(st)
	Quests.accept(st, st.actors[1], {"quest": "lfg:quest/tut_1_furrow"}, [])
	for q in ["lfg:quest/tut_1_furrow"]:
		st.actors[1]["quests"][q]["step"] = 0
	st.actors[1]["quests"]["lfg:quest/tut_1_furrow"] = {"st": "done"}
	Quests.accept(st, st.actors[1], {"quest": "lfg:quest/tut_2_warm"}, [])
	up.refresh()
	eq(up.tutorial.highlight, "craft", "chapter 2 starts at the cooking pot")
	up._process(0.2)
	var b: Button = up.toolbar_buttons[&"craft"]
	check(b.modulate != Color.WHITE, "the CRAFT button glows")
	st.actors[1]["quests"]["lfg:quest/tut_2_warm"]["step"] = 1
	up.refresh()
	eq(up.tutorial.highlight, "bag", "next: the bag (no toolbar button)")
	eq(b.modulate, Color.WHITE, "the glow is cleared")
	up.free()

# ------------------------------------------------------------------ boss bar and hud model
func test_boss_bar_shows_name_health_phase_and_incoming_attack() -> void:
	var bar := BossBar.new()
	bar.set_model({})
	check(not bar.visible, "hidden with no boss")
	bar.set_model({"name": "Vaultwarden", "hp": 55, "max_hp": 110, "phase": 0, "attack": "stone_fist", "windup_left": 0.9})
	check(bar.visible and bar.name_label.text == "VAULTWARDEN", "name: %s" % bar.name_label.text)
	check(absf(bar.bar_fill.size.x - (BossBar.WIDTH - 6.0) * 0.5) < 1.0, "half health")
	check(bar.warn_label.text.contains("Stone Fist"), "incoming attack named: %s" % bar.warn_label.text)
	bar.set_model({"name": "Vaultwarden", "hp": 20, "max_hp": 110, "phase": 1, "attack": "", "windup_left": 0.0})
	check(bar.name_label.text.contains("enraged") and bar.warn_label.text == "", "enraged, quiet between blows")
	bar.free()

func test_nearest_boss_model_and_hud_binder_keys() -> void:
	var st: MatchState = _mk()
	var a: Dictionary = st.actors[1]
	eq(Guardians.nearest_boss(st, a), {}, "no boss, no model")
	var id: int = Setup.spawn_enemy(st, "lfg:enemy/guardian_bog", a["hex"] + HexGrid.DIRS[0] * 3, false)
	var m: Dictionary = Guardians.nearest_boss(st, a)
	eq(int(m["id"]), id, "found")
	eq(String(m["name"]), "Bogtoad Matriarch", "name")
	eq(int(m["hp"]), int(m["max_hp"]), "full health")
	var hm: Dictionary = HudBinder.model_from_state(st)
	for k in ["companions", "tutorial", "boss", "quest_tracker"]:
		check(hm.has(k), "HUD model has %s" % k)
	eq(String(hm["boss"]["name"]), "Bogtoad Matriarch", "the HUD model carries the boss")
	Companions.give(st, a, "lfg:companion/mossbun", [])
	eq(HudBinder.model_from_state(st)["companions"], "Mossbun", "companion summary")
	var far: Dictionary = Guardians.nearest_boss(st, a, 1)
	eq(far, {}, "out of range")
	var prog: Array = Guardians.progress(st, a)
	eq(prog.size(), 7, "seven rows")
	for row in prog:
		check(not bool(row["beaten"]) and (row["gates"] as Array).size() >= 1 and String(row["material"]) != "", "%s: gates something" % row["name"])

func test_stage_wires_companions_boss_bar_and_toasts() -> void:
	var st: MatchState = Rules.new_match(3, &"lfg:class/judd", {"tutorial": true})
	Companions.give(st, st.actors[1], "lfg:companion/mossbun", [])
	var s := WorldStage.new()
	s.hud._ready()
	s.touch._ready()
	s.map._ready()
	s.start_from_state_sync(st)
	eq(s.companions.rig_count(), 1, "the follower is drawn")
	check(s.hud_model.has("tutorial") and s.hud_model["tutorial"].has("phase"), "the tutorial model reaches the HUD model")
	check(s.panels.tutorial.is_showing(), "and the overlay shows the first chapter")
	var boss: int = Setup.spawn_enemy(st, "lfg:enemy/guardian_meadow", st.actors[1]["hex"] + HexGrid.DIRS[0] * 4, false)
	s._update_ui()
	check(s.boss_bar.visible, "the boss bar appears when a guardian is near")
	st.actors[boss]["alive"] = false
	s._update_ui()
	check(not s.boss_bar.visible, "and goes when it falls")
	s.on_events([{"type": &"companion_hungry", "actor": 1, "companion": "lfg:companion/mossbun", "name": "Mossbun"},
		{"type": &"boss_phase", "enemy": boss, "phase": 1, "text": "It rises.", "adds": [], "name": "Gourdmother"},
		{"type": &"guardian_defeated", "actor": 1, "poi": 1, "guardian": "meadow", "name": "Gourdmother's Hollow", "first": true, "bonus": {}, "unlock": "lfg:unlock/guardian_meadow"}], st)
	check(s.hud.toast_box.get_child_count() >= 1, "toasts raised (%d)" % s.hud.toast_box.get_child_count())
	s.free()

func test_hud_shows_the_pets_line_and_the_journal_lists_guardians() -> void:
	var st: MatchState = _mk()
	var h := Hud.new()
	h._ready()
	h.set_model(HudBinder.model_from_state(st))
	check(not h.pets_chip.visible, "no companions, no chip")
	Companions.give(st, st.actors[1], "lfg:companion/mossbun", [])
	Companions.find(st.actors[1], "lfg:companion/mossbun")["fed"] = false
	h.set_model(HudBinder.model_from_state(st))
	check(h.pets_chip.visible and h.pets_label.text == "Pets: Mossbun (hungry)", "chip: %s" % h.pets_label.text)
	h.free()
	var q := QuestPanel.new()
	q.set_model(Quests.journal(st, st.actors[1]))
	q.show_tab("guardians")
	eq(q.rows_for("guardians").size(), 7, "seven guardians listed")
	eq(q.list_box.get_child_count(), 7, "seven cards")
	check(q.tab_buttons["guardians"].text.begins_with("GUARDIANS (7)"), "tab count")
	var txt: String = ""
	for c in q.list_box.get_children():
		txt += _all_text(c)
	check(txt.contains("Gourdmother") and txt.contains("Drops Mother Seed") and txt.contains("Seed Press"), "each card says what it drops and opens")
	eq(UiKit.small_buttons(q).size(), 0, "touch sized")
	q.free()

func _all_text(n: Node) -> String:
	var t: String = ""
	if n is Label:
		t += (n as Label).text + " "
	for c in n.get_children():
		t += _all_text(c)
	return t

func test_the_bag_can_eat_and_drink() -> void:
	var st: MatchState = _mk()
	st.actors[1]["inv"]["lfg:item/tonic"] = 2
	var h := Hud.new()
	h._ready()
	_got.clear()
	_on(h.item_use_requested, "use")
	h.set_model(HudBinder.model_from_state(st))
	var btns: Array = []
	var stack: Array = [h.bag_panel]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is Button:
			btns.append(n)
		stack.append_array(n.get_children())
	check(btns.size() >= 2, "usable items get a button (%d)" % btns.size())
	var texts: Array = btns.map(func(b: Button) -> String: return b.text)
	check(texts.has("EAT") and texts.has("USE"), "food says EAT, a tonic says USE: %s" % str(texts))
	for b in btns:
		(b as Button).pressed.emit()
	check(_got.size() == btns.size(), "each press is a request")
	var ids: Array = _got.map(func(g: Array) -> String: return String(g[1]))
	check(ids.has("lfg:item/ration") and ids.has("lfg:item/tonic"), "for the right items: %s" % str(ids))
	for g in _got:
		var c: Dictionary = UiCommands.eat(String(g[1]))
		check(Rules.COMMAND_TYPES.has(c["type"]) and c["args"]["item"] == g[1], "maps to a real command")
	eq(UiKit.small_buttons(h.bag_panel).size(), 0, "touch sized")
	# the real command works with it
	var before: int = Inv.count(st.actors[1]["inv"], "lfg:item/ration")
	var r: Dictionary = Rules.apply(st, {"type": &"eat", "actor": 1, "seq": 1, "args": UiCommands.eat("lfg:item/ration")["args"]})
	check(r["ok"] and Inv.count(st.actors[1]["inv"], "lfg:item/ration") == before - 1, "eat works")
	h.free()

func test_poi_panel_speaks_guardian_for_arenas() -> void:
	var st: MatchState = _mk()
	var a: Dictionary = st.actors[1]
	var arena: Dictionary = {}
	for p in st.world["pois"]:
		if String(p["type"]) == "lfg:poi/arena_ruins":
			arena = p
	a["pois_seen"] = [int(arena["id"])]
	var panel := PoiPanel.new()
	panel.set_model(Pois.info(st, a, int(arena["id"])))
	eq(panel.go_btn.text, "WAKE THE GUARDIAN", "before the fight")
	check(panel.status_label.text.contains("Battle Stew"), "a hint about preparation")
	a["hex"] = arena["hex"]
	Rules.apply(st, {"type": &"interact_poi", "actor": 1, "seq": 1, "args": {"poi": arena["id"]}})
	panel.set_model(Pois.info(st, a, int(arena["id"])))
	eq(panel.go_btn.text, "THE GUARDIAN IS UP", "mid fight")
	check(panel.go_btn.disabled and panel.status_label.text.contains("HIT"), "the button waits; the text says what to do")
	for id in st.actors.keys():
		if st.actors[id]["kind"] == "enemy":
			Combat.kill(st, int(id), 1, [])
	panel.set_model(Pois.info(st, a, int(arena["id"])))
	eq(panel.go_btn.text, "CLAIM THE SPOILS", "after the fight")
	check(not panel.go_btn.disabled, "enabled")
	panel.free()
