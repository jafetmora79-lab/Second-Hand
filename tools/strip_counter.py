"""Strips the malformed player-facing rear out of the U counter (assets/shop/counter_u.glb), keeping its customer-facing shell.

Meshy built the inside of the counter as disconnected shelves, odd panels and holes. Below the countertop, this keeps only the skin a
customer sees (the front, the arms' outer walls and their back ends) and everything at or above the countertop (the top, the brass rails,
the security screens). The game builds proper cabinetry behind it (Shop._u_cabinetry). Writes assets/shop/counter_u_shell.glb.

Model space (Blender, Z up): x across (+-0.5 -> +-1.3 m in the shop), y toward the customer (+0.49 -> the front at z -0.72 m),
z up (-0.212 -> the floor, 0.035 -> the countertop's underside at 0.9 m).
Run:  blender -b -P tools/strip_counter.py
"""
import bpy, bmesh, os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOP = os.path.join(ROOT, "assets", "shop")
UNDER_TOP = 0.03          ## below this a face is part of the cabinet body
FRONT_SKIN = 0.45         ## y beyond this: the customer-facing front
SIDE_SKIN = 0.477         ## |x| beyond this: an arm's outer wall
END_SKIN = -0.46          ## y below this: an arm's back end

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=os.path.join(SHOP, "counter_u.glb"))
o = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
bpy.context.view_layer.objects.active = o
o.select_set(True)
bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
bm = bmesh.new()
bm.from_mesh(o.data)
gone = []
for f in bm.faces:
    c = f.calc_center_median()
    if c.z >= UNDER_TOP:
        continue
    if c.y > FRONT_SKIN or abs(c.x) > SIDE_SKIN or c.y < END_SKIN:
        continue
    gone.append(f)
bmesh.ops.delete(bm, geom=gone, context="FACES")
bm.to_mesh(o.data)
bm.free()
print("rear faces removed:", len(gone), "kept:", len(o.data.polygons))
bpy.ops.export_scene.gltf(filepath=os.path.join(SHOP, "counter_u_shell.glb"), export_format="GLB", use_selection=True)
