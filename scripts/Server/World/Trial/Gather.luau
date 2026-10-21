--!strict
--[[
	Trial task: `gather`
	Fetch the things the recipe asks for. Each ingredient is a small prop lying
	near the part of the kitchens it belongs to (the flour in the granary, the
	meat at the smokehouse, the herbs in the garden, the water at the well),
	glowing softly where you can see it. Take it and you carry it.

	WHERE THEY ARE
	Each is placed by looking, not by coordinates (Trial.Place): somewhere
	within ZONE_RADIUS of the scenery named in the recipe, on a floor, clear.
	The four a run asks for were rolled in Trial.Recipe; the other three do not
	exist this run, so the same chamber is a different errand each time.

	CARRYING
	An ingredient is a quest item: it takes no place in the pack, it is never
	banked, and it is shown under "In your hands". It is a thing for the pot,
	and the pot is in the kitchen hall (Trial/Cook).

	Params (configs/Trials): none; the recipe is the trial's `recipe`.

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local TweenService = game:GetService("TweenService")

local BackpackService = require(script.Parent.Parent.BackpackService)
local Place = require(script.Parent.Place)
local Recipe = require(script.Parent.Recipe)
local Util = require(script.Parent.Util)

local Gather = {}

local ZONE_RADIUS = 26
local rng = Random.new()

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

--==========================================================================
-- The props. Each is built standing on the floor at `at`.
--==========================================================================
local BUILDERS: { [string]: (Model, CFrame) -> () } = {
	sack = function(m, at)
		part(m, "Sack", Vector3.new(2.2, 2.4, 1.8), at * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, 0, math.rad(4)), Color3.fromRGB(176, 162, 128), Enum.Material.Fabric, Enum.PartType.Ball)
		part(m, "Tie", Vector3.new(0.7, 0.5, 0.7), at * CFrame.new(0, 2.4, 0), Color3.fromRGB(120, 98, 62), Enum.Material.Fabric)
		part(m, "Dust", Vector3.new(1.4, 0.05, 1.1), at * CFrame.new(0.9, 0.05, 1.2), Color3.fromRGB(226, 220, 204), Enum.Material.Sand)
	end,
	ham = function(m, at)
		part(m, "Ham", Vector3.new(1.4, 1.2, 2.4), at * CFrame.new(0, 2.8, 0), Color3.fromRGB(128, 62, 52), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		part(m, "Bone", Vector3.new(0.3, 0.3, 1.0), at * CFrame.new(0, 2.8, -1.8), Color3.fromRGB(216, 204, 176), Enum.Material.SmoothPlastic)
		part(m, "Cord", Vector3.new(0.08, 1.6, 0.08), at * CFrame.new(0, 4.1, 0.2), Color3.fromRGB(150, 128, 90), Enum.Material.Fabric)
		part(m, "Hook", Vector3.new(0.5, 0.2, 0.2), at * CFrame.new(0, 5, 0.2), Color3.fromRGB(60, 54, 50), Enum.Material.Metal)
		part(m, "Post", Vector3.new(0.5, 5, 0.5), at * CFrame.new(0.6, 2.5, 0.2), Color3.fromRGB(78, 56, 38), Enum.Material.Wood).CanCollide = true
	end,
	herbs = function(m, at)
		for i = 1, 7 do
			local a = i * (math.pi * 2 / 7)
			part(m, "Stem", Vector3.new(0.12, 1.6, 0.12), at * CFrame.new(math.cos(a) * 0.35, 0.8, math.sin(a) * 0.35) * CFrame.Angles(math.cos(a) * 0.25, 0, math.sin(a) * 0.25), Color3.fromRGB(86, 118, 62), Enum.Material.Grass)
		end
		part(m, "Leaves", Vector3.new(1.4, 0.8, 1.4), at * CFrame.new(0, 1.7, 0), Color3.fromRGB(100, 138, 70), Enum.Material.Grass, Enum.PartType.Ball)
		part(m, "Twine", Vector3.new(0.7, 0.12, 0.7), at * CFrame.new(0, 0.7, 0), Color3.fromRGB(160, 136, 94), Enum.Material.Fabric)
	end,
	bucket = function(m, at)
		local body = part(m, "Bucket", Vector3.new(2, 2.2, 2.2), at * CFrame.new(0, 1.1, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(88, 64, 42), Enum.Material.Wood, Enum.PartType.Cylinder)
		part(m, "Water", Vector3.new(0.12, 1.9, 1.9), body.CFrame * CFrame.new(0.95, 0, 0), Color3.fromRGB(70, 110, 130), Enum.Material.Glass, Enum.PartType.Cylinder).Transparency = 0.25
		part(m, "Band", Vector3.new(0.18, 2.3, 2.3), body.CFrame * CFrame.new(-0.5, 0, 0), Color3.fromRGB(54, 48, 44), Enum.Material.Metal, Enum.PartType.Cylinder)
	end,
	crate = function(m, at)
		part(m, "Crate", Vector3.new(3, 1.8, 2.2), at * CFrame.new(0, 0.9, 0), Color3.fromRGB(94, 70, 46), Enum.Material.WoodPlanks)
		for i = 1, 5 do
			part(m, "Turnip", Vector3.new(0.9, 0.9, 0.9), at * CFrame.new(-1 + (i - 1) * 0.5, 2, rng:NextNumber(-0.5, 0.5)), Color3.fromRGB(190, 168, 190), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end,
	cask = function(m, at)
		local body = part(m, "Cask", Vector3.new(2.6, 2.2, 2.2), at * CFrame.new(0, 1.2, 0) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 360)), 0), Color3.fromRGB(96, 70, 44), Enum.Material.Wood, Enum.PartType.Cylinder)
		for _, d in { -0.8, 0.8 } do
			part(m, "Hoop", Vector3.new(0.2, 2.35, 2.35), body.CFrame * CFrame.new(d, 0, 0), Color3.fromRGB(54, 48, 44), Enum.Material.Metal, Enum.PartType.Cylinder)
		end
	end,
	crock = function(m, at)
		part(m, "Crock", Vector3.new(1.6, 1.4, 1.4), at * CFrame.new(0, 0.8, 0), Color3.fromRGB(150, 128, 104), Enum.Material.Slate, Enum.PartType.Cylinder).CFrame = at * CFrame.new(0, 0.8, 0) * CFrame.Angles(0, 0, math.rad(90))
		part(m, "Lid", Vector3.new(0.2, 1.6, 1.6), at * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 102, 82), Enum.Material.Slate, Enum.PartType.Cylinder)
	end,
}

