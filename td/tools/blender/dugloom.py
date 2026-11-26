"""Dugloom (Tide/Spirit): sleepy dugong + selkie lore + lighthouse lamp. Rigged. Faces +X.
  python3 dugloom.py preview <prefix>     |     python3 dugloom.py bake <frames_dir>
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from rig import *

PPU = 44.0

def build(variant=""):
    reset()
    teal = toon_mat("teal", "#2fc4b8", shadow=(0.40, 0.55, 0.85))
    deep = toon_mat("deep", "#1f9a9e", shadow=(0.38, 0.5, 0.85))
    belly = toon_mat("belly", "#aaf2e0", shadow=(0.55, 0.7, 0.9))
    snout = toon_mat("snout", "#e0fbf2", shadow=(0.6, 0.7, 0.9))
    white = toon_mat("white", "#ffffff")
    inkc = toon_mat("inkc", "#1d1230", rim=0.0)
    blush = toon_mat("blush", "#ff9ab0", rim=0.0)
    cream = toon_mat("cream", "#fff6d8", rim=0.0)
    wood = toon_mat("wood", "#9a7a5a")
    glint = toon_mat("glint", "#ffffff", glow=2.0)
    cap_m = toon_mat("cap", "#4a5cff", shadow=(0.35, 0.4, 0.9))
    pom = toon_mat("pom", "#fff2f8", shadow=(0.7, 0.6, 0.8))
    r = Rig("DugloomRig")
    S = [(0.78, 0, 1.5), (0.55, 0, 1.95), (0.85, 0, 2.4), (1.25, 0, 2.38), (1.32, 0, 2.12)]
    B = [("root", (0, 0, 0), (0, 0, 0.3), None), ("body", (0, 0, 0.9), (0.5, 0, 0.9), "root"), ("head", (0.88, 0, 1.08), (1.25, 0, 1.0), "body"),
         ("lidP", (1.1, 0.38, 1.3), (1.1, 0.38, 1.1), "head"), ("lidN", (1.1, -0.38, 1.3), (1.1, -0.38, 1.1), "head"),
         ("mouthO", (1.62, 0, 0.76), (1.7, 0, 0.76), "head"), ("nosebub", (1.66, 0, 0.99), (1.8, 0, 0.99), "head"),
         ("flipP", (0.3, 0.78, 0.55), (0.3, 1.1, 0.4), "body"), ("flipN", (0.3, -0.78, 0.55), (0.3, -1.1, 0.4), "body"),
         ("tail1", (-0.9, 0, 0.85), (-1.35, 0, 0.8), "body"), ("tail2", (-1.35, 0, 0.8), (-1.65, 0, 0.9), "tail1"), ("fluke", (-1.72, 0, 0.92), (-2.05, 0, 0.95), "tail2"),
         ("s1", S[0], S[1], "head"), ("s2", S[1], S[2], "s1"), ("s3", S[2], S[3], "s2"), ("s4", S[3], S[4], "s3"),
         ("bulb", (1.32, 0, 1.98), (1.32, 0, 2.2), "s4"),
         ("wisp0", (-0.2, 0.75, 1.65), (-0.2, 0.75, 1.75), "body"), ("wisp1", (-0.55, -0.7, 1.4), (-0.55, -0.7, 1.5), "body"), ("wisp2", (0.2, -0.85, 1.85), (0.2, -0.85, 1.95), "body"),
         ("bub1", (0.95, 0.25, 1.85), (0.95, 0.25, 1.95), "head"), ("bub2", (0.75, -0.2, 1.85), (0.75, -0.2, 1.95), "head")]
    r.bones(B)
    bind = r.bind
    bind(ellipsoid("body", (0, 0, 0.9), (1.05, 0.74, 0.72), teal), "body")
    bind(ellipsoid("belly", (0.18, 0, 0.62), (0.82, 0.58, 0.46), belly, outline=0), "body")
    bind(ellipsoid("head", (0.88, 0, 1.08), (0.56, 0.54, 0.5), teal), "head")
    bind(ellipsoid("snout", (1.33, 0, 0.9), (0.38, 0.42, 0.3), snout), "head")
    for sy in (-1, 1):
        lid = "lidP" if sy > 0 else "lidN"
        flp = "flipP" if sy > 0 else "flipN"
        bind(ellipsoid(f"nostril{sy}", (1.66, sy * 0.1, 0.99), (0.04, 0.05, 0.04), inkc, outline=0), "head")
        bind(cone(f"tusk{sy}", (1.5, sy * 0.15, 0.66), 0.05, 0.0, 0.2, white, rot=(180, 0, 0), outline=0.008), "head")
        bind(ellipsoid(f"eye{sy}", (1.1, sy * 0.38, 1.2), (0.2, 0.2, 0.2), cream, outline=0.012), "head")
        bind(ellipsoid(f"pupil{sy}", (1.28, sy * 0.38, 1.16), (0.085, 0.09, 0.115), inkc, outline=0), "head")
        bind(ellipsoid(f"glint{sy}", (1.29, sy * 0.35, 1.2), (0.03, 0.035, 0.04), glint, outline=0), "head")
        bind(ellipsoid(f"lid{sy}", (1.1, sy * 0.38, 1.29), (0.22, 0.22, 0.11), deep, outline=0.01), lid)
        bind(ellipsoid(f"blush{sy}", (1.2, sy * 0.42, 0.98), (0.05, 0.11, 0.07), blush, outline=0), "head")
        for k in range(3):
            bind(tube(f"whisk{sy}{k}", [(1.6, sy * 0.22, 0.88 - k * 0.04), (1.62, sy * 0.45, 0.9 - k * 0.07 + 0.02), (1.58, sy * 0.7, 0.93 - k * 0.11)], [0.012] * 3, inkc, outline=0), "head")
        bind(ellipsoid(f"flip{sy}", (0.3, sy * 0.78, 0.55), (0.38, 0.1, 0.2), deep, rot=(0, 18, sy * 24)), flp)
        bind(ellipsoid(f"fluke{sy}", (-1.82, sy * 0.36, 0.95), (0.3, 0.38, 0.06), deep, rot=(0, 0, sy * 28)), "fluke")
    sm = tube("smile", [(1.6, -0.14, 0.78), (1.64, -0.05, 0.75), (1.64, 0.05, 0.75), (1.6, 0.14, 0.78)], [0.016] * 4, inkc, outline=0)
    bind(sm, "head")
    for cap in TUBE_CAPS:
        bind(cap, "head")
    bind(ellipsoid("mouthO", (1.66, 0, 0.74), (0.08, 0.14, 0.1), toon_mat("mo", "#5a1030", rim=0.0), outline=0.008), "mouthO")
    # nose bubble that breathes (sleepy)
    bind(ellipsoid("nosebub", (1.74, 0, 0.99), (0.1, 0.1, 0.1), toon_mat("bubble", "#e8fbff", glow=0.5), outline=0.008), "nosebub")
    # nightcap: droopy with pom-pom
    cp = [(0.5, 0, 1.5), (0.2, 0, 1.78), (-0.15, 0, 1.72), (-0.42, 0, 1.42)]
    cap = tube("nightcap", cp, [0.3, 0.24, 0.15, 0.06], cap_m, cap=False)
    bind(cap, "head")
    bind(ellipsoid("pom", (-0.44, 0, 1.36), (0.12, 0.12, 0.12), pom), "head")
    bind(torus("capband", (0.5, 0, 1.5), 0.3, 0.05, pom, rot=(0, 90, 0), outline=0.008), "head")
    # tail (skinned)
    tp = [(-0.9, 0, 0.85), (-1.35, 0, 0.8), (-1.65, 0, 0.9)]
    t = tube("tailstock", tp, [0.3, 0.2, 0.14], teal)
    caps = list(TUBE_CAPS)
    r.skin_chain(t, ["tail1", "tail2"], tp)
    bind(caps[0], "tail1")
    bind(caps[1], "tail2")
    # lantern stalk (skinned along 4 bones)
    st = tube("stalk", S, [0.05] * 5, wood, outline=0.012)
    caps = list(TUBE_CAPS)
    r.skin_chain(st, ["s1", "s2", "s3", "s4"], S)
    bind(caps[0], "s1")
    bind(caps[1], "s4")
    bind(ellipsoid("bulb", (1.32, 0, 1.98), (0.17, 0.17, 0.2), toon_mat("lamp", "#ffe680", glow=3.0), outline=0.012), "bulb")
    bind(torus("cage", (1.32, 0, 1.98), 0.2, 0.018, wood, outline=0.006), "bulb")
    bind(torus("cage2", (1.32, 0, 1.98), 0.2, 0.018, wood, rot=(90, 0, 0), outline=0.006), "bulb")
    for i, p in enumerate(((-0.2, 0.75, 1.65), (-0.55, -0.7, 1.4), (0.2, -0.85, 1.85))):
        bind(ellipsoid(f"wisp{i}", p, (0.07, 0.07, 0.07), toon_mat("wisp", "#bff6ff", glow=3.5), outline=0), f"wisp{i}")
    # dream bubbles
    bind(ellipsoid("bub1", (0.95, 0.25, 1.9), (0.1, 0.1, 0.1), toon_mat("dream", "#ffffff", glow=1.2), outline=0.008), "bub1")
    bind(ellipsoid("bub2", (0.75, -0.2, 1.9), (0.14, 0.14, 0.14), toon_mat("dream", "#ffffff", glow=1.2), outline=0.008), "bub2")
    if variant == "a":    # Beaconmaid: halo, pearl crown, brighter lamp
        bind(torus("halo", (1.32, 0, 2.55), 0.28, 0.04, toon_mat("halo", "#ffe36a", glow=2.5), outline=0.01), "bulb")
        for k in range(6):
            a = k * math.pi / 3
            bind(ellipsoid(f"pearl{k}", (0.9 + math.cos(a) * 0.3, math.sin(a) * 0.3, 1.62), (0.07, 0.07, 0.07), toon_mat("pearl", "#fff6f0", glow=0.5), outline=0.008), "head")
        bind(ellipsoid("bulbglow", (1.32, 0, 1.98), (0.3, 0.3, 0.3), toon_mat("lampglow", "#ffe680", glow=1.0), outline=0), "bulb")
    if variant == "b":    # Wreckwarden: barnacle shell, anchor, bigger tusks
        for k in range(3):
            bind(ellipsoid(f"shell{k}", (0.2 - k * 0.5, 0, 1.55 - 0.05 * k), (0.34 - k * 0.04, 0.5, 0.2), toon_mat("shell", "#8a6a4a"), rot=(0, -8 * k, 0)), "body")
            for j in range(3):
                bind(cone(f"barn{k}{j}", (0.2 - k * 0.5 + (j - 1) * 0.15, (j - 1) * 0.16, 1.72), 0.05, 0.0, 0.1, toon_mat("barn", "#e8e0c8"), outline=0.006), "body")
        bind(cylinder("anchorshaft", (0.3, 1.08, 0.5), 0.04, 0.5, toon_mat("iron", "#5a6080"), outline=0.008), "flipP")
        bind(torus("anchorring", (0.3, 1.08, 0.78), 0.06, 0.02, toon_mat("iron", "#5a6080"), rot=(90, 0, 0), outline=0.006), "flipP")
        bind(tube("anchorarm", [(0.1, 1.08, 0.3), (0.3, 1.08, 0.22), (0.5, 1.08, 0.3)], [0.04] * 3, toon_mat("iron", "#5a6080"), outline=0.008), "flipP")
        for cap in TUBE_CAPS:
            bind(cap, "flipP")
        for sy in (-1, 1):
            bind(cone(f"bigtusk{sy}", (1.55, sy * 0.2, 0.6), 0.06, 0.0, 0.3, white, rot=(180, 0, 0), outline=0.008), "head")
    return r

def pose(r, state, t):
    r.reset()
    ph = 2 * math.pi * t
    r.scale("mouthO", 0.01)
    for b in ("lidP", "lidN"):
        r.loc(b, (0, 0, -0.08))   # permanently droopy: sleepy
    r.scale("nosebub", 0.15 + 0.85 * (0.5 + 0.5 * math.sin(ph - 1.2)))
    if state == "idle":
        r.loc("body", (0, 0, 0.06 * math.sin(ph)))
        r.rot("tail1", AXZ, 8 * math.sin(ph)); r.rot("tail2", AXZ, 14 * math.sin(ph - 0.8)); r.rot("fluke", AXY, 16 * math.sin(ph - 1.6))
        r.rot("flipP", AXX, 12 * math.sin(ph)); r.rot("flipN", AXX, -12 * math.sin(ph))
        for i, b in enumerate(("s1", "s2", "s3", "s4")):
            r.rot(b, AXY, 6 * math.sin(ph - i * 0.7))
        r.scale("bulb", 1.0 + 0.16 * math.sin(2 * ph))
        r.rot("head", AXY, 3 * math.sin(ph - 0.5))
        if 0.62 < t < 0.9:      # slow sleepy blink
            for b in ("lidP", "lidN"):
                r.loc(b, (0, 0, -0.2 * math.sin((t - 0.62) / 0.28 * math.pi)))
        for i, b in enumerate(("wisp0", "wisp1", "wisp2")):
            r.loc(b, (0.1 * math.cos(ph + i * 2.1), 0.1 * math.sin(ph + i * 2.1), 0.08 * math.sin(2 * ph + i)))
        for i, b in enumerate(("bub1", "bub2")):
            u = (t + i * 0.5) % 1.0
            r.loc(b, (0, 0, 0.45 * u))
            r.scale(b, 0.15 + 0.85 * math.sin(math.pi * u))
    elif state == "walk":
        s = math.sin(ph)
        r.loc("body", (0, 0, 0.07 * abs(math.sin(ph))))
        r.rot("root", AXY, 4 * s)
        r.rot("tail1", AXZ, 14 * s); r.rot("tail2", AXZ, 22 * math.sin(ph - 0.8)); r.rot("fluke", AXY, 26 * math.sin(ph - 1.6))
        r.rot("flipP", AXX, 30 * s); r.rot("flipN", AXX, -30 * s)
        for i, b in enumerate(("s1", "s2", "s3", "s4")):
            r.rot(b, AXY, 10 * math.sin(ph - i * 0.8))
        r.scale("bulb", 1.0 + 0.12 * math.sin(2 * ph))
        for i, b in enumerate(("bub1", "bub2")):
            u = (t + i * 0.5) % 1.0
            r.loc(b, (0, 0, 0.4 * u)); r.scale(b, 0.15 + 0.85 * math.sin(math.pi * u))
    else:  # attack: lighthouse pulse
        k = math.sin(math.pi * t)
        r.loc("body", (-0.08 * (1 - smooth(0.0, 0.4, t)) * (1 if t < 0.4 else 0) + 0.1 * k, 0, 0.05 * k))
        r.scale("bulb", 1.0 + 1.4 * k)
        r.scale("mouthO", 0.01 + 1.0 * k)
        for b in ("lidP", "lidN"):
            r.loc(b, (0, 0, 0.12 * k + 0.08))      # eyes snap wide open
        for i, b in enumerate(("s1", "s2", "s3", "s4")):
            r.rot(b, AXY, -22 * k * (1 - i * 0.15))
        r.rot("flipP", AXX, 40 * k); r.rot("flipN", AXX, -40 * k)
        r.rot("fluke", AXY, 30 * k); r.rot("tail2", AXZ, 10 * k)
        for i, b in enumerate(("wisp0", "wisp1", "wisp2")):
            r.loc(b, (0.3 * k * math.cos(ph + i * 2.1), 0.3 * k * math.sin(ph + i * 2.1), 0.1 * k))
        r.scale("nosebub", 0.01)

def finalize(r):
    r.make_actions(pose)

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "preview"
    out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "art", "blender"))
    if mode == "preview":
        prefix = sys.argv[2]
        r = build("")
        pose(r, "idle", 0.1)
        sheet(["side", "three_quarter", "front", "back"], prefix, ortho=4.4, target=(0, 0, 1.1))
        print("preview ok")
    else:
        frames = sys.argv[2]
        for variant in ("", "a", "b"):
            r = build(variant)
            if variant == "":
                finalize(r)
                bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "dugloom.blend"))
            states = ("idle", "walk", "attack") if variant == "" else ("idle", "attack")
            bake_frames(r, pose, frames, "dugloom" + ("_" + variant if variant else ""), PPU, states=states)
        print("bake ok")
