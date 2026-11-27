extends RefCounted
class_name Models
## Builds an object to hold and inspect: its Meshy model when assets/items/<kind>.glb exists (scaled to ~0.28 m), otherwise a stand-in from simple parts.
## Then its clues are drawn on it (stamped text, cracks, chips), and a collider is added so the loupe can find what it is pointing at.

const SIZE := 0.28

static func _mat(c: Color, rough: float = 0.6, metal: float = 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	m.roughness = rough
	m.metallic = metal
	return m

static func _part(root: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.rotation = rot
	root.add_child(mi)
	return mi

static func _box(x: float, y: float, z: float) -> BoxMesh:
	var b := BoxMesh.new()
	b.size = Vector3(x, y, z)
	return b

static func _cyl(rt: float, rb: float, h: float, segs: int = 24) -> CylinderMesh:
	var c := CylinderMesh.new()
	c.top_radius = rt
	c.bottom_radius = rb
	c.height = h
	c.radial_segments = segs
	return c

static func _sphere(r: float, h: float = -1.0) -> SphereMesh:
	var s := SphereMesh.new()
	s.radius = r
	s.height = r * 2.0 if h < 0.0 else h
	s.radial_segments = 24
	s.rings = 12
	return s

static func build(item: Dictionary) -> Node3D:
	var root := Node3D.new()
	root.name = "Item"
	var path := "res://assets/items/%s.glb" % item["kind"]
	if ResourceLoader.exists(path):
		var model := (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		_fit(model)
		_tint(model, item.get("tint", Color.WHITE))
		_aim_clues(root, model, item["clues"])
	else:
		_stand_in(root, String(item["kind"]))
	for c: Dictionary in item["clues"]:
		_draw_clue(root, c)
	var body := StaticBody3D.new()
	body.name = "Hit"
	for mi in root.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null or m.has_meta("clue"):
			continue
		var cs := CollisionShape3D.new()
		cs.shape = m.mesh.create_trimesh_shape()
		cs.transform = root.global_transform.affine_inverse() * m.global_transform if m.is_inside_tree() else _rel(root, m)
		body.add_child(cs)
	root.add_child(body)
	return root

static func _rel(root: Node3D, n: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var cur: Node = n
	while cur != null and cur != root:
		if cur is Node3D:
			t = (cur as Node3D).transform * t
		cur = cur.get_parent()
	return t

const SIDES := {"bottom": Vector3(0, -1, 0), "top": Vector3(0, 1, 0), "front": Vector3(0, 0, 1), "back": Vector3(0, 0, -1), "right": Vector3(1, 0, 0), "left": Vector3(-1, 0, 0)}

## Puts each clue that says where it is ("from" a side, "at" a spot on that side as fractions of the half-size) onto the model's real surface:
## a ray from that side onto the mesh. Works for any model, so new Meshy models need no hand-placed coordinates.
static func _aim_clues(root: Node3D, model: Node3D, clues: Array) -> void:
	var tris := PackedVector3Array()
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		var xf := _rel(root, m)
		var faces := m.mesh.get_faces()
		for v in faces:
			var w: Vector3 = xf * v
			tris.append(w)
			box = AABB(w, Vector3.ZERO) if first else box.expand(w)
			first = false
	var c0 := box.get_center()
	var half := box.size * 0.5
	for c: Dictionary in clues:
		if not c.has("from"):
			continue
		var n: Vector3 = SIDES[c["from"]]
		var at: Vector2 = c.get("at", Vector2.ZERO)
		var ua := Vector3(1, 0, 0) if absf(n.x) < 0.5 else Vector3(0, 0, 1)
		var va := Vector3(0, 0, 1) if absf(n.y) > 0.5 else Vector3(0, 1, 0)
		var origin := c0 + ua * at.x * (ua.abs().dot(half)) + va * at.y * (va.abs().dot(half)) + n * (n.abs().dot(half) + 0.05)
		var best := INF
		var hit := Vector3.INF
		for i in range(0, tris.size(), 3):
			var r = Geometry3D.ray_intersects_triangle(origin, -n, tris[i], tris[i + 1], tris[i + 2])
			if r != null:
				var d := origin.distance_to(r)
				if d < best:
					best = d
					hit = r
		c["pos"] = hit if hit != Vector3.INF else c0 + n * n.abs().dot(half)
		c["normal"] = n

## Colours a copy differently from the real piece (its own copies of the materials, so other objects of the kind are untouched).
static func _tint(model: Node3D, tint: Color) -> void:
	if tint == Color.WHITE:
		return
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		if m.mesh == null:
			continue
		for s in m.mesh.get_surface_count():
			var mat := m.get_active_material(s)
			if mat is BaseMaterial3D:
				var t := (mat as BaseMaterial3D).duplicate() as BaseMaterial3D
				t.albedo_color = t.albedo_color * tint
				m.set_surface_override_material(s, t)

## Scales and centres a Meshy model so its largest side is SIZE and it sits centred on the origin.
static func _fit(model: Node3D) -> void:
	var box := AABB()
	var first := true
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var b := _rel(model, m) * m.get_aabb()
		box = b if first else box.merge(b)
		first = false
	var s := SIZE / maxf(box.size[box.get_longest_axis_index()], 0.001)
	model.scale = Vector3.ONE * s
	model.position = -box.get_center() * s

static func _stand_in(root: Node3D, kind: String) -> void:
	var wood := _mat(Color(0.36, 0.22, 0.13), 0.7)
	var pale := _mat(Color(0.78, 0.64, 0.45), 0.7)
	var brass := _mat(Color(0.78, 0.6, 0.28), 0.35, 0.8)
	var silver := _mat(Color(0.8, 0.8, 0.82), 0.25, 0.9)
	var cream := _mat(Color(0.93, 0.9, 0.82), 0.5)
	var glass := _mat(Color(0.75, 0.85, 0.9), 0.05)
	var red := _mat(Color(0.62, 0.15, 0.12), 0.6)
	var black := _mat(Color(0.08, 0.08, 0.09), 0.6)
	match kind:
		"music_box":
			_part(root, _box(0.22, 0.12, 0.15), Vector3(0, -0.015, 0), wood)
			_part(root, _box(0.225, 0.03, 0.155), Vector3(0, 0.06, 0), wood)
			_part(root, _box(0.12, 0.004, 0.07), Vector3(0, 0.077, 0), pale)
			_part(root, _cyl(0.008, 0.008, 0.04), Vector3(0.12, 0.0, 0), brass, Vector3(0, 0, PI * 0.5))
		"pocket_watch":
			_part(root, _cyl(0.055, 0.055, 0.025, 32), Vector3.ZERO, silver, Vector3(PI * 0.5, 0, 0))
			_part(root, _cyl(0.048, 0.048, 0.002, 32), Vector3(0, 0, 0.013), cream, Vector3(PI * 0.5, 0, 0))
			_part(root, _cyl(0.008, 0.008, 0.015), Vector3(0, 0.062, 0), silver)
			_part(root, _box(0.003, 0.03, 0.001), Vector3(0, 0.012, 0.0145), black)
			_part(root, _box(0.022, 0.003, 0.001), Vector3(0.008, 0, 0.0145), black)
		"carved_bear":
			_part(root, _box(0.2, 0.04, 0.12), Vector3(0, -0.04, 0), wood)
			_part(root, _sphere(0.08, 0.1), Vector3(0, 0.03, 0), pale)
			_part(root, _sphere(0.045), Vector3(0, 0.06, 0.07), pale)
			_part(root, _sphere(0.015), Vector3(0.03, 0.1, 0.07), pale)
			_part(root, _sphere(0.015), Vector3(-0.03, 0.1, 0.07), pale)
		"compass":
			_part(root, _cyl(0.06, 0.06, 0.022, 32), Vector3.ZERO, brass)
			_part(root, _cyl(0.052, 0.052, 0.002, 32), Vector3(0, 0.012, 0), cream)
			_part(root, _box(0.004, 0.002, 0.08), Vector3(0, 0.014, 0), red)
		"lantern":
			_part(root, _cyl(0.07, 0.075, 0.05), Vector3(0, -0.08, 0), red)
			_part(root, _sphere(0.06, 0.13), Vector3(0, 0.0, 0), glass)
			_part(root, _cyl(0.045, 0.05, 0.04), Vector3(0, 0.08, 0), red)
			_part(root, _box(0.004, 0.06, 0.004), Vector3(0.065, 0.0, 0), red)
			_part(root, _box(0.004, 0.06, 0.004), Vector3(-0.065, 0.0, 0), red)
		"camera":
			_part(root, _box(0.16, 0.1, 0.05), Vector3(0, 0, -0.03), black)
			_part(root, _box(0.1, 0.085, 0.07), Vector3(0, 0, 0.03), _mat(Color(0.14, 0.12, 0.12), 0.8))
			_part(root, _cyl(0.025, 0.025, 0.03), Vector3(0, 0, 0.075), silver, Vector3(PI * 0.5, 0, 0))
		"snow_globe":
			_part(root, _cyl(0.06, 0.07, 0.05), Vector3(0, -0.045, 0), wood)
			_part(root, _sphere(0.065), Vector3(0, 0.03, 0), glass)
			_part(root, _box(0.03, 0.025, 0.03), Vector3(0, 0.0, 0), wood)
			_part(root, _box(0.03, 0.012, 0.004), Vector3(0, -0.04, 0.062), brass)
		"jug":
			_part(root, _sphere(0.075, 0.18), Vector3(0, -0.01, 0), cream)
			_part(root, _cyl(0.025, 0.04, 0.06), Vector3(0, 0.09, 0), _mat(Color(0.42, 0.26, 0.14), 0.5))
			_part(root, _cyl(0.014, 0.014, 0.02), Vector3(0, 0.13, 0), pale)

## Draws a clue on the object: a stamp or engraving as small text on its face, a crack as dark lines, a chip as a pale nick.
static func _draw_clue(root: Node3D, c: Dictionary) -> void:
	var pos: Vector3 = c["pos"]
	if c.has("label"):
		var l := Label3D.new()
		l.text = String(c["label"])
		l.pixel_size = 0.00035
		l.font_size = 32
		l.outline_size = 0
		l.modulate = Color(0.12, 0.1, 0.08, 0.9)
		l.double_sided = false
		l.no_depth_test = false
		l.position = pos
		if c.has("normal"):
			var n: Vector3 = c["normal"]
			l.basis = Basis.looking_at(-n, Vector3(0, 0, -1) if absf(n.y) > 0.9 else Vector3.UP)        ## its readable side faces out from the object
			l.position += n * 0.002
		else:
			match String(c.get("face", "front")):
				"bottom":
					l.rotation = Vector3(PI * 0.5, 0, 0)
					l.position.y -= 0.002
				"back":
					l.rotation = Vector3(0, PI, 0)
					l.position.z -= 0.002
				_:
					l.position.z += 0.002
		l.set_meta("clue", true)
		root.add_child(l)
	elif c.get("damage", false):
		var dark := _mat(Color(0.05, 0.04, 0.04), 0.9)
		for k in 3:
			var crack := _part(root, _box(0.025, 0.0015, 0.0015), pos + Vector3(k * 0.008 - 0.008, k * 0.004, 0.001), dark, Vector3(0, 0, 0.6 - k * 0.5))
			crack.set_meta("clue", true)
	elif c.get("fake", false):
		var tell := _part(root, _box(0.03, 0.002, 0.03), pos, _mat(Color(0.5, 0.48, 0.3), 0.3))
		tell.set_meta("clue", true)
