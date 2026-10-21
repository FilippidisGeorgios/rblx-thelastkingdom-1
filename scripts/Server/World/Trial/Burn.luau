--!strict
--[[
	Trial task: `burn`
	A timber door stands in the passage out of the smithy, and it is burned
	down, not cut: oil, a torch, fire, in that order, across the whole yard.

	  1. OIL      The oil store at the west end holds jars. Take them (two at a
	              time fit in your hands) and pour them on the door.
	  2. TORCH    An unlit torch from the rack by the forge.
	  3. FIRE     Light it at the forge's hearth. It burns for `torchSeconds`:
	              the walk from the hearth to the door is the clock, and the
	              yard in between is full of the dead.
	  4. SET      Hold the lit torch to the soaked door: it catches, burns, and
	              falls, and the gate behind it rises (the task is done).

	The order is the point. Every piece lies at a different end of the yard
	(oil far west, fire in the middle, door far east), so the chamber is a
	journey with a deadline rather than a button; and the torch, which must be
	carried the longest distance of any in the game, is the thing the dead are
	trying to make you drop.

	THE DOOR
	Built here, at runtime, across the passage in front of the portcullis: a
	wall of vertical planks bound with three iron straps, as wide as the arch.
	It collides until it falls. It is NOT the gate: AreaService owns the iron
	and rises it when this task is done.

	Params (configs/Trials):
	  oilStore    dotted path of the model whose `OilJar` children are the jars
	  torchRack   dotted path of the model whose `UnlitTorch` children are the torches
	  fire        dotted path of the hearth the torch is lit at
	  jars        how many pourings the door wants
	  torchSeconds, pourHold, setHold, takeHold

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local TweenService = game:GetService("TweenService")

local AreaService = require(script.Parent.Parent.AreaService)
local BackpackService = require(script.Parent.Parent.BackpackService)
local Torch = require(script.Parent.Torch)
local Util = require(script.Parent.Util)

local Burn = {}

local GAP_W = 46
local DOOR_H = 27
local PLANKS = 16

local rng = Random.new()

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = true
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- Hides a scenery piece that has been taken (its parts vanish and stop being scenery).
local function takeAway(model: Instance)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") then
			d.Transparency = 1
			d.CanCollide = false
			d.CanQuery = false
		end
	end
end

local function buildDoor(parent: Instance, centre: Vector3): (Model, { Part })
	local model = Instance.new("Model")
	model.Name = "TimberDoor"
	model.Parent = parent
	local planks: { Part } = {}
	local doorModel: Model? = nil
	local w = GAP_W / PLANKS
	for i = 1, PLANKS do
		local h = DOOR_H + rng:NextNumber(-1.2, 0.4)
		local x = -GAP_W / 2 + w * (i - 0.5)
		local tone = rng:NextNumber(0.85, 1.1)
		local p = part(
			model,
			"Plank",
			Vector3.new(w - 0.12, h, 1.5),
			CFrame.new(centre + Vector3.new(x, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-0.6, 0.6))),
			Color3.fromRGB(86 * tone, 64 * tone, 44 * tone),
			Enum.Material.WoodPlanks
		)
		table.insert(planks, p)
	end
	for _, y in { 4.5, 13, 21.5 } do
		local band = part(model, "Strap", Vector3.new(GAP_W - 1, 1.1, 1.9), CFrame.new(centre + Vector3.new(0, y, 0.2)), Color3.fromRGB(46, 40, 38), Enum.Material.CorrodedMetal)
		band.CanCollide = false
	end
	-- Cross-bracing so it reads as a door barred from behind, not a fence.
	for _, dir in { 1, -1 } do
		local brace = part(model, "Brace", Vector3.new(1.1, 30, 1), CFrame.new(centre + Vector3.new(0, 13, -0.9)) * CFrame.Angles(0, 0, math.rad(dir * 33)), Color3.fromRGB(64, 48, 34), Enum.Material.Wood)
		brace.CanCollide = false
	end
	return model, planks
end

local function drips(parent: Instance, at: Vector3)
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
	e.Lifetime = NumberRange.new(0.8, 1.3)
	e.Speed = NumberRange.new(2, 5)
	e.SpreadAngle = Vector2.new(25, 25)
	e.EmissionDirection = Enum.NormalId.Front
	e.Acceleration = Vector3.new(0, -30, 0)
	e.Color = ColorSequence.new(Color3.fromRGB(26, 20, 12))
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 0.2) })
	e.Parent = anchor
	e:Emit(30)
	task.delay(1.4, function()
		anchor:Destroy()
	end)
