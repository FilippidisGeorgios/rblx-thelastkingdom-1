--[[
	BuildSurroundings — run in the Studio Command Bar of the FORGOTTEN LANDS place,
	in EDIT MODE, AFTER tools/BuildLand.luau. Select all, copy, paste, Enter.

	Everything that stands on the land BuildLand shaped: the moat's stone face,
	the bridge and the drawbridge, the first fires, the mist on the water, the dead
	forest, the burnt village, the old battlefield, the hill where the party
	arrives, and the camera marks the intro is shot from.

	The story this ground tells, read from the hill down to the gate:

	  - Rails end at a broken buffer stop. Nobody has come this way in a long time.
	  - A wayside shrine with candles still burning. Somebody has.
	  - A burnt village to the left. A field of graves to the right, dug in rows,
	    with the weapons of the people in them still standing in the earth, and a
	    siege engine that never got to fire. The kingdom fought out here, and lost.
	  - A gallows by the road.
	  - The bridge: stone, then the drawbridge, LEFT DOWN. Two fires at its foot.
	  - Smoke rising inside the walls, and, at the far end of the castle, one red
	    light in the highest tower. That is where this ends.

	Every section lands in its own folder under `Workspace.Gameplay.Surroundings`
	and re-running a section replaces only that folder. Everything out here is
	scenery behind the castle wall, so nothing collides: physics stays cheap.

	Objects are seated on the terrain by raycasting it, so moving a hill in
	BuildLand moves what stands on it.

	SECTIONS (set SECTIONS below, or "all")
	  Moat        stone revetment, waterline stain, reeds, stakes, debris, mist
	  Bridge      stone bridge, drawbridge, chains, braziers and torches
	  Forest      the dead trees
	  Village     the burnt cottages and the well
	  Battlefield graves, weapons, the trebuchet, banners, the gallows
	  Hill        rails, buffer stop, shrine, the lone tree
	  Castle      smoke inside the walls, the red light in the last tower
	  Intro       stand marks and camera marks for the arrival scene

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local SECTIONS = { "all" }
local SEED = 1453

--==========================================================================
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local rng = Random.new(SEED)

-- The moat follows the castle (configs/Castle.luau): 40 / 120 out from the side
-- walls, 16 / 96 behind the back wall. Was 190 / 270, -1796 / -1876 before the
-- 2026-10-19 widening.
local Castle = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Castle")) :: any
local MOAT = {
	innerX = Castle.HalfWidth + 40,
	outerX = Castle.HalfWidth + 120,
	frontIn = 60,
	frontOut = 140,
	backIn = Castle.zEnd() - 16,
	backOut = Castle.zEnd() - 96,
	water = -6,
}
-- Where along the castle a z falls, as a fraction of its length (0 = front wall).
local function alongCastle(t: number): number
	return Castle.ZStart + (Castle.zEnd() - Castle.ZStart) * t
end
local HILL = Vector3.new(-40, 0, 790) -- where the party stands (y is found on the terrain)
local GATE = Vector3.new(0, 1.2, 66)

local C = {
	stone = Color3.fromRGB(78, 76, 74),
	stoneDark = Color3.fromRGB(58, 57, 58),
	stonePale = Color3.fromRGB(104, 100, 94),
	algae = Color3.fromRGB(44, 52, 40),
	wood = Color3.fromRGB(66, 52, 40),
	woodDark = Color3.fromRGB(42, 34, 28),
	charred = Color3.fromRGB(28, 25, 23),
	deadWood = Color3.fromRGB(48, 42, 36),
	iron = Color3.fromRGB(52, 50, 50),
	rust = Color3.fromRGB(84, 54, 38),
	cloth = Color3.fromRGB(86, 32, 32),
	clothOld = Color3.fromRGB(70, 58, 46),
	reed = Color3.fromRGB(70, 72, 46),
	reedDry = Color3.fromRGB(96, 86, 58),
	earth = Color3.fromRGB(60, 50, 40),
	bone = Color3.fromRGB(170, 162, 144),
}

local M = {
	stone = Enum.Material.Slate,
	cobble = Enum.Material.Cobblestone,
	wood = Enum.Material.WoodPlanks,
	log = Enum.Material.Wood,
	iron = Enum.Material.Metal,
	rust = Enum.Material.CorrodedMetal,
	cloth = Enum.Material.Fabric,
	ground = Enum.Material.Ground,
}

--==========================================================================
-- Foundations
--==========================================================================
local gameplay = workspace:FindFirstChild("Gameplay") or Instance.new("Folder")
gameplay.Name = "Gameplay"
gameplay.Parent = workspace

local root = gameplay:FindFirstChild("Surroundings") or Instance.new("Folder")
root.Name = "Surroundings"
root.Parent = gameplay

local made = 0

local function section(name: string): Folder
	local old = root:FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f
end

local function group(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function rand(a: number, b: number): number
	return a + (b - a) * rng:NextNumber()
end

local function vary(c: Color3, amount: number): Color3
	local k = 1 + rand(-amount, amount)
	return Color3.new(math.clamp(c.R * k, 0, 1), math.clamp(c.G * k, 0, 1), math.clamp(c.B * k, 0, 1))
end

local function part(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, name: string?): Part
	local p = Instance.new("Part")
	p.Name = name or "Part"
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	made += 1
	return p
end

local function wedge(parent: Instance, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): WedgePart
	local p = Instance.new("WedgePart")
	p.Anchored = true
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	made += 1
	return p
end

-- A cylinder from a to b. A cylinder Part's axis is its X axis, so the frame
-- looks along a→b and is turned a quarter round Y to put X on that line.
local function rod(parent: Instance, a: Vector3, b: Vector3, thick: number, color: Color3, material: Enum.Material): Part
	local len = (b - a).Magnitude
	local p = part(parent, Vector3.new(len, thick, thick), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

-- A square beam from a to b.
local function beam(parent: Instance, a: Vector3, b: Vector3, w: number, h: number, color: Color3, material: Enum.Material): Part
	return part(parent, Vector3.new(w, h, (b - a).Magnitude), CFrame.lookAt((a + b) / 2, b), color, material)
end

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { workspace.Terrain }
terrainOnly.IgnoreWater = true

-- The top of the land at x, z (water is looked through).
local function groundY(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 800, z), Vector3.new(0, -1600, 0), terrainOnly)
	return hit and hit.Position.Y or 0
end

local function onGround(x: number, z: number, yaw: number?): CFrame
	return CFrame.new(x, groundY(x, z), z) * CFrame.Angles(0, yaw or 0, 0)
end

-- Distance from (x, z) to the segment a-b on the ground plane.
local function segDist(x: number, z: number, a: Vector2, b: Vector2): number
	local vx, vz = b.X - a.X, b.Y - a.Y
	local t = math.clamp(((x - a.X) * vx + (z - a.Y) * vz) / (vx * vx + vz * vz), 0, 1)
	return math.sqrt((x - a.X - vx * t) ^ 2 + (z - a.Y - vz * t) ^ 2)
end

local ROAD = {
	Vector2.new(-40, 790), Vector2.new(-34, 700), Vector2.new(-22, 600), Vector2.new(-6, 480),
	Vector2.new(0, 360), Vector2.new(0, 250), Vector2.new(0, MOAT.frontOut),
}
local function roadDist(x: number, z: number): number
	local best = math.huge
	for i = 1, #ROAD - 1 do
		best = math.min(best, segDist(x, z, ROAD[i], ROAD[i + 1]))
	end
	return best
end

-- Free ground: outside the castle and its moat (plus a margin), off the road.
local function freeGround(x: number, z: number, margin: number): boolean
	if x > -MOAT.outerX - margin and x < MOAT.outerX + margin and z > MOAT.backOut - margin and z < MOAT.frontOut + margin then
		return false
	end
	return roadDist(x, z) > 14 + margin * 0.3
end

local function fire(parent: Instance, at: Vector3, scale: number, lightRange: number)
	local anchor = part(parent, Vector3.new(0.4, 0.4, 0.4), CFrame.new(at), C.charred, M.iron, "Fire")
	anchor.Transparency = 1
	anchor.CastShadow = false

	local flame = Instance.new("ParticleEmitter")
	flame.Name = "Flame"
	flame.Texture = "rbxasset://textures/particles/fire_main.dds"
	flame.Color = ColorSequence.new(Color3.fromRGB(255, 176, 92), Color3.fromRGB(196, 72, 30))
	flame.LightEmission = 0.85
	flame.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.6 * scale), NumberSequenceKeypoint.new(1, 0.2) })
	flame.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) })
	flame.Lifetime = NumberRange.new(0.5, 0.9)
	flame.Rate = 26
	flame.Speed = NumberRange.new(2.5 * scale, 4 * scale)
	flame.SpreadAngle = Vector2.new(12, 12)
	flame.Acceleration = Vector3.new(0, 3, 0)
	flame.Parent = anchor

	local ember = Instance.new("ParticleEmitter")
	ember.Name = "Embers"
	ember.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	ember.Color = ColorSequence.new(Color3.fromRGB(255, 150, 70))
	ember.LightEmission = 1
	ember.Size = NumberSequence.new(0.12 * scale)
	ember.Lifetime = NumberRange.new(1.5, 3)
	ember.Rate = 4
	ember.Speed = NumberRange.new(3, 6)
	ember.SpreadAngle = Vector2.new(25, 25)
	ember.Acceleration = Vector3.new(0.6, 1.5, 0)
	ember.Parent = anchor

	-- No shadows: the brazier's own bowl sits right under the flame and would
	-- shade the very ground the fire is meant to light.
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 160, 86)
	light.Brightness = 1.2 + scale
	light.Range = lightRange
	light.Shadows = false
	light.Parent = anchor
	return anchor
