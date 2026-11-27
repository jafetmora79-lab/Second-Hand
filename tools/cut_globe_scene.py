# Blender (headless): cuts Meshy's own little house and trees out of the snow globe's original dome, for the rebuilt globe to set inside
# its glass (scripts/snow_globe.gd). Meshy fused the scene onto an opaque grey dome; this keeps only the faces above the top of the base
# whose texture is coloured (the house's wood, the trees' green, the red chimney) or snow-white, and drops the grey glass shell.
# Usage: blender -b -P tools/cut_globe_scene.py -- assets/items/snow_globe.glb assets/items/snow_globe_scene.glb
import bpy, bmesh, sys, colorsys

args = sys.argv[sys.argv.index("--") + 1:]
src, dst = args[0], args[1]
CUT = -0.16 + 0.015          # a little above the base top (Godot y = Blender z here); the base is kept by the game itself

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obj = [o for o in bpy.context.scene.objects if o.type == 'MESH'][0]
me = obj.data
img = None
for mat in me.materials:
    for node in mat.node_tree.nodes:
        if node.type == 'TEX_IMAGE' and node.image:
            img = node.image
W, H = img.size
px = list(img.pixels)


def colour(u, v):
    x = min(W - 1, max(0, int(u * W)))
    y = min(H - 1, max(0, int(v * H)))
    i = (y * W + x) * 4
    return px[i], px[i + 1], px[i + 2]


bm = bmesh.new()
bm.from_mesh(me)
uv = bm.loops.layers.uv.active
mw = obj.matrix_world
kill = []
kept = 0
for f in bm.faces:
    c = mw @ f.calc_center_median()
    if c.z < CUT:
        kill.append(f)                                    # the base: the game keeps its own copy
        continue
    r = g = b = 0.0
    for lp in f.loops:
        cr, cg, cb = colour(lp[uv].uv.x, lp[uv].uv.y)
        r += cr; g += cg; b += cb
    n = len(f.loops)
    h, s, val = colorsys.rgb_to_hsv(r / n, g / n, b / n)
    if s > 0.22 or val > 0.86:
        kept += 1                                         # coloured, or snow-white: part of the scene
    else:
        kill.append(f)                                    # the grey dome
bmesh.ops.delete(bm, geom=kill, context='FACES')
# drop stray specks: islands of a handful of faces (dome highlights that passed the colour test)
islands = []
seen = set()
for f in bm.faces:
    if f.index in seen:
        continue
    stack = [f]
    isl = []
    seen.add(f.index)
    while stack:
        cur = stack.pop()
        isl.append(cur)
        for e in cur.edges:
            for nf in e.link_faces:
                if nf.index not in seen:
                    seen.add(nf.index)
                    stack.append(nf)
    islands.append(isl)
small = [f for isl in islands if len(isl) < 25 for f in isl]
bmesh.ops.delete(bm, geom=small, context='FACES')
bm.to_mesh(me)
bm.free()
print("KEPT", kept, "ISLANDS", len(islands), "DROPPED_SMALL", len(small), "FACES", len(me.polygons))
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB')
