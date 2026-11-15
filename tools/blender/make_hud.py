"""
make_hud.py - the pictures of the HUD and the pack (Blender 5.x, headless).

  blender -b --factory-startup --python-exit-code 1 -P tools/blender/make_hud.py -- <out_dir> [only]

The developer, 2026-11-14: "a much better, realistic UI: it looks fake now; a better pack, darker, not for little
children". So the plates and pictures are MODELLED and rendered, not drawn from flat frames:

  hud_plate.png   128 x 128  a blackened iron plate, bevelled, a rivet in each corner, pitted. Shown 9-sliced
                             (SliceCenter 24..104) under every edge button and weapon place.
  hud_panel.png   512 x 512  the pack's page: dark oiled leather, a raised welt, stitching, an iron bracket at each
                             corner. Shown 9-sliced (SliceCenter 96..416).
  pic_pack.png    512 x 512  a soldier's pack: leather body, flap, two straps with iron buckles, a bedroll on top.
  pic_helm.png    512 x 512  a great helm: eye slits with a cold light behind them, a cross of bands, rivets.
  pic_cog.png     512 x 512  an iron cog (Settings): ten teeth, a boss, holes.
  pic_coin.png    512 x 512  a worn gold penny with a long cross and pellets.

Every picture is lit as the weapon pictures are (tools/blender/make_icons.py): a cold key from above left, a hard rim
from behind, a faint warm fill from below (fire). Coordinates in Roblox axes (x right, y up, z toward the viewer).
"""
import bpy, bmesh, sys, os, math, random
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from meshlib import *  # noqa
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else os.path.join(os.getcwd(), "hud_out"))
ONLY = argv[1].split(",") if len(argv) > 1 else None
os.makedirs(OUT, exist_ok=True)
random.seed(7)


# ------------------------------------------------------------------------------------------------------------------
# Materials: procedural, so the surfaces are not flat colour
# ------------------------------------------------------------------------------------------------------------------
def rich(name, c1, c2, metal, rough0, rough1, scale=6.0, bump=0.25, grain=40.0, grain_bump=0.15, emission=None):
    """Base colour blended c1 -> c2 by a noise, roughness rough0 -> rough1 by another, a bump from both a broad
    noise and a fine grain (pits in iron, pores in leather)."""
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    nt = m.node_tree
    bsdf = next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED")
    tc = nt.nodes.new("ShaderNodeTexCoord")
    n1 = nt.nodes.new("ShaderNodeTexNoise")
    n1.inputs["Scale"].default_value = scale
    n1.inputs["Detail"].default_value = 8
    nt.links.new(tc.outputs["Object"], n1.inputs["Vector"])
    ramp = nt.nodes.new("ShaderNodeValToRGB")
    ramp.color_ramp.elements[0].position = 0.35
    ramp.color_ramp.elements[0].color = (c1[0], c1[1], c1[2], 1)
    ramp.color_ramp.elements[1].position = 0.7
    ramp.color_ramp.elements[1].color = (c2[0], c2[1], c2[2], 1)
    nt.links.new(n1.outputs["Fac"], ramp.inputs["Fac"])
    nt.links.new(ramp.outputs["Color"], bsdf.inputs["Base Color"])
    n2 = nt.nodes.new("ShaderNodeTexNoise")
    n2.inputs["Scale"].default_value = scale * 2.3
    n2.inputs["Detail"].default_value = 4
    nt.links.new(tc.outputs["Object"], n2.inputs["Vector"])
    mr = nt.nodes.new("ShaderNodeMapRange")
    mr.inputs["To Min"].default_value = rough0
    mr.inputs["To Max"].default_value = rough1
    nt.links.new(n2.outputs["Fac"], mr.inputs["Value"])
    nt.links.new(mr.outputs["Result"], bsdf.inputs["Roughness"])
    bsdf.inputs["Metallic"].default_value = metal
    vor = nt.nodes.new("ShaderNodeTexVoronoi")
    vor.inputs["Scale"].default_value = grain
    nt.links.new(tc.outputs["Object"], vor.inputs["Vector"])
    b1 = nt.nodes.new("ShaderNodeBump")
    b1.inputs["Strength"].default_value = grain_bump
    b1.inputs["Distance"].default_value = 0.02
    nt.links.new(vor.outputs["Distance"], b1.inputs["Height"])
    b2 = nt.nodes.new("ShaderNodeBump")
    b2.inputs["Strength"].default_value = bump
    b2.inputs["Distance"].default_value = 0.05
    nt.links.new(n1.outputs["Fac"], b2.inputs["Height"])
    nt.links.new(b1.outputs["Normal"], b2.inputs["Normal"])
    nt.links.new(b2.outputs["Normal"], bsdf.inputs["Normal"])
    if emission:
        bsdf.inputs["Emission Color"].default_value = (emission[0], emission[1], emission[2], 1)
        bsdf.inputs["Emission Strength"].default_value = emission[3]
    m.diffuse_color = (c1[0], c1[1], c1[2], 1)
    return m