end

local function smoke(parent: Instance, at: Vector3, size: Vector3, rate: number, scale: number, color: Color3)
	local anchor = part(parent, size, CFrame.new(at), C.charred, M.iron, "Smoke")
	anchor.Transparency = 1
	anchor.CastShadow = false
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/smoke_main.dds"
	e.Color = ColorSequence.new(color)
	e.LightEmission = 0
	e.LightInfluence = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 6 * scale), NumberSequenceKeypoint.new(1, 22 * scale) })
	e.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 1),
		NumberSequenceKeypoint.new(0.15, 0.55),
		NumberSequenceKeypoint.new(1, 1),
	})
	e.Lifetime = NumberRange.new(10, 16)
	e.Rate = rate
	e.Speed = NumberRange.new(4 * scale, 7 * scale)
	e.SpreadAngle = Vector2.new(8, 8)
	e.Acceleration = Vector3.new(1.2, 0.4, 0)
	e.RotSpeed = NumberRange.new(-12, 12)
	e.Rotation = NumberRange.new(0, 360)
	e.Parent = anchor
	return anchor
end

--==========================================================================
-- Moat
--==========================================================================
local function buildMoat()
	local f = section("Moat")
	local walls = group(f, "Revetment")
	local W = MOAT.water

	-- Anything already standing where a wall segment would go (a corner tower
	-- dropping into the water, the gatehouse) wins, and the segment is skipped.
	local shell = workspace:FindFirstChild("Battleground", true)
	local overlap = OverlapParams.new()
	overlap.FilterType = Enum.RaycastFilterType.Include
	overlap.FilterDescendantsInstances = { shell }

	local SEG = 24
	local TOP, BOTTOM, THICK = 1.5, -30, 6

	-- One run of wall: from a to b along the inner edge, facing `out`.
	local function run(a: Vector3, b: Vector3, out: Vector3)
		local dir = (b - a).Unit
		local length = (b - a).Magnitude
		local count = math.ceil(length / SEG)
		for i = 0, count - 1 do
			local s0 = i * SEG
			local s1 = math.min(length, s0 + SEG)
			local mid = a + dir * ((s0 + s1) / 2) - out * (THICK / 2)
			local len = s1 - s0
			local cf = CFrame.lookAt(Vector3.new(mid.X, (TOP + BOTTOM) / 2, mid.Z), Vector3.new(mid.X, (TOP + BOTTOM) / 2, mid.Z) + dir)
			local size = Vector3.new(THICK, TOP - BOTTOM, len)
			if #workspace:GetPartBoundsInBox(cf, size + Vector3.new(4, 0, 0), overlap) == 0 then
				local face = vary(C.stone, 0.06)
				part(walls, size, cf, face, M.stone, "Wall")
				-- Coping: a lighter capstone standing proud of the face.
				part(walls, Vector3.new(THICK + 1.2, 1.2, len), cf * CFrame.new(0, (TOP - BOTTOM) / 2 + 0.6, 0) + out * 0.6, vary(C.stonePale, 0.05), M.cobble, "Coping")
				-- The waterline: forty years of green.
				local stainCf = CFrame.lookAt(Vector3.new(mid.X, W + 0.5, mid.Z), Vector3.new(mid.X, W + 0.5, mid.Z) + dir) + out * (THICK / 2 + 0.05)
				part(walls, Vector3.new(0.2, 3.4, len), stainCf, vary(C.algae, 0.08), Enum.Material.Slate, "Waterline")
				-- A buttress every third stone.
				if i % 3 == 1 then
					local bcf = CFrame.lookAt(Vector3.new(mid.X, (TOP - 2 + BOTTOM) / 2, mid.Z), Vector3.new(mid.X, (TOP - 2 + BOTTOM) / 2, mid.Z) + dir)
						+ out * (THICK / 2 + 1.6)
					part(walls, Vector3.new(3.2, TOP - 2 - BOTTOM, 4), bcf, vary(C.stoneDark, 0.05), M.stone, "Buttress")
				end
			end
		end
	end

	local X, F, B = MOAT.innerX, MOAT.frontIn, MOAT.backIn
	run(Vector3.new(X, 0, F), Vector3.new(X, 0, B), Vector3.new(1, 0, 0))
	run(Vector3.new(-X, 0, F), Vector3.new(-X, 0, B), Vector3.new(-1, 0, 0))
	run(Vector3.new(-X, 0, F), Vector3.new(X, 0, F), Vector3.new(0, 0, 1))
	run(Vector3.new(-X, 0, B), Vector3.new(X, 0, B), Vector3.new(0, 0, -1))

	-- Reeds and dry rushes in the shallows along the outer bank.
	local reeds = group(f, "Reeds")
	local function reedClump(x: number, z: number)
		local n = rng:NextInteger(4, 8)
		for _ = 1, n do
			local h = rand(2.5, 5.5)
			local px, pz = x + rand(-2.5, 2.5), z + rand(-2.5, 2.5)
			local tilt = CFrame.Angles(rand(-0.25, 0.25), 0, rand(-0.25, 0.25))
			local c = if rng:NextNumber() < 0.6 then C.reed else C.reedDry
			part(reeds, Vector3.new(0.25, h, 0.25), CFrame.new(px, W - 1 + h / 2, pz) * tilt, vary(c, 0.12), Enum.Material.Grass, "Reed")
		end
	end
	local shelfMid = MOAT.outerX - 12 - 5 -- the middle of the shallow shelf
	for z = MOAT.frontOut - 20, MOAT.backOut + 20, -26 do
		if rng:NextNumber() < 0.7 then
			reedClump(shelfMid + rand(-4, 4), z + rand(-8, 8))
		end
		if rng:NextNumber() < 0.7 then
			reedClump(-shelfMid + rand(-4, 4), z + rand(-8, 8))
		end
	end
	for x = -MOAT.outerX + 30, MOAT.outerX - 30, 24 do
		if math.abs(x) > 26 and rng:NextNumber() < 0.75 then
			reedClump(x + rand(-6, 6), MOAT.frontOut - 17 + rand(-3, 3))
		end
		if rng:NextNumber() < 0.6 then
			reedClump(x + rand(-6, 6), MOAT.backOut + 17 + rand(-3, 3))
		end
	end

	-- Sharpened stakes on the far bank, either side of the bridge, leaning out.
	local stakes = group(f, "Stakes")
	for x = -MOAT.outerX + 10, MOAT.outerX - 10, 7 do
		if math.abs(x) > 34 and rng:NextNumber() < 0.85 then
			local z = MOAT.frontOut + 6 + rand(-1, 1)
			local base = Vector3.new(x, groundY(x, z) - 0.5, z)
			for s = -1, 1, 2 do
				local tip = base + Vector3.new(s * rand(1.5, 2.5), rand(5, 6.5), rand(2.5, 4))
				rod(stakes, base, tip, 0.55, vary(C.woodDark, 0.15), M.log)
			end
		end
	end

	-- What the water kept.
	local debris = group(f, "Debris")
	-- A cart, nose down off the bank.
	do
		local at = CFrame.new(-150, W - 1.5, 112) * CFrame.Angles(math.rad(-18), math.rad(24), math.rad(6))
		part(debris, Vector3.new(7, 0.6, 11), at, vary(C.woodDark, 0.1), M.wood, "CartBed")
		part(debris, Vector3.new(0.5, 2.2, 11), at * CFrame.new(-3.3, 1.2, 0), vary(C.wood, 0.1), M.wood, "CartSide")
		part(debris, Vector3.new(0.5, 2.2, 11), at * CFrame.new(3.3, 1.2, 0), vary(C.wood, 0.1), M.wood, "CartSide")
		local wheel = part(debris, Vector3.new(0.6, 5, 5), at * CFrame.new(4, 0.4, -3.5), vary(C.woodDark, 0.1), M.wood, "Wheel")
		wheel.Shape = Enum.PartType.Cylinder
		rod(debris, (at * CFrame.new(0, 0, 5.5)).Position, (at * CFrame.new(0, 2, 13)).Position, 0.5, C.woodDark, M.log)
	end
	-- A rowboat, half sunk, on the west side.
	do
		local at = CFrame.new(-236, W - 0.6, -520) * CFrame.Angles(math.rad(8), math.rad(12), math.rad(-14))
		part(debris, Vector3.new(4.5, 0.5, 13), at, vary(C.woodDark, 0.1), M.wood, "Hull")
		part(debris, Vector3.new(0.5, 1.8, 12), at * CFrame.new(-2.2, 0.8, 0) * CFrame.Angles(0, 0, math.rad(-12)), vary(C.wood, 0.1), M.wood, "Side")
		part(debris, Vector3.new(0.5, 1.8, 12), at * CFrame.new(2.2, 0.8, 0) * CFrame.Angles(0, 0, math.rad(12)), vary(C.wood, 0.1), M.wood, "Side")
		part(debris, Vector3.new(4, 0.4, 1), at * CFrame.new(0, 1, 2), C.wood, M.wood, "Thwart")
		rod(debris, (at * CFrame.new(0.5, 1, 1)).Position, (at * CFrame.new(5, -0.5, -6)).Position, 0.35, C.wood, M.log)
	end
	-- A dead tree fallen across the east channel.
	do
		local ax, az = MOAT.outerX + 4, alongCastle(0.555)
		local a = Vector3.new(ax, groundY(ax, az) + 1, az)
		local b = Vector3.new(MOAT.innerX + 24, W - 1.2, az - 20)
		rod(debris, a, b, 2.6, vary(C.deadWood, 0.1), M.log)
		rod(debris, a:Lerp(b, 0.4), a:Lerp(b, 0.4) + Vector3.new(-4, 7, 9), 1, C.deadWood, M.log)
		rod(debris, a:Lerp(b, 0.7), a:Lerp(b, 0.7) + Vector3.new(-3, 5, -8), 0.8, C.deadWood, M.log)
	end
	-- Planks and barrels floating where the water is still.
	for _ = 1, 16 do
		local side = rng:NextInteger(1, 3)
		local x, z
		if side == 1 then
			x, z = rand(-250, 250), rand(70, 120)
		elseif side == 2 then
			x, z = rand(MOAT.innerX + 10, MOAT.outerX - 20), rand(alongCastle(0.95), 40)
		else
			x, z = rand(-MOAT.outerX + 20, -MOAT.innerX - 10), rand(alongCastle(0.95), 40)
		end
		if math.abs(x) > 24 or z < 60 then
			if rng:NextNumber() < 0.6 then
				part(debris, Vector3.new(rand(0.8, 1.4), 0.3, rand(5, 9)), CFrame.new(x, W - 0.05, z) * CFrame.Angles(0, rand(0, math.pi), rand(-0.05, 0.05)), vary(C.woodDark, 0.15), M.wood, "Plank")
			else
				local barrel = part(debris, Vector3.new(4, 3.2, 3.2), CFrame.new(x, W - 0.4, z) * CFrame.Angles(rand(-0.4, 0.4), rand(0, math.pi), math.rad(90) + rand(-0.3, 0.3)), vary(C.wood, 0.12), M.wood, "Barrel")
				barrel.Shape = Enum.PartType.Cylinder
			end
		end
	end

	-- Mist lying on the water. One wide, flat emitter per stretch; the particles
	-- are big, slow and nearly transparent, so it reads as a layer, not as puffs.
	local mist = group(f, "Mist")
	local function mistPatch(cx: number, cz: number, sx: number, sz: number)
		local anchor = part(mist, Vector3.new(sx, 1, sz), CFrame.new(cx, W + 0.5, cz), C.stone, M.stone, "MistSource")
		anchor.Transparency = 1
		anchor.CastShadow = false
		local e = Instance.new("ParticleEmitter")
		e.Texture = "rbxasset://textures/particles/smoke_main.dds"
		e.Color = ColorSequence.new(Color3.fromRGB(150, 156, 168))
		e.LightInfluence = 1
		e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 14), NumberSequenceKeypoint.new(1, 26) })
		e.Transparency = NumberSequence.new({
			NumberSequenceKeypoint.new(0, 1),
			NumberSequenceKeypoint.new(0.3, 0.86),
			NumberSequenceKeypoint.new(0.7, 0.88),
			NumberSequenceKeypoint.new(1, 1),
		})
		e.Lifetime = NumberRange.new(14, 20)
		e.Rate = 1.6
		e.Speed = NumberRange.new(0.3, 0.8)
		e.SpreadAngle = Vector2.new(70, 70)
		e.Acceleration = Vector3.new(0.15, 0.02, 0)
		e.Rotation = NumberRange.new(0, 360)
		e.RotSpeed = NumberRange.new(-4, 4)
		e.Parent = anchor
	end
	local mid = (MOAT.innerX + MOAT.outerX) / 2
	for z = MOAT.frontOut - 40, MOAT.backOut + 40, -150 do
		mistPatch(mid, z, 60, 150)
		mistPatch(-mid, z, 60, 150)
	end
	for x = -mid, mid, 140 do
		mistPatch(x, (MOAT.frontIn + MOAT.frontOut) / 2, 140, 60)
		mistPatch(x, (MOAT.backIn + MOAT.backOut) / 2, 140, 60)
	end
