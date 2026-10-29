--!strict
--[[
	PlayerCard (domain)
	The page of the MUSTER ROLL for one player, built from their profile: level and title, Might (the
	rating that sets how hard their runs are), their arms, their record and their collection. PURE: a
	profile and the config tables go in, a plain table comes out, so it is unit-tested and the server
	can send it as it is.

	MIGHT is Server/Domain/TeamPower's rating. A player is rated by the best weapon they own
	(`playerRating`, "Best": buying another weapon can never lower it), a party by the average of its
	members, and the dead grow by HALF of what the party gained. The card shows the player's own numbers
	for that rule: how much harder they hit than a fresh blade, how much the dead grow because of it, and
	the edge they keep. Nothing is invented here: change the forge's curve and the card follows.

	Nothing on the card is secret or shared: it is built from one player's own profile.

	Location: ServerScriptService.Server.Domain.PlayerCard
]]

local TeamPower = require(script.Parent.TeamPower)
local Chapel = require(script.Parent.Chapel)

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
	level: number,
	maxLevel: number,
	title: string,
	xp: number,
	xpToNext: number,
	xpFraction: number,
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
	arms: { Arm },
	record: { runsWon: number, runsWiped: number, bestRunGold: number, deeds: number },
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

local function levelOf(profile: any, weaponId: string, maxLevel: number): number
	local stored = profile.upgrades and profile.upgrades[weaponId]
	if type(stored) ~= "number" then
		return 1
	end
	return math.clamp(math.floor(stored), 1, maxLevel)
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

	local titles = ctx.profileCfg.Titles
	local title = titles[math.clamp(level, 1, #titles)]

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

	-- the record
	local stats = profile.stats or {}
	local deeds = 0
	for _, done in profile.achievements or {} do
		if done == true then
			deeds += 1
		end
	end

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

	local worn = profile.loadout and profile.loadout.charm
	if worn and ((profile.stash and profile.stash[worn]) or 0) < 1 then
		worn = nil
	end

	return {
		level = level,
		maxLevel = maxLevel,
		title = title,
		xp = xp,
		xpToNext = xpToNext,
		xpFraction = xpFraction,
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
		arms = arms,
		record = {
			runsWon = stats.runsWon or 0,
			runsWiped = stats.runsWiped or 0,
			bestRunGold = stats.bestRunGold or 0,
			deeds = deeds,
		},
		collection = {
			pagesFound = pagesFound,
			pagesTotal = #entries,
			shardsLaid = math.min((profile.altar and profile.altar.offered) or 0, ctx.chapel.Altar.Shards),
			shardsGoal = ctx.chapel.Altar.Shards,
			starRaised = ((profile.altar and profile.altar.offered) or 0) >= ctx.chapel.Altar.Shards,
			stashKinds = stashKinds,
			stashTotal = stashTotal,
		},
		charm = worn,
	}
end

return PlayerCard
