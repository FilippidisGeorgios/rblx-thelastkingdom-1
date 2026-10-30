--!strict
--[[
	Danger (shared, pure)
	How much harder a run is than its bare numbers say, as ONE figure from 0 to 100 that the train shows
	("+34 of 100 harder") and the run's enemies are scaled by. It adds two things to the party size and the
	depth that `Scaling` already knows:

	  THE MODE      Hard adds points. A party of five or more IS Hard (a big party cannot play Normal); a smaller
	                one may choose Hard.
	  THE VETERANS  the average level of the party, level 1 being nothing and the top level being `LevelPoints`.

	THE SHIELD stops new players being buried by their friends' levels. Sort the party by level: the THIRD
	weakest decides. If that player is a rookie (level 5 or less) only `Keep` of the veterans' points count; the
	shield fades out as that third player climbs to `FreeFrom`; from there the average counts in full. A party
	of fewer than three has no shield (two level-0 players in a party of veterans take the average).

	No Roblox API and no config reads: the rules come in as a table (configs/Difficulty.Danger), so the whole
	contract is unit-tested (Danger.spec) and the client can show the same figure the server will use.

	Location: ReplicatedStorage.Shared.Danger
]]

local Danger = {}

export type Shield = { Need: number, RookieBelow: number, FreeFrom: number, Keep: number }

export type Rules = {
	Max: number,
	MaxLevel: number,
	LevelPoints: number,
	Mode: { [string]: number },
	Shield: Shield,
	AtFull: { EnemyHealth: number, EnemyCount: number, Elite: number, Reward: number },
}

export type Breakdown = {
	total: number, -- 0..Max, what the train shows and the run uses
	mode: number, -- the points the mode added
	veteran: number, -- the points the levels added, after the shield
	avgLevel: number,
	keep: number, -- the share of the veterans' points that counted (1 = no shield)
	shielded: boolean, -- true when the shield took something away
	tier: string,
}

export type Multipliers = {
	enemyCountMult: number,
	enemyHealthMult: number,
	eliteWeight: number,
	rewardMult: number,
}

local function round1(x: number): number
	return math.floor(x * 10 + 0.5) / 10
end

local function clean(levels: { number }, maxLevel: number): { number }
	local out: { number } = {}
	for _, level in levels do
		table.insert(out, math.clamp(math.floor(level), 1, maxLevel))
	end
	return out
end

function Danger.average(levels: { number }): number
	if #levels == 0 then
		return 1
	end
	local total = 0
	for _, level in levels do
		total += level
	end
	return total / #levels
end

--[[
	The share (0..1) of the veterans' points that count for this party. 1 means free; `Keep` is the floor.
]]
function Danger.keep(levels: { number }, shield: Shield): number
	if #levels < shield.Need then
		return 1
	end
	local sorted = table.clone(levels)
	table.sort(sorted)
	local third = sorted[shield.Need]
	local span = math.max(shield.FreeFrom - shield.RookieBelow, 1)
	local fade = math.clamp((third - shield.RookieBelow) / span, 0, 1)
	return shield.Keep + (1 - shield.Keep) * fade
end

--[[
	Which mode a party plays, and whether Normal is closed to it. `count` is how many are aboard (or the size
	being called); a party bigger than the Normal tier holds is Hard, locked. A smaller one plays what it chose.
	`tiers` is configs/Difficulty.Tiers: ascending, the first is Normal.
]]
function Danger.modeFor(count: number, wantsHard: boolean, tiers: { { id: string, maxPlayers: number } }): (string, boolean)
	local normal = tiers[1]
	local hard = tiers[#tiers]
	local locked = count > normal.maxPlayers
	if locked or wantsHard then
		return hard.id, locked
	end
	return normal.id, false
end

function Danger.compute(levels: { number }, tier: string, rules: Rules): Breakdown
	local lv = clean(levels, rules.MaxLevel)
	local avg = Danger.average(lv)
	local keep = Danger.keep(lv, rules.Shield)
	local raw = rules.LevelPoints * math.clamp((avg - 1) / math.max(rules.MaxLevel - 1, 1), 0, 1)
	local veteran = raw * keep
	local mode = rules.Mode[tier] or 0
	return {
		total = round1(math.clamp(mode + veteran, 0, rules.Max)),
		mode = mode,
		veteran = round1(veteran),
		avgLevel = round1(avg),
		keep = round1(keep * 100) / 100,
		shielded = keep < 0.999 and raw >= 1,
		tier = tier,
	}
end

-- What to multiply the enemies (and the pay) by at `total` points: a share of AtFull, so 0 changes nothing.
function Danger.multipliers(total: number, rules: Rules): Multipliers
	local share = math.clamp(total / rules.Max, 0, 1)
	return {
		enemyCountMult = 1 + rules.AtFull.EnemyCount * share,
		enemyHealthMult = 1 + rules.AtFull.EnemyHealth * share,
		eliteWeight = rules.AtFull.Elite * share,
		rewardMult = 1 + rules.AtFull.Reward * share,
	}
end

return Danger
