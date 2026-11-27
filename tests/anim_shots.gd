extends SceneTree
## The Meshy customers animated: mid-walk, then gesturing at the counter. Run windowed (not headless); shots go to tools/shots/.
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/a_%s.png" % name)
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	await wait(7.0)
	for id in ["trapper", "collector"]:
		if g.figure != null:
			g.figure.queue_free()
		var info: Dictionary = People.FOLK[id]
		g.figure = People.figure(info, id)
		g.figure.position = Shop.CUSTOMER_SPOT + Vector3(-0.9, 0, -0.4)
		g.add_child(g.figure)
		g._shop_view(true)
		g.figure.rotation = Vector3(0, -2.2, 0)
		print(id, " walk ", People.play(g.figure, "walk"))
		await wait(0.6)
		await shot(id + "_walk")
		g.figure.position = Shop.CUSTOMER_SPOT
		g.figure.rotation = Vector3.ZERO
		print(id, " talk ", People.play(g.figure, "talk"))
		await wait(1.2)
		await shot(id + "_talk")
		await wait(6.0)
		await shot(id + "_after")
	quit()
