--[[
	BuildCatacombsProps — the second half of `tools/BuildCatacombs.luau` (run after its "plan"). It is loaded with the first
	tool's result as its argument (`local b = ...`) and returns { props, scares, zones }, each a function that returns a short
	report. See BuildCatacombs.luau for how the two are run.

	  props    what lies in the maze: the marks the errand looks for (chests, racks, levers, ropes and bells, tables for the pages,
	           nests, caches), the dressing of each hall, bones and cobwebs along the passages
	  scares   eyes and a grin on the walls at the ends of long passages, words in red, blood
	  zones    the dark (light zones) and the places the runtime looks for (`Marks.DoctorStart`)
]]

local b = ...
local c = b.ctx
local cfg, plan, maze = c.cfg, c.plan, c.maze
local part, ball, pillar, folder, candle = c.part, c.ball, c.pillar, c.folder, c.candle
local rng = c.rng
local col = c.colours
local U = cfg.Layout.Unit
local FLOOR = cfg.Layout.FloorY
local H = cfg.Layout.PassageHeight
local marks = c.marks
local props = c.propsFolder
local scares = c.scaresFolder

local DIR = {
	E = Vector3.new(1, 0, 0),
	W = Vector3.new(-1, 0, 0),
	S = Vector3.new(0, 0, -1),
	N = Vector3.new(0, 0, 1),
}
local DIRS = { "E", "S", "W", "N" }
local OPP = { E = "W", W = "E", N = "S", S = "N" }

local function featuresOf(kind: string): { any }
	local out = {}
	for _, f in plan.Features do
		if f.kind == kind then
			table.insert(out, f)
		end
	end
	return out
end

-- A cell's walls: which sides are closed (shut ways count as open: they have models of their own)
local function closedSides(cc: number, r: number): { string }
	local out = {}
	for _, d in DIRS do
		if not c.rawOpen(cc, r, d) then
			table.insert(out, d)
		end
	end
	return out
end

-- Where a prop stands against a wall of a cell, facing into the cell: a CFrame at the floor, local -Z toward the middle.
local function against(cc: number, r: number, side: string, inset: number?): CFrame
	local centre = c.cellCentre(cc, r)
	local pos = centre + DIR[side] * (U - (inset or 0.6))
	return CFrame.lookAt(pos, pos - DIR[side])
end

-- The side a dead end should keep its things against: opposite the one way out.
local function farSide(cc: number, r: number): string
	for _, d in DIRS do
		if c.rawOpen(cc, r, d) then
			local far = OPP[d]
			if not c.rawOpen(cc, r, far) then
				return far
			end
		end
	end
	local closed = closedSides(cc, r)
	return closed[1] or "N"
end

