## Version 0.30.0 — Chamber 7, the Rows: the prisoner, and three letters

- **The rescue (`Trial/Rescue`).** A villager is bound to the chair in the tavern (a living body, three coils of rope round
  him). Untie him with a held 20 seconds, **banked** across breaks and summed across players (two untie him twice as fast), the
  ropes falling away third by third, the prompt's ring always set to the time that remains. He is then a real unit
  (`prisoner_villager`: Players side, 90 health, does not fight) that follows the party; the task is done when he stands within 28
  studs of the passage out, alive. If he dies a second prisoner is found tied to the chair after 18 s, and a third; when those are
  spent the way opens and the bonus is lost. `RunModService` has **party flags** now: `prisonerAlive` is the +5% gold for the
  whole team at the end of the run (nothing settles the run yet, so the bonus is recorded, not paid).
- **The letters (`Trial/Letters`, a deed).** Three parchments in three houses (the clerk's last entry, a widow's letter to a man in
  the north, a child's drawing of the falling star), each opening as a page; all three read pays a Star Shard and a Mourner's Veil.
  `Read.place` is now the shared piece that lays a readable page on a table.
- **Followers cannot be lost (`EnemyAIService`).** A unit with `Follow` that is more than 80 studs from every player for 9 s, or that
  has wanted to walk and not moved for 6 s with nothing to fight, is put back beside the party. The test that found it: the freed
  prisoner stepped out of the tavern and stood on a stone corner block from which there was no route.
- **Indoors.** `EnemyService.spawn` and `spawnStatic` take an optional `floorY`: a ray dropped from above a room lands on its roof
  (the prisoner appeared eleven studs up in the first test).

**Checked in a playtest** (real prompts and keys): the chair with its ropes and the bound prisoner, the 20 s hold, his freeing,
the walk to the gate (after the fixes: he was put back beside the player when lost, and the trial completed with the flag
set); all three letters read and the prize in the pack. **Not checked:** the ropes falling away mid-hold by eye; the
death-and-second-prisoner branch; two players untying together; the dead going for him in a real fight; the new stuck rule
(only the far-away rule ran). The bound figure stands (there is no sitting clip yet) and shows the zombie idle.

## Version 0.29.0 — Chamber 6, the Great Hall: a pause, the doors, and the siege

- **The pause and the horn (`Trial/Siege`).** Walking into the hall no longer starts a wave. The trial gives 75 s (with a
  warning at thirty and at ten, in the world's terms: torches gathering, then moving), then a horn, then the chamber's
  encounter: three waves of spearmen, archers and the heavy ones (`configs/Encounters` `area_6`, rewritten for it).
  `ownsWaves` in the trial tells `AreaWaveService` not to start the old entry wave for this chamber.
- **Boarding (`Trial/Board`).** The hall's four `BoardPoint` doorways each take up to six planks, one per hold, built up
  from the sill; four seal a door. Planks are the ones carried from the woodyard (chamber 5); two racks of eight stand in
  the hall for a player who skipped it. Boarding is a deed (nothing waits on it); the gate rises when the siege is cleared.
- **A barricade is something the dead attack.** Each is a combat entity on the players' side with 150 health a plank (600
  sealed). The dead's rule is "go for the nearest thing that is not one of us", so they go for it: spearmen thrust, archers
  shoot, the heavy ones lean on it; when its health is gone it breaks (planks fly) and can be rebuilt. New in
  `EnemyAIService`: `approachPoint`: a model with `ApproachA` / `ApproachB` attributes is walked to by a standing place
  on one of its faces, not by its middle (a wall has no route to its middle), so the dead can besiege a door.

**Checked in a playtest** (real prompts, the keyboard tool): the racks and nail prompts, four planks sealing a door (600
health), all four doors sealed; at the horn 33 enemies came and the west door took 300 damage in about six seconds and broke
while the others held; the siege cleared in three waves (33, 31, 49 dead for one player) and the trial completed.
**Not checked:** the dead pouring through a broken door and the fight inside the hall by eye; arrows on boards; a second
player; whether 75 s is enough to fetch planks from the yard and nail four doors (probably not all four: that is the
intended pressure, and the racks make two possible); whether 113 dead for one player is too many.

## Version 0.28.0 — Chamber 5, the Smithy: the forge, the door that is burned, the woodyard, the mine

The third data-driven trial and the one the design calls the spike. Two jobs in any order, two deeds.

- **The forge (`Trial/Forge`).** Pump the bellows (hold E, again and again) to raise the hearth's heat; it bleeds away
  from full to cold in 55 s. Above the round's line (.70, .76, .82) the anvil takes a blow (hold 1 s); each blow costs
  38% heat. Three blows, then a **temper** at one of three stations, one per player: **Edge** +18% damage,
  **Point** +3 studs of reach, **Weight** +40% damage and a 35% slower swing. The coals brighten and the flame and
  light rise and fall with the heat, so the fire is the gauge (no number on screen).
- **`RunModService`** is new: per-player damage / reach / swing-time multipliers for the run, set by `set(player,
  source, mods)`, read by `MeleeCombatService` (the only edit to combat: three numbers around the weapon stats). The
  temper is its first source; relics and oaths will be others.
- **The door (`Trial/Burn`).** A timber door (16 planks, three iron straps, bracing) is built across the passage in
  front of the portcullis. Oil jars from the oil store (far west; two fit in your hands) are poured on it; an unlit torch
  from the rack is lit at the forge and burns 50 s (the carry to the far east is the clock, through the dead); held to the
  soaked door it catches, burns plank by plank and falls, and the gate rises.
- **Deeds.** `Trial/Chop`: the axe in the stump, six dead trees that fall over and give planks (the stack gives four more);
  12 planks pays a Sound-tier prize and the planks are carried to the Great Hall. `Trial/Mine`: eight veins in the
  adit, each rolled for whoever prises it (gold, iron, rarely silver); one hides the **pickaxe**, carried to the Inner Ward.
- New items (all carried, never banked): oil jar, unlit torch, axe, plank, pickaxe. `Torch.give` no longer empties
  your hands (a jar of oil stays when you take fire).

**Checked in a playtest** (real prompts, the keyboard tool): the forge through three rounds, the temper (Point: reach +3
confirmed in `RunModService`), oil jars, the torch from the rack, lighting it, soaking the door, the door catching and
falling, the axe, four trees and the planks deed with its prize, a vein opening and paying gold; the trial then completed.
Bugs found by playing, all fixed: (1) the forge's prompt text was rewritten every frame with the heat, which cancelled the
player's hold (a long hold needs a still prompt); (2) the anvil prompt was withdrawn the moment the heat crossed the line,
cancelling a blow already going down (now a 10% hysteresis); (3) the temper stations stood on top of the torch-lighting
prompt and the nearest prompt won; (4) the door's straps and braces did not fall with its planks.
**Not checked:** the pickaxe turning up (it is one of eight veins); a tree's fall seen by eye; the door burning seen
mid-burn (the capture came after); a second player; how the 55 s decay and the 50 s torch feel with real spearmen and
archers on you. Note: a ProximityPrompt's distance is measured from the player's camera in this engine build as well as
the character; keep MaxActivationDistance generous (>= 10) or a default camera will lose the prompt.

## Version 0.27.0 — Chamber 3, the Kitchens: the recipe, the pot, the five

The second data-driven trial, and the first that uses most of the verbs.

- **Read.** A parchment glows on the kitchen hall's table. Taking it up opens a page (`DocumentUi`, `DocumentController`,
  remote `DocumentEvent`): parchment on a dark veil, ink letters, the writer's name; it closes on Esc, E, a click, or
  the button. The recipe is rolled per run: four of seven ingredients (`Trial/Recipe`), so the same chamber is a
  different errand each time.
- **Gather.** Each ingredient is a small prop (sack, ham, herbs, bucket, crate, cask, crock) placed by looking, near the
  part of the kitchens it belongs to (`Trial/Place`, the winch's floor-and-clearance idea made shared). Carried as quest
  items: no pack place, never banked.
- **Cook.** Put them in the pot in the kitchen hall; it then simmers for 30 s **only while a player is within 22 studs**
  (steam sinks and the clock waits otherwise), and the smell draws the dead (`Trial/Tide`, started by the "simmer"
  signal, stopped when the phase ends). Then it gives five ladles of broth.
- **Feed.** A pen of stakes and rails is built at runtime on open ground (a gap faces the pot); five of the dead stand
  in it as brainless static bodies (`EnemyService.spawnStatic`: no combat entity, so they cannot be killed or chase).
  A ladle to each cures it: the body is swapped for a real `cured_villager` (or `_bow`) and it speaks.
- **The cured** look alive: `EnemyService.livingTint` turns the skin to a living tone and hides the curse's marks (eye
  glow, neck cords, veins, blotches). They are Players-faction, fight the dead, and **follow the party**: a new AI
  option `Follow` (`EnemyAIService`) makes a unit with nothing to fight walk to the nearest player and stop 9
  studs short (checked: two archers ran 150 studs to catch up and stood 9-12 studs away).
