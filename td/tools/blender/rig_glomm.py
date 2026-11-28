"""Glomm (snow-globe frost crab): 4 IK walking legs, 2 FK claw arms, nodding face, snowglobe dome.
  python3 rig_glomm.py <glomm|glomm_alpha> <preview|bake|meta> <out_dir>"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from rigkit import *
from rig_others import legb, ctl, legs_spec

BONES = [("root", (0, 0, 0), (0, 0, 0.3), None, False),
    ("body", (-0.7, 0, 0.75), (0.45, 0, 0.8), "root", True), ("face", (0.45, 0, 0.8), (1.1, 0, 0.8), "body", True),
    ("dome", (0, 0, 1.5), (0, 0, 2.0), "body", True),
    ("clawP", (0.35, 0.75, 0.85), (0.85, 1.15, 0.45), "body", True), ("clawN", (0.35, -0.75, 0.85), (0.85, -1.15, 0.45), "body", True)]
BONES += legb("BP", (-0.85, 0.7, 0.65), (-0.97, 1.05, 0.42), (-0.97, 1.05, 0.1), "body") + legb("BN", (-0.85, -0.7, 0.65), (-0.97, -1.05, 0.42), (-0.97, -1.05, 0.1), "body")
BONES += legb("MP", (-0.2, 0.8, 0.65), (-0.2, 1.2, 0.42), (-0.2, 1.3, 0.1), "body") + legb("MN", (-0.2, -0.8, 0.65), (-0.2, -1.2, 0.42), (-0.2, -1.3, 0.1), "body")
BONES += ctl("BP", (-0.97, 1.05, 0.1), (-0.97, 1.9, 0.95)) + ctl("BN", (-0.97, -1.05, 0.1), (-0.97, -1.9, 0.95))
BONES += ctl("MP", (-0.2, 1.3, 0.1), (-0.2, 2.0, 0.95)) + ctl("MN", (-0.2, -1.3, 0.1), (-0.2, -2.0, 0.95))
GLOMM = dict(glb="/tmp/claude-0/gt/new/snow_monster.plain.glb", yaw=-32.0,
             spec=dict(origin_dx=10, yaw_face=0, px_w=138, lift=0.0, bones=BONES, ratio=0.03, legs=legs_spec(("BP", "BN", "MP", "MN"), dict(BP=1, BN=-1, MP=1, MN=-1))),
             counts={"idle": 8, "walk": 12, "attack": 8}, period={"idle": 2.6, "walk": 0.9, "attack": 0.85}, strike=3, walk_units=1.2)
NEUTRAL = {"BP": (0.0, 0.0), "BN": (0.0, 0.0), "MP": (0.0, 0.0), "MN": (0.0, 0.0)}
PHASE = {"BP": 0.0, "MN": 0.0, "BN": 0.5, "MP": 0.5}

def base(state, u):
    a = 2 * math.pi * u
    b = dict(rx=0.0, rz=0.0, body_p=0.0, body_r=0.0, face_p=0.0, claw=0.0, clawy=0.0, sc=1.0, scx=1.0)
    for k in PHASE: b["f_" + k] = (0.0, 0.0)
    if state == "idle":
        br = math.sin(a)
        b.update(rz=0.012 * br, sc=1 + 0.018 * br, face_p=2.0 * math.sin(a + 0.6), claw=5 * math.sin(a * 0.5 + 0.4), clawy=3 * math.sin(a + 1.0))
    elif state == "walk":
        for k, ph in PHASE.items():
            dx, dz = foot_offset(u + ph, 0.55, 0.2, 0.55)
            b["f_" + k] = (dx, dz)
        b.update(rz=0.04 * abs(math.sin(2 * a)) - 0.015, body_r=3.0 * math.sin(a), body_p=-1.5 * math.sin(2 * a), face_p=2.0 * math.sin(2 * a + 0.5), claw=7 * math.sin(a + 0.3), clawy=4 * math.sin(2 * a))
    else:
        T = [(0.0, 0), (0.14, 1), (0.30, 2), (0.42, 3), (0.60, 4), (0.80, 5), (1.0, 0)]
        P = {0: dict(rx=0, rz=0, bp=0, fp=0, cl=0, s=1.0, sx=1.0),
             1: dict(rx=-0.05, rz=-0.03, bp=-4, fp=-4, cl=-35, s=1.04, sx=0.99),
             2: dict(rx=-0.12, rz=-0.01, bp=-8, fp=-8, cl=-70, s=1.07, sx=0.98),
             3: dict(rx=0.26, rz=-0.05, bp=7, fp=12, cl=50, s=0.95, sx=1.06),
             4: dict(rx=0.18, rz=-0.02, bp=3, fp=4, cl=22, s=0.98, sx=1.03),
             5: dict(rx=0.05, rz=0.0, bp=0, fp=0, cl=4, s=1.0, sx=1.0)}
        for j in range(len(T) - 1):
            if u <= T[j + 1][0]:
                f = smoothstep((u - T[j][0]) / (T[j + 1][0] - T[j][0])); A, B = P[T[j][1]], P[T[j + 1][1]]
                L = lambda k: A[k] + (B[k] - A[k]) * f
                b.update(rx=L("rx"), rz=L("rz"), body_p=L("bp"), face_p=L("fp"), claw=L("cl"), sc=L("s"), scx=L("sx"))
                break
    return b

def sim(state):
    period = GLOMM["period"][state]
    S = dict(dome=SOD(3.0, 0.22, 0.0), cP=SOD(4.0, 0.35, 0.0), cN=SOD(4.0, 0.35, 0.0))
    def fn(t, dt):
        u = (t / period) % 1.0
        b0 = base(state, u); b1 = base(state, (u + 0.004) % 1.0); b2 = base(state, (u - 0.004) % 1.0)
        vx = (b1["rx"] - b2["rx"]) / (0.008 * period); vz = (b1["rz"] - b2["rz"]) / (0.008 * period)
        out = {}
        out["dome"] = max(-14, min(14, S["dome"].step(dt, -6.0 * vx - 16.0 * vz)))
        out["cP"] = S["cP"].step(dt, b0["claw"] - 5.0 * vz); out["cN"] = S["cN"].step(dt, b0["claw"] - 5.0 * vz)
        return out
    return run_loop(fn, period, 240, 3)

CACHE = {}
def pose(c, state, u, i, n):
    k = state
    if k not in CACHE: CACHE[k] = sim(state)
    sec = sample(CACHE[k], u); b = base(state, u)
    c.move("root", (b["rx"], 0, b["rz"]))
    c.rot("body", AXY, b["body_p"]); c.rot("body", AXX, b["body_r"]); c.rig.pb_scale("body", (b["scx"], b["scx"], b["sc"]))
    c.rot("face", AXY, b["face_p"]); c.rot("dome", AXY, sec["dome"])
    c.rot("clawP", AXY, b["claw"] * 0.8 + sec["cP"] * 0.4); c.rot("clawN", AXY, b["claw"] * 0.8 + sec["cN"] * 0.4)
    c.rot("clawP", AXZ, b["clawy"]); c.rot("clawN", AXZ, -b["clawy"])
    for kf, (nx, nz) in NEUTRAL.items():
        dx, dz = b["f_" + kf]
        c.foot(kf, nx + dx, nz + dz)

ANCHORS = dict(muzzle=("attack", 0.42, "face", True, (0.2, 0, -0.1)), mouth=("idle", 0.0, "face", True), dome=("idle", 0.0, "dome", True))

if __name__ == "__main__":
    who, mode, out = sys.argv[1], sys.argv[2], sys.argv[3]
    c = Creature(GLOMM["glb"], GLOMM["spec"], who)
    print(who, "bind s", round(c.bind_s, 1), "filled", c.missing, "poles", {k: (v[1], round(v[2], 3)) for k, v in c.constraints.items()}, flush=True)
    if mode == "preview":
        c.bake(pose, GLOMM["counts"], None, who, yaw=GLOMM["yaw"], preview=out)
    else:
        meta = os.path.join(os.path.dirname(__file__), "..", "..", "art", "blender", "meta", who + ".json")
        c.bake(pose, GLOMM["counts"], out, who, yaw=GLOMM["yaw"], anchors=ANCHORS, meta_extra=dict(strike=GLOMM["strike"], walk_units=GLOMM["walk_units"]), meta_path=os.path.abspath(meta), meta_only=(mode == "meta"))
    print(who, "rig done")