end

--==========================================================================
-- Bridge
--==========================================================================
local function buildBridge()
	local f = section("Bridge")
	local stone = group(f, "StoneBridge")
	local W = MOAT.water
	local DECK = GATE.Y -- top of the deck, level with the gate's sill
	local HALF = 15
	local Z_PIER = 96 -- where the drawbridge rests on stone
	local Z_END = MOAT.frontOut + 8

	-- Deck and parapets of the stone span.
	local len = Z_END - Z_PIER
	local midZ = (Z_END + Z_PIER) / 2
	part(stone, Vector3.new(HALF * 2, 2.4, len), CFrame.new(0, DECK - 1.2, midZ), vary(C.stone, 0.04), M.stone, "Deck")
	part(stone, Vector3.new(HALF * 2 - 4, 0.2, len), CFrame.new(0, DECK + 0.05, midZ), vary(C.stonePale, 0.04), M.cobble, "Paving")
	for s = -1, 1, 2 do
		local x = s * (HALF - 0.8)
		part(stone, Vector3.new(1.6, 3.4, len), CFrame.new(x, DECK + 1.7, midZ), vary(C.stone, 0.05), M.stone, "Parapet")
		part(stone, Vector3.new(2.2, 0.6, len), CFrame.new(x, DECK + 3.7, midZ), vary(C.stonePale, 0.05), M.cobble, "ParapetCap")
		for z = Z_PIER + 4, Z_END - 2, 8 do
			part(stone, Vector3.new(2.4, 4.8, 2.4), CFrame.new(x, DECK + 2.4, z), vary(C.stoneDark, 0.05), M.stone, "Post")
		end
	end

	-- Piers with cutwaters, and segmental arches between them.
	local function pier(z: number, thick: number)
		local h = DECK - 2.4 - (-30)
		part(stone, Vector3.new(HALF * 2, h, thick), CFrame.new(0, -30 + h / 2, z), vary(C.stoneDark, 0.05), M.stone, "Pier")
		for s = -1, 1, 2 do
			-- The cutwater: a wedge pointing along the channel, nose outward.
			wedge(stone, Vector3.new(thick, h, 5), CFrame.new(s * (HALF + 2.5), -30 + h / 2, z) * CFrame.Angles(0, s * math.rad(90), 0), vary(C.stoneDark, 0.05), M.stone)
		end
		part(stone, Vector3.new(HALF * 2 + 0.4, 3.4, thick + 0.4), CFrame.new(0, W + 1, z), vary(C.algae, 0.08), M.stone, "Waterline")
	end
	pier(Z_PIER, 8)
	pier(118, 6)

	local function arch(z0: number, z1: number)
		local span = z1 - z0
		local spring, crown = W - 0.5, DECK - 2.6
		local stones = 7
		for s = -1, 1, 2 do
			for i = 0, stones - 1 do
				local t0, t1 = i / stones, (i + 1) / stones
				local function at(t: number): Vector3
					local zz = z0 + span * t
					local yy = spring + (crown - spring) * math.sin(math.pi * t)
					return Vector3.new(s * (HALF - 0.5), yy, zz)
				end
				local a, b = at(t0), at(t1)
				local p = beam(stone, a, b, 1.4, 1.6, vary(C.stonePale, 0.06), M.cobble)
				p.Name = "Voussoir"
				-- The spandrel: masonry from the top of this stone up to the deck,
				-- so the face of the bridge is solid above the opening.
				local top = math.max(a.Y, b.Y) + 0.8
				local under = DECK - 2.4
				if under - top > 0.2 then
					part(stone, Vector3.new(1.2, under - top, (b.Z - a.Z) + 0.1), CFrame.new(s * (HALF - 0.4), (under + top) / 2, (a.Z + b.Z) / 2), vary(C.stone, 0.05), M.stone, "Spandrel")
				end
			end
		end
	end
	arch(Z_PIER + 4, 115)
	arch(121, MOAT.frontOut - 4)

	-- The drawbridge: left down, planks gone, chains still running up into the
	-- gatehouse.
	local draw = group(f, "Drawbridge")
	local z0, z1 = GATE.Z, Z_PIER - 4
	for z = z0 + 1.2, z1 - 1, 2.3 do
		local roll = rng:NextNumber()
		if roll > 0.09 then
			local broken = roll < 0.18
			local length = if broken then rand(12, 20) else HALF * 2 - 2
			local x = if broken then rand(-6, 6) else 0
			local cf = CFrame.new(x, DECK - 0.4, z) * CFrame.Angles(0, if broken then rand(-0.08, 0.08) else 0, if broken then rand(-0.12, 0.12) else 0)
			part(draw, Vector3.new(length, 0.8, 2.1), cf, vary(C.woodDark, 0.18), M.wood, "Plank")
		end
	end
	for s = -1, 1, 2 do
		-- The two great beams the planks are nailed to.
		part(draw, Vector3.new(2, 2, z1 - z0), CFrame.new(s * (HALF - 2), DECK - 1.6, (z0 + z1) / 2), vary(C.woodDark, 0.1), M.log, "Beam")
		-- Iron straps across.
		for z = z0 + 5, z1 - 3, 9 do
			part(draw, Vector3.new(3.4, 0.25, 0.8), CFrame.new(s * (HALF - 2), DECK + 0.05, z), C.rust, M.rust, "Strap")
		end
		-- The chain, from the far end of the drawbridge up into the gatehouse.
		local a = Vector3.new(s * (HALF - 2.5), DECK + 0.6, z1 - 1)
		-- Into the masonry over the arch (it starts at y 48), not into the opening.
		local b = Vector3.new(s * (HALF - 3), 52, GATE.Z + 0.5)
		local links = 34
		for i = 0, links - 1 do
			local t0, t1 = i / links, (i + 1) / links
			-- A slight sag, as a chain hangs.
			local function at(t: number): Vector3
				return a:Lerp(b, t) - Vector3.new(0, math.sin(math.pi * t) * 2.2, 0)
			end
			local p = beam(draw, at(t0), at(t1), if i % 2 == 0 then 0.35 else 0.9, if i % 2 == 0 then 0.9 else 0.35, C.iron, M.iron)
			p.Name = "Link"
		end
	end

	-- Fire at the foot of the bridge: two braziers on the far bank.
	local lights = group(f, "Fires")
	for s = -1, 1, 2 do
		local x, z = s * 20, Z_END + 6
		local y = groundY(x, z)
		local base = Vector3.new(x, y, z)
		for k = 0, 2 do
			local ang = k * math.pi * 2 / 3
			rod(lights, base + Vector3.new(math.cos(ang) * 1.6, 0, math.sin(ang) * 1.6), base + Vector3.new(0, 4.6, 0), 0.3, C.iron, M.iron)
		end
		local bowl = part(lights, Vector3.new(1.2, 3.2, 3.2), CFrame.new(base + Vector3.new(0, 4.8, 0)) * CFrame.Angles(0, 0, math.rad(90)), C.iron, M.iron, "Bowl")
		bowl.Shape = Enum.PartType.Cylinder
		fire(lights, base + Vector3.new(0, 5.6, 0), 1.6, 42) -- the first warm light in the world: big
	end
	-- And two torch poles where the drawbridge meets the gate.
	for s = -1, 1, 2 do
		local base = Vector3.new(s * (HALF - 3.5), DECK, GATE.Z + 6)
		rod(lights, base, base + Vector3.new(0, 7, 0), 0.4, C.woodDark, M.log)
		part(lights, Vector3.new(0.9, 1.2, 0.9), CFrame.new(base + Vector3.new(0, 7.4, 0)), C.iron, M.iron, "Cage")
		fire(lights, base + Vector3.new(0, 8, 0), 0.9, 30)
	end