def glow(name, rgb, strength):
    m = bpy.data.materials.new(name)
    m.use_nodes = True
    bsdf = next(n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
    bsdf.inputs["Base Color"].default_value = (0, 0, 0, 1)
    bsdf.inputs["Emission Color"].default_value = (rgb[0], rgb[1], rgb[2], 1)
    bsdf.inputs["Emission Strength"].default_value = strength
    return m


def clear():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    for coll in (bpy.data.materials, bpy.data.meshes, bpy.data.lights, bpy.data.cameras, bpy.data.worlds):
        for x in list(coll):
            coll.remove(x)


def mod(ob, kind, **kw):
    m = ob.modifiers.new(kind.lower(), kind)
    for k, v in kw.items():
        setattr(m, k, v)
    return m


def apply_all(ob):
    bpy.context.view_layer.objects.active = ob
    for m in list(ob.modifiers):
        bpy.ops.object.modifier_apply(modifier=m.name)


def cut(ob, cutter_bm, name="cutter"):
    """Boolean difference with a cutter made from a bmesh; the cutter is removed."""
    c = new_obj(name, cutter_bm, None, smooth=False)
    c.hide_render = True
    b = mod(ob, "BOOLEAN", operation="DIFFERENCE", object=c, solver="EXACT")
    apply_all(ob)
    bpy.data.objects.remove(c, do_unlink=True)
    return b


def cylinder_z(c, r, depth, seg=24):
    """A cylinder whose axis is Roblox Z (toward the viewer)."""
    bm = bmesh.new()
    bmesh.ops.create_cone(bm, cap_ends=True, segments=seg, radius1=r, radius2=r, depth=depth)
    # create_cone builds along Blender Z = Roblox Y; turn it to Roblox Z (Blender -Y)
    bmesh.ops.rotate(bm, verts=bm.verts, cent=(0, 0, 0), matrix=Matrix.Rotation(math.radians(90), 3, "X"))
    bmesh.ops.translate(bm, verts=bm.verts, vec=B(c))
    return bm


def rivet(c, r, squash=0.55):
    return ball(c, r, 12, (1, 1, squash))


# ------------------------------------------------------------------------------------------------------------------
# Rendering
# ------------------------------------------------------------------------------------------------------------------
def render(name, res, rot=(0, 0, 0), frame=None, margin=1.1, lights="icon", look="Medium High Contrast"):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = res
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = look
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.02, 0.02, 0.025, 1)
    bg.inputs["Strength"].default_value = 0.5
    if lights == "icon":
        # a studio sky for metal to reflect (dark below, a soft cold light above): without it steel and gold
        # render black (film_transparent hides it; only the reflections show)
        nt = world.node_tree
        tc = nt.nodes.new("ShaderNodeTexCoord")
        sep = nt.nodes.new("ShaderNodeSeparateXYZ")
        nt.links.new(tc.outputs["Generated"], sep.inputs["Vector"])
        mr = nt.nodes.new("ShaderNodeMapRange")
        mr.inputs["From Min"].default_value = -1
        mr.inputs["From Max"].default_value = 1
        nt.links.new(sep.outputs["Z"], mr.inputs["Value"])
        ramp = nt.nodes.new("ShaderNodeValToRGB")
        ramp.color_ramp.elements[0].position = 0.45
        ramp.color_ramp.elements[0].color = (0.006, 0.006, 0.007, 1)
        ramp.color_ramp.elements[1].position = 0.75
        ramp.color_ramp.elements[1].color = (0.22, 0.24, 0.28, 1)
        nt.links.new(mr.outputs["Result"], ramp.inputs["Fac"])
        nt.links.new(ramp.outputs["Color"], bg.inputs["Color"])
        bg.inputs["Strength"].default_value = 1.0
    root = bpy.data.objects.new("root", None)
    scene.collection.objects.link(root)
    for ob in bpy.data.objects:
        if ob.type == "MESH" and ob.parent is None:
            ob.parent = root
    # rot is (tilt about Roblox X, turn about Roblox Y) in degrees
    root.rotation_euler = (math.radians(rot[0]), 0, math.radians(rot[1]))
    bpy.context.view_layer.update()
    if frame:
        centre, size = Vector(frame[0]), frame[1]
    else:
        pts = []
        for ob in bpy.data.objects:
            if ob.type == "MESH" and not ob.hide_render:
                pts += [ob.matrix_world @ Vector(c) for c in ob.bound_box]
        lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
        hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
        centre = (lo + hi) / 2
        size = max(hi.x - lo.x, hi.z - lo.z) * margin
    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = size
    cam = bpy.data.objects.new("cam", cam_d)
    scene.collection.objects.link(cam)
    cam.location = centre + Vector((0, -30, 0))
    cam.rotation_euler = (math.radians(90), 0, 0)
    cam_d.clip_end = 100
    scene.camera = cam
    if lights == "icon":
        rig = (("Key", (-6, -8, 7), 1700, (0.86, 0.9, 1.0), 3),
               ("Rim", (6, 10, 4), 2400, (0.75, 0.82, 1.0), 2),
               ("Fire", (3, -6, -6), 420, (1.0, 0.55, 0.25), 4))
    else:  # a flat thing seen from the front: a broad soft key from the upper left, a weak fill
        rig = (("Key", (-5, -9, 6), 1500, (0.95, 0.95, 1.0), 6),
               ("Fill", (6, -8, -4), 260, (1.0, 0.8, 0.6), 8))
    for lname, loc, energy, color, size_ in rig:
        ld = bpy.data.lights.new(lname, "AREA")
        ld.energy = energy
        ld.color = color
        ld.size = size_
        lo_ = bpy.data.objects.new(lname, ld)
        lo_.location = centre + Vector(loc)
        scene.collection.objects.link(lo_)
        d = centre - lo_.location
        lo_.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, name + ".png")
    bpy.ops.render.render(write_still=True)
    print("WROTE", scene.render.filepath)


