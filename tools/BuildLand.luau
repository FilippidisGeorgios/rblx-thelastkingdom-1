--[[
	BuildLand — run in the Studio Command Bar of the FORGOTTEN LANDS place, in
	EDIT MODE. Select the whole file (Ctrl+A), copy, paste, Enter.

	The land OUTSIDE the castle: the moat, the ground, the hills, the mountains on
	the horizon, and the road down from the hill where the party first sees the
	castle. The castle itself, and everything inside the moat's inner edge, is
	never touched.

	Why the land is shaped the way it is:

	- The castle is the boundary of play, so everything out here is SCENERY. Its
	  job is the first minute of the game: the intro is shot from the hill, and
	  from inside the walls the only thing a player sees of the outside is the
	  skyline. So the land is built for two eyes: the hill, and the sky above the
	  battlements.
	- The hill is 800 studs in front of the gate, and the line from the hill to the
	  gate is kept clear of every other rise, so the castle is never hidden behind
	  a lump of ground in the shot that matters most.
	- Near the moat the ground stays flat. Hills begin a hundred studs out and
	  grow; mountains close the horizon about 1.3k–1.9k out, all the way round, so
	  the world ends in rock and haze, never at an edge.
	- The moat is 80 wide and black. A shallow shelf on the outer side and a mud
	  bank make it read as dug and then left, not as a swimming pool.

	MODE
	  "slab"    the ground plate at y 0 out to the edge of the world (outside the castle)
	  "moat"    re-carves the moat ring
	  "relief"  hills and mountains, a strip at a time. Run it again until it prints
	            "relief: done". Progress is kept on Terrain attribute BuildLandCursor.
	  "road"    paints the road from the hill to the bridge
	  "reset"   clears the relief cursor so "relief" starts over

	Everything is deterministic (SEED), so re-running a mode gives the same land.

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local MODE = "slab"

local SEED = 1066
local T = workspace.Terrain
local ChangeHistoryService = game:GetService("ChangeHistoryService")

--==========================================================================
-- Geometry. The castle shell spans x -164..164, z -1794..66 (gatehouse front),
-- with corner towers standing out into the moat.
--==========================================================================
-- The moat follows the castle: 40 out from the side walls' centre lines and 16
-- behind the back wall (configs/Castle.luau). Before the 2026-10-19 widening
-- these were 190 / 270 and -1796 / -1876.
local Castle = require(game:GetService("ReplicatedStorage"):WaitForChild("Config"):WaitForChild("Castle")) :: any
local MOAT = {
	innerX = Castle.HalfWidth + 40, -- the inner edge, on each side (the castle side)
	outerX = Castle.HalfWidth + 120, -- the outer edge
	frontIn = 60, -- in front of the gate (the gatehouse stands 6 studs into the water)
	frontOut = 140,
	backIn = Castle.zEnd() - 16,
	backOut = Castle.zEnd() - 96,
	water = -6, -- the surface
	bed = -26,
	shelf = 10, -- shallow water along the outer side
	bank = 12, -- the mud slope from the water up to the ground
}

-- Everything inside this rectangle belongs to the castle and its moat.
local RECT = { minX = -MOAT.outerX, maxX = MOAT.outerX, minZ = MOAT.backOut, maxZ = MOAT.frontOut }

local WORLD = { minX = -2400, maxX = 2400, minZ = -4000, maxZ = 2300 }

-- The hill, and the line from it to the bridge that must stay clear.
local HILL = { x = -40, z = 820, height = 44, spread = 190 }
local SIGHT_A = Vector2.new(-40, 820)
local SIGHT_B = Vector2.new(0, MOAT.frontOut)

-- The road, as a polyline from the hill to the bridge.
local ROAD = {
	Vector2.new(-40, 790),
	Vector2.new(-34, 700),
	Vector2.new(-22, 600),
	Vector2.new(-6, 480),
	Vector2.new(0, 360),
	Vector2.new(0, 250),
	Vector2.new(0, MOAT.frontOut),
}
local ROAD_W = 16

local CHUNK = 64 -- studs per relief chunk (16 voxels)
local BUDGET = 25 -- seconds of relief per run

--==========================================================================
-- Helpers
--==========================================================================
local function smooth(a: number, b: number, t: number): number
	local u = math.clamp((t - a) / (b - a), 0, 1)
	return u * u * (3 - 2 * u)
end

local function rectDist(x: number, z: number): number
	local dx = math.max(RECT.minX - x, 0, x - RECT.maxX)
	local dz = math.max(RECT.minZ - z, 0, z - RECT.maxZ)
	return math.sqrt(dx * dx + dz * dz)
end

local function fbm(x: number, z: number, scale: number, octaves: number, salt: number): number
	local sum, amp, freq, norm = 0, 1, 1 / scale, 0
	for i = 1, octaves do
		sum += amp * math.noise(x * freq, z * freq, SEED * 0.0137 + salt + i * 7.31)
		norm += amp
		amp *= 0.5
		freq *= 2
	end
	return sum / norm
end

local function segDist(px: number, pz: number, a: Vector2, b: Vector2): number
	local vx, vz = b.X - a.X, b.Y - a.Y
	local t = math.clamp(((px - a.X) * vx + (pz - a.Y) * vz) / (vx * vx + vz * vz), 0, 1)
	local qx, qz = a.X + vx * t, a.Y + vz * t
	return math.sqrt((px - qx) ^ 2 + (pz - qz) ^ 2)
end

local function fill(minV: Vector3, maxV: Vector3, material: Enum.Material)
	local size = maxV - minV
	if size.X <= 0 or size.Y <= 0 or size.Z <= 0 then
		return
	end
	T:FillBlock(CFrame.new((minV + maxV) / 2), size, material)
end

local function waypoint(name: string)
	pcall(function()
		ChangeHistoryService:SetWaypoint(name)
	end)
end

--==========================================================================
-- The height of the land at a point (0 = the castle's ground level).
--==========================================================================
local function height(x: number, z: number): number
	local d = rectDist(x, z)
	if d <= 0 then
		return 0
	end

	-- 0 inside the sight line, 1 well away from it.
	local clear = smooth(80, 300, segDist(x, z, SIGHT_A, SIGHT_B))

	local hill = HILL.height * math.exp(-((x - HILL.x) ^ 2 + (z - HILL.z) ^ 2) / (2 * HILL.spread ^ 2))

	local rolling = smooth(100, 650, d) * math.max(0, fbm(x, z, 520, 4, 1) * 2.2 + 0.12) * 70 * clear

	local ring = smooth(1250, 1900, d)
	local mountains = 0
	if ring > 0 then
		mountains = ring * (210 + 300 * math.clamp(fbm(x, z, 760, 5, 9) + 0.5, 0, 1.2))
	end

	return hill + rolling + mountains
end

local function surface(x: number, z: number, h: number, slope: number): Enum.Material
	local d = rectDist(x, z)
	if d < 18 then
		return Enum.Material.Mud
	end
	if h > 230 + fbm(x, z, 90, 2, 5) * 80 then
		return Enum.Material.Slate
	end
	if slope > 0.85 or h > 140 + fbm(x, z, 120, 2, 3) * 60 then
		return Enum.Material.Rock
	end
	local patch = fbm(x, z, 70, 3, 7)
	if patch > 0.18 then
		return Enum.Material.Ground
	elseif patch < -0.24 then
		return Enum.Material.Mud
	end
	return Enum.Material.Grass
end

--==========================================================================
-- MODE slab
--==========================================================================
local function buildSlab()
	-- Four plates round the castle rectangle, so nothing inside it is touched.
	local y0, y1 = -16, 0
	fill(Vector3.new(WORLD.minX, y0, WORLD.minZ), Vector3.new(RECT.minX, y1, WORLD.maxZ), Enum.Material.Ground)
	fill(Vector3.new(RECT.maxX, y0, WORLD.minZ), Vector3.new(WORLD.maxX, y1, WORLD.maxZ), Enum.Material.Ground)
	fill(Vector3.new(RECT.minX, y0, RECT.maxZ), Vector3.new(RECT.maxX, y1, WORLD.maxZ), Enum.Material.Ground)
	fill(Vector3.new(RECT.minX, y0, WORLD.minZ), Vector3.new(RECT.maxX, y1, RECT.minZ), Enum.Material.Ground)
	print("[BuildLand] slab: ground plate laid out to the edge of the world")
end

--==========================================================================
-- MODE moat
--==========================================================================
-- True inside the castle's own ground (everything the moat goes round).
local function inCastle(x: number, z: number): boolean
	return math.abs(x) < MOAT.innerX and z > MOAT.backIn and z < MOAT.frontIn
end

--[[
	The moat is written voxel by voxel from one rule: how far a column is in from
	the OUTER edge of the ring. That one number gives the bank, the shelf and the
	deep water, and it turns the corners by itself — four separate trenches would
	each cut through the next one's bank.
]]
local function moatFloor(x: number, z: number): number
	local e = math.min(MOAT.outerX - math.abs(x), MOAT.frontOut - z, z - MOAT.backOut)
	if e < MOAT.bank then
		return MOAT.water * (e / MOAT.bank) -- the mud slope, ground level down to the water
	elseif e < MOAT.bank + MOAT.shelf then
		return MOAT.water - 7 -- the shallow shelf
	end
	-- Down to the bed over a few studs, then flat.
	local t = math.clamp((e - MOAT.bank - MOAT.shelf) / 8, 0, 1)
	return (MOAT.water - 7) + (MOAT.bed - (MOAT.water - 7)) * t
end

local function buildMoat()
	-- Deep enough to swallow the old moat (it went down to about -42).
	local Y0, Y1 = -48, 8
	local columns = 0

	for x0 = RECT.minX, RECT.maxX - 1, CHUNK do
		for z0 = RECT.minZ, RECT.maxZ - 1, CHUNK do
			local x1 = math.min(x0 + CHUNK, RECT.maxX)
			local z1 = math.min(z0 + CHUNK, RECT.maxZ)
			local region = Region3.new(Vector3.new(x0, Y0, z0), Vector3.new(x1, Y1, z1)):ExpandToGrid(4)
			local mats, occ = T:ReadVoxels(region, 4)
			local origin = region.CFrame.Position - region.Size / 2
			local size = mats.Size

			for i = 1, size.X do
				local x = origin.X + (i - 0.5) * 4
				for k = 1, size.Z do
					local z = origin.Z + (k - 0.5) * 4
					local inRing = x > RECT.minX and x < RECT.maxX and z > RECT.minZ and z < RECT.maxZ
					if inRing and not inCastle(x, z) then
						columns += 1
						local g = moatFloor(x, z)
						for y = 1, size.Y do
							local b = origin.Y + (y - 1) * 4
							local solid = math.clamp((g - b) / 4, 0, 1)
							local water = math.clamp((MOAT.water - b) / 4, 0, 1)
							if solid >= 0.25 or b + 4 <= g then
								mats[i][y][k] = if g < -3 then Enum.Material.Mud else Enum.Material.Ground
								occ[i][y][k] = math.max(solid, 0.25)
							elseif water > 0 then
								mats[i][y][k] = Enum.Material.Water
								occ[i][y][k] = water
							else
								mats[i][y][k] = Enum.Material.Air
								occ[i][y][k] = 0
							end
						end
					end
				end
			end
			T:WriteVoxels(region, 4, mats, occ)
		end
	end

	-- The inner side is a vertical cut: the stone revetment (BuildSurroundings) faces it.
	print(("[BuildLand] moat: %d columns re-carved, 80 wide, water at y %d"):format(columns, MOAT.water))
end

--==========================================================================
-- MODE castle
--==========================================================================
--[[
	After the castle grows, its old moat is INSIDE the new walls: water and mud
	where the yard should be. This fills everything inside the moat's inner
	edge back to plain ground at y = 0 (the castle's floor), with air above —
	but only where it is not already flat ground, so nothing painted inside the
	old walls is touched.
]]
local function buildCastleGround()
	local Y0, Y1 = -48, 16
	local columns = 0
	for x0 = -MOAT.innerX, MOAT.innerX - 1, CHUNK do
		for z0 = MOAT.backIn, MOAT.frontIn - 1, CHUNK do
			local x1 = math.min(x0 + CHUNK, MOAT.innerX)
			local z1 = math.min(z0 + CHUNK, MOAT.frontIn)
			local region = Region3.new(Vector3.new(x0, Y0, z0), Vector3.new(x1, Y1, z1)):ExpandToGrid(4)
			local mats, occ = T:ReadVoxels(region, 4)
			local origin = region.CFrame.Position - region.Size / 2
			local size = mats.Size
			local dirty = false
			for i = 1, size.X do
				local x = origin.X + (i - 0.5) * 4
				for k = 1, size.Z do
					local z = origin.Z + (k - 0.5) * 4
					if not inCastle(x, z) then
						continue
					end
					-- Already the castle floor? No water anywhere, the voxel just under
					-- y = 0 solid, nothing above it: leave it alone (and whatever was
					-- painted on it). The castle's own ground is only 20 deep, so air
					-- further down is normal and says nothing.
					local flat = true
					for y = 1, size.Y do
						local b = origin.Y + (y - 1) * 4
						local m = mats[i][y][k]
						if m == Enum.Material.Water then
							flat = false
						elseif b == -4 and (m == Enum.Material.Air or occ[i][y][k] < 0.99) then
							flat = false
						elseif b >= 0 and m ~= Enum.Material.Air then
							flat = false
						end
					end
					if flat then
						continue
					end
					columns += 1
					dirty = true
					for y = 1, size.Y do
						local b = origin.Y + (y - 1) * 4
						if b < 0 then
							mats[i][y][k] = Enum.Material.Ground
							occ[i][y][k] = 1
						else
							mats[i][y][k] = Enum.Material.Air
							occ[i][y][k] = 0
						end
					end
				end
			end
			if dirty then
				T:WriteVoxels(region, 4, mats, occ)
			end
		end
		task.wait()
	end
	print(("[BuildLand] castle: %d columns levelled to the castle floor"):format(columns))
end

--==========================================================================
-- MODE relief
--==========================================================================
local function buildRelief()
	local cols = math.ceil((WORLD.maxX - WORLD.minX) / CHUNK)
	local rows = math.ceil((WORLD.maxZ - WORLD.minZ) / CHUNK)
	local cursor = T:GetAttribute("BuildLandCursor") or 0
	local started = os.clock()
	local written = 0

	while cursor < cols * rows and os.clock() - started < BUDGET do
		local ci = cursor % cols
		local ri = cursor // cols
		cursor += 1

		local x0 = WORLD.minX + ci * CHUNK
		local z0 = WORLD.minZ + ri * CHUNK
		local x1, z1 = x0 + CHUNK, z0 + CHUNK

		-- Column heights at voxel centres, plus one ring for slopes.
		local n = CHUNK // 4
		local hs = table.create(n + 2)
		local maxH = 0
		for i = 0, n + 1 do
			local row = table.create(n + 2)
			for k = 0, n + 1 do
				local h = height(x0 + (i - 0.5) * 4, z0 + (k - 0.5) * 4)
				row[k] = h
				if i >= 1 and i <= n and k >= 1 and k <= n and h > maxH then
					maxH = h
				end
			end
			hs[i] = row
		end

		local touchesCastle = not (x1 <= RECT.minX or x0 >= RECT.maxX or z1 <= RECT.minZ or z0 >= RECT.maxZ)
		local layers = math.max(1, math.ceil(maxH / 4)) + 1 -- from y -4 up
		local region = Region3.new(Vector3.new(x0, -4, z0), Vector3.new(x1, -4 + layers * 4, z1))

		local mats, occ
		if touchesCastle then
			mats, occ = T:ReadVoxels(region, 4)
		else
			mats, occ = {}, {}
			for i = 1, n do
				local mi, oi = table.create(layers), table.create(layers)
				for y = 1, layers do
					local my, oy = table.create(n), table.create(n)
					mi[y], oi[y] = my, oy
				end
				mats[i], occ[i] = mi, oi
			end
		end

		for i = 1, n do
			local x = x0 + (i - 0.5) * 4
			for k = 1, n do
				local z = z0 + (k - 0.5) * 4
				if not touchesCastle or rectDist(x, z) > 0 then
					local h = hs[i][k]
					local slope = math.max(math.abs(hs[i + 1][k] - hs[i - 1][k]), math.abs(hs[i][k + 1] - hs[i][k - 1])) / 8
					local mat = surface(x, z, h, slope)
					for y = 1, layers do
						local bottom = -4 + (y - 1) * 4
						local o = math.clamp((h - bottom) / 4, 0, 1)
						if y == 1 then
							o = 1 -- the top of the plate is always solid
						end
						if o > 0 then
							mats[i][y][k] = mat
							occ[i][y][k] = o
						else
							mats[i][y][k] = Enum.Material.Air
							occ[i][y][k] = 0
						end
					end
				end
			end
		end

		T:WriteVoxels(region, 4, mats, occ)
		written += 1
	end

	T:SetAttribute("BuildLandCursor", cursor)
	if cursor >= cols * rows then
		print(("[BuildLand] relief: done (%d chunks this run)"):format(written))
	else
		print(("[BuildLand] relief: %d / %d chunks (%.0f%%) — run again"):format(cursor, cols * rows, 100 * cursor / (cols * rows)))
	end
	return cursor, cols * rows
end

--==========================================================================
-- MODE road
--==========================================================================
local function buildRoad()
	local painted = 0
	local function paint(cx: number, cz: number, half: number, from: { Enum.Material }, to: Enum.Material)
		local region = Region3.new(Vector3.new(cx - half, -8, cz - half), Vector3.new(cx + half, 72, cz + half)):ExpandToGrid(4)
		for _, m in from do
			T:ReplaceMaterial(region, 4, m, to)
		end
		painted += 1
	end
	for s = 1, #ROAD - 1 do
		local a, b = ROAD[s], ROAD[s + 1]
		local len = (b - a).Magnitude
		local steps = math.ceil(len / 4)
		for j = 0, steps do
			local p = a:Lerp(b, j / steps)
			-- Mud verges first, then the paving down the middle.
			paint(p.X, p.Y, ROAD_W / 2 + 4, { Enum.Material.Grass, Enum.Material.Ground }, Enum.Material.Mud)
			paint(p.X, p.Y, ROAD_W / 2 - 2, { Enum.Material.Grass, Enum.Material.Ground, Enum.Material.Mud }, Enum.Material.Cobblestone)
		end
	end
	print(("[BuildLand] road: %d stamps"):format(painted))
end

--==========================================================================
local Tool = {
	height = height,
	rectDist = rectDist,
	MOAT = MOAT,
	RECT = RECT,
	WORLD = WORLD,
	HILL = HILL,
	ROAD = ROAD,
}

function Tool.run(mode: string)
	waypoint("BuildLand: before " .. mode)
	local a, b
	if mode == "slab" then
		buildSlab()
	elseif mode == "castle" then
		buildCastleGround()
	elseif mode == "moat" then
		buildMoat()
	elseif mode == "relief" then
		a, b = buildRelief()
	elseif mode == "road" then
		buildRoad()
	elseif mode == "reset" then
		T:SetAttribute("BuildLandCursor", nil)
		print("[BuildLand] relief cursor cleared")
	else
		warn("[BuildLand] unknown MODE " .. tostring(mode))
	end
	waypoint("BuildLand: " .. mode)
	return a, b
end

local AUTO_RUN = true
if AUTO_RUN then
	Tool.run(MODE)
end

return Tool
