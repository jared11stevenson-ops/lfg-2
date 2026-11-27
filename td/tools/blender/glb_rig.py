"""Rig + animate + bake a Tripo creature (static GLB) into game sprite frames.
  python3 glb_rig.py <cat|dug|bat> <in.glb> <frames_dir> <id> [preview_dir]
Bones are placed in normalized space (facing +X, feet on z=0). Skin weights come from distance falloff to each bone
segment (numpy), so limbs, tail, ears and lantern deform instead of the whole mesh squashing."""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
import numpy as np
import bpy, bmesh
from mathutils import Vector
from glb_common import load_normalized, basic_render_setup
from rig import Rig, AXX, AXY, AXZ, FRAMES, sprite_camera

kind, src, out_dir, name = sys.argv[1], sys.argv[2], sys.argv[3], sys.argv[4]
preview = sys.argv[5] if len(sys.argv) > 5 else None
SIZE, PPU = 256, 50.0
SMOOTH_ITERS = 6

# name, head, tail, parent, falloff radius
SPECS = {
 "cat": dict(yaw_face=0, px_w=140, lift=0.0, YAW=-58.0, bones=[
    ("root", (0, 0, 0), (0, 0, 0.3), None, 0.01),
    ("body", (-0.75, 0, 0.95), (0.8, 0, 0.98), "root", 0.6),
    ("head", (0.8, 0, 0.98), (1.3, 0, 0.95), "body", 0.42),
    ("earP", (1.0, 0.32, 1.3), (1.0, 0.4, 1.5), "head", 0.17),
    ("earN", (1.0, -0.32, 1.3), (1.0, -0.4, 1.5), "head", 0.17),
    ("legFP", (0.95, 0.42, 0.7), (1.0, 0.42, 0.05), "body", 0.3),
    ("legFN", (0.95, -0.42, 0.7), (1.0, -0.42, 0.05), "body", 0.3),
    ("legBP", (-0.5, 0.42, 0.7), (-0.55, 0.42, 0.05), "body", 0.3),
    ("legBN", (-0.5, -0.42, 0.7), (-0.55, -0.42, 0.05), "body", 0.3),
    ("tail1", (-0.8, 0, 0.85), (-0.98, 0, 0.55), "body", 0.27),
    ("tail2", (-0.98, 0, 0.55), (-1.2, 0, 0.9), "tail1", 0.27),
    ("tail3", (-1.2, 0, 0.9), (-1.25, 0, 1.5), "tail2", 0.3),
    ("watch", (1.05, 0, 0.72), (1.1, 0, 0.3), "body", 0.22)]),
 "dug": dict(yaw_face=0, px_w=150, lift=0.35, YAW=-32.0, bones=[
    ("root", (0, 0, 0), (0, 0, 0.3), None, 0.01),
    ("body", (-0.9, 0, 1.05), (-0.25, 0, 1.07), "root", 0.42),
    ("bodyF", (-0.25, 0, 1.07), (0.45, 0, 1.1), "body", 0.45),
    ("head", (0.45, 0, 1.1), (1.1, 0, 1.12), "bodyF", 0.42),
    ("stalk", (0.85, 0, 1.45), (1.1, 0, 1.85), "head", 0.2),
    ("lantern", (1.1, 0, 1.85), (1.12, 0, 1.5), "stalk", 0.22),
    ("flipP", (0.55, 0.4, 0.8), (0.75, 0.6, 0.5), "bodyF", 0.28),
    ("flipN", (0.55, -0.4, 0.8), (0.75, -0.6, 0.5), "bodyF", 0.28),
    ("tail1", (-0.9, 0, 1.1), (-1.15, 0, 1.3), "body", 0.3),
    ("tail2", (-1.15, 0, 1.3), (-1.3, 0, 1.95), "tail1", 0.32)]),
 "bird": dict(yaw_face=270, px_w=150, lift=0.0, YAW=-40.0, bones=[
    ("root", (0, 0, 0), (0, 0, 0.3), None, 0.01),
    ("body", (-0.75, 0, 1.0), (0.55, 0, 1.1), "root", 0.62),
    ("neck", (0.55, 0, 1.2), (0.95, 0, 1.7), "body", 0.3),
    ("head", (0.95, 0, 1.7), (1.25, 0, 1.8), "neck", 0.3),
    ("crest", (0.95, 0, 1.95), (0.8, 0, 2.3), "head", 0.3),
    ("legN", (-0.2, -0.25, 0.75), (-0.4, -0.25, 0.1), "body", 0.3),
    ("legP", (0.4, 0.25, 0.7), (0.8, 0.25, 0.38), "body", 0.3),
    ("wingP", (0.55, 0.45, 1.05), (1.2, 0.65, 0.95), "body", 0.3),
    ("wingN", (0.55, -0.45, 1.05), (1.2, -0.65, 0.95), "body", 0.3),
    ("tail", (-0.75, 0, 0.85), (-1.4, 0, 0.5), "body", 0.35),
    ("steam", (-0.6, 0, 1.85), (-0.9, 0, 2.5), "body", 0.3)]),
 "bat": dict(yaw_face=270, px_w=150, lift=0.0, YAW=-32.0, bones=[
    ("root", (0, 0, 0), (0, 0, 0.3), None, 0.01),
    ("body", (-0.65, 0, 0.85), (0.6, 0, 0.9), "root", 0.5),
    ("head", (0.65, 0, 0.95), (1.25, 0, 0.85), "body", 0.4),
    ("earA", (1.05, -0.4, 1.1), (1.1, -0.6, 1.6), "head", 0.28),
    ("earB", (0.5, 0.4, 1.1), (0.5, 0.6, 1.55), "body", 0.28),
    ("legFP", (0.45, 0.28, 0.65), (0.78, 0.28, 0.08), "body", 0.26),
    ("legFN", (0.4, -0.28, 0.6), (0.55, -0.28, 0.1), "body", 0.26),
    ("legBP", (-0.45, 0.25, 0.65), (-0.2, 0.25, 0.08), "body", 0.26),
    ("legBN", (-0.5, -0.25, 0.65), (-1.0, -0.25, 0.08), "body", 0.26),
    ("tail1", (-0.7, 0, 0.85), (-1.0, 0, 1.05), "body", 0.26),
    ("tail2", (-1.0, 0, 1.05), (-1.15, 0, 1.55), "tail1", 0.3)]),
}
S = SPECS[kind]
mesh = load_normalized(src, S["yaw_face"], S["px_w"], S["lift"])
rig = Rig(name.capitalize() + "Rig")
rig.bones([(n, h, t, p) for n, h, t, p, r in S["bones"]])

