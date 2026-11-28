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
	var parts_path := "res://assets/items/%s_parts.glb" % item["kind"]      ## the same model cut into moving parts (tools/split_items.py)
	var living: Living = null
	if ResourceLoader.exists(parts_path):
		path = parts_path
	var tris := PackedVector3Array()
	if ResourceLoader.exists(path):
		var model := (load(path) as PackedScene).instantiate() as Node3D
		root.add_child(model)
		_fit(model)
		_tint(model, item.get("tint", Color.WHITE), float(item.get("gloss", -1.0)))
		if item["kind"] == "snow_globe":
			SnowGlobe.build(model)                               ## glass dome, a scene inside and moving snow on the Meshy base
		var data_path := "res://assets/items/%s_parts.json" % item["kind"]
		if path == parts_path and ResourceLoader.exists(data_path):
			var data = (load(data_path) as JSON).data
			if data is Dictionary:
				living = Living.new()
				living.name = "Living"
				root.add_child(living)
				living.setup(root, model, data)
		tris = _aim_clues(root, model, item["clues"])
		if item.has("wear_seed"):
			_wear(root, tris, int(item["wear_seed"]))
	else:
		_stand_in(root, String(item["kind"]))
	for c: Dictionary in item["clues"]:
		_draw_clue(root, c, tris)
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
		if living != null and m.has_meta("living_part"):        ## a lid or a chain: its shape moves with it
			cs.set_meta("living_part", m.get_meta("living_part"))
			for p: Dictionary in living.parts:
				if p["node"] == m:
					p["shape"] = cs
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
static func _aim_clues(root: Node3D, model: Node3D, clues: Array) -> PackedVector3Array:
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
		# straight in from that side; if the ray slips past the model (a hole, a thin part), look a little further round the spot
		var hit := Vector3.INF
		for ring in 6:
			for k in (1 if ring == 0 else 8):
				var off := Vector2.from_angle(TAU * float(k) / 8.0) * 0.12 * float(ring)
				var a2 := at + off
				var origin := c0 + ua * a2.x * (ua.abs().dot(half)) + va * a2.y * (va.abs().dot(half)) + n * (n.abs().dot(half) + 0.05)
				hit = _ray(tris, origin, -n)
				if hit != Vector3.INF:
					break
			if hit != Vector3.INF:
				break
		c["pos"] = hit if hit != Vector3.INF else c0 + n * n.abs().dot(half)
		c["normal"] = n
		c["on_surface"] = hit != Vector3.INF                     ## false: the ray missed the model, the clue would float (tests check this)
	return tris

## The nearest point where a ray meets the triangles, or INF.
static func _ray(tris: PackedVector3Array, origin: Vector3, dir: Vector3) -> Vector3:
	var best := INF
	var hit := Vector3.INF
	for i in range(0, tris.size(), 3):
		var r = Geometry3D.ray_intersects_triangle(origin, dir, tris[i], tris[i + 1], tris[i + 2])
		if r != null:
			var d := origin.distance_to(r)
			if d < best:
				best = d
				hit = r
	return hit

## Colours a copy differently from the real piece (its own copies of the materials, so other objects of the kind are untouched).
static func _tint(model: Node3D, tint: Color, gloss: float = -1.0) -> void:
	if tint == Color.WHITE and gloss < 0.0:
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
				if gloss >= 0.0:                                     ## plastic, resin, plating: a shine the real piece doesn't have
					t.roughness = gloss
					t.metallic_specular = 0.8
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

## A frame on the surface at a clue: z out of the surface, x and y along it.
static func _frame(n: Vector3) -> Basis:
	var up := Vector3(0, 0, -1) if absf(n.y) > 0.9 else Vector3.UP
	var x := up.cross(n).normalized()
	var y := n.cross(x).normalized()
	return Basis(x, y, n)

## Draws a clue on the object: a maker's mark, sticker or stamp as its own artwork laid on the surface (scripts/marks.gd), and damage or
## a copy's tell as the physical part that shows it.
static func _draw_clue(root: Node3D, c: Dictionary, tris: PackedVector3Array = PackedVector3Array()) -> void:
	var pos: Vector3 = c["pos"]
	var n: Vector3 = c.get("normal", Vector3(0, 0, 1))
	if c.has("tex") and tris.size() > 0:
		Marks.patch(root, tris, pos, n, String(c["tex"]), float(c.get("w", 0.06)), String(c.get("fit", "")))
	elif c.has("part"):
		_part_at(root, String(c["part"]), pos, n, String(c.get("part_text", "")))

