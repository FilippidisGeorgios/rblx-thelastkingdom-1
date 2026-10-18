--[[
	LightCastle — run in the Studio Command Bar of the FORGOTTEN LANDS place, in
	EDIT MODE, after tools/BuildChambers.luau. Select all, copy, paste, Enter.

	The castle had no light in it at all: not one Light instance inside the
	walls. This puts in the light and the last layer of things that tell a
	player where they are and what happened here.

	  Torches      on the inner faces of the walls and towers, found by casting
	               at them, so every bracket sits on real stone
	  Passages     a torch either side of every passage, so the way on is the
	               brightest thing in a room
	  Braziers     two per chamber, off the centre (the centre is for fighting)
	  Windows      a share of the towers' window openings glow ember: somebody,
	               or something, still keeps a fire up there
	  Banners      torn standards hung on the walls
	  Clutter      bones, broken blades, arrows, shields, scorch marks — what a
	               fight leaves behind, more of it the deeper you go
	  Ash          falling slowly through every chamber
	  The King     chamber 9: two statues of kings flanking the way to the tower,
	               and fires burning red

	Everything goes into `Gameplay.Battleground.Lighting` (one folder per
	chamber); window glow is done by repainting the window parts themselves and
	is undone with MODE = "undo", which also removes that folder.

	Nothing here collides. The arena floors stay clear: nothing on a spawn, on
	the centre, or on a Storyteller or Checkpoint mark.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local MODE = "build" -- "build" | "undo"
local SEED = 1240

--==========================================================================
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local rng = Random.new(SEED)

local Z_START = 20
local CHAMBER_D = 200
local CHAMBERS = 9
local PASSAGE_X = 115
local GROUND = 2

local WINDOW_SHARE = 0.22 -- of the towers' window openings, how many are lit

local C = {
	iron = Color3.fromRGB(46, 42, 40),
	wood = Color3.fromRGB(58, 42, 30),
	woodDark = Color3.fromRGB(40, 30, 22),
	cloth = Color3.fromRGB(92, 28, 32),
	clothTrim = Color3.fromRGB(150, 118, 52),
	clothOld = Color3.fromRGB(76, 62, 48),
	bone = Color3.fromRGB(176, 166, 146),
	steel = Color3.fromRGB(110, 110, 112),
	rust = Color3.fromRGB(96, 58, 38),
	scorch = Color3.fromRGB(24, 22, 22),
	stone = Color3.fromRGB(96, 92, 86),
	stoneDark = Color3.fromRGB(64, 62, 62),
	ember = Color3.fromRGB(196, 104, 52),
	fire = Color3.fromRGB(255, 160, 86),
	curse = Color3.fromRGB(200, 46, 40),
}

local M = {
	iron = Enum.Material.Metal,
	rust = Enum.Material.CorrodedMetal,
	wood = Enum.Material.Wood,
	cloth = Enum.Material.Fabric,
	stone = Enum.Material.Slate,
	bone = Enum.Material.SmoothPlastic,
}

local gameplay = workspace:FindFirstChild("Gameplay")
local battleground = gameplay and gameplay:FindFirstChild("Battleground")
assert(battleground, "[LightCastle] no Gameplay.Battleground")

--==========================================================================
-- Undo
--==========================================================================
local function undo()
	local old = battleground:FindFirstChild("Lighting")
	if old then
		old:Destroy()
	end
	local restored = 0
	for _, d in battleground:GetDescendants() do
		if d:IsA("BasePart") and d:GetAttribute("GlowOrigColor") then
			d.Color = d:GetAttribute("GlowOrigColor")
			d.Material = Enum.Material[d:GetAttribute("GlowOrigMaterial")]
			d:SetAttribute("GlowOrigColor", nil)
			d:SetAttribute("GlowOrigMaterial", nil)
			restored += 1
		end
	end
	print(("[LightCastle] undone: folder removed, %d windows put back"):format(restored))
end

pcall(function()
	ChangeHistoryService:SetWaypoint("LightCastle: before")
end)
undo()
if MODE == "undo" then
	return
end

local root = Instance.new("Folder")
root.Name = "Lighting"
root.Parent = battleground

local made, lights = 0, 0

--==========================================================================
-- Primitives
--==========================================================================
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
	p.CastShadow = false
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

local function rod(parent: Instance, a: Vector3, b: Vector3, thick: number, color: Color3, material: Enum.Material): Part
	local p = part(parent, Vector3.new((b - a).Magnitude, thick, thick), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), color, material)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function group(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local function flame(parent: Instance, at: Vector3, scale: number, color: Color3, range: number, brightness: number)
	local anchor = part(parent, Vector3.new(0.3, 0.3, 0.3), CFrame.new(at), color, M.iron, "Flame")
	anchor.Transparency = 1
	local f = Instance.new("ParticleEmitter")
	f.Texture = "rbxasset://textures/particles/fire_main.dds"
	f.Color = ColorSequence.new(color, color:Lerp(Color3.new(0.5, 0.1, 0.05), 0.6))
	f.LightEmission = 0.85
	f.Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.3 * scale), NumberSequenceKeypoint.new(1, 0.15) })
	f.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.25), NumberSequenceKeypoint.new(1, 1) })
	f.Lifetime = NumberRange.new(0.4, 0.8)
	f.Rate = 22
	f.Speed = NumberRange.new(2 * scale, 3.5 * scale)
	f.SpreadAngle = Vector2.new(10, 10)
	f.Acceleration = Vector3.new(0, 2.5, 0)
	f.Parent = anchor
	local light = Instance.new("PointLight")
	light.Color = color
	light.Range = range
	light.Brightness = brightness
	light.Shadows = false
	light.Parent = anchor
	lights += 1
	return anchor
