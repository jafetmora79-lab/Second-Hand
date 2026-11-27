extends SceneTree
## The glass counter from the customer's side and from behind it, to see the shop's collection in the case. Run windowed.
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	await wait(4.0)
	g.state = "over"
	g.ui.visible = false
	g.cam.transform = Transform3D(Basis.looking_at(Vector3(0, 0.75, -0.62) - Vector3(0.3, 1.2, -2.2)), Vector3(0.3, 1.2, -2.2))
	await wait(0.4)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/case_front.png")
	print("decor nodes: ", g.shop["decor"])
	quit()
