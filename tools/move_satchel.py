# Blender: slides Old Amos's satchel toward the middle of his body, away from his left hand, so rigging does not bind the bag to the arm.
# Usage: blender -b -P tools/move_satchel.py -- <in.glb> <out.glb>
# Model space (Blender, Z up, he faces -Y): the satchel sits in front of the coat at the left hip, x 0.04..0.17, z -0.08..0.075, y < -0.072.
import bpy, sys
args = sys.argv[sys.argv.index("--") + 1:]
src, dst = args[0], args[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
moved = 0
for o in bpy.context.scene.objects:
    if o.type != 'MESH':
        continue
    mw = o.matrix_world
    inv = mw.inverted()
    for v in o.data.vertices:
        w = mw @ v.co
        if 0.035 <= w.x <= 0.18 and -0.085 <= w.z <= 0.078 and w.y < -0.08:
            # full shift inside the bag, fading to nothing at its edges so the strap and the coat stay joined
            fx = min(1.0, (w.x - 0.035) / 0.02, (0.18 - w.x) / 0.02 + 0.6)
            fz = min(1.0, (w.z + 0.085) / 0.02, (0.078 - w.z) / 0.015)
            f = max(0.0, min(fx, fz))
            w.x -= 0.058 * f
            w.y -= 0.008 * f
            v.co = inv @ w
            moved += 1
print("MOVED", moved)
bpy.ops.export_scene.gltf(filepath=dst, export_format='GLB')