# ------------------------------------------------------------------------------------------------------------------
# The iron plate (9-slice)
# ------------------------------------------------------------------------------------------------------------------
def plate():
    clear()
    iron = rich("iron", srgb(20, 19, 19), srgb(40, 37, 35), 0.85, 0.42, 0.78, scale=5, bump=0.18, grain=55, grain_bump=0.22)
    head = rich("rivet", srgb(52, 49, 46), srgb(78, 74, 70), 1.0, 0.3, 0.5, scale=9, bump=0.1, grain=80, grain_bump=0.1)
    p = new_obj("plate", box((0, 0, 0), (1.96, 1.96, 0.16)), iron, smooth=False)
    mod(p, "BEVEL", width=0.075, segments=4, limit_method="ANGLE")
    mod(p, "WEIGHTED_NORMAL")
    # a shallow hammered dish in the middle: a few dents
    bm = merge([rivet((sx * 0.8, sy * 0.8, 0.08), 0.075) for sx in (-1, 1) for sy in (-1, 1)])
    new_obj("rivets", bm, head)
    # two faint scratches
    for (x0, y0, x1, y1) in ((-0.5, 0.25, 0.35, -0.1), (0.1, -0.45, 0.6, -0.3)):
        d = Vector((x1 - x0, y1 - y0, 0))
        a = math.atan2(d.y, d.x)
        s = new_obj("scratch", box(((x0 + x1) / 2, (y0 + y1) / 2, 0.081), (d.length, 0.012, 0.002),
                                   Matrix.Rotation(a, 3, "Z")), rich("scr", srgb(70, 66, 62), srgb(90, 86, 80), 1, 0.3, 0.4), smooth=False)
    render("hud_plate", 128, frame=((0, 0, 0), 2.0), lights="flat", look="None")


