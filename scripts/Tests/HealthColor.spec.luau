--!strict
--[[
	HealthColor.spec
	The health bar's colour runs green, yellow, orange, red; the percentage never reads 0 while a sliver is left.

	Location: TestService.Tests.HealthColor.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local HealthColor = require(ReplicatedStorage.Shared.HealthColor)
local Hud: any = require(ReplicatedStorage.Config.Hud)

local stops = Hud.HealthBar.Stops

local function same(a: Color3, b: Color3): boolean
	return math.abs(a.R - b.R) + math.abs(a.G - b.G) + math.abs(a.B - b.B) < 0.01
end

return function(t: any)
	t.test("the stops run from full to empty, in order", function()
		assert(stops[1].At == 1 and stops[#stops].At == 0, "from 1 down to 0")
		for i = 2, #stops do
			assert(stops[i].At < stops[i - 1].At, "each stop is lower than the one before")
		end
		assert(#stops == 4, "green, yellow, orange, red")
	end)

	t.test("full is green, empty is red, and the stops are hit exactly", function()
		assert(same(HealthColor.of(1, stops), stops[1].Color), "full health is the first colour")
		assert(same(HealthColor.of(0, stops), stops[4].Color), "no health is the last")
		assert(same(HealthColor.of(0.66, stops), stops[2].Color), "yellow at two thirds")
		assert(same(HealthColor.of(0.33, stops), stops[3].Color), "orange at a third")
	end)

	t.test("between two stops the colour is a blend, not a jump", function()
		local mid = HealthColor.of(0.495, stops) -- half way between orange and yellow
		local a, b = stops[2].Color, stops[3].Color
		assert(not same(mid, a) and not same(mid, b), "neither end")
		assert(mid.R >= math.min(a.R, b.R) - 0.01 and mid.R <= math.max(a.R, b.R) + 0.01, "between them")
	end)

	t.test("values out of range are held to the ends", function()
		assert(same(HealthColor.of(2, stops), stops[1].Color))
		assert(same(HealthColor.of(-1, stops), stops[4].Color))
	end)

	t.test("the percentage is rounded up while alive and zero only at zero", function()
		assert(HealthColor.percent(100, 100) == 100)
		assert(HealthColor.percent(87.2, 100) == 88, "up")
		assert(HealthColor.percent(0.1, 100) == 1, "a sliver is 1, not 0")
		assert(HealthColor.percent(0, 100) == 0)
		assert(HealthColor.percent(50, 0) == 0, "no max, no percentage")
	end)
end
