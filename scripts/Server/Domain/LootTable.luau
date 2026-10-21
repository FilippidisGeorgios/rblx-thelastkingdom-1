--!strict
--[[
	LootTable (domain)
	The roll. Given a drop table (configs/Loot `Tables[id]`), the rules, an RNG
	and a little context, decides what falls. Pure: no Roblox services, no
	Instances, no clock. `Random` is passed in, so a spec can hand it a script.

	WHY PITY EXISTS
	A flat 1.2% is honest and miserable: some players see three Sound items in a
	chamber and some see none in a run. Pity makes the bad streak finite and
	changes nothing about the average a long way out: after
	`PityGuaranteeSound` kills without a Sound-or-better drop the next kill is a
	Sound drop, and after `PityUpgradeHallowed` kills without a Hallowed one the
	next Sound drop is a Hallowed one. The counters belong to the player and the
	run (LootService owns them); this module only reads and updates the table it
	is handed.

	Location: ServerScriptService.Server.Domain.LootTable
]]

local LootTable = {}

export type Rng = {
	NextNumber: (self: any, min: number?, max: number?) -> number,
	NextInteger: (self: any, min: number, max: number) -> number,
}

export type Pity = { dryS: number, dryH: number }

export type Drop = {
	item: string?, -- nil for gold
	count: number, -- the amount, for gold
	rank: string,
	gold: boolean,
}

export type Context = {
	depth: number?, -- chamber index, 1..9
	goldMult: number?, -- party reward multiplier, applied to gold only
	pity: Pity?, -- nil = no pity (containers, fixed prizes)
}

function LootTable.newPity(): Pity
	return { dryS = 0, dryH = 0 }
end

local function between(rng: Rng, min: number, max: number): number
	if max <= min then
		return min
	end
	return rng:NextInteger(min, max)
end

local function pickWeighted(pool: { any }, rng: Rng): any?
	local total = 0
	for _, entry in pool do
		total += entry.Weight
	end
	if total <= 0 then
		return nil
	end
	local r = rng:NextNumber() * total
	for _, entry in pool do
		r -= entry.Weight
		if r < 0 then
			return entry
		end
	end
	return pool[#pool]
end

--[[
	Rolls one table. Returns the list of drops (merged by item, gold merged into
	one entry). `items` is the item catalog, for ranks.
]]
function LootTable.roll(def: any, items: any, rules: any, rng: Rng, ctx: Context?): { Drop }
	local context: Context = ctx or {}
	local depth = math.max(1, context.depth or 1)
	local goldMult = (1 + rules.GoldPerDepth * (depth - 1)) * (context.goldMult or 1)
	local soundMult = 1 + rules.SoundPerDepth * (depth - 1)
	local hallowedMult = 1 + rules.HallowedPerDepth * (depth - 1)

	local out: { Drop } = {}
	local byItem: { [string]: Drop } = {}

	local function give(itemId: string, count: number)
		local existing = byItem[itemId]
		if existing then
			existing.count += count
			return
		end
		local item = items[itemId]
		local drop: Drop = {
			item = itemId,
			count = count,
			rank = if item and item.Rank then item.Rank else "Worn",
			gold = false,
		}
		byItem[itemId] = drop
		table.insert(out, drop)
	end

	-- Guaranteed first (bosses, deed prizes).
	if def.Always then
		for _, entry in def.Always do
			give(entry.Item, between(rng, entry.Min, entry.Max))
		end
	end

	-- Gold.
	local gold = def.Gold
	if gold and rng:NextNumber() < gold.Chance then
		local amount = math.max(1, math.round(between(rng, gold.Min, gold.Max) * goldMult))
		table.insert(out, { item = nil, count = amount, rank = "Worn", gold = true })
	end

	-- Independent chances.
	if def.Drops then
		for _, entry in def.Drops do
			if rng:NextNumber() < entry.Chance then
				give(entry.Item, between(rng, entry.Min, entry.Max))
			end
		end
	end

	-- The ranks, with pity.
	local pity = context.pity
	local gotSound = false
	local gotHallowed = false

	local hallowed = def.Hallowed
	local sound = def.Sound

	if hallowed and rng:NextNumber() < hallowed.Chance * hallowedMult then
		local pick = pickWeighted(hallowed.Pool, rng)
		if pick then
			give(pick.Item, between(rng, pick.Min, pick.Max))
			gotHallowed = true
			gotSound = true
		end
	end

	if not gotHallowed and sound then
		local forced = pity ~= nil and pity.dryS >= rules.PityGuaranteeSound
		if forced or rng:NextNumber() < sound.Chance * soundMult then
			local upgrade = pity ~= nil and pity.dryH >= rules.PityUpgradeHallowed and hallowed ~= nil
			local pool = if upgrade then (hallowed :: any).Pool else sound.Pool
			local pick = pickWeighted(pool, rng)
			if pick then
				give(pick.Item, between(rng, pick.Min, pick.Max))
				gotSound = true
				gotHallowed = upgrade
			end
		end
	end

	if pity and (sound or hallowed) then
		pity.dryS = if gotSound then 0 else pity.dryS + 1
		pity.dryH = if gotHallowed then 0 else pity.dryH + 1
	end

	return out
end

return LootTable
