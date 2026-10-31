# The Catacombs: area 4, a mountain, a deep stair, a maze in the dark (design, 2026-10-31)

The developer asked for a long, hard, frightening area under the ground: a huge rock that shuts the yard, a cave with a table that gives
a lantern, a deep stair down, a maze of narrow passages where only a lantern gives light, a huge blind plague doctor who goes to whatever
he hears, crouch-only passages, letters, blood and eyes on the walls, and a deep stair up on the far side. Everything here is data
(`configs/Catacombs`, `configs/CatacombsMaze`) and a few small rule modules with tests; the stone is made by `tools/BuildCatacombs.luau`.

**Words.** *Area* = one of the nine big yards. *Plan* = the floor plan of the maze (22 by 18 cells). *Cell* = one square of the plan, 10.5
studs. *Passage* = a corridor. *Crawl* = a low opening (3.4 studs) that only a crouching body fits. *The Doctor* = the big blind dead one.
*Noise* = anything that can be heard.

## 1. Which area it takes, and why

The developer asked me to take out the area with the least that is special, somewhere from the 3rd to the 7th, ideally the 3rd or 4th, so
that the next areas can need the lantern (the forest will). **I chose area 4, the Graveyard**:

- its trial was the plainest of the nine ("carry fire to four braziers while graves open"); the Kitchens (3) have the recipe and the five
  who join you, the Smithy (5) the forge, the Great Hall (6) the siege, the Rows (7) the prisoner;
- the catacombs are, in the story, what lies under a graveyard (BigRun.md already put them there);
- it is the 4th: after it, the Smithy, the Great Hall and the rest are still ahead for the forest or anything else to need the lantern.

The old trial is kept in `configs/RetiredTrials.luau` (nothing reads it). The yard's models that the mountain now covers (the belfry, the
sexton's house, the coffin yard, the charnel house, some lamp posts) were MOVED (not deleted) to `ServerStorage.Assets.Retired.Area4` in
the Studio place; the churchyard, the chapel, the new graves and the mass grave still stand behind the mountain, as quiet scenery.

## 2. The ground and the sizes

- **The mountain** shuts the yard from wall to wall near its entrance (the face is at z -772; it is 86 high and 46 deep, steep and rough,
  brown dirt and rock, built of terrain). An **invisible barrier** stands in front of the face from wall to wall, with a gap at the cave:
  nobody climbs it (the developer asked for one; the castle has no other invisible wall).
- **STAY QUIET** is painted large on a flattened face of the rock above the cave, 150 studs wide, in cream with a dark edge so it can be
  read from the gate.
- **The cave** is 9 wide. Beside it a **table** with a lantern on it and a note. Each player takes their own lantern (a hold of 1 second).
- **The deep stairs** are round shafts, 28 across and 72 down, with a spiral stair round an open well (2.75 turns going down and 3.25 going up, so that the last step stands in the doorway at the foot). The planks are very
  broken (some missing, some hanging, some split), but every step has a whole invisible one under it, so the walk is never broken. An
  invisible wall keeps a body from stepping into the well. One is at the cave (down), one at the far side (up, ending in a small stone
  house, the mausoleum, in the yard, 40 studs from the gate to area 5).
- **The passages** are 7 wide (two wide avatars side by side) and 7.6 high (a head and more over a tall avatar). **Crawls** are 3.4 high
  and 10.5 long. The plan lies at y -70, under ground that is solid to y -46.
- **The Doctor** is 6.9 high and 4.6 wide (a stooped giant: he fits a 7.6 passage with a hand of air, and in a passage he cannot be
  passed). The developer asked for "two avatars wide, up to two tall"; two tall (10 studs) does not fit a passage of a head and a half, so
  he is as tall as the passages allow.

## 3. The way through

1. **The table.** Take a lantern. Read the note ("Keep the light. Do not speak. Where the passage is low, go low."). The light dims at the
   cave mouth and goes out completely as you go down: the dark is a *light zone* (`configs/LightZones`: `CatacombMouth`, `Catacombs`),
   the same for every player whatever picture quality they chose.
2. **The stair down** (about 15 seconds of walking).
3. **The safe room.** A small stone room at the foot with a bench, a straw bed, a candle. Its only way out is a **crawl**, so the Doctor
   cannot come in. The first body in it wakes the Catacombs (the Doctor is put down at the far side, in his study; the crawlers go to their
   niches).
