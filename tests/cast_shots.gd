extends SceneTree
## Every Meshy customer at the counter, mid-gesture. Run windowed; shots go to tools/shots/cast_<id>.png.
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	await wait(5.0)
	g.state = "over"
	g.ui.visible = false
	var all := {}
	all.merge(People.FOLK)
	all.merge(People.BUYERS)
	all.merge(People.ROBBERS)
	for id: String in ["trapper", "collector", "widow", "kid", "drifter", "robber", "collector_b", "decorator"]:
		if g.figure != null and is_instance_valid(g.figure):
			g.figure.queue_free()
		g.figure = People.figure(all[id], id)
		g.figure.position = Shop.CUSTOMER_SPOT
		g.add_child(g.figure)
		g._shop_view(true)
		if not People.play(g.figure, "talk"):
			People.play(g.figure, "idle")
		await wait(1.3)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("res://tools/shots/cast_%s.png" % id)
	quit()
