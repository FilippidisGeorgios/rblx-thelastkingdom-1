--!strict
--[[
	RunXp (domain)
	What a run is worth in experience, per player, when it ends (configs/Experience.Sources). Pure: what the
	run counted and the rules in, XP out.

	  the dead      each enemy slain pays by its tier (Standard, Elite, Boss)
	  chambers      each chamber the party cleared pays `Base + PerChamber * n`, once
	  deeds         each deed the party did pays a fixed amount
	  the castle    a victory pays a bonus on top

	A WIPED run pays all of it except the victory bonus: progress persists (AreaPlan, the laws), and a player
	is never made to lose experience they earned. Gold is the thing a wipe takes a share of (Domain/Settlement).

	Location: ServerScriptService.Server.Domain.RunXp
]]

local RunXp = {}

export type Run = {
	kills: { [string]: number }, -- by tier
	cleared: { number }, -- the chambers cleared, by number
	deeds: number,
}

export type Rules = {
	Kill: { [string]: number },
	Chamber: { Base: number, PerChamber: number },
	Deed: number,
	Won: number,
}

export type Result = { total: number, kills: number, chambers: number, deeds: number, won: number }

function RunXp.compute(run: Run, outcome: string, rules: Rules): Result
	local kills = 0
	for tier, count in run.kills do
		kills += math.max(0, count) * (rules.Kill[tier] or 0)
	end

	-- a chamber counts once, however many times it is reported
	local seen: { [number]: boolean } = {}
	local chambers = 0
	for _, n in run.cleared do
		if not seen[n] and n >= 1 then
			seen[n] = true
			chambers += rules.Chamber.Base + rules.Chamber.PerChamber * n
		end
	end

	local deeds = math.max(0, run.deeds) * rules.Deed
	local won = if outcome == "won" then rules.Won else 0
	return {
		total = math.floor(kills + chambers + deeds + won),
		kills = kills,
		chambers = chambers,
		deeds = deeds,
		won = won,
	}
end

return RunXp
