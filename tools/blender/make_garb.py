"""
make_garb.py - the King's coat and cape, and the Hollow Knight's plate and helm (Blender 5.x, headless).

  blender -b --factory-startup --python-exit-code 1 -P tools/blender/make_garb.py -- <out_dir>

The developer, 2026-11-14:
  THE KING   "take the armour off; a brown overcoat, a realistic one, with gold and a little white; a cape that looks as if
             it could drag but does not, exactly his height; and when he moves it moves." So: a brown wool coat over the
             chest and arms, gold braid down the front and round the hems, an ERMINE collar and cuffs (white fur with the
             black tail tips: the royal fur), a belt; a long skirt in eight panels that swing (each its own piece, hinged at
             the waist: ZombieAnimController sways them); a bordeaux velvet cape in six strips of two pieces each, hinged at
             the shoulders and at the middle, its hem a hair above the floor.
  THE KNIGHT "take all of his clothing off; make the helm far more frightening; make the armour far more real, out of very
             many small pieces." So: a bascinet with a hound-skull visor (the beak), narrow eye slits that glow from inside,
             rows of breaths, a mail aventail, a crest; a cuirass with a keel and a plackart, a gorget of three lames, four
             faulds and lamed tassets; pauldrons of a cap and four lames; rerebraces, couters with fan plates, vambraces,
             cuffs; cuisses, poleyns with wings, greaves with a ridge, sabatons of five lames and a toe cap.

Every piece is built in the frame of the body part it rides on (a limb: its long axis X, the end toward the body at +X;
a torso or a head: x right, y up, z back), measured from ServerStorage.Assets.Undead (2026-11-14). The pieces are named
<Body>_<Part>__<Piece>; the cloth hinges are marker points <Body>_<Part>__<Hinge>. One set of frame markers (Garb_M0, MX,
MY) gives the frame back in Studio. Roblox axes are written and turned into Blender's at the end (meshlib.B).
"""
import bpy, bmesh, sys, os, math, random
sys.path.append(os.path.dirname(os.path.abspath(__file__)))
from meshlib import *  # noqa
from mathutils import Vector, Matrix

argv = sys.argv[sys.argv.index("--") + 1:] if "--" in sys.argv else []
OUT = os.path.abspath(argv[0] if argv else os.path.join(os.getcwd(), "garb_out"))
os.makedirs(OUT, exist_ok=True)
random.seed(1114)
bpy.ops.wm.read_factory_settings(use_empty=True)

M = {
    "coat": material("coat", srgb(96, 60, 36), 0, 0.9),
    "gold": material("gold", srgb(196, 150, 70), 1, 0.3),
    "ermine": material("ermine", srgb(236, 232, 222), 0, 0.95),
    "spot": material("spot", srgb(14, 12, 12), 0, 0.9),
    "velvet": material("velvet", srgb(86, 14, 26), 0, 0.85),
    "leather": material("leather", srgb(52, 34, 24), 0, 0.8),
    "plate": material("plate", srgb(72, 74, 78), 1, 0.4),
    "dark": material("dark", srgb(18, 18, 20), 0, 0.9),
    "mail": material("mail", srgb(58, 58, 62), 1, 0.55),
    "glow": material("glow", srgb(150, 200, 255), 0, 0.2),
    "marker": material("marker", (1, 0, 1), 0, 1),
}

# measured part sizes (studs): torso blocks (x, y, z), limbs (length, radius), head radius
KING = dict(UT=(2.58, 1.91, 1.22), LT=(2.29, 0.61, 1.22), UA=(1.45, 0.40), LA=(1.35, 0.33), UL=(1.43, 0.53), LL=(1.41, 0.375),
            FT=(0.80, 0.29, 1.58), FLOOR_UT=-4.37, FLOOR_LT=-3.13)
KNIGHT = dict(UT=(2.31, 1.78, 1.09), LT=(2.05, 0.57, 1.09), UA=(1.36, 0.36), LA=(1.28, 0.29), UL=(1.34, 0.475), LL=(1.32, 0.335),
              FT=(0.72, 0.27, 1.41), HEAD=0.6)


