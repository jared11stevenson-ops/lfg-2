extends Node
## Playable entry: Rules (pure) + WorldStage (presentation) wired through the Game autoload.
## Controls: WASD/stick move, USE (E / button) plants/waters/harvests the nearest plot, HIT (F) attacks, N = new match.
const CLASS_ID := &"lfg:class/judd"
var stage: WorldStage
var seq: int = 1000
var seed_value: int = 1
var _sync_t: float = 0.0
var _over: bool = false

func _ready() -> void:
	var args: PackedStringArray = OS.get_cmdline_user_args()
	for a in args:
		if a.begins_with("--seed="):
			seed_value = int(a.get_slice("=", 1))
	_new_match()
	if "--journey" in OS.get_cmdline_user_args():
		var j: Node = load("res://main/journey.gd").new()
		add_child(j)
		j.run(self)

func _new_match() -> void:
	if stage != null:
		stage.queue_free()
	_over = false
	Game.state = Rules.new_match(seed_value, CLASS_ID)
	stage = WorldStage.new()
	add_child(stage)
	if not Game.events_emitted.is_connected(_on_events):
		Game.events_emitted.connect(_on_events)
	stage.interact_requested.connect(_on_interact)
	stage.action_requested.connect(_on_hit)
	await stage.start_from_state(Game.state)
	stage.player.hex_changed.connect(_on_hex)
	stage.hud.toast("Match started (seed %d). Feed your people. Survive the Purge." % seed_value, UiStyle.GOOD, 5.0)

func _cmd(type: StringName, args: Dictionary) -> Dictionary:
	seq += 1
	return Game.submit({"type": type, "actor": Game.state.player_id, "seq": seq, "args": args})

func _on_hex(offset_hex: Vector2i) -> void:
	_cmd(&"move_intent", {"to": HexMath.offset_to_axial(offset_hex)})

func _on_interact(kind: StringName, data: Dictionary) -> void:
	if kind == &"plot":
		var hx: Vector2i = _parse(String(data["id"]))
		var res: Dictionary
		match int(data["stage"]):
			FarmLayer.Stage.RIPE: res = _cmd(&"harvest", {"hex": hx})
			FarmLayer.Stage.WILTED: res = _cmd(&"harvest", {"hex": hx})
			_: res = _cmd(&"water", {"hex": hx})
		_report(res, String(data["label"]))
	else:
		var here: Vector2i = HexMath.offset_to_axial(stage.player.current_hex)
		var res2: Dictionary = _cmd(&"plant", {"crop": "lfg:crop/glowfruit", "hex": here})
		_report(res2, "Planted glowfruit")

func _on_hit() -> void:
	var me: Dictionary = Game.state.actors[Game.state.player_id]
	var best: int = -1
	var bd: int = 99
	for id in Game.state.actors:
		var t: Dictionary = Game.state.actors[id]
		if int(id) == Game.state.player_id or not t["alive"]:
			continue
		var d: int = HexGrid.distance(me["hex"], t["hex"])
		if d < bd:
			bd = d
			best = int(id)
	if best < 0:
		stage.hud.toast("Nothing to hit", UiStyle.TEXT, 1.0)
		return
	_report(_cmd(&"attack", {"target": best}), "Hit!")

func _report(res: Dictionary, ok_text: String) -> void:
	if res.get("ok", false):
		stage.hud.toast(ok_text, UiStyle.GOOD, 1.2)
	else:
		stage.hud.toast("Can't: %s" % String(res.get("error", "?")).replace("_", " "), UiStyle.WARN, 1.5)

func _parse(k: String) -> Vector2i:
	var p: PackedStringArray = k.split(",")
	return Vector2i(int(p[0]), int(p[1]))

func _on_events(events: Array) -> void:
	if stage == null:
		return
	stage.on_events(events, Game.state)
	for e in events:
		if e.get("type", &"") == &"match_over" and not _over:
			_over = true
			stage.hud.toast("MATCH OVER: %s. Press N for a new world." % String(e.get("reason", "")).replace("_", " "), UiStyle.BAD, 30.0)
		elif e.get("type", &"") == &"victory":
			stage.hud.toast("VICTORY: %s - the frontier continues." % String(e.get("kind", "")), UiStyle.GOOD, 8.0)

func _unhandled_key_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k != null and k.pressed and not k.echo:
		if k.physical_keycode == KEY_N:
			seed_value += 1
			_new_match()
		elif k.physical_keycode == KEY_E and false:
			pass
