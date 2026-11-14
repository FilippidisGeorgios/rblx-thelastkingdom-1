--!nonstrict
--[[
	SeamAudit — finds (and mends) walls that almost touch. Run in EDIT MODE, in either place, loaded from the sync bundle.

	THE PROBLEM (developer, 2026-11-14): two walls should meet with ZERO difference: not one slightly inside the other (the stone
	shows twice and flickers), not one slightly short of the other (a crack of light). Generated buildings drift by a stud-fraction
	because their sizes are computed, and "two parts merged, the stone showing on both" is also what makes a part flicker.

	WHAT IT LOOKS AT. Block parts that are axis-aligned (their faces are turned a whole number of quarter-turns; roofs and ramps
	are left alone). For every pair that shares face area it measures, along each axis, the GAP between them:
	    gap = 0               the faces meet exactly: good
	    0 < gap <= TOL        a CRACK            (kind "gap")
	    -TOL <= gap < 0       a SHALLOW OVERLAP  (kind "overlap"): one part stands a little inside the other
	and, separately, faces on the SAME plane that overlap in area (kind "coplanar": z-fighting).
	Deep overlaps (a beam sunk into a wall by a stud or more) are intended and are not touched.

	THE MEND. A crack or a shallow overlap is closed by moving the face of the part that is SMALLER along that axis (or,
	for equal thickness, the one that is smaller overall) to the other part's face plane, keeping its opposite face where it was:
	the part keeps its far side and changes by less than TOL. Coplanar faces are not moved: the SMALLER part's face is pulled in by
	COPLANAR_INSET (0.02, invisible) so it no longer fights. Everything is one ChangeHistory waypoint.

	  SeamAudit.scan(rootInstance, opts)   -> { issues = {...}, stats = {...} }
	  SeamAudit.mend(issues, opts)         -> number of parts changed
	  opts: tol (0.5), minOverlap (0.3), minSize (0.2 smallest side), onlyAnchored (true)
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")

local SeamAudit = {}

local TOL = 0.5
local MIN_OVERLAP = 0.3
local EXACT = 0.002 -- below this the faces count as meeting exactly
SeamAudit.COPLANAR_INSET = 0.02

local function axisAligned(p: BasePart): boolean
	local cf = p.CFrame
	local function snap(v: Vector3)
		local m = math.max(math.abs(v.X), math.abs(v.Y), math.abs(v.Z))
		return m > 0.9995
	end
	return snap(cf.RightVector) and snap(cf.UpVector) and snap(cf.LookVector)
end

-- the world box of an axis-aligned part
local function box(p: BasePart)
	local cf, s = p.CFrame, p.Size
	local ex = math.abs(cf.RightVector.X) * s.X + math.abs(cf.UpVector.X) * s.Y + math.abs(cf.LookVector.X) * s.Z
	local ey = math.abs(cf.RightVector.Y) * s.X + math.abs(cf.UpVector.Y) * s.Y + math.abs(cf.LookVector.Y) * s.Z
	local ez = math.abs(cf.RightVector.Z) * s.X + math.abs(cf.UpVector.Z) * s.Y + math.abs(cf.LookVector.Z) * s.Z
	local c = cf.Position
	return { c.X - ex / 2, c.Y - ey / 2, c.Z - ez / 2, c.X + ex / 2, c.Y + ey / 2, c.Z + ez / 2 }
end

local CELL = 16

function SeamAudit.scan(root: Instance, opts: { [string]: any }?)
	opts = opts or {}
	local tol = opts.tol or TOL
	local minOv = opts.minOverlap or MIN_OVERLAP
	local minSize = opts.minSize or 0.2

	local items = {}
	local grid = {}
	local considered = 0
	for _, d in root:GetDescendants() do
		if d:IsA("Part") and d.Shape == Enum.PartType.Block and (d.Anchored or opts.onlyAnchored == false) and d.Transparency < 0.95 and d.Size.Magnitude >= 1 then
			local s = d.Size
			if math.min(s.X, s.Y, s.Z) >= minSize and axisAligned(d) then
				considered += 1
				local b = box(d)
				local item = { part = d, b = b, id = considered, vol = s.X * s.Y * s.Z }
				items[considered] = item
				for ix = math.floor(b[1] / CELL), math.floor(b[4] / CELL) do
					for iy = math.floor(b[2] / CELL), math.floor(b[5] / CELL) do
						for iz = math.floor(b[3] / CELL), math.floor(b[6] / CELL) do
							local key = ix * 73856093 + iy * 19349663 + iz * 83492791
							local cell = grid[key]
							if not cell then
								cell = {}
								grid[key] = cell
							end
							table.insert(cell, item)
						end
					end
				end
			end
		end
	end

	local seen = {}
	local issues = {}
	local stats = { considered = considered, exact = 0, gap = 0, overlap = 0, coplanar = 0, duplicate = 0 }
	local clock = os.clock()
	for _, cell in grid do
		for i = 1, #cell do
			local a = cell[i]
			for j = i + 1, #cell do
				local c = cell[j]
				local lo, hi = a.id, c.id
				if lo > hi then
					lo, hi = hi, lo
				end
				local key = lo * 1000003 + hi
				if not seen[key] then
					seen[key] = true
					local ba, bc = a.b, c.b
					local same = true
					for k = 1, 6 do
						if math.abs(ba[k] - bc[k]) > EXACT then
							same = false
							break
						end
					end
					if same and a.part.Material == c.part.Material and a.part.Color == c.part.Color then
						stats.duplicate += 1
						table.insert(issues, { kind = "duplicate", a = a, b = c, axis = 1, gap = 0 })
						continue
					end
					-- overlap length on each axis (negative = apart)
					local ov = {
						math.min(ba[4], bc[4]) - math.max(ba[1], bc[1]),
						math.min(ba[5], bc[5]) - math.max(ba[2], bc[2]),
						math.min(ba[6], bc[6]) - math.max(ba[3], bc[3]),
					}
					for axis = 1, 3 do
						local o1, o2 = ov[axis % 3 + 1], ov[(axis + 1) % 3 + 1]
						if o1 >= minOv and o2 >= minOv then
							-- along this axis: gap (positive) or penetration (negative)
							local gap = -ov[axis]
							local insetPair = a.part:GetAttribute("SeamInset") or c.part:GetAttribute("SeamInset")
							if math.abs(gap) <= EXACT then
								stats.exact += 1
							elseif insetPair and math.abs(gap) <= 0.06 then
								stats.exact += 1 -- a face deliberately recessed by a hair so it does not fight: not a seam
							elseif gap > EXACT and gap <= tol then
								stats.gap += 1
								table.insert(issues, { kind = "gap", a = a, b = c, axis = axis, gap = gap })
							elseif gap < -EXACT and gap >= -tol then
								-- a shallow overlap only counts when it is shallower than the thinner part along the axis
								local ta = ba[axis + 3] - ba[axis]
								local tc = bc[axis + 3] - bc[axis]
								if -gap < math.min(ta, tc) * 0.5 then
									stats.overlap += 1
									table.insert(issues, { kind = "overlap", a = a, b = c, axis = axis, gap = gap })
								end
							end
							-- coplanar: the part-bodies overlap in space (ov >= 0 on all axes) and a face lies on the same plane
							if ov[axis] > EXACT then
								local sameMin = math.abs(ba[axis] - bc[axis]) < EXACT
								local sameMax = math.abs(ba[axis + 3] - bc[axis + 3]) < EXACT
								-- only a visible fight: the two faces differ in colour or material (the same stone twice is not seen)
								if (sameMin or sameMax) and (a.part.Color ~= c.part.Color or a.part.Material ~= c.part.Material) then
									stats.coplanar += 1
									table.insert(issues, { kind = "coplanar", a = a, b = c, axis = axis, gap = 0, sameMin = sameMin, sameMax = sameMax })
								end
							end
						end
					end
				end
			end
			if os.clock() - clock > 8 then
				task.wait()
				clock = os.clock()
			end
		end
	end
	return { issues = issues, stats = stats }
end

-- Resize `item.part` so its face on `axis` (`side` = -1 for the min face, +1 for the max face) is at `target`. Returns true if changed.
local function moveFace(item, axis: number, side: number, target: number): boolean
	local p = item.part
	local b = box(p)
	local cur = if side < 0 then b[axis] else b[axis + 3]
	if math.abs(cur - target) < 1e-4 then
		return false
	end
	-- the world axis of the part's local axis that lies on `axis`
	local cf = p.CFrame
	local dirs = { cf.RightVector, cf.UpVector, cf.LookVector }
	local local_i
	for i, v in dirs do
		local comp = if axis == 1 then v.X elseif axis == 2 then v.Y else v.Z
		if math.abs(comp) > 0.999 then
			local_i = i
		end
	end
	if not local_i then
		return false
	end
	local dim = ({ "X", "Y", "Z" })[local_i]
	local oldSize = p.Size
	local len = oldSize[dim]
	local newLen = if side < 0 then (b[axis + 3] - target) else (target - b[axis])
	if newLen < 0.05 then
		return false
	end
	local shift = (newLen - len) / 2 -- the centre moves half the change, toward the moved face
	local worldMove = Vector3.zero
	local sign = if side < 0 then -1 else 1
	local axisVec = if axis == 1 then Vector3.xAxis elseif axis == 2 then Vector3.yAxis else Vector3.zAxis
	worldMove = axisVec * (sign * shift)
	local sz = {X = oldSize.X, Y = oldSize.Y, Z = oldSize.Z}
	sz[dim] = newLen
	p.Size = Vector3.new(sz.X, sz.Y, sz.Z)
	p.CFrame = p.CFrame + worldMove
	return true
end

function SeamAudit.mend(issues: { any }, opts: { [string]: any }?): number
	opts = opts or {}
	local tol = opts.tol or TOL
	ChangeHistoryService:SetWaypoint("SeamAudit before")
	local changed = 0

	-- 1. exact duplicates: one of the two goes
	local gone = {}
	for _, is in issues do
		if is.kind == "duplicate" and not gone[is.a.id] and not gone[is.b.id] and is.a.part.Parent and is.b.part.Parent then
			gone[is.b.id] = true
			is.b.part:Destroy()
			changed += 1
		end
	end

	-- 1b. faces on the same plane that overlap in space AND differ in colour or material (they fight, one stone showing through the
	-- other): the smaller part's face is pulled in by a hair, and the part is marked so the crack step leaves that hair alone
	if opts.coplanar ~= false then
		local done = {}
		for _, is in issues do
			if is.kind == "coplanar" and not gone[is.a.id] and not gone[is.b.id] then
				local mover = if is.a.vol <= is.b.vol then is.a else is.b
				local anchor = if mover == is.a then is.b else is.a
				local key = mover.id * 4 + is.axis
				if not done[key] then
					done[key] = true
					local bm, ba = box(mover.part), box(anchor.part)
					local side = if math.abs(bm[is.axis] - ba[is.axis]) < 0.002 then -1 else 1
					if is.axis == 2 and side > 0 then
						continue -- a top face stays where it is
					end
					local target = if side < 0 then bm[is.axis] + SeamAudit.COPLANAR_INSET else bm[is.axis + 3] - SeamAudit.COPLANAR_INSET
					if moveFace(mover, is.axis, side, target) then
						mover.part:SetAttribute("SeamInset", true)
						changed += 1
					end
				end
			end
		end
	end

	-- 2. cracks and shallow overlaps. Every face that is meant to meet another is a NODE; an issue joins the two faces that
	-- face each other. Each connected group of faces is brought to ONE coordinate (the face of its biggest part), so a chain
	-- of parts cannot push a crack down the line (moving a pair at a time left cracks oscillating between neighbours).
	local parent, node = {}, {}
	local function find(k)
		while parent[k] ~= k do
			parent[k] = parent[parent[k]]
			k = parent[k]
		end
		return k
	end
	local function reg(item, axis, side)
		local k = item.id * 8 + axis * 2 + (if side > 0 then 1 else 0)
		if not node[k] then
			node[k] = { item = item, axis = axis, side = side }
			parent[k] = k
		end
		return k
	end
	for _, is in issues do
		if (is.kind == "gap" or is.kind == "overlap") and not gone[is.a.id] and not gone[is.b.id] then
			local a, c, axis = is.a, is.b, is.axis
			local aBelow = (a.b[axis] + a.b[axis + 3]) < (c.b[axis] + c.b[axis + 3])
			local ka = reg(a, axis, if aBelow then 1 else -1)
			local kc = reg(c, axis, if aBelow then -1 else 1)
			local ra, rc = find(ka), find(kc)
			if ra ~= rc then
				parent[ra] = rc
			end
		end
	end
	local groups = {}
	for k, nd in node do
		local r = find(k)
		groups[r] = groups[r] or {}
		table.insert(groups[r], nd)
	end
	local function faceAt(nd)
		local bx = box(nd.item.part)
		return if nd.side > 0 then bx[nd.axis + 3] else bx[nd.axis]
	end
	for _, members in groups do
		-- skip a group that holds both faces of one part on the same axis (it would be squashed)
		local seenPart, squash = {}, false
		for _, nd in members do
			local key = nd.item.id * 4 + nd.axis
			if seenPart[key] then
				squash = true
			end
			seenPart[key] = true
		end
		if not squash then
			-- THE RULE THAT KEEPS THE FLOORS WHERE THEY ARE: the top face of a part (Y axis, max side) is where someone may be
			-- standing, so it never moves. If the group holds top faces, one of them is the anchor; two top faces at different
			-- heights mean the group cannot be mended without moving a floor, and it is left alone.
			local anchor, topCoord, clash = nil, nil, false
			for _, nd in members do
				if nd.axis == 2 and nd.side > 0 then
					local y = faceAt(nd)
					if topCoord and math.abs(topCoord - y) > 0.001 then
						clash = true
					end
					if not anchor or nd.item.vol > anchor.item.vol then
						anchor = nd
					end
					topCoord = topCoord or y
				end
			end
			if not clash then
				if not anchor then
					anchor = members[1]
					for _, nd in members do
						if nd.item.vol > anchor.item.vol then
							anchor = nd
						end
					end
				end
				local rep = faceAt(anchor)
				for _, nd in members do
					if nd ~= anchor and not (nd.axis == 2 and nd.side > 0) then
						local cur = faceAt(nd)
						if math.abs(cur - rep) <= tol + 0.001 and moveFace(nd.item, nd.axis, nd.side, rep) then
							changed += 1
						end
					end
				end
			end
		end
	end

	ChangeHistoryService:SetWaypoint("SeamAudit after")
	return changed
end

-- The surface heights a walker would meet: a grid of rays straight down. Compare before and after a mend to prove the floors,
-- stairs and ramps did not move. rect = { minX, minZ, maxX, maxZ }; returns { [key] = y }.
function SeamAudit.heights(root: Instance, rect: { number }, step: number, topY: number)
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { root }
	local map = {}
	local clock = os.clock()
	local n = 0
	local x = rect[1]
	while x <= rect[3] do
		local z = rect[2]
		while z <= rect[4] do
			local hit = workspace:Raycast(Vector3.new(x, topY, z), Vector3.new(0, -2000, 0), params)
			map[n] = hit and hit.Position.Y or -1e9
			n += 1
			z += step
		end
		x += step
		if os.clock() - clock > 6 then
			task.wait()
			clock = os.clock()
		end
	end
	return map, n
end

function SeamAudit.compare(a: { number }, b: { number }, n: number)
	local moved, big = 0, 0
	local worst = 0
	for i = 0, n - 1 do
		local d = math.abs((a[i] or -1e9) - (b[i] or -1e9))
		if d > 1e8 then
			d = 1e9 -- one has a surface where the other has none
		end
		if d > 0.02 then
			moved += 1
			if d > 0.3 then
				big += 1
			end
			worst = math.max(worst, math.min(d, 1e9))
		end
	end
	return { rays = n, moved = moved, moved_over_0_3 = big, worst = worst }
end

return SeamAudit
