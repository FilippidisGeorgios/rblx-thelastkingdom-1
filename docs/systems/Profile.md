# Profile — the Muster Roll (Built, 0.37.0; levels to 100, the Company number, Renown, statistics and the train: 0.38.0)

**What it is.** Every player has one page about themselves in the Hub: who they are (nickname, Company number), the rank and level
they have reached on the road to 100, the whole of their standing in one number (**Renown**), how strong they are (**Might**), the
arms they have forged, what they have done (**statistics**) and what they have collected. It is where the player can SEE the
numbers the difficulty already works from, so the fairness rules are visible rather than hidden. The train shows a short version of
it beside every name aboard.

**Open it:** the **PROFILE** button (a head and shoulders) beside the chat, in the Hub and in the castle (also the touch way in); in the
Hub also the key `P`. (0.39.0: the old `ROLL` corner button is gone; `Services/ProfileService` serves both places.) The **INVENTORY** tab on
the left edge, the **SETTINGS** cog and the nicknames over heads are in `Settings.md`; how hard a run is, in `Danger.md`.

## 1. Who they are

| On the page | Where it comes from |
|---|---|
| **Nickname** (large) | the Roblox display name, taken from `profile.account.displayName` (set at every load) |
| `@name` | the Roblox account name |
| **Company number** `TLK-03YB-HWSR-T` | `Domain/PlayerId.forUser(userId)`: the user id in Crockford base 32, groups of four, one check character. **Given once** (`ProfileSchema.stamp`) and kept in `profile.account.id`, so it never changes even if the scheme does. `PlayerId.decode` goes back to the user id (the admin panel's search): any case, spaces for dashes, O for 0 and I/L for 1 are forgiven; any single wrong character is refused. |
| Account record | `profile.account = { id, userId, name, displayName, since, lastSeen }` (schema v5), for the admin panel |

A custom in-game nickname (chosen by the player) is NOT built: it needs text filtering (`TextService:FilterStringAsync`) and rules for
uniqueness and changes. Today the nickname is the Roblox display name.

## 2. Levels: 1 to 100, easy to 30, hard after (`configs/Experience.luau`)

The curve is built from five numbers (`Curve`): from 60 XP at level 1, each level costs **12% more** up to level 30, then **4% more** to
level 100.

| | cost of that level | XP to reach it from level 1 |
|---|---|---|
| level 10 | 165 | 890 |
| level 20 | 515 | 3,810 |
| level 30 | 1,605 | 12,880 |
| level 50 | 3,515 | 60,665 |
| level 75 | about 9,000 | 207,130 |
| level 99 | 24,030 | about 573,000 |
| **level 100** | | **about 597,500** |

At the sources below a full victory is worth about 2,300 XP, so level 30 is a handful of runs and level 100 is a couple of hundred.
All of this is **provisional** and is tuned in one place.

**What earns XP (`Experience.Sources`, `Domain/RunXp`), paid to each player when the run ends:**
the dead slain (Standard 2, Elite 8, Boss 60), each chamber cleared (30 + 10 x its number), each deed (60) and a victory bonus (300);
and, since 0.39.0, **helping and time**: an assist (3: a blow on an enemy someone else finished within 12 seconds), a fallen friend
raised (40) and 6 a minute on your feet (60 minutes at most). A player who took no part (under 100 of damage, assists and revives
together) is paid the shared prizes (chambers, deeds, the victory) at 30% and no time: standing at the gate is not carried to a level.
A wiped run pays everything but the victory bonus: progress persists. Before 0.38.0 a run paid NO experience at all (only the old
placeholder missions did).

**THE PRIZES OF THE ROAD can now be CLAIMED (0.39.0, `Domain/Prizes`, `Hub/HubInventoryService`).** The prize of a level is taken by the
player from the Inventory panel (a CLAIM button), once: gold goes to the purse, items to the stash, the level is marked in
`profile.prizes.claimed` and the profile is saved at once. What the prizes ARE is still not decided (`Experience.LevelRewards` is empty),
so nothing waits yet; the whole path is tested with a fake reward table (`Prizes.spec`) and was claimed end to end in a playtest.

**The roll of honour (0.39.0, `Domain/Mvp`).** On a victory the closing card ends with the company in order of what each did (the dead by
tier, assists, friends raised, damage), one quiet line each, a thin bar and a laurel on the first place when there are two or more.

**Titles** (`configs/Profile.Titles`): a new rank at every tenth level: Recruit 1, Footman 10, Man-at-Arms 20, Sergeant 30, Standard-Bearer
40, Knight-Errant 50, Banneret 60, Castellan 70, Marshal 80, Lord Marshal 90, Warden of the Last Kingdom 100.

**The road and its prizes** (`Experience.Milestones`, `Domain/LevelMilestones`): a prize at **every 5th level**, a **milestone at every
10th**. WHAT the prizes are is not decided: `Experience.LevelRewards[level]` is empty, the Roll shows the twenty stops (reached ones in
gold, the tens larger, the next one outlined) and says they are "still being forged". `RewardService` already works out which prize
levels a gain passes (`Applied.prizeLevels`) and logs them: the day the prizes exist, that is where they are handed over.

## 3. Renown: the whole player in one number (`configs/Profile.Renown`, `Domain/Renown`)

Out of **9,475**, in eight parts, each with a ceiling so that no one thing can make a name: Rank (25 per level above 1, up to 2,475),
Might (150 per rating above 1, up to 1,350), Victories (75 per run won, up to 1,500), Depth (100 per chamber of the deepest reached,
up to 900), Deeds (40 each, up to 1,000), Lore (100 per page, up to 1,000), The Star (50 per shard laid, +300 once raised, up to 750)
and Slaying (0.05 per kill, up to 500). Bands: Unknown, Known (over 250), Respected (1,000), Renowned (2,500), Famed (4,500),
Legendary (7,000). The page shows each part as a bar.

**Renown sets nothing about difficulty.** Difficulty is Might alone, so a long history can never make a run harder or easier.

## 4. Might and the fairness rules (already in the code, shown on the page)

| On the page | Built from | Rule |
|---|---|---|
| **Might** `n of 10`, tier | `Domain/TeamPower.playerRating(levels, "Best")` | the **best** weapon the player has forged; owning more weapons can never lower it |
| "You strike X% harder" | `TeamPower.multiplierFor` on the forge curve | what the best weapon's level gives against a fresh blade |
| "The dead grow Y%" / "edge x1.28" | `TeamPower.enemyScale` (half the gain) and `netAdvantage` | upgrading always leaves the player ahead (`TeamPower.spec`: THE RULE) |

1. **A player is rated by the best weapon they own** (mode `Best`): buying an axe at +1 cannot lower a +10 sword's rating, so nobody can
   sink their rating to get an easy match. (`Average` exists in `TeamPower` and is NOT used.)
2. **A party is rated by the average of its people.** One strong player cannot carry the rating, and one weak player cannot sink it.
3. **The dead grow by half of what the party gained.** At half, every forged level is a real and permanent advantage, and the run
   never becomes a walk.
4. **Real money buys convenience and cosmetics, never power** (`Economy.md`, GDD §2): everything on the page was earned in runs.

## 5. Statistics (`profile.stats`, `Domain/PlayerStats`, `World/RunStatsService`)

Counted in the run by `RunStatsService` (kills by tier from the blow that killed, damage dealt as health actually removed, times fallen,
chambers cleared, deeds, seconds) and added to the profile ONCE when the run is settled (`RunSettlement`): the dead slain, elite and
boss kills, damage, falls, chambers cleared and the deepest, time in the castle, the fastest victory, gold brought home, xp earned,
plus runs won and lost and the win rate. A deed is also written at once to every player's profile as the achievement `deed_<id>`.
A player who leaves mid-run adds nothing. The ending card now says "Experience: +530 (level 7, Recruit)".

## 6. Who builds it, who may see it

- `Server/Domain/PlayerCard.build(profile, ctx)` is PURE: a profile and the config tables go in, a plain table comes out
  (`PlayerCard.spec`); `PlayerCard.brief` cuts it down for the train.
- `Server/Hub/ProfileService` answers `RequestProfile` with `ProfileEvent {kind = "card", card}`. The request carries **no
  player id**: a player can only ever ask for their own page. Asks are throttled.
- `Client/UI/ProfileUI` only draws; `Client/Controllers/ProfileController` is the key, the button and the asking (Hub only).
- The page is read-only: the client changes nothing, so there is nothing to tamper with.
- **The train** (`TrainService.statusPayload`): every member comes with `{ level, title, might, renown }` (`ProfileService.brief`) and the
  party's Might (the average). The panel shows the name, and under it in a smaller hand `Lv 12 · Sergeant · Might 5`, and for a party
  of two or more `Party Might 4.3 of 10`. The party Might is SHOWN, not used. Since 0.39.0 the train also shows the DANGER
  (`+34 of 100 harder`) and lets a small party choose Hard; the difficulty comes from the party's LEVELS, with a shield for new players,
  not from Might (`Danger.md`).

## 7. What is NOT built (see the ideas in the Changelog and the backlog)

- Any use of Might in matchmaking or in `Scaling`: the developer chose levels instead (`Danger.md`); Might stays on the page.
- Looking at another player's roll (consent and what is public first).
- What the prizes of the road ARE (the claim, the claimed mark and the hand-over to the inventory are built).
- A custom nickname, with filtering.
- The admin panel (the Company number and `profile.account` are ready for it).
- A picture of each weapon on the arms list, a crest per rank.
- Cross-place session locking (`Progression.md` §3).