end

--==========================================================================
-- Where things may not go
--==========================================================================
local waypoints: { Vector2 } = {}
do
	table.insert(waypoints, Vector2.new(0, Z_START - 40))
	for i = 1, CHAMBERS - 1 do
		local zNear = Z_START - (i - 1) * CHAMBER_D
		local zFar = zNear - CHAMBER_D
		local x = if i % 2 == 1 then PASSAGE_X else -PASSAGE_X
		table.insert(waypoints, Vector2.new(x * 0.35, zNear - CHAMBER_D * 0.35))
		table.insert(waypoints, Vector2.new(x, zFar + 34))
		table.insert(waypoints, Vector2.new(x, zFar - 12))
	end
	table.insert(waypoints, Vector2.new(0, Z_START - CHAMBERS * CHAMBER_D + 30))
end

local function distanceToPath(x: number, z: number): number
	local p = Vector2.new(x, z)
	local best = math.huge
	for i = 1, #waypoints - 1 do
		local a, b = waypoints[i], waypoints[i + 1]
		local ab = b - a
		local t = math.clamp((p - a):Dot(ab) / math.max(ab:Dot(ab), 0.001), 0, 1)
		best = math.min(best, (p - (a + ab * t)).Magnitude)
	end
	return best
end

local keepClear: { { x: number, z: number, r: number } } = {}
for i = 1, CHAMBERS do
	local zNear = Z_START - (i - 1) * CHAMBER_D
	table.insert(keepClear, { x = 0, z = zNear - 100, r = 16 })
	local chamber = battleground:FindFirstChild("Chamber" .. i)
	if chamber then
		for _, d in chamber:GetDescendants() do
			if d:IsA("BasePart") then
				local role = d.Parent and d.Parent.Name
				if role == "Spawns" or role == "Objectives" then
					table.insert(keepClear, { x = d.Position.X, z = d.Position.Z, r = 10 })
				elseif d.Name == "Checkpoint" or d.Name == "Storyteller" then
					table.insert(keepClear, { x = d.Position.X, z = d.Position.Z, r = 8 })
				end
			end
		end
	end
end
table.insert(keepClear, { x = 0, z = -40, r = 30 }) -- the arrival pad
table.insert(keepClear, { x = -88, z = -364, r = 14 }) -- the winch

local function clear(x: number, z: number, r: number): boolean
	for _, k in keepClear do
		if (Vector2.new(x - k.x, z - k.z)).Magnitude < k.r + r then
			return false
		end
	end
	return true
end

