"""rigkit: shared rigging + animation toolkit for the Tripo creatures (all techniques are standard, documented ones).
- Skinning: Blender heat-diffusion automatic weights computed on a watertight voxel-remeshed PROXY, transferred to the real mesh
  (data transfer, nearest-surface), then unweighted verts filled from their nearest weighted neighbour.
- Legs: native Blender IK constraints (2-bone chain + pole target); foot controls are planted in world space.
- Secondary motion: second-order dynamics (t3ssel8r / Pixar-style: y + k1*y' + k2*y'' = x + k3*x') chained along tails, ears, etc.
  r < 0 gives anticipation, r > 1 gives overshoot, so follow-through is physical rather than hand-tuned sine lag.
- Gait: footfall order from Muybridge (cat lateral sequence RH,RF,LH,LF), stance linear / swing eased arc, key-pose timing from quadruped walk tutorials.
"""
import math, os, sys, time, tempfile
import numpy as np
import bpy
from mathutils import Vector, Matrix, Quaternion, kdtree
sys.path.insert(0, os.path.dirname(__file__))
from rig import Rig, AXX, AXY, AXZ, sprite_camera
from glb_common import load_normalized, basic_render_setup

# ------------------------------------------------------------------ second-order dynamics
class SOD:
    def __init__(self, f=2.0, z=0.6, r=0.0, x0=0.0):
        self.k1 = z / (math.pi * f)
        self.k2 = 1.0 / ((2 * math.pi * f) ** 2)
        self.k3 = r * z / (2 * math.pi * f)
        self.xp = x0; self.y = x0; self.yd = 0.0

    def step(self, T, x):
        xd = (x - self.xp) / T
        self.xp = x
        k2s = max(self.k2, 1.1 * (T * T / 4 + T * self.k1 / 2))
        self.y += T * self.yd
        self.yd += T * (x + self.k3 * xd - self.y - self.k1 * self.yd) / k2s
        return self.y

def run_loop(fn, period, substeps=240, warm=3):
    """Run a stateful function fn(t, dt) over `warm` loops so dynamics settle, then return the last loop sampled `substeps` times as dict list."""
    dt = period / substeps
    out = []
    for lp in range(warm):
        for i in range(substeps):
            t = (lp * substeps + i) * dt
            res = fn(t, dt)
            if lp == warm - 1:
                out.append(res)
    return out

def sample(series, u):
    """Linear sample of a looped series (list of dict/float) at u in [0,1)."""
    n = len(series)
    x = (u % 1.0) * n
    i = int(x) % n; j = (i + 1) % n; f = x - int(x)
    a, b = series[i], series[j]
    if isinstance(a, dict):
        return {k: a[k] * (1 - f) + b[k] * f for k in a}
    return a * (1 - f) + b * f

def smoothstep(x):
    x = min(1.0, max(0.0, x)); return x * x * (3 - 2 * x)

def ease(a, b, u, kind="inout"):
    u = min(1.0, max(0.0, u))
    if kind == "in": u = u * u
    elif kind == "out": u = 1 - (1 - u) ** 2
    else: u = smoothstep(u)
    return a + (b - a) * u

def keys(table, u):
    """Piecewise key-pose interpolation. table = [(time 0..1, value_or_tuple), ...] sorted; eases between keys (slow in/out)."""
    if u <= table[0][0]: return table[0][1]
    for (t0, v0), (t1, v1) in zip(table, table[1:]):
        if u <= t1:
            f = smoothstep((u - t0) / max(1e-6, t1 - t0))
            if isinstance(v0, (tuple, list)):
                return tuple(a + (b - a) * f for a, b in zip(v0, v1))
            return v0 + (v1 - v0) * f
    return table[-1][1]

# ------------------------------------------------------------------ gait
def foot_offset(phase, span, lift, duty):
    """Foot offset (dx forward, dz up) relative to neutral for phase in [0,1). Stance: planted, sliding back linearly. Swing: eased arc."""
    ph = phase % 1.0
    if ph < duty:
        u = ph / duty
        return span * (0.5 - u), 0.0
    u = (ph - duty) / (1.0 - duty)
    dx = span * (-0.5 + smoothstep(u))
    dz = lift * math.sin(math.pi * u) ** 0.85
    # slight toe-drag at lift-off and heel-strike: foot stays low early, peaks mid-swing
    return dx, dz

