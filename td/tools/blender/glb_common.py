"""Shared loader: import a Tripo GLB, decimate, orient to face +X, scale to px_w/50 world units, feet on z=0 (+lift), centered."""
import math, bpy
from mathutils import Vector

def load_normalized(src, yaw_face, px_w, lift=0.0, ratio=0.09, ppu=50.0):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.gltf(filepath=src)
    meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
    for o in meshes:
        bpy.context.view_layer.objects.active = o
        o.select_set(True)
        m = o.modifiers.new("dec", 'DECIMATE'); m.ratio = ratio
        bpy.ops.object.modifier_apply(modifier="dec")
        o.select_set(False)
    mesh = meshes[0]
    mesh.parent = None
    mesh.rotation_mode = 'XYZ'
    def bbox():
        bpy.context.view_layer.update()
        mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
        for c in mesh.bound_box:
            w = mesh.matrix_world @ Vector(c)
            mn = Vector(min(a, b) for a, b in zip(mn, w)); mx = Vector(max(a, b) for a, b in zip(mx, w))
        return mn, mx
    mesh.rotation_euler = (0, 0, math.radians(yaw_face))
    mn, mx = bbox()
    k = (px_w / ppu) / max(mx.x - mn.x, mx.y - mn.y)
    mesh.scale = (k, k, k)
    mn, mx = bbox()
    ctr = (mn + mx) / 2
    mesh.location = (-ctr.x, -ctr.y, -mn.z + lift)
    bpy.context.view_layer.objects.active = mesh
    mesh.select_set(True)
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    mesh.select_set(False)
    return mesh

def basic_render_setup(res, samples=20):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = samples; sc.cycles.use_denoising = False
    sc.cycles.max_bounces = 2
    sc.render.film_transparent = True
    sc.render.image_settings.file_format = 'PNG'; sc.render.image_settings.color_mode = 'RGBA'
    sc.view_settings.view_transform = 'Standard'
    sc.render.use_freestyle = False
    sc.render.resolution_x = sc.render.resolution_y = res
    w = bpy.data.worlds.new("w"); w.use_nodes = True
    bg = w.node_tree.nodes['Background']; bg.inputs[0].default_value = (0.85, 0.8, 1.0, 1); bg.inputs[1].default_value = 0.8
    sc.world = w
    for rot, e, col in (((math.radians(50), 0, math.radians(-40)), 3.2, (1, 0.96, 0.9)), ((math.radians(60), 0, math.radians(140)), 1.4, (0.6, 0.7, 1.0))):
        ld = bpy.data.lights.new("l", 'SUN'); ld.energy = e; ld.color = col; ld.angle = math.radians(25)
        lo = bpy.data.objects.new("l", ld); sc.collection.objects.link(lo); lo.rotation_euler = rot