-- Everything solid that is already here: castle, chambers, decorations.
local solidParams = OverlapParams.new()
solidParams.FilterType = Enum.RaycastFilterType.Exclude
solidParams.FilterDescendantsInstances = { root }

local rayParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Include
do
	local list = {}
	for _, child in battleground:GetChildren() do
		if child.Name == "Shell" or child.Name:match("^Chamber%d") then
			table.insert(list, child)
		end
	end
	rayParams.FilterDescendantsInstances = list
end

local function emptyAt(at: Vector3, size: Vector3): boolean
	local hits = workspace:GetPartBoundsInBox(CFrame.new(at), size, solidParams)
	for _, h in hits do
		if h.CanCollide and h.Transparency < 1 then
			return false
		end
	end
	return true
end

--==========================================================================
-- Torches
--==========================================================================
-- A bracket on the wall where a ray from the room hits stone.
local function wallTorch(parent: Instance, from: Vector3, dir: Vector3, maxDist: number): boolean
	local hit = workspace:Raycast(from, dir * maxDist, rayParams)
	if not hit or math.abs(hit.Normal.Y) > 0.3 then
		return false
	end
	local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
	local base = hit.Position + n * 0.2
	local m = group(parent, "Torch")
	local face = CFrame.lookAt(base, base + n)
	part(m, Vector3.new(1.4, 2.2, 0.4), face * CFrame.new(0, 0, -0.1), C.iron, M.iron, "Plate")
	rod(m, base + n * 0.2, base + n * 1.6 + Vector3.new(0, 0.6, 0), 0.25, C.iron, M.iron)
	local cup = base + n * 1.7 + Vector3.new(0, 0.7, 0)
	part(m, Vector3.new(0.9, 0.5, 0.9), CFrame.new(cup), C.iron, M.iron, "Cup")
	rod(m, cup - Vector3.new(0, 0.2, 0), cup + Vector3.new(0, 1.6, 0) + n * 0.25, 0.35, C.woodDark, M.wood)
	-- A yard is 300 studs across: a torch has to throw a real pool, not a glint.
	flame(m, cup + Vector3.new(0, 2, 0) + n * 0.3, 1, C.fire, 36, 2.8)
	return true
end

local function buildTorches(index: number, f: Instance)
	local zNear = Z_START - (index - 1) * CHAMBER_D
	local placed = 0
	-- Along both side walls, cast outward from the room at torch height.
	for z = zNear - 30, zNear - CHAMBER_D + 30, -34 do
		for side = -1, 1, 2 do
			local from = Vector3.new(side * 60, GROUND + 11, z + rand(-4, 4))
			if wallTorch(f, from, Vector3.new(side, 0, 0), 120) then
				placed += 1
			end
		end
	end
	-- Either side of the way on: the passage is the brightest thing in the room.
	if index < CHAMBERS then
		local x = if index % 2 == 1 then PASSAGE_X else -PASSAGE_X
		local zWall = zNear - CHAMBER_D + 40
		for _, dx in { -32, 32 } do
			if wallTorch(f, Vector3.new(x + dx, GROUND + 12, zWall), Vector3.new(0, 0, -1), 60) then
				placed += 1
			end
		end
	end
	return placed
end

--==========================================================================
-- Braziers
--==========================================================================
local function brazier(parent: Instance, at: Vector3, color: Color3)
	local m = group(parent, "Brazier")
	for k = 0, 2 do
		local a = k * math.pi * 2 / 3
		rod(m, at + Vector3.new(math.cos(a) * 1.8, 0, math.sin(a) * 1.8), at + Vector3.new(0, 4.4, 0), 0.32, C.iron, M.iron)
	end
	local bowl = part(m, Vector3.new(1.3, 3.6, 3.6), CFrame.new(at + Vector3.new(0, 4.6, 0)) * CFrame.Angles(0, 0, math.rad(90)), C.iron, M.iron, "Bowl")
	bowl.Shape = Enum.PartType.Cylinder
	part(m, Vector3.new(2.6, 0.5, 2.6), CFrame.new(at + Vector3.new(0, 5.1, 0)), C.ember, Enum.Material.Neon, "Coals")
	flame(m, at + Vector3.new(0, 5.6, 0), 1.7, color, 50, 3.6)
