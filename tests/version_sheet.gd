extends SceneTree
## Every version of every object close up at the detail that tells it apart: the mark on the real piece and on copies whose mark gives
## them away, the added part on the others. Shots go to tools/shots/v_<kind>_<version>.png. Run windowed (not headless).

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await process_frame

func run() -> void:
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.16, 0.13, 0.12)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.75, 0.72, 0.7)
	env.environment.ambient_light_energy = 0.45
	w.add_child(env)
	var cam := Camera3D.new()
	cam.fov = 40.0
	cam.near = 0.005
	w.add_child(cam)
	var lamp := OmniLight3D.new()
	lamp.omni_range = 2.0
	lamp.light_energy = 0.55
	w.add_child(lamp)
	var rng := RandomNumberGenerator.new()
	for kind: String in Items.KINDS:
		for v in 5:
			var item := {}
			for t in 3000:
				rng.seed = t * 31 + v
				var it: Dictionary = Items.make(kind, rng, 0.0 if v == 0 else 1.0)
				if it["variant"] == v:
					item = it
					break
			var node := Models.build(item)
			w.add_child(node)
			var focus: Dictionary = {}
			for c: Dictionary in item["clues"]:
				if (v > 0 and c.get("fake", false)) or (v == 0 and c.has("label")):
					focus = c
			var p: Vector3 = focus.get("pos", Vector3.ZERO)
			var n: Vector3 = focus.get("normal", Vector3(0, 0, 1))
			var eye := p + n * 0.13 + Vector3(0, 0.001, 0.001)
			cam.transform = Transform3D(Basis.looking_at(p - eye, Vector3(0, 0, -1) if absf(n.y) > 0.9 else Vector3.UP), eye)
			lamp.position = eye + Vector3(0.05, 0.08, 0.02)
			await frames(4)
			await RenderingServer.frame_post_draw
			root.get_viewport().get_texture().get_image().save_png("res://tools/shots/v_%s_%d.png" % [kind, v])
			node.queue_free()
			await frames(1)
	quit()
