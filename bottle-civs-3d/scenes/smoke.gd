extends Node3D
func _ready():
	var cam = Camera3D.new(); add_child(cam); cam.position = Vector3(0,1,4)
	var l = DirectionalLight3D.new(); add_child(l); l.rotation_degrees = Vector3(-40,30,0)
	var m = MeshInstance3D.new(); m.mesh = SphereMesh.new(); add_child(m)
	var ps = load("res://assets/characters/kaykit/Knight.glb") as PackedScene
	var k = ps.instantiate(); add_child(k); k.position = Vector3(1.5,-1,0)
	await get_tree().create_timer(1.0).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/smoke.png")
	get_tree().quit()
