"""Shuckit (bat-eared fox), Hutzin (hoatzin teapot-bird), Dugloom (dugong) rigs + animation.
  python3 rig_others.py <shuckit|hutzin|dugloom> <preview|bake> <out_dir>"""
import sys, os, math
sys.path.insert(0, os.path.dirname(__file__))
from rigkit import *

def legb(pfx, hip, knee, foot, parent):
    return [(pfx + "1", hip, knee, parent, True), (pfx + "2", knee, foot, pfx + "1", True)]
def ctl(pfx, foot, pole):
    return [("ik_" + pfx, foot, (foot[0], foot[1], foot[2] + 0.18), None, False), ("pole_" + pfx, pole, (pole[0], pole[1], pole[2] + 0.1), None, False)]
def legs_spec(ids, bends):
    return {k: dict(upper=k + "1", lower=k + "2", foot_ctrl="ik_" + k, pole="pole_" + k, bend=bends[k]) for k in ids}

# =============================================================== SHUCKIT
FOX_BONES = [("root", (0, 0, 0), (0, 0, 0.3), None, False),
    ("hips", (-0.65, 0, 0.85), (-0.05, 0, 0.88), "root", True), ("chest", (-0.05, 0, 0.88), (0.6, 0, 0.9), "hips", True),
    ("head", (0.65, 0, 0.95), (1.25, 0, 0.85), "chest", True),
    ("earA", (1.05, -0.4, 1.1), (1.1, -0.6, 1.6), "head", True), ("earB", (0.5, 0.4, 1.1), (0.5, 0.6, 1.55), "chest", True),
    ("tail1", (-0.7, 0, 0.85), (-0.9, 0, 0.98), "hips", True), ("tail2", (-0.9, 0, 0.98), (-1.05, 0, 1.25), "tail1", True), ("tail3", (-1.05, 0, 1.25), (-1.15, 0, 1.55), "tail2", True)]
FOX_BONES += legb("FP", (0.45, 0.28, 0.65), (0.55, 0.28, 0.36), (0.78, 0.28, 0.08), "chest") + legb("FN", (0.4, -0.28, 0.6), (0.44, -0.28, 0.35), (0.55, -0.28, 0.1), "chest")
FOX_BONES += legb("BP", (-0.45, 0.25, 0.65), (-0.25, 0.25, 0.38), (-0.2, 0.25, 0.08), "hips") + legb("BN", (-0.5, -0.25, 0.65), (-0.68, -0.25, 0.38), (-1.0, -0.25, 0.08), "hips")
FOX_BONES += ctl("FP", (0.78, 0.28, 0.08), (-0.2, 0.28, 0.4)) + ctl("FN", (0.55, -0.28, 0.1), (-0.2, -0.28, 0.4)) + ctl("BP", (-0.2, 0.25, 0.08), (0.3, 0.25, 0.4)) + ctl("BN", (-1.0, -0.25, 0.08), (-0.3, -0.25, 0.4))
FOX = dict(glb="/tmp/claude-0/gt/bat_a.plain.glb", yaw=-32.0, spec=dict(origin_dx=16, yaw_face=270, px_w=150, lift=0.0, bones=FOX_BONES, ratio=0.04, legs=legs_spec(("FP", "FN", "BP", "BN"), dict(FP=-1, FN=-1, BP=1, BN=1))),
           counts={"idle": 8, "walk": 12, "attack": 8}, period={"idle": 2.2, "walk": 0.62, "attack": 0.62}, strike=3, walk_units=1.6)
# neutral stance (relative to the generated mid-stride rest pose) and trot (diagonal pairs)
FOX_NEUTRAL = {"FP": (-0.16, 0.0), "FN": (0.07, 0.0), "BP": (-0.26, 0.0), "BN": (0.42, 0.0)}
FOX_PHASE = {"FP": 0.0, "BN": 0.0, "FN": 0.5, "BP": 0.5}