# ------------------------------------------------------------------------------------------------------------------
# The pack's page (9-slice)
# ------------------------------------------------------------------------------------------------------------------
def panel():
    clear()
    leather = rich("leather", srgb(24, 15, 10), srgb(44, 29, 19), 0.0, 0.55, 0.85, scale=3.5, bump=0.12, grain=90, grain_bump=0.28)
    welt = rich("welt", srgb(14, 10, 8), srgb(26, 18, 13), 0.0, 0.5, 0.7, scale=6, bump=0.1, grain=90, grain_bump=0.2)
    thread = rich("thread", srgb(96, 78, 58), srgb(122, 100, 74), 0.0, 0.7, 0.9, scale=20, bump=0.05)
    iron = rich("iron", srgb(22, 21, 20), srgb(44, 41, 38), 0.9, 0.38, 0.7, scale=5, bump=0.2, grain=60, grain_bump=0.25)
    head = rich("rivet", srgb(60, 56, 52), srgb(88, 82, 76), 1.0, 0.3, 0.45, scale=9)
    H = 2.0
    new_obj("page", box((0, 0, 0), (4.0, 4.0, 0.1)), leather, smooth=False)
    # the raised welt round the edge
    e = 0.07
    welts = [box((0, s * (H - e), 0.06), (4.0, 0.1, 0.05)) for s in (-1, 1)] + [box((s * (H - e), 0, 0.06), (0.1, 4.0, 0.05)) for s in (-1, 1)]
    w = new_obj("welt", merge(welts), welt, smooth=False)
    mod(w, "BEVEL", width=0.02, segments=2)
    # stitching a little inside it
    st = []
    inset, step, dash = 0.2, 0.1, 0.055
    n = int((2 * (H - inset)) / step)
    for i in range(n + 1):
        t = -(H - inset) + i * step
        for (cx, cy, horiz) in ((t, H - inset, True), (t, -(H - inset), True), (H - inset, t, False), (-(H - inset), t, False)):
            st.append(box((cx, cy, 0.055), (dash, 0.018, 0.012) if horiz else (0.018, dash, 0.012)))
    new_obj("stitches", merge(st), thread, smooth=False)
    # an iron bracket at each corner: an L of two bevelled straps, three rivets
    br, rv = [], []
    arm, wid = 0.7, 0.16
    for sx in (-1, 1):
        for sy in (-1, 1):
            cx, cy = sx * (H - 0.12), sy * (H - 0.12)
            br.append(box((cx - sx * (arm / 2 - wid / 2), cy, 0.09), (arm, wid, 0.05)))
            br.append(box((cx, cy - sy * (arm / 2 - wid / 2), 0.09), (wid, arm, 0.05)))
            for (dx, dy) in ((0, 0), (-sx * (arm - 0.1), 0), (0, -sy * (arm - 0.1))):
                rv.append(rivet((cx + dx, cy + dy, 0.12), 0.035))
    b = new_obj("brackets", merge(br), iron, smooth=False)
    mod(b, "BEVEL", width=0.018, segments=2)
    new_obj("rivets", merge(rv), head)
    render("hud_panel", 512, frame=((0, 0, 0), 4.0), lights="flat", look="None")


