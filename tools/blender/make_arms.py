"""
make_arms.py - the weapons, the shield, the crown and the antlers of the dead, made from code (Blender 5.x, headless).

  blender -b --factory-startup --python-exit-code 1 -P tools/blender/make_arms.py -- <out_dir>

Writes <out_dir>/arms.glb and two review renders (<out_dir>/arms_front.png, arms_three_quarter.png).

The developer, 2026-11-14: the spearman's pole shorter and real, held right; the Hollow Knight's sword smaller; the
King's bow gone, a real bordeaux shield ("not parts: 3D, it should catch the light"), a very sharp sword with an
effect, a taller thinner crown that the head touches exactly (higher at the front, coming down round the back); the
Huntsman's horns real and darker brown, his spear a little shorter and real.

Every item is built in its OWN frame, in ROBLOX axes (x right, y up, z toward the viewer), one unit a stud, and turned
into Blender's at the end, B(x, y, z) = (x, -z, y), which glTF turns back (the importer then turns a model half a turn
about Y, undone in Studio as for the bone arm). Each item also carries three tiny marker meshes, <item>_M0 at its
origin, <item>_MX one stud along +X and <item>_MY one stud along +Y, so its frame can be read back in Studio whatever
the importer did.

  Spear        the spearman's: 7.6 long, ash shaft, leaf head on a socket with langets, iron butt, two leather grips.
               Frame: origin at the rear (right) hand's fist point, +X to the point, +Y the blade's edge.
               Second grip (left hand) at x = SPEAR_GRIP2.
  BoarSpear    the Huntsman's: 8.0 long, dark shaft, broad blade, lugs (wings) bound with leather.
  KnightSword  a hand-and-a-half sword, 5.1 long: wheel of a pommel, long two-hand grip, straight cross, fullered blade.
               Frame: origin at the right fist (just under the cross), +X to the point, +Y the true edge.
  KingSword    an arming sword, 4.4 long: gilded downturned cross, gold-wire grip, wheel pommel with the star.
  Shield       a heater shield, 2.7 by 2.2, bowed, a metal rim, the star of the house in relief, a handle and an arm
               strap behind. Frame: origin at the handle (the left fist), +X up the handle, +Y away from the arm.
  Crown        in the King's HEAD frame (measured: the inner rim follows the head at 0.30 above its centre, 24 radii).
  Antler       one antler (the right); the left is the same mirrored in Studio. Frame: origin at the burr, +Y up.
"""
import bpy, bmesh, sys, math, os, random
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else os.path.join(os.getcwd(), "arms_out"))
os.makedirs(OUT, exist_ok=True)
random.seed(14)

SPEAR_GRIP2 = 1.9
BOAR_GRIP2 = 2.0
KNIGHT_GRIP2 = -0.46

# The King's head, measured in Studio (2026-11-14): radius at 0.30 above the head's centre, every 15 degrees from the
# front (angle a: direction (sin a, 0, -cos a)), smoothed over three samples.
HEAD_R = [0.512, 0.488, 0.474, 0.448, 0.451, 0.444, 0.449, 0.467, 0.500, 0.530, 0.563, 0.579,
          0.600, 0.579, 0.556, 0.516, 0.501, 0.488, 0.472, 0.449, 0.444, 0.465, 0.495, 0.507]
CROWN_RIM_Y = 0.30


def B(v):
    return Vector((v[0], -v[2], v[1]))


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)


def new_obj(name, bm, mat=None):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat:
        ob.data.materials.append(mat)
    for p in ob.data.polygons:
        p.use_smooth = True
    return ob


def material(name, rgb, metal=0.0, rough=0.6):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    m.diffuse_color = (rgb[0], rgb[1], rgb[2], 1)
    return m


def srgb(r, g, b):
    def c(x):
        x = x / 255
        return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4
    return (c(r), c(g), c(b))


clear()  # first: a factory reset removes every material made before it
MAT = {
    "wood": material("wood", srgb(118, 88, 60), 0, 0.7),
    "darkwood": material("darkwood", srgb(70, 50, 36), 0, 0.75),
    "iron": material("iron", srgb(78, 76, 74), 1, 0.45),
    "darkiron": material("darkiron", srgb(56, 54, 52), 1, 0.5),
    "steel": material("steel", srgb(170, 172, 176), 1, 0.25),
    "leather": material("leather", srgb(68, 44, 30), 0, 0.8),
    "gold": material("gold", srgb(196, 150, 70), 1, 0.3),
    "bordeaux": material("bordeaux", srgb(104, 20, 32), 0, 0.35),
    "antler": material("antler", srgb(52, 36, 24), 0, 0.65),
    "gem": material("gem", srgb(120, 10, 24), 0, 0.1),
    "gemblue": material("gemblue", srgb(30, 50, 120), 0, 0.1),
    "pearl": material("pearl", srgb(226, 220, 204), 0, 0.3),
    "marker": material("marker", (1, 0, 1), 0, 1),
}


