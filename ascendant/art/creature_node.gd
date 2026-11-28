class_name CreatureNode
extends Node2D
var ph: Dictionary = {}
var pose: Dictionary = {"rot": 0.0, "t": 0.0, "phase": 0.0, "spd": 0.0}
func setup(genome: PackedFloat32Array, bp: int, seed_: int = 1) -> CreatureNode:
	ph = Phenotype.build(genome, bp)
	ph["seed"] = seed_
	queue_redraw()
	return self
func _draw() -> void:
	if ph.is_empty(): return
	pose["rot"] = global_rotation
	CreatureArt.draw(self, ph, pose)
