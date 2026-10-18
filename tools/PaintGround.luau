--[[
	PaintGround — run in the Studio Command Bar of the KINGDOM HUB place, in EDIT MODE.
	Select the whole file (Ctrl+A), copy, paste, Enter.

	WHY. The Hub's terrain is a flat slab of `Ground`, with the roads laid on top as one
	layer of `Sand`. Sand has a rippled desert texture, so the camp reads as a dune with a
	white track across it, not as a medieval camp — and colour cannot fix a texture. This
	changes which MATERIAL each top-layer voxel is, and nothing else.

	WHAT IT NEVER DOES. It never changes a height and never changes where a road is: a Sand
	voxel stays a road voxel (it becomes paving), a Ground voxel stays ground (it may become
	mud, grass or stone). Only the top layer is touched, and water is left alone.

	THE RECIPE (the numbers are in `R` below; the reasons are here)
	  Roads      Cobblestone, with the dirt showing through where it is worn and the odd slick of
	             mud. A road that is perfect everywhere is a road nobody ever walked on.
	  Lane edges Mud. Everything that walks the road tramples a few studs either side of it.
	  Shores     Mud, where Ground meets Water.
	  Inside     Ground, with damp patches of Mud, loose Rock, and weeds (Grass) along the fence,
	  the fence  where nobody has swept for forty years.
	  Outside    Patches of Mud, Grass and Rock on Ground, on large slow noise, so the plain
	  the fence  beyond the wall stops being one flat colour all the way to the horizon.
	  Everything is a function of world position and `SEED`, so a re-run paints the same ground.

	MODE, set below:

	  "preview"  counts what would change and draws a map of the camp. Writes nothing.
	  "apply"    does it. The first run records where the Sand roads were (as a Terrain attribute,
	             `GroundPaintSand`) so that "restore" can put them back exactly.
	  "restore"  every painted top-layer voxel goes back to Ground, then the recorded Sand roads
	             are laid again. Exact, because the terrain was only ever Ground, Sand and Water.

	Ground only looks right under a look that was tuned for it: run `ApplyLook` afterwards.
	Judge it with `PreviewRuntimeLights` ON — Edit-mode lamps are far brighter than in play.

	NOTE: a tool, not game code. Not synced by Rojo. Writes terrain voxels, nothing else.
]]

local MODE = "preview"

--==========================================================================
local RES = 4 -- terrain voxels are always 4 studs
local REACH = 640 -- studs from the origin that get painted; beyond that the fog has taken it
local SEED = 7.5 -- change it for a different (but equally stable) scatter

-- The camp: just outside the fence. The fence's parts span x -118..137, z -72..123.
local CAMP = { MinX = -125, MaxX = 145, MinZ = -80, MaxZ = 130 }

local R = {
	-- Roads
	-- (Tuned twice against screenshots. The first recipe wore away nearly half of every road;
	-- the second still let mud cut the road into islands from above. The road is how a player
	-- finds their way, so it has to read as one unbroken road before it reads as old: with these
	-- values 285 of its 308 voxels are paving.)
	WornAbove = 0.5, -- noise above this on a road: the dirt shows through (rare)
	SlickBelow = -0.55, -- noise below this on a road: a slick of mud (rare)
	-- Around the roads and the water
	LaneWearRadius = 1, -- columns (x4 studs) of trampled mud either side of a road
	LaneWearAbove = 0.15, -- noise above this inside that radius: it is mud, not ground
	-- Inside the camp
	DampBelow = -0.40, -- large slow noise below this: a damp patch
	FenceWeedsWithin = 12, -- studs from the fence line
	FenceWeedsAbove = 0.05,
	StonesAbove = 0.62, -- fine noise above this: loose stones
	-- Outside the camp
	WildMudBelow = -0.3,
	WildGrassAbove = 0.3,
	WildRockAbove = 0.55,
}

--==========================================================================
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local T = workspace.Terrain

local Air, Water, Sand, Ground = Enum.Material.Air, Enum.Material.Water, Enum.Material.Sand, Enum.Material.Ground
local Mud, Cobble, Grass, Rock = Enum.Material.Mud, Enum.Material.Cobblestone, Enum.Material.Grass, Enum.Material.Rock

