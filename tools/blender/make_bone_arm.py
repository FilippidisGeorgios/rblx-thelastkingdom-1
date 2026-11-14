"""
make_bone_arm.py - a skeletal forearm and hand for the dead, made from code (Blender 5.x, headless).

  blender -b --factory-startup -P tools/blender/make_bone_arm.py -- <out_dir>

Writes <out_dir>/bone_arm.glb (four meshes) and <out_dir>/bone_arm_*.png (review renders).
  ForearmR / ForearmL   radius + ulna, in the LOWER ARM's own frame (long axis X, elbow at +X, wrist at -X; the radius on +Y)
  HandR / HandL         carpals, metacarpals, finger and thumb bones, in the HAND's own frame (wrist at +Y 0.18, fingers
                        hang toward -Y and curl toward +Z; the right thumb on -X, the left on +X)
These are the frames of the bodies in ServerStorage.Assets.Undead (measured 2026-11-14), so a MeshPart can be welded to
the existing LowerArm / Hand with no turning. One unit is one stud. Coordinates are written in ROBLOX axes (x right,
y up, z toward the viewer) and turned into Blender's at the end: B(x, y, z) = (x, -z, y), which glTF turns back unchanged.

Anatomy (kept honest, no skin, no blood): the radius flares to a wide wrist end and has a round head at the elbow; the
ulna has a hooked olecranon at the elbow and a small head at the wrist; a gap between them; eight carpals in two rows;
five metacarpals with knuckle heads; three phalanges to each finger and two to the thumb, each with swollen joint ends,
the fingers partly curled like a claw. About 2.8k triangles an arm, so a crowd of them is affordable.
"""
import bpy, bmesh, sys, math, os
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else os.path.join(os.getcwd(), "bone_out"))
os.makedirs(OUT, exist_ok=True)


def B(x, y, z):
    return Vector((x, -z, y))


def ring_frame(axis, hint):
    axis = axis.normalized()
    u = (hint - axis * hint.dot(axis))
    if u.length < 1e-6:
        u = Vector((1, 0, 0)) - axis * axis.x
    u.normalize()
    v = axis.cross(u).normalized()
    return u, v


def bone(bm, a, b, r_mid, r_a, r_b, flat=1.0, hint=Vector((0, 0, 1)), bow=Vector((0, 0, 0)),
         rings=9, seg=8, flare_a=0.22, flare_b=0.22):
    """A long bone from a to b (Roblox-axis vectors): a shaft of r_mid, swollen to r_a / r_b at the ends, flattened by `flat`
    (cross-section u : v), slightly bowed, with rounded ends."""
    a, b = Vector(a), Vector(b)
    axis = (b - a)
    L = axis.length
    u, v = ring_frame(axis, Vector(hint))
    ring_verts = []
    for i in range(rings + 1):
        t = i / rings
        c = a + axis * t + bow * math.sin(math.pi * t)
        r = r_mid
        if t < flare_a:
            k = (1 - t / flare_a) ** 2
            r = r_mid + (r_a - r_mid) * k
        elif t > 1 - flare_b:
            k = (1 - (1 - t) / flare_b) ** 2
            r = r_mid + (r_b - r_mid) * k
        row = []
        for s in range(seg):
            ang = 2 * math.pi * s / seg
            p = c + u * (math.cos(ang) * r * flat) + v * (math.sin(ang) * r)
            row.append(bm.verts.new(B(*p)))
        ring_verts.append(row)
    for i in range(rings):
        for s in range(seg):
            s2 = (s + 1) % seg
            bm.faces.new((ring_verts[i][s], ring_verts[i][s2], ring_verts[i + 1][s2], ring_verts[i + 1][s]))
    # rounded caps: one shrunken ring then a point
    for end, sign, rr in ((0, -1, r_a), (rings, 1, r_b)):
        base = ring_verts[end]
        c = a + axis * (0 if end == 0 else 1) + (bow * 0)
        small = []
        for s in range(seg):
            ang = 2 * math.pi * s / seg
            p = c + axis.normalized() * (sign * rr * 0.28) + u * (math.cos(ang) * rr * flat * 0.62) + v * (math.sin(ang) * rr * 0.62)
            small.append(bm.verts.new(B(*p)))
        tip = bm.verts.new(B(*(c + axis.normalized() * (sign * rr * 0.55))))
        for s in range(seg):
            s2 = (s + 1) % seg
            bm.faces.new((base[s], base[s2], small[s2], small[s]) if sign > 0 else (base[s2], base[s], small[s], small[s2]))
            bm.faces.new((small[s], small[s2], tip) if sign > 0 else (small[s2], small[s], tip))


def blob(bm, centre, radii, rot=(0, 0, 0), u=6, v=5):
    """A small lumpy ellipsoid (a carpal)."""
    res = bmesh.ops.create_uvsphere(bm, u_segments=u, v_segments=v, radius=1.0)
    verts = res["verts"]
    m = Matrix.Diagonal(Vector((radii[0], radii[2], radii[1])).to_4d())  # Roblox y is Blender z, Roblox z is -Blender y
    rot_m = Matrix.Rotation(rot[2], 4, "Y") @ Matrix.Rotation(rot[1], 4, "Z") @ Matrix.Rotation(rot[0], 4, "X")
    for vt in verts:
        vt.co = rot_m @ (m @ vt.co) + B(*centre)


