"""Face + feature kit: structured eyes (sclera, iris ring, iris, pupil, glints), open mouths with tongue/teeth, brows.
Every creature script calls its own upgrade_* after the base build: it purges the simple placeholder eyes/mouths and
rebuilds them at a higher standard, binding the parts to the same bones."""
import bpy, math
from mathutils import Vector
from lib import *

def purge(prefixes):
    for o in list(bpy.data.objects):
        if o.type == 'MESH' and o.name.startswith(tuple(prefixes)):
            bpy.data.objects.remove(o, do_unlink=True)

def eye(prefix, c, r, ang, iris, ring, sclera="#ffffff", pupil="round", glow_iris=False, spec=0.9, stretch=1.1):
    """Returns the list of objects making one eye. ang = outward turn (deg about Z), + toward +Y."""
    a = math.radians(ang)
    f = Vector((math.cos(a), math.sin(a), 0))
    s = Vector((-math.sin(a), math.cos(a), 0))
    z = Vector((0, 0, 1))
    c = Vector(c)
    out = []
    sc = toon_mat(prefix + "_sc", sclera, shadow=(0.72, 0.72, 0.9), spec=spec * 0.7, ao=0.25)
    out.append(ellipsoid(prefix + "_sclera", tuple(c), (1.0 * r, 0.95 * r, stretch * r), sc, outline=0.012, rot=(0, 0, ang)))
    ring_m = toon_mat(prefix + "_ring", ring, glow=1.3) if glow_iris else toon_mat(prefix + "_ring", ring, spec=0.3, ao=0.0)
    iris_m = toon_mat(prefix + "_iris", iris, glow=2.2) if glow_iris else toon_mat(prefix + "_iris", iris, spec=spec, ao=0.0)
    out.append(ellipsoid(prefix + "_ring", tuple(c + f * 0.78 * r), (0.3 * r, 0.8 * r, 0.9 * r * stretch / 1.1), ring_m, outline=0, rot=(0, 0, ang)))
    out.append(ellipsoid(prefix + "_iris", tuple(c + f * 0.88 * r), (0.27 * r, 0.64 * r, 0.74 * r * stretch / 1.1), iris_m, outline=0, rot=(0, 0, ang)))
    ink = toon_mat("pupil_ink", "#140a28", rim=0.0, spec=0.5, ao=0.0)
    ps = (0.2 * r, 0.3 * r, 0.42 * r) if pupil == "round" else (0.2 * r, 0.1 * r, 0.62 * r)
    out.append(ellipsoid(prefix + "_pupil", tuple(c + f * 1.0 * r), ps, ink, outline=0, rot=(0, 0, ang)))
    gl = toon_mat("glint_w", "#ffffff", glow=3.0)
    out.append(ellipsoid(prefix + "_glintA", tuple(c + f * 1.08 * r - s * 0.22 * r + z * 0.3 * r), (0.09 * r, 0.2 * r, 0.22 * r), gl, outline=0, rot=(0, 0, ang)))
    out.append(ellipsoid(prefix + "_glintB", tuple(c + f * 1.05 * r + s * 0.26 * r - z * 0.28 * r), (0.06 * r, 0.1 * r, 0.1 * r), gl, outline=0, rot=(0, 0, ang)))
    return out

def mouth_open(prefix, c, w, h, depth, fangs=0, tongue=True, inner="#5a1030", teeth_hex="#ffffff"):
    """An open mouth: dark interior, tongue and optional fangs. Centre c, half-width w, half-height h, depth along +X."""
    c = Vector(c)
    out = []
    out.append(ellipsoid(prefix + "_in", tuple(c), (depth, w, h), toon_mat(prefix + "_im", inner, rim=0.0, ao=0.0), outline=0.01))
    if tongue:
        out.append(ellipsoid(prefix + "_tongue", tuple(c + Vector((depth * 0.3, 0, -h * 0.45))), (depth * 0.8, w * 0.62, h * 0.5), toon_mat(prefix + "_tg", "#ff7a9a", rim=0.0, spec=0.5, ao=0.0), outline=0))
    tooth = toon_mat(prefix + "_th", teeth_hex, rim=0.0, ao=0.0)
    for i in range(fangs):
        side = -1 if i % 2 == 0 else 1
        out.append(cone(f"{prefix}_fang{i}", tuple(c + Vector((depth * 0.5, side * w * 0.6, h * 0.8))), w * 0.14, 0.0, h * 0.8, tooth, rot=(180, 0, 0), outline=0.006))
    return out

def bindall(r, objs, bone):
    for o in objs:
        r.bind(o, bone)
    return objs

def brow(name, pts, rad, mat):
    return tube(name, pts, rad, mat, outline=0.008)

