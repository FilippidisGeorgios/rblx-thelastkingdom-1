# Movement: one walk for everybody, running with stamina, the roll, the mouse lock (2026-11-05)

**Status:** BUILT (0.45.0). Numbers in `configs/Movement.luau`; rules in `Shared/Stamina` (with `Tests/Stamina.spec`).

## What the developer asked for (2026-11-05)

- Everybody walks the **same** way, like the Roblox game **Command An Army** (Fight, Fight, Fight!).
- **Shift runs**, with stamina. Roblox's own Shift lock is taken away.
- A **mouse lock** in our Settings instead: the mouse held in the middle under a very small dot.
- A **stamina bar**, blue, right under the health bar.
- Stamina: **6 seconds** of running on a full bar; it starts to fill **1 second** after the last run or roll and is full
  again **15 seconds** after empty.
- **Q rolls**: a quick tumble (the head goes under), toward the keys held (W, A, S, D), costing **1.5 seconds** of the
  bar, so a full bar is exactly **four rolls**. It takes about half a second to a second and covers more ground than
  walking or running in that time ("walking 2 studs a second, the roll 4 to 6": a way to get away, not a teleport).
- **No back-step.**
- **Three whole movement sets** to look at (idle, walk, run, jump, roll each); the roll may be the same for all three.

## How it works

| Thing | Number | Where |
|---|---|---|
| Walk | 16 studs a second (Roblox's own) | `StarterPlayer.CharacterWalkSpeed` |
| Run (Shift held) | x1.5 = 24 | `Movement.Run.SpeedMult` |
| Stamina | 6 s of running, fills after 1 s, empty to full in 15 s | `Movement.Stamina` |
| A run that empties the bar | stops; needs a new press of Shift | `Shared/Stamina` (`spent`) |
| Standing still with Shift held | costs nothing (only moving drains) | `Movement.Stamina.MovingSpeed` |
| Roll | 1.5 of the bar, 0.58 s, 20 studs, fast at first and slowing | `Movement.Roll` |
| Roll while crouched | not allowed (and crouching stops a run) | `MovementService`, `CrouchService` |
| Crouch | C only now (Shift was its held key; Shift runs) | `configs/Crouch.HoldKey = nil` |

Measured in a Studio play test (2026-11-05): a full bar ran for 6.0 s at 24 studs a second, then the speed fell to 16 and
the run stayed off with Shift still held; the bar started to fill about a second later and climbed 0.12 every quarter
second (full in 15 s). A roll: 0.59 s, 20.2 studs (walking covers 9.4 in that time, running 14.1), bar 6 -> 4.5. Five
presses of Q in a row: four rolls, bar 4.5, 3, 1.5, 0; the fifth did nothing.

**Who decides.** The server (`Server/Services/MovementService`, both places) keeps every player's bar, takes and gives back
the running speed (the same "claim" handshake as the crouch and the charms, so the King's frost or a charm's speed is never
overwritten), refuses a roll without stamina, and publishes `Stamina` on the player and `Running`, `RollSeq`, `RollYaw` on
the Humanoid. The client (`Client/Controllers/MovementController`) asks (`RequestRun`, `RequestRoll`) and, for its own
body, carries out the roll (it owns its body's physics), so the roll answers at once.

**The bar** (`UI/StaminaBar`): as wide as the health bar, 7 pixels high, 3 under it, blue; a darker blue when less than one
roll is left, so a player sees that Q will not answer.

**The mouse lock** (Settings, a computer with a mouse only): the mouse stays in the middle under a 4-pixel cream dot with a
dark edge, the camera sits 1.6 studs over the right shoulder, and the body faces where the camera looks. It lets go by itself
while a panel is open, while the Roblox menu is open, while typing, and while Left Alt is held. Kept in the profile
(`settings.mouseLock`), so it follows the player into the castle.

**Phones:** a run button (on until pressed again) and a roll button beside the crouch button. Not yet tried on a phone.

## The walk and the three sets

**Command An Army** (studied 2026-11-05 from its store page, its screenshots and the community guides): an R6 game (the
place morphs every avatar to R6), Roblox's standard movement and camera, a Q roll that costs stamina. Its walk is the
plain, firm R6 soldier's walk: upright, short quick steps, the arms swinging stiffly opposite the legs. Our players are
R15 and every one of our bodies is R15, so the walk could not be its clip; set 1 is that walk on an R15 body.

| Set | Name | Idle | Walk | Run | Jump |
|---|---|---|---|---|---|
| 1 (in use) | **The soldier** (Command An Army) | upright, weight shifting, a look round | upright, short firm steps, arms close and a little bent | leans in, fists pumping | both knees tucked |
| 2 | **The ranger** | knees bent, chest forward | low and quiet, long soft steps that roll heel to toe | long and low | a stride, one knee up |
| 3 | **The veteran** | broad stance, heavier breathing | wide, the shoulders roll, the arms swing out | pounding | both arms thrown up |
| all | **The roll** | | | | a forward tumble round the hips, knees to chest, chin in, up into a crouch |

Everybody walks with `Movement.Style` (1). In Studio the workspace attribute `TLK_MoveStyle` (1, 2 or 3) switches every
player at once, to compare. The developer picks one; the other two can then go.

## Why the clips are played by our own code (learned 2026-11-05)

- The Roblox reference says an id from `KeyframeSequenceProvider:RegisterKeyframeSequence` "is temporary and cannot be
  used outside of Studio". The dead's clips (`ZombieAnims`) and the sword's (`SwordAnims`) are made that way: if the
  reference is right they play in a Studio test and NOT in the published game. **Not yet checked in the live game**; if
  the dead stand stiff there, they need the same treatment as the player (or uploading), see below.
- Roblox's upgraded avatar joints are `AnimationConstraint`s (a player's body here has 15 of them and one Motor6D), and an
  AnimationConstraint takes its `Transform` inside the physics step: written at RenderStepped or Heartbeat it moves nothing,
  written at `RunService.PreSimulation` it moves (the shoulder to exactly 90 degrees, on your own body and on a body the
  server owns).
- So `Shared/Anim/ClipPlayer` samples the clips (frames in code, no asset) and writes the joints at PreSimulation, on every
  player this client can see; nothing replicates, every client reaches the same picture. `WorkPoseController` now writes
  at PreSimulation too (it wrote at Heartbeat and found no Motor6Ds on these bodies: the dig pose never showed on them).
- Roblox's own `Animate` script is switched off on your body; while the sword is drawn the right arm is left to the sword.

## Still to do

- The developer chooses set 1, 2 or 3 (and says what to change).
- Look in the published game whether the dead's walk and the sword's cuts play; if not, move them onto `ClipPlayer`.
- A roll's sound (cloth and boots) and a little dust; a footstep sound per ground.
- Try on a phone; try two players (each sees the other's run and roll).
