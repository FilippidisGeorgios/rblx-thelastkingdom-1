--!strict
--[[
	Trial deed: `mangonel`
	The camp's siege engine stands broken in the Inner Ward: the long arm has
	come off its axle and lies on the ground behind it, and the machine is a
	counterweight trebuchet of the old pattern (a great beam on an axle, a long
	arm with a sling, a short arm with a hanging weight). Put it right and it
	throws a stone at the thickest knot of the dead, which is the whole reason a
	crew would want it, and the reason a party holding the line might.

	IT TAKES A CREW'S WORTH OF STEPS, IN ORDER, ALL OF THEM WITH THE HANDS
	  1. SEAT the arm       the beam is lifted off the ground and dropped into
	                        the axle; the weight hangs, the long arm stands up.
	  2. WIND               the windlass at the back draws the long arm down
	                        against the weight, click by click (the ratchet);
	                        the weight rises as the arm falls.
	  3. LOAD               a stone from the heap (one in the hands at a time)
	                        into the sling at the end of the arm.
	  4. LOOSE              pull the pin. The weight drops, the arm whips over,
	                        the stone leaves the sling at the top of the throw
	                        and comes down on the densest cluster of the dead in
	                        front of the engine, anywhere from forty to a
	                        hundred and fifty studs away.

	THE FIRST THROW IS THE DEED: it pays its prize. There are only a few stones.

	THE STONE FALLS WHERE THE DEAD ARE, BY THE WORLD'S OWN SIGHTING: the crew's
	chalk marks are on the rails, and the ones who stand at the pin only choose
	WHEN. It is not a cannon you aim; it is a thing you choose the moment of, with
	the line breaking in front of you, and then it is a very good moment.

	Params (configs/Trials):
	  model        dotted path of the mangonel model (parts named Axle, Arm x2, Counterweight, Shot)
	  stones       how many stones there are in all (the engine's own Shot is one)
	  splash       radius of the blow, studs
	  damage       at the centre (half that at the rim)
	  minRange, maxRange
	  prize        a configs/Loot table, paid for the first throw

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local BackpackService = require(script.Parent.Parent.BackpackService)
local CombatService = require(script.Parent.Parent.CombatService)
local LootService = require(script.Parent.Parent.LootService)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Util = require(script.Parent.Util)

local Mangonel = {}

local rng = Random.new()

local ARM_LONG = 11.2
local ARM_SHORT = 5.2
local PHI_REST = math.rad(80) -- arm standing up, weight hanging
local PHI_COCKED = math.rad(215) -- arm down at the back, weight high
local PHI_RELEASE = math.rad(128) -- where the stone leaves the sling, going up and forward
local STONE = "mangonel_stone"

local OAK = Color3.fromRGB(78, 58, 40)
local OAK_PALE = Color3.fromRGB(104, 80, 54)
local IRON = Color3.fromRGB(52, 46, 42)
local ROPE = Color3.fromRGB(150, 124, 86)
local GREY = Color3.fromRGB(96, 92, 86)

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
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if shape then
		p.Shape = shape
	end
	p.Parent = parent
	return p
end

local function puff(parent: Instance, at: Vector3, count: number, spread: number, color: Color3?)
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
	e.Color = ColorSequence.new(color or Color3.fromRGB(120, 108, 92))
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.45), NumberSequenceKeypoint.new(0.6, 0.75), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2.2), NumberSequenceKeypoint.new(1, 9) })
	e.Lifetime = NumberRange.new(1.2, 2.4)
	e.Speed = NumberRange.new(4, 16)
	e.SpreadAngle = Vector2.new(75, 75)
	e.Acceleration = Vector3.new(0, 1.5, 0)
	e.Drag = 1.8
	e.Rate = count / 0.12
	e.Parent = anchor
	task.delay(0.12, function()
		e.Enabled = false
	end)
	task.delay(3.4, function()
		anchor:Destroy()
	end)
end

local function smooth(a: number): number
	a = math.clamp(a, 0, 1)
	return a * a * (3 - 2 * a)
end

local function unit(phi: number): Vector3
	return Vector3.new(0, math.sin(phi), math.cos(phi))
end

