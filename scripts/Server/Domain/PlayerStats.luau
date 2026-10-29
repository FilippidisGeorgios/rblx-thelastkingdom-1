--!strict
--[[
	PlayerStats (domain)
	The lifetime statistics of a player, the numbers the Muster Roll shows so they know what they have done:
	the dead they have slain, the damage they have dealt, how often they fell, how deep they have been, how
	long they have fought. They live in `profile.stats` beside the counts Domain/Settlement already keeps
	(`runsWon`, `runsWiped`, `bestRunGold`). Pure: a stats table and one run's record in, the stats changed.

	A run is added ONCE, when it is settled (World/RunSettlement). A player who leaves mid-run adds nothing:
	what they did not carry out of the castle was not banked either.

	Keys written here:
	  kills, eliteKills, bossKills   the dead slain, and how many were Elite or Boss
	  damageDealt                    whole points of damage to enemies
	  downs                          times they fell
	  chambersCleared                chambers cleared with the party, summed over runs
	  deepestChamber                 the deepest chamber ever cleared
	  playSeconds                    seconds spent in runs
	  fastestWinSeconds              the shortest victory
	  goldBanked                     gold carried out, summed over runs
	  xpEarned                       experience earned in runs

	Location: ServerScriptService.Server.Domain.PlayerStats
]]

local PlayerStats = {}

export type RunRecord = {
	kills: { [string]: number }, -- by tier
	damage: number,
	downs: number,
	cleared: { number },
	seconds: number,
}

local function add(stats: { [string]: any }, key: string, amount: number)
	stats[key] = (stats[key] or 0) + amount
end

function PlayerStats.addRun(stats: { [string]: any }, run: RunRecord, outcome: string, goldBanked: number, xp: number)
	local kills = 0
	for _, count in run.kills do
		kills += math.max(0, count)
	end
	add(stats, "kills", kills)
	add(stats, "eliteKills", math.max(0, run.kills.Elite or 0))
	add(stats, "bossKills", math.max(0, run.kills.Boss or 0))
	add(stats, "damageDealt", math.floor(math.max(0, run.damage)))
	add(stats, "downs", math.max(0, run.downs))

	local seen: { [number]: boolean } = {}
	local deepest = stats.deepestChamber or 0
	for _, n in run.cleared do
		if not seen[n] and n >= 1 then
			seen[n] = true
			add(stats, "chambersCleared", 1)
			deepest = math.max(deepest, n)
		end
	end
	stats.deepestChamber = deepest

	local seconds = math.max(0, math.floor(run.seconds))
	add(stats, "playSeconds", seconds)
	if outcome == "won" and seconds > 0 then
		local best = stats.fastestWinSeconds
		stats.fastestWinSeconds = if best == nil then seconds else math.min(best, seconds)
	end
	add(stats, "goldBanked", math.max(0, goldBanked))
	add(stats, "xpEarned", math.max(0, xp))
end

return PlayerStats