# ---- skin weights: exp falloff to each bone segment, normalized ----
co = np.empty(len(mesh.data.vertices) * 3, dtype=np.float32)
mesh.data.vertices.foreach_get("co", co)
co = co.reshape(-1, 3)
W = np.zeros((len(co), len(S["bones"])), dtype=np.float32)
for j, (n, h, t, p, r) in enumerate(S["bones"]):
    a = np.array(h, dtype=np.float32); b = np.array(t, dtype=np.float32); ab = b - a
    tt = np.clip(((co - a) @ ab) / max(float(ab @ ab), 1e-6), 0.0, 1.0)
    d = np.linalg.norm(co - (a + tt[:, None] * ab), axis=1)
    W[:, j] = np.exp(-3.0 * (d / r) ** 2)
W[:, 0] = 0.0   # root carries no skin
tot = W.sum(axis=1)
W[tot < 1e-4, 1] = 1.0          # stray verts follow the body
W /= W.sum(axis=1, keepdims=True)
# smooth weights along the surface so limbs bend without tearing at thin parts
ed = np.empty(len(mesh.data.edges) * 2, dtype=np.int32)
mesh.data.edges.foreach_get("vertices", ed)
ed = ed.reshape(-1, 2)
for _ in range(SMOOTH_ITERS):
    acc = np.zeros_like(W); cnt = np.zeros(len(W), dtype=np.float32)
    np.add.at(acc, ed[:, 0], W[ed[:, 1]]); np.add.at(acc, ed[:, 1], W[ed[:, 0]])
    np.add.at(cnt, ed[:, 0], 1.0); np.add.at(cnt, ed[:, 1], 1.0)
    W = 0.5 * W + 0.5 * acc / np.maximum(cnt, 1.0)[:, None]
    W[:, 0] = 0.0
    W /= np.maximum(W.sum(axis=1, keepdims=True), 1e-6)
for j, (n, *_r) in enumerate(S["bones"]):
    mesh.vertex_groups.new(name=n)
for j, (n, *_r) in enumerate(S["bones"]):
    idx = np.nonzero(W[:, j] > 0.02)[0]
    vg = mesh.vertex_groups[n]
    for i in idx:
        vg.add([int(i)], float(W[i, j]), 'REPLACE')
mod = mesh.modifiers.new("Armature", 'ARMATURE'); mod.object = rig.arm
mesh.parent = rig.arm

