--[[
	BuildForest — run in the Studio of the FORGOTTEN LANDS place, in EDIT MODE. Builds area 6, the King's Wood
	(docs/systems/Forest.md, numbers in configs/Forest.luau).

	It needs the tree grower: the runner loads `tools/ForestTrees.luau` first and hands it over as `shared.TLK_ForestTrees`.
	It needs the generated materials in MaterialService (OakBark, BeechBark, ForestMoss, Foliage, SpruceNeedles for the
	trees; ForestFloor on Salt, MossFloor on Pebble, ForestPath on Asphalt for the ground: those three base materials are
	used nowhere else in the place, so overriding them for the terrain changes nothing outside the wood).

	SECTIONS (set ONLY to one of them; run them in this order the first time):
	  retire   the Great Hall's yard: every model in Decorations.Area6 is MOVED to ServerStorage.Assets.Retired.Area6
	  ground   the terrain: forest floor, moss, rises and dips, the Hollow (the moat's water taken out between two dams)
	  breach   the west wall broken open (the wall's pieces are split, the gap filled with rubble); a copy of every piece it
	           changes is kept in ServerStorage.Assets.Retired.Area6Wall
	  paths    the worn paths (painted into the ground; the trees keep off them)
	  trees    the trees (grown from seeds: running it again grows the same wood)
	  under    what lies under them: fallen logs, stumps, stones, ferns, brambles, mushrooms
	  places   the gamekeepers' board, the orchard, the charcoal burners' camp, the Hollow's cart and fallen tree, the stag
	           stones, the Huntsman's lodge, the woodcutter's hut, the four watch-fires, the marks the trial reads, and the
	           invisible walls round the outer wood
	  zones    the light zones (the dark)
	  clear    takes away everything this tool made (not the terrain, not the wall)

	Everything it makes lives in Workspace.Gameplay.Battleground.Decorations.Area6.Forest.<Section>. A section that is run
	again first removes what it made before. NOTE: a tool, not game code; the result lives in the place (save it).
]]

local ONLY = "retire"

local MaterialService = game:GetService("MaterialService")
local ServerStorage = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")

local cfg = require(game.ReplicatedStorage.Config.Forest:Clone())
local zonesCfg = require(game.ReplicatedStorage.Config.LightZones:Clone())
local Trees = shared.TLK_ForestTrees

local Terrain = workspace.Terrain
local battleground = workspace.Gameplay.Battleground
local decorations = battleground.Decorations
local area6 = decorations:FindFirstChild("Area6") or Instance.new("Folder")
area6.Name = "Area6"
area6.Parent = decorations

local root = area6:FindFirstChild("Forest") or Instance.new("Folder")
root.Name = "Forest"
root.Parent = area6

local report: { string } = {}
local function say(text: string)
	table.insert(report, text)
end

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

local function marks(): Folder
	local f = root:FindFirstChild("Marks")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Marks"
		f.Parent = root
	end
	return f :: Folder
end

--==========================================================================
-- Helpers
--==========================================================================
local function variant(base: string, rng: Random?): string
	local list = {}
	for _, v in MaterialService:GetDescendants() do
		if v:IsA("MaterialVariant") and (v.Name == base or string.match(v.Name, "^" .. base .. "%d+$")) then
			table.insert(list, v.Name)
		end
	end
	table.sort(list)
	if #list == 0 then
		return ""
	end
	return list[if rng then rng:NextInteger(1, #list) else 1]
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, opts: { [string]: any }?): Part
	local o = opts or {}
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = true
	p.CanCollide = if o.collide == nil then false else o.collide
	p.CanQuery = if o.query == nil then p.CanCollide else o.query
	p.CanTouch = false
	p.CastShadow = if o.shadow == nil then true else o.shadow
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	if o.variant then
		p.MaterialVariant = o.variant
	end
	if o.shape then
		p.Shape = o.shape
	end
	if o.transparency then
		p.Transparency = o.transparency
	end
	p.Parent = parent
	return p
end

local function cyl(parent: Instance, name: string, a: Vector3, b: Vector3, r: number, color: Color3, material: Enum.Material, opts: { [string]: any }?): Part
	local len = (b - a).Magnitude
	local o = table.clone(opts or {})
	o.shape = Enum.PartType.Cylinder
	return part(parent, name, Vector3.new(len, r * 2, r * 2), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), color, material, o)
end

local function blob(parent: Instance, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, opts: { [string]: any }?): Part
	local p = part(parent, name, size, cf, color, material, opts)
	local m = Instance.new("SpecialMesh")
	m.MeshType = Enum.MeshType.Sphere
	m.Parent = p
	return p
end

-- an unseen named point the trial reads (Marks.<name>), replaced if it is there already
local function mark(name: string, at: Vector3, attrs: { [string]: any }?): Part
	local old = marks():FindFirstChild(name)
	if old then
		old:Destroy()
	end
	local p = part(marks(), name, Vector3.new(1, 1, 1), CFrame.new(at), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { transparency = 1, shadow = false })
	for k, v in attrs or {} do
		p:SetAttribute(k, v)
	end
	return p
end

-- the ground's height at (x, z): the first terrain under a ray from high above (parts are ignored)
local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { Terrain }
local function groundY(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 300, z), Vector3.new(0, -400, 0), groundParams)
	return if hit then hit.Position.Y else 2
end
local function ground(x: number, z: number): Vector3
	return Vector3.new(x, groundY(x, z), z)
end

-- Castle stone over (x, z), or within `r` of it: the walls, the gate towers and the side towers that stand into the yard.
-- A hit lower than the ground (a footing under the terrain) does not count.
local castleParams = RaycastParams.new()
castleParams.FilterType = Enum.RaycastFilterType.Include
do
	local list: { Instance } = { battleground.Shell }
	for _, name in { "Chamber5", "Chamber6", "Chamber7" } do
		local ch = battleground:FindFirstChild(name)
		local s = ch and ch:FindFirstChild("Structure")
		if s then
			table.insert(list, s)
		end
	end
	castleParams.FilterDescendantsInstances = list
end
local function stoneAt(x: number, z: number, r: number): boolean
	for _, o in { { 0, 0 }, { r, 0 }, { -r, 0 }, { 0, r }, { 0, -r } } do
		local hit = workspace:Raycast(Vector3.new(x + o[1], 260, z + o[2]), Vector3.new(0, -300, 0), castleParams)
		if hit and hit.Position.Y > groundY(x + o[1], z + o[2]) + 0.5 then
			return true
		end
	end
	return false
end

local function inBox(x: number, z: number, box: any, margin: number?): boolean
	local m = margin or 0
	return x >= math.min(box.X0, box.X1) - m and x <= math.max(box.X0, box.X1) + m and z >= math.min(box.Z0, box.Z1) - m and z <= math.max(box.Z0, box.Z1) + m
end

-- which part of the wood a point is in: "inner", "hollow", "outer", "breach" or nil
local function regionOf(x: number, z: number): string?
	if inBox(x, z, cfg.Inner) then
		return "inner"
	end
	if inBox(x, z, cfg.Outer) then
		return "outer"
	end
	if inBox(x, z, cfg.Hollow) then
		return "hollow"
	end
	if x < -171 and x > -232 and z <= cfg.Breach.Z0 and z >= cfg.Breach.Z1 then
		return "breach"
	end
	if x < -195 and x > -232 and inBox(x, z, cfg.Hollow, 0) == false and z <= cfg.Hollow.Z0 and z >= cfg.Hollow.Z1 then
		return "bank"
	end
	return nil
end

--==========================================================================
-- THE PATHS: worn ways between the places (a polyline each, studs). The trees keep off them; the ground is painted.
--==========================================================================
local PATHS: { { Vector3 } } = {
	-- the way in, through the inner wood to the orchard
	{ Vector3.new(153, 0, -1246), Vector3.new(128, 0, -1290), Vector3.new(70, 0, -1342), Vector3.new(4, 0, -1330), Vector3.new(-56, 0, -1306), Vector3.new(-96, 0, -1282) },
	-- down to the charcoal burners
	{ Vector3.new(70, 0, -1342), Vector3.new(88, 0, -1400), Vector3.new(96, 0, -1430) },
	-- the orchard to the breach, the Hollow and the fallen tree, and on to the stag stones
	{ Vector3.new(-96, 0, -1282), Vector3.new(-140, 0, -1288), Vector3.new(-176, 0, -1287), Vector3.new(-205, 0, -1287), Vector3.new(-236, 0, -1290), Vector3.new(-300, 0, -1292), Vector3.new(-350, 0, -1300), Vector3.new(-410, 0, -1330), Vector3.new(-452, 0, -1352) },
	-- the stag stones to the lodge
	{ Vector3.new(-452, 0, -1352), Vector3.new(-488, 0, -1388), Vector3.new(-520, 0, -1410) },
	-- the stag stones to the woodcutter
	{ Vector3.new(-452, 0, -1352), Vector3.new(-440, 0, -1300), Vector3.new(-424, 0, -1262) },
	-- the middle of the inner wood to the way out
	{ Vector3.new(4, 0, -1330), Vector3.new(-30, 0, -1392), Vector3.new(-96, 0, -1440), Vector3.new(-153, 0, -1462) },
	-- the camp across to the way out
	{ Vector3.new(96, 0, -1430), Vector3.new(30, 0, -1446), Vector3.new(-30, 0, -1392) },
	-- along the bottom of the Hollow, the cart to the fire
	{ Vector3.new(-266, 0, -1246), Vector3.new(-262, 0, -1340), Vector3.new(-266, 0, -1436) },
}
local PATH_HALF = 3.2 -- half the width of a worn path

local function distToSegment(p: Vector3, a: Vector3, b: Vector3): number
	local ab = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local ap = Vector3.new(p.X - a.X, 0, p.Z - a.Z)
	local t = math.clamp(ap:Dot(ab) / math.max(ab:Dot(ab), 1e-6), 0, 1)
	return (ap - ab * t).Magnitude
end
local function nearPath(x: number, z: number): number
	local p = Vector3.new(x, 0, z)
	local best = math.huge
	for _, path in PATHS do
		for i = 1, #path - 1 do
			best = math.min(best, distToSegment(p, path[i], path[i + 1]))
		end
	end
	return best
end

-- places that trees keep clear of: { x, z, radius }
local CLEARINGS: { { number } } = {}
local function clearing(at: Vector3, r: number)
	table.insert(CLEARINGS, { at.X, at.Z, r })
end
for _, f in cfg.Fires do
	clearing(f.at, if f.id == "stones" then 20 else 13)
end
clearing(Vector3.new(96, 0, -1442), 24) -- the charcoal burners' clearing
clearing(Vector3.new(-528, 0, -1428), 24) -- the lodge
clearing(Vector3.new(-424, 0, -1254), 15) -- the woodcutter's hut
clearing(Vector3.new(-262, 0, -1250), 9) -- the sunk cart
clearing(cfg.WayIn, 14)
clearing(cfg.WayOut, 14)
clearing(Vector3.new(-96, 0, -1268), 34) -- the orchard (its own trees are planted in rows)

local function inClearing(x: number, z: number, extra: number): boolean
	for _, c in CLEARINGS do
		local dx, dz = x - c[1], z - c[2]
		if dx * dx + dz * dz < (c[3] + extra) ^ 2 then
			return true
		end
	end
	return false
end

--==========================================================================
-- RETIRE: the Great Hall's yard goes to storage (moved, not deleted)
--==========================================================================
local function retire()
	local assets = ServerStorage:FindFirstChild("Assets") :: Folder
	local retired = assets:FindFirstChild("Retired") or Instance.new("Folder")
	retired.Name = "Retired"
	retired.Parent = assets
	local store = retired:FindFirstChild("Area6") or Instance.new("Folder")
	store.Name = "Area6"
	store.Parent = retired
	local n = 0
	for _, child in area6:GetChildren() do
		if child ~= root then
			child.Parent = store
			n += 1
		end
	end
	say(("retired %d models of the Great Hall's yard to ServerStorage.Assets.Retired.Area6"):format(n))
end

--==========================================================================
-- GROUND
--==========================================================================
local FLOOR = Enum.Material.Salt -- ForestFloor
local MOSS = Enum.Material.Pebble -- MossFloor
local PATH = Enum.Material.Asphalt -- ForestPath

local function overrides()
	local pairsList = { { FLOOR, "ForestFloor" }, { MOSS, "MossFloor" }, { PATH, "ForestPath" } }
	for _, pr in pairsList do
		local name = variant(pr[2])
		if name ~= "" then
			MaterialService:SetBaseMaterialOverride(pr[1], name)
			for _, v in MaterialService:GetDescendants() do
				if v:IsA("MaterialVariant") and v.Name == name then
					v.StudsPerTile = if pr[2] == "ForestPath" then 9 else 11
				end
			end
		else
			say("MISSING MaterialVariant " .. pr[2])
		end
	end
end

local function region(x0: number, y0: number, z0: number, x1: number, y1: number, z1: number): Region3
	local a = Vector3.new(math.min(x0, x1), math.min(y0, y1), math.min(z0, z1))
	local b = Vector3.new(math.max(x0, x1), math.max(y0, y1), math.max(z0, z1))
	return Region3.new(a, b):ExpandToGrid(4)
end

local SURFACES = { Enum.Material.Grass, Enum.Material.Mud, Enum.Material.Ground, Enum.Material.Cobblestone, Enum.Material.LeafyGrass, Enum.Material.Sand, Enum.Material.Rock }

local function paintBox(box: any, y0: number, y1: number, to: Enum.Material)
	local r = region(box.X0, y0, box.Z0, box.X1, y1, box.Z1)
	for _, from in SURFACES do
		Terrain:ReplaceMaterial(r, 4, from, to)
	end
end

local function buildGround()
	overrides()
	local rng = Random.new(61)

	-- the inner wood's floor, and the outer wood's
	paintBox(cfg.Inner, -6, 10, FLOOR)
	paintBox(cfg.Outer, -20, 40, FLOOR)

	-- the Hollow: the moat's water out, a muddy floor in, and two dams that hold the rest of the moat back
	local H = cfg.Hollow
	local hx0, hx1 = math.min(H.X0, H.X1), math.max(H.X0, H.X1)
	Terrain:ReplaceMaterial(region(hx0 - 10, -40, H.Z0, hx1 + 10, 4, H.Z1), 4, Enum.Material.Water, Enum.Material.Air)
	Terrain:FillBlock(CFrame.new((H.X0 + H.X1) / 2, (-40 + H.Floor - 2) / 2, (H.Z0 + H.Z1) / 2), Vector3.new(math.abs(H.X1 - H.X0) + 8, H.Floor - 2 + 40, math.abs(H.Z1 - H.Z0)), PATH)
	Terrain:FillBlock(CFrame.new((H.X0 + H.X1) / 2, H.Floor - 1, (H.Z0 + H.Z1) / 2), Vector3.new(math.abs(H.X1 - H.X0) + 8, 2, math.abs(H.Z1 - H.Z0)), MOSS)
	-- the banks: a slope from the wall's foot down, and from the Hollow up to the outer wood
	for i = 0, 6 do
		local t = i / 6
		local yIn = 2 + (H.Floor - 2) * t
		Terrain:FillBlock(CFrame.new(-198 - t * 30, (yIn - 30) / 2, (H.Z0 + H.Z1) / 2), Vector3.new(6, yIn + 30, math.abs(H.Z1 - H.Z0)), FLOOR)
		local yOut = H.Floor + (2 - H.Floor) * t
		Terrain:FillBlock(CFrame.new(H.X1 - 2 - t * 14, (yOut - 30) / 2, (H.Z0 + H.Z1) / 2), Vector3.new(4, yOut + 30, math.abs(H.Z1 - H.Z0)), FLOOR)
	end
	for _, z in cfg.Dams do
		Terrain:FillBlock(CFrame.new((H.X0 + H.X1) / 2, -16, z), Vector3.new(math.abs(H.X1 - H.X0) + 16, 40, 12), Enum.Material.Ground)
		Terrain:FillBlock(CFrame.new((H.X0 + H.X1) / 2, 4.5, z), Vector3.new(math.abs(H.X1 - H.X0) + 16, 3, 8), FLOOR)
	end
	-- puddles in the Hollow's floor: shallow, a body walks through them
	for _ = 1, 9 do
		local x = rng:NextNumber(hx0 + 8, hx1 - 8)
		local z = rng:NextNumber(H.Z1 + 20, H.Z0 - 20)
		if nearPath(x, z) > 6 then
			Terrain:FillBlock(CFrame.new(x, H.Floor - 1, z), Vector3.new(rng:NextNumber(6, 12), 2, rng:NextNumber(6, 14)), Enum.Material.Air)
			Terrain:FillBlock(CFrame.new(x, H.Floor - 1.5, z), Vector3.new(rng:NextNumber(6, 12), 1.2, rng:NextNumber(6, 14)), Enum.Material.Water)
		end
	end

	-- rises and dips, never on a path or a place: the inner wood gently, the outer wood more
	local function hump(box: any, count: number, rMin: number, rMax: number, lift: number)
		for _ = 1, count do
			local x = rng:NextNumber(math.min(box.X0, box.X1) + 8, math.max(box.X0, box.X1) - 8)
			local z = rng:NextNumber(math.min(box.Z0, box.Z1) + 8, math.max(box.Z0, box.Z1) - 8)
			local r = rng:NextNumber(rMin, rMax)
			if nearPath(x, z) > r * 0.8 + 4 and not inClearing(x, z, r * 0.6) then
				local y = groundY(x, z)
				Terrain:FillBall(Vector3.new(x, y - r + rng:NextNumber(1.5, lift), z), r, if rng:NextNumber() < 0.35 then MOSS else FLOOR)
			end
		end
	end
	hump(cfg.Inner, 46, 6, 14, 4)
	hump(cfg.Outer, 40, 9, 22, 7)

	-- moss in patches (painted into the ground, no height)
	local function mossPatches(box: any, count: number)
		for _ = 1, count do
			local x = rng:NextNumber(math.min(box.X0, box.X1), math.max(box.X0, box.X1))
			local z = rng:NextNumber(math.min(box.Z0, box.Z1), math.max(box.Z0, box.Z1))
			if nearPath(x, z) > 5 then
				local r = rng:NextNumber(5, 11)
				local y = groundY(x, z)
				Terrain:FillBall(Vector3.new(x, y - r + 0.6, z), r, MOSS)
			end
		end
	end
	mossPatches(cfg.Inner, 40)
	mossPatches(cfg.Outer, 40)
	say("ground: forest floor, moss, rises, the Hollow and its dams")
end

--==========================================================================
-- PATHS: painted worn earth (no height change; a slight dip would need whole cells)
--==========================================================================
local function buildPaths()
	for _, path in PATHS do
		for i = 1, #path - 1 do
			local a, b = path[i], path[i + 1]
			local len = Vector3.new(b.X - a.X, 0, b.Z - a.Z).Magnitude
			local steps = math.max(1, math.ceil(len / 3))
			for s = 0, steps do
				local t = s / steps
				local x, z = a.X + (b.X - a.X) * t, a.Z + (b.Z - a.Z) * t
				local y = groundY(x, z)
				Terrain:FillBall(Vector3.new(x, y - PATH_HALF + 0.1, z), PATH_HALF, PATH)
			end
		end
	end
	say(("paths: %d worn ways painted"):format(#PATHS))
end

--==========================================================================
-- THE BREACH: the west wall broken open between two buttresses
--==========================================================================
local function buildBreach()
	local B = cfg.Breach
	local zTop, zBot = math.max(B.Z0, B.Z1), math.min(B.Z0, B.Z1)
	local wall = battleground.Shell:FindFirstChild("WestWall")
	local assets = ServerStorage.Assets
	local retired = assets:FindFirstChild("Retired") or Instance.new("Folder")
	retired.Name = "Retired"
	retired.Parent = assets
	local keep = retired:FindFirstChild("Area6Wall")
	local firstTime = keep == nil
	if not keep then
		keep = Instance.new("Folder")
		keep.Name = "Area6Wall"
		keep.Parent = retired
	end
	local split, removed = 0, 0
	if wall and firstTime then
		for _, d in wall:GetDescendants() do
			if d:IsA("BasePart") then
				local cf, size = d.CFrame, d.Size
				local ext = (cf.RightVector * size.X):Abs() + (cf.UpVector * size.Y):Abs() + (cf.LookVector * size.Z):Abs()
				local z0, z1 = d.Position.Z - ext.Z / 2, d.Position.Z + ext.Z / 2
				if z1 > zBot and z0 < zTop and d.Position.X < -170 then
					local copy = d:Clone()
					copy:SetAttribute("Was", d:GetFullName())
					copy.Parent = keep
					-- a long piece along the wall (its length on Z): cut in two round the gap; anything inside it goes
					if ext.Z > (zTop - zBot) + 10 and math.abs(cf.LookVector.Z) > 0.9 or (ext.Z > (zTop - zBot) + 10 and math.abs(cf.RightVector.Z) > 0.9) then
						local alongZ = if math.abs(cf.LookVector.Z) > 0.9 then "Z" else "X"
						local north = d:Clone()
						local south = d
						local nLen, sLen = z1 - zTop, zBot - z0
						local function resize(p: BasePart, len: number, centreZ: number)
							local s = p.Size
							p.Size = if alongZ == "Z" then Vector3.new(s.X, s.Y, len) else Vector3.new(len, s.Y, s.Z)
							p.CFrame = (p.CFrame - p.CFrame.Position) + Vector3.new(p.Position.X, p.Position.Y, centreZ)
						end
						if nLen > 0.5 then
							resize(north, nLen, zTop + nLen / 2)
							north.Parent = d.Parent
						else
							north:Destroy()
						end
						if sLen > 0.5 then
							resize(south, sLen, zBot - sLen / 2)
						else
							south:Destroy()
						end
						split += 1
					else
						d:Destroy()
						removed += 1
					end
				end
			end
		end
	end
	say(("breach: %d long pieces split, %d small ones taken out (copies in Retired.Area6Wall)%s"):format(split, removed, if firstTime then "" else " — already broken: only the rubble rebuilt"))

	-- the rubble: a heap of earth and stone in the gap, from the inner floor down to the Hollow, and broken blocks
	local f = section("Breach")
	local rng = Random.new(66)
	local zMid = (zTop + zBot) / 2
	for i = 0, 8 do
		local x = -172 - i * 6
		local y = 2 - math.max(0, (x + 196)) * -0.0 - math.max(0, -196 - x) * 0.22
		Terrain:FillBlock(CFrame.new(x, (y - 30) / 2, zMid), Vector3.new(7, y + 30, zTop - zBot + 10), FLOOR)
	end
	for _ = 1, 14 do
		local at = Vector3.new(rng:NextNumber(-200, -176), 0, rng:NextNumber(zBot - 4, zTop + 4))
		local r = rng:NextNumber(2.5, 5)
		Terrain:FillBall(Vector3.new(at.X, groundY(at.X, at.Z) - r * 0.4, at.Z), r, Enum.Material.Rock)
	end
	-- the wall's own stone, so the broken courses match it
	local stone, stoneMat, stoneVar = Color3.fromRGB(118, 112, 104), Enum.Material.Slate, ""
	local sample = wall and wall:FindFirstChild("Wall")
	if sample and sample:IsA("BasePart") then
		stone, stoneMat, stoneVar = sample.Color, sample.Material, sample.MaterialVariant
	end
	local function block(name: string, size: Vector3, cf: CFrame, collide: boolean)
		local p = part(f, name, size, cf, stone:Lerp(Color3.fromRGB(70, 66, 60), rng:NextNumber(0, 0.35)), stoneMat, { collide = collide, variant = if stoneVar ~= "" then stoneVar else nil })
		return p
	end
	-- the broken ends: the wall fell outward from the top, so its courses stand further into the gap the lower they are,
	-- each course a few stones of different lengths (a jagged edge, never a clean cut)
	for _, zEdge in { zTop, zBot } do
		local into = if zEdge == zTop then -1 else 1 -- toward the middle of the gap
		local y = 0
		while y < 60 do
			local h = rng:NextNumber(2.4, 3.6)
			local reach = math.max(0, (1 - y / 60) ^ 1.6 * 11 + rng:NextNumber(-1.5, 1.5))
			local x = -195
			while x < -181 do
				local w = math.min(rng:NextNumber(3, 6), -181 - x)
				local out = math.max(0.6, reach + rng:NextNumber(-2.2, 1.2))
				block("BrokenCourse", Vector3.new(w - 0.1, h - 0.08, out), CFrame.new(x + w / 2, y + h / 2, zEdge + into * out / 2) * CFrame.Angles(rng:NextNumber(-0.03, 0.03), rng:NextNumber(-0.04, 0.04), rng:NextNumber(-0.03, 0.03)), true)
				x += w
			end
			y += h
		end
	end
	-- the fallen stone: a heap in the gap and spilled down the bank outside, stones of the wall's size and smaller
	for i = 1, 70 do
		local x = rng:NextNumber(-214, -174)
		local z = rng:NextNumber(zBot + 2, zTop - 2)
		local big = rng:NextNumber() < 0.3
		local s = if big then Vector3.new(rng:NextNumber(3, 6), rng:NextNumber(2.2, 3.4), rng:NextNumber(2.5, 4)) else Vector3.new(rng:NextNumber(1, 2.6), rng:NextNumber(0.7, 1.6), rng:NextNumber(1, 2.4))
		-- off the walking line through the middle, the big ones
		if not (big and math.abs(z - (zTop + zBot) / 2) < 5) then
			block("Rubble", s, CFrame.new(x, groundY(x, z) + s.Y * 0.25, z) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), rng:NextNumber(0, 6.28), rng:NextNumber(-0.5, 0.5)), big)
		end
	end
	say("breach: broken courses, fallen stone")
end

--==========================================================================
-- TREES
--==========================================================================
-- how far apart trees of each kind keep (studs, trunk to trunk is about twice this)
local SPACING = { oak = 9, beech = 7, spruce = 6, dead = 5, orchard = 2, hollow = 9 }

--[[
	The trees are planted in three runs (they are many, and one run would take too long for one call): `inner` (the
	inner wood, its two hollow giants and the orchard), `outer` (the outer wood and its two), `banks` (the Hollow's banks
	and floor, and one). A run takes away only its own trees first and keeps clear of the others.
]]
local function plantTrees(which: string)
	assert(Trees, "the runner must load tools/ForestTrees.luau into shared.TLK_ForestTrees first")
	Trees.loadMaterials()
	local f = root:FindFirstChild("Trees")
	if not f then
		f = Instance.new("Folder")
		f.Name = "Trees"
		f.Parent = root
	end
	local placed: { { number } } = {} -- x, z, radius kept clear
	for _, m in f:GetChildren() do
		if m:GetAttribute("Set") == which then
			m:Destroy()
		elseif m:IsA("Model") then
			local p = m:GetPivot().Position
			table.insert(placed, { p.X, p.Z, SPACING[m:GetAttribute("Kind") or "oak"] or 6 })
		end
	end
	local rng = Random.new(616 + #which * 7)
	local function free(x: number, z: number, r: number): boolean
		for _, p in placed do
			local dx, dz = x - p[1], z - p[2]
			if dx * dx + dz * dz < (r + p[3]) ^ 2 then
				return false
			end
		end
		return true
	end

	local counts: { [string]: number } = {}
	local parts = 0
	local function plant(kind: string, x: number, z: number, scale: number?, seed: number?)
		local base = ground(x, z) - Vector3.new(0, 0.6, 0)
		local model = Trees.grow(kind, base, seed or rng:NextInteger(1, 1e6), scale)
		model:SetAttribute("Set", which)
		model.Parent = f
		counts[kind] = (counts[kind] or 0) + 1
		parts += #model:GetChildren()
		table.insert(placed, { x, z, SPACING[kind] })
		return model
	end

	-- the hollow giants (hiding places): near a path in each part of the wood
	local hides = {
		inner = { Vector3.new(36, 0, -1300), Vector3.new(-40, 0, -1440) },
		outer = { Vector3.new(-392, 0, -1340), Vector3.new(-500, 0, -1272) },
		banks = { Vector3.new(-216, 0, -1420) },
	}
	for i, at in hides[which] or {} do
		local m = plant("hollow", at.X, at.Z, 1, 900 + i + #which)
		m.Name = "HollowTree"
		mark("Hide_" .. which .. i, ground(at.X, at.Z) + Vector3.new(0, 1, 0))
	end

	-- the orchard: the lord's fruit trees in rows, dead and bent
	if which == "inner" then
		local oc = Vector3.new(-96, 0, -1268)
		for row = -2, 2 do
			for col = -3, 3 do
				local x = oc.X + col * 8.5 + rng:NextNumber(-1.2, 1.2)
				local z = oc.Z + row * 9 + rng:NextNumber(-1.2, 1.2)
				local dx, dz = x - oc.X, z - oc.Z
				if dx * dx + dz * dz > 11 ^ 2 and rng:NextNumber() < 0.82 and nearPath(x, z) > 4.5 and not stoneAt(x, z, 1) then
					plant("orchard", x, z, rng:NextNumber(0.9, 1.2))
				end
			end
		end
	end

	-- the wood itself: darts thrown at the ground, kept apart, off the paths, the places and the castle's stone
	local function sow(box: any, tries: number, pick: () -> string)
		for _ = 1, tries do
			local x = rng:NextNumber(math.min(box.X0, box.X1) + 3, math.max(box.X0, box.X1) - 3)
			local z = rng:NextNumber(math.min(box.Z0, box.Z1) + 3, math.max(box.Z0, box.Z1) - 3)
			local kind = pick()
			local r = SPACING[kind]
			if nearPath(x, z) > PATH_HALF + 3 and not inClearing(x, z, 2) and free(x, z, r) and not stoneAt(x, z, 3) then
				plant(kind, x, z, rng:NextNumber(0.85, 1.15))
			end
		end
	end
	if which == "inner" then
		sow(cfg.Inner, 900, function(): string
			local n = rng:NextNumber()
			return if n < 0.34 then "oak" elseif n < 0.62 then "beech" elseif n < 0.82 then "spruce" else "dead"
		end)
	elseif which == "outer" then
		sow(cfg.Outer, 900, function(): string
			local n = rng:NextNumber()
			return if n < 0.42 then "spruce" elseif n < 0.64 then "oak" elseif n < 0.82 then "beech" else "dead"
		end)
	elseif which == "banks" then
		-- the Hollow's banks and floor: dead trees and spruce that lean over it
		sow({ X0 = -200, X1 = -318, Z0 = cfg.Hollow.Z0, Z1 = cfg.Hollow.Z1 }, 260, function(): string
			return if rng:NextNumber() < 0.55 then "dead" else "spruce"
		end)
	end

	local list = {}
	for k, v in counts do
		table.insert(list, k .. " " .. v)
	end
	table.sort(list)
	say(("trees (%s): %s (%d parts)"):format(which, table.concat(list, ", "), parts))
end

--==========================================================================
-- UNDER THE TREES
--==========================================================================
local function buildUnder()
	local f = section("Under")
	local rng = Random.new(6161)
	local barkColor = Color3.fromRGB(176, 166, 152)
	local mossColor = Color3.fromRGB(150, 160, 140)
	local leaf = Color3.fromRGB(104, 124, 88)
	local n = { logs = 0, stumps = 0, stones = 0, ferns = 0, brambles = 0, mushrooms = 0 }

	local function spot(): (number, number, string?)
		local boxPick = rng:NextNumber()
		local box = if boxPick < 0.5 then cfg.Inner elseif boxPick < 0.9 then cfg.Outer else { X0 = -205, X1 = -318, Z0 = cfg.Hollow.Z0, Z1 = cfg.Hollow.Z1 }
		local x = rng:NextNumber(math.min(box.X0, box.X1) + 2, math.max(box.X0, box.X1) - 2)
		local z = rng:NextNumber(math.min(box.Z0, box.Z1) + 2, math.max(box.Z0, box.Z1) - 2)
		return x, z, regionOf(x, z)
	end

	-- fallen logs: a trunk lying in pieces, mossy on top, a broken end and a stub of branch
	local function mushrooms(at: Vector3, count: number)
		for _ = 1, count do
			local p = at + Vector3.new(rng:NextNumber(-1.2, 1.2), 0, rng:NextNumber(-1.2, 1.2))
			local h = rng:NextNumber(0.25, 0.6)
			cyl(f, "MushroomStem", p, p + Vector3.new(0, h, 0), 0.07, Color3.fromRGB(214, 204, 182), Enum.Material.SmoothPlastic, { shadow = false })
			blob(f, "MushroomCap", Vector3.new(0.45, 0.16, 0.45) * rng:NextNumber(0.8, 1.6), CFrame.new(p + Vector3.new(0, h, 0)), Color3.fromRGB(196, 170, 132), Enum.Material.SmoothPlastic, { shadow = false })
			n.mushrooms += 1
		end
	end
	for _ = 1, 70 do
		local x, z, reg = spot()
		if reg and reg ~= "breach" and nearPath(x, z) > 5 and not inClearing(x, z, 3) then
			local yaw = rng:NextNumber(0, math.pi * 2)
			local dir = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
			local len = rng:NextNumber(10, 24)
			local r = rng:NextNumber(0.9, 1.8)
			local a = ground(x, z) + Vector3.new(0, r * 0.55, 0)
			local b = a + dir * len + Vector3.new(0, rng:NextNumber(-0.6, 0.6), 0)
			local mid = (a + b) / 2 + Vector3.new(rng:NextNumber(-0.6, 0.6), 0, rng:NextNumber(-0.6, 0.6))
			local bark = variant("OakBark", rng)
			cyl(f, "Log", a, mid, r, barkColor, Enum.Material.Wood, { variant = bark, collide = true })
			cyl(f, "Log", mid, b, r * 0.85, barkColor, Enum.Material.Wood, { variant = bark, collide = true })
			-- the moss on its back
			cyl(f, "LogMoss", a + Vector3.new(0, r * 0.35, 0), mid + Vector3.new(0, r * 0.3, 0), r * 0.72, mossColor, Enum.Material.Grass, { variant = variant("ForestMoss", rng), shadow = false })
			-- a stub of branch
			local side = dir:Cross(Vector3.new(0, 1, 0)) * (if rng:NextNumber() < 0.5 then 1 else -1)
			cyl(f, "LogBranch", mid, mid + (side + Vector3.new(0, 0.6, 0)).Unit * rng:NextNumber(2, 4), r * 0.3, barkColor, Enum.Material.Wood, { variant = bark })
			if rng:NextNumber() < 0.5 then
				mushrooms(a + side * (r + 0.3) - Vector3.new(0, r * 0.55, 0), rng:NextInteger(3, 6))
			end
			n.logs += 1
		end
	end

	-- stumps: a cut or broken trunk with its roots
	for _ = 1, 45 do
		local x, z, reg = spot()
		if reg and reg ~= "breach" and nearPath(x, z) > 4 and not inClearing(x, z, 2) then
			local base = ground(x, z) - Vector3.new(0, 0.4, 0)
			local r = rng:NextNumber(1, 2)
			local h = rng:NextNumber(1.2, 3.5)
			local bark = variant("OakBark", rng)
			cyl(f, "Stump", base, base + Vector3.new(rng:NextNumber(-0.2, 0.2), h, rng:NextNumber(-0.2, 0.2)), r, barkColor, Enum.Material.Wood, { variant = bark, collide = true })
			-- the cut face, pale and rotten
			cyl(f, "StumpTop", base + Vector3.new(0, h - 0.05, 0), base + Vector3.new(0, h + 0.08, 0), r * 0.92, Color3.fromRGB(150, 126, 96), Enum.Material.Wood)
			for k = 1, rng:NextInteger(3, 5) do
				local a = (k / 5) * math.pi * 2 + rng:NextNumber(-0.3, 0.3)
				local out = Vector3.new(math.cos(a), 0, math.sin(a))
				cyl(f, "StumpRoot", base + Vector3.new(0, 0.5, 0) + out * r * 0.6, base + out * (r + rng:NextNumber(1.2, 2.5)) - Vector3.new(0, 0.5, 0), r * 0.32, barkColor, Enum.Material.Wood, { variant = bark, shadow = false })
			end
			if rng:NextNumber() < 0.4 then
				mushrooms(base + Vector3.new(r + 0.4, 0.4, 0), rng:NextInteger(2, 5))
			end
			n.stumps += 1
		end
	end

	-- stones: grey rock half in the ground, moss on the north side
	for _ = 1, 60 do
		local x, z, reg = spot()
		if reg and nearPath(x, z) > 4 and not inClearing(x, z, 1) then
			local r = rng:NextNumber(1.5, 4.5)
			local y = groundY(x, z)
			Terrain:FillBall(Vector3.new(x, y - r * 0.35, z), r, Enum.Material.Rock)
			Terrain:FillBall(Vector3.new(x + rng:NextNumber(-0.5, 0.5), y - r * 0.35 + r * 0.45, z + r * 0.35), r * 0.6, MOSS)
			n.stones += 1
		end
	end

	-- ferns: a clump of fronds arching out from the middle
	for _ = 1, 360 do
		local x, z, reg = spot()
		if reg and reg ~= "breach" and nearPath(x, z) > PATH_HALF + 0.5 and not inClearing(x, z, -4) then
			local base = ground(x, z)
			local fronds = rng:NextInteger(5, 7)
			local size = rng:NextNumber(2.2, 4)
			local turn = rng:NextNumber(0, math.pi * 2)
			local foliage = variant("Foliage", rng)
			for k = 1, fronds do
				local a = turn + (k / fronds) * math.pi * 2 + rng:NextNumber(-0.25, 0.25)
				local rise = math.rad(rng:NextNumber(22, 42))
				local cfF = CFrame.new(base) * CFrame.fromAxisAngle(Vector3.new(0, 1, 0), -a) * CFrame.Angles(0, 0, rise) * CFrame.new(size * 0.45, 0, 0)
				blob(f, "Frond", Vector3.new(size, 0.16, size * 0.3), cfF, Color3.fromRGB(96, 126, 76), Enum.Material.LeafyGrass, { variant = foliage, shadow = false })
			end
			n.ferns += 1
		end
	end

	-- brambles and low bushes: dark tangled masses
	for _ = 1, 150 do
		local x, z, reg = spot()
		if reg and reg ~= "breach" and nearPath(x, z) > PATH_HALF + 1.5 and not inClearing(x, z, 0) then
			local base = ground(x, z)
			local foliage = variant("Foliage", rng)
			for _ = 1, rng:NextInteger(2, 4) do
				local s = rng:NextNumber(2.5, 5.5)
				blob(f, "Bramble", Vector3.new(s, s * rng:NextNumber(0.5, 0.75), s * rng:NextNumber(0.7, 1)), CFrame.new(base + Vector3.new(rng:NextNumber(-2, 2), s * 0.22, rng:NextNumber(-2, 2))) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), leaf:Lerp(Color3.fromRGB(70, 74, 52), 0.5), Enum.Material.LeafyGrass, { variant = foliage, shadow = false })
			end
			n.brambles += 1
		end
	end
	local parts = 0
	for _, d in f:GetChildren() do
		if d:IsA("BasePart") then
			parts += 1
		end
	end
	say(("under: %d logs, %d stumps, %d stones, %d ferns, %d brambles, %d mushrooms (%d parts)"):format(n.logs, n.stumps, n.stones, n.ferns, n.brambles, n.mushrooms, parts))
end

--==========================================================================
-- PLACES
--==========================================================================
local WOOD = Color3.fromRGB(108, 84, 62)
local WOOD_DARK = Color3.fromRGB(70, 54, 42)
local IRON = Color3.fromRGB(52, 48, 46)
local STONE = Color3.fromRGB(126, 120, 112)

-- a small timber building: walls of planks on a sill, a roof of boards at a pitch, a door gap on the given side
local function hut(parent: Instance, name: string, at: Vector3, yaw: number, w: number, d: number, h: number, rng: Random, opts: { [string]: any }?): Model
	local o = opts or {}
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	local cf = CFrame.new(at) * CFrame.Angles(0, math.rad(yaw), 0)
	local planks = variant("OakBark", rng)
	-- floor boards
	part(m, "Floor", Vector3.new(w, 0.4, d), cf * CFrame.new(0, 0.2, 0), WOOD_DARK, Enum.Material.WoodPlanks, { collide = true })
	-- corner posts
	for _, sx in { -1, 1 } do
		for _, sz in { -1, 1 } do
			cyl(m, "Post", (cf * CFrame.new(sx * (w / 2 - 0.4), 0, sz * (d / 2 - 0.4))).Position, (cf * CFrame.new(sx * (w / 2 - 0.4), h, sz * (d / 2 - 0.4))).Position, 0.45, WOOD, Enum.Material.Wood, { variant = planks, collide = true })
		end
	end
	-- walls (the front has a door gap 4 wide)
	local doorH = math.min(7, h - 0.8)
	local function wall(len: number, local_: CFrame, door: boolean)
		if door then
			local side = (len - 4.2) / 2
			part(m, "Wall", Vector3.new(side, h, 0.5), cf * local_ * CFrame.new(-(4.2 / 2 + side / 2), h / 2, 0), WOOD, Enum.Material.WoodPlanks, { collide = true })
			part(m, "Wall", Vector3.new(side, h, 0.5), cf * local_ * CFrame.new(4.2 / 2 + side / 2, h / 2, 0), WOOD, Enum.Material.WoodPlanks, { collide = true })
			part(m, "Lintel", Vector3.new(4.6, 0.5, 0.6), cf * local_ * CFrame.new(0, doorH + 0.25, 0), WOOD_DARK, Enum.Material.Wood, { collide = true })
			if h - doorH - 0.5 > 0.1 then
				part(m, "Wall", Vector3.new(4.2, h - doorH - 0.5, 0.5), cf * local_ * CFrame.new(0, doorH + 0.5 + (h - doorH - 0.5) / 2, 0), WOOD, Enum.Material.WoodPlanks, { collide = true })
			end
		else
			part(m, "Wall", Vector3.new(len, h, 0.5), cf * local_ * CFrame.new(0, h / 2, 0), WOOD, Enum.Material.WoodPlanks, { collide = true })
		end
	end
	wall(w, CFrame.new(0, 0, -d / 2), true) -- front (toward local -z)
	wall(w, CFrame.new(0, 0, d / 2), false)
	wall(d, CFrame.new(-w / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), false)
	wall(d, CFrame.new(w / 2, 0, 0) * CFrame.Angles(0, math.rad(90), 0), false)
	-- the roof: two pitched sides of boards, one sagging, a ridge
	local pitch = math.rad(o.pitch or 32)
	local half = (w / 2 + 1) / math.cos(pitch)
	for _, s in { -1, 1 } do
		local sag = if o.sag and s == 1 then math.rad(o.sag) else 0
		part(m, "Roof", Vector3.new(half, 0.45, d + 2), cf * CFrame.new(s * (w / 4 + 0.25), h + math.tan(pitch) * w / 4 + 0.3, 0) * CFrame.Angles(0, 0, -s * (pitch - sag)), Color3.fromRGB(66, 58, 48), Enum.Material.WoodPlanks, { collide = true })
	end
	cyl(m, "Ridge", (cf * CFrame.new(0, h + math.tan(pitch) * w / 2 + 0.4, -d / 2 - 1)).Position, (cf * CFrame.new(0, h + math.tan(pitch) * w / 2 + 0.4, d / 2 + 1)).Position, 0.35, WOOD_DARK, Enum.Material.Wood, { variant = planks })
	-- the gable ends: boards that shorten as they rise under the roof
	local gh = math.tan(pitch) * w / 2
	local rows = math.max(2, math.floor(gh / 0.8))
	for _, sz in { -1, 1 } do
		for k = 0, rows - 1 do
			local t = (k + 0.5) / rows
			part(m, "Gable", Vector3.new(math.max(0.4, w * (1 - t)), gh / rows + 0.05, 0.45), cf * CFrame.new(0, h + gh * t, sz * (d / 2)), WOOD, Enum.Material.WoodPlanks, { collide = true })
		end
	end
	return m
end

-- an iron fire basket on a stone foot: the watch-fire (cold until the trial lights it)
local function watchFire(parent: Instance, id: string, at: Vector3, rng: Random)
	local m = Instance.new("Model")
	m.Name = "WatchFire_" .. id
	m.Parent = parent
	local base = ground(at.X, at.Z)
	-- the foot: rough stones round a pillar
	cyl(m, "Foot", base - Vector3.new(0, 0.5, 0), base + Vector3.new(0, 3.6, 0), 1.5, STONE, Enum.Material.Slate, { collide = true })
	for k = 1, 6 do
		local a = k / 6 * math.pi * 2
		local s = Vector3.new(rng:NextNumber(1.4, 2.2), rng:NextNumber(0.8, 1.4), rng:NextNumber(1.2, 2))
		part(m, "FootStone", s, CFrame.new(base + Vector3.new(math.cos(a) * 1.9, s.Y * 0.35, math.sin(a) * 1.9)) * CFrame.Angles(0, -a, rng:NextNumber(-0.2, 0.2)), STONE:Lerp(Color3.fromRGB(80, 90, 70), rng:NextNumber(0, 0.4)), Enum.Material.Slate)
	end
	-- the basket: a ring of iron bars flaring out, a bottom and a rim
	local bowl = base + Vector3.new(0, 3.6, 0)
	cyl(m, "Pan", bowl, bowl + Vector3.new(0, 0.3, 0), 1.3, IRON, Enum.Material.CorrodedMetal)
	for k = 1, 10 do
		local a = k / 10 * math.pi * 2
		local low = bowl + Vector3.new(math.cos(a) * 1.2, 0.2, math.sin(a) * 1.2)
		local high = bowl + Vector3.new(math.cos(a) * 2.1, 2.6, math.sin(a) * 2.1)
		cyl(m, "Bar", low, high, 0.09, IRON, Enum.Material.CorrodedMetal)
	end
	for _, y in { 1.4, 2.6 } do
		local rr = 1.2 + (2.1 - 1.2) * (y / 2.6)
		for k = 1, 10 do
			local a0, a1 = k / 10 * math.pi * 2, (k + 1) / 10 * math.pi * 2
			cyl(m, "Ring", bowl + Vector3.new(math.cos(a0) * rr, y, math.sin(a0) * rr), bowl + Vector3.new(math.cos(a1) * rr, y, math.sin(a1) * rr), 0.08, IRON, Enum.Material.CorrodedMetal)
		end
	end
	-- old wet wood in it, black
	for k = 1, 6 do
		local a = rng:NextNumber(0, 6.28)
		local p0 = bowl + Vector3.new(math.cos(a) * 1.3, 0.6, math.sin(a) * 1.3)
		local p1 = bowl + Vector3.new(-math.cos(a) * 0.8, rng:NextNumber(1.2, 2.2), -math.sin(a) * 0.8)
		cyl(m, "Wood", p0, p1, rng:NextNumber(0.18, 0.3), Color3.fromRGB(46, 38, 32), Enum.Material.Wood)
	end
	-- the trial lights it: where the flame goes
	mark("Fire_" .. id, bowl + Vector3.new(0, 1.6, 0), { Fire = id })
end

local function standingStone(parent: Instance, at: Vector3, h: number, yaw: number, lean: number, rng: Random)
	local s = Vector3.new(rng:NextNumber(2.6, 3.8), h, rng:NextNumber(1.4, 2.2))
	local cf = CFrame.new(at + Vector3.new(0, h / 2 - 1.2, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.Angles(math.rad(lean), 0, math.rad(rng:NextNumber(-4, 4)))
	part(parent, "Stone", s, cf, Color3.fromRGB(110, 108, 100), Enum.Material.Slate, { collide = true })
	-- moss up its north face
	part(parent, "StoneMoss", Vector3.new(s.X * 0.9, h * rng:NextNumber(0.3, 0.6), 0.2), cf * CFrame.new(0, -h * 0.25, -s.Z / 2 - 0.05), Color3.fromRGB(150, 160, 140), Enum.Material.Grass, { variant = variant("ForestMoss", rng), shadow = false })
end

local function skull(parent: Instance, cf: CFrame, scale: number): Instance?
	local forest = ServerStorage.Assets:FindFirstChild("Forest")
	local src = forest and forest:FindFirstChild("StagSkull")
	if not src then
		return nil
	end
	local m = src:Clone()
	m.Name = "StagSkull"
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			d.CanCollide = false
			d.CanQuery = false
		end
	end
	if scale ~= 1 then
		m:ScaleTo(scale)
	end
	m:PivotTo(cf)
	m.Parent = parent
	return m
end

local function bones(parent: Instance, cf: CFrame)
	local meshes = ServerStorage.Assets:FindFirstChild("CatacombMeshes")
	if not meshes then
		return
	end
	local i = 0
	for _, src in meshes:GetChildren() do
		if (src.Name:lower():find("skull") or src.Name:lower():find("torso") or src.Name:lower():find("skelet")) and i < 2 then
			local b = src:Clone()
			for _, d in b:GetDescendants() do
				if d:IsA("BasePart") then
					d.Anchored = true
					d.CanCollide = false
					d.CanQuery = false
				end
			end
			if b:IsA("BasePart") then
				b.Anchored = true
				b.CanCollide = false
			end
			b:PivotTo(cf * CFrame.new(i * 1.1, 0, 0))
			b.Parent = parent
			i += 1
		end
	end
end

local function buildPlaces()
	local f = section("Places")
	local rng = Random.new(6666)

	-- the four watch-fires
	for _, fire in cfg.Fires do
		watchFire(f, fire.id, fire.at, rng)
	end

	-- THE WAY IN: the gamekeepers' board, and the gamekeeper who did not get out
	do
		local m = Instance.new("Model")
		m.Name = "GamekeepersBoard"
		m.Parent = f
		local at = ground(112, -1266)
		cyl(m, "Post", at - Vector3.new(0, 1, 0), at + Vector3.new(0, 7.5, 0), 0.4, WOOD, Enum.Material.Wood, { collide = true })
		cyl(m, "Post", at + Vector3.new(5, -1, 0), at + Vector3.new(5, 7.5, 0), 0.4, WOOD, Enum.Material.Wood, { collide = true })
		local board = part(m, "Board", Vector3.new(6, 3.4, 0.35), CFrame.new(at + Vector3.new(2.5, 5, 0)) * CFrame.Angles(0, math.rad(180), math.rad(-2)), WOOD_DARK, Enum.Material.WoodPlanks, { collide = true })
		part(m, "Roof", Vector3.new(7, 0.3, 1.6), CFrame.new(at + Vector3.new(2.5, 7.4, 0)) * CFrame.Angles(math.rad(14), 0, 0), Color3.fromRGB(66, 58, 48), Enum.Material.WoodPlanks)
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.PixelsPerStud = 40
		gui.LightInfluence = 1
		gui.Parent = board
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Font = Enum.Font.Fondamento
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(30, 22, 16)
		text.Text = "KEEP THE KING'S WOOD\nfour fires, and the gate"
		text.Parent = gui
		mark("Board", at + Vector3.new(2.5, 3.2, -1))
		-- the gamekeeper: his bones at the post's foot, his lantern broken beside him
		bones(m, CFrame.new(at + Vector3.new(-1.5, 0.4, 1.4)) * CFrame.Angles(0, math.rad(40), 0))
		part(m, "BrokenLantern", Vector3.new(0.6, 0.8, 0.6), CFrame.new(at + Vector3.new(-2.6, 0.4, 2.2)) * CFrame.Angles(math.rad(80), 0, math.rad(20)), IRON, Enum.Material.CorrodedMetal)
		mark("Page5", at + Vector3.new(-1.2, 0.6, 2.6))
	end

	-- THE ORCHARD: a low ruined wall round the lord's old fruit trees, and a shed
	do
		local m = Instance.new("Model")
		m.Name = "Orchard"
		m.Parent = f
		local c = Vector3.new(-96, 0, -1268)
		local hw, hd = 32, 24
		local sides = {
			{ Vector3.new(c.X - hw, 0, c.Z - hd), Vector3.new(c.X + hw, 0, c.Z - hd) },
			{ Vector3.new(c.X + hw, 0, c.Z - hd), Vector3.new(c.X + hw, 0, c.Z + hd) },
			{ Vector3.new(c.X + hw, 0, c.Z + hd), Vector3.new(c.X - hw, 0, c.Z + hd) },
			{ Vector3.new(c.X - hw, 0, c.Z + hd), Vector3.new(c.X - hw, 0, c.Z - hd) },
		}
		for _, sd in sides do
			local a, b = sd[1], sd[2]
			local len = (b - a).Magnitude
			local steps = math.floor(len / 4)
			for k = 0, steps - 1 do
				local t0 = k / steps
				local p = a + (b - a) * (t0 + 0.5 / steps)
				-- gaps where the paths come in, and where it has fallen
				if nearPath(p.X, p.Z) > 4 and rng:NextNumber() > 0.18 then
					local h = rng:NextNumber(1.2, 3.4)
					local y = groundY(p.X, p.Z)
					part(m, "WallStone", Vector3.new(len / steps + 0.4, h, 1.6), CFrame.lookAt(Vector3.new(p.X, y + h / 2 - 0.3, p.Z), Vector3.new(b.X, y + h / 2 - 0.3, b.Z)) * CFrame.Angles(0, math.rad(90), math.rad(rng:NextNumber(-3, 3))), STONE:Lerp(Color3.fromRGB(90, 100, 80), rng:NextNumber(0, 0.5)), Enum.Material.Cobblestone, { collide = true })
				end
			end
		end
		local shed = hut(m, "Shed", ground(-120, -1250), 160, 7, 6, 6, rng, { sag = 14 })
		shed.Name = "OrchardShed"
		mark("Pitch4", ground(-120, -1250) + Vector3.new(0, 0.8, 0))
	end

	-- THE CHARCOAL BURNERS' CLEARING: earth mounds, a bark hut, a woodpile
	do
		local m = Instance.new("Model")
		m.Name = "CharcoalCamp"
		m.Parent = f
		for _, at in { Vector3.new(112, 0, -1456), Vector3.new(120, 0, -1428), Vector3.new(78, 0, -1462) } do
			local y = groundY(at.X, at.Z)
			Terrain:FillBall(Vector3.new(at.X, y - 3, at.Z), 7, PATH)
			Terrain:FillBall(Vector3.new(at.X, y - 3.4, at.Z), 6, Enum.Material.Ground)
		end
		local h = hut(m, "BurnersHut", ground(82, -1446), 20, 8, 7, 6.5, rng, { pitch = 44 })
		h.Name = "BurnersHut"
		-- the woodpile: split logs stacked between stakes
		local wp = ground(70, -1418)
		for row = 0, 3 do
			for k = 0, 6 - row do
				local x = wp.X - 3 + k * 1 + row * 0.5
				cyl(m, "Billet", Vector3.new(x, wp.Y + 0.45 + row * 0.85, wp.Z - 1.8), Vector3.new(x, wp.Y + 0.45 + row * 0.85, wp.Z + 1.8), 0.42, Color3.fromRGB(150, 120, 90), Enum.Material.Wood, { variant = variant("OakBark", rng), collide = row == 0 })
			end
		end
		mark("Pitch1", ground(82, -1446) + Vector3.new(0, 0.8, 0))
		mark("Pitch2", ground(110, -1452) + Vector3.new(0, 0.8, 0))
		mark("Pitch3", ground(70, -1418) + Vector3.new(0, 0.8, 2.6))
		mark("Page6", ground(86, -1450) + Vector3.new(0, 1.2, 0))
	end

	-- THE HOLLOW: the cart that went into the moat, and the great tree that fell across it
	do
		local m = Instance.new("Model")
		m.Name = "Hollow"
		m.Parent = f
		local c = ground(-262, -1250)
		local cartCf = CFrame.new(c + Vector3.new(0, 0.6, 0)) * CFrame.Angles(math.rad(10), math.rad(25), math.rad(-14))
		part(m, "CartBed", Vector3.new(5, 0.4, 8), cartCf, WOOD_DARK, Enum.Material.WoodPlanks, { collide = true })
		part(m, "CartSide", Vector3.new(0.3, 1.4, 8), cartCf * CFrame.new(-2.4, 0.8, 0), WOOD, Enum.Material.WoodPlanks, { collide = true })
		part(m, "CartSide", Vector3.new(0.3, 1.4, 8), cartCf * CFrame.new(2.4, 0.8, 0), WOOD, Enum.Material.WoodPlanks, { collide = true })
		cyl(m, "Wheel", (cartCf * CFrame.new(2.9, -0.3, 2)).Position, (cartCf * CFrame.new(3.3, -0.3, 2)).Position, 1.8, WOOD_DARK, Enum.Material.Wood)
		cyl(m, "Wheel", (cartCf * CFrame.new(-2.9, -1.1, -2.2)).Position, (cartCf * CFrame.new(-3.3, -1.1, -2.2)).Position, 1.8, WOOD_DARK, Enum.Material.Wood)
		cyl(m, "Shaft", (cartCf * CFrame.new(-0.8, -0.2, -4)).Position, (cartCf * CFrame.new(-1.4, -1, -9)).Position, 0.2, WOOD, Enum.Material.Wood)
		mark("Pitch5", c + Vector3.new(0, 1.2, 0))
		-- the fallen giant: an oak that went down across the moat, its roots torn up on the inner bank; one can walk along it
		local a = ground(-226, -1300) + Vector3.new(0, 1.5, 0)
		local b = ground(-306, -1312) + Vector3.new(0, 1.2, 0)
		local bark = variant("OakBark", rng)
		local mid = (a + b) / 2 + Vector3.new(0, 1.5, 0)
		cyl(m, "FallenTrunk", a, mid, 2.6, Color3.fromRGB(176, 166, 152), Enum.Material.Wood, { variant = bark, collide = true })
		cyl(m, "FallenTrunk", mid, b, 2.2, Color3.fromRGB(176, 166, 152), Enum.Material.Wood, { variant = bark, collide = true })
		cyl(m, "FallenMoss", a + Vector3.new(0, 1, 0), mid + Vector3.new(0, 0.9, 0), 1.9, Color3.fromRGB(150, 160, 140), Enum.Material.Grass, { variant = variant("ForestMoss", rng), shadow = false })
		for k = 1, 9 do
			local ang = k / 9 * math.pi * 2
			local out = Vector3.new(0.5, math.cos(ang), math.sin(ang))
			cyl(m, "TornRoot", a, a + (Vector3.new(0.6, 0, 0) + Vector3.new(0, math.cos(ang), math.sin(ang))).Unit * rng:NextNumber(4, 7), rng:NextNumber(0.4, 0.8), Color3.fromRGB(140, 120, 100), Enum.Material.Wood, { variant = bark, shadow = false })
			local _ = out
		end
		-- reeds by the puddles
		for _ = 1, 40 do
			local x = rng:NextNumber(-298, -236)
			local z = rng:NextNumber(-1470, -1240)
			if nearPath(x, z) > 4 then
				local base = ground(x, z)
				for _ = 1, rng:NextInteger(4, 8) do
					local p = base + Vector3.new(rng:NextNumber(-0.8, 0.8), 0, rng:NextNumber(-0.8, 0.8))
					cyl(m, "Reed", p, p + Vector3.new(rng:NextNumber(-0.5, 0.5), rng:NextNumber(3, 5.5), rng:NextNumber(-0.5, 0.5)), 0.06, Color3.fromRGB(120, 112, 76), Enum.Material.Grass, { shadow = false })
				end
			end
		end
	end

	-- THE STAG STONES: a ring of standing stones round the fourth fire, the hunt's old shrine, a stag's skull on the tallest
	do
		local m = Instance.new("Model")
		m.Name = "StagStones"
		m.Parent = f
		local c = cfg.Fires[4].at
		for k = 1, 8 do
			local a = k / 8 * math.pi * 2 + rng:NextNumber(-0.1, 0.1)
			local at = ground(c.X + math.cos(a) * 13, c.Z + math.sin(a) * 13)
			if k == 6 then
				-- one has fallen
				part(m, "FallenStone", Vector3.new(3.4, 1.8, 9), CFrame.new(at + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, a, math.rad(6)), Color3.fromRGB(110, 108, 100), Enum.Material.Slate, { collide = true })
			else
				standingStone(m, at, if k == 2 then 11 else rng:NextNumber(6, 9), -a + math.pi / 2, rng:NextNumber(-6, 6), rng)
			end
		end
		local a2 = 2 / 8 * math.pi * 2
		local top = ground(c.X + math.cos(a2) * 13, c.Z + math.sin(a2) * 13) + Vector3.new(0, 10.2, 0)
		skull(m, CFrame.lookAt(top, Vector3.new(c.X, top.Y, c.Z)), 1.4)
	end

	-- THE HUNTSMAN'S LODGE: his house under the hills, the antlers over the door, the store at its side
	do
		local m = Instance.new("Model")
		m.Name = "HuntsmansLodge"
		m.Parent = f
		local at = ground(-528, -1428)
		local lodge = hut(m, "Lodge", at, 20, 16, 12, 9, rng, { pitch = 38 })
		local cf = CFrame.new(at) * CFrame.Angles(0, math.rad(20), 0)
		skull(m, cf * CFrame.new(0, 9.4, -6.6) * CFrame.Angles(0, math.rad(180), 0), 1.6)
		-- inside: his table, his bed, a wall of trophies, a cold hearth
		part(m, "Table", Vector3.new(4.5, 0.3, 2.4), cf * CFrame.new(-3.5, 3, 1), WOOD, Enum.Material.WoodPlanks, { collide = true })
		for _, sx in { -1, 1 } do
			for _, sz in { -1, 1 } do
				part(m, "TableLeg", Vector3.new(0.3, 2.9, 0.3), cf * CFrame.new(-3.5 + sx * 1.9, 1.45, 1 + sz * 0.9), WOOD_DARK, Enum.Material.Wood, { collide = false })
			end
		end
		part(m, "Bed", Vector3.new(3.5, 1.4, 6.5), cf * CFrame.new(5, 0.9, 2.2), WOOD_DARK, Enum.Material.Wood, { collide = true })
		part(m, "Furs", Vector3.new(3.2, 0.4, 6), cf * CFrame.new(5, 1.8, 2.2), Color3.fromRGB(84, 66, 50), Enum.Material.Fabric, { variant = variant("RotCloth", rng) })
		for k = -2, 2 do
			skull(m, cf * CFrame.new(k * 2.6, 6.2, 5.6) * CFrame.Angles(0, 0, 0), 0.7)
		end
		part(m, "Hearth", Vector3.new(4, 2.4, 2), cf * CFrame.new(-6.4, 1.2, 4.5), STONE, Enum.Material.Cobblestone, { collide = true })
		mark("Page1", (cf * CFrame.new(-3.5, 3.4, 1)).Position)
		mark("Page2", (cf * CFrame.new(5, 2.2, 0.5)).Position)
		mark("Page3", (cf * CFrame.new(0, 1.2, 4.6)).Position)
		-- the store: a lean-to of boards on the side, with tar pots
		local store = cf * CFrame.new(-11.5, 0, 0)
		part(m, "StoreRoof", Vector3.new(6, 0.4, 10), store * CFrame.new(0, 5.4, 0) * CFrame.Angles(0, 0, math.rad(-18)), Color3.fromRGB(66, 58, 48), Enum.Material.WoodPlanks, { collide = true })
		for _, sz in { -1, 1 } do
			cyl(m, "StorePost", (store * CFrame.new(-2.6, 0, sz * 4.4)).Position, (store * CFrame.new(-2.6, 4.4, sz * 4.4)).Position, 0.3, WOOD, Enum.Material.Wood, { collide = true })
		end
		mark("Pitch8", (store * CFrame.new(0, 0.8, -2)).Position)
		mark("Pitch9", (store * CFrame.new(0.5, 0.8, 2.5)).Position)
	end

	-- THE WOODCUTTER'S HUT
	do
		local m = Instance.new("Model")
		m.Name = "WoodcuttersHut"
		m.Parent = f
		local at = ground(-430, -1250)
		hut(m, "Hut", at, 200, 8, 7, 6.5, rng, { sag = 10 })
		local block = ground(-406, -1262)
		cyl(m, "ChoppingBlock", block - Vector3.new(0, 0.2, 0), block + Vector3.new(0, 1.6, 0), 1.1, Color3.fromRGB(150, 120, 90), Enum.Material.Wood, { variant = variant("OakBark", rng), collide = true })
		cyl(m, "AxeHaft", block + Vector3.new(0, 1.6, 0), block + Vector3.new(0.6, 4, 0.3), 0.1, WOOD, Enum.Material.Wood)
		part(m, "AxeHead", Vector3.new(0.9, 0.7, 0.15), CFrame.new(block + Vector3.new(0.05, 1.75, 0)), IRON, Enum.Material.CorrodedMetal)
		mark("Pitch6", at + Vector3.new(0, 0.8, 0))
		mark("Pitch7", block + Vector3.new(1.6, 0.6, 0))
		mark("Page4", at + Vector3.new(1.5, 1.2, 0.5))
	end

	-- the marks the trial reads: his round, where the dead rise, and the hiding trees
	for i, stop in cfg.Huntsman.Round do
		mark("Round" .. i, ground(stop.X, stop.Z) + Vector3.new(0, 0.5, 0))
	end
	mark("HuntsmanSpawn", ground(cfg.Huntsman.Spawn.X, cfg.Huntsman.Spawn.Z) + Vector3.new(0, 0.5, 0))
	local rises = 0
	for _, path in PATHS do
		for i = 1, #path - 1 do
			local mid = (path[i] + path[i + 1]) / 2
			local side = Vector3.new(-(path[i + 1].Z - path[i].Z), 0, path[i + 1].X - path[i].X)
			if side.Magnitude > 1 then
				local at = mid + side.Unit * 7
				rises += 1
				mark("Rise" .. rises, ground(at.X, at.Z) + Vector3.new(0, 0.5, 0))
			end
		end
	end

	-- the invisible walls round the outer wood and the Hollow's ends (behind brambles and spruce: never bare)
	local walls = Instance.new("Folder")
	walls.Name = "Bounds"
	walls.Parent = f
	local O = cfg.Outer
	local function bound(a: Vector3, b: Vector3)
		local mid = (a + b) / 2
		local len = (b - a).Magnitude
		local p = part(walls, "Bound", Vector3.new(len, 160, 4), CFrame.lookAt(Vector3.new(mid.X, 60, mid.Z), Vector3.new(b.X, 60, b.Z)) * CFrame.Angles(0, math.rad(90), 0), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { collide = true, query = false, transparency = 1, shadow = false })
		return p
	end
	bound(Vector3.new(-195, 0, O.Z0 + 2), Vector3.new(O.X1, 0, O.Z0 + 2))
	bound(Vector3.new(O.X1, 0, O.Z0 + 2), Vector3.new(O.X1, 0, O.Z1 - 2))
	bound(Vector3.new(O.X1, 0, O.Z1 - 2), Vector3.new(-195, 0, O.Z1 - 2))
	say(("places: fires, board, orchard, camp, Hollow, stones, lodge, hut; %d rise marks; bounds"):format(rises))

	-- a tree, a log or a stump that stands where a place was built is taken away (the places came after them)
	local solids: { BasePart } = {}
	for _, d in f:GetDescendants() do
		if d:IsA("BasePart") and d.CanCollide and d.Parent ~= walls then
			table.insert(solids, d)
		end
	end
	local function onPlace(at: Vector3, r: number): boolean
		for _, s in solids do
			local lp = s.CFrame:PointToObjectSpace(at)
			local half = s.Size / 2 + Vector3.new(r, 4, r)
			if math.abs(lp.X) <= half.X and math.abs(lp.Y) <= half.Y + 6 and math.abs(lp.Z) <= half.Z then
				return true
			end
		end
		return false
	end
	local gone = 0
	local trees = root:FindFirstChild("Trees")
	for _, m in if trees then trees:GetChildren() else {} do
		if m:IsA("Model") and onPlace(m:GetPivot().Position, if m:GetAttribute("Kind") == "hollow" then 6 else 2.5) then
			m:Destroy()
			gone += 1
		end
	end
	local under = root:FindFirstChild("Under")
	for _, p in if under then under:GetChildren() else {} do
		if p:IsA("BasePart") and onPlace(p.Position, 0.5) then
			p:Destroy()
			gone += 1
		end
	end
	say(("places: %d trees and things under them taken away where they stood on a place"):format(gone))
end

--==========================================================================
-- ZONES: the dark
--==========================================================================
local function buildZones()
	local f = section("Zones")
	local function zone(name: string, x0: number, z0: number, x1: number, z1: number)
		local p = part(f, name, Vector3.new(math.abs(x1 - x0), 200, math.abs(z1 - z0)), CFrame.new((x0 + x1) / 2, 60, (z0 + z1) / 2), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, { transparency = 1, shadow = false, collide = false, query = false })
		p:SetAttribute("Profile", cfg.LightProfile)
		p:SetAttribute("Priority", 2)
		CollectionService:AddTag(p, zonesCfg.Tag)
	end
	zone("ForestInner", -195, -1230, 195, -1480)
	zone("ForestOuter", -195, -1230, cfg.Outer.X1 - 10, -1480)
	say("zones: the dark over the inner wood, the Hollow and the outer wood")
end

--==========================================================================
local SECTIONS = {
	retire = retire,
	ground = buildGround,
	breach = buildBreach,
	paths = buildPaths,
	trees_inner = function()
		plantTrees("inner")
	end,
	trees_outer = function()
		plantTrees("outer")
	end,
	trees_banks = function()
		plantTrees("banks")
	end,
	under = buildUnder,
	places = buildPlaces,
	zones = buildZones,
	clear = function()
		root:ClearAllChildren()
		say("cleared")
	end,
}
local fn = SECTIONS[ONLY]
assert(fn, "unknown section " .. tostring(ONLY))
fn()
return report