def finger(bm, start, spread_x, lengths, curls, radii, hint=Vector((1, 0, 0)), toward=Vector((0, 0, 1))):
    """A chain of phalanges from `start`; each segment points down (-Y), turned toward `toward` by its cumulative curl."""
    p = Vector(start)
    cum = 0.0
    for i, (L, c) in enumerate(zip(lengths, curls)):
        cum = c
        d = Vector((spread_x, -math.cos(math.radians(cum)), 0)) + toward * math.sin(math.radians(cum))
        d.normalize()
        q = p + d * L
        r = radii[i]
        bone(bm, p, q, r, r * 1.32, r * 1.25 if i < len(lengths) - 1 else r * 0.7, flat=1.0, hint=hint, rings=3, seg=7, flare_a=0.3, flare_b=0.3)
        p = q + d * 0.004


def make_forearm(bm):
    # the radius: round head at the elbow, a flaring wrist end, thumb side (+Y), a touch of bow toward the front
    bone(bm, (0.50, 0.074, 0.0), (-0.55, 0.080, 0.0), 0.034, 0.062, 0.088, flat=1.15, hint=Vector((0, 1, 0)), bow=Vector((0, 0.012, 0.014)), rings=14, seg=8)
    # the ulna: a hooked olecranon at the elbow, a slim shaft, a small head at the wrist
    bone(bm, (0.60, -0.072, 0.0), (-0.52, -0.078, 0.0), 0.034, 0.080, 0.050, flat=1.1, hint=Vector((0, 1, 0)), bow=Vector((0, -0.010, -0.012)), rings=14, seg=8)
    bone(bm, (0.62, -0.070, 0.0), (0.54, -0.070, 0.0), 0.062, 0.070, 0.070, flat=1.0, hint=Vector((0, 1, 0)), rings=3, seg=8)
    # the elbow's hook, a short block standing off the ulna toward the back (+Z)
    bone(bm, (0.58, -0.070, 0.01), (0.58, -0.070, 0.07), 0.05, 0.06, 0.03, flat=1.0, hint=Vector((1, 0, 0)), rings=3, seg=7)


def make_hand(bm):
    # eight carpals, two rows
    prox = [(-0.125, 0.140, 0.00, (0.052, 0.040, 0.040)), (-0.04, 0.150, -0.005, (0.050, 0.042, 0.042)),
            (0.045, 0.145, 0.0, (0.050, 0.040, 0.040)), (0.125, 0.130, 0.0, (0.040, 0.036, 0.040))]
    dist = [(-0.15, 0.055, 0.005, (0.048, 0.038, 0.042)), (-0.06, 0.050, 0.0, (0.044, 0.038, 0.040)),
            (0.03, 0.048, 0.004, (0.046, 0.040, 0.042)), (0.115, 0.050, 0.0, (0.050, 0.040, 0.042))]
    for x, y, z, r in prox + dist:
        blob(bm, (x, y, z), r)
    # four metacarpals: fan out a little; each bone's head (knuckle) is swollen
    knuckles = [(-0.165, -0.265, 0.040), (-0.055, -0.285, 0.050), (0.055, -0.275, 0.048), (0.160, -0.245, 0.036)]
    roots = [(-0.14, 0.025, 0.00), (-0.05, 0.020, 0.00), (0.04, 0.020, 0.0), (0.12, 0.022, 0.0)]
    for (rx, ry, rz), (kx, ky, kz) in zip(roots, knuckles):
        bone(bm, (rx, ry, rz), (kx, ky, kz), 0.021, 0.034, 0.040, flat=1.0, hint=Vector((1, 0, 0)), rings=5, seg=7, flare_a=0.25, flare_b=0.3)
    # the fingers: index, middle, ring, little: three phalanges each, partly curled
    lens = [(0.150, 0.088, 0.070), (0.168, 0.098, 0.074), (0.155, 0.092, 0.068), (0.118, 0.070, 0.060)]
    curls = [(24, 52, 78), (30, 58, 84), (22, 50, 76), (34, 62, 88)]
    radii = [(0.0215, 0.0185, 0.0150), (0.0225, 0.0190, 0.0155), (0.0210, 0.0180, 0.0148), (0.0185, 0.0160, 0.0130)]
    spreads = [-0.10, -0.03, 0.04, 0.12]
    for k, L, c, r, sx in zip(knuckles, lens, curls, radii, spreads):
        finger(bm, k, sx, L, c, r)
    # the thumb on the -X side: a metacarpal angled outward, two phalanges curling toward the palm side
    bone(bm, (-0.115, 0.045, 0.01), (-0.265, -0.095, 0.062), 0.024, 0.036, 0.040, flat=1.0, hint=Vector((0, 0, 1)), rings=5, seg=7)
    finger(bm, (-0.268, -0.100, 0.064), -0.35, (0.100, 0.078), (28, 62), (0.0235, 0.0195), hint=Vector((0, 0, 1)), toward=Vector((0.15, 0, 1)))


