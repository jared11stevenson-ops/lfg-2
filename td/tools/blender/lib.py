"""Shared Blender (bpy) toolkit for Wellfall creature models.
Toon look: 3-band cel shading from a fixed light direction (works in Cycles and EEVEE), rim light, ink outline from an
inverted-hull shell (backfaces only). Everything is built from script so models are reproducible.
Run with the pip `bpy` module:  python3 td/tools/blender/tickindle.py
"""
import bpy, math, bmesh
from mathutils import Vector

INK = (0.07, 0.04, 0.13, 1.0)
LINE_PX = 5.5
LIGHT = Vector((-0.55, -0.45, 0.75)).normalized()   # toward the light, world space

def reset():
    global _ink
    _mats.clear()
    _ink = None
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.context.scene.render.engine = 'CYCLES'

def _col(c, a=1.0):
    return (c[0], c[1], c[2], a) if len(c) == 3 else c

def hexc(h):
    h = h.lstrip('#')
    r, g, b = [int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4)]
    # sRGB -> linear
    f = lambda c: c / 12.92 if c <= 0.04045 else ((c + 0.055) / 1.055) ** 2.4
    return (f(r), f(g), f(b), 1.0)

_mats = {}

def toon_mat(name, color, shadow=(0.55, 0.5, 0.75), rim=0.18, glow=0.0, spec=0.0, ao=0.5):
    """Cel-shaded material with soft band edges, contact-shadow AO and an optional toon specular glint.
    color: hex or rgba. glow>0 makes it emissive (lanterns, flames, glowing eyes). spec 0..1: glossy highlight strength."""
    key = (name, str(color), glow, spec, ao)
    if key in _mats:
        return _mats[key]
    base = hexc(color) if isinstance(color, str) else _col(color)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    if glow > 0.0:
        em = nt.nodes.new('ShaderNodeEmission')
        em.inputs['Color'].default_value = base
        em.inputs['Strength'].default_value = glow
        nt.links.new(em.outputs[0], out.inputs[0])
        _mats[key] = m
        return m
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    dot = nt.nodes.new('ShaderNodeVectorMath')
    dot.operation = 'DOT_PRODUCT'
    dot.inputs[1].default_value = LIGHT
    nt.links.new(geo.outputs['Normal'], dot.inputs[0])
    ma = nt.nodes.new('ShaderNodeMath')
    ma.operation = 'MULTIPLY_ADD'
    ma.inputs[1].default_value = 0.5
    ma.inputs[2].default_value = 0.5
    nt.links.new(dot.outputs['Value'], ma.inputs[0])
    ramp = nt.nodes.new('ShaderNodeValToRGB')
    cr = ramp.color_ramp
    cr.interpolation = 'LINEAR'
    dark = (shadow[0] * 0.62, shadow[1] * 0.58, shadow[2] * 0.85, 1)
    mid = (min(1, shadow[0] * 1.3 + 0.12), min(1, shadow[1] * 1.3 + 0.12), min(1, shadow[2] * 1.15 + 0.1), 1)
    cr.elements[0].position = 0.0
    cr.elements[0].color = dark
    for pos, col in ((0.34, dark), (0.44, mid), (0.56, mid), (0.64, (1, 1, 1, 1)), (1.0, (1, 1, 1, 1))):
        if pos == 1.0:
            cr.elements[1].position = pos
            cr.elements[1].color = col
        else:
            e = cr.elements.new(pos)
            e.color = col
    nt.links.new(ma.outputs[0], ramp.inputs['Fac'])
    mul = nt.nodes.new('ShaderNodeMix')
    mul.data_type = 'RGBA'
    mul.blend_type = 'MULTIPLY'
    mul.inputs['Factor'].default_value = 1.0
    mul.inputs['A'].default_value = base
    nt.links.new(ramp.outputs['Color'], mul.inputs['B'])
    last = mul.outputs['Result']
    # contact-shadow ambient occlusion
    if ao > 0.0:
        ao_n = nt.nodes.new('ShaderNodeAmbientOcclusion')
        ao_n.inputs['Distance'].default_value = 0.35
        ao_n.samples = 6
        inv_ao = nt.nodes.new('ShaderNodeMath')
        inv_ao.operation = 'SUBTRACT'
        inv_ao.inputs[0].default_value = 1.0
        nt.links.new(ao_n.outputs['AO'], inv_ao.inputs[1])
        sc = nt.nodes.new('ShaderNodeMath')
        sc.operation = 'MULTIPLY'
        sc.inputs[1].default_value = ao
        nt.links.new(inv_ao.outputs[0], sc.inputs[0])
        aomix = nt.nodes.new('ShaderNodeMix')
        aomix.data_type = 'RGBA'
        aomix.blend_type = 'MIX'
        aomix.inputs['B'].default_value = (0.10, 0.05, 0.22, 1.0)
        nt.links.new(last, aomix.inputs['A'])
        nt.links.new(sc.outputs[0], aomix.inputs['Factor'])
        last = aomix.outputs['Result']
    lw = nt.nodes.new('ShaderNodeLayerWeight')
    lw.inputs['Blend'].default_value = 0.5
    rr = nt.nodes.new('ShaderNodeValToRGB')
    rr.color_ramp.interpolation = 'CONSTANT'
    rr.color_ramp.elements[0].position = 0.0
    rr.color_ramp.elements[0].color = (0, 0, 0, 1)
    r1 = rr.color_ramp.elements.new(0.78)
    r1.color = (1, 1, 1, 1)
    inv = nt.nodes.new('ShaderNodeMath')
    inv.operation = 'SUBTRACT'
    inv.inputs[0].default_value = 1.0
    nt.links.new(lw.outputs['Facing'], inv.inputs[1])
    nt.links.new(inv.outputs[0], rr.inputs['Fac'])
    rim_mix = nt.nodes.new('ShaderNodeMix')
    rim_mix.data_type = 'RGBA'
    rim_mix.blend_type = 'ADD'
    rim_mix.inputs['Factor'].default_value = rim
    nt.links.new(last, rim_mix.inputs['A'])
    nt.links.new(rr.outputs['Color'], rim_mix.inputs['B'])
    last = rim_mix.outputs['Result']
    # toon specular: a hard white glint where the half-vector aligns with the normal
    if spec > 0.0:
        neg = nt.nodes.new('ShaderNodeVectorMath')
        neg.operation = 'SCALE'
        neg.inputs['Scale'].default_value = -1.0
        nt.links.new(geo.outputs['Incoming'], neg.inputs[0])
        add = nt.nodes.new('ShaderNodeVectorMath')
        add.operation = 'ADD'
        add.inputs[1].default_value = LIGHT
        nt.links.new(neg.outputs[0], add.inputs[0])
        nrm = nt.nodes.new('ShaderNodeVectorMath')
        nrm.operation = 'NORMALIZE'
        nt.links.new(add.outputs[0], nrm.inputs[0])
        sd = nt.nodes.new('ShaderNodeVectorMath')
        sd.operation = 'DOT_PRODUCT'
        nt.links.new(nrm.outputs[0], sd.inputs[0])
        nt.links.new(geo.outputs['Normal'], sd.inputs[1])
        sr = nt.nodes.new('ShaderNodeValToRGB')
        sr.color_ramp.interpolation = 'CONSTANT'
        sr.color_ramp.elements[0].position = 0.0
        sr.color_ramp.elements[0].color = (0, 0, 0, 1)
        s1 = sr.color_ramp.elements.new(0.965)
        s1.color = (1, 1, 1, 1)
        nt.links.new(sd.outputs['Value'], sr.inputs['Fac'])
        sp = nt.nodes.new('ShaderNodeMix')
        sp.data_type = 'RGBA'
        sp.blend_type = 'ADD'
        sp.inputs['Factor'].default_value = spec
        nt.links.new(last, sp.inputs['A'])
        nt.links.new(sr.outputs['Color'], sp.inputs['B'])
        last = sp.outputs['Result']
    em = nt.nodes.new('ShaderNodeEmission')
    nt.links.new(last, em.inputs['Color'])
    nt.links.new(em.outputs[0], out.inputs[0])
    _mats[key] = m
    return m