end

--==========================================================================
-- Forest
--==========================================================================
local function randomFlat(): Vector3
	local a = rand(0, math.pi * 2)
	return Vector3.new(math.cos(a), 0, math.sin(a))
end

local function tree(parent: Instance, base: Vector3, h: number)
	local m = group(parent, "DeadTree")
	local col = vary(C.deadWood, 0.12)
	local thick = h * rand(0.045, 0.065)
	local lean = (Vector3.new(0, 1, 0) + randomFlat() * rand(0.03, 0.18)).Unit
	local mid = base + lean * h * 0.55
	local bend = (lean + randomFlat() * rand(0.05, 0.2)).Unit
	local top = mid + bend * h * 0.45
	rod(m, base - Vector3.new(0, 1.5, 0), mid, thick, col, M.log)
	rod(m, mid, top, thick * 0.62, col, M.log)

	local function branch(from: Vector3, dir: Vector3, len: number, t: number, depth: number)
		local to = from + dir * len
		rod(m, from, to, t, col, M.log)
		if depth > 0 then
			for _ = 1, rng:NextInteger(1, 2) do
				local start = from:Lerp(to, rand(0.5, 0.9))
				local nd = (dir + randomFlat() * rand(0.4, 0.9) + Vector3.new(0, rand(0.1, 0.5), 0)).Unit
				branch(start, nd, len * rand(0.45, 0.6), t * 0.55, depth - 1)
			end
		end
	end
	for _ = 1, rng:NextInteger(3, 5) do
		local along = rand(0.45, 0.95)
		local from = if along < 0.55 then base:Lerp(mid, along / 0.55) else mid:Lerp(top, (along - 0.55) / 0.45)
		local dir = (randomFlat() + Vector3.new(0, rand(0.35, 0.9), 0)).Unit
		branch(from, dir, h * rand(0.25, 0.4), thick * 0.45, 1)
	end
	return m
