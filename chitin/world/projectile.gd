class_name Projectile
extends Area3D
## Acid globs and similar. Hits enemies of its owner's team.

var velocity := Vector3.ZERO
var damage := 10.0
var owner_team := "player"
var life := 1.6
var source: Node

func _ready() -> void:
	var cs := CollisionShape3D.new()
	var sh := SphereShape3D.new()
	sh.radius = 0.35
	cs.shape = sh
	add_child(cs)
	var mi := MeshInstance3D.new()
	var m := SphereMesh.new()
	m.radius = 0.22
	m.height = 0.44
	mi.mesh = m
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.6, 0.9, 0.1)
	mat.emission_enabled = true
	mat.emission = Color(0.6, 1.0, 0.1)
	mat.emission_energy_multiplier = 2.5
	mi.material_override = mat
	add_child(mi)
	collision_layer = 0
	collision_mask = 1 | 2
	body_entered.connect(_on_body)

func _physics_process(delta: float) -> void:
	global_position += velocity * delta
	life -= delta
	if life <= 0.0:
		queue_free()

func _on_body(b: Node) -> void:
	if b is Actor:
		var a: Actor = b
		var friendly := (owner_team == "player" or owner_team == "echo_kin") and (a.team == "player" or a.team == "echo_kin")
		if friendly or a.team == owner_team:
			return
		a.take_damage(damage, source)
		queue_free()
	elif b is StaticBody3D:
		queue_free()
