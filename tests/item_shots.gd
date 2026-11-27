extends SceneTree
## Each Meshy object on the mat under the lamp, from the front and turned over, with all of its genuine clues drawn.
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/%s.png" % n)
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	await wait(7.0)
	for kind in ["music_box", "pocket_watch", "carved_bear", "compass", "lantern"]:
		var k: Dictionary = Items.KINDS[kind]
		var clues: Array = []
		for c: Dictionary in k["clues"]:
			clues.append(c.duplicate())
		g.item = {"kind": kind, "name": k["name"], "cat": k["cat"], "clues": clues, "fake": false, "value": k["base"], "found": [], "base": k["base"]}
		g._place_item()
		g.pivot.basis = Basis.IDENTITY
		g.start_inspect()
		g.zoom = 0.55
		await wait(1.0)
		await snap("it_%s_front" % kind)
		g.pivot.basis = Basis(Vector3.RIGHT, PI * 0.62)
		g.zoom = 0.45
		await wait(0.8)
		await snap("it_%s_under" % kind)
	quit()
