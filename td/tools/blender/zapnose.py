"""Zapnose (Volt/Aether): caffeinated elephantnose fish + Nikola Tesla + doorbell. Rigged. Faces +X.
  python3 zapnose.py preview <prefix>   |   python3 zapnose.py bake <frames_dir>
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from rig import *

PPU = 50.0
NOSE = [(0.82, 0, 1.45), (1.2, 0, 1.3), (1.55, 0, 1.45), (1.68, 0, 1.78)]

def build(variant=""):
    reset()
    blue = toon_mat("blue", "#3b57e0", shadow=(0.40, 0.45, 0.85))
    bluel = toon_mat("bluel", "#a8bcff", shadow=(0.55, 0.6, 0.9))
    blued = toon_mat("blued", "#2a3fb0", shadow=(0.35, 0.4, 0.8))
    nosec = toon_mat("nosec", "#6c8cff", shadow=(0.45, 0.5, 0.9))
    yel = toon_mat("yel", "#ffd23a", shadow=(0.75, 0.55, 0.3))
    white = toon_mat("white", "#ffffff", rim=0.0)
    inkc = toon_mat("inkc", "#1d1230", rim=0.0)
    spark = toon_mat("spark", "#fff3a0", glow=3.0)
    btn = toon_mat("btn", "#ffe34a", glow=3.0)
    hairw = toon_mat("hairw", "#ffffff", shadow=(0.8, 0.8, 0.9))
    hairy = toon_mat("hairy", "#fff3a0", shadow=(0.8, 0.75, 0.5))
    r = Rig("ZapnoseRig")
    B = [("root", (0, 0, 0), (0, 0, 0.3), None), ("body", (0, 0, 1.0), (0, 0, 1.4), "root"), ("head", (0.45, 0, 1.5), (0.8, 0, 1.55), "body"),
         ("n1", NOSE[0], NOSE[1], "head"), ("n2", NOSE[1], NOSE[2], "n1"), ("n3", NOSE[2], NOSE[3], "n2"), ("button", (1.68, 0, 1.85), (1.68, 0, 2.05), "n3"),
         ("hairA", (0.3, -0.15, 1.85), (0.2, -0.15, 2.4), "head"), ("hairB", (0.4, 0, 1.9), (0.4, 0, 2.55), "head"), ("hairC", (0.5, 0.15, 1.85), (0.62, 0.15, 2.35), "head"),
         ("hairD", (0.2, 0.05, 1.8), (0.0, 0.05, 2.25), "head"),
         ("lidP", (0.75, 0.2, 1.85), (0.75, 0.2, 1.6), "head"), ("lidN", (0.75, -0.22, 1.78), (0.75, -0.22, 1.6), "head"), ("mouth", (0.82, 0, 1.3), (0.9, 0, 1.3), "head"),
         ("armP", (0.2, 0.5, 1.2), (0.3, 0.9, 1.0), "body"), ("armN", (0.2, -0.5, 1.2), (0.3, -0.9, 1.0), "body"),
         ("legP", (0.0, 0.22, 0.8), (0.08, 0.22, 0.05), "root"), ("legN", (0.0, -0.22, 0.8), (0.08, -0.22, 0.05), "root"),
         ("tailF", (-0.6, 0, 1.1), (-1.2, 0, 1.3), "body"), ("zap", (0.5, 0, 2.0), (0.5, 0, 2.2), "head")]
    r.bones(B)
    bind = r.bind
    bind(ellipsoid("body", (0, 0, 1.1), (0.64, 0.52, 0.56), blue), "body")
    bind(ellipsoid("belly", (0.25, 0, 0.98), (0.4, 0.4, 0.42), bluel, outline=0), "body")
    zz = tube("zigzag", [(-0.4, 0.5, 1.45), (-0.2, 0.52, 1.1), (0.0, 0.54, 1.45), (0.2, 0.52, 1.1), (0.4, 0.5, 1.4)], [0.05] * 5, yel, outline=0.006)
    bind(zz, "body")
    for cap in TUBE_CAPS:
        bind(cap, "body")
    bind(ellipsoid("head", (0.5, 0, 1.56), (0.44, 0.4, 0.38), blue), "head")
    # mismatched caffeinated bug eyes
    for sy, big, lid, z in ((1, 0.23, "lidP", 1.72), (-1, 0.16, "lidN", 1.66)):
        bind(ellipsoid(f"eye{sy}", (0.8, sy * 0.2, z), (big, big, big), white, outline=0.012), "head")
        bind(ellipsoid(f"pup{sy}", (0.8 + big * 0.92, sy * 0.2, z), (0.04, big * 0.4, big * 0.4), inkc, outline=0), "head")
        bind(ellipsoid(f"lid{sy}", (0.8, sy * 0.2, z + big * 0.55), (big * 1.15, big * 1.15, big * 0.7), blue, outline=0.01), lid)
    bind(ellipsoid("mouthbg", (0.86, 0, 1.3), (0.07, 0.14, 0.09), toon_mat("mo", "#5a1030", rim=0.0), outline=0.006), "mouth")
    gr = tube("grin", [(0.9, -0.16, 1.28), (0.94, -0.06, 1.24), (0.94, 0.06, 1.24), (0.9, 0.16, 1.28)], [0.014] * 4, inkc, outline=0)
    bind(gr, "head")
    for cap in TUBE_CAPS:
        bind(cap, "head")
    # long noodle nose ending in a glowing doorbell button (skinned)
    nz = tube("nose", NOSE, [0.15, 0.12, 0.1, 0.08], nosec)
    caps = list(TUBE_CAPS)
    r.skin_chain(nz, ["n1", "n2", "n3"], NOSE)
    bind(caps[0], "n1")
    bind(caps[1], "n3")
    bind(ellipsoid("button", (1.68, 0, 1.88), (0.19, 0.19, 0.19), btn, outline=0.01), "button")
    bind(torus("bring", (1.68, 0, 1.88), 0.16, 0.025, yel, rot=(90, 0, 0), outline=0.006), "button")
    # tesla-frizz hair (wild spikes)
    for nm, (x, y, z, h), mat in (("hairA", (0.3, -0.15, 2.0, 0.55), hairw), ("hairB", (0.4, 0, 2.08, 0.7), hairy), ("hairC", (0.5, 0.15, 2.0, 0.5), hairw), ("hairD", (0.2, 0.05, 1.95, 0.5), hairy)):
        bind(cone(nm, (x, y, z), 0.1, 0.0, h, mat, rot=(0, (x - 0.35) * -60, 0)), nm)
    # spindly arms and legs
    for sy, arm, leg in ((1, "armP", "legP"), (-1, "armN", "legN")):
        a = tube(f"arm{sy}", [(0.2, sy * 0.5, 1.2), (0.28, sy * 0.78, 1.15), (0.34, sy * 0.95, 0.98)], [0.07, 0.055, 0.05], blue, outline=0.008)
        bind(a, arm)
        for cap in TUBE_CAPS:
            bind(cap, arm)
        bind(ellipsoid(f"hand{sy}", (0.36, sy * 1.0, 0.94), (0.09, 0.09, 0.09), blue, outline=0.008), arm)
        lg = tube(f"leg{sy}", [(0.0, sy * 0.22, 0.85), (0.04, sy * 0.22, 0.45), (0.1, sy * 0.22, 0.08)], [0.06, 0.05, 0.045], yel, outline=0.008)
        bind(lg, leg)
        for cap in TUBE_CAPS:
            bind(cap, leg)
        bind(ellipsoid(f"foot{sy}", (0.2, sy * 0.22, 0.05), (0.2, 0.1, 0.045), yel, outline=0.008), leg)
    bind(ellipsoid("tailfin", (-0.95, 0, 1.2), (0.5, 0.06, 0.34), blued, rot=(0, -12, 0)), "tailF")
    # crackling sparks (scaled in on attack)
    for i, (x, y, z) in enumerate(((0.5, 0.55, 2.0), (0.5, -0.55, 2.05), (0.8, 0.0, 2.2))):
        bind(cone(f"spk{i}", (x, y, z), 0.05, 0.0, 0.34, spark, rot=(0, 20 * i, 30 * (i - 1)), outline=0), "zap")
    if variant == "a":    # Thunder Doorbell: giant doorbell + halo of lightning
        bind(ellipsoid("bigbtn", (1.68, 0, 1.88), (0.3, 0.3, 0.3), toon_mat("bigbtn", "#ffe34a", glow=2.6), outline=0.01), "button")
        for k in range(6):
            a = k * math.pi / 3
            bind(cone(f"bolt{k}", (1.68 + math.cos(a) * 0.5, 0, 1.88 + math.sin(a) * 0.5), 0.05, 0.0, 0.3, spark, rot=(0, math.degrees(a) - 90, 0), outline=0), "button")
    if variant == "b":    # Tesla's Gambit: copper coil crown + top-hat vibe
        bind(cylinder("coilbase", (0.4, 0, 2.05), 0.18, 0.12, toon_mat("copper", "#d88a4a"), outline=0.008), "head")
        for k in range(5):
            bind(torus(f"coil{k}", (0.4, 0, 2.15 + k * 0.1), 0.15 - k * 0.012, 0.03, toon_mat("copper", "#d88a4a"), outline=0.005), "head")
        bind(ellipsoid("coilball", (0.4, 0, 2.72), (0.14, 0.14, 0.14), spark, outline=0.006), "head")
        bind(tube("scarf", [(0.5, 0.3, 1.4), (0.4, 0.5, 1.25), (0.1, 0.5, 1.4)], [0.07] * 3, toon_mat("scarfr", "#e0463a"), outline=0.008), "body")
        for cap in TUBE_CAPS:
            bind(cap, "body")
    import faces
    faces.upgrade_zapnose(r, variant)
    return r

def pose(r, state, t):
    r.reset()
    ph = 2 * math.pi * t
    r.scale("zap", 0.01)
    r.scale("mouth", 0.01)
    if state == "idle":      # jittery, caffeinated
        r.loc("body", (0, 0, 0.03 * math.sin(2 * ph)))
        r.rot("head", AXZ, 7 * math.sin(4 * ph)); r.rot("head", AXY, 5 * math.sin(3 * ph))
        for i, b in enumerate(("hairA", "hairB", "hairC", "hairD")):
            r.rot(b, AXY, 16 * math.sin(4 * ph + i * 1.3))
        for i, b in enumerate(("n1", "n2", "n3")):
            r.rot(b, AXY, 8 * math.sin(2 * ph - i * 0.8))
        r.scale("button", 1.0 + 0.25 * math.sin(3 * ph))
        r.rot("armP", AXX, 20 * math.sin(3 * ph)); r.rot("armN", AXX, -20 * math.sin(3 * ph + 1))
        r.rot("tailF", AXZ, 14 * math.sin(3 * ph))
        if 0.45 < t < 0.55:
            for b in ("lidP", "lidN"):
                r.loc(b, (0, 0, -0.22))
    elif state == "walk":    # fast skitter
        s = math.sin(ph)
        r.loc("body", (0, 0, 0.07 * abs(math.sin(2 * ph))))
        r.rot("legP", AXY, 42 * s); r.rot("legN", AXY, -42 * s)
        r.rot("armP", AXX, 35 * s); r.rot("armN", AXX, -35 * s)
        for i, b in enumerate(("n1", "n2", "n3")):
            r.rot(b, AXY, 12 * math.sin(2 * ph - i * 0.9))
        for i, b in enumerate(("hairA", "hairB", "hairC", "hairD")):
            r.rot(b, AXY, 18 * math.sin(2 * ph + i * 1.1))
        r.rot("tailF", AXZ, 20 * math.sin(2 * ph))
        r.scale("button", 1.0 + 0.2 * math.sin(4 * ph))
    else:                    # attack: nose whip + lightning discharge
        k = math.sin(math.pi * t)
        r.loc("root", (0.12 * k, 0, 0))
        for i, b in enumerate(("n1", "n2", "n3")):
            r.rot(b, AXY, -30 * k * (1 - i * 0.2))
        r.scale("button", 1.0 + 1.3 * k)
        r.scale("zap", 0.01 + 1.0 * k)
        r.scale("mouth", 0.01 + 1.0 * k)
        for b in ("hairA", "hairB", "hairC", "hairD"):
            r.scale(b, 1.0 + 0.5 * k)
        r.rot("armP", AXX, 60 * k); r.rot("armN", AXX, -60 * k)
        for b in ("lidP", "lidN"):
            r.loc(b, (0, 0, 0.08 * k))

def finalize(r):
    r.make_actions(pose)

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "preview"
    out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "art", "blender"))
    if mode == "preview":
        r = build("")
        pose(r, "idle", 0.1)
        sheet(["side", "three_quarter", "front", "back"], sys.argv[2], ortho=4.4, target=(0, 0, 1.3))
        print("preview ok")
    else:
        for variant in ("", "a", "b"):
            r = build(variant)
            if variant == "":
                finalize(r)
                bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "zapnose.blend"))
            states = ("idle", "walk", "attack") if variant == "" else ("idle", "attack")
            bake_frames(r, pose, sys.argv[2], "zapnose" + ("_" + variant if variant else ""), PPU, states=states)
        print("bake ok")
