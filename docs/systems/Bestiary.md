# The Dead of Asterfall — Bestiary (Design)

**Status:** DESIGN, written 2026-10-20. Nothing here is built yet; the unit in the game today is one
red anchored box (`EnemyService.buildRig`). This document is the brief for replacing it.
**Serves:** GDD Pillar 1 (atmosphere), Pillar 2 (story first), Pillar 4 (combat that is remembered).
**Reads with:** `Animation.md` (how they move), `Arsenal.md` (what the player answers with),
`EnemyAI.md` (the brain, already built), `AreaPlan.md` (where each appears), `Story.md` (canon).
**Tags:** **[BUILT]** exists in `configs/Enemies.luau` · **[PROPOSED]** new, needs a yes ·
**[LOCKED]** from canon or from an earlier decision.

---

## 1. The idea: the dead keep their stations

A generic zombie is a monster. These are *people*. Forty years ago Asterfall fell with everybody inside
it, and the curse did not make them hunt: it made them **go on**. The cook is still in the kitchen, the
sentry is still on the wall, the sexton still tolls his bell, the guard still bars the door of a king
who has not spoken in forty years. They do their work wrongly, and now the work is you.

That is the whole look of the game's enemies, and it does three jobs at once:

- **Story without exposition** (Pillar 2). A player who kills a pikeman in a brigandine with the
  star on its chest, and then a cook with a ladle, has read the castle's household without a word.
- **Readability.** Each role has its own *silhouette*, so a type is known at forty studs in dusk fog,
  before any detail resolves.
- **Variety without content cost.** One AI type can wear many *dressings* (§4). A shambler in chamber
  1 is a guardsman, in chamber 3 a scullion, in chamber 7 a baker.

> Test for every type, before it ships: take a screenshot at 40 studs in the real fog and ask someone who
> has never seen it what it does. If the answer is wrong, the silhouette is wrong.

---

## 2. What the curse looks like — three tells on every one of them

So that the cursed are known from the living at a glance (and the five cured villagers of chamber 3
read as a relief, not as a recolour):

1. **Grave-wax skin.** Blue-grey, bloodless, the veins dark at the neck and wrists. `(118,126,128)`
   lit, never green and never red. Cloth over it is the colour of what it was 40 years ago, faded.
2. **The Hollow Light.** Two small cold-white points in the eye sockets (a Neon part, **not** a light
   source — five hundred lights are already too many). Standard dead: dim. Elites: brighter. The King:
   the only one with a halo, and it is gold-white. *The cold came up from beneath the castle (Story §6);
   this is its mark.*
3. **Frost breath.** A slow thread of white vapour from the mouth when a dead one is moving, only
   within ~60 studs of the camera (the same distance logic as `DetailLodController`). It is what makes
   a dark chamber feel inhabited before anything is in view.

And one thing they *do* rather than *look like*: **they move wrong**. Gaits are deliberately out of
rhythm — a dragging foot, a head that lags the body, an arm that swings the wrong way (§6 and
`Animation.md`). The eye reads "dead" from the walk before the face.

**The cured** (chamber 3, `cured_villager`, `cured_villager_bow`) keep the same clothes, washed, with
warm skin, ordinary eyes and no breath. They are the only thing in the castle that looks alive, and
they should look it.

**Blood.** There is very little red. Wounds on the dead are dark and dry (ichor, soot, rust). This is
a deliberate choice: it keeps the game inside Roblox's content rules, and it is more medieval-gothic
than slasher — the horror is in the *rot and the routine*, not in gore. Player hits read as impact
(sparks off armour, dust and cloth-puffs off the dead), not as spray.

---

## 3. The heraldry — a falling star

Asterfall's device (name is provisional, like all proper names in the Story): a **white eight-point
star trailing a short tail, on a bordeaux field, fringed gold** — a star falling. It is the thing the
returning company wears (their tabards, now ragged), the thing the garrison and the King's household
wear (rotted), and the thing on the banners already hanging in the Great Hall.

