class_name AbilityBar
extends Control
## Class ability buttons with cooldown rings. The list is read from data/classes.json (`ability` + `peace_ability`) for the
## chosen class; cooldown/energy come from the actor in Rules state. Tapping (or keys 1/2) emits ability_pressed(id) -
## the lead submits UiCommands.ability(id). Unimplemented class abilities are drawn greyed with a WIP tag and never emit.
signal ability_pressed(ability_id: String)
const R := 36.0
const GAP := 12.0
const H := 118.0
var entries: Array[Dictionary] = []
var energy: float = 100.0
var class_id: String = ""
var _hover: int = -1

func _init() -> void:
	name = "AbilityBar"
	mouse_filter = Control.MOUSE_FILTER_STOP
	set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	anchor_top = 1.0
	anchor_bottom = 1.0
	offset_left = 272.0
	offset_right = 272.0 + 2.0 * (2.0 * R + GAP)
	offset_top = -138.0
	offset_bottom = -20.0
	custom_minimum_size = Vector2(2.0 * (2.0 * R + GAP), H)

## Ability list straight from Content (no hardcoded abilities).
static func abilities_for(cid: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var cd: Dictionary = Content.class_def(cid)
	if cd.is_empty():
		return out
	var impl: bool = bool(cd.get("implemented", false))
	for key in ["ability", "peace_ability"]:
		if cd.has(key):
			var a: Dictionary = cd[key]
			out.append({"id": String(a["id"]), "name": String(a.get("name", String(a["id"]).get_slice("/", 1).capitalize())), "energy": float(a.get("energy", 0)),
				"cooldown": float(a.get("cooldown", 0)), "duration": float(a.get("duration", 0)), "implemented": impl,
				"peace": key == "peace_ability", "remaining": 0.0})
	return out

func set_class(cid: String) -> void:
	class_id = cid
	entries = abilities_for(cid)
	queue_redraw()

func slot_center(i: int) -> Vector2:
	return Vector2(R + float(i) * (2.0 * R + GAP), H - R - 24.0)

func slot_at(local: Vector2) -> int:
	for i in entries.size():
		if local.distance_to(slot_center(i)) <= R + 8.0:
			return i
	return -1

## 0 = ready, 1 = just used.
func cooldown_fraction(i: int) -> float:
	var e: Dictionary = entries[i]
	return clampf(float(e["remaining"]) / maxf(float(e["cooldown"]), 0.001), 0.0, 1.0)

func is_usable(i: int) -> bool:
	var e: Dictionary = entries[i]
	return bool(e["implemented"]) and float(e["remaining"]) <= 0.0 and energy >= float(e["energy"])

func update_from_state(state: Object, actor_id: int = -1) -> void:
	var actors: Dictionary = state.get("actors")
	var id: int = int(state.get("player_id")) if actor_id < 0 else actor_id
	var a: Dictionary = actors.get(id, {})
	if a.is_empty():
		return
	if String(a.get("class_id", "")) != class_id:
		set_class(String(a.get("class_id", "")))
	energy = float(a.get("energy", 0.0))
	var now: float = float((state.get("clock") as Dictionary).get("elapsed", 0.0))
	for e in entries:
		e["remaining"] = maxf(float((a.get("cd", {}) as Dictionary).get("ab:" + String(e["id"]), 0.0)) - now, 0.0)
	queue_redraw()

func press_slot(i: int) -> bool:
	if i < 0 or i >= entries.size() or not is_usable(i):
		return false
	ability_pressed.emit(String(entries[i]["id"]))
	return true

func _gui_input(ev: InputEvent) -> void:
	var mb := ev as InputEventMouseButton
	if mb != null and mb.pressed and mb.button_index == MOUSE_BUTTON_LEFT:
		press_slot(slot_at(mb.position))
		accept_event()

func _unhandled_key_input(ev: InputEvent) -> void:
	var k := ev as InputEventKey
	if k != null and k.pressed and not k.echo:
		if k.physical_keycode == KEY_1:
			press_slot(0)
		elif k.physical_keycode == KEY_2:
			press_slot(1)

func _process(_dt: float) -> void:
	var any: bool = false
	for e in entries:
		if float(e["remaining"]) > 0.0:
			any = true
	if any:
		queue_redraw()

func _draw() -> void:
	var font: Font = ThemeDB.fallback_font
	for i in entries.size():
		var e: Dictionary = entries[i]
		var c: Vector2 = slot_center(i)
		var usable: bool = is_usable(i)
		var base: Color = Color("ff2fb5") if not bool(e["peace"]) else Color("19e0c8")
		if not bool(e["implemented"]):
			base = Color("77708a")
		draw_circle(c, R, Color(base.r * 0.3, base.g * 0.3, base.b * 0.3, 0.85))
		var frac: float = cooldown_fraction(i)
		if frac > 0.0:
			# dark pie sweeping away clockwise from 12 o'clock as the cooldown runs out
			var pts := PackedVector2Array([c])
			var steps: int = 28
			for s in steps + 1:
				var a: float = -PI * 0.5 + TAU * (1.0 - frac) + TAU * frac * float(s) / float(steps)
				pts.append(c + Vector2(cos(a), sin(a)) * (R - 2.0))
			draw_colored_polygon(pts, Color(0, 0, 0, 0.55))
		var ring: Color = base.lightened(0.25) if usable else Color(base.r, base.g, base.b, 0.45)
		draw_arc(c, R, -PI * 0.5, -PI * 0.5 + TAU * (1.0 - frac), 36, ring, 5.0, true)
		if frac > 0.0:
			draw_arc(c, R, -PI * 0.5 + TAU * (1.0 - frac), PI * 1.5, 36, Color(1, 1, 1, 0.25), 3.0, true)
		var letter: String = String(e["name"]).substr(0, 1).to_upper()
		var fs: int = 34
		var ts: Vector2 = font.get_string_size(letter, HORIZONTAL_ALIGNMENT_CENTER, -1, fs)
		draw_string_outline(font, c + Vector2(-ts.x * 0.5, ts.y * 0.28), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, 6, Color("1d1030"))
		draw_string(font, c + Vector2(-ts.x * 0.5, ts.y * 0.28), letter, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color("fff6e6"))
		if float(e["remaining"]) > 0.0:
			var t: String = "%d" % int(ceil(float(e["remaining"])))
			draw_string_outline(font, c + Vector2(-8, 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, 5, Color("1d1030"))
			draw_string(font, c + Vector2(-8, 8), t, HORIZONTAL_ALIGNMENT_LEFT, -1, 22, Color("ffe84a"))
		var cap: String = "WIP" if not bool(e["implemented"]) else "%s  %d" % [String(e["name"]).substr(0, 9), int(e["energy"])]
		var cs: Vector2 = font.get_string_size(cap, HORIZONTAL_ALIGNMENT_CENTER, -1, 14)
		draw_string_outline(font, Vector2(c.x - cs.x * 0.5, c.y + R + 16.0), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color("1d1030"))
		draw_string(font, Vector2(c.x - cs.x * 0.5, c.y + R + 16.0), cap, HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("fff6e6") if usable or frac > 0.0 else Color(1, 1, 1, 0.55))
