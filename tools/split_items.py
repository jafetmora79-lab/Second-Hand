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
SPY_LUG = Vector((-0.13, -0.425, 0.0))       ## where the cap's chain is fixed to the tube
SPY_CAP = "((x + 0.2) ** 2 + (y + 0.26) ** 2) ** 0.5 < 0.097 and z < -0.075"
SPEC = {
    "music_box": {"unstack": True, "unstack_gap": 0.016, "unstack_sink": 0.012, "keep": "dark", "unstack_where": "(abs(x) > 0.41 or y < -0.41 or z < -0.38 or y > 0.38) and z < -0.03", "parts": [   ## the inlaid outer panels only; its inlays are the darker layer
        {"name": "Lid", "pick": "z > -0.02 and y > 0.15", "type": "hinge", "axis": "X", "normal": Vector((0, 0, 1))},
    ]},
    "compass": {"parts": [
        {"name": "Lid", "pick": "y > 0.3 and z > -0.2", "type": "hinge", "axis": "X", "normal": Vector((0, 0, 1)), "plate": True, "seat": False},
    ]},
    "pocket_watch": {"parts": [
        {"name": "Cover", "pick": "not %s and x < -0.05 and (y < 0.1 or x < -0.3)" % WATCH_BODY, "type": "hinge", "axis": "Z", "normal": Vector((0, 1, 0))},
        {"name": "Chain", "pick": "not %s and x >= -0.05 and (x > 0.2 or z > 0.15)" % WATCH_BODY, "type": "chain"},
    ]},
    # Meshy gave the spyglass two caps hanging off the tube; one goes, the other is a real cap that fits over the objective lens
    # The left cap is a cup lying open side up at (-0.2, -0.26); its little chain hangs from it and goes with it onto the lens.
    "spyglass": {"delete": "x > 0.115 and -0.44 < y < -0.12", "parts": [
        {"name": "Cap", "pick": SPY_CAP, "opening": Vector((0, 0, 1)), "type": "place", "lug": SPY_LUG},
        {"name": "CapChain", "pick": "x < -0.135 and y < -0.15", "type": "chain", "parent": "Cap", "near": Vector((-0.2, -0.26, -0.1)), "anchor": SPY_LUG},
    ]},
    # the drawer starts shut (pushed flush into the box) and pulls out as modelled
    "coffee_grinder": {"parts": [
        {"name": "Drawer", "pick": "y < -0.26 and z < -0.12", "type": "slide", "start": 1.0},
    ]},
    # the lid lifts off and tips back
    "kettle": {"parts": [
        {"name": "Lid", "pick": "0.054 < z < 0.27 and abs(x - 0.08) < 0.2 and abs(y) < 0.27", "type": "lift"},
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


def unstack(obj, keep="bright", where="True", gap=0.004, sink=0.0):
    """Faces lying on top of other faces (Meshy's inlays and panels: the same plane within a hair, one inside the other) flicker
    against each other in the game. Of each such pair, delete the darker one (the plain panel behind the inlay)."""
    from mathutils import kdtree
    from mathutils.geometry import intersect_point_tri
    me = obj.data
    img = None
    for m in me.materials:
        if m and m.use_nodes:
            for n in m.node_tree.nodes:
                if n.type == "TEX_IMAGE" and n.image:
                    img = n.image
    px = img.pixels[:] if img else None
    W, H = (img.size if img else (1, 1))
    uv = me.uv_layers.active.data

    def bright(p):
        if px is None:
            return 0.0
        u = sum(uv[i].uv.x for i in p.loop_indices) / p.loop_total
        v = sum(uv[i].uv.y for i in p.loop_indices) / p.loop_total
        i = (int(v % 1 * H) * W + int(u % 1 * W)) * 4
        return px[i] + px[i + 1] + px[i + 2]

    polys = list(me.polygons)
    kd = kdtree.KDTree(len(polys))
    for p in polys:
        kd.insert(p.center, p.index)
    kd.balance()
    gone = set()
    for p in polys:
        if p.index in gone or len(p.vertices) != 3:
            continue
        x, y, z = p.center
        if not eval(where):                                      ## only where the flicker is (a model's outer panels, say)
            continue
        a, b, c = (me.vertices[i].co for i in p.vertices)
        reach = max((a - p.center).length, (b - p.center).length, (c - p.center).length)
        for (co, j, dist) in kd.find_range(p.center, reach):
            if j == p.index or j in gone:
                continue
            q = polys[j]
            if q.normal.dot(p.normal) < 0.98 or abs((q.center - p.center).dot(p.normal)) > gap:      ## facing the same way: back-to-back faces never flicker
                continue
            if intersect_point_tri(q.center - p.normal * (q.center - p.center).dot(p.normal), a, b, c) is None:
                continue                                         ## side by side in one plane, not on top of each other
            darker = bright(q) <= bright(p)
            gone.add(j if darker == (keep == "bright") else p.index)      ## which layer is the real surface depends on the model
            if p.index in gone:
                break
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    faces = [bm.faces[i] for i in gone]
    if sink > 0.0:
        # push the under-layer back behind the one meant to show, instead of deleting it: where the top layer doesn't cover it, it
        # still shows (a hair deeper), so nothing opens up; where it does, the top layer always wins
        res = bmesh.ops.split(bm, geom=faces)
        for f in [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]:
            n = f.normal.copy()
            for v in f.verts:
                v.co -= n * sink
    else:
        bmesh.ops.delete(bm, geom=faces, context="FACES")
    bm.to_mesh(me)
    bm.free()
    return len(gone)


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


def pca(vs):
    import numpy as np
    a = np.array([[v.x, v.y, v.z] for v in vs])
    c = a.mean(axis=0)
    _, _, vt = np.linalg.svd(a - c, full_matrices=False)
    return Vector(c), [Vector(r) for r in vt]


def move(kind, ps, part, body):
    """A part that moves without a hinge, as the game's hinge blend (turn about `axis` by `closed`, shift by `offset`, scale by `scale`,
    about the part's own centre), from its modelled place (0) to its other place (1)."""
    vs = verts(part)
    bv = verts(body)
    lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
    hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
    pivot = (lo + hi) / 2
    axis, ang, offset, scale, arc = Vector((1, 0, 0)), 0.0, Vector(), 1.0, 0.0
    if ps["type"] == "place":
        # the cap: its opening, the way its faces don't point (a cup's faces point out of its closed end and sides)
        mw = part.matrix_world
        disc = []
        for p in part.data.polygons:
            x, y, z = mw @ p.center
            if eval(ps.get("measure", "True")):
                disc += [mw @ part.data.vertices[i].co for i in p.vertices]
        cen, ax = pca(disc)
        opening = ps["opening"]                                 ## the cap's axis, pointing out of its open side
        vs = disc
        rad = sorted(((v - cen) - opening * (v - cen).dot(opening)).length for v in vs)
        cap_r = rad[int(len(rad) * 0.9)]                       ## (past the rim: the loop its chain hangs from)
        depth = max(v.dot(opening) for v in vs) - min(v.dot(opening) for v in vs)
        # the objective: the tube's end, lowest y; its ring's centre and outer radius
        ymin = min(v.y for v in bv)
        ring = [v for v in bv if v.y < ymin + 0.035]
        rc = Vector((sum(v.x for v in ring) / len(ring), 0, sum(v.z for v in ring) / len(ring)))
        rr = sorted(((v.x - rc.x) ** 2 + (v.z - rc.z) ** 2) ** 0.5 for v in ring)
        lens_r = rr[int(len(rr) * 0.97)]
        scale = (lens_r + 0.012) / cap_r                        ## its rim just over the lens ring
        # Meshy made it a cup with a one-sided floor (seen only from inside): give the floor an outside, so the cap on the lens is solid
        bm = bmesh.new()
        bm.from_mesh(part.data)
        inv = part.matrix_world.inverted().to_3x3()
        def in_disc(f):
            x, y, z = mw @ f.calc_center_median()
            return eval(ps.get("measure", "True"))
        floor = [f for f in bm.faces if in_disc(f) and (mw.to_3x3() @ f.normal).normalized().dot(opening) > 0.6]
        res = bmesh.ops.duplicate(bm, geom=floor)
        new = [g for g in res["geom"] if isinstance(g, bmesh.types.BMFace)]
        bmesh.ops.reverse_faces(bm, faces=new)
        moved = {v for f in new for v in f.verts}
        for v in moved:
            v.co -= inv @ (opening * 0.003)
        bm.to_mesh(part.data)
        bm.free()
        print(kind, "cap floor given an outside:", len(new), "faces")
        q = opening.rotation_difference(Vector((0, 1, 0)))        ## the open side toward the tube
        if ps.get("lug"):
            # turned about the tube's axis so the point its chain hangs from faces the chain's lug: the chain runs straight back to it
            lug = ps["lug"]
            att = min(vs, key=lambda v: (v - lug).length)
            a = q.to_matrix() @ (att - cen)
            want = math.atan2(lug.z - rc.z, lug.x - rc.x)
            have = math.atan2(a.z, a.x)
            from mathutils import Quaternion
            q = Quaternion(Vector((0, 1, 0)), -(want - have)) @ q
        axis, ang = q.axis, q.angle
        # where its centre goes: its closed end just past the lens, the rim reaching back over the tube
        R = q.to_matrix()
        fin0 = [R @ ((v - cen) * scale) + cen for v in disc]
        mid = Vector(((min(v.x for v in fin0) + max(v.x for v in fin0)) / 2, min(v.y for v in fin0), (min(v.z for v in fin0) + max(v.z for v in fin0)) / 2))
        pivot = cen
        offset = Vector((rc.x, ymin - 0.012, rc.z)) - mid
        arc = 0.06
        # check: where the cap ends up (its floor's outside against the lens's tip)
        R = q.to_matrix()
        fin = [R @ ((v - cen) * scale) + cen + offset for v in disc]
        print(kind, "cap on lens: y %.4f..%.4f  (lens tip %.4f)  x %.4f..%.4f z %.4f..%.4f" % (min(v.y for v in fin), max(v.y for v in fin), ymin,
              min(v.x for v in fin), max(v.x for v in fin), min(v.z for v in fin), max(v.z for v in fin)))
        print(kind, "cap r %.4f depth %.4f lens r %.4f scale %.3f opening %s" % (cap_r, depth, lens_r, scale, tuple(round(c, 3) for c in opening)))
    elif ps["type"] == "slide":
        # the drawer's front pushed back level with the box's front around it
        # its front board (not the knob) pushed back level with the front of the frame around the drawer's opening
        frame = [v for v in bv if lo.z - 0.03 < v.z < hi.z + 0.03 and lo.x - 0.03 < v.x < hi.x + 0.03]
        fy = min(v.y for v in frame)
        plate = sorted(v.y for v in vs)[int(len(vs) * 0.15)]
        offset = Vector((0, fy - plate, 0))
        print(kind, "drawer: frame front %.4f, board %.4f, knob %.4f, push %.4f" % (fy, plate, lo.y, fy - plate))
    else:                                                       ## lift: up and tipped back
        offset = Vector((0, 0, 0.09))
        axis, ang = Vector((1, 0, 0)), -0.35
        arc = 0.0
    m = {"type": "hinge", "pivot": to_godot(pivot), "axis": to_godot(axis.normalized()), "closed": round(ang, 4), "offset": to_godot(offset),
         "scale": round(scale, 4), "arc": arc, "start": ps.get("start", 0.0)}
    return pivot, m


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
    if spec.get("unstack", False):                               ## only where flicker was seen: elsewhere the layers are the model's shape
        print(kind, "stacked faces removed:", unstack(body, spec.get("keep", "bright"), spec.get("unstack_where", "True"), spec.get("unstack_gap", 0.004), spec.get("unstack_sink", 0.0)))
    if spec.get("delete"):                                       ## a duplicate Meshy made: cut out and thrown away
        junk = separate(body, spec["delete"])
        print(kind, "deleted faces:", len(junk.data.polygons))
        bpy.data.objects.remove(junk, do_unlink=True)
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
            # where the part must end up shut: a top lid centred on the body's rim and resting on it; the watch's cover centred on the
            # case's front. The swing alone gets close; this small shift makes it seat exactly (the game blends it in as it closes).
            r = Matrix.Rotation(ang, 3, axis)
            shut = [r @ (v - pivot) + pivot for v in vs]
            sc = sum(shut, Vector()) / len(shut)
            n = ps["normal"]
            if ps["axis"] == "X":
                zs = sorted(v.z for v in bv)
                top = zs[int(len(zs) * 0.97)]                          ## the rim: where the walls end, not a stray hinge or key above it
                rim = [v for v in bv if abs(v.z - top) < 0.02]
                xs = sorted(v.x for v in rim)
                ys = sorted(v.y for v in rim)
                rc = Vector(((xs[int(len(xs) * 0.05)] + xs[int(len(xs) * 0.95)]) / 2, (ys[int(len(ys) * 0.05)] + ys[int(len(ys) * 0.95)]) / 2, 0))
                lid_lo = sorted(v.z for v in shut)[int(len(shut) * 0.03)]
                target = Vector((rc.x, rc.y, sc.z + (top - lid_lo) - 0.004))
            else:
                face = [v for v in bv if ((v.x + 0.05) ** 2 + (v.z + 0.05) ** 2) ** 0.5 < 0.3]
                fy = min(v.y for v in face)
                fc = sum((v for v in face if v.y < fy + 0.03), Vector()) / max(1, len([v for v in face if v.y < fy + 0.03]))
                target = Vector((fc.x, fy - (max(v.y for v in shut) - sc.y), fc.z))
            offset = (target - sc) if ps.get("seat", True) else Vector()     ## (the compass's swing seats it already: its "rim" is its hinge)
            out[ps["name"]] = {"type": "hinge", "pivot": to_godot(pivot), "axis": to_godot(axis), "closed": round(ang, 4), "offset": to_godot(offset)}
        elif ps["type"] in ("place", "slide", "lift"):
            pivot, mv = move(kind, ps, part, body)
            out[ps["name"]] = mv
        else:                                                   ## a chain: hangs from its top link
            if ps.get("near"):                                  ## hangs from the end nearest the part it belongs to
                dn = min((v - ps["near"]).length for v in vs)
                top = [v for v in vs if (v - ps["near"]).length < dn + 0.015]
            else:
                hi = max(v.z for v in vs)
                top = [v for v in vs if v.z > hi - 0.015]
            pivot = sum(top, Vector()) / len(top)
            cen = sum(vs, Vector()) / len(vs)
            out[ps["name"]] = {"type": "chain", "pivot": to_godot(pivot), "hang": to_godot((cen - pivot).normalized())}
            if ps.get("parent"):
                out[ps["name"]]["parent"] = ps["parent"]
            if ps.get("anchor"):                                 ## with its cap on the lens, it runs back to here on the tube
                out[ps["name"]]["anchor"] = to_godot(ps["anchor"])
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


import sys
_only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for k in SPEC:
    if not _only or k in _only:
        run(k)