- **TrialService** learned: `ctx.shared` (a bag the tasks share), `ctx.hint` (a task's own top line), `ctx.signal`
  (starts pressure on an event), `untilPhase` (pressure that ends with a phase), `devDone` (a test hook).

**Checked in a playtest** (real prompts held with the keyboard tool; a temporary test script, removed): read → page
opens; gather four → phase advances; add to the pot → it simmers, enemies stream in; the pot waits while the player is
dead or away and resumes; five ladles; all five cured; the trial completes and the gate rises; followers catch up. No
console errors. A bug found by playing: one penned slot named `undead_shambler_scullion`, which is a body, not an enemy id,
so it had no body and swallowed a ladle: fixed, and a slot with no body now never spends one.
**Not checked:** the cooked broth's look, the pen in daylight, the cured at close range in the real fog, a second
player, how fast the cured die (the waves and the tide keep coming; they died in about half the runs).

## Version 0.26.0 — Spoils, the backpack, and the first data-driven trial (the Graveyard)

Design first (`docs/systems/Trials.md`, `docs/systems/Spoils.md`), then the first slice of each, checked in
a playtest.

**Spoils.**
- `configs/Items` now holds the catalog of what the dead leave: seven materials, four consumables, six
  relics, the star shard, the torch; each with a rank (Worn / Sound / Hallowed / Relic), a use line, a
  flavour line and a pickup look. `configs/Loot` holds the ranks, the rules and the drop tables (the
  dead by enemy id; containers; deed prizes).
- `Domain/LootTable` is the roll: gold scaled by depth and party, independent material chances, Sound and
  Hallowed rolls with **pity** (30 kills without a Sound-or-better drop forces one; 120 without a
  Hallowed upgrades the next Sound). Simulated 2000 kills: 3.2% Sound, 0.8% Hallowed, longest dry spell 30.
- `Domain/Backpack` + `BackpackService`: a pack of 16 places per player per run, gold as a counter,
  quest items carried in the hands (no place, never banked); `bankable()` says what survives a won or a
  wiped run (banking itself is not wired yet). New remote `BackpackEvent`.
- `LootService`: every kill is rolled for each player within 70 studs and the drops are **personal**: a
  part per drop with an `Owner`, hidden by `LootController` on every other client. They pop, lie, slide
  to the owner at 9 studs and are taken at 3; a full pack leaves them (and says so); they fade after 90 s.
- `BackpackHud`: the pickup log bottom right (rank-coloured, a Sound find also gets its flavour line),
  a gold line, and the pack panel (button, or `B`) where every row says what it is for.

**Trials.**
- `Domain/TrialRun` (pure, spec-tested): phases in order, tasks `all` / `any` / `count`, deeds that never
  gate. `configs/Trials` is the data; `TrialService` runs it (grace, tasks, pressure, the top line, the
  gate) and each verb is a module under `Server/World/Trial/`.
- **Chamber 4, the Graveyard, is the first trial.** Carry fire from the chapel altar to four braziers; a
  torch burns 25 s (its flame is the clock), lights one brazier and is spent, and a lit brazier is itself a
  source. Each section's graves keep giving up the dead (`Rising`: six graves a section, a pulse every 9 s,
  capped, scaled by party and depth, every fourth pulse a Gravedigger) until that section's brazier burns.
  The deed — toll the belfry bell — brings the hardest hour and pays Grave Silver and a Saint's Medal.
- Chambers 1 and 2 are untouched (their own services still call `AreaService.clear`).

**Checked in a playtest** (real server modules; a temporary test script, removed): 139 specs pass; a kill
rolls drops for the player, the magnet and the take work, the log, the gold line and the pack panel draw;
the real prompts gave a torch (hold E at the altar) and lit brazier 2 (hold E), then the other three; the
trial completed and the gate rose; the bell brought its answer and its prize fell. No errors in the
console. **Not checked:** the dead climbing out of graves was seen only in counts, not by eye; the
torch in the hand and the brazier flame were seen once (the flame was too tall: 13 → 9); phone frame rate
with a full chamber; the camera keeps losing the player in the dark chapel shot.

Notes: the pickups are server parts with per-client hiding; at 90 pickups the oldest goes. Roblox's
`Humanoid.Health = 0` does not kill a combat entity: damage it through `CombatService`.

## Version 0.25.0 — The dead are in the game: bodies, motion, and attacks you can read

Until now no zombie body and no zombie animation had ever been in the game (the unit was a red box).
Now:
- **Bodies.** `EnemyService` clones a sculpted body from `ServerStorage.Assets.Undead` when the unit's
  config names one (`Body` in `configs/Enemies`: the shambler picks a guard or a scullion, the others
  one each; the King wears the shieldman as a placeholder). Units with no `Body` (the cured villagers,
  the training dummy) keep the box. The body is tagged `TLK_Undead`, Atomic for streaming, and carries a
  gait `Variant` 1–3 for life.
- **Field kit.** The fine kit (80k–420k triangles a body) is too heavy for a wave, so the game uses the
  same shapes at twice the voxel size (`tools/BuildUndeadKit` `QUALITY = "field"`; 8k–70k triangles a
  body, 82–118 parts). The fine kit is not kept in the place; rebuild it with `QUALITY = "fine"` for
  close-ups (it takes several minutes, in batches).
- **Attacks are windup → strike → recover** (`EnemyAIService`, numbers in each enemy's `AI` block:
  `Windup`, `Strike`, `Recover`). The body stops and faces you, keeps turning for the first 65% of
  the windup, then locks; damage lands at the strike on whoever is still within reach and in front.
  Step out and it hits air. The first time it sees you it stops and cries out (0.9 s) before it chases.
  Shambler 0.8/0.15/0.6, runner 0.45/0.2/0.5, gravedigger 1.1/0.18/1.3 (stuck), pikeman 0.8/0.14/0.7,
  archer 0.9/0.1/0.5, King 0.9/0.2/0.8.
- **State on the model.** The AI writes `State` (Idle, Walk, Run, Aggro, Windup, Strike, Recover,
  Death), `Seq`, `Move`; `EnemyService` writes `HitCount` and `Fall`. Nothing is sent per frame.
