# The Last Kingdom — Presentation: Art, Audio & UI (Design)

**Status:** **Active — the Art Direction pass.** The look was **locked on 2026-10-17** (§1). Art
runs alongside the gameplay phases; it is no longer "Tier 3, deferred".
**Serves:** `../GameDesignDocument.md` §1.2 (Pillar 1 — Atmosphere Above Everything), §5
(Tier 3 — Polish).
**Source of truth:** the GDD vision for *why*; this file for *what the game looks like*; and
`configs/Look.luau` for the numbers.

> Migrated here from the old GDD §16 (Art Direction), §17 (Audio), §18 (UI/UX). Atmosphere is
> a **vision pillar** (kept in the GDD); the detailed art/audio/UI **direction** lives here.

---

## 1. The Style Bible — LOCKED 2026-10-17

### 1.1 What was decided

| Decision | Choice | Why |
|---|---|---|
| Base look | **Look A — "Dark Realistic"** (`DarkRealistic` in `configs/Look.luau`) | Reads as grim medieval and keeps the camp legible to play in. Look B (violet sunset) had the better sky but turned the ground orange. |
| References | Mordhau, Kingdom Come, Vermintide | A cold, overcast, desaturated world where the only warmth is fire. |
| Both places | One look family. The Hub is that world at dusk; the Forgotten Lands will be **the same world at a darker hour** (own preset, not started). | Two places that could drift apart by accident are one place with a bug. |
| Borrowed later from Look B | Moon, stars, violet glow on the horizon | Worth trying; **not locked**. |

Evidence: `assets/Images/Reference/look-ab-test_2026-10-17.jpg` (before / A / B) and
`assets/Images/Reference/look-a-ground_2026-10-17.jpg` (before / A / A with the painted ground).

### 1.2 The rules

1. **Warm light comes from fire and lamps only.** Sun and sky are cold and overcast
   (`ColorShift_Top` is near neutral, `Ambient` is blue-grey). If something looks orange and
   there is no flame near it, something is wrong — in the first A/B test the orange ground
   was lanterns, not sun.
2. **Nothing neon, nothing pure white.** The grade is `Saturation −0.28`, `Contrast +0.18`.
   The only things allowed to bloom are real light sources (`Bloom` threshold 1.6), and there
   is **one** Bloom effect: the second one in the old Hub doubled every glow and is off.
3. **Distance dissolves.** `Atmosphere` density 0.42, haze 2.2, and a heavy cloud deck
   (`Clouds` cover 0.82). The horizon is fog, never an edge.
4. **Never use `Sand` terrain.** Its rippled texture reads as desert whatever colour it is
   painted. The ground vocabulary is below.
5. **Judge a scene with the lamps at runtime strength.** Studio lights are hand-placed at
   stock values, two to three times what the game runs at (`LightService` retunes them from
   `configs/Hub.luau`). Turn on `tools/PreviewRuntimeLights.luau` to look, and turn it **off**
   before saving.

### 1.3 Palette

| Role | Colour | Hex |
|---|---|---|
| Earth (`Ground`) | 84, 74, 62 | `#544A3E` |
| Wet earth (`Mud`) | 52, 44, 38 | `#342C26` |
| Paving (`Cobblestone`) | 124, 120, 110 | `#7C786E` |
| Weeds (`Grass`) | 66, 82, 44 | `#42522C` |
| Stone (`Rock`) | 74, 74, 78 | `#4A4A4E` |
| Sky haze (`Atmosphere.Color`) | 164, 170, 182 | `#A4AAB6` |
| Horizon (`Atmosphere.Decay`) | 88, 92, 102 | `#585C66` |
| Shadow fill (`OutdoorAmbient`) | 58, 62, 74 | `#3A3E4A` |
| Lamp light (`Hub.Lights`) | 255, 186, 112 | `#FFBA70` |

The paving is deliberately a clear step **lighter** than the earth: the roads are how a
player finds their way, so the cross of roads must still read from the air.

### 1.4 The ground — vocabulary and meaning

Painted by `tools/PaintGround.luau`; every material says something about the place.

| Material | Where | What it says |
|---|---|---|
| Cobblestone | The roads, and only the roads | Someone built this, once. |
| Mud | Lane edges, shores, damp patches | Everything that walks the road tramples it. |
| Ground | Everywhere else | Packed earth. |
| Grass (3D blades) | Along the fence; patches outside it | Nobody has swept in forty years. |
| Rock | Rare, small | Loose stones. |