def glass_mat(name, color, alpha=0.35):
    """See-through tinted glass (snow globes, goggles)."""
    key = (name, str(color), alpha, 'glass')
    if key in _mats:
        return _mats[key]
    base = hexc(color) if isinstance(color, str) else _col(color)
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    em = nt.nodes.new('ShaderNodeEmission')
    em.inputs['Color'].default_value = base
    tr = nt.nodes.new('ShaderNodeBsdfTransparent')
    mix = nt.nodes.new('ShaderNodeMixShader')
    mix.inputs['Fac'].default_value = alpha
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    _mats[key] = m
    return m

_ink = None
def ink_mat():
    """Outline material: black on backfaces only, transparent on front faces (inverted hull in Cycles)."""
    global _ink
    if _ink is not None:
        return _ink
    m = bpy.data.materials.new("Ink")
    m.use_nodes = True
    nt = m.node_tree
    nt.nodes.clear()
    out = nt.nodes.new('ShaderNodeOutputMaterial')
    geo = nt.nodes.new('ShaderNodeNewGeometry')
    em = nt.nodes.new('ShaderNodeEmission')
    em.inputs['Color'].default_value = INK
    tr = nt.nodes.new('ShaderNodeBsdfTransparent')
    mix = nt.nodes.new('ShaderNodeMixShader')
    nt.links.new(geo.outputs['Backfacing'], mix.inputs['Fac'])
    nt.links.new(tr.outputs[0], mix.inputs[1])
    nt.links.new(em.outputs[0], mix.inputs[2])
    nt.links.new(mix.outputs[0], out.inputs[0])
    _ink = m
    return m