def body_ring(w, d, k=2.6, front_point=0.0):
    """A rounded-rectangle (superellipse) ring of half-width w (x) and half-depth d (z); angle u 0..1 from the front."""
    def p(u):
        a = 2 * math.pi * u
        s, c = math.sin(a), -math.cos(a)
        x = w * math.copysign(abs(s) ** (2 / k), s)
        z = d * math.copysign(abs(c) ** (2 / k), c)
        if front_point and z < 0:
            z -= front_point * max(0.0, 1 - abs(x) / w) ** 2  # a keel down the front
        return x, z
    return p


# =====================================================================================================================
# THE KING
# =====================================================================================================================
def king():
    D = KING
    w, h, d = D["UT"][0] / 2, D["UT"][1] / 2, D["UT"][2] / 2
    pad = 0.06
    ring = body_ring(w + pad, d + pad, 2.4)
    # the coat over the chest: from below the waist seam to the shoulders, rounded over the top
    def coat(u, v):
        y = -h - 0.05 + (2 * h + 0.05) * v
        x, z = ring(u)
        top = max(0.0, (v - 0.8) / 0.2)
        k = 1 - 0.18 * top ** 2  # it rounds in over the shoulders
        return Vector((x * k, y + 0.05 * top, z * (1 - 0.25 * top ** 2)))
    new_obj("King_UpperTorso__Coat", grid_surface(coat, 40, 10, closed_u=True, cap=True), M["coat"])
    # gold braid: down the front, and a band at the waist; gold buttons
    braid = []
    for side in (-1, 1):
        pts = [Vector((side * 0.13, -h - 0.02 + (2 * h) * t, -(d + pad) - 0.012)) for t in (0, 0.33, 0.66, 0.92)]
        braid.append(tube(pts, [0.035] * 4, 6))
    braid.append(box((0, -h + 0.06, 0), (2 * (w + pad) + 0.02, 0.09, 2 * (d + pad) + 0.02)))
    for i in range(5):
        braid.append(ball((0, -h + 0.35 + i * 0.32, -(d + pad) - 0.03), 0.045, 8))
    new_obj("King_UpperTorso__Braid", merge(braid), M["gold"])
    # the ermine collar: a thick roll round the neck and over the shoulders, open at the front
    collar = []
    for i in range(29):
        u = 0.07 + 0.86 * i / 28
        x, z = body_ring(w * 0.62, d * 0.95, 2.2)(u)
        collar.append(Vector((x, h + 0.02 - 0.08 * math.cos(2 * math.pi * u), z)))
    new_obj("King_UpperTorso__Ermine", tube(collar, [0.2] * len(collar), 10), M["ermine"])
    spots = []
    for i in range(16):
        u = 0.1 + 0.8 * (i + 0.5) / 16
        x, z = body_ring(w * 0.62, d * 0.95, 2.2)(u)
        n = Vector((x, 0, z)).normalized()
        spots.append(ball((x + n.x * 0.19, h + 0.06 + 0.05 * (i % 2), z + n.z * 0.19), 0.035, 6, (1, 1.8, 1)))
    new_obj("King_UpperTorso__ErmineSpots", merge(spots), M["spot"])

    # sleeves: wide wool tubes over the upper and lower arm, the lower flaring at the wrist, a gold cuff and ermine
    L, r = D["UA"]
    sleeve_u = lathe_x([(L / 2 + 0.02, r + 0.07), (0, r + 0.08), (-L / 2 - 0.02, r + 0.07)], 16)
    L2, r2 = D["LA"]
    sleeve_l = lathe_x([(L2 / 2 + 0.03, r2 + 0.1), (0, r2 + 0.13), (-L2 / 2 + 0.05, r2 + 0.22)], 16)
    for side in ("Right", "Left"):
        new_obj(f"King_{side}UpperArm__Sleeve", copy(sleeve_u), M["coat"])
        new_obj(f"King_{side}LowerArm__Sleeve", copy(sleeve_l), M["coat"])
        new_obj(f"King_{side}LowerArm__Cuff", lathe_x([(-L2 / 2 + 0.16, r2 + 0.2), (-L2 / 2 + 0.05, r2 + 0.24)], 16), M["gold"])
        new_obj(f"King_{side}LowerArm__CuffFur", lathe_x([(-L2 / 2 + 0.05, r2 + 0.25), (-L2 / 2 - 0.08, r2 + 0.27), (-L2 / 2 - 0.14, r2 + 0.2)], 16), M["ermine"])
    sleeve_u.free()
    sleeve_l.free()

    # the belt
    lw, lh, ld = D["LT"][0] / 2, D["LT"][1] / 2, D["LT"][2] / 2
    bring = body_ring(lw + 0.09, ld + 0.09, 2.6)
    belt = grid_surface(lambda u, v: Vector((bring(u)[0], 0.12 + 0.16 * v, bring(u)[1])), 36, 1, closed_u=True)
    new_obj("King_LowerTorso__Belt", thicken(belt, 0.03), M["leather"])
    new_obj("King_LowerTorso__Buckle", merge([box((0, 0.2, -(ld + 0.11)), (0.26, 0.22, 0.04)), ball((0, 0.2, -(ld + 0.14)), 0.05, 8)]), M["gold"])

    # the skirt: eight panels from the waist to the shin, each hinged at its top; split at the front
    top_y = -lh + 0.02
    length = -(D["FLOOR_LT"]) - 0.9 + top_y  # to about a stud above the floor
    for i in range(8):
        a0 = (i + 0.03) / 8 + 0.0
        a1 = (i + 1.06) / 8
        def panel(u, v, a0=a0, a1=a1):
            uu = a0 + (a1 - a0) * u
            x, z = body_ring(lw + 0.1 + 0.42 * v ** 0.9, ld + 0.1 + 0.35 * v ** 0.9, 2.3)(uu)
            # a fold: the cloth waves a little across the panel
            fold = 0.035 * math.sin(math.pi * 2 * u) * (0.3 + v)
            n = Vector((x, 0, z)).normalized()
            return Vector((x + n.x * fold, top_y - length * v, z + n.z * fold))
        new_obj(f"King_LowerTorso__Skirt{i}", thicken(grid_surface(panel, 6, 8), 0.035), M["coat"])
        hem = grid_surface(lambda u, v, a0=a0, a1=a1: (lambda uu: Vector((body_ring(lw + 0.52, ld + 0.45, 2.3)(uu)[0], top_y - length + 0.02 + 0.14 * v, body_ring(lw + 0.52, ld + 0.45, 2.3)(uu)[1])))(a0 + (a1 - a0) * u), 6, 1)
        new_obj(f"King_LowerTorso__SkirtHem{i}", thicken(hem, 0.045), M["gold"])
        hx, hz = body_ring(lw + 0.1, ld + 0.1, 2.3)((a0 + a1) / 2)
        point(f"King_LowerTorso__SkirtHinge{i}", (hx, top_y, hz), M["marker"])

    # the cape: six strips across the back, each in two pieces, hanging to a hair above the floor
    cape_top = h + 0.02
    cape_len = -(D["FLOOR_UT"]) + cape_top - 0.06
    upper = cape_len * 0.48
    n = 6
    span = 2 * (w + 0.12)
    for i in range(n):
        x0 = -span / 2 + span * i / n - 0.03
        x1 = -span / 2 + span * (i + 1) / n + 0.03
        for seg, (y0, y1) in enumerate(((0, upper), (upper - 0.04, cape_len))):
            def strip(u, v, x0=x0, x1=x1, y0=y0, y1=y1, i=i):
                x = x0 + (x1 - x0) * u
                yy = y0 + (y1 - y0) * v
                # the back of the shoulders, then hanging, the cape swelling out a little from the body and in folds
                z = d + 0.16 + 0.12 * min(1, yy / 1.2) + 0.05 * math.sin(math.pi * 2 * u + i) * min(1, yy / 1.5)
                return Vector((x * (1 - 0.1 * max(0, 1 - yy / 0.6)), cape_top - yy, z))
            new_obj(f"King_UpperTorso__Cape{i}_{seg}", thicken(grid_surface(strip, 4, 10), 0.04), M["velvet"])
        point(f"King_UpperTorso__CapeHinge{i}", ((x0 + x1) / 2, cape_top, d + 0.16), M["marker"])
        point(f"King_UpperTorso__CapeKnee{i}", ((x0 + x1) / 2, cape_top - upper, d + 0.28), M["marker"])
    # the gold edge down the two outer strips and along the hem of each lower piece
    trims = []
    for side in (-1, 1):
        trims.append(tube([Vector((side * (span / 2 + 0.02), cape_top - y, d + 0.16 + 0.12 * min(1, y / 1.2))) for y in (0.1, upper * 0.5, upper - 0.05)], [0.04] * 3, 6))
    new_obj("King_UpperTorso__CapeTrim", merge(trims), M["gold"])


