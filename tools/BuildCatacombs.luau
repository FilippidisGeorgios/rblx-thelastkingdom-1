--[[
	BuildCatacombs — run in the Studio of the FORGOTTEN LANDS place, in EDIT MODE.
	Builds area 4, the Catacombs (docs/systems/Catacombs.md), into
	    workspace.Gameplay.Battleground.Decorations.Area4.Catacombs
	from `configs/Catacombs` (sizes, spots), `configs/CatacombsMaze` (the plan) and `Server/Domain/CatacombMaze`.

	It is run in PARTS (set ONLY to one of them, each takes under a minute):
	  "mountain"   the rock across the yard (terrain), the cave, the barrier, the painted STAY QUIET, the table and the lantern
	  "shafts"     the two deep spiral stairs (carves the ground for them), the safe room, the mausoleum at the top of the way out
	  "plan"       the floor, ceiling and walls of the maze, the crawls, the gate, the beams, the iron door
	  "props"      what is in the maze: bones, beds, carts, cells, chests, levers, ropes and bells, pages' tables, nests
	  "scares"     eyes and a grin on walls, words in red, blood
	  "zones"      the dark (light zones) and the marks the errand looks for
	  "all"        every part, one after the other (may need more than one minute)
	  "clear"      removes everything this tool made (the terrain it cut is NOT put back: see the backup note below)

	BEFORE THE FIRST RUN the ground is backed up: `ServerStorage.CatacombsTerrainBackup` holds the yard's strip (a Region copy),
	and the yard's models that the mountain covers are MOVED (not deleted) to `ServerStorage.Assets.Retired.Area4`.

	NOTE: a tool, not game code. Not synced by Rojo. The result lives in the place (the developer saves it).
]]

local ONLY = "all"

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local ServerStorage = game:GetService("ServerStorage")

local cfg = require(ReplicatedStorage.Config.Catacombs)
local plan = require(ReplicatedStorage.Config.CatacombsMaze)
local Maze = require(ServerScriptService.Server.Domain.CatacombMaze)
local maze = Maze.new(plan, cfg.Layout)

local L = cfg.Layout
local U = L.Unit
local H = L.PassageHeight
local FLOOR = L.FloorY
local CRAWL = L.CrawlHeight
local SLAB = L.Slab
local UW, UH = 3 * plan.Cols + 1, 3 * plan.Rows + 1
local rng = Random.new(20261031)

local battleground = workspace.Gameplay.Battleground
local area4 = battleground.Decorations:FindFirstChild("Area4")
assert(area4, "Decorations.Area4 is not there")