# ------------------------------------------------------------------------------------------------------------------
# Pictures
# ------------------------------------------------------------------------------------------------------------------
def pack():
    clear()
    leather = rich("leather", srgb(46, 29, 18), srgb(74, 48, 30), 0.0, 0.5, 0.8, scale=4, bump=0.2, grain=70, grain_bump=0.3)
    flapm = rich("flap", srgb(38, 24, 15), srgb(62, 40, 25), 0.0, 0.45, 0.75, scale=4, bump=0.2, grain=70, grain_bump=0.3)
    strap = rich("strap", srgb(30, 19, 12), srgb(48, 31, 20), 0.0, 0.5, 0.75, scale=8, bump=0.15, grain=90, grain_bump=0.25)
    iron = rich("iron", srgb(40, 38, 36), srgb(80, 76, 72), 1.0, 0.3, 0.55, scale=10, bump=0.1)
    wool = rich("wool", srgb(42, 38, 34), srgb(64, 58, 50), 0.0, 0.85, 1.0, scale=14, bump=0.35, grain=120, grain_bump=0.4)
    thread = rich("thread", srgb(120, 98, 70), srgb(150, 124, 90), 0.0, 0.7, 0.9, scale=20)
    # the body: a soft box
    body = new_obj("body", box((0, -0.1, 0), (2.0, 2.1, 0.95)), leather)
    mod(body, "BEVEL", width=0.28, segments=3)
    mod(body, "SUBSURF", levels=2, render_levels=2)
    # the flap over the top and down the front, its lower edge rounded
    def flap(u, v):
        x = -1.06 + 2.12 * u
        # path: back top -> over -> down the front
        if v < 0.3:
            a = v / 0.3 * (math.pi / 2)
            z = -0.05 + 0.55 * math.sin(a)
            y = 0.95 + 0.06 * math.cos(a)
        else:
            k = (v - 0.3) / 0.7
            bottom = 0.05 - 0.28 * math.cos(x / 1.06 * math.pi / 2)
            y = 0.95 + (bottom - 0.95) * k
            z = 0.5 + 0.02 * math.sin(k * math.pi)
        return Vector((x, y, z + 0.02 * math.cos(x * 2.5)))
    f = new_obj("flap", thicken(grid_surface(flap, 24, 20), 0.05), flapm)
    mod(f, "SUBSURF", levels=1, render_levels=1)
    # stitching along the flap's edge
    st = []
    for i in range(23):
        x = -0.98 + 1.96 * i / 22
        y = 0.05 - 0.28 * math.cos(x / 1.06 * math.pi / 2) + 0.09
        st.append(box((x, y, 0.535), (0.045, 0.015, 0.01)))
    new_obj("stitches", merge(st), thread, smooth=False)
    # two straps and their buckles
    for sx in (-0.55, 0.55):
        new_obj("strapUp", box((sx, 0.55, 0.545), (0.2, 0.9, 0.025)), strap)
        new_obj("strapDown", box((sx, -0.55, 0.47), (0.2, 0.75, 0.025)), strap)
        frame_ = [box((sx, -0.1 + dy, 0.56), (0.32, 0.04, 0.035)) for dy in (-0.13, 0.13)] + \
                 [box((sx + dx, -0.1, 0.56), (0.04, 0.3, 0.035)) for dx in (-0.14, 0.14)] + \
                 [box((sx, -0.1, 0.575), (0.03, 0.26, 0.025))]
        bk = new_obj("buckle", merge(frame_), iron, smooth=False)
        mod(bk, "BEVEL", width=0.008, segments=2)
        new_obj("tip", box((sx, -0.32, 0.57), (0.2, 0.18, 0.03)), strap)
    # the bedroll on top, tied twice
    roll = tube([Vector((-1.2, 1.38, -0.05)), Vector((1.2, 1.38, -0.05))], [0.36, 0.36], 24)
    r = new_obj("bedroll", roll, wool)
    mod(r, "BEVEL", width=0.06, segments=3)
    for tx in (-0.7, 0.7):
        new_obj("tie", tube([Vector((tx, 1.38, -0.05)), Vector((tx + 0.08, 1.38, -0.05))], [0.375, 0.375], 24), strap)
    # a side pocket
    pk = new_obj("pocket", box((1.08, -0.35, 0.05), (0.3, 1.0, 0.7)), leather)
    mod(pk, "BEVEL", width=0.1, segments=3)
    render("pic_pack", 512, rot=(12, -28), margin=1.08)


