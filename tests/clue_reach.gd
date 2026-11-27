extends SceneTree
## Every clue on every version of every object (8 kinds x 5 versions, damage included) must be findable with the loupe:
##  - it sits on the model's real surface (the aiming ray hit the mesh);
##  - looking straight at it from outside, the first surface the loupe's ray meets is within reach of it (nothing covers it);
##  - no two clues on one piece are so close that the loupe can't tell them apart;
##  - every copy has a tell (a clue marked fake) and the real piece has none.
## Run: godot --headless -s tests/clue_reach.gd

const REACH := 0.032          ## main.gd LOUPE_REACH

func _initialize() -> void:
	call_deferred("run")

func tris_of(root: Node3D) -> PackedVector3Array:
	var t := PackedVector3Array()
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta("clue"):
			continue
		var xf := Models._rel(root, m)
		for v in m.mesh.get_faces():
			t.append(xf * v)
	return t

func first_hit(t: PackedVector3Array, from: Vector3, dir: Vector3) -> Vector3:
	var best := INF
	var hit := Vector3.INF
	for i in range(0, t.size(), 3):
		var r = Geometry3D.ray_intersects_triangle(from, dir, t[i], t[i + 1], t[i + 2])
		if r != null and from.distance_to(r) < best:
			best = from.distance_to(r)
			hit = r
	return hit

func run() -> void:
	var fails := 0
	var checked := 0
	var rng := RandomNumberGenerator.new()
	for kind: String in Items.KINDS:
		for v in 5:
			# a version of this kind with every damage clue present
			var item := {}
			for tries in 4000:
				rng.seed = tries * 977 + v * 13 + kind.length()
				var it: Dictionary = Items.make(kind, rng, 0.0 if v == 0 else 1.0)
				if it["variant"] != v:
					continue
				var dmg := 0
				for c: Dictionary in it["clues"]:
					if c.get("damage", false):
						dmg += 1
				var want := 0
				for c0: Dictionary in Items.KINDS[kind]["clues"]:
					if c0.get("damage", false):
						want += 1
				if dmg == want:
					item = it
					break
			if item.is_empty():
				fails += 1
				print("FAIL: never made %s version %d with its damage" % [kind, v])
				continue
			var node := Models.build(item)
			var t := tris_of(node)
			var tells := 0
			for c: Dictionary in item["clues"]:
				checked += 1
				var where := "%s v%d '%s'" % [kind, v, c["id"]]
				if c.get("fake", false):
					tells += 1
				if not c.get("on_surface", false):
					fails += 1
					print("FAIL: %s is not on the model's surface" % where)
					continue
				var p: Vector3 = c["pos"]
				var n: Vector3 = c["normal"]
				var h := first_hit(t, p + n * 0.4, -n)
				if h == Vector3.INF or h.distance_to(p) > REACH:
					fails += 1
					print("FAIL: %s is covered: the loupe meets the surface %.3f m away from it" % [where, h.distance_to(p) if h != Vector3.INF else -1.0])
				for c2: Dictionary in item["clues"]:
					if c2 != c and str(c2["id"]) > str(c["id"]) and (c2["pos"] as Vector3).distance_to(p) < REACH * 0.9:
						fails += 1
						print("FAIL: %s and '%s' are too close for the loupe to tell apart" % [where, c2["id"]])
			if (v == 0) != (tells == 0):
				fails += 1
				print("FAIL: %s version %d has %d tells" % [kind, v, tells])
			node.free()
	print("checked %d clues on 40 versions" % checked)
	print("RESULT: clue_reach, %d failures" % fails)
	quit(1 if fails > 0 else 0)
