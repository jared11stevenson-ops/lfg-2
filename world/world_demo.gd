extends Node
## Standalone playable demo / capture harness for the presentation layer (does not need Rules).
## Keys: 1-4 phase | F1 reveal map | F2 tilt-shift | F3 telegraph | F4 build preview | F5 advance crops | WASD move, Q/E rotate.
var stage: WorldStage
var day_seconds: float = 90.0
var clock: float = 0.0
var day: int = 1
var tod: float = 0.4
var auto_clock: bool = true
var demo_seed: int = 7
var state: MatchState

func _ready() -> void:
	stage = WorldStage.new()
	add_child(stage)
	state = Rules.new_match(demo_seed, &"lfg:class/judd")
	stage.interact_requested.connect(_on_interact)
	stage.action_requested.connect(func() -> void: stage.hud.toast("Swing!", UiStyle.BAD, 1.0))
	await stage.start_from_state(state)
	_seed_demo_plots()
	stage.hud.toast("Welcome to the Homestead", UiStyle.GOOD)

## Plant through the real Rules API next to the start holding, then fast-forward ages for variety.
func _seed_demo_plots() -> void:
	var start_ax: Vector2i = state.world["start"]
	var n: int = 0
	for h in HexGrid.ring_within(start_ax, 2):
		if h == start_ax or n >= 6:
			continue
		var res: Dictionary = Rules.apply(state, {"type": &"plant", "actor": 1, "seq": 100 + n, "args": {"crop": "lfg:crop/glowfruit", "hex": h}})
		if res.get("ok", false):
			var k: String = MatchState.plot_key(h)
			state.plots[k]["age"] = n % 3
			state.plots[k]["watered"] = n % 2 == 0
			n += 1
	stage.farm.sync_from_state(state)

func _on_interact(kind: StringName, data: Dictionary) -> void:
	if kind == &"plot":
		var st: int = data["stage"]
		var p: Dictionary = stage.farm.plots[data["id"]]
		stage.farm.set_plot(data["id"], p["pos"], (st + 1) % FarmLayer.Stage.size(), p["watered"])
	stage.hud.toast("%s" % data.get("label", ""), UiStyle.TEXT, 1.5)

func _unhandled_key_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k == null or not k.pressed or k.echo:
		return
	match k.physical_keycode:
		KEY_1: _set_phase(&"PEACE", 3)
		KEY_2: _set_phase(&"WARNING", 6)
		KEY_3: _set_phase(&"PURGE_ACTIVE", 7)
		KEY_4: _set_phase(&"RESOLUTION", 7)
		KEY_F1:
			stage.fog.set_reveal_all(not stage.fog.reveal_all)
		KEY_F2: stage.tilt.enabled = not stage.tilt.enabled
		KEY_F3: demo_telegraph()
		KEY_F4:
			if stage.preview.visible:
				stage.preview.hide_preview()
			else:
				stage.preview.follow(stage.player)
		KEY_F5:
			for id in stage.farm.plots:
				var p: Dictionary = stage.farm.plots[id]
				stage.farm.set_plot(id, p["pos"], (p["stage"] + 1) % FarmLayer.Stage.size(), p["watered"])

func demo_telegraph() -> void:
	var p: Vector3 = stage.player.position
	var fwd := Vector3(-sin(stage.player.rotation.y), 0, -cos(stage.player.rotation.y))
	stage.telegraphs.spawn(Telegraphs.Shape.CIRCLE, p + fwd * 10.0, 0.0, 6.0, 2.0)
	stage.telegraphs.spawn(Telegraphs.Shape.CONE, p + fwd * 4.0 + Vector3(-9, 0, 0), stage.player.rotation.y, 11.0, 2.5, {"half_angle": 0.6})
	stage.telegraphs.spawn(Telegraphs.Shape.LINE, p + fwd * 4.0 + Vector3(9, 0, 0), stage.player.rotation.y, 16.0, 3.0, {"width": 3.0})

func _set_phase(ph: StringName, d: int) -> void:
	day = d
	auto_clock = false
	stage.set_hud_model({"phase": ph, "day": d})

func _process(dt: float) -> void:
	if not stage.started or not auto_clock:
		return
	clock += dt
	tod = fposmod(0.4 + clock / day_seconds, 1.0)
	stage.set_hud_model({"time_of_day": tod})
