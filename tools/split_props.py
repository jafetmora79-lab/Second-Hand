"""Cuts moving parts out of the shop's Meshy props (like tools/split_items.py does for the antiques).
- bankers_lamp: the pull chain, with its origin at its top link, so the game can pull it down and let it bounce.
Writes assets/shop/<prop>_parts.glb (Body + parts) and <prop>_parts.json (each part's pivot, in Godot's axes).
Run:  blender -b -P tools/split_props.py
"""
import bpy, bmesh, json, os
from mathutils import Vector

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SHOP = os.path.join(ROOT, "assets", "shop")
SPEC = {"bankers_lamp": [{"name": "Chain", "pick": "y < -0.05 and -0.1 < z < 0.24 and -0.02 < x < 0.22"}]}


def to_godot(v):
    return [round(v.x, 5), round(v.z, 5), round(-v.y, 5)]


def run(prop):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=os.path.join(SHOP, prop + ".glb"))
    body = [o for o in bpy.context.scene.objects if o.type == "MESH"][0]
    bpy.context.view_layer.objects.active = body
    body.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    out = {}
    for ps in SPEC[prop]:
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.select_mode(type="FACE")
        bpy.ops.mesh.select_all(action="DESELECT")
        bpy.ops.object.mode_set(mode="OBJECT")
        me = body.data
        for v in me.vertices:
            v.select = False
        for e in me.edges:
            e.select = False
        for p in me.polygons:
            x, y, z = p.center
            p.select = bool(eval(ps["pick"]))
            if p.select:
                for vi in p.vertices:
                    me.vertices[vi].select = True
        before = set(bpy.data.objects)
        bpy.ops.object.mode_set(mode="EDIT")
        bpy.ops.mesh.separate(type="SELECTED")
        bpy.ops.object.mode_set(mode="OBJECT")
        part = [o for o in bpy.data.objects if o not in before][0]
        part.name = ps["name"]
        vs = [part.matrix_world @ v.co for v in part.data.vertices]
        hi = max(v.z for v in vs)
        top = [v for v in vs if v.z > hi - 0.01]
        pivot = sum(top, Vector()) / len(top)                   ## the chain hangs from its top link
        bpy.context.scene.cursor.location = pivot
        bpy.ops.object.select_all(action="DESELECT")
        part.select_set(True)
        bpy.context.view_layer.objects.active = part
        bpy.ops.object.origin_set(type="ORIGIN_CURSOR")
        out[ps["name"]] = {"pivot": to_godot(pivot), "length": round(hi - min(v.z for v in vs), 4)}
        print(prop, ps["name"], out[ps["name"]], "faces", len(part.data.polygons))
    body.name = "Body"
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.export_scene.gltf(filepath=os.path.join(SHOP, prop + "_parts.glb"), export_format="GLB", use_selection=True)
    with open(os.path.join(SHOP, prop + "_parts.json"), "w") as f:
        json.dump(out, f, indent=1)


for k in SPEC:
    run(k)
