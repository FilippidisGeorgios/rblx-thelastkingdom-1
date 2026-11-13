"""
Arming sword (version 2) for The Last Kingdom, built with bpy (run: blender -b --python make_sword.py).
Units: 1 Blender unit = 1 stud. The sword runs along +X from the grip's middle (the kit's own rule, configs/Gear.luau).
Four objects, one material each (Roblox makes one MeshPart per material): Blade, Guard, Grip, Brass (pommel + ferrules).
Since version 1: a lens-section blade with a ricasso, a fuller that dies out before the point and thin edge bevels; a guard
with spatulate ends and a central boss; a helical leather wrap with ferrules; a wheel pommel with a peen.
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


def smooth(t):
    t = max(0.0, min(1.0, t))
    return t * t * (3 - 2 * t)


def loft(bm, rings, apex=None, cap_start=True, cap_end=True):
    """Rings (lists of Vectors, equal count) joined by quads; `apex` closes the last ring to a point."""
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


def revolve_rings(profile, segs):
    rings = []
    for (x, r) in profile:
        rings.append([Vector((x, math.cos(k / segs * math.tau) * r, math.sin(k / segs * math.tau) * r)) for k in range(segs)])
    return rings


def add_object(name, bm, mat, sharp_deg=38):
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces[:])
    me = bpy.data.meshes.new(name)
    bm.to_mesh(me)
    bm.free()
    try:
        me.shade_smooth()
        me.set_sharp_from_angle(angle=math.radians(sharp_deg))
    except Exception as e:
        print("SMOOTH_FAILED", e)
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    me.materials.append(mat)
    return ob


# ------------------------------------------------------------------ blade
OUTER = [-1.0, -0.94, -0.84, -0.70, -0.52]  # across the top face, in units of the half width
INNER = [-1.0, -0.667, -0.333, 0.0, 0.333, 0.667, 1.0]  # across the fuller, in units of its half width


def blade():
    bm = bmesh.new()
    x0, x1, tip = 0.46, 3.82, 3.94
    stations = 36
    rings = []
    for i in range(stations + 1):
        u = i / stations
        x = x0 + (x1 - x0) * u
        w = 0.345 * (1.0 - 0.40 * (u ** 1.25))  # half width: a gentle taper
        closing = max(0.04, 1.0 - max(0.0, (u - 0.78) / 0.22) ** 1.35)  # the point closes in on a curve, with no kink
        w *= closing
        t = (0.088 - 0.040 * u) * (0.2 + 0.8 * closing)  # half thickness: thick at the guard, thin at the point
        # the fuller: a plain ricasso first, then a groove for two thirds of the blade that dies out before the point
        depth = smooth((u - 0.07) / 0.06) * (1.0 - smooth((u - 0.62) / 0.14))
        fh = min(0.092 * (1.0 - 0.45 * u), 0.45 * w)  # the fuller's half width
        groove = depth * t * 0.78
        ys = [o * w for o in OUTER] + [k * fh for k in INNER] + [-o * w for o in reversed(OUTER)]
        top = []
        for y in ys:
            ay = abs(y)
            if ay >= w * 0.999:
                top.append((y, 0.0))  # the edge itself
                continue
            lens = (1.0 - (ay / w) ** 1.9) ** 0.85  # a lens section: thickest in the middle, thin at the edge
            g = groove * 0.5 * (1.0 + math.cos(math.pi * ay / fh)) if ay < fh else 0.0
            top.append((y, max(t * lens - g, 0.004)))
        up = [Vector((x, y, z)) for (y, z) in top]
        down = [Vector((x, y, -z)) for (y, z) in reversed(top[1:-1])]
        rings.append(up + down)
    loft(bm, rings, apex=Vector((tip, 0.0, 0.0)))
    return add_object("Blade", bm, material("Steel", (0.80, 0.83, 0.88), 0.92, 0.30), 30)


# ------------------------------------------------------------------ guard
def guard():
    bm = bmesh.new()
    half = 0.70
    n = 25
    rings = []
    caps = [0.80, 0.55, 0.28]  # the ends close in a dome, not a flat cut

    def ring_at(s, shrink=1.0, y_extra=0.0):
        a_s = abs(s)
        boss = smooth(1 - a_s / 0.20)  # a swelling in the middle, round the blade
        end = smooth((a_s - 0.70) / 0.30)  # the ends flare into a spatulate terminal
        a = (0.070 + 0.042 * boss + 0.012 * end) * shrink  # half depth along x
        b = (0.062 + 0.030 * boss - 0.020 * a_s + 0.034 * end) * shrink  # half height (z)
        cx = 0.372 + 0.115 * s * s  # the arms sweep forward, toward the point
        y = s * half + math.copysign(y_extra, s)
        ring = []
        for k in range(12):
            ang = k / 12 * math.tau + math.pi / 12
            ring.append(Vector((cx + math.cos(ang) * a, y, math.sin(ang) * b)))
        return ring

    for i in range(n):
        s = (i / (n - 1)) * 2 - 1
        rings.append(ring_at(s))
    # dome the two ends: more rings that shrink, past the last one
    for sgn in (1, -1):
        extra = []
        for j, f in enumerate(caps):
            extra.append(ring_at(sgn * 1.0, f, 0.020 * (j + 1)))
        if sgn == 1:
            rings = rings + extra
        else:
            rings = list(reversed(extra)) + rings
    loft(bm, rings)
    return add_object("Guard", bm, material("Iron", (0.38, 0.39, 0.43), 1.0, 0.45), 40)


# ------------------------------------------------------------------ grip: a spiral of leather
def grip():
    bm = bmesh.new()
    x_start, x_end = 0.30, -0.70
    n = 56
    segs = 20
    pitch = 0.15  # one turn of the cord every 0.15 stud
    rings = []
    for i in range(n):
        v = i / (n - 1)
        x = x_start + (x_end - x_start) * v
        swell = 0.010 * math.sin(math.pi * v)
        ring = []
        for k in range(segs):
            ang = k / segs * math.tau
            phase = ang - (x - x_start) / pitch * math.tau  # the ridge's phase moves with x: a cord winding round the grip
            ridge = max(0.0, math.cos(phase)) ** 1.4  # a rounded cord and a groove beside it
            r = 0.056 + swell + 0.020 * ridge
            ring.append(Vector((x, math.cos(ang) * r, math.sin(ang) * r)))
        rings.append(ring)
    loft(bm, rings)
    return add_object("Grip", bm, material("Leather", (0.10, 0.052, 0.028), 0.0, 0.88), 75)


# ------------------------------------------------------------------ brass: two ferrules and the wheel pommel with its peen
def brass():
    bm = bmesh.new()
    segs = 20
    loft(bm, revolve_rings([(0.315, 0.070), (0.295, 0.100), (0.262, 0.102), (0.240, 0.082), (0.230, 0.078)], segs))
    loft(bm, revolve_rings([(-0.640, 0.074), (-0.655, 0.098), (-0.685, 0.100), (-0.705, 0.080)], segs))
    profile = [
        (-0.700, 0.078), (-0.735, 0.105), (-0.770, 0.142), (-0.790, 0.190), (-0.805, 0.212),
        (-0.870, 0.218), (-0.935, 0.212), (-0.955, 0.190), (-0.985, 0.150), (-1.015, 0.105), (-1.040, 0.062),
        (-1.050, 0.050), (-1.085, 0.050), (-1.105, 0.034),
    ]
    loft(bm, revolve_rings(profile, segs), apex=Vector((-1.118, 0.0, 0.0)))
    return add_object("Brass", bm, material("Brass", (0.72, 0.53, 0.20), 1.0, 0.34), 45)


objs = [blade(), guard(), grip(), brass()]

# ------------------------------------------------------------------ numbers
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
print("SIZE_STUDS", round(size.x, 3), round(size.y, 3), round(size.z, 3))

# ------------------------------------------------------------------ export
bpy.ops.object.select_all(action="DESELECT")
for ob in objs:
    ob.select_set(True)
glb = os.path.join(OUT, "arming_sword.glb")
bpy.ops.export_scene.gltf(filepath=glb, export_format="GLB", use_selection=True, export_apply=True, export_yup=True)
print("GLB", glb, os.path.getsize(glb), "bytes")

# ------------------------------------------------------------------ pictures: a dark set with soft boxes, metal needs something to reflect
world = bpy.data.worlds.new("W")
world.use_nodes = True
nt = world.node_tree
bg = nt.nodes["Background"]
coord = nt.nodes.new("ShaderNodeTexCoord")
mapn = nt.nodes.new("ShaderNodeMapping")
gradient = nt.nodes.new("ShaderNodeTexGradient")
ramp = nt.nodes.new("ShaderNodeValToRGB")
mapn.inputs["Rotation"].default_value = (0, math.radians(-90), 0)  # the gradient runs up and down, not left to right
ramp.color_ramp.elements[0].position = 0.38
ramp.color_ramp.elements[0].color = (0.020, 0.020, 0.026, 1)
ramp.color_ramp.elements[1].position = 0.66
ramp.color_ramp.elements[1].color = (0.62, 0.68, 0.80, 1)
nt.links.new(coord.outputs["Generated"], mapn.inputs["Vector"])
nt.links.new(mapn.outputs["Vector"], gradient.inputs["Vector"])
nt.links.new(gradient.outputs["Fac"], ramp.inputs["Fac"])
nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
bg.inputs["Strength"].default_value = 0.9
scene.world = world


def area(name, loc, target, energy, rgb, sx, sy):
    d = bpy.data.lights.new(name, "AREA")
    d.energy = energy
    d.shape = "RECTANGLE"
    d.size, d.size_y = sx, sy
    d.color = rgb
    o = bpy.data.objects.new(name, d)
    o.location = loc
    scene.collection.objects.link(o)
    o.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("-Z", "Y").to_euler()


T = (1.3, 0, 0)
area("StripTop", (1.4, -2.2, 4.2), T, 700, (0.96, 0.97, 1.0), 6.0, 0.9)
area("StripSide", (-2.0, -3.4, 0.5), T, 320, (0.85, 0.92, 1.0), 0.8, 6.0)
area("Rim", (4.8, 3.2, 1.8), T, 520, (1.0, 0.75, 0.45), 2.5, 2.5)
area("Under", (1.2, -2.0, -3.2), T, 120, (0.9, 0.95, 1.0), 6.0, 1.0)


def softbox(name, loc, target, w, h, strength, rgb):
    """A glowing panel out of frame: what the steel reflects (metal shows only what is round it)."""
    me = bpy.data.meshes.new(name)
    me.from_pydata([(-w / 2, -h / 2, 0), (w / 2, -h / 2, 0), (w / 2, h / 2, 0), (-w / 2, h / 2, 0)], [], [(0, 1, 2, 3)])
    ob = bpy.data.objects.new(name, me)
    scene.collection.objects.link(ob)
    ob.location = loc
    ob.rotation_euler = (Vector(target) - Vector(loc)).to_track_quat("Z", "Y").to_euler()
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nodes = m.node_tree.nodes
    nodes.clear()
    em = nodes.new("ShaderNodeEmission")
    em.inputs["Color"].default_value = (rgb[0], rgb[1], rgb[2], 1)
    em.inputs["Strength"].default_value = strength
    out = nodes.new("ShaderNodeOutputMaterial")
    m.node_tree.links.new(em.outputs["Emission"], out.inputs["Surface"])
    me.materials.append(m)
    try:
        ob.visible_camera = False
    except Exception:
        pass


softbox("BoxTop", (1.3, -1.0, 6.5), T, 9.0, 3.0, 6.0, (1.0, 0.96, 0.90))
softbox("BoxFront", (1.3, -7.5, 1.0), T, 8.0, 1.6, 3.5, (0.80, 0.88, 1.0))
softbox("BoxBack", (1.3, 6.0, 2.5), T, 8.0, 2.0, 5.0, (1.0, 0.82, 0.60))


def shot(name, cam_loc, look_at, lens, res=(1500, 700)):
    cd = bpy.data.cameras.new("Cam")
    cd.lens = lens
    co = bpy.data.objects.new("Cam", cd)
    co.location = cam_loc
    scene.collection.objects.link(co)
    co.rotation_euler = (Vector(look_at) - Vector(cam_loc)).to_track_quat("-Z", "Y").to_euler()
    scene.camera = co
    scene.render.resolution_x, scene.render.resolution_y = res
    for engine in ("BLENDER_EEVEE", "BLENDER_EEVEE_NEXT", "BLENDER_WORKBENCH"):
        try:
            scene.render.engine = engine
            break
        except TypeError:
            continue
    scene.render.filepath = os.path.join(OUT, name)
    bpy.ops.render.render(write_still=True)
    print("RENDER", name)
    bpy.data.objects.remove(co)


shot("sword_hero.png", (4.6, -7.2, 3.0), (1.3, 0, 0), 48)
shot("sword_hilt.png", (-0.2, -3.0, 1.6), (0.0, 0, 0), 52, (1500, 800))
shot("sword_point.png", (2.6, -2.9, 1.0), (2.9, 0, 0), 55, (1500, 800))
shot("sword_flat.png", (1.35, -9.8, 0.2), (1.35, 0, 0), 50, (1500, 520))
