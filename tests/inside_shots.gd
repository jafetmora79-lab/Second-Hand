extends SceneTree
## A piece's inside, close up from above and four sides, as it comes onto the mat (a music box's lid starts open): for checking what Meshy
## left in there. With "shut", its lid is closed first (to check the lid's top).
## Run windowed: godot --resolution 900x900 -s tests/inside_shots.gd -- <kind> [shut]   (shots go to tools/shots/inside_<kind>_<view>[_shut].png)
func _initialize() -> void:
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func run() -> void:
	var args := OS.get_cmdline_user_args()
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.33, 0.36)
	env.environment.ambient_light_color = Color(0.8, 0.8, 0.8)
	env.environment.ambient_light_energy = 0.8
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-1.2, 0.4, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 35
	root.add_child(cam)
	cam.make_current()
	var kind: String = args[0]
	var shut := args.has("shut")
	var n := Models.build({"kind": kind, "clues": []})
	root.add_child(n)
	var lv := n.get_node_or_null("Living") as Living
	if shut and lv:
		await wait(0.2)
		lv.toggle("Lid")
	await wait(2.5)
	for view: Array in [["top", Vector3(0.0, 0.42, 0.06)], ["front", Vector3(0.0, 0.3, 0.3)], ["left", Vector3(-0.3, 0.3, 0.0)], ["right", Vector3(0.3, 0.3, 0.0)], ["back", Vector3(0.0, 0.3, -0.25)]]:
		cam.position = view[1]
		cam.look_at(Vector3.ZERO)
		await wait(0.1)
		await RenderingServer.frame_post_draw
		root.get_viewport().get_texture().get_image().save_png("res://tools/shots/inside_%s_%s%s.png" % [kind, view[0], "_shut" if shut else ""])
	quit()
