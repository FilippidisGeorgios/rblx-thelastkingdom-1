# Spoils — what falls, what is rare, and what a heap of it is for (Design)

**Status:** DESIGN written 2026-10-21. **Built (0.26.0): items, tables, the roll with pity, the backpack, personal
pickups and the HUD (§10 steps 1–4); the camp bench and the banking of a run (0.33.0); the Hub's Chapel (0.34.0).** Supersedes the "Loot" paragraph of
`Economy.md` §1 and fills `configs/Loot.luau` / `configs/Items.luau` (both empty until now).
**Reads with:** `Trials.md` (where the tasks pay out), `Bestiary.md` §9 (equipment of the dead),
`Arsenal.md` §7 (the run), `Inventory.md`, `Economy.md`, `Progression.md`.
**Tags:** **[BUILT]** · **[PROPOSED]** (needs a yes) · **[LOCKED]**.

---

## 1. The idea

Everything the dead leave behind is **something they were**: a soldier's rusted iron, a cook's tallow, a
mourner's silver, a farm-hand's cloth. The player does not collect "loot"; they gather what the castle's
people used, and *use* it. Three promises:

1. **Every drop has a use within two chambers.** No junk, no vendor-trash; a heap of one thing always means
   something.
2. **Rare means different, not just bigger.** A Fine spoil changes a decision; a Rare one changes a run; a
   Relic changes how you play.
3. **The run is carried.** What you hold at the end of a *won* run is yours (`Arsenal.md` §7). That is the
   reason to go again: to bring home a different set.

## 2. What drops — the four ranks

Names are period words; colours are the Theme's (parchment, verdigris, ember, gold).

| Rank | Colour | Meaning | Rate (per kill, shambler) |
|---|---|---|---|
| **Worn** | parchment | the commons: the stuff of every body | ~70% anything |
| **Sound** | verdigris | worth a detour: silver, tallow, a good blade-edge | ~1.5%, **guaranteed** by pity (§5) |
| **Hallowed** | ember | rare: Hollow Embers, deep-grave relics, a signature piece | ~0.2%, pity at 120 kills |
| **Relic** | gold | one-offs: the star shards, the king's seal, charms | **never from a roll**: only Deeds and the King |

## 3. The items

**Counted currency** (own counter, not a backpack slot): `gold` — coin piles from the dead, `gold_bar`
(worth 25) from the mine, elites and Hallowed caches.

**Materials** (stack to 99; one backpack slot per kind):

| id | Name | Rank | From | Used for |
|---|---|---|---|---|
| `bone_dust` | Bone Dust | Worn | every body | the Tithe (§7); tempering; a little in every recipe |
| `grave_cloth` | Grave Cloth | Worn | shamblers, sacks | bandage (3) |
| `rusted_iron` | Rusted Iron | Worn | armed dead, crates | arrows, oil pots, mending |
| `wild_feather` | Fletching | Worn | archers, hay lofts | arrow bundle (2) |
| `tallow` | Tallow | Sound | kitchens, candle stands, cooks | oil pot (2), torches |
| `grave_silver` | Grave Silver | Sound | the graveyard, Sextons | blessed edges at the Reliquary; the Tithe's best shelf |
| `hollow_ember` | Hollow Ember | Hallowed | Cinders, Hollow Knights, deep graves | the Reliquary: Hollow-touched relics |

