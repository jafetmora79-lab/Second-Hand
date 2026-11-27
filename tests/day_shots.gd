extends SceneTree
## The day's opening shot (dawn, the sign lighting up, moving in to the door) and closing shot (pulling back across the lane, the lights
## going down, the sign off, the fade to black, the summary). Run windowed; frames go to tools/shots/day_*.png.
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/day_%s.png" % n)
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	g.seed_override = 5
	root.add_child(g)
	for t: float in [0.9, 1.2, 1.4]:                     ## opening: 0.9, 2.1, 3.5 s in
		await wait(t)
		await snap("open_%d" % roundi(t * 10))
	await wait(2.0)
	await snap("open_done")
	# skip to closing time
	g.skip_tutorial()
	g.queue.clear()
	g._end_day()
	for k in 5:
		await wait(1.15)
		await snap("close_%d" % k)
	await wait(1.0)
	await snap("close_summary")
	quit()
