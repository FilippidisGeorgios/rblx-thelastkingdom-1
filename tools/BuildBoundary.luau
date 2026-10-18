--[[
	BuildBoundary — run in the Studio Command Bar of the KINGDOM HUB place, in EDIT MODE.
	Select the whole file (Ctrl+A), copy, paste, Enter.

	WHY. Nothing stops a player leaving the Hub. The chain-link fence is only 9.6 studs
	tall and a jump plus a stack of crates clears it; on the north side there is no fence
	at all, only the railway, and the plain beyond it goes on for a thousand studs. This
	builds an invisible, very tall wall that closes the whole camp. The fence stays exactly
	as it is: this does not touch it.

	THE SHAPE. One closed outline of the PLAYABLE ground, read from what is already there:
	  - the fence's three sides (west, south, east), at the fence's own lines;
	  - the gaps beside the train on the north, closed at the fence's north ends;
	  - a pocket around the train and the four wagons, CLEARANCE studs outside them, so the
	    rake stays inside the playable area and a player can still walk round it and board.
	The walls stand OUTSIDE that outline, with their inner face on it. So nothing protrudes
	into the camp, and at the fence the wall simply continues the fence's own line.

	THE CAMERA. The wall is Transparency 1 and CanQuery false. Roblox's default camera only
	pulls in for parts that are opaque and collidable, and a part with CanQuery off is
	invisible to the raycasts it uses, so a player can zoom out past the wall and see over it.
	Only the character's body is stopped. (CanQuery off also means no gameplay raycast —
	a weapon, a click, a line of sight — ever hits the wall.)

	THE HEIGHT. HEIGHT studs above the ground. A jump clears about 7; nothing in the camp
	stacks to 50. THICKNESS is generous too, so a fast character cannot tunnel through.

	MODE, set below:

	  "preview"  reads the fence and the train, plans the outline and reports it. Writes nothing.
	  "build"    builds `Lobby.Invisible.Boundary`, replacing a previous one (never stacking).
	  "verify"   proves the wall closed: along the whole outline, points just outside the line
	             must be inside a wall piece, and points just inside must NOT be. Run it after
	             any edit to the fence or the train, and after "build".
	  "remove"   deletes the boundary.

	Move the fence or the train and run "build" again: the outline follows them.

	NOTE: a tool, not game code. Not synced by Rojo. Touches only Lobby.Invisible.Boundary.
]]

local MODE = "preview"

--==========================================================================
local HEIGHT = 50
local THICKNESS = 4
-- Studs between the train/wagons and the wall around them. A stud is about 0.28 m, so 6 is about
-- 1.7 m: room for a character (2 studs wide) to walk round the ends of the train. The first draft
-- used 2 studs by mistake, which is 0.56 m, and would have wedged a player between train and wall.
local CLEARANCE = 6
local CHUNK = 32 -- long walls are cut in pieces so they stream in with the world

--==========================================================================
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local UP = Vector3.yAxis

local function waypoint(name: string)
	pcall(function()
		ChangeHistoryService:SetWaypoint(name)
	end)
end

local groundParams = RaycastParams.new()
groundParams.FilterType = Enum.RaycastFilterType.Include
groundParams.FilterDescendantsInstances = { workspace.Terrain }

-- The real ground under a point (measured: the terrain top here is y = 2).
local function groundY(x: number, z: number): number
	local hit = workspace:Raycast(Vector3.new(x, 60, z), Vector3.new(0, -120, 0), groundParams)
	return if hit then hit.Position.Y else 2
end

--==========================================================================
-- Reading what is there.

