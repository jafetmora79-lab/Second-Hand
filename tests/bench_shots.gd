extends SceneTree
## The restoration bench on screen: looking at it with grimy pieces on the shelves, a piece half scrubbed, and clean.
## Run windowed; shots go to tools/shots/bench_*.png.
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/bench_%s.png" % n)
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	g.cinematics = false
	g.seed_override = 21
	root.add_child(g)
	await wait(0.5)
	g.skip_tutorial()
	g.queue = [{"type": "buyer", "id": "decorator"}]       ## someone on the way, so the day doesn't end while we look
	for kind in ["compass", "camera", "music_box"]:
		g.visitor = {"type": "seller", "id": "widow", "info": People.FOLK["widow"]}
		g.item = Items.make(kind, g.rng, 0.0)
		g._place_item()
		g._buy(50)
		await wait(0.3)
	g.state = "idle"
	g.figure = null
	await wait(1.0)
	g._aim_at(g.BENCH_SPOT)
	await wait(1.5)
	await snap("look")
	print("bench state ", g.state, " shown ", g._bench_shown, " actions ", g.ui._actions.get_child_count(), " restoring ", g.restoring)
	g.start_restore(g.stock[0])
	await wait(1.2)
	await snap("dirty")
	var at: Vector2 = g.cam.unproject_position((g.restore_st["node"] as Node3D).global_position)
	for i in 4:
		g._scrub(Vector2(120 if i % 2 == 0 else -120, 10), at)
	await wait(0.4)
	await snap("half")
	for i in 30:
		if g.restoring:
			g._scrub(Vector2(120 if i % 2 == 0 else -120, 10), at)
	await wait(1.0)
	await snap("clean")
	quit()
