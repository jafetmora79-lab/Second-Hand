extends SceneTree
## Renders a small picture of each antique (its genuine Meshy model, three-quarter view, transparent background) for the ledger:
## assets/ui/items/<kind>.png. Run windowed (not headless):  godot --resolution 256x256 -s tools/item_icons.gd
func _initialize() -> void:
	call_deferred("run")
func frames(n: int) -> void:
	for i in n:
		await process_frame
func run() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://assets/ui/items"))
	var vp := SubViewport.new()
	vp.size = Vector2i(160, 160)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	root.add_child(vp)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_CLEAR_COLOR
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(1, 0.95, 0.88)
	env.environment.ambient_light_energy = 0.55
	vp.add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation = Vector3(-0.8, 0.6, 0)
	sun.light_energy = 1.2
	sun.light_color = Color(1.0, 0.92, 0.8)
	vp.add_child(sun)
	var cam := Camera3D.new()
	cam.fov = 30.0
	vp.add_child(cam)
	for kind: String in Items.KINDS.keys():
		var k: Dictionary = Items.KINDS[kind]
		var clues: Array = []
		for c: Dictionary in k["clues"]:
			clues.append(c.duplicate())
		var node := Models.build({"kind": kind, "name": k["name"], "cat": k["cat"], "clues": clues, "fake": false, "value": k["base"], "found": [], "base": k["base"]})
		vp.add_child(node)
		node.rotation = Vector3(0, -0.6, 0)
		var eye := Vector3(0.0, 0.22, 0.62)
		cam.transform = Transform3D(Basis.looking_at(-eye), eye)
		await frames(6)
		await RenderingServer.frame_post_draw
		vp.get_texture().get_image().save_png("res://assets/ui/items/%s.png" % kind)
		print("icon ", kind)
		node.queue_free()
		await frames(2)
	quit()
