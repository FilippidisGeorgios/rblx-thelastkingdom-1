--!strict
--[[
	Renown (domain)
	The whole player in one number: rank, might, victories, how deep they have been, deeds, lore, the Falling
	Star and the dead they have slain, each CAPPED so that no one thing can make a standing, with the
	breakdown the player can read (the Muster Roll shows the bars). Pure: the numbers on a card and the
	config in, points out.

	Renown is for standing (the Roll, the train, the admin panel). It sets NOTHING about difficulty: that
	is Might (Domain/TeamPower) alone, so a long history can never make a run harder or easier, and a
	player's loyalty cannot be traded for a fairer fight.

	Location: ServerScriptService.Server.Domain.Renown
]]

local Renown = {}

export type Inputs = {
	level: number,
	might: number,
	runsWon: number,
	deepest: number,
	deeds: number,
	pages: number,
	shards: number,
	starRaised: boolean,
	kills: number,
}

export type Part = { id: string, label: string, points: number, max: number }

export type Result = {
	total: number,
	max: number,
	tier: string,
	nextTier: string?, -- the band above, and how far
	toNext: number?,
	parts: { Part },
}

--[[
	`cfg` is configs/Profile.Renown: { Parts = { { id, Label, Unit, Offset, Per, Cap, Flag?, FlagPoints? } }, Tiers = { { id, maxPoints } } }.
	Points are whole numbers: each part is rounded, then capped.
]]
function Renown.compute(inputs: Inputs, cfg: any): Result
	local parts: { Part } = {}
	local total, max = 0, 0
	for _, def in cfg.Parts do
		local units = math.max(0, ((inputs :: any)[def.Unit] or 0) - (def.Offset or 0))
		local points = math.floor(units * def.Per + 0.5)
		if def.Flag and (inputs :: any)[def.Flag] == true then
			points += def.FlagPoints or 0
		end
		points = math.min(def.Cap, math.max(0, points))
		table.insert(parts, { id = def.id, label = def.Label, points = points, max = def.Cap })
		total += points
		max += def.Cap
	end

	local tier = cfg.Tiers[#cfg.Tiers].id
	local nextTier: string? = nil
	local toNext: number? = nil
	for i, band in cfg.Tiers do
		if total <= band.maxPoints then
			tier = band.id
			local above = cfg.Tiers[i + 1]
			if above then
				nextTier = above.id
				toNext = band.maxPoints - total + 1
			end
			break
		end
	end

	return { total = total, max = max, tier = tier, nextTier = nextTier, toNext = toNext, parts = parts }
end

return Renown