local function model(parent: Instance, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

--==========================================================================
-- Single props. `cf` is on the floor, local -Z toward the middle of the cell, +Z toward the wall.
--==========================================================================
local function chest(parent: Instance, cf: CFrame, name: string): Model
	local m = model(parent, name)
	local bodyCf = cf * CFrame.new(0, FLOOR - cf.Y + 0.9, 0.9)
	local body = part(m, "Body", Vector3.new(3, 1.8, 1.9), bodyCf, col.WOOD, Enum.Material.Wood, true)
	local lid = part(m, "Lid", Vector3.new(3.1, 0.55, 2.0), bodyCf * CFrame.new(0, 1.15, 0), col.WOOD_DARK, Enum.Material.Wood, true)
	for _, dx in { -0.9, 0.9 } do
		part(m, "Band", Vector3.new(0.25, 2.0, 2.05), bodyCf * CFrame.new(dx, 0.1, 0), col.IRON, Enum.Material.Metal, false)
	end
	m.PrimaryPart = body
	_ = lid
	return m
end

local function rack(parent: Instance, cf: CFrame, name: string): Model
	local m = model(parent, name)
	local base = cf * CFrame.new(0, FLOOR - cf.Y, 0.5)
	local post1 = part(m, "Post", Vector3.new(0.35, 6, 0.35), base * CFrame.new(-2, 3, 0), col.WOOD_DARK, Enum.Material.Wood, true)
	part(m, "Post", Vector3.new(0.35, 6, 0.35), base * CFrame.new(2, 3, 0), col.WOOD_DARK, Enum.Material.Wood, true)
	part(m, "Beam", Vector3.new(4.6, 0.35, 0.35), base * CFrame.new(0, 5.2, 0), col.WOOD, Enum.Material.Wood, true)
	part(m, "Beam", Vector3.new(4.6, 0.35, 0.35), base * CFrame.new(0, 2.4, 0), col.WOOD, Enum.Material.Wood, true)
	-- tools on the rack: a pick, a hammer, a saw, a shovel
	part(m, "PickShaft", Vector3.new(0.18, 3.2, 0.18), base * CFrame.new(-1.4, 3.7, -0.3) * CFrame.Angles(0, 0, math.rad(8)), col.WOOD, Enum.Material.Wood, false)
	part(m, "PickHead", Vector3.new(1.4, 0.22, 0.22), base * CFrame.new(-1.3, 5.2, -0.3), col.IRON, Enum.Material.Metal, false)
	part(m, "HammerShaft", Vector3.new(0.18, 2.4, 0.18), base * CFrame.new(-0.3, 3.6, -0.3), col.WOOD, Enum.Material.Wood, false)
	part(m, "HammerHead", Vector3.new(0.7, 0.5, 0.5), base * CFrame.new(-0.3, 4.9, -0.3), col.IRON, Enum.Material.Metal, false)
	part(m, "Saw", Vector3.new(2.2, 0.5, 0.06), base * CFrame.new(0.9, 3.4, -0.3) * CFrame.Angles(0, 0, math.rad(-12)), Color3.fromRGB(110, 106, 100), Enum.Material.Metal, false)
	part(m, "ShovelShaft", Vector3.new(0.18, 3.6, 0.18), base * CFrame.new(1.8, 3.6, -0.3), col.WOOD, Enum.Material.Wood, false)
	part(m, "ShovelBlade", Vector3.new(0.7, 0.9, 0.1), base * CFrame.new(1.8, 1.6, -0.3), col.IRON, Enum.Material.Metal, false)
	m.PrimaryPart = post1
	return m
end

local function lever(parent: Instance, cf: CFrame, name: string): Model
	local m = model(parent, name)
	local wall = cf * CFrame.new(0, 0, 1.1)
	local baseCf = wall * CFrame.new(0, FLOOR - cf.Y + 2.6, 0)
	local base = part(m, "Base", Vector3.new(1.4, 0.6, 0.6), baseCf, col.IRON, Enum.Material.Metal, false)
	part(m, "Plate", Vector3.new(2.2, 2.6, 0.3), wall * CFrame.new(0, FLOOR - cf.Y + 2.5, 0.35), col.STONE_DARK, Enum.Material.Slate, true)
	local length = 3
	local handle = part(m, "Handle", Vector3.new(0.3, length, 0.3), baseCf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(35)) * CFrame.new(0, length / 2, 0), col.WOOD_DARK, Enum.Material.Wood, false)
	handle:SetAttribute("Length", length)
	ball(m, "Knob", 0.7, handle.CFrame * CFrame.new(0, length / 2, 0), col.IRON, Enum.Material.Metal)
	m.PrimaryPart = base
	return m
end

-- A bell dead end: a rope with a knob to pull, and a bronze bell hung from a beam (rung from another dead end).
local function bellEnd(parent: Instance, cf: CFrame, name: string): Model
	local m = model(parent, name)
	local f = cf * CFrame.new(0, FLOOR - cf.Y, 0)
	part(m, "Beam", Vector3.new(5, 0.5, 0.5), f * CFrame.new(0, H - 0.6, 1.0), col.WOOD_DARK, Enum.Material.Wood, false)
	local bell = part(m, "Bell", Vector3.new(1.8, 2.0, 1.8), f * CFrame.new(1.2, H - 2.2, 1.0), Color3.fromRGB(150, 112, 52), Enum.Material.Metal, false)
	bell.Shape = Enum.PartType.Ball
	part(m, "Clapper", Vector3.new(0.3, 0.9, 0.3), f * CFrame.new(1.2, H - 3.0, 1.0), col.IRON, Enum.Material.Metal, false)
	local rope = part(m, "Rope", Vector3.new(0.18, H - 2.4, 0.18), f * CFrame.new(-1.4, (H - 2.4) / 2 + 2.4, 0.6), Color3.fromRGB(150, 128, 84), Enum.Material.Fabric, false)
	ball(m, "Knob", 0.6, f * CFrame.new(-1.4, 2.2, 0.6), Color3.fromRGB(120, 92, 56), Enum.Material.Wood)
	m.PrimaryPart = rope
	return m
end

local function paperTable(parent: Instance, cf: CFrame, name: string): Model
	local m = model(parent, name)
	local f = cf * CFrame.new(0, FLOOR - cf.Y, 1.0)
	local top = part(m, "Top", Vector3.new(2.6, 0.35, 1.6), f * CFrame.new(0, 2.3, 0), col.WOOD, Enum.Material.Wood, true)
	for _, dx in { -1.1, 1.1 } do
		part(m, "Leg", Vector3.new(0.3, 2.2, 1.3), f * CFrame.new(dx, 1.1, 0), col.WOOD_DARK, Enum.Material.Wood, true)
	end
	candle(m, f.Position + Vector3.new(0, 2.5, 0) + f.RightVector * 0.8, "PaperCandle")
	m.PrimaryPart = top
	return m
end

