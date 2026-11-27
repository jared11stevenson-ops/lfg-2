"""Bake sprite frames (idle/walk/attack + evolved glow variants) from a Tripo GLB, for creatures with no rig.
  python3 glb_bake.py <in.glb> <out_dir> <id> <yaw_face_deg> <px_width> [lift] [test]
yaw_face rotates the model so it faces +X. 'test' renders only 4 facing candidates to one sheet."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector
from rig import sprite_camera, FRAMES

src, out_dir, name = sys.argv[1], sys.argv[2], sys.argv[3]
yaw_face = float(sys.argv[4]); px_w = float(sys.argv[5])
lift = float(sys.argv[6]) if len(sys.argv) > 6 else 0.0
test = len(sys.argv) > 7 and sys.argv[7] == "test"
SIZE, PPU, YAW = 256, 50.0, -32.0

bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=src)
meshes = [o for o in bpy.context.scene.objects if o.type == 'MESH']
for o in meshes:
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    m = o.modifiers.new("dec", 'DECIMATE'); m.ratio = 0.09
    bpy.ops.object.modifier_apply(modifier="dec")
    o.select_set(False)
# bring everything to world space under one pivot at the origin
pivot = bpy.data.objects.new("pivot", None)
bpy.context.collection.objects.link(pivot)
for o in meshes:
    o.parent = None
bpy.ops.object.select_all(action='DESELECT')
mesh = meshes[0]
mesh.rotation_mode = 'XYZ'

def fit(face):
    mesh.rotation_euler = (0, 0, math.radians(face + 0.0))
    bpy.context.view_layer.update()
    mn = Vector((1e9,) * 3); mx = Vector((-1e9,) * 3)
    for c in mesh.bound_box:
        w = mesh.matrix_world @ Vector(c)
        mn = Vector(min(a, b) for a, b in zip(mn, w)); mx = Vector(max(a, b) for a, b in zip(mx, w))
    return mn, mx

mn, mx = fit(yaw_face)
length = max(mx.x - mn.x, mx.y - mn.y)
k = (px_w / PPU) / length
mesh.scale = (k, k, k)
bpy.context.view_layer.update()
mn, mx = fit(yaw_face)
ctr = (mn + mx) / 2
mesh.location = (-ctr.x, -ctr.y, -mn.z + lift)
mesh.parent = pivot
bpy.context.view_layer.update()

sc = bpy.context.scene
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = 20; sc.cycles.use_denoising = False
sc.cycles.max_bounces = 2
sc.render.film_transparent = True
sc.render.image_settings.file_format = 'PNG'; sc.render.image_settings.color_mode = 'RGBA'
sc.view_settings.view_transform = 'Standard'
sc.render.use_freestyle = False
w = bpy.data.worlds.new("w"); w.use_nodes = True
bg = w.node_tree.nodes['Background']; bg.inputs[0].default_value = (0.85, 0.8, 1.0, 1); bg.inputs[1].default_value = 0.8
sc.world = w
for rot, e, col in (((math.radians(50), 0, math.radians(-40)), 3.2, (1, 0.96, 0.9)), ((math.radians(60), 0, math.radians(140)), 1.4, (0.6, 0.7, 1.0))):
    ld = bpy.data.lights.new("l", 'SUN'); ld.energy = e; ld.color = col; ld.angle = math.radians(25)
    lo = bpy.data.objects.new("l", ld); sc.collection.objects.link(lo); lo.rotation_euler = rot

def pose(state, t):
    s = math.sin(2 * math.pi * t)
    px = py = pz = 0.0; rx = ry = rz = 0.0; sx = sy = sz = 1.0
    if state == "idle":
        sz = 1 + 0.03 * s; sx = sy = 1 - 0.015 * s; pz = 0.03 * s; rz = 1.2 * s
    elif state == "walk":
        pz = 0.07 * abs(math.sin(2 * math.pi * t)); rx = 3.0 * math.sin(2 * math.pi * t); ry = 2.0 * math.sin(4 * math.pi * t)
        sz = 1 + 0.02 * abs(s); sx = 1 - 0.01 * abs(s)
    else:  # attack: anticipate (lean back, squash), strike (lunge), recover
        keys = [(-7, 0.92, -0.10, 0.0), (-10, 0.88, -0.16, 0.0), (9, 1.12, 0.32, 0.12), (4, 1.04, 0.14, 0.04), (0, 1.0, 0.0, 0.0)]
        i = min(int(t * 5), 4)
        ry, sz, px, pz = keys[i]
        sx = sy = 1 / math.sqrt(sz)
    pivot.location = (px, py, pz)
    pivot.rotation_euler = (math.radians(rx), math.radians(ry), math.radians(YAW + rz))
    pivot.scale = (sx, sy, sz)

from PIL import Image, ImageFilter
import tempfile
os.makedirs(out_dir, exist_ok=True)
tmp = os.path.join(tempfile.gettempdir(), "glbbake_%d.png" % os.getpid())
sprite_camera(PPU * SIZE / 192.0, size=SIZE, origin=(105 * SIZE / 192.0, 173 * SIZE / 192.0), el=12.0)
sc.render.resolution_x = sc.render.resolution_y = SIZE * 2
sc.render.filepath = tmp

def render_frame():
    bpy.ops.render.render(write_still=True)
    return Image.open(tmp).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)

if test:
    sheet = Image.new("RGBA", (SIZE * 4, SIZE), (30, 20, 60, 255))
    for i, f in enumerate((0, 90, 180, 270)):
        mn, mx = fit(yaw_face + f); 
        mesh.rotation_euler = (0, 0, math.radians(yaw_face + f))
        bpy.context.view_layer.update()
        pose("idle", 0)
        sheet.alpha_composite(render_frame(), (i * SIZE, 0))
    sheet.save(os.path.join(out_dir, name + "_facing_test.png")); print("test ok"); sys.exit(0)

frames = {}
for state in ("idle", "walk", "attack"):
    for i in range(FRAMES[state]):
        pose(state, i / FRAMES[state])
        frames[(state, i)] = render_frame()
def tinted(im, color, blur=9, grow=2):
    a = im.split()[3].filter(ImageFilter.MaxFilter(2 * grow + 1)).filter(ImageFilter.GaussianBlur(blur))
    glow = Image.new("RGBA", im.size, color + (0,)); glow.putalpha(a.point(lambda v: int(v * 0.85)))
    base = Image.new("RGBA", im.size, (0, 0, 0, 0)); base.alpha_composite(glow); base.alpha_composite(im)
    return base
for (state, i), im in frames.items():
    im.save(os.path.join(out_dir, f"{name}_{state}_{i}.png"))
    if state != "walk":
        tinted(im, (255, 214, 90)).save(os.path.join(out_dir, f"{name}_a_{state}_{i}.png"))
        tinted(im, (255, 96, 60)).save(os.path.join(out_dir, f"{name}_b_{state}_{i}.png"))
print("bake ok")