- **Motion.** `Shared/Anim/ZombieAnims` authors the clips in code (idle, three walks, run, aggro, flinch,
  three deaths, six attacks built from the unit's own timings) in the same style and angle convention as
  the sword's; `Client/Controllers/ZombieAnimController` plays them on every tagged body, only within 170
  studs of the camera.
- **Death.** A killed body is not deleted: it falls one of three ways, lies 3.2 s and sinks. It leaves the
  combat registry at once, so nothing targets it.

Checked in a playtest (the real server modules, a harness script that was removed afterwards): spawn,
Idle → Aggro (0.9 s) → Walk, Windup → Strike → Recover cycles on every type, the player taking damage and
dying to four shamblers, kills producing the three falls with the body lying on the ground, the sculpted
spade, spear, bow and shield on the right bodies. Not checked: flinch seen with eyes, frame rate on a phone.

Notes: the dead notice you from further than I assumed (the wave starts from the east side of the
chamber, x = 157); `DetectionRadius` is unchanged. In the Studio MCP, `require` from `execute_luau` gives a
SEPARATE copy of every module (its AI never runs); drive the real game from a script placed in the
place, as the temporary harness did.

## Version 0.24.0 — The dead, the company's arsenal, and how they move: design, and a first line-up

**Design, before code** (the developer's order: look and animation first, mechanics after):
- `docs/systems/Bestiary.md` — *the dead keep their stations*: every enemy is a person of the fallen castle
  (cook, sentry, sexton, guard) doing their job wrongly. The curse has three tells (grave-wax skin, the
  Hollow Light in the eyes, frost breath) and the dead move out of rhythm. Asterfall's device is a falling
  star on bordeaux and gold. Roster: the five built types kept, five proposed (Shieldman, Sexton, Cinder,
  Hollow Knight, optional Hound), each asking the player a different question; chamber *dressings* so no
  two are alike; the King in three phases, ending in a release, not a kill (Story §8).
- `docs/systems/Arsenal.md` — movement (sprint, roll, kick, stamina), guard/parry/riposte, poise and
  finishers, damage *styles* (slash/pierce/crush against armour), nine more weapons and shields built
  around the four that exist, ranged, armour, and the run: forge tempers, spoils of the dead, Oaths,
  mastery, deeds, records. The sword stays the developer's two cuts and a guard.
- `docs/systems/Animation.md` — the sword work's rules promoted to house rules, the attribute protocol
  that drives the dead's clips, the clip catalogue, hit-feedback numbers, effects, sound list, budgets and
  the order of work with a "done when" for each step.

**Built:** `tools/BuildUndead.luau` builds seven undead masters (104–156 parts each) into
`ServerStorage.Assets.Undead` and stages a line-up outside the gate for a picture. v2 (the realism pass): round
limbs and ball joints, a real skull (cheeks, sockets, teeth, hanging jaw), fingers, exposed ribs, veins, decay,
torn strips for every hem, cloak and tabard, riveted and weathered metal, poses baked into the joints and the
body grounded on its lowest foot. A playtest proved that the developer's `SwordAnims` clip drives this rig
unchanged. **Nothing in the game uses these bodies yet:** `EnemyService` still spawns the red box, and no
zombie animation exists (the only animation in the game is the sword's).

**The fine kit (v3):** `tools/BuildUndeadKit.luau` sculpts 21 pieces from small cubes (0.02–0.03 studs;
~400k cubes in all) and fuses them by material into UnionOperations that keep every cube's colour: four heads,
three helmets and a coif, sword, spear, longbow, arrow, kite shield, spade, brigandine, hauberk, pauldrons,
vambraces, greaves, quiver. The bodies wear them. Heavy in triangles (80k–420k a body): a lighter field
version is the next step before the dead fight in waves (see `Bestiary.md` §10).

## Version 0.23.0 — Streaming and detail LOD: the nine chambers fit on a phone

The place was ~64k parts, ~495 lights and ~430 emitters with StreamingEnabled off: every client
downloaded and drew the whole castle. Measured in a playtest:
- **Streaming on** (`Workspace.StreamingEnabled`; a script can switch it on but cannot set the
  radii, so the defaults stand: 128 min / 1024 target, which a phone lowers by itself). A client at
  the hill held ~15k parts, at the gate ~34k, against 64k. Every building (each direct child Model of
  `Decorations.AreaN`) is **Atomic**, so a house arrives whole, never a floor without its wall; the
  Shell and the arrival pad are **Persistent**.
- **`tools/OptimiseCastle.luau`** sets all of that and tags lights and emitters `TLK_Lod`. Run it
  again after any build tool (it only sets properties and tags; MODE "undo" reverses it).
- **`Client/Controllers/DetailLodController`** switches tagged lights (120 studs) and emitters (150
  studs; x0.7 on a phone) off beyond that distance from the camera. At the gate the client held 262
  lights, 47 of them lit, and 239 emitters, 53 emitting. Mechanics that light or douse a fire set the
  attribute `LodWant` on it (see the controller's header). The red light in the last tower and the
  smoke seen from the hill are under `Surroundings` and are left alone.
- `IntroService`: when the party is put back at the gate, the body stays anchored until
  `Player:RequestStreamAroundAsync` says the ground there has reached that client (it was 800
  studs away a moment before); all players are placed at once.

Checked after the change: 111/111 stairs and ramps, 29/29 upper floors and decks, 27/27 spawns and
every chamber's way through still route (the server sees the whole world, streaming or not); the
playtest boots clean (14 client, 32 server modules), the intro runs, area 1 starts its first wave;
every script in Studio equals the file on disk (136 of 136).

## Version 0.22.0 — The Rows, the Inner Ward and the Keep Steps: all nine chambers built

**Chambers 7–9 rebuilt** by `tools/BuildWards.luau` (sections Area7–Area9). Every chamber of the
castle is now built by the one tool; see `docs/systems/ChamberThemes.md` for what stands in each.
- **7 The Rows**: two streets of seventeen houses, each written out by hand and none alike — eaves or
  gable to the street, one storey or two, jettied or not, thatch or shingles, washed in seven
  colours — with trade signs on iron brackets, water butts, dead flower boxes and bunting; the
  market square with its roofed cross, stalls and stocks; the market hall (stone arcade, guild room
  above) and the tavern, where the villager is tied to a chair; gardens, a privy, a hen house.
- **8 The Inner Ward**: the last line — palisade, gate, two breaches, a firing step you can climb,
  stakes, braziers; the field hospital, the command tent and its map, stands of spears, a broken
  mangonel, a burning cart; the marshal's house with a fighting deck; a pyre; and the tower that
  came down across the yard, its top the only high ground, reached by two slopes of rubble.
- **9 The Keep Steps**: the keep (68 × 56, parapet 72, turrets 84) with its door shut and barred at
  the head of a great flight of steps; kings in stone, a dry fountain, the guard's last ring, the
  royal carriage on its side; the treasury, the chancery, the guardroom, a knot garden gone brown.
- The places the area mechanics need are named: `PrisonerChair` (7), `PassageRubble` (8),
  `KeepDoor` (sealed) and `ScribeSpot` (9). The keep has no stair inside: nothing reaches the
  wall-walk until the ending opens it.
- Library: houses take a limewash colour (their gables follow it) and can hang their door on the
  right post (a door in an end wall must not lie across the stair foot); trade signs, bunting,
  flower boxes, the market cross, stocks, the prisoner's chair, tankards; palisades, stands of arms,
  a mangonel, cots, rubble slopes, a fallen tower; statues, a fountain, a knot garden, the keep and
  its great stair.

**Fixed while building**: a tavern table behind each door made a funnel the pathfinder would not
pass (the left half of the floor was cut off); a sack at a stair foot; a paving edge 0.12 proud of
the keep stair's head shut the landing off (the same kind of lip as the gallery's). A rolled drum of
the fallen tower may sit a little untrue: the walking surface is an invisible deck over it.

**Verified in Studio**, all nine chambers: 111/111 stairs, ramps and door steps and 29/29 upper
floors and decks route from the yard; 27/27 spawns reach their objective; every chamber's entry →
passage is open, and in chamber 9 the way up to the keep's landing. A playtest boots clean (32
server / 13 client modules). Place ~64k parts, ~490 lights.

## Version 0.21.0 — The Graveyard, the Smithy and the Great Hall; the dead get upstairs

**Chambers 4–6 rebuilt** by `tools/BuildWards.luau` (sections Area4–Area6), the same way as 1–3 —
see `docs/systems/ChamberThemes.md` for what stands in each:
- **4 Graveyard**: a stone chapel used as a mortuary, its churchyard (broken wall, lychgate, old
  graves, table tombs, a broken cross, a family vault), the new field of graves dug too close, some
  open, a pit dug into the terrain with the shrouded dead in it, a burning pyre, the sexton's house
  and his coffins, a charnel house, a timber belfry you can climb.
- **5 Smithy**: a stone forge open in six bays with two hearths and two stacks, the armoury with a
  loft, the smith's house, a mine cut into a rock hill in the terrain (adit on timber sets, rails,
  tubs, gold in the walls), the oil store, a rack of unlit torches, dead trees with an axe in a
  stump, a saw pit and sawn planks, a bloomery and a smoking charcoal clamp.
- **6 Great Hall**: a 120 × 46 stone hall with an open timber roof (arch-braced trusses, slates, a
  louvre over the hearth). The road runs through its screens passage, under a minstrels' gallery
  you can climb; dais, high table, cloth of estate, chandeliers, banners, tables thrown over and one
  still laid. Solar wing, buttery, the court of the last feast under pavilions, the lord's garden.
- **The places the area mechanics need are built and named** (not the mechanics): four unlit
  grave braziers, the forge with its bellows and anvil, the torches, the oil, the choppable trees,
  the planks, and a `BoardPoint` in each of the hall's four doorways (AreaPlan.md lists them).
- New in the building library: stone walls with double doors, pointed (lancet) heads, open bays,
  archways and any thickness; stone gables; several chimneys to a roof; buttresses, quoins,
  flagstones; graves in five states, headstones, coffins, shrouds, tombs, crosses, churchyard walls,
  a lychgate, a bell, dead trees; forge hearths, a grindstone, a weapon bench, mail on stands, sword
  and torch racks, oil jars, stumps, mine tubs, rails, timber sets, a bloomery, a charcoal clamp;
  trestle tables, benches, banners, chandeliers, sconces; terrain dug (a pit) and heaped (a hill).

**The dead can now reach every upper floor, not just the top of the stairs.** A new check stands
on each upper floor (`UpperProbe` / `DeckProbe`) instead of on the stair head, and it found that in
every cottage the flight ran into the end wall: whoever climbed it stood on the top step with
nowhere to go. Fixed in all six areas:
- house stairs are steeper (43°; the pathfinder climbs 45°, not 48°) and every one now arrives on a
  landing at least 2.6 wide; the narrow two-storey houses are 2 wider (18→20, stone 22→24), and
  the builder warns if a house is too short for its stair;
- door leaves swing right back against the wall (155–165°): a leaf standing square into a room cut
  a cottage in half; stone doors hang on the inside face;
- a 0.22 lip at the gallery's stair head, an anvil 1.6 inside a forge bay (the area-2 forge bay that
  never routed), a barrel rolled in front of a bay and a shelf in a doorway were all removed.