- The UI already speaks **gold and bordeaux** (`Theme.luau`); the heraldry is the same palette in
  cloth, so the game's menus and its world feel like one place.
- The dead who served the crown wear it faded. The dead who did not (servants, townsfolk) do not. So
  *who wears the star* tells the player *who was on whose side* — and the Fallen King's own armour wears
  it whole.

Palette (all within Look A, "Dark Realistic"; cloth over `TLK_*` fabric MaterialVariants):

| Use | RGB | Note |
|---|---|---|
| Bordeaux cloth, faded | `(96,36,44)` | surcoats, tabards, pennons |
| Gold thread, tarnished | `(150,120,52)` | star, fringe, buckles |
| Undyed linen | `(150,138,118)` | servants, shrouds, aprons |
| Woad blue gone grey | `(70,84,100)` | townsfolk, garrison under-tunics |
| Mud / russet | `(88,66,50)` | peasants, grave-workers |
| Rusted iron | `(92,70,58)` | helms, spear heads, hinges |
| Blackened mail | `(50,52,56)` | coifs, hauberks |
| Bone | `(190,180,160)` | the sexton's charms, exposed bone |
| Skin, grave-wax | `(118,126,128)` | all of the dead |

---

## 4. Dressings — why no two are alike

A **type** is behaviour and silhouette (§5). A **dressing** is a cosmetic outfit that sits on a type.
Each chamber has a *pool* of dressings; the spawner picks from the pool for the room, so the same
shambler is a guard in the Outer Ward and a scullion in the Kitchens, with no code difference.

On top of the dressing, every spawn rolls small, free variations — the same idea the Rows use for
houses ("deal from a shuffled deck, do not roll"):

- scale ±6% in height and ±8% in width; one shoulder lower; head tilt;
- a **damage state**: an arrow in the back, a sleeve torn off, a missing hand wrapped in rag, a split
  helm, a rope still on the wrists (the dead hanged at the gallows);
- a **gait variant** (§6), assigned at spawn and kept for life;
- a head from the pool (eight: shapes, jaw, hair, hood, coif).

The deck is shuffled per wave so a crowd of twelve shows twelve different people, not four.

| Chamber | Dressing pool | Reads as |
|---|---|---|
| 1 Outer Ward | gate guard, sergeant's man, camp follower | the ones who barred the gate |
| 2 Stables | stable hand, groom, carter, farrier's boy | the ones who fed the horses |
| 3 Kitchens | scullion (apron, ladle), baker (flour-white), steward, spit-boy | the household below stairs |
| 4 Graveyard | gravedigger, mourner (black shroud), chaplain, pallbearer | the burying party |
| 5 Smithy | smith's apprentice (leather apron), armourer, miner (lamp, pick), charcoal-burner | the workers of fire |
| 6 Great Hall | household guard (full star), steward, musician, cup-bearer, lady's maid | the court at the last feast |
| 7 The Rows | townsfolk of every trade (the signs over the doors: cobbler, baker, chandler, weaver, butcher, apothecary) | the town |
| 8 Inner Ward | line infantry, field surgeon, standard-bearer, sapper | the last line |
| 9 Keep Steps | the King's own guard in plate, chancery clerks, the royal carriage's driver | the household of the crown |

---

## 5. The roster

Stats are the values already in `configs/Enemies.luau` unless marked **[PROPOSED]**; all of them stay
provisional until tuned in play. "Windup" and "Recover" are new fields needed for dodgeable attacks
(§7 and `Animation.md`).

### 5.1 Standard dead

**Shambler** — `undead_shambler` **[BUILT]** · *the household* · chambers 1+
- HP 60 · speed 7 · 8 damage · cooldown 1.6 · windup **0.8** · recover 0.6 **[PROPOSED fields]**
- *Silhouette:* hunched, one arm hanging, the other reaching; head forward of the shoulders.
- *Behaviour:* walks straight at the nearest player; slow, in numbers. The room's baseline — every
  other type is defined against it.
