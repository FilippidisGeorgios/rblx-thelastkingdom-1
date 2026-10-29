--!strict
--[[
	LevelMilestones.spec
	Where the prizes sit: one at every 5th level, a milestone at every 10th; the next one and how far, the
	prizes passed by a gain, and the whole road for drawing.

	Location: TestService.Tests.LevelMilestones.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local LevelMilestones = require(ServerScriptService.Server.Domain.LevelMilestones)
local Experience: any = require(ReplicatedStorage.Config.Experience)

local rules = { RewardEvery = 5, MilestoneEvery = 10 }

return function(t: any)
	t.test("a prize at every fifth level, a milestone at every tenth, none at level 1", function()
		assert(not LevelMilestones.isRewardLevel(1, rules), "level 1 is where everyone starts")
		assert(LevelMilestones.isRewardLevel(5, rules) and LevelMilestones.isRewardLevel(15, rules), "5 and 15")
		assert(not LevelMilestones.isRewardLevel(7, rules), "7 is not")
		assert(LevelMilestones.isMilestone(10, rules) and LevelMilestones.isMilestone(100, rules), "10 and 100")
		assert(not LevelMilestones.isMilestone(5, rules) and not LevelMilestones.isMilestone(15, rules), "a prize level that is not a milestone")
	end)

	t.test("the next prize above a level, and none past the top", function()
		assert(LevelMilestones.nextRewardLevel(1, 100, rules) == 5, "from 1 it is 5")
		assert(LevelMilestones.nextRewardLevel(5, 100, rules) == 10, "standing on one, the next")
		assert(LevelMilestones.nextRewardLevel(94, 100, rules) == 95, "94 -> 95")
		assert(LevelMilestones.nextRewardLevel(100, 100, rules) == nil, "nothing above 100")
		assert(LevelMilestones.nextRewardLevel(99, 100, rules) == 100, "99 -> 100")
	end)

	t.test("the prizes a gain passes: not the level left, the level reached", function()
		local got = LevelMilestones.reachedBetween(3, 11, rules)
		assert(#got == 2 and got[1] == 5 and got[2] == 10, "3 to 11 passes 5 and 10")
		assert(#LevelMilestones.reachedBetween(5, 9, rules) == 0, "5 to 9: the 5 was already had")
		assert(#LevelMilestones.reachedBetween(4, 5, rules) == 1, "reaching 5 counts")
		assert(#LevelMilestones.reachedBetween(7, 7, rules) == 0, "no gain, no prize")
	end)

	t.test("the road has twenty stops to 100, reached up to the player's level, the tens marked", function()
		local road = LevelMilestones.road(23, 100, rules, nil)
		assert(#road == 20, "twenty stops")
		assert(road[1].level == 5 and road[20].level == 100, "from 5 to 100")
		local reached, big = 0, 0
		for _, stop in road do
			if stop.reached then
				reached += 1
			end
			if stop.milestone then
				big += 1
			end
			assert(not stop.given, "no prize is decided yet")
		end
		assert(reached == 4, "5, 10, 15 and 20 are behind a level-23 player")
		assert(big == 10, "ten milestones")
		local withPrize = LevelMilestones.road(1, 100, rules, { [10] = { gold = 100 } })
		assert(withPrize[2].given and not withPrize[1].given, "a prize in the config shows as given")
	end)

	t.test("the real config: prizes every 5th and milestones every 10th, with the prizes still to decide", function()
		local m = Experience.Milestones
		assert(m.RewardEvery == 5 and m.MilestoneEvery == 10, "5 and 10, as asked")
		assert(m.MilestoneEvery % m.RewardEvery == 0, "every milestone is on a prize level")
		assert(next(Experience.LevelRewards) == nil, "no prize is decided yet")
	end)
end