local function nestPit(parent: Instance, cf: CFrame, name: string): Part
	local f = cf * CFrame.new(0, FLOOR - cf.Y, 0.2)
	local pit = part(parent, name, Vector3.new(3, 0.5, 3), f * CFrame.new(0, 0.2, 0), Color3.fromRGB(26, 22, 20), Enum.Material.Slate, false)
	pit.Transparency = 0.3
	-- bones and rags round it: the dead lie here until a body comes near
	for k = 1, 9 do
		local a = rng:NextNumber(0, math.pi * 2)
		local d = rng:NextNumber(1.3, 2.4)
		local bone = part(props, "Bone", Vector3.new(rng:NextNumber(0.2, 0.3), 0.2, rng:NextNumber(0.8, 1.5)), f * CFrame.new(math.cos(a) * d, 0.15, math.sin(a) * d) * CFrame.Angles(0, rng:NextNumber(0, 6), math.rad(rng:NextNumber(-8, 8))), col.BONE, Enum.Material.Slate, false)
		bone.Name = "Bone"
	end
	for k = 1, 3 do
		part(props, "Rag", Vector3.new(rng:NextNumber(1.2, 2), 0.1, rng:NextNumber(0.8, 1.4)), f * CFrame.new(rng:NextNumber(-1.8, 1.8), 0.12, rng:NextNumber(-1.8, 1.8)) * CFrame.Angles(0, rng:NextNumber(0, 6), 0), col.CLOTH, Enum.Material.Fabric, false)
	end
	return pit
end

--==========================================================================
-- Dressing: scattered things
--==========================================================================
local function skull(parent: Instance, at: Vector3)
	ball(parent, "Skull", 0.9, CFrame.new(at + Vector3.new(0, 0.45, 0)), col.BONE, Enum.Material.Slate)
	part(parent, "Jaw", Vector3.new(0.6, 0.25, 0.5), CFrame.new(at + Vector3.new(0, 0.12, 0.3)), col.BONE, Enum.Material.Slate, false)
end

local function boneHeap(parent: Instance, at: Vector3, count: number)
	for _ = 1, count do
		local p = at + Vector3.new(rng:NextNumber(-1.4, 1.4), rng:NextNumber(0.1, 0.5), rng:NextNumber(-1.4, 1.4))
		if rng:NextNumber() < 0.25 then
			skull(parent, p)
		else
			part(parent, "Bone", Vector3.new(0.22, 0.22, rng:NextNumber(0.9, 1.8)), CFrame.new(p) * CFrame.Angles(math.rad(rng:NextNumber(-20, 20)), rng:NextNumber(0, 6.28), math.rad(rng:NextNumber(-20, 20))), col.BONE, Enum.Material.Slate, false)
		end
	end
end

local function barrel(parent: Instance, at: Vector3)
	local p = pillar(parent, "Barrel", 2.1, 2.6, at + Vector3.new(0, 1.3, 0), col.WOOD_DARK, Enum.Material.Wood, true)
	for _, y in { 0.5, 2.1 } do
		pillar(parent, "Hoop", 2.2, 0.14, at + Vector3.new(0, y, 0), col.IRON, Enum.Material.Metal, false)
	end
	return p
end

local function crate(parent: Instance, at: Vector3)
	local s = rng:NextNumber(1.6, 2.4)
	part(parent, "Crate", Vector3.new(s, s, s), CFrame.new(at + Vector3.new(0, s / 2, 0)) * CFrame.Angles(0, rng:NextNumber(0, 6.28), 0), col.WOOD, Enum.Material.Wood, true)
end

local function web(parent: Instance, corner: Vector3, dirA: Vector3, dirB: Vector3)
	local p = part(parent, "Web", Vector3.new(2.6, 0.04, 2.6), CFrame.lookAt(corner + (dirA + dirB) * 1.0, corner + (dirA + dirB) * 1.0 + Vector3.yAxis) , Color3.fromRGB(190, 188, 180), Enum.Material.Fabric, false)
	p.Transparency = 0.75
end

local function sarcophagus(parent: Instance, cf: CFrame)
	local base = part(parent, "Sarcophagus", Vector3.new(3, 2.2, 6.6), cf * CFrame.new(0, 1.1, 0), col.STONE, Enum.Material.Slate, true)
	part(parent, "Lid", Vector3.new(3.3, 0.6, 7), cf * CFrame.new(rng:NextNumber(-0.5, 0.5), 2.45, rng:NextNumber(-0.4, 0.4)) * CFrame.Angles(0, math.rad(rng:NextNumber(-8, 8)), 0), col.STONE_DARK, Enum.Material.Slate, true)
	_ = base
end

local function cot(parent: Instance, cf: CFrame)
	part(parent, "CotFrame", Vector3.new(2.6, 0.3, 6), cf * CFrame.new(0, 1.3, 0), col.WOOD, Enum.Material.Wood, true)
	for _, dx in { -1.1, 1.1 } do
		for _, dz in { -2.6, 2.6 } do
			part(parent, "CotLeg", Vector3.new(0.3, 1.3, 0.3), cf * CFrame.new(dx, 0.65, dz), col.WOOD_DARK, Enum.Material.Wood, false)
		end
	end
	part(parent, "Cloth", Vector3.new(2.3, 0.2, 5.4), cf * CFrame.new(0, 1.55, 0.2) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-3, 3))), col.CLOTH, Enum.Material.Fabric, false)
	-- somebody was lying here
	boneHeap(parent, (cf * CFrame.new(0, 1.7, 0.4)).Position, 5)
