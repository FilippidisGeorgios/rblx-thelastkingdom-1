--!strict
--[[
	Trial deed: `toll`
	Ring the bell. An optional task: the gate never waits for it.

	The belfry's rope is a prompt. Pull it once and the bell swings; the dead
	answer from the graves around it (`answer`: enemy id and count, spread round
	the belfry) and when the last one is down the bell's prize is dropped for
	everyone: a fixed table in configs/Loot (`prize`), so a Deed is the one
	reliable way to a Relic.

	It is a gamble the player chooses: the hardest hour of the chamber, taken
	on purpose, paid in the rarest thing the chamber has. Rung once per run.

	Params (configs/Trials):
	  rope    dotted path of the rope scenery
	  bell    dotted path of the bell model (it swings)
	  prize   a configs/Loot table id, granted to every player
	  answer  { { id = enemy id, count = n } }

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyService = require(script.Parent.Parent.EnemyService)
local CombatService = require(script.Parent.Parent.CombatService)
local LootService = require(script.Parent.Parent.LootService)
local Scaling = require(ReplicatedStorage.Shared.Scaling)
local Util = require(script.Parent.Util)

local Toll = {}

local rng = Random.new()

-- The bell swings about its own pivot, to and fro, losing weight as it goes.
local function swing(bell: Instance, strikes: number)
	if not bell:IsA("Model") then
		return
	end
	local home = bell:GetPivot()
	task.spawn(function()
		local duration = strikes * 1.2
		local t = 0
		while t < duration do
			t += task.wait(0.03)
			local decay = 1 - math.min(t / duration, 1)
			bell:PivotTo(home * CFrame.Angles(0, 0, math.sin(t * 5.2) * math.rad(18) * decay))
		end
		bell:PivotTo(home)
	end)
end

function Toll.create(ctx: any, def: any)
	local rung = false
	local alive: { [string]: boolean } = {}
	local remaining = 0
	local diedConnection: any = nil
	local prompt: ProximityPrompt? = nil
	local connection: RBXScriptConnection? = nil
	local center = Vector3.zero

	local function award()
		LootService.grantAll(def.prize, center + Vector3.new(0, 3, 0))
		ctx.note("The bell is quiet. Something was left for you.", 4)
		ctx.done()
	end

	local function ring(player: Player)
		if rung then
			return
		end
		rung = true
		if prompt then
			prompt.Enabled = false
		end
		local bell = Util.find(def.bell)
		if bell then
			swing(bell, 5)
		end
		ctx.note(("%s tolls the bell. Something answers."):format(player.Name), 4)

		local s = Scaling.combine(Scaling.forPlayers(#Players:GetPlayers()), Scaling.forArea(ctx.area))
		local jobs: { string } = {}
		for _, group in def.answer do
			for _ = 1, math.max(1, math.round(group.count * s.enemyCountMult)) do
				table.insert(jobs, group.id)
			end
		end
		remaining = #jobs

		diedConnection = CombatService.EntityDied:connect(function(entity: any)
			if alive[entity.id] then
				alive[entity.id] = nil
				remaining -= 1
				if remaining <= 0 then
					if diedConnection then
						diedConnection()
						diedConnection = nil
					end
					award()
				end
			end
		end)

		-- Round the belfry, a few seconds apart in twos so they arrive as a rush, not a line.
		task.spawn(function()
			task.wait(1.6)
			for i, enemyId in jobs do
				local angle = rng:NextNumber(0, math.pi * 2)
				local at = center + Vector3.new(math.cos(angle) * 34, 0, math.sin(angle) * 34)
				local id = EnemyService.spawn(enemyId, at, s.enemyHealthMult)
				alive[id] = true
				if i % 2 == 0 then
					task.wait(1.1)
				end
			end
		end)
	end

	return {
		start = function()
			local rope = Util.find(def.rope)
			if not rope then
				ctx.warn("toll: no rope at " .. tostring(def.rope))
				return
			end
			center = Util.position(rope)
			local p = Util.prompt(ctx.folder, center - Vector3.new(0, 1.2, 0), "BellPrompt", "Toll the bell", "Belfry", 1.2, 16)
			prompt = p
			connection = p.Triggered:Connect(ring)
		end,

		stop = function()
			if connection then
				connection:Disconnect()
			end
			if diedConnection then
				diedConnection()
				diedConnection = nil
			end
			if prompt and not rung then
				prompt.Enabled = false
			end
		end,

		progress = function(): (number, number)
			return if rung and remaining <= 0 then 1 else 0, 1
		end,
	}
end

return Toll
