# The King's Wood: area 6, a forest in the dark, a huntsman who sees light (design, 2026-11-03)

The developer asked (2026-11-03) for the forest: it takes the place of one area, it is big ("ideally quite big") with something
practical to do, the sight is short again ("that is the point": the lantern taken at the catacombs is carried up to and through the
forest), a figure of its own, the dead's rot clothing kept for every figure, very good design and decoration, and generated, very
realistic trees (not little ones).

**Words.** *Area* = one of the nine big yards. *The inner wood* = the part inside the castle walls. *The outer wood* = the part beyond
the broken west wall. *The Hollow* = the old moat between them, dried to mud. *Watch-fire* = an iron fire basket on a stone foot, the
gamekeepers' old beacon. *Pitch* = black tar that burns; it is what lights a wet fire. *The Huntsman* = the figure of the wood.
*Cover* = closing the lantern's shutter so that it hardly shines.

## 1. Which area, and why

**Area 6, the Great Hall.** Its trial was one thing (board the doors, then hold a siege), and the Inner Ward (8) is already the big
fight, so a fight is not lost from the run. The order becomes: 4 the Catacombs (fear: he hears), 5 the Smithy (light, the forge, a
fight), 6 the King's Wood (fear: he sees), 7 the Rows, 8 the Inner Ward, 9 the Keep. Fear and action take turns, and the lantern is
carried through the bright Smithy "up to the forest", as the developer put it. The Great Hall's models are MOVED (not deleted) to
`ServerStorage.Assets.Retired.Area6`; its trial is kept in `configs/RetiredTrials`. The woodyard's planks (area 5) mend the wood's
broken footbridge instead of boarding the hall's doors.

## 2. How big

An area is 342 by 250 studs inside the walls. The wood takes all of area 6 **and goes out through the west wall**: the wood grew over
the wall forty years ago and broke it. Beyond the breach the old moat is a muddy hollow (the water is gone there, held back by two
earth dams), and beyond the hollow the outer wood runs another 300 by 400 studs to the foot of the hills. In all about 220,000 square
studs, two and a half areas, and in the dark, with paths that wind and thickets that close the straight lines, it walks much bigger.
Invisible walls (behind thorn and rock, never bare) keep everyone inside it.

## 3. The dark

Night, and no light but what burns: a light zone (`configs/LightZones` `Forest`) puts out the flat light and the sky's glow and
thickens a black haze, the same for every player whatever picture setting they chose. The lantern (29.5 studs) is the light; the
crowns of the trees hide the sky; a lit watch-fire is the only other light.

## 4. The figure: the Huntsman

