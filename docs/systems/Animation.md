# Motion and Effects — Animation, Feedback, VFX, Sound (Design)

**Status:** DESIGN, written 2026-10-20. **Built 2026-10-20 (0.25.0): the dead's clips, the state protocol and the
client controller; feedback, effects and sound are not.** The sword cuts and guard in `Shared/Anim/SwordAnims.luau` are
the only finished motion in the game, and they set the standard this document extends.
**Reads with:** `Bestiary.md` (who moves), `Arsenal.md` (what the player does), `EnemyAI.md`.
**Tags:** **[BUILT]** · **[PROPOSED]** · **[LOCKED]**.

---

## 1. The house rules (taken from the sword work, now for everything)

The developer's own file says it better than I can; these are its rules, promoted from "how the sword
is done" to "how everything here is done":

1. **Anticipation.** Nothing moves in the direction it is going before it has loaded the other way. A
   fifty-millisecond dip before a swing is the difference between a puppet and a person.
2. **The hold.** The wind-up *arrives* and then does nothing for a moment (40–100 ms). A strike that
   leaves a dead stop reads far faster than the same strike leaving a moving arm — and the hold is where
   the **telegraph** lives. For the dead, the hold is the player's chance to answer.
3. **Follow-through, and two settles.** The blow carries past the target; the limb comes back past rest
   a little, then a smaller amount the other way, then stops. A blade that halts dead on contact weighs
   nothing.
4. **Easing per pose, not per clip.** Decelerate into the wind-up, accelerate into the strike,
   decelerate into the recovery. Linear interpolation is a windscreen wiper.
5. **No two attacks on the same rhythm.** Two cuts that are different shapes but the same length read as
   one cut played twice. Vary the durations by a fortieth of a second at least.
6. **Leave free what you do not key.** A pose that is absent from a keyframe is a pose the animator does
   not touch. Attacks key the arm and torso and leave the legs walking.
7. **Angle convention.** X swings a limb forward (+); Y twists; Z takes it out to the character's right.
   *Exception, learned the hard way:* on `UpperTorso`, +X leans the chest **back**.

---

## 2. How motion is produced **[LOCKED: the pattern is the developer's]**

- **Authored in code.** A clip is a table of frames (`time`, `ease`, and a CFrame per joint, in degrees)
  that builds a `KeyframeSequence` and registers it with `KeyframeSequenceProvider` at runtime. No
  upload, no asset ids, no Animation Editor in the way, and every change is a diff in git.
- **On the client, for everyone.** Registration is per machine, so each client builds the same clips and
  plays them on every character it can see, driven by what the server tells it.
- **Driven by attributes, not by remotes.** The server sets attributes on a body and every client
  watches them. For the dead this replaces any stream of per-frame messages and survives streaming (a
  body that streams in comes with its current state already set).

### 2.1 The state protocol for the dead **[PROPOSED]**

Attributes on the enemy `Model`, written by the server (`EnemyAIService`), read by
`ZombieAnimController` on each client:

| Attribute | Type | Meaning |
|---|---|---|
| `Type` | string | `undead_shambler`, … (chooses the clip set) |
| `State` | string | `Idle`, `Walk`, `Run`, `Aggro`, `Windup`, `Strike`, `Recover`, `Stagger`, `Emerge`, `Toll`, `Death` |
| `Seq` | number | increments on every new state, so the same state twice replays |
| `Variant` | number | gait variant 1–3, fixed at spawn |
| `Move` | number | current speed, for blending walk against run |
| `Hit` | number | hit-direction code, for the flinch and for the death fall |

`State` changes are the *only* thing the server sends about motion. Damage is applied by the server at
the **Strike** state's start (plus the clip's contact offset), to whoever is in the cone *then*; the
client plays the Windup from the same timestamp, so telegraph and consequence cannot disagree.

### 2.2 Clip sets and sharing
One base set per **body class** (Light, Heavy, Armoured, Archer, Quadruped), not per type — then each
type overrides only what makes it itself. Twenty-odd clips cover the whole roster.

---

## 3. The dead — clip catalogue

Times are seconds, provisional until tuned in play. *W* = windup (with its hold), *S* = strike, *R* =
recover. The hold at the end of *W* is where the player reads the attack.

### 3.1 Shared (every body)
| Clip | Loop | Notes |
|---|---|---|
| Idle | yes | breathing, a twitch every few seconds; arms never quite still; eyes (the Hollow Light) pulse slowly |
| Walk (×3 variants) | yes | the lurch / drag / stiff march (Bestiary §6); head lags |
| Aggro | no, 0.9 | the first time it sees a player: head snaps round, jaw drops, a rasp; **exhale burst of frost** |
| Flinch (light/heavy) | no, 0.25 / 0.6 | torso recoils away from the blow; heavy staggers one step |
| Stagger | hold 1.0–1.6 | a kneel; the dagger-finisher window |
| Emerge | no, 2.0 | rises from a grave, or climbs a wall, or bursts a boarded door — a different version for each |
| Death (×3) | no, 0.9–1.4 | falls forward / back / to the knees by `Hit`; the gear drops; ash leaves the body |