The road's **shape is authored** and is never changed by a tool — only what it is made of.
`PaintGround` can be undone exactly (`MODE = "restore"`).

### 1.5 The fence and the boundary

**The chain-link fence stays.** It is the developer's own work. A tall palisade of sharpened logs
was tried on 2026-10-17 and rejected (too tall, not wanted): do not propose it again unless
asked. The fence is not what keeps players in. The boundary is.

The boundary is an **invisible wall, 50 studs high and 4 thick** (`tools/BuildBoundary.luau`, in
`Lobby.Invisible.Boundary`), on one closed outline:
- the fence's three sides (west, south, east), on the fence's own lines;
- across the gaps beside the train on the north, at the fence's north ends;
- a pocket round the train and the wagons, 6 studs (about 1.7 m) outside them, so the rake stays
  in the playable area and a player can still walk round its ends.
The walls stand *outside* that outline, so nothing protrudes into the camp.

Rules:
- **Invisible to the camera.** `Transparency 1` and `CanQuery false`: the default camera only pulls
  in for opaque, collidable parts it can raycast to, so a player can zoom out past the wall. Only
  the character's body is stopped. (It also means no gameplay raycast ever hits the wall.)
- The chain-link's own parts are opaque and collidable, so on the three fence sides the *fence*
  still pushes the camera in, as it always did. If that is unwanted, turn off the fence's
  `CanCollide`: the boundary already stops the player there. Decided 2026-10-17 to leave it as it
  is; revisit only if it bothers play-testing.
- `MODE = "verify"` proves the wall closed. Run it after any change to the fence or the train.

### 1.6 Telling the story with props (a starting rule, to be proven in the set-dressing pass)

The Hub is *the last kingdom standing*: safe, but under siege. Dress it so a player can read
that without a word — barricades, boarded windows, scorch marks, torn banners, an overturned
cart. As a starting density: from any point on a road, every 10 × 10 stud patch in view should
hold **at least three** things that belong to someone. Revisit once there is real set dressing.

### 1.7 How to work on the look (and not lose it)

- **Rojo does not own Workspace, Lighting or Terrain.** The look lives only in the Studio
  place. **Save a backup `.rbxl` before large changes**, and save/publish after each batch.
- Look data: `configs/Look.luau`. Apply it: `tools/ApplyLook.luau`. Paint the ground:
  `tools/PaintGround.luau`. Close the camp: `tools/BuildBoundary.luau`. Judge it:
  `tools/PreviewRuntimeLights.luau`. Each tool's header says how to run it.
- `Lighting.Technology` (Future) and `MaterialService.Use2022Materials` could not be read by a
  script from Studio's MCP context, so treat them as set by hand in the Properties panel. Both
  places are on Future.
- Screenshot from **fixed cameras** before and after every batch: plaza from above
  `(0,42,110)→(0,4,20)`, plaza at player height `(0,8,60)→(0,6,0)`, smithy `(-18,9,48)→(-53,8,20)`,
  houses `(8,10,38)→(57,14,75)`.

### 1.8 Known placeholders

Tracked in `../Todo.md` (Art Direction pass): the four beige train wagons, the flat horizon
with one dead tree repeated, the blocky lantern posts, and eight spare lantern posts parked
outside the south fence.

## 2. Audio

- Ambient, atmospheric score; **silence used deliberately** for tension.
- Diegetic sound cues for discovery, danger, and events.
- Wave/boss moments backed by escalating music.
- Audio assets uploaded via Studio Asset Manager, referenced by `rbxassetid://` from config
  modules (per `../../CLAUDE.md`).

## 3. UI / UX

- **Medieval, diegetic UI** throughout (parchment, iron, wax-seal motifs).
- Key screens: Hub menus (inventory, upgrades, quests, party/mission select), field HUD
  (objective, health/stamina — minimal by design for immersion), death parchment
  (`DeathSystem.md` §3), lore codex.
- HUD stays **minimal in the field** to preserve immersion.
- The UI takes its palette from §1.3 (`scripts/Client/UI/Theme.luau` is where it lives); aligning
  the two is part of the Art Direction pass, not done yet.

## 4. Related

`DeathSystem.md` (death UI) · `Missions.md` (HUD objectives, lore codex) · `../GameDesignDocument.md` (§1.2 Pillar 1) · `../../configs/Look.luau`