# ---- animation ----
TAU = 2 * math.pi
def pose(r, state, t):
    r.reset()
    a = TAU * t
    s = math.sin(a)
    if kind == "cat":
        if state == "idle":
            br = math.sin(a)
            r.loc("root", (0, 0, 0.014 * br)); r.rot("body", AXY, -1.0 * br); r.rot("head", AXY, 1.8 * math.sin(a + 0.5))
            r.scale("body", 1.0 + 0.014 * br)
            r.rot("tail1", AXZ, 6 * br); r.rot("tail2", AXZ, 11 * math.sin(a + 0.8)); r.rot("tail3", AXZ, 15 * math.sin(a + 1.6))
            r.rot("earP", AXX, 9 * max(0, math.sin(2 * a))); r.rot("earN", AXX, -8 * max(0, math.sin(2 * a + 1.5)))
            r.rot("watch", AXY, 6 * math.sin(a + 0.5))
        elif state == "walk":
            for leg, ph in (("legFP", 0), ("legBN", 0), ("legFN", math.pi), ("legBP", math.pi)):
                r.rot(leg, AXY, 34 * math.sin(a + ph))
                r.loc(leg, (0, 0, 0.16 * max(0.0, -math.cos(a + ph))))
            r.loc("root", (0, 0, 0.07 * abs(math.sin(a)))); r.rot("body", AXX, 3.5 * math.sin(a)); r.rot("body", AXY, 2.0 * math.cos(2 * a))
            r.rot("head", AXY, -2.5 * math.cos(2 * a)); r.rot("head", AXZ, 3 * math.sin(a))
            r.rot("tail1", AXZ, 12 * math.sin(a)); r.rot("tail2", AXZ, 20 * math.sin(a - 0.8)); r.rot("tail3", AXZ, 24 * math.sin(a - 1.6))
            r.rot("watch", AXY, 16 * math.sin(2 * a + 0.4)); r.rot("earP", AXX, 4 * math.sin(2 * a)); r.rot("earN", AXX, -4 * math.sin(2 * a))
        else:
            k = [(-0.12, -0.07, -7, -10, 14, 24, 0.90, 1.06), (-0.22, -0.13, -11, -15, 24, 40, 0.86, 1.09), (0.20, 0.07, 8, 11, -42, -34, 1.10, 0.93), (0.10, 0.0, 7, 10, -18, -12, 1.03, 0.99), (0, 0, 0, 0, 0, 0, 1.0, 1.0)][min(int(t * 5), 4)]
            r.loc("root", (k[0], 0, k[1])); r.rot("body", AXY, k[2]); r.rot("head", AXY, k[3])
            r.rot("legFP", AXY, k[4]); r.rot("legFN", AXY, k[4]); r.rot("legBP", AXY, -k[4] * 0.6); r.rot("legBN", AXY, -k[4] * 0.6)
            r.rot("tail1", AXZ, k[5]); r.rot("tail2", AXZ, k[5] * 1.4); r.rot("tail3", AXZ, k[5] * 1.6); r.rot("watch", AXY, -k[3] * 1.6)
            r.rot("earP", AXX, -k[5] * 0.5); r.rot("earN", AXX, k[5] * 0.5)
            r.scale("body", k[6]) if False else None
            r.pb_scale("body", (k[7], 1.0, k[6]))
    elif kind == "dug":
        if state == "idle":
            br = math.sin(a)
            r.loc("root", (0, 0, 0.05 * br)); r.rot("body", AXY, 1.8 * math.sin(a - 0.4)); r.rot("bodyF", AXY, 2.2 * math.sin(a)); r.rot("head", AXY, 3 * math.sin(a + 0.6))
            r.rot("tail1", AXY, 8 * math.sin(a - 0.8)); r.rot("tail2", AXY, 15 * math.sin(a - 1.4))
            r.rot("flipP", AXX, 14 * br); r.rot("flipN", AXX, -14 * br)
            r.rot("stalk", AXY, 6 * math.sin(a - 0.8)); r.rot("lantern", AXY, 11 * math.sin(a - 1.5))
        elif state == "walk":
            r.loc("root", (0, 0, 0.07 * math.sin(a + 0.4)))
            r.rot("bodyF", AXY, 5 * math.sin(a + 0.5)); r.rot("body", AXY, 8 * math.sin(a)); r.rot("head", AXY, -4 * math.sin(a + 0.5))
            r.rot("tail1", AXY, 14 * math.sin(a - 0.7)); r.rot("tail2", AXY, 22 * math.sin(a - 1.4))
            r.rot("flipP", AXX, 21 * math.sin(a + 0.4)); r.rot("flipN", AXX, -21 * math.sin(a + 0.4))
            r.rot("stalk", AXY, 7 * math.sin(a - 0.6)); r.rot("lantern", AXY, 14 * math.sin(a - 1.3))
        else:
            k = [(-6, 0.02, 12, 6, 9, 1.04, 0.98), (-15, 0.08, 24, 14, 15, 1.08, 0.95), (10, -0.06, -16, -20, -22, 0.94, 1.07), (4, 0.0, -8, -9, -10, 0.99, 1.02), (0, 0, 0, 0, 0, 1.0, 1.0)][min(int(t * 5), 4)]
            r.rot("body", AXY, k[0] * 0.6); r.rot("bodyF", AXY, k[0]); r.loc("root", (0, 0, k[1])); r.rot("flipP", AXX, k[2]); r.rot("flipN", AXX, -k[2])
            r.rot("lantern", AXY, k[3]); r.rot("stalk", AXY, k[3] * 0.6); r.rot("tail1", AXY, k[4] * 0.6); r.rot("tail2", AXY, k[4] * 0.9); r.rot("head", AXY, -k[0] * 0.5)
            r.pb_scale("bodyF", (k[5], 1.0, k[6]))
    elif kind == "bird":
        if state == "idle":
            br = math.sin(a)
            r.loc("root", (0, 0, 0.025 * br)); r.rot("body", AXY, -1.2 * br); r.rot("neck", AXY, 4 * math.sin(a + 0.5)); r.rot("head", AXY, 6 * math.sin(a + 1.0))
            r.rot("crest", AXY, 10 * math.sin(a + 1.8)); r.rot("steam", AXZ, 11 * math.sin(a - 0.4)); r.rot("tail", AXY, 6 * math.sin(a - 0.7))
            r.rot("wingP", AXX, 7 * math.sin(a + 0.2)); r.rot("wingN", AXX, -7 * math.sin(a + 0.2))
            r.pb_scale("body", (1.0, 1.0, 1.0 + 0.016 * br))
        elif state == "walk":
            r.rot("legN", AXY, 26 * math.sin(a)); r.rot("legP", AXY, -26 * math.sin(a))
            r.loc("legN", (0, 0, 0.2 * max(0.0, -math.cos(a)))); r.loc("legP", (0, 0, 0.2 * max(0.0, math.cos(a))))
            r.loc("root", (0, 0, 0.08 * abs(math.sin(a)))); r.rot("body", AXX, 3 * math.sin(a)); r.rot("body", AXY, 2.5 * math.cos(2 * a))
            r.loc("neck", (0.11 * math.sin(a + 0.8), 0, 0)); r.rot("neck", AXY, -6 * math.sin(a + 0.8)); r.rot("head", AXY, 7 * math.sin(2 * a)); r.rot("crest", AXY, 15 * math.sin(2 * a + 0.9))
            r.rot("wingP", AXX, 16 * math.sin(2 * a)); r.rot("wingN", AXX, -16 * math.sin(2 * a)); r.rot("tail", AXY, 10 * math.sin(a - 0.8)); r.rot("steam", AXZ, 18 * math.sin(a - 0.6))
        else:
            k = [(-0.10, -0.04, -5, -10, 14, 1.0, 0.92), (-0.18, -0.07, -9, -18, 26, 1.0, 0.88), (0.22, 0.05, 6, 18, -18, 0.96, 1.08), (0.10, 0.0, 5, 12, -8, 1.0, 1.02), (0, 0, 0, 0, 0, 1.0, 1.0)][min(int(t * 5), 4)]
            r.loc("root", (k[0], 0, k[1])); r.rot("body", AXY, k[2]); r.rot("neck", AXY, k[3] * 0.6); r.rot("head", AXY, k[3])
            r.rot("crest", AXY, -k[3] * 0.9); r.rot("wingP", AXX, k[4]); r.rot("wingN", AXX, -k[4]); r.rot("tail", AXY, -k[2] * 1.4); r.rot("steam", AXZ, k[4] * 0.9)
            r.pb_scale("body", (k[5], 1.0, k[6]))
    else:  # bat
        if state == "idle":
            br = math.sin(a)
            r.loc("root", (0, 0, 0.014 * br)); r.rot("body", AXY, -1.0 * br); r.rot("head", AXY, 2.6 * math.sin(a + 0.6))
            r.rot("earA", AXX, 10 * math.sin(a + 0.3)); r.rot("earB", AXX, -10 * math.sin(a + 0.9))
            r.rot("tail1", AXZ, 8 * br); r.rot("tail2", AXZ, 17 * math.sin(a - 0.9)); r.pb_scale("body", (1.0, 1.0, 1.0 + 0.014 * br))
        elif state == "walk":
            for leg, ph in (("legFP", 0), ("legBN", 0), ("legFN", math.pi), ("legBP", math.pi)):
                r.rot(leg, AXY, 28 * math.sin(a + ph))
                r.loc(leg, (0, 0, 0.13 * max(0.0, -math.cos(a + ph))))
            r.loc("root", (0, 0, 0.06 * abs(math.sin(a)))); r.rot("body", AXX, 2.5 * math.sin(a)); r.rot("body", AXY, 2 * math.cos(2 * a))
            r.rot("head", AXY, -3.5 * math.cos(2 * a)); r.rot("head", AXZ, 3 * math.sin(a))
            r.rot("earA", AXX, 15 * math.sin(2 * a)); r.rot("earB", AXX, -15 * math.sin(2 * a + 0.6))
            r.rot("tail1", AXZ, 12 * math.sin(a)); r.rot("tail2", AXZ, 24 * math.sin(a - 0.8))
        else:
            k = [(-0.10, -0.05, -6, -8, 16, 1.0, 0.92), (-0.18, -0.09, -10, -14, 28, 1.0, 0.88), (0.18, 0.06, 7, 11, -28, 0.95, 1.1), (0.08, 0.0, 6, 9, -12, 1.0, 1.02), (0, 0, 0, 0, 0, 1.0, 1.0)][min(int(t * 5), 4)]
            r.loc("root", (k[0], 0, k[1])); r.rot("body", AXY, k[2]); r.rot("head", AXY, k[3])
            for leg in ("legFP", "legFN"):
                r.rot(leg, AXY, -k[4] * 0.8)
            r.rot("earA", AXX, k[4] * 0.6); r.rot("earB", AXX, -k[4] * 0.6); r.rot("tail1", AXZ, -k[4] * 0.5); r.rot("tail2", AXZ, -k[4]); r.pb_scale("body", (k[5], 1.0, k[6]))

