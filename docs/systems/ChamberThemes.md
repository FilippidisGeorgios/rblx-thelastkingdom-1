# The nine chambers

Notes behind `tools/BuildWards.luau`, which builds all nine chambers (1–3 on
2026-10-19, 4–9 on 2026-10-20) to be believed: timber frames, thatch, stone,
rooms you can walk into and climb, and the dead can follow. The older
`tools/BuildChambers.luau` no longer runs on the widened castle. The z ranges
below are the widened castle's (250-stud chambers).

## Chambers 1–3 as built (BuildWards)

- **1 Outer Ward** — stone-and-timber guardhouse with a fighting deck on the roof,
  a long thatched barracks (beds, hearth, upper dormitory), the gatekeeper's
  lodging, the sergeant's house, the muster yard (dummies, butts, spear racks), a
  timber watch platform, the camp that burned, the armoury lean-to on the east
  wall, a store shed, a woodshed, a fallen building, and a barricade across the
  yard facing the gate with one gap for the road.
- **2 Stables** — the stable range (stalls kicked out, hayloft above with hoist
  beams), the tack room, an open hay barn, the farrier's forge (hearth, bellows,
  anvil, quench), the carriage shed, the paddock with its rails down.
- **3 Kitchens** — the kitchen hall (great hearth and cauldron, long tables,
  servants above), the bakehouse with two domed ovens, the boarded well, the
  granary on staddle stones, two stores emptied in a hurry, the kitchen garden
  (wattle hurdles, beds, a scarecrow), the smokehouse, the sty, a woodshed.

## Chambers 4–6 as built (BuildWards, 2026-10-20)

- **4 Graveyard** — a stone chapel (nave, lower chancel, lancet windows, slate
  roof, a bell-cote on the west gable, a porch on the north door) used as a
  mortuary: the dead laid out in rows with candles, the altar, the rood, a
  lord's tomb with its effigy. Round it the churchyard: a low wall broken in
  places, a lychgate where the road comes in, old graves gone green, table
  tombs (one opened from inside), a broken churchyard cross, a family vault
  with its gate hanging off. East of the wall, the new field: fresh graves too
  close together, some open, some dug and waiting, a pit dug into the ground
  with the shrouded dead in rows and lime over them, the cart that brought
  them, a pyre still burning. The sexton's house and the coffins he made, a
  charnel house, a free-standing timber belfry you can climb. Four braziers,
  laid and unlit, one to each section of ground.
- **5 Smithy** — a stone forge open along its front in six bays, two hearths
  backing onto two stacks, bellows, anvils on blocks, quench troughs, the bench
  of half-made blades; a blade still in the fire. The armoury (racks, mail on
  stands, shields; a loft of swords and helmets), the smith's house. The mine
  in the south-west corner: a rock hill in the terrain, an adit 30 in on timber
  sets, rails, tubs, ore, gold in the walls. The oil store on the west wall,
  a rack of unlit torches by the forge. Dead trees to fell, an axe left in a
  stump, the saw pit and the planks already sawn. The bloomery and the
  charcoal clamp, smoking.
- **6 Great Hall** — 120 × 46, rubble stone, buttressed, tall lancets high up,
  an open roof of arch-braced trusses under slates and a louvre over the
  central hearth. The road runs through it by the screens passage (north
  porch to south door) under the minstrels' gallery, which a stair climbs.
  The dais at the west end with the high table, the lord's chair and the cloth
  of estate; tables down both sides, most thrown over, one still laid;
  chandeliers, banners, sconces. Four doors, each eight wide. Around it the
  solar wing, the buttery, the court where the last feast was laid out under
  pavilions, the lord's garden, the chamberlain's house, a range that burned
  and one that fell.

## Chambers 7–9 as built (BuildWards, 2026-10-20)

