--!strict
--[[
	Mvp.spec
	The roll of honour: who stands first, ties that never flicker, a quiet line for each, and no laurel for a
	run of one.

	Location: TestService.Tests.Mvp.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Mvp = require(ServerScriptService.Server.Domain.Mvp)
local Experience: any = require(ReplicatedStorage.Config.Experience)

local weights = Experience.Mvp

local function entry(userId: number, name: string, kills: { [string]: number }, damage: number, assists: number, revives: number): Mvp.Entry
	return { userId = userId, name = name, kills = kills, damage = damage, assists = assists, revives = revives }
end

return function(t: any)
	t.test("the one who did most stands first and carries the laurel", function()
		local rows = Mvp.rank({
			entry(1, "Ada", { Standard = 20 }, 1000, 0, 0),
			entry(2, "Bram", { Standard = 40, Elite = 3 }, 4000, 5, 1),
			entry(3, "Cato", { Standard = 10 }, 500, 2, 0),
		}, weights)
		assert(rows[1].name == "Bram" and rows[1].rank == 1 and rows[1].mvp, "Bram first")
		assert(rows[2].name == "Ada" and rows[3].name == "Cato", "then Ada, then Cato")
		assert(not rows[2].mvp and not rows[3].mvp, "one laurel")
		assert(rows[1].share == 1 and rows[3].share < rows[2].share, "bars fall away")
	end)

	t.test("raising a friend can outweigh a pile of ordinary kills", function()
		local rows = Mvp.rank({
			entry(1, "Slayer", { Standard = 20 }, 800, 0, 0),
			entry(2, "Healer", { Standard = 5 }, 200, 6, 3),
		}, weights)
		assert(rows[1].name == "Healer", "three friends raised beat twenty ordinary dead")
	end)

	t.test("a tie goes to the damage, then to the name, and never changes between asks", function()
		local a = entry(1, "Zed", {}, 100, 0, 0)
		local b = entry(2, "Amy", {}, 100, 0, 0)
		local rows = Mvp.rank({ a, b }, weights)
		assert(rows[1].name == "Amy", "equal score and damage: the name")
		local again = Mvp.rank({ b, a }, weights)
		assert(again[1].name == "Amy", "the order of the input does not matter")
		local more = Mvp.rank({ entry(1, "Zed", {}, 100, 0, 0), entry(2, "Amy", {}, 99, 0, 0) }, weights)
		assert(more[1].name == "Zed", "more damage wins a tie in score")
	end)

	t.test("a lone player is shown their tally, without a laurel", function()
		local rows = Mvp.rank({ entry(1, "Solo", { Standard = 30 }, 2000, 0, 0) }, weights)
		assert(#rows == 1 and rows[1].rank == 1 and not rows[1].mvp, "no laurel for one")
		assert(rows[1].slain == 30, "the tally is there")
	end)

	t.test("nobody who did nothing is crowned", function()
		local rows = Mvp.rank({ entry(1, "A", {}, 0, 0, 0), entry(2, "B", {}, 0, 0, 0) }, weights)
		assert(not rows[1].mvp and rows[1].share == 0, "no laurel on zero")
	end)

	t.test("the line says only what is true, in a quiet voice", function()
		local rows = Mvp.rank({ entry(1, "Ada", { Standard = 41, Elite = 1 }, 900, 1, 2) }, weights)
		assert(rows[1].line == "42 slain  ·  1 assist  ·  2 raised", rows[1].line)
		local plain = Mvp.rank({ entry(1, "Bo", { Standard = 3 }, 10, 0, 0) }, weights)
		assert(plain[1].line == "3 slain", plain[1].line)
	end)

	t.test("falling costs nothing, negative numbers count as zero, and an empty run is an empty list", function()
		local rows = Mvp.rank({ entry(1, "Odd", { Standard = -5 }, -10, -3, -1) }, weights)
		assert(rows[1].score == 0 and rows[1].slain == 0, "nothing negative")
		assert(#Mvp.rank({}, weights) == 0, "no one, no rows")
	end)

	t.test("the weights are in the config, positive, and a boss is worth more than a crowd", function()
		for tier, w in weights.Kill do
			assert(w > 0, tier .. " is worth something")
		end
		assert(weights.Kill.Boss > weights.Kill.Elite and weights.Kill.Elite > weights.Kill.Standard, "tiers climb")
		assert(weights.Revive > weights.Assist, "raising a friend beats an assist")
	end)
end
