# Tooling: what we use to make better 3D, animation, UI and effects (2026-11-13)

The developer's complaint, 2026-11-13: what gets built is "five cylinders and some blocks", then not looked at again.
They asked for a better toolchain: real 3D models, better animation, UI, effects. This page records what was checked
(each claim below was looked up, not taken from memory), what was installed, and what is still to do.
Weapons, not blocks: the whole point is that a weapon is a modelled mesh from Blender, not parts put together.

## The tools the developer named, and what is true of each

| Asked for | What it really is | State |
|---|---|---|
| **Roblox Studio as an MCP server** | Real and official, built into Studio (Assistant Settings > MCP). Docs: create.roblox.com/docs/studio/mcp | **Already connected** (both places). `asset:read` + `asset:write` Open Cloud scopes are granted (probe returned 200). Whether an upload FOLDER is approved is not known (cannot be probed). |
| **Blender MCP** | Real: `ahujasid/blender-mcp`, now renamed **`mcp-for-blender`** (MIT, third party, "not made by Blender"). A Blender add-on opens a local socket; the MCP server relays to it. | **Installed**: Blender 5.3.0 (winget, installer hash verified), uv 0.13.8, the add-on `blender_mcp.py` enabled in Blender's preferences. MCP registered for THIS project only (`claude mcp` local scope) with `DISABLE_TELEMETRY=true` and `BLENDER_MCP_SAFE_MODE=1`. Checked by starting the server by hand: it answers and lists 10 tools (`execute_blender_code`, `get_scene_info`, `look`, `generate_3d`, `search_assets`, `import_asset`...). Its tools appear in Claude after the session is restarted; Blender must be open with the server started. |
| **Best UI tool** | There is no single "best". The fit with Studio is **Figma**: the Studio tool `upload_image` is written to take Figma MCP asset links, and Figma's own MCP (`mcp.figma.com`, tools `get_design_context`, `get_screenshot`, `get_variable_defs`...) is in Claude's registry. Community Figma-to-Roblox plugins exist (Figma Importer Assistant v2.0.2, 2026-07; UILint v2) but are unvetted third-party code and were not installed. | **Offered, not connected**: a Connect card was shown; Figma needs the developer to sign in (card, or `/mcp`, plugin `design:figma`). Claude cannot do that. There is also no Blender connector in the registry: Blender goes by the config above. |
| **"Roblox Agent Skills", the `scenario...-labs/skills` repo** | The name was heard as "script labs": it is **`scenario-labs/skills`** (MIT, an OpenSSF scorecard, 62 releases). 14 Roblox and 15 Blender "expert" skill families, written from ~200 expert videos and run live in Studio 0.743. Also `gamedev-skills/awesome-gamedev-agent-skills` (Apache-2.0, about 375 stars; a `roblox-luau` skill). | **Installed** 14 skills from commit `94cab3f` (2026-11-11) into `~/.claude/skills`: roblox expert, animation, assets, vfx-audio, environment, gameplay, ui; blender expert, hard-surface, export, texturing-shading, uv-baking, rigging, animation. Read first: no network calls, no instructions aimed at the reader; their Python helpers only call local programs and are written for macOS (they were never run on Windows), so the value is in the written procedures. The second repo was not installed (overlaps). |
| **Context7 MCP** | Real (Upstash, `upstash/context7`). It is NOT "faultless code for movement and combat": it is a **documentation lookup**. It does index Roblox: `/roblox/creator-docs`, `/websites/create_roblox_reference_engine` (engine API), `/websites/create_roblox`. | **Added** (remote, no key, this project only). Studio's own `http_get` also reads the official docs, so it is a second way, not a new power. |
| **VFX Studio (Creator Store plugin)** | **It EXISTS** (a web search said it did not; the Creator Store itself, opened in Chrome, shows it): free, by `@XxOmqxXNerd`, 95% of 800+ votes, 112 reviews, updated 2026-09-07, asset 135581141962270, described only as "AIO (soon to be) vfx tool". Same name, other makers or prices: VFX Studio Pro and Pro+ ($4.99 each), PRISM VFX Studio ($8.99), VFX Atlas Studio ($34.99), Studio To JJS VFX (free). Others: VFX Editor (open source, but last updated 2024-11), Sine VFX (paid), VFX Forge (obfuscated). | **Added to the developer's inventory on 2026-11-13** ("Get Plugin", free; the developer signed in, Claude never typed the password). Studio refuses `LoadAsset` of it ("Asset is not trusted for this place"), so its code could NOT be read first: it runs with plugin rights, so watch the permission prompts it raises (web access, script edits). It shows in Studio's Plugins tab after Studio is restarted: SAVE both places first (File > Save to Roblox), the synced scripts are not saved. Not yet opened or tried. |

## Extras the developer asked for ("2 to 4 more")

| Tool | What it is | State |
|---|---|---|
| **luau-lsp** (`JohnnyMorganz/luau-lsp`, MIT, 565 stars, release 1.70.1 of 2026-09-27) | The Luau type checker and linter from the command line: `luau-lsp analyze` reads the Rojo sourcemap and finds type errors without Studio. `CLAUDE.md` already says to run it when available. | **Installed** in `%USERPROFILE%\.luau-lsp` (downloaded from the GitHub release, 5.1 MB, sha256 `64225B97...8159F`). Run `tools\TypeCheck.ps1`. Baseline today: **932 warnings, none a real bug in the five distinct places checked in the 0.46 code**; use the number as a tripwire. It cannot open a path with Greek letters, so the script links the project under an ASCII path first. (The aftman route asked for "trust" first; not used.) |
| **Poly Haven** through the Blender MCP | About 2,400 CC0 HDRIs, PBR textures and models, importable from Blender with `search_assets` / `import_asset`. The way to get real surfaces instead of photographs on a block (the developer's wall complaint). | Comes with the Blender MCP (after the restart). |
| **Studio's own generators** (`generate_material`, `generate_mesh`, `generate_animation`, `generate_scene`) | In the Studio MCP already connected. | Available now; used in earlier passes for materials and meshes. |
| **Figma** | See the UI row above. | Needs the developer. |
| **Blender rig exporter / animation importer** (Creator Store plugin, FREE, with a Blender add-on) | Animate in Blender, bring the clip into Studio as an animation. Reports of a broken importer update in August 2026 (unconfirmed). Matters because our player clips are code-made: a real animation asset is the other road. | Seen in the store; not installed (needs the sign-in). Not tried. |
| **Moon Animator 2** | The usual keyframe tool of Roblox animators: **$19.99** at the official listing (seen 2026-11-13). The store also lists free copies tagged "[CRACKED]": pirated, never install them (a classic way to get a plugin that steals the account). | Not installed (paid, and the developer's choice). |

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

## Still to do (needs the developer)

- **Save both places, then restart Studio** so the VFX Studio plugin (already in the inventory) shows up. Try it on a scratch part first.
- **Connect Figma** (the card, or `/mcp`) if the UI is to be redesigned from Figma.
- **Restart the Claude session once** so the Blender and Context7 tools show up (they are registered; MCP tools load at the start).
- Open Blender and click Start MCP Server in its side panel when the live window is wanted (the headless route needs nothing).
- Approve an upload folder in Studio (Assistant Settings > MCP Permissions) when the first real upload is wanted.
- (Later, not now: the sword, bow and arrows. The developer, 2026-11-13: "not now, we will see them in the future".)

## A mistake of mine, corrected here

I wrote that no plugin called VFX Studio existed, from a web search. The Creator Store itself shows it. A search engine is
not the store: check the store.