# ---- bake ----
from PIL import Image, ImageFilter
import tempfile
basic_render_setup(SIZE * 2, samples=18)
sc = bpy.context.scene
sprite_camera(PPU * SIZE / 192.0, size=SIZE, origin=(105 * SIZE / 192.0, 173 * SIZE / 192.0), el=12.0)
tmp = os.path.join(tempfile.gettempdir(), "glbrig_%d.png" % os.getpid())
sc.render.filepath = tmp
def render_frame():
    bpy.ops.render.render(write_still=True)
    return Image.open(tmp).convert("RGBA").resize((SIZE, SIZE), Image.LANCZOS)
rig.arm.rotation_euler = (0, 0, math.radians(S["YAW"]))
def tinted(im, color, blur=9, grow=2):
    al = im.split()[3].filter(ImageFilter.MaxFilter(2 * grow + 1)).filter(ImageFilter.GaussianBlur(blur))
    glow = Image.new("RGBA", im.size, color + (0,)); glow.putalpha(al.point(lambda v: int(v * 0.85)))
    base = Image.new("RGBA", im.size, (0, 0, 0, 0)); base.alpha_composite(glow); base.alpha_composite(im)
    return base
if preview:
    os.makedirs(preview, exist_ok=True)
    sheet = Image.new("RGBA", (SIZE * 5, SIZE * 3), (30, 20, 60, 255))
    for row, state in enumerate(("idle", "walk", "attack")):
        for c in range(5):
            n = FRAMES[state]
            i = int(c * n / 5) if state != "attack" else c
            pose(rig, state, i / n)
            sheet.alpha_composite(render_frame(), (c * SIZE, row * SIZE))
    sheet.save(os.path.join(preview, name + "_anim_preview.png")); print("preview ok"); sys.exit(0)
os.makedirs(out_dir, exist_ok=True)
for state in ("idle", "walk", "attack"):
    for i in range(FRAMES[state]):
        pose(rig, state, i / FRAMES[state])
        im = render_frame()
        im.save(os.path.join(out_dir, f"{name}_{state}_{i}.png"))
        if state != "walk":
            tinted(im, (255, 214, 90)).save(os.path.join(out_dir, f"{name}_a_{state}_{i}.png"))
            tinted(im, (255, 96, 60)).save(os.path.join(out_dir, f"{name}_b_{state}_{i}.png"))
print("rig bake ok")
