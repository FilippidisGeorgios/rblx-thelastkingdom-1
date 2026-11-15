"""
render_moves.py - a short video of each movement set (Blender 5.x, headless).

  blender -b --factory-startup --python-exit-code 1 -P tools/blender/render_moves.py -- <moves.json> <out_dir> [set]

The developer, 2026-11-15: "how can I see the three movement sets? Make me three short videos of the moves."

<moves.json> is taken out of Studio (the clips of Shared/Anim/PlayerMoveAnims for sets 1-3: idle, walk, run, jump,
fall; every frame's joint angles, Euler XYZ in degrees as CFrame:ToEulerAnglesXYZ gives them, and the hips' shift). The
body is the game's own square body (Services/AvatarService), built here from its measured parts and joint seats
(tools/Filmstrip `geometry`), posed exactly as ClipPlayer poses it: part = parent * seat0 * pose * seat1^-1.

Each video (1280 x 720, 30 fps, about 10 s): standing still, a walk at the game's 16 studs a second, a run at 24, a
stop, a jump, standing again; the camera goes along beside the body; the floor is laid in tiles so the speed shows.
"""
import bpy, sys, os, math, json
from mathutils import Matrix, Vector, Quaternion

argv = sys.argv[sys.argv.index("--") + 1:]
DATA, OUT = os.path.abspath(argv[0]), os.path.abspath(argv[1])
ONLY = int(argv[2]) if len(argv) > 2 else None
# a fourth argument: frames to render as stills instead of the video (to look at them), e.g. 30,80,140
STILLS = [int(x) for x in argv[3].split(",")] if len(argv) > 3 else None
os.makedirs(OUT, exist_ok=True)
with open(DATA, encoding="utf8") as f:
    MOVES = json.load(f)

FPS = 30

# ---------------------------------------------------------------- the square body (Roblox axes, studs)
PARTS = {
    "LowerTorso": ((2, 0.4, 1), "trousers"),
    "UpperTorso": ((2, 1.6, 1), "coat"),
    "Head": ((1.2, 1.2, 1.2), "skin"),
    "RightUpperArm": ((1, 1.1687, 1), "coat"),
    "RightLowerArm": ((1, 1.0519, 1), "skin"),
    "RightHand": ((1, 0.3, 1), "skin"),
    "LeftUpperArm": ((1, 1.1687, 1), "coat"),
    "LeftLowerArm": ((1, 1.0519, 1), "skin"),
    "LeftHand": ((1, 0.3, 1), "skin"),
    "RightUpperLeg": ((1, 1.2166, 1), "trousers"),
    "RightLowerLeg": ((1, 1.1931, 1), "trousers"),
    "RightFoot": ((1, 0.3, 1), "boots"),
    "LeftUpperLeg": ((1, 1.2166, 1), "trousers"),
    "LeftLowerLeg": ((1, 1.1931, 1), "trousers"),
    "LeftFoot": ((1, 0.3, 1), "boots"),
}
# (parent, seat on the parent, seat on the part): ClipPlayer's a0 and a1
JOINTS = [
    ("LowerTorso", "Root", (0, -1, 0), (0, -0.2, 0)),
    ("UpperTorso", "LowerTorso", (0, 0.2, 0), (0, -0.8, 0)),
    ("Head", "UpperTorso", (0, 0.8, 0), (0, -0.586, 0)),
    ("RightUpperArm", "UpperTorso", (1.0, 0.563, 0), (-0.5, 0.3943, 0)),
    ("RightLowerArm", "RightUpperArm", (0, -0.3342, 0), (0, 0.2586, 0)),
    ("RightHand", "RightLowerArm", (0, -0.5009, 0), (0, 0.125, 0)),
    ("LeftUpperArm", "UpperTorso", (-1.0, 0.563, 0), (0.5, 0.3943, 0)),
    ("LeftLowerArm", "LeftUpperArm", (0, -0.3342, 0), (0, 0.2586, 0)),
    ("LeftHand", "LeftLowerArm", (0, -0.5009, 0), (0, 0.125, 0)),
    ("RightUpperLeg", "LowerTorso", (0.5, -0.2, 0), (0, 0.4208, 0)),
    ("RightLowerLeg", "RightUpperLeg", (0, -0.4009, 0), (0, 0.3792, 0)),
    ("RightFoot", "RightLowerLeg", (0, -0.5472, 0), (0, 0.1019, 0)),
    ("LeftUpperLeg", "LowerTorso", (-0.5, -0.2, 0), (0, 0.4208, 0)),
    ("LeftLowerLeg", "LeftUpperLeg", (0, -0.4009, 0), (0, 0.3792, 0)),
    ("LeftFoot", "LeftLowerLeg", (0, -0.5472, 0), (0, 0.1019, 0)),
]
ROOT_HEIGHT = 3.0  # the root's centre over the floor (HipHeight 2 + half of the 2-stud root)

