"""
make_icons.py - the weapon pictures for the weapon bar and the pack (Blender 5.x, headless).

  blender -b --factory-startup --python-exit-code 1 -P tools/blender/make_icons.py -- <out_dir>

The developer, 2026-11-14: "not that boring pack with the boring little sword and the boring bow you give me: make
them much sharper, cutting, a little wilder. This is not a game for little children; darker, more frightening."

So each weapon is MODELLED (not drawn from flat shapes) and rendered alone on a transparent background, lit from the
side and from behind so its edges catch a cold light and its body stays dark: a long war sword with a wicked point and a
notched edge, a war spear with a long barbed head, a war bow with horn tips and a dark grip. 512 x 512 PNGs with alpha,
diagonal, ready to be uploaded as images (configs/ItemArt / Client/UI/Icons use them by asset id).
"""
import bpy, bmesh, sys, os, math
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from meshlib import *  # noqa
from mathutils import Vector

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else os.path.join(os.getcwd(), "icons_out"))
os.makedirs(OUT, exist_ok=True)


def setup():
    bpy.ops.wm.read_factory_settings(use_empty=True)
    return {
        "steel": material("steel", srgb(120, 124, 132), 1, 0.22),
        "dark": material("dark", srgb(36, 36, 40), 1, 0.35),
        "edge": material("edge", srgb(210, 214, 222), 1, 0.12),
        "leather": material("leather", srgb(44, 28, 20), 0, 0.7),
        "wood": material("wood", srgb(52, 36, 26), 0, 0.6),
        "horn": material("horn", srgb(150, 140, 120), 0, 0.4),
        "string": material("string", srgb(170, 160, 140), 0, 0.8),
        "blood": material("blood", srgb(60, 8, 10), 0, 0.3),
    }


def sword(M):
    grip0, guard, tip = -0.95, 0.0, 4.6

    def w(u):
        # a long blade, a little waisted, a sharp swelling point; notches near the tip
        base = 0.2 * (1 - 0.35 * u)
        if u > 0.78:
            base *= max(0.0, 1 - ((u - 0.78) / 0.22) ** 1.3)
        notch = 0.02 if (0.55 < u < 0.57 or 0.66 < u < 0.675) else 0.0
        return base - notch

    new_obj("blade", blade(guard + 0.05, tip, w, lambda u: 0.04 * (1 - 0.5 * u), lambda u: 0.6 * max(0, 1 - u / 0.65), 48), M["steel"])
    # the cutting edges, a thin bright line along each side
    for s in (-1, 1):
        pts = [Vector((guard + 0.1 + (tip - guard - 0.1) * t, s * w(t * 0.98) * 0.97, 0)) for t in [k / 24 for k in range(25)]]
        new_obj(f"edge{s}", tube(pts, [0.008] * len(pts), 4), M["edge"])
    # a cross with down-swept quillons ending in points
    pts, rad = [], []
    for i in range(15):
        s = -0.75 + 1.5 * i / 14
        pts.append(Vector((guard + 0.22 * (abs(s) / 0.75) ** 2.2, s, 0)))
        rad.append(0.05 * (1 - 0.7 * (abs(s) / 0.75) ** 3))
    new_obj("guard", tube(pts, rad, 8), M["dark"])
    new_obj("grip", lathe_x_solid([(grip0, 0.07), (-0.5, 0.085), (guard - 0.02, 0.07)]), M["leather"])
    # a spiked pommel
    new_obj("pommel", merge([ball((grip0 - 0.12, 0, 0), 0.14, 12, (1.2, 1, 0.8)), tube([Vector((grip0 - 0.2, 0, 0)), Vector((grip0 - 0.42, 0, 0))], [0.06, 0.0], 8)]), M["dark"])
    # a little dried blood on the blade
    new_obj("blood", box((2.1, 0.06, 0.042), (0.6, 0.12, 0.006)), M["blood"])


def lathe_x_solid(profile, seg=14):
    def f(u, v):
        i = v * (len(profile) - 1)
        k = min(int(i), len(profile) - 2)
        fr = i - k
        x = profile[k][0] * (1 - fr) + profile[k + 1][0] * fr
        r = profile[k][1] * (1 - fr) + profile[k + 1][1] * fr
        a = 2 * math.pi * u
        return Vector((x, r * math.sin(a), -r * math.cos(a)))
    return grid_surface(f, seg, 8, closed_u=True, cap=True)


