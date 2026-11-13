"""
Arming sword for The Last Kingdom, built with bpy (run: blender -b --python make_sword.py).
Units: 1 Blender unit = 1 stud. The sword runs along +X from the grip's middle (the kit's own rule, configs/Gear.luau).
Four objects, one material each (Roblox makes one MeshPart per material): Blade, Guard, Grip, Pommel.
"""
import bpy, bmesh, math, os
from mathutils import Vector

OUT = os.environ.get("TLK_OUT", ".")
bpy.ops.wm.read_factory_settings(use_empty=True)
scene = bpy.context.scene


def material(name, rgb, metal, rough):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    b = m.node_tree.nodes["Principled BSDF"]
    b.inputs["Base Color"].default_value = (rgb[0], rgb[1], rgb[2], 1.0)
    b.inputs["Metallic"].default_value = metal
    b.inputs["Roughness"].default_value = rough
    return m


def loft(bm, rings, apex=None, cap_start=True, cap_end=True):
    """Joins rings (lists of Vectors, the same count) with quads; optional point `apex` closes the last ring."""
    verts = [[bm.verts.new(p) for p in ring] for ring in rings]
    n = len(rings[0])
    for r in range(len(verts) - 1):
        for i in range(n):
            j = (i + 1) % n
            bm.faces.new((verts[r][i], verts[r][j], verts[r + 1][j], verts[r + 1][i]))
    if cap_start:
        bm.faces.new(list(reversed(verts[0])))
    if apex is not None:
        a = bm.verts.new(apex)
        last = verts[-1]
        for i in range(n):
            bm.faces.new((last[i], last[(i + 1) % n], a))
    elif cap_end:
        bm.faces.new(verts[-1])


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def finish(name, bm, mat):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    try:
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(38))
    except Exception as e:
        print("SMOOTH_FAILED", e)
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    me.materials.append(mat)
    return ob


# ---------------------------------------------------------------- the blade: a fullered, tapering, pointed lens
def blade():
    bm = bmesh.new()
    x0, x1, tip = 0.46, 3.28, 3.78
    n = 16
    rings = []
    for i in range(n + 1):
        u = i / n
        x = x0 + (x1 - x0) * u
        w = 0.34 - 0.185 * (u ** 1.1)  # half width
        t = 0.082 - 0.034 * u  # half thickness
        depth = smooth(u / 0.07) * (1.0 - smooth((u - 0.66) / 0.2))  # the fuller runs most of the length and fades out
        fw = 0.075 * (1.0 - 0.55 * u)
        gz = t * (1.0 - 0.58 * depth)  # the floor of the groove
        pts = [
            (-w, 0.0),
            (-w * 0.5, t),
            (-fw * 1.55, t),
            (-fw, gz),
            (fw, gz),
            (fw * 1.55, t),
            (w * 0.5, t),
            (w, 0.0),
            (w * 0.5, -t),
            (fw * 1.55, -t),
            (fw, -gz),
            (-fw, -gz),
            (-fw * 1.55, -t),
            (-w * 0.5, -t),
        ]
        rings.append([Vector((x, y, z)) for (y, z) in pts])
    loft(bm, rings, apex=Vector((tip, 0.0, 0.0)))
    return finish("Blade", bm, material("Steel", (0.74, 0.76, 0.80), 1.0, 0.26))


# ---------------------------------------------------------------- the crossguard: a bar that droops to the point, with knobs
def guard():
    bm = bmesh.new()
    half = 0.66
    n = 17
    rings = []
    for i in range(n):
        s = (i / (n - 1)) * 2 - 1  # -1..1 along the bar (Y)
        a = 0.078 - 0.026 * abs(s) ** 1.6 + 0.040 * smooth(1 - abs(s) / 0.22)  # half depth along X; a boss in the middle
        b = 0.072 - 0.026 * abs(s) ** 1.4 + 0.020 * smooth(1 - abs(s) / 0.22)  # half thickness (Z)
        cx = 0.37 + 0.12 * s * s  # the ends sweep forward, toward the point
        y = s * half
        ring = []
        for k in range(8):
            ang = k / 8 * math.tau + math.pi / 8
            ring.append(Vector((cx + math.cos(ang) * a, y, math.sin(ang) * b)))
        rings.append(ring)
    loft(bm, rings)
    # the knobs on the ends
    for sgn in (-1, 1):
        cx = 0.37 + 0.12
        bmesh.ops.create_uvsphere(
            bm, u_segments=10, v_segments=6, radius=0.082, matrix=__import__("mathutils").Matrix.Translation((cx + 0.012, sgn * (half + 0.045), 0.0))
        )
    return finish("Guard", bm, material("DarkSteel", (0.30, 0.31, 0.34), 1.0, 0.42))


