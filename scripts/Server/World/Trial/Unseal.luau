--!strict
--[[
	Trial task: `unseal`
	The keep is shut and barred until the King is released (AreaPlan §9). When he is, the door answers
	from behind itself: the bar that lies across the two leaves is lifted out of its staples by something
	that is not a hand, tips, and falls to the landing; the two leaves of oak and iron swing slowly inward
	on their hinges, a leaf at a time, the hall's cold coming out over the sill; and a line of pale chevrons
	comes up out of the ground along the court and the Steps, one after another toward the door ("an arrow
	appears on the ground pointing the way in").

	Door mechanisms need real animation, not parts sliding sideways: it has weight. The bar goes first and
	loudly; the leaves are heavy and start slowly, run on, and settle against the hall wall with a shudder
	of dust. Each leaf is a Model pivoted about its hinge (the `Hinge` attribute the keep builder sets).

	The task is done when somebody walks through the door and into the hall.

	Params (configs/Trials):
	  door      dotted path of the Model of the two leaves (Interior.KeepDoor)
	  seal      dotted path of the invisible seal part that holds the way shut (Keep.KeepDoor)
	  bar       dotted path of the bar across the door (Keep.Bar)
	  from      marker path where the chevrons begin (the middle of the court)
	  to        dotted path of the part the chevrons lead to (the keep landing)

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Markers = require(ReplicatedStorage.Shared.World.Markers)
local Util = require(script.Parent.Util)

local Unseal = {}

local rng = Random.new()

local function puff(parent: Instance, at: Vector3, count: number, spread: number)
	local anchor = Instance.new("Part")
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(spread, 1, spread)
	anchor.Position = at
	anchor.Parent = parent
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(150, 138, 120))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.5), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 8) })
	e.Lifetime = NumberRange.new(1.4, 2.6)
	e.Speed = NumberRange.new(2, 9)
	e.SpreadAngle = Vector2.new(70, 70)
	e.Drag = 2
	e.Rate = count / 0.15
	e.Parent = anchor
	task.delay(0.15, function()
		e.Enabled = false
	end)
	task.delay(3.5, function()
		anchor:Destroy()
	end)
end

