# Profile — the Muster Roll (Built, 0.37.0)

**What it is.** Every player has one page about themselves in the Hub: who they are in the Company (a rank title from their
level), how strong they are (**Might**), the arms they have forged, their record, and what they have collected. It is the
first place the player can SEE the numbers the difficulty already works from, so the fairness rules are visible rather than
hidden.

**Open it:** key `P`, or the small `ROLL` button in the bottom-right corner of the Hub (also the touch way in).

## 1. What the page says, and where each number comes from

| On the page | Built from | Rule |
|---|---|---|
| Rank title, level, xp bar | `profile.level`, `profile.xp`, `configs/Experience`, `configs/Profile.Titles` | the title is the level's, from the config |
| **Might** `n of 10`, tier | `Domain/TeamPower.playerRating(levels, "Best")`, `configs/Profile.MightTiers` | the **best** weapon the player has forged; owning more weapons can never lower it |
| "You strike X% harder" | `TeamPower.multiplierFor` on the forge curve (`configs/Economy.Upgrades.Weapon`) | what the best weapon's level gives against a fresh blade |
| "The dead grow Y%" / "edge x1.28" | `TeamPower.enemyScale` (half of the gain) and `netAdvantage` | upgrading always leaves the player ahead (`TeamPower.spec`: THE RULE) |
| Arms (pips) | `profile.upgrades`, `configs/Weapons` | unlocked arms first, best forged first; a weapon below its level gate says so |
| Record | `profile.stats` (`runsWon`, `runsWiped`, `bestRunGold`), `profile.achievements` | counted by `RunSettlement` and the deeds |
| Collection | `profile.stash` (pages, kinds), `profile.altar.offered`, `Chapel.journal` | the same sources as the Chapel |
| Charm worn | `profile.loadout.charm`, only while still in the stash | with its picture (`UI/ItemArt`) |

Nothing on the page is a new rule. Change the forge curve, the XP curve or the weapons and the page follows.

## 2. Who builds it, who may see it

- `Server/Domain/PlayerCard.build(profile, ctx)` is PURE: a profile and the config tables go in, a plain table comes out
  (`PlayerCard.spec`).
- `Server/Hub/ProfileService` answers `RequestProfile` with `ProfileEvent {kind = "card", card}`. The request carries **no
  player id**: a player can only ever ask for their own page. Asks are throttled to one per 0.4 s.
- `Client/UI/ProfileUI` only draws; `Client/Controllers/ProfileController` is the key, the button and the asking (Hub only).
- The page is read-only: the client changes nothing, so there is nothing to tamper with.

## 3. The fairness rules the page shows (already in the code)

1. **A player is rated by the best weapon they own.** (`playerRating`, mode `Best`.) Buying an axe at +1 cannot lower a +10 sword's
   rating, so nobody can sink their rating to get an easy match. (`Average` exists in `TeamPower` and is NOT used.)
2. **A party is rated by the average of its people.** One strong player cannot carry the rating, and one weak player cannot sink it.
3. **The dead grow by half of what the party gained.** At half, every forged level is a real and permanent advantage, and the run
   never becomes a walk.
4. **Real money buys convenience and cosmetics, never power** (`Economy.md`, GDD §2): everything on the page was earned in runs
   (gold from the dead, upgrades at the forge, deeds), so two players with the same page earned the same standing.

## 4. What is NOT built yet (waiting for the design talk)

- **Points as a separate score** (a renown or season score computed from deeds, runs, speed). Today "points" on the page is the
  Might rating. The words of the discussion about fairer points are not in the docs; the developer will say what they want.
- **Looking at another player's roll** (a party mate, a friend). It needs consent rules and what is public; the request has no
  target by design until then.
- **The Roll's rating used by the train/party** (showing the party's rating before departure: `TeamPower.partyRating` and
  `enemyScale` are written and tested but nothing reads them yet in the matchmaking or in `Scaling`).
- **Per-account separation** is the DataStore profile itself (keyed by user id, loaded on join, saved on leave and every few
  minutes: `SaveService`). The page makes it visible ("kept on your account"). Cross-place session locking is still open
  (`Progression.md` §3).
- A picture of the weapons on the arms list (they are 3D models in `ServerStorage.Assets.Weapons`, not meshes the client can load
  by id yet) and a title picture/crest per rank.
