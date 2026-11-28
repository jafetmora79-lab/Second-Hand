"""Splits Meshy item models into moving parts for the "living objects": the music box's and compass's lids, the pocket watch's cover and
chain. Meshy exports one mesh of disconnected triangle islands, so each part is cut out by a region (tuned by rendering the picks).

Also: deletes exactly duplicated faces (Meshy sometimes stacks two copies of a surface, which flicker against each other in the game),
and closes the hole in the back of the compass lid with a brass plate textured from the lid's own brass.

Writes assets/items/<kind>_parts.glb (Body plus the parts, each part's origin on its hinge) and <kind>_parts.json with, per part,
the pivot and hinge axis in Godot's axes and the angle that closes it. The originals stay as they are.
Run:  blender -b -P tools/split_items.py
"""
import bpy, bmesh, json, math, os
from mathutils import Vector, Matrix

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ITEMS = os.path.join(ROOT, "assets", "items")

WATCH_BODY = "(y > 0.1 and ((((x+0.05)**2+(z+0.05)**2)**0.5 < 0.335 and x < 0.265) or (abs(x+0.03) < 0.15 and z > 0.2)))"
# per kind: parts in Blender coordinates (Z up). A hinge closes about `axis` until the part lies flat across `normal` at `cap`.
SPEC = {
    "music_box": {"parts": [
        {"name": "Lid", "pick": "z > -0.02 and y > 0.15", "type": "hinge", "axis": "X", "normal": Vector((0, 0, 1))},
    ]},
    "compass": {"parts": [
        {"name": "Lid", "pick": "y > 0.3 and z > -0.2", "type": "hinge", "axis": "X", "normal": Vector((0, 0, 1)), "plate": True},
    ]},
    "pocket_watch": {"parts": [
        {"name": "Cover", "pick": "not %s and x < -0.05 and (y < 0.1 or x < -0.3)" % WATCH_BODY, "type": "hinge", "axis": "Z", "normal": Vector((0, 1, 0))},
        {"name": "Chain", "pick": "not %s and x >= -0.05 and (x > 0.2 or z > 0.15)" % WATCH_BODY, "type": "chain"},
    ]},
}


def to_godot(v):
    return [round(v.x, 5), round(v.z, 5), round(-v.y, 5)]


