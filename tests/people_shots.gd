extends SceneTree
## Each Meshy customer at the counter, seen from behind it.
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	await wait(7.0)
	for id in ["trapper", "collector"]:
		if g.figure != null:
			g.figure.queue_free()
		var info: Dictionary = People.FOLK[id]
		g.figure = People.figure(info, id)
		g.figure.position = Shop.CUSTOMER_SPOT
		g.add_child(g.figure)
		g._shop_view(true)
		await wait(0.8)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("res://tools/shots/p_%s.png" % id)
	quit()
