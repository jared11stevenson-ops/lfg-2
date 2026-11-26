"""Tickindle hero model: static high-detail build from a reference pose (comparison against Tripo).
  python3 tickindle_hero.py <out.png> [view]"""
import sys, os, math, random
sys.path.insert(0, os.path.dirname(__file__))
from lib import *
import lib
from mathutils import Vector, Euler

random.seed(7)
def V(*a): return Vector(a)
def orient(d):
    d = Vector(d).normalized()
    e = Vector((0, 0, 1)).rotation_difference(d).to_euler()
    return tuple(math.degrees(a) for a in e)
def sp(c, rad, u):
    u = Vector(u).normalized()
    p = Vector(c) + Vector((rad[0] * u.x, rad[1] * u.y, rad[2] * u.z))
    n = Vector((u.x / rad[0], u.y / rad[1], u.z / rad[2])).normalized()
    return p, n
FLUFF = []
def tuft(name, base, d, length, rad, mat):
    d = Vector(d).normalized()
    FLUFF.append(name)
    return cone(name, tuple(base + d * length / 2), rad, 0.0, length, mat, rot=orient(d), outline=0, verts=8)

def pattern_mat(name, base, dark_hex, kind, shadow=(0.52, 0.42, 0.82)):
    m = toon_mat(name, base, shadow=shadow)
    nt = m.node_tree
    mul = [n for n in nt.nodes if n.bl_idname == 'ShaderNodeMix' and n.blend_type == 'MULTIPLY'][0]
    tc = nt.nodes.new('ShaderNodeTexCoord')
    if kind == "stripes":
        t = nt.nodes.new('ShaderNodeTexWave')
        t.wave_type = 'BANDS'; t.bands_direction = 'X'; t.wave_profile = 'SIN'
        t.inputs['Scale'].default_value = 4.2
        t.inputs['Distortion'].default_value = 5.0
        t.inputs['Detail'].default_value = 2.0
        t.inputs['Detail Scale'].default_value = 1.4
        t.inputs['Detail Roughness'].default_value = 0.6
        nt.links.new(tc.outputs['Object'], t.inputs['Vector'])
        out = t.outputs['Color']; lo, hi = 0.66, 0.74
    else:
        t = nt.nodes.new('ShaderNodeTexVoronoi')
        t.feature = 'DISTANCE_TO_EDGE'
        t.inputs['Scale'].default_value = 13.0
        nt.links.new(tc.outputs['Object'], t.inputs['Vector'])
        out = t.outputs['Distance']; lo, hi = 0.0, 0.0
    rp = nt.nodes.new('ShaderNodeValToRGB')
    if kind == "stripes":
        rp.color_ramp.elements[0].position = lo; rp.color_ramp.elements[0].color = (0, 0, 0, 1)
        rp.color_ramp.elements[1].position = hi; rp.color_ramp.elements[1].color = (1, 1, 1, 1)
    else:   # spots: cells whose centre-distance-to-edge is large become dark blobs (inverted ramp)
        rp.color_ramp.elements[0].position = 0.10; rp.color_ramp.elements[0].color = (1, 1, 1, 1)
        rp.color_ramp.elements[1].position = 0.13; rp.color_ramp.elements[1].color = (0, 0, 0, 1)
        # keep only a sparse subset of cells: modulate with noise
        nz = nt.nodes.new('ShaderNodeTexNoise'); nz.inputs['Scale'].default_value = 3.5
        nt.links.new(tc.outputs['Object'], nz.inputs['Vector'])
        r2 = nt.nodes.new('ShaderNodeValToRGB'); r2.color_ramp.elements[0].position = 0.46; r2.color_ramp.elements[1].position = 0.5
        nt.links.new(nz.outputs['Fac'], r2.inputs['Fac'])
        mm = nt.nodes.new('ShaderNodeMix'); mm.data_type = 'RGBA'; mm.blend_type = 'MULTIPLY'; mm.inputs['Factor'].default_value = 1.0
        nt.links.new(out, rp.inputs['Fac'])
        nt.links.new(rp.outputs['Color'], mm.inputs['A']); nt.links.new(r2.outputs['Color'], mm.inputs['B'])
        mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'
        mix.inputs['A'].default_value = hexc(base); mix.inputs['B'].default_value = hexc(dark_hex)
        nt.links.new(mm.outputs['Result'], mix.inputs['Factor'])
        nt.links.remove(mul.inputs['A'].links[0]) if mul.inputs['A'].links else None
        nt.links.new(mix.outputs['Result'], mul.inputs['A'])
        return m
    nt.links.new(out, rp.inputs['Fac'])
    mix = nt.nodes.new('ShaderNodeMix'); mix.data_type = 'RGBA'
    mix.inputs['A'].default_value = hexc(base); mix.inputs['B'].default_value = hexc(dark_hex)
    nt.links.new(rp.outputs['Color'], mix.inputs['Factor'])
    nt.links.new(mix.outputs['Result'], mul.inputs['A'])
    return m

