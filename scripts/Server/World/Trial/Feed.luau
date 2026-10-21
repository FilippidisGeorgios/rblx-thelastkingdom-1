--!strict
--[[
	Trial task: `feed`
	Five of the dead stand penned in a yard of the kitchens, quiet and waiting.
	Feed each a ladle of the broth and it turns back into a villager, who speaks,
	and from then on walks with the party and fights beside it.

	THE PEN
	Built here, at runtime, on open ground found by looking (Trial.Place): a
	ring of stakes with rails between them and a wide gap on the side facing the
	pot, so the cured can walk out and the pathfinder can route them. The rails
	do not collide and are invisible to the AI's rays (CanQuery off); the stakes
	collide, because a pen you can walk through reads as a drawing of a pen.

	THE PENNED
	Bodies with no brain and no combat entity (`EnemyService.spawnStatic`): they
	cannot chase, be targeted or be killed, so the chamber can never be made
	impossible by a stray swing. They play the idle. Feeding one swaps it for a
	real `cured_villager` (or `_bow`) with the same body and the curse put out.

	THE FIVE
	Three fight in melee and two carry bows (docs/systems/AreaPlan.md §3). The
	task is done when all five are fed: one ladle each, five ladles in the pot.

	Params (configs/Trials):
	  near       dotted path of the scenery the pen is found around
	  gateToward dotted path of the scenery the pen's gap faces (the pot)
	  radius     how far from it to look
	  holdSeconds
	  penned     { { dead = enemy id (the body), cure = enemy id (what it becomes) } } x5
	  lines      the words the cured speak, one each

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local BackpackService = require(script.Parent.Parent.BackpackService)
local EnemyService = require(script.Parent.Parent.EnemyService)
local Place = require(script.Parent.Place)
local Util = require(script.Parent.Util)

local Feed = {}

local rng = Random.new()

local PEN_RX = 10
local PEN_RZ = 7.5
local POSTS = 22
local GATE_ARC = math.rad(46) -- the gap, on the side facing the pot

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

--[[
	The fence. `centre` is on the floor; `gateAngle` is the direction (radians,
	about +Y from +X) of the gap. Returns the model.
]]
local function buildPen(parent: Instance, centre: Vector3, gateAngle: number): Model
	local model = Instance.new("Model")
	model.Name = "Pen"
	model.Parent = parent

	local wood = Color3.fromRGB(78, 58, 40)
	local weathered = Color3.fromRGB(96, 80, 62)
	local posts: { { pos: Vector3, angle: number } } = {}

	for i = 0, POSTS - 1 do
		local a = i * (math.pi * 2 / POSTS)
		local delta = math.abs(((a - gateAngle + math.pi) % (math.pi * 2)) - math.pi)
		if delta > GATE_ARC then
			local x = centre.X + math.cos(a) * PEN_RX
			local z = centre.Z + math.sin(a) * PEN_RZ
			local y = Place.floorAt(x, z, { model }) or centre.Y
			local h = 4.6 + rng:NextNumber(-0.5, 0.7)
			local post = part(model, "Stake", Vector3.new(0.7, h, 0.7), CFrame.new(x, y + h / 2 - 0.3, z) * CFrame.Angles(math.rad(rng:NextNumber(-3, 3)), rng:NextNumber(0, 6), math.rad(rng:NextNumber(-3, 3))), wood, Enum.Material.Wood)
			post.CanCollide = true
			table.insert(posts, { pos = Vector3.new(x, y, z), angle = a })
			-- A sharpened head.
			part(model, "Point", Vector3.new(0.5, 0.6, 0.5), post.CFrame * CFrame.new(0, h / 2 + 0.2, 0) * CFrame.Angles(0, math.rad(45), 0), wood, Enum.Material.Wood)
		end
	end

	-- Two rails between each neighbouring pair that are actually neighbours.
	for i = 1, #posts - 1 do
		local a, b = posts[i], posts[i + 1]
		local gap = (b.pos - a.pos).Magnitude
		if gap < 6 then
			for _, height in { 1.5, 3.2 } do
				local from = a.pos + Vector3.new(0, height, 0)
				local to = b.pos + Vector3.new(0, height, 0)
				local mid = (from + to) / 2
				part(model, "Rail", Vector3.new(0.3, 0.45, (to - from).Magnitude), CFrame.lookAt(mid, to), weathered, Enum.Material.Wood)
			end
		end
	end

	-- Trodden mud inside, so it reads as a yard and not a ring of sticks.
	-- (a cylinder's axis is its local X, so it is turned to lie flat)
	local mud = part(model, "Mud", Vector3.new(0.25, PEN_RZ * 2 - 1, PEN_RZ * 2 - 1), CFrame.new(centre + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(62, 48, 36), Enum.Material.Mud)
	mud.Shape = Enum.PartType.Cylinder
	return model
end

local function puff(parent: Instance, at: Vector3)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(1, 1, 1)
	anchor.Position = at
	anchor.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Rate = 0
	e.Lifetime = NumberRange.new(0.8, 1.4)
	e.Speed = NumberRange.new(3, 7)
	e.SpreadAngle = Vector2.new(180, 180)
	e.LightEmission = 0.8
	e.LightInfluence = 0
	e.Color = ColorSequence.new(Color3.fromRGB(255, 232, 170))
	e.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.5),
		NumberSequenceKeypoint.new(1, 0),
	})
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Parent = anchor
	e:Emit(28)
	task.delay(1.6, function()
		anchor:Destroy()
	end)
end

function Feed.create(ctx: any, def: any)
	type Slot = { model: Model?, prompt: ProximityPrompt, fed: boolean, index: number }
	local slots: { Slot } = {}
	local connections: { RBXScriptConnection } = {}
	local total = #def.penned
	local fed = 0
	local finished = false

	local function cure(slot: Slot, player: Player)
		local model = slot.model
		if not model then
			return
		end
		local at = model:GetPivot().Position
		local facing = model:GetPivot().LookVector
		model:Destroy()
		slot.model = nil
		slot.fed = true
		slot.prompt.Enabled = false
		slot.prompt.Parent:Destroy()

		puff(ctx.folder, at + Vector3.new(0, 2.5, 0))
		EnemyService.spawn(def.penned[slot.index].cure, at + facing * 0.1)

		fed += 1
		ctx.progress(fed, total)
		local line = def.lines[slot.index] or def.lines[1]
		ctx.note(line, 6)
		if fed >= total and not finished then
			finished = true
			ctx.done()
		end
	end

	return {
		start = function()
			local near = Util.find(def.near)
			local centre = if near then Util.position(near) else Vector3.zero
			local zone = { x0 = centre.X - def.radius, x1 = centre.X + def.radius, z0 = centre.Z - def.radius, z1 = centre.Z + def.radius }
			local spots = Place.find(zone, 1, 13, 20, nil, { ctx.folder }, rng)
			local spot = spots[1]
			if not spot then
				ctx.warn("feed: no open ground for the pen near " .. tostring(def.near))
				local y = Place.floorAt(centre.X, centre.Z, { ctx.folder }) or centre.Y
				spot = Vector3.new(centre.X, y, centre.Z)
			end

			-- The gap faces the pot, so the cured walk toward the work and the party.
			local pot = Util.find(def.gateToward)
			local toward = if pot then (Util.position(pot) - spot) else Vector3.new(1, 0, 0)
			local gateAngle = math.atan2(toward.Z, toward.X)
			buildPen(ctx.folder, spot, gateAngle)

			for i, entry in def.penned do
				local a = (i - 1) * (math.pi * 2 / total) + rng:NextNumber(-0.2, 0.2)
				local r = if total > 1 then 4.2 + rng:NextNumber(-0.6, 0.6) else 0
				local at = spot + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r * 0.8)
				local model = EnemyService.spawnStatic(entry.dead, at, spot)
				if not model then
					ctx.warn(("feed: no body for \"%s\""):format(tostring(entry.dead)))
				end
				local anchorAt = at + Vector3.new(0, 3.2, 0)
				local prompt = Util.prompt(ctx.folder, anchorAt, "Feed_" .. i, "Feed", "The penned - still", def.holdSeconds, 12)
				local slot: Slot = { model = model, prompt = prompt, fed = false, index = i }
				table.insert(slots, slot)
				table.insert(
					connections,
					prompt.Triggered:Connect(function(player: Player)
						if slot.fed or finished then
							return
						end
						if not slot.model then
							return -- no body was made for this slot; never spend a ladle on it
						end
						if BackpackService.count(player, "broth") <= 0 then
							ctx.note("They need the broth from the pot.", 3)
							return
						end
						BackpackService.remove(player, "broth", 1)
						cure(slot, player)
					end)
				)
			end
			ctx.progress(fed, total)
		end,

		stop = function()
			for _, c in connections do
				c:Disconnect()
			end
			connections = {}
			for _, s in slots do
				s.prompt.Enabled = false
			end
		end,

		progress = function(): (number, number)
			return fed, total
		end,
	}
end

return Feed