def dots(prefix, pts, r, mat):
    return [ellipsoid(f"{prefix}{i}", p, (r, r, r), mat, outline=0, seg=14) for i, p in enumerate(pts)]

INK = None
def _ink():
    return toon_mat("faceink", "#1d1230", rim=0.0, ao=0.0)

def _bind_tube(r, t, bone):
    caps = list(TUBE_CAPS)
    r.bind(t, bone)
    for c in caps:
        r.bind(c, bone)

# ---------------- Tickindle ----------------
def upgrade_tickindle(r, variant=""):
    purge(("eye", "pupil", "glint", "mouth", "nose", "roar", "fang"))
    for sy in (1, -1):
        bindall(r, eye(f"teye{sy}", (1.0, sy * 0.34, 1.46), 0.215, sy * 16, "#ffd23a", "#e07a10", pupil="slit"), "head")
    bindall(r, [ellipsoid("tnose", (1.28, 0, 1.3), (0.085, 0.12, 0.065), toon_mat("tnose_m", "#ff8fa8", spec=0.9), outline=0.008)], "head")
    for sy in (-1, 1):
        _bind_tube(r, tube(f"tmouth{sy}", [(1.285, 0, 1.24), (1.285, sy * 0.02, 1.2), (1.27, sy * 0.1, 1.15), (1.24, sy * 0.21, 1.17)], [0.022] * 4, _ink(), outline=0), "head")
    r.bind(cone("tfang", (1.262, -0.115, 1.14), 0.026, 0.0, 0.085, toon_mat("tooth_m", "#ffffff", rim=0.0, ao=0.0), rot=(180, 0, 0), outline=0.005), "head")
    bindall(r, mouth_open("troar", (1.27, 0, 1.12), 0.2, 0.13, 0.12, fangs=2), "roar")
    cream = toon_mat("tfluff_m", "#ffe9bf", shadow=(0.75, 0.55, 0.55))
    for k in range(7):
        r.bind(cone(f"tfluff{k}", (0.58, (k - 3) * 0.12, 1.0 + 0.02 * abs(k - 3)), 0.075, 0.0, 0.2, cream, rot=(0, -10, (k - 3) * 6), outline=0.006), "body")
    for k in range(12):
        a = k * math.pi / 6
        r.bind(box(f"ttick{k}", (0.775, math.cos(a) * 0.185, 0.62 + math.sin(a) * 0.185), (0.012, 0.016, 0.034), _ink(), rot=(math.degrees(a) + 90, 0, 0), outline=0), "watch")

# ---------------- Dugloom ----------------
def upgrade_dugloom(r, variant=""):
    purge(("eye", "pupil", "glint", "smile", "mouthO"))
    for sy in (1, -1):
        bindall(r, eye(f"deye{sy}", (1.1, sy * 0.38, 1.2), 0.21, sy * 14, "#1f6a80", "#0e3a4a", sclera="#fff6e8"), "head")
        for k in range(3):
            _bind_tube(r, tube(f"dlash{sy}{k}", [(1.14, sy * (0.55 + 0.01 * k), 1.3 + 0.03 * k), (1.16, sy * (0.64 + 0.03 * k), 1.35 + 0.045 * k), (1.14, sy * (0.72 + 0.05 * k), 1.36 + 0.06 * k)], [0.014, 0.011, 0.008], _ink(), outline=0), "head")
    _bind_tube(r, tube("dsmile", [(1.62, -0.17, 0.8), (1.67, -0.08, 0.745), (1.67, 0.08, 0.745), (1.62, 0.17, 0.8)], [0.02] * 4, _ink(), outline=0), "head")
    for sy in (-1, 1):
        _bind_tube(r, tube(f"ddimple{sy}", [(1.6, sy * 0.19, 0.84), (1.62, sy * 0.22, 0.8), (1.6, sy * 0.19, 0.77)], [0.012] * 3, _ink(), outline=0), "head")
    r.bind(ellipsoid("dtongue", (1.655, 0, 0.72), (0.03, 0.06, 0.025), toon_mat("dtg", "#ff7a9a", rim=0.0, ao=0.0), outline=0), "head")
    bindall(r, mouth_open("dmo", (1.66, 0, 0.74), 0.1, 0.11, 0.06, fangs=0), "mouthO")
    bindall(r, dots("dpore", [(1.55, 0.14, 0.92), (1.52, 0.2, 0.88), (1.5, 0.12, 0.95), (1.47, 0.22, 0.92), (1.55, -0.14, 0.92), (1.52, -0.2, 0.88), (1.5, -0.12, 0.95), (1.47, -0.22, 0.92)], 0.018, _ink()), "head")

