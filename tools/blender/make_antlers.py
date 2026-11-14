"""
make_antlers.py - the Huntsman's pair of antlers (Blender 5.x, headless), from the right antler of arms.glb.

  blender -b --factory-startup --python-exit-code 1 -P tools/blender/make_antlers.py -- <arms.glb> <out_dir>

The right antler (tools/blender/make_arms.py) is copied and mirrored across X for the left, so the brow tines of both
point forward. Writes <out_dir>/antlers.glb: Antler_Right, Antler_Left and the frame markers Antler_M0/MX/MY (origin
at the right burr; the left burr is the mirror image, at the same place: Studio sets them apart on the skull).
"""
import bpy, bmesh, sys, os

argv = sys.argv[sys.argv.index("--") + 1:]
SRC, OUT = os.path.abspath(argv[0]), os.path.abspath(argv[1])
os.makedirs(OUT, exist_ok=True)
bpy.ops.wm.read_factory_settings(use_empty=True)
bpy.ops.import_scene.gltf(filepath=SRC)
keep = {"Antler_Right", "Antler_M0", "Antler_MX", "Antler_MY"}
for ob in list(bpy.data.objects):
    if ob.name not in keep:
        bpy.data.objects.remove(ob, do_unlink=True)
right = bpy.data.objects["Antler_Right"]
left = right.copy()
left.data = right.data.copy()
left.name = "Antler_Left"
bpy.context.scene.collection.objects.link(left)
# mirror across X in the mesh itself (no negative scale goes to Roblox), and turn the faces back outward
me = left.data
bm = bmesh.new()
bm.from_mesh(me)
for v in bm.verts:
    v.co.x = -v.co.x
bmesh.ops.reverse_faces(bm, faces=bm.faces)
bm.to_mesh(me)
bm.free()
# the darker brown the developer asked for, on both
for ob in (right, left):
    for m in ob.data.materials:
        if m and m.use_nodes:
            bsdf = next((n for n in m.node_tree.nodes if n.type == "BSDF_PRINCIPLED"), None)
            if bsdf:
                bsdf.inputs["Base Color"].default_value = (0.034, 0.018, 0.009, 1)
bpy.ops.export_scene.gltf(filepath=os.path.join(OUT, "antlers.glb"), export_format="GLB", export_apply=True)
print("DONE", [o.name for o in bpy.data.objects])