--==========================================================================
-- Small tools
--==========================================================================
local STONE = Color3.fromRGB(88, 82, 76)
local STONE_DARK = Color3.fromRGB(62, 58, 55)
local FLOORC = Color3.fromRGB(70, 66, 62)
local WOOD = Color3.fromRGB(88, 62, 38)
local WOOD_DARK = Color3.fromRGB(58, 40, 26)
local IRON = Color3.fromRGB(48, 44, 42)
local BONE = Color3.fromRGB(196, 186, 160)
local BLOOD = Color3.fromRGB(78, 12, 12)
local CLOTH = Color3.fromRGB(118, 102, 84)

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide ~= false
	p.CanQuery = collide ~= false
	p.CanTouch = false
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function ball(parent: Instance, name: string, diameter: number, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = part(parent, name, Vector3.one * diameter, cf, color, material, false)
	p.Shape = Enum.PartType.Ball
	return p
end

-- An upright cylinder (a Part's cylinder lies along X: turn it up).
local function pillar(parent: Instance, name: string, diameter: number, height: number, at: Vector3, color: Color3, material: Enum.Material, collide: boolean?): Part
	local p = part(parent, name, Vector3.new(height, diameter, diameter), CFrame.new(at) * CFrame.Angles(0, 0, math.rad(90)), color, material, collide)
	p.Shape = Enum.PartType.Cylinder
	return p
end

local function folder(parent: Instance, name: string): Folder
	local f = parent:FindFirstChild(name)
	if f and f:IsA("Folder") then
		return f
	end
	local made = Instance.new("Folder")
	made.Name = name
	made.Parent = parent
	return made
end

local root = folder(area4, "Catacombs")
local surface = folder(root, "Surface")
local stairs = folder(root, "Stairs")
local planFolder = folder(root, "Plan")
local propsFolder = folder(root, "Props")
local scaresFolder = folder(root, "Scares")
local marks = folder(root, "Marks")
local zones = folder(root, "Zones")

local function tagLight(l: Light)
	CollectionService:AddTag(l, "TLK_Lod")
end

local function candle(parent: Instance, at: Vector3, name: string?)
	local holder = Instance.new("Model")
	holder.Name = name or "Candle"
	holder.Parent = parent
	part(holder, "Stub", Vector3.new(0.35, 0.5, 0.35), CFrame.new(at + Vector3.new(0, 0.25, 0)), Color3.fromRGB(214, 200, 168), Enum.Material.Fabric, false)
	local flame = ball(holder, "Flame", 0.24, CFrame.new(at + Vector3.new(0, 0.62, 0)), Color3.fromRGB(255, 200, 120), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = cfg.Candle.Color
	light.Range = cfg.Candle.Range
	light.Brightness = cfg.Candle.Brightness
	light.Shadows = false
	light.Parent = flame
	tagLight(light)
	return holder
end

--==========================================================================
-- The plan in world terms
--==========================================================================
local function unitX(i: number): number -- the west edge of unit column i
	return L.X0 + i * U
end
local function unitZ(j: number): number -- the north edge of unit row j (south is -z)
	return L.ZTop - j * U
end
local function cellCentre(c: number, r: number): Vector3
	local x, z = maze:centre(c, r)
	return Vector3.new(x, FLOOR, z)
end

-- the raw digits (the shut ways are open in them)
local function rawOpen(c: number, r: number, dir: string): boolean
	if dir == "E" then
		return c < plan.Cols - 1 and bit32.band(tonumber(string.sub(plan.Cells[r + 1], c + 1, c + 1)) or 0, 1) ~= 0
	elseif dir == "S" then
		return r < plan.Rows - 1 and bit32.band(tonumber(string.sub(plan.Cells[r + 1], c + 1, c + 1)) or 0, 2) ~= 0
	elseif dir == "W" then
		return c > 0 and rawOpen(c - 1, r, "E")
	else
		return r > 0 and rawOpen(c, r - 1, "S")
	end
end

-- open[j][i] : the unit is not wall
local openUnit: { [number]: { [number]: boolean } } = {}
for j = 0, UH - 1 do
	openUnit[j] = {}
end
local function setOpen(i: number, j: number)
	if i >= 0 and i < UW and j >= 0 and j < UH then
		openUnit[j][i] = true
	end
end
for r = 0, plan.Rows - 1 do
	for c = 0, plan.Cols - 1 do
		for di = 1, 2 do
			for dj = 1, 2 do
				setOpen(3 * c + di, 3 * r + dj)
			end
		end
		if rawOpen(c, r, "E") then
			setOpen(3 * c + 3, 3 * r + 1)
			setOpen(3 * c + 3, 3 * r + 2)
		end
		if rawOpen(c, r, "S") then
			setOpen(3 * c + 1, 3 * r + 3)
			setOpen(3 * c + 2, 3 * r + 3)
		end
	end
end
-- the way in (east boundary of the entrance cell) and the way out (west boundary of the exit cell)
local sc, sr = plan.Start[1], plan.Start[2]
for dj = 1, 2 do
	setOpen(3 * sc + 3, 3 * sr + dj)
end
local ec, er = plan.Exit[1], plan.Exit[2]
for dj = 1, 2 do
	setOpen(3 * ec, 3 * er + dj)
end

-- the crawls: units where the ceiling is low (3 units along the way)
local crawlUnits: { { i: number, j: number } } = {}
local function addCrawl(c: number, r: number, dir: string)
	if dir == "W" then
		c, dir = c - 1, "E"
	elseif dir == "N" then
		r, dir = r - 1, "S"
	end
	if dir == "E" then
		for di = 2, 4 do
			for dj = 1, 2 do
				table.insert(crawlUnits, { i = 3 * c + di, j = 3 * r + dj })
			end
		end
	else
		for dj = 2, 4 do
			for di = 1, 2 do
				table.insert(crawlUnits, { i = 3 * c + di, j = 3 * r + dj })
			end
		end
	end
end
for _, l in plan.Low do
	addCrawl(l[1], l[2], l[3])
end
-- the way into the maze from the safe room is a crawl too: the wall unit and the two units of the cell
for di = 64, 66 do
	for dj = 1, 2 do
		table.insert(crawlUnits, { i = di, j = 3 * sr + dj })
	end
end

local function isSolid(i: number, j: number): boolean
	return not (openUnit[j] and openUnit[j][i])
end

--==========================================================================
-- Which of the yard's old models the mountain covers
--==========================================================================
local function backupAndRetire()
	local assets = ServerStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ServerStorage
	end
	local retired = folder(folder(assets, "Retired"), "Area4")
	local zFront = cfg.Mountain.FrontZ + 8
	local zBack = cfg.Mountain.FrontZ - cfg.Mountain.Depth - 8
	local moved = {}
	for _, m in area4:GetChildren() do
		if m ~= root and (m:IsA("Model") or m:IsA("BasePart")) then
			local ok, cf, size = pcall(function()
				local a, b = (m :: any):GetBoundingBox()
				return a, b
			end)
			if ok then
				local lo, hi = cf.Position.Z - size.Z / 2, cf.Position.Z + size.Z / 2
				-- big scatter models (WallTorches, Clutter) span the whole yard: leave them
				if size.Z < 120 and hi > zBack and lo < zFront then
					m.Parent = retired
					table.insert(moved, m.Name)
				end
			end
		end
	end
	return moved
end

--==========================================================================
-- PART: the mountain
--==========================================================================
local function buildMountain()
	local M = cfg.Mountain
	local T = workspace.Terrain
	local report = {}

	-- the old yard's models under the rock
	local moved = backupAndRetire()
	table.insert(report, "retired: " .. table.concat(moved, ", "))

	-- a copy of the strip of ground that is about to change
	local backup = ServerStorage:FindFirstChild("CatacombsTerrainBackup")
	if not backup then
		-- (CopyRegion wants voxel numbers: 4 studs to a voxel)
		local region = Region3int16.new(
			Vector3int16.new(-44, -2, math.floor((M.FrontZ - M.Depth - 24) / 4)),
			Vector3int16.new(44, 30, math.ceil((M.FrontZ + 24) / 4))
		)
		local ok, copy = pcall(function()
			return T:CopyRegion(region)
		end)
		if ok and copy then
			(copy :: any).Name = "CatacombsTerrainBackup"
			(copy :: any).Parent = ServerStorage
			table.insert(report, "terrain backup made")
		else
			table.insert(report, "terrain backup FAILED: " .. tostring(copy))
		end
	end

	-- the heightfield: columns of 4 x 4 studs from wall to wall
	local seedX, seedZ = rng:NextNumber(0, 1000), rng:NextNumber(0, 1000)
	local cols = 0
	local x = -M.HalfWidth
	while x < M.HalfWidth do
		local jag = 7 * math.noise(x * 0.045 + seedX, 0.5) + 3 * math.noise(x * 0.17, 1.5 + seedZ)
		local frontZ = M.FrontZ + jag
		local z = frontZ
		while z > M.FrontZ - M.Depth - 10 do
			local t = (frontZ - z) / M.Depth
			if t >= 1 then
				break
			end
			-- steep at the face, rolling off behind
			local shape = 1 - math.clamp((t - 0.12) / 0.88, 0, 1) ^ 1.4
			local rough = 1 + 0.30 * math.noise(x * 0.05 + seedX, z * 0.08 + seedZ) + 0.10 * math.noise(x * 0.21, z * 0.23)
			local h = M.Height * shape * rough
			if h > 3 then
				h = math.floor(h / 4 + 0.5) * 4
				-- BROWN rock in layers (the developer asked for a brown mountain): dark earth at the foot, then bands of sandstone,
				-- earth and a little grey rock, each band 4 studs, runs of the same stuff made one block
				local runFrom, runMat = 0, nil
				local function flush(upTo: number)
					if runMat and upTo > runFrom then
						T:FillBlock(CFrame.new(x + 2, 2 + (runFrom + upTo) / 2, z - 2), Vector3.new(4, upTo - runFrom, 4), runMat)
					end
				end
				for yb = 0, h - 4, 4 do
					local n = math.noise(x * 0.035 + seedZ, yb * 0.11 + seedX, z * 0.035)
					local strata = math.noise(seedX, yb * 0.16 + seedZ)
					local mat
					if yb < h * 0.2 then
						mat = if n > 0.12 then Enum.Material.Mud else Enum.Material.Ground
					else
						local s = strata * 0.8 + n * 0.5
						mat = if s > 0.5 then Enum.Material.Rock elseif s < -0.34 then Enum.Material.Ground else Enum.Material.Sandstone
					end
					if mat ~= runMat then
						flush(yb)
						runFrom, runMat = yb, mat
					end
				end
				flush(h)
				cols += 1
			end
			z -= 4
		end
		x += 4
	end
	table.insert(report, ("%d columns of rock"):format(cols))
	return report
end

local function buildCaveAndSign()
	local M = cfg.Mountain
	local T = workspace.Terrain
	local report = {}
	local caveX = M.Cave.X
	local w = M.Cave.Width

	-- the way in, cut in whole 4-stud cells with a margin (smooth terrain reaches half a cell beyond a cell)
	local lo = math.floor((caveX - w / 2 - 4) / 4) * 4
	local hi = math.ceil((caveX + w / 2 + 4) / 4) * 4
	T:FillBlock(CFrame.new((lo + hi) / 2, 2 + 6, M.FrontZ - 6), Vector3.new(hi - lo, 12, 28), Enum.Material.Air)
	table.insert(report, ("cave cut x %d..%d"):format(lo, hi))

	-- a rough frame of rock round the mouth, so that the cut edges of the ground are never seen
	local mouth = folder(surface, "Mouth")
	local z0 = M.FrontZ + 2
	local function slab(name: string, size: Vector3, at: Vector3, tilt: number)
		local p = part(mouth, name, size, CFrame.new(at) * CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), math.rad(rng:NextNumber(-6, 6)), math.rad(tilt)), Color3.fromRGB(96, 74, 54), Enum.Material.Rock, true)
		return p
	end
	slab("JambW", Vector3.new(5, 12, 9), Vector3.new(caveX - w / 2 - 2.5, 2 + 6, z0 - 3), 2)
	slab("JambE", Vector3.new(5, 12, 9), Vector3.new(caveX + w / 2 + 2.5, 2 + 6, z0 - 3), -2)
	slab("Lintel", Vector3.new(w + 12, 5, 10), Vector3.new(caveX, 2 + 10.5, z0 - 3), 0)
	for k = 1, 6 do
		local side = if k % 2 == 0 then 1 else -1
		slab("Boulder" .. k, Vector3.new(rng:NextNumber(4, 8), rng:NextNumber(3, 6), rng:NextNumber(4, 7)), Vector3.new(caveX + side * (w / 2 + 6 + k * 2), 2 + 2, z0 + rng:NextNumber(0, 5)), rng:NextNumber(-12, 12))
	end

	-- the invisible barrier: the developer asked for one (nobody climbs the rock): from wall to wall, in front of the face,
	-- with a gap at the cave
	local barrier = folder(surface, "Barrier")
	local zb = M.FrontZ + 7
	local function wall(name: string, x0: number, x1: number)
		local p = part(barrier, name, Vector3.new(x1 - x0, M.BarrierHeight, 2), CFrame.new((x0 + x1) / 2, M.BarrierHeight / 2, zb), Color3.fromRGB(255, 0, 255), Enum.Material.SmoothPlastic, true)
		p.Transparency = 1
		p.CanQuery = false
		return p
	end
	wall("West", -M.HalfWidth - 6, caveX - w / 2)
	wall("East", caveX + w / 2, M.HalfWidth + 6)
	local lintel = part(barrier, "Over", Vector3.new(w, M.BarrierHeight - 13, 2), CFrame.new(caveX, 13 + (M.BarrierHeight - 13) / 2, zb), Color3.fromRGB(255, 0, 255), Enum.Material.SmoothPlastic, true)
	lintel.Transparency = 1
	lintel.CanQuery = false
	-- and one behind the mouth, so that a body cannot walk round the foot of the rock into the yard behind it
	local back = part(barrier, "Behind", Vector3.new(M.HalfWidth * 2 + 12, M.BarrierHeight, 2), CFrame.new(0, M.BarrierHeight / 2, M.FrontZ - M.Depth + 6), Color3.fromRGB(255, 0, 255), Enum.Material.SmoothPlastic, true)
	back.Transparency = 1
	back.CanQuery = false
	back.Name = "Back"
	-- (the back wall also keeps the yard south of the rock apart from the ledge; the way out of the catacombs is on the far side)
	back:Destroy()

	-- STAY QUIET, painted large on a flattened face of the rock above the cave
	-- (a deep block, its painted face standing 13 studs in front of the mean face of the rock, so that no jag of the cliff
	-- can stand in front of a letter)
	local signFace = M.FrontZ + 13
	local signZ = signFace + 2
	local signW, signH = 150, 26
	local signX = caveX - 40
	local rock = part(surface, "SignRock", Vector3.new(signW, signH, 14), CFrame.new(signX, 2 + 40, signFace - 7), Color3.fromRGB(112, 84, 60), Enum.Material.Sandstone, true)
	rock.CanCollide = false
	local gui = Instance.new("SurfaceGui")
	gui.Name = "Paint"
	gui.Face = Enum.NormalId.Front
	gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	-- (TextScaled stops at 100 pixels: 4 pixels to the stud makes that 25 studs high, the whole height of the slab)
	gui.PixelsPerStud = 4
	gui.LightInfluence = 0
	gui.AlwaysOnTop = false
	gui.Parent = rock
	-- Front of a Part faces -Z; this slab must face +Z (toward the gate), so it is turned round
	rock.CFrame = CFrame.new(signX, 2 + 40, signFace - 7) * CFrame.Angles(0, math.rad(180), 0)
	local text = Instance.new("TextLabel")
	text.Name = "Words"
	text.BackgroundTransparency = 1
	text.Size = UDim2.fromScale(1, 1)
	text.Text = "STAY QUIET"
	text.Font = Enum.Font.Fondamento
	text.TextScaled = true
	text.TextColor3 = Color3.fromRGB(236, 226, 196)
	text.TextStrokeColor3 = Color3.fromRGB(34, 24, 16)
	text.TextStrokeTransparency = 0.25
	text.Parent = gui
	-- rough edges so that it is a painted rock and not a signboard
	for k = 1, 8 do
		local bx = signX + rng:NextNumber(-signW / 2, signW / 2)
		local edge = if k % 2 == 0 then signH / 2 else -signH / 2
		part(surface, "SignChunk" .. k, Vector3.new(rng:NextNumber(5, 12), rng:NextNumber(3, 7), 6), CFrame.new(bx, 2 + 40 + edge, signZ - 2) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-15, 15))), Color3.fromRGB(94, 72, 52), Enum.Material.Rock, false)
	end
	table.insert(report, "cave, barrier, painted words")
	return report
