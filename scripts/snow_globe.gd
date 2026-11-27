extends RefCounted
class_name SnowGlobe
## The snow globe, rebuilt so it reads as a real one. Meshy gave us a good turned wooden base with its brass plate, but its dome came out as
## an opaque grey shell with the house stuck on the outside. So the Meshy mesh is rebuilt without every triangle above the top of the base,
## and on the base go a clear glass dome, a snowy mound with a tiny Timberline cottage and two pines inside, and real snow: flakes that sink
## slowly through the water, settle on the mound, and swirl up again when you turn or shake the globe.
## Everything is built in the Meshy model's own units (the model is scaled down to object size afterwards, with all of this inside it), and
## the glass dome is part of the model, so the loupe and the clues meet the glass.

const CUT := -0.16              ## the top of the wooden base, in the Meshy mesh's units (its dome starts just above)
const DOME_R := 0.33            ## the glass dome's radius in the same units
const FLAKES := 150

static func build(model: Node3D) -> void:
	var base_node: MeshInstance3D = null
	for mi in model.find_children("*", "MeshInstance3D", true, false):
		base_node = mi as MeshInstance3D
		base_node.mesh = _below(base_node.mesh, CUT)
	if base_node == null:
		return
	var aabb := base_node.mesh.get_aabb()
	var r := DOME_R
	var base_top := Vector3(aabb.get_center().x, CUT, aabb.get_center().z)
	var centre := base_top + Vector3(0, r * 0.82, 0)
	# the glass: clear where you look through it, bright at its rim, with a highlight (shaders/globe_glass.gdshader)
	var glass := ShaderMaterial.new()
	glass.shader = load("res://shaders/globe_glass.gdshader") as Shader
	var dome := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = r
	sphere.height = r * 2.0
	sphere.radial_segments = 32
	sphere.rings = 16
	dome.mesh = sphere
	dome.material_override = glass
	dome.position = centre
	dome.name = "Dome"
	base_node.add_child(dome)
	# inside: a snowy mound, the cottage and two pines (Timberline's own models, tiny)
	var inside := Node3D.new()
	inside.name = "Inside"
	base_node.add_child(inside)
	var snow_m := StandardMaterial3D.new()
	snow_m.albedo_color = Color(0.95, 0.97, 1.0)
	snow_m.roughness = 0.9
	var mound := MeshInstance3D.new()
	var cyl := CylinderMesh.new()
	cyl.top_radius = r * 0.74
	cyl.bottom_radius = r * 0.84
	cyl.height = r * 0.16
	mound.mesh = cyl
	mound.material_override = snow_m
	mound.position = base_top + Vector3(0, r * 0.08, 0)
	inside.add_child(mound)
	var floor_y := base_top.y + r * 0.16
	Shop._prop(inside, "outside/HOUSE_cottage", base_top + Vector3(-r * 0.1, r * 0.14, r * 0.08), r * 0.6, 0.5)
	Shop._prop(inside, "outside/TREE_meshy_pine", base_top + Vector3(r * 0.42, r * 0.14, -r * 0.22), r * 0.95, 0.3)
	Shop._prop(inside, "outside/TREE_meshy_pine", base_top + Vector3(-r * 0.46, r * 0.14, -r * 0.3), r * 0.7, 2.0)
	for mi in inside.find_children("*", "MeshInstance3D", true, false):
		mi.set_meta("clue", true)                                ## the loupe meets the glass, not what is inside it
	mound.set_meta("clue", true)
	# the snow itself
	var flakes := Flakes.new()
	flakes.position = centre
	flakes.setup(r * 0.9, floor_y - centre.y, FLAKES)
	base_node.add_child(flakes)

