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

func _ready() -> void:
	stage = WorldStage.new()
	add_child(stage)
	stage.set_hud_model({"day": 1, "time_of_day": tod, "phase": &"PEACE", "rations": 14, "rations_per_day": 4, "class_label": "Judd - Farmer", "hp": 80.0, "hp_max": 100.0, "prompt": "",
		"inventory": [
			{"id": "lfg:crop/glowfruit", "name": "Glowfruit", "count": 12, "color": Color("ff2fb5")},
			{"id": "lfg:item/seed", "name": "Seeds", "count": 30, "color": Color("e6ff2e")},
			{"id": "lfg:item/hoe", "name": "Hoe", "count": 1, "color": Color("c9a070")},
			{"id": "lfg:item/spore", "name": "Spore", "count": 4, "color": Color("19e0c8")},
			{"id": "lfg:item/wood", "name": "Wood", "count": 22, "color": Color("a06a3a")},
		]})
	stage.interact_requested.connect(_on_interact)
	stage.action_requested.connect(func() -> void: stage.hud.toast("Swing!", UiStyle.BAD, 1.0))
	await stage.start(demo_seed)
	_seed_demo_plots()
	stage.hud.toast("Welcome to the Homestead", UiStyle.GOOD)

func _seed_demo_plots() -> void:
	var h: Vector2i = stage.world.start_hex
	var stages: Array[int] = [FarmLayer.Stage.TILLED, FarmLayer.Stage.SEEDED, FarmLayer.Stage.SPROUT, FarmLayer.Stage.GROWING]
	for i in 4:
		stage.farm.set_plot("a%d" % i, stage.farm.slot_position(h, i), stages[i], i == 1)
	var h2 := Vector2i(h.x + 1, h.y)
	var st2: Array[int] = [FarmLayer.Stage.RIPE, FarmLayer.Stage.WILTED, FarmLayer.Stage.RIPE, FarmLayer.Stage.GROWING]
	for i in 4:
		stage.farm.set_plot("b%d" % i, stage.farm.slot_position(h2, i), st2[i])

func _on_interact(kind: StringName, data: Dictionary) -> void:
	if kind == &"plot":
		var st: int = data["stage"]
		var p: Dictionary = stage.farm.plots[data["id"]]
		stage.farm.set_plot(data["id"], p["pos"], mini(st + 1, FarmLayer.Stage.RIPE) if st != FarmLayer.Stage.RIPE else FarmLayer.Stage.TILLED, st == FarmLayer.Stage.SEEDED)
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