reset()
fur = toon_mat("fur", "#9a7ecf", shadow=(0.52, 0.42, 0.82), spec=0.0)
furw = toon_mat("furw", "#b08fcf", shadow=(0.55, 0.42, 0.78))
furS = pattern_mat("furS", "#9a7ecf", "#4b3a8f", "stripes")
furH = pattern_mat("furH", "#9a7ecf", "#4b3a8f", "spots")
dark = toon_mat("stripe", "#4b3a8f", shadow=(0.4, 0.34, 0.75), rim=0.05)
cream = toon_mat("cream", "#ecd2d8", shadow=(0.7, 0.55, 0.7))
creamL = toon_mat("creamL", "#f6e6e0", shadow=(0.75, 0.6, 0.72))
pink = toon_mat("pink", "#ff86a6", spec=0.9)
pad = toon_mat("pad", "#d98aa8", shadow=(0.6, 0.4, 0.6))
gold = toon_mat("gold", "#f2b92a", shadow=(0.7, 0.42, 0.25), spec=0.8)
goldD = toon_mat("goldD", "#a8741a", shadow=(0.5, 0.3, 0.2))
ink = toon_mat("ink", "#1d1230", rim=0.0, ao=0.0)
tooth = toon_mat("tooth", "#ffffff", rim=0.0, ao=0.0)
white = toon_mat("whisk", "#f4eefc", rim=0.0, ao=0.0)

# ---------------- body ----------------
BC, BR = V(-0.05, 0, 0.84), (1.05, 0.62, 0.56)
ellipsoid("body", tuple(BC), BR, furS, outline=0, seg=64)
ellipsoid("shoulder", (0.55, 0, 0.84), (0.55, 0.62, 0.55), furS, outline=0)
ellipsoid("hip", (-0.7, 0, 0.84), (0.5, 0.6, 0.52), furS, outline=0)
ellipsoid("belly", (0.1, 0, 0.5), (0.9, 0.5, 0.3), cream, outline=0)

def body_pt(x, phi, out=1.0):
    k = 1 - ((x - BC.x) / BR[0]) ** 2
    s = math.sqrt(max(k, 0.01))
    return V(x, BR[1] * s * math.cos(phi) * out, BC.z + BR[2] * s * math.sin(phi) * out)

# back ridge fur
for k in range(26):
    x = -0.85 + k * 0.08
    p = body_pt(x, math.pi / 2, 0.97)
    tuft(f"ridge{k}", p, V(-0.45, 0, 1), random.uniform(0.12, 0.2), 0.08, furw)

# ---------------- legs ----------------
def leg(name, x, sy, front):
    y = sy * 0.46
    ellipsoid(name + "u", (x, y, 0.45), (0.27, 0.23, 0.44), furS, outline=0)
    ellipsoid(name + "p", (x + 0.12, y, 0.1), (0.36, 0.28, 0.14), cream, outline=0)
    for k in (-1, 0, 1):
        ellipsoid(f"{name}t{k}", (x + 0.43, y + k * 0.1 * sy * 0.9, 0.09), (0.09, 0.075, 0.075), cream, outline=0, seg=16)
        tube(f"{name}tl{k}", [(x + 0.4, y + k * 0.065 - 0.03, 0.16), (x + 0.36, y + k * 0.065 - 0.03, 0.04)], [0.008, 0.008], ink, outline=0, cap=False)
    for k in range(3):
        tuft(f"{name}ft{k}", V(x + 0.05, y + (k - 1) * 0.11, 0.27), V(0.2, (k - 1) * 0.3, -1), 0.17, 0.05, creamL)
    for k in range(3):
        ellipsoid(f"{name}s{k}", (x - 0.05, y + sy * 0.2, 0.62 - k * 0.12), (0.1, 0.03, 0.04), dark, outline=0, seg=10)
leg("fp", 0.78, 1, True); leg("fn", 0.78, -1, True)
leg("bp", -0.72, 1, False); leg("bn", -0.72, -1, False)

