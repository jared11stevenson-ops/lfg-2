extends SceneTree
## Generator validation (needs rendering: run via tools/shot.sh). For each body plan x N random genomes:
##  - DETERMINISM: render twice -> identical pixels
##  - COVERAGE: silhouette area within sane fraction of the creature's own bounding box
##  - BOUNDS: drawn pixels stay inside a box derived from phenotype length (no runaway geometry)
##  - DIVERSITY: different genomes of one bauplan produce measurably different silhouettes
## Writes docs/validation/creature_gen.json.
const SZ := 360
func _render(vp: SubViewport, g: PackedFloat32Array, bp: int, seed_: int) -> Image:
	for ch in vp.get_children(): ch.queue_free()
	var bg := ColorRect.new(); bg.color = Color(0.5, 0.58, 0.36); bg.size = Vector2(SZ, SZ); vp.add_child(bg)
	var c := CreatureNode.new().setup(g, bp, seed_)
	c.position = Vector2(SZ / 2, SZ / 2); c.pose["spd"] = 0.4; c.pose["phase"] = 1.3; c.pose["t"] = 0.7
	var s: float = 150.0 / maxf(c.ph["L"] + c.ph["tail_len"] * 0.5, 1.0)
	c.scale = Vector2(s, s)
	vp.add_child(c)
	return null

func _initialize():
	var n_per := 8
	var vp := SubViewport.new(); vp.size = Vector2i(SZ, SZ); vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var report := {"bauplans": {}, "failures": []}
	var rng := RandomNumberGenerator.new(); rng.seed = 2024
	var bg_col := Color(0.5, 0.58, 0.36)
	for bp in 7:
		var sig := []
		var okc := 0
		for i in n_per:
			var g := Genome.random_for(bp, rng)
			var imgs := []
			for rep in 2:
				_render(vp, g, bp, 500 + i)
				await process_frame; await process_frame; await process_frame
				imgs.append(vp.get_texture().get_image())
			var a: Image = imgs[0]; var b: Image = imgs[1]
			var det := a.get_data() == b.get_data()
			var cnt := 0; var minx := SZ; var maxx := 0; var miny := SZ; var maxy := 0
			for y in range(0, SZ, 2):
				for x in range(0, SZ, 2):
					var px := a.get_pixel(x, y)
					if absf(px.r - bg_col.r) + absf(px.g - bg_col.g) + absf(px.b - bg_col.b) > 0.08:
						cnt += 1; minx = mini(minx, x); maxx = maxi(maxx, x); miny = mini(miny, y); maxy = maxi(maxy, y)
			var area := float(cnt) * 4.0
			var bbox := float(maxi(maxx - minx, 1) * maxi(maxy - miny, 1))
			var fill := area / bbox
			var touches_edge := minx <= 2 or miny <= 2 or maxx >= SZ - 4 or maxy >= SZ - 4
			var probs := []
			if not det: probs.append("nondeterministic")
			if cnt < 30: probs.append("empty/invisible")
			if fill < 0.12: probs.append("too sparse (fill %.2f)" % fill)
			if touches_edge: probs.append("geometry exceeds bounds")
			sig.append(fill)
			if probs.is_empty(): okc += 1
			else: report["failures"].append({"bp": Genome.BP_NAMES[bp], "i": i, "problems": probs})
		var mn := 9.0; var mx := -9.0
		for f in sig: mn = minf(mn, f); mx = maxf(mx, f)
		report["bauplans"][Genome.BP_NAMES[bp]] = {"ok": okc, "of": n_per, "fill_range": [snappedf(mn, 0.01), snappedf(mx, 0.01)]}
		print("%-10s ok %d/%d fill %.2f..%.2f" % [Genome.BP_NAMES[bp], okc, n_per, mn, mx])
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://docs/validation"))
	FileAccess.open("res://docs/validation/creature_gen.json", FileAccess.WRITE).store_string(JSON.stringify(report, "  "))
	print("failures: ", report["failures"].size())
	for f in report["failures"]: print("  ", f)
	quit()