def spear(M):
    butt, socket0, head0, tip = -3.0, 2.2, 2.6, 4.4
    new_obj("shaft", lathe_x_solid([(butt, 0.075), (socket0, 0.07)]), M["wood"])
    new_obj("socket", lathe_x_solid([(socket0 - 0.05, 0.09), (head0, 0.05)]), M["dark"])

    def w(u):
        if u < 0.25:
            return 0.06 + 0.2 * math.sin(u / 0.25 * math.pi / 2)
        return 0.26 * (1 - ((u - 0.25) / 0.75) ** 1.1)

    new_obj("head", blade(head0 - 0.02, tip, w, lambda u: 0.045 * (1 - 0.7 * u), None, 36), M["steel"])
    # barbs swept back from the base of the head
    barbs = [tube([Vector((head0 + 0.1, s * 0.12, 0)), Vector((head0 - 0.15, s * 0.32, 0)), Vector((head0 - 0.32, s * 0.36, 0))], [0.035, 0.025, 0.0], 6) for s in (-1, 1)]
    new_obj("barbs", merge(barbs), M["steel"])
    new_obj("wrap", merge([lathe_x_solid([(x, 0.083), (x + 0.06, 0.083)]) for x in [i * 0.08 - 0.4 for i in range(10)]]), M["leather"])


def bow(M):
    # a war bow seen from the side: the limbs curve back, the tips recurve forward; along Y (up), drawn in the XY plane
    pts, rad = [], []
    for i in range(41):
        t = -1 + 2 * i / 40
        y = 2.4 * t
        x = -0.55 * (1 - t * t) + 0.18 * (abs(t) ** 6)
        pts.append(Vector((x, y, 0)))
        rad.append(0.075 * (1 - 0.55 * abs(t)) + 0.012)
    new_obj("limbs", tube(pts, rad, 8), M["wood"])
    new_obj("grip", lathe_x_solid([(-0.5, 0.11), (0.5, 0.11)]), M["leather"])
    bpy.data.objects["grip"].rotation_euler = (0, math.radians(90), 0)
    bpy.data.objects["grip"].location = B((-0.55, 0, 0))
    tips = [tube([pts[k], pts[k] + Vector((0.14, s * 0.18, 0))], [0.05, 0.0], 6) for k, s in ((0, -1), (40, 1))]
    new_obj("horns", merge(tips), M["horn"])
    new_obj("string", tube([pts[1], Vector((0.04, 0, 0)), pts[39]], [0.012, 0.012, 0.012], 4), M["string"])


def render(name, frame_obj_names, rot):
    scene = bpy.context.scene
    scene.render.engine = "BLENDER_EEVEE"
    scene.render.resolution_x = scene.render.resolution_y = 512
    scene.render.film_transparent = True
    scene.view_settings.view_transform = "Standard"
    scene.view_settings.look = "Medium High Contrast"
    world = bpy.data.worlds.new("w")
    scene.world = world
    world.use_nodes = True
    bg = next(n for n in world.node_tree.nodes if n.type == "BACKGROUND")
    bg.inputs["Color"].default_value = (0.02, 0.02, 0.025, 1)
    bg.inputs["Strength"].default_value = 0.6
    # the weapon turned to a diagonal
    root = bpy.data.objects.new("root", None)
    scene.collection.objects.link(root)
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            ob.parent = root
    root.rotation_euler = rot
    bpy.context.view_layer.update()
    # frame it
    pts = []
    for ob in bpy.data.objects:
        if ob.type == "MESH":
            pts += [ob.matrix_world @ Vector(c) for c in ob.bound_box]
    lo = Vector((min(p.x for p in pts), min(p.y for p in pts), min(p.z for p in pts)))
    hi = Vector((max(p.x for p in pts), max(p.y for p in pts), max(p.z for p in pts)))
    centre = (lo + hi) / 2
    size = max(hi.x - lo.x, hi.z - lo.z)
    cam_d = bpy.data.cameras.new("cam")
    cam_d.type = "ORTHO"
    cam_d.ortho_scale = size * 1.12
    cam = bpy.data.objects.new("cam", cam_d)
    scene.collection.objects.link(cam)
    cam.location = centre + Vector((0, -20, 0))
    cam.rotation_euler = (math.radians(90), 0, 0)
    scene.camera = cam
    # light: a cold key from above left, a hard rim from behind, a faint warm fill (fire) from below
    for lname, loc, energy, color, size_ in (("Key", (-6, -8, 7), 1600, (0.85, 0.9, 1.0), 3),
                                              ("Rim", (6, 10, 4), 2600, (0.75, 0.82, 1.0), 2),
                                              ("Fire", (2, -6, -6), 400, (1.0, 0.55, 0.25), 4)):
        ld = bpy.data.lights.new(lname, "AREA")
        ld.energy = energy
        ld.color = color
        ld.size = size_
        lo_ = bpy.data.objects.new(lname, ld)
        lo_.location = centre + Vector(loc)
        scene.collection.objects.link(lo_)
        d = centre - lo_.location
        lo_.rotation_euler = d.to_track_quat("-Z", "Y").to_euler()
    scene.render.filepath = os.path.join(OUT, f"icon_{name}.png")
    bpy.ops.render.render(write_still=True)


for name, build, rot in (("sword", sword, (0, math.radians(-45), 0)), ("spear", spear, (0, math.radians(-45), 0)), ("bow", bow, (0, math.radians(-30), 0))):
    M = setup()
    build(M)
    render(name, None, rot)
print("DONE", OUT)
