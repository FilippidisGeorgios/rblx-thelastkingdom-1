# The Company's Arsenal — Movement, Weapons and the Run (Design)

**Status:** DESIGN, written 2026-10-20. Builds on what exists: `configs/Weapons.luau` (four melee
weapons), `MeleeCombatService` (server swing), the developer's sword animation work in
`Shared/Anim/SwordAnims.luau` and `WeaponAnimController` (two cuts and a guard).
**Serves:** GDD Pillar 4 (combat that is remembered), Pillar 5 (co-op), and the replay goal: *a player
who finishes should want to go again, better.*
**Reads with:** `Bestiary.md` (what is being fought), `Animation.md` (how it moves), `Combat.md`,
`Inventory.md`, `Economy.md`, `AreaPlan.md`.
**Tags:** **[BUILT]** · **[PROPOSED]** (needs a yes) · **[LOCKED]** (canon or an earlier decision).

---

## 1. Who the player is, in the hand

The player is one of the sworn company that marched north and came back after forty years: veterans in
battered kit, a bordeaux tabard with the **falling star** gone to rags, an old blade that is still
sharp. The kit should *say* that. So:

- **Weapons are real medieval weapons**, named as the period named them, each with a single honest job
  (sword, axe, mace, spear, billhook, dagger; bow and crossbow; a shield on the other arm).
- **The fight is about distance and timing, not numbers.** Every enemy asks a question (Bestiary §5.4);
  every weapon is a different answer to it. No weapon is the best answer to everything.
- **No levelling treadmill inside a run.** What makes you stronger mid-run is *what you find and what you
  chose* (the forge, spoils of the dead), not a number going up.

Design test: the player can say in one sentence what their weapon is *for* — "the axe pulls shields
down", "the spear holds the line", "the mace breaks plate".

---

## 2. Movement **[PROPOSED]**

| Action | Spec | Why |
|---|---|---|
| Walk | 14 studs/s | slower than Roblox's 16: a castle is dense and tense |
| Sprint | 20 studs/s, 10 stamina/s, cannot attack while sprinting | outruns a Runner (15) *briefly*; noise draws the dead (Bestiary §7) |
| Roll | 9 studs in 0.55 s, **i-frames 0.20–0.40 s**, 25 stamina, 0.35 s end-lag | the one dependable answer to a telegraphed hit |
| Back-step | 4 studs, 12 stamina, short hop | spacing without commitment |
| Jump | low (about 4 studs), no air attacks | stairs and ramps are the verticality, not hops |
| Kick | 6-stud shove, 10 stamina, 0.9 s cooldown, **knocks a Runner down** | the answer to being crowded; opens a guard |
| Climb | ladders and stairs only (belfry, wall platforms) | height is earned; archers want it too |

**Stamina:** 100 max, regenerates 22/s after a 0.7 s pause. At 0 you are **winded** — 1.2 s of walking
slowly, no attack, no roll. Stamina is *the* tension: it is what makes a crowd dangerous and a good
player calm. Armour weight changes the regeneration (§6).

**Health:** 100 **[BUILT: `Settings.Dev.PlayerMaxHealth`]**. No passive regeneration. You mend by
**bandage** (hold 2 s, interruptible, 3 carried) — found, bought, or *cooked* (the Kitchens recipe is
food; a good dish heals more than a bandage and is a reason to read the papyrus). Co-op: revive, as the
Death System already does.

---

## 3. The fight

### 3.1 The verbs

