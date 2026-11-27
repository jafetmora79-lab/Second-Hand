# Blender: prints the trapper's bounds and renders front and side views with a 5 cm grid, to find the satchel.
import bpy, sys, mathutils
args = sys.argv[sys.argv.index("--") + 1:]
src, out = args[0], args[1]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
obs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
lo = mathutils.Vector((1e9,)*3); hi = mathutils.Vector((-1e9,)*3)
for o in obs:
    for v in o.data.vertices:
        w = o.matrix_world @ v.co
        lo = mathutils.Vector((min(lo[i], w[i]) for i in range(3))); hi = mathutils.Vector((max(hi[i], w[i]) for i in range(3)))
print("BOUNDS", tuple(round(x,3) for x in lo), tuple(round(x,3) for x in hi), "verts", sum(len(o.data.vertices) for o in obs))
scene = bpy.context.scene
scene.render.engine = 'BLENDER_WORKBENCH'
scene.display.shading.color_type = 'TEXTURE'
scene.display.shading.light = 'FLAT'
scene.render.resolution_x = 800
scene.render.resolution_y = 800
cam_data = bpy.data.cameras.new("cam")
cam_data.type = 'ORTHO'
cam_data.ortho_scale = 1.0
cam = bpy.data.objects.new("cam", cam_data)
scene.collection.objects.link(cam)
scene.camera = cam
for name, loc, rot in [("front", (0, -2, 0), (1.5708, 0, 0)), ("side", (2, 0, 0), (1.5708, 0, 1.5708))]:
    cam.location = loc
    cam.rotation_euler = rot
    scene.render.filepath = out + "_" + name + ".png"
    bpy.ops.render.render(write_still=True)
