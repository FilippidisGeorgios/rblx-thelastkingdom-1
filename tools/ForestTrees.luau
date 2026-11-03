--[[
	ForestTrees — the tree grower of the King's Wood (docs/systems/Forest.md). A library, not a tool to run by itself:
	`tools/BuildForest.luau` loads it (the runner puts it in a ModuleScript beside the builder) and grows every tree with it.

	WHY GROWN, NOT GENERATED. The developer asked for generated, very realistic trees (2026-11-03). Whole trees made with
	`generate_mesh` came out as toys (a stump with a face, a lollipop beech), and so did a generated trunk and a log; the
	MATERIALS made with `generate_material` came out as real as a photograph (furrowed oak bark with moss, beech skin, leaf
	litter, needles). So each tree here is grown from its own seed out of plain shapes dressed in those generated materials:
	a trunk that leans and bends as it rises and narrows, a flared foot and roots that dive into the ground, limbs that fork
	into branches, and leaf masses at the branch ends. No two are alike.

	THE MATERIALS (MaterialService, made by generate_material, four variations each; one variation per tree):
	  OakBark (Wood) ......... oak and dead trunks, roots and limbs
	  BeechBark (Wood) ....... beech trunks
	  ForestMoss (Grass) ..... the moss on roots, on the foot of old trees, on logs
	  Foliage (LeafyGrass) ... leaf masses
	  SpruceNeedles (LeafyGrass) the spruce's tiers

	WHAT IS SOLID. Only the trunk's lower part collides and stops sight (an unseen-cost cylinder that is also the bark the
	lantern lights); roots, limbs and leaves neither collide nor stop sight nor can be queried, so the Huntsman's rays and the
	pathfinder see a clean trunk, and players walk over roots. Limbs and leaves cast no shadow (the lantern casts shadows: a
	crown of balls in its shadow map costs more than it gives).

	Each grown tree is a Model with the attributes `Kind` and `Seed`, pivoted at its foot.
]]

local MaterialService = game:GetService("MaterialService")

local Trees = {}

local function variants(base: string): { string }
	local list = {}
	for _, v in MaterialService:GetDescendants() do
		if v:IsA("MaterialVariant") and (v.Name == base or string.match(v.Name, "^" .. base .. "%d+$")) then
			table.insert(list, v.Name)
		end
	end
	table.sort(list)
	if #list == 0 then
		warn("ForestTrees: no MaterialVariant called " .. base .. " (run generate_material first)")
		list = { "" }
	end
	return list
end

