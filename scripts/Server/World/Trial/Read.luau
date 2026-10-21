--!strict
--[[
	Trial task: `read`
	A parchment on a table that glows a little, so the eye finds it. Take it up
	and it opens as a page on the player's screen; the task is done the first
	time anyone does. It can be read again whenever (the prompt stays).

	Papyrus and parchment are the game's one language for "this is something
	somebody wrote" (docs/systems/AreaPlan.md): recipes, letters, burial rolls.
	This verb is where the Story's text reaches the player without a cutscene.

	Params (configs/Trials):
	  at      dotted path of the scenery the scroll lies on (it sits on its top)
	  title   the page's heading
	  sign    who wrote it
	  recipe  true: the lines are the chamber's rolled recipe (Trial.Recipe)
	  lines   otherwise: the page's lines, as written

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local Net = require(ReplicatedStorage.Shared.Net)
local Recipe = require(script.Parent.Recipe)
local Util = require(script.Parent.Util)

local Read = {}

local PAPER = Color3.fromRGB(214, 198, 160)
local WAX = Color3.fromRGB(122, 36, 38)

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

-- A scroll lying on a surface: a rolled sheet, a ribbon of wax, a curl at one end.
local function buildScroll(parent: Instance, at: CFrame): Model
	local model = Instance.new("Model")
	model.Name = "Papyrus"
	model.Parent = parent

	local roll = part(model, "Roll", Vector3.new(2.4, 0.5, 0.5), at * CFrame.new(0, 0.3, 0), PAPER, Enum.Material.Fabric)
	roll.Shape = Enum.PartType.Cylinder
	-- A cylinder's axis is its local X: the roll lies along X as built.
	local sheet = part(model, "Sheet", Vector3.new(1.1, 0.04, 0.9), at * CFrame.new(1.7, 0.08, 0.1) * CFrame.Angles(0, math.rad(8), 0), PAPER, Enum.Material.Fabric)
	sheet.Color = PAPER:Lerp(Color3.new(1, 1, 1), 0.1)
	part(model, "Seal", Vector3.new(0.34, 0.12, 0.34), at * CFrame.new(-0.2, 0.58, 0), WAX, Enum.Material.SmoothPlastic).Shape = Enum.PartType.Cylinder
	model.PrimaryPart = roll
	return model
end

local function glow(adornee: Instance): Highlight
	local h = Instance.new("Highlight")
	h.Name = "Glow"
	h.FillColor = Color3.fromRGB(240, 222, 170)
	h.FillTransparency = 0.8
	h.OutlineColor = Color3.fromRGB(250, 236, 196)
	h.OutlineTransparency = 0.7
	h.DepthMode = Enum.HighlightDepthMode.Occluded
	h.Adornee = adornee
	h.Parent = adornee
	TweenService:Create(h, TweenInfo.new(2.2, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, -1, true), { FillTransparency = 0.92 }):Play()
	return h
end

--[[
	Lays a parchment on the scenery at `path` and makes it readable: it sits on the
	top of whatever it lies on, glows softly, and opens as a page on the screen of
	whoever takes it up. `onRead(player)` runs each time. Returns the prompt, or nil
	(after warning) when there is nothing at `path`. Shared by `read` (one page) and
	`letters` (several).
]]
function Read.place(ctx: any, path: string, title: string?, sign: string?, lines: () -> { string }, onRead: (Player) -> ()): ProximityPrompt?
	local documentEvent = Net.getEvent("DocumentEvent")
	local scenery = Util.find(path)
	if not scenery then
		ctx.warn("read: nothing at " .. tostring(path))
		return nil
	end
	local cf, size
	if scenery:IsA("Model") then
		cf, size = scenery:GetBoundingBox()
	else
		cf, size = (scenery :: BasePart).CFrame, (scenery :: BasePart).Size
	end
	local top = Vector3.new(cf.Position.X, cf.Position.Y + size.Y / 2, cf.Position.Z)
	local scroll = buildScroll(ctx.folder, CFrame.new(top) * CFrame.Angles(0, math.rad(22), 0))
	glow(scroll)

	local prompt = Util.prompt(ctx.folder, top + Vector3.new(0, 1.4, 0), "ReadPrompt", "Read", title or "Parchment", 0.4, 11)
	prompt.Triggered:Connect(function(player: Player)
		documentEvent:FireClient(player, {
			kind = "open",
			title = title,
			sign = sign,
			lines = lines(),
		})
		onRead(player)
	end)
	return prompt
end

function Read.create(ctx: any, def: any)
	local done = false

	local function linesFor(): { string }
		if def.recipe then
			return Recipe.lines(ctx.shared, ctx.trial.recipe)
		end
		return def.lines or {}
	end

	return {
		start = function()
			Read.place(ctx, def.at, def.title, def.sign, linesFor, function()
				if not done then
					done = true
					ctx.done()
				end
			end)
		end,

		-- The scroll stays on its table and stays readable after the task is done.
		stop = function() end,

		progress = function(): (number, number)
			return if done then 1 else 0, 1
		end,
	}
end

return Read