end

local function cart(parent: Instance, cf: CFrame)
	part(parent, "CartBox", Vector3.new(3.4, 1.8, 5.2), cf * CFrame.new(0, 2.1, 0), col.WOOD, Enum.Material.Wood, true)
	part(parent, "CartBand", Vector3.new(3.5, 0.3, 5.3), cf * CFrame.new(0, 2.7, 0), col.IRON, Enum.Material.Metal, false)
	for _, dx in { -1.75, 1.75 } do
		for _, dz in { -1.7, 1.7 } do
			local w = pillar(parent, "Wheel", 1.7, 0.3, (cf * CFrame.new(dx, 0.9, dz)).Position, col.IRON, Enum.Material.Metal, false)
			w.CFrame = cf * CFrame.new(dx, 0.9, dz) * CFrame.Angles(0, math.rad(90), math.rad(90))
		end
	end
	-- ore in it
	for k = 1, 6 do
		part(parent, "Ore", Vector3.new(rng:NextNumber(0.6, 1.2), rng:NextNumber(0.5, 1), rng:NextNumber(0.6, 1.2)), cf * CFrame.new(rng:NextNumber(-1.1, 1.1), 3.3, rng:NextNumber(-1.9, 1.9)) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), Color3.fromRGB(82, 76, 70), Enum.Material.Slate, false)
	end
end

local function cellBars(parent: Instance, from: Vector3, to: Vector3)
	-- a run of iron bars between two floor points: a cell front (for the eye only: the Doctor walks the middle of the cells, so nothing here collides)
	local len = (to - from).Magnitude
	local dir = (to - from).Unit
	local n = math.floor(len / 0.7)
	for k = 0, n do
		local at = from + dir * (k * 0.7)
		part(parent, "Bar", Vector3.new(0.18, H - 0.8, 0.18), CFrame.new(at + Vector3.new(0, (H - 0.8) / 2, 0)), col.IRON, Enum.Material.Metal, false)
	end
	for _, y in { 1.0, 3.8, H - 1.0 } do
		part(parent, "BarRail", Vector3.new(0.25, 0.25, len), CFrame.lookAt((from + to) / 2 + Vector3.new(0, y, 0), to + Vector3.new(0, y, 0)), col.IRON, Enum.Material.Metal, false)
	end
end

local function desk(parent: Instance, cf: CFrame)
	part(parent, "DeskTop", Vector3.new(5.5, 0.4, 2.6), cf * CFrame.new(0, 2.9, 0), col.WOOD_DARK, Enum.Material.Wood, true)
	for _, dx in { -2.4, 2.4 } do
		part(parent, "DeskLeg", Vector3.new(0.5, 2.8, 2.2), cf * CFrame.new(dx, 1.4, 0), col.WOOD_DARK, Enum.Material.Wood, true)
	end
	for k = 1, 4 do
		part(parent, "Book", Vector3.new(0.9, 0.3, 0.65), cf * CFrame.new(-1.8 + k * 0.5, 3.25 + (k % 2) * 0.01, rng:NextNumber(-0.6, 0.6)) * CFrame.Angles(0, rng:NextNumber(-0.4, 0.4), 0), Color3.fromRGB(70 + k * 12, 40, 34), Enum.Material.Fabric, false)
	end
	-- the doctor's instruments: a bone saw, a jar, a bellows
	part(parent, "Saw", Vector3.new(1.4, 0.12, 0.3), cf * CFrame.new(1.2, 3.15, 0.3), Color3.fromRGB(120, 116, 110), Enum.Material.Metal, false)
	pillar(parent, "Jar", 0.6, 1.0, (cf * CFrame.new(2.0, 3.6, -0.5)).Position, Color3.fromRGB(140, 160, 130), Enum.Material.Glass, false).Transparency = 0.5
end

local function shelf(parent: Instance, cf: CFrame, length: number)
	for _, y in { 1.5, 3.4, 5.3 } do
		part(parent, "Shelf", Vector3.new(length, 0.25, 1.1), cf * CFrame.new(0, y, 0), col.WOOD, Enum.Material.Wood, false)
	end
	for _, dx in { -length / 2 + 0.2, length / 2 - 0.2 } do
		part(parent, "ShelfPost", Vector3.new(0.3, 5.5, 1.1), cf * CFrame.new(dx, 2.75, 0), col.WOOD_DARK, Enum.Material.Wood, false)
	end
	for k = 1, math.floor(length / 0.9) do
		local y = ({ 1.8, 3.7, 5.6 })[rng:NextInteger(1, 3)]
		if rng:NextNumber() < 0.7 then
			pillar(parent, "Jar", 0.5, rng:NextNumber(0.5, 0.9), (cf * CFrame.new(-length / 2 + k * 0.9, y + 0.2, 0)).Position, Color3.fromRGB(110, 130, 100), Enum.Material.Glass, false).Transparency = 0.55
		else
			skull(parent, (cf * CFrame.new(-length / 2 + k * 0.9, y - 0.05, 0)).Position)
		end
	end
