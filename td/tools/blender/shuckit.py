"""Shuckit (Umbra/Gale): cheeky bat-eared fox + Black Shuck + broken umbrella. Rigged. Faces +X. Level-1 enemy.
  python3 shuckit.py preview <prefix>   |   python3 shuckit.py bake <frames_dir>
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from rig import *

PPU = 52.0

def build(variant=""):
    reset()
    ink = toon_mat("ink", "#3a2f78", shadow=(0.32, 0.28, 0.70))
    inkd = toon_mat("inkd", "#241a58", shadow=(0.30, 0.26, 0.68))
    chest = toon_mat("chest", "#6a5cc8", shadow=(0.4, 0.35, 0.8))
    panel = toon_mat("panel", "#5446b0", shadow=(0.38, 0.34, 0.8))
    rib = toon_mat("rib", "#c8c4f0", shadow=(0.6, 0.6, 0.9))
    pink = toon_mat("pink", "#ff7a9a")
    glow = toon_mat("glow", "#fff3a0", glow=2.5)
    inkc = toon_mat("inkc", "#1d1230", rim=0.0)
    white = toon_mat("white", "#ffffff", rim=0.0)
    wisp = toon_mat("wisp", "#b48aff", glow=2.2)
    r = Rig("ShuckitRig")
    B = [("root", (0, 0, 0), (0, 0, 0.3), None), ("body", (-0.1, 0, 0.95), (0.6, 0, 0.98), "root"), ("head", (0.8, 0, 1.15), (1.2, 0, 1.25), "body"),
         ("jaw", (1.15, 0, 1.08), (1.45, 0, 1.02), "head"), ("tongue", (1.36, 0, 1.02), (1.4, 0, 0.78), "jaw"),
         ("earP", (0.78, 0.22, 1.5), (0.7, 0.36, 2.2), "head"), ("earN", (0.78, -0.22, 1.5), (0.7, -0.36, 2.2), "head"),
         ("lidP", (1.1, 0.2, 1.45), (1.1, 0.2, 1.25), "head"), ("lidN", (1.1, -0.2, 1.45), (1.1, -0.2, 1.25), "head"),
         ("legFP", (0.55, 0.17, 0.85), (0.55, 0.17, 0.08), "body"), ("legFN", (0.55, -0.17, 0.85), (0.55, -0.17, 0.08), "body"),
         ("legBP", (-0.5, 0.17, 0.85), (-0.5, 0.17, 0.08), "body"), ("legBN", (-0.5, -0.17, 0.85), (-0.5, -0.17, 0.08), "body"),
         ("tail1", (-0.7, 0, 1.0), (-1.1, 0, 1.1), "body"), ("tail2", (-1.1, 0, 1.1), (-1.45, 0, 1.35), "tail1"), ("tail3", (-1.45, 0, 1.35), (-1.6, 0, 1.75), "tail2")]
    r.bones(B)
    bind = r.bind
    bind(ellipsoid("body", (0, 0, 0.98), (0.82, 0.34, 0.31), ink), "body")
    bind(ellipsoid("chest", (0.5, 0, 0.9), (0.36, 0.28, 0.26), chest, outline=0), "body")
    bind(ellipsoid("hips", (-0.45, 0, 0.96), (0.34, 0.3, 0.29), ink), "body")
    bind(ellipsoid("head", (0.92, 0, 1.24), (0.38, 0.33, 0.3), ink), "head")
    bind(ellipsoid("snout", (1.3, 0, 1.15), (0.36, 0.16, 0.14), ink), "head")
    bind(ellipsoid("nose", (1.64, 0, 1.17), (0.08, 0.08, 0.07), inkc, outline=0.008), "head")
    bind(ellipsoid("jawl", (1.22, 0, 1.03), (0.28, 0.12, 0.06), inkd), "jaw")
    t = tube("tongue", [(1.34, 0, 1.03), (1.38, 0, 0.92), (1.4, 0.0, 0.8)], [0.07, 0.065, 0.055], pink, outline=0.008)
    bind(t, "tongue")
    for cap in TUBE_CAPS:
        bind(cap, "tongue")
    g = tube("grin", [(1.5, 0.12, 1.12), (1.42, 0.14, 1.07), (1.28, 0.15, 1.08), (1.12, 0.17, 1.14)], [0.014] * 4, inkc, outline=0)
    bind(g, "head")
    for cap in TUBE_CAPS:
        bind(cap, "head")
    for sy, ear, lid in ((1, "earP", "lidP"), (-1, "earN", "lidN")):
        # giant umbrella-panel ears with ribs and scalloped, torn tips
        bind(ellipsoid(f"ear{sy}", (0.78, sy * 0.28, 1.95), (0.07, 0.3, 0.62), ink, rot=(sy * 16, -10, 0)), ear)
        bind(ellipsoid(f"earin{sy}", (0.82, sy * 0.28, 1.9), (0.04, 0.2, 0.48), panel, rot=(sy * 16, -10, 0), outline=0), ear)
        for k in range(3):
            bind(ellipsoid(f"scal{sy}{k}", (0.74 - k * 0.01, sy * (0.46 - k * 0.17), 2.5 - 0.03 * k + 0.04 * (k % 2)), (0.06, 0.11, 0.1), ink, rot=(sy * 16, -10, 0)), ear)
        for k in (-1, 1):
            rb = tube(f"rib{sy}{k}", [(0.84, sy * (0.28 + 0.12 * k), 1.5), (0.84, sy * (0.3 + 0.16 * k), 2.0), (0.82, sy * (0.32 + 0.18 * k), 2.45)], [0.018] * 3, rib, outline=0)
            bind(rb, ear)
            for cap in TUBE_CAPS:
                bind(cap, ear)
        # mismatched, glowing, cheeky eyes (one bigger)
        big = 0.2 if sy > 0 else 0.15
        bind(ellipsoid(f"eye{sy}", (1.1, sy * 0.2, 1.34), (big, big, big), glow, outline=0.01), "head")
        bind(ellipsoid(f"pupil{sy}", (1.1 + big * 0.9, sy * 0.2, 1.33), (0.035, 0.05, 0.075), inkc, outline=0), "head")
        bind(ellipsoid(f"lid{sy}", (1.1, sy * 0.2, 1.34 + big * 0.6), (big * 1.15, big * 1.15, big * 0.7), ink, outline=0.01), lid)
    # one eyebrow cocked (mischief)
    bind(tube("brow1", [(1.04, 0.1, 1.55), (1.1, 0.22, 1.63), (1.08, 0.34, 1.56)], [0.03] * 3, inkc, outline=0), "head")
    for cap in TUBE_CAPS:
        bind(cap, "head")
    bind(tube("brow2", [(1.04, -0.1, 1.52), (1.08, -0.22, 1.54), (1.05, -0.34, 1.5)], [0.03] * 3, inkc, outline=0), "head")
    for cap in TUBE_CAPS:
        bind(cap, "head")
    # noodle legs with paws
    for name, x, sy, bone in (("FP", 0.55, 1, "legFP"), ("FN", 0.55, -1, "legFN"), ("BP", -0.5, 1, "legBP"), ("BN", -0.5, -1, "legBN")):
        lg = tube(f"leg{name}", [(x, sy * 0.17, 0.86), (x + 0.04, sy * 0.17, 0.5), (x + 0.02, sy * 0.17, 0.12)], [0.115, 0.085, 0.075], inkd)
        bind(lg, bone)
        for cap in TUBE_CAPS:
            bind(cap, bone)
        bind(ellipsoid(f"paw{name}", (x + 0.1, sy * 0.17, 0.06), (0.17, 0.12, 0.07), inkd), bone)
    # wispy tail
    pts = [(-0.7, 0, 1.0), (-1.1, 0, 1.1), (-1.45, 0, 1.35), (-1.6, 0, 1.75)]
    tl = tube("tail", pts, [0.13, 0.11, 0.08, 0.04], ink)
    caps = list(TUBE_CAPS)
    r.skin_chain(tl, ["tail1", "tail2", "tail3"], pts)
    bind(caps[0], "tail1")
    bind(caps[1], "tail3")
    bind(ellipsoid("tailwisp", (-1.6, 0, 1.84), (0.07, 0.07, 0.13), wisp, outline=0), "tail3")
    return r

def pose(r, state, t):
    r.reset()
    ph = 2 * math.pi * t
    if state == "idle":
        r.loc("body", (0, 0, 0.02 * math.sin(ph)))
        r.rot("earP", AXY, 8 * math.sin(ph)); r.rot("earN", AXY, 8 * math.sin(ph - 0.6))
        r.rot("tail1", AXZ, 8 * math.sin(ph)); r.rot("tail2", AXZ, 14 * math.sin(ph - 0.7)); r.rot("tail3", AXZ, 20 * math.sin(ph - 1.4))
        r.rot("tongue", AXY, 10 * math.sin(2 * ph))
        r.rot("head", AXX, 6 * math.sin(ph))      # cheeky head tilt
        if 0.7 < t < 0.85:
            for b in ("lidP", "lidN"):
                r.loc(b, (0, 0, -0.2))
    elif state == "walk":
        s = math.sin(ph)
        r.loc("body", (0, 0, 0.06 * abs(math.sin(ph))))
        r.rot("legFP", AXY, 34 * s); r.rot("legBN", AXY, 34 * s)
        r.rot("legFN", AXY, -34 * s); r.rot("legBP", AXY, -34 * s)
        r.rot("earP", AXY, 18 * math.sin(2 * ph - 0.8)); r.rot("earN", AXY, 18 * math.sin(2 * ph - 1.2))
        r.rot("tail1", AXZ, 14 * s); r.rot("tail2", AXZ, 22 * math.sin(ph - 0.8)); r.rot("tail3", AXZ, 30 * math.sin(ph - 1.6))
        r.rot("tongue", AXY, 22 * math.sin(2 * ph))
        r.rot("head", AXY, 5 * math.sin(2 * ph))
        r.rot("body", AXX, 2.5 * s)
    else:  # attack: pounce with a snarl
        k = math.sin(math.pi * t)
        r.loc("root", (0.25 * k, 0, 0.05 * k))
        r.rot("body", AXY, -10 * k)
        r.rot("jaw", AXY, 26 * k)
        r.rot("earP", AXY, -22 * k); r.rot("earN", AXY, -22 * k)
        r.rot("tail1", AXY, -14 * k); r.rot("tail2", AXY, -20 * k); r.rot("tail3", AXY, -24 * k)
        r.rot("legFP", AXY, -35 * k); r.rot("legFN", AXY, -35 * k)
        r.rot("legBP", AXY, 25 * k); r.rot("legBN", AXY, 25 * k)
        for b in ("lidP", "lidN"):
            r.loc(b, (0, 0, 0.06 * k))

def finalize(r):
    r.make_actions(pose)

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "preview"
    out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "art", "blender"))
    r = build("")
    if mode == "preview":
        pose(r, "idle", 0.1)
        sheet(["side", "three_quarter", "front", "back"], sys.argv[2], ortho=4.2, target=(0, 0, 1.0))
        print("preview ok")
    else:
        finalize(r)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "shuckit.blend"))
        bake_frames(r, pose, sys.argv[2], "shuckit", PPU)
        print("bake ok")
