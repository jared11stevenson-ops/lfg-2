class_name CombatFx
extends Node3D
## Floating damage/heal numbers (pooled billboard Label3D, no per-hit allocation after warm-up).
const POOL := 18
const LIFE := 0.9
const RISE := 3.2
var _free: Array[Label3D] = []
var _live: Array[Dictionary] = []

func _init() -> void:
	name = "CombatFx"
	for i in POOL:
		var l := Label3D.new()
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.fixed_size = false
		l.pixel_size = 0.03
		l.font_size = 48
		l.outline_size = 14
		l.outline_modulate = Color("1d1030")
		l.modulate.a = 0.0
		l.visible = false
		l.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(l)
		_free.append(l)

func active_count() -> int:
	return _live.size()

static func color_for(amount: int, to_player: bool) -> Color:
	if amount < 0:
		return Color("19e0c8") # heal
	return Color("ff2f5f") if to_player else Color("fff6a0")

## amount > 0 damage, < 0 healing.
func spawn_number(pos: Vector3, amount: int, to_player: bool = false) -> void:
	var l: Label3D
	if _free.is_empty():
		var oldest: Dictionary = _live.pop_front()
		l = oldest["label"]
	else:
		l = _free.pop_back()
	l.text = str(absi(amount)) if amount >= 0 else "+%d" % absi(amount)
	l.modulate = color_for(amount, to_player)
	l.font_size = 48 + mini(absi(amount), 40)
	l.position = pos + Vector3(randf_range(-0.6, 0.6), 0, 0)
	l.visible = true
	_live.append({"label": l, "t": 0.0, "y0": l.position.y})

func _process(dt: float) -> void:
	for i in range(_live.size() - 1, -1, -1):
		var z: Dictionary = _live[i]
		z["t"] += dt
		var p: float = clampf(z["t"] / LIFE, 0.0, 1.0)
		var l: Label3D = z["label"]
		l.position.y = float(z["y0"]) + RISE * (1.0 - (1.0 - p) * (1.0 - p))
		l.modulate.a = 1.0 - smoothstep(0.55, 1.0, p)
		var sc: float = 1.0 + 0.5 * (1.0 - smoothstep(0.0, 0.18, p))
		l.scale = Vector3.ONE * sc
		if p >= 1.0:
			l.visible = false
			_free.append(l)
			_live.remove_at(i)
