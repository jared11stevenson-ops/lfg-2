"""Tickindle (Pallas's cat, Ember/Forge) rig + animation.  python3 rig_tickindle.py <preview|bake> <out_dir>"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from rigkit import *

GLB = "/tmp/claude-0/gt/cat_plain.glb"
COUNTS = {"idle": 8, "walk": 12, "attack": 8}
PERIOD = {"idle": 2.4, "walk": 0.8, "attack": 0.75}
GROUND = 0.05

def leg_bones(pfx, hip, knee, foot, parent):
    return [(pfx + "1", hip, knee, parent, True), (pfx + "2", knee, foot, pfx + "1", True)]

def ctrl(pfx, foot, pole):
    return [("ik_" + pfx, (foot[0], foot[1], foot[2]), (foot[0], foot[1], foot[2] + 0.18), None, False),
            ("pole_" + pfx, pole, (pole[0], pole[1], pole[2] + 0.1), None, False)]

BONES = [("root", (0, 0, 0), (0, 0, 0.3), None, False),
         ("hips", (-0.75, 0, 0.95), (0.0, 0, 0.97), "root", True),
         ("chest", (0.0, 0, 0.97), (0.8, 0, 0.98), "hips", True),
         ("head", (0.8, 0, 0.98), (1.3, 0, 0.95), "chest", True),
         ("earP", (1.0, 0.32, 1.3), (1.0, 0.4, 1.5), "head", True),
         ("earN", (1.0, -0.32, 1.3), (1.0, -0.4, 1.5), "head", True),
         ("tail1", (-0.8, 0, 0.85), (-0.98, 0, 0.55), "hips", True),
         ("tail2", (-0.98, 0, 0.55), (-1.2, 0, 0.9), "tail1", True),
         ("tail3", (-1.2, 0, 0.9), (-1.25, 0, 1.5), "tail2", True),
         ("watch", (1.05, 0, 0.72), (1.1, 0, 0.3), "chest", True)]
BONES += leg_bones("FP", (0.95, 0.42, 0.72), (0.93, 0.42, 0.40), (1.0, 0.42, GROUND), "chest")
BONES += leg_bones("FN", (0.95, -0.42, 0.72), (0.93, -0.42, 0.40), (1.0, -0.42, GROUND), "chest")
BONES += leg_bones("BP", (-0.5, 0.42, 0.72), (-0.42, 0.42, 0.40), (-0.55, 0.42, GROUND), "hips")
BONES += leg_bones("BN", (-0.5, -0.42, 0.72), (-0.42, -0.42, 0.40), (-0.55, -0.42, GROUND), "hips")
BONES += ctrl("FP", (1.0, 0.42, GROUND), (0.2, 0.42, 0.45)) + ctrl("FN", (1.0, -0.42, GROUND), (0.2, -0.42, 0.45))
BONES += ctrl("BP", (-0.55, 0.42, GROUND), (0.5, 0.42, 0.45)) + ctrl("BN", (-0.55, -0.42, GROUND), (0.5, -0.42, 0.45))

SPEC = dict(yaw_face=0, px_w=140, lift=0.0, bones=BONES, ratio=0.04, voxel=0.022,
            legs={k: dict(upper=k + "1", lower=k + "2", foot_ctrl="ik_" + k, pole="pole_" + k, bend=(-1 if k[0] == "F" else 1)) for k in ("FP", "FN", "BP", "BN")})
# lateral sequence (Muybridge, cat): RH, RF, LH, LF. P side = right.
PHASE = {"BP": 0.0, "FP": 0.25, "BN": 0.5, "FN": 0.75}

def base(state, u):
    """Kinematic key motion (units, degrees) for state at u in [0,1)."""
    a = 2 * math.pi * u
    b = dict(rx=0.0, rz=0.0, hip_p=0.0, hip_y=0.0, hip_r=0.0, ch_p=0.0, ch_y=0.0, ch_s=1.0, ch_sx=1.0, hd_p=0.0, hd_y=0.0, hd_x=0.0)
    for k in PHASE: b["f_" + k] = (0.0, 0.0)
    if state == "idle":
        br = math.sin(a)
        b.update(rz=0.012 * br, ch_s=1.0 + 0.022 * br, ch_p=0.8 * br, hd_p=1.2 * math.sin(a + 0.7), hd_y=1.5 * math.sin(a * 0.5 + 0.4), hip_y=1.0 * math.sin(a * 0.5))
    elif state == "walk":
        for k, ph in PHASE.items():
            dx, dz = foot_offset(u + ph, 0.55, 0.16, 0.65)
            b["f_" + k] = (dx, dz)
        b.update(rz=0.035 * math.cos(2 * a + 0.5), hip_y=5.5 * math.sin(a), ch_y=-5.5 * math.sin(a), hip_r=3.0 * math.sin(a + 0.4),
                 ch_p=2.2 * math.sin(2 * a + 1.0), hip_p=-2.0 * math.sin(2 * a + 1.0), hd_y=4.5 * math.sin(a), hd_p=-1.5 * math.sin(2 * a + 1.0))
    else:   # attack: crouch -> pounce -> land -> settle
        T = [(0.00, 0), (0.14, 1), (0.30, 2), (0.42, 3), (0.58, 4), (0.78, 5), (1.0, 0)]
        poses = {
            0: dict(rx=0.0, rz=0.0, ch_p=0, hip_p=0, hd_p=0, hd_x=0, ff=(0, 0), fb=(0, 0), s=1.0, sx=1.0),
            1: dict(rx=-0.04, rz=-0.08, ch_p=9, hip_p=-3, hd_p=-5, hd_x=-0.02, ff=(-0.08, 0), fb=(0.08, 0), s=1.04, sx=0.98),
            2: dict(rx=-0.13, rz=-0.15, ch_p=13, hip_p=-8, hd_p=-8, hd_x=-0.05, ff=(-0.12, 0), fb=(0.12, 0), s=1.06, sx=0.97),
            3: dict(rx=0.30, rz=0.09, ch_p=-9, hip_p=5, hd_p=6, hd_x=0.12, ff=(0.42, 0.14), fb=(-0.26, 0.05), s=1.02, sx=1.05),
            4: dict(rx=0.22, rz=-0.03, ch_p=7, hip_p=-4, hd_p=-4, hd_x=0.03, ff=(0.30, 0.0), fb=(-0.10, 0.0), s=0.94, sx=1.06),
            5: dict(rx=0.07, rz=-0.01, ch_p=1.5, hip_p=0, hd_p=0, hd_x=0.0, ff=(0.08, 0), fb=(-0.03, 0), s=1.0, sx=1.0),
        }
        # interpolate between key poses with slow-in/slow-out
        for j in range(len(T) - 1):
            if u <= T[j + 1][0]:
                f = smoothstep((u - T[j][0]) / (T[j + 1][0] - T[j][0]))
                A, B = poses[T[j][1]], poses[T[j + 1][1]]
                def L(k):
                    x, y = A[k], B[k]
                    return tuple(p + (q - p) * f for p, q in zip(x, y)) if isinstance(x, tuple) else x + (y - x) * f
                b.update(rx=L("rx"), rz=L("rz"), ch_p=L("ch_p"), hip_p=L("hip_p"), hd_p=L("hd_p"), hd_x=L("hd_x"), ch_s=L("s"), ch_sx=L("sx"))
                ff, fb = L("ff"), L("fb")
                for k in ("FP", "FN"): b["f_" + k] = ff
                for k in ("BP", "BN"): b["f_" + k] = fb
                break
    return b

def simulate(state):
    period = PERIOD[state]
    secs = {}
    def mk():
        return dict(tail=[SOD(2.6, 0.32, 0.0), SOD(2.9, 0.30, 0.0), SOD(3.3, 0.28, 0.0)], tailz=[SOD(2.4, 0.30, 0.0), SOD(2.7, 0.28, 0.0), SOD(3.0, 0.28, 0.0)],
                    earP=SOD(5.0, 0.35, -1.5), earN=SOD(4.6, 0.35, -1.5), watch=SOD(2.2, 0.28, 0.0), headlag=SOD(3.2, 0.5, 0.0))
    S = mk()
    def fn(t, dt):
        u = (t / period) % 1.0
        b0 = base(state, u); b1 = base(state, (u + 0.004) % 1.0); b2 = base(state, (u - 0.004) % 1.0)
        vx = (b1["rx"] - b2["rx"]) / (0.008 * period)
        vz = (b1["rz"] - b2["rz"]) / (0.008 * period)
        drv_p = -4.0 * vx - 8.0 * vz + b0["hip_p"] * -0.4
        drv_y = -b0["hip_y"] * 0.9
        out = {}
        x = drv_p
        for i, s in enumerate(S["tail"]):
            x = s.step(dt, x * (1.0 if i == 0 else 0.8)); out["t%d" % (i + 1)] = max(-38.0, min(38.0, x))
        x = drv_y
        for i, s in enumerate(S["tailz"]):
            x = s.step(dt, x * (1.0 if i == 0 else 0.9)); out["tz%d" % (i + 1)] = max(-35.0, min(35.0, x))
        out["earP"] = S["earP"].step(dt, -10.0 * vz - 2.5 * vx)
        out["earN"] = S["earN"].step(dt, -10.0 * vz - 2.5 * vx)
        out["watch"] = max(-28.0, min(28.0, S["watch"].step(dt, -7.0 * vx - 6.0 * vz + b0["ch_p"] * -0.8)))
        out["hd_lag"] = S["headlag"].step(dt, b0["hd_p"])
        return out
    return run_loop(fn, period, 240, 3)

CACHE = {}
def pose(c, state, u, i, n):
    if state not in CACHE: CACHE[state] = simulate(state)
    sec = sample(CACHE[state], u)
    b = base(state, u)
    c.move("root", (b["rx"], 0, b["rz"]))
    c.rot("hips", AXY, b["hip_p"]); c.rot("hips", AXZ, b["hip_y"]); c.rot("hips", AXX, b["hip_r"])
    c.rot("chest", AXY, b["ch_p"]); c.rot("chest", AXZ, b["ch_y"])
    c.rig.pb_scale("chest", (b["ch_sx"], b["ch_sx"], b["ch_s"]))
    c.rot("head", AXY, b["hd_p"] + 0.35 * (sec["hd_lag"] - b["hd_p"])); c.rot("head", AXZ, b["hd_y"]); c.move("head", (b["hd_x"], 0, 0))
    for k in ("tail1", "tail2", "tail3"):
        j = k[-1]
        c.rot(k, AXY, sec["t" + j]); c.rot(k, AXZ, sec["tz" + j])
    c.rot("earP", AXX, sec["earP"]); c.rot("earN", AXX, -sec["earN"])
    c.rot("watch", AXY, sec["watch"])
    for k in PHASE:
        dx, dz = b["f_" + k]
        c.foot(k, dx, dz)

if __name__ == "__main__":
    mode, out = sys.argv[1], sys.argv[2]
    c = Creature(GLB, SPEC, "tickindle")
    print("bind s", round(c.bind_s, 1), "unweighted filled", c.missing, "poles", {k: (v[1], round(v[2], 3)) for k, v in c.constraints.items()})
    if mode == "preview":
        c.bake(pose, COUNTS, None, "tickindle", yaw=-58.0, preview=out)
    else:
        meta = os.path.abspath(os.path.join(os.path.dirname(__file__), "..", "..", "art", "blender", "meta", "tickindle.json"))
        anchors = dict(muzzle=("attack", 0.42, "head", True, (0.2, 0, -0.1)), mouth=("idle", 0.0, "head", True), flame=("idle", 0.0, "tail3", True), paw=("attack", 0.42, "FP2", True))
        c.bake(pose, COUNTS, out, "tickindle", yaw=-58.0, anchors=anchors, meta_extra=dict(strike=3, walk_units=1.0), meta_path=meta, meta_only=(mode == "meta"))
    print("rig done")