end

local function buildTable()
	local M = cfg.Mountain
	local report = {}
	-- the table to the west of the cave, in the open plateau before the barrier
	local at = Vector3.new(M.Cave.X - M.Cave.Width / 2 - 12, 2, M.FrontZ + 20)
	local model = Instance.new("Model")
	model.Name = "EntranceTable"
	model.Parent = marks
	local y = at.Y
	part(model, "Top", Vector3.new(6, 0.4, 3), CFrame.new(at.X, y + 3.2, at.Z), WOOD, Enum.Material.Wood, true)
	for _, dx in { -2.5, 2.5 } do
		for _, dz in { -1.1, 1.1 } do
			part(model, "Leg", Vector3.new(0.45, 3.0, 0.45), CFrame.new(at.X + dx, y + 1.5, at.Z + dz), WOOD_DARK, Enum.Material.Wood, true)
		end
	end
	-- a lantern standing on it (the one you may take) and a cloth beneath
	local lantern = Instance.new("Model")
	lantern.Name = "LanternProp"
	lantern.Parent = model
	part(lantern, "Base", Vector3.new(0.7, 0.14, 0.7), CFrame.new(at.X - 1.6, y + 3.47, at.Z), IRON, Enum.Material.Metal, false)
	part(lantern, "Glass", Vector3.new(0.55, 0.8, 0.55), CFrame.new(at.X - 1.6, y + 3.95, at.Z), cfg.Lantern.Color, Enum.Material.Glass, false).Transparency = 0.5
	part(lantern, "Cap", Vector3.new(0.72, 0.14, 0.72), CFrame.new(at.X - 1.6, y + 4.42, at.Z), IRON, Enum.Material.Metal, false)
	local flame = ball(lantern, "Flame", 0.26, CFrame.new(at.X - 1.6, y + 3.95, at.Z), Color3.fromRGB(255, 214, 140), Enum.Material.Neon)
	local light = Instance.new("PointLight")
	light.Color = cfg.Lantern.Color
	light.Range = 14
	light.Brightness = 1.4
	light.Shadows = false
	light.Parent = flame
	tagLight(light)
	local spot = part(marks, "LanternSpot", Vector3.new(1, 1, 1), CFrame.new(at.X - 1.6, y + 3.6, at.Z), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
	spot.Transparency = 1
	table.insert(report, "table and lantern at " .. tostring(at))
	-- stakes with skulls at the edges of the plateau (a warning in the old way)
	for k = 1, 3 do
		local sx = M.Cave.X + (k - 2) * 18 + 28
		part(surface, "Stake" .. k, Vector3.new(0.5, 7, 0.5), CFrame.new(sx, 2 + 3.5, M.FrontZ + 14 + k * 2) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6))), WOOD_DARK, Enum.Material.Wood, false)
		ball(surface, "Skull" .. k, 1.3, CFrame.new(sx, 2 + 7.2, M.FrontZ + 14 + k * 2), BONE, Enum.Material.Slate)
	end
	return report