def fox_base(state, u):
    a = 2 * math.pi * u
    b = dict(rx=0.0, rz=0.0, hip_p=0.0, hip_y=0.0, ch_p=0.0, ch_y=0.0, ch_s=1.0, ch_sx=1.0, hd_p=0.0, hd_y=0.0, hd_x=0.0, ear_back=0.0)
    for k in FOX_PHASE: b["f_" + k] = (0.0, 0.0)
    if state == "idle":
        br = math.sin(a)
        b.update(rz=0.01 * br, ch_s=1 + 0.02 * br, hd_p=1.5 * math.sin(a + 0.8), hd_y=2.0 * math.sin(a * 0.5 + 0.3), ear_back=4 * math.sin(a * 0.5))
    elif state == "walk":
        for k, ph in FOX_PHASE.items():
            dx, dz = foot_offset(u + ph, 0.8, 0.22, 0.5)
            b["f_" + k] = (dx, dz)
        b.update(rz=0.05 * abs(math.sin(2 * a - 0.4)) - 0.02, hip_p=-3.5 * math.sin(2 * a), ch_p=3.5 * math.sin(2 * a), hip_y=3.0 * math.sin(a), ch_y=-3.0 * math.sin(a),
                 hd_p=-2.5 * math.sin(2 * a), hd_y=2.5 * math.sin(a), ear_back=6 + 3 * math.sin(2 * a))
    else:
        T = [(0.0, 0), (0.13, 1), (0.28, 2), (0.40, 3), (0.56, 4), (0.78, 5), (1.0, 0)]
        P = {0: dict(rx=0, rz=0, ch_p=0, hip_p=0, hd_p=0, hd_x=0, eb=0, ff=(0, 0), fb=(0, 0), s=1.0, sx=1.0),
             1: dict(rx=-0.05, rz=-0.09, ch_p=8, hip_p=-3, hd_p=-4, hd_x=-0.02, eb=10, ff=(-0.08, 0), fb=(0.12, 0), s=1.03, sx=0.99),
             2: dict(rx=-0.14, rz=-0.14, ch_p=12, hip_p=-8, hd_p=-8, hd_x=-0.05, eb=22, ff=(-0.14, 0), fb=(0.18, 0), s=1.05, sx=0.98),
             3: dict(rx=0.30, rz=0.06, ch_p=-10, hip_p=6, hd_p=14, hd_x=0.17, eb=30, ff=(0.46, 0.12), fb=(-0.32, 0.06), s=1.0, sx=1.06),
             4: dict(rx=0.25, rz=-0.02, ch_p=6, hip_p=-4, hd_p=-6, hd_x=0.04, eb=12, ff=(0.32, 0.0), fb=(-0.12, 0.0), s=0.95, sx=1.05),
             5: dict(rx=0.08, rz=0.0, ch_p=1, hip_p=0, hd_p=0, hd_x=0, eb=4, ff=(0.08, 0), fb=(-0.04, 0), s=1.0, sx=1.0)}
        for j in range(len(T) - 1):
            if u <= T[j + 1][0]:
                f = smoothstep((u - T[j][0]) / (T[j + 1][0] - T[j][0])); A, B = P[T[j][1]], P[T[j + 1][1]]
                L = lambda k: tuple(p + (q - p) * f for p, q in zip(A[k], B[k])) if isinstance(A[k], tuple) else A[k] + (B[k] - A[k]) * f
                b.update(rx=L("rx"), rz=L("rz"), ch_p=L("ch_p"), hip_p=L("hip_p"), hd_p=L("hd_p"), hd_x=L("hd_x"), ear_back=L("eb"), ch_s=L("s"), ch_sx=L("sx"))
                for k in ("FP", "FN"): b["f_" + k] = L("ff")
                for k in ("BP", "BN"): b["f_" + k] = L("fb")
                break
    return b

def fox_sim(state):
    period = FOX["period"][state]
    S = dict(tail=[SOD(2.8, 0.30, 0.0), SOD(3.1, 0.28, 0.0), SOD(3.5, 0.26, 0.0)], tz=[SOD(2.6, 0.30, 0.0), SOD(2.9, 0.28, 0.0), SOD(3.2, 0.26, 0.0)],
             eA=SOD(5.5, 0.35, -1.2), eB=SOD(5.0, 0.35, -1.2), ez=SOD(4.0, 0.4, 0.0))
    def fn(t, dt):
        u = (t / period) % 1.0
        b0 = fox_base(state, u); b1 = fox_base(state, (u + 0.004) % 1.0); b2 = fox_base(state, (u - 0.004) % 1.0)
        vx = (b1["rx"] - b2["rx"]) / (0.008 * period); vz = (b1["rz"] - b2["rz"]) / (0.008 * period)
        out = {}
        x = -4.0 * vx - 9.0 * vz - b0["hip_p"] * 0.5
        for i, s in enumerate(S["tail"]):
            x = s.step(dt, x * (1.0 if i == 0 else 0.85)); out["t%d" % (i + 1)] = max(-38.0, min(38.0, x))
        x = -b0["hip_y"] * 1.2
        for i, s in enumerate(S["tz"]):
            x = s.step(dt, x * (1.0 if i == 0 else 0.9)); out["tz%d" % (i + 1)] = max(-32.0, min(32.0, x))
        out["eA"] = S["eA"].step(dt, -12.0 * vz - 3.0 * vx); out["eB"] = S["eB"].step(dt, -12.0 * vz - 3.0 * vx)
        return out
    return run_loop(fn, period, 240, 3)