end

-- Is the world point (x, z) inside a wall or a pillar?
local function solidAt(x: number, z: number): boolean
	local i = math.floor((x - c.unitX(0)) / U)
	local j = math.floor((c.unitZ(0) - z) / U)
	return c.isSolid(i, j)
end

-- A random place in a hall where a footprint of half-sizes (hx, hz), turned by `yaw`, touches no wall and no pillar.
local function hallSpot(hall: any, hx: number, hz: number, yaw: number): Vector3?
	local cos, sin = math.abs(math.cos(yaw)), math.abs(math.sin(yaw))
	local ex = hx * cos + hz * sin + 0.3
	local ez = hx * sin + hz * cos + 0.3
	local x0, x1 = c.unitX(3 * hall.c0 + 1), c.unitX(3 * hall.c1 + 3)
	local z1, z0 = c.unitZ(3 * hall.r1 + 3), c.unitZ(3 * hall.r0 + 1)
	for _ = 1, 80 do
		local x = rng:NextNumber(x0 + ex, x1 - ex)
		local z = rng:NextNumber(z1 + ez, z0 - ez)
		local clear = true
		for fx = -1, 1 do
			for fz = -1, 1 do
				if solidAt(x + fx * ex, z + fz * ez) then
					clear = false
				end
			end
		end
		if clear then
			return Vector3.new(x, FLOOR, z)
		end
	end
	return nil
end

