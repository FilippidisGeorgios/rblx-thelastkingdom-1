--!strict
--[[
	Trial pressure: `rising`
	The graves of a burying ground give up their dead, section by section, until
	a section is shut (its brazier is lit). It is pressure laid over a task, not
	a wave: it has no end of its own, only the end the player gives it.

	  - The ground is divided into SECTIONS by the braziers: every grave belongs
	    to the nearest one.
	  - In each section a handful of graves are chosen (`gravesPerSection`). Every
	    `interval` seconds the section "pulses": `burst` of the dead climb out of
	    random graves of that section, unless `cap` of its dead are already alive
	    (a section a player ignores must not fill the room without limit).
	  - Sections wake `stagger` seconds apart, in section order.
	  - Every `heavy.every`th pulse of a section carries a heavy-weapon corpse.
	  - When a section's brazier turns `Lit`, that section never pulses again.
	    The dead already out stay out.

	The party and depth curves (Shared/Scaling) apply to burst and cap exactly as
	they do to waves, so a trial is never easier in a big party than a wave is.

	A grave is a Model with an `Earth` part (the mound). The body is spawned at
	the top of the mound after a short burst of dirt, so the player sees where it
	came from and has a moment to turn.

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local EnemyService = require(script.Parent.Parent.EnemyService)
local CombatService = require(script.Parent.Parent.CombatService)
local Scaling = require(ReplicatedStorage.Shared.Scaling)
local Util = require(script.Parent.Util)

local Rising = {}

local DIRT = Color3.fromRGB(78, 58, 40)
local RISE_DELAY = 0.9 -- from the dirt to the dead

type Section = {
	index: number,
	order: number,
	brazier: Model,
	graves: { Vector3 },
	nextAt: number,
	pulses: number,
	alive: { [string]: boolean },
	shut: boolean,
}

local rng = Random.new()

local function burst(parent: Instance, at: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "GraveDirt"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(2, 0.2, 2)
	anchor.Position = at
	anchor.Parent = parent

	local emitter = Instance.new("ParticleEmitter")
	emitter.Rate = 0
	emitter.Lifetime = NumberRange.new(0.7, 1.2)
	emitter.Speed = NumberRange.new(7, 14)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.EmissionDirection = Enum.NormalId.Top
	emitter.Acceleration = Vector3.new(0, -34, 0)
	emitter.Color = ColorSequence.new(DIRT)
	emitter.LightInfluence = 1
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.7),
		NumberSequenceKeypoint.new(1, 0.15),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 0.8),
	})
	emitter.Parent = anchor
	emitter:Emit(22)
	task.delay(1.6, function()
		anchor:Destroy()
	end)
end

