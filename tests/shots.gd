extends SceneTree
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
	await wait(7.0)
	await snap("shop")
	g.start_inspect()
	g.zoom = 0.5
	await wait(1.0)
	await snap("inspect")
	g.pivot.rotate_x(PI)
	g.zoom = 0.4
	await wait(1.0)
	g.item["found"].append(g.item["clues"][0]["id"])
	g.ui.refresh_inspect(g.item)
	await wait(0.3)
	await snap("inspect_under")
	g.start_haggle()
	await wait(0.6)
	await snap("haggle")
	quit()
