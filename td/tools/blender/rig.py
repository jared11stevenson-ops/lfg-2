"""Armature + animation helpers for Wellfall creature models (bpy)."""
import bpy, math
from mathutils import Vector, Matrix, Quaternion
from lib import *

AXX, AXY, AXZ = Vector((1, 0, 0)), Vector((0, 1, 0)), Vector((0, 0, 1))
FRAMES = {"idle": 6, "walk": 8, "attack": 5}

class Rig:
    def __init__(self, name):
        data = bpy.data.armatures.new(name)
        self.arm = bpy.data.objects.new(name, data)
        bpy.context.collection.objects.link(self.arm)
        self.names = []
        self.actions = {}

    def bones(self, spec):
        """spec: list of (name, head, tail, parent or None)."""
        bpy.context.view_layer.objects.active = self.arm
        self.arm.select_set(True)
        bpy.ops.object.mode_set(mode='EDIT')
        eb = self.arm.data.edit_bones
        for n, h, t, p in spec:
            b = eb.new(n)
            b.head = h
            b.tail = t
            if p:
                b.parent = eb[p]
            self.names.append(n)
        bpy.ops.object.mode_set(mode='OBJECT')
        self.arm.select_set(False)

    def bind(self, obj, bone):
        vg = obj.vertex_groups.new(name=bone)
        vg.add([v.index for v in obj.data.vertices], 1.0, 'REPLACE')
        mod = obj.modifiers.new("Armature", 'ARMATURE')
        mod.object = self.arm
        return obj

    def skin_chain(self, obj, bone_names, pts):
        """Smoothly skin a tube to a bone chain: pts has len(bone_names)+1 points (bone heads, then last tail)."""
        P = [Vector(p) for p in pts]
        for n in bone_names:
            obj.vertex_groups.new(name=n)
        for v in obj.data.vertices:
            co = v.co
            best = (1e9, 0.0)
            for i in range(len(P) - 1):
                a, b = P[i], P[i + 1]
                ab = b - a
                tt = max(0.0, min(1.0, (co - a).dot(ab) / ab.length_squared))
                d = (co - (a + ab * tt)).length
                if d < best[0]:
                    best = (d, i + tt)
            u = best[1]
            ws = [max(0.0, 1.0 - abs(u - (i + 0.5))) for i in range(len(bone_names))]
            if u < 0.5:
                ws[0] = 1.0
            if u > len(bone_names) - 0.5:
                ws[-1] = 1.0
            tot = sum(ws) or 1.0
            for i, w in enumerate(ws):
                if w > 0.001:
                    obj.vertex_groups[i].add([v.index], w / tot, 'REPLACE')
        mod = obj.modifiers.new("Armature", 'ARMATURE')
        mod.object = self.arm
        return obj

    # ---- pose helpers (rotations are specified about WORLD axes through the bone head) ----
    def reset(self):
        for pb in self.arm.pose.bones:
            pb.rotation_mode = 'QUATERNION'
            pb.rotation_quaternion = Quaternion((1, 0, 0, 0))
            pb.location = Vector((0, 0, 0))
            pb.scale = Vector((1, 1, 1))

    def rot(self, bone, axis, deg):
        pb = self.arm.pose.bones[bone]
        B = pb.bone.matrix_local.to_3x3()
        R = Matrix.Rotation(math.radians(deg), 3, axis)
        q = (B.inverted() @ R @ B).to_quaternion()
        pb.rotation_mode = 'QUATERNION'
        pb.rotation_quaternion = (pb.rotation_quaternion @ q) if False else q @ pb.rotation_quaternion

    def loc(self, bone, v):
        pb = self.arm.pose.bones[bone]
        B = pb.bone.matrix_local.to_3x3()
        pb.location = pb.location + B.inverted() @ Vector(v)

    def scale(self, bone, k):
        pb = self.arm.pose.bones[bone]
        pb.scale = Vector((k, k, k))

    def key_all(self, frame):
        for pb in self.arm.pose.bones:
            pb.keyframe_insert('rotation_quaternion', frame=frame)
            pb.keyframe_insert('location', frame=frame)
            pb.keyframe_insert('scale', frame=frame)

    def make_actions(self, pose_fn):
        """Keyframe idle/walk/attack as real Blender actions so the .blend is animated."""
        self.arm.animation_data_create()
        for state, n in FRAMES.items():
            act = bpy.data.actions.new(state)
            self.arm.animation_data.action = act
            for i in range(n + 1):
                pose_fn(self, state, (i % n) / n)
                self.key_all(i + 1)
            self.actions[state] = act
        self.arm.animation_data.action = None

def smooth(a, b, x):
    t = max(0.0, min(1.0, (x - a) / (b - a)))
    return t * t * (3 - 2 * t)

def sprite_camera(ppu, size=192, origin=(105, 173), el=10.0, az=90.0):
    """Orthographic camera framed so the world origin lands on pixel `origin` of a size x size frame at ppu px/unit."""
    if bpy.data.objects.get("Cam"):
        bpy.data.objects.remove(bpy.data.objects["Cam"])
    cd = bpy.data.cameras.new("Cam")
    cd.type = 'ORTHO'
    cd.ortho_scale = size / ppu
    cam = bpy.data.objects.new("Cam", cd)
    bpy.context.collection.objects.link(cam)
    a, e = math.radians(az), math.radians(el)
    d = 9.0
    # direction from target to camera
    to_cam = Vector((math.cos(e) * math.cos(a + math.pi), math.cos(e) * math.sin(a + math.pi), math.sin(e)))
    # camera basis
    fwd = -to_cam
    right = fwd.cross(Vector((0, 0, 1))).normalized()
    up = right.cross(fwd).normalized()
    ox = (origin[0] - size / 2) / ppu
    oy = (origin[1] - size / 2) / ppu
    target = right * (-ox) + up * oy
    cam.location = target + to_cam * d
    cam.rotation_euler = (target - cam.location).to_track_quat('-Z', 'Y').to_euler()
    bpy.context.scene.camera = cam
    return cam

def bake_frames(rig, pose_fn, out_dir, name, ppu, states=("idle", "walk", "attack"), yaw=-28.0):
    """Render every animation frame to 192px PNGs (2x supersampled, downscaled)."""
    from PIL import Image
    import os, tempfile
    os.makedirs(out_dir, exist_ok=True)
    setup_render(res=384, samples=14)
    bpy.context.scene.render.line_thickness = 4.8
    sprite_camera(ppu, size=192)
    tmp = os.path.join(tempfile.gettempdir(), "wf_frame_%d.png" % os.getpid())
    for state in states:
        for i in range(FRAMES[state]):
            pose_fn(rig, state, i / FRAMES[state])
            rig.rot("root", AXZ, yaw)
            bpy.context.scene.render.filepath = tmp
            bpy.context.scene.render.resolution_x = 384
            bpy.context.scene.render.resolution_y = 384
            bpy.ops.render.render(write_still=True)
            im = Image.open(tmp).convert("RGBA").resize((192, 192), Image.LANCZOS)
            im.save(os.path.join(out_dir, f"{name}_{state}_{i}.png"))
