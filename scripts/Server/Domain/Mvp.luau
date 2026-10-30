--!strict
--[[
	Mvp (domain)
	The ROLL OF HONOUR on the closing card of a won run: everyone who went up the keep, in order of what they
	did. Pure: each player's record and the weights (configs/Experience.Mvp) in, a ranked list out.

	  score  = the dead by tier (Standard 1, Elite 5, Boss 30)
	           + assists x 0.5 + fallen friends raised x 15 + damage x 0.01

	Nothing here punishes: falling does not count against anyone, and a player who did little simply stands lower.
	Ties go to the one who dealt more damage, then by name, so the order never flickers. The first place carries
	the laurel only when the run had two or more players AND they did something; alone, you are shown your own tally.

	Location: ServerScriptService.Server.Domain.Mvp
]]

local Mvp = {}

export type Entry = {
	userId: number,
	name: string,
	kills: { [string]: number },
	damage: number,
	assists: number,
	revives: number,
}

export type Weights = {
	Kill: { [string]: number },
	Assist: number,
	Revive: number,
	Damage: number,
}

export type Row = {
	userId: number,
	name: string,
	rank: number,
	score: number,
	share: number, -- of the best score, 0..1, for a thin bar
	mvp: boolean,
	slain: number,
	assists: number,
	revives: number,
	damage: number,
	line: string, -- "42 slain  ·  6 assists  ·  2 raised"
}

local function round1(x: number): number
	return math.floor(x * 10 + 0.5) / 10
end

function Mvp.score(entry: Entry, weights: Weights): number
	local total = 0
	for tier, count in entry.kills do
		total += math.max(0, count) * (weights.Kill[tier] or 0)
	end
	total += math.max(0, entry.assists) * weights.Assist
	total += math.max(0, entry.revives) * weights.Revive
	total += math.max(0, entry.damage) * weights.Damage
	return total
end

local function slainOf(entry: Entry): number
	local n = 0
	for _, count in entry.kills do
		n += math.max(0, count)
	end
	return n
end

-- The small line under a name: only what is non-zero, in the order a player would care.
local function lineOf(slain: number, assists: number, revives: number): string
	local parts: { string } = {}
	table.insert(parts, ("%d slain"):format(slain))
	if assists > 0 then
		table.insert(parts, ("%d %s"):format(assists, if assists == 1 then "assist" else "assists"))
	end
	if revives > 0 then
		table.insert(parts, ("%d raised"):format(revives))
	end
	return table.concat(parts, "  ·  ")
end

function Mvp.rank(entries: { Entry }, weights: Weights): { Row }
	local rows: { Row } = {}
	for _, entry in entries do
		local slain = slainOf(entry)
		table.insert(rows, {
			userId = entry.userId,
			name = entry.name,
			rank = 0,
			score = round1(Mvp.score(entry, weights)),
			share = 0,
			mvp = false,
			slain = slain,
			assists = math.max(0, entry.assists),
			revives = math.max(0, entry.revives),
			damage = math.floor(math.max(0, entry.damage)),
			line = lineOf(slain, math.max(0, entry.assists), math.max(0, entry.revives)),
		})
	end

	table.sort(rows, function(a, b)
		if a.score ~= b.score then
			return a.score > b.score
		end
		if a.damage ~= b.damage then
			return a.damage > b.damage
		end
		return a.name < b.name
	end)

	local best = if #rows > 0 then rows[1].score else 0
	for index, row in rows do
		row.rank = index
		row.share = if best > 0 then row.score / best else 0
	end
	if #rows >= 2 and best > 0 then
		rows[1].mvp = true
	end
	return rows
end

return Mvp