def lathe_x(profile, seg=16):
    """(x, r) points revolved about X."""
    def f(u, v):
        i = v * (len(profile) - 1)
        k = min(int(i), len(profile) - 2)
        fr = i - k
        x = profile[k][0] * (1 - fr) + profile[k + 1][0] * fr
        r = profile[k][1] * (1 - fr) + profile[k + 1][1] * fr
        a = 2 * math.pi * u
        return Vector((x, r * math.sin(a), -r * math.cos(a)))
    bm = grid_surface(f, seg, max(2, (len(profile) - 1) * 2), closed_u=True, cap=False)
    bmesh.ops.recalc_face_normals(bm, faces=bm.faces)
    return thicken(bm, 0.025)


def copy(bm):
    me = bpy.data.meshes.new("c")
    bm.to_mesh(me)
    out = bmesh.new()
    out.from_mesh(me)
    bpy.data.meshes.remove(me)
    return out


# =====================================================================================================================
# THE HOLLOW KNIGHT
# =====================================================================================================================
def knight():
    D = KNIGHT
    w, h, d = D["UT"][0] / 2, D["UT"][1] / 2, D["UT"][2] / 2
    # --- the cuirass: a keeled shell round the chest, shoulders cut away
    ring = body_ring(w + 0.05, d + 0.07, 2.2, front_point=0.14)
    def cuirass(u, v):
        y = -h + 0.05 + (2 * h - 0.18) * v
        x, z = ring(u)
        waist = 1 - 0.07 * math.exp(-((v - 0.15) / 0.2) ** 2)
        top = max(0.0, (v - 0.82) / 0.18)
        return Vector((x * waist * (1 - 0.12 * top), y, z * waist * (1 - 0.3 * top ** 1.5)))
    new_obj("Knight_UpperTorso__Cuirass", grid_surface(cuirass, 48, 12, closed_u=True, cap=True), M["plate"])
    # the plackart, a second plate over the belly with a pointed top, and its rivets
    pring = body_ring(w + 0.08, d + 0.1, 2.2, front_point=0.14)
    def plack(u, v):
        uu = 0.75 + 0.5 * u  # the front half only (angles wrap)
        x, z = pring(uu % 1)
        top = -h + 0.1 + 0.75 * (1 - abs(u - 0.5) * 1.4)
        y = -h + 0.06 + (top - (-h + 0.06)) * v
        return Vector((x, y, z))
    new_obj("Knight_UpperTorso__Plackart", thicken(grid_surface(plack, 20, 4), 0.03), M["plate"])
    rivets = []
    for i in range(9):
        u = 0.78 + 0.44 * i / 8
        x, z = pring(u % 1)
        rivets.append(ball((x * 1.01, -h + 0.14, z - 0.02), 0.025, 6))
    # the roll of the neck and arm openings
    neck = [Vector((body_ring(w * 0.45, d * 0.8, 2.0)(t)[0], h - 0.1 + 0.05 * math.cos(2 * math.pi * t), body_ring(w * 0.45, d * 0.8, 2.0)(t)[1])) for t in [k / 24 for k in range(25)]]
    new_obj("Knight_UpperTorso__Rolls", merge(rivets + [tube(neck, [0.035] * len(neck), 6)]), M["plate"])
    # the gorget: three lames round the neck
    gorget = []
    for k in range(3):
        rr = (0.55 - 0.06 * k, 0.5 - 0.05 * k)
        gorget.append(thicken(grid_surface(lambda u, v, k=k, rr=rr: Vector((rr[0] * math.sin(2 * math.pi * u), h - 0.12 + 0.12 * k + 0.11 * v, -rr[1] * math.cos(2 * math.pi * u))), 24, 1, closed_u=True), 0.025))
    new_obj("Knight_UpperTorso__Gorget", merge(gorget), M["plate"])

    # --- faulds (four lames below the cuirass, round the front) and tassets on the thighs
    lw, lh, ld = D["LT"][0] / 2, D["LT"][1] / 2, D["LT"][2] / 2
    faulds = []
    for k in range(4):
        fr = body_ring(lw + 0.1 + 0.04 * k, ld + 0.1 + 0.04 * k, 2.4)
        faulds.append(thicken(grid_surface(lambda u, v, k=k, fr=fr: Vector((fr((0.62 + 0.76 * u) % 1)[0], lh - 0.05 - 0.17 * k - 0.2 * v, fr((0.62 + 0.76 * u) % 1)[1])), 24, 1), 0.025))
    new_obj("Knight_LowerTorso__Faulds", merge(faulds), M["plate"])
    tassets = []
    for side in (-1, 1):
        for k in range(3):
            def tas(u, v, k=k, side=side):
                x = side * (0.25 + 0.6 * u)
                y = lh - 0.75 - 0.22 * k - 0.24 * v
                return Vector((x, y, -(ld + 0.12 + 0.04 * k) - 0.05 * math.sin(math.pi * u)))
            tassets.append(thicken(grid_surface(tas, 6, 1), 0.025))
    new_obj("Knight_LowerTorso__Tassets", merge(tassets), M["plate"])

    # --- arms
    L, r = D["UA"]
    for side in ("Right", "Left"):
        # the pauldron: a cap over the shoulder and four lames down the arm
        cap = arc_shell_x(L / 2 - 0.05, L / 2 + 0.22, r + 0.2, r + 0.05, -2.2, 2.2, 0.03, 18, 4)
        lames = [arc_shell_x(L / 2 - 0.16 - 0.15 * k, L / 2 - 0.02 - 0.15 * k, r + 0.19 - 0.02 * k, r + 0.19 - 0.02 * k, -1.9, 1.9, 0.025, 16, 1) for k in range(4)]
        new_obj(f"Knight_{side}UpperArm__Pauldron", merge([cap] + lames), M["plate"])
        new_obj(f"Knight_{side}UpperArm__Rerebrace", arc_shell_x(-L / 2 + 0.05, L / 2 - 0.62, r + 0.05, r + 0.06, -math.pi, math.pi, 0.025, 16, 2), M["plate"])
        L2, r2 = D["LA"]
        # the couter: a cup at the elbow (behind: +Z) and a fan plate on its outer side
        couter = ball((L2 / 2 - 0.02, 0, 0.16), r2 + 0.06, 12, (0.8, 1, 0.8))
        fan = box((L2 / 2 - 0.04, 0, 0.26), (0.36, 0.42, 0.03))
        new_obj(f"Knight_{side}LowerArm__Couter", merge([couter, fan]), M["plate"])
        new_obj(f"Knight_{side}LowerArm__Vambrace", arc_shell_x(-L2 / 2 + 0.12, L2 / 2 - 0.18, r2 + 0.05, r2 + 0.08, -math.pi, math.pi, 0.025, 16, 3, flare=0.012), M["plate"])
        new_obj(f"Knight_{side}LowerArm__Cuff", lathe_x([(-L2 / 2 + 0.14, r2 + 0.09), (-L2 / 2 - 0.02, r2 + 0.16), (-L2 / 2 - 0.08, r2 + 0.2)], 16), M["plate"])

    # --- legs
    L3, r3 = D["UL"]
    L4, r4 = D["LL"]
    fw, fh, fd = D["FT"][0] / 2, D["FT"][1] / 2, D["FT"][2] / 2
    for side in ("Right", "Left"):
        new_obj(f"Knight_{side}UpperLeg__Cuisse", arc_shell_x(-L3 / 2 + 0.1, L3 / 2 - 0.05, r3 + 0.05, r3 + 0.07, -1.9, 1.9, 0.025, 16, 3, flare=0.01), M["plate"])
        poleyn = ball((L4 / 2 - 0.02, 0, -0.2), r4 + 0.08, 12, (0.85, 1, 0.75))
        wing = box((L4 / 2 - 0.02, 0.0, -0.06), (0.3, 0.05, 0.4))
        new_obj(f"Knight_{side}LowerLeg__Poleyn", merge([poleyn, wing]), M["plate"])
        new_obj(f"Knight_{side}LowerLeg__Greave", arc_shell_x(-L4 / 2 + 0.02, L4 / 2 - 0.2, r4 + 0.06, r4 + 0.04, -math.pi, math.pi, 0.025, 18, 3), M["plate"])
        ridge = tube([Vector((x, 0, -(r4 + 0.07))) for x in (-L4 / 2 + 0.05, 0, L4 / 2 - 0.22)], [0.02] * 3, 6)
        new_obj(f"Knight_{side}LowerLeg__GreaveRidge", ridge, M["plate"])
        # sabatons: five lames over the foot and a pointed toe
        sab = []
        for k in range(5):
            z0 = fd - 0.25 - 0.22 * k
            sab.append(thicken(grid_surface(lambda u, v, z0=z0: Vector(((u - 0.5) * 2 * (fw + 0.04), fh + 0.06 - 0.05 * abs(u - 0.5) * 2 - 0.02 * v, z0 - 0.26 * v)), 6, 1), 0.02))
        sab.append(thicken(grid_surface(lambda u, v: Vector(((u - 0.5) * 2 * (fw + 0.03) * (1 - v), fh + 0.02 - 0.12 * v, -fd + 0.1 - 0.28 * v)), 6, 3), 0.02))
        new_obj(f"Knight_{side}Foot__Sabaton", merge(sab), M["plate"])

    # --- the helm: a pointed bascinet, a hound-skull visor (the beak), eye slits that glow, breaths, an aventail, a crest
    R0 = D["HEAD"] + 0.06
    skull = lathe_y([(-0.05, R0), (0.25, R0 - 0.01), (0.5, R0 - 0.08), (0.72, R0 - 0.24), (0.88, 0.2), (1.0, 0.0)], 28)
    new_obj("Knight_Head__Bascinet", skull, M["plate"])
    # the visor: a snout pushed forward and down from the face, ellipses shrinking to a blunt point
    def visor(u, v):
        a = 2 * math.pi * u
        rx = (R0 - 0.02) * (1 - 0.82 * v ** 1.15)
        ry = 0.42 * (1 - 0.75 * v ** 1.1)
        cy = -0.12 - 0.12 * v
        z = -0.28 - 0.62 * v
        return Vector((rx * math.sin(a), cy + ry * math.cos(a), z))
    new_obj("Knight_Head__Visor", grid_surface(visor, 28, 10, closed_u=True, cap=True), M["plate"])
    # eye slits (dark) with a cold light inside, and two rows of breaths down the snout
    darks, glows = [], []
    for s in (-1, 1):
        darks.append(box((s * 0.2, 0.02, -0.5), (0.24, 0.045, 0.16), Matrix.Rotation(math.radians(s * 18), 3, "Y")))
        glows.append(box((s * 0.2, 0.02, -0.46), (0.2, 0.025, 0.1), Matrix.Rotation(math.radians(s * 18), 3, "Y")))
        for row in range(2):
            for k in range(5):
                darks.append(box((s * (0.06 + 0.055 * k), -0.2 - 0.09 * row, -0.62 - 0.03 * k + 0.05 * row), (0.03, 0.03, 0.08)))
    new_obj("Knight_Head__VisorDark", merge(darks), M["dark"])
    new_obj("Knight_Head__VisorGlow", merge(glows), M["glow"])
    # the brow band with its rivets, the visor's pivots, a crest down the top
    band = [lathe_y([(0.0, R0 + 0.015), (0.09, R0 + 0.015)], 28)]
    for k in range(14):
        a = 2 * math.pi * k / 14
        band.append(ball((math.sin(a) * (R0 + 0.03), 0.045, -math.cos(a) * (R0 + 0.03)), 0.022, 6))
    band += [ball((s * (R0 + 0.02), -0.05, -0.05), 0.06, 8) for s in (-1, 1)]
    band.append(tube([Vector((0, R0 * 0.7 + 0.05 * math.sin(t * 3.1), -R0 * 0.7 + 1.35 * R0 * t)) for t in (0, 0.25, 0.5, 0.75, 1.0)], [0.025, 0.04, 0.045, 0.04, 0.02], 6))
    new_obj("Knight_Head__Band", merge(band), M["plate"])
    # the mail aventail: from the helm's rim down over the neck and shoulders
    new_obj("Knight_Head__Aventail", lathe_y([(0.02, R0 + 0.01), (-0.35, R0 + 0.08), (-0.7, R0 + 0.3)], 28, 1.0), M["mail"])


king()
knight()
markers("Garb", M["marker"])

stats = {}
for ob in bpy.data.objects:
    if ob.type == "MESH":
        stats[ob.name] = sum(len(p.vertices) - 2 for p in ob.data.polygons)
print("COUNT", len(stats), "TRIS total", sum(stats.values()), "max", max(stats.items(), key=lambda kv: kv[1]))
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "garb.glb"), export_format="GLB", export_apply=True, export_materials="EXPORT")
print("EXPORTED")
