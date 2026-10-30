--!strict
--[[
	Scaling
	Reads the player-count difficulty curves from `configs/Difficulty` and returns the
	scaling parameters for a given party size — the "balanced, not linear" rule in one
	place. Shared so rewards/other systems can reuse it; only the server acts on it.

	Location: ReplicatedStorage.Shared.Scaling
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)
local Danger = require(script.Parent.Danger)

local Scaling = {}

-- The run's DANGER (0..100, Shared/Danger): set once by the server when a run begins, folded into every
-- `forPlayers` answer so the waves, the trials, the King and the pay all feel it without being edited.
-- It is 0 in the Hub, and the client never sets it.
local runDanger = 0

export type Params = {
	enemyCountMult: number,
	enemyHealthMult: number,
	eliteWeight: number,
	rewardMult: number,
}

local DEFAULT: Params = {
	enemyCountMult = 1,
	enemyHealthMult = 1,
	eliteWeight = 0,
	rewardMult = 1,
}

-- Scaling params for `playerCount`. Falls back to the largest defined entry <= count
-- (so 8 players uses the [8] row even if only some counts are defined).
function Scaling.forPlayers(playerCount: number): Params
	local difficulty = Config.get("Difficulty")
	local byCount = difficulty.PlayerCount
	local n = math.max(1, playerCount)

	local entry = byCount[n]
	if not entry then
		local bestKey = -1
		for k, v in byCount do
			if k <= n and k > bestKey then
				bestKey = k
				entry = v
			end
		end
	end
	if not entry then
		return DEFAULT
	end

	local params: Params = {
		enemyCountMult = entry.EnemyCountMult or 1,
		enemyHealthMult = entry.EnemyHealthMult or 1,
		eliteWeight = entry.EliteWeight or 0,
		rewardMult = entry.RewardMult or 1,
	}
	if runDanger > 0 then
		local extra = Scaling.forDanger(runDanger)
		params = {
			enemyCountMult = params.enemyCountMult * extra.enemyCountMult,
			enemyHealthMult = params.enemyHealthMult * extra.enemyHealthMult,
			eliteWeight = params.eliteWeight + extra.eliteWeight,
			rewardMult = params.rewardMult * extra.rewardMult,
		}
	end
	return params
end

--[[
	What `total` points of Danger do to the enemies and the pay (see configs/Difficulty.Danger). Pure of the
	run: `forPlayers` adds the run's own figure; this answers for any figure, so the train can preview one.
]]
function Scaling.forDanger(total: number): Params
	return Danger.multipliers(total, Config.get("Difficulty").Danger)
end

-- The server sets the run's Danger when the run begins (World/RunDifficultyService); 0 clears it.
function Scaling.setRunDanger(total: number)
	runDanger = math.max(0, total)
end

function Scaling.getRunDanger(): number
	return runDanger
end

--[[
	Scaling params for DEPTH: how much harder the castle gets as you go in.

	The second of the two curves in `configs/Difficulty`, and the one that had
	been sitting there written and unread. Area 5 is the spike; see the comment
	over the Areas table for the shape and why it is that shape.
]]
function Scaling.forArea(areaIndex: number): Params
	local difficulty = Config.get("Difficulty")
	local entry = difficulty.Areas and difficulty.Areas[areaIndex]
	if not entry then
		return DEFAULT
	end
	return {
		enemyCountMult = entry.EnemyCountMult or 1,
		enemyHealthMult = entry.EnemyHealthMult or 1,
		eliteWeight = 0, -- depth does not add elites; party size does
		rewardMult = 1,
	}
end

--[[
	The two curves multiplied, which is the whole point of them being separate:
	party size says how much the room can chew through, depth says what the
	castle is willing to send, and a solo player deep in and a full party near
	the door should both be working hard.
]]
function Scaling.combine(a: Params, b: Params): Params
	return {
		enemyCountMult = a.enemyCountMult * b.enemyCountMult,
		enemyHealthMult = a.enemyHealthMult * b.enemyHealthMult,
		eliteWeight = math.max(a.eliteWeight, b.eliteWeight),
		rewardMult = a.rewardMult * b.rewardMult,
	}
end

return Scaling
