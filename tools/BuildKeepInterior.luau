--[[
	BuildKeepInterior — run in the FORGOTTEN LANDS place, in EDIT MODE.
	Furnishes the inside of the keep at the head of the Keep Steps (chamber 9) and builds the way UP and OUT
	that the ending opens: a stair tower (three switchback flights) behind a locked door, the wall-walk round the
	top, and the arch at the end of it. Everything goes into `Decorations.Area9.Keep.Interior`; a rerun deletes
	that model and builds it again.

	THE HALL (floor y = 20, inside x +-29.9, z -2211.9 .. -2164.3)
	  - six pillars, a long table with chairs and candles, a great hearth in the east wall, bordeaux banners,
	  - the scribe's desk at the back, with shelves of rolls behind it (Interior.Desk.ScribeAt is where he stands).

	THE WAY OUT (nothing here is reachable until the roof door opens: Trial/Exit)
	  - the stair tower along the west wall: a vestibule, a door (Interior.RoofDoor: a Leaf that swings, a Lock),
	    three flights of nineteen steps with landings, up to the wall-walk at y = 71.3;
	  - the wall-walk: along the front, down the east side, along the back, with a railing on the inner edge;
	  - the arch at the end of it (Interior.ExitArch: the light that is the way out, a Gate part for the prompt).

	NOTE: a tool, not game code. Not synced by Rojo. Parts are anchored; the hall's furniture does not collide
	where a body could catch on it (the pathfinder breaks on clutter near doors and stairs).
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local keep = workspace.Gameplay.Battleground.Decorations.Area9.Keep
local old = keep:FindFirstChild("Interior")
local recording = ChangeHistoryService:TryBeginRecording("BuildKeepInterior")
if old then
	old:Destroy()
end

local root = Instance.new("Model")
root.Name = "Interior"
root.Parent = keep

--==========================================================================
local X0, X1 = -29.9, 29.9
local Z0, Z1 = -2211.9, -2164.3 -- back, front (the hall faces +z, the door is at the front)
local FLOOR = 20

local STONE = Color3.fromRGB(109, 105, 99)
local STONE_DARK = Color3.fromRGB(88, 84, 80)
local STONE_PALE = Color3.fromRGB(128, 122, 112)
local OAK = Color3.fromRGB(84, 62, 44)
local OAK_DARK = Color3.fromRGB(58, 44, 34)
local OAK_PALE = Color3.fromRGB(104, 80, 54)
local IRON = Color3.fromRGB(52, 46, 42)
local CLOTH = Color3.fromRGB(96, 36, 44)
local GOLD = Color3.fromRGB(150, 120, 52)
local LINEN = Color3.fromRGB(150, 138, 118)
local WAX = Color3.fromRGB(214, 200, 168)

local function folder(name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = root
	return m
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, collide: boolean?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Anchored = true
	p.CanCollide = if collide == nil then true else collide
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = parent
	return p
end

-- a block by its extents
local function block(parent: Instance, name: string, x0: number, x1: number, y0: number, y1: number, z0: number, z1: number, color: Color3, material: Enum.Material, collide: boolean?): Part
	return part(parent, name, Vector3.new(x1 - x0, y1 - y0, z1 - z0), CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, (z0 + z1) / 2), color, material, collide)
end

local function cyl(parent: Instance, name: string, length: number, diameter: number, cf: CFrame, color: Color3, material: Enum.Material, collide: boolean?): Part
	local p = part(parent, name, Vector3.new(length, diameter, diameter), cf, color, material, collide)
	p.Shape = Enum.PartType.Cylinder
	return p
end

--==========================================================================
-- THE STAIR TOWER
--==========================================================================
local stair = folder("Stair")
local TX0, TX1 = X0, -17.9 -- the tower, along the west wall
local FLIGHT_W = 4
local STEPS = 19
local RISE = 0.9
local RUN = 1.8
local ZA = -2203.2 -- where the flights start (the vestibule is behind it)
local ZE = ZA + STEPS * RUN -- -2169.0
local TOP_A = FLOOR + STEPS * RISE -- 37.1
local TOP_B = TOP_A + STEPS * RISE -- 54.2
local TOP_C = TOP_B + STEPS * RISE -- 71.3

-- Flight A: x -29.9 .. -25.9, +z, y 20 -> 37.1. Solid steps from the floor.
for i = 1, STEPS do
	block(stair, "StepA", TX0, TX0 + FLIGHT_W, FLOOR, FLOOR + i * RISE, ZA + (i - 1) * RUN, ZA + i * RUN, STONE, Enum.Material.Slate)
end
-- Landing 1 (front of the tower): x -29.9 .. -21.9, z ZE .. Z1, solid up to 37.1
block(stair, "Landing1", TX0, TX0 + 2 * FLIGHT_W, FLOOR, TOP_A, ZE, Z1, STONE_PALE, Enum.Material.Slate)
-- Flight B: x -25.9 .. -21.9, -z, y 37.1 -> 54.2, on a pier from the floor
block(stair, "PierB", TX0 + FLIGHT_W, TX0 + 2 * FLIGHT_W, FLOOR, TOP_A, ZA, ZE, STONE_DARK, Enum.Material.Slate)
for i = 1, STEPS do
	block(stair, "StepB", TX0 + FLIGHT_W, TX0 + 2 * FLIGHT_W, TOP_A, TOP_A + i * RISE, ZE - i * RUN, ZE - (i - 1) * RUN, STONE, Enum.Material.Slate)
end
-- Landing 2 (back of the tower, high over the vestibule): x -29.9 .. -21.9, z Z0 .. ZA, a slab 1.4 thick at 54.2
block(stair, "Landing2", TX0, TX0 + 2 * FLIGHT_W, TOP_B - 1.4, TOP_B, Z0, ZA, STONE_PALE, Enum.Material.Slate)
-- Flight C: x -21.9 .. -17.9, +z, y 54.2 -> 71.3, on a pier from the floor
block(stair, "PierC", TX0 + 2 * FLIGHT_W, TX1, FLOOR, TOP_B, ZA, ZE, STONE_DARK, Enum.Material.Slate)
for i = 1, STEPS do
	block(stair, "StepC", TX0 + 2 * FLIGHT_W, TX1, TOP_B, TOP_B + i * RISE, ZA + (i - 1) * RUN, ZA + i * RUN, STONE, Enum.Material.Slate)
end
-- The head of the stair (front of the tower, at the walk's level)
block(stair, "Head", TX0 + 2 * FLIGHT_W, TX1, TOP_B, TOP_C, ZE, Z1, STONE_PALE, Enum.Material.Slate)
-- the ceiling over the vestibule's door is the landing; the stair's own corbels under the high landing
for _, x in { TX0 + 1.5, TX0 + 6.5 } do
	part(stair, "Corbel", Vector3.new(1.4, 1.6, 1.4), CFrame.new(x, TOP_B - 2.2, Z0 + 1), STONE_DARK, Enum.Material.Slate)
end

-- the partition: the tower's east wall, with the doorway at its foot
local PX0, PX1 = TX1, TX1 + 1.2
local DOOR_Z0, DOOR_Z1 = -2210.4, -2206.4
local DOOR_H = 7.8
block(stair, "PartitionBack", PX0, PX1, FLOOR, TOP_C - 1.2, Z0, DOOR_Z0, STONE, Enum.Material.Slate)
block(stair, "PartitionFront", PX0, PX1, FLOOR, TOP_C - 1.2, DOOR_Z1, Z1, STONE, Enum.Material.Slate)
block(stair, "PartitionLintel", PX0, PX1, FLOOR + DOOR_H, TOP_C - 1.2, DOOR_Z0, DOOR_Z1, STONE, Enum.Material.Slate)
-- the doorway's stone frame
block(stair, "Jamb", PX0 - 0.3, PX1 + 0.3, FLOOR, FLOOR + DOOR_H, DOOR_Z0 - 0.6, DOOR_Z0, STONE_PALE, Enum.Material.Slate)
block(stair, "Jamb", PX0 - 0.3, PX1 + 0.3, FLOOR, FLOOR + DOOR_H, DOOR_Z1, DOOR_Z1 + 0.6, STONE_PALE, Enum.Material.Slate)
block(stair, "Head", PX0 - 0.3, PX1 + 0.3, FLOOR + DOOR_H, FLOOR + DOOR_H + 0.7, DOOR_Z0 - 0.6, DOOR_Z1 + 0.6, STONE_PALE, Enum.Material.Slate)

--==========================================================================
-- THE ROOF DOOR (iron-bound oak, hinged on the north jamb, opens inward to the tower)
--==========================================================================
local door = folder("RoofDoor")
local leaf = Instance.new("Model")
leaf.Name = "Leaf"
leaf.Parent = door
local DOOR_X = (PX0 + PX1) / 2
local hingeZ = DOOR_Z0
local doorW = DOOR_Z1 - DOOR_Z0
local planks = 6
for i = 1, planks do
	local z = hingeZ + (i - 0.5) * doorW / planks
	part(leaf, "Plank", Vector3.new(0.7, DOOR_H - 0.2, doorW / planks - 0.06), CFrame.new(DOOR_X, FLOOR + DOOR_H / 2, z), OAK_PALE, Enum.Material.WoodPlanks)
end
for _, y in { 1.6, DOOR_H / 2, DOOR_H - 1.6 } do
	part(leaf, "Strap", Vector3.new(0.9, 0.45, doorW - 0.1), CFrame.new(DOOR_X + 0.05, FLOOR + y, hingeZ + doorW / 2), IRON, Enum.Material.CorrodedMetal)
	part(leaf, "HingeEye", Vector3.new(1.0, 0.7, 0.7), CFrame.new(DOOR_X + 0.05, FLOOR + y, hingeZ + 0.3), IRON, Enum.Material.CorrodedMetal, false)
end
local lock = part(leaf, "Lock", Vector3.new(0.5, 1.8, 1.4), CFrame.new(DOOR_X + 0.55, FLOOR + DOOR_H / 2 - 0.4, hingeZ + doorW - 0.9), IRON, Enum.Material.Metal, false)
part(leaf, "Keyhole", Vector3.new(0.12, 0.5, 0.18), CFrame.new(DOOR_X + 0.84, FLOOR + DOOR_H / 2 - 0.5, hingeZ + doorW - 0.9), Color3.fromRGB(10, 8, 8), Enum.Material.SmoothPlastic, false)
part(leaf, "Ring", Vector3.new(0.2, 1.0, 1.0), CFrame.new(DOOR_X + 0.62, FLOOR + DOOR_H / 2 + 0.7, hingeZ + doorW - 0.9) * CFrame.Angles(0, 0, 0), IRON, Enum.Material.Metal, false).Shape = Enum.PartType.Cylinder
leaf.PrimaryPart = lock
door:SetAttribute("Locked", true)
-- the hinge pin: a vertical post where the leaf turns
local hinge = part(door, "Hinge", Vector3.new(0.5, DOOR_H, 0.5), CFrame.new(DOOR_X, FLOOR + DOOR_H / 2, hingeZ), IRON, Enum.Material.Metal, false)
hinge.Name = "Hinge"

--==========================================================================
-- THE WALL-WALK
--==========================================================================
local walk = folder("Walk")
local THICK = 1.2
local WALK_Y = TOP_C
local function slab(name: string, x0: number, x1: number, z0: number, z1: number)
	return block(walk, name, x0, x1, WALK_Y - THICK, WALK_Y, z0, z1, STONE, Enum.Material.Slate)
end
slab("Front", TX1, 24.5, Z1 - 5.2, Z1)
slab("East", 19.5, X1, Z0 + 5.4, Z1 - 5.2)
slab("Back", -13.0, 24.5, Z0, Z0 + 5.4)
-- corbels under the walk, off the walls (so it does not float)
for x = -14, 22, 9 do
	part(walk, "Corbel", Vector3.new(1.6, 2.2, 1.8), CFrame.new(x, WALK_Y - THICK - 1.1, Z1 - 0.9) * CFrame.Angles(0, 0, 0), STONE_DARK, Enum.Material.Slate)
end
for z = -2205, -2175, 9 do
	part(walk, "Corbel", Vector3.new(1.8, 2.2, 1.6), CFrame.new(X1 - 0.9, WALK_Y - THICK - 1.1, z), STONE_DARK, Enum.Material.Slate)
end
for x = -8, 22, 10 do
	part(walk, "Corbel", Vector3.new(1.6, 2.2, 1.8), CFrame.new(x, WALK_Y - THICK - 1.1, Z0 + 0.9), STONE_DARK, Enum.Material.Slate)
end
-- and four stone arches springing from the pillars (below), carried up by the pillar capitals in the hall
-- railings on the inner edges
local function rail(name: string, x0: number, x1: number, z0: number, z1: number)
	block(walk, name, x0, x1, WALK_Y, WALK_Y + 3.2, z0, z1, STONE_PALE, Enum.Material.Slate)
	block(walk, name .. "Coping", x0 - 0.2, x1 + 0.2, WALK_Y + 3.2, WALK_Y + 3.7, z0 - 0.2, z1 + 0.2, STONE, Enum.Material.Slate)
end
rail("RailFront", TX1, 19.5, Z1 - 5.2, Z1 - 4.7)
rail("RailEast", 19.5, 20.0, Z0 + 5.4, Z1 - 5.2)
rail("RailBack", -13.0, 19.5, Z0 + 5.4, Z0 + 5.9)
rail("RailEndcap", -13.2, -12.7, Z0, Z0 + 5.4)

--==========================================================================
-- THE ARCH (the way out)
--==========================================================================
local arch = folder("ExitArch")
local AX = -7.0
local AZ = (Z0 + Z0 + 5.4) / 2
for _, side in { -1, 1 } do
	block(arch, "Post", AX + side * 3.2 - 0.9, AX + side * 3.2 + 0.9, WALK_Y, WALK_Y + 9.6, AZ - 1.1, AZ + 1.1, STONE_PALE, Enum.Material.Slate)
	block(arch, "PostBase", AX + side * 3.2 - 1.2, AX + side * 3.2 + 1.2, WALK_Y, WALK_Y + 0.8, AZ - 1.4, AZ + 1.4, STONE_DARK, Enum.Material.Slate)
end
block(arch, "Lintel", AX - 4.6, AX + 4.6, WALK_Y + 9.6, WALK_Y + 11, AZ - 1.3, AZ + 1.3, STONE_PALE, Enum.Material.Slate)
part(arch, "Keystone", Vector3.new(1.4, 1.8, 1.7), CFrame.new(AX, WALK_Y + 10.9, AZ), GOLD, Enum.Material.Metal, false)
-- the light that is the way out: a pale plane in the doorway, and a soft lamp
local light = part(arch, "ExitLight", Vector3.new(5.0, 9.4, 0.3), CFrame.new(AX, WALK_Y + 4.9, AZ), Color3.fromRGB(232, 240, 255), Enum.Material.Neon, false)
light.Transparency = 0.45
light.CanQuery = false
local lamp = Instance.new("PointLight")
lamp.Color = Color3.fromRGB(220, 232, 255)
lamp.Brightness = 1.6
lamp.Range = 26
lamp.Shadows = false
lamp.Parent = light
local gate = part(arch, "Gate", Vector3.new(6, 6, 6), CFrame.new(AX, WALK_Y + 3, AZ + 2.4), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
gate.Transparency = 1
gate.CanQuery = false
gate.CanTouch = false

--==========================================================================
-- THE KEEP DOOR: two leaves of oak and iron in the seal's place (the seal part stays, unseen, to hold
-- the way shut until Trial/Unseal lifts the bar and swings the leaves inward)
--==========================================================================
local kd = folder("KeepDoor")
local DOOR_Z = -2162
local seal = keep:FindFirstChild("KeepDoor")
if seal and seal:IsA("BasePart") then
	seal.Transparency = 1
end
for _, side in { -1, 1 } do
	local leaf = Instance.new("Model")
	leaf.Name = if side == -1 then "LeafL" else "LeafR"
	leaf.Parent = kd
	local hx = side * 5
	local spine = part(leaf, "Spine", Vector3.new(0.5, 16, 0.5), CFrame.new(hx, 28, DOOR_Z), IRON, Enum.Material.CorrodedMetal, false)
	for i = 1, 5 do
		local tone = 0.9 + 0.06 * ((i * 7) % 4)
		part(leaf, "Plank", Vector3.new(0.96, 15.8, 0.8), CFrame.new(hx - side * (0.5 + (i - 1) * 0.99), 28, DOOR_Z), Color3.new(OAK.R * tone, OAK.G * tone, OAK.B * tone), Enum.Material.WoodPlanks, false)
	end
	for _, y in { 22.2, 28, 33.8 } do
		part(leaf, "Strap", Vector3.new(5.0, 0.55, 1.0), CFrame.new(hx - side * 2.5, y, DOOR_Z), IRON, Enum.Material.CorrodedMetal, false)
		for k = 0, 4 do
			cyl(leaf, "Stud", 0.3, 0.45, CFrame.new(hx - side * (0.6 + k * 1.0), y, DOOR_Z - 0.55) * CFrame.Angles(0, 0, math.rad(90)) * CFrame.Angles(0, 0, 0), STONE_DARK, Enum.Material.Metal, false)
		end
	end
	local ring = cyl(leaf, "Ring", 0.2, 1.5, CFrame.new(hx - side * 4.4, 27.4, DOOR_Z - 0.6) * CFrame.Angles(0, math.rad(90), 0), IRON, Enum.Material.Metal, false)
	ring.Name = "Ring"
	leaf.PrimaryPart = spine
	leaf:SetAttribute("Hinge", Vector3.new(hx, 28, DOOR_Z))
	leaf:SetAttribute("Side", side)
end

--==========================================================================
-- THE HALL
--==========================================================================
local hall = folder("Hall")

-- six pillars with capitals, a row each side of the table
for _, x in { -12, 12 } do
	for _, z in { -2178, -2190, -2202 } do
		block(hall, "PillarBase", x - 1.8, x + 1.8, FLOOR, FLOOR + 1.2, z - 1.8, z + 1.8, STONE_DARK, Enum.Material.Slate)
		cyl(hall, "Pillar", 49, 3.4, CFrame.new(x, FLOOR + 1.2 + 24.5, z) * CFrame.Angles(0, 0, math.rad(90)), STONE, Enum.Material.Slate)
		cyl(hall, "Capital", 1.6, 4.8, CFrame.new(x, FLOOR + 50.2 + 0.8, z) * CFrame.Angles(0, 0, math.rad(90)), STONE_PALE, Enum.Material.Slate)
	end
end

-- light: a sconce on each pillar's inner face, and a brazier either side of the door. A hall of this size
-- needs something to see it by, and the dead have no use for light; the living who come here do.
local function lit(parent: Instance, at: Vector3, size: number, brightness: number, range: number)
	local anchor = part(parent, "Flame", Vector3.new(0.6, 0.6, 0.6), CFrame.new(at), Color3.fromRGB(255, 160, 70), Enum.Material.Neon, false)
	anchor.Transparency = 1
	anchor.CanQuery = false
	local f = Instance.new("Fire")
	f.Size = size
	f.Heat = size * 0.8
	f.Color = Color3.fromRGB(255, 150, 60)
	f.SecondaryColor = Color3.fromRGB(200, 60, 20)
	f.Parent = anchor
	local l = Instance.new("PointLight")
	l.Color = Color3.fromRGB(255, 170, 90)
	l.Brightness = brightness
	l.Range = range
	l.Shadows = false
	l.Parent = anchor
	game:GetService("CollectionService"):AddTag(l, "TLK_Lod")
end
for _, x in { -12, 12 } do
	for _, z in { -2184, -2196 } do
		local face = if x < 0 then 1 else -1
		part(hall, "SconceBracket", Vector3.new(1.4, 0.4, 0.4), CFrame.new(x + face * 2.2, FLOOR + 14, z), IRON, Enum.Material.CorrodedMetal, false)
		cyl(hall, "SconceCup", 1.0, 0.9, CFrame.new(x + face * 2.9, FLOOR + 14.5, z) * CFrame.Angles(0, 0, math.rad(90)), IRON, Enum.Material.CorrodedMetal, false)
		lit(hall, Vector3.new(x + face * 2.9, FLOOR + 15.3, z), 3, 1.5, 36)
	end
end
for _, x in { -9, 9 } do
	cyl(hall, "BrazierBowl", 1.2, 3.2, CFrame.new(x, FLOOR + 3.6, -2170.5) * CFrame.Angles(0, 0, math.rad(90)), IRON, Enum.Material.CorrodedMetal, false)
	cyl(hall, "BrazierStem", 3.2, 0.7, CFrame.new(x, FLOOR + 1.6, -2170.5) * CFrame.Angles(0, 0, math.rad(90)), IRON, Enum.Material.CorrodedMetal)
	lit(hall, Vector3.new(x, FLOOR + 4.6, -2170.5), 5, 1.7, 40)
end

-- the long table, down the middle
local TABLE_Y = FLOOR
local table_ = folder("Table")
table_.Parent = hall
block(table_, "Top", -3.2, 3.2, TABLE_Y + 3.0, TABLE_Y + 3.6, -2198, -2176, OAK, Enum.Material.WoodPlanks)
for _, z in { -2196, -2187, -2178 } do
	for _, x in { -2.6, 2.6 } do
		block(table_, "Leg", x - 0.35, x + 0.35, TABLE_Y, TABLE_Y + 3.0, z - 0.35, z + 0.35, OAK_DARK, Enum.Material.Wood)
	end
	block(table_, "Stretcher", -2.6, 2.6, TABLE_Y + 0.9, TABLE_Y + 1.25, z - 0.2, z + 0.2, OAK_DARK, Enum.Material.Wood, false)
end
-- a feast, long gone: plates, a loaf, a tipped goblet, candles burned to the wood
for i = 0, 9 do
	local z = -2197 + i * 2.1
	local side = if i % 2 == 0 then -1 else 1
	cyl(table_, "Plate", 0.12, 1.5, CFrame.new(side * 1.7, TABLE_Y + 3.7, z) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(120, 116, 106), Enum.Material.Metal, false)
	if i % 3 == 0 then
		cyl(table_, "Goblet", 0.9, 0.55, CFrame.new(-side * 1.5, TABLE_Y + 4.1, z + 0.4) * CFrame.Angles(0, 0, math.rad(if i == 6 then 20 else 90)), GOLD, Enum.Material.Metal, false)
	end
end
for _, z in { -2194, -2187, -2180 } do
	cyl(table_, "Candle", 1.4, 0.4, CFrame.new(0, TABLE_Y + 4.3, z) * CFrame.Angles(0, 0, math.rad(90)), WAX, Enum.Material.SmoothPlastic, false)
	part(table_, "Flame", Vector3.new(0.3, 0.5, 0.3), CFrame.new(0, TABLE_Y + 5.2, z), Color3.fromRGB(255, 190, 90), Enum.Material.Neon, false).Name = "CandleFlame"
end
-- the chairs, pushed back, one over
for i = 0, 4 do
	for _, side in { -1, 1 } do
		local z = -2196 + i * 4.4
		local x = side * 5.6
		local fallen = (i == 2 and side == 1)
		local chair = folder("Chair")
		chair.Parent = hall
		local base = CFrame.new(x, 0, z) * CFrame.Angles(0, if side == 1 then math.rad(-90) else math.rad(90), 0)
		if fallen then
			base = base * CFrame.Angles(0, 0, math.rad(86)) * CFrame.new(1.4, 0.6, 0)
		end
		local function c(sz: Vector3, off: Vector3)
			part(chair, "Piece", sz, base * CFrame.new(off + Vector3.new(0, FLOOR, 0)), OAK, Enum.Material.Wood, false)
		end
		c(Vector3.new(2.2, 0.4, 2.2), Vector3.new(0, 2.2, 0))
		for _, lx in { -0.9, 0.9 } do
			for _, lz in { -0.9, 0.9 } do
				c(Vector3.new(0.3, 2.2, 0.3), Vector3.new(lx, 1.1, lz))
			end
		end
		c(Vector3.new(2.2, 2.6, 0.3), Vector3.new(0, 3.6, -0.95))
	end
end

-- the hearth in the east wall
local hearth = folder("Hearth")
hearth.Parent = hall
local HZ = -2188
block(hearth, "Back", X1 - 1.0, X1, FLOOR, FLOOR + 14, HZ - 6.5, HZ + 6.5, STONE_DARK, Enum.Material.Slate, false)
block(hearth, "Base", X1 - 5.0, X1 - 0.6, FLOOR, FLOOR + 1.0, HZ - 7.5, HZ + 7.5, STONE_PALE, Enum.Material.Slate)
for _, s in { -1, 1 } do
	block(hearth, "Jamb", X1 - 3.6, X1 - 0.6, FLOOR + 1.0, FLOOR + 10.5, HZ + s * 6.0 - 1.0, HZ + s * 6.0 + 1.0, STONE_PALE, Enum.Material.Slate)
end
block(hearth, "Mantel", X1 - 4.2, X1 - 0.4, FLOOR + 10.5, FLOOR + 11.8, HZ - 7.4, HZ + 7.4, OAK, Enum.Material.Wood)
block(hearth, "Hood", X1 - 3.0, X1 - 0.6, FLOOR + 11.8, FLOOR + 22, HZ - 6.2, HZ + 6.2, STONE, Enum.Material.Slate, false)
for i = 0, 5 do
	cyl(hearth, "Log", 4.6, 0.9, CFrame.new(X1 - 2.2, FLOOR + 1.6 + (i % 2) * 0.8, HZ - 3.4 + i * 1.4) * CFrame.Angles(0, math.rad(80 + i * 6), 0), Color3.fromRGB(36, 28, 22), Enum.Material.Wood, false)
end
local hearthFire = part(hearth, "Fire", Vector3.new(3, 1, 8), CFrame.new(X1 - 2.2, FLOOR + 2.4, HZ), Color3.fromRGB(255, 150, 60), Enum.Material.Neon, false)
hearthFire.Transparency = 1
local fire = Instance.new("Fire")
fire.Size = 9
fire.Heat = 6
fire.Color = Color3.fromRGB(255, 150, 60)
fire.SecondaryColor = Color3.fromRGB(200, 60, 20)
fire.Parent = hearthFire
local hearthLight = Instance.new("PointLight")
hearthLight.Color = Color3.fromRGB(255, 170, 90)
hearthLight.Brightness = 1.4
hearthLight.Range = 40
hearthLight.Shadows = false
hearthLight.Parent = hearthFire
game:GetService("CollectionService"):AddTag(hearthLight, "TLK_Lod")

-- banners on the partition and the east wall
local function banner(x: number, z: number, faceX: number)
	local m = folder("Banner")
	m.Parent = hall
	local base = CFrame.new(x, FLOOR + 30, z) * CFrame.Angles(0, if faceX > 0 then math.rad(90) else math.rad(-90), 0)
	part(m, "Rod", Vector3.new(7.4, 0.4, 0.4), base * CFrame.new(0, 7.3, 0), OAK_DARK, Enum.Material.Wood, false)
	part(m, "Cloth", Vector3.new(6, 14, 0.15), base * CFrame.new(0, 0, 0), CLOTH, Enum.Material.Fabric, false)
	for i = 0, 3 do
		part(m, "Bar", Vector3.new(3.4, 0.4, 0.12), base * CFrame.new(0, 1.2, -0.12) * CFrame.Angles(0, 0, math.rad(i * 45)), GOLD, Enum.Material.Fabric, false)
	end
	for i = 1, 5 do
		part(m, "Rag", Vector3.new(6 / 5 - 0.1, 1.6, 0.15), base * CFrame.new(-3 + (i - 0.5) * 6 / 5, -7.6 - (i % 2) * 0.6, 0), CLOTH, Enum.Material.Fabric, false)
	end
end
for _, z in { -2204, -2188, -2172 } do
	banner(PX1 + 0.1, z, 1)
	banner(X1 - 0.2, z, -1)
end

-- THE SCRIBE'S DESK, at the back: a slanted writing desk, a chair, candles, inks and rolls, shelves behind
local desk = folder("Desk")
local DZ = -2207.8
block(desk, "Top", -4, 4, FLOOR + 3.6, FLOOR + 4.2, DZ - 1.4, DZ + 1.4, OAK, Enum.Material.WoodPlanks)
for _, x in { -3.4, 3.4 } do
	for _, z in { DZ - 1.1, DZ + 1.1 } do
		block(desk, "Leg", x - 0.3, x + 0.3, FLOOR, FLOOR + 3.6, z - 0.3, z + 0.3, OAK_DARK, Enum.Material.Wood)
	end
end
-- the slope of the writing board and the book open on it
part(desk, "Board", Vector3.new(5.4, 0.25, 2.6), CFrame.new(-1, FLOOR + 4.6, DZ + 0.2) * CFrame.Angles(math.rad(-14), 0, 0), OAK_PALE, Enum.Material.Wood, false)
part(desk, "Book", Vector3.new(3.6, 0.3, 2.2), CFrame.new(-1, FLOOR + 4.85, DZ + 0.2) * CFrame.Angles(math.rad(-14), 0, 0), LINEN, Enum.Material.Fabric, false)
part(desk, "BookSpine", Vector3.new(0.3, 0.4, 2.3), CFrame.new(-1, FLOOR + 4.9, DZ + 0.2) * CFrame.Angles(math.rad(-14), 0, 0), Color3.fromRGB(70, 36, 30), Enum.Material.Fabric, false)
for i = 0, 3 do
	part(desk, "Roll", Vector3.new(0.5, 0.5, 3.2), CFrame.new(2.2 + i * 0.1, FLOOR + 4.7 + i * 0.5, DZ - 0.2) * CFrame.Angles(0, math.rad(8 * i), 0), LINEN, Enum.Material.Fabric, false).Shape = Enum.PartType.Cylinder
end
cyl(desk, "InkPot", 0.8, 0.6, CFrame.new(2.6, FLOOR + 4.6, DZ + 0.9) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(26, 22, 30), Enum.Material.Glass, false)
cyl(desk, "Candle", 1.5, 0.45, CFrame.new(-3.2, FLOOR + 4.95, DZ - 0.8) * CFrame.Angles(0, 0, math.rad(90)), WAX, Enum.Material.SmoothPlastic, false)
local dflame = part(desk, "CandleFlame", Vector3.new(0.3, 0.5, 0.3), CFrame.new(-3.2, FLOOR + 5.9, DZ - 0.8), Color3.fromRGB(255, 190, 90), Enum.Material.Neon, false)
local dfire = Instance.new("Fire")
dfire.Size = 2
dfire.Heat = 2
dfire.Parent = dflame
local dlight = Instance.new("PointLight")
dlight.Color = Color3.fromRGB(255, 190, 120)
dlight.Brightness = 1.2
dlight.Range = 22
dlight.Shadows = false
dlight.Parent = dflame
-- the scribe's stool, pushed in, and where he stands
cyl(desk, "Stool", 1.8, 2.2, CFrame.new(0, FLOOR + 1.0, DZ + 3.2) * CFrame.Angles(0, 0, math.rad(90)), OAK, Enum.Material.Wood, false)
local at = part(desk, "ScribeAt", Vector3.new(1, 1, 1), CFrame.new(0, FLOOR + 1, DZ + 2.2), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
at.Transparency = 1
at.CanQuery = false
-- shelves of rolls along the back wall behind him
for _, x in { -12, -6, 6, 12 } do
	block(desk, "ShelfUpright", x - 2.6, x - 2.3, FLOOR, FLOOR + 12, Z0 + 0.1, Z0 + 1.5, OAK_DARK, Enum.Material.Wood, false)
	block(desk, "ShelfUpright", x + 2.3, x + 2.6, FLOOR, FLOOR + 12, Z0 + 0.1, Z0 + 1.5, OAK_DARK, Enum.Material.Wood, false)
	for row = 1, 4 do
		block(desk, "Shelf", x - 2.6, x + 2.6, FLOOR + row * 2.8 - 0.2, FLOOR + row * 2.8, Z0 + 0.1, Z0 + 1.5, OAK, Enum.Material.Wood, false)
		for k = 0, 5 do
			cyl(desk, "ScrollRoll", 1.3, 0.6, CFrame.new(x - 2.1 + k * 0.84, FLOOR + row * 2.8 + 0.5, Z0 + 0.8) * CFrame.Angles(0, math.rad(90), math.rad(90)), if (k + row) % 3 == 0 then Color3.fromRGB(110, 96, 70) else LINEN, Enum.Material.Fabric, false)
		end
	end
end

--==========================================================================
if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("[BuildKeepInterior] built")
