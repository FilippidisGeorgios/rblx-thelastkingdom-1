# TODO

## Done
- [x] Game Design Document authored (`docs/GameDesignDocument.md`)
- [x] Lobby / Kingdom Hub defined (`docs/Architecture.md` §2)
- [x] Gameplay loop defined (`docs/systems/Missions.md`)
- [x] Inventory scope defined (`docs/systems/Inventory.md` — detailed design deferred to the Inventory phase)
- [x] Progression scope defined (`docs/systems/Progression.md`)
- [x] Architecture + dual-place structure implemented (`docs/Architecture.md`)
- [x] Phase 2 core systems implemented (see `docs/Changelog.md` 0.2.0)

## Phase 2 wrap-up
- [x] Expand `docs/Story.md` — story canon locked (Asterfall, the 40-year return, the Fallen King, TLK2 seed).
- [x] Add a test harness for the pure domain modules (Match state machine, Party rules,
      ProfileSchema) — Architecture §10. Uses a dependency-free `TestService.Tests.TestRunner`
      (swappable for TestEZ later); run command documented in `CLAUDE.md`.
- [ ] Decide whether sensitive configs (`Loot`, `Economy`) move to a server-only location
      before real values land (flagged in `configs/README.md`).

## Before gameplay phases
- [ ] Lock the open questions now distributed across the system docs — `docs/systems/Economy.md`
      (revive economy, resource-on-death, extraction), `docs/systems/Combat.md` (combat model),
      `docs/systems/Missions.md` (world structure, hub depth), `docs/systems/EnemyAI.md` (wave
      triggering), `docs/systems/Multiplayer.md` (party persistence).

## Phase 3 — Combat (in progress)
- [x] Combat foundation: server-authoritative core (`CombatService`, `Health`, `CombatEntity`,
      `DamagePipeline`), factions, i-frames, damage types — see Changelog 0.3.0 & `docs/systems/Combat.md`.
- [x] Combat / Weapon / Enemy config *structure* (schemas only, no values).
- [x] Combat vertical slice: player swing → server validation → enemy damage → death
      (`PlayerCombatService`, `EnemyService`, `MeleeCombatService`, `HumanoidAdapter`,
      `CombatController`). TEST placeholders only — see Changelog 0.3.1.
- [ ] Author real combat / weapon / enemy balancing values.
- [ ] Real weapon models/animations (a visible equipped weapon).
- [ ] Client hit/health VFX & HUD (build on the `CombatEvent` bridge).
- [ ] Enemy AI, config-driven spawning, and waves (build on generic `EnemyService`; `ZombieService`).

## Phase 4 — Inventory & Equipment (in progress)
- [x] Item config structure (`configs/Items.luau`) + `Shared/Inventory` Enums/Types.
- [x] `Inventory` & `Equipment` domain classes (+ specs).
- [x] `InventoryService` (fleshed out) & `EquipmentService` (add/remove/equip/unequip).
- [x] Melee reads the equipped weapon (no hard-coded `starter_sword`); starter kit grants + equips it.
- [ ] Serialize inventory/equipment into the persistent Profile (`ProfileSchema`).
- [ ] Inventory/equipment UI + client interface (loadout in the Hub).
- [ ] Loot, crafting, shops, item stacking — later phases.

## Phase 5 — Enemy AI (in progress)
- [x] AI state machine (`EnemyBrain`: Idle/Chase/Attack/Return/Dead) + spec.
- [x] Detection / chase / attack / return, config-driven (`configs/Enemies` AI block).
- [x] Enemy attacks through the existing `CombatService` (no duplicate combat logic).
- [ ] Pathfinding / navmesh (currently straight-line kinematic movement).
- [ ] Enemy spawning system + waves (build on the generic `EnemyService`; `ZombieService`).
- [ ] Animations, ragdoll, and aggro/hit feedback.
- [ ] Multiplayer AI throttling / optimisation.

