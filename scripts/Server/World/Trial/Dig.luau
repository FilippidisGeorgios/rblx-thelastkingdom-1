--!strict
--[[
	Trial task: `dig`
	The way out of the Inner Ward is buried. The arch over the passage came down
	when the tower fell, and the mouth of it is a heap of masonry, beams and
	earth thirty feet high. There is one way through it: cut a trench along the
	middle, and prop it as you go.

	HOW IT PLAYS
	Hold E at the face of the cut. You put your sword up (it is sheathed while you
	work: you cannot fight and dig) and swing a pick; the stones in front of you
	come away and are flung aside. LET GO and the heap SLIPS BACK, stone by stone,
	into the trench you have made. The trench is five lengths long. At the end of
	each length you set a timber frame, and a frame holds: the heap cannot slip
	back past the last one you set. The progress bar is the trench.

	  - A PICK (the miner's pick from the mine, chamber 5) is full speed. Without
	    it you can still do it with your hands, at under half the speed. A deed
	    that was skipped costs time, never possibility.
	  - A second pair of hands is worth half a first (the winch's rule): never the
	    difference between possible and not.
	  - ONE length of the trench is packed hard (rolled each run, and you can see
	    it: its boulders are bigger and darker). It digs at half speed.
	  - Being HIT while you dig costs you a moment: you stagger, and the stones
	    you had loosened settle.
	  - Each frame set is a signal ("shore1".."shore4") that the pressure of the
	    chamber listens for: the noise carries.

	THE HEAP IS THE PROGRESS BAR, as the gate is the winch's: nothing is drawn on
	the screen for it.

	WHAT IT BUILDS (at runtime, in the trial's folder)
	  - the static mound: a few score boulders either side of the cut and over it,
	    so the mouth really is buried and the cut is a gallery with a roof;
	  - the corridor's own stones (60 of them: five lengths of twelve), each one
	    flying aside when dug and rolling back when it slips;
	  - four timber frames.

	Params (configs/Trials):
	  seconds    seconds of unbroken pick work for the whole trench, one player
	  bare       speed without a pick, as a fraction (0.45)
	  fall       how fast it slips back, as a fraction of the digging speed (0.8)
	  hands      what each extra pair of hands adds (0.5)

	Place: Forgotten Lands ONLY (Server/World/Trial).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local AreaService = require(script.Parent.Parent.AreaService)
local BackpackService = require(script.Parent.Parent.BackpackService)
local CombatService = require(script.Parent.Parent.CombatService)
local WeaponVisualService = require(script.Parent.Parent.WeaponVisualService)
local Constants = require(ReplicatedStorage.Shared.Constants)
local Config = require(ReplicatedStorage.Shared.Config)
local Util = require(script.Parent.Util)

local Dig = {}

local rng = Random.new()

--==========================================================================
-- The trench and the heap (studs)
--==========================================================================
local CUT_W = 11 -- the trench: wide enough for two to stand shoulder to shoulder
local CUT_H = 9.5
local CUT_LEN = 22 -- five lengths of 4.4
local LENGTHS = 5
local PER_LENGTH = 12 -- four across, three high
local MOUND_W = 50 -- the whole width of the arch, and a little over
local MOUND_H = 36
local FRAMES = LENGTHS - 1

local STONE = {
	Color3.fromRGB(88, 86, 82),
	Color3.fromRGB(102, 98, 92),
	Color3.fromRGB(74, 72, 70),
	Color3.fromRGB(116, 110, 100),
	Color3.fromRGB(94, 88, 80),
}
local EARTH = { Color3.fromRGB(70, 56, 42), Color3.fromRGB(84, 68, 50), Color3.fromRGB(58, 48, 38) }
local OAK = Color3.fromRGB(78, 58, 40)
local OAK_PALE = Color3.fromRGB(104, 80, 54)
local IRON = Color3.fromRGB(58, 52, 48)

--==========================================================================
-- Helpers
--==========================================================================
local function newPart(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, class: string?): Part
	local p = Instance.new(class or "Part") :: Part
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

local function randomRotation(): CFrame
	return CFrame.Angles(math.rad(rng:NextNumber(-25, 25)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-25, 25)))
end

--[[
	A piece of the collapse. A heap that is all one kind of block looks like a
	pile of crates, so the pieces are mixed the way a fallen arch mixes them:
	rough Slate and Cobblestone for the walling, paler cut stone from the arch
	itself (blocks, and wedges: the broken voussoirs), a few column drums, lumps
	of earth, the odd bit of granite. `packed` darkens the lot: the stones in the
	hard length are older and wetter.
]]
local function rock(parent: Instance, name: string, size: Vector3, cf: CFrame, packed: boolean?): Part
	local r = rng:NextNumber()
	local class = "Part"
	local material = Enum.Material.Slate
	local color = STONE[rng:NextInteger(1, #STONE)]
	local drum = false
	if r < 0.12 then
		class = "WedgePart"
		material = Enum.Material.Concrete
		color = Color3.fromRGB(122, 116, 104)
	elseif r < 0.24 then
		material = Enum.Material.Concrete
		color = Color3.fromRGB(116, 110, 100):Lerp(STONE[rng:NextInteger(1, #STONE)], 0.4)
	elseif r < 0.42 then
		material = Enum.Material.Cobblestone
	elseif r < 0.5 then
		material = Enum.Material.Granite
	elseif r < 0.56 then
		drum = true
		material = Enum.Material.Concrete
		color = Color3.fromRGB(120, 114, 102)
	elseif r < 0.74 then
		material = Enum.Material.Mud
		color = EARTH[rng:NextInteger(1, #EARTH)]
	end
	if packed then
		color = color:Lerp(Color3.new(0, 0, 0), 0.3)
	end
	local p = newPart(parent, name, size, cf, color, material, class)
	if drum then
		p.Shape = Enum.PartType.Cylinder
		p.Size = Vector3.new(math.max(size.X, size.Z) * 0.9, math.min(size.X, size.Z) * 1.1, math.min(size.X, size.Z) * 1.1)
	end
	return p
end

-- A short burst of dust, made by creating an emitter that is already running
-- (a ParticleEmitter:Emit on the server does not reach the clients).
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
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(0.6, 0.78), NumberSequenceKeypoint.new(1, 1) })
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.2), NumberSequenceKeypoint.new(1, 4.5) })
	e.Lifetime = NumberRange.new(1.0, 1.9)
	e.Speed = NumberRange.new(2, 7)
	e.SpreadAngle = Vector2.new(70, 70)
	e.Acceleration = Vector3.new(0, 1.2, 0)
	e.Drag = 2
	e.LightEmission = 0
	e.Rate = count / 0.12
	e.Parent = anchor
	task.delay(0.12, function()
		e.Enabled = false
	end)
	task.delay(2.4, function()
		anchor:Destroy()
	end)
end

--==========================================================================
-- The pick, in the hand
--==========================================================================
local function handOf(character: Model): BasePart?
	local right = character:FindFirstChild("RightHand") or character:FindFirstChild("Right Arm")
	return if right and right:IsA("BasePart") then right else nil
end

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

local function giveVisual(character: Model): Model?
	local hand = handOf(character)
	if not hand then
		return nil
	end
	local model = Instance.new("Model")
	model.Name = "MinersPick"

	local function piece(name: string, size: Vector3, offset: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
		local p = Instance.new("Part")
		p.Name = name
		p.Size = size
		p.Color = color
		p.Material = material
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Massless = true
		p.TopSurface = Enum.SurfaceType.Smooth
		p.BottomSurface = Enum.SurfaceType.Smooth
		if shape then
			p.Shape = shape
		end
		p.CFrame = hand.CFrame * offset
		p.Parent = model
		return p
	end

	-- The helve runs out of the fist along the hand's own -Y, like the torch.
	local helve = piece("Helve", Vector3.new(0.34, 4.6, 0.34), CFrame.new(0, -1.55, -0.25), OAK_PALE, Enum.Material.Wood)
	-- The head sits across the end of it, its points along the swing.
	local head = piece("Head", Vector3.new(0.5, 0.56, 1.1), CFrame.new(0, -3.85, -0.25), IRON, Enum.Material.CorrodedMetal)
	local front = piece("Point", Vector3.new(0.4, 0.46, 1.4), CFrame.new(0, -3.9, -1.25) * CFrame.Angles(math.rad(8), 0, 0), IRON, Enum.Material.CorrodedMetal)
	local back = piece("Point", Vector3.new(0.4, 0.46, 1.4), CFrame.new(0, -3.9, 0.75) * CFrame.Angles(math.rad(-8), 0, 0), IRON, Enum.Material.CorrodedMetal)
	local socket = piece("Socket", Vector3.new(0.5, 0.9, 0.5), CFrame.new(0, -3.55, -0.25), Color3.fromRGB(44, 38, 34), Enum.Material.Metal)
	local butt = piece("Butt", Vector3.new(0.42, 0.34, 0.42), CFrame.new(0, 0.78, -0.25), OAK, Enum.Material.Wood)

	weld(hand, helve)
	for _, p in { head, front, back, socket, butt } do
		weld(helve, p)
	end
	model.PrimaryPart = helve
	model.Parent = character
	return model
end

--==========================================================================
-- The task
--==========================================================================
type Chunk = {
	part: Part,
	home: CFrame,
	spoil: CFrame,
	length: number,
	flying: boolean,
}

type Flight = { chunk: Chunk, from: CFrame, to: CFrame, t: number, dur: number, arc: number, landing: boolean }

type Holder = {
	pick: Model?,
	wasDrawn: boolean,
	hasPick: boolean,
	stunUntil: number,
	hits: number,
}

function Dig.create(ctx: any, def: any)
	local Castle = Config.get("Castle")
	local nearZ, farZ = Castle.chamberBounds(ctx.area)
	local dirZ = if nearZ > farZ then 1 else -1 -- from the passage into the ward

	local connections: { any } = {}
	local running = false
	local finished = false

	local chunks: { Chunk } = {}
	local flights: { Flight } = {}
	local shores: { { Part } } = {}
	local pointer = 0 -- how many chunks are out of the trench
	local progress = 0
	local shored = 0
	local packedLength = rng:NextInteger(2, 4) -- 1-based; the first and the last are loose
	local holders: { [Player]: Holder } = {}

	local prompt: ProximityPrompt? = nil
	local anchor: Part? = nil
	local dust: ParticleEmitter? = nil
	local mound: Model? = nil
	local heartbeat: RBXScriptConnection? = nil
	local damageConnection: any = nil

	local passage = AreaService.passageOf(ctx.area)
	local groundY = Castle.GroundY
	local innerZ = passage.Z + dirZ * 12.5 -- the mouth of the arch, ward side
	local outerZ = innerZ + dirZ * CUT_LEN
	local centreX = passage.X

	local RAISE = 1 / def.seconds
	local FALL = RAISE * def.fall

	local function lengthStartZ(k: number): number -- the z where length k (1-based) begins, outer side
		return outerZ - dirZ * (k - 1) * (CUT_LEN / LENGTHS)
	end

	--======================================================================
	-- BUILD
	--======================================================================
	local function build()
		local folder = Instance.new("Model")
		folder.Name = "BuriedPassage"
		folder.Parent = ctx.folder
		mound = folder

		-- Anything the scenery already put in the line of the cut is cleared: the
		-- loose masonry heaped at the mouth is part of this heap now.
		local scenery = Util.find("Decorations.Area8.PassageRubble")
		if scenery then
			for _, d in scenery:GetChildren() do
				if d:IsA("BasePart") then
					local rel = d.Position - Vector3.new(centreX, groundY, innerZ)
					local depth = rel.Z * dirZ
					if math.abs(rel.X) < CUT_W / 2 + 1.5 and depth > -2 and depth < CUT_LEN + 3 then
						d.CanCollide = false
						d.Transparency = 1
					end
				end
			end
		end

		-- THE MOUND: boulders either side of the cut and over it.
		local function surface(dx: number, depth: number): number
			local u = math.clamp(depth / (CUT_LEN + 4), 0, 1)
			local across = 1 - 0.28 * (dx / (MOUND_W / 2)) ^ 2
			return MOUND_H * (1 - u) ^ 0.85 * across
		end
		local placed = 0
		local attempts = 0
		local function small(): number
			return 1.6 + rng:NextNumber() ^ 2.2 * 6.2
		end
		while placed < 260 and attempts < 1800 do
			attempts += 1
			local dx = rng:NextNumber(-MOUND_W / 2, MOUND_W / 2)
			local depth = rng:NextNumber(-1, CUT_LEN + 3) ^ 1.0
			local top = surface(dx, depth)
			local y = top * (0.35 + 0.65 * rng:NextNumber() ^ 0.6)
			local inCut = math.abs(dx) < CUT_W / 2 + 2.2 and y < CUT_H + 2 and depth < CUT_LEN + 1
			if not inCut and top > 2 then
				placed += 1
				local size = Vector3.new(small(), small() * 0.8, small())
				local at = Vector3.new(centreX + dx, groundY + math.max(size.Y / 2 * 0.7, y), innerZ + dirZ * depth)
				rock(folder, "Boulder", size, CFrame.new(at) * randomRotation())
			end
		end
		-- The roof of the cut: heavy stones and a beam or two lying across it, so
		-- the gallery has something over its head.
		for k = 0, 4 do
			local depth = 1.5 + k * 4.6
			newPart(
				folder,
				"Roof",
				Vector3.new(CUT_W + 8, 4.6, 5.4),
				CFrame.new(centreX + rng:NextNumber(-1, 1), groundY + CUT_H + 2.6 + rng:NextNumber(0, 1.2), innerZ + dirZ * depth) * CFrame.Angles(0, math.rad(rng:NextNumber(-6, 6)), math.rad(rng:NextNumber(-3, 3))),
				STONE[rng:NextInteger(1, #STONE)],
				Enum.Material.Slate
			)
		end
		for _ = 1, 9 do
			local depth = rng:NextNumber(0, CUT_LEN)
			local dx = rng:NextNumber(-MOUND_W / 2 + 4, MOUND_W / 2 - 4)
			local len = rng:NextNumber(9, 16)
			local beam = newPart(
				folder,
				"Beam",
				Vector3.new(1.3, 1.3, len),
				CFrame.new(centreX + dx, groundY + surface(dx, depth) * rng:NextNumber(0.55, 0.9), innerZ + dirZ * depth)
					* CFrame.Angles(math.rad(rng:NextNumber(-35, 35)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-20, 20))),
				OAK,
				Enum.Material.Wood
			)
			beam.CanCollide = false
		end

		-- Small stuff on the floor round the foot of the heap and along the trench:
		-- it is what makes the ground look struck and walked on.
		for _ = 1, 70 do
			local dx = rng:NextNumber(-MOUND_W / 2 - 6, MOUND_W / 2 + 6)
			local depth = rng:NextNumber(-1, CUT_LEN + 9)
			if not (math.abs(dx) < CUT_W / 2 and depth < CUT_LEN) then
				local u = rng:NextNumber(0.5, 1.4)
				local p = rock(folder, "Scatter", Vector3.new(u, u * 0.7, u * 1.2), CFrame.new(centreX + dx, groundY + u * 0.3, innerZ + dirZ * depth) * randomRotation())
				p.CanCollide = false
			end
		end
		-- The heap is still settling: a thread of dust off the top, now and then.
		local haze = Instance.new("Part")
		haze.Name = "Haze"
		haze.Anchored = true
		haze.CanCollide = false
		haze.CanQuery = false
		haze.CanTouch = false
		haze.Transparency = 1
		haze.Size = Vector3.new(MOUND_W * 0.6, 1, 8)
		haze.Position = Vector3.new(centreX, groundY + MOUND_H * 0.8, innerZ + dirZ * 5)
		haze.Parent = folder
		local settle = Instance.new("ParticleEmitter")
		settle.Texture = "rbxasset://textures/particles/smoke_main.dds"
		settle.Color = ColorSequence.new(Color3.fromRGB(110, 98, 82))
		settle.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.7), NumberSequenceKeypoint.new(1, 1) })
		settle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4), NumberSequenceKeypoint.new(1, 4.4) })
		settle.Lifetime = NumberRange.new(2.5, 4)
		settle.Speed = NumberRange.new(0.5, 2)
		settle.Acceleration = Vector3.new(0, -1.5, 0)
		settle.Rate = 1.6
		settle.Parent = haze

		-- THE CUT: five lengths, a dozen stones each, flung to either side when dug.
		for k = 1, LENGTHS do
			local packed = (k == packedLength)
			local zMid = lengthStartZ(k) - dirZ * (CUT_LEN / LENGTHS) / 2
			-- top row first: that is the order a person digs in
			for row = 3, 1, -1 do
				for col = 1, 4 do
					local base = if packed then 4.6 else 3.2
					local size = Vector3.new(rng:NextNumber(base, base + 1.4), rng:NextNumber(base - 0.4, base + 1.0), rng:NextNumber(base, base + 1.2))
					local home = CFrame.new(
						centreX + (col - 2.5) * 2.9 + rng:NextNumber(-0.7, 0.7),
						groundY + (row - 0.5) * (CUT_H / 3) + rng:NextNumber(-0.4, 0.4),
						zMid + rng:NextNumber(-0.7, 0.7)
					) * randomRotation()
					local part = rock(folder, "Cut", size, home, packed)

					-- Where it ends up: thrown out to one side of the trench, and flat.
					local side = if col <= 2 then -1 else 1
					local land = Vector3.new(
						centreX + side * (CUT_W / 2 + rng:NextNumber(5, 15)),
						groundY + size.Y * 0.32,
						zMid + dirZ * rng:NextNumber(2, 12)
					)
					table.insert(chunks, {
						part = part,
						home = home,
						spoil = CFrame.new(land) * CFrame.Angles(math.rad(rng:NextNumber(-12, 12)), math.rad(rng:NextNumber(0, 360)), math.rad(rng:NextNumber(-12, 12))),
						length = k,
						flying = false,
					})
				end
			end
		end

		-- THE FRAMES: two posts, a cap, two braces, set behind the face at the end of
		-- each length. Built now, lifted out of sight until they are earned.
		for k = 1, FRAMES do
			local z = lengthStartZ(k) - dirZ * (CUT_LEN / LENGTHS) + dirZ * 0.9
			local set: { Part } = {}
			for _, side in { -1, 1 } do
				table.insert(set, newPart(folder, "Post", Vector3.new(1.1, CUT_H - 0.3, 1.1), CFrame.new(centreX + side * (CUT_W / 2 - 0.4), groundY + (CUT_H - 0.3) / 2, z), OAK, Enum.Material.Wood))
				table.insert(set, newPart(folder, "Footing", Vector3.new(2.0, 0.6, 2.0), CFrame.new(centreX + side * (CUT_W / 2 - 0.4), groundY + 0.3, z), STONE[1], Enum.Material.Slate))
				table.insert(
					set,
					newPart(folder, "Brace", Vector3.new(0.7, 3.4, 0.7), CFrame.new(centreX + side * (CUT_W / 2 - 1.9), groundY + CUT_H - 1.9, z) * CFrame.Angles(0, 0, math.rad(side * 45)), OAK_PALE, Enum.Material.Wood)
				)
			end
			table.insert(set, newPart(folder, "Cap", Vector3.new(CUT_W + 1.4, 1.2, 1.4), CFrame.new(centreX, groundY + CUT_H - 0.3 + 0.2, z), OAK_PALE, Enum.Material.Wood))
			for i = -2, 2 do
				-- the lagging boards laid across the cap, holding up the roof
				table.insert(set, newPart(folder, "Lagging", Vector3.new(0.5, 0.4, 4.2), CFrame.new(centreX + i * 2.4, groundY + CUT_H + 0.75, z + dirZ * 1.4), OAK, Enum.Material.WoodPlanks))
			end
			-- A rope round the cap: the sort of thing a person does to a prop.
			table.insert(set, newPart(folder, "Lashing", Vector3.new(0.35, 1.5, 0.35), CFrame.new(centreX - CUT_W / 2 + 0.2, groundY + CUT_H - 0.7, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(150, 124, 86), Enum.Material.Fabric))
			for _, p in set do
				p.CanCollide = false
				p.Transparency = 1
			end
			shores[k] = set
		end
	end

	--======================================================================
	-- FLIGHT
	--======================================================================
	local function removeFlight(chunk: Chunk)
		for i = #flights, 1, -1 do
			if flights[i].chunk == chunk then
				table.remove(flights, i)
			end
		end
	end

	local function fly(chunk: Chunk, to: CFrame, dur: number, arc: number, landing: boolean)
		removeFlight(chunk)
		chunk.flying = true
		table.insert(flights, { chunk = chunk, from = chunk.part.CFrame, to = to, t = 0, dur = dur, arc = arc, landing = landing })
	end

	local function step(dt: number)
		for i = #flights, 1, -1 do
			local f = flights[i]
			f.t += dt
			local a = math.clamp(f.t / f.dur, 0, 1)
			local e = if f.landing then a * a * (3 - 2 * a) else 1 - (1 - a) ^ 2
			local pos = f.from.Position:Lerp(f.to.Position, e) + Vector3.new(0, f.arc * 4 * a * (1 - a), 0)
			local rot = f.from.Rotation:Lerp(f.to.Rotation, e)
			f.chunk.part.CFrame = CFrame.new(pos) * rot
			if a >= 1 then
				table.remove(flights, i)
				f.chunk.flying = false
				if f.landing then
					-- back in the trench: solid again, and the dust of it landing
					f.chunk.part.CanCollide = true
				else
					puff(ctx.folder, f.to.Position + Vector3.new(0, 0.5, 0), 3, 3)
				end
			end
		end
	end

	local function throwOut(chunk: Chunk)
		chunk.part.CanCollide = false
		puff(ctx.folder, chunk.part.Position, 5, 4)
		fly(chunk, chunk.spoil, rng:NextNumber(0.55, 0.8), rng:NextNumber(5, 9), false)
	end

	local function slipBack(chunk: Chunk)
		fly(chunk, chunk.home, rng:NextNumber(0.4, 0.6), 1.5, true)
	end

	--======================================================================
	-- THE FACE (where the prompt stands) and the frames
	--======================================================================
	local function faceZ(): number
		local length = math.clamp(math.floor(progress * LENGTHS) + 1, 1, LENGTHS)
		return lengthStartZ(length) + dirZ * 3.2
	end

	local function moveFace()
		if anchor then
			anchor.Position = Vector3.new(centreX, groundY + 3.4, faceZ())
		end
	end

	local function setFrame(k: number)
		for i, p in shores[k] do
			local home = p.CFrame
			p.Transparency = 0
			p.CFrame = home * CFrame.new(0, 7, 0)
			task.delay((i % 4) * 0.05, function()
				TweenService:Create(p, TweenInfo.new(0.45, Enum.EasingStyle.Bounce, Enum.EasingDirection.Out), { CFrame = home }):Play()
			end)
			p.CanCollide = (p.Name == "Post")
		end
		local at = shores[k][1].Position
		task.delay(0.35, function()
			puff(ctx.folder, Vector3.new(at.X, groundY + 1, at.Z), 14, 8)
		end)
	end

	--======================================================================
	-- THE HANDS
	--======================================================================
	local function release(player: Player)
		local h = holders[player]
		if not h then
			return
		end
		holders[player] = nil
		if h.pick then
			h.pick:Destroy()
		end
		local character = player.Character
		if character then
			character:SetAttribute("WorkPose", nil)
			character:SetAttribute("WorkAt", nil)
		end
		if h.wasDrawn then
			pcall(WeaponVisualService.setDrawn, player, true)
		end
		if dust and next(holders) == nil then
			dust.Rate = 0
		end
	end

	local function grab(player: Player)
		if finished or holders[player] then
			return
		end
		local character = player.Character
		local humanoid = character and character:FindFirstChildOfClass("Humanoid")
		if not (character and humanoid and humanoid.Health > 0) then
			return
		end
		local hasPick = BackpackService.count(player, "pickaxe") > 0
		local wasDrawn = false
		local okDrawn, drawn = pcall(WeaponVisualService.isDrawn, player)
		if okDrawn and drawn then
			wasDrawn = true
			pcall(WeaponVisualService.setDrawn, player, false)
		end
		local pick = if hasPick then giveVisual(character) else nil
		holders[player] = { pick = pick, wasDrawn = wasDrawn, hasPick = hasPick, stunUntil = 0, hits = 0 }
		character:SetAttribute("WorkPose", if hasPick then "dig" else "dig_bare")
		character:SetAttribute("WorkAt", Vector3.new(centreX, groundY + 4.4, faceZ() - dirZ * 2.4))
		if dust then
			dust.Rate = 18
		end
		if not hasPick then
			ctx.note("No pick. Bare hands will do it, slowly. There was a miner's pick in the mine.", 5)
		end
	end

	local function rate(now: number): number
		local total = 0
		local first = true
		for player, h in holders do
			local character = player.Character
			local humanoid = character and character:FindFirstChildOfClass("Humanoid")
			if not (character and humanoid and humanoid.Health > 0) then
				release(player)
			elseif now >= h.stunUntil then
				local pivot = character:GetPivot().Position
				local at = if anchor then anchor.Position else pivot
				if (pivot - at).Magnitude > 17 then
					release(player)
				else
					local share = if h.hasPick then 1 else def.bare
					total += share * (if first then 1 else def.hands)
					first = false
				end
			end
		end
		return total
	end

	local lastReported = -1
	local function applyFace()
		-- readable from outside (a test, a debug overlay): the heap says how far it has got
		if anchor and math.abs(progress - lastReported) >= 0.01 then
			lastReported = progress
			anchor:SetAttribute("Progress", math.floor(progress * 100) / 100)
		end
		-- stones come out as the progress passes their threshold, and go back as it falls
		local want = math.floor(progress * #chunks + 0.5)
		while pointer < want do
			pointer += 1
			throwOut(chunks[pointer])
		end
		while pointer > want do
			slipBack(chunks[pointer])
			pointer -= 1
		end
		moveFace()
	end

	local function finish()
		finished = true
		for player in holders do
			release(player)
		end
		if prompt then
			prompt.Enabled = false
		end
		-- whatever is left of the cut lets go together
		for i = pointer + 1, #chunks do
			throwOut(chunks[i])
		end
		pointer = #chunks
		puff(ctx.folder, Vector3.new(centreX, groundY + 4, innerZ + dirZ * 3), 40, CUT_W)
		ctx.hint(nil)
		ctx.note("Daylight. A draught from the passage, and the smell of the stair beyond. Through.", 5)
		ctx.done()
	end

	--======================================================================
	return {
		start = function()
			if running then
				return
			end
			running = true
			build()

			local face = Instance.new("Part")
			face.Name = "DigFace"
			face.Anchored = true
			face.CanCollide = false
			face.CanQuery = false
			face.CanTouch = false
			face.Transparency = 1
			face.Size = Vector3.new(6, 6, 6)
			face.Position = Vector3.new(centreX, groundY + 3.4, faceZ())
			face.Parent = ctx.folder
			anchor = face

			local trickle = Instance.new("ParticleEmitter")
			trickle.Texture = "rbxasset://textures/particles/smoke_main.dds"
			trickle.Color = ColorSequence.new(Color3.fromRGB(110, 98, 82))
			trickle.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 1) })
			trickle.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.6), NumberSequenceKeypoint.new(1, 2.6) })
			trickle.Lifetime = NumberRange.new(0.8, 1.5)
			trickle.Speed = NumberRange.new(1, 4)
			trickle.SpreadAngle = Vector2.new(60, 60)
			trickle.Rate = 0
			trickle.Parent = face
			dust = trickle

			local p = Instance.new("ProximityPrompt")
			p.Name = "Prompt"
			p.ActionText = "Dig"
			p.ObjectText = "Buried passage"
			-- A hold longer than the whole job, so the hold events bracket exactly how long
			-- the key was down (the winch's trick); Triggered is wired for the day somebody
			-- really holds it that long.
			p.HoldDuration = def.seconds * 3
			p.MaxActivationDistance = 11
			p.RequiresLineOfSight = false
			p.KeyboardKeyCode = Enum.KeyCode.E
			p.Parent = face
			prompt = p

			table.insert(connections, p.PromptButtonHoldBegan:Connect(grab))
			table.insert(connections, p.PromptButtonHoldEnded:Connect(release))
			table.insert(connections, p.Triggered:Connect(release))
			table.insert(connections, Players.PlayerRemoving:Connect(release))

			-- Being hit while digging: a stagger and the stones settle.
			damageConnection = CombatService.DamageDealt:connect(function(result: any)
				if result.blocked or result.amount <= 0 then
					return
				end
				for player, h in holders do
					if result.targetId == Constants.CombatId.PlayerPrefix .. player.UserId then
						h.stunUntil = os.clock() + 0.7
						h.hits += 1
						local character = player.Character
						if character then
							character:SetAttribute("WorkHit", h.hits)
						end
					end
				end
			end)

			heartbeat = RunService.Heartbeat:Connect(function(dt: number)
				step(dt)
				if finished then
					return
				end
				local now = os.clock()
				local pushing = rate(now)
				local floor = shored / LENGTHS
				local delta
				if pushing > 0 then
					local multiplier = 1
					local length = math.clamp(math.floor(progress * LENGTHS) + 1, 1, LENGTHS)
					if length == packedLength then
						multiplier = 0.5
					end
					delta = RAISE * pushing * multiplier * dt
				elseif progress > floor then
					delta = -FALL * dt
				else
					delta = 0
				end
				if delta ~= 0 then
					progress = math.clamp(progress + delta, floor, 1)
					applyFace()
				end
				-- a length is finished: set its frame, and the noise carries
				while shored < FRAMES and progress >= (shored + 1) / LENGTHS do
					shored += 1
					if anchor then
						anchor:SetAttribute("Shored", shored)
					end
					setFrame(shored)
					ctx.progress(shored, FRAMES)
					ctx.note(("Frame %d of %d set. The heap cannot slip back past it."):format(shored, FRAMES), 4)
					ctx.signal("shore" .. shored)
				end
				if progress >= 1 then
					finish()
				end
			end)

			ctx.progress(0, FRAMES)
			ctx.note("The way out is buried under the arch. Cut through it, and prop the cut as you go.", 6)
			task.delay(7, function()
				if running and not finished then
					ctx.note(("The %s length of the cut is packed hard. It will be slow."):format(({ "first", "second", "third", "fourth", "fifth" })[packedLength]), 5)
				end
			end)
		end,

		stop = function()
			running = false
			for player in holders do
				release(player)
			end
			for _, c in connections do
				c:Disconnect()
			end
			connections = {}
			if damageConnection then
				damageConnection()
				damageConnection = nil
			end
			if heartbeat and finished then
				-- the stones are still flying; let the loop run until they land
				task.delay(2, function()
					if heartbeat then
						heartbeat:Disconnect()
						heartbeat = nil
					end
				end)
			elseif heartbeat then
				heartbeat:Disconnect()
				heartbeat = nil
			end
		end,

		progress = function(): (number, number)
			return shored, FRAMES
		end,
	}
end

return Dig
