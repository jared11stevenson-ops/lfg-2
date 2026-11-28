"""Icewake (frozen steam-whale airship): hovering swimmer with S-wave body, tail fluke, flippers, smokestack puff.
  python3 rig_icewake.py <preview|bake|meta> <out_dir>"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from rigkit import *

BONES = [("root", (0, 0, 0), (0, 0, 0.3), None, False),
    ("body", (-0.4, 0, 1.35), (0.5, 0, 1.4), "root", True), ("head", (0.5, 0, 1.4), (1.4, 0, 1.3), "body", True),
    ("stack", (0.0, 0, 2.0), (0.0, 0, 2.5), "body", True),
    ("flipP", (0.2, 0.55, 1.1), (0.45, 0.95, 0.8), "body", True), ("flipN", (0.2, -0.55, 1.1), (0.45, -0.95, 0.8), "body", True),
    ("tail1", (-0.4, 0, 1.35), (-0.9, 0, 1.4), "body", True), ("tail2", (-0.9, 0, 1.4), (-1.3, 0, 1.55), "tail1", True), ("tail3", (-1.3, 0, 1.55), (-1.6, 0, 1.8), "tail2", True)]
SPEC = dict(origin_dx=6, yaw_face=0, px_w=150, lift=0.5, bones=BONES, ratio=0.03, legs={})
ICE = dict(glb="/tmp/claude-0/gt/new/whale_ship.plain.glb", yaw=-32.0, spec=SPEC,
           counts={"idle": 8, "walk": 12, "attack": 8}, period={"idle": 2.6, "walk": 1.2, "attack": 0.9}, strike=3, walk_units=1.4)

def base(state, u):
    a = 2 * math.pi * u
    b = dict(rx=0.0, rz=0.0, w_body=0.0, w_head=0.0, w_t1=0.0, w_t2=0.0, w_t3=0.0, flip=0.0, s=1.0, sx=1.0, roll=0.0)
    if state in ("idle", "walk"):
        amp = 1.0 if state == "walk" else 0.5
        for nm, A, lag in (("w_body", 2.5, 0.0), ("w_head", -2.0, 0.4), ("w_t1", 8.0, 1.0), ("w_t2", 14.0, 1.5), ("w_t3", 20.0, 2.0)):
            b[nm] = amp * A * math.sin(a - lag)
        b.update(rz=(0.12 if state == "walk" else 0.07) * math.sin(a + 0.4), flip=amp * 22 * math.sin(a + 0.6), roll=amp * 2.5 * math.sin(a), s=1 + 0.015 * math.sin(a))
    else:
        T = [(0.0, 0), (0.16, 1), (0.32, 2), (0.44, 3), (0.62, 4), (0.82, 5), (1.0, 0)]
        P = {0: dict(rz=0, rx=0, hd=0, tl=0, fl=0, s=1.0),
             1: dict(rz=-0.05, rx=-0.06, hd=-5, tl=10, fl=-30, s=1.04),
             2: dict(rz=-0.1, rx=-0.12, hd=-10, tl=20, fl=-45, s=1.07),
             3: dict(rz=0.06, rx=0.28, hd=14, tl=-26, fl=50, s=0.96),
             4: dict(rz=0.02, rx=0.16, hd=5, tl=-10, fl=15, s=1.0),
             5: dict(rz=0.0, rx=0.04, hd=0, tl=2, fl=2, s=1.0)}
        for j in range(len(T) - 1):
            if u <= T[j + 1][0]:
                f = smoothstep((u - T[j][0]) / (T[j + 1][0] - T[j][0])); A, B = P[T[j][1]], P[T[j + 1][1]]
                L = lambda k: A[k] + (B[k] - A[k]) * f
                b.update(rz=L("rz"), rx=L("rx"), w_head=L("hd"), flip=L("fl"), s=L("s"), w_t1=L("tl") * 0.5, w_t2=L("tl") * 0.8, w_t3=L("tl"))
                break
    return b

def sim(state):
    period = ICE["period"][state]
    S = dict(stack=SOD(2.6, 0.25, 0.0), fP=SOD(3.5, 0.4, -0.6), fN=SOD(3.5, 0.4, -0.6))
    def fn(t, dt):
        u = (t / period) % 1.0
        b0 = base(state, u); b1 = base(state, (u + 0.004) % 1.0); b2 = base(state, (u - 0.004) % 1.0)
        vz = (b1["rz"] - b2["rz"]) / (0.008 * period); vx = (b1["rx"] - b2["rx"]) / (0.008 * period)
        out = {}
        out["stack"] = max(-30, min(30, S["stack"].step(dt, -14.0 * vz - 8.0 * vx)))
        out["fP"] = S["fP"].step(dt, b0["flip"]); out["fN"] = S["fN"].step(dt, b0["flip"])
        return out
    return run_loop(fn, period, 240, 3)

CACHE = {}
def pose(c, state, u, i, n):
    if state not in CACHE: CACHE[state] = sim(state)
    sec = sample(CACHE[state], u); b = base(state, u)
    c.move("root", (b["rx"], 0, b["rz"]))
    c.rot("body", AXY, b["w_body"]); c.rot("body", AXX, b["roll"]); c.rig.pb_scale("body", (1.0, 1.0, b["s"]))
    c.rot("head", AXY, b["w_head"])
    c.rot("tail1", AXY, b["w_t1"]); c.rot("tail2", AXY, b["w_t2"]); c.rot("tail3", AXY, b["w_t3"])
    c.rot("stack", AXZ, sec["stack"]); c.rot("flipP", AXX, sec["fP"]); c.rot("flipN", AXX, -sec["fN"])

ANCHORS = dict(muzzle=("attack", 0.44, "head", True), mouth=("idle", 0.0, "head", True), stack=("idle", 0.0, "stack", True))

if __name__ == "__main__":
    mode, out = sys.argv[1], sys.argv[2]
    c = Creature(ICE["glb"], ICE["spec"], "icewake")
    print("icewake bind s", round(c.bind_s, 1), "filled", c.missing, flush=True)
    if mode == "preview":
        c.bake(pose, ICE["counts"], None, "icewake", yaw=ICE["yaw"], preview=out)
    else:
        meta = os.path.join(os.path.dirname(__file__), "..", "..", "art", "blender", "meta", "icewake.json")
        c.bake(pose, ICE["counts"], out, "icewake", yaw=ICE["yaw"], anchors=ANCHORS, meta_extra=dict(strike=ICE["strike"], walk_units=ICE["walk_units"]), meta_path=os.path.abspath(meta), meta_only=(mode == "meta"))
    print("icewake rig done")