- Verified in Studio: 62/62 stairs, ramps and door steps and 15/15 upper floors and decks in
  chambers 1–6 route from the yard; 18/18 spawns reach their objective; entry → passage open in all
  six chambers. A playtest boots clean (32 server / 13 client modules). Place ~52k parts, 390 lights.

## Version 0.20.0 — A bigger castle, and the first three chambers built to be believed

**The castle is 25% bigger both ways** (300 × 1800 → 376 × 2250; chambers 200 → 250 deep).
- `configs/Castle.luau` (new) holds the numbers. `tools/BuildBattleground` (new MODE "resize"),
  `tools/BuildLand`, `tools/BuildSurroundings`, `AreaService` and `WinchService` all read them; no
  copy of the castle's size is kept anywhere else.
- Resize keeps everything: walls whose length changed are rebuilt (in runs of ≤1000 — a part longer
  than 2048 is silently clamped, which left holes the first time), every tower, passage, marker,
  building and light is moved whole. The moat, reeds, mist and the smoke moved out with it; the old
  moat inside the new walls is filled (`BuildLand` MODE "castle").
- The old chamber tools (`BuildChambers`, `LightCastle`, `CleanSlate`) refuse to run on the resized
  castle instead of building in the wrong place.

**Chambers 1–3 rebuilt** by `tools/BuildWards.luau` (new) — see `docs/systems/ChamberThemes.md`:
- A building library made the way buildings were made: stone plinths with quoins, timber frames
  (sill, posts, rail, braces, close studding upstairs), daub panels set back from the frame, jettied
  upper floors on joists and a bressumer, thatch 2.6 thick with a rolled eave, a sedge ridge and
  hazel liggers, plank doors on strap hinges, mullioned windows with shutters, rubble-stone walls
  with dressed jambs and oak lintels, chimneys, fighting decks, lean-tos, open sheds, ruins.
- Generated PBR materials (`TLK_Thatch2/3`, `TLK_Daub`, `TLK_OakBeam`, `TLK_OldPlanks`, `TLK_Rubble`,
  `TLK_Charred`, `TLK_Shingles`, `TLK_Hay`, `TLK_Burlap`, `TLK_YardMud`, `TLK_Cobbles`) and textured
  mesh props (barrel, cart, anvil, sacks, firewood, trough, crate, table, bed, cauldron, shelf, bread
  basket) in `ServerStorage.Assets.Props`. Mud and cobblestone terrain use the generated textures.
- New roads painted into the terrain, cobbles with mud verges, grass along the walls; torches on the
  walls again; braziers, hearths, glowing windows, smoke from chimneys and burnt buildings.
- Area 1 ~4.5k parts, areas 2 and 3 ~2.7k each. Place total ~39k parts.

**The dead can follow you up.** Every raised floor is reached by a flight whose walking surface is an
invisible ramp, every doorway has steps with a ramp under them, and:
- `EnemyAIService` now follows the floor (each step finds the surface under it: up 2.2, down 40), takes
  a route instead of a straight line when the target is on another level, gathers underneath when
  there is no route, routes with a 1.0 radius (at 2.4 or 1.6 the pathfinder judged every door and
  stair impassable), and turns at waypoints within 2 (at 4 bodies met stairs from the side).
- Verified: all 32 doors, stairs and decks in chambers 1–3 route from the yard; a playtest had four
  of the dead climb the watch platform and reach the player on it. Every route from the entry to the
  passage, and from every spawn to every objective, is open.

## Version 0.19.1 — Both places caught up, and published for testers

Both places were brought level with the repo and **published** (2026-10-18) so testers can play.

- **Kingdom Hub**: 20 shared scripts were behind the repo — 12 stale (Net, Scaling, Encounters, Enemies,
  Difficulty, Missions, Look, EnemyBrain, CombatController, MissionController, Mission.Types, the
  EnemyBrain spec) and 8 missing (Intro, IntroController, IntroUI, AreaController, AreaHud, ObjectiveHud,
  WeaponAnimController, Shared.Anim.SwordAnims). Now 120 of 120 match disk.
- **Hub bug fixed**: `StarterPlayerScripts.Client` held a second, older `Core`, `Controllers` and `UI`
  folder (left by an old sync), so two `Bootstrap`s ran and every client controller booted twice.
  The stale copies are gone; one Bootstrap runs.
- **Forgotten Lands**: `Interactions` and `DialogueUI` were older than disk (no voiced lines) and
  `Look` was missing. Now 134 of 134 match disk.
- The Studio edit camera was left `Scriptable` by the screenshot work in both places (only selecting
  worked); it is back to `Fixed`.
- Verified: `rojo build` clean for both projects; a playtest of each place boots with no script errors
  (Hub: 18 server / 13 client modules; Forgotten Lands: intro → area 1 → wave 1).

## Version 0.19.0 — A castle with people's things in it, and fire

The nine chambers were bare yards with no light in them at all — not one Light instance inside the
walls.

**The chambers are furnished again** (`tools/BuildChambers.luau`, `Battleground.Decorations`, ~4.2k parts):
the guardhouse and barracks of the Outer Ward, the stables and farrier's, the bakehouse and ovens, the
chapel and its graves, two forges and the smith's house, the Great Hall, seven houses in the Rows, the
fallen tower in the Inner Ward. The tool was reused, with four changes:
- the stone road is NOT drawn (`DRAW_PATH = false`; two parts roads were taken back in Aug 2026). The
  route is still computed, and every building keeps off it;
- the markers are READ from each chamber (spawns, objectives, Checkpoint, Storyteller) instead of the old
  assumed positions, plus the arrival pad, the winch, and the throne room;
- every footprint is tested against the towers and walls, so nothing is built through a tower;
- big buildings are placed as rectangles (`placeRect`) on a grid search: as circles the Great Hall, the
  fallen tower and three of the Rows never fitted beside the road. The hall is 64 x 44 now (was 64 x 90),
  the fallen tower 70 long, and the house plaster darker (it read as fresh whitewash).

**Light** (`tools/LightCastle.luau`, `Battleground.Lighting`, ~2k parts, 150+ lights, none with shadows):
- torches on the walls (cast at the stone, so each bracket sits on it), a torch either side of every
  passage so the way on is the brightest thing in a room, four braziers per chamber off the centre;
- ~22% of the towers' window openings glow ember (`MODE = "undo"` puts them back);
- a fire inside half the houses, a fire pit and two chandeliers in the Great Hall, candles on the altar;
- torn banners on the walls, ash falling through every room, and battle clutter — bones, blades,
  arrows, shields, helms, scorch marks — more of it the deeper you go;
- chamber 9 is the throne room: a dais against the back wall, an empty throne, a red carpet, two kings
  in stone, fires burning red and the back wall washed red.

Checked: nothing solid stands on any enemy spawn; a Studio playtest runs intro → skip → area 1 →
barricade → wave 1 (15 enemies) with no new errors. The place is now ~29k parts, 164 lights.

**Tooling**: tools are no longer pasted into Studio. A tiny local server (node, 127.0.0.1 only) serves
the repo's text files and the command bar loads them with `HttpService:GetAsync` + `loadstring`, with
`HttpEnabled` switched on only for that one call and straight back off.

## Version 0.18.0 — The Forgotten Lands get a horizon, and an arrival

The castle stood on a flat plate of earth that ended 900 studs out, under a red sky, ringed by a thin
turquoise ditch. It now sits in a land.

**Look** — new preset `ForgottenDusk` (`configs/Look.luau`): Look A an hour later. Cold blue-grey haze,
a heavy cloud deck, a moon, and only a bruise of red where the sky meets the hills. Water is black and
still. `ForgottenBaseline` is the exact old look, kept as the undo. `tools/ApplyLook.luau` now also sets
the terrain's water (`Water` section).

**Land** (`tools/BuildLand.luau`, terrain only, nothing inside the moat touched):
- The moat is rebuilt as one ring, 80 wide (was 44): mud bank, a shallow shelf, deep black water at y −6.
- Ground out to 4.8k × 6.3k studs. Flat by the moat, rolling hills from 100 out, mountains 1.3k–1.9k out
  all the way round, so the world ends in rock and haze. Rock and slate on the heights, dead grass, earth
  and mud patches below.
- A hill 800 studs in front of the gate, with a clear sight line to it, and a paved road down to the bridge.

