extends SceneTree
## The text fixes on screen: the visit tag above the portrait at the door, a "Found:" toast while inspecting (readable, clear of the
## tip and the notes card), and the ledger's antiques with a picture of each piece. Run windowed; shots go to tools/shots/notes_*.png.
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
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/notes_%s.png" % n)
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	g.cinematics = false
	root.add_child(g)
	await wait_state(g, "at_door", 30.0)
	await wait(2.0)
	await snap("door")
	g.buzz_in()
	await wait_state(g, "talk", 12.0)
	await wait(1.5)
	await snap("counter")
	g.start_inspect()
	await wait(0.8)
	var c: Dictionary = g.item["clues"][0]
	g.item["found"].append(c["id"])
	g.ui.found_clue(c)
	g.ui.refresh_inspect(g.item)
	await wait(0.6)
	await snap("toast")
	g.stop_inspect()
	g.accept_ask()
	await wait(1.0)
	g.ui.toggle_ledger()
	g.ui._ledger_tab = "antiques"
	g.ui._fill_ledger()
	await wait(0.6)
	await snap("ledger")
	quit()