-- The fence: three runs of 'Old Wire' segments. Returns the lines they stand on.
local function readFence()
	local lobby = workspace:FindFirstChild("Lobby")
	local nature = lobby and lobby:FindFirstChild("Nature")
	assert(nature, "no Workspace.Lobby.Nature")

	local segments = {}
	for _, d in ipairs(nature:GetChildren()) do
		if d.Name == "Old Wire" and d:IsA("Model") then
			table.insert(segments, d)
		end
	end
	assert(#segments > 0, "no 'Old Wire' fence segments in Lobby.Nature")

	local groups = {}
	for _, seg in ipairs(segments) do
		local cf, size = seg:GetBoundingBox()
		local long = math.max(size.X, size.Z)
		local longVec = if size.X >= size.Z then cf.RightVector else cf.LookVector
		local axis = if math.abs(longVec.X) > math.abs(longVec.Z) then "x" else "z"
		local fixed = if axis == "x" then cf.Z else cf.X
		local along = if axis == "x" then cf.X else cf.Z
		local key = axis .. "@" .. math.round(fixed)
		local g = groups[key]
		if not g then
			g = { axis = axis, fixed = math.round(fixed), lo = math.huge, hi = -math.huge }
			groups[key] = g
		end
		g.lo = math.min(g.lo, along - long / 2)
		g.hi = math.max(g.hi, along + long / 2)
	end

	local alongZ, alongX = {}, {}
	for _, g in pairs(groups) do
		table.insert(if g.axis == "z" then alongZ else alongX, g)
	end
	assert(
		#alongZ == 2 and #alongX == 1,
		("expected a west and an east run and one south run, found %d running along z and %d along x"):format(#alongZ, #alongX)
	)
	table.sort(alongZ, function(a, b)
		return a.fixed < b.fixed
	end)

	local fence = {
		west = alongZ[1].fixed,
		east = alongZ[2].fixed,
		south = alongX[1].fixed,
		north = math.min(alongZ[1].lo, alongZ[2].lo), -- where the west and east sides stop
	}
	assert(fence.south > fence.north, "the south run is not south of the fence's north end")
	return fence, #segments
end

-- The train and the wagons: their footprint in the world.
local function readRake()
	local station = workspace.Lobby:FindFirstChild("TrainStation")
	assert(station, "no Workspace.Lobby.TrainStation")
	local minX, maxX, minZ, maxZ = math.huge, -math.huge, math.huge, -math.huge
	local count = 0
	for _, m in ipairs(station:GetChildren()) do
		if m:IsA("Model") and (m.Name == "Wagon" or m.Name == "Main Train") then
			count += 1
			local cf, size = m:GetBoundingBox()
			for sx = -1, 1, 2 do
				for sz = -1, 1, 2 do
					local c = cf * Vector3.new(sx * size.X / 2, 0, sz * size.Z / 2)
					minX, maxX = math.min(minX, c.X), math.max(maxX, c.X)
					minZ, maxZ = math.min(minZ, c.Z), math.max(maxZ, c.Z)
				end
			end
		end
	end
	assert(count > 0, "no 'Wagon' or 'Main Train' under the station")
	return { minX = minX, maxX = maxX, minZ = minZ, maxZ = maxZ, count = count }
end

--==========================================================================
-- The outline of the playable ground, as vertices in (x, z).
local function planOutline(fence, rake)
	local x0, x1 = rake.minX - CLEARANCE, rake.maxX + CLEARANCE
	local zn = rake.minZ - CLEARANCE
	assert(x0 > fence.west and x1 < fence.east, "the train is not between the fence's west and east sides")
	assert(zn < fence.north, "the train does not reach beyond the fence's north end, so there is nothing to wrap")
	return {
		Vector2.new(fence.west, fence.north), -- west side, north end
		Vector2.new(fence.west, fence.south), -- ... down the west fence
		Vector2.new(fence.east, fence.south), -- ... along the south fence
		Vector2.new(fence.east, fence.north), -- ... up the east fence
		Vector2.new(x1, fence.north), -- ... west along the north gap, up to the train
		Vector2.new(x1, zn), -- ... round the train's east end
		Vector2.new(x0, zn), -- ... behind the train
		Vector2.new(x0, fence.north), -- ... round its west end, and on to the start
	}
end

local function isInside(outline, x: number, z: number): boolean
	local inside = false
	local j = #outline
	for i = 1, #outline do
		local a, b = outline[i], outline[j]
		if (a.Y > z) ~= (b.Y > z) and x < (b.X - a.X) * (z - a.Y) / (b.Y - a.Y) + a.X then
			inside = not inside
		end
		j = i
	end
	return inside
end

-- One wall per edge: a rectangle outside the outline, inner face on the edge. At a corner that
-- bends AWAY from the playable ground the wall runs THICKNESS past the vertex to fill the
-- corner; at a corner that bends INTO it, it stops on the line, so nothing sticks into the camp.
local function planWalls(outline)
	local n = #outline
	local area = 0
	for i = 1, n do
		local a, b = outline[i], outline[i % n + 1]
		area += a.X * b.Y - b.X * a.Y
	end
	local orientation = if area > 0 then 1 else -1

	local function convex(i: number): boolean
		local prev, cur, nxt = outline[(i - 2) % n + 1], outline[i], outline[i % n + 1]
		local d1, d2 = (cur - prev).Unit, (nxt - cur).Unit
		return (d1.X * d2.Y - d1.Y * d2.X) * orientation > 0
	end

	local walls = {}
	for i = 1, n do
		local a, b = outline[i], outline[i % n + 1]
		local dir = (b - a).Unit
		local length = (b - a).Magnitude
		local normal = Vector2.new(-dir.Y, dir.X)
		local mid = (a + b) / 2
		if isInside(outline, mid.X + normal.X * 0.5, mid.Y + normal.Y * 0.5) then
			normal = -normal -- that side is playable ground; the wall goes the other way
		end
		local from = if convex(i) then -THICKNESS else 0
		local to = length + (if convex(i % n + 1) then THICKNESS else 0)
		table.insert(walls, { a = a, dir = dir, normal = normal, length = length, from = from, to = to })
	end
	return walls
end

local function planPieces(walls)
	local pieces = {}
	for _, w in ipairs(walls) do
		local span = w.to - w.from
		local count = math.ceil(span / CHUNK)
		for k = 1, count do
			local along = w.from + (k - 0.5) * span / count
			local p = w.a + w.dir * along + w.normal * (THICKNESS / 2)
			local gy = groundY(p.X, p.Y)
			table.insert(pieces, {
				size = Vector3.new(span / count + 0.4, HEIGHT, THICKNESS), -- +0.4: pieces overlap, so there is no seam
				cf = CFrame.fromMatrix(Vector3.new(p.X, gy - 1 + HEIGHT / 2, p.Y), Vector3.new(w.dir.X, 0, w.dir.Y), UP),
			})
		end
	end
	return pieces
end

--==========================================================================
local function boundaryFolder(): Folder?
	local invisible = workspace.Lobby:FindFirstChild("Invisible")
	return invisible and invisible:FindFirstChild("Boundary") :: Folder?
end

local function run(mode: string)
	assert(mode == "preview" or mode == "build" or mode == "verify" or mode == "remove", 'MODE must be "preview", "build", "verify" or "remove"')
	local report = {}
	local function say(text: string)
		table.insert(report, text)
	end
	local function finish(): string
		local text = table.concat(report, "\n")
		print(text)
		return text
	end

	if mode == "remove" then
		local f = boundaryFolder()
		waypoint("Boundary: before remove")
		if f then
			f:Destroy()
		end
		waypoint("Boundary: removed")
		say(("[Boundary] %s."):format(if f then "removed" else "was not there"))
		return finish()
	end

	local fence, segmentCount = readFence()
	local rake = readRake()
	local outline = planOutline(fence, rake)

	--======================================================================
	if mode == "verify" then
		local folder = boundaryFolder()
		assert(folder, "there is no Lobby.Invisible.Boundary to verify; run \"build\" first")
		local pieces = {}
		local badProps = 0
		for _, d in ipairs(folder:GetChildren()) do
			if d:IsA("BasePart") then
				table.insert(pieces, d)
				if d.Transparency < 1 or not d.CanCollide or d.CanQuery or not d.Anchored then
					badProps += 1
				end
			end
		end

		-- `tolerance` grows (+) or shrinks (-) every piece a hair. A point exactly ON a wall's face,
		-- as at a corner where two walls meet, is not inside it: the check for protrusions shrinks.
		local function covered(p: Vector3, tolerance: number): boolean
			for _, b in ipairs(pieces) do
				local o = b.CFrame:PointToObjectSpace(p)
				local h = b.Size / 2 + Vector3.new(tolerance, tolerance, tolerance)
				if math.abs(o.X) <= h.X and math.abs(o.Y) <= h.Y and math.abs(o.Z) <= h.Z then
					return true
				end
			end
			return false
		end

		local walls = planWalls(outline)
		local gaps, protrusions, sampled = {}, {}, 0
		for _, w in ipairs(walls) do
			local t = 0
			while t <= w.length do
				local base = w.a + w.dir * t
				local gy = groundY(base.X, base.Y)
				for _, height in ipairs({ 2, 12, 30, HEIGHT - 3 }) do
					for _, depth in ipairs({ 0.5, THICKNESS - 0.5 }) do -- just outside the line, and at the back of the wall
						local q = base + w.normal * depth
						sampled += 1
						if not covered(Vector3.new(q.X, gy + height, q.Y), 0.01) then
							table.insert(gaps, ("(%.0f,%.0f) y+%d depth %.1f"):format(q.X, q.Y, height, depth))
						end
					end
					for _, depth in ipairs({ 0.5, 1.5, 3 }) do -- just inside the line: must be clear
						local q = base - w.normal * depth
						sampled += 1
						if covered(Vector3.new(q.X, gy + height, q.Y), -0.01) then
							table.insert(protrusions, ("(%.0f,%.0f) y+%d depth %.1f"):format(q.X, q.Y, height, depth))
						end
					end
				end
				t += 1.5
			end
		end
		say(("[Boundary] verify: %d wall pieces, %d points sampled along the outline."):format(#pieces, sampled))
		say(("  GAPS (outside the line but not in a wall): %d%s"):format(#gaps, if #gaps > 0 then "  e.g. " .. table.concat(gaps, "; ", 1, math.min(5, #gaps)) else ""))
		say(("  PROTRUSIONS (wall inside the playable ground): %d%s"):format(#protrusions, if #protrusions > 0 then "  e.g. " .. table.concat(protrusions, "; ", 1, math.min(5, #protrusions)) else ""))
		say(("  pieces with wrong properties (must be invisible, collidable, not queryable, anchored): %d"):format(badProps))
		say(if #gaps == 0 and #protrusions == 0 and badProps == 0 then "  RESULT: closed." else "  RESULT: PROBLEMS FOUND.")
		return finish()
	end

	--======================================================================
	local walls = planWalls(outline)
	local pieces = planPieces(walls)

	say(("[Boundary] %s. Fence: %d segments; west x=%.0f, east x=%.0f, south z=%.0f, stops at z=%.1f."):format(mode, segmentCount, fence.west, fence.east, fence.south, fence.north))
	say(("  Train and wagons (%d models): x %.1f..%.1f, z %.1f..%.1f; wall %d studs outside them."):format(rake.count, rake.minX, rake.maxX, rake.minZ, rake.maxZ, CLEARANCE))
	say("  outline (x, z): " .. table.concat(
		(function()
			local out = {}
			for _, v in ipairs(outline) do
				table.insert(out, ("(%.1f, %.1f)"):format(v.X, v.Y))
			end
			return out
		end)(),
		" -> "
	))
	local total = 0
	for i, w in ipairs(walls) do
		total += w.to - w.from
		say(("  wall %d: from (%.1f, %.1f) along (%.0f, %.0f), outward (%.0f, %.0f), %.0f studs"):format(i, w.a.X, w.a.Y, w.dir.X, w.dir.Y, w.normal.X, w.normal.Y, w.to - w.from))
	end
	say(("  %d pieces, %.0f studs of wall, %d high, %d thick."):format(#pieces, total, HEIGHT, THICKNESS))

	-- Anything the player needs that would end up outside?
	local lobby = workspace.Lobby
	local outside = {}
	for _, folderName in ipairs({ "NPCs", "Interactables", "Leaderboards", "Spawn" }) do
		local f = lobby:FindFirstChild(folderName)
		if f then
			for _, c in ipairs(f:GetChildren()) do
				local pos = if c:IsA("Model") then c:GetBoundingBox().Position elseif c:IsA("BasePart") then c.Position else nil
				if pos and not isInside(outline, pos.X, pos.Z) then
					table.insert(outside, ("%s/%s (%.0f, %.0f)"):format(folderName, c.Name, pos.X, pos.Z))
				end
			end
		end
	end
	say(("  functional things (NPCs, interactables, leaderboards, spawn) outside the outline: %d%s"):format(#outside, if #outside > 0 then "  " .. table.concat(outside, "; ") else ""))

	if mode == "build" then
		waypoint("Boundary: before build")
		local invisible = lobby:FindFirstChild("Invisible")
		if not invisible then
			invisible = Instance.new("Folder")
			invisible.Name = "Invisible"
			invisible.Parent = lobby
		end
		local old = invisible:FindFirstChild("Boundary")
		if old then
			old:Destroy()
		end
		local folder = Instance.new("Folder")
		folder.Name = "Boundary"
		folder.Parent = invisible

		for _, spec in ipairs(pieces) do
			local part = Instance.new("Part")
			part.Name = "Barrier"
			part.Size = spec.size
			part.CFrame = spec.cf
			part.Anchored = true
			part.CanCollide = true -- stops the character...
			part.CanQuery = false -- ...but no raycast, and so no camera, ever sees it
			part.CanTouch = false
			part.CastShadow = false
			part.Transparency = 1
			part.Locked = true -- cannot be clicked in the viewport; still selectable in the Explorer
			part.Material = Enum.Material.SmoothPlastic
			part.Color = Color3.fromRGB(120, 60, 60) -- never seen
			part.Parent = folder
		end
		waypoint("Boundary: built")
		say(("[Boundary] built %d pieces in Lobby.Invisible.Boundary. Run with MODE = \"verify\" to prove it closed."):format(#pieces))
	end

	return finish()
end

--==========================================================================
run(MODE)
