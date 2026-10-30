# Danger: how hard a run is (Built, 0.39.0)

**What it is.** The third difficulty curve. `configs/Difficulty` already had two: the party size (`PlayerCount`, how much the room can chew
through) and the depth (`Areas`, what the castle is willing to send). Danger is one figure from **0 to 100** that adds the party's
LEVELS and its MODE on top, shown on the train as **"+34 of 100 harder"** and used by the run to scale the dead and the pay.

Written in the developer's own words (2026-10-30): normal and hard come by head count; even two very high-level players should meet an
extra step of difficulty; but new players must not be buried by their friends' levels: with three or more rookies, only a small share
of the average counts. The rules below are exactly that.

## 1. The mode (Normal / Hard)

| Party | What it plays |
|---|---|
| 1 to 4 | **Normal** by default. The caller may press **Hard**. |
| 5 to 8 | **Hard**, and Normal is shut (the button is dimmed and says "A party of 5 or more fights only in Hard"). |

`Danger.modeFor(count, wantsHard, tiers)` is the whole rule. The server decides it again at departure from who is really aboard
(`TrainService.depart`): a party of five that lost two people on the platform and leaves as three keeps the Hard it was called in; a party
that grows past four is Hard whatever it chose. The World re-checks it from the teleport data (`RunDifficultyService`): the only thing a
forged payload can do is make its own run harder.

## 2. The points (`Shared/Danger`, `configs/Difficulty.Danger`)

```
total = min(100, mode + veterans)
mode      = 0 for Normal, 25 for Hard
veterans  = 100 x (average level - 1) / 99  x  keep
```

- **The veterans** are the AVERAGE level of the party: level 1 is nothing, level 100 is +100. Two level-100 players on Normal are +100; a
  level-50 pair about +50.
- **The shield (`keep`)** protects new players. Sort the party by level; the **third weakest** decides:
  - fewer than three players: no shield (two level-0 players among veterans take the average, as they chose to);
  - the third weakest is level 5 or less (three or more rookies): only **15%** of the veterans' points count;
  - from level 5 to level 20 of the third weakest the shield fades out (about 55% at level 12);
  - from level 20: the average counts in full. (So "exclusively people over level 20, even with two level-0 players" takes the whole average.)

| Party | Average | keep | Veterans | + mode | Danger |
|---|---|---|---|---|---|
| 1 player, level 1, Normal | 1 | 1 | 0 | 0 | **+0** |
| 2 players, 1 and 100, Normal | 50 | 1 (a pair) | 50 | 0 | **+50** |
| 3 level-1 + 2 level-100, Normal (5 = Hard) | 40 | 0.15 | 6 | 25 | **+31** |
| 4 level-1 + 4 level-100 (Hard) | 50 | 0.15 | 7.5 | 25 | **+32.5** |
| 2 players, level 100, Hard | 100 | 1 | 100 | 25 | **+100** (capped) |

## 3. What the figure does

`Shared/Scaling.setRunDanger(total)` (called by `World/RunDifficultyService` when a run begins, the first one and every Play Again) folds it
into `Scaling.forPlayers`, which the waves, the trials, the King and the loot already call. At 100 points (`AtFull`): the dead have **+60%
health**, there are **+40% as many**, **+0.2 elite weight**, and the gold paid is **+50%**. Any lower figure is that share of it. Damage is
NOT scaled: a hard run is long and tense, not a run where one blow is a down.

The figure is left on the workspace (`RunDanger`, `RunMode`) and printed on the ending card ("Danger of the run: +32 (Hard)").

## 4. Where it is

| File | Job |
|---|---|
| `Shared/Danger.luau` | the pure rules (the client previews with the same module the server uses) |
| `configs/Difficulty.luau` `Danger` | every number: `Mode`, `LevelPoints`, `Shield`, `AtFull` |
| `Shared/Scaling.luau` | `setRunDanger`, `forDanger`; `forPlayers` includes the run's figure |
| `Server/Hub/TrainService` | `berth.wantsHard`; the status carries `tier`, `normalClosed`, `danger`; departs on `Danger.modeFor` |
| `Server/World/RunDifficultyService` | sets the run's figure at `DeathService.onRunBegin` |
| `Client/UI/DepartureUI` | the NORMAL / HARD buttons, the meter, the preview from your own level |
| `Tests/Danger.spec` | the whole contract |

## 5. Tuning and what is provisional

- The old `PlayerCount` rows were tuned when Hard did nothing. Hard now also adds +25 points (about +15% health, +10% as many), so
  five to eight players are a little harder than before: re-measure with a real party.
- `LevelPoints`, the shield's `Keep` (15%) and its two levels (5 and 20), `Mode.Hard` and `AtFull` are in one table.
- A level is not power (power is the forge, `TeamPower`/Might): Danger makes a veteran's run harder because they are a veteran, which is
  what was asked. If it ever feels like a tax on playing, lower `LevelPoints`.