end

local function buildForest()
	local f = section("Forest")
	local placed = 0
	local tries = 0
	while placed < 230 and tries < 6000 do
		tries += 1
		local x, z = rand(-1350, 1350), rand(-2700, 1500)
		-- Patches, not a carpet: noise decides where the wood is.
		local density = math.noise(x / 340, z / 340, 3.3)
		if density > 0.02 and freeGround(x, z, 60) and segDist(x, z, Vector2.new(-40, 820), Vector2.new(0, 140)) > 110 then
			local y = groundY(x, z)
			if y < 120 then
				tree(f, Vector3.new(x, y, z), rand(18, 34))
				placed += 1
			end
		end
	end
	-- A few loners nearer the castle, standing alone in the flats.
	for _ = 1, 14 do
		local x, z = rand(-650, 650), rand(-2200, 600)
		if freeGround(x, z, 70) and segDist(x, z, Vector2.new(-40, 820), Vector2.new(0, 140)) > 90 then
			tree(f, Vector3.new(x, groundY(x, z), z), rand(16, 26))
		end
	end
	print(("[Surroundings] forest: %d trees"):format(placed))
end

--==========================================================================
-- Village
--==========================================================================
local function cottage(parent: Instance, origin: CFrame, w: number, d: number, smoking: boolean)
	local m = group(parent, "Cottage")
	local T = 1.6
	local function wallRun(a: Vector3, b: Vector3, door: boolean)
		local len = (b - a).Magnitude
		local dir = (b - a).Unit
		local pieces = rng:NextInteger(3, 4)
		local step = len / pieces
		for i = 0, pieces - 1 do
			local isDoor = door and i == math.floor(pieces / 2)
			if not isDoor and rng:NextNumber() > 0.12 then
				local h = rand(2.2, 7.5)
				local c = a + dir * (step * (i + 0.5))
				local cf = origin * CFrame.lookAt(c + Vector3.new(0, h / 2, 0), c + Vector3.new(0, h / 2, 0) + dir)
				part(m, Vector3.new(T, h, step + 0.05), cf, vary(C.stone, 0.08), M.cobble, "Wall")
			end
		end
	end
	local hw, hd = w / 2, d / 2
	wallRun(Vector3.new(-hw, 0, -hd), Vector3.new(hw, 0, -hd), false)
	wallRun(Vector3.new(hw, 0, -hd), Vector3.new(hw, 0, hd), false)
	wallRun(Vector3.new(hw, 0, hd), Vector3.new(-hw, 0, hd), true)
	wallRun(Vector3.new(-hw, 0, hd), Vector3.new(-hw, 0, -hd), false)

	-- The chimney stands; chimneys always do.
	local chimneyH = rand(11, 15)
	part(m, Vector3.new(3.2, chimneyH, 3.2), origin * CFrame.new(-hw + 1.2, chimneyH / 2, rand(-hd + 2, hd - 2)), vary(C.stoneDark, 0.06), M.cobble, "Chimney")

	-- What is left of the roof: charred rafters fallen in.
	for _ = 1, rng:NextInteger(2, 4) do
		local a = Vector3.new(rand(-hw, hw), rand(4, 7), rand(-hd, hd))
		local b = Vector3.new(rand(-hw, hw), 0.3, rand(-hd, hd))
		local wa, wb = origin * a, origin * b
		beam(m, wa, wb, 0.9, 0.9, vary(C.charred, 0.15), M.log)
	end
	-- One corner post still up, black.
	part(m, Vector3.new(1, rand(6, 9), 1), origin * CFrame.new(hw - 0.5, 4, -hd + 0.5), C.charred, M.log, "Post")

	-- Rubble.
	for _ = 1, rng:NextInteger(5, 9) do
		local s = rand(0.8, 2)
		local p = Vector3.new(rand(-hw - 3, hw + 3), s / 3, rand(-hd - 3, hd + 3))
		part(m, Vector3.new(s, s * 0.7, s * 1.2), origin * CFrame.new(p) * CFrame.Angles(rand(0, 3), rand(0, 3), rand(0, 3)), vary(C.stone, 0.1), M.cobble, "Rubble")
	end

	if smoking then
		local at = origin * Vector3.new(rand(-hw / 2, hw / 2), 0.6, rand(-hd / 2, hd / 2))
		fire(m, at, 0.6, 16)
		smoke(m, at + Vector3.new(0, 3, 0), Vector3.new(2, 1, 2), 3, 0.6, Color3.fromRGB(56, 54, 56))
	end
