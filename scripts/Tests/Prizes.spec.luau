--!strict
--[[
	Prizes.spec
	The claim: a prize at every fifth level is collected once, by the player, into the purse and the stash;
	nothing is pending while the config has no prizes; a bad reward is refused whole.

	Location: TestService.Tests.Prizes.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Prizes = require(ServerScriptService.Server.Domain.Prizes)
local Experience: any = require(ReplicatedStorage.Config.Experience)

local milestones = { RewardEvery = 5, MilestoneEvery = 10 }
local items = { bone_dust = true, iron_shard = true }

local rewards: { [number]: Prizes.Reward } = {
	[5] = { Gold = 100, Items = { bone_dust = 3 } },
	[10] = { Gold = 250, Items = { iron_shard = 2 }, Title = "Footman of the Wall" },
	[15] = { Items = { bone_dust = 5 } },
}

local function profile(level: number): { [string]: any }
	return { level = level, currency = 0, stash = {} }
end

return function(t: any)
	t.test("a prize level is every fifth level, up to the player's own", function()
		local levels = Prizes.prizeLevels(23, milestones)
		assert(#levels == 4 and levels[1] == 5 and levels[4] == 20, "5, 10, 15, 20")
		assert(#Prizes.prizeLevels(4, milestones) == 0, "none before the fifth")
		assert(#Prizes.prizeLevels(100, milestones) == 20, "twenty stops on the road")
	end)

	t.test("while the config has no prizes, nothing is ever waiting", function()
		assert(next(Experience.LevelRewards) == nil, "(the prizes are still being forged)")
		local p = profile(100)
		assert(#Prizes.waiting(p, Experience.LevelRewards, milestones) == 0, "nothing to claim at level 100")
		local claimed, why = Prizes.claim(p, 50, Experience.LevelRewards, milestones, items)
		assert(claimed == nil and why == "no prize", "and a claim finds nothing")
	end)

	t.test("what is waiting is what was reached, defined and not yet taken, lowest first", function()
		local p = profile(12)
		local waiting = Prizes.waiting(p, rewards, milestones)
		assert(#waiting == 2 and waiting[1].level == 5 and waiting[2].level == 10, "5 and 10; 15 is not reached")
		assert(not waiting[1].milestone and waiting[2].milestone, "the tenth is a milestone")
	end)

	t.test("claiming pays gold into the purse and items into the stash, and marks the level taken", function()
		local p = profile(10)
		local claim = Prizes.claim(p, 10, rewards, milestones, items)
		assert(claim ~= nil, "claimed")
		assert(claim.gold == 250 and claim.items.iron_shard == 2 and claim.title == "Footman of the Wall" and claim.milestone, "what was given")
		assert(p.currency == 250 and p.stash.iron_shard == 2, "in the profile")
		assert(p.prizes.titles["Footman of the Wall"] == true, "and the title is kept")
		assert(Prizes.isClaimed(p, 10) and not Prizes.isClaimed(p, 5), "only that level is taken")
	end)

	t.test("a prize is taken once: the second claim gives nothing", function()
		local p = profile(10)
		assert(Prizes.claim(p, 5, rewards, milestones, items) ~= nil, "the first time")
		local again, why = Prizes.claim(p, 5, rewards, milestones, items)
		assert(again == nil and why == "already taken", "refused: " .. tostring(why))
		assert(p.currency == 100 and p.stash.bone_dust == 3, "and nothing was paid twice")
		assert(#Prizes.waiting(p, rewards, milestones) == 1, "only the tenth is left")
	end)

	t.test("a level not yet reached, or without a prize, cannot be claimed", function()
		local p = profile(7)
		local early, why = Prizes.claim(p, 10, rewards, milestones, items)
		assert(early == nil and why == "not reached", "the tenth is for later")
		local odd, why2 = Prizes.claim(p, 7, rewards, milestones, items)
		assert(odd == nil and why2 == "no prize", "level 7 is not a prize level")
		assert(p.currency == 0 and next(p.stash) == nil, "nothing moved")
	end)

	t.test("a reward naming an item nobody defined is refused whole, and the level stays open", function()
		local p = profile(5)
		local broken: { [number]: Prizes.Reward } = { [5] = { Gold = 50, Items = { not_an_item = 1 } } }
		local claim, why = Prizes.claim(p, 5, broken, milestones, items)
		assert(claim == nil and why == "no prize", "refused")
		assert(p.currency == 0 and not Prizes.isClaimed(p, 5), "no gold given and not marked taken")
	end)

	t.test("several claims in a row add up, and an old profile without the field is mended", function()
		local p = profile(15)
		for _, level in { 5, 10, 15 } do
			assert(Prizes.claim(p, level, rewards, milestones, items) ~= nil, "claim " .. level)
		end
		assert(p.currency == 350 and p.stash.bone_dust == 8 and p.stash.iron_shard == 2, "the sum")
		assert(#Prizes.waiting(p, rewards, milestones) == 0, "the road is collected")
	end)
end
