"""Tickindle (Ember/Forge): grumpy manul cat + Hephaestus's automatons + pocket watch. Faces +X."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from lib import *

def build():
    reset()
    fur = toon_mat("fur", "#8a6bbd", shadow=(0.50, 0.40, 0.80))
    dark = toon_mat("furdark", "#5a3f95", shadow=(0.45, 0.38, 0.78))
    light = toon_mat("furlight", "#b79de8", shadow=(0.55, 0.45, 0.85))
    cream = toon_mat("cream", "#ffe9bf", shadow=(0.75, 0.55, 0.55))
    pink = toon_mat("pink", "#ff8fa8")
    gold = toon_mat("gold", "#ffcc3a", shadow=(0.75, 0.5, 0.3))
    eye = toon_mat("eye", "#ffe36a", rim=0.0)
    inkc = toon_mat("inkc", "#1d1230", rim=0.0)
    # body, belly, legs
    ellipsoid("body", (0, 0, 0.74), (0.74, 0.68, 0.68), fur)
    ellipsoid("belly", (0.3, 0, 0.62), (0.4, 0.55, 0.48), cream, outline=0)
    for sx, name in ((1, "f"), (-1, "b")):
        for sy in (-1, 1):
            x = 0.5 if sx > 0 else -0.42
            ellipsoid(f"leg_{name}{sy}", (x, sy * 0.38, 0.2), (0.24, 0.2, 0.3), dark)
            ellipsoid(f"paw_{name}{sy}", (x + 0.08, sy * 0.38, 0.05), (0.27, 0.22, 0.12), dark)
    # head: wide, flat, fluffy
    ellipsoid("head", (0.6, 0, 1.38), (0.72, 0.84, 0.56), fur)
    for sy in (-1, 1):
        ellipsoid(f"cheek{sy}", (0.52, sy * 0.78, 1.28), (0.34, 0.3, 0.3), light)
        ellipsoid(f"cheek2{sy}", (0.42, sy * 0.92, 1.2), (0.22, 0.2, 0.22), light)
        cone(f"ear{sy}", (0.34, sy * 0.52, 1.86), 0.24, 0.03, 0.42, fur, rot=(sy * -14, 8, 0))
        cone(f"earin{sy}", (0.4, sy * 0.52, 1.84), 0.13, 0.02, 0.3, pink, rot=(sy * -14, 8, 0), outline=0)
    # grumpy face
    for sy in (-1, 1):
        ellipsoid(f"eye{sy}", (1.0, sy * 0.34, 1.46), (0.17, 0.2, 0.19), eye, outline=0.012)
        ellipsoid(f"pupil{sy}", (1.15, sy * 0.34, 1.46), (0.035, 0.06, 0.15), inkc, outline=0)
        ellipsoid(f"glint{sy}", (1.17, sy * 0.3, 1.52), (0.025, 0.03, 0.04), toon_mat("glint", "#ffffff", glow=2.0), outline=0)
        # heavy brow, inner end lower = scowl
        tube(f"brow{sy}", [(0.98, sy * 0.62, 1.78), (1.04, sy * 0.36, 1.72), (1.08, sy * 0.1, 1.58)], [0.065, 0.075, 0.065], dark, outline=0.01)
        ellipsoid(f"lid{sy}", (1.0, sy * 0.34, 1.6), (0.19, 0.22, 0.07), fur, outline=0.01)
    ellipsoid("nose", (1.28, 0, 1.3), (0.08, 0.11, 0.06), pink, outline=0.008)
    tube("mouth", [(1.26, -0.2, 1.1), (1.29, -0.1, 1.16), (1.29, 0.1, 1.16), (1.26, 0.2, 1.1)], [0.026] * 4, inkc, outline=0)
    # pocket-watch chest plate
    cylinder("watch", (0.68, 0, 0.62), 0.28, 0.09, gold, rot=(0, 90, 0))
    cylinder("glass", (0.73, 0, 0.62), 0.22, 0.07, toon_mat("face", "#fff4d0", rim=0.0), rot=(0, 90, 0), outline=0.008)
    torus("bezel", (0.72, 0, 0.62), 0.28, 0.035, toon_mat("ember", "#ff8a2b", glow=1.4), rot=(0, 90, 0), outline=0)
    tube("hand_a", [(0.78, 0, 0.62), (0.78, 0.02, 0.76)], [0.022, 0.016], toon_mat("hand", "#c43c00", rim=0.0), outline=0)
    tube("hand_b", [(0.78, 0, 0.62), (0.78, -0.1, 0.58)], [0.022, 0.016], inkc, outline=0)
    tube("chain", [(0.76, 0.0, 0.92), (0.78, -0.25, 0.9), (0.66, -0.45, 0.82)], [0.025] * 3, gold, outline=0.008)
    # wind-up key on its back
    cylinder("keystem", (-0.4, 0, 1.32), 0.05, 0.3, gold, outline=0.01)
    for sy in (-1, 1):
        ellipsoid(f"key{sy}", (-0.4, sy * 0.15, 1.5), (0.05, 0.14, 0.12), gold, outline=0.01)
    # tail: curled candle with flame
    tube("tail", [(-0.78, 0, 0.55), (-1.15, 0.1, 0.42), (-1.45, 0.3, 0.7), (-1.38, 0.3, 1.12)], [0.2, 0.18, 0.14, 0.1], fur)
    teardrop("flame", (-1.38, 0.3, 1.2), (0.17, 0.17, 0.2), toon_mat("flame", "#ff8a2b", glow=2.2), outline=0.01)
    teardrop("flame_in", (-1.38, 0.3, 1.2), (0.09, 0.09, 0.12), toon_mat("flame2", "#ffe36a", glow=3.0), outline=0)
    return

if __name__ == "__main__":
    out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "art", "blender"))
    os.makedirs(out, exist_ok=True)
    build()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "tickindle.blend"))
    prefix = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(out, "tickindle")
    sheet(["side", "three_quarter", "front", "back"], prefix, ortho=3.6, target=(0, 0, 0.95))
    print("done tickindle")