end

local function buildBraziers(index: number, f: Instance)
	local zMid = Z_START - (index - 1) * CHAMBER_D - 100
	local placed = 0
	-- Four: two each side, one in each half of the room, so no part of the
	-- yard is more than a short run from a fire.
	for _, slot in { { -1, 1 }, { -1, -1 }, { 1, 1 }, { 1, -1 } } do
		for _ = 1, 30 do
			local x = slot[1] * rand(26, 80)
			local z = zMid + slot[2] * rand(12, 62)
			if clear(x, z, 4) and distanceToPath(x, z) > 9 and emptyAt(Vector3.new(x, GROUND + 3, z), Vector3.new(5, 5, 5)) then
				brazier(f, Vector3.new(x, GROUND, z), C.fire)
				placed += 1
				break
			end
		end
	end
	return placed
end

--==========================================================================
-- Banners
--==========================================================================
local function banner(parent: Instance, from: Vector3, dir: Vector3): boolean
	local hit = workspace:Raycast(from, dir * 140, rayParams)
	if not hit or math.abs(hit.Normal.Y) > 0.3 then
		return false
	end
	local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
	local top = hit.Position + n * 0.35
	local m = group(parent, "Banner")
	local face = CFrame.lookAt(top, top + n)
	local w, h = 7, rand(15, 21)
	part(m, Vector3.new(w + 1.5, 0.5, 0.5), face, C.woodDark, M.wood, "Pole")
	-- Torn into strips at the bottom: the cloth is longer in the middle.
	local strips = 4
	for s = 0, strips - 1 do
		local sh = h * (if s == 1 or s == 2 then rand(0.85, 1) else rand(0.55, 0.8))
		local x = -w / 2 + w * (s + 0.5) / strips
		part(m, Vector3.new(w / strips + 0.02, sh, 0.12), face * CFrame.new(x, -sh / 2 - 0.3, 0.1), vary(C.cloth, 0.1), M.cloth, "Cloth")
	end
	-- A gold band across, the house colour.
	part(m, Vector3.new(w + 0.04, 0.9, 0.14), face * CFrame.new(0, -h * 0.3, 0.13), C.clothTrim, M.cloth, "Trim")
	return true
end

local function buildBanners(index: number, f: Instance)
	local zNear = Z_START - (index - 1) * CHAMBER_D
	local placed = 0
	for _ = 1, 3 do
		local side = if rng:NextNumber() < 0.5 then -1 else 1
		local z = zNear - rand(40, 160)
		if banner(f, Vector3.new(side * 60, GROUND + 34, z), Vector3.new(side, 0, 0)) then
			placed += 1
		end
	end
	return placed
end

