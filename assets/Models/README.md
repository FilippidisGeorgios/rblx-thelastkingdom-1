# assets/Models

One folder per model: the Blender script or `.blend`, the exported `.glb`, and the renders that were looked at. 1 Blender unit =
1 stud; a weapon runs along +X from the grip; one object and one material per part. Pipeline: `docs/Pipelines.md` (2).
The first one, `tools/blender/make_sword.py`, writes its GLB and four renders to the folder in `TLK_OUT`.