# =============================================================== HUTZIN
BIRD_BONES = [("root", (0, 0, 0), (0, 0, 0.3), None, False), ("body", (-0.75, 0, 1.0), (0.55, 0, 1.1), "root", True),
    ("neck", (0.55, 0, 1.2), (0.95, 0, 1.7), "body", True), ("head", (0.95, 0, 1.7), (1.25, 0, 1.8), "neck", True), ("crest", (0.95, 0, 1.95), (0.8, 0, 2.3), "head", True),
    ("wingP", (0.55, 0.45, 1.05), (1.2, 0.65, 0.95), "body", True), ("wingN", (0.55, -0.45, 1.05), (1.2, -0.65, 0.95), "body", True),
    ("tail", (-0.75, 0, 0.85), (-1.4, 0, 0.5), "body", True), ("steam", (-0.6, 0, 1.85), (-0.9, 0, 2.5), "body", True)]
BIRD_BONES += legb("LN", (-0.2, -0.25, 0.75), (-0.32, -0.25, 0.42), (-0.4, -0.25, 0.1), "body") + legb("LP", (0.4, 0.25, 0.7), (0.5, 0.25, 0.46), (0.8, 0.25, 0.38), "body")
BIRD_BONES += ctl("LN", (-0.4, -0.25, 0.1), (-0.75, -0.25, 0.42)) + ctl("LP", (0.8, 0.25, 0.38), (0.1, 0.25, 0.46))
BIRD = dict(glb="/tmp/claude-0/gt/bird.plain.glb", yaw=-40.0, spec=dict(origin_dx=8, yaw_face=270, px_w=150, lift=0.0, bones=BIRD_BONES, ratio=0.04, legs=legs_spec(("LN", "LP"), dict(LN=-1, LP=-1))),
            counts={"idle": 8, "walk": 12, "attack": 8}, period={"idle": 2.4, "walk": 0.8, "attack": 0.8}, strike=3, walk_units=1.0)
BIRD_NEUTRAL = {"LN": (0.05, 0.0), "LP": (-0.3, -0.27)}
BIRD_PHASE = {"LN": 0.0, "LP": 0.5}

def bird_base(state, u):
    a = 2 * math.pi * u
    b = dict(rx=0.0, rz=0.0, body_p=0.0, body_r=0.0, nk_p=0.0, nk_x=0.0, hd_p=0.0, wing=0.0, sc=1.0, scx=1.0)
    for k in BIRD_PHASE: b["f_" + k] = (0.0, 0.0)
    if state == "idle":
        br = math.sin(a)
        b.update(rz=0.02 * br, sc=1 + 0.02 * br, nk_p=3 * math.sin(a + 0.5), hd_p=5 * math.sin(a + 1.0), wing=5 * math.sin(a + 0.2))
    elif state == "walk":
        for k, ph in BIRD_PHASE.items():
            dx, dz = foot_offset(u + ph, 0.55, 0.24, 0.6)
            b["f_" + k] = (dx, dz)
        # head-bob: neck thrusts forward then holds while the body catches up (twice per cycle)
        u2 = (2 * u) % 1.0
        thrust = smoothstep(u2 / 0.25) if u2 < 0.25 else 1.0 - (u2 - 0.25) / 0.75
        b.update(rz=0.06 * abs(math.sin(a)) - 0.02, body_p=-2.5 * math.sin(2 * a), body_r=3.5 * math.sin(a), nk_x=0.14 * (thrust - 0.5), nk_p=-3 * math.sin(2 * a + 0.8), hd_p=4 * math.sin(2 * a), wing=10 * math.sin(2 * a))
    else:
        T = [(0.0, 0), (0.15, 1), (0.30, 2), (0.42, 3), (0.58, 4), (0.80, 5), (1.0, 0)]
        P = {0: dict(rx=0, rz=0, bp=0, nk=0, nkx=0, hd=0, wing=0, s=1.0, sx=1.0),
             1: dict(rx=-0.06, rz=-0.04, bp=-6, nk=-8, nkx=-0.08, hd=-8, wing=16, s=1.05, sx=1.0),
             2: dict(rx=-0.12, rz=-0.02, bp=-12, nk=-16, nkx=-0.14, hd=-12, wing=26, s=1.12, sx=0.98),
             3: dict(rx=0.22, rz=0.04, bp=9, nk=20, nkx=0.28, hd=24, wing=-10, s=0.97, sx=1.05),
             4: dict(rx=0.12, rz=0.0, bp=4, nk=6, nkx=0.08, hd=6, wing=8, s=1.02, sx=1.0),
             5: dict(rx=0.03, rz=0.0, bp=0, nk=0, nkx=0.0, hd=0, wing=2, s=1.0, sx=1.0)}
        for j in range(len(T) - 1):
            if u <= T[j + 1][0]:
                f = smoothstep((u - T[j][0]) / (T[j + 1][0] - T[j][0])); A, B = P[T[j][1]], P[T[j + 1][1]]
                L = lambda k: A[k] + (B[k] - A[k]) * f
                b.update(rx=L("rx"), rz=L("rz"), body_p=L("bp"), nk_p=L("nk"), nk_x=L("nkx"), hd_p=L("hd"), wing=L("wing"), sc=L("s"), scx=L("sx"))
                break
    return b