--==========================================================================
-- Clutter: what the fight left
--==========================================================================
local function clutterAt(parent: Instance, x: number, z: number, deep: number)
	local roll = rng:NextNumber()
	local y = GROUND
	local yaw = rand(0, math.pi * 2)
	local base = CFrame.new(x, y, z) * CFrame.Angles(0, yaw, 0)
	if roll < 0.22 then
		-- Bones: a skull and a few long bones.
		local m = group(parent, "Bones")
		local skull = part(m, Vector3.new(1.1, 1.1, 1.1), base * CFrame.new(0, 0.5, 0), C.bone, M.bone, "Skull")
		skull.Shape = Enum.PartType.Ball
		for _ = 1, 3 do
			local a = base * CFrame.new(rand(-2, 2), 0.2, rand(-2, 2))
			rod(m, a.Position, (a * CFrame.new(rand(-2.5, 2.5), 0, rand(-2.5, 2.5))).Position, 0.28, vary(C.bone, 0.08), M.bone)
		end
	elseif roll < 0.42 then
		-- A broken blade lying flat.
		local m = group(parent, "Blade")
		part(m, Vector3.new(0.35, 0.12, rand(1.8, 3.4)), base * CFrame.new(0, 0.1, 0), vary(C.steel, 0.15), M.rust, "Blade")
		part(m, Vector3.new(1.4, 0.2, 0.25), base * CFrame.new(0, 0.12, -1.9), C.iron, M.iron, "Guard")
		part(m, Vector3.new(0.25, 0.25, 1.1), base * CFrame.new(0, 0.12, -2.6), C.woodDark, M.wood, "Grip")
	elseif roll < 0.58 then
		-- Arrows stuck in the ground, in a little spread.
		local m = group(parent, "Arrows")
		for _ = 1, rng:NextInteger(2, 5) do
			local p = base * CFrame.new(rand(-2, 2), 0, rand(-2, 2))
			local tip = p.Position - Vector3.new(0, 0.3, 0)
			local tail = tip + Vector3.new(rand(-0.6, 0.6), 2.4, rand(-0.6, 0.6))
			rod(m, tip, tail, 0.1, C.wood, M.wood)
			part(m, Vector3.new(0.05, 0.4, 0.3), CFrame.lookAt(tail, tail + Vector3.new(0, 1, 0)), C.clothOld, M.cloth, "Fletch")
		end
	elseif roll < 0.72 then
		-- A shield, face down or propped.
		local s = part(parent, Vector3.new(0.4, 4, 4), base * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90) + rand(-0.2, 0.2)), vary(C.clothOld, 0.2), M.wood, "Shield")
		s.Shape = Enum.PartType.Cylinder
	elseif roll < 0.86 then
		-- A scorch mark where something burned.
		local s = part(parent, Vector3.new(0.1, rand(5, 9), rand(5, 9)), base * CFrame.new(0, 0.06, 0) * CFrame.Angles(0, 0, math.rad(90)), C.scorch, Enum.Material.Ground, "Scorch")
		s.Shape = Enum.PartType.Cylinder
		s.Transparency = 0.15
	else
		-- A helm, rolled away from whoever wore it.
		local h = part(parent, Vector3.new(1.4, 1.2, 1.4), base * CFrame.new(0, 0.55, 0) * CFrame.Angles(rand(-1, 1), 0, rand(-1, 1)), vary(C.steel, 0.2), M.rust, "Helm")
		h.Shape = Enum.PartType.Ball
	end
	return deep
end

local function buildClutter(index: number, f: Instance)
	local zNear = Z_START - (index - 1) * CHAMBER_D
	-- More of it the further in: the fight went this way and lost ground.
	local count = 14 + index * 4
	local placed = 0
	for _ = 1, count * 6 do
		if placed >= count then
			break
		end
		local x, z = rand(-118, 118), zNear - rand(22, 178)
		if clear(x, z, 3) and emptyAt(Vector3.new(x, GROUND + 2, z), Vector3.new(4, 3, 4)) then
			clutterAt(f, x, z, index)
			placed += 1
		end
	end
	return placed
end

--==========================================================================
-- Ash, falling through the whole room
--==========================================================================
local function buildAsh(index: number, f: Instance)
	local zMid = Z_START - (index - 1) * CHAMBER_D - 100
	local anchor = part(f, Vector3.new(240, 1, 170), CFrame.new(0, 70, zMid), C.stone, M.stone, "AshSource")
	anchor.Transparency = 1
	local e = Instance.new("ParticleEmitter")
	e.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	e.Color = ColorSequence.new(Color3.fromRGB(150, 146, 140))
	e.LightInfluence = 1
	e.Size = NumberSequence.new(0.25)
	e.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1), NumberSequenceKeypoint.new(0.15, 0.3), NumberSequenceKeypoint.new(1, 1) })
	e.Lifetime = NumberRange.new(14, 22)
	e.Rate = 10 + index
	e.Speed = NumberRange.new(2, 4)
	e.EmissionDirection = Enum.NormalId.Bottom
	e.SpreadAngle = Vector2.new(20, 20)
	e.Acceleration = Vector3.new(0.8, 0, 0.3)
	e.RotSpeed = NumberRange.new(-60, 60)
	e.Parent = anchor
end