end

--==========================================================================
-- PART: the deep stairs
--==========================================================================

-- A round shaft with a spiral stair round an open well. Built from the top landing (k = 0) down to the floor. `opening`
-- is the angle (degrees, 0 = +x, 90 = +z) where the bottom floor has its doorway and `landing` the angle of the top landing.
local function spiral(name: string, s: any, landing: number, opening: number)
	local model = folder(stairs, name)
	local cx, cz = s.X, s.Z
	local top, bottom = s.Top, s.Bottom
	local R, well = s.Radius, s.Well
	local per = 24 -- steps in a turn
	local N = math.floor(s.Turns * per + 0.5)
	local rise = (top - bottom) / N
	local dTheta = 360 / per * (if s.Clockwise then -1 else 1)
	local mid = (R - 1 + well) / 2
	local width = (R - 1) - well
	local steps = folder(model, "Steps")

	local function at(angle: number, radius: number, y: number): Vector3
		return Vector3.new(cx + radius * math.cos(math.rad(angle)), y, cz + radius * math.sin(math.rad(angle)))
	end

	-- the wall of the shaft: a ring of upright slabs; a doorway at `opening` (down at the floor) and the top landing's gap
	local wallRing = folder(model, "Wall")
	local segs = 40
	local rw = R + 0.8
	local seg = 2 * math.pi * rw / segs
	for k = 0, segs - 1 do
		local a = k * 360 / segs
		local function near(target: number, span: number): boolean
			local d = math.abs((a - target + 540) % 360 - 180)
			return d < span
		end
		local colour = if k % 3 == 0 then STONE_DARK else STONE
		local cf = CFrame.new(at(a, rw, 0)) * CFrame.Angles(0, math.rad(-a + 90), 0)
		local y0, y1 = bottom - 3, top + 14
		if near(opening, 360 / segs * 1.6) then
			-- a doorway at the foot: wall above it only
			part(wallRing, "Lintel", Vector3.new(seg + 0.3, y1 - (bottom + H), 1.6), cf + Vector3.new(0, (y1 + bottom + H) / 2, 0) - Vector3.new(0, 0, 0), colour, Enum.Material.Cobblestone, true)
		elseif near(landing, 360 / segs * 1.7) then
			-- the way in at the top: a doorway as high as the cave, lintel above
			part(wallRing, "Lintel", Vector3.new(seg + 0.3, y1 - (top + 10), 1.6), cf + Vector3.new(0, (y1 + top + 10) / 2, 0), colour, Enum.Material.Cobblestone, true)
			-- (the sill of the doorway: its top is the level of the landing; it was 6 studs lower, a pit between the cave and the landing)
			part(wallRing, "Under", Vector3.new(seg + 0.3, top - y0, 1.6), cf + Vector3.new(0, (y0 + top) / 2, 0), colour, Enum.Material.Cobblestone, true)
		else
			part(wallRing, "Wall", Vector3.new(seg + 0.3, y1 - y0, 1.6), cf + Vector3.new(0, (y0 + y1) / 2, 0), colour, Enum.Material.Cobblestone, true)
		end
	end

	-- the top landing: a flat floor over the first stretch of the ring
	local landingFloor = Instance.new("Model")
	landingFloor.Name = "Landing"
	landingFloor.Parent = model
	for k = 0, 4 do
		-- on the side the stair does NOT go to, so that nothing hangs over the first steps
		local a = landing - math.sign(dTheta) * k * (360 / per)
		local p = part(landingFloor, "Slab", Vector3.new(width, 0.6, 3.1), CFrame.new(at(a, mid, top - 0.3)) * CFrame.Angles(0, math.rad(-a), 0), WOOD, Enum.Material.Wood, true)
		p.Color = WOOD:Lerp(STONE, 0.25)
	end

	-- the steps: an invisible flat collider for each (so that the walk is never broken), and the plank on it, which may be
	-- missing, hanging or cracked
	local broken = s.BrokenShare or 0.14
	local previousBroken = false
	for k = 0, N - 1 do
		local a = landing + (k + 1) * dTheta
		local y = top - (k + 1) * rise
		local cf = CFrame.new(at(a, mid, y - 0.2)) * CFrame.Angles(0, math.rad(-a), 0)
		local tread = 2 * math.pi * mid / per
		local step = part(steps, "Step", Vector3.new(width, 0.4, tread + 0.25), cf, WOOD, Enum.Material.Wood, true)
		step.Transparency = 1
		step.CanQuery = true
		local rollBad = rng:NextNumber() < broken and not previousBroken
		previousBroken = rollBad
		if rollBad then
			local kind = rng:NextInteger(1, 3)
			if kind == 1 then
				-- missing: nothing to see (the collider stays; a body steps over the gap)
			elseif kind == 2 then
				-- hanging by one end
				local plank = part(steps, "Plank", Vector3.new(width - 0.3, 0.34, tread * 0.9), cf * CFrame.new(0, -0.4, 0) * CFrame.Angles(math.rad(rng:NextNumber(10, 22)), 0, 0), WOOD_DARK, Enum.Material.Wood, false)
				plank.Color = WOOD_DARK
			else
				-- split down the middle
				for _, side in { -1, 1 } do
					part(steps, "Plank", Vector3.new(width / 2 - 0.4, 0.34, tread * 0.9), cf * CFrame.new(side * (width / 4 + 0.1), side * 0.05, 0) * CFrame.Angles(0, math.rad(side * rng:NextNumber(3, 9)), math.rad(side * rng:NextNumber(2, 8))), WOOD, Enum.Material.Wood, false)
				end
			end
		else
			local plank = part(steps, "Plank", Vector3.new(width - 0.2, 0.36, tread * 0.94), cf * CFrame.new(0, 0.02, 0) * CFrame.Angles(math.rad(rng:NextNumber(-1.5, 1.5)), 0, math.rad(rng:NextNumber(-1.5, 1.5))), WOOD:Lerp(WOOD_DARK, rng:NextNumber(0, 0.7)), Enum.Material.Wood, false)
			plank.Color = WOOD:Lerp(WOOD_DARK, rng:NextNumber(0, 0.7))
		end
	end

	-- the floor at the foot: a disc, its top at the bottom of the last step
	local floor = pillar(model, "Floor", R * 2 + 1, 2, Vector3.new(cx, bottom - 1, cz), FLOORC, Enum.Material.Slate, true)
	floor.Name = "Floor"

	-- the well: an invisible column so that nobody can step off the inside edge, and a railing, broken in places
	local column = pillar(model, "WellWall", (well + 0.4) * 2, top - bottom + 20, Vector3.new(cx, (top + bottom) / 2 + 4, cz), Color3.fromRGB(255, 0, 255), Enum.Material.SmoothPlastic, true)
	column.Transparency = 1
	column.CanQuery = false
	local rail = folder(model, "Railing")
	for k = 0, N - 1, 2 do
		local a = landing + (k + 1) * dTheta
		local y = top - (k + 1) * rise
		if rng:NextNumber() > 0.3 then
			part(rail, "Post", Vector3.new(0.3, 3.2, 0.3), CFrame.new(at(a, well + 0.3, y + 1.4)), WOOD_DARK, Enum.Material.Wood, false)
		end
		if rng:NextNumber() > 0.4 then
			local a2 = a + dTheta * 2
			local p0, p1 = at(a, well + 0.3, y + 2.6), at(a2, well + 0.3, y - 2 * rise + 2.6)
			local len = (p1 - p0).Magnitude
			part(rail, "Rail", Vector3.new(0.22, 0.22, len), CFrame.lookAt((p0 + p1) / 2, p1), WOOD, Enum.Material.Wood, false)
		end
	end
	-- a pillar of old masonry in the middle for the eye to fall along
	pillar(model, "Core", 3.4, top - bottom + 10, Vector3.new(cx, (top + bottom) / 2 + 3, cz), STONE_DARK, Enum.Material.Cobblestone, false)
	return model
