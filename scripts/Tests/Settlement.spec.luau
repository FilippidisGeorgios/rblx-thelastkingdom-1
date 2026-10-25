--!strict
--[[
	Settlement.spec
	What a run is worth: a won run banks the whole pack and pays the prisoner's bonus;
	a wiped run keeps a quarter of the gold and only the story things; quest items are
	never banked; the profile ends up with the stash and the counts.

	Location: TestService.Tests.Settlement.spec
]]

local ServerScriptService = game:GetService("ServerScriptService")
local Backpack = require(ServerScriptService.Server.Domain.Backpack)
local Settlement = require(ServerScriptService.Server.Domain.Settlement)
local ProfileSchema = require(ServerScriptService.Server.Domain.ProfileSchema)

local items = {
	bone_dust = { Category = "Resource", Stackable = true, MaxStack = 99 },
	saints_medal = { Category = "Relic", Stackable = false },
	star_shard = { Category = "Relic", Stackable = true, MaxStack = 9 },
	page_marta = { Category = "Story", Stackable = false },
	torch = { Category = "QuestItem", Stackable = false, Banked = false },
}

local rules = { keepFraction = 0.25, bonus = 0.05 }

local function fullPack()
	local bp = Backpack.new(items, 16)
	bp:addGold(200)
	bp:add("bone_dust", 12)
	bp:add("saints_medal", 1)
	bp:add("star_shard", 2)
	bp:add("page_marta", 1)
	bp:add("torch", 1)
	return bp
end

return function(t: any)
	t.test("a won run banks the whole pack but not the quest items", function()
		local ledger = Settlement.compute(fullPack(), "won", rules, false)
		assert(ledger.gold == 200 and ledger.bonusGold == 0 and ledger.lostGold == 0, "all the gold, no bonus")
		assert(ledger.items.bone_dust == 12 and ledger.items.saints_medal == 1, "materials and relics banked")
		assert(ledger.items.star_shard == 2 and ledger.items.page_marta == 1, "story things banked")
		assert(ledger.items.torch == nil, "a torch is not banked")
	end)

	t.test("a prisoner alive at the end adds five percent of the gold on a won run", function()
		local ledger = Settlement.compute(fullPack(), "won", rules, true)
		assert(ledger.bonusGold == 10, "5% of 200")
		local lost = Settlement.compute(fullPack(), "won", rules, false)
		assert(lost.bonusGold == 0, "no prisoner, no bonus")
	end)

	t.test("a wiped run keeps a quarter of the gold and only the story things", function()
		local ledger = Settlement.compute(fullPack(), "wiped", rules, true)
		assert(ledger.gold == 50 and ledger.lostGold == 150, "a quarter kept")
		assert(ledger.bonusGold == 0, "no bonus on a wiped run, prisoner or not")
		assert(ledger.items.star_shard == 2 and ledger.items.page_marta == 1, "shards and pages are never lost")
		assert(ledger.items.bone_dust == nil and ledger.items.saints_medal == nil, "the rest is lost")
	end)

	t.test("gold is whole: a quarter of seven is one", function()
		local bp = Backpack.new(items, 4)
		bp:addGold(7)
		local ledger = Settlement.compute(bp, "wiped", rules, false)
		assert(ledger.gold == 1 and ledger.lostGold == 6, "floor")
	end)

	t.test("apply puts the ledger in the profile: currency, stash, counts", function()
		local profile = ProfileSchema.default()
		profile.currency = 100
		local ledger = Settlement.compute(fullPack(), "won", rules, true)
		local total = Settlement.apply(profile :: any, ledger)
		assert(total == 310 and profile.currency == 310, "100 + 200 + 10")
		assert(profile.stash.bone_dust == 12, "stash holds counts")
		assert(profile.stats.runsWon == 1 and profile.stats.bestRunGold == 210, "the run is counted")
		Settlement.apply(profile :: any, Settlement.compute(fullPack(), "won", rules, false))
		assert(profile.stash.bone_dust == 24, "the stash accumulates across runs")
		assert(profile.stats.runsWon == 2, "two runs won")
	end)

	t.test("a v2 profile migrates to v3 with an empty stash", function()
		local old: any = { version = 2, currency = 5, xp = 1, level = 1, inventory = {}, upgrades = {}, stats = {}, unlockedLore = {}, achievements = {} }
		local migrated = ProfileSchema.migrate(old)
		assert(migrated.version == ProfileSchema.VERSION and ProfileSchema.VERSION >= 3, "v3 or later")
		assert(type((migrated :: any).stash) == "table" and next((migrated :: any).stash) == nil, "an empty stash")
		assert(migrated.currency == 5, "data preserved")
	end)
end
