--!strict
--[[
	PlayerCard (domain)
	The page of the MUSTER ROLL for one player, built from their profile: who they are (the Company number,
	the names), their level on the road to 100 with its prizes, Might (the rating that sets how hard their runs
	are), Renown (the whole player in one number, with its breakdown), their arms, their statistics and their
	collection. PURE: a profile and the config tables go in, a plain table comes out, so it is unit-tested and
	the server can send it as it is.

	MIGHT is Server/Domain/TeamPower's rating. A player is rated by the best weapon they own
	(`playerRating`, "Best": buying another weapon can never lower it), a party by the average of its
	members, and the dead grow by HALF of what the party gained. The card shows the player's own numbers
	for that rule: how much harder they hit than a fresh blade, how much the dead grow because of it, and
	the edge they keep. RENOWN is Domain/Renown's: it sets nothing about difficulty. Nothing is invented
	here: change a curve or a config and the card follows.

	Nothing on the card is secret or shared: it is built from one player's own profile.

	Location: ServerScriptService.Server.Domain.PlayerCard
]]

local TeamPower = require(script.Parent.TeamPower)
local Chapel = require(script.Parent.Chapel)
local LevelMilestones = require(script.Parent.LevelMilestones)
local PlayerId = require(script.Parent.PlayerId)
local Renown = require(script.Parent.Renown)

local PlayerCard = {}

export type Context = {
	experience: any, -- configs/Experience
	weapons: any, -- configs/Weapons
	curve: any, -- configs/Economy.Upgrades.Weapon
	profileCfg: any, -- configs/Profile
	chapel: any, -- configs/Chapel
	pages: any, -- configs/Pages
}

export type Arm = {
	id: string,
	name: string,
	class: string,
	level: number,
	maxLevel: number,
	locked: boolean,
	requiredLevel: number,
}

export type Card = {
	account: { id: string, userId: number, name: string, displayName: string },
	level: number,
	maxLevel: number,
	title: string,
	nextTitle: { name: string, level: number }?, -- the next rank and the level that brings it
	xp: number,
	xpToNext: number,
	xpFraction: number,
	totalXp: number, -- everything earned, from level 1
	nextReward: { level: number, away: number }?,
	road: { LevelMilestones.Stop },
	gold: number,
	might: {
		rating: number,
		maxRating: number,
		tier: string,
		multiplier: number, -- how hard they hit, against a fresh blade (1.33 = a third harder)
		enemyGrowth: number, -- what the dead gain because of it, as a fraction (0.165)
		edge: number, -- what they keep after that (1.14)
		bestId: string?,
	},
	renown: Renown.Result,
	arms: { Arm },
	record: { runsWon: number, runsWiped: number, bestRunGold: number, deeds: number },
	stats: {
		kills: number,
		eliteKills: number,
		bossKills: number,
		damageDealt: number,
		downs: number,
		chambersCleared: number,
		deepestChamber: number,
		playSeconds: number,
		fastestWinSeconds: number?,
		goldBanked: number,
		assists: number,
		revives: number,
		winRate: number?, -- a fraction of the runs that ended; nil before the first
	},
	collection: {
		pagesFound: number,
		pagesTotal: number,
		shardsLaid: number,
		shardsGoal: number,
		starRaised: boolean,
		stashKinds: number,
		stashTotal: number,
	},
	charm: string?,
}

-- What the train shows beside a name: small enough to send often.
export type Brief = { name: string, level: number, title: string, might: number, renownTier: string, renown: number }

local function levelOf(profile: any, weaponId: string, maxLevel: number): number
	local stored = profile.upgrades and profile.upgrades[weaponId]
	if type(stored) ~= "number" then
		return 1
	end
	return math.clamp(math.floor(stored), 1, maxLevel)
end

-- The rank at `level`: the last entry of `titles` whose Level it has reached.
function PlayerCard.titleFor(level: number, titles: { { Level: number, Name: string } }): string
	local name = titles[1].Name
	for _, entry in titles do
		if level >= entry.Level then
			name = entry.Name
		end
	end
	return name
end

-- The next rank above `level`, and the level at which it comes; nil at the top.
function PlayerCard.nextTitleFor(level: number, titles: { { Level: number, Name: string } }): { name: string, level: number }?
	for _, entry in titles do
		if entry.Level > level then
			return { name = entry.Name, level = entry.Level }
		end
	end
	return nil
end