**Surroundings** (`tools/BuildSurroundings.luau`, `Workspace.Gameplay.Surroundings`, ~5,000 parts, none
collide — it is all behind the castle wall):
- Moat: stone revetment with coping, buttresses and a green waterline; reeds; sharpened stakes on the far
  bank; a sunk cart, a half-sunk boat, a fallen tree, floating planks and barrels; mist lying on the water.
- Bridge: stone, two arches on cutwater piers, then the drawbridge left down, planks missing, chains
  running up into the gatehouse. Two braziers at its foot and two torches at the gate: the first warm
  light in the world.
- Outside: a burnt village (seven cottages, a well, two still smouldering), an old battlefield (rows of
  graves, weapons left standing in the earth, a trebuchet that never fired, torn banners), a gallows,
  ~240 dead trees in patches, rails ending at a broken buffer stop, and a wayside shrine whose candles
  are still lit.
- Smoke rising inside the walls, and one red light in the highest tower of the last chamber.

**The arrival scene** — new: `configs/Intro.luau`, `Server/World/IntroService`,
`Client/Controllers/IntroController`, `Client/UI/IntroUI`; remotes `IntroEvent`, `RequestIntroSkip`.
- On arrival the party stands on the hill and sees the castle: title card, letterbox, six shots from
  camera marks (`Surroundings.Intro.Cam1..6`, movable in Studio), and six lines. Each line is said by a
  player in the party, shown by their display name on a gold plate above the text; the order is shuffled
  per run, and alone the one player says them all.
- Skip is a vote (more than half; alone, one press). Sized for a thumb (48 px), text scales with the
  screen.
- Then black, everyone is on the arrival pad, and the run starts. Bodies are taken up the hill the moment
  they appear, so chamber 1's barricade and waves only arm once the scene is over. `ChapterService` now
  waits on `IntroService.whenFinished`.
- Verified in a Studio playtest (solo): scene starts, lines show under the player's display name, the
  camera changes shots, the scene ends on time, then area 1 → waves → chapter start, in that order.
- First look with screenshots (`assets/Images/Reference/forgotten-lands-exterior_2026-10-18.jpg`), and
  what it changed: the haze hid the castle from the hill entirely (density 0.44 → 0.3, haze 2.4 → 1.5);
  the cloud deck sat on the mountains like a lid (cover 0.74 → 0.6); the ground and moat went pure black
  (outdoor ambient and exposure lifted); the water now reflects the sky. The talking shots were turned
  round — from the front the castle is behind the camera — to over-the-shoulder shots, with a cold moon
  fill on the party. The braziers were too small to read: bigger, brighter, shadowless.

## Version 0.17.2 — The veteran speaks in short breaths

- The Storyteller's speech is now ten single sentences (`configs/Interactions.luau`), each replacing
  the last on screen, instead of four long paragraphs. Holds are shorter to match.
- `DialogueUI` reads any line that has no `Sound` aloud with Roblox's built-in text-to-speech
  (`Dialogue.Voice`: VoiceId, Pitch, Speed; `Enabled = false` turns it off). The text paces itself to the
  voice. A line with its own recording still wins. Verified in Studio that the voice loads
  (2.4 s for the first sentence); how it *sounds* is not verified.
