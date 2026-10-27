class_name WorldStage
extends Node3D
## Composite presentation scene: terrain view, player, camera, atmosphere, fog of war, farm/preview/telegraph layers,
## HUD, touch controls, strategic map, tilt-shift. The lead's main scene instantiates this and feeds it state.
## Everything gameplay-related goes out through signals / in through set_hud_model()/farm/telegraph APIs.
signal ready_to_play
signal interact_requested(kind: StringName, data: Dictionary)
signal action_requested
signal ability_requested(ability_id: String)
signal item_use_requested(item_id: String)      # the bag's EAT / USE button -> UiCommands.eat(item_id)
signal placement_checked(result: Dictionary) # {valid, reason, holding_id} while a building ghost is out

var world: WorldData
var fog: FogOfWar
var view: WorldView
var player: Player
var cam: FollowCamera
var atmosphere: Atmosphere
var farm: FarmLayer
var preview: BuildPreview
var telegraphs: Telegraphs
var hud: Hud
var touch: TouchControls
var map: StrategicMap
var tilt: TiltShift
var actors: ActorLayer
var roads: RoadLayer
var holding_layer: HoldingLayer
var pois: PoiLayer
var companions: CompanionLayer
var boss_bar: BossBar
var panels: UiPanels
var combat_hud: CombatHud
var state_ref: Object
var placing_id: String = ""
var shadows_on: bool = false
var _last_placement_key: String = ""
var _ui_timer: float = 0.0
var hud_model: Dictionary = {}
var grid_on: bool = false
var prompt_range: float = 14.0
var loading_label: Label
var _loading_layer: CanvasLayer
var _prompt_timer: float = 0.0
var started: bool = false

func _init() -> void:
	name = "WorldStage"
	atmosphere = Atmosphere.new()
	add_child(atmosphere)
	view = WorldView.new()
	add_child(view)
	roads = RoadLayer.new()
	add_child(roads)
	holding_layer = HoldingLayer.new()
	add_child(holding_layer)
	pois = PoiLayer.new()
	add_child(pois)
	farm = FarmLayer.new()
	add_child(farm)
	actors = ActorLayer.new()
	add_child(actors)
	companions = CompanionLayer.new()
	add_child(companions)
	preview = BuildPreview.new()
	add_child(preview)
	telegraphs = Telegraphs.new()
	add_child(telegraphs)
	player = Player.new()
	add_child(player)
	cam = FollowCamera.new()
	add_child(cam)
	tilt = TiltShift.new()
	add_child(tilt)
	hud = Hud.new()
	add_child(hud)
	combat_hud = CombatHud.new()
	add_child(combat_hud)
	var boss_layer := CanvasLayer.new()
	boss_layer.name = "BossLayer"
	boss_layer.layer = 5
	boss_bar = BossBar.new()
	boss_layer.add_child(boss_bar)
	add_child(boss_layer)
	touch = TouchControls.new()
	add_child(touch)
	panels = UiPanels.new()
	add_child(panels)
	map = StrategicMap.new()
	var map_layer := CanvasLayer.new()
	map_layer.layer = 6
	map_layer.name = "MapLayer"
	map_layer.add_child(map)
	add_child(map_layer)
	_loading_layer = CanvasLayer.new()
	_loading_layer.layer = 20
	loading_label = UiStyle.label("Growing the world...", 36)
	loading_label.position = Vector2(480, 320)
	_loading_layer.add_child(loading_label)
	add_child(_loading_layer)
	touch.interact_pressed.connect(_on_interact)
	touch.action_pressed.connect(func() -> void:
		player.play_attack()
		action_requested.emit())
	combat_hud.ability_pressed.connect(func(id: String) -> void: ability_requested.emit(id))
	hud.item_use_requested.connect(func(id: String) -> void: item_use_requested.emit(id))
	actors.player_hurt.connect(combat_hud.flash_hurt)
	panels.placement_started.connect(begin_placement)
	panels.placement_ended.connect(end_placement)
	panels.panel_changed.connect(func(kind: StringName) -> void:
		touch.suspended = kind != &"" and panels.any_open()
		player.input_enabled = not touch.suspended)
	touch.map_pressed.connect(toggle_map)
	touch.bag_pressed.connect(hud.toggle_bag)
	touch.grid_pressed.connect(toggle_grid)
	touch.camera_dragged.connect(func(d: Vector2) -> void: cam.rotate_yaw(-d.x * 0.008))
	touch.camera_zoomed.connect(cam.zoom_by)

## Generate (or accept) the world and build it over several frames. Await this or listen for ready_to_play.
func start(seed_value: int = 1, world_override: WorldData = null) -> void:
	_prepare(seed_value, world_override)
	await view.build_async(4)
	_finish()

