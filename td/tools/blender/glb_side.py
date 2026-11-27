"""python3 glb_side.py <glb> <out_prefix> <yaw_face> <px_w> <lift>: gridded side (-Y) and top views in normalized rig space."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import bpy
from mathutils import Vector
from glb_common import load_normalized, basic_render_setup
from PIL import Image, ImageDraw
src, out, yaw, pxw, lift = sys.argv[1], sys.argv[2], float(sys.argv[3]), float(sys.argv[4]), float(sys.argv[5])
mesh = load_normalized(src, yaw, pxw, lift)
basic_render_setup(900)
sc = bpy.context.scene
SPAN = 4.0   # world units across the 900px image
cd = bpy.data.cameras.new("c"); cd.type = 'ORTHO'; cd.ortho_scale = SPAN
cam = bpy.data.objects.new("c", cd); sc.collection.objects.link(cam); sc.camera = cam
def shot(name, loc, target):
    cam.location = loc
    cam.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat('-Z', 'Y').to_euler()
    sc.render.filepath = f"{out}_{name}.png"
    bpy.ops.render.render(write_still=True)
shot("side", (0, -9, 1.0), (0, 0, 1.0))     # image x = world x, image y centre = z 1.0
shot("top", (0, 0, 9), (0, 0, 0))            # image x = world x, image y up = world y
for name, cz in (("side", 1.0), ("top", 0.0)):
    im = Image.open(f"{out}_{name}.png").convert("RGBA")
    bg = Image.new("RGBA", im.size, (24, 18, 50, 255)); bg.alpha_composite(im); d = ImageDraw.Draw(bg)
    px = 900 / SPAN
    for i in range(-8, 9):
        v = i * 0.25
        x = 450 + v * px
        d.line([(x, 0), (x, 900)], fill=(255, 255, 255, 70) if i % 4 else (255, 220, 80, 160), width=1)
        y = 450 - (v - (cz - cz)) * px
        d.line([(0, 450 - v * px), (900, 450 - v * px)], fill=(255, 255, 255, 70) if i % 4 else (255, 220, 80, 160), width=1)
        if i % 2 == 0:
            d.text((x + 2, 884), f"{v:.1f}", fill=(255, 255, 255, 255))
            d.text((2, 450 - v * px - 12), f"{v + cz:.1f}", fill=(255, 255, 255, 255))
    bg.save(f"{out}_{name}_grid.png")
print("side ok")
