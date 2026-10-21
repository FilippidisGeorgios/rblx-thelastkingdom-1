--!strict
--[[
	Backpack.spec
	Slots, stack caps, gold, quest items and what survives a run.

	Location: TestService.Tests.Backpack.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local Backpack = require(ServerScriptService.Server.Domain.Backpack)

local items = {
	bone_dust = { Category = "Resource", Stackable = true, MaxStack = 5 },
	tallow = { Category = "Resource", Stackable = true, MaxStack = 99 },
	saints_medal = { Category = "Relic", Stackable = false },
	star_shard = { Category = "Relic", Stackable = true, MaxStack = 9 },
	torch = { Category = "QuestItem", Stackable = false, Banked = false },
}

return function(t: any)
	t.test("an add stacks up to its cap", function()
		local bp = Backpack.new(items, 4)
		assert(bp:add("bone_dust", 3) == 3, "3 fit")
		assert(bp:add("bone_dust", 4) == 2, "only 2 more fit under 5")
		assert(bp:count("bone_dust") == 5, "5 held")
		assert(bp:slotsUsed() == 1, "one slot")
	end)

	t.test("a full pack refuses a new kind but takes more of an old one", function()
		local bp = Backpack.new(items, 2)
		bp:add("bone_dust", 1)
		bp:add("tallow", 1)
		assert(bp:add("saints_medal", 1) == 0, "no slot for a third kind")
		assert(bp:add("tallow", 5) == 5, "an existing stack still grows")
	end)

	t.test("an unstackable item is one", function()
		local bp = Backpack.new(items, 4)
		assert(bp:add("saints_medal", 1) == 1, "first fits")
		assert(bp:add("saints_medal", 1) == 0, "second does not")
	end)

	t.test("remove is all or nothing", function()
		local bp = Backpack.new(items, 4)
		bp:add("tallow", 3)
		assert(not bp:remove("tallow", 4), "cannot remove more than held")
		assert(bp:count("tallow") == 3, "unchanged")
		assert(bp:remove("tallow", 3), "removes exactly")
		assert(bp:slotsUsed() == 0, "the slot is freed")
	end)

	t.test("gold is a counter, takes no slot, and cannot overdraw", function()
		local bp = Backpack.new(items, 1)
		bp:addGold(40)
		assert(bp.gold == 40 and bp:slotsUsed() == 0, "40 gold, no slot")
		assert(not bp:spendGold(41), "cannot overspend")
		assert(bp:spendGold(15) and bp.gold == 25, "15 spent")
	end)

	t.test("quest items are carried: no slot, never banked", function()
		local bp = Backpack.new(items, 1)
		bp:add("tallow", 1)
		assert(bp:add("torch", 1) == 1, "a torch goes in hands even when the pack is full")
		assert(bp:slotsUsed() == 1, "the slot count is untouched")
		local banked = bp:bankable()
		assert(banked.tallow == 1 and banked.torch == nil, "tallow banks, torch does not")
		bp:clearCarried()
		assert(bp:count("torch") == 0, "hands emptied")
	end)

	t.test("a wiped run keeps only the story", function()
		local bp = Backpack.new(items, 4)
		bp:add("tallow", 4)
		bp:add("star_shard", 2)
		local kept = bp:bankable(true)
		assert(kept.star_shard == 2 and kept.tallow == nil, "shards only")
	end)
end