- The built-in voices are a stand-in. The intended voice — an old British veteran — is now recorded:
  ten clips (`assets/Audio/Storyteller/veteran_01..10.mp3`, ElevenLabs voice "Veterans Voice, Rblx",
  model eleven_v4, one file per sentence, in the order of `Lines`). Uploaded through the Asset Manager
  (creator = the experience's group) and wired into each line's `Sound` in `configs/Interactions.luau`.
  All ten load in Studio with the expected lengths. How they sound in the scene is not verified yet.

## Version 0.17.1 — The camp is closed

Nothing stopped a player leaving the Hub. The chain-link fence is 9.6 studs tall (a jump and a
stack of crates clears it), and on the north side there was no fence at all, only the railway
and a plain a thousand studs wide. Nothing here touches gameplay code, and the fence itself is
untouched.

- **`tools/BuildBoundary.luau`**: an invisible wall, 50 studs high and 4 thick, in
  `Lobby.Invisible.Boundary`, on one closed outline read from what is already there: the fence's
  three sides on the fence's own lines; the gaps beside the train on the north, closed at the
  fence's ends; and a pocket round the train and the four wagons, 6 studs (about 1.7 m) outside
  them, so the rake stays in the playable area and a player can still walk round its ends. The
  walls stand outside the outline, so nothing sticks into the camp. 35 pieces, about 1,000 studs
  of wall. `preview`, `build`, `verify` and `remove`; move the fence or the train, run `build`
  again, and the outline follows.
- **The wall does not touch the camera.** It is `Transparency 1` and `CanQuery false`: Roblox's
  default camera only pulls in for opaque, collidable parts it can raycast to, so the player can
  zoom out past the wall. Only the character is stopped. The chain-link's own parts are opaque and
  collidable, so on the three fence sides the *fence* still pushes the camera in, as it always did
  (left as it is, on purpose).
- **Checked three ways.** `verify` samples 12,880 points along the outline: no gap, nothing
  protruding into the camp, every piece invisible, collidable, not queryable and anchored. In a
  real playtest a character was ordered to walk out through every side, the corners and both ends
  of the train pocket, and to keep jumping the whole way: all 13 stopped inside, and the two bare
  north shoulders (no fence there) show the barrier stops a body on its own.
- **A palisade was tried and rejected.** A wall of sharpened logs (1,781 parts) replaced the
  chain-link briefly. It was too tall and not wanted, so the chain-link was put back exactly (82
  segments, same positions, checked) and the tool was deleted.
- **Not verified:** the camera in a running client. The Studio window was not rendering during
  the playtest, so the camera never moved; only Roblox's rule for it was checked.

## Version 0.17.0 — The Hub gets a look

The game was playable and looked like a prototype: a pale sand "road" across a flat plain,
under a flat blue sky, in lamplight that did not exist in play. Nothing here touches gameplay.

- **`configs/Look.luau` + `tools/ApplyLook.luau`**: how a place looks — lighting, atmosphere,
  sky, clouds, post-processing, the colour of each terrain material — is now **data** with
  named presets, baked into a place at edit time. Zero cost while the game runs. `Baseline` is
  the Hub as it was; `DarkRealistic` is the locked base look; `StylizedDarkFantasy` is kept as
  a reference. `Lighting.Technology` cannot be touched by a script and is left alone.
- **Look A locked** after an A/B test on four fixed cameras. Overcast, cold, desaturated; warm
  light only from fire. The doubled Bloom is gone. The rules, palette and ground vocabulary are
  the Style Bible in `docs/systems/Presentation.md`.
- **`tools/PaintGround.luau`**: the terrain was a flat slab of `Ground` with the roads as one
  layer of `Sand`, whose rippled texture read as desert whatever colour it was given. Colour
  cannot fix a texture, so it changes the *material* of the top layer: paving on the roads
  (285 of their 308 voxels), mud at lane edges and shores, weeds along the fence, patches of
  grass and stone beyond it. Heights and the authored road shape are never touched. It has
  `preview`, `apply` and an **exact `restore`** (the road positions are recorded on the
  terrain).
- **`tools/PreviewRuntimeLights.luau`**: the lamps are hand-placed at stock strength
  (lantern posts 2.4, range 24) and `LightService` retunes them only when the game runs
  (0.8, range 40), so the Studio view overstates every lamp two to three times. The tool
  stamps the runtime values on for judging and restores the originals exactly on `off`.
- **Not done, on purpose:** the placeholders (train wagons, chain-link fence, flat horizon),
  set dressing, VFX, and the Forgotten Lands look. They are in `docs/Todo.md`.

## Version 0.16.0 — A sword you can see

- **`Server/World/WeaponVisualService`**: the player was punching. Combat has been
  numerically correct since the vertical slice and has never had a weapon on screen —
  you could not read your reach, tell whether a swing came out, or tell you were armed.
  The equipped weapon is now built from parts (hilt, binding, pommel, crossguard, fuller,
  twin edges, point) and welded to the right hand, with a `Trail` on the blade that is
  off except during the strike.
- **The swing is procedural.** Roblox animations need an uploaded asset id and this
  project has none, so the right shoulder's `Motor6D.C0` is driven through wind-up →
  strike → recover in ~0.47s. C0 rather than the Animator's `Transform` channel for two
  reasons: server C0 changes replicate and `Transform` does not, and because the joint
  is `Part0 * C0 * Transform * C1⁻¹` the offset composes **on top of** the idle/walk
  animation instead of fighting it. `GRIP` is the single constant to adjust if the
  sword sits wrong in the fist.
- **The winch is a HOLD, not a tap.** No more banked notches: hold E and the gate climbs
  at 1/14 per second, let go and it falls at **×1.5** from that same frame, with no
  grace. Fourteen unbroken seconds gets you through, so the room has to be cleared
  enough to give you fourteen — and every second spent swinging costs a second and a
  half of height. Each extra pair of hands adds half a pair's worth.
- **Highlights no longer draw through walls** (`DepthMode.Occluded`). Nine boxes lit up
  through the stables from the doorway is not searching, it is reading a map.
- **Enemies notice you from across the room.** Detection radii were 40–60 in chambers
  300×200 studs with spawn markers up to 150 away, so the dead stood where they spawned
  and were never seen. Shambler 45→110, runner 60→130, heavy 40→100, spearman 55→120,
  archer 85→145, King 120→200, with leashes at roughly twice that so they follow you
  through the arch instead of turning round in the doorway.

## Version 0.15.0 — The dead, in every room

Areas 1 and 2 both played correctly and both played wrong: you cut three ropes, found
a handle, wound a winch, and nothing ever came. Every line written into those mechanics
— progress is kept when you break off, the winch slips while you fight — assumes there
is something to break off *for*.

- **`Server/World/AreaWaveService`**: walk into a chamber, that chamber's encounter
  starts (after a 3s breath). The waves are **pressure, not the lock** — clearing them
  opens nothing, the room's own puzzle does, and you may leave the moment it is done.
  Entering chamber N stops chamber N−2's encounter and despawns its stragglers, so the
  thing chasing you through a doorway keeps chasing you and the thing three rooms back
  does not.
- **`configs/Encounters`** +`area_1` … `area_8`: 3–5 waves each, obeying
  `Difficulty.Areas[n].Unlocks` as the single source of truth for which enemies exist
  yet — shamblers alone in the Outer Ward, runners from the Stables, the heavy at the
  Graveyard turn, spearmen and archers at the Smithy spike. Counts are the BASE for one
  player; the curves do the ramp.
- **The depth curve is finally read.** `Scaling.forArea(index)` + `Scaling.combine`, and
  `WaveService.Context.areaIndex`. `Difficulty.Areas` has been sitting in the config
  written and unused since 0.8.0 — party size and depth now multiply, which is the whole
  reason they are two tables.
- Chamber 9 is deliberately absent: the King is not a wave table.

**Known**: `Difficulty.Areas[n].EnemyDamageMult` is still applied nowhere — count and
health scale with depth, damage does not. It needs `EnemyService.spawn` to carry a
damage multiplier the way it already carries a health one. **Also**: the Chapter 1
mission's `chapter_one_ambush` still fires in chamber 2 on top of `area_2`, so that room
currently gets both.

## Version 0.14.0 — Area 2's winch

- **`Server/World/WinchService`**: the portcullis out of the Stables is down and the
  winch has lost its handle. Nine search points — crates, barrels, bales, sacks,
  chests — are scattered around the stables **at runtime**: the service raycasts for a
  floor, rejects anything above ward level (a ray dropped over the stables lands on the
  roof), rejects anything overlapping existing geometry, and keeps 20 studs off the
  measured road. One holds the handle and which one changes every run.
- **The gate is the progress bar.** `AreaService.setOpenFraction(index, f)` (new) lets a
  mechanic drive the grille directly. Turning the winch raises the real portcullis a
  fraction at a time and letting go lowers it — no bar on screen, and the slip-back
  hurts in a way a number could not. GAIN 0.075 per hold, SLIP 0.022/sec, 0.7s grace.
- **Solo-first**: alone and unbothered it is ~20 seconds of work; a ten-second fight
  costs about three holds. A `ProximityPrompt` is held per player, so two people on the
  same winch produce two turns where one produced one — faster, never the difference
  between possible and not.
- **Plain words** everywhere on screen: "Look around", "Keep going", "Kill them all",
  "Cut the ropes — 2 left", "Find the winch handle", "Turn the winch". The prompt on the
  barricade says Rope, not Lashing.
- **`tools/SurveyArea2`** replaces `tools/BuildStables` (deleted). It measures rather
  than computes: the real road in ten z-slices, the real bounds of the user's own
  `Horse Stable`, and everything else standing in the chamber. The stable range I built
  from `BuildChambers`' constants landed on the road; every position in `WinchService`
  came from this survey instead.

## Version 0.13.0 — The HUD gets quiet, the world gets loud

Playtest feedback, applied. The screen was shouting and the props were greyboxes.

- **Bug**: `ArrivalService` asked `GameService.getPlaceRole()` in **Init**, and the Loader
  runs Init alphabetically — so it asked before GameService had answered, got `Unknown`,
  and did nothing. No log line, and the player kept spawning inside the gatehouse. The
  check is gone: `Server/World` only syncs into the Forgotten Lands, so the file existing
  IS the place check.
- **No more waypoint beams.** `Server/World/Beacon` is deleted. A pillar of light over
  the objective turns a castle into a checklist, and the gold read as neon. The area name
  says where you are, one line at the top says what to do, and the world has to carry the
  rest.
- **`AreaHud` v2** — bottom left, bare screen: white name, 2px black outline, nothing
  else. No panel, no status, no "locked". Two labels swap so a room's name can leave while
  the next arrives, with a hairline rule sweeping under it.
- **`Client/UI/ObjectiveHud`** (new) — one small white line at the top, typed a character
  at a time, no panel behind it. Sources push and clear by name and the newest live one
  shows, so an area mechanic can take the line and the mission's line comes back when it
  finishes. `Net` +`ObjectiveHint`; objective defs gain a short `hint`.
- **`AreaService.onEnter(index, fn)`** — the invisible barrier. An area's content starts
  when a player first walks into it, once per run. No trigger part: the position poll
  already knows, and it catches players who spawn past a line, are put down by a
  checkpoint, or clip a corner at speed.
- **The barricade is built like a barricade.** Rope is now turns of cord passing right
  around the beam — eight tangent segments per turn, jittered, nine turns per lashing,
  falling three at a time as it is cut — with frayed tails and an eight-segment iron ring.
  Boards get a facing plank, six nails each and a split end. The lashing's height is
  DERIVED from its board instead of hand-written; the first version had one wrapping thin
  air a stud above the plank it was holding. The highlight is a pale warm edge, not gold.

## Version 0.12.0 — Area 1's mechanic, and somewhere to land

- **`Server/World/ArrivalService`**: the place had **no SpawnLocation at all** — deleted
  by hand at some point, most likely, since it is invisible and non-colliding. Roblox's
  fallback is to drop the character near the world origin, and this map's origin is the
  middle of the gatehouse arch, so the player spawned standing on the gate every time
  with nothing in the log to say why. The spawn is now created at boot from the pad's own
  geometry, so it cannot be deleted again, and the service sweeps the landing box and
  names anything solid standing in it.
  (The previous guess — the fallen gatehouse doors — was wrong; `FixArrival` reported
  `z 8 -> 8`, i.e. it moved nothing. The doors are better placed now regardless.)
- **`Server/World/BarricadeService`** — Area 1 per `systems/AreaPlan.md`: heavy timber
  lashed across the portcullis, **three bindings, three cuts each**, `ProximityPrompt`
  hold-to-cut. Each completed cut is banked and a turn of rope falls away, so breaking
  off to fight costs at most the 1.6s in progress — never the binding. Solo-first: three
  bindings, one pair of hands; more players is faster, never *possible*. Cut all three
  and the timber comes down and `AreaService.clear(1)` raises the gate.
  Each binding wears a `Highlight` (AlwaysOnTop) so it is findable through the timber,
  and the barricade carries a beacon counting down the bindings left.
- **`AreaService`** exposes `passageOf(index)` / `gateModel(index)` so a mechanic can
  build onto the gate instead of keeping its own copy of the castle's dimensions.

## Version 0.11.1 — Wayfinding, and two things the first playtest found

The castle's first real playtest failed on one thing, and it was not combat: the
player did not know where to walk.

- **Bug (silent, and the cause of most of it)**: `MissionRuntimeService` assigned
  `objective.def.position` — which configs write as a marker NAME — straight to
  `Part.Position`, throwing `Vector3 expected, got string` on every objective and
  leaving Chapter 1 with no waypoint at all. It now goes through `Markers.resolve`,
  the same call `ObjectiveTrackers` already used.
- **`Server/World/Beacon`**: a reusable "go here" — a 70-stud neon shaft, two ground
  rings pulsing outward, rising motes, a point light, and a nameplate that draws
  THROUGH walls (`AlwaysOnTop`), so it survives a building being in the way. All
  parts are `CanQuery = false`: a waypoint must never eat an arrow or a sword swing.
  Objectives label it by kind (`GO HERE` / `SEARCH` / `HOLD HERE` / …).
- **`AreaService`** lights a `THE WAY ON` beacon in front of a passage the moment its
  chamber is cleared, and puts it out on `lock`. Deliberately dark while locked — the
  objective owns the player's eye until it is done.
- **Bug (arrival)**: the two gatehouse doors were placed 30 and 46 studs *past* the
  gate, flat across the arrival pad, so the player spawned standing on one. Moved
  into the archway where "off their hinges in the passage" actually means it.
  `tools/BuildBattleground` carries the new numbers; **`tools/FixArrival`** applies
  the same move to an existing place without a rebuild, then sweeps the spawn box
  and names anything else standing in it.

## Version 0.11.0 — Area gates & the corner HUD

The nine decorated chambers become a **run**: the way forward is shut until the room
is done, and the player can always see which room that is.

- **World**: `Server/World/AreaService` builds a real portcullis into each of the first
  eight passages — bars, spikes, ties, guide runners, a threshold sill, and chains that
  shorten into the masonry as the gate rises. The lift is a ~3s smoothstep with a
  decaying judder, not a tween of a part sideways. The visible grille is non-colliding;
  an invisible slab inside it does the stopping, because 2.5-stud bar gaps do not stop a
  Roblox character.
- **API**: `clear(index)` / `lock(index)` / `isCleared` / `areaOf(player)` / `resetAll()`.
  The service owns the gate and the HUD and deliberately **not** the win condition —
  each area's mechanic calls `clear` when its own puzzle is done.
- **Client**: `Client/UI/AreaHud` (bottom-left panel: chamber number, English name, one
  status line; gold rule open, bordeaux shut, a single gold flourish when the gate goes
  up) driven by `Client/Controllers/AreaController`, which stands down outside the
  Forgotten Lands.
- **Contract**: `Net` +`AreaEvent`.
- **Geometry**: `AreaService` duplicates `tools/BuildBattleground`'s numbers (gap width,
  springing height, span underside, passage inset, the east/west serpentine). Changing
  one now requires changing the other.

