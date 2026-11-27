extends SceneTree
## The view out of the shop window: from just outside the glass, and from behind the counter. Run windowed; shots go to tools/shots/.
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
	await wait(6.0)
	g.state = "over"
	g.ui.visible = false
	g.cam.transform = Transform3D(Basis.looking_at(Vector3(0.33, 0.02, -1)), Vector3(1.4, 1.6, -4.3))
	await wait(0.5)
	await snap("out_open")
	g.cam.transform = Transform3D(Basis.looking_at(Vector3(1.4, 1.55, -4.0) - Vector3(0, 1.62, 0.35)), Vector3(0, 1.62, 0.35))
	g.cam.fov = 25.0
	await wait(0.5)
	await snap("out_window")
	quit()