# ---------------- head ----------------
HC, HR = V(1.05, 0, 0.98), (0.58, 0.74, 0.52)
ellipsoid("head", tuple(HC), HR, furH, outline=0, seg=64)
# ears (low, round, tufted)
for sy in (1, -1):
    e = ellipsoid(f"ear{sy}", (0.9, sy * 0.52, 1.43), (0.2, 0.2, 0.22), fur, outline=0, rot=(sy * 15, 0, 0))
    ellipsoid(f"earin{sy}", (0.97, sy * 0.52, 1.42), (0.14, 0.14, 0.17), cream, outline=0, rot=(sy * 15, 0, 0))
    for k in range(5):
        tuft(f"eart{sy}{k}", V(1.0, sy * (0.46 + 0.03 * k), 1.38 + 0.02 * k), V(0.5, sy * 0.1, 0.5), 0.13, 0.04, creamL)
# face muzzle
ellipsoid("muzzle", (1.5, 0, 0.82), (0.22, 0.32, 0.2), creamL, outline=0)
ellipsoid("muzzleL", (1.45, 0.17, 0.8), (0.2, 0.2, 0.17), creamL, outline=0)
ellipsoid("muzzleR", (1.45, -0.17, 0.8), (0.2, 0.2, 0.17), creamL, outline=0)
ellipsoid("nose", (1.7, 0, 0.9), (0.075, 0.1, 0.06), pink, outline=0.008)
ellipsoid("nosebr", (1.73, 0, 0.92), (0.03, 0.04, 0.02), toon_mat("glossy", "#ffd0dc", glow=1.0), outline=0, seg=12)
tube("phil", [(1.69, 0, 0.86), (1.68, 0, 0.8)], [0.012, 0.012], ink, outline=0)
for sy in (1, -1):
    tube(f"mth{sy}", [(1.68, 0, 0.8), (1.66, sy * 0.1, 0.75), (1.6, sy * 0.2, 0.76), (1.52, sy * 0.28, 0.8)], [0.014] * 4, ink, outline=0)
    cone(f"fang{sy}", (1.655, sy * 0.095, 0.715), 0.028, 0.0, 0.095, tooth, rot=(180, 0, 0), outline=0.004)
    for k in range(5):
        ellipsoid(f"wp{sy}{k}", (1.6 - (k % 3) * 0.04, sy * (0.17 + 0.05 * (k // 3) + 0.03 * k), 0.87 - (k % 2) * 0.03), (0.012, 0.012, 0.012), ink, outline=0, seg=8)
    for k in range(5):
        a = [(-8, 4), (-2, 2), (4, -1), (10, -6), (16, -10)][k]
        tube(f"wh{sy}{k}", [(1.55, sy * 0.28, 0.86 - k * 0.025), (1.62, sy * 0.6, 0.9 - k * 0.04 + a[1] * 0.005), (1.5, sy * 1.0, 0.92 - k * 0.07 + a[1] * 0.01), (1.3, sy * 1.35, 0.9 - k * 0.1)], [0.01, 0.009, 0.007, 0.004], white, outline=0, cap=False)
# eyes: big glaring yellow slits
import faces
for sy in (1, -1):
    objs = faces.eye(f"he{sy}", (1.43, sy * 0.31, 1.07), 0.185, sy * 20, "#ffd23a", "#e8870e", pupil="slit")
    # eyelid (angled heavy scowl): fur slab angled down toward the nose
    ellipsoid(f"lid{sy}", (1.44, sy * 0.31, 1.2), (0.17, 0.25, 0.085), fur, outline=0.006, rot=(sy * -24, 0, sy * 20))
    tube(f"brow{sy}", [(1.37, sy * 0.6, 1.26), (1.46, sy * 0.38, 1.2), (1.55, sy * 0.1, 1.08)], [0.05, 0.062, 0.05], dark, outline=0.006)
    for k in range(4):
        tuft(f"bt{sy}{k}", V(1.38 + 0.03 * k, sy * (0.55 - 0.1 * k), 1.27 - 0.045 * k), V(0.2, sy * 0.4, 1), 0.11, 0.025, creamL)
# cheek ruff (big layered cream mane) + chin beard
rows = [(-0.2, 0.3, 0.05, 130), (-0.3, 0.26, 0.055, 110), (-0.4, 0.22, 0.05, 90)]
for ri, (e0, ln, rd, a_end) in enumerate(rows):
    n = 22
    for k in range(n + 1):
        a = math.radians((-1 if k % 2 else 1) * (60 + (a_end - 60) * (k // 2) / (n // 2)))
        e = math.radians(-18 - ri * 24 + 10 * math.sin(k * 1.7))
        p, nm = sp(HC, HR, V(math.cos(a) * math.cos(e), math.sin(a) * math.cos(e), math.sin(e)))
        d = nm * 0.8 + V(-0.25, 0, -0.45) + V(0, 0, 0)
        tuft(f"ruff{ri}_{k}", p * 0.97 + HC * 0.03, d, ln * random.uniform(0.9, 1.3), rd * 1.3, creamL if ri % 2 else cream)
for k in range(16):   # top-of-head/back-of-head fluff
    a = math.radians(-120 + 240 * k / 15)
    p, nm = sp(HC, HR, V(math.cos(a) * 0.7, math.sin(a) * 0.7, 0.7))
    tuft(f"crown{k}", p, nm + V(-0.3, 0, 0.2), 0.2, 0.06, furw)

# chest mane
for r_i in range(4):
    for k in range(13):
        a = math.radians(-70 + 140 * k / 12)
        p = V(1.05 + 0.1 * r_i, 0.5 * math.sin(a) * (1 - 0.08 * r_i), 0.62 - 0.09 * r_i + 0.04 * math.cos(a))
        tuft(f"chest{r_i}{k}", p, V(0.15, math.sin(a) * 0.5, -1), random.uniform(0.17, 0.26), 0.065, cream)

# ---------------- pocket watch ----------------
W = V(1.5, 0.05, 0.42)
cylinder("w_body", tuple(W), 0.29, 0.1, gold, rot=(0, 90, 0), outline=0.01)
torus("w_rim", tuple(W + V(0.05, 0, 0)), 0.285, 0.045, gold, rot=(0, 90, 0), outline=0.008)
torus("w_rim2", tuple(W + V(0.07, 0, 0)), 0.22, 0.015, goldD, rot=(0, 90, 0), outline=0)
cylinder("w_face", tuple(W + V(0.056, 0, 0)), 0.235, 0.05, toon_mat("wface", "#f6e8c4", rim=0.0), rot=(0, 90, 0), outline=0.006)
cylinder("w_crown", tuple(W + V(0, 0, 0.33)), 0.05, 0.08, gold, outline=0.006)
torus("w_loop", tuple(W + V(0, 0, 0.42)), 0.07, 0.022, gold, rot=(0, 90, 0), outline=0.006)
for k in range(12):
    a = k * math.pi / 6
    r_ = 0.19 if k % 3 else 0.175
    box(f"wt{k}", tuple(W + V(0.085, math.cos(a) * r_, math.sin(a) * r_)), (0.01, 0.014 if k % 3 else 0.022, 0.04 if k % 3 == 0 else 0.026), ink, rot=(math.degrees(a) + 90 - 90, 0, 0), outline=0)
tube("w_h1", [tuple(W + V(0.092, 0, 0)), tuple(W + V(0.092, 0.1, 0.1))], [0.02, 0.012], toon_mat("hand", "#d83a1a", rim=0.0), outline=0)
tube("w_h2", [tuple(W + V(0.092, 0, 0)), tuple(W + V(0.092, -0.02, 0.15))], [0.018, 0.01], ink, outline=0)
ellipsoid("w_hub", tuple(W + V(0.095, 0, 0)), (0.02, 0.025, 0.025), goldD, outline=0, seg=12)
# chain: links as small tori along the neck path
chain = [W + V(0, 0, 0.45), V(1.55, 0.28, 0.78), V(1.38, 0.5, 0.9), V(1.2, 0.62, 0.9)]
chain2 = [W + V(0, 0, 0.45), V(1.55, -0.28, 0.78), V(1.38, -0.5, 0.9), V(1.2, -0.62, 0.9)]
for ci, ch in enumerate((chain, chain2)):
    pts = lib._catmull([tuple(p) for p in ch], 4)
    for i, p in enumerate(pts):
        tg = (pts[min(i + 1, len(pts) - 1)] - pts[max(i - 1, 0)]).normalized()
        torus(f"link{ci}_{i}", tuple(p), 0.03, 0.011, gold, rot=orient(tg if i % 2 else tg.cross(V(0, 0, 1)) if abs(tg.z) < 0.9 else V(1, 0, 0)), outline=0)

# ---------------- tail + flame ----------------
tp = [(-1.05, 0, 0.9), (-1.5, 0.05, 0.72), (-1.78, 0.12, 1.0), (-1.7, 0.1, 1.5)]
tr = [0.24, 0.24, 0.23, 0.19]
tube("tail", tp, tr, fur, outline=0)
path = lib._catmull(tp, 12)
for i in range(6, len(path) - 4, 4):
    tg = (path[i + 1] - path[i - 1]).normalized()
    f = i / (len(path) - 1) * 3
    a_ = min(int(f), 2); rr = tr[a_] * (1 - (f - a_)) + tr[a_ + 1] * (f - a_)
    torus(f"tring{i}", tuple(path[i]), rr * 1.01, 0.05, dark, rot=orient(tg), outline=0)
    for k in range(8):
        a = k * math.pi / 4
        nb = tg.cross(V(0, 0, 1)).normalized() if abs(tg.z) < 0.9 else V(1, 0, 0)
        bt = tg.cross(nb)
        p = path[i] + (nb * math.cos(a) + bt * math.sin(a)) * rr
        tuft(f"tfur{i}_{k}", p, (nb * math.cos(a) + bt * math.sin(a)) * 0.7 - tg * 0.5, 0.15, 0.05, furw)
FP = V(*tp[-1])
flm = toon_mat("flame", "#ff7a1a", glow=2.4); flm2 = toon_mat("flame2", "#ffb52a", glow=3.0); flm3 = toon_mat("flame3", "#fff0a0", glow=4.0)
for k, (dx, h, w) in enumerate(((0, 0.28, 0.2), (-0.2, 0.18, 0.13), (0.2, 0.2, 0.13), (-0.3, 0.1, 0.09), (0.3, 0.12, 0.09))):
    teardrop(f"fl{k}", tuple(FP + V(dx * 0.5, 0.0, 0.2 + h * 0.2)), (w, w * 0.8, h), flm, outline=0.01, rot=(0, dx * 90, 0))
teardrop("fl_in", tuple(FP + V(0, 0, 0.2)), (0.13, 0.1, 0.17), flm2, outline=0)
teardrop("fl_core", tuple(FP + V(0, 0, 0.17)), (0.07, 0.06, 0.1), flm3, outline=0)
for k in range(7):
    ellipsoid(f"spark{k}", tuple(FP + V(random.uniform(-0.4, 0.4), random.uniform(-0.2, 0.2), random.uniform(0.5, 1.0))), (0.025,) * 3, flm2, outline=0, seg=8)

# ---------------- floating gears ----------------
def gear(name, c, R, rot, teeth=10):
    torus(name + "r", tuple(c), R, R * 0.28, gold, rot=rot, outline=0.008)
    q = Euler([math.radians(a) for a in rot]).to_quaternion()
    for k in range(teeth):
        a = 2 * math.pi * k / teeth
        loc = Vector(c) + q @ V(math.cos(a) * R * 1.3, math.sin(a) * R * 1.3, 0)
        box(f"{name}t{k}", tuple(loc), (R * 0.42, R * 0.42, R * 0.4), gold, rot=(rot[0], rot[1], rot[2] + math.degrees(a)), outline=0.004)
    cylinder(name + "hub", tuple(c), R * 0.35, R * 0.3, goldD, rot=rot, outline=0)
gear("g1", (2.55, 0.25, 1.05), 0.16, (80, 0, 70))
gear("g2", (2.4, 0.6, 0.66), 0.1, (75, 0, 65))
gear("g3", (2.85, 0.5, 0.82), 0.075, (80, 0, 60), 8)
torus("orbit", (2.6, 0.4, 0.85), 0.42, 0.012, toon_mat("orb", "#ffd070", glow=3.0), rot=(70, 20, 20), outline=0)
for k in range(9):
    ellipsoid(f"gs{k}", (2.6 + random.uniform(-0.45, 0.4), 0.4 + random.uniform(-0.4, 0.3), 0.82 + random.uniform(-0.45, 0.5)), (0.018,) * 3, toon_mat("gsp", "#ffe090", glow=3.5), outline=0, seg=8)

# ---------------- render ----------------
if __name__ == "__main__":
    out = sys.argv[1]
    view = sys.argv[2] if len(sys.argv) > 2 else "three_quarter"
    setup_render(res=1600, samples=40)
    sc = bpy.context.scene
    sc.render.resolution_x, sc.render.resolution_y = 1800, 1200
    sc.render.line_thickness = 5.0 * 1800 / 768.0 * 0.6
    coll = bpy.data.collections.new("Fluff"); sc.collection.children.link(coll)
    for n in FLUFF:
        o = bpy.data.objects.get(n)
        if o:
            for c in list(o.users_collection): c.objects.unlink(o)
            coll.objects.link(o)
    ls = bpy.context.view_layer.freestyle_settings.linesets[0]
    ls.select_by_collection = True; ls.collection = coll; ls.collection_negation = 'EXCLUDE'
    camera(view, 6.4, (0.45, 0, 1.0))
    sc.render.filepath = out
    bpy.ops.render.render(write_still=True)
    print("hero ok")
