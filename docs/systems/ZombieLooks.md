# The Dead: seven looks for eight kinds (2026-11-14)

The developer asked (2026-11-14) to take every kind of the dead the game has and make them better: some changed a lot, some kept,
seven looks in all, each shown on all the kinds in ONE photograph so a whole look can be chosen at once. Weak spots they named:
no fingers or hands unless they can be done well; instead a very realistic skeleton from the middle of the arm down, no skin and no
blood. Everything must fit The Last Kingdom (and the game should become more frightening and last longer).

**Status:** the seven looks are built as a photo tool and shown; NONE is in the game yet. The developer picks (one look for all, or
a look per kind, or a mix) and then it is baked into `ServerStorage.Assets.Undead`.

## The eight kinds (the photograph, left to right)

| Kind | Master in `Assets.Undead` | Note |
|---|---|---|
| Crawler | `undead_shambler_scullion`, laid down by `Domain/CrawlerBody` | no legs, drags on its arms |
| Shambler | `undead_shambler` | the plain standing dead |
| Runner | `undead_runner` | fast, thin |
| Spearman | `undead_spearman` | pennon, brigandine |
| Hollow Knight | `undead_knight` | the hard one |
| The King | `the_king` | big boss |
| The Doctor | `plague_doctor` | catacombs boss |
| The Huntsman | `the_huntsman` | forest boss |

The Gravedigger, the Archer, the Sentinel, the Burned and the Scribe take the chosen look afterwards: it is the same recipe.

## The seven looks

1. **The Garrison, kept**: as the game has them; only the lowest ranks lose the skin of the hands.
2. **The Ossuary**: bone from the elbow down and from the knee down (real meshes for the arm and hand, parts for the shin and
   foot), a skull for a face, a ragged burial shroud, a rosary of bone beads, hollow-light eyes like embers.
3. **The Cinder**: the siege fire's dead: `CrackedLava` skin, glowing cracks (neon strips), charred rags with a glowing hem,
   embers and smoke, eyes like coals.
4. **The Rime**: the cold that came up from beneath (canon, Story section 6): ice skin, frozen mantle fringed with icicles, a crown of
   ice, frost breath and mist, pale blue light.
5. **The Drowned**: the moat's dead: swollen grey-blue skin, wet dark cloth, rope and chain, black weed hair, barnacles, dripping.
6. **The Faded Court**: the household that kept its manners: porcelain masks (full and half), tarnished gold, velvet that was
   bordeaux or midnight blue, ruffs, star brooches (the heraldry of Bestiary section 3).
7. **The Shrouded**: the plague years' dead: bound in linen, sacking hoods with a black void and two small lights, stitched mouths,
   rusted nails, a burial shroud.

No green and no moss (developer's rules), little red (Bestiary: dry wounds, rot and routine rather than gore).

## How it is made (all in `tools/zombie/`, loaded from the sync bundle, never reaches players)

- `Figures` the eight kinds from the masters. `Dress` role-based painting (skin, cloth, leather, metal, wood, bone, vein, eye),
  attach, spike, wrap, cloak, chain, cracks, beads, emitters (ember, smoke, frost, glint, drip, ash, breath), lights.
  `Bones` takes the flesh off a forearm and hand (hides it, joints and held weapons keep working) and welds the skeleton meshes;
  also the shin and foot. `Themes` the seven looks. `Showroom` a photo studio at (4000, 500, 4000), mood lights per look.
  `Run.stage(themeId, opts)` builds a photograph in one call.
- **The skeleton arm** (`tools/blender/make_bone_arm.py`, Blender 5.3 headless): radius and ulna with a gap, eight carpals, five
  metacarpals, three phalanges a finger and two in the thumb; right and left; 724 triangles a forearm and 2,120 a hand. Built in the
  frames of the bodies' own LowerArm and Hand (measured: long axis X, elbow at +X; thumb on -X for the right hand, +X for the
  left), so no turning is needed. Uploaded as asset `99818223615911` (register: `bone_arm_v1`).
- **Importer fact:** Roblox turns a glTF model half a turn about Y (x and z are negated). `Bones` undoes it: `RY180 * part.CFrame`.
- **Photo-studio facts (Edit mode):** a light with `Shadows = true` does not light anything in Edit here; the place's night is
  too dark to judge a face, so the studio lifts the ambient light and puts every number back on `clear()` (`TLK_Orig_*`
  attributes); a `MeshPart` texture ignores `Color` (the generated skull keeps its texture, otherwise it loses its eye sockets);
  the capture is about 2.67 : 1 and the camera sees 3.67 studs across per stud of distance; the camera is left Scriptable after a
  capture (set it back to Fixed).

## Cost to know before it goes in the game

Every look but the Ossuary is parts, materials and emitters on the body (no script). Lights and emitters are the dearest part of
a crowd: a spawn should keep the emitters and drop the lights (they are only for the photographs), thin the emitters on Low through
`GraphicsController` and tag them for `DetailLodController`. The bone arm is 2,844 triangles a side.
