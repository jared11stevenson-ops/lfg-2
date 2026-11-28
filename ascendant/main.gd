extends Node
## Entry point. (Title screen/world creation: ui/title.gd, wired in later; --play= for direct launch.)
func _ready() -> void:
	var seed_ := 1; var arch := "vole"
	for a in OS.get_cmdline_user_args():
		if a.begins_with("seed="): seed_ = int(a.substr(5))
		if a.begins_with("species="): arch = a.substr(8)
	var ps := PlayScene.new()
	add_child(ps)
	ps.start_new(seed_, arch)
