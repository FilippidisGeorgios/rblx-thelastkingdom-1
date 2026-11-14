# Walls that touch exactly: SeamAudit (2026-11-14)

The developer (2026-11-14): where two walls meet, the difference must be ZERO studs: not one a little inside the other (the stone
shows twice, and a face lying on another's face flickers), not one a little short of the other (a crack of light). Generated
buildings drift by a stud-fraction because their sizes are computed.

`tools/SeamAudit.luau` (Edit mode, loaded from the sync bundle; works in either place):

- `SeamAudit.scan(root)` finds, among axis-aligned block parts that share face area: **gap** (a crack, 0 to 0.5 studs),
  **overlap** (a shallow overlap, shallower than half the thinner part), **coplanar** (faces on one plane that overlap in space AND
  differ in colour or material: this is the visible flicker), **duplicate** (the same box twice). Deep overlaps (a beam sunk into a
  wall) are meant and are left alone.
- `SeamAudit.mend(issues)` closes them. Every face that should meet another is a node; each connected group of faces is brought to
  ONE coordinate (the face of its biggest part), so a chain of parts does not push a crack down the line. A coplanar fight is
  fixed by recessing the smaller part's face by 0.02 (that part is marked `SeamInset`, so the crack step does not pull it back).
  **Rule: the top face of a part (Y axis) never moves**: someone may be standing on it. A group that holds two top faces at
  different heights is left alone.
- `SeamAudit.heights` / `compare`: rays straight down on a grid, before and after: the proof that no floor, stair or ramp moved.

## Result (Forgotten Lands, saved as version 229, not published)

| Place | Cracks | Shallow overlaps | Faces fighting | Meeting exactly |
|---|---|---|---|---|
| Chambers 1 to 9 (about 14,000 parts) | 5 to 58 each, now 0 to 5 | 2 to 239 each, now 0 to 33 | 24 to 75 each, now 0 to 1 | 2 to 65 each, now 90 to 379 |
| The shell (castle ring wall, 3,545 parts) | 182, now 161 | 2,023, now 471 | 339, now 2 | 779, now 3,024 |

Heights: 0 changed in about 175,000 sample points after the top-face rule (an earlier version moved 15 samples by 0.3 in chamber 2
before the rule existed; those were not undone: 0.3 stud, under the step height).
What is left: pairs held by the top-face rule (a wall standing 0.3 into a floor: invisible), and 148 arrow-slits in the shell
that stop 0.34 short of the string course above them (a dark inset in a wall: the wall shows in the gap, no crack).

Run it again after every build tool (`BuildWards`, `BuildKeepInterior`...): scan, mend, scan, then compare the heights.
