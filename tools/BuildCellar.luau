--[[
	BuildCellar — run in the FORGOTTEN LANDS place, in EDIT MODE.
	Builds the Kitchens' cellar (docs/systems/BigRun.md, Trials.md chamber 3's deed) into
	`Workspace.Gameplay.Battleground.Decorations.Area3.Cellar`, and cuts its rooms out of the terrain.

	WHERE (world coordinates, in the open ground between the kitchen hall and the Dairy, south of the hall):
	  the STAIR   an open stone-lined trench, 8 wide, going south from the ground at z -662 down to the floor at z -686
	  the LANDING and the DOOR   a short flat floor at the foot (z -686 to -692) and a heavy locked door in the wall at z -692
	  the LARDER  a roofed hall behind the door, x -96 to -66, z -706 to -694, 9 high: shelves, casks, hams, a table, a chest
	  the CRAWL   a LOW passage (3.4 high, 5 wide) that leaves the larder's east end and bends twice: you must crouch
	  the CISTERN a flooded vault under the Dairy, x -44 to -26, z -716 to -700, 7 high: a pool, a dais, the hoard, and three mounds
	              of rubble where the dead dig up through the floor
	The floor of everything underground is y = -12 (the ground above is y = 2). The ceilings are slabs under 3 studs
	of earth, so the sun and moon never reach them; the flat ambient light is turned down by a LIGHT ZONE (the tagged,
	invisible box named `Zone`; see configs/LightZones).

	NAMES the game reads (Server/World/Trial/Cellar.luau): Stair.Top, Door (LeafW, LeafE, Lock), Larder.Chest (Lid),
	Cistern.Hoard (Lid), Cistern.Burrows (Burrow1..3), Cistern.Pool, Zone.

	WHAT A RERUN DOES: it puts the terrain back exactly as it was (a copy taken on the first run is kept in
	ServerStorage.CellarTerrainBackup), deletes `Cellar` and builds it again. To remove the cellar for good, restore the
	terrain from the backup and delete `Cellar`.

	NOTE: a tool, not game code. Not synced by Rojo. Everything is anchored; floors, walls and ceilings collide, props
	mostly do not.
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local CollectionService = game:GetService("CollectionService")
local ServerStorage = game:GetService("ServerStorage")
local Terrain = workspace.Terrain

--==========================================================================
-- The numbers
--==========================================================================
local GROUND = 2 -- the ground inside the walls
local FLOOR = -14 -- the top of every underground floor
local CELL = 4 -- terrain cells are 4 studs

--[[
	WHY THE CEILING IS AT -6.3 AND NOT HIGHER. The ground's top layer is the terrain cell from y -4 to 0, and smooth terrain
	reaches half a cell (2 studs) beyond a full cell toward an empty one: so the ground over the cellar hangs down to
	y -6. Anything below that is air. A ceiling slab whose underside is at -6.3 or lower hides that edge inside itself;
	one that is higher would have terrain poking through it (the first version of this tool had a ceiling at -3, and a
	ray from inside the larder hit terrain at -5). The same half cell is why every cut is made 4 studs wider than the
	room it holds (see `carve`).
]]
local HALL_TOP = -6.3 -- the underside of the larder and cistern ceilings
local TOP = -3 -- the top of every ceiling slab and wall: inside the earth, above the reach of the ground's edge
local CRAWL_H = 3.4 -- the clear height of the low passage
local CRAWL_TOP = -4.5 -- the top of the low passage's roof slab (it must pass -6, where the ground above hangs)

local STAIR_X = -85 -- the centre line of the stair, and of the door
local STAIR_W = 8
local STAIR_Z0, STAIR_Z1 = -662, -686 -- the top and the foot of the ramp
local DOOR_Z = -692 -- the door wall's near face
local DOOR_W, DOOR_H = 5, 7.5

local HALL = { x0 = -96, x1 = -66, z0 = -706, z1 = -694 } -- the larder's inside
local CRAWL_Z = -699 -- the centre line of the first leg of the low passage
local CRAWL_W = 5
local CISTERN = { x0 = -44, x1 = -26, z0 = -716, z1 = -700, top = HALL_TOP }

local STONE = Color3.fromRGB(100, 97, 92)
local STONE_DARK = Color3.fromRGB(68, 66, 63)
local FLAG = Color3.fromRGB(84, 82, 78)
local OAK = Color3.fromRGB(84, 62, 44)
local OAK_DARK = Color3.fromRGB(56, 42, 32)
local IRON = Color3.fromRGB(46, 42, 40)
local WAX = Color3.fromRGB(226, 212, 178)
local WATER = Color3.fromRGB(34, 52, 60)

--==========================================================================
-- Start: the terrain back as it was, the old cellar gone
--==========================================================================
local recording = ChangeHistoryService:TryBeginRecording("BuildCellar")

local a3 = workspace.Gameplay.Battleground.Decorations.Area3
local old = a3:FindFirstChild("Cellar")
if old then
	old:Destroy()
end

local footprint = Region3.new(Vector3.new(-100, -16, -720), Vector3.new(-20, 8, -658)):ExpandToGrid(CELL)
local footprintMin = footprint.CFrame.Position - footprint.Size / 2
-- the same box in terrain cells (a cell is 4 studs): its first cell and its last
local minCell = Vector3int16.new(math.floor(footprintMin.X / CELL + 0.5), math.floor(footprintMin.Y / CELL + 0.5), math.floor(footprintMin.Z / CELL + 0.5))
local maxCell = Vector3int16.new(
	minCell.X + math.floor(footprint.Size.X / CELL + 0.5) - 1,
	minCell.Y + math.floor(footprint.Size.Y / CELL + 0.5) - 1,
	minCell.Z + math.floor(footprint.Size.Z / CELL + 0.5) - 1
)
local backup = ServerStorage:FindFirstChild("CellarTerrainBackup")
if backup and backup:IsA("TerrainRegion") then
	-- a rerun: the ground as it was before the first cut, then the cut again
	Terrain:PasteRegion(backup, minCell, true)
else
	local copy = Terrain:CopyRegion(Region3int16.new(minCell, maxCell))
	copy.Name = "CellarTerrainBackup"
	copy.Parent = ServerStorage
end

local cellar = Instance.new("Model")
cellar.Name = "Cellar"
cellar.ModelStreamingMode = Enum.ModelStreamingMode.Atomic
cellar.Parent = a3

local function folder(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

local stairM = folder(cellar, "Stair")
local doorM = folder(cellar, "Door")
local larderM = folder(cellar, "Larder")
local crawlM = folder(cellar, "Crawl")
local cisternM = folder(cellar, "Cistern")

--==========================================================================
-- Helpers
--==========================================================================
local function box(parent: Instance, name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3, material: Enum.Material, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = if collide == nil then true else collide
	p.Size = Vector3.new(math.abs(x1 - x0), math.abs(y1 - y0), math.abs(z1 - z0))
	p.Position = Vector3.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2)
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = collide == true
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

--[[
	Cuts a box out of the terrain, ROUNDED OUT to whole terrain cells (4 studs). A box that covers only part of a cell
	does not empty it: it only lowers the cell's fill, and the ground stays (the first version of this tool cut the stair
	in one-stud slices and left the whole trench full). So the cut is always larger than the room, and the room's own
	walls, floor and ceiling (parts, at the exact heights) are what the player sees and stands on.
]]
local function carve(x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, margin: number?)
	local m = if margin == nil then CELL else margin
	local function down(v: number): number
		return math.floor(v / CELL) * CELL
	end
	local function up(v: number): number
		return math.ceil(v / CELL) * CELL
	end
	-- sideways and below the room there is always a margin of a cell (the terrain's own edge reaches 2 studs further
	-- in); above it, the cut stops at the cell boundary the ground needs (see the note at the top)
	local ax0, ax1 = down(math.min(x0, x1) - m), up(math.max(x0, x1) + m)
	local ay0, ay1 = down(math.min(y0, y1) - m), up(math.max(y0, y1))
	local az0, az1 = down(math.min(z0, z1) - m), up(math.max(z0, z1) + m)
	Terrain:FillBlock(CFrame.new((ax0 + ax1) / 2, (ay0 + ay1) / 2, (az0 + az1) / 2), Vector3.new(ax1 - ax0, ay1 - ay0, az1 - az0), Enum.Material.Air)
end

-- A wall torch: an iron bracket, a stick, a flame and the light that is all the cellar has.
local function torch(parent: Instance, at: Vector3, facing: Vector3)
	local cf = CFrame.lookAt(at, at + facing)
	part(parent, "Bracket", Vector3.new(0.3, 0.3, 1.2), cf * CFrame.new(0, 0, -0.5), IRON, Enum.Material.Metal)
	local stick = part(parent, "Torch", Vector3.new(0.35, 1.6, 0.35), cf * CFrame.new(0, 0.5, -1) * CFrame.Angles(math.rad(-12), 0, 0), OAK_DARK, Enum.Material.Wood)
	local head = part(parent, "Flame", Vector3.new(0.5, 0.6, 0.5), stick.CFrame * CFrame.new(0, 0.95, 0), Color3.fromRGB(255, 170, 80), Enum.Material.Neon, Enum.PartType.Ball)
	head.CanQuery = false
	local fire = Instance.new("Fire")
	fire.Size = 3
	fire.Heat = 2
	fire.Color = Color3.fromRGB(255, 150, 60)
	fire.SecondaryColor = Color3.fromRGB(200, 60, 20)
	fire.Parent = head
	local light = Instance.new("PointLight")
	light.Name = "FlameLight"
	light.Color = Color3.fromRGB(255, 168, 92)
	light.Brightness = 1.7
	light.Range = 24
	light.Shadows = false
	light.Parent = head
	CollectionService:AddTag(light, "TLK_Lod")
end

local function candle(parent: Instance, at: Vector3, height: number)
	-- a cylinder's axis is its X: length first, then turned upright
	part(parent, "Candle", Vector3.new(height, 0.3, 0.3), CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), WAX, Enum.Material.SmoothPlastic, Enum.PartType.Cylinder)
	local flame = part(parent, "Flame", Vector3.new(0.18, 0.32, 0.18), CFrame.new(at + Vector3.new(0, height + 0.16, 0)), Color3.fromRGB(255, 190, 90), Enum.Material.Neon, Enum.PartType.Ball)
	flame.CanQuery = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 176, 96)
	light.Brightness = 1.0
	light.Range = 14
	light.Shadows = false
	light.Parent = flame
	CollectionService:AddTag(light, "TLK_Lod")
