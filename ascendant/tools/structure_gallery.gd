extends SceneTree
## CONSTRUCTED FIXTURE (not simulation output): every structure style, pristine and ruined, for art review.
class G extends Node2D:
	var styles := ["warren","hive_mound","lodge","web_hall","nest_cluster","woven_hut","root_cellar","fungus_garden","reed_paddy","dam","tunnel_net","spike_ring","forge_hollow","cairn_spire","silk_cocoon_store","trail"]
	func _draw():
		draw_rect(Rect2(0,0,1280,720), Color(0.5,0.58,0.36))
		for row in 2:
			for i in styles.size():
				var col := i % 8; var rw := i / 8
				var s := {"style": styles[i], "state": "alive" if row == 0 else "ruin", "hp": 1.0 if row == 0 else 0.3, "tile": Vector2i(0,0), "layer": "surface", "kind": "x"}
				var pal := Ink.palette(0.08 + i * 0.07, 0.5, 0.5, 0.2, 0.5)
				draw_set_transform(Vector2(90 + col * 150, 90 + rw * 170 + row * 340 * 0.0 + (0 if row == 0 else 0)), 0.0, Vector2.ONE)
				if row == 0: StructureArt.draw(self, s, pal, 0.0, 32.0, i * 31)
		for i in styles.size():
			var col := i % 8; var rw := i / 8
			var s := {"style": styles[i], "state": "ruin", "hp": 0.3, "tile": Vector2i(0,0), "layer": "surface", "kind": "x"}
			var pal := Ink.palette(0.08 + i * 0.07, 0.5, 0.5, 0.2, 0.5)
			draw_set_transform(Vector2(90 + col * 150, 430 + rw * 140), 0.0, Vector2.ONE)
			StructureArt.draw(self, s, pal, 0.0, 32.0, i * 31)
func _initialize():
	root.add_child(G.new())
	for i in 4: await process_frame
	root.get_viewport().get_texture().get_image().save_png("res://captures/structure_gallery_v1.png")
	quit()
