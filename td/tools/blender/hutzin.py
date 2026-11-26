"""Hutzin (Verdant/Venom): manic hoatzin + Baba Yaga's hut + teapot. Rigged. Faces +X.
  python3 hutzin.py preview <prefix>   |   python3 hutzin.py bake <frames_dir>
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from rig import *

PPU = 48.0

def build(variant=""):
    reset()
    green = toon_mat("green", "#8fd13a", shadow=(0.45, 0.6, 0.75))
    pale = toon_mat("pale", "#eaf7a8", shadow=(0.6, 0.7, 0.7))
    yel = toon_mat("yel", "#ffb82a", shadow=(0.7, 0.5, 0.35))
    orange = toon_mat("orange", "#ff6a2a", shadow=(0.7, 0.4, 0.4))
    gold = toon_mat("gold2", "#ffc83a", shadow=(0.7, 0.5, 0.35))
    blue = toon_mat("blue", "#4ad8ee", shadow=(0.4, 0.55, 0.85))
    brown = toon_mat("brown", "#a8743f", shadow=(0.55, 0.45, 0.5))
    brownd = toon_mat("brownd", "#5a3a1e", shadow=(0.5, 0.4, 0.5))
    red = toon_mat("red", "#d84a4a", shadow=(0.6, 0.4, 0.6))
    grey = toon_mat("grey", "#8a8a9a")
    inkc = toon_mat("inkc", "#1d1230", rim=0.0)
    white = toon_mat("white", "#ffffff", rim=0.0)
    ired = toon_mat("ired", "#d6362b", rim=0.0)
    lit = toon_mat("lit", "#ffe680", glow=2.5)
    steam = toon_mat("steam", "#d09aff", glow=1.6)
    r = Rig("HutzinRig")
    B = [("root", (0, 0, 0), (0, 0, 0.3), None), ("body", (0, 0, 1.05), (0, 0, 1.5), "root"), ("neck", (0.35, 0, 1.45), (0.6, 0, 1.9), "body"),
         ("head", (0.6, 0, 1.9), (0.95, 0, 1.95), "neck"), ("jaw", (0.95, 0, 1.86), (1.25, 0, 1.84), "head"),
         ("lidP", (0.9, 0.18, 2.12), (0.9, 0.18, 1.95), "head"), ("lidN", (0.9, -0.2, 2.07), (0.9, -0.2, 1.95), "head"),
         ("crestA", (0.52, -0.12, 2.12), (0.4, -0.12, 2.65), "head"), ("crestB", (0.58, 0, 2.18), (0.52, 0, 2.8), "head"), ("crestC", (0.62, 0.12, 2.12), (0.72, 0.12, 2.6), "head"),
         ("wingP", (0.1, 0.5, 1.2), (0.1, 1.0, 0.9), "body"), ("wingN", (0.1, -0.5, 1.2), (0.1, -1.0, 0.9), "body"),
         ("legP", (0, 0.25, 0.9), (0.1, 0.25, 0.05), "root"), ("legN", (0, -0.25, 0.9), (0.1, -0.25, 0.05), "root"),
         ("tailF", (-0.6, 0, 1.1), (-1.1, 0, 1.25), "body"),
         ("hut", (-0.15, 0, 1.55), (-0.15, 0, 2.0), "body"),
         ("st1", (-0.3, 0, 2.45), (-0.3, 0, 2.6), "hut"), ("st2", (-0.3, 0, 2.45), (-0.3, 0, 2.6), "hut"), ("st3", (-0.3, 0, 2.45), (-0.3, 0, 2.6), "hut")]
    r.bones(B)
    bind = r.bind
    bind(ellipsoid("body", (0, 0, 1.1), (0.64, 0.56, 0.6), green), "body")
    bind(ellipsoid("belly", (0.24, 0, 0.98), (0.4, 0.44, 0.44), pale, outline=0), "body")
    for sy, leg in ((1, "legP"), (-1, "legN")):
        lg = tube(f"leg{sy}", [(0.0, sy * 0.25, 0.9), (0.02, sy * 0.25, 0.5), (0.1, sy * 0.25, 0.08)], [0.07, 0.055, 0.05], yel, outline=0.01)
        bind(lg, leg)
        for cap in TUBE_CAPS:
            bind(cap, leg)
        bind(ellipsoid(f"foot{sy}", (0.18, sy * 0.25, 0.05), (0.2, 0.12, 0.05), yel), leg)
        for k in (-1, 0, 1):
            bind(cone(f"toe{sy}{k}", (0.4, sy * 0.25 + k * 0.1, 0.05), 0.04, 0.0, 0.16, yel, rot=(0, 90, 0), outline=0.006), leg)
        # wings with claws
        wg = tube(f"wing{sy}", [(0.1, sy * 0.5, 1.25), (0.12, sy * 0.78, 1.15), (0.1, sy * 1.0, 0.92)], [0.1, 0.08, 0.06], green, outline=0.01)
        wb = "wingP" if sy > 0 else "wingN"
        bind(wg, wb)
        for cap in TUBE_CAPS:
            bind(cap, wb)
        for k in (-1, 0, 1):
            bind(cone(f"claw{sy}{k}", (0.1 + k * 0.08, sy * 1.04, 0.86), 0.035, 0.0, 0.14, brownd, rot=(180, 0, 0), outline=0.006), wb)
    # neck, head, blue face, beak
    nk = tube("neck", [(0.3, 0, 1.5), (0.45, 0, 1.72), (0.6, 0, 1.92)], [0.2, 0.16, 0.15], green, outline=0.01)
    bind(nk, "neck")
    for cap in TUBE_CAPS:
        bind(cap, "neck")
    bind(ellipsoid("head", (0.74, 0, 1.97), (0.32, 0.27, 0.28), green), "head")
    bind(ellipsoid("face", (0.96, 0, 1.93), (0.14, 0.22, 0.22), blue, outline=0.01), "head")
    bind(cone("beakU", (1.12, 0, 1.92), 0.11, 0.0, 0.4, gold, rot=(0, 90, 0)), "head")
    bind(cone("beakL", (1.08, 0, 1.82), 0.08, 0.0, 0.3, gold, rot=(0, 90, 0)), "jaw")
    # manic mismatched bug eyes
    for sy, big, lid in ((1, 0.15, "lidP"), (-1, 0.1, "lidN")):
        z = 2.05 if sy > 0 else 2.0
        bind(ellipsoid(f"eye{sy}", (0.9, sy * 0.19, z), (big, big, big), white, outline=0.012), "head")
        bind(ellipsoid(f"iris{sy}", (0.9 + big * 0.85, sy * 0.19, z - 0.01), (0.05, big * 0.5, big * 0.5), ired, outline=0), "head")
        bind(ellipsoid(f"pup{sy}", (0.9 + big * 0.95, sy * 0.19, z - 0.02), (0.03, big * 0.25, big * 0.25), inkc, outline=0), "head")
        bind(ellipsoid(f"lid{sy}", (0.9, sy * 0.19, z + big * 0.55), (big * 1.15, big * 1.15, big * 0.7), green, outline=0.01), lid)
    # spiky mohawk crest (wobbles independently)
    for nm, (x, y, z, h), mat in (("crestA", (0.5, -0.12, 2.3, 0.5), orange), ("crestB", (0.55, 0, 2.38, 0.62), gold), ("crestC", (0.66, 0.12, 2.28, 0.46), orange)):
        bind(cone(nm, (x, y, z), 0.12, 0.0, h, mat, rot=(0, -12, 0)), nm)
    # teapot-hut on its back
    bind(ellipsoid("hutbody", (-0.15, 0, 1.78), (0.46, 0.42, 0.36), brown), "hut")
    bind(cone("roof", (-0.15, 0, 2.2), 0.62, 0.0, 0.55, red, rot=(0, 0, 45), verts=4), "hut")
    bind(ellipsoid("door", (-0.15, 0.4, 1.72), (0.13, 0.05, 0.19), brownd, outline=0.008), "hut")
    for sx in (-0.5, 0.2):
        bind(ellipsoid(f"win{sx}", (sx + 0.05, 0.38, 1.88), (0.07, 0.04, 0.08), lit, outline=0.006), "hut")
    bind(box("chimney", (-0.3, 0, 2.38), (0.16, 0.16, 0.34), grey), "hut")
    sp = tube("spout", [(-0.55, 0, 1.75), (-0.8, 0, 1.85), (-0.95, 0, 2.1)], [0.08, 0.065, 0.055], brown, outline=0.01)
    bind(sp, "hut")
    for cap in TUBE_CAPS:
        bind(cap, "hut")
    bind(ellipsoid("knob", (-0.15, 0, 2.5), (0.06, 0.06, 0.06), gold, outline=0.006), "hut")
    for i, (sz, bone) in enumerate(((0.1, "st1"), (0.13, "st2"), (0.09, "st3"))):
        bind(ellipsoid(f"steam{i}", (-0.3, 0, 2.6 + i * 0.05), (sz, sz, sz), steam, outline=0.006), bone)
    # tail feathers
    for i, (mat, ang, ln) in enumerate(((orange, 22, 0.55), (gold, 0, 0.62), (orange, -22, 0.55))):
        bind(ellipsoid(f"feather{i}", (-0.85, (i - 1) * 0.14, 1.2 + (1 - abs(i - 1)) * 0.08), (ln, 0.07, 0.15), mat, rot=(0, -12 + (i - 1) * 4, ang)), "tailF")
    if variant == "a":    # Brewmother: bubbling cauldron on the roof
        bind(ellipsoid("cauldron", (-0.15, 0, 2.7), (0.46, 0.44, 0.3), toon_mat("iron", "#2a2a3a", shadow=(0.4, 0.4, 0.6))), "hut")
        bind(torus("caurim", (-0.15, 0, 2.9), 0.4, 0.05, toon_mat("iron", "#2a2a3a"), outline=0.008), "hut")
        bind(ellipsoid("brew", (-0.15, 0, 2.93), (0.38, 0.36, 0.08), toon_mat("brew", "#b45cff", glow=2.0), outline=0), "hut")
        for i in range(4):
            bind(ellipsoid(f"bubble{i}", (-0.3 + i * 0.12, (i % 2) * 0.1, 3.05 + (i % 3) * 0.08), (0.07, 0.07, 0.07), toon_mat("bub", "#e0b0ff", glow=2.5), outline=0.006), "hut")
    if variant == "b":    # Walking Cottage: second storey with lit windows
        bind(box("floor2", (-0.15, 0, 2.55), (0.62, 0.56, 0.4), brown), "hut")
        bind(cone("roof2", (-0.15, 0, 3.0), 0.66, 0.0, 0.5, red, rot=(0, 0, 45), verts=4), "hut")
        for sx in (-0.4, 0.1):
            bind(box(f"win2{sx}", (sx, 0.3, 2.6), (0.12, 0.04, 0.14), lit, outline=0.006), "hut")
        bind(box("door2", (-0.15, 0.3, 2.45), (0.14, 0.04, 0.22), brownd, outline=0.006), "hut")
    return r

def pose(r, state, t):
    r.reset()
    ph = 2 * math.pi * t
    if state == "idle":
        r.loc("body", (0, 0, 0.03 * math.sin(ph)))
        r.rot("head", AXZ, 8 * math.sin(3 * ph)); r.rot("neck", AXY, 6 * math.sin(2 * ph))      # manic twitching
        r.rot("crestA", AXY, 12 * math.sin(2 * ph)); r.rot("crestB", AXY, 14 * math.sin(2 * ph - 1)); r.rot("crestC", AXY, 12 * math.sin(2 * ph - 2))
        r.rot("wingP", AXX, 14 * math.sin(3 * ph)); r.rot("wingN", AXX, -14 * math.sin(3 * ph + 1))
        r.rot("tailF", AXY, 8 * math.sin(ph))
        r.rot("hut", AXX, 2 * math.sin(ph))
        for i, b in enumerate(("st1", "st2", "st3")):
            u = (t + i / 3.0) % 1.0
            r.loc(b, (0.1 * math.sin(2 * math.pi * u), 0, 0.5 * u))
            r.scale(b, 0.2 + 0.8 * math.sin(math.pi * u))
        if 0.6 < t < 0.7:
            for b in ("lidP", "lidN"):
                r.loc(b, (0, 0, -0.17))
    elif state == "walk":
        s = math.sin(ph)
        r.loc("body", (0, 0, 0.06 * abs(math.sin(ph))))
        r.rot("legP", AXY, 32 * s); r.rot("legN", AXY, -32 * s)
        r.loc("neck", (0.07 * math.sin(2 * ph), 0, 0))
        r.rot("head", AXZ, 6 * math.sin(2 * ph))
        r.rot("wingP", AXX, 25 * math.sin(2 * ph)); r.rot("wingN", AXX, -25 * math.sin(2 * ph))
        r.rot("crestA", AXY, 14 * math.sin(2 * ph)); r.rot("crestB", AXY, 16 * math.sin(2 * ph - 0.8)); r.rot("crestC", AXY, 14 * math.sin(2 * ph - 1.6))
        r.rot("tailF", AXY, 14 * math.sin(2 * ph))
        r.rot("hut", AXX, 5 * s)
        for i, b in enumerate(("st1", "st2", "st3")):
            u = (t * 1.0 + i / 3.0) % 1.0
            r.loc(b, (-0.2 * u, 0, 0.45 * u)); r.scale(b, 0.2 + 0.8 * math.sin(math.pi * u))
    else:  # attack: lunge, beak open, wings flung wide, poison steam burst
        k = math.sin(math.pi * t)
        r.loc("root", (0.12 * k, 0, 0))
        r.rot("neck", AXY, 28 * k)
        r.rot("jaw", AXY, 24 * k)
        r.rot("wingP", AXX, 50 * k); r.rot("wingN", AXX, -50 * k)
        for b in ("crestA", "crestB", "crestC"):
            r.scale(b, 1.0 + 0.5 * k)
        r.rot("hut", AXX, -6 * k)
        for i, b in enumerate(("st1", "st2", "st3")):
            u = (t + i / 3.0) % 1.0
            r.loc(b, (0.15 * i * k, 0, 0.4 * u * (1 + 2 * k))); r.scale(b, (0.3 + 1.6 * k) * math.sin(math.pi * u) + 0.1)
        for b in ("lidP", "lidN"):
            r.loc(b, (0, 0, 0.07 * k))

def finalize(r):
    r.make_actions(pose)

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "preview"
    out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "art", "blender"))
    if mode == "preview":
        r = build("")
        pose(r, "idle", 0.1)
        sheet(["side", "three_quarter", "front", "back"], sys.argv[2], ortho=4.4, target=(0, 0, 1.4))
        print("preview ok")
    else:
        for variant in ("", "a", "b"):
            r = build(variant)
            if variant == "":
                finalize(r)
                bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "hutzin.blend"))
            states = ("idle", "walk", "attack") if variant == "" else ("idle", "attack")
            bake_frames(r, pose, sys.argv[2], "hutzin" + ("_" + variant if variant else ""), PPU, states=states)
        print("bake ok")