### 3.2 Per type
| Type | Move clips | Attack (W / S / R) | Tell |
|---|---|---|---|
| Shambler | Walk×3 | **Shove-bite** 0.8 (hold 0.2) / 0.15 / 0.6 | arm draws back, jaw opens, breath flash |
| Runner | Lope→Run | **Lunge** 0.45 (crouch, hold 0.12) / 0.2 (airborne, committed) / 0.9 | drops low with a hitch, then springs |
| Gravedigger | Heavy walk | **Overhead slam** 1.1 (hold 0.35) / 0.18 / **1.3 stuck** | spade rises, soil falls from it, a groan *before* the strike |
| Pikeman | Stiff march | **Thrust** 0.8 (hold 0.25) / 0.14 / 0.7 | spear draws back along the body, feet plant |
| Archer | Shuffle-step | **Draw** 0.9 (hold 0.3) / release / 0.5 | nock, a line of breath, a held draw |
| Shieldman | Wedge advance | **Bash** 0.6 / 0.12 / 0.5, then **Cut** 0.8 / 0.15 / 0.7 | shield rises, boots slide, shoulder drops |
| Sexton | Stoop-shuffle | **Toll** 1.4 (bell raised, hold 0.5) | the bell *is* the tell, and a ring on the ground |
| Cinder | Smoulder-walk | **Grab** 0.7 / 0.2 / 0.6 | arms out, embers flare |
| Hollow Knight | Slow march | **Sweep** 1.0 (hold 0.4, whole body winds) / 0.25 (360°) / 1.0 | the great sword goes behind the shoulder; the plate groans |
| The King | per phase | see Bestiary §8 | phase-specific: horn, bow draw with a ground ring, cold light in the seams |

**One rule for all attack durations:** no two attacks of one type share a length; and the *hold* is
never shorter than 0.12 s on anything that can hurt, or the first-time player cannot learn it.

---

## 4. The player — clip catalogue

| Clip | State | Notes |
|---|---|---|
| Idle, Walk, Sprint | loops | the sword's guard idle already exists **[BUILT]**; the others follow the same stance (nobody stands square) |
| Light attack ×2 | no | the sword's two cuts **[BUILT]**; other weapons get their own, *different in shape and length* (rule 5) |
| Heavy attack | charge + release | each weapon a different shape (thrust, hook, smash, half-sword) **[PROPOSED]** |
| Guard | hold | the sword's guard pose **[BUILT]**; shield guard adds the left arm **[PROPOSED]** |
| Parry | 0.18 window + 0.4 settle | a short sharp beat, the blade *rings* |
| Riposte | 0.5 | the follow-up the parry arms, faster than a cut |
| Roll | 0.55 | a committed tuck-and-turn, i-frames mid-roll; end-lag 0.35 |
| Back-step | 0.3 | |
| Kick | 0.4 | |
| Bow / crossbow | draw, hold, release / wind, aim, loose | |
| Bandage | 2.0 hold | kneeling, binding the left forearm |
| Search | 1.0 | kneel to a chest; lift the lid |
| Hit reaction, Death, Revive | | light flinch, heavy stagger, fall and rise |
| Release the King | hold | a kneel and a hand held out |

---

## 5. Authoring and tooling **[PROPOSED]**

The sword file builds clips with its own private `pose/keyframe/build` helpers. Extracting them into
one shared module (`Shared/Anim/Clip.luau`: `Frame`, `build`, `register`, with all joints, not only
the right arm) lets every clip in the game be written the way the sword's is, and lets a **preview
rig** in Studio play any clip on a dummy so it can be judged without a playtest. The sword file stays as
it is and becomes the first consumer; nothing of the developer's changes meaning.

---

## 6. Hit feedback — the numbers behind "it feels good" **[PROPOSED]**

| Event | Hit-stop | Camera | Knock-back | Sound layers |
|---|---|---|---|---|
| Light hit on the dead | 40 ms | 0.5° shake, 80 ms | 1 stud (Shambler) | blade-on-cloth thud + a wet-dry crunch |
| Heavy hit | 90 ms | 1.5° + a 2% FOV punch | 3–5 studs by weight | + low impact boom |
| Hit on armour | 60 ms | 0.8° | 0.5 | **metal ring**, sparks |
| Parry | 120 ms (both bodies) | 1.2° | the attacker staggers back 2 studs | a clear **ring**, shared with a spark |
| Taking a hit | 70 ms | 1.6° + a 0.15 s red edge | by weight | grunt + a dull thump |
| Kill | 100 ms | small push | falls by `Hit` | the dead's exhale, then silence |

