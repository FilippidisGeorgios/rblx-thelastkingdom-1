# Pipelines: how a thing gets from an idea to the game (2026-11-13)

The developer, 2026-11-13: "first we add the plugins, the connectors, the tools; then a good, complete structure; and only then
we start to build. The aim is capabilities, so that when we build we go all the way." This page is that structure. It says,
for each kind of thing the game needs, which tools make it, where the files live, how it gets onto Roblox, how it is checked,
and **what has really been tried** (VERIFIED) and what has not. `docs/Tooling.md` records the tools themselves and why each
was chosen; this page records how they are used together.

## Rules that hold for every pipeline

1. **A thing on Roblox has a line in `assets/manifest.json`.** An upload is permanent (Open Cloud cannot delete a model or an
   image; only the Creator Dashboard can), and some sources want a credit. `node tools/assets.js check` must say OK before a
   commit. The game still reads its ids from `configs/` (as `configs/ItemArt.luau` does); the manifest is the memory behind them.
2. **Look at it before it goes up.** A render (Blender), a capture (Studio) or a frame (Figma) is looked at and judged first.
   Version 1 of the first sword had a flat-cut guard, a kink before the point, no grip wrap and black steel; it was caught
   only because the pictures were looked at.
3. **Plain sources first.** Our own work, Roblox's own tools, CC0 (no credit). CC-BY only with the credit written in the
   manifest. Anything else (a marketplace model of unknown licence) is not used.
4. **Source files stay in the repository** (`assets/...`), so any asset can be made again. Only the finished thing is uploaded.
5. **The graphics rule still holds** (`docs/systems/Settings.md`): "Low looks low". Every new surface, effect and light must be
   something `Client/Controllers/GraphicsController` can take off or thin on Low. A pipeline is not finished until that is checked.
6. **Say what is tried.** Status words below: **VERIFIED** (done end to end and looked at), **PARTLY** (some steps done),
   **NOT TRIED**, **BLOCKED** (waiting for something, said which).
