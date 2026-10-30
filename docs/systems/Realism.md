# The realism pass: sculpted models for the dead and for the weapons (first test, 2026-10-30)

The developer saw that the zombies, bows and arrows are "built from blocks" and wants smooth models with faces and skins; their own
sword is a sculpted mesh and is the standard. This is the first test of what the Studio tool `generate_mesh` can give, and what to do next.
Nothing here is in the game yet: the five test models are kept in `ServerStorage.Assets.RealismTests` (not Rojo-owned) of the Forgotten Lands
place, for looking at.

## What was tried

| Model | Prompt (after the key) | Result | Asset id |
|---|---|---|---|
| `Bow1` | a medieval wooden longbow with a leather-wrapped grip and a taut hemp string, weathered dark yew wood, realistic | **bad**: three separate pieces (a grip, a curved limb, a loose stick) that do not make a bow | 70720280544781 |
| `Arrow1` | a single medieval arrow with a steel bodkin head, a straight wooden shaft and grey goose feather fletching, realistic | **half good**: the arrow reads (shaft, steel tip, fletching) but the fletching is one large white blob and the model carries a stray bow curve beside it | 112309854627383 |
| `Head1` | a realistic undead zombie human head, gaunt face with sunken eyes, grey-green pale decayed skin, a torn cheek showing teeth ... | **a smooth head with a face and hair, but cartoon style** (black empty eye holes, a skull nose): wrong for the dark realistic look | 71075223229533 |
| `Bow2` | one single longbow standing upright, a smooth continuous curve of dark yew wood, leather-wrapped grip in the middle, a thin taut bowstring from tip to tip, no arrow, realistic medieval weapon | **good**: one clean strung longbow with a wrapped grip, nocks and a string; readable at game distance | 103800020038442 |
| `Head2` | a photorealistic dark fantasy undead human head, hollow cheeks, grey bruised skin, cracked lips, sunken bloodshot eyes with eyelids and eyeballs, scars, thin patchy hair, realistic proportions, not cartoon, facing forward | **good, and fitting**: realistic skin, red-rimmed sunken eyes with lids, nose, lips, burial wraps over the skull (the dead of the castle lay in a mortuary in shrouds) | 87857368891994 |

(The two heads face -Z; a view from +Z shows the back of the hair.)

## What this says

- **The same tool, asked precisely, gives usable models.** The difference between Bow1 and Bow2 is the wording: *one single*, *standing upright*,
  *smooth continuous curve*, *no arrow*. The difference between Head1 and Head2: *photorealistic*, *not cartoon*, the parts of the face named.
  Vague prompts produce several objects, or a cartoon.
- **Size is not obeyed for small things** (the bow and arrow came out half a stud across): scale the model afterwards (`Model:ScaleTo`).
  A head obeyed it.
- A model is one MeshPart with a texture (`MeshId`, `TextureID`), static. It has no skeleton: a **head** can be welded to the neck joint of
  the existing body (the joints are R15-named, so every clip still fits); a **whole body** cannot come from this tool.

## What to do next (in this order)

1. **Weapons.** Make a bow (use `Bow2`'s wording), an arrow with a clean fletching, a quiver, a spear; weld to the hand of the archers and
   to the back (the existing `WeaponVisualService` is the developer's own work in progress: do not touch it; a new piece goes beside it). Each
   needs a grip point (an Attachment) and a scale.
2. **The dead's heads.** A few different heads (a young one, an old one, a woman, a soldier with a helm, a burnt one) from the Head2 wording, welded
   to the Head joint in place of the box-and-cylinder skull (`tools/BuildUndead`), keeping everything else. Tint and wear to the dressing.
3. **Limbs, hands and clothes** as meshes with textures (`generate_texture` re-skins an existing mesh), one part at a time, tested with the
   clips. This is slow and each part may need tuning.
4. **Full bodies** by an artist (rigged, PBR textures) are the Steam-quality answer; they are made outside Studio and uploaded by the developer.
5. Then the animation, design and sound passes the developer has planned (the project has no audio yet).

Generation limits (from `ItemArt.md`): three at a time, a prompt with "fire" can fail moderation, `maxTriangles` 3000 for props and 6000 to 8000
for a head.
