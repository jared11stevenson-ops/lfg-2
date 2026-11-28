class_name StructureLayer
extends Node2D
## Draws every civilization's structures (living and ruined) that are in view.
var world: GameWorld
var cam: Camera2D
var t := 0.0
func _process(dt: float) -> void:
	t += dt
	queue_redraw()
func _draw() -> void:
	if world == null or cam == null: return
	var vp := get_viewport_rect().size / cam.zoom
	var c := cam.get_screen_center_position()
	var rect := Rect2(c - vp * 0.5 - Vector2(120, 120), vp + Vector2(240, 240))
	for civ in world.sim.civs:
		var pal: Dictionary = Ink.palette(civ["g"][Genome.IDX["hue"]], civ["g"][Genome.IDX["sat"]], civ["g"][Genome.IDX["val"]], civ["g"][Genome.IDX["acc_hue"]], 0.5)
		var i := 0
		for s in civ["structures"]:
			i += 1
			var p := Vector2(s["tile"].x * GameWorld.TILE + 16.0, s["tile"].y * GameWorld.TILE + 16.0)
			if not rect.has_point(p): continue
			draw_set_transform(p, 0.0, Vector2.ONE)
			StructureArt.draw(self, s, pal, t, GameWorld.TILE, civ["id"] * 1000 + i)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
