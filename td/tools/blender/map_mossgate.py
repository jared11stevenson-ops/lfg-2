"""Mossgate Lane (Level 1) painted diorama, built in Blender from the game's own pixel coordinates.
  python3 map_mossgate.py <out.png> [width=2560] [samples=48] [debug]
Camera: orthographic, 60 deg elevation, 100 px per world unit horizontally. Game pixel (px,py) -> world via G()."""
import sys, os, math, random
import bpy, bmesh
import numpy as np
from mathutils import Vector

out = sys.argv[1]
WIDTH = int(sys.argv[2]) if len(sys.argv) > 2 else 2560
SAMPLES = int(sys.argv[3]) if len(sys.argv) > 3 else 48
DEBUG = len(sys.argv) > 4 and sys.argv[4] == "debug"
EL = 60.0
S = 100.0
SY = S * math.sin(math.radians(EL))
random.seed(11)
rnd = random.Random(5)

def G(px, py, z=0.0):
    return Vector(((px - 640.0) / S, -(py - 360.0) / SY, z))
def hexc(h, a=1.0):
    h = h.lstrip("#"); r, g, b = (int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))
    f = lambda c: c ** 2.2
    return (f(r), f(g), f(b), a)

PATH = [(54, 360), (300, 360), (300, 160), (700, 160), (700, 560), (1000, 560), (1000, 300), (1190, 300)]
STONES = [(460, 250, "#6fd35a"), (560, 470, "#4aa8ff"), (880, 420, "#ff8a2b"), (150, 230, "#8a7ae0")]
LANE_W = 68.0

bpy.ops.wm.read_factory_settings(use_empty=True)
sc = bpy.context.scene

# ------------------------------------------------------------------ materials
_mat = {}
def mat(name, color, rough=0.8, emit=0.0, emit_color=None, metal=0.0):
    key = (name, color, rough, emit)
    if key in _mat:
        return _mat[key]
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = hexc(color) if isinstance(color, str) else color
    b.inputs["Roughness"].default_value = rough
    b.inputs["Metallic"].default_value = metal
    if emit > 0:
        b.inputs["Emission Color"].default_value = hexc(emit_color or color) if isinstance(emit_color or color, str) else (emit_color or color)
        b.inputs["Emission Strength"].default_value = emit
    _mat[key] = m
    return m

def node(nt, kind, **kw):
    n = nt.nodes.new(kind)
    for k, v in kw.items():
        setattr(n, k, v)
    return n

def ramp(nt, stops):
    r = nt.nodes.new("ShaderNodeValToRGB")
    cr = r.color_ramp
    while len(cr.elements) > 2:
        cr.elements.remove(cr.elements[-1])
    for i, (pos, col) in enumerate(stops):
        e = cr.elements[i] if i < 2 else cr.elements.new(pos)
        e.position = pos; e.color = hexc(col)
    return r