def bird_sim(state):
    period = BIRD["period"][state]
    S = dict(crest=SOD(3.5, 0.30, 0.0), steam=SOD(2.4, 0.25, 0.0), tail=SOD(3.0, 0.30, 0.0), wP=SOD(4.0, 0.4, -0.8), wN=SOD(4.0, 0.4, -0.8))
    def fn(t, dt):
        u = (t / period) % 1.0
        b0 = bird_base(state, u); b1 = bird_base(state, (u + 0.004) % 1.0); b2 = bird_base(state, (u - 0.004) % 1.0)
        vx = (b1["rx"] - b2["rx"]) / (0.008 * period); vz = (b1["rz"] - b2["rz"]) / (0.008 * period); vn = (b1["nk_x"] - b2["nk_x"]) / (0.008 * period)
        out = {}
        out["crest"] = max(-35, min(35, S["crest"].step(dt, -10.0 * vx - 14.0 * vz - 25.0 * vn)))
        out["steam"] = max(-30, min(30, S["steam"].step(dt, -12.0 * vx - 20.0 * vz)))
        out["tail"] = max(-30, min(30, S["tail"].step(dt, -8.0 * vx - 14.0 * vz - b0["body_p"] * 0.6)))
        out["wP"] = S["wP"].step(dt, b0["wing"] - 6.0 * vz); out["wN"] = S["wN"].step(dt, b0["wing"] - 6.0 * vz)
        return out
    return run_loop(fn, period, 240, 3)

# =============================================================== DUGLOOM
DUG_BONES = [("root", (0, 0, 0), (0, 0, 0.3), None, False),
    ("body", (-0.9, 0, 1.05), (-0.25, 0, 1.07), "root", True), ("bodyF", (-0.25, 0, 1.07), (0.45, 0, 1.1), "body", True), ("head", (0.45, 0, 1.1), (1.1, 0, 1.12), "bodyF", True),
    ("stalk", (0.85, 0, 1.45), (1.1, 0, 1.85), "head", True), ("lantern", (1.1, 0, 1.85), (1.12, 0, 1.5), "stalk", True),
    ("flipP", (0.55, 0.4, 0.8), (0.75, 0.6, 0.5), "bodyF", True), ("flipN", (0.55, -0.4, 0.8), (0.75, -0.6, 0.5), "bodyF", True),
    ("tail1", (-0.9, 0, 1.1), (-1.08, 0, 1.25), "body", True), ("tail2", (-1.08, 0, 1.25), (-1.2, 0, 1.6), "tail1", True), ("tail3", (-1.2, 0, 1.6), (-1.3, 0, 1.95), "tail2", True)]
DUG = dict(glb="/tmp/claude-0/gt/narwhal.plain.glb", yaw=-32.0, spec=dict(origin_dx=10, yaw_face=0, px_w=150, lift=0.35, bones=DUG_BONES, ratio=0.04, legs={}),
           counts={"idle": 8, "walk": 12, "attack": 8}, period={"idle": 2.6, "walk": 1.1, "attack": 0.9}, strike=3, walk_units=1.4)

