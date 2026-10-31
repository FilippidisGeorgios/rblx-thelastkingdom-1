# The bigger run: more to search, to do, to fear (design, 2026-10-30)

A design to talk through, not built. The developer asked for: bigger areas with more action (search, do, show,
fight), some of them frightening; ceilings or a better way to make the dark; a forest; catacombs under the ground
(a maze, a mine, low passages you crouch through). This is what I would do and why, in plain words.

**Words used here.** *Area* = one of the nine big yards of the castle (what the older docs call "chambers"). *Room* =
a space inside a building. *Layer* = a level above or below the ground. *Hunter* = a monster you cannot kill, only
escape. *Crouch* = ducking down to fit a low passage.

> **2026-10-31 update.** The developer chose how the Catacombs go: they are AREA 4 (they took the Graveyard's place), a mountain across the yard with a
> cave and a deep stair, a one-way safe room, a maze of narrow passages in total dark with only a lantern, and a huge blind plague doctor who
> hunts by sound. Written down in `docs/systems/Catacombs.md`; it replaces this page's sections 6 and 10 for the catacombs. The forest will need the
> lantern from the catacombs, so it comes after them (not before the gate as first thought).

## 0. What is built so far (0.41.0, 2026-10-30)

| Piece | Where | State |
|---|---|---|
| Crouching (key C, a button on a phone, the server decides when you can stand) | `configs/Crouch`, `World/CrouchService`, `Controllers/CrouchController` | **built and tested** |
| Light zones (a dark room, the same for everyone) | `configs/LightZones`, `Shared/LightZone`, `Controllers/LightZoneController` | **built and tested** |
| The Kitchens' cellar: search for a key, a door, a larder, a low passage, a flooded vault, the Crawlers | `tools/BuildCellar.luau`, `Trial/Cellar`, `configs/Trials` area 3 | **built; seen by measurement, not yet by eye** |
| The camera's zoom limit (25 studs) | `configs/Camera` | built |
| The entering scene, the mark key, the forest, the catacombs, the other big areas | | not built |

## 1. What there is today (counted in the Forgotten Lands place, 2026-10-30)

| | |
|---|---|
| The castle | one wall round everything, 376 wide and 2,250 long |
| Areas | **9**, in a zigzag, each 250 deep and about 340 wide inside the walls (about 85,000 square studs) |
| Things placed in them | **282 groups** (buildings, camps, carts, graves, stalls): areas 1 to 9 hold 26, 31, 33, 26, 27, 24, **81**, 16, 18; about 40,700 parts in all |
| Outside the walls | the moat, the bridge, the hill where the party arrives, and about **750 studs of empty land** between that hill and the gate (a burnt village, an old battlefield, a gallows and dead woods, as scenery only) |
| Under the ground | nothing. Over your head: a roof only on the buildings that have one |
| How long it takes | under an hour for someone who knows it |

**Why it is short.** An area is about 16 seconds of walking across. Each has one job and one fight, the weapons
are strong, and there is no reason to stop and look. Making the castle wider would only make the same walk longer.
What lengthens a run is **reasons to stop**: something to find, something to do, something that frightens you.

## 2. The shape of a big area: four parts

Every area that gets bigger has the same four parts, so a player learns the rhythm:

1. **Search.** Something is hidden and the area says where to look (a paper, a mark on a wall, a locked door
   whose key is somewhere else). Containers take a moment to open (a short hold), and some make a noise.
2. **Do.** The area's own job (the winch, the recipe, the braziers, the forge...), as built now.
3. **Hold.** The fight that the job calls down.
4. **Secret** (optional). A side way: a cellar, a roof, a locked room with something better inside. Players who
   look get more; players who do not still finish. (The standing rule stays: **solo-first**, one player can
   always finish; more players are faster, never the only way.)

**Show.** A *mark* key for the party (a ping): point at a door, a chest, a lever or a dead one and your friends
see it too. It makes searching a team thing and it costs almost nothing to build.

## 3. Which areas get bigger

Not all nine. A run where everything is long is tiring; the short sharp areas are what make the long ones matter.

| Area | Now | Becomes | Why |
|---|---|---|---|
| 1 Outer Ward | the cut barricade | stays short | an easy start |
| 2 Stables | find the handle, turn the winch | stays; add a hayloft to search | warm-up |
| 3 Kitchens | recipe and five villagers | **bigger: a cellar** under the kitchens (larders, a low tunnel to the well) | first low passage, teaches crouching |
| 4 Graveyard | braziers, graves open | **bigger: the entrance to the Catacombs** (see 6) | the fear starts here |
| 5 Smithy | forge, mine, door | **bigger: the mine is a level** (carts, props that fall, gold) and the Catacombs end here | the way up |
| 6 Great Hall | the siege | **roofed**, dark, the siege inside | the roof is already planned |
| 7 The Rows | the prisoner in the tavern | **bigger: a search of the houses** (81 groups are already there), a hunter walks the streets | most scenery already built, best place for fear |
| 8 Inner Ward | dig out the passage | stays; it is the big fight | pace |
| 9 Keep Steps | the King | stays | the end |

## 4. How to make room without breaking the castle

- **A. Make the yards bigger.** Edit `configs/Castle.luau` and run the resize tool. The walls, the nine gates and the
  streaming all depend on it, and everything placed inside would have to be moved. Cheap to try, **not
  recommended** (it only makes the walk longer).
- **B. Go up and down.** Roofs, wall-walks, towers, cellars, the crypt, the mine. The walls are not touched, the
  streaming costs little, and a layer is a *new place* rather than a longer walk. **Recommended.**
- **C. New places outside the castle.** The forest before the gate, the catacombs below. **Recommended**, together
  with B.

## 5. Ceilings and the dark

Two tools, used for different things.

- **Real ceilings** where something is a building: the Great Hall, the cellars, the crypt, the catacombs, the
  mine, the gatehouse passage, the keep, the tavern. Timber beams for the kitchens, stables and tavern; stone
  vaults for the crypt, the gatehouse and the catacombs. A real ceiling makes real shadow, so the dark is *real*:
  nothing to fake and the same for every player on every picture setting (the rule in `Settings.md`).
- **The entering scene** for the big yards that are open to the sky: when the party crosses the doorway line of a
  big area, the portcullis behind them comes down, the light changes smoothly (colder, darker; torches flare), a
  line of its name appears, and the fight is called. It is a short animation, with **no ceiling to build**, and it
  tells the player "it has begun". Light zones (a doorway line that changes the light) can also dim a room
  without a roof.

My advice: real ceilings in the six places above, the entering scene in all five or six big areas.

## 6. The two new places

### The Dark Forest (before the gate)

*Where:* the 750 studs of land between the hill and the bridge. The party has just stood on the hill and said "we go
in together"; the forest is the way there.

- It is night and almost black. **Your lantern is the light** (about 25 studs round you; the same for everyone, never
  changed by a picture setting). Black fog beyond.
- **You carry no weapon** until the hunters' lodge (the old armoury). Fear works when you cannot just fight.
- **The goal:** find 3 fuses and 2 tools (a crank, a key), spread along two or three paths, and use them to open
  the lodge and then the gate's winch. Papers on the way tell what happened to the hunters.
- **One hunter, two for a big party.** It hears running and hates light; it cannot be killed. If it catches you, you
  are downed and the party can raise you (the Death System as built). **Crouching** makes no noise.
- **Hiding places:** wardrobes in the huts, barrels, a hollow tree. **Safe places:** lit braziers, which the hunter
  will not enter, so the walk has rests.
- *Length:* about 6 to 8 minutes. *Solo:* the same, with one hunter.

### The Catacombs (under the graveyard)

*Where:* below areas 4 and 5, reached by stairs down in the chapel's crypt (or the open grave pit). They end inside
the smithy of area 5, so the underground is a route, not a dead end.

- **The crypt** (easy): stone, candles, tombs; the first dead dig up through the floor (the **Crawler**, built, not
  yet placed).
- **The maze:** about 7 by 7 cells with corridors 8 wide and 9 high; torches in niches that go out one by one;
  doors that open only with the right lever; the dead come up through the floor behind you.
- **Low tunnels** (3.4 high) join parts of the maze: you must **crouch**. The Crawlers are at home there.
- **The old mine:** rails, carts, timber props that fall when you take the wrong turn, gold in the walls. It meets
  the mine of area 5.
- *Length:* about 10 to 15 minutes. *Mandatory or a side way?* See the questions below.

## 7. Crouching (what it takes)

- A **crouch key** (C or Ctrl, held or toggled) and a small button on phones (a picture, no word).
- Crouched you are about 60% as tall (R15 body scale and hip height), move at about half speed and make **no
  noise** to the hunters. Low tunnels are 3.4 studs high so only a crouching player fits.
- Needs: a small client controller, a server check (a client that says it is crouching is only believed when it
  fits, and standing up in a low tunnel is refused), a crouch-walk clip, and a rule that a tunnel under a low
  ceiling keeps you down. About a day of work; everything underground rests on it, so it goes **first**.

## 8. The fear toolbox

Darkness with a small light; a lantern with oil that runs out; noise (running is loud, crouching is quiet); a
hunter you cannot kill; hiding places; a safe light to rest at; doors that slam; a shape in a window; a lit room that
is a trap; breathing and a heartbeat when the hunter is near (the project has no audio yet, so sound is a task of
its own). Fear is used in the forest, the catacombs and the Rows. The Great Hall and the Inner Ward are *action*,
not fear: a run needs both.

## 9. The time I am aiming at

First time through: **70 to 90 minutes** (now: about 50). For someone who knows it: **45 to 55 minutes**.
Roughly: forest 7, areas 1 and 2 10, kitchens with its cellar 10, graveyard and catacombs 25, smithy and mine 12,
Great Hall 8, the Rows 10, Inner Ward 6, keep and King 8. Tune with real runs.

## 10. The order I would build in

1. ~~**Crouch** and low passages~~ **(done, 0.41.0)**.
2. **The entering scene** (light zones are done, 0.41.0; the scene itself is not).
2b. ~~The first big area~~ **the Kitchens' cellar (done, 0.41.0)**: the model for the others (search, do, crawl, fear, a prize).
3. **The Forest** (it is outside the castle, so nothing existing is touched).
4. **The Catacombs** and the Crawler's first appearance.
5. **Bigger areas**, one at a time: the Rows, the Great Hall roof, the kitchens' cellar, the mine.
6. The mark (ping) key, sounds, more fear as it is playtested.

## 11. Questions for the developer

1. **No weapon in the forest?** (my advice: yes, until the lodge) or a weak one?
2. **Catacombs mandatory** (adds 10 to 15 minutes to every run) or **a side way with better loot**?
3. **How many hunters** for a big party (my advice: one per four players, at least one)?
4. **Fear for everyone**, or an option to switch the scary parts down for young players? (A "gentle" setting
   changes how loud, not how dark: the fairness rule again.)
5. Is **70 to 90 minutes** the right length for a first run?
