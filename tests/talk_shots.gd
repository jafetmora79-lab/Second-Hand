extends SceneTree
## The conversation look: the speech box rising with its letters typing in, the camera settled on the speaker's face, and a look around
## the shop. Run windowed; shots go to tools/shots/talk_*.png.
func _initialize() -> void:
	call_deferred("run")
func wait_state(g: Node, want: String, t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end and g.state != want:
		await process_frame
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/talk_%s.png" % n)
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	g.cinematics = false
	root.add_child(g)
	await wait_state(g, "at_door", 30.0)
	await wait(0.5)
	await wait(1.0)
	await snap("door")
	g._aim_at(Vector3.ZERO)
	await wait(1.2)
	await snap("door_unzoomed")
	g._aim_at(g.monitor_screen)
	await wait(1.2)
	g.buzz_in()
	await wait_state(g, "talk", 12.0)
	await wait(0.25)
	await snap("rising")
	await wait(2.5)
	await snap("framed")
	g._look(1.0, 0.15)
	await wait(1.0)
	await snap("looked_around")
	g.start_inspect()
	for c: Dictionary in g.item["clues"]:
		g.item["found"].append(c["id"])
	g.ui.refresh_inspect(g.item)
	await wait(1.0)
	await snap("inspect")
	g.want_q = Quaternion(Vector3.RIGHT, 0.8) * g.want_q
	g.zoom = 0.3
	await wait(1.5)
	await snap("inspect_comb")
	g.start_haggle()
	await wait(0.6)
	await snap("haggle")
	quit()
