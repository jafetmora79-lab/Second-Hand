extends SceneTree
## A piece with all its genuine clues drawn (and, with "copies", each copy's tell), from the front, the back and underneath, close up.
## Run windowed:  godot --resolution 480x480 -s tests/clue_shots.gd -- <kind> [<kind> ...]
## Shots go to tools/shots/clue_<kind>_<view>.png.
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func run() -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.33, 0.36)
	env.environment.ambient_light_color = Color(0.75, 0.75, 0.75)
	env.environment.ambient_light_energy = 0.7
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	root.add_child(sun)
	var under := DirectionalLight3D.new()
	under.rotation = Vector3(1.0, 0.3, 0)
	under.light_energy = 0.6
	root.add_child(under)
	var cam := Camera3D.new()
	cam.fov = 35
	root.add_child(cam)
	cam.make_current()
	for kind: String in OS.get_cmdline_user_args():
		var clues: Array = []
		for c: Dictionary in Items.KINDS[kind]["clues"]:
			clues.append(c.duplicate())
		for cp: Dictionary in Items.COPIES[kind]:                ## every copy's tell too, to see where each would sit
			if not (cp["tell"] as Dictionary).is_empty():
				var t: Dictionary = (cp["tell"] as Dictionary).duplicate()
				t["id"] = "tell_%d" % clues.size()
				t["pos"] = Vector3.ZERO
				clues.append(t)
		var n := Models.build({"kind": kind, "clues": clues})
		root.add_child(n)
		await wait(0.3)
		for view: Array in [["front", Vector3(0.1, 0.12, 0.45)], ["back", Vector3(-0.1, 0.12, -0.45)], ["under", Vector3(0.02, -0.45, 0.12)]]:
			cam.position = view[1]
			cam.look_at(Vector3.ZERO, Vector3.UP if view[0] != "under" else Vector3.FORWARD)
			await wait(0.1)
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("res://tools/shots/clue_%s_%s.png" % [kind, view[0]])
		n.queue_free()
	quit()
