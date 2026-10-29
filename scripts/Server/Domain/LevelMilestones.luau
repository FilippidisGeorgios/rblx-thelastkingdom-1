--!strict
--[[
	LevelMilestones (domain)
	Where the prizes sit on the road from level 1 to the top: one at every 5th level, and a MILESTONE
	(a new rank, a bigger prize) at every 10th. Pure: levels and the config in, levels out.

	What a prize IS lives in `configs/Experience.LevelRewards[level]` and is not decided yet; this only
	says WHERE the prizes are and which ones a player has reached, so the Muster Roll can show the road
	and, later, a reward service can hand each one over exactly once (`reachedBetween`).

	Location: ServerScriptService.Server.Domain.LevelMilestones
]]

local LevelMilestones = {}

export type Rules = { RewardEvery: number, MilestoneEvery: number }

export type Stop = {
	level: number,
	milestone: boolean, -- a tenth level: the big stop
	reached: boolean,
	given: boolean, -- the config says what the prize is
}

-- Is there a prize at this level? (Level 1 is where everyone starts: none.)
function LevelMilestones.isRewardLevel(level: number, rules: Rules): boolean
	return level > 1 and level % rules.RewardEvery == 0
end

function LevelMilestones.isMilestone(level: number, rules: Rules): boolean
	return level > 1 and level % rules.MilestoneEvery == 0
end

-- The next prize level above `level`, up to `maxLevel`; nil when there is none left.
function LevelMilestones.nextRewardLevel(level: number, maxLevel: number, rules: Rules): number?
	local candidate = (math.floor(level / rules.RewardEvery) + 1) * rules.RewardEvery
	if candidate <= maxLevel then
		return candidate
	end
	return nil
end

-- Every prize level a player passes going from `from` to `to` (exclusive of `from`, inclusive of `to`).
function LevelMilestones.reachedBetween(from: number, to: number, rules: Rules): { number }
	local out: { number } = {}
	for level = from + 1, to do
		if LevelMilestones.isRewardLevel(level, rules) then
			table.insert(out, level)
		end
	end
	return out
end

-- The whole road, in order, for drawing: a stop at every prize level.
function LevelMilestones.road(level: number, maxLevel: number, rules: Rules, rewards: { [number]: any }?): { Stop }
	local stops: { Stop } = {}
	for at = 1, maxLevel do
		if LevelMilestones.isRewardLevel(at, rules) then
			table.insert(stops, {
				level = at,
				milestone = LevelMilestones.isMilestone(at, rules),
				reached = level >= at,
				given = rewards ~= nil and rewards[at] ~= nil,
			})
		end
	end
	return stops
end

return LevelMilestones
