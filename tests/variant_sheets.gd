extends SceneTree
## One comparison sheet per antique type: its five versions (real first, then copies 1-4) in three rows: the whole object, its maker's mark,
## and its tell (or, on the real piece, its damage). Close-ups are taken from the game's closest inspection distance and field of view.
## Shots go to tools/shots/cmp_<kind>_<version>_<row>.png; tools/compose_sheets.py lays them out. Run windowed (not headless).

const FOV := 60.0          ## the inspection camera's field of view (main.gd)
const CLOSEST := 0.28      ## the inspection camera's closest distance from the object's centre (main.gd zoom minimum)

func _initialize() -> void:
	call_deferred("run")

func frames(n: int) -> void:
	for i in n:
		await process_frame

func shot(name: String) -> void:
	await frames(3)
	await RenderingServer.frame_post_draw
	root.get_viewport().get_texture().get_image().save_png("res://tools/shots/%s.png" % name)

func run() -> void:
	var w := Node3D.new()
	root.add_child(w)
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.13, 0.1, 0.09)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.5, 0.48)
	env.environment.ambient_light_energy = 0.6
	env.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	w.add_child(env)
	var lamp := DirectionalLight3D.new()                   ## the inspection lamp, warm, from the front right and above
	lamp.light_color = Color(1.0, 0.86, 0.66)
	lamp.light_energy = 1.1
	w.add_child(lamp)
	var cam := Camera3D.new()
	cam.fov = FOV
	cam.near = 0.005
	w.add_child(cam)
	var rng := RandomNumberGenerator.new()
	var only := ""                                              ## -- --kinds=lantern,jug renders just those
	for a in OS.get_cmdline_user_args():
		if a.begins_with("--kinds="):
			only = a.substr(8)
	for kind: String in Items.KINDS:
		if only != "" and not kind in only.split(","):
			continue
		for v in 5:
			var item := {}
			for t in 4000:                                  ## a version of this kind with all of its clues present
				rng.seed = t * 37 + v
				var it: Dictionary = Items.make(kind, rng, 0.0 if v == 0 else 1.0)
				if it["variant"] == v and it["clues"].size() >= Items.KINDS[kind]["clues"].size() - (0 if v == 0 else 1):
					item = it
					break
			var node := Models.build(item)
			w.add_child(node)
			await frames(2)
			# the whole object, three-quarter view
			var eye := Vector3(0.28, 0.2, 0.42)
			cam.transform = Transform3D(Basis.looking_at(-eye), eye)
			lamp.transform = Transform3D(Basis.looking_at(Vector3(-0.4, -0.6, -0.7)), Vector3.ZERO)
			await shot("cmp_%s_%d_over" % [kind, v])
			var mark: Dictionary = {}
			var tell: Dictionary = {}
			for c: Dictionary in item["clues"]:
				if c.has("tex") and String(c["id"]) in Items.MARK_IDS:
					mark = c
				elif (v > 0 and c.get("fake", false)) or (v == 0 and c.get("damage", false)):
					tell = c
			for pair in [["mark", mark], ["tell", tell]]:
				var c2: Dictionary = pair[1]
				if c2.is_empty():
					continue
				var p: Vector3 = c2["pos"]
				var n: Vector3 = c2["normal"]
				var dist := maxf(CLOSEST - p.length(), 0.12)  ## as close as the game lets you get to that spot
				var e2 := p + n * dist + Vector3(0.0005, 0.0005, 0.0005)
				var up := Vector3(0, 0, -1) if absf(n.y) > 0.9 else Vector3.UP
				cam.transform = Transform3D(Basis.looking_at(p - e2, up), e2)
				lamp.transform = Transform3D(Basis.looking_at(-n + Vector3(0.3, -0.4, 0.2)), Vector3.ZERO)
				await shot("cmp_%s_%d_%s" % [kind, v, pair[0]])
			node.queue_free()
			await frames(1)
	quit()
