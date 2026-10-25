--!strict
--[[
	Trial pressure: `surge`
	One mass of the dead, sent once, from named places, after a warning. Where a
	tide is a trickle for as long as a job lasts, a surge is a thing that HAPPENS:
	a drum beats, there is a pause long enough to look round, and then they come
	out of the far end of the ward and begin the long walk to where the noise was.

	The Inner Ward starts one on every length of the trench that is dug and shored
	(Trial/Dig signals "shore1".."shore4"), so the pressure is the work's own
	echo: the faster you cut, the sooner they come, and the further you are down
	the cut when they arrive the more it costs to leave it.

	GROUPS scale like waves (party size x depth) unless a group is `flat`: the
	heavy ones (the Hollow Knights) scale with the party alone, so a depth
	multiplier of 2.85 never turns "one knight" into three.

	Params (configs/Trials):
	  warn     a line over the top line when the signal arrives
	  delay    seconds between the warning and the first of them appearing
	  groups   { { id = enemyId, count = n, spawn = marker path, spread = studs, flat = bool? } }

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyService = require(script.Parent.Parent.EnemyService)
local Markers = require(ReplicatedStorage.Shared.World.Markers)
local Scaling = require(ReplicatedStorage.Shared.Scaling)

local Surge = {}

local rng = Random.new()

function Surge.create(ctx: any, def: any)
	local cancelled = false

	local function send()
		local party = Scaling.forPlayers(#Players:GetPlayers())
		local depth = Scaling.forArea(ctx.area)
		local full = Scaling.combine(party, depth)
		for _, group in def.groups do
			local at = Markers.resolve(group.spawn)
			if not at then
				ctx.warn("surge: no marker at " .. tostring(group.spawn))
			else
				local mult = if group.flat then party.enemyCountMult else full.enemyCountMult
				local count = math.max(1, math.round(group.count * mult))
				for i = 1, count do
					local angle = rng:NextNumber(0, math.pi * 2)
					local radius = (group.spread or 8) * math.sqrt(rng:NextNumber())
					EnemyService.spawn(group.id, at + Vector3.new(math.cos(angle) * radius, 0, math.sin(angle) * radius), full.enemyHealthMult)
					-- not all in the same frame: a column, not a clap
					if i % 4 == 0 then
						task.wait(0.15)
						if cancelled then
							return
						end
					end
				end
			end
		end
	end

	return {
		start = function()
			if def.warn then
				ctx.note(def.warn, 5)
			end
			task.delay(def.delay or 0, function()
				if not cancelled then
					send()
				end
			end)
		end,

		stop = function()
			cancelled = true
		end,
	}
end

return Surge
