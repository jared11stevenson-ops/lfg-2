"""Tickindle (Ember/Forge): grumpy manul cat + Hephaestus's automatons + pocket watch. Rigged. Faces +X.
  python3 tickindle.py preview <prefix>      4-view still sheet
  python3 tickindle.py bake <frames_dir>     idle/walk/attack (+ evolved a/b) sprite frames
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from rig import *

PPU = 56.0   # sprite scale: pixels per world unit (matches the puppet sprite size in game)

def build(variant=""):
    reset()
    fur = toon_mat("fur", "#8a6bbd", shadow=(0.50, 0.40, 0.80))
    dark = toon_mat("furdark", "#5a3f95", shadow=(0.45, 0.38, 0.78))
    light = toon_mat("furlight", "#b79de8", shadow=(0.55, 0.45, 0.85))
    cream = toon_mat("cream", "#ffe9bf", shadow=(0.75, 0.55, 0.55))
    pink = toon_mat("pink", "#ff8fa8")
    gold = toon_mat("gold", "#ffcc3a", shadow=(0.75, 0.5, 0.3))
    steel = toon_mat("steel", "#9aa6c8", shadow=(0.5, 0.55, 0.8))
    eye = toon_mat("eye", "#ffe36a", rim=0.0)
    inkc = toon_mat("inkc", "#1d1230", rim=0.0)
    glint = toon_mat("glint", "#ffffff", glow=2.0)
    r = Rig("TickindleRig")
    B = [("root", (0, 0, 0), (0, 0, 0.3), None), ("body", (0, 0, 0.5), (0, 0, 1.0), "root"), ("head", (0.55, 0, 1.15), (0.95, 0, 1.4), "body"),
         ("earP", (0.34, 0.52, 1.72), (0.34, 0.52, 2.0), "head"), ("earN", (0.34, -0.52, 1.72), (0.34, -0.52, 2.0), "head"),
         ("browP", (1.0, 0.4, 1.7), (1.06, 0.1, 1.6), "head"), ("browN", (1.0, -0.4, 1.7), (1.06, -0.1, 1.6), "head"),
         ("lidP", (1.0, 0.34, 1.6), (1.0, 0.34, 1.4), "head"), ("lidN", (1.0, -0.34, 1.6), (1.0, -0.34, 1.4), "head"),
         ("roar", (1.26, 0, 1.12), (1.34, 0, 1.12), "head"),
         ("legFP", (0.5, 0.38, 0.42), (0.5, 0.38, 0.12), "root"), ("legFN", (0.5, -0.38, 0.42), (0.5, -0.38, 0.12), "root"),
         ("legBP", (-0.42, 0.38, 0.42), (-0.42, 0.38, 0.12), "root"), ("legBN", (-0.42, -0.38, 0.42), (-0.42, -0.38, 0.12), "root"),
         ("tail1", (-0.78, 0, 0.55), (-1.15, 0.1, 0.42), "body"), ("tail2", (-1.15, 0.1, 0.42), (-1.45, 0.3, 0.7), "tail1"),
         ("tail3", (-1.45, 0.3, 0.7), (-1.38, 0.3, 1.12), "tail2"), ("flame", (-1.38, 0.3, 1.15), (-1.38, 0.3, 1.45), "tail3"),
         ("watch", (0.68, 0, 0.62), (0.95, 0, 0.62), "body"), ("handA", (0.78, 0, 0.62), (0.78, 0, 0.78), "watch"),
         ("handB", (0.78, 0, 0.62), (0.78, -0.12, 0.58), "watch"), ("key", (-0.4, 0, 1.3), (-0.4, 0, 1.55), "body"),
         ("orbit", (0, 0, 1.9), (0, 0, 2.1), "body")]
    r.bones(B)
    bind = r.bind
    # --- body ---
    bind(ellipsoid("body", (0, 0, 0.74), (0.74, 0.68, 0.68), fur), "body")
    bind(ellipsoid("belly", (0.3, 0, 0.62), (0.4, 0.55, 0.48), cream, outline=0), "body")
    for name, x, bn in (("FP", 0.5, "legFP"), ("FN", 0.5, "legFN"), ("BP", -0.42, "legBP"), ("BN", -0.42, "legBN")):
        sy = 1 if name.endswith("P") else -1
        bind(ellipsoid(f"leg{name}", (x, sy * 0.38, 0.22), (0.24, 0.2, 0.3), dark), bn)
        bind(ellipsoid(f"paw{name}", (x + 0.08, sy * 0.38, 0.06), (0.27, 0.22, 0.12), dark), bn)
        for k in (-1, 0, 1):   # little claws
            bind(cone(f"claw{name}{k}", (x + 0.3, sy * 0.38 + k * 0.08, 0.05), 0.03, 0.0, 0.1, cream, rot=(0, 90, 0), outline=0), bn)
    # --- head ---
    bind(ellipsoid("head", (0.6, 0, 1.38), (0.72, 0.84, 0.56), fur), "head")
    for sy, bn in ((1, "earP"), (-1, "earN")):
        bind(ellipsoid(f"cheek{sy}", (0.52, sy * 0.78, 1.28), (0.34, 0.3, 0.3), light), "head")
        bind(ellipsoid(f"cheek2{sy}", (0.42, sy * 0.92, 1.2), (0.22, 0.2, 0.22), light), "head")
        tilt = (sy * -14, 8, 0) if sy > 0 else (sy * -14, 8, 0)
        bind(cone(f"ear{sy}", (0.34, sy * 0.52, 1.86), 0.24, 0.03, 0.42, fur, rot=(sy * -14, 8, sy * (10 if sy > 0 else 0))), bn)
        bind(cone(f"earin{sy}", (0.4, sy * 0.52, 1.84), 0.13, 0.02, 0.3, pink, rot=(sy * -14, 8, sy * (10 if sy > 0 else 0)), outline=0), bn)
        # whisker tufts
        for k in range(3):
            bind(tube(f"whisk{sy}{k}", [(1.2, sy * 0.58, 1.2 - k * 0.07), (1.22, sy * 0.85, 1.22 - k * 0.1), (1.12, sy * 1.12, 1.2 - k * 0.15)], [0.014] * 3, inkc, outline=0), "head")
        # big expressive eyes
        bind(ellipsoid(f"eye{sy}", (1.0, sy * 0.34, 1.46), (0.17, 0.2, 0.19), eye, outline=0.012), "head")
        bind(ellipsoid(f"pupil{sy}", (1.15, sy * 0.34, 1.46), (0.035, 0.06, 0.15), inkc, outline=0), "head")
        bind(ellipsoid(f"glint{sy}", (1.17, sy * 0.3, 1.52), (0.025, 0.03, 0.04), glint, outline=0), "head")
        brow = tube(f"brow{sy}", [(0.98, sy * 0.62, 1.78), (1.04, sy * 0.36, 1.72), (1.08, sy * 0.1, 1.58)], [0.065, 0.075, 0.065], dark, outline=0.01)
        bind(brow, "browP" if sy > 0 else "browN")
        for cap in TUBE_CAPS:
            bind(cap, "browP" if sy > 0 else "browN")
        bind(ellipsoid(f"lid{sy}", (1.0, sy * 0.34, 1.62), (0.19, 0.22, 0.1), fur, outline=0.01), "lidP" if sy > 0 else "lidN")
    # fur crown tuft: scruffy personality
    for k, (dy, h) in enumerate(((-0.2, 0.3), (0.0, 0.42), (0.2, 0.32))):
        bind(cone(f"tuft{k}", (0.4, dy, 1.9 + h * 0.1), 0.1, 0.0, h, fur, rot=(dy * -40, -12, 0)), "head")
    # band-aid on one cheek (tough but scruffy)
    bind(box("bandaid", (0.92, 0.66, 1.18), (0.16, 0.26, 0.05), toon_mat("bandaid", "#ffd2a8"), rot=(0, 0, -20), outline=0.01), "head")
    bind(ellipsoid("nose", (1.28, 0, 1.3), (0.08, 0.11, 0.06), pink, outline=0.008), "head")
    m = tube("mouth", [(1.26, -0.2, 1.1), (1.29, -0.1, 1.16), (1.29, 0.1, 1.16), (1.26, 0.2, 1.1)], [0.026] * 4, inkc, outline=0)
    bind(m, "head")
    for cap in TUBE_CAPS:
        bind(cap, "head")
    # roar mouth (scaled in during the attack)
    bind(ellipsoid("roar", (1.27, 0, 1.12), (0.12, 0.2, 0.13), toon_mat("roar", "#5a1030", rim=0.0), outline=0.01), "roar")
    for sy in (-1, 1):
        bind(cone(f"fang{sy}", (1.32, sy * 0.1, 1.2), 0.03, 0.0, 0.08, toon_mat("tooth", "#ffffff", rim=0.0), rot=(180, 0, 0), outline=0), "roar")
    # --- pocket watch ---
    bind(cylinder("watch", (0.68, 0, 0.62), 0.28, 0.09, gold, rot=(0, 90, 0)), "watch")
    bind(cylinder("glass", (0.73, 0, 0.62), 0.22, 0.07, toon_mat("face", "#fff4d0", rim=0.0), rot=(0, 90, 0), outline=0.008), "watch")
    bind(torus("bezel", (0.72, 0, 0.62), 0.28, 0.035, toon_mat("ember", "#ff8a2b", glow=1.4), rot=(0, 90, 0), outline=0), "watch")
    bind(tube("handA", [(0.78, 0, 0.62), (0.78, 0.0, 0.78)], [0.026, 0.018], toon_mat("hand", "#c43c00", rim=0.0), outline=0), "handA")
    for cap in TUBE_CAPS:
        bind(cap, "handA")
    bind(tube("handB", [(0.78, 0, 0.62), (0.78, -0.12, 0.58)], [0.026, 0.018], inkc, outline=0), "handB")
    for cap in TUBE_CAPS:
        bind(cap, "handB")
    bind(tube("chain", [(0.76, 0.0, 0.92), (0.78, -0.25, 0.9), (0.66, -0.45, 0.82)], [0.025] * 3, gold, outline=0.008), "body")
    for cap in TUBE_CAPS:
        bind(cap, "body")
    # --- wind-up key ---
    bind(cylinder("keystem", (-0.4, 0, 1.32), 0.05, 0.3, gold, outline=0.01), "key")
    for sy in (-1, 1):
        bind(ellipsoid(f"key{sy}", (-0.4, sy * 0.15, 1.5), (0.05, 0.14, 0.12), gold, outline=0.01), "key")
    # --- tail (skinned) + flame ---
    pts = [(-0.78, 0, 0.55), (-1.15, 0.1, 0.42), (-1.45, 0.3, 0.7), (-1.38, 0.3, 1.12)]
    t = tube("tail", pts, [0.2, 0.18, 0.14, 0.1], fur)
    caps = list(TUBE_CAPS)
    r.skin_chain(t, ["tail1", "tail2", "tail3"], pts)
    bind(caps[0], "tail1")
    bind(caps[1], "tail3")
    bind(teardrop("flame", (-1.38, 0.3, 1.2), (0.17, 0.17, 0.2), toon_mat("flame", "#ff8a2b", glow=2.2), outline=0.01), "flame")
    bind(teardrop("flame_in", (-1.38, 0.3, 1.2), (0.09, 0.09, 0.12), toon_mat("flame2", "#ffe36a", glow=3.0), outline=0), "flame")
    # --- evolved forms ---
    if variant == "a":    # Clockwork Pyre: goggles, orbiting gears, bigger flame
        for sy in (-1, 1):
            bind(torus(f"gog{sy}", (0.9, sy * 0.22, 1.82), 0.14, 0.04, gold, rot=(0, 90, 0), outline=0.008), "head")
            bind(cylinder(f"goglens{sy}", (0.92, sy * 0.22, 1.82), 0.12, 0.03, toon_mat("lens", "#9fe8ff", glow=0.6), rot=(0, 90, 0), outline=0), "head")
        bind(tube("strap", [(0.9, 0.36, 1.84), (0.4, 0.66, 1.8), (0.2, 0.0, 1.78), (0.4, -0.66, 1.8), (0.9, -0.36, 1.84)], [0.03] * 5, dark, outline=0.006), "head")
        for cap in TUBE_CAPS:
            bind(cap, "head")
        for i, (gx, gy) in enumerate(((-0.1, 1.15), (0.5, -1.2))):
            bind(torus(f"gear{i}", (gx, gy, 1.7), 0.22, 0.06, gold, rot=(90, 0, 0)), "orbit")
            for k in range(8):
                a = k * math.pi / 4
                bind(box(f"gt{i}{k}", (gx + math.cos(a) * 0.3, gy, 1.7 + math.sin(a) * 0.3), (0.08, 0.06, 0.08), gold, rot=(0, math.degrees(-a), 0), outline=0), "orbit")
    if variant == "b":    # Anvilmanul: steel pauldrons, red warband, anvil, molten seams
        for sy in (-1, 1):
            bind(ellipsoid(f"pauld{sy}", (0.12, sy * 0.78, 1.2), (0.32, 0.26, 0.24), steel), "body")
            for k in range(3):
                bind(cone(f"spike{sy}{k}", (0.12 + (k - 1) * 0.16, sy * 0.8, 1.45), 0.07, 0.0, 0.2, steel, outline=0.008), "body")
        bind(tube("warband", [(1.0, 0.3, 1.66), (0.6, 0.76, 1.7), (0.1, 0.5, 1.72), (0.1, -0.5, 1.72), (0.6, -0.76, 1.7), (1.0, -0.3, 1.66)], [0.05] * 6, toon_mat("band", "#e0463a"), outline=0.01), "head")
        for cap in TUBE_CAPS:
            bind(cap, "head")
        bind(box("anvil1", (-0.55, 0, 1.5), (0.5, 0.32, 0.12), steel), "body")
        bind(box("anvil2", (-0.55, 0, 1.38), (0.22, 0.2, 0.14), steel), "body")
        bind(cone("anvilhorn", (-0.22, 0, 1.5), 0.08, 0.0, 0.22, steel, rot=(0, 90, 0), outline=0.008), "body")
        for k in range(4):
            bind(ellipsoid(f"seam{k}", (0.2 - k * 0.2, 0.0, 1.43 - 0.04 * (k % 2)), (0.05, 0.12, 0.03), toon_mat("lava", "#ff6a1a", glow=2.5), outline=0), "body")
    return r

def pose(r, state, t):
    r.reset()
    ph = 2 * math.pi * t
    r.scale("roar", 0.01)
    for b in ("lidP", "lidN"):
        r.loc(b, (0, 0, -0.04))   # permanently heavy-lidded: grumpy
    if state == "idle":
        r.loc("body", (0, 0, 0.025 * math.sin(ph)))
        r.rot("tail1", AXZ, 9 * math.sin(ph))
        r.rot("tail2", AXZ, 13 * math.sin(ph - 0.7))
        r.rot("tail3", AXZ, 18 * math.sin(ph - 1.4))
        r.scale("flame", 1.0 + 0.14 * math.sin(3 * ph))
        r.rot("handA", AXX, -60 * t)
        r.rot("key", AXZ, 120 * t)
        r.rot("head", AXY, 3 * math.sin(ph))
        if 0.55 < t < 0.75:
            r.rot("earP", AXX, 22 * math.sin((t - 0.55) / 0.2 * math.pi))
        if 0.85 < t < 0.97:
            for b in ("lidP", "lidN"):
                r.loc(b, (0, 0, -0.2))
        r.rot("browP", AXY, 4 * math.sin(ph))
    elif state == "walk":
        s = math.sin(ph)
        r.loc("body", (0, 0, 0.05 * abs(math.sin(ph))))
        r.rot("legFP", AXY, 28 * s); r.rot("legBN", AXY, 28 * s)
        r.rot("legFN", AXY, -28 * s); r.rot("legBP", AXY, -28 * s)
        r.rot("body", AXX, 3 * s)
        r.rot("head", AXY, 4 * math.sin(2 * ph))
        r.rot("tail1", AXZ, 16 * s); r.rot("tail2", AXZ, 22 * math.sin(ph - 0.8)); r.rot("tail3", AXZ, 26 * math.sin(ph - 1.6))
        r.scale("flame", 1.0 + 0.16 * math.sin(4 * ph))
        r.rot("handA", AXX, -120 * t)
        r.rot("key", AXZ, 240 * t)
    else:  # attack: wind-up crouch then a roaring lunge
        wind = 1 - smooth(0.0, 0.4, t) if t < 0.4 else 0.0
        strike = math.sin(math.pi * min(1.0, max(0.0, (t - 0.3) / 0.7)))
        r.loc("root", (0.18 * strike - 0.08 * (1 - wind) * (1 if t < 0.4 else 0), 0, 0))
        r.loc("body", (0, 0, -0.1 * (smooth(0.0, 0.35, t) if t < 0.4 else 0) + 0.05 * strike))
        r.rot("body", AXY, -8 * strike + 6 * (smooth(0.0, 0.35, t) if t < 0.4 else 0))
        r.rot("head", AXY, -14 * strike)
        r.scale("roar", 0.01 + 1.0 * strike)
        for b, sgn in (("browP", 1), ("browN", 1)):
            r.rot(b, AXY, 24 * strike)
        for b in ("lidP", "lidN"):
            r.loc(b, (0, 0, 0.05 * strike))
        r.rot("earP", AXY, 20 * strike); r.rot("earN", AXY, 20 * strike)
        r.scale("flame", 1.0 + 0.8 * strike)
        r.rot("tail1", AXZ, 10 * strike); r.rot("tail2", AXY, -20 * strike); r.rot("tail3", AXY, -25 * strike)
        r.rot("key", AXZ, 720 * t)
        r.rot("handA", AXX, -360 * t)
        for b in ("legFP", "legFN"):
            r.rot(b, AXY, -20 * strike)

def finalize(r):
    r.make_actions(pose)

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "preview"
    out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "art", "blender"))
    if mode == "preview":
        prefix = sys.argv[2]
        r = build("")
        pose(r, "idle", 0.1)
        bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "tickindle.blend")) if False else None
        sheet(["side", "three_quarter", "front", "back"], prefix, ortho=3.6, target=(0, 0, 0.95))
        print("preview ok")
    else:
        frames = sys.argv[2]
        for variant in ("", "a", "b"):
            r = build(variant)
            if variant == "":
                finalize(r)
                bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "tickindle.blend"))
            states = ("idle", "walk", "attack") if variant == "" else ("idle", "attack")
            bake_frames(r, pose, frames, "tickindle" + ("_" + variant if variant else ""), PPU, states=states)
        print("bake ok")