- *Tell:* the reaching arm draws back, the mouth opens (a drop of the jaw and a flash of breath) —
  then a slow shove-and-bite. Readable by a first-time player.
- *Counter:* back away, hit the gap, kick one into the next.

**Runner (the Couriers)** — `undead_runner` **[BUILT]** · chambers 2+
- HP 40 · speed 15 · 6 damage · cooldown 1.1 · windup **0.45**
- *Silhouette:* low, forward-leaning, arms trailing behind like a diver; a satchel or horn at the hip
  (the kingdom's messengers, still running).
- *Behaviour:* flanks round a crowd instead of through it; **commits** to a lunge from ~7 studs and
  cannot turn in the air.
- *Tell:* drops into a crouch with a half-second hitch, then springs. Fast but honest.
- *Counter:* a roll through the lunge; a braced spear stops it dead (see `Arsenal.md`).

**Gravedigger** — `undead_brute_heavy` **[BUILT]** · Elite · chambers 4+
- HP 260 · speed 6 · 30 damage · cooldown 2.6 · windup **1.1** (overhead) · stuck **1.3** after a miss
- *Silhouette:* the biggest thing in the room, hooded, burlap and leather, a long grave-spade or
  mattock held two-handed over the shoulder. Dirt falling off it.
- *Behaviour:* walks without hurry; the swing **cannot be parried**, only avoided. A miss buries the
  blade — a long, vulnerable pause.
- *Tell:* spade up, a flick of soil, a low groan *before* the strike (audio is half the telegraph).
- *Counter:* sidestep or roll, then punish the stuck frames; mace and heavy attacks stagger it.

**Pikeman** — `undead_spearman` **[BUILT]** · chambers 5+
- HP 90 · speed 7 · 16 damage · reach ~12 · windup **0.8** thrust
- *Silhouette:* the tall thin one, kettle-hat, brigandine with the faded star, a long ash-wood spear
  with a rag of pennon. A pole you can see before the man.
- *Behaviour:* stops at the edge of its reach and thrusts; stands in twos and threes with the points
  together. **Never thrown** (AreaPlan law: melee reach only, or ranged balance breaks).
- *Tell:* the spear draws back along the body and the feet plant.
- *Counter:* close the distance (inside the point, a spear is nearly harmless: a shove); or roll in.

**Wall Archer** — `undead_archer` **[BUILT]** · chambers 5+
- HP 55 · speed 9 · arrow 12 · draw **0.9**
- *Silhouette:* thin, hooded in a coif, a bow taller than its shoulders, a quiver at the back.
- *Behaviour:* keeps its distance (backs off inside `MinRange`), prefers a firing step or a wall; the
  arrow flies and can miss (honest misses: aim error, you moved, a wall was in the way).
- *Tell:* the nock, a thread of white breath, a held half-second draw — you can *see* the line.
- *Counter:* move; fight from cover (every barricade and ruin in nine chambers now does something).

### 5.2 New types **[PROPOSED]**

Each of these exists to put a *question* to the player that the five above do not.

**Shieldman** — `undead_sentinel` · Elite · chamber 6+ (the King's household)
- HP 180 · speed 6.5 · shield bash 10 + cut 22 · windup 0.6 / 0.8
- *Silhouette:* wide and low behind a **kite shield with the whole star on it**; a helm with a nasal bar.
- *Behaviour:* blocks every frontal hit inside a 120° arc. Presses forward in pairs (a shield wall).
- *Tell:* the shield rises and the boots slide; the bash comes with a visible shoulder drop.
- *Question:* "can you get round, or through?" — answered by a flank, a kick, the axe's hook (pulls the
  shield down), a mace or a heavy attack (guard-break).

**The Sexton** — `undead_sexton` · Elite support · chambers 4 and 8
- HP 150 · speed 5 · does not attack in melee (a weak swing of the bell, 8 damage)
- *Silhouette:* stooped, in the black of the chapel, a hand-bell the size of a head. Charms of bone.
- *Behaviour:* every ~14 seconds he **tolls**: in the graveyard it raises two dead from the nearest open
  grave; elsewhere the nearest dead rush at +20% speed for 6 seconds. He walks away from the player.
- *Tell:* the bell is the tell, and it carries (a ring on the ground at the toll).
- *Question:* "do I chase the one who is calling more?" — a priority target that costs you position.

**Cinder** — `undead_cinder` · Standard+ · chambers 5 and 8 (the burnt)
- HP 120 · speed 8 · 14 damage · resists fire
- *Silhouette:* blackened, cracked, still smouldering; a trail of embers.
- *Behaviour:* walks on you; on death it **flares** (a 3-second pool of embers at its feet, ~10 fire
  damage to anyone in it).
- *Question:* "do I stand where I killed it?" — punishes swinging in a pile and rewards knockback.

**Hollow Knight** — `undead_knight` · Elite+ · chambers 8–9 (the King's guard in plate) **[BUILT 0.31.0]**
- HP 300 (x2 at depth 8) · speed 6 · great-sword sweep 38 · windup **1.0** · `Armour 0.4` (an ordinary blow does 60%; the forge's Weight temper does 84%). Cut/pierce/crush are not separate damage types yet, so armour is one number.
- *Silhouette:* the tallest thing that is not the King: full plate, a great helm with a crest, the star
  on a surcoat that has outlived its owner. The eyes are the brightest in the castle apart from his.
- *Behaviour:* guards doorways and the way to the keep; wide 360° sweep after a long, loud wind-up.
- *Question:* "do you have something that breaks armour?" — the mace, the war hammer, a heavy attack,
  and the forge upgrade you chose in chamber 5.

**Hound** — `undead_hound` · optional · chambers 2 and 7 (the kennels)
- HP 45 · speed 17 · 7 damage · `Archetype = "Animal"`
- A quadruped needs its own rig and gait, so it is the last of the proposed units, and optional: build
  only if the pack-of-hounds moment is wanted in the Stables.

**The Crawler** — `undead_crawler` · Standard · **[BUILT 0.39.0, NOT PLACED YET]**
- HP 36 · speed 8.5 · 7 damage · reach 5 · notices you from 70 studs (a shambler: 110) · windup 0.8 (the shambler's)
- *Silhouette:* a body with no legs. A torso sloping up from the hips along the ground, the head lifted, the
  arms planted in front, the ribs and spine showing and two short thighbones broken off at the hips. It is
  low enough to be lost in a crowd of standing dead, which is its purpose.
- *How it is made:* at spawn, from a shambler body (`Crawler = true`; `Domain/CrawlerBody`): everything joined
  to a leg is found by following the joints out from the thighs and removed, the torso is laid down by the
  Root joint's C1 so the standing clips still read (a lean is a rise and fall of the front, a lurch goes forward),
  the head is lifted and the arms turned to reach. No new model, no new clip: it plays the shambler's walk
  (the arms drag) and shove (a reach from the floor).
- *Question:* "do you look down?" — it goes for the ankles of a party that is watching the doors.
- *Where:* not in any wave or area yet (`Difficulty.Areas.*.Unlocks`): its first appearance, and whether a
  chamber gets a dozen of them from a drain or a crack in the floor, is the developer's call.
- *Still to do:* a dedicated crawl clip (alternate arms, a drag of the hips) and a low hiss for the sound.

### 5.3 The cured **[BUILT]**
`cured_villager` (melee ×3) and `cured_villager_bow` (×2): the same bodies as the dead, restored (§2),
that follow the party through chambers 4–6. They share the living-skin palette and simple tool-weapons
(a ladle-turned-club, a woodsman's axe, a short bow). Their animations are the dead's, minus the wrongness.

### 5.4 Roster at a glance

| Type | Role | First seen | Question it asks |
|---|---|---|---|
| Shambler | baseline, numbers | 1 | "are you spaced?" |
| Runner | punishes retreating | 2 | "can you stand your ground?" |
| Gravedigger | slow, lethal | 4 | "do you know the gap?" |
| Sexton | support, summoner | 4 | "who do you hit first?" |
| Pikeman | reach | 5 | "can you close in?" |
| Wall Archer | range | 5 | "do you use cover?" |
| Cinder | punishes piling | 5 | "where do you stand?" |
| Shieldman | blocks the front | 6 | "can you get round?" |
| Hollow Knight | armour | 8 | "can you break it?" |
| The King | everything | 9 | all of it, in sequence |

Most of these ask a different question, which is the point: nobody should be able to beat the castle
with one move, and every area should feel like a change of *problem*, not a change of numbers.

---

## 6. How each one moves (see `Animation.md` for the clips)

| Type | Gait | The wrongness |
|---|---|---|
| Shambler | lurch: weight thrown from one hip to the other, one foot dragged | head lags a beat behind the body |
| Runner | all-fours lope that straightens into a run | arms swing *backward* |
| Gravedigger | heavy, flat-footed, shoulders rolling | the spade never touches the ground, as if weightless to it |
| Pikeman | stiff march, upright | steps in time with nobody |
| Archer | shuffling sidestep, bow arm held out | draws and releases with too-regular a rhythm |
| Sexton | stoop and shuffle, bell swinging | the bell rings out of step with his walk |
| Shieldman | wedge advance, shield forward | stops dead, then lunges |
| Hollow Knight | slow, measured, armour grinding | turns with the whole body, never the head |

Every spawn picks one of **three gait variants** for its type and keeps it, so a crowd has no
synchronised footfalls (the single cheapest thing that makes a crowd look *wrong* in the right way).

---

## 7. Behaviour that the brain must grow (small, specific)

The existing FSM (Idle/Chase/Attack/Return/Dead) is right. It needs five additions, none of which
changes its shape:

1. **Windup and recover.** An attack is *start → windup → strike → recover*. Damage is dealt at the
   strike, to whoever is still in the cone. This is the change that turns a damage race into a fight
   you can play: dodges, parries and interrupts all hang on it. Fields `Windup`, `Recover` in the `AI`
   block.
2. **Attack tokens.** At most 3 of the dead attack one player at once; the rest circle at ~7 studs and
   take a turn. This is what makes forty zombies a *fight* instead of a sum.
3. **Separation.** The dead keep ~2.5 studs apart (no stacking into one body); they surround.
4. **Hearing.** Noise draws the dead: sprinting, a bell, the forge hammer, a shot. It makes the area
   mechanics tense (hammering the anvil is loud) without a new system.
5. **Fire.** A fresh brazier or a carried torch holds standing dead at ~6 studs while it burns. It is
   period-true (the dead fear the hearth in every story), it gives the grave braziers of chamber 4 a
   meaning beyond "a switch", and it is what a torch is *for* in chamber 5.

Everything else — what spawns where, how many — is `Waves`/`Difficulty`/`AreaPlan` and already exists.

---

## 8. The King — a fight, not a health bar

`the_king` **[BUILT 0.32.0: Trial/King, three faces, kneels, "Release him"]** · HP 2400 · nameplate **"The King"** **[LOCKED]**. Armour, a shield on the back, a
sword, and a bow. The arena is the keep forecourt below the Steps: the carriage on its side, the dry
fountain, the statues, the guard's last ring of carts. Cover is real and he uses the same cover.

**Three phases, one rule: each phase asks the player to answer what the previous one taught.**

1. **The Crowned** (100–66%). Shield and sword, the arming sword's two-cut rhythm mirrored back at the
   player (he is what they could become). Presses with shield bashes, one overhead that cannot be
   parried. At 80% the guard answers his horn: two Shieldmen at the gate.
2. **The Archer King** (66–33%). He withdraws to the Steps and draws the great bow: volleys with
   **ground markers** (a ring of pale frost where the arrow will land), a leap-back when pressed, a
   shot through the cover that you *thought* was safe. The forecourt's carts and statues are the
   puzzle.
3. **The Hollow** (33–0%). The power beneath the castle takes over: the armour cracks and shows cold
   light through the seams, the shield is gone, the sword is now two-handed. No horn, no bow — just him,
   faster, with the frost spreading across the forecourt floor in rings that slow the player.

**The ending is not a kill [LOCKED: Story §8].** At 0% he does not fall. He kneels, the light goes out of
his eyes, the crown cracks. The final input is a held **"Release him"** that every player in the party
can add to — not an attack. Then the keep door opens and an arrow appears on the ground (AreaPlan §9).

---

## 9. Equipment of the dead — the gear list (what the builder needs)

This is the "store the whole kit" list; every item is a small Model assembled from parts (and a few
MeshParts), kept in `ServerStorage.Assets.Undead` (not Rojo-owned) and chosen by the dressing.

- **Heads/helms:** coif, kettle hat, nasal helm, great helm with crest, hood, cloth cap, mourner's veil,
  bare (eight face shapes).
- **Body:** linen shirt, apron, tunic, gambeson, brigandine, mail hauberk, plate cuirass, black shroud,
  burlap cloak, leather smith's apron, tabard with the star.
- **Weapons (in their hands):** grave-spade, mattock, spear with pennon, hunting bow, quiver, arming
  sword, great sword, mace, kitchen ladle and cleaver, pitchfork, torch, hand-bell, billhook, pike.
- **Shields:** kite (star), round buckler, tower shield (from the Sentinel's death, see `Arsenal.md`).
- **Props they carry:** satchel, horn, lantern, keys, bucket, loaf, rope on the wrists, a rag-wrapped
  stump.
- **Wounds:** arrow in back, split helm, torn sleeve, rag bandage, missing hand, burn blackening,
  rope burn at the neck.

**Spoils [PROPOSED, run variety].** An Elite drops the signature piece it carried with a roll (a Shieldman
may drop its shield, a Pikeman its spear, a Knight its helm). Taking what the dead hold is both a
weapons-variety mechanic and the clearest way the game says *these were soldiers once*.

---

## 10. How they are built (the technical brief)

**Rig.** A real body, R15-named joints (`LowerTorso/UpperTorso/Head/Left+RightUpperArm/LowerArm/Hand/
UpperLeg/LowerLeg/Foot`) joined by `Motor6D`s, so any R15 keyframe sequence (including the sword cuts
already in `Shared/Anim`) fits it. `HumanoidRootPart` (the collision proxy the AI already moves with
`PivotTo`) stays anchored; the limbs are welded to it. A `Humanoid` stays as the health bar
(`HumanoidAdapter` already binds it) with its state machine off (`EvaluateStateMachine = false`,
`BreakJointsOnDeath = false`).

**Parts.** 60–90 per body, `CanCollide = false` except the root, `Massless`, `CastShadow` only on the
big pieces; limbs are blocks and cylinders, cloth is wedges that hang and swing (the same craft as the
thatch and banners already built). Meshes only for props. Materials are the `TLK_*` MaterialVariants,
so the dead look like they belong to the castle.

**Where.** `tools/BuildUndead.luau` builds one model per type into `ServerStorage.Assets.Undead` (edit
mode, rerunnable, like the other tools); `EnemyService` clones it instead of `buildRig`. A dressing is a
`Folder` of accessories welded on at spawn.

**Built (2026-10-20, v2).** `tools/BuildUndead.luau` builds seven masters (shambler in two dressings,
runner, gravedigger, pikeman, archer, shieldman) of 104–156 parts each. v2 is the realism pass: **round
limbs** (cylinders) with ball joints instead of blocks; a skull made of a cranium, hollow cheeks, deep
sockets with the Hollow Light, a ruined nose, teeth and a jaw that hangs open; curled fingers; exposed
ribs and spine through a torn shirt, dark veins, blotches of decay; ragged hems, cloaks and tabards cut
into strips so the edges are torn rather than straight; riveted brigandine, mail, weathered iron;
poses baked into the joints and the body lowered so the lowest foot stands on the floor. In a playtest
the developer's own `SwordAnims` cut, registered on the client, drove the shieldman's right arm through
the Animator (the shoulder's `Transform` went from identity to the cut, the hand moved ~1.9 studs in
0.2 s): the R15-named skeleton and the client-side clip pattern work together, with no change to either.
Pictures: `assets/Images/Reference/undead-v2-*_2026-10-20.jpg`. Still first-pass: one head shape, no
animation, no frost breath, the hats are too round, and the part counts need the LOD below.

**The fine kit (2026-10-20, v3).** At the developer's request ("many very small cubes, not three blocks
and call it a sword") the heads, helmets, weapons, shields and armour are now **sculpted** by
`tools/BuildUndeadKit.luau`: each piece is a shape function sampled on a 0.02–0.03-stud grid (a sword is
~5,500 cubes, a head ~70,000), each row of same-coloured cubes merged into a box, and the boxes of one
material fused into a UnionOperation that keeps every cube's colour. 21 pieces in
`ServerStorage.Assets.UndeadKit`: four heads (gaunt, heavy and stubbled, torn cheek and bare skull, old
with long hair; heavy-lidded clouded eyes, nose, bloodless lips, yellowed teeth, veins, mottled skin),
kettle hat, nasal spangenhelm, mail coif, arming sword (diamond section, fuller, nicked edges, curved
quillons, cord-wrapped grip, wheel pommel), spear head and ash shaft (leaf blade with midrib, socket,
langets, rivets, leather grips, butt spike), two-tone yew longbow (horn nocks, leather grip, string),
arrow (barbed broadhead, crested shaft, barred fletching with a dyed cock feather), kite shield (painted
falling star with chipped paint, iron rim and rivets, boss, a split and a bite out of the edge, planks
and arm straps behind), grave-spade, brigandine (brass rivet rows), hauberk, pauldrons, vambraces,
greaves, quiver. `BuildUndead` mounts them on the bodies and keeps the plain parts only as a fallback.
Pictures: `assets/Images/Reference/undead-v3-*` and `undead-kit-*`.

**The cost, honestly.** Each fused box keeps its own faces, so the kit is heavy in triangles: a shambler
~80k, an archer ~170k, a pikeman ~310k, a shieldman ~420k (the brigandine alone 135k). Unions use
RenderFidelity Automatic, so the engine thins them with distance, but a crowd of shieldmen at arm's length
is more than a phone should draw. Before the dead go into a wave the kit needs a **field version**:
the same shapes at twice the voxel size and with fewer colour steps (about a quarter of the triangles),
kept for the standard dead, with this fine version for elites, the King and close-ups.

**In the game (0.25.0).** `EnemyService` clones these bodies (`Body` in the enemy config), the AI writes the
state onto them and `ZombieAnimController` animates them; the field kit (voxel x2) is what spawns, the fine
kit is a tool run away (`BuildUndeadKit` QUALITY "fine", then `BuildUndead` QUALITY "fine").

**Budget.** The v2 bodies are 100–160 parts. That is for the dead you fight at arm's length: **45 at full detail**
(~6k parts), and beyond ~60 studs the client hides everything small (face pieces, fingers, rivets, strips,
veins: the parts the builder marks `CastShadow = false` are the candidates) through the existing LOD tag
mechanism, so a crowd costs a silhouette, not 130 parts a head. If a phone cannot carry it, the first cut is
the face and the fingers beyond 30 studs.

**Animation.** Client-side, from replicated attributes on the model (`State`, `Variant`, `Seq`), the
same pattern the sword work uses — no per-frame remotes. See `Animation.md`.

---

## 11. Open questions for the developer

1. **Hound** — build it (Stables, Rows), or leave the dead human only?
2. **Gore level** — the plan is "ichor, rust and soot, no red". Confirm.
3. **Names** — Courier, Pikeman, Wall Archer, Shieldman, Sexton, Cinder, Hollow Knight are working names.
4. **The star** — keep the falling-star device, or choose another for Asterfall?
5. **Spoils** — Elites dropping their signature gear as a run-variety mechanic: yes or no?