## Art Direction pass (alongside the gameplay phases)
- [x] A/B look test; **Look A "Dark Realistic" locked** (`docs/systems/Presentation.md`, `configs/Look.luau`).
- [x] Hub ground repainted: paving roads, mud, grass (`tools/PaintGround.luau`).
- [ ] Replace the train wagons — four flat beige blocks, the loudest placeholder in the Hub.
- [x] Hub boundary: an invisible 50-stud wall along the fence and round the train, closed and
      verified (`tools/BuildBoundary.luau`). The chain-link stays; a palisade was tried and rejected.
- [x] Chain-link collision: left as it is (decided 2026-10-17). The boundary stops the player on its
      own; the opaque chain-link still pushes the camera in on the three fence sides. Revisit only
      if that bothers play-testing.
- [ ] Walk the boundary in a real client (the playtest ran with Studio not rendering, so the camera
      itself was never seen moving): zoom out against the fence, the north shoulders and the train.
- [ ] The horizon is flat and repeats one dead tree. Vary the trees; add far silhouettes (hills, ruins).
- [ ] Eight `Lantern Posts` are parked outside the south fence at x ≈ −40, z 143–170, stacked two high
      (y 9 and 18) — most likely a storage row. Place them or remove them.
- [ ] The lantern posts (blocky, marble plinth) do not match the Tudor buildings. Restyle or replace.
- [ ] The roads read narrower than the old sand did (paving blends less). Widen the road voxels if play needs it.
- [ ] Set dressing that tells the siege story: barricades, boarded windows, scorch marks, torn banners, carts, hay.
- [ ] Light & VFX: fires, smoke, embers, window glow — with a mobile budget.
- [ ] Decide whether the runtime lamp values (`configs/Hub.luau → Lights`) are baked into the place, or
      whether `tools/PreviewRuntimeLights.luau` stays the way to judge it. Studio lamps are 2–3× too strong.
- [x] Forgotten Lands: the same look family at a darker hour (`ForgottenDusk`), the land outside the walls
      (`tools/BuildLand.luau`), the moat, bridge and surroundings (`tools/BuildSurroundings.luau`).
- [x] Forgotten Lands arrival scene (IntroService / IntroController / IntroUI, `configs/Intro.luau`).
- [x] Looked at it and tuned it from screenshots (2026-10-18): haze, clouds, exposure, water, shots, fires.
- [ ] Watch the intro once with real avatars in a playtest (the framing used stand-in figures), on a phone too.
- [ ] The red light in the last tower does not read from the hill: make the King's tower visible as the goal.
- [x] The castle itself: chambers furnished (`BuildChambers`) and lit (`LightCastle`), throne room in 9.
- [ ] The fallen tower in chamber 8 reads as a box from some angles; give the barrel more drums.
- [ ] Some houses' timber frames float a little off the ground where the yard is not flat; check up close.
- [ ] Performance: Forgotten Lands is ~29k parts, 164 lights, 214 emitters, StreamingEnabled off. Measure
      on a phone; `BuildChambers` DETAIL 3 → 2 is the first lever (~100 parts less per house).
- [ ] The torchlight is strong orange near the walls; if it reads too warm in play, drop the torches'
      brightness in `LightCastle` (2.8 → 2.2).
- [ ] Try Look B's moon, stars and violet horizon glow on top of Look A (try, do not lock).
- [ ] Compare the terrain with `MaterialService.Use2022Materials` on (set by hand in Properties).
- [ ] Align `scripts/Client/UI/Theme.luau` with the Style Bible palette.
- [ ] The Storyteller's real voice: ten clips uploaded and wired (`Interactions.luau → Lines[].Sound`).
      In both places and published (2026-10-18). Still to do: walk up to the Storyteller in a playtest and listen. Tune the holds
      (`Dialogue.HoldSeconds`) and, if a sentence sounds wrong, regenerate that one clip. The built-in
      TTS (`Dialogue.Voice`) only speaks lines that have no `Sound`; turn it off once all are voiced.