Nothing calls `clear()` yet — the per-area mechanics land next. `DEV_OPEN_ALL` in
`AreaService`, or `require(...AreaService).clear(n)` from a **server** command bar,
walks the castle in the meantime.

## Version 0.10.0 — Death System

Death = WHAT HAPPENS WHEN YOU FALL. A foundational death/revive loop wired into the mission
run. Placeholder feedback (prints), no UI/camera polish:

- **Contract**: `Shared/Death/Enums` (Choice: Lobby/Revive/Wait; Status); `Net` +`DeathEvent`
  / `RequestDeathChoice`.
- **Domain (pure, tested)**: `DeathGroup` — wipe / reviver-available / waiting-group rules
  (`DeathGroup.spec`).
- **World**: `DeathService` owns respawn (`CharacterAutoLoads` off in the World) + death status;
  detects death via `CombatService.EntityDied` (once per life); drives PARTY-AWARE choices
  (solo: Lobby + Revive; party: also Wait), the spectate window, free teammate proximity revive,
  self-revive (gold, anti-P2W: cost / cooldown / reduced HP), and run-over.
- **Integration**: `MissionRuntimeService` registers the run's players (`DeathService.beginRun`,
  guarded against re-entrant/stale fails via a run id) and fails the mission on a run-over. There
  is NO auto-restart — players respawn idle and a manual Play Again (`RequestPlayAgain`) restarts
  the chapter. Self-revive spends gold from the persistent profile.
- **Client**: minimal `DeathController` (prints choices, keys 1/2/3).
- **Content/config**: `Economy.Revive` + `Settings.Death`; dev starter gold
  (`Settings.Dev.StarterGold`) so solo self-revive is testable.

Resolves slice tech debt: player death now has real consequences and choices. Robux revive,
diegetic UI, and real Hub teleport are follow-ups.

## Version 0.9.0 — Progression & Rewards + Persistence

Progression = WHAT THE PLAYER EARNS. A real reward pipeline over durable saves; missions and
encounters now grant currency and XP. Placeholder values, no UI:

- **Domain (pure, tested)**: `Progression` (XP -> levels from the Experience curve, +
  `Progression.spec`); `ProfileSchema` v2 adds `xp`/`level` with a v1->v2 migration
  (`ProfileSchema.spec` extended); `DataStoreStore` — a real DataStoreService-backed `Store`
  (pcall + retry).
- **Service**: `RewardService` grants currency + XP (via Progression) into the persistent
  profile — server-authoritative, with level-ups.
- **Persistence**: `SaveService` injects `DataStoreStore` when enabled + available
  (`FeatureFlags.UseDataStore`), else keeps the in-memory mock (Studio without API access) —
  same `Store` interface, no other change. Load/save/autosave/close lifecycle already existed.
- **Content**: `configs/Experience` (XP curve, MaxLevel 10), `configs/Economy` (`gold`);
  Chapter 1's mission and its `Clear` objective carry real `reward` values.
- **Integration**: `MissionRuntimeService` applies a mission's `reward` on completion AND any
  objective's `reward` on objective complete (so encounters reward too); results stream to the
  `MissionEvent` feed and print via `MissionController`.

Resolves slice tech debt: rewards are real (currency + XP into the profile) and persistence is
a real DataStore backend, not a mock. Cross-place session locking remains tracked tech debt.

## Version 0.8.0 — Encounter / Wave System

A reusable, data-driven encounter framework: the Mission System decides WHEN an encounter
starts, the Wave System decides HOW it runs. Placeholder content, no UI/VFX:

- **Data**: `configs/Encounters.luau` (spawn points + waves + groups) and `Shared/Wave`
  (Enums, Types); `configs/Difficulty` (player-count scaling) and `configs/Waves` (global
  defaults) filled; `configs/Enemies` +elite (`undead_brute`) +boss (`fallen_champion`).
- **Domain (pure, tested)**: `EncounterRun` — sequential/parallel wave progression, wave
  clearing, completion/fail (+ `EncounterRun.spec`).
- **World runtime**: `WaveService.startEncounter(id, ctx)` spawns via `EnemyService`, tracks
  deaths via `CombatService.EntityDied`, advances waves (rest between), applies difficulty
  scaling (count + health + elite substitution), and cleans up. `Shared/Scaling` reads
  `configs/Difficulty`.
- **Integration**: new `Clear` objective (`encounterId`) -> `ObjectiveTrackers.Clear` ->
  WaveService; wave/kill progress streams to the `MissionEvent` feed. `EnemyService.spawn`
  gained a health-scaling argument.
- **Chapter 1** moved from a flat 3-dummy spawn to a real 2-wave encounter
  (`chapter_one_ambush`, with an elite in wave 2).

Clean seam for level design: drop encounters into `configs/Encounters.luau` and reference them
from missions — no new code. Resolves the "objective spawns call EnemyService directly" debt.

## Version 0.7.0 — Mission & Objective System

Data-driven missions, objectives, and chapters replace the hardcoded Chapter 1 slice — the
former slice is now content, not code. Placeholder text only, no UI/VFX/polish:

- **Data**: `configs/Missions.luau` (ordered objectives + narrative + symbolic reward) and
  `configs/Chapters.luau` (ordered mission ids); shared contract in `Shared/Mission` (Enums:
  Reach/Kill/Survive/Defend/Escort/Interact; Types).
- **Domain (pure, tested)**: `Objective` and `MissionRun` (sequential activation, completion,
  failure) + specs `Objective.spec`, `MissionRun.spec`.
- **World runtime**: `MissionRuntimeService` (mission -> live run, drives a `Match`, streams a
  `MissionEvent` feed), `ObjectiveTrackers` (Reach/Kill/Survive/Interact full; Defend/Escort
  foundational with a neutral NPC), `ChapterService` (auto-plays a chapter; flag `EnableCampaign`).
- **Integration / refactor**: `MissionService` loads + validates the configs (and chapters);
  `EnemyService.spawn(enemyId, position)` generalised from the hardcoded dummy; `Net`
  `SliceNarrative` -> `MissionEvent`; client `NarrativeController` -> `MissionController`.
- **Removed** the hardcoded slice: `ChapterOneSliceService`, `ChapterOneSliceFlow` (+ spec),
  `configs/ChapterOneSlice.luau`, `NarrativeController`. Chapter 1 plays identically, from data.

Resolves slice tech debt: objectives are data (not baked into an orchestrator) and the run
uses the `Match` lifecycle. Reward stays symbolic until the Progression milestone.

## Version 0.6.0 — Chapter 1 Vertical Slice (integration)

The first playable end-to-end loop, proving the foundations connect. DEV/TEST scaffolding
and placeholder text only — no new gameplay systems, no UI/VFX/animations:

- **ChapterOneSliceService** (`Server/World`, Forgotten Lands only): an ORCHESTRATOR over
  existing public APIs (never their internals). Per-player flow: Spawn -> Story Intro ->
  Exploration -> Lore -> Objective -> Undead Encounter -> Combat -> Reward -> End.
