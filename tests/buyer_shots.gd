extends SceneTree
## A buyer's choices with long labels: the button column must stay on screen and clear of the speech box.
## Run windowed (try a small window); the shot goes to tools/shots/buyer_choices.png.
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func run() -> void:
	var g: Node3D = (load("res://main.tscn") as PackedScene).instantiate()
	g.seed_override = 5
	root.add_child(g)
	await wait(1.0)
	g.skip_tutorial()
	var choices := []
	for n in ["Music box", "Oil lantern", "Snow globe", "Stoneware jug"]:
		choices.append({"item": {"name": n}, "paid": 125})
	g.ui.say("Jo, from the lodge", "We're doing up the lodge for the season. Something with character?\nWhat have you got?")
	g.ui.show_present_choices(choices)
	await wait(1.5)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/buyer_choices.png")
	quit()