## Same as start() but builds every chunk immediately (tests, capture tools). Blocks ~1-3 s.
func start_sync(seed_value: int = 1, world_override: WorldData = null) -> void:
	_prepare(seed_value, world_override)
	view.build_all()
	_finish()

func _prepare(seed_value: int, world_override: WorldData) -> void:
	world = world_override if world_override != null else StubWorldGen.generate(seed_value)
	fog = FogOfWar.new()
	view.setup(world, fog)
	farm.world = world
	farm.bind_fog(fog.texture)
	roads.bind_fog(fog.texture)
	roads.build(world)
	holding_layer.world = world
	holding_layer.bind_fog(fog.texture)
	pois.world = world
	pois.bind_fog(fog.texture)
	actors.world = world
	actors.fog = fog
	actors.player = player
	companions.world = world
	companions.player = player
	combat_hud.danger.camera = cam
	preview.world = world
	preview.extra_validator = func(h: Vector2i) -> bool: return not farm.hex_has_plot(h)
	telegraphs.world = world
	cam.world = world
	player.world = world
	map.setup(world, fog)
	var sp: Vector3 = Walk.find_spawn(world, world.start_hex)
	player.place_on_ground(Vector2(sp.x, sp.z))
	player.hex_changed.connect(func(h: Vector2i) -> void: fog.reveal(h))
	fog.reveal(world.start_hex)
	cam.target = player
	cam.snap()

func _finish() -> void:
	_loading_layer.visible = false
	started = true
	ready_to_play.emit()

## Start from authoritative Rules state: real world, player hex, fog, plots. Await or listen for ready_to_play.
func start_from_state(state: Object) -> void:
	await start(int(state.get("seed")), RulesWorldAdapter.from_state(state))
	_apply_state(state)

func start_from_state_sync(state: Object) -> void:
	start_sync(int(state.get("seed")), RulesWorldAdapter.from_state(state))
	_apply_state(state)

func _apply_state(state: Object) -> void:
	var acts: Variant = state.get("actors")
	var pid: int = int(state.get("player_id"))
	if acts is Dictionary and (acts as Dictionary).has(pid):
		var hx: Vector2i = HexMath.axial_to_offset((acts as Dictionary)[pid]["hex"])
		var sp: Vector3 = Walk.find_spawn(world, hx)
		player.place_on_ground(Vector2(sp.x, sp.z))
		fog.reveal(hx)
		cam.snap()
	state_ref = state
	var pa: Dictionary = (state.get("actors") as Dictionary).get(pid, {}) if state.get("actors") is Dictionary else {}
	if String(pa.get("class_id", "")) != "":
		player.apply_class(String(pa["class_id"]))
		combat_hud.abilities.set_class(String(pa["class_id"]))
	actors.player_id = pid
	actors.bind_state(state)
	companions.bind_state(state)
	holding_layer.sync_from_state(state)
	_sync_pois(state)
	panels.bind_state(state)
	farm.sync_from_state(state)
	set_hud_model(HudBinder.model_from_state(state))

func _sync_pois(state: Object) -> void:
	pois.sync_from_state(state)
	var pa: Dictionary = (state.get("actors") as Dictionary).get(int(state.get("player_id")), {}) if state.get("actors") is Dictionary else {}
	if not pa.is_empty():
		map.set_poi_markers(Pois.markers(state as MatchState, pa))

const POI_VERBS: Dictionary = {"farm": "Tend the old farm", "cave": "Peer into the cave", "shrine": "Visit the shrine", "vault": "Study the vault door", "wreck": "Search the wreck",
	"hut": "Knock at the hut", "spire": "Approach the spire", "arena_meadow": "Enter the Gourdmother's hollow", "arena_shore": "Step onto Brinecrown's reef",
	"arena_fungal_grove": "Enter the Elder ring", "arena_ruins": "Approach the Warden's gate", "arena_salt_flats": "Wade into the Heron's mirror",
	"arena_highlands": "Climb to the Thunder Crown", "arena_bog": "Wade into the Matriarch's mire"}
const TOAST_COLORS: Dictionary = {"good": UiStyle.GOOD, "warn": UiStyle.WARN, "bad": UiStyle.BAD, "info": UiStyle.TEXT}