end

local function carveShaft(s: any, extraTop: number)
	local T = workspace.Terrain
	-- whole cells, with a margin (the wall ring is at the radius + 0.8; the ground is cut well beyond it)
	local r = s.Radius + 5
	local y0, y1 = -52, s.Top + extraTop
	T:FillCylinder(CFrame.new(s.X, (y0 + y1) / 2, s.Z), y1 - y0, r, Enum.Material.Air)
end

local function buildShafts()
	local report = {}
	local down, up = cfg.Stairs.Down, cfg.Stairs.Up
	carveShaft(down, 10)
	carveShaft(up, 4)
	spiral("Down", { X = down.X, Z = down.Z, Radius = down.Radius, Well = down.Well, Top = down.Top, Bottom = down.Bottom, Turns = down.Turns, Clockwise = down.Clockwise, BrokenShare = cfg.Stairs.BrokenShare }, 90, 180)
	spiral("Up", { X = up.X, Z = up.Z, Radius = up.Radius, Well = up.Well, Top = up.Top, Bottom = up.Bottom, Turns = up.Turns, Clockwise = up.Clockwise, BrokenShare = 0.1 }, 270, 0)
	-- the shaft's cut takes the ground of the cave with it (a round hole 19 wide): a floor of stone from the cave's mouth to the
	-- landing, level with it, so that the way in has no pit in it
	local sill = part(stairs, "CaveSill", Vector3.new(24, 1.4, 14), CFrame.new(down.X, down.Top - 0.7, down.Z + down.Radius + 5), FLOORC, Enum.Material.Cobblestone, true)
	sill.Name = "CaveSill"
	-- a cap over the top of the down shaft, inside the rock (the ground above it is the mountain)
	local cap = pillar(stairs, "DownCap", down.Radius * 2 + 4, 3, Vector3.new(down.X, down.Top + 11.5, down.Z), STONE_DARK, Enum.Material.Rock, true)
	cap.Name = "DownCap"
	table.insert(report, "two shafts carved and built")

	-- the safe room: between the shaft's west door and the crawl into the maze
	local sx0 = L.X0 + UW * U -- east edge of the plan (the plan's boundary wall ends here)
	local sx1 = down.X - down.Radius - 0.8
	local sz = Vector3.new(0, 0, cellCentre(sc, sr).Z)
	local zc = sz.Z
	local room = folder(root, "SafeRoom")
	local w = 12
	local len = sx1 - sx0
	local cx = (sx0 + sx1) / 2
	part(room, "Floor", Vector3.new(len + 1, SLAB, w + 4), CFrame.new(cx, FLOOR - SLAB / 2, zc), FLOORC, Enum.Material.Slate, true)
	part(room, "Ceiling", Vector3.new(len + 1, SLAB, w + 4), CFrame.new(cx, FLOOR + H + SLAB / 2, zc), STONE_DARK, Enum.Material.Cobblestone, true)
	part(room, "WallN", Vector3.new(len + 1, H, 2), CFrame.new(cx, FLOOR + H / 2, zc + w / 2 + 1), STONE, Enum.Material.Cobblestone, true)
	part(room, "WallS", Vector3.new(len + 1, H, 2), CFrame.new(cx, FLOOR + H / 2, zc - w / 2 - 1), STONE, Enum.Material.Cobblestone, true)
	-- the crawl in the west wall (two units wide; the lintel above it keeps standing bodies out)
	local crawlW = 2 * U
	local sideW = (w - crawlW) / 2
	for _, side in { -1, 1 } do
		part(room, "WestWall", Vector3.new(2, H, sideW), CFrame.new(sx0 + 1, FLOOR + H / 2, zc + side * (crawlW / 2 + sideW / 2)), STONE, Enum.Material.Cobblestone, true)
	end
	part(room, "CrawlLintel", Vector3.new(3 * U, H - CRAWL, crawlW), CFrame.new(sx0 + 0.5, FLOOR + CRAWL + (H - CRAWL) / 2, zc), STONE_DARK, Enum.Material.Cobblestone, true)
	-- the way to the shaft is the ring's own doorway: nothing to build but the sill
	-- furniture: a bench, a straw bed, a table with a candle, a chest of dry things
	part(room, "Bench", Vector3.new(5, 0.5, 1.4), CFrame.new(cx + 2, FLOOR + 1.6, zc + w / 2 - 1.2), WOOD, Enum.Material.Wood, true)
	for _, dx in { -2, 2 } do
		part(room, "BenchLeg", Vector3.new(0.4, 1.4, 1), CFrame.new(cx + 2 + dx, FLOOR + 0.8, zc + w / 2 - 1.2), WOOD_DARK, Enum.Material.Wood, true)
	end
	for k = 1, 3 do
		part(room, "Straw", Vector3.new(4, 0.3 + k * 0.1, 2), CFrame.new(cx - 4, FLOOR + 0.2 + k * 0.1, zc - w / 2 + 2 + 0.02 * k) * CFrame.Angles(0, math.rad(rng:NextNumber(-8, 8)), 0), Color3.fromRGB(176, 150, 88), Enum.Material.Fabric, false)
	end
	part(room, "Table", Vector3.new(3, 0.3, 2), CFrame.new(cx - 4, FLOOR + 2.4, zc + w / 2 - 1.8), WOOD, Enum.Material.Wood, true)
	part(room, "TableLeg", Vector3.new(0.4, 2.3, 1.6), CFrame.new(cx - 4, FLOOR + 1.15, zc + w / 2 - 1.8), WOOD_DARK, Enum.Material.Wood, true)
	candle(room, Vector3.new(cx - 4, FLOOR + 2.55, zc + w / 2 - 1.8), "SafeCandle")
	local mark = part(marks, "SafeRoom", Vector3.new(4, 4, 4), CFrame.new(cx, FLOOR + 3, zc), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
	mark.Transparency = 1
	table.insert(report, "safe room")

	-- the mausoleum at the top of the way out: a small stone house over the shaft's top, with a door that stands open
	local m = folder(root, "Mausoleum")
	local ux, uz = up.X, up.Z
	local half = up.Radius + 3
	local roofY = up.Top + 15
	for _, spec in {
		{ "WallN", Vector3.new(half * 2, 15, 2), Vector3.new(ux, up.Top + 7.5, uz + half) },
		{ "WallW", Vector3.new(2, 15, half * 2), Vector3.new(ux - half, up.Top + 7.5, uz) },
		{ "WallE", Vector3.new(2, 15, half * 2), Vector3.new(ux + half, up.Top + 7.5, uz) },
	} do
		part(m, spec[1] :: string, spec[2] :: Vector3, CFrame.new(spec[3] :: Vector3), STONE, Enum.Material.Cobblestone, true)
	end
	-- the south wall has the door (toward the yard and the gate), 8 wide and 11 high, open
	part(m, "WallSTop", Vector3.new(half * 2, 4, 2), CFrame.new(ux, up.Top + 13, uz - half), STONE, Enum.Material.Cobblestone, true)
	for _, side in { -1, 1 } do
		part(m, "WallSSide", Vector3.new(half - 4, 11, 2), CFrame.new(ux + side * (4 + (half - 4) / 2), up.Top + 5.5, uz - half), STONE, Enum.Material.Cobblestone, true)
	end
	part(m, "Roof", Vector3.new(half * 2 + 3, 2, half * 2 + 3), CFrame.new(ux, roofY + 1, uz), STONE_DARK, Enum.Material.Slate, true)
	part(m, "RoofRidge", Vector3.new(half * 2 + 3, 3, 4), CFrame.new(ux, roofY + 3.2, uz), STONE_DARK, Enum.Material.Slate, true)
	-- the same floor as at the cave: the shaft's cut takes the ground round its doorway, so a sill of stone is laid from the
	-- landing out across the cut to the ground of the yard
	local exitSill = part(m, "ExitSill", Vector3.new(24, 1.4, 14), CFrame.new(ux, up.Top - 0.7, uz - up.Radius - 3.5), FLOORC, Enum.Material.Cobblestone, true)
	exitSill.Name = "ExitSill"
	local top = part(marks, "ExitTop", Vector3.new(4, 4, 4), CFrame.new(ux, up.Top + 3, uz - 9.5), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
	top.Transparency = 1
	table.insert(report, "mausoleum")
	return report
end

--==========================================================================
-- PART: the plan
--==========================================================================
local function mergeRects(): { { i: number, j: number, w: number, h: number } }
	local used: { [number]: boolean } = {}
	local out = {}
	for j = 0, UH - 1 do
		for i = 0, UW - 1 do
			if isSolid(i, j) and not used[j * UW + i] then
				local w = 1
				while i + w < UW and isSolid(i + w, j) and not used[j * UW + i + w] do
					w += 1
				end
				local h = 1
				local ok = true
				while ok and j + h < UH do
					for k = 0, w - 1 do
						if not isSolid(i + k, j + h) or used[(j + h) * UW + i + k] then
							ok = false
							break
						end
					end
					if ok then
						h += 1
					end
				end
				for dj = 0, h - 1 do
					for di = 0, w - 1 do
						used[(j + dj) * UW + i + di] = true
					end
				end
				table.insert(out, { i = i, j = j, w = w, h = h })
			end
		end
	end
	return out
end

local function buildPlan()
	local report = {}
	local x0, x1 = unitX(0), unitX(UW)
	local z0, z1 = unitZ(0), unitZ(UH)
	local cx, cz = (x0 + x1) / 2, (z0 + z1) / 2
	local sizeX, sizeZ = x1 - x0, z0 - z1

	-- Found by walking it (the character was swimming): under the castle, deeper than y -58, a band of water lies from wall to wall
	-- between z -870 and z -810, and the maze's middle was full of it. It is taken out of the maze's footprint (whole cells, with
	-- a margin: smooth terrain reaches half a cell beyond).
	local T = workspace.Terrain
	local wx0, wx1 = x0 - 28, x1 + 8
	T:FillBlock(CFrame.new((wx0 + wx1) / 2, -63, -840), Vector3.new(wx1 - wx0, 26, 72), Enum.Material.Air)
	table.insert(report, "water taken out of the plan's footprint")

	part(planFolder, "Floor", Vector3.new(sizeX, SLAB, sizeZ), CFrame.new(cx, FLOOR - SLAB / 2, cz), FLOORC, Enum.Material.Slate, true)
	part(planFolder, "Ceiling", Vector3.new(sizeX, SLAB, sizeZ), CFrame.new(cx, FLOOR + H + SLAB / 2, cz), STONE_DARK, Enum.Material.Cobblestone, true)

	local walls = folder(planFolder, "Walls")
	local count = 0
	for _, rect in mergeRects() do
		local wx0, wz0 = unitX(rect.i), unitZ(rect.j)
		local sx, sz = rect.w * U, rect.h * U
		local colour = if (rect.i + rect.j) % 5 == 0 then STONE_DARK else STONE
		part(walls, "Wall", Vector3.new(sx, H, sz), CFrame.new(wx0 + sx / 2, FLOOR + H / 2, wz0 - sz / 2), colour, Enum.Material.Cobblestone, true)
		count += 1
	end
	table.insert(report, count .. " wall blocks")

	-- the crawls: a low lintel over each
	local lintels = folder(planFolder, "Crawls")
	local seen: { [string]: boolean } = {}
	for _, cu in crawlUnits do
		local key = cu.i .. "," .. cu.j
		if not seen[key] then
			seen[key] = true
			local px, pz = unitX(cu.i), unitZ(cu.j)
			part(lintels, "Lintel", Vector3.new(U, H - CRAWL, U), CFrame.new(px + U / 2, FLOOR + CRAWL + (H - CRAWL) / 2, pz - U / 2), STONE_DARK, Enum.Material.Cobblestone, true)
		end
	end
	table.insert(report, ("%d low units"):format(#crawlUnits))

	-- the gate (an iron grille in the edge south of cell 0,8)
	local g = plan.Gate
	local gm = Instance.new("Model")
	gm.Name = "Gate"
	gm.Parent = marks
	local gx = unitX(3 * g[1] + 1) + U
	local gz = unitZ(3 * g[2] + 3) - U / 2
	for k = 0, 8 do
		part(gm, "Bar", Vector3.new(0.35, H - 0.2, 0.35), CFrame.new(gx - 3 + k * 0.75, FLOOR + (H - 0.2) / 2, gz), IRON, Enum.Material.Metal, true)
	end
	for _, y in { 1.2, 3.8, 6.4 } do
		part(gm, "Cross", Vector3.new(7, 0.3, 0.4), CFrame.new(gx, FLOOR + y, gz), IRON, Enum.Material.Metal, true)
	end
	for k = 0, 8 do
		local spike = part(gm, "Spike", Vector3.new(0.3, 0.8, 0.3), CFrame.new(gx - 3 + k * 0.75, FLOOR + 0.4, gz), IRON, Enum.Material.Metal, false)
		spike.Name = "Spike"
	end
	gm.PrimaryPart = gm:FindFirstChildWhichIsA("BasePart")
	table.insert(report, "gate")

	-- the fallen beams (an edge south of cell 0,12)
	local b = plan.Barricade
	local bm = Instance.new("Model")
	bm.Name = "Barricade"
	bm.Parent = marks
	local bx = unitX(3 * b[1] + 1) + U
	local bz = unitZ(3 * b[2] + 3) - U / 2
	for k = 1, 11 do
		local len = rng:NextNumber(6, 8.4)
		local tilt = rng:NextNumber(-55, 55)
		local beam = part(bm, "Beam", Vector3.new(0.9, 0.9, len), CFrame.new(bx + rng:NextNumber(-2.4, 2.4), FLOOR + rng:NextNumber(0.8, 6.6), bz + rng:NextNumber(-1.2, 1.2)) * CFrame.Angles(math.rad(tilt) * 0.3, math.rad(rng:NextNumber(-20, 20)), math.rad(tilt)), WOOD:Lerp(WOOD_DARK, rng:NextNumber(0.2, 0.9)), Enum.Material.Wood, true)
		beam.Name = "Beam"
	end
	for k = 1, 4 do
		part(bm, "Rubble", Vector3.new(rng:NextNumber(1.5, 3), rng:NextNumber(0.8, 1.6), rng:NextNumber(1.5, 2.6)), CFrame.new(bx + rng:NextNumber(-3, 3), FLOOR + 0.6, bz + rng:NextNumber(-1.6, 1.6)) * CFrame.Angles(0, math.rad(rng:NextNumber(0, 180)), 0), STONE_DARK, Enum.Material.Slate, true)
	end
	bm.PrimaryPart = bm:FindFirstChildWhichIsA("BasePart")
	table.insert(report, "barricade")

	-- the iron door in the west wall of the exit cell
	local dm = Instance.new("Model")
	dm.Name = "IronDoor"
	dm.Parent = marks
	local doorX = unitX(0) + U / 2
	local doorZ = unitZ(3 * er + 1) - U
	local leafW = U
	for _, side in { { "LeafW", 1 }, { "LeafE", -1 } } do
		local leaf = Instance.new("Model")
		leaf.Name = side[1] :: string
		leaf.Parent = dm
		local sgn = side[2] :: number
		local lx = doorX
		local lz = doorZ + sgn * leafW / 2
		part(leaf, "Slab", Vector3.new(0.8, H - 0.1, leafW - 0.05), CFrame.new(lx, FLOOR + (H - 0.1) / 2, lz), IRON, Enum.Material.Metal, true)
		for k = 1, 5 do
			part(leaf, "Band", Vector3.new(0.95, 0.35, leafW - 0.05), CFrame.new(lx, FLOOR + k * 1.25, lz), Color3.fromRGB(34, 31, 30), Enum.Material.Metal, false)
		end
		for k = 1, 6 do
			ball(leaf, "Rivet", 0.3, CFrame.new(lx + 0.5, FLOOR + 0.6 + k * 1.1, lz + sgn * (leafW / 2 - 0.4)), Color3.fromRGB(70, 64, 60), Enum.Material.Metal)
		end
		-- the hinge is on the outside edge of each leaf
		leaf.WorldPivot = CFrame.new(lx, FLOOR, doorZ + sgn * leafW)
		leaf.PrimaryPart = leaf:FindFirstChild("Slab") :: BasePart
	end
	local lock = Instance.new("Model")
	lock.Name = "Lock"
	lock.Parent = dm
	part(lock, "Plate", Vector3.new(0.4, 1.2, 1.0), CFrame.new(doorX + 0.5, FLOOR + 3.6, doorZ), Color3.fromRGB(110, 92, 52), Enum.Material.Metal, false)
	part(lock, "Hole", Vector3.new(0.5, 0.35, 0.18), CFrame.new(doorX + 0.7, FLOOR + 3.6, doorZ), Color3.fromRGB(10, 10, 10), Enum.Material.Metal, false)
	dm.PrimaryPart = (dm:FindFirstChild("LeafW") :: Model).PrimaryPart
	table.insert(report, "iron door")

	-- the exit corridor beyond the door, to the shaft's wall
	local up = cfg.Stairs.Up
	local ex1 = up.X + up.Radius + 0.8
	local ex0 = unitX(0)
	local ecx = (ex0 + ex1) / 2
	local ez = cellCentre(ec, er).Z
	local corr = folder(root, "ExitCorridor")
	part(corr, "Floor", Vector3.new(ex0 - ex1 + 4, SLAB, 11), CFrame.new(ecx, FLOOR - SLAB / 2, ez), FLOORC, Enum.Material.Slate, true)
	part(corr, "Ceiling", Vector3.new(ex0 - ex1 + 4, SLAB, 11), CFrame.new(ecx, FLOOR + H + SLAB / 2, ez), STONE_DARK, Enum.Material.Cobblestone, true)
	for _, side in { -1, 1 } do
		part(corr, "Wall", Vector3.new(ex0 - ex1 + 4, H, 2), CFrame.new(ecx, FLOOR + H / 2, ez + side * (2 * U / 2 + 1)), STONE, Enum.Material.Cobblestone, true)
	end
	return report
end

--==========================================================================
-- Clear
--==========================================================================
local function clearAll()
	root:ClearAllChildren()
	for _, name in { "Surface", "Stairs", "Plan", "Props", "Scares", "Marks", "Zones" } do
		folder(root, name)
	end
	return { "cleared (the terrain that was cut is not put back; ServerStorage.CatacombsTerrainBackup has the old ground)" }
end

return {
	ctx = {
		ONLY = ONLY,
		cfg = cfg,
		plan = plan,
		maze = maze,
		root = root,
		surface = surface,
		stairs = stairs,
		planFolder = planFolder,
		propsFolder = propsFolder,
		scaresFolder = scaresFolder,
		marks = marks,
		zones = zones,
		part = part,
		ball = ball,
		pillar = pillar,
		folder = folder,
		candle = candle,
		tagLight = tagLight,
		cellCentre = cellCentre,
		rawOpen = rawOpen,
		isSolid = isSolid,
		unitX = unitX,
		unitZ = unitZ,
		rng = rng,
		colours = { STONE = STONE, STONE_DARK = STONE_DARK, FLOORC = FLOORC, WOOD = WOOD, WOOD_DARK = WOOD_DARK, IRON = IRON, BONE = BONE, BLOOD = BLOOD, CLOTH = CLOTH },
		UW = UW,
		UH = UH,
	},
	mountain = function()
		local r = buildMountain()
		for _, line in buildCaveAndSign() do
			table.insert(r, line)
		end
		for _, line in buildTable() do
			table.insert(r, line)
		end
		return r
	end,
	shafts = buildShafts,
	plan = buildPlan,
	clear = clearAll,
}
