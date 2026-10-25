--!strict
--[[
	Settlement (domain)
	What a run is worth when it ends (docs/systems/Spoils.md §7). Pure rules over a
	backpack and a profile, no Roblox: the service that calls it owns the players,
	the saving and the screen.

	A WON RUN banks everything the pack holds that can be banked: gold becomes the
	profile's currency, every material, consumable, relic, shard and page goes into
	its STASH (a table of counts), and a prisoner who is still alive at the end pays
	the whole team a bonus on top of the gold.

	A WIPED RUN keeps what the Story says is never lost (star shards and pages) and
	only a fraction of the gold (`Loot.Rules.WipeKeepsGold`, a quarter); no bonus.

	QUEST ITEMS (a torch, planks, a key) are never banked: `Backpack.bankable` leaves
	them out, and they are not in the ledger.

	Location: ServerScriptService.Server.Domain.Settlement
]]

local Backpack = require(script.Parent.Backpack)

local Settlement = {}

export type Outcome = "won" | "wiped"

export type Rules = {
	keepFraction: number, -- of the gold, on a wiped run
	bonus: number, -- of the gold, on a won run with the prisoner alive
}

export type Ledger = {
	outcome: Outcome,
	gold: number, -- banked from the pack
	bonusGold: number, -- on top, the prisoner
	lostGold: number, -- what a wiped run did not keep
	items: { [string]: number },
}

export type Profile = {
	currency: number,
	stash: { [string]: number },
	stats: { [string]: any },
}

--[[
	What `backpack` is worth. `prisonerAlive` only matters on a won run. Gold is
	always whole: a quarter of 7 is 1, never 1.75.
]]
function Settlement.compute(backpack: Backpack.Backpack, outcome: Outcome, rules: Rules, prisonerAlive: boolean): Ledger
	local have = backpack.gold
	if outcome == "won" then
		local bonus = if prisonerAlive then math.floor(have * rules.bonus + 0.5) else 0
		return {
			outcome = outcome,
			gold = have,
			bonusGold = bonus,
			lostGold = 0,
			items = backpack:bankable(false),
		}
	end
	local kept = math.floor(have * rules.keepFraction)
	return {
		outcome = outcome,
		gold = kept,
		bonusGold = 0,
		lostGold = have - kept,
		items = backpack:bankable(true),
	}
end

-- Writes a ledger into a profile. Returns the profile's new currency.
function Settlement.apply(profile: Profile, ledger: Ledger): number
	profile.currency = (profile.currency or 0) + ledger.gold + ledger.bonusGold
	profile.stash = profile.stash or {}
	for itemId, count in ledger.items do
		profile.stash[itemId] = (profile.stash[itemId] or 0) + count
	end
	profile.stats = profile.stats or {}
	local key = if ledger.outcome == "won" then "runsWon" else "runsWiped"
	profile.stats[key] = (profile.stats[key] or 0) + 1
	local best = (profile.stats.bestRunGold or 0) :: number
	profile.stats.bestRunGold = math.max(best, ledger.gold + ledger.bonusGold)
	return profile.currency
end

return Settlement