local function waypoint(name: string)
	pcall(function()
		ChangeHistoryService:SetWaypoint(name)
	end)
end

local function noise(wx: number, wz: number, scale: number, salt: number): number
	return math.noise(wx * scale + 0.31, wz * scale + 0.17, SEED + salt)
end

-- Grows every true cell of a sparse mask by `r` columns in each direction.
local function dilate(mask, nx: number, nz: number, r: number)
	local tmp = {}
	for x = 1, nx do
		local col = table.create(nz, false)
		for z = 1, nz do
			if mask[x][z] then
				for dz = math.max(1, z - r), math.min(nz, z + r) do
					col[dz] = true
				end
			end
		end
		tmp[x] = col
	end
	local out = {}
	for x = 1, nx do
		out[x] = table.create(nz, false)
	end
	for x = 1, nx do
		for z = 1, nz do
			if tmp[x][z] then
				for dx = math.max(1, x - r), math.min(nx, x + r) do
					out[dx][z] = true
				end
			end
		end
	end
	return out
end

local region = Region3.new(Vector3.new(-REACH, -2 * RES, -REACH), Vector3.new(REACH, 0, REACH)):ExpandToGrid(RES)
local origin = region.CFrame.Position - region.Size / 2
local mats, occ = T:ReadVoxels(region, RES)
local nx, ny, nz = mats.Size.X, mats.Size.Y, mats.Size.Z
assert(ny == 2, "expected two layers (y -8..0), got " .. ny)
local TOP = ny

local function worldX(x: number): number
	return origin.X + (x - 0.5) * RES
end
local function worldZ(z: number): number
	return origin.Z + (z - 0.5) * RES
end

local report = {}
local function say(text: string)
	table.insert(report, text)
end

--==========================================================================
if MODE == "restore" then
	local record = T:GetAttribute("GroundPaintSand")
	if record == nil then
		warn("[Ground] nothing is recorded — was `apply` ever run in this place?")
		return
	end
	local sandAt = {}
	for sx, sz in string.gmatch(record, "(-?%d+),(-?%d+);") do
		sandAt[sx .. "," .. sz] = true
	end
	waypoint("Ground: before restore")
	local back = 0
	for x = 1, nx do
		for z = 1, nz do
			local m = mats[x][TOP][z]
			if m ~= Air and m ~= Water and occ[x][TOP][z] > 0 then
				local key = ("%d,%d"):format(worldX(x), worldZ(z))
				local want = if sandAt[key] then Sand else Ground
				if m ~= want then
					mats[x][TOP][z] = want
					back += 1
				end
			end
		end
		if x % 40 == 0 then
			task.wait()
		end
	end
	T:WriteVoxels(region, RES, mats, occ)
	T:SetAttribute("GroundPaintSand", nil)
	waypoint("Ground: restored")
	print(("[Ground] restored: %d voxels put back."):format(back))
	return
end

assert(MODE == "preview" or MODE == "apply", 'MODE must be "preview", "apply" or "restore"')

-- Masks the recipe needs.
local lane, water = {}, {}
for x = 1, nx do
	lane[x] = table.create(nz, false)
	water[x] = table.create(nz, false)
end
local sandRecord = {}
for x = 1, nx do
	for z = 1, nz do
		local top = mats[x][TOP][z]
		if top == Sand then
			lane[x][z] = true
			table.insert(sandRecord, ("%d,%d;"):format(worldX(x), worldZ(z)))
		end
		if top == Water or mats[x][TOP - 1][z] == Water then
			water[x][z] = true
		end
	end
end
local nearLane = dilate(lane, nx, nz, R.LaneWearRadius)
local nearWater = dilate(water, nx, nz, 1)
task.wait()

