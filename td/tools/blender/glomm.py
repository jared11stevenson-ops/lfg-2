"""Glomm (Stone/Frost): stoic hairy yeti-crab golem + Golem of Prague + snow globe. Rigged. Faces +X.
  python3 glomm.py preview <prefix>   |   python3 glomm.py bake <frames_dir>
"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from rig import *

PPU = 46.0

def build(variant=""):
    reset()
    stone = toon_mat("stone", "#6a8ce6", shadow=(0.34, 0.42, 0.85))
    stoned = toon_mat("stoned", "#4a62b8", shadow=(0.3, 0.36, 0.8))
    fur = toon_mat("fur", "#f2f8ff", shadow=(0.62, 0.72, 0.92))
    icy = toon_mat("icy", "#9be7ff", glow=2.2)
    brown = toon_mat("brown", "#a2763a", shadow=(0.55, 0.45, 0.5))
    green = toon_mat("green", "#3f9a4a")
    inkc = toon_mat("inkc", "#1d1230", rim=0.0)
    flake = toon_mat("flake", "#ffffff", glow=2.0)
    glass = glass_mat("glass", "#bfe8ff", 0.32)
    r = Rig("GlommRig")
    B = [("root", (0, 0, 0), (0, 0, 0.3), None), ("body", (0, 0, 0.85), (0.4, 0, 0.9), "root"),
         ("browB", (0.8, 0, 1.05), (0.9, 0, 1.05), "body"), ("lidP", (0.88, 0.28, 1.0), (0.88, 0.28, 0.85), "body"), ("lidN", (0.88, -0.28, 1.0), (0.88, -0.28, 0.85), "body"),
         ("clawP", (0.55, 0.62, 0.95), (1.0, 0.95, 0.9), "body"), ("clawN", (0.55, -0.62, 0.95), (1.0, -0.95, 0.9), "body"),
         ("thumbP", (1.2, 0.95, 0.9), (1.5, 0.95, 0.9), "clawP"), ("thumbN", (1.2, -0.95, 0.9), (1.5, -0.95, 0.9), "clawN"),
         ("globe", (0, 0, 1.55), (0, 0, 2.0), "body"), ("sn1", (0, 0, 1.9), (0, 0, 2.0), "globe"), ("sn2", (0, 0, 1.9), (0, 0, 2.0), "globe"), ("sn3", (0, 0, 1.9), (0, 0, 2.0), "globe"), ("sn4", (0, 0, 1.9), (0, 0, 2.0), "globe")]
    for i, x in enumerate((0.45, 0.0, -0.45)):
        B.append((f"legP{i}", (x, 0.55, 0.5), (x, 0.95, 0.08), "root"))
        B.append((f"legN{i}", (x, -0.55, 0.5), (x, -0.95, 0.08), "root"))
    r.bones(B)
    bind = r.bind
    bind(ellipsoid("body", (0, 0, 0.92), (0.98, 0.88, 0.72), stone), "body")
    # carved golem cracks that glow faintly
    for k, pts in enumerate((((-0.4, 0.2, 1.5), (-0.25, 0.3, 1.25), (-0.4, 0.4, 1.05)), ((0.3, -0.4, 1.5), (0.45, -0.3, 1.28), (0.3, -0.2, 1.1)))):
        ck = tube(f"crack{k}", [p for p in pts], [0.02] * 3, icy, outline=0)
        bind(ck, "body")
        for cap in TUBE_CAPS:
            bind(cap, "body")
    # heavy brow slab, glowing eyes, flat stoic mouth
    bind(box("brow", (0.8, 0, 1.08), (0.22, 1.0, 0.2), stoned, outline=0.012), "browB")
    for sy, lid in ((1, "lidP"), (-1, "lidN")):
        bind(ellipsoid(f"eye{sy}", (0.88, sy * 0.28, 0.93), (0.14, 0.16, 0.16), icy, outline=0.01), "body")
        bind(ellipsoid(f"lid{sy}", (0.87, sy * 0.28, 1.0), (0.13, 0.14, 0.08), stoned, outline=0.008), lid)
    mo = tube("mouth", [(0.92, -0.25, 0.6), (0.95, 0, 0.58), (0.92, 0.25, 0.6)], [0.03] * 3, inkc, outline=0)
    bind(mo, "body")
    for cap in TUBE_CAPS:
        bind(cap, "body")
    # frost fringe along the belly
    for k in range(14):
        a = k * 2 * math.pi / 14
        bind(cone(f"fringe{k}", (math.cos(a) * 0.92, math.sin(a) * 0.84, 0.28), 0.1, 0.0, 0.3, fur, rot=(math.degrees(math.sin(a)) * -0.7 + 180, math.degrees(math.cos(a)) * 0.7, 0), outline=0.006), "body")
    # big hairy claws
    for sy, claw, thumb in ((1, "clawP", "thumbP"), (-1, "clawN", "thumbN")):
        arm = tube(f"arm{sy}", [(0.55, sy * 0.6, 0.95), (0.8, sy * 0.8, 0.92), (1.0, sy * 0.95, 0.9)], [0.16, 0.14, 0.13], stone, outline=0.01)
        bind(arm, claw)
        for cap in TUBE_CAPS:
            bind(cap, claw)
        bind(ellipsoid(f"fist{sy}", (1.15, sy * 1.0, 0.9), (0.34, 0.3, 0.3), fur), claw)
        for k in range(8):
            a = k * math.pi / 4
            bind(cone(f"cfur{sy}{k}", (1.15 + math.cos(a) * 0.3, sy * 1.0, 0.9 + math.sin(a) * 0.3), 0.07, 0.0, 0.2, fur, rot=(0, math.degrees(a) - 90, 0), outline=0.005), claw)
        bind(cone(f"thumb{sy}", (1.46, sy * 1.0, 0.9), 0.1, 0.0, 0.34, fur, rot=(0, 90, 0), outline=0.008), thumb)
        # knuckle spikes
        if variant == "a":
            for k in range(3):
                bind(cone(f"knuck{sy}{k}", (1.0 + k * 0.14, sy * 1.0, 1.2), 0.07, 0.0, 0.24, toon_mat("rock", "#4a5578"), outline=0.008), claw)
    # six stubby crab legs
    for i, x in enumerate((0.45, 0.0, -0.45)):
        for sy, nm in ((1, "P"), (-1, "N")):
            lg = tube(f"leg{nm}{i}", [(x, sy * 0.55, 0.5), (x, sy * 0.8, 0.45), (x, sy * 0.95, 0.08)], [0.12, 0.1, 0.09], stoned, outline=0.01)
            bind(lg, f"leg{nm}{i}")
            for cap in TUBE_CAPS:
                bind(cap, f"leg{nm}{i}")
            bind(ellipsoid(f"foot{nm}{i}", (x, sy * 1.0, 0.06), (0.14, 0.14, 0.06), stoned, outline=0.008), f"leg{nm}{i}")
    # snow globe on its back
    bind(cylinder("gbase", (-0.1, 0, 1.56), 0.34, 0.2, brown), "globe")
    bind(ellipsoid("gball", (-0.1, 0, 2.1), (0.5, 0.5, 0.5), glass, outline=0), "globe")
    bind(cone("pine", (-0.1, 0, 2.0), 0.18, 0.0, 0.5, green, outline=0.008), "globe")
    bind(cone("pine2", (-0.1, 0, 2.2), 0.13, 0.0, 0.34, green, outline=0.006), "globe")
    for i in range(4):
        bind(ellipsoid(f"snow{i}", (-0.1 + (i - 1.5) * 0.12, (i % 2 - 0.5) * 0.2, 2.15 + (i % 3) * 0.08), (0.04, 0.04, 0.04), flake, outline=0), f"sn{i + 1}")
    if variant == "b":    # Snowglobe Blizzard: icicle crown and a swirling storm
        for k in range(8):
            a = k * math.pi / 4
            bind(cone(f"icicle{k}", (-0.1 + math.cos(a) * 0.45, math.sin(a) * 0.45, 2.7), 0.06, 0.0, 0.35, toon_mat("ice", "#cfefff", glow=0.8), rot=(180, 0, 0), outline=0.006), "globe")
        for k in range(10):
            a = k * 0.63
            bind(ellipsoid(f"storm{k}", (-0.1 + math.cos(a) * 0.32, math.sin(a) * 0.32, 1.85 + k * 0.05), (0.05, 0.05, 0.05), flake, outline=0), "globe")
    import faces
    faces.upgrade_glomm(r, variant)
    return r

def pose(r, state, t):
    r.reset()
    ph = 2 * math.pi * t
    legs = [f"leg{s}{i}" for i in range(3) for s in "PN"]
    if state == "idle":
        r.loc("body", (0, 0, 0.05 * math.sin(ph)))
        r.rot("clawP", AXZ, 9 * math.sin(ph)); r.rot("clawN", AXZ, -9 * math.sin(ph - 0.5))
        r.rot("browB", AXY, 5 * math.sin(2 * ph))
        r.rot("browB", AXY, 2 * math.sin(ph))
        for i, b in enumerate(("sn1", "sn2", "sn3", "sn4")):
            u = (t + i / 4.0) % 1.0
            r.loc(b, (0.1 * math.sin(2 * math.pi * u + i), 0.08 * math.cos(2 * math.pi * u), -0.35 * u + 0.1))
        if 0.78 < t < 0.9:
            for b in ("lidP", "lidN"):
                r.loc(b, (0, 0, -0.13))
    elif state == "walk":      # crab scuttle: alternating tripods
        s = math.sin(ph)
        r.loc("body", (0, 0, 0.05 * abs(math.sin(ph))))
        for i, b in enumerate(legs):
            side = 1 if "P" in b else -1
            r.rot(b, AXY, 30 * s * (1 if (i % 3 != 1) == (side > 0) else -1))
        r.rot("body", AXX, 4 * s)
        r.rot("clawP", AXZ, 12 * s); r.rot("clawN", AXZ, -12 * s)
        for i, b in enumerate(("sn1", "sn2", "sn3", "sn4")):
            u = (t + i / 4.0) % 1.0
            r.loc(b, (0.12 * math.sin(4 * math.pi * u + i), 0, -0.3 * u + 0.1))
    else:                      # attack: both claws raise, then slam
        k = math.sin(math.pi * t)
        up = smooth(0.0, 0.4, t) if t < 0.5 else 0.0
        slam = math.sin(math.pi * min(1.0, max(0.0, (t - 0.4) / 0.6)))
        r.loc("root", (0.1 * slam, 0, 0))
        r.rot("clawP", AXY, -40 * up + 55 * slam); r.rot("clawN", AXY, -40 * up + 55 * slam)
        r.rot("thumbP", AXZ, -25 * slam); r.rot("thumbN", AXZ, 25 * slam)
        r.rot("browB", AXY, 14 * k)
        r.scale("sn1", 1.0 + 0.8 * k)
        for b in ("lidP", "lidN"):
            r.loc(b, (0, 0, 0.05 * k))

def finalize(r):
    r.make_actions(pose)

if __name__ == "__main__":
    mode = sys.argv[1] if len(sys.argv) > 1 else "preview"
    out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "art", "blender"))
    if mode == "preview":
        r = build("")
        pose(r, "idle", 0.1)
        sheet(["side", "three_quarter", "front", "back"], sys.argv[2], ortho=4.4, target=(0, 0, 1.2))
        print("preview ok")
    else:
        for variant in ("", "a", "b"):
            r = build(variant)
            if variant == "":
                finalize(r)
                bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "glomm.blend"))
            states = ("idle", "walk", "attack") if variant == "" else ("idle", "attack")
            bake_frames(r, pose, sys.argv[2], "glomm" + ("_" + variant if variant else ""), PPU, states=states)
        print("bake ok")
