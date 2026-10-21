--!strict
--[[
	Trial pressure: `tide`
	A thin, steady trickle of the dead, for exactly as long as a task asks for
	it. Where a wave is a thing to be cleared, a tide is a thing to be stood
	in: it never ends by being beaten, only by the work being done.

	Every `interval` seconds, `burst` of the dead appear at one of `spawns`
	(marker names, resolved the way WaveService resolves them) unless `cap` of
	its own are already alive. Party size and depth scale burst and cap the same
	way they scale waves.

	Chamber 3 starts it on the signal "simmer" and stops it when the cooking
	phase ends: the smell of the pot is what draws them.

	Params (configs/Trials):
	  spawns    { marker path }
	  interval  seconds
	  burst     per pulse, before the curve
	  cap       alive at once, before the curve
	  enemies   { { id, weight } }

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyService = require(script.Parent.Parent.EnemyService)
local CombatService = require(script.Parent.Parent.CombatService)
local Markers = require(ReplicatedStorage.Shared.World.Markers)
local Scaling = require(ReplicatedStorage.Shared.Scaling)

local Tide = {}

local rng = Random.new()

function Tide.create(ctx: any, def: any)
	local stopped = false
	local alive: { [string]: boolean } = {}
	local diedConnection: any = nil

	local function scale()
		return Scaling.combine(Scaling.forPlayers(#Players:GetPlayers()), Scaling.forArea(ctx.area))
	end

	local function aliveCount(): number
		local n = 0
		for _ in alive do
			n += 1
		end
		return n
	end

	local function pulse()
		local s = scale()
		if aliveCount() >= math.ceil(def.cap * s.enemyCountMult) then
			return
		end
		local at = Markers.resolve(def.spawns[rng:NextInteger(1, #def.spawns)])
		if not at then
			return
		end
		local total = 0
		for _, e in def.enemies do
			total += e.weight
		end
		for i = 1, math.max(1, math.round(def.burst * s.enemyCountMult)) do
			local r = rng:NextNumber() * total
			local pick = def.enemies[1].id
			for _, e in def.enemies do
				r -= e.weight
				if r < 0 then
					pick = e.id
					break
				end
			end
			local id = EnemyService.spawn(pick, at + Vector3.new((i - 1) * 4, 0, 0), s.enemyHealthMult)
			alive[id] = true
		end
	end

	return {
		start = function()
			stopped = false
			diedConnection = CombatService.EntityDied:connect(function(entity: any)
				alive[entity.id] = nil
			end)
			task.spawn(function()
				while not stopped do
					task.wait(def.interval)
					if not stopped then
						pulse()
					end
				end
			end)
		end,

		stop = function()
			stopped = true
			if diedConnection then
				diedConnection()
				diedConnection = nil
			end
		end,
	}
end

return Tide
