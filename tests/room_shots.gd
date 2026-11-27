extends SceneTree
## The room's lamps (wall lanterns on their plates, string lights under the beams), a customer walking the aisle in, and the appraisal
## notes folding away while zoomed in on a piece. Run windowed; shots go to tools/shots/room_*.png.
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
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/room_%s.png" % n)
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(g)
	await wait(0.5)
	g.skip_tutorial()
	await wait_state(g, "at_door", 30.0)
	await wait(0.5)
	g.buzz_in()
	await wait(2.6)
	await snap("walk_in_1")
	await wait(1.0)
	await snap("walk_in_2")
	await wait_state(g, "talk", 12.0)
	g._look(0.0, 0.35)
	await wait(1.2)
	await snap("ceiling")
	g._look(0.9, -0.2)
	await wait(1.2)
	await snap("left_wall")
	g._look(-1.8, 0.0)
	await wait(1.4)
	await snap("right_wall")
	g._aim_at(Vector3.ZERO)
	g.start_inspect()
	await wait(1.0)
	await snap("notes_open")
	g.zoom = 0.45
	await wait(1.2)
	await snap("notes_folded")
	g.decline()
	await wait(1.8)
	await snap("walk_out")
	quit()