7. **Use the tools we installed, to the full (developer's order, 2026-11-14).** Before any task, read the tool list in
   `docs/Tooling.md` and say which tools (MCP connectors, Studio plugins, skills, Studio's own AI tools) this task can use. Use
   every one that fits; do not use one that does not fit. Do not build by hand what a tool makes better, and do not skip a tool
   from habit. The check is written in the task's plan (one line: "tools: ..."), and in the commit or changelog when it matters.
   Quick map: surfaces = Poly Haven + Studio `generate_material`; models = Blender MCP + the `scenario-blender-*` skills +
   Studio `generate_mesh`; rigs/animation = RigEdit Lite, Studio `generate_animation`, `scenario-roblox-animation`; UI = Figma MCP
   + `scenario-roblox-ui`; effects = VFX Studio + `scenario-roblox-vfx-audio`; sound = ElevenLabs; docs = Context7; builds and
   tests = Rojo, Luau LSP, F3X / ResizeAlign / Archimedes for hand edits in Studio, the two-player test.

## Where things live

| Folder | Holds | In git |
|---|---|---|
| `assets/Models/` | Blender sources and the exported GLB of each model, one folder per model, with its renders | yes (small) |
| `assets/Materials/` | the maps of each PBR material, one folder per material, with `SOURCE.txt` | yes (1k maps) |
| `assets/UI/` | exports from Figma (frames, icons) and the Figma file link | yes |
| `assets/Concept/` | concept pictures (Hugging Face image models), with their prompts | yes |
| `assets/Audio/` | sound files and where each came from | yes (small) |
| `assets/Animations/` | retired reference clips (`*_2026-08.luau`), and Blender animation sources | yes |
| `assets/VFX/` | flipbook sheets and the Blender scripts that made them | yes |
| `assets/Icons/` | icon sources | yes |
| `assets/manifest.json` | the register of everything uploaded or taken | yes |
| `tools/blender/` | the Blender scripts (`make_sword.py`, `StartBlenderMcp.ps1`) | yes |
| `tools/textures/` | texture fetch tools (`polyhaven.js`) | yes |
| `tools/assets.js` | the register's tool | yes |
| In Roblox: `ServerStorage.Assets.*` | hand-made models (Rojo never touches it); `MaterialService` holds material variants | the place |

## The pipelines

### 1. Materials (walls, floors, ground): Poly Haven, then a MaterialVariant

```
Poly Haven (CC0)  ->  tools/textures/polyhaven.js  ->  assets/Materials/<id>/{Diffuse,nor_gl,Rough}_1k.jpg
   ->  upload as Image (Open Cloud, group 32361153)  ->  MaterialVariant (ColorMap, NormalMap, RoughnessMap)
   ->  set on the parts of a wall  ->  capture, compare with before  ->  manifest + configs/Materials.luau
```
- **Status: PARTLY.** Search VERIFIED (673 hits for a castle wall); the fetch VERIFIED (`rock_wall_08`: three maps, 2.3 MB, CC0, with
  `SOURCE.txt`); upload **VERIFIED 2026-11-14** (the three maps went to group 32361153 as Decals, moderation Approved; the image id is
  read from the Decal's `Texture` with `InsertService:LoadAsset`, and the three are in `assets/manifest.json`). The MaterialVariant
  step is NOT TRIED.
- Check: the wall must read as stone from 3 studs and from 40 studs (the tile must not show a pattern); Low must still look like
  Low (a MaterialVariant is not a `SurfaceAppearance`: `GraphicsController` must be taught to thin it).

### 2. Models (props, weapons, the shield): Blender, then a GLB

```
script in tools/blender/ (bpy)  ->  renders looked at  ->  GLB (1 unit = 1 stud, +X along the weapon from the grip)
   ->  upload as Model (rbx-import-asset skill)  ->  insert, check scale / colour / orientation / anchoring  ->  manifest + config
```
- **Status: PARTLY.** Script to GLB VERIFIED (`tools/blender/make_sword.py`: 4 parts, 6,252 triangles, four renders looked at);
  upload and insert BLOCKED (same folder approval). Alternatives that exist: Studio `generate_mesh` (VERIFIED: the 20 item
  models of `configs/ItemArt.luau`), Hugging Face TRELLIS image-to-3D (Space found, NOT TRIED).
- Budget: weapons up to 6,000 triangles, props up to 3,000, nothing near the 20,000 limit. Roblox makes one MeshPart per material,
  so one material per part. Colours often arrive grey: set `MeshPart.Color` after the import.

### 3. UI: Figma, then Luau

```
Figma file (the game's look, mirroring Client/UI/Theme.luau)  ->  get_design_context / get_screenshot (Figma MCP)
   ->  Luau built on Theme and Components (the existing pattern)  ->  images through Studio upload_image  ->  device simulator
```
- **Status: PARTLY.** VERIFIED: the connector is connected; a Figma file was CREATED ("The Last Kingdom - UI",
  `https://www.figma.com/design/mkdySvVZEmrraFUJNsSYCp`, in the team "VynexGior Web's team", although the seat is shown as
  View); and WRITTEN to: a variable collection "TLK Theme" with the **28 colours of `Theme.luau`** (one mode, Dark; each variable
  names its Luau path, e.g. `Theme.Color.Gold`; explicit scopes). NOT TRIED: a screen designed and read back into Luau
  (`get_design_context`), the type ramp (Merriweather, Fondamento), the plate/edge components.
- The Figma MCP brings its own skills (`figma-use`, `figma-generate-library`, `figma-generate-design`, `figma-design-to-code`):
  read them before the first call of each kind, as the tool descriptions demand. `use_figma` calls must run one at a time.
- Next when building: the type ramp and the plates as styles/components in that file, then one screen end to end.
  House rule kept: edge buttons are a picture, no words.

### 4. Animation: code clips first, Blender for the hard ones

```
Shared/Anim/ClipPlayer + PlayerActionAnims (code)       <- VERIFIED in 0.46 (walk, run, roll, sword, spear, bow)
Blender (Rigify on, R15-named bones) -> tools/blender/export_clip.py (TO BUILD) -> the same ClipPlayer frames
Studio generate_animation (a sentence -> an R15 clip)   <- available, NOT TRIED
```
- Registered KeyframeSequence ids do not work outside Studio, and uploading animations has no Open Cloud route, so the game
  plays clips from code. The exporter (Blender action to `ClipPlayer` frames) is the missing piece that lets a real animation
  tool (IK, curves, onion skin) feed the game. **TO BUILD.**
- Check: `tools/PreviewPose` for one frame, a play test for the move, two players for what a friend sees (NOT DONE: see 9).

### 5. VFX: code first, flipbooks from Blender

```
ParticleEmitter / Beam / Trail in code (as the game does)  +  VFX Studio plugin (installed, no web access)
Blender script -> sprite sheet (flipbook: smoke, embers, slash arcs)  ->  upload Image  ->  ParticleEmitter.Texture
```
- **Status: NOT TRIED** (the plugin opens; the flipbook script is TO BUILD). Check: counts on Low (`GraphicsController` thins
  particles to a fifth), no effect visible to one player only.

### 6. Audio: ElevenLabs, then an upload

```
ElevenLabs connector (sound effects, music, voice)  ->  assets/Audio/  ->  upload Audio (moderation takes time)  ->  config
```
- **Status: BLOCKED for effects and music.** The ElevenLabs connector in Claude's list covers **voice and speech only** (its own
  tools say music, images and video need "the full ElevenLabs connector", `https://api.elevenlabs.io/v1/mcp`, added as a custom
  connector, which needs the developer's ElevenLabs account/key). Voice (the arrival scene's speakers, a herald) can be done now.
  Roblox audio uploads go through moderation: a sound may wait or be refused; never upload the same file again to get round a wait.

### 7. Concept pictures and icons: Hugging Face

`dynamic_space` runs image models (FLUX.1 Krea, Qwen-Image, edits with camera angles), background removal and speech.
**VERIFIED that the connector is signed in and lists them** (account `Filippidis`, free tier; `discover`, `view_parameters` and the
repository search work, and TRELLIS image-to-3D Spaces exist: `microsoft/TRELLIS`, `trellis-community/TRELLIS`). **BLOCKED: `invoke`
is switched off ("gradio=none" is set in the connector's headers)**; it needs the Gradio setting turned on for the connector
(huggingface.co/settings/mcp) or a connector URL that names a Space. A picture is NOT TRIED. Use: concept
art to judge a shape before modelling it, icon backgrounds removed for UI. Pictures made this way are `generated` in the manifest
and are never shipped without a human having redrawn or at least chosen and cleaned them.

### 8. Code quality

`tools/TypeCheck.ps1` (luau-lsp, baseline 932, a tripwire), the `TestService` specs (`TestRunner.run()`, 340), both Rojo builds
(`rojo build default.project.json`, `rojo build world.project.json`), `tools/mksync.js` + `tools/SyncFromBundle.luau` to carry the
scripts into an open Studio. **VERIFIED.** To add: a CI run of the builds and the type check on every push (GitHub Actions).

### 9. Testing what a second player sees

**VERIFIED (2026-11-13) and it found a real bug.** Studio's Test menu starts a local server; the MCP `start_stop_play` starts
one client only, so the second is added by hand (computer use). The recipe that worked:

1. In the place's Edit window: **Test > Start Test Session > Server and Clients**. It starts a SERVER window only (about 40 s;
   the screen may go dark grey while it loads).
2. In the Server window: **Test > Add Clients**; ~70 s later a client window "Place1" opens (`Player1`, userId -1). In THAT
   window: **Test > Add Clients** again for `Player2`. Each of the three windows is its own MCP studio id
   (`list_roblox_studios`, mode Play): `execute_luau` with `datamodel_type` Server for the server, Client for either client
   (`game.Players.LocalPlayer.Name` says which is which).
3. To end: **Test > End Session** in a client window (the MCP `start_stop_play false` does not end it).
- Edits made to the scripts in the Edit window do not reach a running session: end it, sync, start it again.
- Clicks sometimes fail with "UIPI" or only focus the window: take a screenshot and retry. All the windows run from the same
  Studio version folder, which must be the one in computer-use's allowed list.

**What it found.** A friend's head never turned (the waist did): `ClipPlayer.rig` took a body on as soon as its torso and hips
had arrived, and a neck joint whose attachments had not streamed in was left out for ever. Measured: Neck 0.0 degrees while
the sender looked 55 up (Waist 17.8). Fixed (`ClipPlayer.rig` counts joints and says `complete`; `BodyAnimController` looks again every
0.5 s until the body is whole; a spec builds the half-streamed body). Measured after: Neck 29.1, Waist 17.8, and a picture of
one player seen by the other with the head and chest tipped back.

Still to see with two players: a friend's roll, the spear thrust and sword cut from outside, the arrival scene on two screens.

## The capability matrix, today

| Can Claude... | Yes? | Through |
|---|---|---|
| write and test Luau in both places | yes | Studio MCP, `rojo`, specs, `TypeCheck.ps1` |
| see the game | yes | `screen_capture`, play sessions, computer use |
| search and fetch free PBR surfaces | yes | Poly Haven (Blender MCP, `polyhaven.js`) |
| model a prop or weapon and look at it | yes | Blender (script or live MCP), renders |
| put a file on Roblox | yes (3 textures uploaded 2026-11-14) | Studio `open_cloud_invoke` POST /assets/v1/assets, then read the image id from the Decal |
| read and write a Figma design | yes (a file and 28 tokens made) | Figma MCP |
| make a picture or remove a background | **blocked** | Hugging Face `invoke` is off (Gradio setting) |
| make a voice line | yes (connected) | ElevenLabs (voice and speech only) |
| make a sound effect or music | **blocked** | needs the full ElevenLabs connector with the developer's key |
| look up Roblox documentation | yes | Context7, Studio `http_get` |
| try a second player | yes, by hand (about 4 minutes) | Studio local server + 2 clients, computer use (found the head bug) |

**Upload folder: DONE 2026-11-14** (the developer approved it; the upload worked). The folder must stay approved; files are never copied elsewhere to get round it. A Decal upload gives a Decal id, not an image id: load it and read `Texture`.

## The order of building (each phase ends with its check, then a commit and a changelog line)

| Phase | What | Pipelines | Ends when |
|---|---|---|---|
| 0 | the two-player test and the upload folder | 9, 1 | a friend's head (DONE 2026-11-13), roll and thrust are seen from outside; one texture is on Roblox and in the manifest (waits for the upload folder) |
| A | surfaces: the castle's walls and floors, the Hub's ground | 1 | the castle reads as stone; Low still looks like Low |
| B | weapons: the sword, spear, bow, and the SHIELD (left hand) | 2, 4 | each is a real mesh, in the hand, with its clip; none made of parts |
| C | animation from Blender | 4 | one move authored in Blender plays in the game the same way |
| D | UI from Figma | 3 | one screen redone end to end and checked on a phone-size device |
| E | effects and sound | 5, 6 | the weapons glow, hit and sound; counts hold on Low |
| F | people and the dead (their looks and clips) | 2, 4, 7 | the undead's clips play in the live game (they may not now) |

## Definition of done for a thing

- It has a manifest line and `node tools/assets.js check` is OK.
- Its source is in the repository and can be made again.
- It was looked at: from the front, from the side, close, and at the distance the player sees it.
- It has been in a play session, on Low and on Ultra, and nothing was wrong.
- The numbers it needs (ids, sizes) are in a `configs/` file, not in code.
- `docs/` says what it is, `docs/Changelog.md` has its line, the specs and both builds pass, `TypeCheck.ps1` did not get worse.