def dug_base(state, u):
    a = 2 * math.pi * u
    b = dict(rx=0.0, rz=0.0, w_body=0.0, w_bf=0.0, w_t1=0.0, w_t2=0.0, w_t3=0.0, hd_p=0.0, flip=0.0, flip_s=0.0, bf_s=1.0, bf_sx=1.0, lant=1.0, stalk=0.0)
    if state in ("idle", "walk"):
        amp = 1.0 if state == "walk" else 0.45
        # sirenian swimming: dorso-ventral S-wave travelling head->tail, amplitude growing toward the fluke
        for nm, A, lag in (("w_body", 3.0, 0.0), ("w_bf", 2.0, 0.55), ("w_t1", 9.0, 1.1), ("w_t2", 15.0, 1.65), ("w_t3", 22.0, 2.2)):
            b[nm] = amp * A * math.sin(a - lag)
        b.update(rz=(0.07 if state == "walk" else 0.045) * math.sin(a + 0.4), hd_p=-1.6 * b["w_bf"] * 0.5, flip=amp * 24 * math.sin(a + 0.6), flip_s=amp * 8 * math.sin(a + 1.0),
                 bf_s=1 + 0.02 * math.sin(a * (1 if state == "idle" else 2)))
    else:
        T = [(0.0, 0), (0.16, 1), (0.32, 2), (0.44, 3), (0.62, 4), (0.82, 5), (1.0, 0)]
        P = {0: dict(rz=0, rx=0, bf=0, hd=0, fl=0, s=1.0, sx=1.0, lant=1.0, wt=0),
             1: dict(rz=-0.03, rx=-0.04, bf=5, hd=-4, fl=-28, s=1.05, sx=0.97, lant=0.9, wt=8),
             2: dict(rz=-0.05, rx=-0.09, bf=9, hd=-8, fl=-40, s=1.09, sx=0.95, lant=0.85, wt=16),
             3: dict(rz=0.06, rx=0.07, bf=-11, hd=12, fl=46, s=0.96, sx=1.05, lant=1.5, wt=-20),
             4: dict(rz=0.02, rx=0.04, bf=-4, hd=4, fl=14, s=1.0, sx=1.0, lant=1.15, wt=-8),
             5: dict(rz=0.0, rx=0.02, bf=0, hd=0, fl=2, s=1.0, sx=1.0, lant=1.02, wt=2)}
        for j in range(len(T) - 1):
            if u <= T[j + 1][0]:
                f = smoothstep((u - T[j][0]) / (T[j + 1][0] - T[j][0])); A, B = P[T[j][1]], P[T[j + 1][1]]
                L = lambda k: A[k] + (B[k] - A[k]) * f
                b.update(rz=L("rz"), rx=L("rx"), w_bf=L("bf"), w_body=L("bf") * 0.6, hd_p=L("hd"), flip=L("fl"), bf_s=L("s"), bf_sx=L("sx"), lant=L("lant"), w_t1=L("wt") * 0.5, w_t2=L("wt") * 0.8, w_t3=L("wt"))
                break
    return b

def dug_sim(state):
    period = DUG["period"][state]
    S = dict(stalk=SOD(2.6, 0.28, -0.6), lant=SOD(3.4, 0.25, 0.0), fP=SOD(3.5, 0.4, -0.6), fN=SOD(3.5, 0.4, -0.6))
    def fn(t, dt):
        u = (t / period) % 1.0
        b0 = dug_base(state, u); b1 = dug_base(state, (u + 0.004) % 1.0); b2 = dug_base(state, (u - 0.004) % 1.0)
        vz = (b1["rz"] - b2["rz"]) / (0.008 * period); vx = (b1["rx"] - b2["rx"]) / (0.008 * period)
        drv = -b0["w_bf"] * 1.2 - 18.0 * vz - 8.0 * vx
        out = {}
        out["stalk"] = max(-35, min(35, S["stalk"].step(dt, drv)))
        out["lant"] = max(-45, min(45, S["lant"].step(dt, drv * 1.3)))
        out["fP"] = S["fP"].step(dt, b0["flip"]); out["fN"] = S["fN"].step(dt, b0["flip"])
        return out
    return run_loop(fn, period, 240, 3)

