# Trials — what each chamber asks of you (Design)

**Status:** DESIGN written 2026-10-21. **Built: the engine, the verbs `light`, `toll`, `read`, `gather`, `cook` and `feed`, the pressures `rising` and `tide`,
and chambers 3, 4 and 5 as data (0.26.0, 0.27.0, 0.28.0).** The rest is design. Builds on `AreaPlan.md` (what is *in* each
chamber), `Encounters.md` (the waves), `Bestiary.md` / `Arsenal.md` (who and with what) and `Spoils.md`
(what falls out of it all).
**Serves:** GDD Pillar 3 (exploration is a verb), Pillar 5 (co-op), and the replay goal.
**Tags:** **[BUILT]** · **[PROPOSED]** (needs a yes) · **[LOCKED]** (canon or an earlier decision).

---

## 1. The idea in one paragraph

A chamber is a **Trial**: a short list of **Phases**, each a handful of **Tasks**, with **Pressure** (the
dead) laid over them. When the last phase is done the gate rises (`AreaService.clear`). A task is one plain
verb a player already understands — *search, carry, light, hold, read, cook, board, free, wait, kill* — and
the whole art of the castle is **which verbs, in what order, under what pressure**. No two chambers ask the
same question; none asks two players to be in two places at the same moment.

```
Trial ── Phase 1 ── Task, Task, Task   (all required, any order)
      ├─ Phase 2 ── Task                (starts when Phase 1 is done)
      ├─ Pressure ── Tide / Waves / Rising / Ambush / Siege  (laid over a phase or the whole trial)
      └─ Deeds ───── optional tasks, never needed for the gate, paid in rare spoils
```

## 2. The laws (they stand over every chamber)

1. **Solo-first** *[LOCKED, AreaPlan]*. Scale by **count**, never by **role**. Four jars, six braziers, N
   waves: one player makes four trips, four players make one each.
2. **Progress persists** when you break off to fight. Slip-back is allowed only as tuned pressure that one
   player can beat (the winch).
3. **More players = faster, never = possible.**
4. **The room teaches itself.** The first task of every chamber is visible from the door and says what to do
   in the world (a glow, a prop, a sound), not in a tutorial. The top line (`ObjectiveHud`) confirms it.
5. **Pressure is a clock, not a wall.** The dead never stop a task by standing there; they stop it by
   *interrupting* the player. A chamber is beaten by making space, then working.
6. **Every chamber changes the problem, not the numbers** (Bestiary §5.4). Waves and tasks are designed
   together: the task decides *where the player must be*, the wave decides *what is trying to stop them
   there*.
7. **Something is different each run** (Arsenal §7): which crate holds the handle, which grave opens first,
   which two Deeds are offered, what the recipe needs. The structure is fixed; the contents are rolled.
8. **A run is carried.** At least two things pass from chamber to chamber (planks 5→6, the pickaxe 5→8, the
   cured villagers 3→6): the castle is one story, not nine rooms.

## 3. The task verbs

Each verb is one module (`Server/World/Trial/<Kind>.luau`), driven by data in `configs/Trials.luau`.
**[BUILT]** = in the first engine; **[LATER]** = designed, written when a chamber needs it.

