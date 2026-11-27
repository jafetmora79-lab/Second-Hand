extends SceneTree
## The door: a caller on the porch camera, coming in through the door, at the counter; and a wide look round the furnished shop.
## Run windowed (not headless); shots go to tools/shots/.
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func wait_state(g: Node, want: String, t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end and g.state != want:
		await process_frame
func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/%s.png" % n)
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	await wait_state(g, "at_door", 15.0)
	await wait(0.6)
	await snap("d_door")
	var keep: Transform3D = g.cam.transform
	g.cam.transform = Transform3D(Basis.looking_at(Vector3(-1.08, 1.1, -0.74) - Vector3(-0.6, 1.4, 0.0)), Vector3(-0.6, 1.4, 0.0))
	await wait(0.3)
	await snap("d_monitor")
	g.cam.transform = keep
	g.buzz_in()
	await wait(1.1)
	await snap("d_entering")
	await wait_state(g, "talk", 8.0)
	await wait(0.5)
	await snap("d_counter")
	g.state = "over"
	g.ui.visible = false
	g.cam.fov = 75.0
	g.cam.transform = Transform3D(Basis.looking_at(Vector3(0, 1.0, -3.0) - Vector3(0, 1.9, 0.8)), Vector3(0, 1.9, 0.8))
	await wait(0.4)
	await snap("d_wide")
	g.cam.transform = Transform3D(Basis.looking_at(Vector3(-2.2, 1.0, -4.0) - Vector3(0.5, 1.7, -7.5)), Vector3(0.5, 1.7, -7.5))
	await wait(0.4)
	await snap("d_porch")
	quit()