end

function Burn.create(ctx: any, def: any)
	local connections: { any } = {}
	local poured = 0
	local soaked = false
	local burning = false
	local active = true
	local planks: { Part } = {}
	local doorPrompt: ProximityPrompt? = nil
	local doorCentre = Vector3.zero
	local expiredConnection: any = nil

	local function darken(fraction: number)
		for _, p in planks do
			local base = p.Color
			p.Color = base:Lerp(Color3.fromRGB(26, 20, 14), fraction)
			if fraction >= 0.99 then
				p.Material = Enum.Material.Wood
			end
		end
	end

	local function ignite()
		burning = true
		if doorPrompt then
			doorPrompt.Enabled = false
		end
		ctx.hint(nil)
		ctx.note("The door catches.", 3)
		for _, p in planks do
			task.delay(rng:NextNumber(0, 1.2), function()
				local f = Instance.new("Fire")
				f.Size = 14
				f.Heat = 12
				f.Color = Color3.fromRGB(255, 150, 50)
				f.SecondaryColor = Color3.fromRGB(180, 40, 10)
				f.Parent = p
				TweenService:Create(p, TweenInfo.new(2.6), { Color = Color3.fromRGB(14, 10, 8) }):Play()
			end)
		end
		-- Burns for a while, then gives way plank by plank, and the gate can rise.
		task.delay(3.4, function()
			-- Everything the door was made of falls: planks, straps and braces alike.
			local pieces: { BasePart } = {}
			for _, d in (doorModel :: Model):GetChildren() do
				if d:IsA("BasePart") then
					table.insert(pieces, d)
				end
			end
			for i, p in pieces do
				task.delay((i % 5) * 0.18 + rng:NextNumber(0, 0.3), function()
					p.CanCollide = false
					local pivot = p.CFrame
					TweenService:Create(p, TweenInfo.new(1.5, Enum.EasingStyle.Quad, Enum.EasingDirection.In), {
						CFrame = pivot * CFrame.new(0, -p.Size.Y / 2, 3) * CFrame.Angles(math.rad(rng:NextNumber(70, 95)), 0, math.rad(rng:NextNumber(-10, 10))) * CFrame.new(0, p.Size.Y / 2, 0),
						Transparency = 1,
					}):Play()
					task.delay(1.7, function()
						p:Destroy()
					end)
				end)
			end
			ctx.done()
		end)
	end

	local function onDoor(player: Player)
		if burning or not active then
			return
		end
		if not soaked then
			local carried = BackpackService.count(player, "oil_jar")
			if carried <= 0 then
				ctx.note("The door is dry timber. It wants oil.", 3)
				return
			end
			local use = math.min(carried, def.jars - poured)
			BackpackService.remove(player, "oil_jar", use)
			poured += use
			darken(poured / def.jars * 0.85)
			drips(ctx.folder, doorCentre + Vector3.new(0, 10, 2))
			ctx.progress(poured, def.jars)
			if poured >= def.jars then
				soaked = true
				if doorPrompt then
					doorPrompt.ActionText = "Set alight"
					doorPrompt.ObjectText = "The soaked door"
					doorPrompt.HoldDuration = def.setHold
				end
				ctx.hint("Light a torch at the forge and carry it to the door")
				ctx.note("Soaked through. Now fire.", 4)
			else
				ctx.note("Oil runs into the grain. More.", 3)
			end
			return
		end
		if Torch.isLit(player) then
			Torch.consume(player)
			ignite()
		else
			ctx.note("It needs fire. The forge is lit.", 3)
		end
	end

	return {
		start = function()
			-- THE DOOR
			local passage = AreaService.passageOf(ctx.area)
			doorCentre = passage + Vector3.new(0, 0, 6)
			local door, p = buildDoor(ctx.folder, doorCentre)
			planks = p
			doorModel = door
			doorPrompt = Util.prompt(ctx.folder, doorCentre + Vector3.new(0, 3.2, 3.5), "DoorPrompt", "Pour oil", "The timber door", def.pourHold, 11)
			table.insert(connections, doorPrompt.Triggered:Connect(onDoor))

			-- THE OIL
			local store = Util.find(def.oilStore)
			if store then
				for _, jar in store:GetDescendants() do
					if jar.Name == "OilJar" and (jar:IsA("Model") or jar:IsA("BasePart")) then
						local prompt = Util.prompt(ctx.folder, Util.position(jar) + Vector3.new(0, 2.4, 0), "TakeOil", "Take a jar", "Lamp oil", def.takeHold, 8)
						table.insert(
							connections,
							prompt.Triggered:Connect(function(player: Player)
								if not active or prompt.Parent == nil then
									return
								end
								if BackpackService.add(player, "oil_jar", 1, true) > 0 then
									takeAway(jar)
									prompt.Parent:Destroy()
									ctx.note("A jar of lamp oil. Heavy.", 2.5)
								else
									ctx.note("Your hands are full of oil.", 2.5)
								end
							end)
						)
					end
				end
			else
				ctx.warn("burn: no oil store at " .. tostring(def.oilStore))
			end

			-- THE TORCHES
			local rack = Util.find(def.torchRack)
			if rack then
				for _, t in rack:GetDescendants() do
					if t.Name == "UnlitTorch" and (t:IsA("Model") or t:IsA("BasePart")) then
						local prompt = Util.prompt(ctx.folder, Util.position(t) + Vector3.new(0, 1.8, 0), "TakeTorch", "Take a torch", "Unlit torch", def.takeHold, 8)
						table.insert(
							connections,
							prompt.Triggered:Connect(function(player: Player)
								if not active or prompt.Parent == nil then
									return
								end
								if BackpackService.add(player, "unlit_torch", 1, true) > 0 then
									takeAway(t)
									prompt.Parent:Destroy()
									ctx.note("An unlit torch. Light it at the forge.", 3)
								else
									ctx.note("You hold one already.", 2)
								end
							end)
						)
					end
				end
			else
				ctx.warn("burn: no torch rack at " .. tostring(def.torchRack))
			end

			-- THE FIRE
			local hearth = Util.find(def.fire)
			if hearth then
				local prompt = Util.prompt(ctx.folder, Util.position(hearth) + Vector3.new(0, -3.4, 3.2), "LightTorch", "Light the torch", "The forge", def.takeHold, 9)
				table.insert(
					connections,
					prompt.Triggered:Connect(function(player: Player)
						if not active then
							return
						end
						if BackpackService.count(player, "unlit_torch") <= 0 then
							ctx.note("You have nothing to light.", 2.5)
							return
						end
						BackpackService.remove(player, "unlit_torch", 1)
						if Torch.give(player, def.torchSeconds) then
							ctx.note(("Lit. It will burn about %d seconds."):format(def.torchSeconds), 4)
						end
					end)
				)
			else
				ctx.warn("burn: no fire at " .. tostring(def.fire))
			end

			expiredConnection = Torch.onExpired(function(_player: Player)
				if active and soaked and not burning then
					ctx.note("The torch is out. Fresh fire is at the forge.", 4)
				end
			end)
			ctx.progress(0, def.jars)
		end,

		stop = function()
			active = false
			for _, c in connections do
				c:Disconnect()
			end
			connections = {}
			if expiredConnection then
				expiredConnection:Disconnect()
			end
		end,

		progress = function(): (number, number)
			return poured, def.jars
		end,
	}
end

return Burn