def _finish(obj, mat, outline, smooth=True):
    obj.data.materials.clear()
    obj.data.materials.append(mat)
    bpy.context.view_layer.objects.active = obj
    obj.select_set(True)
    if smooth:
        bpy.ops.object.shade_smooth()
    bpy.ops.object.transform_apply(location=True, rotation=True, scale=True)
    obj.select_set(False)
    if outline > 0.0:
        add_outline(obj, outline)
    return obj

HULL = False

def add_outline(obj, w):
    if not HULL:
        return None
    sh = obj.copy()
    sh.data = obj.data.copy()
    sh.name = obj.name + "_ink"
    bpy.context.collection.objects.link(sh)
    sh.data.materials.clear()
    sh.data.materials.append(ink_mat())
    d = sh.modifiers.new("grow", 'DISPLACE')
    d.strength = w
    d.mid_level = 0.0
    d.direction = 'NORMAL'
    return sh

def ellipsoid(name, loc, scale, mat, outline=0.022, rot=(0, 0, 0), seg=48):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=seg, ring_count=seg // 2, radius=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = scale
    o.rotation_euler = [math.radians(r) for r in rot]
    return _finish(o, mat, outline)

def cone(name, loc, r1, r2, h, mat, rot=(0, 0, 0), outline=0.018, verts=32):
    bpy.ops.mesh.primitive_cone_add(vertices=verts, radius1=r1, radius2=r2, depth=h, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = [math.radians(r) for r in rot]
    return _finish(o, mat, outline)

def cylinder(name, loc, r, h, mat, rot=(0, 0, 0), outline=0.018, verts=40):
    bpy.ops.mesh.primitive_cylinder_add(vertices=verts, radius=r, depth=h, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = [math.radians(a) for a in rot]
    return _finish(o, mat, outline)

def torus(name, loc, major, minor, mat, rot=(0, 0, 0), outline=0.012):
    bpy.ops.mesh.primitive_torus_add(location=loc, major_segments=48, minor_segments=20, major_radius=major, minor_radius=minor)
    o = bpy.context.active_object
    o.name = name
    o.rotation_euler = [math.radians(a) for a in rot]
    return _finish(o, mat, outline)

TUBE_CAPS = []

def box(name, loc, size, mat, rot=(0, 0, 0), outline=0.015):
    bpy.ops.mesh.primitive_cube_add(size=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    o.scale = size
    o.rotation_euler = [math.radians(a) for a in rot]
    return _finish(o, mat, outline, smooth=False)

def _catmull(pts, n=10):
    out = []
    P = [Vector(pts[0])] + [Vector(p) for p in pts] + [Vector(pts[-1])]
    for i in range(1, len(P) - 2):
        p0, p1, p2, p3 = P[i - 1], P[i], P[i + 1], P[i + 2]
        for k in range(n):
            t = k / n
            out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t * t + (-p0 + 3 * p1 - 3 * p2 + p3) * t * t * t))
    out.append(Vector(pts[-1]))
    return out

def tube(name, pts, radii, mat, outline=0.02, cap=True, sides=18):
    """Noodle limb / tail: smooth swept tube through pts with per-point radius, rounded end caps."""
    if not isinstance(radii, (list, tuple)):
        radii = [radii] * len(pts)
    path = _catmull(pts, 12)
    nseg = len(pts) - 1
    rad = []
    for idx in range(len(path)):
        f = idx / max(1, len(path) - 1) * nseg
        a = min(int(f), nseg - 1)
        t = f - a
        rad.append(radii[a] * (1 - t) + radii[a + 1] * t)
    bm = bmesh.new()
    rings = []
    prev_n = None
    for idx, c in enumerate(path):
        tan = (path[min(idx + 1, len(path) - 1)] - path[max(idx - 1, 0)]).normalized()
        ref = Vector((0, 0, 1)) if abs(tan.z) < 0.9 else Vector((1, 0, 0))
        nrm = tan.cross(ref).normalized() if prev_n is None else (prev_n - tan * prev_n.dot(tan)).normalized()
        prev_n = nrm
        bit = tan.cross(nrm).normalized()
        ring = []
        for k in range(sides):
            a = 2 * math.pi * k / sides
            ring.append(bm.verts.new(c + (nrm * math.cos(a) + bit * math.sin(a)) * rad[idx]))
        rings.append(ring)
    for r in range(len(rings) - 1):
        for k in range(sides):
            bm.faces.new((rings[r][k], rings[r][(k + 1) % sides], rings[r + 1][(k + 1) % sides], rings[r + 1][k]))
    if cap:
        for ring, end in ((rings[0], path[0]), (rings[-1], path[-1])):
            bm.faces.new(ring[::-1] if end is path[0] else ring)
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    o = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(o)
    bpy.context.view_layer.objects.active = o
    o.select_set(True)
    bmesh_smooth = bpy.ops.object.shade_smooth
    o = _finish(o, mat, outline)
    # round caps
    TUBE_CAPS.clear()
    if cap:
        for end, rr in ((path[0], rad[0]), (path[-1], rad[-1])):
            TUBE_CAPS.append(ellipsoid(name + "_cap", tuple(end), (rr, rr, rr), mat, outline=0, seg=24))
    return o

def teardrop(name, loc, scale, mat, outline=0.015, rot=(0, 0, 0)):
    """Flame / droplet: sphere with a pulled-up tip."""
    bpy.ops.mesh.primitive_uv_sphere_add(segments=40, ring_count=20, radius=1.0, location=loc)
    o = bpy.context.active_object
    o.name = name
    bm = bmesh.new()
    bm.from_mesh(o.data)
    for v in bm.verts:
        if v.co.z > 0:
            k = (v.co.z) ** 1.6
            v.co.z += 1.3 * k
            v.co.x *= (1.0 - 0.55 * k)
            v.co.y *= (1.0 - 0.55 * k)
    bm.to_mesh(o.data)
    bm.free()
    o.scale = scale
    o.rotation_euler = [math.radians(a) for a in rot]
    return _finish(o, mat, outline)

def setup_render(res=512, samples=24):
    sc = bpy.context.scene
    sc.render.engine = 'CYCLES'
    sc.cycles.device = 'CPU'
    sc.cycles.samples = samples
    sc.cycles.use_denoising = False
    sc.cycles.filter_width = 1.2
    sc.render.film_transparent = True
    sc.render.resolution_x = res
    sc.render.resolution_y = res
    sc.render.image_settings.file_format = 'PNG'
    sc.render.image_settings.color_mode = 'RGBA'
    sc.view_settings.view_transform = 'Standard'
    sc.view_settings.look = 'None'
    sc.cycles.max_bounces = 2
    sc.render.use_freestyle = True
    sc.render.line_thickness_mode = 'ABSOLUTE'
    sc.render.line_thickness = LINE_PX * res / 768.0
    vl = bpy.context.view_layer
    vl.use_freestyle = True
    fs = vl.freestyle_settings
    for ls in list(fs.linesets):
        fs.linesets.remove(ls)
    ls = fs.linesets.new('ink')
    ls.select_silhouette = True
    ls.select_border = True
    ls.select_crease = True
    ls.select_by_visibility = True
    ls.visibility = 'VISIBLE'
    ls.linestyle.color = INK[:3]
    ls.linestyle.thickness = 1.0
    fs.crease_angle = math.radians(120)
    sc.cycles.transparent_max_bounces = 16

def camera(view, ortho=3.4, target=(0, 0, 0.95)):
    """view: 'side' (creature faces +X, camera on -Y), 'three_quarter', 'front', 'back'."""
    if bpy.data.objects.get("Cam"):
        bpy.data.objects.remove(bpy.data.objects["Cam"])
    cd = bpy.data.cameras.new("Cam")
    cd.type = 'ORTHO'
    cd.ortho_scale = ortho
    cam = bpy.data.objects.new("Cam", cd)
    bpy.context.collection.objects.link(cam)
    d = 7.0
    az, el = {'side': (90, 10), 'three_quarter': (135, 12), 'front': (180, 8), 'back': (0, 10), 'top': (90, 55)}[view]
    # azimuth measured so that 'side' puts the camera on -Y looking toward +Y with the creature facing +X (to the right)
    a = math.radians(az)
    e = math.radians(el)
    cam.location = (target[0] + d * math.cos(e) * math.cos(a + math.pi), target[1] + d * math.cos(e) * math.sin(a + math.pi), target[2] + d * math.sin(e))
    tgt = Vector(target)
    dirv = tgt - cam.location
    cam.rotation_euler = dirv.to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = cam
    return cam

def render(path):
    bpy.context.scene.render.filepath = path
    bpy.ops.render.render(write_still=True)

def sheet(views, out_prefix, res=384, ortho=3.4, target=(0, 0, 0.95)):
    setup_render(res=res * 2, samples=20)
    paths = []
    for v in views:
        camera(v, ortho, target)
        p = f"{out_prefix}_{v}.png"
        render(p)
        paths.append(p)
    return paths
