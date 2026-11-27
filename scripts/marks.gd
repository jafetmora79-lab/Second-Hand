extends RefCounted
class_name Marks
## Maker's marks, stickers and stamps as textures that follow the object's real surface.
## A mark is a small grid mesh: each of its vertices is projected along the clue's side onto the Meshy model's own triangles, so the mark
## curves with a lantern tank, a jug's belly or a watch back, sits a hair above the surface (no z-fighting, no gap), turns with the object
## and never floats. The textures (assets/textures/antiques/<kind>/) come from the antique-mark atlases via tools/extract_marks.py.
## Compatibility renderer: no Decal nodes, just a mesh with an alpha-blended, nearest-filtered texture lit like the object.

const LIFT := 0.0007           ## how far above the surface the mark sits (metres, object space)
const DIR := "res://assets/textures/antiques/%s.png"

static var _mats := {}         ## one material per texture

## Lays the texture `tex` (a path under assets/textures/antiques, no extension) on the surface at `pos`, facing out along `n`,
## `width` metres across. fit "lens": a lens ring, sized to the lens it sits on (measured from the geometry). Returns the mesh.
static func patch(root: Node3D, tris: PackedVector3Array, pos: Vector3, n: Vector3, tex: String, width: float, fit: String = "") -> MeshInstance3D:
	var path := DIR % tex
	if not ResourceLoader.exists(path):
		push_warning("mark texture missing: " + path)
		return null
	var t := load(path) as Texture2D
	var aspect := float(t.get_height()) / float(t.get_width())
	var fr := Models._frame(n)
	if fit == "lens":
		width = _lens_width(tris, pos, n, fr)
	var w := width
	var h := width * aspect
	var near := _near(tris, pos, maxf(w, h) * 0.8 + 0.01)
	var nx := 14
	var ny := clampi(roundi(nx * aspect), 3, 14)
	var verts := PackedVector3Array()
	var uvs := PackedVector2Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()                          ## alpha 0 where the mark runs off the object: it fades instead of floating
	for j in ny + 1:
		for i in nx + 1:
			var u := float(i) / nx
			var v := float(j) / ny
			var on_plane := pos + fr.x * (u - 0.5) * w + fr.y * (0.5 - v) * h
			var hit := Models._ray(near, on_plane + n * 0.04, -n)
			var on := hit != Vector3.INF and hit.distance_to(on_plane) <= maxf(w, h) * 0.35
			if not on:
				hit = on_plane                               ## past the edge of the object: stay in the mark's plane, invisible
			verts.append(hit + n * LIFT)
			cols.append(Color(1, 1, 1, 1.0 if on else 0.0))
			uvs.append(Vector2(u, v))
			norms.append(n)
	var idx := PackedInt32Array()
	for j in ny:
		for i in nx:
			var a := j * (nx + 1) + i
			var b := a + 1
			var c := a + nx + 1
			var d := c + 1
			idx.append_array([a, c, b, b, c, d] if _faces_out(verts[a], verts[c], verts[b], n) else [a, b, c, b, d, c])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = idx
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = _mat(path, t)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.set_meta("clue", true)                               ## not part of the loupe's collider: the loupe meets the object under it
	mi.name = "Mark"
	root.add_child(mi)
	return mi

## Godot's front faces wind clockwise seen from the front: pick the order that faces out along n.
static func _faces_out(a: Vector3, b: Vector3, c: Vector3, n: Vector3) -> bool:
	return (b - a).cross(c - a).dot(n) < 0.0

static func _mat(path: String, t: Texture2D) -> StandardMaterial3D:
	if _mats.has(path):
		return _mats[path]
	var m := StandardMaterial3D.new()
	m.albedo_texture = t
	m.vertex_color_use_as_albedo = true                     ## white everywhere; its alpha fades the parts off the object's edge
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST      ## crisp low-res pixels, like the Meshy textures under it
	m.roughness = 0.8
	m.render_priority = 1
	_mats[path] = m
	return m

## The triangles with a corner within `r` of `p`: rays for one mark only need to test these.
static func _near(tris: PackedVector3Array, p: Vector3, r: float) -> PackedVector3Array:
	var out := PackedVector3Array()
	var r2 := r * r
	for i in range(0, tris.size(), 3):
		if tris[i].distance_squared_to(p) < r2 or tris[i + 1].distance_squared_to(p) < r2 or tris[i + 2].distance_squared_to(p) < r2:
			out.append(tris[i])
			out.append(tris[i + 1])
			out.append(tris[i + 2])
	return out

## A lens ring's width: walk out from the lens centre until the surface drops away behind the lens front (its rim), all round.
static func _lens_width(tris: PackedVector3Array, pos: Vector3, n: Vector3, fr: Basis) -> float:
	var near := _near(tris, pos, 0.08)
	var front := pos.dot(n)
	var edge := 0.0
	var k := 0
	for a in 8:
		var dir := fr.x * cos(TAU * a / 8.0) + fr.y * sin(TAU * a / 8.0)
		var r := 0.004
		while r < 0.07:
			var hit := Models._ray(near, pos + dir * r + n * 0.04, -n)
			if hit == Vector3.INF or front - hit.dot(n) > 0.006:
				break
			r += 0.002
		edge += r
		k += 1
	return clampf(edge / float(k) * 2.0, 0.02, 0.12)
