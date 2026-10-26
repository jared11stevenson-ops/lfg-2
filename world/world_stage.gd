class_name WorldStage
extends Node3D
## Composite presentation scene: terrain view, player, camera, atmosphere, fog of war, farm/preview/telegraph layers,
## HUD, touch controls, strategic map, tilt-shift. The lead's main scene instantiates this and feeds it state.
## Everything gameplay-related goes out through signals / in through set_hud_model()/farm/telegraph APIs.
signal ready_to_play
signal interact_requested(kind: StringName, data: Dictionary)
signal action_requested

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
	farm = FarmLayer.new()
	add_child(farm)
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
	touch = TouchControls.new()
	add_child(touch)
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
	touch.action_pressed.connect(func() -> void: action_requested.emit())
	touch.map_pressed.connect(toggle_map)
	touch.bag_pressed.connect(hud.toggle_bag)
	touch.grid_pressed.connect(toggle_grid)
	touch.camera_dragged.connect(func(d: Vector2) -> void: cam.rotate_yaw(-d.x * 0.008))
	touch.camera_zoomed.connect(cam.zoom_by)

## Generate (or accept) the world and build it over several frames. Await this or listen for ready_to_play.
func start(seed_value: int = 1, world_override: WorldData = null) -> void:
	world = world_override if world_override != null else StubWorldGen.generate(seed_value)
	fog = FogOfWar.new()
	view.setup(world, fog)
	farm.world = world
	farm.bind_fog(fog.texture)
	preview.world = world
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
	await view.build_async(4)
	_loading_layer.visible = false
	started = true
	ready_to_play.emit()

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
		atmosphere.set_time_of_day(m["time_of_day"])
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
		interact_requested.emit(it["kind"], it)

## Closest holding or farm plot within prompt_range -> {kind, label, dist, ...}.
func nearest_interactable() -> Dictionary:
	if world == null:
		return {}
	var best: Dictionary = {}
	var bd: float = prompt_range
	for h in world.holdings:
		var c: Vector2 = HexMath.offset_center(h["hex"].x, h["hex"].y)
		var d: float = Vector2(player.position.x, player.position.z).distance_to(c)
		if d < bd:
			bd = d
			best = {"kind": &"holding", "label": "Visit %s" % h["name"], "hex": h["hex"], "dist": d}
	for id in farm.plots:
		var p: Dictionary = farm.plots[id]
		var d2: float = Vector2(player.position.x, player.position.z).distance_to(p["pos"])
		if d2 < minf(bd, 5.5):
			bd = d2
			var st: int = p["stage"]
			var verb: String = "Plant seeds" if st == FarmLayer.Stage.TILLED else ("Water" if (st == FarmLayer.Stage.SEEDED or st == FarmLayer.Stage.SPROUT or st == FarmLayer.Stage.GROWING) else ("Harvest" if st == FarmLayer.Stage.RIPE else "Clear wilted crop"))
			best = {"kind": &"plot", "label": verb, "id": id, "stage": st, "dist": d2}
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
	tilt.set_purge(atmosphere.purge_amount)