# Roblox (x right, y up, -z ahead) to Blender (x right, y ahead... z up): (x, y, z) -> (x, -z, y)
C = Matrix(((1, 0, 0, 0), (0, 0, -1, 0), (0, 1, 0, 0), (0, 0, 0, 1)))
C_INV = C.inverted()


def srgb(r, g, b):
    def c(x):
        x = x / 255
        return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4
    return (c(r), c(g), c(b), 1)


def material(name, rgba, rough=0.7):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = rgba
    bsdf.inputs["Roughness"].default_value = rough
    return m


def box(name, size, mat, bevel=0.06):
    bpy.ops.mesh.primitive_cube_add(size=1)
    ob = bpy.context.active_object
    ob.name = name
    # Roblox size (x, y, z) is Blender (x, z, y)
    ob.data.transform(Matrix.Diagonal((size[0], size[2], size[1], 1)))
    ob.data.materials.append(mat)
    mod = ob.modifiers.new("bevel", "BEVEL")
    mod.width = bevel
    mod.segments = 3
    for p in ob.data.polygons:
        p.use_smooth = True
    ob.rotation_mode = "QUATERNION"
    return ob


def euler_quat(rx, ry, rz):
    # CFrame.Angles(rx, ry, rz) = Rx * Ry * Rz
    m = Matrix.Rotation(math.radians(rx), 4, "X") @ Matrix.Rotation(math.radians(ry), 4, "Y") @ Matrix.Rotation(math.radians(rz), 4, "Z")
    return m.to_quaternion()


def parse_clip(clip):
    frames = []
    for f in clip["frames"]:
        pose = {}
        for joint, s in f["p"].items():
            v = [float(x) for x in s.split()]
            q = euler_quat(v[0], v[1], v[2])
            p = Vector(v[3:6]) if len(v) >= 6 else Vector((0, 0, 0))
            pose[joint] = (q, p)
        frames.append((f["t"], pose))
    return {"frames": frames, "looped": clip["looped"], "length": frames[-1][0]}


def sample(clip, t):
    frames = clip["frames"]
    length = clip["length"]
    if clip["looped"] and length > 0:
        t = t % length
    else:
        t = max(0.0, min(t, length))
    i = 0
    while i < len(frames) - 2 and frames[i + 1][0] <= t:
        i += 1
    t0, a = frames[i]
    t1, b = frames[min(i + 1, len(frames) - 1)]
    u = 0.0 if t1 <= t0 else max(0.0, min(1.0, (t - t0) / (t1 - t0)))
    out = {}
    for joint in set(a) | set(b):
        qa, pa = a.get(joint, (Quaternion(), Vector((0, 0, 0))))
        qb, pb = b.get(joint, (Quaternion(), Vector((0, 0, 0))))
        out[joint] = (qa.slerp(qb, u), pa.lerp(pb, u))
    return out


def mix(a, b, w):
    if w <= 0:
        return a
    if w >= 1:
        return b
    out = {}
    for joint in set(a) | set(b):
        qa, pa = a.get(joint, (Quaternion(), Vector((0, 0, 0))))
        qb, pb = b.get(joint, (Quaternion(), Vector((0, 0, 0))))
        out[joint] = (qa.slerp(qb, w), pa.lerp(pb, w))
    return out


def smooth(x):
    x = max(0.0, min(1.0, x))
    return x * x * (3 - 2 * x)


# ---------------------------------------------------------------- the timeline (seconds)
# standing, walking, running, stopping, a jump (rise, fall), standing again
T_WALK, T_RUN, T_STOP, T_JUMP, T_LAND, T_END = 1.6, 4.4, 6.9, 7.5, 8.3, 10.0
BLEND = 0.25


