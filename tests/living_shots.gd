extends SceneTree
## The living objects: each piece with moving parts, open and then shut (E), and the pocket watch turned so its chain swings.
## Also renders the music box's side (where the flickering doubled faces were) and the compass lid's back (where the hole was).
## Run windowed; shots go to tools/shots/live_*.png.
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/live_%s.png" % n)
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	g.cinematics = false
	root.add_child(g)
	await wait(2.0)
	g.skip_tutorial()
	g.ui.visible = false
	for kind in ["music_box", "pocket_watch", "compass"]:
		var k: Dictionary = Items.KINDS[kind]
		var clues: Array = []
		for c: Dictionary in k["clues"]:
			clues.append(c.duplicate())
		g.item = {"kind": kind, "name": k["name"], "cat": k["cat"], "clues": clues, "fake": false, "value": k["base"], "found": [], "base": k["base"]}
		g._place_item()
		g.pivot.basis = Basis.IDENTITY
		g.rest_q = Quaternion.IDENTITY
		g.want_q = Quaternion.IDENTITY
		g.start_inspect()
		g.zoom = 0.6
		await wait(1.2)
		await snap("%s_open" % kind)
		var lv: Living = g._living()
		print(kind, " living: ", lv != null, " parts: ", lv.parts.size() if lv else 0)
		if lv:
			lv.toggle()
		await wait(1.0)
		await snap("%s_shut" % kind)
		if kind == "pocket_watch":
			lv.toggle()                                   ## open again, then turn it: the chain should swing
			g.want_q = Quaternion(Vector3.UP, 1.3)
			await wait(0.35)
			await snap("pocket_watch_swing1")
			await wait(0.35)
			await snap("pocket_watch_swing2")
		if kind == "music_box":
			g.want_q = Quaternion(Vector3.UP, -1.2)       ## its side, where the faces used to flicker
			await wait(1.0)
			await snap("music_box_side")
		if kind == "compass":
			lv.toggle()
			g.want_q = Quaternion(Vector3.UP, PI)         ## the lid's back, where the hole was
			await wait(1.2)
			await snap("compass_lid_back")
	quit()