def dedupe(obj):
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    seen, dup = set(), []
    for f in bm.faces:
        key = tuple(sorted(tuple(round(c, 5) for c in v.co) for v in f.verts))
        if key in seen:
            dup.append(f)
        else:
            seen.add(key)
    bmesh.ops.delete(bm, geom=dup, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    return len(dup)


def separate(obj, pick):
    bpy.context.view_layer.objects.active = obj
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.select_mode(type="FACE")
    bpy.ops.mesh.select_all(action="DESELECT")             ## nothing left selected from the import: only the picked faces move
    bpy.ops.object.mode_set(mode="OBJECT")
    me = obj.data
    for v in me.vertices:
        v.select = False
    for e in me.edges:
        e.select = False
    for p in me.polygons:
        x, y, z = p.center
        p.select = bool(eval(pick))
        if p.select:
            for vi in p.vertices:
                me.vertices[vi].select = True
    before = set(bpy.data.objects)
    bpy.ops.object.mode_set(mode="EDIT")
    bpy.ops.mesh.separate(type="SELECTED")
    bpy.ops.object.mode_set(mode="OBJECT")
    new = [o for o in bpy.data.objects if o not in before]
    return new[0]


def verts(o):
    return [o.matrix_world @ v.co for v in o.data.vertices]


def closing_angle(part, pivot, axis, normal, cap):
    """The rotation about the hinge that lays the part flat across `normal` with its middle nearest `cap`."""
    vs = verts(part)
    best, best_a = 1e9, 0.0
    for deg in range(-180, 181):
        r = Matrix.Rotation(math.radians(deg), 3, axis)
        pts = [r @ (v - pivot) + pivot for v in vs]
        d = [p.dot(normal) for p in pts]
        flat = max(d) - min(d)
        cen = sum(pts, Vector()) / len(pts)
        off = (cen - cap) - normal * (cen - cap).dot(normal)
        score = flat * 3.0 + off.length + abs((cen - cap).dot(normal)) * 0.5
        if score < best:
            best, best_a = score, math.radians(deg)
    return best_a


def plate(part, body_center, mesh_uv_obj):
    """A brass plate inside the back of the lid, covering the hole: the lid's outline, a little smaller, just under its outer face."""
    vs = verts(part)
    cen = sum(vs, Vector()) / len(vs)
    # the lid's plane: the axis it is thinnest along
    import numpy as np
    a = np.array([[v.x, v.y, v.z] for v in vs]) - np.array(cen)
    _, _, vt = np.linalg.svd(a, full_matrices=False)
    n = Vector(vt[2])
    if n.dot(cen - body_center) < 0:
        n = -n                                                  ## pointing out, away from the compass
    u = Vector(vt[0]); w = Vector(vt[1])
    outer = max(v.dot(n) for v in vs)
    pts2 = sorted({(round((v - cen).dot(u), 4), round((v - cen).dot(w), 4)) for v in vs})
    # convex hull of the outline (monotone chain)
    def cross(o, a, b):
        return (a[0] - o[0]) * (b[1] - o[1]) - (a[1] - o[1]) * (b[0] - o[0])
    lower, upper = [], []
    for p in pts2:
        while len(lower) >= 2 and cross(lower[-2], lower[-1], p) <= 0:
            lower.pop()
        lower.append(p)
    for p in reversed(pts2):
        while len(upper) >= 2 and cross(upper[-2], upper[-1], p) <= 0:
            upper.pop()
        upper.append(p)
    hull = lower[:-1] + upper[:-1]
    depth = outer - 0.006 - cen.dot(n)
    ring = [cen + u * (p[0] * 0.9) + w * (p[1] * 0.9) + n * depth for p in hull]
    # the brass of the lid's outer face, for the plate's texture
    me = part.data
    uvl = me.uv_layers.active.data
    far = max(me.polygons, key=lambda p: (part.matrix_world @ p.center).dot(n))
    uv0 = sum((uvl[i].uv for i in far.loop_indices), Vector((0, 0))) / far.loop_total
    bm = bmesh.new()
    bm.from_mesh(me)
    uvlay = bm.loops.layers.uv.active
    inv = part.matrix_world.inverted()
    bv = [bm.verts.new(inv @ p) for p in ring]
    c = bm.verts.new(inv @ (cen + n * depth))
    for i in range(len(bv)):
        f = bm.faces.new((c, bv[i], bv[(i + 1) % len(bv)]))
        if f.normal.dot(inv.to_3x3() @ n) < 0:
            f.normal_flip()
        f.material_index = 0
        for loop in f.loops:
            q = part.matrix_world @ loop.vert.co
            loop[uvlay].uv = uv0 + Vector(((q - cen).dot(u), (q - cen).dot(w))) * 0.04
    bm.to_mesh(me)
    bm.free()
    return len(ring)


def run(kind):
    spec = SPEC[kind]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(ITEMS, kind + ".glb"))
    body = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    bpy.ops.object.select_all(action="DESELECT")
    # apply the import's transform so vertex coordinates are the Blender world coordinates the picks were tuned in
    body.select_set(True)
    bpy.context.view_layer.objects.active = body
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    print(kind, "duplicate faces removed:", dedupe(body))
    out = {}
    parts = []
    for ps in spec["parts"]:
        part = separate(body, ps["pick"])
        part.name = ps["name"]
        parts.append((ps, part))
    bv = verts(body)
    bmin = Vector((min(v.x for v in bv), min(v.y for v in bv), min(v.z for v in bv)))
    bmax = Vector((max(v.x for v in bv), max(v.y for v in bv), max(v.z for v in bv)))
    bcen = (bmin + bmax) / 2
    for ps, part in parts:
        vs = verts(part)
        if ps["type"] == "hinge":
            import numpy as np
            from mathutils import kdtree
            kd = kdtree.KDTree(len(bv))
            for i, v in enumerate(bv):
                kd.insert(v, i)
            kd.balance()
            dist = [kd.find(v)[2] for v in vs]
            dmin = min(dist)
            edge = [v for v, d in zip(vs, dist) if d < dmin + 0.012]
            pivot = sum(edge, Vector()) / len(edge)             ## where the part meets the body: the hinge
            a0 = np.array([[v.x, v.y, v.z] for v in vs])
            a0 = a0 - a0.mean(axis=0)
            pn = Vector(np.linalg.svd(a0, full_matrices=False)[2][2])
            axis = pn.cross(ps["normal"]).normalized()           ## the line that turns the part's face onto the closed face
            if ps["axis"] == "X":
                cap = Vector((bcen.x, bcen.y, bmax.z))
            else:
                cap = Vector((-0.05, bmin.y, -0.05))
            ang = closing_angle(part, pivot, axis, ps["normal"], cap)
            if ps.get("plate"):
                print(kind, "lid plate sides:", plate(part, bcen, body))
            out[ps["name"]] = {"type": "hinge", "pivot": to_godot(pivot), "axis": to_godot(axis), "closed": round(ang, 4)}
        else:                                                   ## a chain: hangs from its top link
            hi = max(v.z for v in vs)
            top = [v for v in vs if v.z > hi - 0.015]
            pivot = sum(top, Vector()) / len(top)
            cen = sum(vs, Vector()) / len(vs)
            out[ps["name"]] = {"type": "chain", "pivot": to_godot(pivot), "hang": to_godot((cen - pivot).normalized())}
        # the part's origin on its pivot, so turning the node turns the part about the hinge
        bpy.context.scene.cursor.location = pivot
        bpy.ops.object.select_all(action="DESELECT")
        part.select_set(True)
        bpy.context.view_layer.objects.active = part
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        print(kind, ps["name"], out[ps["name"]], "faces", len(part.data.polygons))
    body.name = "Body"
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(ITEMS, kind + "_parts.glb"), export_format="GLB", use_selection=True)
    with open(os.path.join(ITEMS, kind + "_parts.json"), "w") as f:
        json.dump(out, f, indent=1)


for k in SPEC:
    run(k)