## Quest and point-of-interest events become HUD toasts (only the player's own).
func _toast_for(e: Dictionary) -> void:
	var t: Dictionary = {}
	var ty: String = String(e.get("type", ""))
	if ty.begins_with("poi_"):
		t = Pois.toast_for(e)
	elif ty.begins_with("quest_"):
		t = Quests.toast_for(e)
	elif ty.begins_with("companion_"):
		t = Companions.toast_for(e)
	elif ty == "boss_phase" or ty == "guardian_defeated":
		t = Guardians.toast_for(e)
	if t.is_empty() or (e.has("actor") and int(e["actor"]) != actors.player_id):
		return
	var col: Color = TOAST_COLORS.get(String(t.get("kind", "info")), UiStyle.TEXT)
	hud.toast(String(t["title"]), col, 5.0)
	var body: String = String(t.get("body", "")).get_slice(".", 0).strip_edges()      # toasts do not wrap: the first sentence, short
	if body != "":
		hud.toast(body.substr(0, 56) + ("..." if body.length() > 56 else ""), Color(1, 1, 1, 0.85), 5.0)

## Call with Game.events_emitted payloads. Handles crop/phase events and enemy telegraphs.
func on_events(events: Array, state: Object = null) -> void:
	var farm_dirty := false
	var holdings_dirty := false
	var pois_dirty := false
	actors.on_events(events)
	companions.on_events(events)
	for e in events:
		match e.get("type", &""):
			&"enemy_telegraph": telegraphs.handle_event(e)
			&"crop_planted", &"crop_grown", &"crop_watered", &"crop_harvested", &"crop_withered": farm_dirty = true
			&"built", &"demolished", &"holding_captured": holdings_dirty = true
			&"poi_discovered", &"poi_claimed", &"poi_guarded", &"poi_progress":
				pois_dirty = true
				_toast_for(e)
			&"quest_accepted", &"quest_step", &"quest_ready", &"quest_done": _toast_for(e)
			&"companion_adopted", &"companion_hungry", &"companion_work", &"boss_phase": _toast_for(e)
			&"guardian_defeated":
				pois_dirty = true
				_toast_for(e)
			&"phase_changed":
				match e.get("to", &""):
					&"PURGE_ACTIVE": hud.toast("THE PURGE BEGINS", UiStyle.BAD, 4.0)
					&"WARNING": hud.toast("Warning: the Purge nears", UiStyle.WARN, 4.0)
	if state != null:
		state_ref = state
		if farm_dirty:
			farm.sync_from_state(state)
		if holdings_dirty:
			holding_layer.sync_from_state(state)
		if pois_dirty or (state.get("phase") == &"RESOLUTION"):
			_sync_pois(state)
		set_hud_model(HudBinder.model_from_state(state))
		combat_hud.abilities.update_from_state(state)
		if panels.visible or panels.any_open():
			panels.refresh()

func set_phase(phase: StringName, instant: bool = false) -> void:
	atmosphere.set_phase(phase, instant)
	hud_model["phase"] = phase
	hud.set_model(hud_model)
	telegraphs.purge_colors = phase == &"PURGE_ACTIVE"

func set_hud_model(m: Dictionary) -> void:
	hud_model.merge(m, true)
	if m.has("phase"):
		atmosphere.set_phase(m["phase"])
		telegraphs.purge_colors = m["phase"] == &"PURGE_ACTIVE"
	if m.has("time_of_day"):
		atmosphere.set_time_of_day(Atmosphere.visual_tod(m["time_of_day"]))
	hud.set_model(hud_model)

func toggle_map() -> void:
	map.toggle()
	player.input_enabled = not map.visible

func toggle_grid() -> void:
	grid_on = not grid_on
	view.set_grid_overlay(grid_on)

func _on_interact() -> void:
	var it: Dictionary = nearest_interactable()
	if not it.is_empty():
		if it["kind"] == &"poi" and state_ref != null:
			panels.open_poi(int(it["id"]))
		interact_requested.emit(it["kind"], it)

## Closest holding or farm plot within prompt_range -> {kind, label, dist, ...}.
func nearest_interactable() -> Dictionary:
	if world == null:
		return {}
	var pp := Vector2(player.position.x, player.position.z)
	# Farm plots win over the holding they sit in when the player is right next to one.
	var best_plot: Dictionary = {}
	var pd: float = 5.5
	for id in farm.plots:
		var p: Dictionary = farm.plots[id]
		var d2: float = pp.distance_to(p["pos"])
		if d2 < pd:
			pd = d2
			var st: int = p["stage"]
			var verb: String = "Plant seeds" if st == FarmLayer.Stage.TILLED else ("Water" if (st == FarmLayer.Stage.SEEDED or st == FarmLayer.Stage.SPROUT or st == FarmLayer.Stage.GROWING) else ("Harvest" if st == FarmLayer.Stage.RIPE else "Clear wilted crop"))
			best_plot = {"kind": &"plot", "label": verb, "id": id, "stage": st, "dist": d2}
	if not best_plot.is_empty():
		return best_plot
	var np: Dictionary = pois.nearest(player.position, 9.0)
	if not np.is_empty():
		var nm: String = String(POI_VERBS.get(String(np["prop"]), "Look closer"))
		return {"kind": &"poi", "label": nm, "id": int(np["id"]), "dist": float(np["dist"]), "available": bool(np["available"])}
	var best: Dictionary = {}
	var bd: float = prompt_range
	for h in world.holdings:
		var c: Vector2 = HexMath.offset_center(h["hex"].x, h["hex"].y)
		var d: float = pp.distance_to(c)
		if d < bd:
			bd = d
			best = {"kind": &"holding", "label": "Visit %s" % h["name"], "hex": h["hex"], "dist": d}
	return best

