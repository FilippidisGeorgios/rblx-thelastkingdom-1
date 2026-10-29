--!strict
--[[
	RunXp.spec
	What a run pays in experience: the dead by tier, each chamber once, the deeds, and the victory bonus;
	a wiped run keeps everything but the bonus.

	Location: TestService.Tests.RunXp.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RunXp = require(ServerScriptService.Server.Domain.RunXp)
local Experience: any = require(ReplicatedStorage.Config.Experience)

local rules = {
	Kill = { Standard = 2, Elite = 8, Boss = 60 },
	Chamber = { Base = 30, PerChamber = 10 },
	Deed = 60,
	Won = 300,
}

return function(t: any)
	t.test("an empty run pays nothing", function()
		local xp = RunXp.compute({ kills = {}, cleared = {}, deeds = 0 }, "wiped", rules)
		assert(xp.total == 0, "nothing done, nothing paid")
	end)

	t.test("the dead pay by their tier", function()
		local xp = RunXp.compute({ kills = { Standard = 10, Elite = 2, Boss = 1 }, cleared = {}, deeds = 0 }, "wiped", rules)
		assert(xp.kills == 10 * 2 + 2 * 8 + 60 and xp.total == xp.kills, "20 + 16 + 60")
		local unknown = RunXp.compute({ kills = { Mystery = 5 }, cleared = {}, deeds = 0 }, "wiped", rules)
		assert(unknown.total == 0, "a tier nobody priced pays nothing, not an error")
	end)

	t.test("each chamber pays Base + PerChamber x n, once however often it is reported", function()
		local xp = RunXp.compute({ kills = {}, cleared = { 1, 2, 2, 3 }, deeds = 0 }, "wiped", rules)
		assert(xp.chambers == (30 + 10) + (30 + 20) + (30 + 30), "chambers 1, 2 and 3 once each")
	end)

	t.test("deeds pay, and a victory adds its bonus on top; a wipe does not", function()
		local run = { kills = { Standard = 5 }, cleared = { 1 }, deeds = 3 }
		local won = RunXp.compute(run, "won", rules)
		local wiped = RunXp.compute(run, "wiped", rules)
		assert(won.deeds == 180 and won.won == 300, "three deeds and the castle taken")
		assert(wiped.won == 0, "no victory bonus on a wipe")
		assert(won.total - wiped.total == 300, "a wipe keeps all the rest: progress persists")
	end)

	t.test("a full victory is worth about what the curve was tuned for", function()
		local kills = { Standard = 350, Elite = 25, Boss = 3 }
		local cleared = { 1, 2, 3, 4, 5, 6, 7, 8, 9 }
		local xp = RunXp.compute({ kills = kills, cleared = cleared, deeds = 9 }, "won", Experience.Sources)
		assert(xp.total > 1500 and xp.total < 4000, "a full run pays a few thousand: " .. xp.total)
	end)
end
