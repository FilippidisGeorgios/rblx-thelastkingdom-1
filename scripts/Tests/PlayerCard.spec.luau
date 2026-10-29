--!strict
--[[
	PlayerCard.spec
	The page of the Muster Roll: level, title and xp, the Might rating (the best weapon, never lowered by
	owning more), what the difficulty does with it (the dead grow by half of the gain, the player keeps an
	edge), the record and the collection, and that the real config gives a title for every level.

	Location: TestService.Tests.PlayerCard.spec
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")

local PlayerCard = require(ServerScriptService.Server.Domain.PlayerCard)
local ProfileSchema = require(ServerScriptService.Server.Domain.ProfileSchema)
local Experience: any = require(ReplicatedStorage.Config.Experience)
local Weapons: any = require(ReplicatedStorage.Config.Weapons)
local Economy: any = require(ReplicatedStorage.Config.Economy)
local ProfileCfg: any = require(ReplicatedStorage.Config.Profile)
local ChapelCfg: any = require(ReplicatedStorage.Config.Chapel)
local Pages: any = require(ReplicatedStorage.Config.Pages)

local ctx: PlayerCard.Context = {
	experience = Experience,
	weapons = Weapons,
	curve = Economy.Upgrades.Weapon,
	profileCfg = ProfileCfg,
	chapel = ChapelCfg,
	pages = Pages,
}

local function fresh(): any
	return ProfileSchema.default()
end

local function near(a: number, b: number): boolean
	return math.abs(a - b) < 1e-6
end

return function(t: any)
	t.test("a new player is a Recruit at level 1 with nothing yet and a Might of 1", function()
		local card = PlayerCard.build(fresh(), ctx)
		assert(card.level == 1 and card.title == ProfileCfg.Titles[1], "level 1, the first title")
		assert(card.xpFraction == 0 and card.xpToNext == Experience.XpToLevel[1], "no xp: the whole first level to go")
		assert(card.might.rating == 1, "a fresh blade rates 1")
		assert(near(card.might.multiplier, 1) and near(card.might.enemyGrowth, 0) and near(card.might.edge, 1), "no gain, no growth, no edge")
		assert(card.record.runsWon == 0 and card.record.runsWiped == 0 and card.record.deeds == 0, "an empty record")
		assert(card.collection.pagesFound == 0 and card.collection.shardsLaid == 0 and not card.collection.starRaised, "nothing collected")
		assert(card.charm == nil, "no charm")
	end)

	t.test("xp is a share of the level being climbed, and the top level has none left to go", function()
		local p = fresh()
		p.level, p.xp = 2, Experience.XpToLevel[2] / 2
		local card = PlayerCard.build(p, ctx)
		assert(near(card.xpFraction, 0.5), "halfway through level 2")
		assert(near(card.xpToNext, Experience.XpToLevel[2] / 2), "half of it to go")
		assert(card.title == ProfileCfg.Titles[2], "the title of level 2")

		p.level, p.xp = Experience.MaxLevel, 50
		local top = PlayerCard.build(p, ctx)
		assert(top.xpFraction == 1 and top.xpToNext == 0, "nothing left to climb")
		assert(top.title == ProfileCfg.Titles[#ProfileCfg.Titles], "the last title")
	end)

	t.test("Might is the best weapon, and owning more never lowers it", function()
		local p = fresh()
		p.upgrades.starter_sword = 6
		local one = PlayerCard.build(p, ctx)
		assert(one.might.rating == 6 and one.might.bestId == "starter_sword", "the +6 sword rates 6")
		p.upgrades.woodsman_axe = 1
		p.upgrades.footman_spear = 2
		local more = PlayerCard.build(p, ctx)
		assert(more.might.rating == 6, "an axe at +1 and a spear at +2 do not lower it")
		p.upgrades.footman_spear = 9
		assert(PlayerCard.build(p, ctx).might.rating == 9, "a better weapon raises it")
	end)

	t.test("a level written by an older build is clamped, never a crash or a rating off the curve", function()
		local p = fresh()
		p.upgrades.starter_sword = 99
		p.upgrades.woodsman_axe = -4
		p.upgrades.footman_spear = "x"
		local card = PlayerCard.build(p, ctx)
		assert(card.might.rating == card.might.maxRating, "clamped to the top of the curve")
		for _, arm in card.arms do
			assert(arm.level >= 1 and arm.level <= arm.maxLevel, arm.id .. " is on the curve")
		end
	end)

	t.test("the dead grow by half of what the player gained, and the player keeps an edge", function()
		local p = fresh()
		p.upgrades.starter_sword = 10
		local card = PlayerCard.build(p, ctx)
		local gain = card.might.multiplier - 1
		assert(gain > 0, "a +10 weapon hits harder")
		assert(near(card.might.enemyGrowth, gain / 2), "half of the gain")
		assert(card.might.edge > 1, "upgrading always leaves the player ahead")
		assert(near(card.might.edge, card.might.multiplier / (1 + card.might.enemyGrowth)), "the edge is what is kept")
	end)

	t.test("a tier name for every rating the curve allows, rising with it", function()
		local seen: { string } = {}
		for level = 1, Economy.Upgrades.Weapon.MaxLevel do
			local p = fresh()
			p.upgrades.starter_sword = level
			local tier = PlayerCard.build(p, ctx).might.tier
			assert(tier ~= "", "level " .. level .. " has a tier")
			if seen[#seen] ~= tier then
				table.insert(seen, tier)
			end
		end
		assert(#seen == #ProfileCfg.MightTiers, "every band is reachable, in order")
		for i, band in ProfileCfg.MightTiers do
			assert(seen[i] == band.id, "band " .. i .. " is " .. band.id)
		end
	end)

	t.test("the best arm is one the player can swing, the same every time", function()
		local card = PlayerCard.build(fresh(), ctx)
		assert(card.might.bestId == "starter_sword", "a new player's best arm is the sword they carry, not a locked spear")
		assert(not card.arms[1].locked, "the arms they can swing are listed first")
		for _ = 1, 5 do
			assert(PlayerCard.build(fresh(), ctx).might.bestId == "starter_sword", "never depends on table order")
		end
	end)

	t.test("arms list a locked weapon as locked, best first", function()
		local p = fresh()
		p.upgrades.starter_sword = 3
		local card = PlayerCard.build(p, ctx)
		assert(card.arms[1].id == "starter_sword", "the +3 sword is first")
		local mace
		for _, arm in card.arms do
			if arm.id == "flanged_mace" then
				mace = arm
			end
		end
		assert(mace and mace.locked and mace.requiredLevel == 8, "the mace waits for level 8")
		p.level = 8
		for _, arm in PlayerCard.build(p, ctx).arms do
			if arm.id == "flanged_mace" then
				assert(not arm.locked, "unlocked at level 8")
			end
		end
	end)

	t.test("the record and the collection count what the profile holds", function()
		local p = fresh()
		p.currency = 340
		p.stats = { runsWon = 3, runsWiped = 2, bestRunGold = 410 }
		p.achievements = { falling_star = true, bell = true, nothing = false }
		p.stash = { bone_dust = 12, star_shard = 2, page_graveyard_bell = 1, rusted_iron = 0 }
		p.altar.offered = 4
		local card = PlayerCard.build(p, ctx)
		assert(card.gold == 340, "the gold held")
		assert(card.record.runsWon == 3 and card.record.runsWiped == 2 and card.record.bestRunGold == 410, "the record")
		assert(card.record.deeds == 2, "only the deeds that are done")
		assert(card.collection.pagesFound == 1, "one page found")
		assert(card.collection.pagesTotal >= 5, "all the pages of the castle")
		assert(card.collection.shardsLaid == 4 and card.collection.shardsGoal == ChapelCfg.Altar.Shards, "four of the shards laid")
		assert(not card.collection.starRaised, "the star is not up")
		assert(card.collection.stashKinds == 3 and card.collection.stashTotal == 15, "what is in the stash, a zero is nothing")
		p.altar.offered = ChapelCfg.Altar.Shards
		assert(PlayerCard.build(p, ctx).collection.starRaised, "the ninth shard raises it")
	end)

	t.test("a charm is shown only while it is still in the stash", function()
		local p = fresh()
		p.loadout.charm = "mourners_veil"
		assert(PlayerCard.build(p, ctx).charm == nil, "worn but not owned: not shown")
		p.stash.mourners_veil = 1
		assert(PlayerCard.build(p, ctx).charm == "mourners_veil", "owned and worn")
	end)

	t.test("the real config: a title for every level, tiers rising and covering the whole curve", function()
		assert(#ProfileCfg.Titles >= Experience.MaxLevel, "a title for each level up to the cap")
		local last = 0
		for _, band in ProfileCfg.MightTiers do
			assert(band.maxRating > last, "bands ascend")
			last = band.maxRating
		end
		assert(last >= Economy.Upgrades.Weapon.MaxLevel, "the last band reaches the top of the curve")
	end)
end