function PlayerCard.build(profile: any, ctx: Context): Card
	local exp = ctx.experience
	local maxLevel = exp.MaxLevel or (#exp.XpToLevel + 1)
	local level = math.clamp(profile.level or 1, 1, maxLevel)
	local xp = math.max(0, profile.xp or 0)

	local threshold = exp.XpToLevel[level]
	local xpToNext, xpFraction = 0, 1
	if level < maxLevel and threshold then
		xpToNext = math.max(0, threshold - xp)
		xpFraction = math.clamp(xp / threshold, 0, 1)
	end
	local totalXp = xp
	for l = 1, level - 1 do
		totalXp += exp.XpToLevel[l] or 0
	end

	local titles = ctx.profileCfg.Titles
	local title = PlayerCard.titleFor(level, titles)
	local nextTitle = PlayerCard.nextTitleFor(level, titles)

	-- the road to the top: a prize every few levels, a milestone every tenth
	local rules = exp.Milestones
	local nextLevel = LevelMilestones.nextRewardLevel(level, maxLevel, rules)
	local nextReward = if nextLevel then { level = nextLevel, away = nextLevel - level } else nil
	local road = LevelMilestones.road(level, maxLevel, rules, exp.LevelRewards)

	-- arms, and the rating they make
	local curveTop = math.min(ctx.curve.MaxLevel or #ctx.curve.Levels, #ctx.curve.Levels)
	local arms: { Arm } = {}
	local levels: { number } = {}
	for id, weapon in ctx.weapons do
		local lvl = levelOf(profile, id, curveTop)
		local required = (weapon.Requirements and weapon.Requirements.level) or 0
		table.insert(levels, lvl)
		table.insert(arms, {
			id = id,
			name = weapon.DisplayName or id,
			class = weapon.Class or "Melee",
			level = lvl,
			maxLevel = curveTop,
			locked = level < required,
			requiredLevel = required,
		})
	end
	-- the ones they can swing first, then the best forged, then by name (so the order never wobbles)
	table.sort(arms, function(a, b)
		if a.locked ~= b.locked then
			return not a.locked
		end
		if a.level ~= b.level then
			return a.level > b.level
		end
		return a.name < b.name
	end)
	local bestId: string? = nil
	for _, arm in arms do
		if not arm.locked then
			bestId = arm.id
			break
		end
	end

	local rating = TeamPower.playerRating(levels, "Best")
	local multiplier = TeamPower.multiplierFor(ctx.curve, rating)
	local enemyGrowth = TeamPower.enemyScale(ctx.curve, rating) - 1
	local edge = TeamPower.netAdvantage(ctx.curve, rating)
	local tier = TeamPower.tierFor(rating, ctx.profileCfg.MightTiers) or ""

	-- the record and the statistics
	local stats = profile.stats or {}
	local deeds = 0
	for id, done in profile.achievements or {} do
		if done == true and string.sub(id, 1, 5) == "deed_" then
			deeds += 1
		end
	end
	local runsWon, runsWiped = stats.runsWon or 0, stats.runsWiped or 0
	local ended = runsWon + runsWiped

	-- the collection
	local pagesFound = 0
	local entries = Chapel.journal(profile, ctx.pages)
	for _, entry in entries do
		if entry.found then
			pagesFound += 1
		end
	end
	local stashKinds, stashTotal = 0, 0
	for _, n in profile.stash or {} do
		if type(n) == "number" and n > 0 then
			stashKinds += 1
			stashTotal += n
		end
	end
	local offered = (profile.altar and profile.altar.offered) or 0
	local shardsLaid = math.min(offered, ctx.chapel.Altar.Shards)
	local starRaised = offered >= ctx.chapel.Altar.Shards

	local worn = profile.loadout and profile.loadout.charm
	if worn and ((profile.stash and profile.stash[worn]) or 0) < 1 then
		worn = nil
	end

	-- who they are
	local account = profile.account or {}
	local userId = account.userId or 0
	local id = account.id or (if userId > 0 then PlayerId.forUser(userId) else nil) or ""

	local renown = Renown.compute({
		level = level,
		might = rating,
		runsWon = runsWon,
		deepest = stats.deepestChamber or 0,
		deeds = deeds,
		pages = pagesFound,
		shards = shardsLaid,
		starRaised = starRaised,
		kills = stats.kills or 0,
	}, ctx.profileCfg.Renown)

	return {
		account = {
			id = id,
			userId = userId,
			name = account.name or "",
			displayName = account.displayName or account.name or "",
		},
		level = level,
		maxLevel = maxLevel,
		title = title,
		nextTitle = nextTitle,
		xp = xp,
		xpToNext = xpToNext,
		xpFraction = xpFraction,
		totalXp = totalXp,
		nextReward = nextReward,
		road = road,
		gold = profile.currency or 0,
		might = {
			rating = rating,
			maxRating = curveTop,
			tier = tier,
			multiplier = multiplier,
			enemyGrowth = enemyGrowth,
			edge = edge,
			bestId = bestId,
		},
		renown = renown,
		arms = arms,
		record = {
			runsWon = runsWon,
			runsWiped = runsWiped,
			bestRunGold = stats.bestRunGold or 0,
			deeds = deeds,
		},
		stats = {
			kills = stats.kills or 0,
			eliteKills = stats.eliteKills or 0,
			bossKills = stats.bossKills or 0,
			damageDealt = stats.damageDealt or 0,
			downs = stats.downs or 0,
			chambersCleared = stats.chambersCleared or 0,
			deepestChamber = stats.deepestChamber or 0,
			playSeconds = stats.playSeconds or 0,
			fastestWinSeconds = stats.fastestWinSeconds,
			goldBanked = stats.goldBanked or 0,
			assists = stats.assists or 0,
			revives = stats.revives or 0,
			winRate = if ended > 0 then runsWon / ended else nil,
		},
		collection = {
			pagesFound = pagesFound,
			pagesTotal = #entries,
			shardsLaid = shardsLaid,
			shardsGoal = ctx.chapel.Altar.Shards,
			starRaised = starRaised,
			stashKinds = stashKinds,
			stashTotal = stashTotal,
		},
		charm = worn,
	}
end

-- A card cut down to what the train shows beside a name.
function PlayerCard.brief(card: Card): Brief
	return {
		name = if card.account.displayName ~= "" then card.account.displayName else card.account.name,
		level = card.level,
		title = card.title,
		might = card.might.rating,
		renownTier = card.renown.tier,
		renown = card.renown.total,
	}
end

return PlayerCard
