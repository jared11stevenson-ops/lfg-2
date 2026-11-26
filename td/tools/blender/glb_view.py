"""Render a GLB from a few angles: python3 glb_view.py <in.glb> <out_prefix>"""
import sys, math, bpy
from mathutils import Vector
src, out = sys.argv[1], sys.argv[2]
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
objs = [o for o in bpy.context.scene.objects if o.type == 'MESH']
mn = Vector((1e9,)*3); mx = Vector((-1e9,)*3)
for o in objs:
    for c in o.bound_box:
        w = o.matrix_world @ Vector(c)
        mn = Vector(min(a, b) for a, b in zip(mn, w)); mx = Vector(max(a, b) for a, b in zip(mx, w))
ctr = (mn + mx) / 2; size = max(mx - mn)
print("bbox", tuple(mn), tuple(mx), "tris", sum(len(o.data.polygons) for o in objs))
sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.samples = 24; sc.cycles.device = 'CPU'; sc.cycles.use_denoising = False
sc.render.film_transparent = False
sc.render.resolution_x = sc.render.resolution_y = 900
w = bpy.data.worlds.new("w"); w.use_nodes = True
w.node_tree.nodes['Background'].inputs[0].default_value = (0.08, 0.06, 0.22, 1); w.node_tree.nodes['Background'].inputs[1].default_value = 1.2
sc.world = w
for loc, e in (((4, -4, 6), 4.0), ((-5, 3, 3), 2.0)):
    ld = bpy.data.lights.new("l", 'SUN'); ld.energy = e
    lo = bpy.data.objects.new("l", ld); sc.collection.objects.link(lo)
    lo.rotation_euler = (Vector((0, 0, 0)) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
cd = bpy.data.cameras.new("c"); cd.type = 'ORTHO'; cd.ortho_scale = size * 1.25
cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
for name, az in (("front", 0), ("side", 90), ("three", 45)):
    a = math.radians(az)
    cam.location = ctr + Vector((math.sin(a) * 8 * size, -math.cos(a) * 8 * size, 0.25 * 8 * size))
    cam.rotation_euler = (ctr - cam.location).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = f"{out}_{name}.png"
    bpy.ops.render.render(write_still=True)
print("view ok")