local function easeInOut(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

local function run(duration: number, step: (number) -> ())
	local started = os.clock()
	while true do
		local a = (os.clock() - started) / duration
		if a >= 1 then
			step(1)
			return
		end
		step(a)
		RunService.Heartbeat:Wait()
	end
end

function Unseal.create(ctx: any, def: any)
	local connections: { any } = {}
	local ticker: RBXScriptConnection? = nil
	local opened = false
	local chevrons: { Part } = {}
	local alive = true

	local function swing(leaf: Model, seconds: number, degrees: number, delay: number)
		task.wait(delay)
		local hinge = leaf:GetAttribute("Hinge") :: Vector3
		local side = leaf:GetAttribute("Side") :: number
		local home = leaf:GetPivot()
		local hingeCf = CFrame.new(hinge)
		-- left leaf (side -1) turns +, right leaf turns -, so both go inward (-z)
		local sign = if side < 0 then 1 else -1
		run(seconds, function(a)
			-- slow to start (the weight), fast through the middle, a settle at the end
			local e = easeInOut(a)
			local overshoot = math.sin(a * math.pi) * 0.02 * (if a > 0.7 then 1 else 0)
			local angle = math.rad((degrees + degrees * overshoot) * e) * sign
			leaf:PivotTo(hingeCf * CFrame.Angles(0, angle, 0) * hingeCf:Inverse() * home)
		end)
		puff(ctx.folder, Vector3.new(hinge.X - side * 3.8, 21, hinge.Z - 5), 14, 6)
	end

	local function liftBar(bar: BasePart)
		local home = bar.CFrame
		-- up out of the staples, a tilt as one end comes free, and over
		run(1.1, function(a)
			local e = easeInOut(a)
			bar.CFrame = home * CFrame.new(0, 2.4 * e, 0) * CFrame.Angles(0, 0, math.rad(-14 * e))
		end)
		task.wait(0.25)
		local start = bar.CFrame
		local fall = Vector3.new(0, -(start.Position.Y - 20.9), 3.6)
		run(0.55, function(a)
			bar.CFrame = start * CFrame.new(fall.X * a, fall.Y * a * a, fall.Z * a) * CFrame.Angles(0, 0, math.rad(-70 * a))
		end)
		puff(ctx.folder, Vector3.new(start.Position.X, 21, start.Position.Z + 3.6), 20, 10)
		bar.CanCollide = false
		TweenService:Create(bar, TweenInfo.new(0.2), { Transparency = 0 }):Play()
	end

	local function laySigns(from: Vector3, to: Vector3)
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Exclude
		params.FilterDescendantsInstances = { ctx.folder }
		local dir = Vector3.new(to.X - from.X, 0, to.Z - from.Z)
		local length = dir.Magnitude
		if length < 1 then
			return
		end
		local unit = dir.Unit
		local n = math.floor(length / 7)
		for i = 0, n do
			local p = from + unit * (i * 7)
			local hit = Workspace:Raycast(Vector3.new(p.X, to.Y + 30, p.Z), Vector3.new(0, -80, 0), params)
			if hit then
				local at = hit.Position + hit.Normal * 0.2
				local chevron = Instance.new("Model")
				chevron.Name = "Chevron"
				local parts: { Part } = {}
				for _, s in { -1, 1 } do
					local bar = Instance.new("Part")
					bar.Anchored = true
					bar.CanCollide = false
					bar.CanQuery = false
					bar.CanTouch = false
					bar.Material = Enum.Material.Neon
					bar.Color = Color3.fromRGB(206, 230, 255)
					bar.Transparency = 1
					bar.Size = Vector3.new(0.5, 0.12, 4.2)
					-- lie on the surface, point along `unit`, the two arms swept back
					local flat = CFrame.lookAt(at, at + unit)
					local up = hit.Normal
					local look = (unit - up * unit:Dot(up)).Unit
					local base = CFrame.lookAt(at, at + look, up)
					bar.CFrame = base * CFrame.new(s * 1.4, 0, 1.4) * CFrame.Angles(0, s * math.rad(38), 0)
					bar.Parent = chevron
					table.insert(parts, bar)
					table.insert(chevrons, bar)
				end
				chevron.Parent = ctx.folder
				-- they come up one after another toward the door
				task.delay(i * 0.35, function()
					for _, bar in parts do
						TweenService:Create(bar, TweenInfo.new(0.8), { Transparency = 0.15 }):Play()
					end
				end)
			end
		end
	end

	local function pulse()
		-- a slow wave of light along the signs, toward the door
		task.spawn(function()
			while alive do
				for i, bar in chevrons do
					task.delay((i // 2) * 0.12, function()
						if bar.Parent then
							TweenService:Create(bar, TweenInfo.new(0.45, Enum.EasingStyle.Sine, Enum.EasingDirection.InOut, 0, true), { Transparency = 0.55 }):Play()
						end
					end)
				end
				task.wait(4.5)
			end
		end)
	end

	return {
		start = function()
			local door = Util.find(def.door)
			local seal = Util.find(def.seal)
			local bar = Util.find(def.bar)
			local landing = Util.find(def.to)
			local fromAt = Markers.resolve(def.from)
			if not (door and landing and fromAt) then
				ctx.warn("unseal: missing door, landing or start")
				return
			end
			local leafL = door:FindFirstChild("LeafL") :: Model?
			local leafR = door:FindFirstChild("LeafR") :: Model?
			if not (leafL and leafR) then
				ctx.warn("unseal: the door has no leaves")
				return
			end

			ctx.note("Behind the keep's door, iron moves.", 5)
			task.spawn(function()
				task.wait(2.2)
				if bar and bar:IsA("BasePart") then
					liftBar(bar)
				end
				if seal and seal:IsA("BasePart") then
					seal.CanCollide = false
				end
				ctx.note("The bar is lifted out of its staples by nothing. The door gives.", 4)
				task.spawn(swing, leafL :: Model, 4.2, 104, 0)
				task.spawn(swing, leafR :: Model, 4.0, 100, 0.9)
				task.wait(3.2)
				local landingPart = landing :: BasePart
				laySigns(Vector3.new(fromAt.X, 2, fromAt.Z), Vector3.new(landingPart.Position.X, landingPart.Position.Y + landingPart.Size.Y / 2, landingPart.Position.Z))
				pulse()
				opened = true
				ctx.hint("Go in. The way is lit.")
			end)

			ticker = RunService.Heartbeat:Connect(function()
				if not opened then
					return
				end
				for _, player in Players:GetPlayers() do
					local character = player.Character
					local root = character and character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						local p = root.Position
						if math.abs(p.X) < 26 and p.Z < -2167 and p.Z > -2210 and p.Y > 18 and p.Y < 30 then
							opened = false
							ctx.hint(nil)
							ctx.done()
							return
						end
					end
				end
			end)
		end,

		stop = function()
			alive = false
			if ticker then
				ticker:Disconnect()
				ticker = nil
			end
			-- the signs fade; the door stays open for good
			for _, bar in chevrons do
				if bar.Parent then
					TweenService:Create(bar, TweenInfo.new(2.5), { Transparency = 1 }):Play()
				end
			end
		end,

		progress = function(): (number, number)
			return if opened then 1 else 0, 1
		end,
	}
end

return Unseal