| Verb | What the player does | Parameters | Needs |
|---|---|---|---|
| `search` | Open containers until the thing is found; which one holds it is rolled | `count`, `finds` (item), `prop` set | [BUILT as WinchService; generalised **LATER**] |
| `gather` | Collect N world items (ingredients, planks, oil) into the backpack | `item`, `count`, `nodes` (named parts) | **[BUILT]** |
| `carry` | Pick up a *burning* or *heavy* thing and take it somewhere before it fails | `item`, `lifetime`, `from`, `to` | **[BUILT]** (the torch) |
| `use` | Spend items at a station (feed, pour, board, put on the fire) | `station`, `item`, `count`, `hold` | **[BUILT]** |
| `light` | `use` + a flame that stays: ignite N points | `points`, `fuel` | **[BUILT]** |
| `forge` / `burn` / `chop` / `mine` | The smithy's verbs: the heat you hold, the door you burn, the trees, the veins | see `Trial/Forge`, `Burn`, `Chop`, `Mine` | **[BUILT]** |
| `cook` / `feed` | The pot that must be minded, and the ladle to each of the penned (chamber 3's own verbs) | see `Trial/Cook`, `Trial/Feed` | **[BUILT]** |
| `hold` | Hold a prompt for T seconds, optionally slipping back (winch) or banking (lashing) | `seconds`, `slip`, `bank` | [BUILT: Barricade, Winch] |
| `read` | Open a document; may reveal a clue (an order, a number, a location) | `at`, `title`, `lines` / `recipe` | **[BUILT]** |
| `wait` | Survive T seconds while the world works; the clock is *in the world* (a candle, a bell, a pot) | `seconds`, `show` | **[BUILT]** |
| `clear` | Kill the wave / N of a type | `encounter` / `enemy`, `count` | [BUILT: AreaWaveService] |
| `defend` | Keep a thing or person alive (the pot, the prisoner, the boards) | `target`, `seconds` | **[LATER]** |
| `free` | Long hold on a person; they join / speak | `seconds` | **[LATER]** |
| `sequence` | Do points in a clued order; a wrong one costs an Ambush | `points`, `order` | **[LATER]** |
| `slay` | The boss | `enemy` | **[LATER]** |

**Combinators.** A phase's tasks are `all` (default), `any` (first to finish) or `count N` (any N of M).
A task may be `optional` (a **Deed**) — it never gates anything.

## 4. Pressure — the dead laid over the work

"Waves" are only one shape. Chambers use these (all `WaveService` underneath):

| Pressure | What it is | Tied to | Example |
|---|---|---|---|
| **Waves** *[BUILT: `AreaWaveService`]* | Sequential rooms of the dead from the doors | the chamber (starts on entry) | 1, 2 today |
| **Tide** | A thin steady trickle for as long as a task runs; stops when it ends | a task's lifetime | the pot simmers (3) |
| **Rising** | Named graves/holes open on a timer and produce a few at a time; a section can be *shut* | a world feature | graveyard sections (4) |
| **Ambush** | A burst when a trigger happens: a chest opened, a handle taken, a wrong choice | a single event | the handle is found (2) |
| **Siege** | A countdown, then a mass spawn from outside, with ranged on the walls | a timer | the hall (6) |
| **Funnel** | The dead come to one place, and only that place | geometry | the fallen tower (8) |

Rules: pressure **never** starts before the player has read the room (the existing 3 s grace plus the
door), **never** stacks beyond the depth curve (`Difficulty.Areas`), and is *scaled* by `Scaling` as waves
are. A task that has pressure on it and a task that has none may share a phase: the player chooses the order.

## 5. The nine, designed together

Each entry: **Asks · Pressure · Carries · Deeds · Rolled**. Chambers 1 and 2 are built; the rest are the
plan, in the order they will be written. Numbers are provisional.

### 1 — Outer Ward · *Cut your way in* **[BUILT]**
- **Asks:** three lashings, three cuts each (`hold`, banked).
- **Pressure:** 15 shamblers in 3 waves.
- **Deeds:** *The Standard* — the company banner is in the guardhouse, face down. (Reading it is the first
  glimpse of the falling star.)
- **Rolled:** which two of the barracks' chests hold a bandage.
- **Teaches:** progress is kept; the dead do not stop you, they *interrupt* you.

### 2 — Stables · *Find it, then wind it* **[BUILT]**
- **Asks:** `search` (the handle, 9 points) → `hold` (the winch, slip-back).
- **Pressure:** 4 waves of shamblers and runners. **Ambush:** taking the handle rings the stall bell — a
  pack of runners from the west (the noise draws them).
- **Deeds:** *Stolen horse-brass* — a hidden cache in the hayloft; pays an Iron Scrap and a Fine spoil.
- **Rolled:** which box holds the handle (already), which three hold supplies.
- **Teaches:** the cost of finding is noise; the gate is the progress bar.

### 3 — Kitchens · *The recipe, the pot, the five*
- **Asks:** Phase 1 `read` the recipe (the papyrus) → Phase 2 `gather` **four** ingredients (flour, salted
  meat, herbs, well water — the well is boarded: `hold` to break) → Phase 3 `use` at the cauldron
  (`light` the hearth, then `wait` 25 s while it cooks) → Phase 4 `use` the dish on **five** penned dead
  (`hold` 3 s each: each turns).
- **Pressure:** waves from the doors for the whole chamber; **Tide** while the pot simmers — the smell draws
  them to the hearth. The pot is where you *must* stand, so you must fight there.
- **Carries:** the five cured villagers follow the party through 4–6 (the existing `cured_villager`
  types). Co-op: more hands = more penned dead fed at once.
- **Deeds:** *The cellar* — a locked door (the key is a Search find); inside, the larder: bandages, a tallow
  cake (Spoils), a rare knife.
- **Rolled:** the recipe's four ingredients (from a pool of seven: it can ask for turnips, or for mead).

### 4 — Graveyard · *Carry the fire* **[FIRST, being built]**
- **Asks:** four grave braziers, one per section. Each needs a **lit torch**. A torch burns for **45 s**
  and is lit only at the **chapel's candle stand** (or an already-lit brazier). Light all four.
- **Pressure:** **Rising** — each section has 5-6 open graves that produce the dead on a timer (every 8-10 s,
  2 each) until *that section's brazier is lit*, which shuts it for good. Heavy-weapon dead appear here.
  **Waves** continue from the doors.
- **The decision:** the torch is a clock. Start with the near brazier, and the far ones are slower; start
  with the far one, and the near section is unchecked for longer. Fighting with a torch in hand (it holds
  standing dead at ~6 studs, Arsenal §4) is the skill.
- **Deeds:** *Toll the bell* — the chapel bell brings a hard wave but pays **Grave Silver** (Fine) per kill
  for 60 s; *The burial roll* — read it, learn what was buried here (Story).
- **Rolled:** which graves are the "deep" ones (they hold a relic), which section's graves are most active.

### 5 — Smithy · *The spike*
- **Asks (parallel, three jobs, one needed to leave):** (a) **the forge** — bellows (`hold`, heat gauge
  decays over 50 s) → chain in → strike, 3 rounds; the one permanent upgrade (temper: Edge / Point / Weight);
  (b) **the door** — `gather` oil + a torch → `use` at the door → it burns open (the way out);
  (c) **the woodyard** — `gather` planks (axe from a stump + `hold` at each tree) for the Hall.
- **Pressure:** the sharpest in the game: spears and bows appear. **Siege-lite:** archers on the smithy roof.
- **Carries:** planks → 6; the **pickaxe** (found in the mine) → 8.
- **Deeds:** *The mine* — gold on the ground, a cart; a rolled **hoard** (a Rare spoil).
- **Rolled:** the loot of the mine; which tree has the axe in its stump.

### 6 — Great Hall · *The siege*
- **Asks:** Phase 1 `use` planks on the **four** BoardPoints (each: `hold` 6 s; 30 s before the mass spawn).
  Phase 2 `wait` — **hold the hall for 4 waves**; boards have health, spearmen and archers break them.
  Re-board (planks are in the chamber's racks) as they fall.
- **Pressure:** **Siege**: the strongest spawn in the game, but it comes at the boards.
- **Deeds:** *The table* — the lord's seat holds the hall's key; *the gallery* — an archer's seat above the
  passage.

### 7 — The Rows · *The prisoner*
- **Asks:** `free` the villager from the tavern chair (hold 20 s) → they must reach the gate alive (`defend`).
  Along the way `read` three letters (lore) — optional.
- **Pressure:** very hard; the Rows are a maze, **Ambush** at each street end.
- **Pays:** the whole team +5% gold if they survive (AreaPlan).

### 8 — Inner Ward · *The line*
- **Asks:** the passage is buried: `hold` to dig it out **with the pickaxe from 5**, with a slip-back like the
  winch's. The fallen tower is the only high ground.
- **Pressure:** **Funnel** — the dead have to climb to the tower; Hollow Knights.
- **Rolled:** which side the rubble gives way from.

### 9 — Keep Steps · *The King*
- **Asks:** `slay` the King → the keep door opens → the scribe: hear the whole dialogue → the key → the
  roof door → everyone leaves together.
- **Pressure:** the boss; the court (the cured villagers who survived stand beside you).

## 6. The camp — the breath after a gate

When a gate opens, a **camp** appears in the passage mouth (a hearth, a bench, a chest): a safe-ish place
(no spawns within 30 studs) where the party can breathe, **craft** from what they have gathered
(`Spoils.md` §6) and have their place saved. It is the point of the loot: *a reason to pick things up*.
**[PROPOSED]**; first version after the first two chambers' spoils work.

## 7. Time

The user's word was *wait*. There are three honest kinds, and each belongs somewhere:

- **Work time** — the winch is 14 s of holding; the forge is 3 rounds. The player's hands are the clock.
- **World time** — the pot simmers 25 s; the torch burns 45 s; the siege arrives in 30 s. The world's clock,
  *visible in the world* (steam, a flame going low, a bell).
- **Pressure time** — "hold the hall for 4 waves". The enemy's clock.

No chamber uses a bare countdown on the screen. A timer is always a *thing that is happening*.

## 8. What the player sees

- **The top line** (`ObjectiveHud`): the one instruction + a count. "Light the braziers (2 of 4)".
- **The world**: a prompt that says what the object needs ("Light — needs fire"), glows on what is next, a
  flame on what is done, a gate that moves.
- **The ledger** *[LATER]*: a parchment (key `J`) with the phases, ticks and Deeds. The Story's papyrus
  language again.
- **The corner** (`AreaHud`): where you are. Unchanged.

## 9. The engine (what is being built)

```
configs/Trials.luau            data: per chamber, phases → tasks, pressure, deeds
Server/World/TrialService      runs a trial: starts on AreaService.onEnter, advances phases, calls AreaService.clear
Server/World/Trial/<Kind>      one module per verb: create(ctx, def) → { start, stop, progress }
Server/Domain/TrialRun         the pure state machine: phases, required/optional, any/all/count (+ spec)
```

- **`TrialRun` is pure** (no Roblox), like `EncounterRun`: it takes a trial definition, hears `taskDone(id)`
  and says which phase is live, what is optional, and when the trial is complete. Spec-tested.
- **A task module** gets a context (`area`, `hint`, `backpack`, `pressure`) and reports `done()`. It builds
  its own props, prompts and glow, and removes them when it stops.
- **Pressure is a task-adjacent service** (`Trial/Pressure`): `tide`, `rising`, `ambush`, `siege` call
  `EnemyService.spawn` through `WaveService`'s scaling, so the depth/party curves apply once.
- **Existing mechanics are not rewritten.** `BarricadeService` and `WinchService` keep working and call
  `AreaService.clear` as before; they are *listed* in `Trials.luau` as `legacy = true` so the ledger and the
  top line know about them.
- **New chambers are data + at most one new verb module.** Chamber 4 needs `carry`, `light`, `Rising`.

## 10. Open questions for the developer

1. **The camp (§6)** — yes? It is the answer to "what do I do with everything I picked up", but it is work.
2. **Chamber 3's five** — all five must be fed to open the gate, or any three (the other two are a Deed)?
   Solo-first suggests three; the story suggests five.
3. **Deeds** — shown on the ledger from the start (so players know what exists), or hidden (so finding one is
   a discovery)? Suggest: a one-line hint is shown, the *how* is not.
4. **The torch** — 45 s fits chamber 4; is a lit torch also usable as a weapon (Arsenal §4) from day one?
5. **Chambers 1–2** — add the Deeds and the Ambush now (small), or leave them as built until the rest exists?