# ---------------- Hutzin ----------------
def upgrade_hutzin(r, variant=""):
    purge(("eye", "iris", "pup"))
    bindall(r, eye("heyeB", (0.9, 0.19, 2.05), 0.205, 24, "#e63a2a", "#7a1010"), "head")
    bindall(r, eye("heyeS", (0.9, -0.19, 2.0), 0.145, -24, "#e63a2a", "#7a1010"), "head")
    org = toon_mat("hbrow", "#ff6a2a", shadow=(0.7, 0.4, 0.4))
    for sy, z in ((1, 2.34), (-1, 2.27)):
        r.bind(cone(f"hbrow{sy}", (0.86, sy * 0.2, z), 0.05, 0.0, 0.2, org, rot=(sy * -50, -20, 0), outline=0.006), "head")
    for sy in (-1, 1):
        _bind_tube(r, tube(f"hnos{sy}", [(1.27, sy * 0.04, 1.97), (1.31, sy * 0.045, 1.96)], [0.011] * 2, _ink(), outline=0), "head")
        _bind_tube(r, tube(f"hwrink{sy}", [(0.98, sy * 0.3, 1.88), (1.0, sy * 0.34, 1.84), (0.98, sy * 0.3, 1.8)], [0.01] * 3, toon_mat("hwr", "#1a8aa0", rim=0.0, ao=0.0), outline=0), "head")
    r.bind(ellipsoid("htongue", (1.12, 0, 1.8), (0.15, 0.05, 0.025), toon_mat("htg", "#ff7a9a", rim=0.0, ao=0.0), outline=0), "jaw")
    # breast feather scallops
    sc = toon_mat("hscal", "#c2e680", shadow=(0.5, 0.65, 0.7))
    k = 0
    for row, dz in enumerate((0.3, 0.12, -0.06)):
        for col in range(5 - (row % 2)):
            dy = (col - (4 - (row % 2)) / 2.0) * 0.2
            inside = 1.0 - (dy / 0.44) ** 2 - (dz / 0.44) ** 2
            if inside <= 0.05:
                continue
            x = 0.24 + 0.4 * math.sqrt(inside) - 0.01
            r.bind(ellipsoid(f"hscal{k}", (x, dy, 0.98 + dz), (0.05, 0.1, 0.065), sc, outline=0.006, seg=16), "body")
            k += 1

# ---------------- Shuckit ----------------
def upgrade_shuckit(r, variant=""):
    purge(("eye", "pupil", "grin", "nose"))
    for sy, big in ((1, 0.2), (-1, 0.15)):
        bindall(r, eye(f"seye{sy}", (1.1, sy * 0.2, 1.34), big, sy * 10, "#fff27a", "#ffb020", sclera="#241a58", pupil="slit", glow_iris=True), "head")
    bindall(r, [ellipsoid("snose", (1.64, 0, 1.17), (0.095, 0.1, 0.085), toon_mat("snose_m", "#140a28", spec=1.0, ao=0.0), outline=0.008)], "head")
    _bind_tube(r, tube("sphil", [(1.62, 0, 1.12), (1.58, 0, 1.07)], [0.016] * 2, _ink(), outline=0), "head")
    for sy in (-1, 1):
        _bind_tube(r, tube(f"slip{sy}", [(1.58, 0, 1.07), (1.5, sy * 0.1, 1.06), (1.36, sy * 0.15, 1.08), (1.2, sy * 0.18, 1.16)], [0.016] * 4, _ink(), outline=0), "head")
        _bind_tube(r, tube(f"sdimple{sy}", [(1.2, sy * 0.185, 1.2), (1.18, sy * 0.2, 1.16), (1.2, sy * 0.185, 1.12)], [0.011] * 3, _ink(), outline=0), "head")
        r.bind(cone(f"sfang{sy}", (1.46, sy * 0.095, 1.06), 0.022, 0.0, 0.085, toon_mat("tooth_m", "#ffffff", rim=0.0, ao=0.0), rot=(180, 0, 0), outline=0.005), "head")
    bindall(r, mouth_open("smo", (1.3, 0, 1.04), 0.11, 0.045, 0.2, fangs=0, tongue=False), "jaw")
    fur = toon_mat("stuft", "#3a2f78", shadow=(0.32, 0.28, 0.7))
    for sy in (-1, 1):
        for k in range(3):
            r.bind(cone(f"scheek{sy}{k}", (0.98 - k * 0.05, sy * (0.34 + 0.02 * k), 1.14 - k * 0.07), 0.06, 0.0, 0.2, fur, rot=(sy * 20, 150 + k * 6, 0), outline=0.006), "head")
    for k in range(5):
        r.bind(cone(f"sruff{k}", (0.78, (k - 2) * 0.1, 0.84 - abs(k - 2) * 0.02), 0.06, 0.0, 0.2, fur, rot=(0, 160, (k - 2) * 8), outline=0.006), "body")
    for x, sy, bone in ((0.55, 1, "legFP"), (0.55, -1, "legFN"), (-0.5, 1, "legBP"), (-0.5, -1, "legBN")):
        for k in (-1, 0, 1):
            r.bind(ellipsoid(f"stoe{bone}{k}", (x + 0.24, sy * 0.17 + k * 0.055, 0.045), (0.04, 0.035, 0.03), toon_mat("stoe_m", "#241a58"), outline=0.005, seg=12), bone)