# ---------------------------------------------------------------- the grip: leather wound round a core
def grip():
    bm = bmesh.new()
    x_start, x_end = 0.34, -0.72
    n = 19
    rings = []
    for i in range(n):
        v = i / (n - 1)
        x = x_start + (x_end - x_start) * v
        r = 0.066 + 0.014 * math.sin(math.pi * v) + (0.010 if i % 2 == 0 and 0 < i < n - 1 else 0.0)  # the winding
        ring = []
        for k in range(12):
            ang = k / 12 * math.tau
            ring.append(Vector((x, math.cos(ang) * r, math.sin(ang) * r)))
        rings.append(ring)
    loft(bm, rings)
    return finish("Grip", bm, material("Leather", (0.17, 0.095, 0.05), 0.0, 0.88))


# ---------------------------------------------------------------- the pommel: a faceted wheel with a button
def pommel():
    bm = bmesh.new()
    profile = [(-0.70, 0.075), (-0.76, 0.12), (-0.83, 0.165), (-0.90, 0.17), (-0.97, 0.13), (-1.02, 0.07), (-1.06, 0.045), (-1.10, 0.0)]
    rings = []
    for (x, r) in profile[:-1]:
        ring = []
        for k in range(12):
            ang = k / 12 * math.tau
            ring.append(Vector((x, math.cos(ang) * r, math.sin(ang) * r)))
        rings.append(ring)
    loft(bm, rings, apex=Vector((profile[-1][0], 0.0, 0.0)))
    return finish("Pommel", bm, material("Pommel", (0.62, 0.50, 0.24), 1.0, 0.38))


objs = [blade(), guard(), grip(), pommel()]

# ---------------------------------------------------------------- numbers
dg = bpy.context.evaluated_depsgraph_get()
tris = 0
lo = Vector((1e9, 1e9, 1e9))
hi = Vector((-1e9, -1e9, -1e9))
for ob in objs:
    me = ob.evaluated_get(dg).to_mesh()
    me.calc_loop_triangles()
    tris += len(me.loop_triangles)
    for v in me.vertices:
        p = ob.matrix_world @ v.co
        lo = Vector((min(lo.x, p.x), min(lo.y, p.y), min(lo.z, p.z)))
        hi = Vector((max(hi.x, p.x), max(hi.y, p.y), max(hi.z, p.z)))
    print("PART", ob.name, "tris", len(me.loop_triangles))
size = hi - lo
print("TOTAL_TRIS", tris)
print("SIZE_STUDS", round(size.x, 3), round(size.y, 3), round(size.z, 3), "from", [round(c, 3) for c in lo], "to", [round(c, 3) for c in hi])

# ---------------------------------------------------------------- export (GLB, y-up; selection only)
bpy.ops.object.select_all(action="DESELECT")
for ob in objs:
    ob.select_set(True)
glb = os.path.join(OUT, "arming_sword.glb")
bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
print("GLB", glb, os.path.getsize(glb), "bytes")

# ---------------------------------------------------------------- a picture
world = bpy.data.worlds.new("W")
world.use_nodes = True
nt = world.node_tree
bg = nt.nodes["Background"]
sky = nt.nodes.new("ShaderNodeTexSky")
sky.sky_type = "MULTIPLE_SCATTERING"
sky.sun_disc = False
sky.sun_elevation = math.radians(35)
sky.sun_rotation = math.radians(210)
nt.links.new(sky.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 0.55
scene.world = world


def light(name, loc, energy, rgb, size=3.0):
    d = bpy.data.lights.new(name, "AREA")
    d.energy = energy
    d.size = size
    d.color = rgb
    o = bpy.data.objects.new(name, d)
    o.location = loc
    scene.collection.objects.link(o)
    direction = Vector((1.5, 0, 0)) - Vector(loc)
    o.rotation_euler = direction.to_track_quat("-Z", "Y").to_euler()


light("Key", (1.2, -4.0, 3.2), 520, (1.0, 0.92, 0.80), 3.5)
light("Rim", (4.5, 3.0, 2.0), 380, (0.55, 0.70, 1.0), 3.0)
light("Fill", (-1.5, -3.0, -1.0), 90, (1.0, 1.0, 1.0), 4.0)


def shot(name, cam_loc, look_at, lens=60):
    cd = bpy.data.cameras.new("Cam")
    cd.lens = lens
    co = bpy.data.objects.new("Cam", cd)
    co.location = cam_loc
    scene.collection.objects.link(co)
    co.rotation_euler = (Vector(look_at) - Vector(cam_loc)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = co
    scene.render.resolution_x, scene.render.resolution_y = 1500, 620
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)
    print("RENDER", scene.render.engine, scene.render.filepath)
    bpy.data.objects.remove(co)


shot("sword_side.png", (1.35, -9.6, 0.4), (1.35, 0, 0), 50)
shot("sword_three_quarter.png", (4.6, -7.4, 3.4), (1.35, 0, 0), 50)