def mirror(bm, axis_blender):
    """Mirror a bmesh across one Blender axis (x, y or z), flipping the faces so the normals stay outward."""
    idx = {"x": 0, "y": 1, "z": 2}[axis_blender]
    for v in bm.verts:
        co = v.co.copy()
        co[idx] = -co[idx]
        v.co = co
    bmesh.ops.reverse_faces(bm, faces=bm.faces[:])


def build(name, fn, mirror_axis=None):
    bm = bmesh.new()
    fn(bm)
    if mirror_axis:
        mirror(bm, mirror_axis)
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=0.0005)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    bmesh.ops.triangulate(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    for p in me.polygons:
        p.use_smooth = True
    ob = bpy.data.objects.new(name, me)
    bpy.context.collection.objects.link(ob)
    return ob


# ---------------------------------------------------------------------------
bpy.ops.wm.read_factory_settings(use_empty=True)
mat = bpy.data.materials.new("Bone")
mat.use_nodes = True
bsdf = next(n for n in mat.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
bsdf.inputs["Base Color"].default_value = (0.78, 0.70, 0.55, 1)
bsdf.inputs["Roughness"].default_value = 0.62

objs = {}
objs["ForearmR"] = build("ForearmR", make_forearm)
objs["HandR"] = build("HandR", make_hand)
objs["ForearmL"] = build("ForearmL", make_forearm, "z")  # the lower arm's +Y (thumb side) is Blender +Z
objs["HandL"] = build("HandL", make_hand, "x")  # the hand's -X (thumb side) mirrors to +X
for o in objs.values():
    o.data.materials.append(mat)

tris = {n: len(o.data.polygons) for n, o in objs.items()}
print("TRIANGLES", tris)

# ---- review: the right arm assembled (hand placed in the lower arm's frame: pos(-0.73,0,0) * Rz(-90)), 4 views
asm = []
for src, off in ((objs["ForearmR"], None), (objs["HandR"], "hand")):
    cp = src.copy()
    cp.data = src.data.copy()
    cp.name = "ASM_" + src.name
    bpy.context.collection.objects.link(cp)
    if off:
        # Roblox: (x, y, z) -> (y - 0.73, -x, z); in Blender coordinates that is a rotation of -90 deg about Blender's Y
        # (Roblox Z is Blender -Y) and a move of (-0.73, 0, 0)
        cp.matrix_world = Matrix.Translation(Vector((-0.73, 0, 0))) @ Matrix.Rotation(math.radians(90), 4, "Y")
    asm.append(cp)

for o in objs.values():
    o.hide_render = True  # the originals sit at the origin; only the assembled copy is photographed

scene = bpy.context.scene
scene.render.resolution_x, scene.render.resolution_y = 900, 600
try:
    scene.render.engine = "BLENDER_EEVEE"
except TypeError:
    scene.render.engine = "BLENDER_WORKBENCH"
world = bpy.data.worlds.new("W")
world.use_nodes = True
world.node_tree.nodes["Background"].inputs[0].default_value = (0.05, 0.05, 0.06, 1)
scene.world = world
for loc, energy, col in (((1.5, -2.5, 2.5), 400, (1.0, 0.82, 0.62)), ((-2.5, 1.0, 1.5), 150, (0.55, 0.7, 1.0)), ((0.2, 2.5, 1.0), 220, (0.8, 0.85, 1.0))):
    ld = bpy.data.lights.new("L", "AREA")
    ld.energy = energy
    ld.color = col
    ld.size = 2.5
    lo = bpy.data.objects.new("L", ld)
    lo.location = loc
    bpy.context.collection.objects.link(lo)
    con = lo.constraints.new("TRACK_TO")
    con.target = asm[0]
    con.track_axis, con.up_axis = "TRACK_NEGATIVE_Z", "UP_Y"

cam_d = bpy.data.cameras.new("C")
cam_d.lens = 70
cam = bpy.data.objects.new("C", cam_d)
bpy.context.collection.objects.link(cam)
scene.camera = cam
centre = Vector((-0.2, 0, 0))
views = {"front": Vector((0, -1, 0.1)), "side": Vector((1, 0, 0.1)), "top": Vector((0, -0.2, 1)), "back": Vector((-0.6, 1, 0.3))}
for name, d in views.items():
    cam.location = centre + d.normalized() * 2.6
    cam.rotation_euler = (centre - cam.location).to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, f"bone_arm_{name}.png")
    bpy.ops.render.render(write_still=True)

# ---- export: only the four meshes
for o in list(bpy.data.objects):
    if o.name.startswith("ASM_") or o.type in {"LIGHT", "CAMERA"}:
        bpy.data.objects.remove(o)
bpy.ops.object.select_all(action="DESELECT")
for o in objs.values():
    o.select_set(True)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "bone_arm.glb"), use_selection=True, export_format="GLB",
                          export_apply=True, export_yup=True, export_materials="EXPORT")
print("DONE", OUT)
