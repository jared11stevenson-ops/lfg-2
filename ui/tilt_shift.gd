class_name TiltShift
extends CanvasLayer
## Screen-space tilt-shift (Compatibility has no DOF). One full-screen quad, 9 taps. enabled=false removes the cost.
var rect: ColorRect
var mat: ShaderMaterial
var enabled: bool = true:
	set(v):
		enabled = v
		if rect != null:
			rect.visible = v

func _init() -> void:
	name = "TiltShift"
	layer = 1
	rect = ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mat = ShaderMaterial.new()
	mat.shader = load("res://ui/shaders/tilt_shift.gdshader")
	rect.material = mat
	add_child(rect)

func set_purge(amount: float) -> void:
	mat.set_shader_parameter("tint", Color(1.0, 1.0 - 0.35 * amount, 1.0 - 0.15 * amount))
	mat.set_shader_parameter("vignette", 0.35 + 0.3 * amount)