# ------------------------------------------------------------------ skinning
def bind_heat(mesh, arm_obj, deform_bones, voxel=0.022, limit=4):
    """Automatic (heat diffusion) weights via a watertight proxy, transferred to `mesh`."""
    for vg in list(mesh.vertex_groups): mesh.vertex_groups.remove(vg)
    for m in list(mesh.modifiers): mesh.modifiers.remove(m)
    mesh.parent = None
    bpy.ops.object.select_all(action='DESELECT')
    for b in arm_obj.data.bones:
        b.use_deform = b.name in deform_bones
    proxy = None
    for vox in [voxel, 0.03, 0.035, 0.04, 0.026, 0.05]:
        if proxy is not None:
            bpy.data.objects.remove(proxy, do_unlink=True)
        proxy = mesh.copy(); proxy.data = mesh.data.copy(); proxy.name = "proxy"
        bpy.context.collection.objects.link(proxy)
        proxy.data.remesh_voxel_size = vox
        bpy.ops.object.select_all(action='DESELECT')
        bpy.context.view_layer.objects.active = proxy; proxy.select_set(True)
        bpy.ops.object.voxel_remesh()
        proxy.select_set(False)
        bpy.ops.object.select_all(action='DESELECT')
        proxy.select_set(True); arm_obj.select_set(True); bpy.context.view_layer.objects.active = arm_obj
        bpy.ops.object.parent_set(type='ARMATURE_AUTO')
        pz = sum(1 for v in proxy.data.vertices if not v.groups)
        print("  voxel", vox, "proxy verts", len(proxy.data.vertices), "without weights", pz, flush=True)
        if pz < 0.3 * len(proxy.data.vertices):
            break
    bpy.ops.object.select_all(action='DESELECT')
    for n in deform_bones:
        if n not in mesh.vertex_groups: mesh.vertex_groups.new(name=n)
    mod = mesh.modifiers.new("dt", 'DATA_TRANSFER')
    mod.object = proxy; mod.use_vert_data = True; mod.data_types_verts = {'VGROUP_WEIGHTS'}
    mod.vert_mapping = 'POLYINTERP_NEAREST'
    bpy.context.view_layer.objects.active = mesh; mesh.select_set(True)
    bpy.ops.object.modifier_apply(modifier="dt")
    # fill vertices that ended up without weights from their nearest weighted neighbour
    kd = kdtree.KDTree(len(mesh.data.vertices))
    weighted = []
    for v in mesh.data.vertices:
        if v.groups and sum(g.weight for g in v.groups) > 1e-4:
            weighted.append(v.index)
    for i in weighted: kd.insert(mesh.data.vertices[i].co, i)
    kd.balance()
    missing = [v.index for v in mesh.data.vertices if not (v.groups and sum(g.weight for g in v.groups) > 1e-4)]
    for i in missing:
        co, j, d = kd.find(mesh.data.vertices[i].co)
        for g in mesh.data.vertices[j].groups:
            mesh.vertex_groups[g.group].add([i], g.weight, 'REPLACE')
    bpy.ops.object.vertex_group_limit_total(group_select_mode='ALL', limit=limit)
    bpy.ops.object.vertex_group_normalize_all(group_select_mode='ALL', lock_active=False)
    bpy.data.objects.remove(proxy, do_unlink=True)
    mod = mesh.modifiers.new("Armature", 'ARMATURE'); mod.object = arm_obj
    mesh.parent = arm_obj
    return len(missing)

# ------------------------------------------------------------------ IK
def add_ik_leg(arm, lower, ctrl, pole, pole_angle=0.0):
    pb = arm.pose.bones[lower]
    c = pb.constraints.new('IK')
    c.target = arm; c.subtarget = ctrl
    c.pole_target = arm; c.pole_subtarget = pole
    c.chain_count = 2
    c.pole_angle = math.radians(pole_angle)
    return c