-- What material a top-layer voxel should become.
local function choose(x: number, z: number, m: Enum.Material): Enum.Material
	local wx, wz = worldX(x), worldZ(z)

	if m == Sand then
		local n = noise(wx, wz, 0.09, 1)
		if n > R.WornAbove then
			return Ground
		elseif n < R.SlickBelow then
			return Mud
		end
		return Cobble
	end

	if m ~= Ground then
		return m
	end

	if nearWater[x][z] then
		return Mud
	end

	local inCamp = wx >= CAMP.MinX and wx <= CAMP.MaxX and wz >= CAMP.MinZ and wz <= CAMP.MaxZ
	if inCamp then
		if nearLane[x][z] and noise(wx, wz, 0.12, 2) > R.LaneWearAbove then
			return Mud
		end
		if noise(wx, wz, 0.035, 3) < R.DampBelow then
			return Mud
		end
		local toFence = math.min(wx - CAMP.MinX, CAMP.MaxX - wx, wz - CAMP.MinZ, CAMP.MaxZ - wz)
		if toFence < R.FenceWeedsWithin and noise(wx, wz, 0.15, 4) > R.FenceWeedsAbove then
			return Grass
		end
		if noise(wx, wz, 0.22, 5) > R.StonesAbove then
			return Rock
		end
		return Ground
	end

	local wild = noise(wx, wz, 0.02, 6)
	if wild < R.WildMudBelow then
		return Mud
	elseif wild > R.WildGrassAbove then
		return Grass
	elseif noise(wx, wz, 0.05, 7) > R.WildRockAbove then
		return Rock
	end
	return Ground
end

local before, after = {}, {}
local changed = 0
local plan = {} -- plan[x][z] = new material, only where it differs
for x = 1, nx do
	plan[x] = {}
	for z = 1, nz do
		local m = mats[x][TOP][z]
		if m ~= Air and m ~= Water and occ[x][TOP][z] > 0 then
			before[m.Name] = (before[m.Name] or 0) + 1
			local want = choose(x, z, m)
			after[want.Name] = (after[want.Name] or 0) + 1
			if want ~= m then
				plan[x][z] = want
				changed += 1
			end
		end
	end
	if x % 40 == 0 then
		task.wait()
	end
end

local function tally(counts): string
	local parts = {}
	for name, n in pairs(counts) do
		table.insert(parts, name .. "=" .. n)
	end
	table.sort(parts)
	return table.concat(parts, ", ")
end
say(("[Ground] %s over x,z = ±%d, top layer only."):format(MODE, REACH))
say("  before: " .. tally(before))
say("  after:  " .. tally(after))
say(("  %d voxels change; %d road voxels recorded for restore."):format(changed, #sandRecord))

-- A map of the camp as it would be: one character per 8 studs, north (-z) at the top.
local chars = { [Sand] = "S", [Ground] = ".", [Mud] = "m", [Cobble] = "C", [Grass] = "g", [Rock] = "r", [Water] = "~" }
say("  map ( C paving  . ground  m mud  g grass  r stones  ~ water ):")
for wz = CAMP.MinZ, CAMP.MaxZ, 8 do
	local row = {}
	for wx = CAMP.MinX, CAMP.MaxX, 8 do
		local x = math.floor((wx - origin.X) / RES) + 1
		local z = math.floor((wz - origin.Z) / RES) + 1
		local m = plan[x][z] or mats[x][TOP][z]
		table.insert(row, chars[m] or "?")
	end
	say("  " .. table.concat(row))
end

if MODE == "apply" then
	-- The record of where the roads were comes first: without it there is no exact way back.
	if T:GetAttribute("GroundPaintSand") == nil then
		local saved = table.concat(sandRecord)
		local ok, err = pcall(function()
			T:SetAttribute("GroundPaintSand", saved)
		end)
		assert(ok and T:GetAttribute("GroundPaintSand") == saved, "could not record the roads, so nothing was painted: " .. tostring(err))
	end
	waypoint("Ground: before paint")
	for x = 1, nx do
		for z, want in pairs(plan[x]) do
			mats[x][TOP][z] = want
		end
	end
	T:WriteVoxels(region, RES, mats, occ)
	waypoint("Ground: painted")
	say('[Ground] painted. Run ApplyLook next, and set MODE = "restore" to undo.')
end

print(table.concat(report, "\n"))
