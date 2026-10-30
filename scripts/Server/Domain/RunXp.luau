--!strict
--[[
	RunXp (domain)
	What a run is worth in experience, per player, when it ends (configs/Experience.Sources). Pure: what the
	run counted and the rules in, XP out.

	  the dead      each enemy slain pays by its tier (Standard, Elite, Boss)
	  helping       each dead enemy someone else finished that this player had struck (an assist), and each
	                fallen friend raised (a revive)
	  time          minutes spent on their feet in the run, a little each, up to a cap
	  chambers      each chamber the party cleared pays `Base + PerChamber * n`, once       } the SHARED prizes
	  deeds         each deed the party did pays a fixed amount                              }
	  the castle    a victory pays a bonus on top                                            }

	A WIPED run pays all of it except the victory bonus: progress persists (AreaPlan, the laws), and a player
	is never made to lose experience they earned. Gold is the thing a wipe takes a share of (Domain/Settlement).

	TAKING PART. The shared prizes and the time pay go to someone who played. A player whose contribution (damage
	dealt, plus a worth for each assist and revive) is under `Participation.MinContribution` is paid the shared
	prizes at `IdleShare` and no time at all: standing at the gate is not carried to a level. The line is a couple
	of good blows, so anyone who plays is far over it. A record WITHOUT a damage count (the old shape of a run) is
	treated as having taken part.

	Location: ServerScriptService.Server.Domain.RunXp
]]

local RunXp = {}

export type Run = {
	kills: { [string]: number }, -- by tier
	cleared: { number }, -- the chambers cleared, by number
	deeds: number,
	damage: number?, -- damage dealt to the dead (the gate; absent = took part)
	assists: number?,
	revives: number?,
	activeSeconds: number?, -- seconds on their feet in the run
}

export type Rules = {
	Kill: { [string]: number },
	Chamber: { Base: number, PerChamber: number },
	Deed: number,
	Won: number,
	Assist: number?,
	Revive: number?,
	Time: { PerMinute: number, CapMinutes: number }?,
	Participation: { MinContribution: number, IdleShare: number, AssistWorth: number, ReviveWorth: number }?,
}

export type Result = {
	total: number,
	kills: number,
	assists: number,
	revives: number,
	time: number,
	chambers: number,
	deeds: number,
	won: number,
	tookPart: boolean,
}

-- Whether this record counts as someone who played (see the header).
function RunXp.tookPart(run: Run, rules: Rules): boolean
	local gate = rules.Participation
	if not gate or run.damage == nil then
		return true
	end
	local contribution = math.max(0, run.damage)
		+ math.max(0, run.assists or 0) * gate.AssistWorth
		+ math.max(0, run.revives or 0) * gate.ReviveWorth
	return contribution >= gate.MinContribution
end

function RunXp.compute(run: Run, outcome: string, rules: Rules): Result
	local kills = 0
	for tier, count in run.kills do
		kills += math.max(0, count) * (rules.Kill[tier] or 0)
	end

	local assists = math.max(0, run.assists or 0) * (rules.Assist or 0)
	local revives = math.max(0, run.revives or 0) * (rules.Revive or 0)

	local tookPart = RunXp.tookPart(run, rules)
	local share = if tookPart or not rules.Participation then 1 else rules.Participation.IdleShare

	local time = 0
	if tookPart and rules.Time then
		local minutes = math.min(math.max(0, run.activeSeconds or 0) / 60, rules.Time.CapMinutes)
		time = math.floor(minutes) * rules.Time.PerMinute
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
	chambers *= share

	local deeds = math.max(0, run.deeds) * rules.Deed * share
	local won = if outcome == "won" then rules.Won * share else 0
	return {
		total = math.floor(kills + assists + revives + time + chambers + deeds + won),
		kills = kills,
		assists = assists,
		revives = revives,
		time = time,
		chambers = chambers,
		deeds = deeds,
		won = won,
		tookPart = tookPart,
	}
end

return RunXp
