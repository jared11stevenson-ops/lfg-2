"""Dugloom (Tide/Spirit): sleepy dugong + selkie lore + lighthouse lamp. Faces +X."""
import sys, os
sys.path.insert(0, os.path.dirname(__file__))
from lib import *

def build():
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
    # chubby body
    ellipsoid("body", (0, 0, 0.9), (1.05, 0.74, 0.72), teal)
    ellipsoid("belly", (0.18, 0, 0.62), (0.82, 0.58, 0.46), belly, outline=0)
    # head + bulbous snout
    ellipsoid("head", (0.88, 0, 1.08), (0.56, 0.54, 0.5), teal)
    ellipsoid("snout", (1.33, 0, 0.9), (0.38, 0.42, 0.3), snout)
    for sy in (-1, 1):
        ellipsoid(f"nostril{sy}", (1.66, sy * 0.1, 0.99), (0.04, 0.05, 0.04), inkc, outline=0)
        cone(f"tusk{sy}", (1.5, sy * 0.15, 0.66), 0.05, 0.0, 0.2, white, rot=(180, 0, 0), outline=0.008)
        # sleepy half-lidded eyes
        ellipsoid(f"eye{sy}", (1.1, sy * 0.38, 1.2), (0.17, 0.17, 0.17), cream, outline=0.012)
        ellipsoid(f"pupil{sy}", (1.24, sy * 0.38, 1.16), (0.07, 0.075, 0.095), inkc, outline=0)
        ellipsoid(f"glint{sy}", (1.29, sy * 0.35, 1.2), (0.03, 0.035, 0.04), toon_mat("glint", "#ffffff", glow=2.0), outline=0)
        ellipsoid(f"lid{sy}", (1.1, sy * 0.38, 1.27), (0.19, 0.19, 0.095), deep, outline=0.01)
        ellipsoid(f"blush{sy}", (1.2, sy * 0.42, 0.98), (0.05, 0.11, 0.07), blush, outline=0)
        for k in range(3):
            tube(f"whisk{sy}{k}", [(1.6, sy * 0.22, 0.88 - k * 0.04), (1.62, sy * 0.45, 0.9 - k * 0.07 + 0.02), (1.58, sy * 0.7, 0.93 - k * 0.11)], [0.012] * 3, inkc, outline=0)
        # flippers act as arms
        ellipsoid(f"flip{sy}", (0.3, sy * 0.78, 0.55), (0.38, 0.1, 0.2), deep, rot=(0, 18, sy * 24))
    tube("smile", [(1.6, -0.14, 0.78), (1.64, -0.05, 0.75), (1.64, 0.05, 0.75), (1.6, 0.14, 0.78)], [0.016] * 4, inkc, outline=0)
    # tail and fluke
    tube("tailstock", [(-0.9, 0, 0.85), (-1.35, 0, 0.8), (-1.65, 0, 0.9)], [0.3, 0.2, 0.14], teal)
    for sy in (-1, 1):
        ellipsoid(f"fluke{sy}", (-1.82, sy * 0.36, 0.95), (0.3, 0.38, 0.06), deep, rot=(0, 0, sy * 28))
    # curly anglerfish lantern stalk
    tube("stalk", [(0.78, 0, 1.5), (0.55, 0, 1.95), (0.85, 0, 2.4), (1.25, 0, 2.38), (1.32, 0, 2.12)], [0.05] * 5, wood, outline=0.012)
    ellipsoid("bulb", (1.32, 0, 1.98), (0.17, 0.17, 0.2), toon_mat("lamp", "#ffe680", glow=3.0), outline=0.012)
    torus("cage", (1.32, 0, 1.98), 0.2, 0.018, wood, outline=0.006)
    torus("cage2", (1.32, 0, 1.98), 0.2, 0.018, wood, rot=(90, 0, 0), outline=0.006)
    # drifting wisps
    for i, p in enumerate(((-0.2, 0.75, 1.65), (-0.55, -0.7, 1.4), (0.2, -0.85, 1.85))):
        ellipsoid(f"wisp{i}", p, (0.07, 0.07, 0.07), toon_mat("wisp", "#bff6ff", glow=3.5), outline=0)

if __name__ == "__main__":
    out = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "art", "blender"))
    os.makedirs(out, exist_ok=True)
    build()
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(out, "dugloom.blend"))
    prefix = sys.argv[sys.argv.index("--") + 1] if "--" in sys.argv else os.path.join(out, "dugloom")
    sheet(["side", "three_quarter", "front", "back"], prefix, ortho=4.4, target=(0, 0, 1.1))
    print("done dugloom")