## A copy of `mesh` keeping only the triangles that lie wholly at or below `cut_y` (its own space).
static func _below(mesh: Mesh, cut_y: float) -> ArrayMesh:
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arrays := mesh.surface_get_arrays(si)
		var verts: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var idx = arrays[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		var n: int = (idx as PackedInt32Array).size() if idx != null else verts.size()
		for t in range(0, n, 3):
			var a: int = idx[t] if idx != null else t
			var b: int = idx[t + 1] if idx != null else t + 1
			var c: int = idx[t + 2] if idx != null else t + 2
			if verts[a].y <= cut_y and verts[b].y <= cut_y and verts[c].y <= cut_y:
				keep.append(a)
				keep.append(b)
				keep.append(c)
		arrays[Mesh.ARRAY_INDEX] = keep
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
		out.surface_set_material(si, mesh.surface_get_material(si))
	return out

## The snowflakes: a MultiMesh moved by a tiny simulation in the globe's own frame. Gravity is turned into that frame every frame, so when the
## globe tips the snow falls toward the new "down"; any turn or shake stirs the flakes up in proportion to how fast it turned.
class Flakes extends MultiMeshInstance3D:
	var radius := 0.08
	var floor_y := -0.05
	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
	var last := Basis.IDENTITY
	var rng := RandomNumberGenerator.new()

	func setup(r: float, floor_local: float, n: int) -> void:
		radius = r
		floor_y = floor_local
		rng.seed = 7
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		var q := SphereMesh.new()                            ## small round flakes, a little see-through: snow, not confetti
		q.radius = r * 0.014
		q.height = r * 0.028
		q.radial_segments = 6
		q.rings = 3
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.albedo_color = Color(1, 1, 1, 0.85)
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		q.material = m
		mm.mesh = q
		mm.instance_count = n
		multimesh = mm
		cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		pos.resize(n)
		vel.resize(n)
		for i in n:                                          ## start stirred up, so a globe put on the mat is snowing
			var p := Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.2, 1), rng.randf_range(-1, 1)).normalized() * radius * rng.randf_range(0.2, 0.95)
			p.y = maxf(p.y, floor_y + radius * 0.05)
			pos[i] = p
			vel[i] = Vector3.ZERO
			mm.set_instance_transform(i, Transform3D(Basis.IDENTITY, p))

	func _ready() -> void:
		last = global_transform.basis.orthonormalized()

	func _process(delta: float) -> void:
		delta = minf(delta, 0.05)
		var b := global_transform.basis.orthonormalized()
		var down := (b.inverse() * Vector3.DOWN).normalized()   ## world "down" in the globe's frame
		var turned := (b * last.inverse()).get_rotation_quaternion().get_angle()
		last = b
		var stir := clampf(turned / maxf(delta, 0.001), 0.0, 14.0)       ## how fast it is being turned, rad/s
		var drag := exp(-1.6 * delta)                         ## water: the swirl dies away over a few seconds
		for i in pos.size():
			var v: Vector3 = vel[i]
			var p: Vector3 = pos[i]
			if stir > 0.3:                                    ## a turn sends the snow up and round: lift, a spin about the axis, some scatter
				var spin := Vector3(-p.z, 0.0, p.x).normalized() if Vector2(p.x, p.z).length() > 0.001 else Vector3.ZERO
				v += (Vector3(0, 0.45, 0) + spin * 1.0 + Vector3(rng.randf_range(-1, 1), rng.randf_range(-0.6, 1), rng.randf_range(-1, 1)) * 1.3) * stir * radius * 0.45 * delta
			v += down * radius * 0.16 * delta                 ## sinking slowly through the water
			v *= drag
			p += v * delta
			if p.length() > radius:                            ## the glass
				p = p.normalized() * radius
				v -= p.normalized() * maxf(v.dot(p.normalized()), 0.0)
			if p.y < floor_y:                                  ## the snowy mound
				p.y = floor_y
				v.y = maxf(v.y, 0.0)
				v *= 0.5
			pos[i] = p
			vel[i] = v
			multimesh.set_instance_transform(i, Transform3D(Basis(Vector3.UP, float(i)), p))