end

local function buildVillage()
	local f = section("Village")
	local spots = {
		{ -232, 520, 0.3 }, { -262, 470, -0.2 }, { -300, 540, 0.9 }, { -214, 430, 1.4 },
		{ -330, 455, 0.1 }, { -282, 395, -0.6 }, { -358, 520, 0.5 },
	}
	for i, s in spots do
		local x, z, yaw = s[1], s[2], s[3]
		cottage(f, onGround(x, z, yaw), rand(14, 20), rand(11, 15), i == 2 or i == 5)
	end
	-- The well, in the middle of what was the green.
	do
		local base = onGround(-268, 498)
		local m = group(f, "Well")
		for k = 0, 9 do
			local a = k / 10 * math.pi * 2
			part(m, Vector3.new(1.6, 2.6, 1.5), base * CFrame.Angles(0, a, 0) * CFrame.new(0, 1.3, 2.6), vary(C.stone, 0.08), M.cobble, "Ring")
		end
		rod(m, (base * CFrame.new(-3, 0, 0)).Position, (base * CFrame.new(-3, 6.5, 0)).Position, 0.5, C.woodDark, M.log)
		rod(m, (base * CFrame.new(3, 0, 0)).Position, (base * CFrame.new(3, 4, 0)).Position, 0.5, C.woodDark, M.log) -- the other post snapped
		rod(m, (base * CFrame.new(-3, 6.2, 0)).Position, (base * CFrame.new(2.4, 3.6, 0.4)).Position, 0.4, C.woodDark, M.log)
	end
	-- A cart on its side by the road.
	do
		local at = onGround(-48, 545, 0.4) * CFrame.new(0, 1.8, 0) * CFrame.Angles(0, 0, math.rad(82))
		part(f, Vector3.new(6, 0.5, 9), at, vary(C.woodDark, 0.1), M.wood, "Cart")
		local wheel = part(f, Vector3.new(0.6, 4.6, 4.6), at * CFrame.new(-1, -3.3, -2.8) * CFrame.Angles(0, 0, math.rad(90)), C.woodDark, M.wood, "Wheel")
		wheel.Shape = Enum.PartType.Cylinder
	end
end

