class_name PauseMenu
extends Control
signal action(id: String)
var btns: Array = []
func _ready() -> void:
	UiKit.fit(self)
	for i in 3:
		var b := UiKit.Btn.new(); b.id = ["resume", "save", "title"][i]; b.label = ["Resume", "Save world", "Save & return to title"][i]
		b.rect = Rect2(size.x * 0.5 - 170, 260 + i * 66, 340, 52); btns.append(b)
func _process(_d: float) -> void: queue_redraw()
func _input(ev: InputEvent) -> void:
	if ev is InputEventMouseMotion:
		for b in btns: b.hover = b.rect.has_point(ev.position)
	elif ev is InputEventMouseButton and ev.pressed and ev.button_index == MOUSE_BUTTON_LEFT:
		for b in btns:
			if b.rect.has_point(ev.position): action.emit(b.id)
func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), Color(0.05, 0.04, 0.12, 0.6))
	UiKit.title_text(self, "Paused", Vector2(size.x * 0.5 - 90, 220), 56)
	for b in btns: UiKit.draw_btn(self, b, 0.0)
