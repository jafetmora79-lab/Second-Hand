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
    # the new music box (batch 7): its lid made the box's own size so it shuts flush; Meshy's double handle on the side replaced by one
    # brass winding key; the brass cylinder turns while it plays. Also gone: the big brass roller Meshy stood on the lid's back edge, and
    # a few stray white shards (huge thin triangles) inside the lid and the box
    "music_box": {"drop_sheets": True, "double_sided": True, "raise_front": True, "delete_island": "(x > 0.36 and sx < 0.4) or (z > 0.05 and y > 0.18 and sx < 0.6) or (n <= 3 and max(sx, sy, sz) > 0.15)", "add_key": {"at": Vector((0.393, -0.06, -0.29)), "uv_from": "x > 0.36"},
                  "parts": [
        {"name": "Lid", "pick": "z > -0.03", "type": "hinge", "axis": "X", "normal": Vector((0, 0, 1)), "fit": True},
        {"name": "Key", "pick": "False", "island": "IS_KEY", "type": "spin", "role": "key", "spin_axis": Vector((1, 0, 0))},
        {"name": "Drum", "pick": "False", "island": "abs(y + 0.02) < 0.035 and abs(z + 0.138) < 0.02 and 0.3 < sx < 0.36", "type": "spin", "role": "drum", "spin_axis": Vector((1, 0, 0))},
    ]},
    "compass": {"parts": [
        {"name": "Lid", "pick": "y > 0.3 and z > -0.2", "type": "hinge", "axis": "X", "normal": Vector((0, 0, 1)), "plate": True, "seat": False},
    ]},
    "pocket_watch": {"parts": [
        {"name": "Cover", "pick": "not %s and x < -0.05 and (y < 0.1 or x < -0.3)" % WATCH_BODY, "type": "hinge", "axis": "Z", "normal": Vector((0, 1, 0))},
        {"name": "Chain", "pick": "not %s and x >= -0.05 and (x > 0.2 or z > 0.15)" % WATCH_BODY, "type": "chain"},
    ]},
    # the tin toy car: its wind-up key (Meshy doubled its bow: one copy goes) and four wheels that turn when it runs
    "toy_car": {"dedupe_islands": True, "parts": [
        {"name": "Key", "pick": "False", "island": "abs(x) < 0.07 and y < -0.19 and -0.13 < z < 0.05 and sx < 0.1", "type": "spin", "role": "key", "spin_axis": Vector((0, 1, 0))},
    ] + [
        {"name": "Wheel%d" % i, "pick": "False", "island": "abs(x - %f) < 0.13 and abs(y - %f) < 0.07 and abs(z + 0.143) < 0.04 and sx < 0.28 and sz < 0.27" % w, "type": "spin", "role": "wheel", "spin_axis": Vector((0, 1, 0))}
        for i, w in enumerate([(-0.31, 0.26), (-0.32, -0.09), (0.235, -0.255), (0.30, 0.18)])
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


def islands(obj):
    """The mesh's separate pieces (Meshy's smart topology makes each part its own island): per face index, its island's bounding-box
    centre, size, face count and first face."""
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    seen, info = set(), {}
    for f in bm.faces:
        if f.index in seen:
            continue
        stack, comp = [f], []
        seen.add(f.index)
        while stack:
            g = stack.pop()
            comp.append(g.index)
            for e in g.edges:
                for h in e.link_faces:
                    if h.index not in seen:
                        seen.add(h.index)
                        stack.append(h)
        vs = [obj.matrix_world @ v.co for i in comp for v in bm.faces[i].verts]
        lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
        hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
        for i in comp:
            info[i] = ((lo + hi) / 2, hi - lo, len(comp), comp[0])
    bm.free()
    return info


def island_ok(pred, inf):
    (x, y, z), (sx, sy, sz), n = inf[0], inf[1], inf[2]
    return bool(eval(pred))


def separate(obj, pick, island=None):
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
    isl = islands(obj) if island else None
    for p in me.polygons:
        x, y, z = p.center
        p.select = bool(eval(pick)) or (island is not None and island_ok(island, isl[p.index]))
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


# the axis a winding key turns about, where the bow's middle isn't on it (None: the bow's middle)
KEY_AXIS = {"toy_car": (None, None, -0.036)}


def dedupe_islands(obj):
    """Meshy sometimes makes a small piece twice, one copy almost on the other (the toy car's key bow): delete the copies."""
    isl = islands(obj)
    first = {}
    for i, (c, sz, n, root) in isl.items():
        first.setdefault(root, (c, sz, n))
    keep, gone = [], set()
    for root, (c, sz, n) in first.items():
        for (c2, sz2, n2, r2) in keep:
            if n == n2 and (c - c2).length < 0.006 and (sz - sz2).length < 0.006:
                gone.add(root)
                break
        else:
            keep.append((c, sz, n, root))
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    bm.faces.ensure_lookup_table()
    faces = [bm.faces[i] for i, inf in isl.items() if inf[3] in gone]
    bmesh.ops.delete(bm, geom=faces, context="FACES")
    bm.to_mesh(obj.data)
    bm.free()
    return len(gone)


def drop_sheets(obj):
    """Meshy's stray shards: big flat sheets with no thickness (each face back to back with a reversed twin) floating inside the box.
    (The lid has such faces too, but there they are its surface: its white wedge is in the texture, painted over by clean_texture.)"""
    from mathutils import kdtree
    me = obj.data
    polys = [p for p in me.polygons]
    kd = kdtree.KDTree(len(polys))
    for p in polys:
        kd.insert(p.center, p.index)
    kd.balance()
    gone = set()
    for p in polys:
        if p.area < 0.008 or (obj.matrix_world @ p.center).z > -0.03:     ## (the lid's are part of its surface: only the box's go)
            continue
        for (co, j, d) in kd.find_range(p.center, 0.006):
            q = me.polygons[j]
            if j != p.index and q.normal.dot(p.normal) < -0.95 and abs(q.area - p.area) < 0.2 * p.area:
                gone.update((p.index, j))
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    bmesh.ops.delete(bm, geom=[bm.faces[i] for i in gone], context="FACES")
    bm.to_mesh(me)
    bm.free()
    return len(gone)


def island_uv(obj, pick):
    """The average texture coordinate of the faces `pick` chooses (to paint something new in the same brass)."""
    me = obj.data
    uvl = me.uv_layers.active.data
    acc, n = Vector((0, 0)), 0
    for p in me.polygons:
        x, y, z = p.center
        if eval(pick):
            for i in p.loop_indices:
                acc += uvl[i].uv
                n += 1
    return acc / max(1, n)


def add_key(obj, k):
    """A brass winding key, like the concept's: a collar on the wall, a short shaft, and a flat upright bow with rounded ends."""
    at, uv0 = k["at"], k["uv"]
    bm = bmesh.new()
    bm.from_mesh(obj.data)
    uvl = bm.loops.layers.uv.active
    new = []
    def piece(vs, mat):
        bmesh.ops.transform(bm, matrix=mat, verts=vs)
        return list({f for v in vs for f in v.link_faces})
    lay = Matrix.Rotation(math.radians(90), 4, "Y")                   ## a cone's axis is z: lay it along x
    for (r, d, x0) in [(0.03, 0.014, 0.0), (0.014, 0.055, 0.014)]:    ## the collar on the wall, then the shaft
        res = bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=r, radius2=r, depth=d)
        new += piece(res["verts"], Matrix.Translation(at + Vector((x0 + d / 2, 0, 0))) @ lay)
    res = bmesh.ops.create_cube(bm, size=1.0)                         ## the bow: an upright slab...
    new += piece(res["verts"], Matrix.Translation(at + Vector((0.083, 0, 0))) @ Matrix.Diagonal((0.04, 0.026, 0.1, 1.0)))
    for dz in (-0.05, 0.05):                                          ## ...with a rounded end at the top and the bottom
        res = bmesh.ops.create_cone(bm, cap_ends=True, segments=10, radius1=0.026, radius2=0.026, depth=0.026)
        new += piece(res["verts"], Matrix.Translation(at + Vector((0.083, 0, dz))) @ Matrix.Rotation(math.radians(90), 4, "X"))
    bm.normal_update()
    for f in new:
        f.material_index = 0
        f.smooth = False
        for loop in f.loops:
            q = loop.vert.co - at
            loop[uvl].uv = uv0 + Vector((q.y, q.z)) * 0.02            ## the same brass, a little variation
    bm.to_mesh(obj.data)
    bm.free()
    return len(new)


LID_LIP = 0.008                            ## how far a fitted lid overhangs the box all round, and drops over its walls


def raise_front(obj):
    """Meshy made the box's front wall lower than its ends (its top 9 cm under theirs), so a shut lid leaves a gap over the front. A board
    the wall's own thickness goes on top of it, level with the ends, its face continuing the wall's face (textured from the wall just below
    it). Returns its height."""
    from mathutils.geometry import intersect_point_tri_2d, barycentric_transform
    me = obj.data
    mw = obj.matrix_world
    polys = [(p, mw @ p.center, (mw.to_3x3() @ p.normal).normalized()) for p in me.polygons]
    face = [c.y for p, c, n in polys if n.y < -0.9 and p.area > 0.002 and c.z < -0.1]
    fy = sorted(face)[int(len(face) * 0.05)]                    ## the front's face (its outermost: the hasp and panels sit on it)
    tops = [(c.z, c.y) for p, c, n in polys if n.z > 0.9 and fy - 0.01 < c.y < fy + 0.12 and c.z < -0.08 and abs(c.x) < 0.25]
    ftop = sorted(t[0] for t in tops)[len(tops) // 2]            ## the front wall's top
    back = max(t[1] for t in tops if abs(t[0] - ftop) < 0.01)
    shell = [mw @ v.co for v in me.vertices]
    bx0 = min(w.x for w in shell)
    bx1 = max(w.x for w in shell if w.x < 0.38)
    ends = sorted(w.z for w in shell if (w.x < bx0 + 0.02 or w.x > bx1 - 0.02) and -0.3 < w.z < 0.0)
    etop = ends[int(len(ends) * 0.9)]
    h = etop - ftop
    if h <= 0.004:
        return 0.0
    # the wall's face, as 2D triangles (x, z) with their texture coordinates, to sample just below the board
    uvl = me.uv_layers.active.data
    fronts = []
    for p, c, n in polys:
        if n.y < -0.8 and abs(c.y - fy) < 0.02 and p.loop_total == 3:
            vs = [mw @ me.vertices[vi].co for vi in p.vertices]
            fronts.append(([Vector((v.x, v.z)) for v in vs], [uvl[i].uv.copy() for i in p.loop_indices]))
    def wall_uv(x, z):
        q = Vector((x, z))
        for tri, uvs in fronts:
            if intersect_point_tri_2d(q, *tri):
                return barycentric_transform(q.to_3d(), *[t.to_3d() for t in tri], *[u.to_3d() for u in uvs]).to_2d()
        return None
    bm = bmesh.new()
    bm.from_mesh(me)
    uvlay = bm.loops.layers.uv.active
    inv = mw.inverted()
    lo = Vector((bx0 + 0.01, fy + 0.001, ftop - 0.004))
    hi = Vector((bx1 - 0.01, back, etop))
    res = bmesh.ops.create_cube(bm, size=1.0)
    for v in res["verts"]:
        q = Vector((lo.x + (v.co.x + 0.5) * (hi.x - lo.x), lo.y + (v.co.y + 0.5) * (hi.y - lo.y), lo.z + (v.co.z + 0.5) * (hi.z - lo.z)))
        v.co = inv @ q
    bm.normal_update()
    for f in list({f for v in res["verts"] for f in v.link_faces}):
        f.material_index = 0
        for loop in f.loops:
            q = mw @ loop.vert.co
            zz = ftop - 0.012 - (etop - q.z) * 0.0 if abs(f.normal.z) < 0.5 else ftop - 0.012
            uv = wall_uv(max(bx0 + 0.02, min(bx1 - 0.02, q.x)), ftop - 0.012 - (q.z - ftop) * 0.15)
            loop[uvlay].uv = uv if uv is not None else Vector((0.5, 0.5))
    bm.to_mesh(me)
    bm.free()
    return h


def drop_skirt(part, bv, r, pivot, offset):
    """Meshy's box walls aren't level (its front is lower than its ends): where a shut lid's edge stops short of the wall under it, that
    edge is stretched down to just over the wall's top, so no gap shows between lid and box. (Not at the back, where the hinges are.)"""
    mw = part.matrix_world
    inv = mw.inverted()
    ri = r.inverted()
    S = [r @ (mw @ v.co - pivot) + pivot + offset for v in part.data.vertices]
    bx0, bx1 = min(v.x for v in bv), max(v.x for v in bv if v.x < 0.38)
    by0 = min(v.y for v in bv)
    lx0, lx1, ly0 = min(v.x for v in S), max(v.x for v in S), min(v.y for v in S)
    zlo = min(v.z for v in S)
    moved = 0
    for wall, near_lid in (
            (lambda v: v.y < by0 + 0.02, lambda q: q.y < ly0 + 0.03),
            (lambda v: v.x < bx0 + 0.02, lambda q: q.x < lx0 + 0.03),
            (lambda v: v.x > bx1 - 0.02, lambda q: q.x > lx1 - 0.03)):
        zs = sorted(v.z for v in bv if wall(v) and v.z > zlo - 0.15)
        if not zs:
            continue
        wtop = zs[int(len(zs) * 0.99)]
        for i, q in enumerate(S):
            if near_lid(q) and q.z < zlo + 0.02 and q.z > wtop - LID_LIP:
                S[i] = Vector((q.x, q.y, wtop - LID_LIP))
                moved += 1
    for v, q in zip(part.data.vertices, S):
        v.co = inv @ (ri @ (q - offset - pivot) + pivot)
    return moved


def odd_faces(part, r, pivot):
    """A few of the lid's faces have texture coordinates reaching into some other part's piece of the atlas (the comb's stripes on the
    lid's top): any face whose texture differs strongly from the faces around it gets an evenly scaled patch of its neighbours' wood."""
    import numpy as np, random
    me = part.data
    img = [nd.image for m in me.materials if m and m.use_nodes for nd in m.node_tree.nodes if nd.type == "TEX_IMAGE" and nd.image][0]
    W, H = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)[:, :, :3]
    uvl = me.uv_layers.active.data
    rnd = random.Random(3)
    def mean_col(poly):
        uv = [uvl[i].uv for i in poly.loop_indices]
        acc = np.zeros(3)
        for _ in range(24):
            b = [rnd.random() for _ in uv]
            t = sum(b)
            u = sum(bk * q.x for bk, q in zip(b, uv)) / t
            v = sum(bk * q.y for bk, q in zip(b, uv)) / t
            acc += a[int(v % 1 * H) % H, int(u % 1 * W) % W]
        return acc / 24
    bm = bmesh.new()
    bm.from_mesh(me)
    bm.faces.ensure_lookup_table()
    cols = {p.index: mean_col(p) for p in me.polygons}
    dens = sorted(math.sqrt(abs(((uvl[p.loop_indices[1]].uv - uvl[p.loop_indices[0]].uv).x * (uvl[p.loop_indices[2]].uv - uvl[p.loop_indices[0]].uv).y
                                  - (uvl[p.loop_indices[1]].uv - uvl[p.loop_indices[0]].uv).y * (uvl[p.loop_indices[2]].uv - uvl[p.loop_indices[0]].uv).x) / 2)
                             / max(p.area, 1e-9)) for p in me.polygons if p.area > 1e-4 and p.loop_total == 3)
    k = dens[len(dens) // 2]
    fixed = 0
    allc = np.median(np.array(list(cols.values())), axis=0)
    for f in bm.faces:
        nb = {g.index for e in f.edges for g in e.link_faces if g.index != f.index}
        if len(nb) < 2:
            continue
        ncol = np.median(np.array([cols[i] for i in nb]), axis=0)
        c = cols[f.index]
        stripes = np.abs(c - ncol).sum()
        sat_f = (c.max() - c.min()) / max(c.max(), 1e-3)
        sat_n = (ncol.max() - ncol.min()) / max(ncol.max(), 1e-3)
        sat_a = (allc.max() - allc.min()) / max(allc.max(), 1e-3)
        p_ = me.polygons[f.index]
        wraps = any(not (0.0 <= uvl[i].uv.x <= 1.0 and 0.0 <= uvl[i].uv.y <= 1.0) for i in p_.loop_indices)   ## off the atlas's edge: wraps round
        if not wraps and stripes < 0.35 and abs(sat_f - sat_n) < 0.3 and not (abs(sat_f - sat_a) > 0.3 and np.abs(c - allc).sum() > 0.3):
            continue
        good = min(nb, key=lambda i: np.abs(cols[i] - ncol).sum())
        gp = me.polygons[good]
        guv = sum((uvl[i].uv for i in gp.loop_indices), Vector((0, 0))) / gp.loop_total
        p = me.polygons[f.index]
        t1 = (me.vertices[p.vertices[1]].co - me.vertices[p.vertices[0]].co).normalized()
        t2 = p.normal.cross(t1)
        for i, vi in zip(p.loop_indices, p.vertices):
            d = me.vertices[vi].co - p.center
            uvl[i].uv = guv + Vector((d.dot(t1), d.dot(t2))) * k * 0.5
        cols[f.index] = cols[good]
        fixed += 1
    bm.free()
    return fixed


def clean_texture(part, r, pivot):
    """Paints over the white wedges and the roller's dark shadow that Meshy baked into the lid's part of the atlas: each bad pixel takes
    the colour of the nearest good ones, growing in from the edges. Only pixels the lid's own faces use change."""
    import numpy as np
    me = part.data
    img = None
    for m in me.materials:
        if m and m.use_nodes:
            for nd in m.node_tree.nodes:
                if nd.type == "TEX_IMAGE" and nd.image:
                    img = nd.image
    if img is None:
        return 0
    W, H = img.size
    a = np.array(img.pixels[:], dtype=np.float32).reshape(H, W, 4)
    uvl = me.uv_layers.active.data
    mw = part.matrix_world
    shut_z = [(r @ (mw @ v.co - pivot) + pivot).z for v in me.vertices]
    ztop = max(shut_z)
    lid = np.zeros((H, W), bool)
    top = np.zeros((H, W), bool)
    for poly in me.polygons:
        tri = [uvl[i].uv for i in poly.loop_indices]
        xs = [t.x * W for t in tri]
        ys = [t.y * H for t in tri]
        x0, x1 = max(0, int(min(xs))), min(W - 1, int(max(xs)) + 1)
        y0, y1 = max(0, int(min(ys))), min(H - 1, int(max(ys)) + 1)
        if x1 <= x0 or y1 <= y0:
            continue
        gx, gy = np.meshgrid(np.arange(x0, x1 + 1) + 0.5, np.arange(y0, y1 + 1) + 0.5)
        inside = np.ones_like(gx, bool)
        sign = None
        for k in range(len(xs)):
            ax, ay, bx_, by_ = xs[k], ys[k], xs[(k + 1) % len(xs)], ys[(k + 1) % len(xs)]
            c = (bx_ - ax) * (gy - ay) - (by_ - ay) * (gx - ax)
            if sign is None:
                sign = 1.0 if ((xs[1] - xs[0]) * (ys[2] - ys[0]) - (ys[1] - ys[0]) * (xs[2] - xs[0])) >= 0 else -1.0
            inside &= c * sign >= -0.5
        lid[y0:y1 + 1, x0:x1 + 1] |= inside
        cz = sum(shut_z[vi] for vi in poly.vertices) / len(poly.vertices)
        if cz > ztop - 0.06:
            top[y0:y1 + 1, x0:x1 + 1] |= inside
    for _ in range(10):                                      ## (thin triangles rasterise to almost nothing, and the game blurs texels from just outside a face into it: widen the lid's area)
        l2 = lid.copy()
        l2[1:, :] |= lid[:-1, :]
        l2[:-1, :] |= lid[1:, :]
        l2[:, 1:] |= lid[:, :-1]
        l2[:, :-1] |= lid[:, 1:]
        lid = l2
    rgb = a[:, :, :3]
    mx, mn = rgb.max(axis=2), rgb.min(axis=2)
    white = (mn > 0.42) & (mx > 0.58) & (mx - mn < 0.22)          ## white to pale grey: the wood and its inlay are far more saturated
    white |= ((mx - mn) / np.maximum(mx, 1e-3) < 0.2) & (mx > 0.12)  ## any grey at all (the comb's steel stripes, bled onto the lid)
    white |= mx < 0.07                                               ## and the atlas's black padding
    lum = rgb.mean(axis=2)
    med = np.median(lum[top]) if top.any() else 0.0
    shadow = top & (lum < med * 0.8)
    bad = lid & (white | shadow)
    # grow the bad patches a few pixels, to take their soft edges too
    for _ in range(3):
        b2 = bad.copy()
        b2[1:, :] |= bad[:-1, :]
        b2[:-1, :] |= bad[1:, :]
        b2[:, 1:] |= bad[:, :-1]
        b2[:, :-1] |= bad[:, 1:]
        bad = b2 & lid
    n = int(bad.sum())
    good = ~bad
    for _ in range(400):                                    ## fill inward from the edges, a ring of pixels at a time
        if not bad.any():
            break
        acc = np.zeros_like(rgb)
        cnt = np.zeros((H, W), np.float32)
        for dy, dx in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            sh_good = np.roll(np.roll(good, dy, 0), dx, 1)
            sh_rgb = np.roll(np.roll(rgb, dy, 0), dx, 1)
            acc += sh_rgb * sh_good[:, :, None]
            cnt += sh_good
        ring = bad & (cnt > 0)
        rgb[ring] = acc[ring] / cnt[ring][:, None]
        good |= ring
        bad &= ~ring
    a[:, :, :3] = rgb
    a[:, :, 3][lid] = 1.0                                  ## and nothing on the lid see-through (its atlas has clear padding)
    img.pixels[:] = a.ravel()
    img.update()
    img.pack()
    return n


def fit_lid(kind, part, body, bv, r, pivot, shut):
    """Makes a lid exactly the size of the box it shuts on (Meshy's lid and box needn't match): measured shut, against the box's rim,
    and scaled in its own plane about its shut middle, so it covers the box edge to edge."""
    zs = sorted(v.z for v in bv)
    top = zs[int(len(zs) * 0.97)]
    rim = [v for v in bv if top - 0.15 < v.z <= top]                  ## the walls' upper part: the box's outline under the lid
    def span(vals):
        vals = sorted(vals)
        return vals[int(len(vals) * 0.005)], vals[int(len(vals) * 0.995)]
    bx, by = span(v.x for v in rim), span(v.y for v in rim)
    lx, ly = span(v.x for v in shut), span(v.y for v in shut)
    fx = (bx[1] - bx[0] + LID_LIP * 2) / (lx[1] - lx[0])         ## a hair bigger than the box all round, so its rim
    fy = (by[1] - by[0] + LID_LIP * 2) / (ly[1] - ly[0])         ## drops just over the walls' top when it shuts
    c = Vector(((lx[0] + lx[1]) / 2, (ly[0] + ly[1]) / 2, 0))
    # the walls' top: the highest of the box's verts out at its outline
    # (the front and the two ends: the back carries the hinge leaves, which stand higher)
    edge = [v.z for v in bv if min(abs(v.x - bx[0]), abs(v.x - bx[1]), abs(v.y - by[0])) < 0.025]
    wall_top = sorted(edge)[int(len(edge) * 0.9)]
    ri = r.inverted()
    mw, inv = part.matrix_world, part.matrix_world.inverted()
    for v in part.data.vertices:
        sv = r @ (mw @ v.co - pivot) + pivot
        sv = Vector((c.x + (sv.x - c.x) * fx, c.y + (sv.y - c.y) * fy, sv.z))
        v.co = inv @ (ri @ (sv - pivot) + pivot)
    print(kind, "lid fitted to the box: x %.3f..%.3f (box %.3f..%.3f) y %.3f..%.3f (box %.3f..%.3f), scale %.3f x %.3f, walls' top z %.3f" % (
        lx[0], lx[1], bx[0], bx[1], ly[0], ly[1], by[0], by[1], fx, fy, wall_top))
    # its texture: Meshy baked its stray shards into the atlas (white wedges on the lid's top and inside panel) and the roller's shadow
    # (a dark bar across the top): those pixels are painted over with the wood around them
    # a corner of the lid's top is missing (the drum showed through it). Its seams aren't welded, so every seam looks open: weld them,
    # then close the holes that are left in the top surface (small ones: the lid's open underside is one big loop)
    bm = bmesh.new()
    bm.from_mesh(part.data)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0008)
    mw_ = part.matrix_world
    ztop_ = max((r @ (mw_ @ v.co - pivot) + pivot).z for v in bm.verts)
    open_e = [e for e in bm.edges if len(e.link_faces) < 2 and all((r @ (mw_ @ v.co - pivot) + pivot).z > ztop_ - 0.03 for v in e.verts)]
    res = bmesh.ops.holes_fill(bm, edges=open_e, sides=8)
    bmesh.ops.triangulate(bm, faces=res["faces"])
    bm.to_mesh(part.data)
    bm.free()
    print(kind, "holes in the lid's top filled:", len(res["faces"]))
    print(kind, "lid texture pixels painted over:", clean_texture(part, r, pivot))
    print(kind, "lid faces re-pointed at the lid's own wood:", odd_faces(part, r, pivot))
    print(kind, "...and painted over where they now point:", clean_texture(part, r, pivot))
    return Vector(((bx[0] + bx[1]) / 2, (by[0] + by[1]) / 2, wall_top))


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
    if spec.get("drop_sheets"):
        print(kind, "paper-thin stray sheets removed:", drop_sheets(body))
    if spec.get("raise_front"):
        print(kind, "board on the front wall, raising it level with the ends: %.3f" % raise_front(body))
    if spec.get("dedupe_islands"):
        print(kind, "doubled pieces removed:", dedupe_islands(body))
    if spec.get("delete_island"):
        if spec.get("add_key"):
            spec["add_key"]["uv"] = island_uv(body, spec["add_key"]["uv_from"])
        junk = separate(body, "False", spec["delete_island"])
        print(kind, "deleted pieces' faces:", len(junk.data.polygons))
        bpy.data.objects.remove(junk, do_unlink=True)
    if spec.get("add_key"):
        print(kind, "winding key faces:", add_key(body, spec["add_key"]))
    out = {}
    parts = []
    for ps in spec["parts"]:
        isl = ps.get("island")
        if isl == "IS_KEY":
            isl = "x > %f and abs(y - %f) < 0.09 and abs(z - %f) < 0.09 and sx < 0.12" % tuple(spec["add_key"]["at"])
        part = separate(body, ps["pick"], isl)
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
            if ps.get("fit"):                                   ## a fitted lid shuts exactly flat: its panel's plane turned level
                big = sorted(part.data.polygons, key=lambda q: -q.area)[:12]
                nrm = sum(((part.matrix_world.to_3x3() @ q.normal) * q.area * (1 if (part.matrix_world.to_3x3() @ q.normal).dot(Matrix.Rotation(ang, 3, axis).inverted() @ Vector((0, 0, 1))) > 0 else -1) for q in big), Vector()).normalized()
                best = min(range(-1800, 1801), key=lambda k: -(Matrix.Rotation(math.radians(k / 10), 3, axis) @ nrm).z)
                print(kind, "lid flat at %.1f deg (search gave %.1f)" % (best / 10, math.degrees(ang)))
                ang = math.radians(best / 10)
            if ps.get("plate"):
                print(kind, "lid plate sides:", plate(part, bcen, body))
            # where the part must end up shut: a top lid centred on the body's rim and resting on it; the watch's cover centred on the
            # case's front. The swing alone gets close; this small shift makes it seat exactly (the game blends it in as it closes).
            r = Matrix.Rotation(ang, 3, axis)
            shut = [r @ (v - pivot) + pivot for v in vs]
            box_seat = None
            if ps.get("fit"):
                box_seat = fit_lid(kind, part, body, bv, r, pivot, shut)
                vs = verts(part)
                shut = [r @ (v - pivot) + pivot for v in vs]
            sc = sum(shut, Vector()) / len(shut)
            n = ps["normal"]
            if box_seat is not None:                            ## centred on the box's outline, its underside on the walls' top
                lo_x, hi_x = min(v.x for v in shut), max(v.x for v in shut)
                lo_y, hi_y = min(v.y for v in shut), max(v.y for v in shut)
                sides = [v.z for v in shut if min(abs(v.x - lo_x), abs(v.x - hi_x)) < 0.04]     ## its side rims (the clasp hangs lower)
                lid_lo = sorted(sides)[int(len(sides) * 0.05)]
                target = sc + Vector((box_seat.x - (lo_x + hi_x) / 2, box_seat.y - (lo_y + hi_y) / 2, box_seat.z - lid_lo - LID_LIP))
            elif ps["axis"] == "X":
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
        elif ps["type"] == "spin":                              ## a key, a wheel, a drum: turns about its own middle
            lo = Vector((min(v.x for v in vs), min(v.y for v in vs), min(v.z for v in vs)))
            hi = Vector((max(v.x for v in vs), max(v.y for v in vs), max(v.z for v in vs)))
            pivot = (lo + hi) / 2
            if ps["role"] == "key" and kind in KEY_AXIS:          ## a key turns about its shaft, not the middle of its bow
                ax = KEY_AXIS[kind]
                pivot = Vector((pivot.x if ax[0] is None else ax[0], pivot.y if ax[1] is None else ax[1], pivot.z if ax[2] is None else ax[2]))
            out[ps["name"]] = {"type": "spin", "role": ps["role"], "pivot": to_godot(pivot), "axis": to_godot(ps["spin_axis"])}
            print(kind, ps["name"], "spin about", tuple(round(c, 3) for c in pivot), "size", tuple(round(c, 3) for c in hi - lo))
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
    if spec.get("double_sided"):                                 ## some of Meshy's faces face inward (a corner of the lid's top vanished)
        for m in body.data.materials:
            if m:
                m.use_backface_culling = False
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(ITEMS, kind + "_parts.glb"), export_format="GLB", use_selection=True)
    with open(os.path.join(ITEMS, kind + "_parts.json"), "w") as f:
        json.dump(out, f, indent=1)


import sys
_only = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
for k in SPEC:
    if not _only or k in _only:
        run(k)
