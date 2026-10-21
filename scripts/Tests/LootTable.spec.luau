--!strict
--[[
	LootTable.spec
	The roll: chances, gold scaling, merging, and the pity that makes a bad
	streak finite. The RNG is scripted so every case is exact.

	Location: TestService.Tests.LootTable.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local LootTable = require(ServerScriptService.Server.Domain.LootTable)

local rules = {
	GoldPerDepth = 0.15,
	SoundPerDepth = 0.08,
	HallowedPerDepth = 0.06,
	PityGuaranteeSound = 3,
	PityUpgradeHallowed = 5,
}

local items = {
	bone_dust = { Rank = "Worn" },
	tallow = { Rank = "Sound" },
	hollow_ember = { Rank = "Hallowed" },
}

-- Hands out the numbers it is given, then 0.99 forever (a roll nothing passes).
local function scripted(numbers: { number })
	local i = 0
	return {
		NextNumber = function(_self: any, a: number?, b: number?): number
			i += 1
			local v = numbers[i] or 0.99
			if a and b then
				return a + (b - a) * v
			end
			return v
		end,
		NextInteger = function(_self: any, a: number, b: number): number
			i += 1
			local v = numbers[i] or 0.99
			return a + math.floor((b - a + 1) * v - 1e-9)
		end,
	}
end

local def = {
	Gold = { Chance = 0.5, Min = 10, Max = 10 },
	Drops = { { Item = "bone_dust", Chance = 0.5, Min = 2, Max = 2 } },
	Sound = { Chance = 0.1, Pool = { { Item = "tallow", Weight = 1, Min = 1, Max = 1 } } },
	Hallowed = { Chance = 0.01, Pool = { { Item = "hollow_ember", Weight = 1, Min = 1, Max = 1 } } },
}

return function(t: any)
	t.test("a roll nothing passes gives nothing", function()
		local drops = LootTable.roll(def, items, rules, scripted({}), nil)
		assert(#drops == 0, "no drops")
	end)

	t.test("gold and a material, in that order", function()
		-- gold chance, gold amount (Min == Max, so no integer draw), drop chance, drop amount (none: Min == Max)
		local drops = LootTable.roll(def, items, rules, scripted({ 0.1, 0.1 }), nil)
		assert(#drops == 2, "two drops, got " .. #drops)
		assert(drops[1].gold and drops[1].count == 10, "gold 10")
		assert(drops[2].item == "bone_dust" and drops[2].count == 2, "two bone dust")
	end)

	t.test("depth scales gold only", function()
		local drops = LootTable.roll(def, items, rules, scripted({ 0.1 }), { depth = 5 })
		-- 10 x (1 + 0.15 x 4) = 16
		assert(drops[1].gold and drops[1].count == 16, "gold 16 at depth 5, got " .. tostring(drops[1].count))
	end)

	t.test("the party multiplier scales gold", function()
		local drops = LootTable.roll(def, items, rules, scripted({ 0.1 }), { goldMult = 2 })
		assert(drops[1].count == 20, "gold doubled")
	end)

	t.test("a Sound drop carries its rank", function()
		-- gold miss, drop miss, hallowed miss, sound hit, pick
		local drops = LootTable.roll(def, items, rules, scripted({ 0.9, 0.9, 0.9, 0.05, 0.1 }), nil)
		assert(#drops == 1 and drops[1].item == "tallow" and drops[1].rank == "Sound", "tallow, Sound")
	end)

	t.test("same item twice merges", function()
		local d = {
			Always = { { Item = "bone_dust", Min = 1, Max = 1 } },
			Drops = { { Item = "bone_dust", Chance = 1, Min = 2, Max = 2 } },
		}
		local drops = LootTable.roll(d, items, rules, scripted({}), nil)
		assert(#drops == 1 and drops[1].count == 3, "merged to 3")
	end)

	t.test("pity forces a Sound after the dry spell", function()
		local pity = LootTable.newPity()
		for _ = 1, 3 do
			local drops = LootTable.roll(def, items, rules, scripted({ 0.9, 0.9, 0.9, 0.9 }), { pity = pity })
			assert(#drops == 0, "dry")
		end
		assert(pity.dryS == 3, "three dry kills")
		local drops = LootTable.roll(def, items, rules, scripted({ 0.9, 0.9, 0.9, 0.99 }), { pity = pity })
		assert(#drops == 1 and drops[1].rank == "Sound", "the fourth is forced")
		assert(pity.dryS == 0, "counter reset")
	end)

	t.test("pity upgrades to Hallowed after a long dry spell", function()
		local pity = LootTable.newPity()
		pity.dryS = 3
		pity.dryH = 5
		local drops = LootTable.roll(def, items, rules, scripted({ 0.9, 0.9, 0.9, 0.99 }), { pity = pity })
		assert(#drops == 1 and drops[1].item == "hollow_ember", "upgraded to the ember")
		assert(pity.dryS == 0 and pity.dryH == 0, "both reset")
	end)

	t.test("no pity context means no pity", function()
		local drops = LootTable.roll(def, items, rules, scripted({}), nil)
		assert(#drops == 0, "nothing forced")
	end)

	t.test("guaranteed items always fall", function()
		local d = { Always = { { Item = "hollow_ember", Min = 3, Max = 5 } } }
		local drops = LootTable.roll(d, items, rules, scripted({ 0.5 }), nil)
		assert(#drops == 1 and drops[1].count >= 3 and drops[1].count <= 5, "3 to 5 embers")
	end)
end
