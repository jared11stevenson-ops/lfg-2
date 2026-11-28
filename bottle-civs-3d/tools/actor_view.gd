extends Node3D
func _ready():
	var cam := Camera3D.new(); add_child(cam); cam.position = Vector3(0, 2.2, 9); cam.look_at(Vector3(0, 0.8, 0))
	var l := DirectionalLight3D.new(); add_child(l); l.rotation_degrees = Vector3(-45, 30, 0)
	var env := Environment.new(); env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; env.ambient_light_color = Color(0.6,0.6,0.7); env.background_mode = Environment.BG_COLOR; env.background_color = Color(0.2,0.2,0.25)
	var we := WorldEnvironment.new(); we.environment = env; add_child(we)
	for i in BCData.RACES.size():
		var a := BCActor.new(); add_child(a); a.setup(BCData.RACES[i])
		a.position = Vector3((i - 4.5) * 1.5, 0, 0)
		a.play("walk" if i % 2 == 0 else "work")
	await get_tree().create_timer(1.5).timeout
	get_viewport().get_texture().get_image().save_png("/tmp/actors.png")
	get_tree().quit()
