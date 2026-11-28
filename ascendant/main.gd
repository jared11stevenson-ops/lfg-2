extends Node
## Flow: boot -> title (live simulated backdrop) -> new world (chunked history generation) -> play <-> pause -> title.
var stage: Node = null
var title: TitleScreen
var layer: CanvasLayer
var play: PlayScene
var gen_sim: EcoSim
var gen_target := 0
var gen_arch := ""
var paused := false
var pause_btns: Array = []
var pause_mode := false
var autosave_t := 0.0

func _ready() -> void:
	Settings.load_all(); Settings.apply()
	var args := OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("seed="):
			_direct_start(args); return
	_show_title()

func _direct_start(args: PackedStringArray) -> void:
	var seed_ := 1; var arch := "vole"
	for a in args:
		if a.begins_with("seed="): seed_ = int(a.substr(5))
		if a.begins_with("species="): arch = a.substr(8)
	_begin_play_fresh(seed_, arch, 120)

func _clear() -> void:
	if play: play.queue_free(); play = null
	if layer: layer.queue_free(); layer = null
	title = null

func _show_title() -> void:
	_clear()
	# backdrop world: real simulation, observer camera
	var s := EcoSim.new(); s.generate(7)
	for i in 70: s.step()
	play = PlayScene.new(); play.autoplay_input = false
	add_child(play)
	play.start_from_sim(s, "", true)
	layer = CanvasLayer.new(); layer.layer = 50; add_child(layer)
	title = TitleScreen.new()
	title.start_new.connect(_on_start_new); title.start_continue.connect(_on_continue); title.quit_game.connect(func(): get_tree().quit())
	layer.add_child(title)

func _on_start_new(seed_: int, arch: String, ticks: int) -> void:
	gen_sim = EcoSim.new(); gen_sim.generate(seed_)
	gen_target = ticks; gen_arch = arch
	title.mode = "generating"; title.btns.clear(); title.gen_progress = 0.0; title.gen_lines = ["Seed %d — the first animals stir." % seed_]
	for c in title.cards: c.visible = false

func _process(dt: float) -> void:
	if title and title.mode == "generating" and gen_sim:
		var seen: int = gen_sim.events.size()
		for i in 3:
			if gen_sim.tick < gen_target: gen_sim.step()
		for e in gen_sim.events.slice(seen):
			if e["type"] in ["dawn", "civ", "speciation", "extinction", "collapse", "war", "invention"]:
				title.gen_lines.append("Year %d: %s" % [gen_sim.tick / 4, e["text"]])
		title.gen_progress = float(gen_sim.tick) / gen_target
		if gen_sim.tick >= gen_target:
			var s := gen_sim; gen_sim = null
			_launch(s, gen_arch)
	if play and not title and not paused and is_instance_valid(play.player):
		autosave_t += dt
		if autosave_t > 90.0:
			autosave_t = 0.0; SaveGame.write("autosave", play)

func _begin_play_fresh(seed_: int, arch: String, ticks: int) -> void:
	_clear()
	var s := EcoSim.new(); s.generate(seed_)
	for i in ticks: s.step()
	_launch(s, arch)

func _launch(s: EcoSim, arch: String) -> void:
	_clear()
	play = PlayScene.new()
	add_child(play)
	play.start_from_sim(s, arch)
	play.chronicle.append("The world is %d years old. Your line begins." % (s.tick / 4))
	layer = CanvasLayer.new(); layer.layer = 60; add_child(layer)
	SaveGame.write("autosave", play)

func _on_continue(slot: String) -> void:
	var d := SaveGame.read(slot)
	if d.is_empty(): return
	_clear()
	play = PlayScene.new(); add_child(play)
	play.load_game(d)
	layer = CanvasLayer.new(); layer.layer = 60; add_child(layer)

func _unhandled_key_input(ev: InputEvent) -> void:
	if ev is InputEventKey and ev.pressed and ev.keycode == KEY_ESCAPE and play and not title:
		paused = not paused
		get_tree().paused = paused
		play.process_mode = Node.PROCESS_MODE_PAUSABLE
		if paused: _open_pause()
		else: _close_pause()

var pause_ui: Control
func _open_pause() -> void:
	pause_ui = PauseMenu.new(); pause_ui.process_mode = Node.PROCESS_MODE_ALWAYS
	pause_ui.action.connect(_pause_action)
	layer.add_child(pause_ui)
func _close_pause() -> void:
	if pause_ui: pause_ui.queue_free(); pause_ui = null
func _pause_action(id: String) -> void:
	match id:
		"resume": paused = false; get_tree().paused = false; _close_pause()
		"save": SaveGame.write("autosave", play); play.chronicle.append("World saved.")
		"title": paused = false; get_tree().paused = false; SaveGame.write("autosave", play); _show_title()