The King's Master of the Hunt. He kept the wood for the King, and he still does. Tall (9 studs to the tips of his antlers) and thin,
built on the first blocky rig like the Doctor and dressed in the same rot (`RotCloth`, `RotLeather`, `RotSkin`): a long hunting
coat, a belt with a horn, gloved hands with real fingers, and for a face the skull of a stag with its antlers (a generated mesh, as the
Doctor's mask is), two dim points of light in the sockets. He carries a boar spear.

**He hunts by sight, and what he sees is light** (the Doctor was blind and heard; the Huntsman is the other half):

- An **open** lantern is seen up to **70 studs**, a **covered** one only at **8** (6 if crouched), and only along a clear line from
  his eyes: trunks, rocks, huts and the hills hide you. Behind him (outside his sight, 110 degrees either side) he sees only what is
  at his back, 8 studs.
- A light inside a burning watch-fire's glow (16 studs) is not seen: the fire drowns it. He will not walk into a fire's glow.
- When he first sees a light he stops, lifts his head and **blows his horn**: everyone in the wood hears it, and he is coming.
- He **hunts** the light at 14.5 studs a second (a walking player does 16, a crouching one 8), as long as he sees it; when it is
  gone (covered, hidden behind a trunk) he goes to where it was and **searches** for 8 seconds, then goes back to his **round**
  (the paths, at 7).
- In reach (7 studs) he swings the spear: a windup of 1.0 second that can be stepped out of, then 50 damage.
- **He cannot be killed.** Hurt him enough (about 300, more with more players) and he goes back into the dark for 25 seconds.

**Cover the lantern: F** (and a button on a phone). Covered, the lantern gives a glimmer of 5 studs: you see your feet. It is the
whole game of the wood: open it to see and to find, cover it when the horn sounds.

## 5. What there is to do

The gamekeepers' board at the edge of the wood says the old rule: **"When the four fires burn, the hunt is over and the gate is
raised."** The dead keep their old orders (the Huntsman his round, the gatekeepers their gate), so they still do.

1. **Find pitch.** Pots of pitch lie in the charcoal burners' camp, the woodcutter's hut, the Hollow's sunk cart and the Huntsman's
   lodge store (six pots in nine places, rolled each run; one is needed per fire). Taking one is a short hold.
2. **Light the four watch-fires**, one in each part of the wood: the old orchard (inner wood), the stag stones (outer wood), the
   Hollow, and the charcoal burners' clearing. Pour the pitch (a hold), then light it from your lantern (a longer hold): the lantern is
   OPEN while you light, and the fire takes 6 seconds to catch, growing; the flare is seen across the wood. When it burns it burns for
   the rest of the run: a place he will not come, and a light to steer by.
3. **Each fire wakes dead in the leaves** (the woodsmen and the lost: the ordinary dead in rot) round the wood, more with more players.
4. When the fourth burns, far off the gate groans up: the trial is done. The Huntsman still hunts until you are out.

**Deed (never needed for the gate):** the Huntsman's journal: six pages in the lodge and the huts, his own hand and his men's.
Read all six for a prize. (A mended footbridge with the woodyard's planks was planned and left out: the Hollow is dry mud, so a
bridge would carry nobody anywhere.)

## 6. The places

| Place | Where | What |
|---|---|---|
| The gamekeepers' gate | inner wood, east, at the way in from the Smithy | the board with the rule, a dead gamekeeper's lantern hook |
| The old orchard | inner wood, north | the lord's garden gone wild: dead apple trees, a broken wall, **watch-fire 1** |
| The charcoal burners' clearing | inner wood, south-west | earth mounds, a hut, pitch pots, **watch-fire 2** |
| The breach | the west wall | the wall broken by roots, rubble, a giant oak in the gap |
| The Hollow | the old moat | mud, puddles, reeds, a sunk cart (pitch), the broken footbridge, a fallen tree across, **watch-fire 3** |
| The stag stones | outer wood, middle | a ring of standing stones in a clearing, **watch-fire 4** |
| The Huntsman's lodge | outer wood, south-west, under the hills | a timber lodge, antlers over the door, his trophies, the store (pitch), journal pages |
| The woodcutter's hut | outer wood, north | a hut, an axe in a block, pitch, a page |
| The way out | inner wood, south-west, the gate to the Rows | where the hunt ends |

## 7. The look

- **Trees** (since 2026-11-05) are store-made mesh models, not blocks: silver firs for the dense dark, oaks for the broadleaves
  (and the five ancient ones), leafless trees with thin twigs, and the hills' own plain bare trees, which the developer likes
  (`tools/ForestDress.luau`, kit in `ServerStorage.Assets.ForestKit`). Every tree has an unseen round trunk that collides and stops
  sight; the crown neither collides nor stops sight. No crown grows into the castle's stone or a hut.
- **The ground** is terrain: leaf litter, mud and worn paths (generated MaterialVariants), never the grass of the yards.
- **Undergrowth**: mesh ferns (where the blade-built ferns and the bramble balls were), fallen logs and stumps in plain dark wood,
  mushrooms. **No moss or lichen pieces on anything** (the developer, 2026-11-05).
- **The edge**: a low broken rail fence (posts and two rails, some leaning, some fallen, a bay missing here and there) runs on the
  line of the invisible walls round the outer wood, so a player sees where the wood ends; the walls stand from y -20 to 300,
  far above any tree (they reach about y 75) and nothing in the wood can be climbed.

**How the map runs (for the developer, 2026-11-05).** The run walks the castle from the gate south, area by area. The wood is area
6: you come in from the Smithy through the gate in the north wall at the east end, and you leave by the gate in the south wall at
the west end, to the Rows. Between the two gates is the inner wood (inside the walls). Through the broken west wall you can go out
across the dry moat (the Hollow) into the outer wood; the castle walls close the inner wood, and the fence with its invisible wall
closes the outer wood on its three open sides. Two of the four watch-fires are outside (the Hollow, the stag stones), so the outer
wood is part of the errand, not a detour.
- **Paths** are worn earth, a little lower than the ground round them, so a lantern shows where they run.
- **Nothing stuck anywhere without a reason** (the developer's rule): every hut, stone, cart and fire is there for the story or the
  errand.

## 8. What was learned building it (2026-11-03)

- `generate_mesh` makes toy-like trees; `generate_material` makes real ones. Grow the shape, generate the skin.
- Roblox wraps a material round a cylinder: bark on a cylinder trunk has rings, not furrows. Trunks are two or three blocks
  turned round the axis (eight or twelve sides); limbs and roots stay cylinders.
- Generated materials come at Roblox's own scale: set `StudsPerTile` (bark 5-6, moss 4, leaves 3.5, needles 2.5, the floor 4.5).
- Terrain overrides are global per base material: the wood uses Salt, Pebble and Asphalt, which nothing else in the place uses.
- A test that teleports a body far must stream the ground first (`RequestStreamAroundAsync`), or the body falls through it,
  drops under -500, loses its root and the run counts as wiped.
- A prompt is only pressed when it is shown, and it is only shown when it is on screen: in tests, hold the camera on it.

**Learned 2026-11-05 (the second look).**
- Trees built of blocks fail twice: two textured blocks round one trunk show the bark twice where they overlap, and a branch of
  blocks is never thin. Free PBR mesh trees from the store (strip their scripts, tint `SurfaceAppearance.Color` darker, make the
  leaves untouchable and shadowless, add an unseen trunk) look like a wood and cost a fraction: the wood went from 37,765
  parts to 5,317.
- Store models can carry hidden UI scripts (two "dead tree" models did): keep only the MeshPart.
- A MeshPart's `TextureID` ignores `Color`; to darken a pale textured mesh, drop the texture and give it a plain material.
- The Huntsman is moved ten times a second by the server; an anchored root's new place reaches a client as a jump (0.72 studs,
  nine times a second, while his legs walked smoothly). `ZombieAnimController` now draws every one of the dead a little behind
  the server, between its last two places (moved on 319 of 321 frames, largest step 0.09).

## 9. Built where

| What | File |
|---|---|
| The numbers, places and pages | `configs/Forest.luau` |
| What he sees, and his mind | `Server/Domain/HuntsmanBrain.luau` (pure; `Tests/Forest.spec.luau`) |
| The errand | `Server/World/Trial/Forest.luau` |
| His body in the world | `Server/World/Trial/Huntsman.luau` |
| Covering the lantern | `LanternService` (`RequestLanternCover`), `Client/Controllers/LanternController.luau` |
| The dark | `configs/LightZones` `Forest` |
| The stone, the ground, the places | `tools/BuildForest.luau` |
| The mesh trees, ferns, edge fence, plain bark | `tools/ForestDress.luau` (kit `ServerStorage.Assets.ForestKit`; the grown trees kept in `Retired.ForestTreesGrown`) |
| The figure | `tools/BuildHuntsman.luau` (`ServerStorage.Assets.Undead.the_huntsman`) |
