extends SceneTree
## The Timberline kit pieces the shop is built from, side by side (front faces toward the camera). Run windowed; shot to tools/shots/kit_sheet.png.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var w := Node3D.new()
	root.add_child(w)
	var names := ["HK_wall_interior", "HK_wall_shop", "HK_wall_plain", "HK_window", "HK_floor_worn", "HK_floor_finished", "HK_counter", "HK_door_shop", "HK_wall_door", "HK_partition"]
	for i in names.size():
		var m := (load("res://assets/kit/%s.glb" % names[i]) as PackedScene).instantiate() as Node3D
		m.position = Vector3((i % 5) * 1.25 - 2.5, 1.0 - (i / 5) * 1.1, 0)
		w.add_child(m)
		var l := Label3D.new()
		l.text = names[i]
		l.pixel_size = 0.002
		l.position = m.position + Vector3(0, -0.5, 0.3)
		w.add_child(l)
	var c := Camera3D.new()
	c.position = Vector3(0, 0.5, 5.2)
	w.add_child(c)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.6, 0.3, 0)
	w.add_child(sun)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.3, 0.3, 0.32)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.6, 0.6, 0.6)
	w.add_child(env)
	for k in 30:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/kit_sheet.png")
	quit()