--==========================================================================
-- Chamber 9: the King's own court
--==========================================================================
local function statue(parent: Instance, at: Vector3, facing: Vector3)
	local m = group(parent, "KingStatue")
	local base = CFrame.lookAt(at, at + facing)
	part(m, Vector3.new(8, 3, 8), base * CFrame.new(0, 1.5, 0), C.stoneDark, M.stone, "Plinth").CastShadow = true
	part(m, Vector3.new(6.4, 2, 6.4), base * CFrame.new(0, 4, 0), C.stone, M.stone, "Plinth2")
	-- A robed figure, crowned, hands on a sword point-down.
	part(m, Vector3.new(4.2, 9, 3), base * CFrame.new(0, 9.5, 0), C.stone, M.stone, "Robe").CastShadow = true
	part(m, Vector3.new(5.6, 2, 3.2), base * CFrame.new(0, 14.2, 0), C.stone, M.stone, "Shoulders")
	local head = part(m, Vector3.new(2.2, 2.6, 2.2), base * CFrame.new(0, 16.4, 0), C.stone, M.stone, "Head")
	head.Shape = Enum.PartType.Ball
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		part(m, Vector3.new(0.4, 0.9, 0.4), base * CFrame.new(math.cos(a) * 1, 17.9, math.sin(a) * 1), C.stoneDark, M.stone, "CrownPoint")
	end
	part(m, Vector3.new(2.6, 0.5, 2.6), base * CFrame.new(0, 17.4, 0), C.stoneDark, M.stone, "Crown")
	part(m, Vector3.new(0.5, 8, 0.2), base * CFrame.new(0, 8, -2), C.stoneDark, M.stone, "Sword")
	part(m, Vector3.new(2.6, 0.4, 0.4), base * CFrame.new(0, 12.2, -2), C.stoneDark, M.stone, "Guard")
	-- The face has been struck off one of them. Nobody will say by whom.
	return m
end

--[[
	The last room is where the King is fought, so it is built as a throne room
	with the roof gone: a dais against the back wall, an empty throne, a red
	carpet running from it toward the way in, two kings in stone either side,
	and fires that burn red. The player should know where to look the moment
	they walk in.
]]
local function scaledStatue(parent: Instance, at: Vector3, facing: Vector3, scale: number)
	local m = statue(parent, at, facing)
	m:ScaleTo(scale)
	-- ScaleTo grows about the model's centre; sit it back down on the ground.
	local cf, size = m:GetBoundingBox()
	m:PivotTo(m:GetPivot() + Vector3.new(0, (GROUND - (cf.Y - size.Y / 2)), 0))
	return m
end

local function buildKingsCourt(f: Instance)
	local zNear = Z_START - (CHAMBERS - 1) * CHAMBER_D
	local zBack = zNear - CHAMBER_D + 22 -- just in front of the back wall
	local court = group(f, "ThroneRoom")

	-- The dais: three steps, solid underfoot.
	for i = 0, 2 do
		local w, d = 40 - i * 8, 22 - i * 5
		local step = part(court, Vector3.new(w, 1.2, d), CFrame.new(0, GROUND + 0.6 + i * 1.2, zBack + d / 2 - 2), if i == 2 then C.stone else C.stoneDark, M.stone, "Dais")
		step.CanCollide = true
		step.CastShadow = true
	end
	local seat = Vector3.new(0, GROUND + 3.6, zBack + 4)
	-- The throne: high back, arms, and the seat empty.
	local throne = group(court, "Throne")
	part(throne, Vector3.new(7, 1.2, 6), CFrame.new(seat + Vector3.new(0, 1.8, 0)), C.woodDark, M.wood, "Seat")
	part(throne, Vector3.new(7, 13, 1.2), CFrame.new(seat + Vector3.new(0, 7, -2.6)), C.woodDark, M.wood, "Back").CastShadow = true
	for _, s in { -1, 1 } do
		part(throne, Vector3.new(1.2, 4.6, 6), CFrame.new(seat + Vector3.new(s * 3.6, 3, 0)), C.wood, M.wood, "Arm")
		part(throne, Vector3.new(1.2, 2.2, 1.2), CFrame.new(seat + Vector3.new(s * 3.2, 14.2, -2.6)), C.clothTrim, M.iron, "Finial")
	end
	part(throne, Vector3.new(5.6, 7, 0.2), CFrame.new(seat + Vector3.new(0, 7.6, -1.9)), C.cloth, M.cloth, "BackCloth")
	-- The carpet, from the throne toward the room, frayed at its far end.
	local carpetLen = 96
	part(court, Vector3.new(8, 0.15, carpetLen), CFrame.new(0, GROUND + 0.1, zBack + 22 + carpetLen / 2), vary(C.cloth, 0.05), M.cloth, "Carpet")
	for _, s in { -1, 1 } do
		part(court, Vector3.new(0.6, 0.18, carpetLen), CFrame.new(s * 3.7, GROUND + 0.12, zBack + 22 + carpetLen / 2), C.clothTrim, M.cloth, "CarpetTrim")
	end

	-- Two kings in stone, twice a man's height, facing whoever comes in.
	for _, side in { -1, 1 } do
		for _, dz in { 30, 0, 60 } do
			local at = Vector3.new(side * 30, GROUND, zBack + 26 + dz)
			if emptyAt(at + Vector3.new(0, 8, 0), Vector3.new(10, 14, 10)) then
				scaledStatue(court, at, Vector3.new(0, 0, 1), 1.6)
				break
			end
		end
	end

	-- Red fire: one either side of the dais, and the back wall washed red.
	for _, side in { -1, 1 } do
		for _, dx in { 26, 32, 20, 38 } do
			local b = Vector3.new(side * dx, GROUND, zBack + 12)
			if emptyAt(b + Vector3.new(0, 3, 0), Vector3.new(4, 5, 4)) then
				brazier(court, b, C.curse)
				break
			end
		end
	end
	local wash = part(court, Vector3.new(1, 1, 1), CFrame.new(0, GROUND + 24, zBack + 14), C.curse, M.iron, "CurseWash")
	wash.Transparency = 1
	local red = Instance.new("PointLight")
	red.Color = C.curse
	red.Range = 60
	red.Brightness = 2.4
	red.Shadows = false
	red.Parent = wash
	lights += 1