--==========================================================================
-- Battlefield
--==========================================================================
local function buildBattlefield()
	local f = section("Battlefield")

	-- The graves: rows of mounds and crosses, dug in a hurry.
	local graves = group(f, "Graves")
	for row = 0, 4 do
		for col = 0, 7 do
			if rng:NextNumber() < 0.88 then
				local x = 150 + col * 9 + rand(-1, 1)
				local z = 470 - row * 10 + rand(-1, 1)
				local base = onGround(x, z, rand(-0.06, 0.06))
				part(graves, Vector3.new(3.4, 1.1, 7), base * CFrame.new(0, 0.2, 2.4) * CFrame.Angles(rand(-0.03, 0.03), 0, 0), vary(C.earth, 0.1), M.ground, "Mound")
				local tilt = CFrame.Angles(rand(-0.12, 0.12), 0, rand(-0.14, 0.14))
				part(graves, Vector3.new(0.45, 4.4, 0.45), base * CFrame.new(0, 2, -1.3) * tilt, vary(C.woodDark, 0.15), M.log, "Cross")
				part(graves, Vector3.new(2.4, 0.4, 0.4), base * CFrame.new(0, 3.1, -1.3) * tilt, vary(C.woodDark, 0.15), M.log, "CrossBar")
			end
		end
	end

	-- The weapons of the fallen, left standing in the earth.
	local weapons = group(f, "Weapons")
	for _ = 1, 34 do
		local x, z = rand(110, 460), rand(240, 640)
		if freeGround(x, z, 10) then
			local base = Vector3.new(x, groundY(x, z), z)
			local tilt = CFrame.Angles(rand(-0.35, 0.35), rand(0, math.pi * 2), rand(-0.35, 0.35))
			local cf = CFrame.new(base) * tilt
			if rng:NextNumber() < 0.55 then
				part(weapons, Vector3.new(0.4, 4.2, 0.12), cf * CFrame.new(0, 1.2, 0), vary(C.iron, 0.15), M.rust, "Blade")
				part(weapons, Vector3.new(1.8, 0.25, 0.3), cf * CFrame.new(0, 3.3, 0), C.iron, M.iron, "Guard")
				part(weapons, Vector3.new(0.3, 1.3, 0.3), cf * CFrame.new(0, 4.1, 0), C.woodDark, M.log, "Grip")
			else
				part(weapons, Vector3.new(0.3, 9, 0.3), cf * CFrame.new(0, 3.4, 0), vary(C.woodDark, 0.15), M.log, "Shaft")
				wedge(weapons, Vector3.new(0.1, 1.4, 0.5), cf * CFrame.new(0, 8.5, 0), C.iron, M.rust)
			end
		end
	end
	for _ = 1, 12 do
		local x, z = rand(120, 440), rand(250, 620)
		if freeGround(x, z, 10) then
			local shield = part(weapons, Vector3.new(0.4, 4, 4), CFrame.new(x, groundY(x, z) + 0.3, z) * CFrame.Angles(rand(-0.2, 0.2), rand(0, 6), math.rad(90) + rand(-0.15, 0.15)), vary(C.clothOld, 0.2), M.wood, "Shield")
			shield.Shape = Enum.PartType.Cylinder
		end
	end

	-- A trebuchet that never got to fire: frame standing, arm on the ground.
	do
		local m = group(f, "Trebuchet")
		local o = onGround(330, 430, math.rad(-35))
		local col = vary(C.wood, 0.08)
		for s = -1, 1, 2 do
			part(m, Vector3.new(1.4, 1.4, 22), o * CFrame.new(s * 5, 0.7, 0), col, M.log, "Rail")
			beam(m, (o * Vector3.new(s * 5, 0.5, -8)), (o * Vector3.new(s * 4, 16, 0)), 1.3, 1.3, col, M.log)
			beam(m, (o * Vector3.new(s * 5, 0.5, 8)), (o * Vector3.new(s * 4, 16, 0)), 1.3, 1.3, col, M.log)
		end
		part(m, Vector3.new(10, 1.2, 1.2), o * CFrame.new(0, 16, 0), col, M.log, "Axle")
		for z = -9, 9, 6 do
			part(m, Vector3.new(11, 1, 1), o * CFrame.new(0, 1, z), col, M.log, "Cross")
		end
		-- The arm, snapped and fallen.
		beam(m, o * Vector3.new(1, 15.5, 0.5), o * Vector3.new(2, 0.6, 24), 1.6, 1.6, vary(C.woodDark, 0.08), M.log)
		beam(m, o * Vector3.new(-1.5, 0.8, 25), o * Vector3.new(-6, 0.5, 34), 1.4, 1.4, vary(C.woodDark, 0.08), M.log)
		part(m, Vector3.new(6, 5, 6), o * CFrame.new(0, 2.5, -14) * CFrame.Angles(0.1, 0.2, 0.15), vary(C.wood, 0.1), M.wood, "Counterweight")
	end

	-- Banners on poles, torn to strips.
	local banners = group(f, "Banners")
	for _, p in { { 128, 360 }, { 214, 520 }, { 402, 330 }, { 268, 600 }, { 96, 480 }, { 440, 500 } } do
		local x, z = p[1], p[2]
		local base = Vector3.new(x, groundY(x, z), z)
		local lean = CFrame.Angles(rand(-0.12, 0.12), rand(0, 6.28), rand(-0.12, 0.12))
		local pole = CFrame.new(base) * lean
		part(banners, Vector3.new(0.45, 16, 0.45), pole * CFrame.new(0, 8, 0), C.woodDark, M.log, "Pole")
		part(banners, Vector3.new(4.2, 0.3, 0.3), pole * CFrame.new(1.6, 15.4, 0), C.woodDark, M.log, "Crossbar")
		for k = 0, 2 do
			local h = rand(3.5, 7)
			part(banners, Vector3.new(1.3, h, 0.08), pole * CFrame.new(0.4 + k * 1.35, 15.2 - h / 2, 0) * CFrame.Angles(0, 0, rand(-0.06, 0.06)), vary(C.cloth, 0.15), M.cloth, "Cloth")
		end
	end

	-- The gallows by the road.
	do
		local m = group(f, "Gallows")
		local o = onGround(30, 560, math.rad(80))
		part(m, Vector3.new(1.3, 14, 1.3), o * CFrame.new(-3, 7, 0), vary(C.woodDark, 0.1), M.log, "Post")
		part(m, Vector3.new(1.3, 14, 1.3), o * CFrame.new(3, 7, 0), vary(C.woodDark, 0.1), M.log, "Post")
		part(m, Vector3.new(9, 1.3, 1.3), o * CFrame.new(0, 13.6, 0), vary(C.woodDark, 0.1), M.log, "Beam")
		beam(m, o * Vector3.new(-3, 9, 0), o * Vector3.new(-0.6, 13, 0), 0.7, 0.7, C.woodDark, M.log)
		part(m, Vector3.new(0.15, 4, 0.15), o * CFrame.new(1, 11, 0), C.clothOld, M.cloth, "Rope")
		local noose = part(m, Vector3.new(0.2, 1.4, 1.4), o * CFrame.new(1, 8.6, 0), C.clothOld, M.cloth, "Noose")
		noose.Shape = Enum.PartType.Cylinder
		part(m, Vector3.new(10, 1, 6), o * CFrame.new(0, 0.5, 0), vary(C.woodDark, 0.1), M.wood, "Platform")
	end
end

--==========================================================================
-- Hill
--==========================================================================
local function buildHill()
	local f = section("Hill")

	-- The rails the party came in on, ending at a broken buffer stop.
	local rails = group(f, "Rails")
	local railEnd = 812
	local last: Vector3? = nil
	for z = railEnd, railEnd + 320, 4 do
		local x = -40 + (z - railEnd) * 0.05
		local y = groundY(x, z)
		part(rails, Vector3.new(7, 0.5, 1), CFrame.new(x, y + 0.25, z) * CFrame.Angles(0, rand(-0.04, 0.04), 0), vary(C.woodDark, 0.15), M.wood, "Sleeper")
		local here = Vector3.new(x, y + 0.75, z)
		if last and z % 12 == railEnd % 12 then
			for s = -1, 1, 2 do
				beam(rails, last + Vector3.new(s * 2.4, 0, 0), here + Vector3.new(s * 2.4, 0, 0), 0.35, 0.5, C.rust, M.rust)
			end
			last = here
		elseif not last then
			last = here
		end
	end
	do
		local y = groundY(-40, railEnd)
		local o = CFrame.new(-40, y, railEnd - 2)
		part(f, Vector3.new(8, 3, 1.6), o * CFrame.new(0, 2.6, 0) * CFrame.Angles(0, 0, math.rad(6)), vary(C.woodDark, 0.1), M.log, "BufferBeam")
		for s = -1, 1, 2 do
			beam(f, (o * Vector3.new(s * 2.4, 0.5, 0)), (o * Vector3.new(s * 2.4, 3.5, 0)), 0.8, 0.8, C.woodDark, M.log)
			beam(f, (o * Vector3.new(s * 2.4, 0.5, 5)), (o * Vector3.new(s * 2.4, 3.2, 0.6)), 0.8, 0.8, C.woodDark, M.log)
		end
	end

	-- A wayside shrine. The candles are still burning: someone tends it.
	do
		local m = group(f, "Shrine")
		local o = onGround(-66, 792, math.rad(-20))
		part(m, Vector3.new(2.6, 6, 2.6), o * CFrame.new(0, 3, 0), vary(C.stone, 0.06), M.cobble, "Pillar")
		part(m, Vector3.new(3.6, 0.8, 3.6), o * CFrame.new(0, 6.4, 0), vary(C.stonePale, 0.06), M.cobble, "Ledge")
		wedge(m, Vector3.new(4, 2, 2.1), o * CFrame.new(0, 7.8, -1), vary(C.stoneDark, 0.06), M.cobble)
		wedge(m, Vector3.new(4, 2, 2.1), o * CFrame.new(0, 7.8, 1) * CFrame.Angles(0, math.pi, 0), vary(C.stoneDark, 0.06), M.cobble)
		for k = -1, 1 do
			local c = part(m, Vector3.new(0.25, 0.7 + k * 0.1, 0.25), o * CFrame.new(k * 0.7, 7.15, -1.1), Color3.fromRGB(220, 210, 180), Enum.Material.SmoothPlastic, "Candle")
			c.CastShadow = false
		end
		local glow = part(m, Vector3.new(0.3, 0.3, 0.3), o * CFrame.new(0, 7.8, -1.2), Color3.fromRGB(255, 190, 110), Enum.Material.Neon, "Flame")
		glow.CastShadow = false
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 176, 100)
		light.Brightness = 1.2
		light.Range = 12
		light.Parent = glow
	end

	-- The lone tree on the crest that frames the first shot.
	tree(f, Vector3.new(-92, groundY(-92, 772), 772), 34)
	tree(f, Vector3.new(20, groundY(20, 836), 836), 26)
