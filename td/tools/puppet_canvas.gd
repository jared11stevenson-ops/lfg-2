extends Node2D
# Helper node drawn into a SubViewport by tools/bake_puppets.gd.
const Pup = preload("res://art/puppet.gd")
var parts: Array = []
var state := "idle"
var t := 0.0

func _draw() -> void:
	Pup.draw(self, parts, state, t, Vector2(1, 0))