## Bigger castle, chambers 1–3 rebuilt (2026-10-19, Changelog 0.20.0)
- [x] Castle widened 25% both ways (`configs/Castle.luau`, `BuildBattleground` MODE "resize"); moat,
      land and surroundings moved out; AreaService/WinchService read the config.
- [x] Chambers 1–3 rebuilt by `tools/BuildWards.luau`: realistic timber/stone/thatch buildings you
      can enter and climb, generated PBR materials and mesh props, painted roads, lanterns, torches.
- [x] The dead follow the floor and route up stairs (EnemyAIService); 39/39 raised floors and doors
      route; a playtest had them climb the watch platform.
- [ ] Look at it with your own eyes in a playtest and say what reads wrong (scale, colours, density).
- [x] Chambers 4–6 rebuilt by BuildWards (Graveyard, Smithy, Great Hall; 2026-10-20, Changelog
      0.21.0). 62/62 stairs and 15/15 upper floors route in chambers 1–6; playtest boots clean.
- [ ] Look at chambers 4–6 in a playtest and say what reads wrong.
- [ ] Save to Roblox (not done: only when asked).
- [x] Chambers 7–9 rebuilt by BuildWards (the Rows, the Inner Ward, the Keep Steps; 2026-10-20,
      Changelog 0.22.0). All nine chambers: 111/111 stairs and ramps, 29/29 upper floors and decks,
      27/27 spawns, every chamber's way through; playtest boots clean.
- [ ] Look at chambers 7–9 in a playtest and say what reads wrong.
- [ ] Mechanics for areas 4–9 against the named scenery (AreaPlan): the grave braziers, the forge,
      torch + oil + the door that burns, trees → planks, the hall's four BoardPoints, the prisoner's
      chair, the buried passage, the sealed keep and the scribe.
- [ ] Props still to generate (asset quota ran out): Chest, Bucket. The straw dummy and weapon racks
      were refused by moderation — they are built from parts instead.
- [ ] Re-texture the pale crate mesh darker (`generate_texture` timed out once).
- [ ] The intro shots were framed on the old castle; watch the arrival again (the walls are wider).
- [x] Performance pass (2026-10-20, Changelog 0.23.0): StreamingEnabled on, buildings Atomic, shell
      Persistent, lights/emitters thinned by distance (`OptimiseCastle`, `DetailLodController`).
      Still to do on a real phone: measure FPS/memory; if it is short, set StreamingTargetRadius by
      hand (Properties; scripts cannot) to ~600 and thin shutter straps and thatch spars.
- [x] One of the forge's four open bays did not route: an anvil stood 1.6 inside it (moved, 2026-10-20).
- [x] Cottage upper floors were not reachable by the dead (the stair ran into the end wall); fixed
      in chambers 1–6 with landings, steeper stairs and doors swung back (2026-10-20).
- [x] Saved to Roblox (version "Castle widened 25%, areas 1-3 rebuilt", 2026-10-19). Not published.

## The dead, the arsenal, motion (design 2026-10-20, Changelog 0.24.0) — order set by the developer
Look and animation first; mechanics after. Each step ends in a playtest and screenshots.
- [x] Design: `Bestiary.md`, `Arsenal.md`, `Animation.md`.
- [x] First line-up of seven undead (`tools/BuildUndead.luau`); the sword clip drives the rig.
- [ ] **Developer decisions** (each doc ends with its questions): Hound yes/no, gore level, working names,
      the falling-star device, spoils, sword heavy attack, parry, roll, Oaths and mastery now or later.