- **7 The Rows** — two streets of seventeen houses, every one written out (no
  two alike: eaves to the street or gable to the street, one storey or two,
  jettied or not, thatch or shingles, stone or timber below, and each washed
  its own colour — cream, ochre, rose, white, grey, sage, blue). Trade signs on
  iron brackets (cobbler, baker, chandler, weaver, butcher, apothecary), water
  butts, flower boxes long dead, bunting strung across. The market square
  between them: the roofed market cross, stalls, the stocks, carts; the market
  hall (an open stone arcade, the guild's room above) on its west side and the
  tavern on its east, where the villager is tied to a chair. Gardens behind
  in wattle, a privy, a hen house.
- **8 The Inner Ward** — the last line: a palisade across the ward with its
  gate and two breaches, a firing step behind it you can climb, stakes before
  it, braziers still lit. Behind it the camp it guarded: the field hospital
  (cots, bandages), the command tent with its map, stands of spears, a broken
  mangonel, a cart burning. The marshal's house on the near side with a
  fighting deck; a pyre in the field. And the tower that came down: its stump,
  five drums of its shaft lying across the yard with the loops on their sides
  and the string courses running round them like hoops, its crown smashed at
  the far end. Its top is the only high ground; two slopes of rubble are the
  only ways up. Masonry heaped either side of the passage out.
- **9 The Keep Steps** — the keep against the back wall, 68 × 56, its parapet
  at 72 and its corner turrets at 84, higher than the curtain; loops low,
  lancets high, the realm's banners down its face. A great flight of stone
  steps between parapets to a landing at 18, and the door there shut and
  barred. The forecourt below: kings of the line in stone (one thrown down), a
  fountain gone dry, braziers, the King's guard's last ring of carts and crates
  and their shields where they fell, the royal carriage on its side. The
  treasury, the chancery, the guardroom; the king's knot garden gone brown.

Every building can be entered; every raised floor is reached by a stair the
dead can climb.

The serpentine already works as a route. What it does not yet do is tell you
where you are. Nine identical yards would be nine identical fights; nine
*places* make the walk mean something, and let a player say "I'm at the
graveyard" without a map.

The order is not decorative. It runs outward-in: the parts of a castle a
stranger would see first, then the parts only its household used, then the last
place anybody was alive.

| # | z | Place | What it was | What it is now |
|---|---|---|---|---|
| 1 | +20 → -230 | **Outer Ward** | Guardhouse, muster yard | Barricaded from the inside. They knew what was coming. |
| 2 | -230 → -480 | **Stables** | Horses, forage, farrier | Stalls smashed outward. Whatever left did not use the door. |
| 3 | -480 → -730 | **Kitchens** | Bake ovens, well, stores | Cold ovens, a boarded well, stores emptied in a hurry. |
| 4 | -730 → -980 | **Graveyard** | Chapel and burial ground | New graves, dug badly, and more of them than the ground was meant for. |
| 5 | -980 → -1230 | **Smithy** | Forge, armoury, quench | Weapons half-finished on the bench. It was still working when it stopped. |
| 6 | -1230 → -1480 | **Great Hall** | Feasting, court, banners | The largest ruin here, roof gone, table still standing. |
| 7 | -1480 → -1730 | **The Rows** | Servants' houses, market | Ordinary streets. The only place in the castle that was ever cheerful. |
| 8 | -1730 → -1980 | **Inner Ward** | Last defensive line | A tower down across the yard. The line broke here. |
| 9 | -1980 → -2230 | **Keep Steps** | The way in to the keep | The end. Whatever it was, it went in there. |

## Rules the builder follows

**Nothing on the path.** The route is drawn first and every building tests
against it, so the road is never blocked and never has to be un-blocked by hand.

**Nothing near a spawn.** Enemies arrive at fixed marks; a building on top of
one drops zombies inside a wall.

**Buildings face the path.** A door that opens onto a wall reads as generated.
Every entrance is turned toward the route, because that is where people walked.

**Ruin gets worse as you go in.** Chamber 1 is barricaded but standing; chamber
8 has a tower lying across it. The damage should read as a fight that moved in
one direction and lost ground the whole way.

**One folder per chamber**, and every building its own Model, so a whole house
can be grabbed and moved in one click.

**No two houses the same.** Buildings are assembled from independent traits
rather than picked from a handful of fixed shapes. See `HouseAnatomy.md` for what
those traits are and why the Rows deal from a shuffled deck instead of rolling.
