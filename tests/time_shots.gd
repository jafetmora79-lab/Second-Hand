extends SceneTree
## The shop at morning, midday, sunset and night (as seen from behind the counter), and an animal going past. Run windowed.
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
	await wait(7.0)                       ## let the day's own time-of-day tweens finish first
	g.state = "over"
	g.ui.visible = false
	g.queue.clear()
	if g.figure != null and is_instance_valid(g.figure):
		g.figure.visible = false
	for t in [0.0, 1.0 / 3.0, 2.0 / 3.0, 1.0]:
		Outside.set_time(t)
		await wait(0.4)
		await snap("t_%d" % roundi(t * 3.0))
	Outside.set_time(0.3)
	var rng := RandomNumberGenerator.new()
	for i in 4:
		rng.seed = i * 7 + 1
		Outside.spawn_animal(g, rng)
	await wait(2.5)
	g.cam.fov = 28.0
	g.cam.transform = Transform3D(Basis.looking_at(Vector3(1.4, 1.55, -4.0) - Vector3(0, 1.62, 0.35)), Vector3(0, 1.62, 0.35))
	await wait(0.2)
	await snap("t_animals")
	g.cam.fov = 60.0
	g.cam.transform = Transform3D(Basis.looking_at(Vector3(0, 2.6, -2.0) - Vector3(0, 1.4, 0.6)), Vector3(0, 1.4, 0.6))
	await wait(0.3)
	await snap("t_ceiling")
	quit()