- [x] Look pass 2 (v2, round limbs) and v3: the fine kit (`tools/BuildUndeadKit.luau`), 21 sculpted pieces on the bodies.
- [x] Field version of the kit (voxel x2): 8k–70k triangles a body; it is what the game spawns.
- [x] The dead in the game (Changelog 0.25.0): bodies cloned from `Assets.Undead`, attacks as windup/strike/recover,
      the cry of first sight, ZombieAnims + ZombieAnimController, falls on death. Verified in a playtest.
- [ ] Look at it in a real playtest and say what reads wrong (gaits, the cry, the falls, how long a corpse lies).
- [ ] Frame rate and memory with a full wave on a phone (the field bodies are 82–118 parts each).
- [ ] Types still on the plain box: cured villagers (a living look), the King (a placeholder shieldman), the
      Sexton, Cinder, Hollow Knight, Hound (Bestiary §5.2).
- [ ] Frost breath, Hollow Light pulse on aggro, death ash, impacts (Animation.md §7), and sound.
- [ ] Hit-stop and camera shake; the player's verbs (stamina, roll, guard, parry).
- [ ] Look pass 3: head pool (eight), dressings per chamber, damage states, gait variants, the missing types
      (Sexton, Cinder, Hollow Knight, King); judge at 40 studs in the real fog.
- [ ] `Shared/Anim/Clip.luau` (extract the sword file's builders, all joints) and a preview rig.
- [ ] `ZombieAnimController` + the attribute protocol; the shared and per-type clips.
- [ ] `EnemyService` clones from `Assets.Undead`; `Windup`/`Recover`, attack tokens, separation in the brain.
- [ ] Player verbs: stamina, roll, guard, parry, heavy; weapon models for the other weapons.
- [ ] Hit feedback and effects; sourced sound.
- [ ] Rebuild chambers 1–3 structures and add things to *do* in areas (Arsenal §8).
- [ ] Then the per-area mechanics (waves, wave-like events, tasks combined with waves).

## Trials and spoils (design 2026-10-21, Changelog 0.26.0) — chambers ask, the dead pay
- [x] Design: `Trials.md` (verbs, pressure, the nine chambers), `Spoils.md` (ranks, items, the backpack, co-op).
- [x] Items + Loot configs, `LootTable` (pity), `Backpack`, `BackpackService`, `LootService`, `BackpackHud`.
- [x] `TrialRun`, `TrialService`, verbs `light` and `toll`, pressure `rising`; chamber 4 runs as data.
- [ ] **Developer decisions** (end of each doc): the camp, chamber 3's five-or-three, deeds shown or hidden,
      the torch as a weapon, wipe penalty, the Tithe, personal loot, the shards, one charm or two.
- [ ] Look at chamber 4 with your own eyes: the graves opening, the torch in the hand, the flame, how long
      25 s feels, whether six graves a section is too many.
- [ ] Banking at the end of a won run: gold → profile currency, materials/relics/shards → `profile.stash`
      (ProfileSchema v3); the wiped-run rule.
- [ ] Pickup sound and a better pickup look; pickups rotate/bob (client only).
- [ ] Containers: a `search` verb generalised from the winch, `cache_*` tables on the stables' nine points.
- [ ] The camp (bench: bandage, arrows, oil pot, torch); the Hub's Tithe, Reliquary, Shard Altar, Journal.
- [x] Chamber 3: recipe, ingredients, the pot (minded), the pen, the five cured followers (Changelog 0.27.0).
- [ ] Look at chamber 3 by eye; tune: the cured die fast (more health? stay back from the front?), simmer 30 s, tide 7 s.
- [ ] A proper living head for the cured (now the skin union is tinted whole); their own lines/voices.
- [ ] Cured villagers should keep following through 4 to 6 and the gates must not trap them (check the portcullis passage).
- [x] Chamber 5: the forge and its tempers, the burned door, the woodyard and the mine (Changelog 0.28.0).
- [ ] Look at chamber 5 by eye; tune the forge (decay 55 s, pump .14, lines .70/.76/.82), the torch (50 s), the tempers.
- [ ] The pickaxe: open the veins in a real run and see it; a tree falling; the door mid-burn.
- [ ] Tempers for Point/Weight need the things they are for: armour (Arsenal §6) and stagger (poise).
- [x] Chamber 6: the pause, boarding with planks, the siege against barricades (Changelog 0.29.0).
- [ ] Look at chamber 6 by eye; tune: the 75 s pause, 150 health a plank, the wave sizes (113 dead for one player).
- [ ] Boards as a repair loop: a broken door in the middle of a wave, planks from the racks, a cooldown on rebuilding.
- [x] Chamber 7: the prisoner (held 20 s, retries), the walk to the gate, three letters (Changelog 0.30.0).
- [x] Chamber 8: the cut (pick, slip-back, frames), surges, the Hollow Knight and its armour, the mangonel, three papers (Changelog 0.31.0).
- [ ] Sounds for the work: pick on stone, rubble rolling back, the windlass's ratchet, the throw, plate. (No audio in the project yet.)
- [ ] More poses in `WorkPoseController`: the forge's hammer, the woodyard's axe, nailing a board, untying a rope.
- [ ] Look at the Hollow Knight's sweep and the digger from the front, in the real fog; tune the surges with two players.
- [ ] A sitting pose for the bound prisoner (and a living idle); his voice; the death branch seen once.
- [ ] Settle the run: pay the prisoner bonus (+5% gold) and bank (see the banking item above).
- [ ] Chambers
      8 (dig out), 9 (the King): each a Trials entry plus the verbs it needs (`gather`, `use`,
      `wait`, `read`, `defend`, `free`, `sequence`, `slay`).
- [ ] Add the Deeds and the Ambush to chambers 1 and 2 (Trials.md §5).
- [ ] Player verbs, weapon holding and the animation of the player's own kit (the developer's next topic).