end

--==========================================================================
-- Castle (atmosphere only — nothing of the castle is moved)
--==========================================================================
local function buildCastleAtmosphere()
	local f = section("CastleAtmosphere")

	-- Smoke climbing out of the courts: something is still burning in there.
	for _, t in { 0.15, 0.4, 0.66, 0.88 } do
		local z = alongCastle(t)
		smoke(f, Vector3.new(rand(-60, 60), 70, z), Vector3.new(30, 1, 30), 2.2, 1.6, Color3.fromRGB(46, 44, 48))
	end

	-- The red light in the last tower: the one thing visible from the hill that
	-- says "that is where you are going".
	local bg = gameplay:FindFirstChild("Battleground")
	local last = bg and bg:FindFirstChild("Chamber9")
	local top: BasePart? = nil
	if last then
		for _, d in last:GetDescendants() do
			if d:IsA("BasePart") and (not top or d.Position.Y + d.Size.Y / 2 > top.Position.Y + top.Size.Y / 2) then
				top = d
			end
		end
	end
	local at = if top then top.Position + Vector3.new(0, top.Size.Y / 2 + 6, 0) else Vector3.new(0, 180, alongCastle(0.95))
	local beacon = part(f, Vector3.new(1, 1, 1), CFrame.new(at), Color3.fromRGB(150, 30, 30), M.iron, "CurseLight")
	beacon.Transparency = 1
	beacon.CastShadow = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(190, 40, 36)
	light.Brightness = 4
	light.Range = 60
	light.Parent = beacon
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(220, 60, 50))
	e.LightEmission = 1
	e.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 3), NumberSequenceKeypoint.new(1, 0.5) })
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(2, 4)
	e.Rate = 8
	e.Speed = NumberRange.new(1, 3)
	e.SpreadAngle = Vector2.new(180, 180)
	e.Parent = beacon
	print(("[Surroundings] curse light at %.0f, %.0f, %.0f"):format(at.X, at.Y, at.Z))
end

--==========================================================================
-- Intro marks
--==========================================================================
local function buildIntro()
	local f = section("Intro")
	local function mark(name: string, cf: CFrame, color: Color3)
		local p = part(f, Vector3.new(2, 2, 3), cf, color, Enum.Material.SmoothPlastic, name)
		-- Invisible in the game; its front face is the way it looks.
		p.Transparency = 1
		p.CastShadow = false
		return p
	end

	-- Where each player stands: an arc on the crest, all facing the gate.
	local centre = Vector3.new(HILL.X, groundY(HILL.X, HILL.Z), HILL.Z)
	local toGate = (Vector3.new(GATE.X, centre.Y, GATE.Z) - centre).Unit
	local right = toGate:Cross(Vector3.new(0, 1, 0)).Unit
	local offsets = { 0, -1, 1, -2, 2, -3 }
	for i, o in offsets do
		local p = centre + right * (o * 4.2) - toGate * (math.abs(o) * 1.2)
		p = Vector3.new(p.X, groundY(p.X, p.Z) + 3, p.Z)
		mark("Stand" .. i, CFrame.lookAt(p, p + toGate), Color3.fromRGB(80, 160, 80))
	end

	-- Camera marks, in order. Each part's CFrame IS the camera: move one in
	-- Studio and the shot moves with it. Framed from screenshots (2026-10-18):
	-- the party can only be in the same frame as the castle from BEHIND them,
	-- so the talking shots are over their shoulders, not at their faces.
	local castle = Vector3.new(0, 40, 0)
	local cams = {
		-- 1: high and wide, behind the hill: rails, shrine, party, road, castle.
		CFrame.lookAt(Vector3.new(-95, 120, 1010), castle),
		-- 2: craned down to their shoulders, the castle centred.
		CFrame.lookAt(Vector3.new(-46, 55, 812), Vector3.new(-12, 42, 0)),
		-- 3: behind them, right: the party on the left third, the castle on the right.
		CFrame.lookAt(Vector3.new(-24, 50.5, 806), Vector3.new(-52, 40, 500)),
		-- 4: the same from the left.
		CFrame.lookAt(Vector3.new(-58, 50.5, 806), Vector3.new(-20, 40, 500)),
		-- 5: down the road, low, the castle filling the frame.
		CFrame.lookAt(Vector3.new(-14, 30, 430), Vector3.new(0, 22, 40)),
		-- 6: the gate, the braziers, the drawbridge.
		CFrame.lookAt(Vector3.new(4, 12, 200), Vector3.new(0, 20, 40)),
	}
	for i, cf in cams do
		mark("Cam" .. i, cf, Color3.fromRGB(80, 120, 200))
	end

	-- Moonlight on the party, so the characters are not black cut-outs against
	-- the sky. Cold, soft and shadowless: it is the moon, not a lamp.
	local fill = mark("MoonFill", CFrame.new(centre + Vector3.new(0, 20, 16)), Color3.fromRGB(150, 164, 196))
	fill.Size = Vector3.new(1, 1, 1)
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(150, 164, 196)
	light.Brightness = 0.9
	light.Range = 30
	light.Shadows = false
	light.Parent = fill
end

--==========================================================================
local BUILDERS = {
	Moat = buildMoat,
	Bridge = buildBridge,
	Forest = buildForest,
	Village = buildVillage,
	Battlefield = buildBattlefield,
	Hill = buildHill,
	Castle = buildCastleAtmosphere,
	Intro = buildIntro,
}
local ORDER = { "Moat", "Bridge", "Village", "Battlefield", "Hill", "Forest", "Castle", "Intro" }

local Tool = {}

function Tool.run(list: { string })
	pcall(function()
		ChangeHistoryService:SetWaypoint("Surroundings: before")
	end)
	local wanted = {}
	for _, name in list do
		wanted[name] = true
	end
	for _, name in ORDER do
		if wanted.all or wanted[name] then
			local before = made
			BUILDERS[name]()
			print(("[Surroundings] %s: %d parts"):format(name, made - before))
		end
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("Surroundings")
	end)
	return made
end

local AUTO_RUN = true
if AUTO_RUN then
	Tool.run(SECTIONS)
end

return Tool