end

local function cask(parent: Instance, at: Vector3, radius: number, height: number, yaw: number)
	-- upright: a cylinder's long axis is X; turned about Z by 90 degrees it stands
	local body = part(parent, "Cask", Vector3.new(height, radius * 2, radius * 2), CFrame.new(at + Vector3.new(0, height / 2, 0)) * CFrame.Angles(0, math.rad(yaw), math.rad(90)), OAK, Enum.Material.Wood, Enum.PartType.Cylinder, true)
	for _, d in { -height * 0.3, height * 0.3 } do
		part(parent, "Hoop", Vector3.new(0.18, radius * 2 + 0.12, radius * 2 + 0.12), body.CFrame * CFrame.new(d, 0, 0), IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
	end
end

local function sack(parent: Instance, at: Vector3, yaw: number)
	part(parent, "Sack", Vector3.new(2.2, 2.4, 1.8), CFrame.new(at + Vector3.new(0, 1.2, 0)) * CFrame.Angles(0, math.rad(yaw), math.rad(4)), Color3.fromRGB(170, 156, 122), Enum.Material.Fabric, Enum.PartType.Ball)
end

local function chest(parent: Instance, name: string, at: CFrame): Model
	local m = folder(parent, name)
	part(m, "Body", Vector3.new(3.6, 1.7, 2.2), at * CFrame.new(0, 0.85, 0), OAK, Enum.Material.WoodPlanks, nil, true)
	for _, x in { -1.4, 1.4 } do
		part(m, "Band", Vector3.new(0.28, 1.75, 2.28), at * CFrame.new(x, 0.85, 0), IRON, Enum.Material.Metal)
	end
	-- the lid is its own part; the game opens it by turning it about the back top edge of the body (the hinge is
	-- at `Body.CFrame * CFrame.new(0, 0.85, -1.15)`), so nothing here needs to know how
	part(m, "Lid", Vector3.new(3.7, 0.5, 2.3), at * CFrame.new(0, 1.95, 0), OAK_DARK, Enum.Material.WoodPlanks)
	part(m, "Clasp", Vector3.new(0.5, 0.7, 0.2), at * CFrame.new(0, 1.6, 1.15), IRON, Enum.Material.Metal)
	m.PrimaryPart = m:FindFirstChild("Body") :: BasePart
	return m
end

--==========================================================================
-- 1. The stair: a trench cut into the ground, lined with stone
--==========================================================================
-- the height of the ramp at z: GROUND at the top (z = STAIR_Z0), FLOOR at the foot (z = STAIR_Z1)
local function rampY(z: number): number
	local t = math.clamp((STAIR_Z0 - z) / (STAIR_Z0 - STAIR_Z1), 0, 1)
	return GROUND + (FLOOR - GROUND) * t
end

local halfW = STAIR_W / 2
-- the cut: the whole trench, down to the floor and up above the ground (rounded out to cells, see `carve`); under the
-- ramp it is then filled again with the solid stone of the stair
-- (no sideways margin here: the ground beside the stair must stay. The walls are 3 studs thick on the outside, so
-- the terrain's own edge, 2 studs in from the cut at x -92 and x -76, ends inside them.)
carve(-92, -76, FLOOR - 0.6, GROUND + 6, STAIR_Z0 + 2, DOOR_Z, 0)

-- the walkable ramp: a thin slab that follows the slope (invisible: the steps on it are the picture)
do
	local top = Vector3.new(STAIR_X, rampY(STAIR_Z0), STAIR_Z0)
	local bottom = Vector3.new(STAIR_X, rampY(STAIR_Z1), STAIR_Z1)
	local length = (top - bottom).Magnitude
	local ramp = part(stairM, "Ramp", Vector3.new(STAIR_W, 0.6, length), CFrame.lookAt((top + bottom) / 2, bottom) * CFrame.new(0, -0.5, 0), STONE, Enum.Material.Slate, nil, true)
	ramp.Transparency = 1
	-- the steps: one a stud of run, each a solid block of stone from the foot of the stair up to its tread, so the
	-- stair is masonry and not a slab over a void (the walking is done by the invisible ramp above them)
	for z = STAIR_Z0, STAIR_Z1 + 1, -1 do
		local y = rampY(z - 0.5)
		box(stairM, "Step", STAIR_X - halfW, STAIR_X + halfW, FLOOR - 1, y - 0.15, z, z - 1, FLAG, Enum.Material.Slate, false)
		part(stairM, "Nosing", Vector3.new(STAIR_W, 0.14, 0.22), CFrame.new(STAIR_X, y - 0.1, z - 0.1), STONE, Enum.Material.Cobblestone)
	end
	-- the landing floor
	box(stairM, "LandingFloor", STAIR_X - halfW, STAIR_X + halfW, FLOOR - 1, FLOOR, STAIR_Z1, DOOR_Z, FLAG, Enum.Material.Slate)
end

-- the walls of the trench, two studs of run at a time, standing from below the ramp to above the ground
-- (each wall is 1 stud inside the stair's width and 2 outside it: 3 studs thick, which is what hides the terrain's edge)
for z = STAIR_Z0, DOOR_Z + 1, -2 do
	box(stairM, "TrenchWall", STAIR_X - halfW - 3, STAIR_X - halfW, FLOOR - 1, GROUND + 1.6, z, z - 2, STONE, Enum.Material.Cobblestone)
	box(stairM, "TrenchWall", STAIR_X + halfW, STAIR_X + halfW + 3, FLOOR - 1, GROUND + 1.6, z, z - 2, STONE, Enum.Material.Cobblestone)
end
-- the cap: a coping of dark stone along the top of each wall
for _, side in { -1, 1 } do
	local x = STAIR_X + side * (halfW + 1.5)
	box(stairM, "Coping", x - 1.8, x + 1.8, GROUND + 1.5, GROUND + 2.0, STAIR_Z0 + 1.5, DOOR_Z, STONE_DARK, Enum.Material.Slate, false)
end
-- the head of the stair: a lintel stone across the top, and the anchor the game measures "near the cellar" from
box(stairM, "HeadStone", STAIR_X - halfW - 1.4, STAIR_X + halfW + 1.4, GROUND + 0.2, GROUND + 1.0, STAIR_Z0 + 1.5, STAIR_Z0 + 0.5, STONE_DARK, Enum.Material.Slate)
local top = part(stairM, "Top", Vector3.new(2, 2, 2), CFrame.new(STAIR_X, GROUND + 1, STAIR_Z0 + 3), STONE, Enum.Material.Slate)
top.Transparency = 1
top.CanQuery = false

-- a lantern on a post at the head of the stair, so the way down is seen from across the yard
do
	local px, pz = STAIR_X + halfW + 3, STAIR_Z0 + 2
	part(stairM, "LanternPost", Vector3.new(0.6, 8, 0.6), CFrame.new(px, GROUND + 4, pz), OAK_DARK, Enum.Material.Wood, nil, false)
	local arm = part(stairM, "LanternArm", Vector3.new(0.4, 0.4, 2.4), CFrame.new(px, GROUND + 7.6, pz - 1.1), OAK_DARK, Enum.Material.Wood)
	local lantern = part(stairM, "Lantern", Vector3.new(0.9, 1.2, 0.9), arm.CFrame * CFrame.new(0, -0.9, -0.9), Color3.fromRGB(255, 190, 100), Enum.Material.Neon)
	lantern.Transparency = 0.2
	lantern.CanQuery = false
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(255, 176, 96)
	light.Brightness = 1.4
	light.Range = 26
	light.Shadows = false
	light.Parent = lantern
	CollectionService:AddTag(light, "TLK_Lod")
end

--==========================================================================
-- 2. The door wall and the door
--==========================================================================
local WALL = 2
-- the wall: two piers and a lintel round the opening, in the door's wall (z from -692 to -694)
box(doorM, "WallW", HALL.x0 - WALL, STAIR_X - DOOR_W / 2, FLOOR - 1, TOP, DOOR_Z, DOOR_Z - WALL, STONE, Enum.Material.Cobblestone)
box(doorM, "WallE", STAIR_X + DOOR_W / 2, HALL.x1 + WALL, FLOOR - 1, TOP, DOOR_Z, DOOR_Z - WALL, STONE, Enum.Material.Cobblestone)
box(doorM, "Lintel", STAIR_X - DOOR_W / 2, STAIR_X + DOOR_W / 2, FLOOR + DOOR_H, TOP, DOOR_Z, DOOR_Z - WALL, STONE_DARK, Enum.Material.Cobblestone)
box(doorM, "Threshold", STAIR_X - DOOR_W / 2, STAIR_X + DOOR_W / 2, FLOOR - 1, FLOOR, DOOR_Z, DOOR_Z - WALL, FLAG, Enum.Material.Slate)
-- the leaves: two oak doors hinged at the jambs (each leaf's pivot is its hinge edge, so the game swings them with PivotTo)
local leafW = DOOR_W / 2
for _, side in { "W", "E" } do
	local sign = if side == "W" then -1 else 1
	local hingeX = STAIR_X + sign * DOOR_W / 2
	local leaf = Instance.new("Model")
	leaf.Name = "Leaf" .. side
	leaf.Parent = doorM
	local plank = part(leaf, "Planks", Vector3.new(leafW, DOOR_H, 0.8), CFrame.new(hingeX - sign * leafW / 2, FLOOR + DOOR_H / 2, DOOR_Z - 0.6), OAK, Enum.Material.WoodPlanks, nil, true)
	for _, y in { 1.3, DOOR_H - 1.3 } do
		part(leaf, "Strap", Vector3.new(leafW * 0.96, 0.4, 0.14), plank.CFrame * CFrame.new(0, y - DOOR_H / 2, 0.47), IRON, Enum.Material.Metal)
	end
	part(leaf, "Ring", Vector3.new(0.5, 0.5, 0.12), plank.CFrame * CFrame.new(-sign * leafW * 0.35, 0, 0.45), IRON, Enum.Material.Metal)
	-- the hinge is the pivot: a tiny anchor part at the hinge edge, set as the primary part
	local hinge = part(leaf, "Hinge", Vector3.new(0.4, DOOR_H, 0.4), CFrame.new(hingeX, FLOOR + DOOR_H / 2, DOOR_Z - 0.6), IRON, Enum.Material.Metal)
	leaf.PrimaryPart = hinge
end
-- the lock: a big iron plate and keyhole across the join (the game removes it when the door is unlocked)
do
	local lock = Instance.new("Model")
	lock.Name = "Lock"
	lock.Parent = doorM
	part(lock, "Plate", Vector3.new(1.1, 1.5, 0.2), CFrame.new(STAIR_X, FLOOR + 3.4, DOOR_Z + 0.02), IRON, Enum.Material.Metal)
	part(lock, "Keyhole", Vector3.new(0.18, 0.5, 0.22), CFrame.new(STAIR_X, FLOOR + 3.3, DOOR_Z + 0.04), Color3.new(0, 0, 0), Enum.Material.SmoothPlastic)
	lock.PrimaryPart = lock:FindFirstChild("Plate") :: BasePart
end
-- the torches at the landing: the only light a player sees from the stair
torch(stairM, Vector3.new(STAIR_X - halfW + 0.2, FLOOR + 5.2, DOOR_Z + 2), Vector3.new(1, 0, 0))
torch(stairM, Vector3.new(STAIR_X + halfW - 0.2, FLOOR + 5.2, DOOR_Z + 2), Vector3.new(-1, 0, 0))

--==========================================================================
-- 3. The larder
--==========================================================================
carve(HALL.x0 - 1, HALL.x1 + 1, FLOOR - 0.6, HALL_TOP, HALL.z0 - 1, HALL.z1 + 1)
box(larderM, "Floor", HALL.x0 - WALL, HALL.x1 + WALL, FLOOR - 1, FLOOR, HALL.z0 - WALL, DOOR_Z, FLAG, Enum.Material.Slate)
box(larderM, "WallSouth", HALL.x0 - WALL, HALL.x1 + WALL, FLOOR - 1, TOP, HALL.z0 - WALL, HALL.z0, STONE, Enum.Material.Cobblestone)
box(larderM, "WallWest", HALL.x0 - WALL, HALL.x0, FLOOR - 1, TOP, HALL.z0, DOOR_Z, STONE, Enum.Material.Cobblestone)
-- the east wall has the low opening to the crawl: a lintel and two piers, 3.4 clear
box(larderM, "WallEastNorth", HALL.x1, HALL.x1 + WALL, FLOOR - 1, TOP, CRAWL_Z + CRAWL_W / 2, DOOR_Z, STONE, Enum.Material.Cobblestone)
box(larderM, "WallEastSouth", HALL.x1, HALL.x1 + WALL, FLOOR - 1, TOP, HALL.z0, CRAWL_Z - CRAWL_W / 2, STONE, Enum.Material.Cobblestone)
box(larderM, "CrawlLintel", HALL.x1, HALL.x1 + WALL, FLOOR + CRAWL_H, TOP, CRAWL_Z - CRAWL_W / 2, CRAWL_Z + CRAWL_W / 2, STONE_DARK, Enum.Material.Cobblestone)
-- the ceiling: a stone slab under the earth, with oak beams under it
box(larderM, "Ceiling", HALL.x0 - WALL, HALL.x1 + WALL, HALL_TOP, TOP, HALL.z0 - WALL, DOOR_Z, STONE_DARK, Enum.Material.Slate)
for x = HALL.x0 + 3, HALL.x1 - 2, 6 do
	box(larderM, "Beam", x - 0.6, x + 0.6, HALL_TOP - 1.1, HALL_TOP, HALL.z0, HALL.z1, OAK_DARK, Enum.Material.Wood, false)
	-- hams hang from every other beam
	if (x - HALL.x0) % 12 == 3 then
		for _, z in { HALL.z0 + 3, HALL.z0 + 9 } do
			part(larderM, "Cord", Vector3.new(0.08, 1.6, 0.08), CFrame.new(x, HALL_TOP - 1.1 - 0.7, z), Color3.fromRGB(150, 128, 90), Enum.Material.Fabric)
			part(larderM, "Ham", Vector3.new(1.4, 1.2, 2.2), CFrame.new(x, HALL_TOP - 2.7, z), Color3.fromRGB(122, 58, 50), Enum.Material.SmoothPlastic, Enum.PartType.Ball)
		end
	end
end
-- shelves down the west wall and the south wall, with jars and loaves
for _, y in { FLOOR + 2.2, FLOOR + 4.4, FLOOR + 6.6 } do
	box(larderM, "Shelf", HALL.x0, HALL.x0 + 1.4, y - 0.15, y + 0.15, HALL.z0 + 1, HALL.z1 - 1, OAK, Enum.Material.WoodPlanks, false)
	for z = HALL.z0 + 2, HALL.z1 - 2, 2.3 do
		part(larderM, "Jar", Vector3.new(1.1, 0.9, 0.9), CFrame.new(HALL.x0 + 0.8, y + 0.7, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(128 + math.floor(math.abs(z) * 7) % 40, 96, 66), Enum.Material.Slate, Enum.PartType.Cylinder)
	end
end
for _, x in { HALL.x0 + 6, HALL.x0 + 12, HALL.x0 + 18 } do
	cask(larderM, Vector3.new(x, FLOOR, HALL.z0 + 1.8), 1.3, 2.6, 0)
end
for _, x in { HALL.x0 + 8, HALL.x0 + 10 } do
	sack(larderM, Vector3.new(x, FLOOR, HALL.z1 - 1.6), x * 13)
end
-- the long table in the middle, with candles on it
do
	local tx, tz = HALL.x0 + 17, (HALL.z0 + HALL.z1) / 2 + 1
	box(larderM, "TableTop", tx - 3.4, tx + 3.4, FLOOR + 2.9, FLOOR + 3.3, tz - 1.4, tz + 1.4, OAK, Enum.Material.WoodPlanks)
	for _, dx in { -3, 3 } do
		for _, dz in { -1, 1 } do
			box(larderM, "TableLeg", tx + dx - 0.25, tx + dx + 0.25, FLOOR, FLOOR + 2.9, tz + dz - 0.25, tz + dz + 0.25, OAK_DARK, Enum.Material.Wood, false)
		end
	end
	candle(larderM, Vector3.new(tx - 1.8, FLOOR + 3.3, tz), 0.9)
	candle(larderM, Vector3.new(tx + 1.2, FLOOR + 3.3, tz + 0.4), 0.6)
	part(larderM, "Loaf", Vector3.new(1.4, 0.6, 0.7), CFrame.new(tx + 2.4, FLOOR + 3.6, tz - 0.3), Color3.fromRGB(150, 110, 62), Enum.Material.Sand, Enum.PartType.Ball)
end
-- the larder's chest, against the south wall
chest(larderM, "Chest", CFrame.new(HALL.x0 + 24, FLOOR, HALL.z0 + 1.7))
-- torches: one by the door, one at the crawl
torch(larderM, Vector3.new(HALL.x0 + 1, FLOOR + 5.4, DOOR_Z - 2.6), Vector3.new(1, 0, 0))
torch(larderM, Vector3.new(HALL.x1 - 0.2, FLOOR + 5.4, HALL.z0 + 2.4), Vector3.new(-1, 0, 0))

--==========================================================================
-- 4. The crawl: a low passage that bends twice (east, south, east)
--==========================================================================
local legs = {
	{ x0 = HALL.x1, x1 = -53.5, z0 = CRAWL_Z - CRAWL_W / 2, z1 = CRAWL_Z + CRAWL_W / 2 }, -- A: east out of the larder
	{ x0 = -58.5, x1 = -53.5, z0 = -710.5, z1 = CRAWL_Z - CRAWL_W / 2 }, -- B: south from A's south edge
	{ x0 = -58.5, x1 = CISTERN.x0 + 0.5, z0 = -710.5, z1 = -705.5 }, -- C: east into the cistern
}
local CH = FLOOR + CRAWL_H
for index, leg in legs do
	carve(leg.x0, leg.x1, FLOOR - 0.6, -4, leg.z0, leg.z1)
	box(crawlM, "Floor" .. index, leg.x0 - 1.4, leg.x1 + 1.4, FLOOR - 1, FLOOR, leg.z0 - 1.4, leg.z1 + 1.4, FLAG, Enum.Material.Slate)
	box(crawlM, "Roof" .. index, leg.x0 - 1.4, leg.x1 + 1.4, CH, CRAWL_TOP, leg.z0 - 1.4, leg.z1 + 1.4, STONE_DARK, Enum.Material.Slate)
end
--[[
	The walls, one piece to a side, drawn by hand because the three legs share corners:

	      x -64        -58.5   -53.5       -46
	z -695.1  +-----------------------+
	          |        leg A          |      A runs east out of the larder (x -66 to -53.5, z -701.5 to -696.5)
	z -701.5  +--------+ B  +----------+      B turns south (x -58.5 to -53.5)
	                   |    |
	z -705.5           |    +----------+      C turns east again (z -710.5 to -705.5) and reaches the cistern
	                   +---- leg C ----+
	z -711.9
]]
local function crawlWall(name: string, x0: number, x1: number, z0: number, z1: number)
	box(crawlM, name, x0, x1, FLOOR - 1, CRAWL_TOP, z0, z1, STONE, Enum.Material.Cobblestone)
end
crawlWall("A_North", -64, -52.1, -696.5, -695.1)
crawlWall("A_SouthWest", -64, -58.5, -702.9, -701.5)
crawlWall("BC_West", -59.9, -58.5, -711.9, -701.5)
crawlWall("AB_East", -53.5, -52.1, -705.5, -695.1)
crawlWall("C_North", -53.5, -46, -705.5, -704.1)
crawlWall("C_South", -59.9, -46, -711.9, -710.5)
-- a few low arches of oak so the passage looks propped, and a rat's nest of old straw
for _, x in { -62, -55.8 } do
	box(crawlM, "Prop", x - 0.3, x + 0.3, FLOOR, CH, legs[1].z0, legs[1].z0 + 0.5, OAK_DARK, Enum.Material.Wood, false)
	box(crawlM, "Prop", x - 0.3, x + 0.3, FLOOR, CH, legs[1].z1 - 0.5, legs[1].z1, OAK_DARK, Enum.Material.Wood, false)
	box(crawlM, "Header", x - 0.3, x + 0.3, CH - 0.35, CH, legs[1].z0, legs[1].z1, OAK_DARK, Enum.Material.Wood, false)
end
part(crawlM, "Straw", Vector3.new(2.6, 0.3, 1.8), CFrame.new(-56, FLOOR + 0.15, -708), Color3.fromRGB(150, 128, 74), Enum.Material.Sand)
-- one candle stub in a niche at the first bend, the only light in the crawl
candle(crawlM, Vector3.new(-55.9, FLOOR + 0.1, -701.3), 0.5)

--==========================================================================
-- 5. The cistern: a flooded vault under the Dairy
--==========================================================================
local c = CISTERN
carve(c.x0, c.x1, FLOOR - 0.6, c.top, c.z0, c.z1)
box(cisternM, "Floor", c.x0 - WALL, c.x1 + WALL, FLOOR - 1, FLOOR, c.z0 - WALL, c.z1 + WALL, FLAG, Enum.Material.Slate)
box(cisternM, "WallSouth", c.x0 - WALL, c.x1 + WALL, FLOOR - 1, TOP, c.z0 - WALL, c.z0, STONE, Enum.Material.Cobblestone)
box(cisternM, "WallNorth", c.x0 - WALL, c.x1 + WALL, FLOOR - 1, TOP, c.z1, c.z1 + WALL, STONE, Enum.Material.Cobblestone)
box(cisternM, "WallEast", c.x1, c.x1 + WALL, FLOOR - 1, TOP, c.z0, c.z1, STONE, Enum.Material.Cobblestone)
-- the west wall, with the low mouth of the crawl in it
box(cisternM, "WallWestNorth", c.x0 - WALL, c.x0, FLOOR - 1, TOP, -705.5, c.z1, STONE, Enum.Material.Cobblestone)
box(cisternM, "WallWestSouth", c.x0 - WALL, c.x0, FLOOR - 1, TOP, c.z0, -710.5, STONE, Enum.Material.Cobblestone)
box(cisternM, "MouthLintel", c.x0 - WALL, c.x0, CH, TOP, -710.5, -705.5, STONE_DARK, Enum.Material.Cobblestone)
box(cisternM, "Ceiling", c.x0 - WALL, c.x1 + WALL, c.top, TOP, c.z0 - WALL, c.z1 + WALL, STONE_DARK, Enum.Material.Slate)
-- columns carrying the vault
for _, x in { c.x0 + 5, c.x0 + 13 } do
	for _, z in { c.z0 + 4, c.z1 - 4 } do
		box(cisternM, "Column", x - 0.9, x + 0.9, FLOOR, c.top, z - 0.9, z + 0.9, STONE, Enum.Material.Cobblestone)
	end
end
-- the water: ankle deep, dark, and still (it does not collide; you wade)
local pool = box(cisternM, "Pool", c.x0 + 0.5, c.x1 - 5, FLOOR + 0.05, FLOOR + 0.7, c.z0 + 0.5, c.z1 - 0.5, WATER, Enum.Material.Glass, false)
pool.Transparency = 0.35
pool.Reflectance = 0.15
pool.CanQuery = false
-- the dais at the east end, with the hoard on it
box(cisternM, "Dais", c.x1 - 5, c.x1, FLOOR, FLOOR + 1.1, c.z0 + 4, c.z1 - 4, STONE, Enum.Material.Cobblestone)
local hoard = chest(cisternM, "Hoard", CFrame.new(c.x1 - 2.6, FLOOR + 1.1, (c.z0 + c.z1) / 2) * CFrame.Angles(0, math.rad(-90), 0))
-- bones beside it: whoever hid this did not leave
part(cisternM, "Bones", Vector3.new(2.6, 0.3, 1.1), CFrame.new(c.x1 - 3.6, FLOOR + 1.3, (c.z0 + c.z1) / 2 + 3.4) * CFrame.Angles(0, math.rad(20), 0), Color3.fromRGB(206, 196, 168), Enum.Material.Slate)
part(cisternM, "Skull", Vector3.new(0.9, 0.8, 0.9), CFrame.new(c.x1 - 2.3, FLOOR + 1.6, (c.z0 + c.z1) / 2 + 3.6), Color3.fromRGB(214, 204, 176), Enum.Material.Slate, Enum.PartType.Ball)
-- the three mounds where the dead dig up through the floor: rubble over a slab that is already lifted
local burrows = Instance.new("Folder")
burrows.Name = "Burrows"
burrows.Parent = cisternM
local mounds = {
	Vector3.new(c.x0 + 3.5, FLOOR, c.z1 - 3),
	Vector3.new(c.x0 + 9, FLOOR, c.z0 + 3),
	Vector3.new(c.x0 + 12.5, FLOOR, c.z1 - 4.5),
}
for i, at in mounds do
	local m = Instance.new("Model")
	m.Name = "Burrow" .. i
	m.Parent = burrows
	local pit = part(m, "Pit", Vector3.new(0.2, 3.2, 3.2), CFrame.new(at + Vector3.new(0, 0.12, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(26, 22, 20), Enum.Material.Slate, Enum.PartType.Cylinder)
	for k = 1, 6 do
		local a = k * math.pi / 3
		part(m, "Rubble", Vector3.new(0.9 + (k % 3) * 0.3, 0.5, 0.8), CFrame.new(at + Vector3.new(math.cos(a) * 1.9, 0.3, math.sin(a) * 1.9)) * CFrame.Angles(0.2 * k, k, 0.1), STONE, Enum.Material.Cobblestone)
	end
	m.PrimaryPart = pit
end
torch(cisternM, Vector3.new(c.x0 + 1, FLOOR + 5, c.z1 - 0.2), Vector3.new(0, 0, -1))
torch(cisternM, Vector3.new(c.x1 - 0.2, FLOOR + 5, c.z0 + 3), Vector3.new(-1, 0, 0))
candle(cisternM, Vector3.new(c.x1 - 2.6, FLOOR + 3.2, (c.z0 + c.z1) / 2 - 1.5), 0.5)

--==========================================================================
-- The light zone: one invisible box over everything from the door inwards
--==========================================================================
local zone = Instance.new("Part")
zone.Name = "Zone"
zone.Anchored = true
zone.CanCollide = false
zone.CanQuery = false
zone.CanTouch = false
zone.Transparency = 1
zone.Size = Vector3.new(CISTERN.x1 + 2 - (HALL.x0 - 2), 11, (DOOR_Z - 0.5) - (CISTERN.z0 - 2))
zone.Position = Vector3.new((CISTERN.x1 + 2 + HALL.x0 - 2) / 2, FLOOR + 4.5, ((DOOR_Z - 0.5) + (CISTERN.z0 - 2)) / 2)
zone:SetAttribute("Profile", "Cellar")
zone:SetAttribute("Priority", 1)
zone.Parent = cellar
CollectionService:AddTag(zone, "TLK_LightZone")

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end

local count = 0
for _, d in cellar:GetDescendants() do
	if d:IsA("BasePart") then
		count += 1
	end
end
print(("[BuildCellar] built: %d parts. Stair top at (%d, %d, %d)."):format(count, STAIR_X, GROUND, STAIR_Z0))
return count
