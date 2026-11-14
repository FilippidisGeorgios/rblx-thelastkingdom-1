"""
meshlib.py - small mesh builders shared by the Blender scripts of The Last Kingdom (Blender 5.x).

Coordinates are written in ROBLOX axes (x right, y up, z toward the viewer: -Z is a body's front) and turned into
Blender's with B(x, y, z) = (x, -z, y), which glTF turns back. One unit is one stud.
"""
import bpy, bmesh, math
from mathutils import Vector, Matrix


def B(v):
    return Vector((v[0], -v[2], v[1]))


def R(v):
    """Blender -> Roblox axes."""
    return Vector((v[0], v[2], -v[1]))


def srgb(r, g, b):
    def c(x):
        x = x / 255
        return x / 12.92 if x <= 0.04045 else ((x + 0.055) / 1.055) ** 2.4
    return (c(r), c(g), c(b))


def material(name, rgb, metal=0.0, rough=0.6):
    m = bpy.data.materials.get(name) or bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1)
    bsdf.inputs["Metallic"].default_value = metal
    bsdf.inputs["Roughness"].default_value = rough
    m.diffuse_color = (rgb[0], rgb[1], rgb[2], 1)
    return m


def new_obj(name, bm, mat=None, smooth=True):
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    ob = bpy.data.objects.new(name, me)
    bpy.context.scene.collection.objects.link(ob)
    if mat:
        ob.data.materials.append(mat)
    for p in ob.data.polygons:
        p.use_smooth = smooth
    return ob


def merge(bms):
    out = bmesh.new()
    for bm in bms:
        me = bpy.data.meshes.new("tmp")
        bm.to_mesh(me)
        out.from_mesh(me)
        bpy.data.meshes.remove(me)
        bm.free()
    return out


def transform(bm, fn):
    """Applies fn (Roblox-axis Vector -> Roblox-axis Vector) to every vertex."""
    for v in bm.verts:
        v.co = B(fn(R(v.co)))
    return bm


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


def grid_surface(fn, nu, nv, closed_u=False, cap=False):
    """A surface from fn(u, v) -> Roblox point, u,v in 0..1, nu x nv quads. closed_u wraps u."""
    bm = bmesh.new()
    cols = nu if closed_u else nu + 1
    rows = []
    for j in range(nv + 1):
        row = [bm.verts.new(B(fn(i / nu, j / nv))) for i in range(cols)]
        rows.append(row)
    for j in range(nv):
        for i in range(nu):
            a = rows[j][i]
            b = rows[j][(i + 1) % cols] if closed_u else rows[j][i + 1]
            c = rows[j + 1][(i + 1) % cols] if closed_u else rows[j + 1][i + 1]
            d = rows[j + 1][i]
            bm.faces.new((a, b, c, d))
    if cap and closed_u:
        bm.faces.new(list(reversed(rows[0])))
        bm.faces.new(rows[-1])
    bmesh.ops.remove_doubles(bm, verts=bm.verts, dist=1e-6)
    if cap and closed_u:
        # a closed solid: every face outward (Roblox draws only the front of a face)
        bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def thicken(bm, t):
    """Gives a single-sided surface a thickness along its normals (a plate)."""
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    geom = bm.faces[:]
    res = bmesh.ops.extrude_face_region(bm, geom=geom)
    newv = [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]
    bm.normal_update()
    for v in newv:
        v.co -= v.normal * t
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def tube(points, radii, seg=8, cap=True):
    """A tube through Roblox-axis points with a radius at each (parallel-transport frames)."""
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
        ring = []
        for k in range(seg):
            a = 2 * math.pi * k / seg
            ring.append(bm.verts.new(B(p + u * math.cos(a) * radii[i] + v * math.sin(a) * radii[i])))
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


def arc_shell_x(x0, x1, r0, r1, a0, a1, t, nu=16, nv=4, flare=0.0):
    """A plate wrapped round the X axis (a limb's long axis): from x0 to x1, radius r0 -> r1, from angle a0 to a1
    (radians, 0 = -Z, the front; positive toward +Y... measured in the YZ plane as (y, z) = (sin a, -cos a)), thickness
    t (inward). `flare` widens the ends a little (a rolled rim look)."""
    def f(u, v):
        x = x0 + (x1 - x0) * v
        r = r0 + (r1 - r0) * v + flare * (math.exp(-((v - 0) / 0.12) ** 2) + math.exp(-((v - 1) / 0.12) ** 2))
        a = a0 + (a1 - a0) * u
        return Vector((x, r * math.sin(a), -r * math.cos(a)))
    return thicken(grid_surface(f, nu, nv), t)


def lathe_y(profile, seg=20, scale_z=1.0, center=(0, 0, 0)):
    """Revolves (y, r) points about the Y axis; closed at an end whose r is 0."""
    def f(u, v):
        i = v * (len(profile) - 1)
        k = min(int(i), len(profile) - 2)
        fr = i - k
        y = profile[k][0] * (1 - fr) + profile[k + 1][0] * fr
        r = profile[k][1] * (1 - fr) + profile[k + 1][1] * fr
        a = 2 * math.pi * u
        return Vector((center[0] + r * math.sin(a), center[1] + y, center[2] - r * math.cos(a) * scale_z))
    bm = grid_surface(f, seg, (len(profile) - 1) * 2, closed_u=True, cap=True)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return bm


def markers(name, mat, origin=(0, 0, 0)):
    o = Vector(origin)
    for suffix, off in (("M0", (0, 0, 0)), ("MX", (1, 0, 0)), ("MY", (0, 1, 0))):
        point(f"{name}_{suffix}", o + Vector(off), mat)


def point(name, at, mat):
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=3, radius1=0.03, radius2=0.0, depth=0.04)
    for v in bm.verts:
        v.co = B((v.co.x + at[0], v.co.z + at[1], v.co.y + at[2]))
    new_obj(name, bm, mat)
