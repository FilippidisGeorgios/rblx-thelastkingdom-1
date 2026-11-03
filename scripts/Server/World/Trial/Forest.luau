--!strict
--[[
	Trial task: `forest`
	Area 6, the King's Wood (docs/systems/Forest.md): the whole errand of the wood as one task. The stone, the trees and the
	marks are made by `tools/BuildForest.luau` (Decorations.Area6.Forest.Marks.*); the numbers are `configs/Forest`.

	THE RULE. The gamekeepers' board at the way in says it: when the four watch-fires burn, the hunt is over and the gate is
	raised. The board can be read (a page on the screen).

	PITCH. `PitchPots` pots stand in `PitchPots` of the nine Pitch marks, rolled each run. A short hold takes one into the
	pack (`pitch`).

	THE FIRES. Each of the four is cold, its old wood wet. Hold to pour a pot of pitch on it; hold again to light it from your
	lantern (your lantern is opened to do it). It CATCHES for `CatchSeconds`, growing, and its flare is seen across the wood by
	the Huntsman; then it BURNS for the rest of the run: inside its glow a light is not seen and he will not come. Each fire
	that catches wakes `RisePerFire` dead in the leaves near it (more with more players). When the fourth burns, far off the
	gate groans up: the task is done.

	THE HUNTSMAN (`Trial/Huntsman`) walks from the moment the trial starts. He is not stopped when the task is done: he keeps
	the wood until nobody is in it any more.

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local BackpackService = require(script.Parent.Parent.BackpackService)
local EnemyService = require(script.Parent.Parent.EnemyService)
local EnemyAIService = require(script.Parent.Parent.EnemyAIService)
local LanternService = require(script.Parent.Parent.LanternService)
local Config = require(ReplicatedStorage.Shared.Config)
local Scaling = require(ReplicatedStorage.Shared.Scaling)
local Util = require(script.Parent.Util)
local Read = require(script.Parent.Read)
local Cue = require(script.Parent.Cue)
local Huntsman = require(script.Parent.Huntsman)

local Forest = {}

local MARKS = "Decorations.Area6.Forest.Marks."
-- the dead that wake in the leaves (a shambler wears a guard's or a cook's body, picked at spawn)
local RISERS = { "undead_shambler", "undead_shambler", "undead_shambler", "undead_runner" }

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- a clay pot of black pitch with a rope round its neck
local function pot(parent: Instance, at: Vector3): Model
	local m = Instance.new("Model")
	m.Name = "PitchPot"
	m.Parent = parent
	local clay = Color3.fromRGB(122, 84, 58)
	part(m, "Body", Vector3.new(1.3, 1.5, 1.5), CFrame.new(at + Vector3.new(0, 0.7, 0)) * CFrame.Angles(0, 0, math.rad(90)), clay, Enum.Material.Slate, Enum.PartType.Cylinder)
	part(m, "Neck", Vector3.new(0.4, 1, 1), CFrame.new(at + Vector3.new(0, 1.55, 0)) * CFrame.Angles(0, 0, math.rad(90)), clay:Lerp(Color3.new(0, 0, 0), 0.2), Enum.Material.Slate, Enum.PartType.Cylinder)
	local tar = part(m, "Pitch", Vector3.new(0.08, 0.85, 0.85), CFrame.new(at + Vector3.new(0, 1.76, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(14, 12, 10), Enum.Material.Glass, Enum.PartType.Cylinder)
	tar.Reflectance = 0.15
	part(m, "Rope", Vector3.new(0.14, 1.14, 1.14), CFrame.new(at + Vector3.new(0, 1.35, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 128, 90), Enum.Material.Fabric, Enum.PartType.Cylinder)
	-- a drip down its side
	part(m, "Drip", Vector3.new(0.12, 0.7, 0.2), CFrame.new(at + Vector3.new(0.72, 1.2, 0)), Color3.fromRGB(14, 12, 10), Enum.Material.Glass)
	return m
end

function Forest.create(ctx: any, def: any)
	local cfg = Config.get("Forest")
	local F = cfg.Fire
	local rng = Random.new()
	local connections: { RBXScriptConnection } = {}
	local running = false
	local finished = false
	local litCount = 0
	local glowing: { Vector3 } = {} -- the fires that burn (and are safe)
	local fires: { [string]: any } = {}
	local risers: { string } = {}

	local hunter = Huntsman.create(ctx, cfg, function()
		return glowing
	end)

	local function mark(name: string): Instance?
		return Util.find(MARKS .. name)
	end

	local function scaling(): any
		return Scaling.combine(Scaling.forPlayers(#Players:GetPlayers()), Scaling.forArea(ctx.area))
	end

	-- dead in the leaves near `at`: at the Rise marks nearest it
	local function rise(at: Vector3)
		local marksFolder = Util.find("Decorations.Area6.Forest.Marks")
		if not marksFolder then
			return
		end
		local spots: { Vector3 } = {}
		for _, m in marksFolder:GetChildren() do
			if string.match(m.Name, "^Rise%d+$") and m:IsA("BasePart") then
				table.insert(spots, m.Position)
			end
		end
		table.sort(spots, function(a, b)
			return (a - at).Magnitude < (b - at).Magnitude
		end)
		local s = scaling()
		local count = math.max(1, math.round(cfg.RisePerFire * s.enemyCountMult))
		for i = 1, count do
			local spot = spots[((i - 1) % math.min(3, #spots)) + 1]
			if spot then
				local p = spot + Vector3.new(rng:NextNumber(-4, 4), 0, rng:NextNumber(-4, 4))
				-- the floor is the mark's (a ray from above could land on a trunk)
				local ok, idOrErr = pcall(EnemyService.spawn, RISERS[rng:NextInteger(1, #RISERS)], p, s.enemyHealthMult, spot.Y - 0.5)
				if ok then
					table.insert(risers, idOrErr)
					-- the dark makes the dead nearsighted too
					pcall(EnemyAIService.tune, idOrErr, { detection = 34, leash = 120, spawnPosition = p })
				else
					ctx.warn("forest: a riser would not spawn: " .. tostring(idOrErr))
				end
			end
		end
	end

	--======================================================================
	-- The fires
	--======================================================================
	local function setUpFire(fireDef: any)
		local m = mark("Fire_" .. fireDef.id)
		if not m then
			ctx.warn("forest: no mark Fire_" .. fireDef.id)
			return
		end
		local at = Util.position(m)
		local state = "cold"
		local anchor = part(ctx.folder, "Fire_" .. fireDef.id, Vector3.new(1, 1, 1), CFrame.new(at - Vector3.new(0, 0.8, 0)), Color3.new(), Enum.Material.SmoothPlastic)
		anchor.Transparency = 1
		local prompt = Util.prompt(ctx.folder, at + Vector3.new(0, 0.6, 0), "FirePrompt_" .. fireDef.id, "Pour pitch", "Watch-fire", F.PourHold, 9)
		fires[fireDef.id] = { at = at, state = function(): string
			return state
		end }

		local function catchFire(by: Player)
			state = "catching"
			prompt.Enabled = false
			LanternService.setCovered(by, false)
			Cue.play(at, cfg.Sounds.Catch)
			hunter.flare(at, F.CatchSeconds)
			ctx.note(("%s lights the fire at %s. It is catching: everything in the wood can see it."):format(by.Name, fireDef.name), 4)
			local f, l = Util.flame(anchor, 1.5, 6)
			l.Color = F.Color
			l.Shadows = false
			-- it grows
			local grow = TweenInfo.new(F.CatchSeconds, Enum.EasingStyle.Quad, Enum.EasingDirection.Out)
			TweenService:Create(f, grow, { Size = 8, Heat = 12 }):Play()
			TweenService:Create(l, grow, { Range = F.Range, Brightness = F.Brightness }):Play()
			rise(at)
			task.delay(F.CatchSeconds, function()
				if not running then
					return
				end
				state = "lit"
				table.insert(glowing, at)
				litCount += 1
				ctx.progress(litCount, #cfg.Fires)
				if litCount >= #cfg.Fires and not finished then
					finished = true
					Cue.play(cfg.WayOut, cfg.Sounds.Gate)
					ctx.note("Four fires burn. Far off, a gate groans up.", 5)
					ctx.done()
				else
					ctx.note(("The fire at %s burns. %d of %d."):format(fireDef.name, litCount, #cfg.Fires), 3.5)
				end
			end)
		end

		table.insert(connections, prompt.Triggered:Connect(function(player: Player)
			if state == "cold" then
				if BackpackService.count(player, F.Item) <= 0 then
					ctx.note("The wood in it is old and wet. It will not take without pitch.", 3.5)
					return
				end
				pcall(BackpackService.remove, player, F.Item, 1)
				state = "poured"
				Cue.play(at, cfg.Sounds.Pour)
				-- the wood goes black and wet with it; the prompt now lights it
				local basket = Util.find("Decorations.Area6.Forest.Places.WatchFire_" .. fireDef.id)
				if basket then
					for _, d in basket:GetChildren() do
						if d.Name == "Wood" and d:IsA("BasePart") then
							d.Color = Color3.fromRGB(16, 13, 11)
							d.Material = Enum.Material.Glass
							d.Reflectance = 0.12
						end
					end
				end
				prompt.ActionText = "Light it"
				prompt.HoldDuration = F.LightHold
				ctx.note(("%s pours the pitch. Now a flame."):format(player.Name), 3)
			elseif state == "poured" then
				if not LanternService.has(player) then
					ctx.note("You have nothing to light it with.", 3)
					return
				end
				catchFire(player)
			end
		end))
		-- development: pour and light it at once, as `by`
		fires[fireDef.id].force = function(by: Player)
			if state == "cold" or state == "poured" then
				catchFire(by)
			end
		end
	end

	--======================================================================
	-- Pitch
	--======================================================================
	local function setUpPitch()
		local spots = {}
		for i = 1, #cfg.PitchSpots do
			table.insert(spots, i)
		end
		-- shuffle, and take as many as there are pots
		for i = #spots, 2, -1 do
			local j = rng:NextInteger(1, i)
			spots[i], spots[j] = spots[j], spots[i]
		end
		for k = 1, math.min(cfg.PitchPots, #spots) do
			local m = mark("Pitch" .. spots[k])
			if m then
				local at = Util.position(m) - Vector3.new(0, 0.8, 0)
				local model = pot(ctx.folder, at)
				local prompt = Util.prompt(ctx.folder, at + Vector3.new(0, 1.6, 0), "PitchPrompt" .. spots[k], "Take", "Pot of Pitch", cfg.PitchHold, 8)
				local taken = false
				table.insert(connections, prompt.Triggered:Connect(function(player: Player)
					if taken then
						return
					end
					taken = true
					BackpackService.add(player, F.Item, 1, true)
					model:Destroy()
					local anchor = prompt.Parent
					if anchor then
						anchor:Destroy()
					end
					ctx.note(("%s takes a pot of pitch."):format(player.Name), 2.5)
				end))
			else
				ctx.warn("forest: no mark Pitch" .. spots[k])
			end
		end
	end

	return {
		start = function()
			if running then
				return
			end
			if not mark("Board") then
				ctx.warn("forest: not built (run tools/BuildForest.luau); the gate opens without it")
				ctx.done()
				return
			end
			running = true
			-- the gamekeepers' rule, on their board
			Read.place(ctx, MARKS .. "Board", cfg.Rule.title, cfg.Rule.sign, function()
				return cfg.Rule.lines
			end, function() end)
			setUpPitch()
			for _, f in cfg.Fires do
				setUpFire(f)
			end
			ctx.progress(0, #cfg.Fires)
			-- the Huntsman, by his lodge, on his round
			local stops: { Vector3 } = {}
			for i = 1, #cfg.Huntsman.Round do
				local m = mark("Round" .. i)
				if m then
					table.insert(stops, Util.position(m))
				end
			end
			local spawnMark = mark("HuntsmanSpawn")
			local at = if spawnMark then Util.position(spawnMark) else cfg.Huntsman.Spawn
			hunter.start(at, stops, scaling().enemyHealthMult)
		end,

		-- The errand is done or the run is over. The prompts go; the fires that burn keep burning; the Huntsman keeps the
		-- wood until nobody is in it.
		stop = function()
			running = false
			for _, c in connections do
				c:Disconnect()
			end
			connections = {}
			task.spawn(function()
				local empty = 0
				while hunter.isRunning() do
					task.wait(2)
					local anyone = false
					for _, p in Players:GetPlayers() do
						local root = p.Character and p.Character:FindFirstChild("HumanoidRootPart")
						if root and root:IsA("BasePart") and cfg.contains(root.Position) then
							anyone = true
						end
					end
					empty = if anyone then 0 else empty + 2
					if empty >= 10 then
						hunter.stop()
					end
				end
			end)
		end,

		progress = function(): (number, number)
			return litCount, #cfg.Fires
		end,

		dev = {
			state = function(): string
				local brain = hunter.brain()
				local m = hunter.model()
				return ("lit=%d huntsman=%s at %s"):format(litCount, if brain then brain.state else "none", if m then tostring(m:GetPivot().Position) else "-")
			end,
			grant = function(player: Player, itemId: string, n: number?)
				BackpackService.add(player, itemId, n or 1, true)
			end,
			hunter = function(): any
				return hunter
			end,
			fires = function(): any
				return fires
			end,
		},
	}
end

return Forest