end

--==========================================================================
-- Fires inside the buildings
--==========================================================================
--[[
	Light from INSIDE is what makes a building read as a place rather than a
	shape: it comes out through the doorways, the windows and the gaps in the
	roof, and it says someone kept a fire here. The Great Hall gets a fire pit
	and two iron chandeliers, the chapel its candles, and about half the houses
	a hearth.
]]
local function chandelier(parent: Instance, at: Vector3)
	local m = group(parent, "Chandelier")
	for k = 0, 11 do
		local a0, a1 = k / 12 * math.pi * 2, (k + 1) / 12 * math.pi * 2
		rod(m, at + Vector3.new(math.cos(a0) * 4, 0, math.sin(a0) * 4), at + Vector3.new(math.cos(a1) * 4, 0, math.sin(a1) * 4), 0.3, C.iron, M.iron)
	end
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		rod(m, at + Vector3.new(math.cos(a) * 4, 0, math.sin(a) * 4), at + Vector3.new(0, 7, 0), 0.15, C.iron, M.iron)
	end
	rod(m, at + Vector3.new(0, 7, 0), at + Vector3.new(0, 18, 0), 0.2, C.iron, M.iron)
	for k = 0, 5 do
		local a = k / 6 * math.pi * 2
		local c = at + Vector3.new(math.cos(a) * 4, 0.6, math.sin(a) * 4)
		part(m, Vector3.new(0.35, 0.9, 0.35), CFrame.new(c), Color3.fromRGB(214, 204, 176), M.bone, "Candle")
		part(m, Vector3.new(0.25, 0.4, 0.25), CFrame.new(c + Vector3.new(0, 0.7, 0)), Color3.fromRGB(255, 196, 120), Enum.Material.Neon, "Wick")
	end
	local light = Instance.new("PointLight")
	light.Color = C.fire
	light.Range = 36
	light.Brightness = 2
	light.Shadows = false
	light.Parent = m:FindFirstChild("Wick") :: Instance
	lights += 1
end