4. **The maze.** Dead ends, crawl shortcuts and pockets, six halls (the ossuary, the plague ward, the quarry, the gaol, the great crypt, the
   Doctor's study). Pages on little tables, blood on the floor, words in red on the walls, eyes and a grin on the wall at the end of ten long
   passages (see 5).
5. **The errand** (no fixed order; `Trial/Catacombs`):
   - **three levers**, in three wings, lift the iron gate at the head of the exit road (each pull is loud);
   - the **axe** (one of three tool racks in the quarry, rolled each run) cuts the fallen beams across the road (eight strokes, every one
     very loud);
   - the **key** (one of four chests, in the plague ward and the gaol, rolled each run) opens the iron door at the foot of the stair up;
   - **ropes** hang in four dead ends. Each rings a bell in another dead end, far off, and the Doctor walks to it: a way to move him.
   - **seven pockets** (dead ends entered by a crawl) are refuges with a candle and a small cache.
6. **The stair up**, and the mausoleum. The first body at the top ends the trial and lifts the yard's gate (as every area does).
7. **Pages (a deed, not needed for the gate):** nine, from the gravedigger to a child. Three are the Doctor's own hand: he cured the dead and
   they did experiments on him; he lost his sight and heard everything; "I am very big now, and very sorry." Read all nine for a prize.

Solo-first, as always: one player can do all of it. More players are faster (levers and strokes are shared), never needed.

## 4. How he hears (the heart of it)

Everything that makes a sound is a *noise* with a **loudness in studs of passage**: how far it carries ALONG THE PASSAGES. Walls stop it, so a
shout in the next corridor is as far as the way round to it, and the shut gate stops everything.

| Thing | Carries | Note |
|---|---|---|
| a crouched step | 7 | less than one cell: he must be all but on you |
| a walking step | 36 | about three cells |
| a running step | 52 | |
| a jump, a swing | 24, 30 | |
| a blow that lands | 42 | |
| a dead one going down | 64 | it also plays a sound |
| a lever | 60 | |
| the key in the lock | 34 | |
| a stroke of the axe | 90 | |
| a bell | 130 | at the bell |
| anything within 4 studs | always | breath and cloth |

He keeps the LOUDEST thing he heard for 9 seconds (a louder one pulls him off a quieter one). He then **goes to where it was** (Investigate),
**stands and listens** for 8 seconds, and goes back to his **round** (the middle of each hall and a few cells). A body that keeps walking near
him is **chased** step by step (he is faster than a crouching body, 13 against 8, and slower than a running one, 16: but running is loud).
A body in reach (6.5) is **struck**: a windup of 0.9 seconds that can be stepped out of, then 45 damage. He cannot pass a crawl: that is how
a crawl is a refuge. Crouching (Shift held, or C) is the whole game of the place.

The logic is `Domain/DoctorBrain` (a state machine), `Domain/Hearing` (what is heard) and `Domain/CatacombMaze` (the plan as a graph), all
with specs (`Tests/Catacombs.spec`); `Trial/Doctor` is his hands and ears in the world.

## 5. Fear

- **No light but the lantern** (30 studs, the walls stop it) and the odd candle at a page (7 studs). Swords and the like do not glow.
- **His eyes** are two white lights in the dark; nothing else of him is seen until the lantern touches him.
- **Watchers on the walls**: the same two white eyes, and under them a crooked grin, at the end of ten long passages, the height of his
  own eyes. You walk toward them; they are a wall.
- **Words in red** (28 of them, from 14 lines, some cut short): HELP, DO NOT MOVE, DO NOT RU-, IT HEARS, THE BELL IS A LIE... They are lit
  only by a lantern near them.
- **Blood**: pools, drags and smears (36).
- **Crawlers** (the dead that go low) in 14 niches, pockets and corners, more with more players; they wake only when a body is within 18
  studs. Killing one is a noise of 64 and a sound.

## 6. What is built, what is not (2026-10-31, evening)

Built, in the Forgotten Lands place, and walked in play with the Studio's character: the mountain, the cave, the painted words, the table, both stairs, the safe
room, the plan, the props, the scares, the light zones and the Doctor's body; the errand end to end (levers, gate, axe, beams, key, door, stair up, the trial
ends and the gate rises). The rules, the lantern, the dark and the Shift key are code with specs (312 pass). The numbers to tune by feel are all in
`configs/Catacombs`.

What a walk found (and the tools now do): the stairs must end at their doors (turns 2.75 and 3.25), a sill of stone must bridge the cut round each shaft, the water
that lies under the castle must be taken out of the plan's footprint, a walking light must not carry the `TLK_Lod` tag, and below the ground every light on a
body but the lantern's is put out.

Not in this version: real sounds (Roblox's own are used and named in `configs/Catacombs.Sounds`), a lantern that runs out of oil, animated eyes, more spawn points than the
three markers each area has (waves take each unit from one of the three at random: `configs/Waves.Defaults.Scatter`), the forest (it will need the lantern:
`Items.lantern`), weapon skins, and a play-through by a person (the chase through the maze, the crawlers, the Shift key).