# ---------------------------------------------------------------------------------------------------------------------
# shapes, in Roblox axes (converted with B when the vertices are made)
# ---------------------------------------------------------------------------------------------------------------------
def lathe(profile, seg=12, axis="x", offset=(0, 0, 0), scale_z=1.0):
    """Revolves points (t, r) about the X axis (t along it); returns a bmesh with caps."""
    bm = bmesh.new()
    rings = []
    for t, r in profile:
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            y, z = math.cos(a) * r, math.sin(a) * r * scale_z
            p = (t + offset[0], y + offset[1], z + offset[2])
            ring.append(bm.verts.new(B(p)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(seg):
            a, b = rings[i][k], rings[i][(k + 1) % seg]
            c, d = rings[i + 1][(k + 1) % seg], rings[i + 1][k]
            bm.faces.new((a, b, c, d))
    if profile[0][1] > 1e-4:
        bm.faces.new(list(reversed(rings[0])))
    if profile[-1][1] > 1e-4:
        bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-5)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def section_loft(sections):
    """sections: list of (x, [ (y, z) ... ]) all with the same point count, closed rings, ends capped."""
    bm = bmesh.new()
    rings = []
    for x, pts in sections:
        rings.append([bm.verts.new(B((x, y, z))) for (y, z) in pts])
    n = len(sections[0][1])
    for i in range(len(rings) - 1):
        for k in range(n):
            a, b = rings[i][k], rings[i][(k + 1) % n]
            c, d = rings[i + 1][(k + 1) % n], rings[i + 1][k]
            if len({a, b, c, d}) == 4:
                bm.faces.new((a, b, c, d))
    bm.faces.new(list(reversed(rings[0])))
    bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def blade(x0, x1, width_fn, thick_fn, fuller_fn=None, n=28):
    """A blade along X from x0 to x1: half-width w(u) along Y (the edges), half-thickness t(u) along Z, an optional
    fuller depth f(u) (a groove down the middle). u = 0..1. Lenticular-diamond section, 10 points."""
    secs = []
    for i in range(n + 1):
        u = i / n
        x = x0 + (x1 - x0) * u
        w = max(width_fn(u), 0.002)
        t = max(thick_fn(u), 0.0015)
        f = fuller_fn(u) if fuller_fn else 0.0
        mid = t * (1 - f)
        pts = [(w, 0), (0.55 * w, 0.82 * t), (0.2 * w, t), (0.0, mid), (-0.2 * w, t), (-0.55 * w, 0.82 * t),
               (-w, 0), (-0.55 * w, -0.82 * t), (-0.2 * w, -t), (0.0, -mid), (0.2 * w, -t), (0.55 * w, -0.82 * t)]
        secs.append((x, pts))
    return section_loft(secs)


def box(c, size, rot=None):
    bm = bmesh.new()
    bmesh.ops.create_cube(bm, size=1.0)
    for v in bm.verts:
        p = Vector((v.co.x * size[0], v.co.y * size[1], v.co.z * size[2]))
        if rot:
            p = rot @ p
        v.co = B((p.x + c[0], p.y + c[1], p.z + c[2]))
    return bm


def ball(c, r, seg=10, squash=(1, 1, 1)):
    bm = bmesh.new()
    bmesh.ops.create_uvsphere(bm, u_segments=seg, v_segments=max(6, seg // 2), radius=1.0)
    for v in bm.verts:
        p = Vector((v.co.x * r * squash[0], v.co.z * r * squash[1], v.co.y * r * squash[2]))
        v.co = B((p.x + c[0], p.y + c[1], p.z + c[2]))
    return bm


def tube(points, radii, seg=8, cap=True):
    """A tube through 3D points (Roblox axes) with a radius at each point (parallel-transport frames)."""
    bm = bmesh.new()
    rings = []
    prev_u = None
    for i, p in enumerate(points):
        p = Vector(p)
        if i == 0:
            d = Vector(points[1]) - p
        elif i == len(points) - 1:
            d = p - Vector(points[i - 1])
        else:
            d = Vector(points[i + 1]) - Vector(points[i - 1])
        d.normalize()
        if prev_u is None:
            hint = Vector((0, 0, 1)) if abs(d.z) < 0.9 else Vector((1, 0, 0))
            u = (hint - d * hint.dot(d)).normalized()
        else:
            u = (prev_u - d * prev_u.dot(d)).normalized()
        v = d.cross(u).normalized()
        prev_u = u
        r = radii[i]
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            q = p + u * math.cos(a) * r + v * math.sin(a) * r
            ring.append(bm.verts.new(B(q)))
        rings.append(ring)
    for i in range(len(rings) - 1):
        for k in range(seg):
            bm.faces.new((rings[i][k], rings[i][(k + 1) % seg], rings[i + 1][(k + 1) % seg], rings[i + 1][k]))
    if cap:
        bm.faces.new(list(reversed(rings[0])))
        if radii[-1] > 1e-4:
            bm.faces.new(rings[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def merge(bms):
    out = bmesh.new()
    for bm in bms:
        me = bpy.data.meshes.new("tmp")
        bm.to_mesh(me)
        out.from_mesh(me)
        bpy.data.meshes.remove(me)
        bm.free()
    return out


def markers(item, origin=(0, 0, 0)):
    o = Vector(origin)
    for suffix, off in (("M0", (0, 0, 0)), ("MX", (1, 0, 0)), ("MY", (0, 1, 0))):
        c = o + Vector(off)
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=3, radius1=0.03, radius2=0.0, depth=0.04)
        for v in bm.verts:
            v.co = B((v.co.x + c.x, v.co.z + c.y, v.co.y + c.z))
        new_obj(f"{item}_{suffix}", bm, MAT["marker"])


def wrap_rings(x0, x1, r, count, seg=12):
    """A leather or wire wrap: a row of fat rings along X."""
    bms = []
    step = (x1 - x0) / count
    for i in range(count):
        a = x0 + i * step
        prof = [(a, r * 0.93), (a + step * 0.15, r), (a + step * 0.5, r * 1.04), (a + step * 0.85, r), (a + step, r * 0.93)]
        bms.append(lathe(prof, seg))
    return merge(bms)


# ---------------------------------------------------------------------------------------------------------------------
# the items
# ---------------------------------------------------------------------------------------------------------------------
def make_spear():
    butt, socket0, head0, tip = -2.1, 4.1, 4.62, 5.5
    shaft = lathe([(butt + 0.12, 0.084), (0.0, 0.085), (2.5, 0.081), (socket0 + 0.05, 0.076)], 12)
    new_obj("Spear_Shaft", shaft, MAT["wood"])
    ferrule = lathe([(butt, 0.0), (butt + 0.015, 0.06), (butt + 0.05, 0.09), (butt + 0.2, 0.092), (butt + 0.22, 0.086)], 12)
    new_obj("Spear_Butt", ferrule, MAT["darkiron"])
    grips = merge([wrap_rings(-0.38, 0.38, 0.094, 9), wrap_rings(SPEAR_GRIP2 - 0.3, SPEAR_GRIP2 + 0.3, 0.09, 7)])
    new_obj("Spear_Wrap", grips, MAT["leather"])
    sock = lathe([(socket0 - 0.02, 0.098), (socket0 + 0.04, 0.1), (socket0 + 0.06, 0.088), (socket0 + 0.3, 0.07),
                  (socket0 + 0.32, 0.078), (socket0 + 0.36, 0.066), (head0, 0.05)], 12)
    langets = merge([box((socket0 - 0.2, s * 0.08, 0), (0.42, 0.012, 0.05)) for s in (-1, 1)] +
                    [ball((socket0 - 0.32, s * 0.088, 0), 0.016, 6) for s in (-1, 1)])
    new_obj("Spear_Socket", merge([sock, langets]), MAT["iron"])

    def w(u):
        if u < 0.32:
            return 0.045 + (0.17 - 0.045) * math.sin(u / 0.32 * math.pi / 2) ** 0.8
        return 0.17 * (1 - ((u - 0.32) / 0.68) ** 1.25)

    def t(u):
        return 0.042 * (1 - u * 0.75)
    new_obj("Spear_Head", blade(head0 - 0.04, tip, w, t, None, 26), MAT["steel"])
    markers("Spear")
    g2 = bmesh.new()
    bmesh.ops.create_cone(g2, cap_ends=True, segments=3, radius1=0.03, radius2=0.0, depth=0.04)
    for v in g2.verts:
        v.co = B((v.co.x + SPEAR_GRIP2, v.co.z, v.co.y))
    new_obj("Spear_G2", g2, MAT["marker"])


def make_boar_spear():
    butt, socket0, lug, head0, tip = -2.2, 4.0, 4.5, 4.62, 5.8
    shaft = lathe([(butt + 0.1, 0.098), (0, 0.1), (2.6, 0.096), (socket0 + 0.05, 0.09)], 12)
    # a few knots
    knots = merge([ball((x, 0.09 * math.cos(a), 0.09 * math.sin(a)), 0.03, 6) for x, a in ((-1.2, 0.5), (0.9, 2.4), (2.9, 4.1))])
    new_obj("BoarSpear_Shaft", merge([shaft, knots]), MAT["darkwood"])
    new_obj("BoarSpear_Butt", lathe([(butt, 0.0), (butt + 0.02, 0.07), (butt + 0.06, 0.104), (butt + 0.22, 0.104), (butt + 0.24, 0.098)], 10), MAT["darkiron"])
    new_obj("BoarSpear_Wrap", merge([wrap_rings(-0.4, 0.4, 0.108, 9), wrap_rings(BOAR_GRIP2 - 0.32, BOAR_GRIP2 + 0.32, 0.104, 7)]), MAT["leather"])
    sock = lathe([(socket0 - 0.02, 0.11), (socket0 + 0.05, 0.112), (socket0 + 0.08, 0.1), (lug - 0.04, 0.078), (head0, 0.06)], 8)
    rivets = merge([ball((socket0 + 0.2, 0.1 * math.cos(a), 0.1 * math.sin(a)), 0.02, 6) for a in (0, math.pi)])
    lugs = merge([tube([(lug, s * 0.06, 0), (lug + 0.05, s * 0.22, 0), (lug + 0.02, s * 0.4, 0)], [0.045, 0.04, 0.02], 6) for s in (-1, 1)])
    new_obj("BoarSpear_Socket", merge([sock, rivets, lugs]), MAT["darkiron"])
    binding = merge([lathe([(lug - 0.08 + i * 0.045, 0.08), (lug - 0.06 + i * 0.045, 0.092), (lug - 0.04 + i * 0.045, 0.08)], 10) for i in range(4)])
    new_obj("BoarSpear_Binding", binding, MAT["leather"])

    def w(u):
        if u < 0.28:
            return 0.06 + (0.26 - 0.06) * math.sin(u / 0.28 * math.pi / 2) ** 0.7
        return 0.26 * (1 - ((u - 0.28) / 0.72) ** 1.15)

    def t(u):
        return 0.06 * (1 - u * 0.8)
    new_obj("BoarSpear_Head", blade(head0 - 0.04, tip, w, t, None, 26), MAT["darkiron"])
    markers("BoarSpear")
    g2 = bmesh.new()
    bmesh.ops.create_cone(g2, cap_ends=True, segments=3, radius1=0.03, radius2=0.0, depth=0.04)
    for v in g2.verts:
        v.co = B((v.co.x + BOAR_GRIP2, v.co.z, v.co.y))
    new_obj("BoarSpear_G2", g2, MAT["marker"])


def make_knight_sword():
    pom0, grip0, guard, tip = -0.86, -0.62, 0.33, 4.25
    new_obj("KnightSword_Grip", merge([wrap_rings(grip0, 0.24, 0.1, 12, 12)]), MAT["leather"])
    # a faceted pear pommel
    new_obj("KnightSword_Pommel", lathe([(pom0, 0.0), (pom0 + 0.03, 0.08), (pom0 + 0.1, 0.135), (pom0 + 0.17, 0.12),
                                          (grip0 - 0.01, 0.07), (grip0 + 0.02, 0.06)], 8), MAT["darkiron"])
    # the cross: a bar along Y, a little bowed toward the point, swelling at the ends
    pts, rad = [], []
    for i in range(13):
        s = -0.64 + 1.28 * i / 12
        pts.append((guard + 0.06 * (abs(s) / 0.64) ** 2, s, 0))
        rad.append(0.045 + 0.02 * (abs(s) / 0.64) ** 4)
    cross = merge([tube(pts, rad, 8), box((guard, 0, 0), (0.1, 0.16, 0.12))])
    new_obj("KnightSword_Guard", cross, MAT["darkiron"])

    def w(u):
        return 0.155 * (1 - 0.3 * u) * (1 if u < 0.82 else max(0.0, 1 - ((u - 0.82) / 0.18) ** 1.6))

    def t(u):
        return 0.036 * (1 - 0.5 * u)

    def f(u):
        return 0.55 * (1 - min(1, u / 0.6) ** 3) if u < 0.6 else 0.0
    new_obj("KnightSword_Blade", blade(guard + 0.04, tip, w, t, f, 30), MAT["steel"])
    markers("KnightSword")
    g2 = bmesh.new()
    bmesh.ops.create_cone(g2, cap_ends=True, segments=3, radius1=0.03, radius2=0.0, depth=0.04)
    for v in g2.verts:
        v.co = B((v.co.x + KNIGHT_GRIP2, v.co.z, v.co.y))
    new_obj("KnightSword_G2", g2, MAT["marker"])


def make_king_sword():
    pom, grip0, guard, tip = -0.42, -0.27, 0.28, 3.9
    new_obj("KingSword_Grip", wrap_rings(grip0, 0.22, 0.082, 14, 12), MAT["gold"])
    # a wheel pommel (flat faces along Z) with a raised star on each face
    wheel = lathe([(-0.05, 0.0), (-0.048, 0.12), (-0.035, 0.16), (0.035, 0.16), (0.048, 0.12), (0.05, 0.0)], 20)
    rot = Matrix.Rotation(math.radians(90), 4, "Y")  # the wheel's axis along Z
    me = bpy.data.meshes.new("w")
    wheel.to_mesh(me)
    wheel.free()
    wheelb = bmesh.new()
    wheelb.from_mesh(me)
    bpy.data.meshes.remove(me)
    # (built about X in Roblox axes; turn it about Roblox Y so its axis is Roblox Z, then move it to the pommel)
    for v in wheelb.verts:
        p = Vector((v.co.x, v.co.z, -v.co.y))  # back to Roblox axes
        p = Vector((p.z, p.y, -p.x))  # turn about Y
        p += Vector((pom, 0, 0))
        v.co = B(p)
    stars = []
    for side in (-1, 1):
        sb = bmesh.new()
        ring = []
        for k in range(16):
            a = 2 * math.pi * k / 16
            r = 0.11 if k % 2 == 0 else 0.045
            ring.append(sb.verts.new(B((pom + math.cos(a) * r, math.sin(a) * r, side * 0.055))))
        c = sb.verts.new(B((pom, 0, side * 0.075)))
        for k in range(16):
            sb.faces.new((ring[k], ring[(k + 1) % 16], c) if side > 0 else (ring[(k + 1) % 16], ring[k], c))
        stars.append(sb)
    new_obj("KingSword_Pommel", merge([wheelb] + stars), MAT["gold"])
    # the cross: downturned quillons toward the point, a centre plate
    pts, rad = [], []
    for i in range(15):
        s = -0.5 + 1.0 * i / 14
        pts.append((guard + 0.16 * (abs(s) / 0.5) ** 2.2, s, 0))
        rad.append(0.034 + 0.018 * (abs(s) / 0.5) ** 5)
    cross = merge([tube(pts, rad, 8), box((guard + 0.02, 0, 0), (0.14, 0.13, 0.09)),
                   ball((guard + 0.16, -0.5, 0), 0.045, 8), ball((guard + 0.16, 0.5, 0), 0.045, 8)])
    new_obj("KingSword_Guard", cross, MAT["gold"])

    def w(u):
        return 0.14 * (1 - 0.45 * u) * (1 if u < 0.7 else max(0.0, 1 - ((u - 0.7) / 0.3) ** 1.35))

    def t(u):
        return 0.03 * (1 - 0.55 * u)

    def f(u):
        return 0.6 * (1 - min(1, u / 0.7) ** 2) if u < 0.7 else 0.0
    new_obj("KingSword_Blade", blade(guard + 0.06, tip, w, t, f, 32), MAT["steel"])
    markers("KingSword")
    for name, x in (("KingSword_B0", guard + 0.25), ("KingSword_B1", tip - 0.15)):
        g = bmesh.new()
        bmesh.ops.create_cone(g, cap_ends=True, segments=3, radius1=0.03, radius2=0.0, depth=0.04)
        for v in g.verts:
            v.co = B((v.co.x + x, v.co.z, v.co.y))
        new_obj(name, g, MAT["marker"])


def heater_outline(n_side=26):
    """The shield's outline (x, y) in its own face, clockwise from the top left: a straight top, sides that go straight
    down a little and then sweep in to the point (two arcs, the classic heater)."""
    top, shoulder, half = 1.0, 0.3, 1.1
    R, cx = 2.5, -1.4
    # the top edge in short steps (the face is bowed: one long straight piece of rim would stand off its corners)
    pts = [(-half + 2 * half * i / 14, top) for i in range(15)] + [(half, (top + shoulder) / 2), (half, shoulder)]
    # right side: arc centred at (cx, shoulder) from (half, shoulder) down to the point at x = 0
    a0 = 0.0
    a1 = -math.acos((0 - cx) / R)
    for i in range(1, n_side + 1):
        a = a0 + (a1 - a0) * i / n_side
        pts.append((cx + R * math.cos(a), shoulder + R * math.sin(a)))
    # left side, mirrored, back up
    right = pts[17:]
    for (x, y) in reversed(right[:-1]):
        pts.append((-x, y))
    pts.append((-half, shoulder))
    pts.append((-half, (top + shoulder) / 2))
    return pts


def make_shield():
    R = 2.6  # the bow of the face: a cylinder about Y
    depth = 0.11
    outline = heater_outline()

    def bow(x):
        return x * x / (2 * R)  # z: the edges sit further back than the middle (the face bulges toward -Z)

    # the face: a grid inside the outline, bowed, given thickness
    bm = bmesh.new()
    verts = [bm.verts.new(B((x, y, bow(x)))) for (x, y) in outline]
    face = bm.faces.new(verts)
    bmesh.ops.triangulate(bm, faces=[face])
    bmesh.ops.subdivide_edges(bm, edges=bm.edges[:], cuts=3, use_grid_fill=True)
    for v in bm.verts:
        p = Vector((v.co.x, v.co.z, -v.co.y))
        v.co = B((p.x, p.y, bow(p.x)))
    res = bmesh.ops.extrude_face_region(bm, geom=bm.faces[:])
    for e in res["geom"]:
        if isinstance(e, bmesh.types.BMVert):
            e.co += B((0, 0, depth))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    new_obj("Shield_Face", bm, MAT["bordeaux"])
    # the rim: a band round the outline, proud of the face on both sides
    rim = []
    n = len(outline)
    for i in range(n):
        x0, y0 = outline[i]
        x1, y1 = outline[(i + 1) % n]
        mx, my = (x0 + x1) / 2, (y0 + y1) / 2
        L = math.hypot(x1 - x0, y1 - y0)
        ang = math.atan2(y1 - y0, x1 - x0)
        rot = Matrix.Rotation(ang, 3, "Z")
        rim.append(box((mx, my, bow(mx) + depth / 2), (L + 0.03, 0.09, depth + 0.07), rot))
    rivets = []
    for i in range(0, n, 3):
        x, y = outline[i]
        cx, cy = x * 0.94, y * 0.94 + 0.02
        rivets.append(ball((cx, cy, bow(cx) - 0.012), 0.032, 6))
    new_obj("Shield_Rim", merge(rim + rivets), MAT["gold"])
    # the star of the house, in relief, a little above the middle
    sb = bmesh.new()
    sc = (0.0, 0.18)
    ring_f, ring_b = [], []
    for k in range(16):
        a = 2 * math.pi * k / 16 + math.pi / 2
        r = 0.62 if k % 2 == 0 else 0.24
        x, y = sc[0] + math.cos(a) * r, sc[1] + math.sin(a) * r
        ring_f.append(sb.verts.new(B((x, y, bow(x) - 0.045))))
        ring_b.append(sb.verts.new(B((x, y, bow(x) + 0.005))))
    cf = sb.verts.new(B((sc[0], sc[1], -0.075)))
    for k in range(16):
        sb.faces.new((ring_f[k], ring_f[(k + 1) % 16], cf))
        sb.faces.new((ring_b[k], ring_b[(k + 1) % 16], ring_f[(k + 1) % 16], ring_f[k]))
    sb.faces.new(list(reversed(ring_b)))
    bmesh.ops.recalc_face_normals(sb, faces=sb.faces)
    boss = ball((sc[0], sc[1], -0.08), 0.1, 10, (1, 1, 0.6))
    new_obj("Shield_Star", merge([sb, boss]), MAT["gold"])
    # behind: the handle (a bar up and down, on two posts) and the arm strap
    back = depth + 0.0
    hz = back + 0.13
    handle = merge([lathe([(-0.24, 0.045), (0.24, 0.045)], 10),
                    box((-0.24, 0, -0.065 + 0.0), (0.06, 0.06, 0.13)), box((0.24, 0, -0.065), (0.06, 0.06, 0.13))])
    # the handle is built along X; it stands up the shield's Y: turn it
    me = bpy.data.meshes.new("h")
    handle.to_mesh(me)
    handle.free()
    hb = bmesh.new()
    hb.from_mesh(me)
    bpy.data.meshes.remove(me)
    for v in hb.verts:
        p = Vector((v.co.x, v.co.z, -v.co.y))
        p = Vector((0.0 + p.y, p.x, p.z + hz))
        v.co = B(p)
    strap = box((0.0, 0.62, back + 0.09), (0.95, 0.16, 0.035))
    new_obj("Shield_Back", merge([hb, strap]), MAT["leather"])
    # the frame: origin at the handle (where the fist goes), +X up the handle, +Y away from the arm (toward the face)
    for suffix, off in (("M0", (0, 0, hz)), ("MX", (0, 1, hz)), ("MY", (0, 0, hz - 1))):
        bm = bmesh.new()
        bmesh.ops.create_cone(bm, cap_ends=True, segments=3, radius1=0.03, radius2=0.0, depth=0.04)
        for v in bm.verts:
            v.co = B((v.co.x + off[0], v.co.z + off[1], v.co.y + off[2]))
        new_obj("Shield_" + suffix, bm, MAT["marker"])


def head_r(a_deg):
    """The head's radius at the rim height, by angle from the front, interpolated round the 24 samples."""
    a = (a_deg % 360) / 15
    i = int(math.floor(a))
    f = a - i
    return HEAD_R[i % 24] * (1 - f) + HEAD_R[(i + 1) % 24] * f


def make_crown():
    seg = 72
    th = 0.045
    y0 = CROWN_RIM_Y

    def height(a):  # band height above the rim: tall at the front, low at the back
        c = (1 + math.cos(math.radians(a))) / 2
        return 0.2 + 0.2 * c ** 1.6

    bm = bmesh.new()
    inner_b, inner_t, outer_b, outer_t = [], [], [], []
    for k in range(seg):
        a = 360 * k / seg
        r = head_r(a)
        d = (math.sin(math.radians(a)), -math.cos(math.radians(a)))
        h = height(a)
        lean = 0.025  # the band flares a little as it rises
        inner_b.append(bm.verts.new(B((d[0] * r, y0, d[1] * r))))
        inner_t.append(bm.verts.new(B((d[0] * (r + lean), y0 + h, d[1] * (r + lean)))))
        outer_b.append(bm.verts.new(B((d[0] * (r + th), y0, d[1] * (r + th)))))
        outer_t.append(bm.verts.new(B((d[0] * (r + th + lean), y0 + h, d[1] * (r + th + lean)))))
    for k in range(seg):
        n = (k + 1) % seg
        bm.faces.new((inner_b[k], inner_t[k], inner_t[n], inner_b[n]))
        bm.faces.new((outer_b[n], outer_t[n], outer_t[k], outer_b[k]))
        bm.faces.new((inner_t[k], outer_t[k], outer_t[n], inner_t[n]))
        bm.faces.new((outer_b[k], inner_b[k], inner_b[n], outer_b[n]))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    parts = [bm]
    # two beaded rings round the band
    for yy, rr in ((y0 + 0.03, 0.022), ):
        for k in range(0, seg, 2):
            a = 360 * k / seg
            r = head_r(a) + th + 0.012
            d = (math.sin(math.radians(a)), -math.cos(math.radians(a)))
            parts.append(ball((d[0] * r, yy, d[1] * r), rr, 6))
    # the fleurons: a lily at the front and at the sides, points between, lower toward the back
    for k in range(8):
        a = k * 45
        c = (1 + math.cos(math.radians(a))) / 2
        r = head_r(a) + th / 2 + 0.03
        d = Vector((math.sin(math.radians(a)), 0, -math.cos(math.radians(a))))
        side = Vector((math.cos(math.radians(a)), 0, math.sin(math.radians(a))))
        base = d * r + Vector((0, y0 + height(a) - 0.02, 0))
        tall = 0.12 + 0.24 * c ** 1.3
        if k in (0, 2, 6):
            # a lily: a tall middle petal and two curling side petals
            parts.append(tube([base, base + Vector((0, tall * 0.55, 0)) + d * 0.02, base + Vector((0, tall, 0))],
                              [0.05, 0.04, 0.0], 6))
            for s in (-1, 1):
                p0 = base + side * 0.0 + Vector((0, 0.02, 0))
                p1 = base + side * (s * 0.09) + Vector((0, tall * 0.42, 0)) + d * 0.02
                p2 = base + side * (s * 0.13) + Vector((0, tall * 0.3, 0)) + d * 0.04
                parts.append(tube([p0, p1, p2], [0.03, 0.025, 0.006], 6))
            parts.append(ball(base + Vector((0, 0.03, 0)) + d * 0.02, 0.04, 8))
        else:
            parts.append(tube([base, base + Vector((0, tall, 0))], [0.035, 0.0], 6))
            parts.append(ball(base + Vector((0, tall + 0.02, 0)), 0.03, 6))
    new_obj("Crown_Band", merge(parts), MAT["gold"])
    # gems: a great red stone at the front, blue at the sides, red behind
    gems = []
    for a, rr, mat in ((0, 0.075, "gem"), (90, 0.05, "gemblue"), (270, 0.05, "gemblue"), (180, 0.045, "gem"), (45, 0.035, "gem"), (315, 0.035, "gem")):
        r = head_r(a) + th + 0.01
        d = (math.sin(math.radians(a)), -math.cos(math.radians(a)))
        gems.append((ball((d[0] * r, y0 + height(a) * 0.5, d[1] * r), rr, 10, (1, 1.25, 0.6)), mat))
    new_obj("Crown_Gems", merge([g for g, m in gems if m == "gem"]), MAT["gem"])
    new_obj("Crown_Sapphires", merge([g for g, m in gems if m == "gemblue"]), MAT["gemblue"])
    markers("Crown")


def make_antler():
    """One antler, the right: a beam that sweeps out, back and up, a brow tine forward, a bez and a trez tine, and a
    crown of three points. Radii taper; the surface is roughened. Origin at the burr."""
    random.seed(7)
    beam_pts = [(0, 0, 0), (0.28, 0.46, 0.14), (0.64, 1.08, 0.28), (0.92, 1.76, 0.24), (1.06, 2.36, 0.04), (1.02, 2.84, -0.16)]

    def smooth(pts, n=6):
        out = []
        for i in range(len(pts) - 1):
            p0 = Vector(pts[max(0, i - 1)])
            p1, p2 = Vector(pts[i]), Vector(pts[i + 1])
            p3 = Vector(pts[min(len(pts) - 1, i + 2)])
            for k in range(n):
                t = k / n
                t2, t3 = t * t, t * t * t
                out.append(0.5 * ((2 * p1) + (-p0 + p2) * t + (2 * p0 - 5 * p1 + 4 * p2 - p3) * t2 + (-p0 + 3 * p1 - 3 * p2 + p3) * t3))
        out.append(Vector(pts[-1]))
        return out

    def rough(pts, amt):
        return [p + Vector((random.uniform(-amt, amt), random.uniform(-amt, amt), random.uniform(-amt, amt))) if 0 < i < len(pts) - 1 else p for i, p in enumerate(pts)]

    beam = rough(smooth(beam_pts, 7), 0.012)
    n = len(beam)
    radii = [0.165 * (1 - 0.5 * (i / (n - 1)) ** 1.1) + random.uniform(-0.006, 0.006) for i in range(n)]
    parts = [tube(beam, radii, 10)]

    def tine(at, direction, length, r0):
        i = int(at * (n - 1))
        p0 = Vector(beam[i])
        d = Vector(direction).normalized()
        up = Vector((0, 1, 0))
        mid = p0 + d * length * 0.5 + up * length * 0.15
        end = p0 + d * length + up * length * 0.42
        pts = rough(smooth([p0, mid, end], 6), 0.008)
        m = len(pts)
        parts.append(tube(pts, [r0 * (1 - 0.92 * (k / (m - 1)) ** 0.9) for k in range(m)], 7))

    tine(0.06, (0.05, 0.25, -1.0), 0.82, 0.095)   # brow tine, forward over the face
    tine(0.2, (0.1, 0.4, -1.0), 0.7, 0.085)       # bez
    tine(0.48, (0.25, 0.3, -1.0), 0.66, 0.078)    # trez
    # the crown: three points at the top
    tine(0.86, (0.4, 0.8, 0.5), 0.58, 0.07)
    tine(0.9, (-0.3, 0.9, -0.6), 0.52, 0.066)
    tine(0.96, (0.6, 0.7, -0.4), 0.42, 0.058)
    # the burr: a rough collar at the base
    for k in range(14):
        a = 2 * math.pi * k / 14
        parts.append(ball((math.cos(a) * 0.18, 0.04 + random.uniform(-0.02, 0.02), math.sin(a) * 0.18), 0.06 + random.uniform(0, 0.02), 6))
    bm = merge(parts)
    new_obj("Antler_Right", bm, MAT["antler"])
    markers("Antler")


# ---------------------------------------------------------------------------------------------------------------------
make_spear()
make_boar_spear()
make_knight_sword()
make_king_sword()
make_shield()
make_crown()
make_antler()

# triangle counts
stats = {}
for ob in bpy.data.objects:
    if ob.type == "MESH":
        me = ob.data
        tris = sum(len(p.vertices) - 2 for p in me.polygons)
        stats[ob.name] = tris
print("TRIS", sorted(stats.items(), key=lambda kv: -kv[1])[:12], "total", sum(stats.values()))

# export (markers included)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "arms.glb"), export_format="GLB", export_apply=True,
                          export_materials="EXPORT", export_yup=True)

# ---------------------------------------------------------------------------------------------------------------------
# review renders: everything laid out in a row (copies), lit, two views
# ---------------------------------------------------------------------------------------------------------------------
layout = {"Spear": (0, 0, 0), "BoarSpear": (0, 0, 1.4), "KnightSword": (0, 0, 2.8), "KingSword": (0, 0, 3.9),
          "Shield": (2.0, 1.2, 6.2), "Crown": (5.0, -0.6, 6.0), "Antler": (6.8, -1.4, 6.0)}
for ob in list(bpy.data.objects):
    if ob.type != "MESH":
        continue
    if ob.name.endswith(("_M0", "_MX", "_MY", "_G2", "_B0", "_B1")):
        ob.hide_render = True
        continue
    item = ob.name.split("_")[0]
    off = layout.get(item, (0, 0, 0))
    ob.location = B(off)
    if item == "Shield":
        ob.rotation_euler = (0, 0, 0)
scene = bpy.context.scene
scene.render.engine = "BLENDER_EEVEE"
scene.render.resolution_x, scene.render.resolution_y = 1600, 900
world = bpy.data.worlds.new("w")
scene.world = world
world.use_nodes = True
bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
bg.inputs["Color"].default_value = (0.05, 0.05, 0.06, 1)
bg.inputs["Strength"].default_value = 1.0
for name, loc, energy, color in (("Key", (-4, -8, 9), 2200, (1, 0.93, 0.85)), ("Fill", (9, -6, 4), 900, (0.8, 0.85, 1)),
                                 ("Rim", (3, 10, 6), 1600, (0.85, 0.9, 1))):
    ld = bpy.data.lights.new(name, "AREA")
    ld.energy = energy
    ld.size = 5
    ld.color = color
    lo = bpy.data.objects.new(name, ld)
    lo.location = loc
    scene.collection.objects.link(lo)
    d = Vector((2.5, 0, 1.5)) - Vector(loc)
    lo.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
# a floor
fb = box((2.5, -3.5, 3), (20, 0.1, 20))
floor = new_obj("Floor", fb, material("floor", srgb(40, 40, 42), 0, 0.9))
cam_d = bpy.data.cameras.new("cam")
cam_d.lens = 30
cam = bpy.data.objects.new("cam", cam_d)
scene.collection.objects.link(cam)
scene.camera = cam
for tag, loc, target in (("front", (2.6, 0.3, -9.5), (2.6, 0.2, 3.0)), ("three_quarter", (-4.5, 3.5, -7.0), (2.6, 0.2, 3.2))):
    cam.location = B(loc)
    d = B(target) - B(loc)
    cam.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, f"arms_{tag}.png")
    bpy.ops.render.render(write_still=True)
print("DONE", OUT)