def ground_mat():
    m = bpy.data.materials.new("ground"); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    tc = node(nt, "ShaderNodeTexCoord")
    big = node(nt, "ShaderNodeTexNoise"); big.inputs["Scale"].default_value = 0.7; big.inputs["Detail"].default_value = 3
    mid = node(nt, "ShaderNodeTexNoise"); mid.inputs["Scale"].default_value = 3.2; mid.inputs["Detail"].default_value = 8
    fine = node(nt, "ShaderNodeTexNoise"); fine.inputs["Scale"].default_value = 38.0; fine.inputs["Detail"].default_value = 4
    for n_ in (big, mid, fine):
        nt.links.new(tc.outputs["Object"], n_.inputs["Vector"])
    r1 = ramp(nt, [(0.25, "#17414f"), (0.75, "#2f7a62")])
    nt.links.new(mid.outputs["Fac"], r1.inputs["Fac"])
    r2 = ramp(nt, [(0.35, "#000000"), (0.7, "#ffffff")])
    nt.links.new(big.outputs["Fac"], r2.inputs["Fac"])
    patch = node(nt, "ShaderNodeMix"); patch.data_type = "RGBA"
    patch.inputs["B"].default_value = hexc("#5f9a5a")
    patch.inputs["Factor"].default_value = 0.0
    nt.links.new(r1.outputs["Color"], patch.inputs["A"])
    mf = node(nt, "ShaderNodeMath", operation="MULTIPLY"); mf.inputs[1].default_value = 0.45
    nt.links.new(r2.outputs["Color"], mf.inputs[0])
    nt.links.new(mf.outputs[0], patch.inputs["Factor"])
    dk = node(nt, "ShaderNodeMix"); dk.data_type = "RGBA"; dk.blend_type = "MULTIPLY"
    dk.inputs["Factor"].default_value = 0.35
    nt.links.new(patch.outputs["Result"], dk.inputs["A"])
    nt.links.new(fine.outputs["Color"], dk.inputs["B"])
    nt.links.new(dk.outputs["Result"], b.inputs["Base Color"])
    bump = node(nt, "ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.35
    nt.links.new(fine.outputs["Fac"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = 0.92
    return m

def lane_mat():
    m = bpy.data.materials.new("lane"); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    tc = node(nt, "ShaderNodeTexCoord")
    cell = node(nt, "ShaderNodeTexVoronoi"); cell.feature = "F1"; cell.inputs["Scale"].default_value = 9.0
    nt.links.new(tc.outputs["Object"], cell.inputs["Vector"])
    edge = node(nt, "ShaderNodeTexVoronoi"); edge.feature = "DISTANCE_TO_EDGE"; edge.inputs["Scale"].default_value = 9.0
    nt.links.new(tc.outputs["Object"], edge.inputs["Vector"])
    sepc = node(nt, "ShaderNodeSeparateColor"); nt.links.new(cell.outputs["Color"], sepc.inputs["Color"])
    sand = ramp(nt, [(0.0, "#d9b87c"), (1.0, "#f7e6b8")]); nt.links.new(sepc.outputs["Red"], sand.inputs["Fac"])
    mort = ramp(nt, [(0.02, "#6b5238"), (0.09, "#ffffff")]); nt.links.new(edge.outputs["Distance"], mort.inputs["Fac"])
    nz = node(nt, "ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 5.0; nz.inputs["Detail"].default_value = 6
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    mx1 = node(nt, "ShaderNodeMix"); mx1.data_type = "RGBA"; mx1.blend_type = "MULTIPLY"; mx1.inputs["Factor"].default_value = 1.0
    nt.links.new(sand.outputs["Color"], mx1.inputs["A"]); nt.links.new(mort.outputs["Color"], mx1.inputs["B"])
    mx2 = node(nt, "ShaderNodeMix"); mx2.data_type = "RGBA"; mx2.blend_type = "MULTIPLY"; mx2.inputs["Factor"].default_value = 0.28
    nt.links.new(mx1.outputs["Result"], mx2.inputs["A"]); nt.links.new(nz.outputs["Color"], mx2.inputs["B"])
    nt.links.new(mx2.outputs["Result"], b.inputs["Base Color"])
    bump = node(nt, "ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.9; bump.inputs["Distance"].default_value = 0.05
    nt.links.new(edge.outputs["Distance"], bump.inputs["Height"])
    nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = 0.88
    return m

def mossy_rock_mat(base="#8a80a6"):
    key = ("rock", base)
    if key in _mat:
        return _mat[key]
    m = bpy.data.materials.new("rock"); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    tc = node(nt, "ShaderNodeTexCoord"); geo = node(nt, "ShaderNodeNewGeometry")
    nz = node(nt, "ShaderNodeTexNoise"); nz.inputs["Scale"].default_value = 9.0; nz.inputs["Detail"].default_value = 6
    nt.links.new(tc.outputs["Object"], nz.inputs["Vector"])
    rk = ramp(nt, [(0.3, base), (0.7, "#a89cc0")])
    nt.links.new(nz.outputs["Fac"], rk.inputs["Fac"])
    sep = node(nt, "ShaderNodeSeparateXYZ")
    nt.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    mz = node(nt, "ShaderNodeMapRange"); mz.inputs["From Min"].default_value = 0.35; mz.inputs["From Max"].default_value = 0.85
    nt.links.new(sep.outputs["Z"], mz.inputs["Value"])
    nm = node(nt, "ShaderNodeMath", operation="MULTIPLY")
    nt.links.new(mz.outputs["Result"], nm.inputs[0]); nt.links.new(nz.outputs["Fac"], nm.inputs[1])
    nm2 = node(nt, "ShaderNodeMath", operation="MULTIPLY"); nm2.inputs[1].default_value = 0.9
    nt.links.new(nm.outputs[0], nm2.inputs[0])
    moss = node(nt, "ShaderNodeMix"); moss.data_type = "RGBA"
    moss.inputs["B"].default_value = hexc("#5fae52")
    nt.links.new(rk.outputs["Color"], moss.inputs["A"]); nt.links.new(nm2.outputs[0], moss.inputs["Factor"])
    nt.links.new(moss.outputs["Result"], b.inputs["Base Color"])
    bump = node(nt, "ShaderNodeBump"); bump.inputs["Strength"].default_value = 0.6
    nt.links.new(nz.outputs["Fac"], bump.inputs["Height"]); nt.links.new(bump.outputs["Normal"], b.inputs["Normal"])
    b.inputs["Roughness"].default_value = 0.9
    _mat[key] = m
    return m

def foliage_mat(a, b_, name="leaf"):
    key = (name, a, b_)
    if key in _mat:
        return _mat[key]
    m = bpy.data.materials.new(name); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    geo = node(nt, "ShaderNodeNewGeometry"); oi = node(nt, "ShaderNodeObjectInfo")
    sep = node(nt, "ShaderNodeSeparateXYZ"); nt.links.new(geo.outputs["Normal"], sep.inputs["Vector"])
    mr = node(nt, "ShaderNodeMapRange"); mr.inputs["From Min"].default_value = -0.3; mr.inputs["From Max"].default_value = 0.9
    nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
    ad = node(nt, "ShaderNodeMath", operation="ADD"); ad.inputs[1].default_value = 0.0
    nt.links.new(mr.outputs["Result"], ad.inputs[0])
    rr = node(nt, "ShaderNodeMath", operation="MULTIPLY"); rr.inputs[1].default_value = 0.35
    nt.links.new(oi.outputs["Random"], rr.inputs[0])
    sm = node(nt, "ShaderNodeMath", operation="ADD"); nt.links.new(ad.outputs[0], sm.inputs[0]); nt.links.new(rr.outputs[0], sm.inputs[1])
    rp = ramp(nt, [(0.0, a), (1.0, b_)]); nt.links.new(sm.outputs[0], rp.inputs["Fac"])
    nt.links.new(rp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.75
    _mat[key] = m
    return m

def mushroom_cap_mat(cap="#d8383a"):
    key = ("cap", cap)
    if key in _mat:
        return _mat[key]
    m = bpy.data.materials.new("cap"); m.use_nodes = True
    nt = m.node_tree; b = nt.nodes["Principled BSDF"]
    tc = node(nt, "ShaderNodeTexCoord")
    vr = node(nt, "ShaderNodeTexVoronoi"); vr.feature = "DISTANCE_TO_EDGE"; vr.inputs["Scale"].default_value = 26.0
    nt.links.new(tc.outputs["Object"], vr.inputs["Vector"])
    rp = ramp(nt, [(0.02, "#fff4e6"), (0.07, cap)])
    nt.links.new(vr.outputs["Distance"], rp.inputs["Fac"])
    nt.links.new(rp.outputs["Color"], b.inputs["Base Color"])
    b.inputs["Roughness"].default_value = 0.4
    _mat[key] = m
    return m

# ------------------------------------------------------------------ geometry helpers
def link(o):
    bpy.context.collection.objects.link(o)
    return o

def from_bmesh(name, bm, m):
    for f in list(bm.faces):
        vs_ = [v.co for v in f.verts]
        area = sum(vs_[i].x * vs_[(i + 1) % len(vs_)].y - vs_[(i + 1) % len(vs_)].x * vs_[i].y for i in range(len(vs_)))
        if area < 0:
            f.normal_flip()
    bmesh.ops.triangulate(bm, faces=list(bm.faces))
    bm.normal_update()
    me = bpy.data.meshes.new(name); bm.to_mesh(me); bm.free()
    o = bpy.data.objects.new(name, me); link(o)
    me.materials.append(m)
    for p in me.polygons:
        p.use_smooth = True
    return o

_shared = {}
def shared_mesh(key, builder):
    if key not in _shared:
        bm = bmesh.new(); builder(bm)
        me = bpy.data.meshes.new(key); bm.to_mesh(me); bm.free()
        for p_ in me.polygons:
            p_.use_smooth = True
        _shared[key] = me
    return _shared[key]

def sphere_bm(bm, seg=14, rings=9, r=1.0, noise=0.0, seed=0):
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=rings, radius=r)
    if noise > 0:
        rr = random.Random(seed)
        for v in bm.verts:
            v.co *= 1.0 + rr.uniform(-noise, noise)

def inst(name, mesh, m, loc, scale=(1, 1, 1), rot=(0, 0, 0)):
    o = bpy.data.objects.new(name, mesh); link(o)
    if not mesh.materials:
        mesh.materials.append(m)
    o.location = loc; o.scale = scale; o.rotation_euler = rot
    return o

def prim(kind, name, m, loc, **kw):
    if kind == "sphere":
        bpy.ops.mesh.primitive_uv_sphere_add(segments=kw.get("seg", 32), ring_count=kw.get("rings", 16), radius=1.0, location=loc)
    elif kind == "cyl":
        bpy.ops.mesh.primitive_cylinder_add(vertices=kw.get("seg", 32), radius=kw.get("r", 1.0), depth=kw.get("h", 1.0), location=loc)
    elif kind == "cone":
        bpy.ops.mesh.primitive_cone_add(vertices=kw.get("seg", 24), radius1=kw.get("r", 1.0), radius2=kw.get("r2", 0.0), depth=kw.get("h", 1.0), location=loc)
    elif kind == "torus":
        bpy.ops.mesh.primitive_torus_add(major_segments=kw.get("seg", 48), minor_segments=kw.get("mseg", 16), major_radius=kw.get("R", 1.0), minor_radius=kw.get("r", 0.1), location=loc)
    elif kind == "cube":
        bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object; o.name = name
    o.scale = kw.get("scale", (1, 1, 1)); o.rotation_euler = kw.get("rot", (0, 0, 0))
    o.data.materials.clear(); o.data.materials.append(m)
    bpy.ops.object.shade_smooth()
    return o

def dist_to_path(px, py):
    best = 1e9
    for i in range(len(PATH) - 1):
        a = Vector(PATH[i]); b = Vector(PATH[i + 1]); p = Vector((px, py))
        ab = b - a; t = max(0.0, min(1.0, (p - a).dot(ab) / ab.length_squared))
        best = min(best, (p - (a + ab * t)).length)
    return best

def free_spot(px, py, lane=70.0, pads=62.0):
    if dist_to_path(px, py) < lane:
        return False
    for sx, sy, _c in STONES:
        if math.hypot(px - sx, py - sy) < pads:
            return False
    if math.hypot(px - 1190, py - 300) < 110 or math.hypot(px - 54, py - 360) < 90:
        return False
    if ((px - 300) / 200.0) ** 2 + ((py - 650) / 82.0) ** 2 < 1.0:      # pond
        return False
    return True

# ------------------------------------------------------------------ terrain
gm = ground_mat()
N = 260
bpy.ops.mesh.primitive_grid_add(x_subdivisions=N, y_subdivisions=int(N * 0.7), size=1.0, location=(0, 0, 0))
ground = bpy.context.active_object; ground.name = "ground"
ground.scale = (17.0, 12.5, 1.0)
bpy.ops.object.transform_apply(scale=True)
vs = ground.data.vertices
co = np.empty(len(vs) * 3, dtype=np.float32); vs.foreach_get("co", co); co = co.reshape(-1, 3)
rngn = np.random.RandomState(3)
z = 0.045 * (np.sin(co[:, 0] * 1.3) * np.cos(co[:, 1] * 1.7) + 0.5 * np.sin(co[:, 0] * 3.1 + co[:, 1] * 2.3))
co[:, 2] = z
vs.foreach_set("co", co.reshape(-1)); ground.data.update()
ground.data.materials.append(gm)
bpy.ops.object.shade_smooth()

# ------------------------------------------------------------------ lane (pixel-space rectangles + joint discs, converted by G)
lm = lane_mat()
bm = bmesh.new()
def add_poly_px(pts, z):
    vs_ = [bm.verts.new(G(px, py, z)) for px, py in pts]
    try:
        bm.faces.new(vs_)
    except ValueError:
        pass
def seg_poly(i, half, z):
    a = Vector(PATH[i]); b = Vector(PATH[i + 1]); d = (b - a).normalized(); nrm = Vector((-d.y, d.x)) * half
    a2 = a - d * half if i > 0 else a
    b2 = b + d * half if i < len(PATH) - 2 else b
    add_poly_px([a2 - nrm, b2 - nrm, b2 + nrm, a2 + nrm], z)
for i in range(len(PATH) - 1):
    seg_poly(i, LANE_W / 2, 0.075 + 0.0007 * i)
lane = from_bmesh("lane", bm, lm)
# lane edge: darker earthy border strip slightly wider and lower
bm = bmesh.new()
for i in range(len(PATH) - 1):
    seg_poly(i, LANE_W / 2 + 9, 0.06 + 0.0007 * i)
from_bmesh("laneedge", bm, mat("laneedge", "#6f5a46", 0.95))

# edge stones along both sides (shared mesh, varied scale)
rock_m = mossy_rock_mat()
stone_mesh = shared_mesh("stoneE", lambda b: sphere_bm(b, 12, 8, 1.0, 0.18, 4))
for i in range(len(PATH) - 1):
    a = Vector(PATH[i]); b = Vector(PATH[i + 1]); L = (b - a).length; d = (b - a).normalized(); nrm = Vector((-d.y, d.x))
    n = int(L / 22)
    for k in range(n):
        for side in (-1, 1):
            if rnd.random() < 0.18:
                continue
            p = a + d * (k * 22 + rnd.uniform(0, 10)) + nrm * side * (LANE_W / 2 + 8 + rnd.uniform(-2, 4))
            w = G(p.x, p.y, 0.07)
            sz = rnd.uniform(0.085, 0.15)
            inst("es", stone_mesh, rock_m, w, (sz * 1.15, sz * 0.95, sz * 0.6), (0, 0, rnd.uniform(0, 3)))

# ------------------------------------------------------------------ rune pads
for (sx, sy, col) in STONES:
    c = G(sx, sy, 0.06)
    prim("cyl", "pad", mossy_rock_mat("#8a809e"), c + Vector((0, 0, 0.04)), r=0.5, h=0.09, seg=48)
    prim("cyl", "padtop", mat("padtop", "#6b6288", 0.6), c + Vector((0, 0, 0.1)), r=0.42, h=0.03, seg=48)
    prim("torus", "padring", mat("padglow_" + col, col, 0.4, 3.5), c + Vector((0, 0, 0.125)), R=0.34, r=0.018, seg=64)
    for k in range(4):
        a_ = k * math.pi / 2 + math.pi / 4
        prim("cube", "padrune", mat("padglow_" + col, col, 0.4, 3.5), c + Vector((math.cos(a_) * 0.17, math.sin(a_) * 0.17, 0.125)), scale=(0.2, 0.028, 0.012), rot=(0, 0, a_))
    prim("sphere", "padgem", mat("padglow_" + col, col, 0.4, 4.0), c + Vector((0, 0, 0.14)), scale=(0.05, 0.05, 0.03), seg=16, rings=8)
    pl = bpy.data.lights.new("padlight", 'POINT'); pl.energy = 14; pl.color = hexc(col)[:3]; pl.shadow_soft_size = 0.2
    lo = bpy.data.objects.new("padlight", pl); link(lo); lo.location = c + Vector((0, 0, 0.3))

# ------------------------------------------------------------------ trees, rocks, mushrooms, flowers, grass
leaf_m = foliage_mat("#1f6a68", "#6fc07a", "canopy")
leaf2_m = foliage_mat("#355f9a", "#7fd0c0", "canopy2")
trunk_m = mat("trunk", "#5b3f66", 0.9)
cap_red = mushroom_cap_mat("#d8383a"); cap_pink = mushroom_cap_mat("#e8639a")
stem_m = mat("stem", "#f1e4d2", 0.7)
glowcap = mat("glowcap", "#7fe8ff", 0.4, 3.0)

puff_mesh = None
def tree(px, py, k=1.0, blue=False):
    global puff_mesh
    base = G(px, py, 0.05)
    h = 1.3 * k
    prev = base
    for i in range(6):
        t = (i + 1) / 6.0
        nxt = base + Vector((math.sin(t * 2.4 + px) * 0.12 * k, 0.04 * i * k, h * t))
        mid = (prev + nxt) / 2; ln = (nxt - prev).length
        d = (nxt - prev).normalized()
        rot = Vector((0, 0, 1)).rotation_difference(d).to_euler()
        rad = 0.17 * k * (1 - t * 0.55)
        prim("cyl", "trunk", trunk_m, mid, r=rad, h=ln * 1.05, seg=14, rot=rot)
        prev = nxt
    # root flare
    for q in range(4):
        a_ = q * 1.57 + px
        prim("cone", "root", trunk_m, base + Vector((math.cos(a_) * 0.15 * k, math.sin(a_) * 0.15 * k, 0.05)), r=0.07 * k, r2=0.01, h=0.22 * k, seg=8, rot=(math.cos(a_) * 1.1, math.sin(a_) * 1.1, 0))
    top = prev
    cm = leaf2_m if blue else leaf_m
    if puff_mesh is None:
        puff_mesh = shared_mesh("puff", lambda b: sphere_bm(b, 10, 7, 1.0, 0.12, 3))
    clumps = [(0, 0, 0.35, 0.62), (-0.42, 0.05, 0.18, 0.46), (0.45, -0.02, 0.2, 0.48), (0.05, 0.3, 0.6, 0.4), (-0.15, -0.3, 0.12, 0.42)]
    for j, (dx, dy, dz, r_) in enumerate(clumps):
        me = shared_mesh(f"canopy{j}", lambda b, j=j: sphere_bm(b, 20, 14, 1.0, 0.1, j + 20))
        c0 = top + Vector((dx * k, dy * k, dz * k))
        inst("canopy", me, cm, c0, (r_ * k * 1.0, r_ * k * 0.95, r_ * k * 0.82), (0, 0, rnd.uniform(0, 6)))
        # leaf puffs on the upper surface of each clump: lumpy painterly silhouette
        for q in range(14):
            th = rnd.uniform(0, 6.283); ph = rnd.uniform(0.1, 1.25)
            off = Vector((math.cos(th) * math.cos(ph), math.sin(th) * math.cos(ph), math.sin(ph) * 0.85)) * r_ * k * 0.95
            sz = rnd.uniform(0.07, 0.12) * k
            inst("puff", puff_mesh, cm, c0 + off, (sz * 1.2, sz * 1.2, sz * 0.8), (0, 0, rnd.uniform(0, 6)))
    for q in range(7):   # glowing fruit
        a_ = rnd.uniform(0, 6.28)
        prim("sphere", "fruit", mat("fruit", "#ffd86a", 0.4, 4.0), top + Vector((math.cos(a_) * 0.55 * k, math.sin(a_) * 0.45 * k, rnd.uniform(0.0, 0.7) * k)), scale=(0.035,) * 3, seg=8, rings=6)

def rock(px, py, k=1.0):
    me = shared_mesh("rockM", lambda b: sphere_bm(b, 14, 9, 1.0, 0.28, 9))
    inst("rock", me, mossy_rock_mat(), G(px, py, 0.05), (0.32 * k, 0.26 * k, 0.2 * k), (0, 0, rnd.uniform(0, 6)))

def mushroom(px, py, k=1.0, glow=False):
    base = G(px, py, 0.06)
    prim("cyl", "stem", stem_m, base + Vector((0, 0, 0.06 * k)), r=0.026 * k, h=0.12 * k, seg=10)
    cap = glowcap if glow else rnd.choice([cap_red, cap_red, cap_pink])
    prim("sphere", "cap", cap, base + Vector((0, 0, 0.13 * k)), scale=(0.1 * k, 0.1 * k, 0.065 * k), seg=16, rings=10)

def flower(px, py):
    base = G(px, py, 0.06)
    col = rnd.choice(["#ffe36a", "#ff9ad8", "#a8e8ff", "#c8a8ff"])
    prim("cyl", "stalk", mat("stalk", "#3f8f56", 0.8), base + Vector((0, 0, 0.05)), r=0.006, h=0.1, seg=6)
    prim("sphere", "bloom", mat("bloom_" + col, col, 0.5, 1.6), base + Vector((0, 0, 0.11)), scale=(0.03, 0.03, 0.022), seg=10, rings=6)

tuft_mesh = shared_mesh("tuft", lambda b: [bmesh.ops.create_cone(b, cap_ends=False, segments=5, radius1=0.02, radius2=0.0, depth=0.18, matrix=__import__("mathutils").Matrix.Translation((rnd.uniform(-0.03, 0.03), rnd.uniform(-0.03, 0.03), 0.09)) @ __import__("mathutils").Matrix.Rotation(rnd.uniform(-0.3, 0.3), 4, 'X')) for _ in range(5)])
tuft_m = foliage_mat("#1f5a4a", "#5fa862", "grass")

# trees: borders and corners, kept away from the lane and pads
tree_spots = [(60, 112, 1.0), (175, 82, 0.9), (330, 70, 0.8), (470, 60, 0.95), (610, 70, 0.8), (800, 66, 0.9), (940, 84, 0.85), (1075, 70, 1.0), (1215, 130, 0.95),
              (36, 590, 0.9), (520, 706, 0.7), (850, 706, 0.8), (1090, 690, 0.9), (1228, 600, 0.9), (1236, 470, 0.8), (70, 470, 0.75)]
for i, (tx, ty, k) in enumerate(tree_spots):
    tree(tx, ty, k * 0.8, blue=(i % 5 == 2))

# scatter rocks / mushrooms / flowers / tufts in free ground
placed = []
def scatter(n, fn, min_gap=34, tries=2500, **kw):
    c = 0; t = 0
    while c < n and t < tries:
        t += 1
        px = rnd.uniform(20, 1260); py = rnd.uniform(70, 700)
        if not free_spot(px, py, **kw):
            continue
        if any(math.hypot(px - qx, py - qy) < min_gap for qx, qy in placed):
            continue
        placed.append((px, py)); fn(px, py); c += 1
scatter(16, lambda x, y: rock(x, y, rnd.uniform(0.7, 1.4)), 46)
scatter(22, lambda x, y: [mushroom(x + rnd.uniform(-14, 14), y + rnd.uniform(-10, 10), rnd.uniform(0.8, 1.5)) for _ in range(rnd.randint(1, 3))], 40)
scatter(14, lambda x, y: [mushroom(x + rnd.uniform(-12, 12), y + rnd.uniform(-9, 9), rnd.uniform(0.7, 1.2), True) for _ in range(rnd.randint(2, 4))], 46)
scatter(40, lambda x, y: [flower(x + rnd.uniform(-12, 12), y + rnd.uniform(-9, 9)) for _ in range(rnd.randint(2, 5))], 30)
placed_t = []
for _ in range(560):
    px = rnd.uniform(10, 1270); py = rnd.uniform(60, 710)
    if dist_to_path(px, py) < 52 or any(math.hypot(px - sx, py - sy) < 50 for sx, sy, _c in STONES):
        continue
    inst("tuft", tuft_mesh, tuft_m, G(px, py, 0.05), (rnd.uniform(0.6, 1.2),) * 3, (0, 0, rnd.uniform(0, 6)))


# ------------------------------------------------------------------ extra decor (non-buildable bands + borders)
fern_m = foliage_mat("#1d6a52", "#7fd08a", "fern")
def fern(px, py, k=1.0):
    base = G(px, py, 0.06)
    for q in range(9):
        a_ = q * 0.7 + rnd.uniform(-0.2, 0.2)
        ln = rnd.uniform(0.28, 0.42) * k
        tilt = rnd.uniform(0.9, 1.25)
        c = base + Vector((math.cos(a_) * ln * 0.45, math.sin(a_) * ln * 0.45, 0.05 + ln * 0.18))
        prim("cone", "frond", fern_m, c, r=0.045 * k, r2=0.0, h=ln, seg=6, scale=(1.0, 0.35, 1.0), rot=(math.sin(a_) * tilt, -math.cos(a_) * tilt, a_))

def giant_mushroom(px, py, k=1.0, col="#7fe8ff"):
    base = G(px, py, 0.06)
    gm_ = mat("gmush_" + col, col, 0.4, 2.6)
    prim("cyl", "gstem", stem_m, base + Vector((0, 0, 0.22 * k)), r=0.07 * k, h=0.44 * k, seg=12)
    prim("sphere", "gcap", mat("gcap_" + col, "#8a62d8", 0.45), base + Vector((0, 0, 0.5 * k)), scale=(0.3 * k, 0.3 * k, 0.17 * k), seg=20, rings=12)
    for q in range(10):
        a_ = q * 0.63
        prim("sphere", "gdot", gm_, base + Vector((math.cos(a_) * 0.19 * k, math.sin(a_) * 0.19 * k, 0.58 * k + 0.02 * (q % 3))), scale=(0.05 * k,) * 3, seg=8, rings=6)
    prim("sphere", "gtop", gm_, base + Vector((0, 0, 0.64 * k)), scale=(0.09 * k, 0.09 * k, 0.04 * k), seg=12, rings=6)
    gl_ = bpy.data.lights.new("gml", 'POINT'); gl_.energy = 6; gl_.color = hexc(col)[:3]; gl_.shadow_soft_size = 0.2
    lo_ = bpy.data.objects.new("gml", gl_); link(lo_); lo_.location = base + Vector((0, 0, 0.35 * k))

def log(px, py, rot=0.0):
    c = G(px, py, 0.12)
    prim("cyl", "log", trunk_m, c, r=0.13, h=0.9, seg=16, rot=(0, math.pi / 2, rot))
    ca = Vector((math.cos(rot) * 0.45, math.sin(rot) * 0.45 * -1, 0))
    for sgn in (1, -1):
        prim("cyl", "logend", mat("logend", "#c9a46a", 0.7), c + Vector((math.cos(rot) * 0.45 * sgn, -math.sin(rot) * 0.45 * sgn, 0)), r=0.115, h=0.02, seg=16, rot=(0, math.pi / 2, rot))
    for q in range(3):
        mushroom(px + (q - 1) * 14, py - 6, 0.9)
    prim("cone", "logmoss", foliage_mat("#2f7d58", "#9ad66a", "moss"), c + Vector((0, 0, 0.13)), r=0.1, r2=0.08, h=0.5, seg=10, scale=(1.4, 0.7, 0.35), rot=(0, 0, rot))

def sign(px, py):
    b0 = G(px, py, 0.06)
    prim("cyl", "signpost", trunk_m, b0 + Vector((0, 0, 0.35)), r=0.035, h=0.7, seg=10)
    prim("cube", "signboard", mat("signboard", "#c9a46a", 0.7), b0 + Vector((0.0, -0.02, 0.62)), scale=(0.42, 0.04, 0.2), rot=(0, 0, 0.12))
    prim("cube", "signrune", mat("signrune", "#ffe9a8", 0.4, 3.0), b0 + Vector((0.0, -0.045, 0.62)), scale=(0.2, 0.012, 0.04), rot=(0, 0, 0.12))
    prim("cube", "signarrow", mat("signboard2", "#b98a52", 0.7), b0 + Vector((0.12, -0.02, 0.45)), scale=(0.3, 0.035, 0.11), rot=(0, 0, -0.18))

def fence(x0, y0, x1, y1):
    a_ = Vector((x0, y0)); b_ = Vector((x1, y1)); L = (b_ - a_).length; d = (b_ - a_).normalized()
    n = max(2, int(L / 38))
    ang = math.atan2(-(d.y), d.x)
    for q in range(n + 1):
        p = a_ + d * (L * q / n)
        prim("cyl", "post", trunk_m, G(p.x, p.y, 0.4 + 0.05 * 0), r=0.035, h=0.55 + 0.05 * (q % 2), seg=8)
    for hz in (0.28, 0.45):
        mid = (a_ + b_) / 2
        prim("cube", "rail", mat("rail", "#8a6a4a", 0.8), G(mid.x, mid.y, hz), scale=(L / S * 1.0, 0.035, 0.035), rot=(0, 0, ang))

# pond in the bottom-left band (under the shop bar, never buildable)
pond_c = G(300, 650, 0.02)
prim("cyl", "pondbank", mossy_rock_mat("#6a6a90"), pond_c + Vector((0, 0, 0.0)), r=1.0, h=0.06, seg=64, scale=(1.7, 0.66, 1.0))
water_m = bpy.data.materials.new("water"); water_m.use_nodes = True
nt = water_m.node_tree; wb = nt.nodes["Principled BSDF"]
wb.inputs["Base Color"].default_value = hexc("#1a4f78"); wb.inputs["Roughness"].default_value = 0.12
wb.inputs["Metallic"].default_value = 0.0
try:
    wb.inputs["Specular IOR Level"].default_value = 0.9
except Exception:
    pass
tcw = node(nt, "ShaderNodeTexCoord"); wv = node(nt, "ShaderNodeTexNoise"); wv.inputs["Scale"].default_value = 2.2; wv.inputs["Detail"].default_value = 4
nt.links.new(tcw.outputs["Object"], wv.inputs["Vector"])
wr = ramp(nt, [(0.3, "#1a5c86"), (0.7, "#2f86b0")]); nt.links.new(wv.outputs["Fac"], wr.inputs["Fac"])
nt.links.new(wr.outputs["Color"], wb.inputs["Base Color"])
wbump = node(nt, "ShaderNodeBump"); wbump.inputs["Strength"].default_value = 0.06
nt.links.new(wv.outputs["Fac"], wbump.inputs["Height"]); nt.links.new(wbump.outputs["Normal"], wb.inputs["Normal"])
prim("cyl", "water", water_m, pond_c + Vector((0, 0, 0.045)), r=0.94, h=0.03, seg=64, scale=(1.62, 0.62, 1.0))
lily_m = foliage_mat("#2a8a5a", "#7fd08a", "lily")
for q in range(7):
    a_ = rnd.uniform(0, 6.28); rr = rnd.uniform(0.2, 0.9)
    lp_ = pond_c + Vector((math.cos(a_) * rr * 1.45, math.sin(a_) * rr * 0.55, 0.07))
    prim("cyl", "lily", lily_m, lp_, r=0.11, h=0.01, seg=14)
    if q % 2 == 0:
        prim("sphere", "lotus", mat("lotus", "#ff9ad8", 0.5, 2.2), lp_ + Vector((0, 0, 0.04)), scale=(0.045, 0.045, 0.05), seg=10, rings=6)
pl2 = bpy.data.lights.new("pondlight", 'POINT'); pl2.energy = 12; pl2.color = (1.0, 0.6, 0.9); pl2.shadow_soft_size = 0.3
lo2 = bpy.data.objects.new("pondlight", pl2); link(lo2); lo2.location = pond_c + Vector((0, 0, 0.4))
for q in range(10):
    a_ = q * 0.63
    inst("pstone", stone_mesh, rock_m, pond_c + Vector((math.cos(a_) * 1.72, math.sin(a_) * 0.68, 0.05)), (0.13, 0.11, 0.08), (0, 0, a_))

# bottom band (below y 600) and left/right margins: denser, richer scenery since nothing can be built there
for (fx, fy) in [(60, 520), (130, 595), (520, 690), (560, 655), (700, 700), (900, 690), (1160, 600), (1230, 660), (1240, 520), (420, 575), (1130, 700)]:
    fern(fx, fy, rnd.uniform(0.9, 1.3))
for (gx_, gy_, gk, gc) in [(40, 610, 1.2, "#7fe8ff"), (470, 668, 1.0, "#ff9ad8"), (780, 676, 1.3, "#7fe8ff"), (1180, 650, 1.1, "#c8a8ff"), (1250, 420, 0.9, "#7fe8ff"), (30, 330, 0.9, "#ff9ad8")]:
    giant_mushroom(gx_, gy_, gk, gc)
log(640, 668, 0.3)
log(1030, 120, -0.2)
sign(110, 400)
fence(20, 470, 20, 560)
fence(1262, 380, 1262, 470)

# ------------------------------------------------------------------ gate (spawn) and Well (goal)
gstone = mossy_rock_mat("#8a809e")
gx, gy = PATH[0]
for sgn in (-1, 1):
    base = G(gx + 6, gy + sgn * 58, 0.06)
    prim("cyl", "pillar", gstone, base + Vector((0, 0, 0.5)), r=0.2, h=1.0, seg=20)
    prim("cyl", "pillarcap", gstone, base + Vector((0, 0, 1.03)), r=0.26, h=0.1, seg=20)
    prim("sphere", "pillarball", mat("gateglow", "#ffe9a8", 0.4, 0.7), base + Vector((0, 0, 1.2)), scale=(0.07,) * 3, seg=16, rings=8)
    prim("cone", "pillarmoss", foliage_mat("#2f7d58", "#9ad66a", "moss"), base + Vector((0, 0, 0.3)), r=0.23, r2=0.19, h=0.6, seg=18)
arch_c = G(gx + 6, gy, 1.0)
ARC_R = 0.62
for k in range(13):
    t = math.pi * k / 12.0     # 0..pi over the top, in the YZ plane
    pos = arch_c + Vector((0, math.cos(t) * ARC_R, math.sin(t) * ARC_R * 0.78))
    prim("cube", "voussoir", gstone if k % 2 else mossy_rock_mat("#9a90b4"), pos, scale=(0.22, 0.17, 0.12), rot=(t - math.pi / 2, 0, 0))
prim("cube", "keystone", mossy_rock_mat("#a89cc0"), arch_c + Vector((0, 0, ARC_R * 0.78 + 0.03)), scale=(0.26, 0.2, 0.17))
prim("sphere", "archlamp", mat("gateglow", "#ffe9a8", 0.4, 3.0), arch_c + Vector((0.13, 0, ARC_R * 0.78 - 0.17)), scale=(0.06, 0.06, 0.08), seg=16, rings=8)
prim("cone", "archvine", foliage_mat("#235f4d", "#5fa862", "vine"), arch_c + Vector((0.02, 0.35, ARC_R * 0.6)), r=0.07, r2=0.02, h=0.3, seg=8)
gl = bpy.data.lights.new("gatelight", 'POINT'); gl.energy = 120; gl.color = (1.0, 0.85, 0.55); gl.shadow_soft_size = 0.25
lo = bpy.data.objects.new("gatelight", gl); link(lo); lo.location = arch_c + Vector((0.15, 0, 0.55))

wx, wy = PATH[-1]
wc = G(wx, wy - 4, 0.06)
prim("torus", "wellring", gstone, wc + Vector((0, 0, 0.14)), R=0.62, r=0.17, seg=64, mseg=24)
prim("cyl", "wellwater", mat("wellwater", "#8a6a2a", 0.2, 0.9, "#ffd98a"), wc + Vector((0, 0, 0.17)), r=0.58, h=0.04, seg=64)
prim("sphere", "wellcore", mat("wellcore", "#fff0c0", 0.3, 1.1), wc + Vector((0, 0, 0.3)), scale=(0.28, 0.28, 0.1), seg=24, rings=12)
for k in range(9):
    a_ = k * 2 * math.pi / 9 + 0.2
    p_ = wc + Vector((math.cos(a_) * 1.0, math.sin(a_) * 1.0, 0.0))
    prim("cube", "standing", gstone, p_ + Vector((0, 0, 0.3)), scale=(0.16, 0.1, 0.6 + 0.12 * (k % 3)), rot=(0, 0, a_ + 1.57))
    prim("cube", "runeS", mat("runeW", "#ffe9a8", 0.4, 3.5), p_ + Vector((math.cos(a_) * -0.055, math.sin(a_) * -0.055, 0.38)), scale=(0.02, 0.05, 0.22), rot=(0, 0, a_ + 1.57))
wl = bpy.data.lights.new("welllight", 'POINT'); wl.energy = 14; wl.color = (1.0, 0.88, 0.55); wl.shadow_soft_size = 0.5
lo = bpy.data.objects.new("welllight", wl); link(lo); lo.location = wc + Vector((0, 0, 1.6))
# light column (emissive, translucent)
col_m = bpy.data.materials.new("beam"); col_m.use_nodes = True
nt = col_m.node_tree; nt.nodes.clear()
em = node(nt, "ShaderNodeEmission"); em.inputs["Color"].default_value = hexc("#fff0b8"); em.inputs["Strength"].default_value = 1.0
tr = node(nt, "ShaderNodeBsdfTransparent"); mx = node(nt, "ShaderNodeMixShader"); mx.inputs[0].default_value = 0.02
o_ = node(nt, "ShaderNodeOutputMaterial")
nt.links.new(tr.outputs[0], mx.inputs[1]); nt.links.new(em.outputs[0], mx.inputs[2]); nt.links.new(mx.outputs[0], o_.inputs[0])
prim("cone", "beam", col_m, wc + Vector((0, 0, 1.2)), r=0.55, r2=0.22, h=2.3, seg=40)

# ------------------------------------------------------------------ lanterns + fireflies
for (lx, ly) in [(230, 420), (640, 105), (770, 625), (940, 610), (1085, 245), (400, 300)]:
    if dist_to_path(lx, ly) < 60:
        continue
    b0 = G(lx, ly, 0.06)
    prim("cyl", "post", trunk_m, b0 + Vector((0, 0, 0.4)), r=0.03, h=0.8, seg=10)
    prim("cube", "lantern", mat("lantern", "#ffcf70", 0.4, 7.0), b0 + Vector((0, 0, 0.86)), scale=(0.1, 0.1, 0.14))
    prim("cone", "lanternhat", mat("hat", "#5b3f66", 0.8), b0 + Vector((0, 0, 0.99)), r=0.095, h=0.08, seg=4)
    ll = bpy.data.lights.new("lantern", 'POINT'); ll.energy = 55; ll.color = (1.0, 0.8, 0.45); ll.shadow_soft_size = 0.12
    lo = bpy.data.objects.new("lantern", ll); link(lo); lo.location = b0 + Vector((0, 0, 0.9))
for _ in range(46):
    px = rnd.uniform(40, 1240); py = rnd.uniform(90, 690)
    col = rnd.choice(["#e8ff8a", "#9ff0ff", "#ffe08a"])
    prim("sphere", "ff", mat("ff_" + col, col, 0.4, 14.0), G(px, py, rnd.uniform(0.25, 1.1)), scale=(0.022,) * 3, seg=8, rings=6)

# ------------------------------------------------------------------ lighting + camera + render
world = bpy.data.worlds.new("w"); world.use_nodes = True
bgn = world.node_tree.nodes["Background"]; bgn.inputs[0].default_value = hexc("#3c3c92"); bgn.inputs[1].default_value = 1.1
sc.world = world
def sun(name, rot, energy, col, angle=0.08):
    ld = bpy.data.lights.new(name, 'SUN'); ld.energy = energy; ld.color = col[:3]; ld.angle = angle
    lo = bpy.data.objects.new(name, ld); link(lo); lo.rotation_euler = rot
sun("key", (math.radians(52), 0, math.radians(-38)), 2.6, hexc("#ffc98a"), 0.05)
sun("rim", (math.radians(62), 0, math.radians(150)), 1.1, hexc("#8ab4ff"), 0.1)

H = int(WIDTH * 9 / 16)
cd = bpy.data.cameras.new("cam"); cd.type = 'ORTHO'; cd.ortho_scale = 12.8
cam = bpy.data.objects.new("cam", cd); link(cam); sc.camera = cam
e = math.radians(EL); dd = 30.0
cam.location = (0, -dd * math.cos(e), dd * math.sin(e))
cam.rotation_euler = (Vector((0, 0, 0)) - cam.location).to_track_quat('-Z', 'Y').to_euler()
cd.clip_end = 200
sc.render.engine = 'CYCLES'; sc.cycles.device = 'CPU'; sc.cycles.samples = SAMPLES
try:
    sc.cycles.use_denoising = True; sc.cycles.denoiser = 'OPENIMAGEDENOISE'
except Exception:
    sc.cycles.use_denoising = False
sc.cycles.max_bounces = 4; sc.cycles.diffuse_bounces = 3
sc.render.resolution_x = WIDTH; sc.render.resolution_y = H
sc.render.film_transparent = False
sc.view_settings.view_transform = 'AgX'
try:
    sc.view_settings.look = 'AgX - Medium High Contrast'
except Exception:
    pass
sc.render.image_settings.file_format = 'PNG'
sc.render.filepath = out
if DEBUG:
    # path overlay for alignment checking: thin emissive polyline along the exact game path
    bm = bmesh.new()
    for i in range(len(PATH) - 1):
        a = Vector(PATH[i]); b = Vector(PATH[i + 1]); d = (b - a).normalized(); nrm = Vector((-d.y, d.x)) * 2.0
        vs_ = [bm.verts.new(G(*(p), 0.09)) for p in (a - nrm, b - nrm, b + nrm, a + nrm)]
        bm.faces.new(vs_)
    from_bmesh("dbg", bm, mat("dbg", "#ff00ff", 0.5, 10.0))
bpy.ops.render.render(write_still=True)
print("map ok")
