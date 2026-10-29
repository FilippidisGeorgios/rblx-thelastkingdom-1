--!strict
--[[
	Experience.spec
	The road to level 100: the curve is built for it, easy until 30 and hard after, and the numbers a player
	meets on the way are what the config says.

	Location: TestService.Tests.Experience.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Experience: any = require(ReplicatedStorage.Config.Experience)
local Progression = require(ServerScriptService.Server.Domain.Progression)

local function cumulative(upTo: number): number
	local total = 0
	for level = 1, upTo - 1 do
		total += Experience.XpToLevel[level]
	end
	return total
end

return function(t: any)
	t.test("level 100 is the top and every level below it has a price", function()
		assert(Experience.MaxLevel == 100, "the top is 100")
		assert(#Experience.XpToLevel == 99, "99 steps")
		for level = 1, 99 do
			assert(type(Experience.XpToLevel[level]) == "number" and Experience.XpToLevel[level] > 0, "level " .. level .. " has a price")
		end
	end)

	t.test("each level costs more than the one before", function()
		for level = 2, 99 do
			assert(Experience.XpToLevel[level] >= Experience.XpToLevel[level - 1], "level " .. level .. " is not cheaper than the last")
		end
	end)

	t.test("easy to 30: a few thousand xp to level 20, under fifteen thousand to level 30", function()
		assert(cumulative(20) < 5000, "level 20 within a few runs: " .. cumulative(20))
		assert(cumulative(30) < 15000, "level 30 in a handful of runs: " .. cumulative(30))
		assert(Experience.XpToLevel[10] < 250, "the first ten levels cost almost nothing each")
	end)

	t.test("hard after 30: the second half is most of the road, and the last levels cost a great deal", function()
		local toTop = cumulative(100)
		assert(toTop > 400000 and toTop < 900000, "about half a million to the top: " .. toTop)
		assert((toTop - cumulative(50)) > 0.8 * toTop, "levels 50 to 100 are most of the xp")
		assert(Experience.XpToLevel[99] > 10 * Experience.XpToLevel[30], "level 99 costs over ten times level 30")
		assert(Experience.XpToLevel[99] / Experience.XpToLevel[98] < 1.1, "and it grows steadily, not in a cliff")
	end)

	t.test("the maths walks the whole road: enough xp for every level reaches 100 and stops", function()
		local xp, level, gained = Progression.addXp(0, 1, cumulative(100), Experience)
		assert(level == 100 and gained == 99 and xp == 0, "all the way, nothing left over")
		local past, topLevel = Progression.addXp(xp, level, 1000000, Experience)
		assert(topLevel == 100 and past == 1000000, "there is no level 101")
		local one = Progression.addXp(0, 1, Experience.XpToLevel[1] - 1, Experience)
		assert(one == Experience.XpToLevel[1] - 1, "one xp short is not a level")
	end)

	t.test("what a run pays is named and priced for every enemy tier", function()
		local enemies: any = require(ReplicatedStorage.Config.Enemies)
		for id, def in enemies do
			if type(def) == "table" and def.Tier then
				assert(Experience.Sources.Kill[def.Tier] ~= nil, id .. " is a " .. def.Tier .. ": priced")
			end
		end
	end)
end