def build_scene(set_index):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    scene = bpy.context.scene
    scene.render.fps = FPS
    scene.frame_start = 1
    scene.frame_end = int(T_END * FPS)
    scene.render.resolution_x, scene.render.resolution_y = 1280, 720
    scene.render.engine = "BLENDER_EEVEE"
    try:
        scene.eevee.taa_render_samples = 16
    except Exception:
        pass
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.05, 0.055, 0.07, 1)
    bg.inputs["Strength"].default_value = 1.0

    mats = {
        "coat": material("coat", srgb(120, 46, 40)),
        "trousers": material("trousers", srgb(70, 62, 54)),
        "skin": material("skin", srgb(214, 172, 136), 0.6),
        "boots": material("boots", srgb(40, 32, 26)),
        "eye": material("eye", srgb(15, 12, 10), 0.4),
    }
    parts = {name: box(name, size, mats[m]) for name, (size, m) in PARTS.items()}
    # a face on the front of the head (Roblox -Z), so which way it looks shows
    face = []
    for (x, y, w, h) in ((-0.22, 0.12, 0.12, 0.16), (0.22, 0.12, 0.12, 0.16), (0, -0.25, 0.36, 0.06)):
        bpy.ops.mesh.primitive_cube_add(size=1)
        f = bpy.context.active_object
        f.data.transform(Matrix.Translation((x, 0.6, y)) @ Matrix.Diagonal((w, 0.03, h, 1)))
        f.data.materials.append(mats["eye"])
        f.parent = parts["Head"]
        face.append(f)

    # the floor: stone tiles, 4 studs, so the ground going by shows the speed
    bpy.ops.mesh.primitive_plane_add(size=1)
    floor = bpy.context.active_object
    floor.scale = (60, 900, 1)
    floor.location = (0, 400, 0)
    fm = bpy.data.materials.new("floor")
    fm.use_nodes = True
    nt = fm.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    chk = nt.nodes.new("ShaderNodeTexChecker")
    chk.inputs["Scale"].default_value = 1.0
    chk.inputs["Color1"].default_value = srgb(58, 56, 54)
    chk.inputs["Color2"].default_value = srgb(44, 42, 41)
    mp = nt.nodes.new("ShaderNodeMapping")
    mp.inputs["Scale"].default_value = (0.25, 0.25, 0.25)
    nt.links.new(tc.outputs["Object"], mp.inputs["Vector"])
    # object space of a scaled plane: undo the scale so a tile is 4 studs
    mp.inputs["Scale"].default_value = (60 / 4, 900 / 4, 1)
    nt.links.new(mp.outputs["Vector"], chk.inputs["Vector"])
    nt.links.new(chk.outputs["Color"], bsdf.inputs["Base Color"])
    bsdf.inputs["Roughness"].default_value = 0.85
    floor.data.materials.append(fm)

    # light: a cool key from above and ahead, a warm low fill
    for name, rot, energy, color in (("Sun", (math.radians(50), 0, math.radians(35)), 3.2, (0.9, 0.92, 1.0)),
                                     ("Fill", (math.radians(70), 0, math.radians(-140)), 0.8, (1.0, 0.8, 0.6))):
        ld = bpy.data.lights.new(name, "SUN")
        ld.energy = energy
        ld.color = color
        lo = bpy.data.objects.new(name, ld)
        lo.rotation_euler = rot
        scene.collection.objects.link(lo)

    cam_d = bpy.data.cameras.new("cam")
    cam_d.lens = 42
    cam = bpy.data.objects.new("cam", cam_d)
    scene.collection.objects.link(cam)
    scene.camera = cam

    # the set's name in a corner, and the move under way (one text for each, shown in its time)
    def text(body, size, at, name):
        bpy.ops.object.text_add()
        t = bpy.context.active_object
        t.name = name
        t.data.body = body
        t.data.size = size
        t.data.materials.append(mats["skin"])
        t.parent = cam
        t.location = at
        return t
    sdata = MOVES["sets"][set_index - 1]
    text(f"{set_index}  {sdata['name'].upper()}", 0.055, (-0.36, 0.17, -1), "Title")
    labels = []
    for body, t0, t1 in (("STANDING", 0, T_WALK), ("WALK", T_WALK, T_RUN), ("RUN", T_RUN, T_STOP),
                         ("STOP", T_STOP, T_JUMP), ("JUMP", T_JUMP, T_LAND), ("STANDING", T_LAND, T_END + 1)):
        labels.append((text(body, 0.035, (-0.36, -0.2, -1), "Label_" + body), t0, t1))
    return scene, parts, cam, labels, sdata