--==========================================================================
-- PROPS
--==========================================================================
local function buildProps()
	local report = {}

	-- the key places (chests in the plague ward and the gaol) and the axe places (racks in the quarry)
	for _, f in featuresOf("keyspot") do
		chest(marks, against(f.c, f.r, farSide(f.c, f.r)), f.id)
	end
	for _, f in featuresOf("axespot") do
		rack(marks, against(f.c, f.r, farSide(f.c, f.r)), f.id)
	end
	for _, f in featuresOf("lever") do
		lever(marks, against(f.c, f.r, farSide(f.c, f.r), 0.5), f.id)
	end
	for _, f in featuresOf("bell") do
		bellEnd(marks, against(f.c, f.r, farSide(f.c, f.r)), f.id)
	end
	local pages = featuresOf("paper")
	for i, f in pages do
		paperTable(marks, against(f.c, f.r, farSide(f.c, f.r)), "Paper" .. i)
	end
	for _, f in featuresOf("nest") do
		nestPit(marks, against(f.c, f.r, farSide(f.c, f.r), 1.5), f.id)
	end
	for _, f in featuresOf("pocket") do
		chest(marks, against(f.c, f.r, farSide(f.c, f.r)), f.id)
		-- a pocket is a refuge: a candle, a blanket
		candle(props, c.cellCentre(f.c, f.r) + Vector3.new(0, 0, 0) + DIR[farSide(f.c, f.r)] * -1.5, "PocketCandle")
		part(props, "Blanket", Vector3.new(3, 0.12, 2), CFrame.new(c.cellCentre(f.c, f.r) + Vector3.new(0, 0.1, 0)), col.CLOTH, Enum.Material.Fabric, false)
	end
	table.insert(report, "marks: keys, axes, levers, bells, tables, nests, pockets")

	-- the halls
	local hallProps = 0
	for _, hall in plan.Halls do
		local id = hall.id
		local n = 0
		-- `count` things whose footprint is hx by hz (before turning); each is told where and which way it lies
		local function many(count: number, hx: number, hz: number, fn: (Vector3, number) -> ())
			for _ = 1, count do
				local yaw = rng:NextInteger(0, 1) * math.pi / 2
				local at = hallSpot(hall, hx, hz, yaw)
				if at then
					fn(at, yaw)
					n += 1
				end
			end
		end
		if id == "ossuary" then
			many(14, 1.6, 1.6, function(at) boneHeap(props, at, 9) end)
			many(6, 1.1, 1.1, function(at) barrel(props, at) end)
		elseif id == "ward" then
			many(8, 1.4, 3.1, function(at, yaw) cot(props, CFrame.new(at) * CFrame.Angles(0, yaw, 0)) end)
			many(3, 1.4, 1.4, function(at) crate(props, at) end)
		elseif id == "quarry" then
			many(3, 1.9, 2.9, function(at, yaw) cart(props, CFrame.new(at) * CFrame.Angles(0, yaw, 0)) end)
			many(8, 1.4, 1.4, function(at) crate(props, at) end)
			many(8, 1.9, 1.9, function(at)
				for k = 1, 5 do
					part(props, "Rock", Vector3.new(rng:NextNumber(1, 2.6), rng:NextNumber(0.8, 2), rng:NextNumber(1, 2.6)), CFrame.new(at + Vector3.new(rng:NextNumber(-1.5, 1.5), 0.6, rng:NextNumber(-1.5, 1.5))) * CFrame.Angles(rng:NextNumber(0, 3), rng:NextNumber(0, 3), 0), Color3.fromRGB(84, 74, 62), Enum.Material.Rock, true)
				end
			end)
			-- rails across the hall
			local x0, x1 = c.unitX(3 * hall.c0 + 1), c.unitX(3 * hall.c1 + 3)
			local zr = c.unitZ(3 * hall.r0 + 3)
			for _, dz in { -0.7, 0.7 } do
				part(props, "Rail", Vector3.new(x1 - x0, 0.15, 0.2), CFrame.new((x0 + x1) / 2, FLOOR + 0.12, zr + dz), col.IRON, Enum.Material.Metal, false)
			end
			for k = 0, math.floor((x1 - x0) / 2) do
				part(props, "Sleeper", Vector3.new(0.5, 0.12, 2.2), CFrame.new(x0 + k * 2, FLOOR + 0.07, zr), col.WOOD_DARK, Enum.Material.Wood, false)
			end
		elseif id == "gaol" then
			-- cell fronts of bars with a skeleton behind each, chains from the wall
			for k = 0, 2 do
				local ci = hall.c0 + 1 + k
				local from = Vector3.new(c.unitX(3 * ci + 1), FLOOR, c.unitZ(3 * (hall.r0 + 1) + 1))
				local to = Vector3.new(c.unitX(3 * ci + 3), FLOOR, c.unitZ(3 * (hall.r0 + 1) + 1))
				cellBars(props, from, to)
				boneHeap(props, from:Lerp(to, 0.5) + Vector3.new(0, 0, 2.2), 7)
				for ch = 1, 3 do
					part(props, "Chain", Vector3.new(0.12, 2.4, 0.12), CFrame.new(from:Lerp(to, 0.5) + Vector3.new(ch * 0.25 - 0.5, 3.4, 3.1)), col.IRON, Enum.Material.Metal, false)
				end
				n += 1
			end
			many(4, 1.2, 1.2, function(at) barrel(props, at) end)
		elseif id == "crypt" then
			many(8, 1.8, 3.7, function(at, yaw) sarcophagus(props, CFrame.new(at) * CFrame.Angles(0, yaw, 0)) end)
			many(6, 1.6, 1.6, function(at) boneHeap(props, at, 5) end)
		elseif id == "study" then
			many(1, 3, 3.9, function(at, yaw)
				desk(props, CFrame.new(at) * CFrame.Angles(0, yaw, 0))
				local rot = CFrame.new(at) * CFrame.Angles(0, yaw, 0)
				part(props, "Chair", Vector3.new(1.6, 0.3, 1.6), rot * CFrame.new(0, 1.7, 2.6), col.WOOD, Enum.Material.Wood, false)
				part(props, "ChairBack", Vector3.new(1.6, 1.8, 0.3), rot * CFrame.new(0, 2.7, 3.4), col.WOOD, Enum.Material.Wood, false)
			end)
			many(5, 2.8, 0.8, function(at, yaw) shelf(props, CFrame.new(at) * CFrame.Angles(0, yaw, 0), 5) end)
			many(4, 1.4, 1.4, function(at) crate(props, at) end)
		end
		hallProps += n
		-- the Doctor's start: the middle of his study
		if id == cfg.Doctor.SpawnHall then
			local cx = math.floor((hall.c0 + hall.c1) / 2)
			local cr = math.floor((hall.r0 + hall.r1) / 2)
			local p = part(marks, "DoctorStart", Vector3.new(2, 2, 2), CFrame.new(c.cellCentre(cx, cr) + Vector3.new(0, 1, 0)), Color3.new(1, 1, 1), Enum.Material.SmoothPlastic, false)
			p.Transparency = 1
		end
	end
	table.insert(report, hallProps .. " hall things")

	-- along the passages: bones, barrels, crates, webs, puddles
	local scattered = 0
	for r = 0, plan.Rows - 1 do
		for cc = 0, plan.Cols - 1 do
			if maze:hallAt(cc, r) == nil and not (cc == 0 and r >= 9) then
				local roll = rng:NextNumber()
				local centre = c.cellCentre(cc, r)
				local closed = closedSides(cc, r)
				if roll < 0.10 then
					boneHeap(props, centre + Vector3.new(rng:NextNumber(-1.8, 1.8), 0, rng:NextNumber(-1.8, 1.8)), rng:NextInteger(4, 9))
					scattered += 1
				elseif roll < 0.15 and #closed > 0 then
					local cf = against(cc, r, closed[rng:NextInteger(1, #closed)], 1.4)
					barrel(props, cf.Position)
					scattered += 1
				elseif roll < 0.19 and #closed > 0 then
					crate(props, against(cc, r, closed[rng:NextInteger(1, #closed)], 1.4).Position)
					scattered += 1
				elseif roll < 0.27 and #closed >= 2 then
					-- a web in a corner: between two closed sides at the roof
					local a, bb = closed[1], closed[2]
					web(props, centre + DIR[a] * (U - 0.2) + DIR[bb] * (U - 0.2) + Vector3.new(0, H - 0.4, 0), -DIR[a], -DIR[bb])
					scattered += 1
				elseif roll < 0.31 then
					local pd = rng:NextNumber(2.2, 4.4)
					local puddle = pillar(props, "Puddle", pd, 0.05, centre + Vector3.new(rng:NextNumber(-1.5, 1.5), 0.04, rng:NextNumber(-1.5, 1.5)), Color3.fromRGB(34, 46, 52), Enum.Material.Glass, false)
					puddle.Transparency = 0.25
					puddle.Reflectance = 0.2
					scattered += 1
				end
			end
		end
	end
	table.insert(report, scattered .. " things along the passages")
	return report
end

--==========================================================================
-- SCARES
--==========================================================================
-- How many cells a straight run goes on from (cc, r) in `dir`
local function runLength(cc: number, r: number, dir: string): number
	local n = 0
	local x, y = cc, r
	while c.rawOpen(x, y, dir) do
		n += 1
		x += (if dir == "E" then 1 elseif dir == "W" then -1 else 0)
		y += (if dir == "S" then 1 elseif dir == "N" then -1 else 0)
	end
	return n
end

local function eyesAndGrin(parent: Instance, wallPoint: Vector3, normal: Vector3)
	-- the wall faces along `normal` (into the passage); built on the wall at the height of the Doctor's own eyes
	local base = CFrame.lookAt(wallPoint + normal * 0.12, wallPoint + normal * 2)
	local y = FLOOR + 5.4
	local m = model(parent, "Watcher")
	for _, dx in { -1.0, 1.0 } do
		local e = part(m, "Eye", Vector3.new(0.95, 0.6, 0.12), base * CFrame.new(dx, y - FLOOR, 0), Color3.fromRGB(255, 255, 255), Enum.Material.Neon, false)
		e.Shape = Enum.PartType.Ball
		e.Size = Vector3.new(0.95, 0.6, 0.14)
	end
	-- a broken grin: a crooked curve of teeth, some of them missing
	for k = -6, 6 do
		if rng:NextNumber() > 0.12 then
			local x = k * 0.34
			local curve = 0.95 * (1 - (k / 6) ^ 2)
			local tooth = part(m, "Tooth", Vector3.new(0.17, rng:NextNumber(0.35, 0.7), 0.1), base * CFrame.new(x + rng:NextNumber(-0.05, 0.05), y - FLOOR - 1.2 - curve + (if k % 2 == 0 then 0.08 else -0.08), 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-10, 10) - k * 3)), Color3.fromRGB(226, 222, 204), Enum.Material.Neon, false)
			tooth.Name = "Tooth"
		end
	end
end

local function buildScares()
	local report = {}

	-- eyes: at the end of a long straight passage, on the wall it runs into
	local candidates = {}
	for r = 0, plan.Rows - 1 do
		for cc = 0, plan.Cols - 1 do
			if maze:hallAt(cc, r) == nil and not (cc == 0 and r >= 8) then
				for _, d in DIRS do
					local n = runLength(cc, r, d)
					-- the cell at the end of a run: the run came toward it along d's opposite
					if n == 0 then
						local back = OPP[d]
						local length = runLength(cc, r, back)
						if length >= 4 and not c.rawOpen(cc, r, d) then
							table.insert(candidates, { cc = cc, r = r, d = d, length = length })
						end
					end
				end
			end
		end
	end
	for i = #candidates, 2, -1 do
		local j = rng:NextInteger(1, i)
		candidates[i], candidates[j] = candidates[j], candidates[i]
	end
	local placed = {}
	for _, cand in candidates do
		if #placed >= cfg.Decoys then
			break
		end
		local far = true
		for _, p in placed do
			if math.abs(p.cc - cand.cc) + math.abs(p.r - cand.r) < 6 then
				far = false
			end
		end
		if far then
			table.insert(placed, cand)
			local centre = c.cellCentre(cand.cc, cand.r)
			eyesAndGrin(scares, centre + DIR[cand.d] * (U - 0.05), -DIR[cand.d])
		end
	end
	table.insert(report, #placed .. " watchers on walls (of " .. #candidates .. " places)")

	-- words in red
	local words = cfg.Writings
	local wallSpots = {}
	for r = 0, plan.Rows - 1 do
		for cc = 0, plan.Cols - 1 do
			if maze:hallAt(cc, r) == nil and not (cc == 0 and r >= 9) then
				for _, d in closedSides(cc, r) do
					table.insert(wallSpots, { cc = cc, r = r, d = d })
				end
			end
		end
	end
	for i = #wallSpots, 2, -1 do
		local j = rng:NextInteger(1, i)
		wallSpots[i], wallSpots[j] = wallSpots[j], wallSpots[i]
	end
	local written = 0
	for i = 1, math.min(#words * 2, #wallSpots) do
		local spot = wallSpots[i]
		local word = words[(i - 1) % #words + 1]
		local centre = c.cellCentre(spot.cc, spot.r)
		local at = centre + DIR[spot.d] * (U - 0.06) + Vector3.new(0, rng:NextNumber(2.4, 5.2), 0)
		local sign = part(scares, "Words", Vector3.new(3.8, 1.3, 0.05), CFrame.lookAt(at, at - DIR[spot.d]) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-7, 7))), Color3.fromRGB(0, 0, 0), Enum.Material.SmoothPlastic, false)
		sign.Transparency = 1
		local gui = Instance.new("SurfaceGui")
		gui.Face = Enum.NormalId.Front
		gui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
		gui.PixelsPerStud = 40
		gui.LightInfluence = 1
		gui.Parent = sign
		local text = Instance.new("TextLabel")
		text.BackgroundTransparency = 1
		text.Size = UDim2.fromScale(1, 1)
		text.Text = word
		text.Font = Enum.Font.Creepster
		text.TextScaled = true
		text.TextColor3 = Color3.fromRGB(146, 18, 18)
		text.Parent = gui
		written += 1
	end
	table.insert(report, written .. " words in red")

	-- blood: on the floor, in drags along it, and smeared on the walls
	local stains = 0
	local spots = {}
	for r = 0, plan.Rows - 1 do
		for cc = 0, plan.Cols - 1 do
			if not (cc == 0 and r >= 9) then
				table.insert(spots, { cc, r })
			end
		end
	end
	for _ = 1, cfg.Stains do
		local s = spots[rng:NextInteger(1, #spots)]
		local centre = c.cellCentre(s[1], s[2])
		local kind = rng:NextInteger(1, 3)
		if kind == 1 then
			local d = rng:NextNumber(1.2, 3.2)
			local p = pillar(scares, "Pool", d, 0.05, centre + Vector3.new(rng:NextNumber(-1.8, 1.8), 0.05, rng:NextNumber(-1.8, 1.8)), col.BLOOD, Enum.Material.Slate, false)
			p.Color = col.BLOOD:Lerp(Color3.fromRGB(40, 6, 6), rng:NextNumber(0, 0.6))
		elseif kind == 2 then
			-- a drag: long, thin, wandering
			local yaw = rng:NextInteger(0, 1) * math.pi / 2 + rng:NextNumber(-0.1, 0.1)
			for k = 0, 3 do
				part(scares, "Drag", Vector3.new(1.0, 0.05, 2.6), CFrame.new(centre + Vector3.new(0, 0.05, 0)) * CFrame.Angles(0, yaw, 0) * CFrame.new(rng:NextNumber(-0.5, 0.5), 0, (k - 1.5) * 2.5), col.BLOOD, Enum.Material.Slate, false)
			end
		else
			local closed = closedSides(s[1], s[2])
			if #closed > 0 then
				local d = closed[rng:NextInteger(1, #closed)]
				local at = centre + DIR[d] * (U - 0.05) + Vector3.new(0, rng:NextNumber(1.6, 4.4), 0)
				part(scares, "Smear", Vector3.new(rng:NextNumber(0.6, 1.2), rng:NextNumber(1.6, 3.2), 0.05), CFrame.lookAt(at, at - DIR[d]), col.BLOOD, Enum.Material.Slate, false)
			end
		end
		stains += 1
	end
	table.insert(report, stains .. " stains")
	return report
end

--==========================================================================
-- ZONES
--==========================================================================
local function buildZones()
	local zones = c.zones
	for _, child in zones:GetChildren() do
		child:Destroy()
	end
	local function zone(name: string, centre: Vector3, size: Vector3, profile: string, priority: number)
		local z = part(zones, name, size, CFrame.new(centre), Color3.fromRGB(0, 0, 0), Enum.Material.SmoothPlastic, false)
		z.Transparency = 1
		z.CanQuery = false
		z.CanTouch = false
		z:SetAttribute("Profile", profile)
		z:SetAttribute("Priority", priority)
		game:GetService("CollectionService"):AddTag(z, "TLK_LightZone")
		return z
	end
	local down, up = cfg.Stairs.Down, cfg.Stairs.Up
	-- the whole underground: from the plan's floor to the ground, wall to wall
	zone("Catacombs", Vector3.new(-5, -38, -865), Vector3.new(345, 76, 270), "Catacombs", 5)
	-- the mouth of the cave and the top of the way out: the day goes out slowly
	zone("MouthDown", Vector3.new(down.X, 3, cfg.Mountain.FrontZ - 6), Vector3.new(34, 24, 40), "CatacombMouth", 1)
	zone("MouthUp", Vector3.new(up.X, 3, up.Z), Vector3.new(44, 24, 44), "CatacombMouth", 1)
	return { "3 light zones" }
end

return {
	props = buildProps,
	scares = buildScares,
	zones = buildZones,
}
