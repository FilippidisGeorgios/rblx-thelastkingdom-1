--!strict
--[[
	PlayerStats.spec
	The lifetime statistics a settled run adds to the profile: kills by tier, damage, falls, chambers (counted
	once, with the deepest), time (with the fastest victory), gold and xp.

	Location: TestService.Tests.PlayerStats.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local PlayerStats = require(ServerScriptService.Server.Domain.PlayerStats)

local function run(): any
	return { kills = { Standard = 40, Elite = 3, Boss = 1 }, damage = 1234.7, downs = 2, cleared = { 1, 2, 3, 3 }, seconds = 1800.9 }
end

return function(t: any)
	t.test("a run is added to an empty profile", function()
		local stats: any = {}
		PlayerStats.addRun(stats, run(), "wiped", 120, 500)
		assert(stats.kills == 44 and stats.eliteKills == 3 and stats.bossKills == 1, "44 dead, 3 elite, 1 boss")
		assert(stats.damageDealt == 1234 and stats.downs == 2, "whole points of damage, two falls")
		assert(stats.chambersCleared == 3 and stats.deepestChamber == 3, "a chamber reported twice counts once")
		assert(stats.playSeconds == 1800 and stats.goldBanked == 120 and stats.xpEarned == 500, "time, gold, xp")
		assert(stats.fastestWinSeconds == nil, "a wipe is not a victory")
	end)

	t.test("runs add up, the deepest only rises, and the fastest victory only falls", function()
		local stats: any = {}
		PlayerStats.addRun(stats, run(), "won", 100, 100)
		assert(stats.fastestWinSeconds == 1800, "the first victory is the fastest")
		local second = run()
		second.seconds = 2400
		second.cleared = { 1 }
		PlayerStats.addRun(stats, second, "won", 50, 50)
		assert(stats.fastestWinSeconds == 1800, "a slower victory does not replace it")
		assert(stats.deepestChamber == 3, "a shallower run does not lower the deepest")
		local third = run()
		third.seconds = 1500
		third.cleared = { 1, 2, 3, 4, 5 }
		PlayerStats.addRun(stats, third, "won", 0, 0)
		assert(stats.fastestWinSeconds == 1500 and stats.deepestChamber == 5, "a faster, deeper one does")
		assert(stats.kills == 44 * 3 and stats.goldBanked == 150, "the totals add")
	end)

	t.test("nonsense in a record never subtracts", function()
		local stats: any = { kills = 10 }
		PlayerStats.addRun(stats, { kills = { Standard = -5 }, damage = -100, downs = -1, cleared = {}, seconds = -9 }, "wiped", -50, -10)
		assert(stats.kills == 10 and stats.damageDealt == 0 and stats.downs == 0, "nothing taken away")
		assert(stats.playSeconds == 0 and stats.goldBanked == 0 and stats.xpEarned == 0, "nor from time, gold or xp")
	end)
end