def animate(scene, parts, cam, labels, sdata):
    clips = {name: parse_clip(c) for name, c in sdata["clips"].items()}
    walk, run, idle, jump, fall = clips["walk"], clips["run"], clips["idle"], clips["jump"], clips["fall"]
    dt = 1.0 / FPS
    phase = 0.0
    z = 0.0  # how far ahead the body has gone (Roblox -Z)
    v = 0.0
    for fi in range(scene.frame_start, scene.frame_end + 1):
        T = (fi - 1) * dt
        # how much it is walking and running, and the speed it goes at (as the game blends them)
        w_walk = smooth((T - T_WALK) / BLEND) * (1 - smooth((T - T_STOP) / 0.4))
        w_run = smooth((T - T_RUN) / 0.35) * (1 - smooth((T - T_STOP) / 0.4))
        target_v = 0.0
        if T_WALK <= T < T_STOP:
            target_v = MOVES["walkPace"] + (MOVES["runPace"] - MOVES["walkPace"]) * w_run
        v += (target_v - v) * min(1.0, dt * 6)
        z += v * dt
        stride = walk["length"] + (run["length"] - walk["length"]) * w_run
        phase = (phase + dt / max(stride, 0.1) * (v / (MOVES["walkPace"] + (MOVES["runPace"] - MOVES["walkPace"]) * w_run) if v > 0.5 else 0)) % 1
        moving = sample(walk, phase * walk["length"])
        moving = mix(moving, sample(run, phase * run["length"]), w_run)
        still = sample(idle, T)
        pose = mix(still, moving, w_walk)
        # the jump: up with the jump's clip, down with the fall's, the root on an arc
        y_off = 0.0
        if T_JUMP <= T < T_LAND:
            u = (T - T_JUMP) / (T_LAND - T_JUMP)
            y_off = 4.0 * 4 * u * (1 - u)
            air = sample(jump, (T - T_JUMP)) if u < 0.5 else sample(fall, (T - T_JUMP) - (T_LAND - T_JUMP) / 2)
            pose = mix(pose, air, smooth(u / 0.15) * (1 - smooth((u - 0.85) / 0.15)))
        # place every part: root, then the chain (Roblox space), then to Blender
        root = Matrix.Translation((0, ROOT_HEIGHT + y_off, -z))
        world = {"Root": root}
        for name, parent, a0, a1 in JOINTS:
            q, p = pose.get(name, (Quaternion(), Vector((0, 0, 0))))
            m_pose = Matrix.Translation(p) @ q.to_matrix().to_4x4()
            world[name] = world[parent] @ Matrix.Translation(a0) @ m_pose @ Matrix.Translation(a1).inverted()
            mb = C @ world[name] @ C_INV
            ob = parts[name]
            loc, rot, _ = mb.decompose()
            ob.location = loc
            ob.rotation_quaternion = rot
            ob.keyframe_insert("location", frame=fi)
            ob.keyframe_insert("rotation_quaternion", frame=fi)
        # the camera: beside and a little ahead, at chest height, going along with the body
        # far enough that the whole body, and a jump, stay in the picture with room round them
        target = Vector((0, 2.4 + y_off * 0.85, -z - 1.0))
        eye = Vector((17.0, 4.6 + y_off * 0.6, -z - 9.5))
        cb = (C @ Matrix.Translation(eye) @ C_INV).to_translation()
        tb = (C @ Matrix.Translation(target) @ C_INV).to_translation()
        cam.location = cb
        cam.rotation_euler = (tb - cb).to_track_quat("-Z", "Y").to_euler()
        cam.keyframe_insert("location", frame=fi)
        cam.keyframe_insert("rotation_euler", frame=fi)
        for label, t0, t1 in labels:
            label.hide_render = not (t0 <= T < t1)
            label.keyframe_insert("hide_render", frame=fi)


def render(scene, name):
    scene.render.image_settings.media_type = "VIDEO"
    scene.render.image_settings.file_format = "FFMPEG"
    scene.render.ffmpeg.format = "MPEG4"
    scene.render.ffmpeg.codec = "H264"
    scene.render.ffmpeg.constant_rate_factor = "HIGH"
    scene.render.filepath = os.path.join(OUT, name + ".mp4")
    bpy.ops.render.render(animation=True)
    print("WROTE", scene.render.filepath)


for i in range(1, len(MOVES["sets"]) + 1):
    if ONLY is not None and ONLY != i:
        continue
    scene, parts, cam, labels, sdata = build_scene(i)
    animate(scene, parts, cam, labels, sdata)
    if STILLS:
        for fr in STILLS:
            scene.frame_set(fr)
            scene.render.image_settings.file_format = "PNG"
            scene.render.filepath = os.path.join(OUT, f"check_set{i}_{fr:03d}.png")
            bpy.ops.render.render(write_still=True)
        continue
    render(scene, f"set{i}_{sdata['name'].lower()}")
print("DONE")