local function buildInteriors(): number
	local deco = battleground:FindFirstChild("Decorations")
	if not deco then
		return 0
	end
	local lit = 0
	for _, area in deco:GetChildren() do
		local f = root:FindFirstChild(area.Name) or root
		for _, m in area:GetChildren() do
			if m:IsA("Model") then
				local cf, size = m:GetBoundingBox()
				local floor = Vector3.new(cf.X, GROUND, cf.Z)
				if m.Name == "GreatHall" then
					-- The fire pit down the middle, and the chandeliers over the table.
					local pit = group(f, "FirePit")
					for k = 0, 9 do
						local a = k / 10 * math.pi * 2
						part(pit, Vector3.new(1.6, 1.2, 1.6), CFrame.new(floor + Vector3.new(math.cos(a) * 4, 4.8, math.sin(a) * 4)), C.stoneDark, M.stone, "Kerb")
					end
					part(pit, Vector3.new(6, 0.4, 6), CFrame.new(floor + Vector3.new(0, 4.6, 0)), C.ember, Enum.Material.Neon, "Embers")
					flame(pit, floor + Vector3.new(0, 6, 0), 2.2, C.fire, 60, 3.4)
					local long = if size.X >= size.Z then Vector3.new(1, 0, 0) else Vector3.new(0, 0, 1)
					chandelier(f, floor + long * 16 + Vector3.new(0, 20, 0))
					chandelier(f, floor - long * 16 + Vector3.new(0, 20, 0))
					lit += 1
				elseif m.Name == "Chapel" then
					local altar = m:FindFirstChild("Altar", true)
					if altar and altar:IsA("BasePart") then
						local top = altar.Position + Vector3.new(0, altar.Size.Y / 2, 0)
						for k = -2, 2 do
							local c = (altar.CFrame * CFrame.new(k * 1.6, altar.Size.Y / 2 + 0.6, 0)).Position
							part(f, Vector3.new(0.4, 1.2 + math.abs(k) * 0.2, 0.4), CFrame.new(c), Color3.fromRGB(214, 204, 176), M.bone, "Candle")
							part(f, Vector3.new(0.25, 0.4, 0.25), CFrame.new(c + Vector3.new(0, 0.9, 0)), Color3.fromRGB(255, 196, 120), Enum.Material.Neon, "Wick")
						end
						flame(f, top + Vector3.new(0, 2.2, 0), 0.4, C.fire, 28, 2)
						lit += 1
					end
				elseif (m.Name == "House" or m.Name == "LongBuilding") and rng:NextNumber() < 0.5 then
					-- A hearth still burning. Low, so the light spills out of the
					-- doorway and the windows rather than lighting the roof.
					flame(f, floor + Vector3.new(0, 5, 0), 0.8, C.fire, 26, 2.4)
					lit += 1
				end
			end
		end
	end
	return lit
end

--==========================================================================
-- Windows
--==========================================================================
local function lightWindows(): number
	local lit = 0
	for _, d in battleground:GetDescendants() do
		if d:IsA("BasePart") and d.Name == "Opening" and not d:IsDescendantOf(root) then
			if rng:NextNumber() < WINDOW_SHARE then
				d:SetAttribute("GlowOrigColor", d.Color)
				d:SetAttribute("GlowOrigMaterial", d.Material.Name)
				d.Material = Enum.Material.Neon
				-- Dim and deep: an ember behind glass, not a lamp.
				d.Color = Color3.fromRGB(150, 70, 30):Lerp(Color3.fromRGB(190, 100, 44), rng:NextNumber())
				lit += 1
			end
		end
	end
	return lit
end

--==========================================================================
local report = {}
for index = 1, CHAMBERS do
	local f = Instance.new("Folder")
	f.Name = "Area" .. index
	f.Parent = root
	local torches = buildTorches(index, f)
	local braziers = if index == CHAMBERS then 0 else buildBraziers(index, f)
	local banners = buildBanners(index, f)
	local clutter = buildClutter(index, f)
	buildAsh(index, f)
	if index == CHAMBERS then
		buildKingsCourt(f)
	end
	table.insert(report, ("Area%d: %d torches, %d braziers, %d banners, %d clutter"):format(index, torches, braziers, banners, clutter))
end
local windows = lightWindows()
local interiors = buildInteriors()
print(("[LightCastle] %d buildings with a fire inside"):format(interiors))

pcall(function()
	ChangeHistoryService:SetWaypoint("LightCastle")
end)
print(table.concat(report, "\n"))
print(("[LightCastle] %d parts, %d lights, %d windows lit"):format(made, lights, windows))