func _process(dt: float) -> void:
	if not started:
		return
	player.touch_move = touch.move if not map.visible else Vector2.ZERO
	map.set_player(player.position, player.rotation.y)
	_prompt_timer -= dt
	if _prompt_timer <= 0.0:
		_prompt_timer = 0.12
		var it: Dictionary = nearest_interactable()
		var txt: String = ""
		if not it.is_empty():
			txt = "[E]  " + String(it["label"])
		if txt != String(hud_model.get("prompt", "")):
			hud_model["prompt"] = txt
			hud.set_model(hud_model)
	view.set_purge_amount(atmosphere.purge_amount)
	view.set_night_amount(atmosphere.night_amount)
	tilt.set_purge(atmosphere.purge_amount)
	combat_hud.danger.purge = atmosphere.purge_amount > 0.5
	_ui_timer -= dt
	if _ui_timer <= 0.0:
		_ui_timer = 0.2
		_update_ui()
	if placing_id != "":
		_update_placement()

## Periodic UI sync (5 Hz): merchant proximity, ability cooldowns, danger arrows, touch blockers.
func _update_ui() -> void:
	var th: Array[Vector3] = actors.threat_positions(70.0)
	th.append_array(telegraphs.live_positions())
	combat_hud.danger.set_threats(th, player.position)
	if state_ref != null:
		combat_hud.abilities.update_from_state(state_ref)
		panels.set_merchant(PanelModels.merchant_near(state_ref))
		if state_ref is MatchState:
			var pa: Dictionary = (state_ref as MatchState).player()
			boss_bar.set_model(Guardians.nearest_boss(state_ref as MatchState, pa) if not pa.is_empty() else {})
	var rects: Array[Rect2] = [combat_hud.abilities.get_global_rect()]
	rects.append_array(panels.toolbar_rects())
	touch.blockers = rects

## Start the building ghost (BuildPreview.follow) for a building id; validity comes from PanelModels.check_placement.
func begin_placement(building_id: String) -> void:
	placing_id = building_id
	_last_placement_key = ""
	preview.set_model(building_id)
	preview.extra_validator = func(h: Vector2i) -> bool:
		return bool(_check_hex(h)["valid"])
	preview.follow(player)
	_update_placement()

func end_placement() -> void:
	placing_id = ""
	preview.hide_preview()
	preview.set_model("")
	preview.extra_validator = func(h: Vector2i) -> bool: return not farm.hex_has_plot(h)

func _check_hex(offset_hex: Vector2i) -> Dictionary:
	if state_ref == null or placing_id == "":
		return {"valid": false, "reason": "no_own_holding_nearby", "holding_id": -1}
	return PanelModels.check_placement(state_ref, placing_id, HexMath.offset_to_axial(offset_hex), world.can_build(offset_hex), farm.hex_has_plot(offset_hex))

func _update_placement() -> void:
	preview.follow(player)
	preview.revalidate()
	var r: Dictionary = _check_hex(preview.hex)
	var key: String = "%s|%s|%s" % [preview.hex, r["valid"], r["reason"]]
	if key != _last_placement_key:
		_last_placement_key = key
		panels.build.set_placement(r)
		placement_checked.emit(r)

## Options from the main menu: {shadows:bool, tilt_shift:bool}.
func apply_options(o: Dictionary) -> void:
	set_shadows(bool(o.get("shadows", false)))
	tilt.enabled = bool(o.get("tilt_shift", true))

## Shadows are opt-in (off by default): sun shadow map + terrain/prop/road/building casters + character rigs.
func set_shadows(on: bool) -> void:
	shadows_on = on
	atmosphere.shadows_enabled = on
	view.set_cast_shadows(on)
	for n in [roads, holding_layer, farm]:
		for ch in (n as Node).get_children():
			if ch is GeometryInstance3D:
				(ch as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if on else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	actors.set_cast_shadows(on)