function Rising.create(ctx: any, def: any)
	local sections: { Section } = {}
	local stopped = false
	local diedConnection: any = nil
	local startedAt = 0

	local function scale()
		local s = Scaling.forPlayers(#Players:GetPlayers())
		return Scaling.combine(s, Scaling.forArea(ctx.area))
	end

	local function spawnAt(section: Section, enemyId: string, at: Vector3)
		task.delay(RISE_DELAY, function()
			if stopped then
				return
			end
			local s = scale()
			local id = EnemyService.spawn(enemyId, at, s.enemyHealthMult)
			section.alive[id] = true
		end)
	end

	local function aliveCount(section: Section): number
		local n = 0
		for _ in section.alive do
			n += 1
		end
		return n
	end

	local function pulse(section: Section)
		local s = scale()
		local cap = math.ceil(def.cap * s.enemyCountMult)
		if aliveCount(section) >= cap then
			return
		end
		section.pulses += 1
		local count = math.max(1, math.round(def.burst * s.enemyCountMult))

		local totalWeight = 0
		for _, e in def.enemies do
			totalWeight += e.weight
		end

		for i = 1, count do
			local grave = section.graves[rng:NextInteger(1, #section.graves)]
			local enemyId = def.enemies[1].id
			local r = rng:NextNumber() * totalWeight
			for _, e in def.enemies do
				r -= e.weight
				if r < 0 then
					enemyId = e.id
					break
				end
			end
			if def.heavy and i == 1 and section.pulses % def.heavy.every == 0 then
				enemyId = def.heavy.id
			end
			burst(ctx.folder, grave)
			spawnAt(section, enemyId, grave)
		end
	end

	local function shut(section: Section)
		if section.shut then
			return
		end
		section.shut = true
	end

	return {
		start = function()
			stopped = false
			startedAt = os.clock()

			local brazierRoot = Util.find(def.braziers)
			if not brazierRoot then
				ctx.warn("rising: no braziers at " .. tostring(def.braziers))
				return
			end
			local points: { { index: number, brazier: Model, pos: Vector3 } } = {}
			for _, child in brazierRoot:GetChildren() do
				local section = child:GetAttribute("Section")
				if child:IsA("Model") and typeof(section) == "number" then
					table.insert(points, { index = section, brazier = child, pos = child:GetPivot().Position })
				end
			end
			table.sort(points, function(a, b)
				return a.index < b.index
			end)
			if #points == 0 then
				ctx.warn("rising: the braziers carry no Section")
				return
			end

			-- Every grave to its nearest brazier.
			local bySection: { [number]: { Vector3 } } = {}
			for _, p in points do
				bySection[p.index] = {}
			end
			for _, path in def.graves do
				local root = Util.find(path)
				if root then
					for _, d in root:GetDescendants() do
						if d:IsA("BasePart") and d.Name == "Earth" then
							local at = d.Position + Vector3.new(0, d.Size.Y / 2, 0)
							local best, bestD = points[1], math.huge
							for _, p in points do
								local dist = Vector3.new(at.X - p.pos.X, 0, at.Z - p.pos.Z).Magnitude
								if dist < bestD then
									best, bestD = p, dist
								end
							end
							table.insert(bySection[best.index], at)
						end
					end
				else
					ctx.warn("rising: no graves at " .. path)
				end
			end

			for order, p in points do
				local all = bySection[p.index]
				-- Choose which graves can open: shuffled, then the first N.
				for i = #all, 2, -1 do
					local j = rng:NextInteger(1, i)
					all[i], all[j] = all[j], all[i]
				end
				local chosen: { Vector3 } = {}
				for i = 1, math.min(def.gravesPerSection, #all) do
					chosen[i] = all[i]
				end
				if #chosen > 0 then
					local section: Section = {
						index = p.index,
						order = order,
						brazier = p.brazier,
						graves = chosen,
						nextAt = startedAt + (order - 1) * def.stagger + def.interval * 0.5,
						pulses = 0,
						alive = {},
						shut = p.brazier:GetAttribute("Lit") == true,
					}
					table.insert(sections, section)
					p.brazier:GetAttributeChangedSignal("Lit"):Connect(function()
						if p.brazier:GetAttribute("Lit") == true then
							shut(section)
						end
					end)
				end
			end

			diedConnection = CombatService.EntityDied:connect(function(entity: any)
				for _, section in sections do
					section.alive[entity.id] = nil
				end
			end)

			task.spawn(function()
				while not stopped do
					task.wait(0.5)
					local now = os.clock()
					for _, section in sections do
						if not section.shut and now >= section.nextAt then
							section.nextAt = now + def.interval
							pulse(section)
						end
					end
				end
			end)
		end,

		stop = function()
			stopped = true
			if diedConnection then
				diedConnection() -- Signal.connect hands back its own disconnect
				diedConnection = nil
			end
		end,

		-- For tests and the ledger: how many sections are still open.
		openSections = function(): number
			local n = 0
			for _, section in sections do
				if not section.shut then
					n += 1
				end
			end
			return n
		end,
	}
end

return Rising