function Mangonel.create(ctx: any, def: any)
	local model = Util.find(def.model)
	local connections: { any } = {}
	local state = "broken" -- broken | rest | winding | cocked | loaded | firing
	local thrown = 0
	local stonesLeft = def.stones

	local longArm: BasePart? = nil
	local shortArm: BasePart? = nil
	local counter: BasePart? = nil
	local axle: BasePart? = nil
	local shot: BasePart? = nil
	local pivot = Vector3.zero
	local home: { [string]: CFrame } = {}

	local drum: Model? = nil
	local drumAt = Vector3.zero
	local rope: Part? = nil
	local sling: Part? = nil
	local prompts: { [string]: ProximityPrompt } = {}
	local stoneParts: { Part } = {}
	local phi = 0
	local drumTurns = 0
	local wind: () -> ()

	--======================================================================
	-- The pose of the beam at an angle
	--======================================================================
	local function pose(angle: number)
		local u = unit(angle)
		local shortEnd = pivot - u * ARM_SHORT
		return {
			long = CFrame.lookAt(pivot + u * (ARM_LONG / 2), pivot + u * ARM_LONG),
			short = CFrame.lookAt(pivot - u * (ARM_SHORT / 2), pivot - u * ARM_SHORT),
			counter = CFrame.new(shortEnd + Vector3.new(0, -1.9, 0)),
			tip = pivot + u * ARM_LONG,
		}
	end

	local function applyAngle(angle: number)
		phi = angle
		local p = pose(angle)
		if longArm then
			longArm.CFrame = p.long
		end
		if shortArm then
			shortArm.CFrame = p.short
		end
		if counter then
			counter.CFrame = p.counter
		end
		if sling then
			-- the sling: a short strap trailing from the tip, with the pouch at its end
			sling.CFrame = CFrame.new(p.tip + Vector3.new(0, -0.9, 0)) * CFrame.Angles(math.rad(90), 0, 0)
		end
		if rope and rope.Parent then
			local from = drumAt + Vector3.new(0, 0.9, 0)
			local delta = p.tip - from
			rope.Size = Vector3.new(0.22, 0.22, math.max(0.5, delta.Magnitude))
			rope.CFrame = CFrame.lookAt(from + delta / 2, p.tip)
			rope.Transparency = if state == "firing" then 0.35 else 0
		end
		if drum then
			drum:PivotTo(CFrame.new(drumAt) * CFrame.Angles(drumTurns, 0, 0))
		end
	end

	local function runTween(duration: number, step: (number) -> ())
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

	--======================================================================
	-- The stones
	--======================================================================
	local function stonePositions(): { Vector3 }
		local at = if shot then shot.Position else pivot + Vector3.new(3.6, -7.5, -3.6)
		return {
			at,
			at + Vector3.new(8.2, 0.0, 4.6),
			at + Vector3.new(9.6, 0.0, -1.8),
			at + Vector3.new(6.6, 0.0, -7.4),
		}
	end

	local function setPrompt(name: string, enabled: boolean)
		local p = prompts[name]
		if p then
			p.Enabled = enabled
		end
	end

	local function refreshPrompts()
		setPrompt("seat", state == "broken")
		setPrompt("wind", state == "rest" and drum ~= nil)
		setPrompt("load", state == "cocked")
		setPrompt("fire", state == "loaded")
	end

	--======================================================================
	-- The throw
	--======================================================================
	local function targetFor(origin: Vector3): (Vector3, number)
		local minRange, maxRange = def.minRange, def.maxRange
		local best: Vector3? = nil
		local bestCount = 0
		local entities = CombatService.getAllEntities()
		local points: { Vector3 } = {}
		for _, e in entities do
			if e.faction == "Enemies" and e.model then
				local pos = (e.model :: Model):GetPivot().Position
				local flat = Vector3.new(pos.X - origin.X, 0, pos.Z - origin.Z)
				if flat.Magnitude >= minRange and flat.Magnitude <= maxRange and flat.Z > 0 then
					table.insert(points, pos)
				end
			end
		end
		for _, a in points do
			local sum, count = Vector3.zero, 0
			for _, b in points do
				if (a - b).Magnitude <= def.splash then
					sum += b
					count += 1
				end
			end
			if count > bestCount then
				bestCount = count
				best = sum / count
			end
		end
		if best then
			return best, bestCount
		end
		return origin + Vector3.new(rng:NextNumber(-6, 6), -7, 62), 0
	end

	local function impact(at: Vector3, player: Player)
		puff(ctx.folder, at + Vector3.new(0, 1, 0), 60, 8)
		puff(ctx.folder, at + Vector3.new(0, 0.5, 0), 30, 14, Color3.fromRGB(86, 74, 60))
		-- the stone breaks: a ring of pieces thrown out and let lie
		for _ = 1, 9 do
			local piece = part(ctx.folder, "Shard", Vector3.new(rng:NextNumber(0.7, 1.6), rng:NextNumber(0.5, 1.2), rng:NextNumber(0.7, 1.6)), CFrame.new(at + Vector3.new(0, 1, 0)), GREY, Enum.Material.Slate)
			local angle = rng:NextNumber(0, math.pi * 2)
			local reach = rng:NextNumber(4, 12)
			local land = at + Vector3.new(math.cos(angle) * reach, 0.4, math.sin(angle) * reach)
			TweenService:Create(piece, TweenInfo.new(0.7, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), { CFrame = CFrame.new(land) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), rng:NextNumber(0, 3)) }):Play()
			task.delay(14, function()
				piece:Destroy()
			end)
		end
		local source = Constants.CombatId.PlayerPrefix .. player.UserId
		for _, e in CombatService.getAllEntities() do
			if e.faction == "Enemies" and e.model then
				local d = ((e.model :: Model):GetPivot().Position - at).Magnitude
				if d <= def.splash then
					local falloff = 1 - 0.5 * (d / def.splash)
					CombatService.applyDamage({
						targetId = e.id,
						sourceId = source,
						amount = def.damage * falloff,
						damageType = "Physical",
					})
				end
			end
		end
	end

	local function fly(from: Vector3, to: Vector3, player: Player)
		local stone = part(ctx.folder, "ThrownStone", Vector3.new(2.2, 2.2, 2.2), CFrame.new(from), GREY, Enum.Material.Slate, Enum.PartType.Ball)
		local distance = (to - from).Magnitude
		local duration = math.clamp(distance / 70, 0.9, 2.4)
		local height = math.clamp(distance * 0.3, 12, 36)
		local spin = Vector3.new(rng:NextNumber(-4, 4), rng:NextNumber(-4, 4), rng:NextNumber(-4, 4))
		runTween(duration, function(a)
			local pos = from:Lerp(to, a) + Vector3.new(0, height * 4 * a * (1 - a), 0)
			stone.CFrame = CFrame.new(pos) * CFrame.Angles(spin.X * a * 6, spin.Y * a * 6, spin.Z * a * 6)
		end)
		stone:Destroy()
		impact(to, player)
	end

	local function loose(player: Player)
		if state ~= "loaded" then
			return
		end
		state = "firing"
		refreshPrompts()
		local origin = pose(PHI_COCKED).tip
		local target, cluster = targetFor(pivot)
		local stoneAt: Part? = nil
		-- the stone that sat in the sling goes with the arm
		if sling then
			stoneAt = part(ctx.folder, "SlungStone", Vector3.new(2.2, 2.2, 2.2), CFrame.new(origin), GREY, Enum.Material.Slate, Enum.PartType.Ball)
		end
		-- the pin comes out, the weight drops, the arm whips over
		runTween(0.62, function(a)
			local e = a * a * (0.4 + 0.6 * a)
			local angle = PHI_COCKED + (PHI_RELEASE - PHI_COCKED) * e
			applyAngle(angle)
			if stoneAt then
				stoneAt.CFrame = CFrame.new(pose(angle).tip + Vector3.new(0, -0.8, 0))
			end
		end)
		local releaseAt = pose(PHI_RELEASE).tip
		if stoneAt then
			stoneAt:Destroy()
		end
		task.spawn(fly, releaseAt, target, player)
		-- it carries on over the top and the weight rocks, then it settles
		runTween(0.7, function(a)
			applyAngle(PHI_RELEASE + (PHI_REST - PHI_RELEASE) * smooth(a) + math.sin(a * math.pi * 3) * (1 - a) * math.rad(10))
		end)
		applyAngle(PHI_REST)
		thrown += 1
		state = "rest"
		refreshPrompts()
		if cluster > 0 then
			ctx.note(("The stone falls among %d of them."):format(cluster), 4)
		else
			ctx.note("The stone falls on empty ground. Wait until they are in front of it.", 4)
		end
		if thrown == 1 then
			LootService.grantAll(def.prize, pivot + Vector3.new(-5, 3, -9))
			ctx.note("The engine is sound. Something was left in its ammunition box.", 5)
			ctx.done()
		end
	end

	--======================================================================
	-- The hands' steps
	--======================================================================
	local function seat()
		if state ~= "broken" or not (longArm and shortArm and counter) then
			return
		end
		state = "rest" -- guards a second hold while it moves
		refreshPrompts()
		ctx.note("The arm goes into the axle.", 3)
		local from = { long = longArm.CFrame, short = shortArm.CFrame, counter = counter.CFrame }
		local to = pose(PHI_REST)
		longArm.CanCollide = false
		runTween(2.2, function(a)
			local e = smooth(a)
			;(longArm :: BasePart).CFrame = from.long:Lerp(to.long, e) + Vector3.new(0, 7 * math.sin(e * math.pi), 0)
			;(shortArm :: BasePart).CFrame = from.short:Lerp(to.short, e)
			;(counter :: BasePart).CFrame = from.counter:Lerp(to.counter, e)
		end)
		applyAngle(PHI_REST)
		puff(ctx.folder, pivot + Vector3.new(0, -2, 0), 14, 6)

		-- the windlass, at the back, and the rope from it to the tip of the arm
		drumAt = Vector3.new(pivot.X, pivot.Y - 6.6, pivot.Z - 13.8)
		local d = Instance.new("Model")
		d.Name = "Windlass"
		d.Parent = ctx.folder
		for _, side in { -1, 1 } do
			part(d, "Cheek", Vector3.new(0.6, 2.8, 3), CFrame.new(drumAt + Vector3.new(side * 2.5, 0.0, 0)), OAK, Enum.Material.Wood)
			part(d, "Upright", Vector3.new(0.9, 3.4, 0.9), CFrame.new(drumAt + Vector3.new(side * 2.7, -1.3, 1.1)) * CFrame.Angles(math.rad(14), 0, 0), OAK, Enum.Material.Wood)
			part(d, "Upright", Vector3.new(0.9, 3.4, 0.9), CFrame.new(drumAt + Vector3.new(side * 2.7, -1.3, -1.1)) * CFrame.Angles(math.rad(-14), 0, 0), OAK, Enum.Material.Wood)
		end
		local turning = Instance.new("Model")
		turning.Name = "Drum"
		turning.Parent = d
		local barrel = part(turning, "Barrel", Vector3.new(4.6, 1.8, 1.8), CFrame.new(drumAt), OAK_PALE, Enum.Material.Wood, Enum.PartType.Cylinder)
		for i = -2, 2 do
			part(turning, "Wound", Vector3.new(0.5, 2.1, 2.1), CFrame.new(drumAt + Vector3.new(i * 0.8, 0, 0)), ROPE, Enum.Material.Fabric, Enum.PartType.Cylinder)
		end
		for i = 0, 7 do
			local a = i * math.pi / 4
			part(turning, "Tooth", Vector3.new(0.5, 0.5, 0.5), CFrame.new(drumAt + Vector3.new(2.15, math.cos(a) * 1.35, math.sin(a) * 1.35)), IRON, Enum.Material.CorrodedMetal)
		end
		for _, dir in { 1, -1 } do
			part(turning, "Spoke", Vector3.new(0.5, 0.5, 3.6), CFrame.new(drumAt + Vector3.new(-3.1, 0, 0)) * CFrame.Angles(0, 0, math.rad(if dir == 1 then 0 else 90)) , OAK, Enum.Material.Wood)
		end
		barrel.Name = "Barrel"
		turning.PrimaryPart = barrel
		drum = turning
		drumTurns = 0
		rope = part(ctx.folder, "WindlassRope", Vector3.new(0.22, 0.22, 4), CFrame.new(drumAt), ROPE, Enum.Material.Fabric)
		sling = part(ctx.folder, "Sling", Vector3.new(0.3, 1.8, 0.3), CFrame.new(pose(PHI_REST).tip), ROPE, Enum.Material.Fabric)
		applyAngle(PHI_REST)

		local windPrompt = Util.prompt(ctx.folder, drumAt + Vector3.new(0, 2.6, 2.4), "WindPrompt", "Wind", "Windlass", 0.5, 6.5)
		prompts.wind = windPrompt
		table.insert(connections, windPrompt.Triggered:Connect(function()
			wind()
		end))
		state = "rest"
		refreshPrompts()
		ctx.note("The windlass is sound. Wind it, bring a stone, pull the pin.", 4)
	end

	wind = function()
		if state ~= "rest" then
			return
		end
		state = "winding"
		refreshPrompts()
		local clicks = 16
		local startTurns = drumTurns
		runTween(def.windSeconds or 4, function(a)
			-- the ratchet: it moves in clicks, and each click stops for a moment
			local scaled = a * clicks
			local whole = math.floor(scaled)
			local frac = scaled - whole
			local stepped = (whole + smooth(math.clamp(frac * 2.2, 0, 1))) / clicks
			applyAngle(PHI_REST + (PHI_COCKED - PHI_REST) * math.min(1, stepped))
			drumTurns = startTurns - stepped * math.pi * 4
		end)
		applyAngle(PHI_COCKED)
		state = "cocked"
		refreshPrompts()
		puff(ctx.folder, pose(PHI_COCKED).tip + Vector3.new(0, -2, 0), 6, 3)
		ctx.note("Cocked. A stone for the sling.", 3)
	end

	local function load(player: Player)
		if state ~= "cocked" then
			return
		end
		if BackpackService.count(player, STONE) <= 0 then
			ctx.note("The sling is empty. There are stones heaped by the right wheel.", 3)
			return
		end
		BackpackService.remove(player, STONE, 1)
		state = "loaded"
		refreshPrompts()
		local tip = pose(PHI_COCKED).tip
		local held = part(ctx.folder, "LoadedStone", Vector3.new(2.2, 2.2, 2.2), CFrame.new(tip + Vector3.new(0, -0.8, 0)), GREY, Enum.Material.Slate, Enum.PartType.Ball)
		task.delay(0.1, function()
			held:Destroy()
		end)
		ctx.note("Loaded. The pin is at the front of the frame.", 3)
	end

	--======================================================================
	return {
		start = function()
			if not model then
				ctx.warn("mangonel: no model at " .. tostring(def.model))
				return
			end
			for _, d in model:GetDescendants() do
				if d:IsA("BasePart") then
					if d.Name == "Axle" then
						axle = d
					elseif d.Name == "Counterweight" then
						counter = d
					elseif d.Name == "Shot" then
						shot = d
					elseif d.Name == "Arm" then
						if d.Size.Z > 8 then
							longArm = d
						else
							shortArm = d
						end
					end
				end
			end
			if not (axle and longArm and shortArm and counter) then
				ctx.warn("mangonel: the model is missing parts")
				return
			end
			pivot = (axle :: BasePart).Position
			for _, p in { longArm, shortArm, counter } do
				(p :: BasePart).CanCollide = false
			end

			-- 1. the arm on the ground
			local seatPrompt = Util.prompt(ctx.folder, (longArm :: BasePart).Position + Vector3.new(0, 3.2, 0), "SeatPrompt", "Lift the arm", "Fallen throwing arm", 1.8, 8)
			prompts.seat = seatPrompt
			table.insert(connections, seatPrompt.Triggered:Connect(seat))

			-- 3. the loading point, at the end of the arm when it is down
			local loadPrompt = Util.prompt(ctx.folder, pose(PHI_COCKED).tip + Vector3.new(0, 1.6, 0), "LoadPrompt", "Load the sling", "Mangonel", 0.9, 5.5)
			prompts.load = loadPrompt
			table.insert(connections, loadPrompt.Triggered:Connect(load))

			-- 4. the pin
			local firePrompt = Util.prompt(ctx.folder, pivot + Vector3.new(-3.2, -5.2, 3.6), "PinPrompt", "Pull the pin", "Mangonel", 0.6, 6)
			prompts.fire = firePrompt
			table.insert(connections, firePrompt.Triggered:Connect(loose))

			-- the stones, in a heap by the right wheel
			local spots = stonePositions()
			for i = 1, math.min(def.stones, #spots) do
				local at = spots[i]
				local stone: Part
				if i == 1 and shot then
					stone = shot :: Part
				else
					stone = part(ctx.folder, "Stone", Vector3.new(2.2, 2.2, 2.2), CFrame.new(at) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), GREY, Enum.Material.Slate, Enum.PartType.Ball)
				end
				table.insert(stoneParts, stone)
				local prompt = Util.prompt(ctx.folder, stone.Position + Vector3.new(0, 2.4, 0), "TakeStone", "Take", "Stone for the mangonel", 1.0, 4.5)
				table.insert(
					connections,
					prompt.Triggered:Connect(function(player: Player)
						if BackpackService.add(player, STONE, 1, true) > 0 then
							prompt.Enabled = false
							stone.Transparency = 1
							prompt.Parent:Destroy()
							stonesLeft -= 1
							ctx.note("A stone. Heavy. The sling is at the back.", 3)
						else
							ctx.note("You are carrying one already.", 2)
						end
					end)
				)
			end
			refreshPrompts()
		end,

		stop = function() end,

		progress = function(): (number, number)
			return math.min(thrown, 1), 1
		end,
	}
end

return Mangonel