## A small mesh on a part, marked so the loupe's collider ignores it.
static func _bit(parent: Node3D, mesh: Mesh, pos: Vector3, mat: Material, rot: Vector3 = Vector3.ZERO) -> MeshInstance3D:
	var mi := _part(parent, mesh, pos, mat, rot)
	mi.set_meta("clue", true)
	return mi

## The physical tell of a copy, built where its clue sits on the surface.
static func _part_at(root: Node3D, kind: String, pos: Vector3, n: Vector3, text: String) -> void:
	var f := Node3D.new()
	f.position = pos + n * 0.002
	f.basis = _frame(n)
	root.add_child(f)
	var steel := _mat(Color(0.62, 0.62, 0.64), 0.35, 0.8)
	var dark := _mat(Color(0.08, 0.07, 0.06), 0.8)
	match kind:
		"crack":                                                   ## a hairline crack in glass: a fine pale zigzag
			var pale := _mat(Color(0.95, 0.97, 1.0, 0.8), 0.1)
			pale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			for k in 4:
				_bit(f, _box(0.011, 0.0007, 0.0006), Vector3(-0.016 + k * 0.0105, (0.002 if k % 2 == 0 else -0.002), 0), pale, Vector3(0, 0, 0.5 if k % 2 == 0 else -0.5))
		"dent":                                                    ## a dent: a dark crescent with a bright lip
			_bit(f, _cyl(0.008, 0.008, 0.0008, 14), Vector3(0, 0, -0.0004), _mat(Color(0.25, 0.18, 0.08), 0.7, 0.6), Vector3(PI * 0.5, 0, 0))
			_bit(f, _box(0.014, 0.0012, 0.0008), Vector3(0, 0.0075, 0), _mat(Color(1.0, 0.92, 0.6), 0.2, 0.9))
		"chip_glass":                                              ## a chip out of glass: a small bright notch
			var g := _mat(Color(0.92, 0.97, 1.0, 0.9), 0.05)
			g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_bit(f, _box(0.007, 0.005, 0.0008), Vector3.ZERO, g, Vector3(0, 0, 0.7))
			_bit(f, _box(0.004, 0.003, 0.0009), Vector3(0.002, -0.002, 0), g, Vector3(0, 0, -0.4))
		"chip_ceramic":                                            ## a chip out of the glaze: raw pale clay showing
			var clay := _mat(Color(0.86, 0.78, 0.66), 0.95)
			_bit(f, _box(0.009, 0.006, 0.0009), Vector3.ZERO, clay, Vector3(0, 0, 0.6))
			_bit(f, _box(0.005, 0.004, 0.001), Vector3(0.003, 0.002, 0), clay, Vector3(0, 0, -0.3))
		"pinholes":                                                ## pinholes in the bellows: light coming through
			var lightm := _mat(Color(1.0, 0.95, 0.8), 0.5)
			lightm.emission_enabled = true
			lightm.emission = Color(1.0, 0.9, 0.7)
			for k in 4:
				_bit(f, _box(0.0018, 0.0018, 0.0008), Vector3(sin(k * 2.4) * 0.008, cos(k * 1.9) * 0.006, 0), lightm)
		"airgap":                                                  ## water lost from the dome: a silvery air pocket under the glass top
			var air := _mat(Color(0.85, 0.9, 0.95, 0.55), 0.05, 0.3)
			air.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_bit(f, _cyl(0.02, 0.02, 0.001, 20), Vector3(0, 0, -0.004), air, Vector3(PI * 0.5, 0, 0))
		"screws":                                                  ## two cross-head screws
			for sx: float in [-0.018, 0.018]:
				_bit(f, _cyl(0.006, 0.006, 0.002, 12), Vector3(sx, 0, 0), steel, Vector3(PI * 0.5, 0, 0))
				_bit(f, _box(0.008, 0.0012, 0.001), Vector3(sx, 0, 0.0012), dark)
				_bit(f, _box(0.0012, 0.008, 0.001), Vector3(sx, 0, 0.0012), dark)
		"tin":                                                     ## a stamped tin plate where a steel comb should be
			_bit(f, _box(0.05, 0.03, 0.0015), Vector3.ZERO, _mat(Color(0.8, 0.8, 0.78), 0.25, 0.9))
			for k in 4:
				_bit(f, _box(0.04, 0.0012, 0.0008), Vector3(0, -0.01 + k * 0.007, 0.001), _mat(Color(0.5, 0.5, 0.5), 0.4, 0.8))
		"glue":                                                    ## a lifting edge with a shiny glue line
			var amber := _mat(Color(0.85, 0.62, 0.2), 0.1)
			for k in 3:
				_bit(f, _box(0.014, 0.0018, 0.0012), Vector3(k * 0.012 - 0.012, sin(float(k)) * 0.002, 0), amber, Vector3(0, 0, 0.15 * float(k - 1)))
		"grooves":                                                 ## knife cuts all exactly alike
			for k in 5:
				_bit(f, _box(0.022, 0.0018, 0.0012), Vector3(0, -0.012 + k * 0.006, 0), _mat(Color(0.3, 0.18, 0.09), 0.9))
		"seam":                                                    ## a moulding seam: a fine raised line
			_bit(f, _box(0.0016, 0.075, 0.0016), Vector3.ZERO, _mat(Color(0.75, 0.68, 0.58), 0.3))
		"seam_short":                                              ## the same on a small rounded piece, where a long one would stand off the curve
			_bit(f, _box(0.0014, 0.026, 0.0012), Vector3.ZERO, _mat(Color(0.75, 0.68, 0.58), 0.3))
		"paint", "rust", "brassy", "chips":                        ## patina, rust, worn brass or chipped paint, painted on in flat even blotches
			var col := {"paint": Color(0.32, 0.56, 0.38), "rust": Color(0.46, 0.24, 0.12), "brassy": Color(0.72, 0.56, 0.28), "chips": Color(0.82, 0.72, 0.55)}[kind] as Color
			var flat := _mat(col, 0.95)
			for k in 3:
				_bit(f, _cyl(0.009 - k * 0.002, 0.009 - k * 0.002, 0.0006, 14), Vector3(k * 0.009 - 0.009, k * 0.004 - 0.004, 0), flat, Vector3(PI * 0.5, 0, 0))
		"bubble":                                                  ## an air bubble in the liquid under the glass
			var b := _mat(Color(0.9, 0.95, 1.0, 0.5), 0.05)
			b.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			_bit(f, _sphere(0.007), Vector3(0, 0, 0.002), b)
		"welds":                                                   ## a row of spot welds
			for k in 4:
				_bit(f, _cyl(0.003, 0.003, 0.0012, 10), Vector3(0, -0.015 + k * 0.01, 0), _mat(Color(0.2, 0.18, 0.16), 0.6, 0.6), Vector3(PI * 0.5, 0, 0))
		"scratches":                                               ## a plastic globe, scratched all over
			var pale := _mat(Color(0.92, 0.92, 0.95, 0.85), 0.2)
			pale.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			for k in 6:
				_bit(f, _box(0.022, 0.0008, 0.0006), Vector3(sin(k * 2.1) * 0.012, cos(k * 1.7) * 0.012, 0), pale, Vector3(0, 0, k * 0.9))
		"glitter":                                                 ## metal glitter instead of bone-white flakes
			var gl := _mat(Color(0.95, 0.85, 0.5), 0.15, 1.0)
			for k in 12:
				_bit(f, _box(0.0025, 0.0025, 0.0008), Vector3(sin(k * 2.7) * 0.015, cos(k * 1.3) * 0.015, 0), gl, Vector3(0, 0, k))
		"stain":                                                   ## tea stain on a too-clean base
			var tea := _mat(Color(0.42, 0.26, 0.12, 0.55), 0.9)
			tea.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
			for k in 3:
				_bit(f, _cyl(0.012 - k * 0.003, 0.012 - k * 0.003, 0.0006, 14), Vector3(k * 0.006 - 0.006, -k * 0.004, 0), tea, Vector3(PI * 0.5, 0, 0))
		"glaze":                                                   ## bright even modern glaze
			_bit(f, _cyl(0.014, 0.014, 0.0008, 16), Vector3.ZERO, _mat(Color(0.98, 0.98, 0.96), 0.05), Vector3(PI * 0.5, 0, 0))

## Honest wear on every version, real or copy: a few light scratches and rubbed spots anywhere on the surface. Never a clue.
static func _wear(root: Node3D, tris: PackedVector3Array, seed: int) -> void:
	if tris.size() < 3:
		return
	var r := RandomNumberGenerator.new()
	r.seed = seed
	var scuff := _mat(Color(0.85, 0.82, 0.76, 0.45), 0.9)
	scuff.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	for k in r.randi_range(3, 5):
		var i := (r.randi() % (tris.size() / 3)) * 3
		var a: Vector3 = tris[i]
		var b: Vector3 = tris[i + 1]
		var c: Vector3 = tris[i + 2]
		var nrm := (b - a).cross(c - a)
		if nrm.length() < 1e-9:
			continue
		var f := Node3D.new()
		f.position = (a + b + c) / 3.0 + nrm.normalized() * 0.0008
		f.basis = _frame(nrm.normalized())
		root.add_child(f)
		_bit(f, _box(r.randf_range(0.01, 0.025), 0.0009, 0.0005), Vector3.ZERO, scuff, Vector3(0, 0, r.randf() * PI))
