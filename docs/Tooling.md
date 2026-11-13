# Tooling: what we use to make better 3D, animation, UI and effects (2026-11-13)

The developer's complaint, 2026-11-13: what gets built is "five cylinders and some blocks", then not looked at again.
They asked for a better toolchain: real 3D models, better animation, UI, effects. This page records what was checked
(each claim below was looked up, not taken from memory), what was installed, and what is still to do.
Weapons, not blocks: the whole point is that a weapon is a modelled mesh from Blender, not parts put together.

## The tools the developer named, and what is true of each

| Asked for | What it really is | State |
|---|---|---|
| **Roblox Studio as an MCP server** | Real and official, built into Studio (Assistant Settings > MCP). Docs: create.roblox.com/docs/studio/mcp | **Already connected** (both places). `asset:read` + `asset:write` Open Cloud scopes are granted (probe returned 200). Whether an upload FOLDER is approved is not known (cannot be probed). |
| **Blender MCP** | Real: `ahujasid/blender-mcp`, now renamed **`mcp-for-blender`** (MIT, third party, "not made by Blender"). A Blender add-on opens a local socket; the MCP server relays to it. | **Installed**: Blender 5.3.0 (winget, installer hash verified), uv 0.13.8, the add-on `blender_mcp.py` enabled in Blender's preferences. MCP registered for THIS project only (`claude mcp` local scope) with `DISABLE_TELEMETRY=true` and `BLENDER_MCP_SAFE_MODE=1`. Its tools appear after the session is restarted; Blender must be open with the server started. |
| **Best UI tool** | There is no single "best". The fit with Studio is **Figma**: the Studio tool `upload_image` is written to take Figma MCP asset links. Community Figma-to-Roblox plugins exist (UILint v2, Figma Importer Assistant, others) but are unvetted third-party code. | **Not installed**: Figma's connector needs the developer to sign in (`/mcp`, plugin `design:figma`); Claude cannot do that. |
| **"Roblox Agent Skills", the `scenario...-labs/skills` repo** | The name was heard as "script labs": it is **`scenario-labs/skills`** (MIT, an OpenSSF scorecard, 62 releases). 14 Roblox and 15 Blender "expert" skill families, written from ~200 expert videos and run live in Studio 0.743. Also `gamedev-skills/awesome-gamedev-agent-skills` (Apache-2.0, about 375 stars; a `roblox-luau` skill). | **Installed** 14 skills from commit `94cab3f` (2026-11-11) into `~/.claude/skills`: roblox expert, animation, assets, vfx-audio, environment, gameplay, ui; blender expert, hard-surface, export, texturing-shading, uv-baking, rigging, animation. Read first: no network calls, no instructions aimed at the reader; their Python helpers only call local programs and are written for macOS (they were never run on Windows), so the value is in the written procedures. The second repo was not installed (overlaps). |
| **Context7 MCP** | Real (Upstash, `upstash/context7`). It is NOT "faultless code for movement and combat": it is a **documentation lookup**. It does index Roblox: `/roblox/creator-docs`, `/websites/create_roblox_reference_engine` (engine API), `/websites/create_roblox`. | **Added** (remote, no key, this project only). Studio's own `http_get` also reads the official docs, so it is a second way, not a new power. |
| **VFX Studio (Creator Store plugin)** | **No plugin by that name was found.** Real ones: VFX Editor (open source, `VirtualButFake/vfx-editor`), Sine VFX (paid), VFX Forge (sold on itch.io, obfuscated code), Beziers. | **Not installed.** A plugin runs with Studio's permissions; most are paid or obfuscated. Effects are written in code (as the rest of the game) with the `scenario-roblox-vfx-audio` skill. If a hand-tuned particle editor is wanted: VFX Editor, because its source can be read. |

## Found while looking, worth more than some of the above

- **Studio now has its own AI tools** (the same MCP): `generate_mesh` (a textured mesh from words, 12 to 20,000 triangles),
  `generate_procedural_model`, `generate_animation` (R15, from a sentence), `generate_material`, `generate_texture`,
  `segment_mesh`, `generate_scene`. And 13 official skills (`rbx-*`), among them **`rbx-import-asset`**: the road from
  Blender to Studio (export GLB, upload with Open Cloud, insert, then check scale, colours, orientation, anchoring).
- **Blender can run with no MCP at all**: `blender --background --python script.py` (this is how the first sword was made).
  The MCP adds a live window. Both work.
- **CC0 sources** (no licence trouble) are the safe way to get surfaces: Blender MCP reads Poly Haven (about 2,400 HDRIs,
  textures, models). Other free packs exist; check each licence before using one.
- Importing animation from Blender: the Blender rig exporter / animation importer (DevForum thread) exists; reports of a
  broken update in August 2026. Not tried.

## The road for a weapon (what the first sword proved)

1. Model in Blender with a script (`tools/blender/make_sword.py`): 1 Blender unit = 1 stud; one object and one material per
   part (Roblox makes one MeshPart per material); the weapon runs along +X from the grip's middle (the kit's own rule).
2. Export GLB (Y up), look at a render (the script writes two).
3. **Upload only after the developer has seen it**: an upload is a permanent asset on their account (Open Cloud cannot
   delete it; only the Creator Dashboard can). `rbx-import-asset` then inserts it and checks scale, colour, orientation.
4. Roblox limits: a mesh over 20,000 triangles is refused, so is a bad texture; colours often arrive grey and need
   setting on the MeshPart.

The first sword (`tools/blender/make_sword.py`, version 2 after the developer said "improve it first"): 4 parts (Blade
2,366 triangles, Guard 740, Grip 2,236, Brass 910) = **6,252 triangles**, 5.06 x 1.52 x 0.44 studs. A lens-section blade
with a ricasso and a fuller that dies out before an ogival point; a guard with a central boss, arms that sweep toward the
point and domed ends; a grip wound with a real helical cord; two brass ferrules; a wheel pommel with a peen. Version 1
(1,560 triangles) read as "a sword-shaped thing": flat-cut guard ends, a kink before the point, a grip with no wrap, and
steel that rendered black because nothing round it could be reflected (the render set now has soft boxes and a horizon).
It is a PROGRAMMED draft, not a sculpted piece: right shape, no wear, no scratches, no texture. NOT uploaded, NOT in the
game.

## Things that went wrong, and the fixes

- `claude mcp add ... -- cmd` loses the `--` in Windows PowerShell 5.1: run it from Git Bash.
- uv's own Python 3.11 failed on this machine ("missing target directory for the minor version link"): the broken
  link was removed and the MCP is given the interpreter by full path (`UV_PYTHON`).
- Blender's first run creates its add-ons folder; `mcp-for-blender install-addon` finds none before that.

## Still to do (ask the developer)

- Approve an upload folder in Studio (Assistant Settings > MCP Permissions) when the first real upload is wanted.
- Sign in to Figma (`/mcp`) if the UI is to be redesigned from Figma.
- Restart the session once so the Blender and Context7 tools show up.
- Decide: upload the sword and wire it in as `starter_sword`? (It would replace the developer's own model there.)