CACHE = {}
def pose_fox(c, state, u, i, n):
    k = ("fox", state)
    if k not in CACHE: CACHE[k] = fox_sim(state)
    sec = sample(CACHE[k], u); b = fox_base(state, u)
    c.move("root", (b["rx"], 0, b["rz"]))
    c.rot("hips", AXY, b["hip_p"]); c.rot("hips", AXZ, b["hip_y"]); c.rot("chest", AXY, b["ch_p"]); c.rot("chest", AXZ, b["ch_y"])
    c.rig.pb_scale("chest", (b["ch_sx"], b["ch_sx"], b["ch_s"]))
    c.rot("head", AXY, b["hd_p"]); c.rot("head", AXZ, b["hd_y"]); c.move("head", (b["hd_x"], 0, 0))
    for j in "123":
        c.rot("tail" + j, AXY, sec["t" + j]); c.rot("tail" + j, AXZ, sec["tz" + j])
    c.rot("earA", AXY, -b["ear_back"] + sec["eA"]); c.rot("earB", AXY, -b["ear_back"] + sec["eB"])
    for kf, (nx, nz) in FOX_NEUTRAL.items():
        dx, dz = b["f_" + kf]
        c.foot(kf, nx + dx, nz + dz)

def pose_bird(c, state, u, i, n):
    k = ("bird", state)
    if k not in CACHE: CACHE[k] = bird_sim(state)
    sec = sample(CACHE[k], u); b = bird_base(state, u)
    c.move("root", (b["rx"], 0, b["rz"]))
    c.rot("body", AXY, b["body_p"]); c.rot("body", AXX, b["body_r"]); c.rig.pb_scale("body", (b["scx"], b["scx"], b["sc"]))
    c.rot("neck", AXY, b["nk_p"]); c.move("neck", (b["nk_x"], 0, 0)); c.rot("head", AXY, b["hd_p"])
    c.rot("crest", AXY, sec["crest"]); c.rot("steam", AXZ, sec["steam"]); c.rot("tail", AXY, sec["tail"])
    c.rot("wingP", AXX, b["wing"] * 0.7 + sec["wP"] * 0.5); c.rot("wingN", AXX, -(b["wing"] * 0.7 + sec["wN"] * 0.5))
    for kf, (nx, nz) in BIRD_NEUTRAL.items():
        dx, dz = b["f_" + kf]
        c.foot(kf, nx + dx, nz + dz)

def pose_dug(c, state, u, i, n):
    k = ("dug", state)
    if k not in CACHE: CACHE[k] = dug_sim(state)
    sec = sample(CACHE[k], u); b = dug_base(state, u)
    c.move("root", (b["rx"], 0, b["rz"]))
    c.rot("body", AXY, b["w_body"]); c.rot("bodyF", AXY, b["w_bf"]); c.rig.pb_scale("bodyF", (b["bf_sx"], b["bf_sx"], b["bf_s"]))
    c.rot("head", AXY, b["hd_p"])
    c.rot("tail1", AXY, b["w_t1"]); c.rot("tail2", AXY, b["w_t2"]); c.rot("tail3", AXY, b["w_t3"])
    c.rot("stalk", AXY, sec["stalk"]); c.rot("lantern", AXY, sec["lant"]); c.rig.pb_scale("lantern", (b["lant"], b["lant"], b["lant"]))
    c.rot("flipP", AXX, sec["fP"]); c.rot("flipN", AXX, -sec["fN"])

DEF = {"shuckit": (FOX, pose_fox, dict(muzzle=("attack", 0.40, "head", True, (0.22, 0, -0.1)), mouth=("idle", 0.0, "head", True), tail=("idle", 0.0, "tail3", True))),
       "hutzin": (BIRD, pose_bird, dict(muzzle=("attack", 0.42, "head", True, (0.2, 0, -0.1)), mouth=("idle", 0.0, "head", True), spout=("idle", 0.0, "steam", True))),
       "dugloom": (DUG, pose_dug, dict(lantern=("attack", 0.44, "lantern", False), mouth=("idle", 0.0, "head", True), snout=("idle", 0.0, "head", True)))}

if __name__ == "__main__":
    who, mode, out = sys.argv[1], sys.argv[2], sys.argv[3]
    D, fn, anchors = DEF[who]
    c = Creature(D["glb"], D["spec"], who)
    print(who, "bind s", round(c.bind_s, 1), "filled", c.missing, "poles", {k: (v[1], round(v[2], 3)) for k, v in c.constraints.items()}, flush=True)
    if mode == "preview":
        c.bake(fn, D["counts"], None, who, yaw=D["yaw"], preview=out)
    else:
        meta = os.path.join(os.path.dirname(__file__), "..", "..", "art", "blender", "meta", who + ".json")
        c.bake(fn, D["counts"], out, who, yaw=D["yaw"], anchors=anchors, meta_extra=dict(strike=D["strike"], walk_units=D["walk_units"]), meta_path=os.path.abspath(meta), meta_only=(mode == "meta"))
    print(who, "rig done")
