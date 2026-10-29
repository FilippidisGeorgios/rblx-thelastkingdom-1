--!strict
--[[
	PlayerCard.spec
	The page of the Muster Roll: who the player is (Company number, names), level, rank and xp on the road to
	100, Might (the best weapon, never lowered by owning more), what the difficulty does with it (the dead
	grow by half of the gain, the player keeps an edge), Renown, statistics, the record and the collection,
	the brief the train shows, and that the real config gives a rank for every level.

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
		assert(card.level == 1 and card.title == ProfileCfg.Titles[1].Name, "level 1, the first rank")
		assert(card.xpFraction == 0 and card.xpToNext == Experience.XpToLevel[1], "no xp: the whole first level to go")
		assert(card.totalXp == 0, "nothing earned")
		assert(card.might.rating == 1, "a fresh blade rates 1")
		assert(near(card.might.multiplier, 1) and near(card.might.enemyGrowth, 0) and near(card.might.edge, 1), "no gain, no growth, no edge")
		assert(card.record.runsWon == 0 and card.record.runsWiped == 0 and card.record.deeds == 0, "an empty record")
		assert(card.collection.pagesFound == 0 and card.collection.shardsLaid == 0 and not card.collection.starRaised, "nothing collected")
		assert(card.charm == nil, "no charm")
		assert(card.renown.total >= 0 and card.renown.tier == ProfileCfg.Renown.Tiers[1].id, "an unknown name")
		assert(card.stats.winRate == nil and card.stats.fastestWinSeconds == nil, "no runs, no rate, no fastest")
	end)

	t.test("who they are: the Company number, the nickname, the account name", function()
		local p = fresh()
		ProfileSchema.stamp(p, { userId = 1234567, name = "Cookies11f", displayName = "Cookie" }, 1000)
		local card = PlayerCard.build(p, ctx)
		assert(card.account.userId == 1234567, "the user id")
		assert(card.account.name == "Cookies11f" and card.account.displayName == "Cookie", "the names")
		assert(card.account.id:sub(1, 4) == "TLK-" and #card.account.id > 10, "a Company number")
		-- a profile that was never stamped still shows a number when the user id is known
		local q = fresh()
		q.account.userId = 42
		assert(PlayerCard.build(q, ctx).account.id:sub(1, 4) == "TLK-", "made from the user id")
		-- and with nothing at all it shows blanks, not an error
		local empty = PlayerCard.build(fresh(), ctx)
		assert(empty.account.id == "" and empty.account.name == "", "blank, not a crash")
	end)

	t.test("xp is a share of the level being climbed, and the top level has none left to go", function()
		local p = fresh()
		p.level, p.xp = 2, Experience.XpToLevel[2] / 2
		local card = PlayerCard.build(p, ctx)
		assert(near(card.xpFraction, 0.5), "halfway through level 2")
		assert(near(card.xpToNext, Experience.XpToLevel[2] / 2), "half of it to go")
		assert(near(card.totalXp, Experience.XpToLevel[1] + Experience.XpToLevel[2] / 2), "all the xp earned from level 1")

		p.level, p.xp = Experience.MaxLevel, 50
		local top = PlayerCard.build(p, ctx)
		assert(top.level == 100 and top.xpFraction == 1 and top.xpToNext == 0, "nothing left to climb at level 100")
		assert(top.title == ProfileCfg.Titles[#ProfileCfg.Titles].Name, "the last rank")
		assert(top.nextReward == nil and top.nextTitle == nil, "no prize or rank above the top")
	end)

	t.test("the rank changes at every tenth level and the next one is told", function()
		local p = fresh()
		p.level = 9
		local nine = PlayerCard.build(p, ctx)
		assert(nine.title == "Recruit" and nine.nextTitle ~= nil and nine.nextTitle.level == 10, "still a recruit at 9, a rank at 10")
		p.level = 10
		local ten = PlayerCard.build(p, ctx)
		assert(ten.title == "Footman" and ten.nextTitle ~= nil and ten.nextTitle.level == 20, "a footman at 10")
		p.level = 99
		assert(PlayerCard.build(p, ctx).title == "Lord Marshal", "the rank below the top at 99")
	end)

	t.test("the road: a prize every fifth level, the next one and how far", function()
		local p = fresh()
		p.level = 7
		local card = PlayerCard.build(p, ctx)
		assert(card.nextReward ~= nil and card.nextReward.level == 10 and card.nextReward.away == 3, "level 10 is three away")
		assert(#card.road == 20, "twenty stops from 5 to 100")
		assert(card.road[1].level == 5 and card.road[1].reached and not card.road[1].milestone, "5 is reached and small")
		assert(card.road[2].level == 10 and not card.road[2].reached and card.road[2].milestone, "10 is ahead and big")
		p.level = 5
		assert(PlayerCard.build(p, ctx).nextReward.level == 10, "standing on a prize level, the next is the one above")
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
		p.level = 9
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

	t.test("the record and the statistics count what the profile holds; only deeds are deeds", function()
		local p = fresh()
		p.currency = 340
		p.stats = {
			runsWon = 3,
			runsWiped = 1,
			bestRunGold = 410,
			kills = 250,
			eliteKills = 12,
			bossKills = 1,
			damageDealt = 9000,
			downs = 5,
			chambersCleared = 20,
			deepestChamber = 7,
			playSeconds = 7200,
			fastestWinSeconds = 2400,
			goldBanked = 1500,
		}
		p.achievements = { deed_bell = true, deed_mangonel = true, falling_star = true, deed_missed = false }
		local card = PlayerCard.build(p, ctx)
		assert(card.gold == 340, "the gold held")
		assert(card.record.runsWon == 3 and card.record.runsWiped == 1 and card.record.bestRunGold == 410, "the record")
		assert(card.record.deeds == 2, "two deeds done; the star and a deed not done are not counted")
		assert(card.stats.kills == 250 and card.stats.eliteKills == 12 and card.stats.bossKills == 1, "the dead slain")
		assert(card.stats.damageDealt == 9000 and card.stats.downs == 5, "damage and falls")
		assert(card.stats.chambersCleared == 20 and card.stats.deepestChamber == 7, "chambers")
		assert(card.stats.playSeconds == 7200 and card.stats.fastestWinSeconds == 2400, "time")
		assert(card.stats.goldBanked == 1500, "gold brought home")
		assert(near(card.stats.winRate :: number, 0.75), "three of four runs won")
	end)

	t.test("the collection counts the pages, the shards and the stash", function()
		local p = fresh()
		p.stash = { bone_dust = 12, star_shard = 2, page_graveyard_bell = 1, rusted_iron = 0 }
		p.altar.offered = 4
		local card = PlayerCard.build(p, ctx)
		assert(card.collection.pagesFound == 1, "one page found")
		assert(card.collection.pagesTotal >= 5, "all the pages of the castle")
		assert(card.collection.shardsLaid == 4 and card.collection.shardsGoal == ChapelCfg.Altar.Shards, "four of the shards laid")
		assert(not card.collection.starRaised, "the star is not up")
		assert(card.collection.stashKinds == 3 and card.collection.stashTotal == 15, "what is in the stash, a zero is nothing")
		p.altar.offered = ChapelCfg.Altar.Shards
		assert(PlayerCard.build(p, ctx).collection.starRaised, "the ninth shard raises it")
	end)

	t.test("Renown rises with the player and is capped, and the card carries its parts", function()
		local card = PlayerCard.build(fresh(), ctx)
		assert(#card.renown.parts == #ProfileCfg.Renown.Parts, "every part is shown")
		local p = fresh()
		p.level = 50
		p.upgrades.starter_sword = 8
		p.stats = { runsWon = 10, deepestChamber = 5, kills = 4000 }
		local richer = PlayerCard.build(p, ctx)
		assert(richer.renown.total > card.renown.total, "a longer history is a bigger name")
		for _, part in richer.renown.parts do
			assert(part.points <= part.max, part.id .. " is under its ceiling")
		end
		-- grinding kills for ever cannot make a name
		p.stats = { kills = 10 ^ 9 }
		local grind = PlayerCard.build(p, ctx)
		local slaying
		for _, part in grind.renown.parts do
			if part.id == "slaying" then
				slaying = part
			end
		end
		assert(slaying and slaying.points == slaying.max, "a billion kills stop at the ceiling")
	end)

	t.test("a charm is shown only while it is still in the stash", function()
		local p = fresh()
		p.loadout.charm = "mourners_veil"
		assert(PlayerCard.build(p, ctx).charm == nil, "worn but not owned: not shown")
		p.stash.mourners_veil = 1
		assert(PlayerCard.build(p, ctx).charm == "mourners_veil", "owned and worn")
	end)

	t.test("the brief for the train: name, level, rank, Might, Renown", function()
		local p = fresh()
		ProfileSchema.stamp(p, { userId = 99, name = "Name", displayName = "Nick" }, 1)
		p.level = 12
		p.upgrades.starter_sword = 4
		local brief = PlayerCard.brief(PlayerCard.build(p, ctx))
		assert(brief.name == "Nick" and brief.level == 12 and brief.might == 4, "the numbers")
		assert(brief.title == "Footman", "the rank of level 12")
		assert(brief.renownTier ~= "" and brief.renown > 0, "a standing")
		local anon = PlayerCard.brief(PlayerCard.build(fresh(), ctx))
		assert(anon.level == 1, "an unstamped profile still has a brief")
	end)

	t.test("the real config: a rank for every level, tiers rising and covering the whole curve", function()
		assert(ProfileCfg.Titles[1].Level == 1, "the first rank starts at level 1")
		local last = 0
		for _, entry in ProfileCfg.Titles do
			assert(entry.Level > last or entry.Level == 1, "ranks ascend")
			last = entry.Level
		end
		assert(last == Experience.MaxLevel, "the last rank is the top level")
		last = 0
		for _, band in ProfileCfg.MightTiers do
			assert(band.maxRating > last, "bands ascend")
			last = band.maxRating
		end
		assert(last >= Economy.Upgrades.Weapon.MaxLevel, "the last band reaches the top of the curve")
	end)
end