# ---------------- Zapnose ----------------
def upgrade_zapnose(r, variant=""):
    purge(("eye", "pup", "grin", "mouthbg"))
    bindall(r, eye("zeyeB", (0.8, 0.2, 1.72), 0.245, 20, "#37e0ff", "#1a6fb0"), "head")
    bindall(r, eye("zeyeS", (0.8, -0.22, 1.66), 0.17, -20, "#37e0ff", "#1a6fb0"), "head")
    white = toon_mat("zbrow", "#ffffff", shadow=(0.8, 0.8, 0.95))
    for sy, z in ((1, 2.02), (-1, 1.9)):
        _bind_tube(r, tube(f"zbrow{sy}", [(0.72, sy * 0.06, z), (0.78, sy * 0.22, z + 0.07), (0.74, sy * 0.38, z - 0.01)], [0.04, 0.045, 0.03], white, outline=0.006), "head")
    _bind_tube(r, tube("zgrin", [(0.9, -0.19, 1.28), (0.945, -0.08, 1.225), (0.945, 0.08, 1.225), (0.9, 0.19, 1.28)], [0.018] * 4, _ink(), outline=0), "head")
    for k in range(5):
        r.bind(box(f"zteeth{k}", (0.935, (k - 2) * 0.05, 1.25), (0.012, 0.038, 0.04), toon_mat("tooth_m", "#ffffff", rim=0.0, ao=0.0), outline=0.004), "head")
    bindall(r, mouth_open("zmo", (0.86, 0, 1.28), 0.15, 0.1, 0.07, fangs=2), "mouth")
    for sy in (-1, 1):
        for k in range(3):
            _bind_tube(r, tube(f"zgill{sy}{k}", [(0.46, sy * 0.4, 1.52 - k * 0.07), (0.5, sy * 0.415, 1.47 - k * 0.07), (0.46, sy * 0.4, 1.42 - k * 0.07)], [0.01] * 3, _ink(), outline=0), "head")

# ---------------- Glomm ----------------
def upgrade_glomm(r, variant=""):
    purge(("eye", "mouth"))
    for sy in (1, -1):
        bindall(r, eye(f"geye{sy}", (0.88, sy * 0.28, 0.93), 0.17, sy * 10, "#c8f8ff", "#37a8d8", sclera="#1a2a58", glow_iris=True), "body")
    _bind_tube(r, tube("gmouth", [(0.92, -0.27, 0.6), (0.95, -0.1, 0.565), (0.95, 0.1, 0.565), (0.92, 0.27, 0.6)], [0.035] * 4, _ink(), outline=0), "body")
    for sy in (-1, 1):
        r.bind(cone(f"gtusk{sy}", (0.95, sy * 0.2, 0.6), 0.04, 0.0, 0.15, toon_mat("tooth_m", "#f4f8ff", rim=0.0, ao=0.0), outline=0.006), "body")
    icy = toon_mat("grune", "#9be7ff", glow=2.5)
    _bind_tube(r, tube("grune1", [(0.925, -0.12, 1.13), (0.925, 0.0, 1.03), (0.925, 0.12, 1.13)], [0.014] * 3, icy, outline=0), "browB")
    _bind_tube(r, tube("grune2", [(0.925, 0.0, 1.03), (0.925, 0.0, 0.97)], [0.014] * 2, icy, outline=0), "browB")
    facet = toon_mat("gfacet", "#8fb0ff", shadow=(0.4, 0.5, 0.85))
    for k, (t, p) in enumerate(((0.9, 0.5), (1.5, 0.45), (2.1, 0.3), (-0.9, 0.5), (-1.5, 0.4), (-2.2, 0.35), (2.8, 0.45), (-2.9, 0.3))):
        x = 0.98 * math.cos(p) * math.cos(t) * 0.96
        y = 0.88 * math.cos(p) * math.sin(t) * 0.96
        z = 0.92 + 0.72 * math.sin(p) * 0.96
        r.bind(ellipsoid(f"gfacet{k}", (x, y, z), (0.11, 0.11, 0.06), facet, outline=0.008, seg=16, rot=(0, 0, math.degrees(t))), "body")
