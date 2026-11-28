extends SceneTree
## The newer antiques' moving parts, each at rest and moved, from the front and the side: the spyglass's cap on its lens, the coffee
## grinder's drawer, the kettle's lid. Run windowed; shots go to tools/shots/parts_<kind>_<pose>_<view>.png.
var KINDS := ["spyglass", "coffee_grinder", "kettle"]
func _initialize() -> void:
	var a := OS.get_cmdline_user_args()
	if a.size() > 0:
		KINDS = Array(a)
	call_deferred("run")
func wait(t: float) -> void:
	var end := Time.get_ticks_msec() + int(t * 1000.0)
	while Time.get_ticks_msec() < end:
		await process_frame
func snap(n: String) -> void:
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/parts_%s.png" % n)
func run() -> void:
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.32, 0.33, 0.36)
	env.environment.ambient_light_color = Color(0.7, 0.7, 0.7)
	env.environment.ambient_light_energy = 0.6
	w.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	w.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 35
	w.add_child(cam)
	cam.make_current()
	for kind in KINDS:
		var n := Models.build({"kind": kind, "clues": []})
		w.add_child(n)
		var lv := n.get_node_or_null("Living") as Living
		print(kind, " parts: ", lv.parts.size() if lv else 0)
		for pose in ["rest", "moved"]:
			if pose == "moved" and lv:
				lv.toggle()
			await wait(2.5)
			for view: Array in [["front", Vector3(0.12, 0.08, 0.42)], ["side", Vector3(0.5, 0.06, 0.12)], ["top", Vector3(0.02, 0.42, 0.08)]]:
				cam.position = view[1]
				cam.look_at(Models._rel(w, n).origin + n.get_child(0).position * 0.0 + _centre(n))
				await wait(0.1)
				await snap("%s_%s_%s" % [kind, pose, view[0]])
		n.queue_free()
	quit()
func _centre(n: Node3D) -> Vector3:
	var box := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var b := Models._rel(n, mi as Node3D) * (mi as MeshInstance3D).get_aabb()
		box = b if first else box.merge(b)
		first = false
	return box.get_center()