- **Pure state machine** extracted to `ChapterOneSliceFlow` (`Server/Domain`) — ordered
  states + legal single-step transitions, validated on every advance. Spec:
  `Tests.ChapterOneSliceFlow.spec`.
- **Exploration**: visible placeholder markers + server-side distance detection.
- **Encounter**: reaching the objective spawns scripted undead via the existing
  `EnemyService` (reuses the `training_dummy` block); the always-on test dummy is now off.
- **Completion**: encounter deaths tracked through `CombatService.EntityDied` -> symbolic
  reward -> end -> marker cleanup. The intro is start-once and survives respawn.
- **Networking / config**: one server->client remote `SliceNarrative` (client
  `NarrativeController` prints beats — no UI); `configs/ChapterOneSlice.luau` (placeholders)
  + `Settings` flag `EnableChapterOneSlice`.

No existing system was modified beyond additive hooks (a `Net` remote, `Settings` flags).
Slice hardening (real reward, multiplayer, Match/Mission integration) is tracked in `Todo`.

## Version 0.5.0 — Phase 5: Enemy AI Foundation

The enemy AI architecture (foundation only — no waves, spawning system, pathfinding, bosses,
abilities, or optimisation):

- **EnemyBrain** (`Server/Domain/AI`): a pure, testable state machine — Idle → Chase → Attack
  → Return → Dead — deciding state from perceived distances only. Easy to extend.
- **EnemyAIService** (`Server/World`): drives each enemy per `Heartbeat` — perceive (nearest
  player via `CombatService`) → decide (brain) → actuate. Movement is simple **kinematic**
  (`PivotTo` toward target/spawn, no pathfinding). Attacks go **through the existing
  `CombatService.applyDamage`** — no duplicate combat logic.
- **Config-driven**: detection / attack / leash / arrival radii, move speed, attack cooldown
  and damage come from a new `AI` block in `configs/Enemies` (placeholder tuning). Nothing is
  hard-coded.
- **EnemyService**: one additive `EnemyAIService.attach(...)` call on spawn (no-op for enemies
  without an `AI` block). The dummy rig is unchanged.
- **Tests**: `EnemyBrain` spec covering every transition.

`CombatService` is untouched; enemy damage reuses the same authoritative path as the player's
melee. The training dummy now detects, chases, and attacks the player (and is still killable).

## Version 0.4.0 — Phase 4: Inventory & Equipment Foundation

The item / inventory / equipment base, wired into the combat slice (no UI, loot, crafting,
shops, or balancing):

- **Items config**: `configs/Items.luau` — the item catalog (structure/metadata). Weapon
  items link to their combat stats in `Weapons.luau` via `WeaponId`.
- **Domain**: `Inventory` (item instances, uids, capacity) and `Equipment` (per-slot equipped
  instances) — pure classes in `Server/Domain/Inventory`.
- **Services** (`Server/Services`, shared): `InventoryService` (fleshed out from its skeleton
  — add/remove/get, item-id validation) and new `EquipmentService` (equip/unequip, plus
  `getEquippedWeaponId` for the combat layer). Per-player in-memory state; profile
  serialization is a deferred follow-up.
- **Shared contract**: `Shared/Inventory` `Enums` (ItemCategory, EquipmentSlot) and `Types`.
- **Combat connection**: `MeleeCombatService` now reads the attacker's **equipped** MainHand
  weapon (no hard-coded `starter_sword`); `PlayerCombatService` grants + equips a starter
  weapon on entering the World (dev flag). Weapon stats still come from `configs/Weapons`.
- **Tests**: `Inventory` and `Equipment` domain specs.

`CombatService` and the authoritative combat flow (validation, hit detection, `applyDamage`)
are unchanged — only the melee weapon *source* moved to equipment.

## Version 0.3.1 — Phase 3: Combat Vertical Slice

Wires the combat foundation to real gameplay end-to-end (player swing → server validation →
enemy damage → death). No inventory, AI, waves, VFX, animations, or balanced values:

- **Player → CombatEntity**: `PlayerCombatService` (World) registers each player's character
  as a CombatEntity on spawn; `HumanoidAdapter` mirrors the authoritative `Health` onto the
  character's `Humanoid` (Health stays source of truth).
- **Enemy → CombatEntity**: `EnemyService` (World, generic for undead/animals/bosses/NPCs)
  spawns and registers enemies; ships a TEST training dummy behind `EnableCombatTestDummies`.
- **Server-authoritative melee**: `MeleeCombatService` validates the swing (attacker alive,
  per-player cooldown), performs server-side range + arc hit detection, and applies damage
  via `CombatService`. The client sends only intent + aim — never targets or damage.
- **First remotes**: `Shared/Net` declares `RequestMeleeAttack` (client→server, validated)
  and `CombatEvent` (server→client feedback); `CombatController` (client) sends the intent.
- **Additive only**: `CombatService` gained one read accessor (`getAllEntities`); `Net` now
  waits for the Remotes folder on the client so lookups are replication-safe.
- **TEST placeholders**: `starter_sword` (Weapons), `training_dummy` (Enemies), and the
  `Combat` block/flags (Settings) — not balanced values.

`ZombieService` untouched (stays the future undead-content layer over the generic `EnemyService`).

## Version 0.3.0 — Phase 3: Combat Foundation

The server-authoritative combat core for the Forgotten Lands (no weapons, enemies, or
balancing values — foundation only):

- **CombatService** (`Server/World`, Forgotten Lands only): the single authoritative damage
  entry point. Owns an entity registry (id ↔ entity, model ↔ entity for hit lookup),
  validates every hit (alive / i-frames / faction), resolves through the pipeline, applies it,
  and emits `DamageDealt` / `EntityDied` signals.
- **Damage system**: `DamagePipeline` — a pure, ordered modifier chain (empty by default) so
  armor, resistances, crits, and abilities extend it later without touching the core.
- **Entity / target handling**: `CombatEntity` — a generic combatant (players, undead,
  animals, bosses, NPCs, traps all share it) with faction, stats, and i-frames; instance→entity
  resolution walks a hit part up to its registered model.
- **Health system**: `Health` — server-authoritative current/max with clamping, latched death,
  and `Changed` / `Died` signals; decoupled from Humanoids/replication.
- **Shared contract**: `Combat.Enums` (DamageType, Faction, CombatState) and `Combat.Types`;
  plus a minimal `Core/Signal` primitive.
- **Config structure** (schemas only, no values): new `Combat.luau`; enriched `Weapons.luau`
  and `Enemies.luau` schemas (generic — enemy *archetype* is data, not a faction).
- **Tests**: `Health`, `CombatEntity`, `DamagePipeline` specs via the existing runner.

No new remotes this phase — the client-facing bridge is added with the HUD/VFX feature. No
Phase 2 systems changed.

## Version 0.2.0 — Phase 2: Core Systems

The server/client backend framework is implemented (no gameplay content yet — see the
reserved skeletons at the end):

- **Boot framework**: a shared, two-phase (`Init` → `Start`) `Loader` that boots modules
  deterministically and isolates failures; a scoped `Logger`.
- **Server core**: a place-aware server `Bootstrap` that boots the shared Services plus the
  place-specific `Hub`/`World` folder, and a per-player client `Bootstrap`.
- **Player & persistence ("Save Architecture")**: `PlayerService` (join/leave lifecycle +
  runtime `PlayerSession`), `DataService` (in-memory profile cache), `SaveService` (autosave +
  save-on-close over a pluggable `Store` — an `InMemoryStore` mock, so **no real DataStore is
  touched yet**), and a versioned `ProfileSchema`.
- **Run frameworks**: `PartyService`/`Party`, `MatchService`/`Match` (validated lifecycle
  state machine), `MissionService`/`Mission` (empty registry by design), and `TeleportService`
  (safely no-ops while the places are unpublished). `GameService` detects Hub vs. Forgotten
  Lands at runtime.
- **Shared contracts**: `Net` remote registry (zero remotes declared by design), the typed
  `Config` accessor, `Constants`, and `Types`.
- **Reserved skeletons for later phases**: `InventoryService`, `QuestService`, `ZombieService`,
  and the `Input` / `Camera` / `UI` / `Audio` client controllers.

Both places build cleanly (`rojo build default.project.json` and `world.project.json`).

## Version 0.1.0 — Phase 1: Design & Structure

- Authored the Game Design Document and the Architecture document.
- Applied the dual-place Rojo structure: `default.project.json` (Kingdom Hub) and
  `world.project.json` (Forgotten Lands), sharing `scripts/Shared`, `scripts/Modules`, and
  `configs`.
- Added the `configs/` data-driven balancing scaffold (schema skeletons documented in their
  headers; no balance values yet).

## Version 0.0.1

Project initialized.