**Consumables** (stack to 9; made at the camp or found in caches): `bandage` (heal 35, hold 2 s),
`arrow_bundle` (8 arrows), `oil_pot` (throw: fire pool 4 s), `hearty_dish` (the Kitchens' recipe: heal 60).

**Quest items** (never banked, spent in the same run): `torch` (burns 45 s), `winch_handle`, `oil_jar`,
`plank`, `pickaxe`, `ingredient_*`, `cellar_key`, `scribe_key`.

**Relics** (one charm slot; **[BUILT 0.36.0]** for the medal, stirrup, veil and lantern, via `configs/Chapel.luau → Charms` and
`Server/World/CharmService`; the signet and the key are still proposals):

| id | Name | Where | Effect |
|---|---|---|---|
| `saints_medal` | Saint's Medal | Deed, Graveyard | +1 bandage carried |
| `company_signet` | The Company's Signet | Deed, Outer Ward | parry window +0.04 s |
| `sextons_key` | Sexton's Key | deep grave | opens one locked cache a run |
| `hollow_lantern` | Hollow Lantern | Hallowed | the dead notice you 20% later |
| `mourners_veil` | Mourner's Veil | Deed, Rows | first killing blow of a run is survived |
| `brass_stirrup` | Brass Stirrup | Deed, Stables | +8% walk speed out of combat |

**Story things:** `star_shard` ×9 (one per chamber, a Deed each — *the falling star*, Bestiary §3) and
`page_*` (lore pages, a few per chamber). Never lost; they go to the Hub's journal (Story delivery channel).

## 4. Where they come from

- **The dead** (`configs/Loot.luau → Tables`): each enemy type has a table; weights bend with depth.
  Heavier, better-armed, rarer dead leave better things (a Gravedigger leaves iron and silver; an archer
  leaves fletching). Elites with signature gear can drop it (Bestiary §9).
- **Caches** (crates, sacks, chests, barrels): the same tables by *kind of container*, rolled when you
  search (the winch already searches nine). A chest is Sound-tier.
- **Nodes** (the mine's veins, trees, the larder): fixed yields, rolled amounts.
- **Deeds** (`Trials.md`): fixed prizes — the way to get a Relic.
- **The camp chest**: a one-per-chamber guaranteed Sound roll *after* the gate opens (a reason to come back
  for the last item).

## 5. The roll (and why it is fair)

Per kill, per player in range (§8): `rolls = 1`. Each table entry has `Weight`, `Min`, `Max` and an optional
`Chance`. Then three modifiers, all in `configs/Loot.luau → Rules`:

- **Depth:** gold ×(1 + 0.15 × (chamber − 1)); material weights flatter, rare weights richer with depth.
- **Party:** `Difficulty.PlayerCount[n].RewardMult` applies to *gold* (the unused `RewardMult` finally
  lands here) and not to ranks — five players do not find five times as many Relics.
- **Pity (per player, per run):** after **30** kills without a Sound-or-better drop, the next kill is a
  guaranteed Sound; after **120** without a Hallowed, the next *Sound* roll is upgraded. Counters reset on
  the drop. This is what makes the game feel fair *and* is why a bad streak never wastes a run.

The roll is pure (`Server/Domain/LootTable`, spec-tested with a seeded RNG).

## 6. What a heap is for

### 6.1 In the run — the camp **[BUILT 0.33.0]** (`Trials.md` §6, `configs/Camp.luau`)
Crafting at the camp bench, instant, no UI beyond four buttons (the panel `CampUi`, E at the bench):

| Make | From | Result |
|---|---|---|
| Bandage | 3 Grave Cloth | `bandage` |
| Arrows | 2 Fletching + 1 Rusted Iron | `arrow_bundle` (8) |
| Oil pot | 2 Tallow + 1 Rusted Iron | `oil_pot` |
| Torch | 1 Tallow + 1 Grave Cloth | `torch` |

Nothing else needs a menu. The point is that after chamber 3 a player *wants* cloth, and after chamber 5
wants iron.

### 6.2 Between runs — the Hub **[BUILT 0.34.0 for the Chapel]** (`configs/Chapel.luau`, `Server/Hub/ChapelService`)
*What was built, where it differs from the proposal:* the Tithe's shelf (six things, three a day, a pick goes to the next run's kit, or to the
stash for grave silver); the Reliquary makes ONE kind of blessing (the Blessed Edge, +10% damage for a run: fire damage against the Hollow
waits for fire damage to exist) and wears a charm (one slot; the Saint's Medal, the Brass Stirrup, the Mourner's Veil and the Hollow Lantern
work since 0.36.0, see §3; the Signet and the Sexton's Key wait for the parry and the locked caches); the Altar takes shards one at a
time; the Journal reads `configs/Pages`. The Forge's use of rusted iron (mending) is not built: there is no durability.
- **The Tithe** (the chapel): bring **60 Bone Dust** → pick **one** from today's shelf of three Sound items
  (rotates daily). *Bone Dust is the commons' sink: a player with a full pack of it always has something to
  do.*
- **The Reliquary** (the chapel's second table): Hollow Embers + Grave Silver → **blessed edges** (a weapon
  does fire damage to the Hollow for one run) and the charms' upgrades.
- **The Forge** (existing, `BlacksmithUI`): gold upgrades stay; **Rusted Iron** gains a use — *mending* a
  weapon's lost durability **[only if durability exists]**.
- **The Shard Altar**: nine `star_shard`s raise the **Falling Star** — a sigil on the tabard and the first
  scene of *The Last Kingdom 2*. Slow, once, and the reason to finish *every* Deed.
- **The Journal**: every `page_*` ever found, in order. (The Story's papyrus language.)

## 7. The backpack

- A player carries a **pack of 16 stacks** + a **charm slot** + gold. Materials stack to 99, consumables to 9,
  quest items are separate (a "hands" slot: one carried thing at a time, like the torch or the plank load).
- **It is per player and per run.** On a **won run** it is banked: gold → profile currency, materials,
  relics, shards, pages → profile stash (schema v3, a table of counts).
- On a **wiped run** the party keeps **25% of the gold** and every `star_shard` and `page_*` (story things are
  never lost). *[PROPOSED — Economy open question 2; one switch in `Loot.Rules`.]*
- **Downed and revived: nothing is lost.** The pack is never dropped on a body — no corpse run in a game
  that already has a king to kill.

## 8. Loot in co-op — it is **yours**

Every kill is rolled **for each player within 70 studs** (the dead belong to the party). The drops are
physical (a coin pile that rolls, a glow, a spark) but carry an `Owner`: **you see yours; others do not see
them.** Nobody fights over a shard; a player standing in a doorway is not robbed by a faster one. Pickups
magnet to their owner at 7 studs and are auto-collected at 2.5. An unclaimed drop vanishes after 90 s (the
owner was down or far).

## 9. What the player sees

- **On the ground:** a small glowing object per rank (the commons barely glow; a Sound item has a verdigris
  mote; a Hallowed one an ember column; a Relic a gold light). Coins clink; sound is a later pass.
- **On pickup:** a parchment line bottom-right, "+2 Bone Dust", "+14 gold", stacked and fading; a chime that
  steps up with rank. A **Sound or better** drop also gets a short line of flavour ("a mourner's silver,
  warm from the ground").
- **The pack:** a parchment panel on `B`: the stacks, the charm, gold, what is *for what* (hover/tap shows
  the recipe or Tithe use). No inventory management beyond that.

## 10. What is being built first

1. `configs/Items.luau` + `configs/Loot.luau` filled (this file is the source).
2. `Server/Domain/LootTable` (pure roll + pity) + spec.
3. `Server/World/BackpackService` (per player, per run, replicated by event).
4. `Server/World/LootService` (kill → rolls → owned pickups → auto-collect) and the client
   `LootController` + `BackpackHud` (pickup lines, the panel).
5. Then `TrialService` and chamber 4 (`Trials.md`) use `gather`/`carry` and pay Deeds into the same pack.
6. **Done (0.33.0):** camp crafting; banking to the profile (won and wiped), the prisoner's bonus.
7. **Later:** the Hub's Tithe, Reliquary, Altar, Journal.

## 11. Open questions for the developer

1. **Wipe penalty (§7)** — 25% of gold and story things kept; or nothing kept; or everything kept?
2. **The Tithe (§6.2)** — 60 Bone Dust for one pick of a daily shelf: right cost, right idea?
3. **Personal loot (§8)** — OK that other players do not see your drops, or do you want shared loot with a
   pickup race?
4. **The shards (§3)** — nine across the game and the first scene of TLK2 behind them: right weight?
5. **Charm slot** — one, or two? (One is a choice; two is a build.)