def helm():
    clear()
    steel = rich("steel", srgb(52, 52, 54), srgb(92, 90, 88), 1.0, 0.28, 0.6, scale=4, bump=0.3, grain=22, grain_bump=0.06)
    inside = material("inside", srgb(2, 2, 3), 0, 1)
    band = rich("band", srgb(30, 29, 29), srgb(56, 54, 52), 1.0, 0.35, 0.6, scale=7, bump=0.15, grain=60, grain_bump=0.25)
    head = rich("rivet", srgb(90, 86, 80), srgb(120, 116, 108), 1.0, 0.25, 0.4, scale=9)
    rust = rich("rust", srgb(54, 26, 14), srgb(86, 44, 22), 0.2, 0.8, 1.0, scale=12, bump=0.3)
    prof = [(-1.15, 0.9), (-0.6, 0.93), (0.3, 0.95), (0.85, 0.93), (1.0, 0.86), (1.12, 0.6), (1.18, 0.0)]
    bm = lathe_y(prof, seg=48, scale_z=1.12)
    h = new_obj("helm", bm, steel)
    h.data.materials.append(inside)
    mod(h, "SOLIDIFY", thickness=0.06, material_offset=1, offset=-1)
    apply_all(h)
    # eye slits (toward the viewer, +Z) and breaths on the right of the face
    slits = merge([box((s * 0.4, 0.32, 1.0), (0.62, 0.085, 1.2)) for s in (-1, 1)])
    cut(h, slits)
    holes = merge([cylinder_z((0.35 + 0.13 * (i % 3), -0.2 - 0.14 * (i // 3), 1.0), 0.035, 1.2, 10) for i in range(9)])
    cut(h, holes)
    for p in h.data.polygons:
        p.use_smooth = True
    # the cross of bands: down the middle of the face, round the brow, round the rim
    new_obj("nose", box((0, -0.2, 1.065), (0.17, 1.9, 0.04)), band, smooth=False)
    new_obj("brow", lathe_y([(0.46, 0.975), (0.6, 0.975)], seg=48, scale_z=1.12), band)
    new_obj("rim", lathe_y([(-1.15, 0.93), (-1.03, 0.935)], seg=48, scale_z=1.12), band)
    rv = []
    for i in range(16):
        a = 2 * math.pi * i / 16
        for y, rr in ((0.53, 0.99), (-1.09, 0.95)):
            rv.append(rivet((rr * math.sin(a), y, rr * math.cos(a) * 1.12), 0.035))
    for y in (0.85, 0.05, -0.75):
        rv.append(rivet((0, y, 1.09), 0.04))
    new_obj("rivets", merge(rv), head)
    # a cold light behind the slits: something is still inside
    new_obj("eyes", box((0, 0.3, 0.55), (1.2, 0.2, 0.02)), glow("eyes", (0.25, 0.45, 1.0), 1.4), smooth=False)
    render("pic_helm", 512, rot=(8, 24), margin=1.12)


def cog():
    clear()
    iron = rich("iron", srgb(96, 96, 98), srgb(140, 138, 136), 0.75, 0.35, 0.6, scale=5, bump=0.25, grain=20, grain_bump=0.05)
    dark = rich("dark", srgb(36, 36, 38), srgb(60, 58, 56), 1.0, 0.35, 0.6, scale=6)
    teeth, ro, rr = 10, 1.0, 0.8
    bm = bmesh.new()
    pts = []
    for i in range(teeth):
        a0 = 2 * math.pi * i / teeth
        step = 2 * math.pi / teeth
        # a trapezoid tooth: root, rise, top, fall
        for (fr, r) in ((0.0, rr), (0.15, rr), (0.25, ro), (0.5, ro), (0.6, rr), (1.0, rr)):
            if fr == 1.0:
                continue
            a = a0 + fr * step
            pts.append((r * math.cos(a), r * math.sin(a)))
    vs = [bm.verts.new(B((x, y, -0.13))) for x, y in pts]
    face = bm.faces.new(vs)
    res = bmesh.ops.extrude_face_region(bm, geom=[face])
    for v in [e for e in res["geom"] if isinstance(e, bmesh.types.BMVert)]:
        v.co += B((0, 0, 0.26)) - B((0, 0, 0))
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    g = new_obj("cog", bm, iron, smooth=False)
    holes = [cylinder_z((0, 0, 0), 0.2, 1, 32)] + [cylinder_z((0.5 * math.cos(2 * math.pi * k / 5 + 0.3), 0.5 * math.sin(2 * math.pi * k / 5 + 0.3), 0), 0.13, 1, 20) for k in range(5)]
    cut(g, merge(holes))
    mod(g, "BEVEL", width=0.025, segments=3, limit_method="ANGLE")
    mod(g, "WEIGHTED_NORMAL")
    # the boss round the hole
    outer = cylinder_z((0, 0, 0), 0.32, 0.38, 40)
    b = new_obj("boss", outer, dark, smooth=True)
    cut(b, cylinder_z((0, 0, 0), 0.2, 1, 32))
    mod(b, "BEVEL", width=0.03, segments=3, limit_method="ANGLE")
    render("pic_cog", 512, rot=(18, -22), margin=1.12)


def coin():
    clear()
    gold = rich("gold", srgb(186, 136, 52), srgb(232, 188, 96), 1.0, 0.25, 0.48, scale=6, bump=0.3, grain=24, grain_bump=0.05)
    worn = rich("worn", srgb(236, 196, 112), srgb(255, 226, 150), 1.0, 0.12, 0.3, scale=8, bump=0.1, grain=30, grain_bump=0.03)
    c = new_obj("coin", cylinder_z((0, 0, 0), 1.0, 0.14, 64), gold, smooth=False)
    mod(c, "BEVEL", width=0.04, segments=3, limit_method="ANGLE")
    mod(c, "WEIGHTED_NORMAL")
    new_obj("rim", tube([Vector((0.9 * math.cos(2 * math.pi * k / 64), 0.9 * math.sin(2 * math.pi * k / 64), 0.07)) for k in range(65)], [0.045] * 65, 10), worn)
    cross = merge([box((0, 0, 0.08), (1.5, 0.12, 0.05)), box((0, 0, 0.08), (0.12, 1.5, 0.05))])
    cr = new_obj("cross", cross, worn, smooth=False)
    mod(cr, "BEVEL", width=0.02, segments=2)
    pel = []
    for qx in (-1, 1):
        for qy in (-1, 1):
            for (dx, dy) in ((0.3, 0.3), (0.42, 0.3), (0.3, 0.42)):
                pel.append(rivet((qx * dx, qy * dy, 0.08), 0.05, 0.8))
    new_obj("pellets", merge(pel), worn)
    # a dot ring inside the rim
    dots = [rivet((0.78 * math.cos(2 * math.pi * k / 40), 0.78 * math.sin(2 * math.pi * k / 40), 0.075), 0.022, 0.7) for k in range(40)]
    new_obj("dots", merge(dots), worn)
    render("pic_coin", 512, rot=(-36, -18), margin=1.12)  # its face turned up, to the sky it shines with


JOBS = {"plate": plate, "panel": panel, "pack": pack, "helm": helm, "cog": cog, "coin": coin}
for name, job in JOBS.items():
    if ONLY is None or name in ONLY:
        job()
print("DONE", OUT)