local MATS: { [string]: { material: Enum.Material, names: { string } } } = {}
-- `tile`: studs one picture of the material covers (2026-11-03: at Roblox's own size the needles were as big as fern
-- fronds and the bark's furrows as wide as a hand)
local function mat(key: string, material: Enum.Material, base: string, tile: number)
	MATS[key] = { material = material, names = variants(base) }
	for _, v in MaterialService:GetDescendants() do
		if v:IsA("MaterialVariant") and table.find(MATS[key].names, v.Name) then
			v.StudsPerTile = tile
		end
	end
end
function Trees.loadMaterials()
	mat("oak", Enum.Material.Wood, "OakBark", 5)
	mat("beech", Enum.Material.Wood, "BeechBark", 6)
	mat("moss", Enum.Material.Grass, "ForestMoss", 4)
	mat("leaf", Enum.Material.LeafyGrass, "Foliage", 3.5)
	mat("needle", Enum.Material.LeafyGrass, "SpruceNeedles", 2.5)
end

type Look = { material: Enum.Material, variant: string, color: Color3 }

local function look(rng: Random, key: string, color: Color3): Look
	local m = MATS[key]
	return { material = m.material, variant = m.names[rng:NextInteger(1, #m.names)], color = color }
end

local function apply(p: BasePart, l: Look)
	p.Material = l.material
	p.MaterialVariant = l.variant
	p.Color = l.color
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
end

-- a cylinder from `a` to `b`, radius `r`, each end running on a little so a bend shows no notch
local function limb(parent: Instance, a: Vector3, b: Vector3, r: number, l: Look, rng: Random, solid: boolean): Part
	local d = b - a
	local len = d.Magnitude
	local p = Instance.new("Part")
	p.Name = if solid then "Trunk" else "Limb"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(len + r * 0.8, r * 2, r * 2)
	p.CFrame = CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0) * CFrame.Angles(rng:NextNumber(0, math.pi * 2), 0, 0)
	p.Anchored = true
	p.CanCollide = solid
	p.CanQuery = solid
	p.CanTouch = false
	p.CastShadow = solid or r > 0.7
	apply(p, l)
	p.Parent = parent
	return p
end

--[[
	A piece of trunk from `a` to `b`: blocks turned round the axis (two make an eight-sided trunk, three a twelve-sided
	one for the thickest). Not a cylinder: Roblox wraps a material ROUND a cylinder, so the bark's furrows ran round the
	trunk like the rings of a birch (2026-11-03, tried and seen; a material generated "sideways" came out the same). On a
	block standing along the trunk the furrows run up it, as they do on a tree.
]]
local function trunkPiece(parent: Instance, a: Vector3, b: Vector3, r: number, l: Look, rng: Random, solid: boolean): { Part }
	local d = b - a
	local len = d.Magnitude
	local up = d.Unit
	-- a frame whose Y runs along the trunk
	local side = if math.abs(up.Y) > 0.95 then Vector3.new(1, 0, 0) else Vector3.new(0, 1, 0):Cross(up).Unit
	local base = CFrame.fromMatrix((a + b) / 2, side, up)
	local sides = if r > 2 then 3 else 2
	local w = r * 2 * (if sides == 3 then 0.97 else 0.93)
	local turn = rng:NextNumber(0, math.pi / 2)
	local list = {}
	for k = 0, sides - 1 do
		local p = Instance.new("Part")
		p.Name = if solid then "Trunk" else "TrunkUpper"
		p.Size = Vector3.new(w, len + r * 0.5, w)
		p.CFrame = base * CFrame.Angles(0, turn + k * (math.pi / 2 / sides), 0)
		p.Anchored = true
		p.CanCollide = solid
		p.CanQuery = solid
		p.CanTouch = false
		p.CastShadow = true
		apply(p, l)
		p.Parent = parent
		table.insert(list, p)
	end
	return list
end
Trees.trunkPiece = function(parent: Instance, a: Vector3, b: Vector3, r: number, material: Enum.Material, variant: string, color: Color3, seed: number, solid: boolean): { Part }
	return trunkPiece(parent, a, b, r, { material = material, variant = variant, color = color }, Random.new(seed), solid)
end

-- a leaf mass: a squashed ball, turned at random
local function mass(parent: Instance, at: Vector3, w: number, h: number, l: Look, rng: Random): Part
	local p = Instance.new("Part")
	p.Name = "Leaves"
	p.Size = Vector3.new(w, h, w * rng:NextNumber(0.7, 1.1))
	p.CFrame = CFrame.new(at) * CFrame.Angles(rng:NextNumber(-0.6, 0.6), rng:NextNumber(0, math.pi * 2), rng:NextNumber(-0.6, 0.6))
	p.Anchored = true
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.CastShadow = false
	apply(p, l)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	p.Parent = parent
	return p
end

local UP = Vector3.new(0, 1, 0)

-- `dir` turned toward a random side by up to `amount` (a unit vector out)
local function wander(rng: Random, dir: Vector3, amount: number): Vector3
	local side = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-1, 1), rng:NextNumber(-1, 1))
	return (dir + side * amount).Unit
end

local function horizontal(angle: number, elevation: number): Vector3
	return Vector3.new(math.cos(angle) * math.cos(elevation), math.sin(elevation), math.sin(angle) * math.cos(elevation))
end

--[[
	THE SPECIES. Heights and radii in studs (a player is about 5 tall; a mature oak here is six to eight of them).
	  height     the trunk's length, min..max
	  r0         its radius at the foot; rTop the share of r0 left at the top
	  segs       how many pieces the trunk is made of (each bends a little)
	  lean       the most the whole tree leans, degrees
	  limbsFrom  where along the trunk the limbs begin (share of its height)
	  limbs      how many main limbs
	  elev       how steeply they rise, degrees above level
	  reach      how long a limb is, as a share of the height
	  leaves     the leaf masses' size, or nil for a dead tree
]]
local SPECIES = {
	-- an old oak: a short, very thick trunk, and great limbs that spread wide and low (2026-11-03: the first try was a thin
	-- tree with flat crowns, like an acacia)
	oak = { bark = "oak", barkColor = Color3.fromRGB(190, 180, 166), height = { 24, 32 }, r0 = { 2.3, 3.3 }, rTop = 0.34, segs = 5, wobble = 0.15, lean = 5,
		limbsFrom = 0.34, limbs = { 4, 6 }, elev = { 14, 40 }, reach = { 0.5, 0.72 }, subs = { 1, 2 }, roots = { 6, 8 }, rootLen = { 5, 8 },
		leaves = { 5.5, 8.5 }, leafColor = Color3.fromRGB(116, 132, 100), mossFoot = 0.6 },
	beech = { bark = "beech", barkColor = Color3.fromRGB(150, 150, 144), height = { 34, 46 }, r0 = { 1.5, 2.1 }, rTop = 0.32, segs = 5, wobble = 0.08, lean = 4,
		limbsFrom = 0.5, limbs = { 4, 6 }, elev = { 32, 60 }, reach = { 0.32, 0.46 }, subs = { 1, 2 }, roots = { 5, 7 }, rootLen = { 4, 7 },
		leaves = { 6, 9 }, leafColor = Color3.fromRGB(122, 140, 104), mossFoot = 0.4 },
	dead = { bark = "oak", barkColor = Color3.fromRGB(150, 146, 140), height = { 18, 28 }, r0 = { 1.3, 2.2 }, rTop = 0.25, segs = 5, wobble = 0.22, lean = 10,
		limbsFrom = 0.35, limbs = { 3, 5 }, elev = { 10, 50 }, reach = { 0.3, 0.55 }, subs = { 1, 3 }, roots = { 5, 7 }, rootLen = { 4, 8 },
		leaves = nil, mossFoot = 0.8, broken = 0.4 },
	orchard = { bark = "oak", barkColor = Color3.fromRGB(150, 138, 126), height = { 9, 13 }, r0 = { 0.7, 1.0 }, rTop = 0.35, segs = 4, wobble = 0.3, lean = 14,
		limbsFrom = 0.4, limbs = { 3, 5 }, elev = { 15, 45 }, reach = { 0.5, 0.75 }, subs = { 1, 2 }, roots = { 4, 5 }, rootLen = { 2, 3.5 },
		leaves = nil, mossFoot = 0.9, broken = 0.3 },
}
Trees.SPECIES = SPECIES

local function between(rng: Random, range: { number }): number
	return rng:NextNumber(range[1], range[2])
end

-- the foot: a flare that widens into the ground, and roots that dive into it
local function foot(model: Model, base: Vector3, r0: number, s: any, bark: Look, moss: Look, rng: Random)
	-- a low collar, mostly in the ground (a tall one read as a green box round the foot)
	for _, p in trunkPiece(model, base - Vector3.new(0, 1.4, 0), base + Vector3.new(0, 0.5, 0), r0 * 1.16, if rng:NextNumber() < s.mossFoot * 0.6 then moss else bark, rng, false) do
		p.Name = "Flare"
	end

	local n = rng:NextInteger(s.roots[1], s.roots[2])
	local start = rng:NextNumber(0, math.pi * 2)
	for i = 1, n do
		local a = start + (i - 1) * (math.pi * 2 / n) + rng:NextNumber(-0.25, 0.25)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local len = between(rng, s.rootLen) * (r0 / 2)
		local p0 = base + out * (r0 * 0.55) + Vector3.new(0, rng:NextNumber(0.9, 1.6), 0)
		local p1 = p0 + (out + Vector3.new(0, -0.32, 0)).Unit * len * 0.55
		local p2 = p1 + (out + Vector3.new(rng:NextNumber(-0.3, 0.3), -0.55, rng:NextNumber(-0.3, 0.3))).Unit * len * 0.5
		local rr = r0 * rng:NextNumber(0.34, 0.5)
		local mossy = rng:NextNumber() < s.mossFoot
		limb(model, p0, p1, rr, bark, rng, false).Name = "Root"
		limb(model, p1, p2, rr * 0.55, if mossy then moss else bark, rng, false).Name = "Root"
	end
end

-- a branch of `segs` pieces from `from` toward `dir`, rising a little as it goes; returns its tip and the points along it
local function branch(model: Model, from: Vector3, dir: Vector3, length: number, r0: number, r1: number, segs: number, bark: Look, rng: Random, rise: number): (Vector3, { { at: Vector3, dir: Vector3, r: number } })
	local at = from
	local points = {}
	for i = 1, segs do
		local t = i / segs
		local r = r0 + (r1 - r0) * t
		dir = wander(rng, (dir + UP * rise).Unit, 0.18)
		local nxt = at + dir * (length / segs)
		limb(model, at, nxt, r, bark, rng, false)
		table.insert(points, { at = nxt, dir = dir, r = r })
		at = nxt
	end
	return at, points
end

--[[
	Grows a tree of `kind` with its foot at `base` (on the ground), from `seed`. `scale` stretches it (1 = as the species says).
	Returns the Model (pivoted at the foot) and the radius of its solid trunk.
]]
function Trees.grow(kind: string, base: Vector3, seed: number, scale: number?): (Model, number)
	if kind == "spruce" then
		return Trees.spruce(base, seed, scale)
	end
	if kind == "hollow" then
		return Trees.hollow(base, seed, scale)
	end
	local s = SPECIES[kind]
	assert(s, "no species " .. tostring(kind))
	local rng = Random.new(seed)
	local k = scale or 1
	local model = Instance.new("Model")
	model.Name = "Tree"
	model:SetAttribute("Kind", kind)
	model:SetAttribute("Seed", seed)

	local bark = look(rng, s.bark, s.barkColor)
	local moss = look(rng, "moss", Color3.fromRGB(150, 160, 140))
	local height = between(rng, s.height) * k
	local r0 = between(rng, s.r0) * k

	foot(model, base, r0, s, bark, moss, rng)

	-- the trunk: it leans, and every piece bends a little and narrows
	local leanDir = horizontal(rng:NextNumber(0, math.pi * 2), 0)
	local dir = (UP + leanDir * math.tan(math.rad(rng:NextNumber(0, s.lean)))).Unit
	local at = base
	local trunk = {}
	for i = 1, s.segs do
		local t = i / s.segs
		local r = r0 * (1 - (1 - s.rTop) * t ^ 0.85)
		dir = wander(rng, (dir + UP * 0.25).Unit, s.wobble)
		local nxt = at + dir * (height / s.segs)
		-- the lower trunk is solid: it collides and stops sight
		trunkPiece(model, at, nxt, r, if i == 1 and rng:NextNumber() < s.mossFoot * 0.5 then moss else bark, rng, i <= 2)
		table.insert(trunk, { at = nxt, dir = dir, r = r, t = t })
		at = nxt
	end

	-- the limbs, from `limbsFrom` up, spread round the trunk
	local tips: { { at: Vector3, r: number } } = {}
	local n = rng:NextInteger(s.limbs[1], s.limbs[2])
	local start = rng:NextNumber(0, math.pi * 2)
	for i = 1, n do
		local f = s.limbsFrom + (1 - s.limbsFrom) * ((i - 0.5) / n) * rng:NextNumber(0.85, 1.05)
		local idx = math.clamp(math.ceil(f * s.segs), 1, s.segs)
		local p = trunk[idx]
		local from = p.at - p.dir * (height / s.segs) * rng:NextNumber(0, 0.6)
		local a = start + (i - 1) * (math.pi * 2 / n) + rng:NextNumber(-0.4, 0.4)
		local d = horizontal(a, math.rad(between(rng, s.elev)))
		local len = height * between(rng, s.reach)
		if s.broken and rng:NextNumber() < s.broken then
			len *= rng:NextNumber(0.25, 0.5) -- snapped off
		end
		local tip, points = branch(model, from, d, len, p.r * 0.62, math.max(0.14, p.r * 0.16), 3, bark, rng, if s.leaves then 0.12 else 0.05)
		table.insert(tips, { at = tip, r = 1 })
		-- the leaves hang along the outer half of some limbs too, not only at their ends
		if rng:NextNumber() < 0.5 then
			table.insert(tips, { at = points[2].at, r = 0.75 })
		end
		-- the forks off the limb
		local subs = rng:NextInteger(s.subs[1], s.subs[2])
		for j = 1, subs do
			local q = points[math.clamp(j + 1, 1, #points)] or points[#points]
			local sd = (q.dir + horizontal(a + rng:NextNumber(-1.1, 1.1), math.rad(rng:NextNumber(10, 40))) * 0.9).Unit
			local stip = branch(model, q.at, sd, len * rng:NextNumber(0.35, 0.55), q.r * 0.7, 0.1, 2, bark, rng, 0.08)
			table.insert(tips, { at = stip, r = 0.8 })
		end
	end
	-- the crown's top: the trunk's own end
	table.insert(tips, { at = trunk[#trunk].at, r = 1.1 })

	-- leaves: a few masses at every tip, and more round the middle of the crown, so it is one crown and not lollipops
	if s.leaves then
		local leaf = look(rng, "leaf", s.leafColor)
		local cx, cy, cz, count = 0, 0, 0, 0
		for _, tip in tips do
			local size = between(rng, s.leaves) * k * tip.r
			-- a body of leaves, and smaller clumps on its skin, so its edge is broken like a real crown's (round masses
			-- alone read as balloons, flat ones as pancakes)
			local core = tip.at + Vector3.new(rng:NextNumber(-0.3, 0.3), rng:NextNumber(0.1, 0.5), rng:NextNumber(-0.3, 0.3)) * size
			mass(model, core, size * rng:NextNumber(0.85, 1.1), size * rng:NextNumber(0.65, 0.85), leaf, rng)
			for _ = 1, rng:NextInteger(2, 3) do
				local d = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.45, 1), rng:NextNumber(-1, 1))
				if d.Magnitude < 0.1 then
					d = UP
				end
				local small = size * rng:NextNumber(0.32, 0.55)
				mass(model, core + d.Unit * size * rng:NextNumber(0.38, 0.55), small, small * rng:NextNumber(0.55, 0.9), leaf, rng)
			end
			cx += tip.at.X
			cy += tip.at.Y
			cz += tip.at.Z
			count += 1
		end
		local centre = Vector3.new(cx, cy, cz) / count
		for _ = 1, rng:NextInteger(3, 5) do
			local size = between(rng, s.leaves) * k * 1.45
			local off = Vector3.new(rng:NextNumber(-1, 1), rng:NextNumber(-0.3, 0.5), rng:NextNumber(-1, 1)) * size * 0.55
			mass(model, centre + off, size, size * 0.8, leaf, rng)
		end
	end

	model.WorldPivot = CFrame.new(base)
	return model, r0
end

--[[
	A spruce: a straight trunk, and tiers of drooping boughs that shrink toward the top (each tier a squashed ball of
	needles, hung a little lower at its rim by a tilt).
]]
function Trees.spruce(base: Vector3, seed: number, scale: number?): (Model, number)
	local rng = Random.new(seed)
	local k = scale or 1
	local model = Instance.new("Model")
	model.Name = "Tree"
	model:SetAttribute("Kind", "spruce")
	model:SetAttribute("Seed", seed)
	local bark = look(rng, "oak", Color3.fromRGB(150, 128, 112))
	local moss = look(rng, "moss", Color3.fromRGB(140, 150, 130))
	local needles = look(rng, "needle", Color3.fromRGB(110, 124, 104))
	local height = rng:NextNumber(40, 56) * k
	local r0 = rng:NextNumber(0.9, 1.4) * k
	foot(model, base, r0, { roots = { 4, 6 }, rootLen = { 3, 5 }, mossFoot = 0.5 }, bark, moss, rng)

	local lean = horizontal(rng:NextNumber(0, 6.28), 0) * math.tan(math.rad(rng:NextNumber(0, 3)))
	local dir = (UP + lean).Unit
	local at = base
	local segs = 4
	for i = 1, segs do
		local r = r0 * (1 - 0.8 * (i / segs))
		local nxt = at + wander(rng, dir, 0.03) * (height / segs)
		trunkPiece(model, at, nxt, r, bark, rng, i <= 2)
		at = nxt
	end
	local top = at
	local axis = (top - base).Unit

	-- the boughs, in whorls from a little above a head to the top: each a long squashed ball of needles laid out from the
	-- trunk and hanging down at its end; long at the bottom, short up high (2026-11-03: whole discs read as a stack of rings)
	local y = rng:NextNumber(6.5, 9) * k
	local reach = rng:NextNumber(8.5, 11) * k
	local turn = rng:NextNumber(0, 6.28)
	while y < height - 3 do
		local t = y / height
		local len = math.max(1.8, reach * (1 - t) ^ 0.9 + 1.2)
		local centre = base + axis * y
		local count = if len > 4 then 4 else 3
		turn += rng:NextNumber(0.5, 1.1)
		for b = 1, count do
			local a = turn + (b - 1) * (math.pi * 2 / count) + rng:NextNumber(-0.3, 0.3)
			local out = Vector3.new(math.cos(a), 0, math.sin(a))
			local droop = math.rad(rng:NextNumber(14, 26))
			local mid = centre + out * (len * 0.5) - Vector3.new(0, math.sin(droop) * len * 0.5, 0)
			local p = mass(model, mid, len, math.max(0.9, len * 0.2), needles, rng)
			-- the long axis (X) out from the trunk, tipped down at the end
			p.Size = Vector3.new(len, math.max(0.9, len * 0.2), math.max(1.6, len * 0.5))
			p.CFrame = CFrame.new(mid) * CFrame.fromAxisAngle(UP, -a) * CFrame.Angles(0, 0, -droop) * CFrame.Angles(rng:NextNumber(-0.2, 0.2), 0, 0)
		end
		y += math.max(2.0, 3.4 * (1 - t) + 1.5) * k
	end
	mass(model, top + Vector3.new(0, 0.5, 0), 1.6, 4.2, needles, rng)

	model.WorldPivot = CFrame.new(base)
	return model, r0
end

--[[
	A hollow giant: an old oak whose foot has rotted out into a room a body can stand in, with one way in. Its walls are
	solid and stop sight: inside it, a covered lantern cannot be seen from anywhere but its mouth.
]]
function Trees.hollow(base: Vector3, seed: number, scale: number?): (Model, number)
	local rng = Random.new(seed)
	local k = scale or 1
	local model = Instance.new("Model")
	model.Name = "HollowTree"
	model:SetAttribute("Kind", "hollow")
	model:SetAttribute("Seed", seed)
	local bark = look(rng, "oak", Color3.fromRGB(176, 166, 152))
	local moss = look(rng, "moss", Color3.fromRGB(150, 160, 140))
	local inside = 3.4 * k -- the room's radius
	local wall = 1.6 * k
	local mouth = rng:NextNumber(0, math.pi * 2)
	local staves = 11
	for i = 1, staves do
		local a = mouth + (i - 0.5) * (math.pi * 2 / staves)
		if i ~= 1 and i ~= staves then -- the two either side of the mouth are left out: the way in
			local at = base + Vector3.new(math.cos(a), 0, math.sin(a)) * (inside + wall * 0.5)
			local tilt = Vector3.new(math.cos(a), 0, math.sin(a)) * -0.06
			trunkPiece(model, at - Vector3.new(0, 1, 0), at + (UP + tilt).Unit * (12 * k), wall * 0.62, if rng:NextNumber() < 0.3 then moss else bark, rng, true)
		end
	end
	-- the trunk above the room, closed
	local roofAt = base + Vector3.new(0, 12 * k, 0)
	trunkPiece(model, roofAt - Vector3.new(0, 1.5, 0), roofAt + Vector3.new(rng:NextNumber(-1, 1), 14 * k, rng:NextNumber(-1, 1)), inside + wall * 0.8, bark, rng, true)
	foot(model, base, inside + wall, { roots = { 7, 9 }, rootLen = { 3, 4.5 }, mossFoot = 0.7 }, bark, moss, rng)
	-- remove the flare (it would fill the room)
	for _, flare in model:GetChildren() do
		if flare.Name == "Flare" then
			flare:Destroy()
		end
	end
	-- a few dead limbs high up and some leaves
	local leaf = look(rng, "leaf", Color3.fromRGB(112, 128, 98))
	for i = 1, 4 do
		local a = rng:NextNumber(0, 6.28)
		local tip = branch(model, roofAt + Vector3.new(0, 10 * k, 0), horizontal(a, math.rad(rng:NextNumber(20, 45))), 12 * k, 1.1 * k, 0.15, 3, bark, rng, 0.1)
		if i <= 3 then
			mass(model, tip, 8 * k, 5 * k, leaf, rng)
		end
	end
	model:SetAttribute("Hide", true)
	model.WorldPivot = CFrame.new(base)
	return model, inside + wall
end

return Trees