## Chapter 1 — Vertical Slice (integration milestone)
- [x] `ChapterOneSliceService` orchestrator over existing public APIs (no rewrites).
- [x] Story Intro (start-once per player; survives respawn).
- [x] Exploration flow (visible markers + server distance detection) → Lore → Objective.
- [x] Scripted undead encounter via `EnemyService` (always-on test dummy turned off).
- [x] Completion via `CombatService.EntityDied` → symbolic reward → end → marker cleanup.
- [x] Pure state machine `ChapterOneSliceFlow` (`Server/Domain`) + spec.

### Slice tech debt / refactors (recorded — not scheduled)
- [x] ~~Reward is symbolic (narrative only)~~ — RESOLVED (0.9.0): `RewardService` grants
      currency + XP into the persistent profile.
- [ ] Single shared run / single-player assumptions (`encounterSpawned` / `encounterEnemies`
      / `encounterRemaining` are module globals) — needs per-run encapsulation for multiplayer.
- [x] ~~Slice uses its own per-player states instead of `Match`~~ — RESOLVED (0.7.0): the
      Mission System drives a `Match` lifecycle.
- [x] ~~Objective lives in the orchestrator, not as `Mission` data~~ — RESOLVED (0.7.0):
      objectives are data in `configs/Missions.luau`.
- [x] ~~No player-death UX (respawn far, no re-route)~~ — RESOLVED (0.10.0): DeathService adds
      death choices, revive, and total-wipe → Play Again.
- [ ] No timeout / failure path if the objective is never reached.

## Mission & Objective System (integration milestone)
- [x] Data-driven missions/objectives/chapters (`configs/Missions.luau`, `configs/Chapters.luau`,
      `Shared/Mission` Enums/Types), validated by `Server/Domain/Mission`.
- [x] Pure domain `Objective` + `MissionRun` (sequential activation/completion/fail) + specs.
- [x] World runtime `MissionRuntimeService` (drives a `Match`, streams `MissionEvent`) +
      `ObjectiveTrackers` (Reach/Kill/Survive/Interact full; Defend/Escort foundational) +
      `ChapterService` (auto-plays a chapter).
