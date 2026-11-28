extends SceneTree
## The Meshy props from the user's images in place: lamp, ledger, clock, rug, bench, the monitor with the porch camera on its screen,
## and the lamp's pull chain mid-bounce. Run windowed; shots go to tools/shots/props_*.png.
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/props_%s.png" % n)
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	g.cinematics = false
	root.add_child(g)
	await wait(0.6)
	g.ui.visible = false
	g.queue.clear()
	await wait(1.0)
	await snap("room")
	g._look(0.0, -0.35)
	await wait(1.0)
	await snap("counter")
	g.pull_lamp()
	await wait(0.12)
	await snap("pulled")
	await wait(1.2)
	await snap("lamp_off")
	g.pull_lamp()
	g._aim_at(g.monitor_screen)
	g.screen_mat.set_shader_parameter("on", 1.0)
	g.feed.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	await wait(1.4)
	await snap("monitor")
	g._aim_at(Vector3(-1.25, 1.75, -3.8))
	await wait(1.4)
	await snap("clock")
	quit()