local function glow(adornee: Instance): Highlight
	local h = Instance.new("Highlight")
	h.Name = "Glow"
	h.FillColor = Color3.fromRGB(232, 216, 182)
	h.FillTransparency = 0.86
	h.OutlineColor = Color3.fromRGB(240, 230, 206)
	h.OutlineTransparency = 0.88
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = adornee
	h.Parent = adornee
	TweenService:Create(h, TweenInfo.new(2.4, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { FillTransparency = 0.95 }):Play()
	return h
end

--==========================================================================
function Gather.create(ctx: any, def: any)
	local nodes: { { prompt: ProximityPrompt, model: Model, taken: boolean, pick: any } } = {}
	local connections: { RBXScriptConnection } = {}
	local taken = 0
	local total = 0
	local finished = false

	return {
		start = function()
			local picks = Recipe.get(ctx.shared, ctx.trial.recipe)
			total = #picks
			local avoid: { Vector3 } = {}
			for _, pick in picks do
				local scenery = Util.find(pick.where)
				local centre = if scenery then Util.position(scenery) else nil
				if not centre then
					ctx.warn("gather: no scenery at " .. tostring(pick.where))
					centre = Vector3.zero
				end
				local zone = { x0 = centre.X - ZONE_RADIUS, x1 = centre.X + ZONE_RADIUS, z0 = centre.Z - ZONE_RADIUS, z1 = centre.Z + ZONE_RADIUS }
				local spots = Place.find(zone, 1, 3, 8, avoid, { ctx.folder }, rng)
				local at = spots[1]
				if not at then
					local y = Place.floorAt(centre.X, centre.Z, { ctx.folder }) or centre.Y
					at = Vector3.new(centre.X, y, centre.Z)
					ctx.warn(("gather: no clear ground near %s; putting %s at its centre"):format(pick.where, pick.id))
				end
				table.insert(avoid, at)

				local model = Instance.new("Model")
				model.Name = "Ingredient_" .. pick.id
				model.Parent = ctx.folder
				local build = BUILDERS[pick.prop] or BUILDERS.sack
				build(model, CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
				glow(model)

				local prompt = Util.prompt(ctx.folder, at + Vector3.new(0, 2.6, 0), "Take_" .. pick.id, "Take", pick.name, 0.8, 10)
				local node = { prompt = prompt, model = model, taken = false, pick = pick }
				table.insert(nodes, node)
				table.insert(
					connections,
					prompt.Triggered:Connect(function(player: Player)
						if node.taken or finished then
							return
						end
						local added = BackpackService.add(player, "ingredient_" .. pick.id, 1, true)
						if added == 0 then
							ctx.note("You are already carrying one of these.", 2.5)
							return
						end
						node.taken = true
						prompt.Enabled = false
						model:Destroy()
						prompt.Parent:Destroy()
						taken += 1
						ctx.progress(taken, total)
						ctx.note(("%s: %s."):format(pick.name, "taken"), 2)
						if taken >= total then
							finished = true
							ctx.done()
						end
					end)
				)
			end
			ctx.progress(taken, total)
		end,

		stop = function()
			for _, c in connections do
				c:Disconnect()
			end
			connections = {}
			for _, n in nodes do
				n.prompt.Enabled = false
			end
		end,

		progress = function(): (number, number)
			return taken, total
		end,
	}
end

return Gather