- [x] `EnemyService.spawn(enemyId, position)` generalised; client `MissionController` feed.
- [x] Chapter 1 replaced by data (`chapter_one_return`); hardcoded slice removed.

### Mission System tech debt (recorded — not scheduled)
- [ ] Reward is symbolic — grant through Economy/persistence (`systems/Economy.md`) later.
- [ ] Single active run / co-op share one run — multiple concurrent runs + wipe/leave handling.
- [ ] Defend/Escort foundational (minimal NPC; no attacker targeting/pathfinding).
- [ ] Objective HUD is client prints — real diegetic UI is Tier 3 polish.
- [x] ~~Objective spawns call `EnemyService` directly~~ — RESOLVED (0.8.0): Clear objectives
      run encounters via the Wave System.

## Encounter / Wave System (integration milestone)
- [x] Data-driven encounters (`configs/Encounters.luau`, `Shared/Wave` Enums/Types): spawn
      points, waves, spawn groups, sequential/parallel modes.
- [x] Pure `EncounterRun` conductor (wave progression/clearing/completion) + spec.
- [x] `WaveService.startEncounter` engine: spawn / track / advance / scale / cleanup + callbacks.
- [x] Difficulty scaling (`configs/Difficulty`, `Shared/Scaling`): count/health/elite/reward
      per player count (sub-linear). Elite/boss enemies (`undead_brute`, `fallen_champion`).
- [x] `Clear` objective ties Mission (WHEN) to Wave (HOW); Chapter 1 uses a 2-wave encounter.

### Wave System tech debt (recorded — not scheduled)
- [ ] Boss abilities/phases, spawn telegraphs/VFX (polish).
- [ ] Enemy pooling / perf for large invasions.
- [ ] Timed/triggered invasions beyond `startDelay` waves.
- [ ] `RewardMult` from scaling is computed but not applied yet (pending Economy).

## Progression & Rewards + Persistence (milestone)
- [x] Pure `Progression` (XP -> levels) + spec; `ProfileSchema` v2 (`xp`/`level`) + migration + spec.
- [x] `RewardService` grants currency + XP into the persistent profile (server-authoritative).
- [x] Real `DataStoreStore` (DataStoreService + retry) injected into `SaveService`; in-memory fallback.
- [x] Missions & encounters apply rewards (`reward` on mission + objective complete); client feed.
- [x] `configs/Experience` curve, `configs/Economy` gold, Chapter 1 real reward values.

### Progression tech debt (recorded — not scheduled)
- [ ] Cross-place session locking (DataStore dupe protection via UpdateAsync + lock token).
- [ ] Apply scaling `RewardMult` to reward amounts.
- [ ] Hub spend/upgrades + economy sinks; Loot/crafting.
- [ ] Replicate currency/level to the client for a real HUD (currently print-only).

## Death System (milestone)
- [x] `Shared/Death/Enums` + `Net` DeathEvent/RequestDeathChoice.
- [x] Pure `DeathGroup` (wipe / reviver / waiting) + spec.
- [x] `DeathService`: respawn ownership, death detection, 3 choices, spectate, self-revive
      (gold anti-P2W), free teammate revive, total wipe.
- [x] `MissionRuntimeService` wipe → mission fail; `ChapterService` Play Again (respawn).
- [x] Minimal client `DeathController`; `Economy.Revive` + `Settings.Death` config.

### Death System tech debt (recorded — not scheduled)
- [ ] Robux revive (MarketplaceService) alongside the gold path.
- [ ] Diegetic death parchment + spectate camera (Tier 3 polish).
- [ ] Real Hub teleport on "Back to Lobby" (needs the Multiplayer/teleport flow).
- [ ] Cross-place party re-formation for "Wait" survivors.
- [ ] Remove `Settings.Dev.StarterGold` before real content.