- **Light attack** — the weapon's fast move. For the **sword** this is the developer's pair: two cuts that
  draw an X, A then B, alternating. **[LOCKED: that is the sword's moveset; nothing here changes it.]**
- **Heavy attack** *[PROPOSED]* — hold to charge (0.5 s), release: slower, +60% damage, +stagger, breaks
  a guard. Each weapon's heavy is *different in shape*, not a slower copy of its light (see §4).
- **Guard** — hold: a frontal arc of 150° in which damage is reduced by the weapon's `Guard`
  (50–90%); every blow costs stamina. Stamina at 0 breaks the guard and staggers you.
- **Parry** — pressing guard *just before* a blow lands (first 0.18 s) deflects it entirely, staggers the
  attacker for ~1 s and arms your next strike with +100% (the **riposte**). Parry applies to melee
  attacks that the Bestiary marks parryable; the Gravedigger's slam and the Knight's sweep are not.
- **Shield** (off-hand) — raises guard strength and, for a buckler, widens the parry window to 0.26 s.
- **Kick**, **Roll**, **Back-step** — §2.

### 3.2 Staggers and finishers

Every enemy has a **poise** (hidden). Heavy hits, parries, kicks and mace blows drain it; at zero the
enemy **staggers** (a kneel, or a flinch for light units). A staggered enemy can be **finished** with a
dagger or any heavy attack for double damage — the single most satisfying thing the fight offers, and
the reason a parry is worth the risk.

### 3.3 Damage has a *style*, and armour has an opinion **[PROPOSED]**

`DamageType` stays `Physical/Fire/...`. A weapon also carries a **Strike** — `Slash`, `Pierce` or
`Crush` — which is what resistances care about (the schema gains one field):

| | Slash | Pierce | Crush |
|---|---|---|---|
| Unarmoured dead | 100% | 100% | 100% |
| Pikeman (brigandine) | 85% | 90% | 110% |
| Shieldman (shield front) | 0% from the front | 0% | 40% from the front (guard-break) |
| Hollow Knight (plate) | 55% | 70% | **140%** |
| Cinder | 100% | 100% | 100% (fire immune) |

That one table is why the mace exists, and why the Smithy's forge choice (§7) matters in chamber 8.

### 3.4 Feel (see `Animation.md` §6 for the numbers)
Hit-stop, a small camera push, knock-back by weight, impact dust and sparks, sound in layers. A blow
that lands should be *felt in the controller*; a blow that is parried should *ring*.

---

## 4. The weapons

Existing four are **[BUILT]** in `configs/Weapons.luau`; their numbers below are those values, plus
the new fields. Everything else is **[PROPOSED]**.

**Reading the table.** *Speed* is the full swing time. *Reach* is studs. *Stagger* is poise damage.
*Guard* is how much a held guard absorbs. The single line under each is what it is **for**.

### One-handed (sword/axe/mace/dagger + shield)

| id | Name | Strike | Dmg | Speed | Reach | Stagger | Guard | Moveset |
|---|---|---|---|---|---|---|---|---|
| `starter_sword` | **Old Blade** (arming sword) | Slash | 25 | 0.6 | 8 | low | 75% | two cuts forming an X (developer's) · heavy: a **lunging thrust** (pierce, +reach) |
| `woodsman_axe` | **Woodsman's Axe** | Slash | 38 | 0.95 | 8 | med | 55% | chop and backhand · heavy: **hook** — pulls a raised shield down (counters the Shieldman). Also the tool that fells trees for planks. |
| `flanged_mace` | **Flanged Mace** | Crush | 52 | 1.35 | 7 | **high** | 60% | overhead and horizontal smash · heavy: guard-break, shatters poise (counters plate) |
| `rondel_dagger` | **Rondel Dagger** *[new]* | Pierce | 14 | 0.35 | 4 | none | 30% | rapid stabs · **finisher**: 3× on a staggered or guard-broken enemy, and the only weapon that slips into a gap in plate |

### Two-handed

| id | Name | Strike | Dmg | Speed | Reach | Stagger | Guard | Moveset |
|---|---|---|---|---|---|---|---|---|
| `footman_spear` | **Footman's Spear** | Pierce | 30 | 0.8 | **14** | low | 55% | thrust · heavy: **set** — plant the spear to brace; a charging Runner impales itself (counters the lunge) |
| `knight_longsword` | **Longsword** *[new]* | Slash/Pierce | 34 | 0.75 | 10 | med | 85% | wide cuts · heavy: **half-sword** — grip the blade, a short armour-piercing thrust |
| `war_billhook` | **Billhook / Halberd** *[new]* | Slash/Pierce | 44 | 1.1 | 13 | med | 50% | sweeping cut, hook, thrust · heavy: **hook and pull** — drags a Pikeman or Archer off a firing step |

### Off-hand (shield)

| id | Name | Guard | Parry | Notes |
|---|---|---|---|---|
| `buckler` *[new]* | Buckler | 55% | **0.26 s** | light, fast; best for parry players; arrows deflected, not absorbed |
| `heater_shield` *[new]* | Heater shield | 85% | 0.18 s | the standard answer to a crowd and to arrows |
| `tower_shield` *[new, spoil]* | Tower shield | 95% | 0.12 s | heavy (−3 speed, −20% stamina regeneration); **only found**, from a Shieldman |

### Ranged

| id | Name | Dmg | Cycle | Notes |
|---|---|---|---|---|
| `hunting_bow` *[new]* | Hunting Bow | 22 (headshot ×1.5) | draw 0.8 s, hold costs stamina | arrows are real projectiles (`ProjectileService` exists); drop and arc; 20 in a quiver, recoverable from bodies |
| `light_crossbow` *[new]* | Crossbow | 48, **pierces one body** | reload 2.2 s | slow, heavy, cannot move while winding; the answer to a Hollow Knight at range |
| `hand_cannon` *[new, rare relic]* | Hand Cannon | 120 | one shot, reload 6 s | period-correct (mid-14th century); **very loud** — every dead in the room turns; a gamble, not a staple |

### Thrown and carried

- **Torch** — equip: lights the way, and **holds standing dead at ~6 studs while it burns** (Bestiary §7).
  Swung, it does 10 fire damage and sets a Cinder's trail alight. It is also *the key of chamber 5*: light
  it at a fire, set it by the oil, and the door burns open (AreaPlan §5).
- **Oil pot** — thrown: a pool of fire that lasts 4 s. From the Smithy's oil store. A tool for a corridor, a
  stair foot, or a Shieldman wall.
- **Bandage**, **dish** — §2.

---

## 5. Why this has no "best weapon"

| If the enemy is… | Reach for… |
|---|---|
| a crowd of Shamblers | spear (hold the line) · heater shield · kick |
| Runners | a set spear · a roll through the lunge · the dagger on the downed |
| a Gravedigger | any weapon + a roll, punish the stuck frames; mace staggers |
| a Pikeman | roll inside, or billhook-pull |
| Archers | shield, cover, crossbow |
| a Shieldman | axe hook · mace · kick · flank |
| a Sexton | bow / thrown oil — he walks away |
| a Hollow Knight | **mace, crossbow, longsword half-sword, the forge's armour-piercing choice** |
| the King | all of it, in order |

---

## 6. Armour **[PROPOSED]**

Three slots — **Head, Body, Relic** — so it never becomes a spreadsheet. Weight class sets the trade:

| Class | Example | Damage taken | Stamina regeneration | Roll |
|---|---|---|---|---|
| Light | gambeson, cap | −10% | normal | full |
| Medium | brigandine, kettle hat | −25% | −10% | −15% distance |
| Heavy | plate, great helm | −40% | −25% | −30% distance, 0.1 s longer end-lag |

Armour shows on the player's body (it is what the Hub's armoury is *for*); a heavy player looks like a
knight and moves like one. **Relics** are small passive charms found in the run (a saint's medal: +1
bandage; a signet: a bigger parry window) — one slot, one choice.

---

## 7. The run — what makes you go again

The structure already exists: **a backpack, and you keep only what is in it if you win the run;
randomised loot in chamber 5; one permanent upgrade at the forge** (AreaPlan §5). This section adds the
pieces that make a *second* run different from the first without ever making the first one impossible.

### 7.1 Inside a run (randomness the player can read)

- **The forge [BUILT, 0.28.0: `Trial/Forge`, `RunModService`]** (chamber 5, three rounds, the only permanent upgrade *of the run*): choose **one** of
  three tempers for your weapon — **Edge** (+damage), **Point** (armour-piercing, +reach), **Weight**
  (+stagger). The choice decides how chamber 8 goes (Hollow Knights) and *is* the reason to replay: a
  mace player and a spear player want opposite tempers.
- **Spoils of the dead** (Bestiary §9): Elites may drop what they carried. A Shieldman's tower shield, a
  Pikeman's spear, a Knight's helm. Rare, run-specific, and it tells you who they were.
- **Search**: containers (crates, chests, barrels, sacks) hold bandages, arrows, oil pots, relics and
  lore. *Which* ones, changes per run (as the winch handle already does).

### 7.2 Between runs (the Hub) **[PROPOSED]**

- **The Armoury**: every weapon/armour piece you have *brought home* (won a run with it in the backpack)
  is yours; you take two weapons and a shield into the next.
- **Oaths**: optional vows you swear at the gate for a larger share of the spoils — *Oath of Iron* (no
  shield), *of Silence* (no sprint), *of the Short Candle* (no bandages), *of the Lone Blade* (no
  companions). A hard run is a story; and it is the content that never runs out.
- **Mastery**: each weapon has a rank earned by use (kills, parries, finishes). Ranks unlock **moves**, not
  numbers: the sword's lunging thrust, the axe's backhand, the spear's brace. A rank is a new thing to do
  with a weapon you already like.
- **Deeds → heraldry**: cosmetic. Tabard colours, sigils, trim — earned by what you *did* (finished
  without a bandage; released the King; parried a Gravedigger). Players recognise each other by their
  star.
- **Records**: personal best time, best no-death run, a party's record. Nothing global is required.

### 7.3 Co-op (no role is required — AreaPlan law: solo-first)

More players is **faster**, never **possible**. What co-op adds, without a *needed* role:
- **Shield wall**: guards that stand adjacent share a small guard bonus.
- **Revive** and **carry**.
- **Torch ring**: two torches hold a wider circle of dead.
- **Release the King**: every player in range adds to the final held input.

---

## 8. Things to do in the world **[PROPOSED]**

The castle is now a place; it should have things the player can *do* besides fight, so that exploring is
a verb (Pillar 3). None of these needs a new system — they are interactions on the built scenery.

- **Search** (hold): chests, crates, barrels, sacks, shelves, the dead's pockets after a fight.
- **Read**: papyrus and parchment (a recurring visual language already decided): letters, orders, a
  child's drawing in the Rows, the chaplain's burial roll in the chapel. They *glow faintly* so the eye
  finds them, open as a UI panel, and are collected in the Hub's journal. This is the Story's delivery
  channel (Pillar 2).
- **Climb**: the belfry (chamber 4), the guardhouse deck (1), the watch platform (1), the granary (3), the
  firing steps and fallen tower (8), the minstrels' gallery (6). A view, an archer's seat, a place to fall back to.
- **Light**: braziers and sconces, torches. Fire is your friend.
- **Break**: barricades, boarded doors, barrels of oil, crates.
- **Toll**: the chapel's bell. It brings the dead — and the graveyard's Sexton answers it.
- **Tend**: the field hospital's cots (chamber 8) give a bandage; the kitchens' hearth cooks.
- **Rest**: a hearth or camp *per chamber after the gate opens*: refills bandages to a minimum and saves
  your place (the rejoin checkpoint). Not a heal: a breath.
- **Fell and saw**: trees, planks (chamber 5 → 6).

---

## 9. What this needs in code (in order, small)

1. `Strike` on weapons and a resistance table on enemies; `Windup`/`Recover` on enemy attacks.
2. Stamina, roll, guard and parry on the player (server decides, client predicts the roll).
3. Heavy attacks per weapon; poise and stagger.
4. Weapon models (the developer supplied the Old Blade in `ServerStorage.Assets.Weapons`; the others follow).
5. Armour slots, relics, bandage; then the Hub armoury, Oaths, mastery.

None of this touches the developer's current animation work except as a consumer of it.

---

## 10. Open questions for the developer

1. **Heavy attack for the sword** — a lunging thrust (my proposal), or leave the sword at two cuts only?
2. **Parry** — yes (skill ceiling, the riposte), or guard only (simpler)?
3. **Roll vs. back-step only** — roll is in the plan; say if it is too "action-game" for the tone.
4. **Oaths and mastery** — a strong replay engine, but real work in the Hub. Now, or after the mechanics?
5. **Hand cannon** — keep as a rare gamble, or drop (anachronism risk is low; tone risk is yours to judge)?
