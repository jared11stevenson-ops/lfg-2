class_name CombatHud
extends CanvasLayer
## Combat-feel overlay: red hurt flash, screen-edge danger arrows, class ability bar with cooldown rings.
## The stage feeds it; ability presses come out as `ability_pressed(id)`.
signal ability_pressed(ability_id: String)
var abilities: AbilityBar
var danger: DangerIndicator
var hurt_rect: ColorRect
var _hurt: float = 0.0
var root: Control

func _init() -> void:
	name = "CombatHud"
	layer = 7
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	hurt_rect = ColorRect.new()
	hurt_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hurt_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sm := ShaderMaterial.new()
	var sh := Shader.new()
	sh.code = "shader_type canvas_item;\nuniform float amount = 0.0;\nvoid fragment(){ vec2 q = UV-0.5; float v = smoothstep(0.12, 0.7, length(q*vec2(1.0,1.2))); COLOR = vec4(0.95,0.05,0.12, v*amount*0.8); }"
	sm.shader = sh
	hurt_rect.material = sm
	root.add_child(hurt_rect)
	danger = DangerIndicator.new()
	root.add_child(danger)
	abilities = AbilityBar.new()
	abilities.ability_pressed.connect(func(id: String) -> void: ability_pressed.emit(id))
	root.add_child(abilities)

func flash_hurt(amount: int = 5) -> void:
	_hurt = clampf(0.45 + float(amount) * 0.03, 0.45, 1.0)

func hurt_amount() -> float:
	return _hurt

func _process(dt: float) -> void:
	_hurt = maxf(_hurt - dt * 1.8, 0.0)
	(hurt_rect.material as ShaderMaterial).set_shader_parameter("amount", _hurt)