def calibrate_pole(rig, leg_upper, leg_lower, ctrl, constraint, bend_dir):
    """Pick the pole angle whose knee displacement points toward `bend_dir` (+1 = +X forward, -1 = -X backward) when the foot is lifted."""
    arm = rig.arm
    best, best_score = 0.0, -1e9
    rig.reset()
    rig.loc(ctrl, (0.1, 0, 0.18))
    for ang in (-90, 0, 90, 180):
        constraint.pole_angle = math.radians(ang)
        bpy.context.view_layer.update()
        knee = Vector(arm.pose.bones[leg_lower].head)
        hip = Vector(arm.pose.bones[leg_upper].head)
        foot = Vector(arm.pose.bones[leg_lower].tail)
        mid = (hip + foot) / 2
        score = (knee.x - mid.x) * bend_dir
        if score > best_score:
            best, best_score = ang, score
    constraint.pole_angle = math.radians(best)
    rig.reset()
    bpy.context.view_layer.update()
    return best, best_score

# ------------------------------------------------------------------ build + bake
class Creature:
    """spec keys: bones [(name, head, tail, parent, deform)], legs {id: dict(upper, lower, foot_ctrl, pole, bend)}, mesh settings."""
    def __init__(self, glb, spec, name):
        self.spec = spec; self.name = name
        self.origin_x = 105.0 - float(spec.get("origin_dx", 0.0))
        self.mesh = load_normalized(glb, spec["yaw_face"], spec["px_w"], spec["lift"], ratio=spec.get("ratio", 0.04))
        self.rig = Rig(name.capitalize() + "Rig")
        self.rig.bones([(n, h, t, p) for n, h, t, p, d in spec["bones"]])
        deform = [n for n, h, t, p, d in spec["bones"] if d]
        t0 = time.time()
        self.missing = bind_heat(self.mesh, self.rig.arm, deform, spec.get("voxel", 0.022))
        self.bind_s = time.time() - t0
        # controls never deform
        for b in self.rig.arm.data.bones:
            b.use_deform = b.name in deform
        bpy.context.view_layer.objects.active = self.rig.arm
        bpy.ops.object.mode_set(mode='POSE')
        self.constraints = {}
        for lid, L in spec.get("legs", {}).items():
            c = add_ik_leg(self.rig.arm, L["lower"], L["foot_ctrl"], L["pole"])
            ang, score = calibrate_pole(self.rig, L["upper"], L["lower"], L["foot_ctrl"], c, L["bend"])
            self.constraints[lid] = (c, ang, score)
        bpy.ops.object.mode_set(mode='OBJECT')
        self.rest_foot = {}
        for lid, L in spec.get("legs", {}).items():
            bpy.context.view_layer.update()
            self.rest_foot[lid] = Vector(self.rig.arm.data.bones[L["lower"]].tail_local)

    # control helpers: world-space offsets relative to rest
    def move(self, bone, v):
        self.rig.loc(bone, v)

    def foot(self, lid, dx, dz, dy=0.0):
        self.rig.loc(self.spec["legs"][lid]["foot_ctrl"], (dx, dy, dz))

    def rot(self, bone, axis, deg):
        self.rig.rot(bone, axis, deg)

    def anchor_logical(self, bone, tail=True, size=256, off=None):
        """Screen anchor of a bone end in the game's logical sprite px, relative to the sprite origin (105,173)."""
        from bpy_extras.object_utils import world_to_camera_view
        sc = bpy.context.scene
        pb = self.rig.arm.pose.bones[bone]
        p = self.rig.arm.matrix_world @ (Vector(pb.tail if tail else pb.head) + (off if off is not None else Vector((0, 0, 0))))
        v = world_to_camera_view(sc, sc.camera, p)
        k = size / 192.0
        return ((v.x * size - self.origin_x * k) / k, ((1.0 - v.y) * size - 173 * k) / k)

    def compute_anchors(self, pose_fn, counts, anchors, size=256):
        out = {}
        for nm, spec_ in anchors.items():
            state, u, bone, tail = spec_[:4]
            off = Vector(spec_[4]) if len(spec_) > 4 else Vector((0, 0, 0))
            self.rig.reset()
            n = counts[state]
            pose_fn(self, state, u, int(u * n), n)
            bpy.context.view_layer.update()
            out[nm] = [round(x, 1) for x in self.anchor_logical(bone, tail, size, off)]
        self.rig.reset()
        return out

    def bake(self, pose_fn, counts, out_dir, name, size=256, ppu=50.0, yaw=-32.0, preview=None, glow=True, anchors=None, meta_extra=None, meta_path=None, meta_only=False):
        from PIL import Image, ImageFilter
        basic_render_setup(size * 2, samples=18)
        sc = bpy.context.scene
        sprite_camera(ppu * size / 192.0, size=size, origin=(self.origin_x * size / 192.0, 173 * size / 192.0), el=12.0)
        tmp = os.path.join(tempfile.gettempdir(), "crig_%d.png" % os.getpid())
        sc.render.filepath = tmp
        self.rig.arm.rotation_euler = (0, 0, math.radians(yaw))
        if anchors and meta_path and not preview:
            import json
            meta = dict(meta_extra or {})
            meta["counts"] = counts
            meta["origin"] = [self.origin_x, 173.0]
            meta["anchors"] = self.compute_anchors(pose_fn, counts, anchors, size)
            os.makedirs(os.path.dirname(meta_path), exist_ok=True)
            json.dump(meta, open(meta_path, "w"), indent=1)
            print("meta", meta_path, meta["anchors"], flush=True)
            if meta_only:
                return
        def frame(state, i, n):
            self.rig.reset()
            pose_fn(self, state, i / n, i, n)
            bpy.context.view_layer.update()
            bpy.ops.render.render(write_still=True)
            return Image.open(tmp).convert("RGBA").resize((size, size), Image.LANCZOS)
        def tinted(im, color, blur=9, grow=2):
            al = im.split()[3].filter(ImageFilter.MaxFilter(2 * grow + 1)).filter(ImageFilter.GaussianBlur(blur))
            g = Image.new("RGBA", im.size, color + (0,)); g.putalpha(al.point(lambda v: int(v * 0.85)))
            b = Image.new("RGBA", im.size, (0, 0, 0, 0)); b.alpha_composite(g); b.alpha_composite(im)
            return b
        if preview:
            os.makedirs(preview, exist_ok=True)
            cols = 12
            rows = []
            for state in ("idle", "walk", "attack"):
                n = counts[state]
                step = max(1, n // cols) if n > cols else 1
                rows.append([frame(state, i, n) for i in range(0, n, step)][:cols])
            W = Image.new("RGBA", (size * cols, size * 3), (30, 20, 60, 255))
            for r, row in enumerate(rows):
                for c, im in enumerate(row):
                    W.alpha_composite(im, (c * size, r * size))
            W.save(os.path.join(preview, name + "_rig_preview.png"))
            return
        os.makedirs(out_dir, exist_ok=True)
        clipped = []
        for state in ("idle", "walk", "attack"):
            n = counts[state]
            for i in range(n):
                im = frame(state, i, n)
                al = im.getchannel("A")
                W_, H_ = al.size
                edge = max(al.crop((W_ - 2, 0, W_, H_)).getextrema()[1], al.crop((0, 0, 2, H_)).getextrema()[1], al.crop((0, 0, W_, 2)).getextrema()[1], al.crop((0, H_ - 2, W_, H_)).getextrema()[1])
                if edge > 12: clipped.append(f"{state}_{i}")
                im.save(os.path.join(out_dir, f"{name}_{state}_{i}.png"))
                if state != "walk" and glow:
                    tinted(im, (255, 214, 90)).save(os.path.join(out_dir, f"{name}_a_{state}_{i}.png"))
                    tinted(im, (255, 96, 60)).save(os.path.join(out_dir, f"{name}_b_{state}_{i}.png"))
        print("CLIPPED frames:", clipped if clipped else "none", flush=True)
