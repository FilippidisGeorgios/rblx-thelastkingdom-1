--!strict
--[[
	Prizes (domain)
	The prizes of the road to level 100, and how a player CLAIMS one: a prize waits at every fifth level
	(`Experience.Milestones.RewardEvery`), the player collects it, and it goes into their inventory.

	WHAT the prizes are is not decided: `Experience.LevelRewards` is empty today, so nothing is ever pending.
	The day it is filled, the claim, the saving and the "claimed" mark below already work. A reward is
		LevelRewards[level] = { Gold = number?, Items = { [itemId] = count }?, Title = string? }
	Gold goes to the purse (`profile.currency`), items to the stash (`profile.stash`, which the Hub's
	inventory shows), a title to `profile.prizes.titles`. Anything else a prize may become later (a banner, a
	tabard) is another key here, nothing else changes.

	Claiming is the player's act, never automatic, and happens ONCE per level: `profile.prizes.claimed` keeps the
	levels already taken, keyed by the level as a string (a DataStore turns numeric keys into trouble).

	Pure: a profile table and the config tables in, the profile changed and a result out.

	Location: ServerScriptService.Server.Domain.Prizes
]]

local Prizes = {}

export type Reward = { Gold: number?, Items: { [string]: number }?, Title: string? }

export type Milestones = { RewardEvery: number, MilestoneEvery: number }

export type Waiting = { level: number, reward: Reward, milestone: boolean }

export type Claimed = {
	level: number,
	gold: number,
	items: { [string]: number },
	title: string?,
	milestone: boolean,
}

-- The levels up to `level` that carry a prize (reached or not), whether or not the prize is defined yet.
function Prizes.prizeLevels(upTo: number, milestones: Milestones): { number }
	local out: { number } = {}
	local every = math.max(milestones.RewardEvery, 1)
	local level = every
	while level <= upTo do
		table.insert(out, level)
		level += every
	end
	return out
end

local function claimedOf(profile: { [string]: any }): { [string]: any }
	local prizes = profile.prizes
	if type(prizes) ~= "table" then
		prizes = { claimed = {}, titles = {} }
		profile.prizes = prizes
	end
	prizes.claimed = prizes.claimed or {}
	prizes.titles = prizes.titles or {}
	return prizes.claimed
end

function Prizes.isClaimed(profile: { [string]: any }, level: number): boolean
	return claimedOf(profile)[tostring(level)] ~= nil
end

-- Prizes the player has reached, that exist, and have not been taken. Lowest level first.
function Prizes.waiting(profile: { [string]: any }, rewards: { [number]: Reward }, milestones: Milestones): { Waiting }
	local out: { Waiting } = {}
	for _, level in Prizes.prizeLevels(profile.level or 1, milestones) do
		local reward = rewards[level]
		if reward and not Prizes.isClaimed(profile, level) then
			table.insert(out, {
				level = level,
				reward = reward,
				milestone = level % math.max(milestones.MilestoneEvery, 1) == 0,
			})
		end
	end
	return out
end

--[[
	Takes the prize of `level`. Returns the claim, or nil and why:
	  "not reached"   the player's level is lower
	  "no prize"      that level has no prize (not a prize level, or not defined yet)
	  "already taken" it was claimed before
	`known` is the table of item ids that exist (configs/Items): a reward naming an item nobody defined is
	refused whole, so a typo in the config can never hand out nothing and mark the prize taken.
]]
function Prizes.claim(
	profile: { [string]: any },
	level: number,
	rewards: { [number]: Reward },
	milestones: Milestones,
	known: { [string]: any }?
): (Claimed?, string?)
	if (profile.level or 1) < level then
		return nil, "not reached"
	end
	local reward = rewards[level]
	if not reward or level % math.max(milestones.RewardEvery, 1) ~= 0 then
		return nil, "no prize"
	end
	if Prizes.isClaimed(profile, level) then
		return nil, "already taken"
	end
	if known and reward.Items then
		for itemId in reward.Items do
			if known[itemId] == nil then
				return nil, "no prize"
			end
		end
	end

	local gold = math.max(0, math.floor(reward.Gold or 0))
	profile.currency = (profile.currency or 0) + gold

	local items: { [string]: number } = {}
	profile.stash = profile.stash or {}
	if reward.Items then
		for itemId, count in reward.Items do
			local n = math.max(0, math.floor(count))
			if n > 0 then
				profile.stash[itemId] = (profile.stash[itemId] or 0) + n
				items[itemId] = n
			end
		end
	end

	local claimed = claimedOf(profile)
	claimed[tostring(level)] = os.time()
	if reward.Title then
		profile.prizes.titles[reward.Title] = true
	end

	return {
		level = level,
		gold = gold,
		items = items,
		title = reward.Title,
		milestone = level % math.max(milestones.MilestoneEvery, 1) == 0,
	},
		nil
end

return Prizes
