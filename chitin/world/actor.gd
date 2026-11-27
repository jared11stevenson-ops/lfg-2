class_name Actor
extends CharacterBody3D
## Shared base for player, creatures and echoes: hp, damage, status effects.

signal died(actor: Actor)

var max_hp := 50.0
var hp := 50.0
var armor := 0.0
var move_speed := 4.0
var root_time := 0.0
var invuln := 0.0
var team := "wild"   # "player" | "wild" | "echo_kin"
var visual: Node3D
var _flash := 0.0

func take_damage(amount: float, source: Node = null) -> float:
	if invuln > 0.0 or hp <= 0.0:
		return 0.0
	var dealt := maxf(1.0, amount - armor * 0.8)
	hp -= dealt
	_flash = 0.12
	_on_hurt(dealt, source)
	if hp <= 0.0:
		hp = 0.0
		died.emit(self)
	return dealt

func _on_hurt(_dealt: float, _source: Node) -> void:
	pass

func heal(amount: float) -> void:
	hp = minf(max_hp, hp + amount)

func _tick_status(delta: float) -> void:
	root_time = maxf(0.0, root_time - delta)
	invuln = maxf(0.0, invuln - delta)
	if _flash > 0.0:
		_flash -= delta
		if visual:
			visual.scale = visual.scale.lerp(Vector3.ONE * 1.08, 0.5) if _flash > 0.0 else visual.scale

func flat_dist(other: Node3D) -> float:
	var d := other.global_position - global_position
	d.y = 0.0
	return d.length()

func radius_m() -> float:
	return 0.5

func radius_m_safe() -> float:
	return radius_m()
