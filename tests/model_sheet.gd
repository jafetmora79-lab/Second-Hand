extends SceneTree
## Renders every item model from the front, the side, above and below, with its box size printed: for placing clues.
func _initialize() -> void:
	call_deferred("run")
func run() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.85, 0.85, 0.85)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(1, 1, 1)
	e.ambient_light_energy = 0.7
	env.environment = e
	root.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-40, 30, 0)
	root.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 35
	root.add_child(cam)
	cam.current = true
	for kind in ["music_box", "pocket_watch", "carved_bear", "compass", "lantern"]:
		var holder := Node3D.new()
		root.add_child(holder)
		var m := (load("res://assets/items/%s.glb" % kind) as PackedScene).instantiate() as Node3D
		holder.add_child(m)
		Models._fit(m)
		var box := AABB()
		var first := true
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			var b: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
			box = b if first else box.merge(b)
			first = false
		print("BOX ", kind, " ", box)
		var views := {"front": Vector3(0, 0, 1), "right": Vector3(1, 0, 0), "top": Vector3(0, 1, 0.001), "bottom": Vector3(0, -1, 0.001)}
		for vn in views:
			var d: Vector3 = views[vn]
			cam.global_position = d.normalized() * 0.8
			cam.look_at(Vector3.ZERO, Vector3.UP if absf(d.y) < 0.9 else Vector3(0, 0, -1))
			await process_frame
			await process_frame
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("res://tools/shots/m_%s_%s.png" % [kind, vn])
		holder.queue_free()
		await process_frame
	quit()
