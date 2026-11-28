extends SceneTree
## The U counter from both sides: the customer's (glass, brass, the pieces inside) and the shopkeeper's (open display compartments with
## the pieces in reach, cupboards and doors beneath, dividers, corners). Run windowed; shots go to tools/shots/counter_*.png.
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func snapcam(g: Node, eye: Vector3, at: Vector3, n: String, fov: float = 50.0) -> void:
	var c := Camera3D.new()
	g.add_child(c)
	c.fov = fov
	c.transform = Transform3D(Basis.looking_at(at - eye), eye)
	c.current = true
	await wait(0.3)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/counter_%s.png" % n)
	c.queue_free()
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	g.cinematics = false
	root.add_child(g)
	await wait(0.6)
	g.ui.visible = false
	g.queue = [{"type": "buyer", "id": "decorator"}]
	await wait(0.6)
	await snapcam(g, Vector3(0.0, 1.55, -2.6), Vector3(0, 0.6, -0.4), "customer")
	await snapcam(g, Vector3(-1.9, 1.3, -1.9), Vector3(0, 0.6, -0.3), "customer_corner")
	await snapcam(g, Vector3(0, 1.62, 0.35), Vector3(0, 0.55, -0.55), "player_down")
	await snapcam(g, Vector3(0.0, 1.0, 0.6), Vector3(0, 0.55, -0.55), "player_low", 62.0)
	await snapcam(g, Vector3(0.2, 1.1, 0.5), Vector3(-1.0, 0.5, -0.1), "player_left_arm", 62.0)
	await snapcam(g, Vector3(-0.2, 1.1, 0.5), Vector3(1.0, 0.5, -0.1), "player_right_arm", 62.0)
	quit()