Hit-stop freezes the attacker and the victim's animations (not the world), which is what makes the
blow feel heavy without making the game stutter. All of it is **client-side feedback**; damage stays on
the server.

---

## 7. Effects (VFX) — the list

Everything here is a `ParticleEmitter` or a small mesh; all of it respects the budget (§9) and the
distance LOD already built.

| Effect | Where | Look |
|---|---|---|
| **Frost breath** | the dead's mouths, moving | one slow thread of white; **the curse's signature** (Bestiary §2) |
| **Hollow Light** | the dead's eye sockets | two Neon dots; pulses on aggro |
| **Death ash** | every death | a short grey plume rising off the body, pale embers; the body lies a moment, then dissolves |
| **Impact: flesh/cloth** | player hits | a puff of dust and thread; no spray |
| **Impact: metal** | armour, shields | sparks, a ring-shaped flash |
| **Parry flash** | a parry | a white star-shaped burst (the falling star) |
| **Dirt flick** | Gravedigger | soil off the spade at the wind-up and a crater at the slam |
| **Toll ring** | the Sexton | an expanding ring on the ground when the bell rings |
| **Ember trail** | Cinder | embers dropping behind; a pool on death |
| **Arrow** | archers, player | a thin dark streak; a "thunk" and a splinter where it lands |
| **Frost rings** | the King, phase 3 | pale circles spreading across the forecourt that slow the player |
| **Torch/Brazier** | world | already built; the dead **hold off** from fresh flame (Bestiary §7) |
| **Cold light** | the King, phase 3 | cold white seeping through the cracks in his armour |
| **Release** | the ending | the crown cracks, the cold light goes out in a slow breath |

---

## 8. Sound — the list **[PROPOSED]**

Claude cannot generate or hear audio (see the project memory); the sounds are sourced (the Roblox
audio library, or uploaded clips the developer approves) and wired in by id. What is needed, so it can
be sourced in one go:

- **Ambience** per chamber: wind through broken thatch, distant bell, creaking timber, a smithy's tick of
  cooling metal, the hall's long reverberation, the Rows' empty street.
- **The dead:** a breathy rasp (idle, 3 voices), aggro cry, attack grunts per type, the Gravedigger's low
  groan, the Archer's creak of a bow, the Sexton's bell (a clear, flat chapel bell), death exhale.
- **Footsteps** by surface: gravel, grass, stone, planks, **mail** (the Hollow Knight's grinding).
- **Combat:** blade-on-cloth, blade-on-armour, mace-on-plate, shield-on-blade, parry ring, arrow flight
  and thunk, bow creak, a swing's whoosh in three weights.
- **Player:** breath when winded, bandage cloth, the roll's cloth-and-boot, a hurt grunt.
- **Music:** sparse. A low drone for exploration, a drum and one voice when a wave begins, silence at the
  gate opening (the loudest sound in the game, which is then the *absence*), a single plain melody for
  the King that breaks in phase 3.

---

## 9. Budgets

- **Dead on screen:** 45 at full detail; beyond ~80 studs the small accessories hide (the LOD tag).
- **Emitters on bodies:** frost breath only within 60 studs; death ash is one-shot; no body carries more
  than three emitters.
- **Animation cost:** a few joint writes per body per frame on the client, only for bodies within ~120
  studs (further: the idle pose, no updates).
- **Network:** nothing per frame. Attribute changes on state, nothing else.

---

## 10. Order of work, and what "done" means for each step

1. **Look first.** `tools/BuildUndead.luau`: a line-up of the roster on a test pad. *Done when:* a person who
   has not seen the list names each type's job from a 40-stud screenshot in the real fog.
2. **Motion.** Extract `Clip.luau`; author the shared set, then each type's attack. *Done when:* every
   attack passes rules 1–5 on the preview rig and no two share a length.
3. **The telegraph in the brain.** `Windup`/`Recover` in `EnemyAIService`, tokens, separation; attributes
   for the clients. *Done when:* a first-time player can dodge a Shambler with no instruction.
4. **Player verbs.** Stamina, roll, guard, parry, heavy. *Done when:* a roll through a Runner's lunge is
   reliable and a parry on a Pikeman's thrust feels like a gift.
5. **Feedback and effects.** Hit-stop, shake, impacts, frost breath, death ash. *Done when:* the same fight
   with feedback off feels dead.
6. **Sound.** Sourced, wired by id.
7. **Only then** the per-area mechanics (AreaPlan), which can finally lean on a fight worth having.

Each step ends in a short playtest and screenshots in `assets/Images/Reference/`, as the chamber work did.
