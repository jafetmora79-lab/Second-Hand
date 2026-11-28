extends SceneTree
## Phase 3 on screen: asking at the door, the seller's choices with "Say something...", the three lines, and the ledger's pages.
## Run windowed; shots go to tools/shots/story_*.png.
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
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/story_%s.png" % n)
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	g.cinematics = false
	root.add_child(g)
	await wait_state(g, "at_door", 30.0)
	g.skip_tutorial()
	await wait(1.0)
	await snap("door")
	g.ask_door()
	await wait(2.5)
	await snap("door_asked")
	g.buzz_in()
	await wait_state(g, "talk", 12.0)
	await wait(2.0)
	await snap("seller")
	g.ui.show_talk_choices()
	await wait(0.6)
	await snap("talk_choices")
	g.talk("friendly")
	await wait(2.0)
	await snap("talked")
	g.ui.toggle_ledger()
	await wait(0.5)
	await snap("ledger_customers")
	g.ui._ledger_tab = "accounts"
	g.ui._fill_ledger()
	await wait(0.5)
	await snap("ledger_accounts")
	quit()
