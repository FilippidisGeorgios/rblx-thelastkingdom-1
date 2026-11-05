--[[
	ForestDress — run in the Studio of the FORGOTTEN LANDS place, in EDIT MODE, after `tools/BuildForest.luau` (sections
	trees, under, places). It dresses the King's Wood (area 6, docs/systems/Forest.md) in MODELS instead of blocks.

	WHY (the developer, 2026-11-05). Trees built out of blocks never had thin twigs, and where two textured blocks overlapped
	the bark (a photo) showed twice; the green moss laid on trunks, logs and stones read as stuck-on pieces. So:
	  * every grown tree is replaced by a store-made mesh tree of its kind, at its place, at about its height;
	  * every fern made of blades and every bramble ball becomes a mesh fern;
	  * a low, broken rail fence (posts and two rails, some leaning, some fallen) marks the edge of the outer wood, on the
	    line of the invisible walls, and those walls are made taller than anything a body could climb;
	  * the bark that is left on logs, stumps, posts and huts (a photo with moss baked in) becomes plain dark wood.

	THE KIT (ServerStorage.Assets.ForestKit), made on 2026-11-05 from free Creator Store models, scripts stripped, every part
	anchored and untouchable, PBR skins tinted darker (SurfaceAppearance.Color), pivots at the foot:
	  Fir1..Fir8   "Silver Firs / Grey Pines Realistic Trees Pack PBR" (18475173887, Letaij): the dense evergreens
	  Oak1..Oak9   "(PBR) Realistic Oak Trees Pack Free" (98950444096614) and "Realistic Oak Trees Pack Free"
	               (114023396228594), both Letaij: the broadleaves (beech and oak in the old plan)
	  Dead1        "realistic dead tree" (13535614846): a leafless tree with thin twisting twigs
	  Dead2        the mesh of "Dead Tree 2" (104156036225286; the model came with a hidden UI script: only its mesh is kept)
	  Dead3, Dead4 "Realistic Dead Tree Model" (1407692099) and "Realistic Dead Tree" (2953179150), plain dark wood
	  Bare1..Bare6 copies of the hills' own bare trees (Gameplay.Surroundings.Forest): the developer likes them
	  Fern1, Fern2 "FernTallVar01" (8311854308) and "Fern" (11611657675)
	  FenceBay     "Crooked Fence" (10197029989), plain dark wood (its pale photo texture is taken off)
	Leaves never collide, never stop sight and cast no shadow; each tree gets an unseen round "Trunk" that collides and stops
	the Huntsman's sight, as the grown trees had.

	SECTIONS (set ONLY): trees | plants | fence | bark | all
	Old pieces are MOVED, not deleted: grown trees go to ServerStorage.Assets.Retired.ForestTreesGrown.
	NOTE: a tool, not game code; the result lives in the place (save it).
]]

local ONLY = "all"

local ServerStorage = game:GetService("ServerStorage")
local Workspace = game:GetService("Workspace")

local Forest = Workspace.Gameplay.Battleground.Decorations.Area6.Forest
local Kit = ServerStorage.Assets:FindFirstChild("ForestKit")
assert(Kit, "ForestDress: ServerStorage.Assets.ForestKit is missing (see the list at the top)")

local function say(s: string)
	print("[ForestDress] " .. s)
end

local function retired(name: string): Folder
	local root = ServerStorage.Assets:FindFirstChild("Retired") or Instance.new("Folder")
	root.Name = "Retired"
	root.Parent = ServerStorage.Assets
	local f = root:FindFirstChild(name) or Instance.new("Folder")
	f.Name = name
	f.Parent = root
	return f :: Folder
end

local function pick(rng: Random, list: { { any } }): string
	local total = 0
	for _, e in list do
		total += e[2]
	end
	local r = rng:NextNumber() * total
	for _, e in list do
		r -= e[2]
		if r <= 0 then
			return e[1]
		end
	end
	return list[#list][1]
end

local terrainOnly = RaycastParams.new()
terrainOnly.FilterType = Enum.RaycastFilterType.Include
terrainOnly.FilterDescendantsInstances = { Workspace.Terrain }
local function groundY(x: number, z: number): number
	local hit = Workspace:Raycast(Vector3.new(x, 200, z), Vector3.new(0, -400, 0), terrainOnly)
	return if hit then hit.Position.Y else 2
end

--==========================================================================
-- TREES: a mesh tree of the same kind where each grown tree stood
--==========================================================================
local FIRS = {}
for i = 1, 8 do
	table.insert(FIRS, { "Fir" .. i, 1 })
end
-- the two widest oaks are kept rare: a dense wood has little room for a crown 70 studs across
local OAKS = { { "Oak1", 1 }, { "Oak2", 1 }, { "Oak3", 1 }, { "Oak4", 0.35 }, { "Oak5", 0.8 }, { "Oak6", 0.25 }, { "Oak7", 1 }, { "Oak8", 0.9 }, { "Oak9", 1 } }
local DEAD = { { "Bare1", 0.07 }, { "Bare2", 0.07 }, { "Bare3", 0.07 }, { "Bare4", 0.07 }, { "Bare5", 0.06 }, { "Bare6", 0.06 }, { "Dead1", 0.25 }, { "Dead2", 0.17 }, { "Dead3", 0.1 }, { "Dead4", 0.08 } }
local ORCHARD = { { "Dead4", 0.4 }, { "Dead3", 0.3 }, { "Bare1", 0.15 }, { "Bare6", 0.15 } }
local MAX_WIDTH = 52

local function trunk(parent: Instance, base: Vector3, d: number, h: number)
	local p = Instance.new("Part")
	p.Name = "Trunk"
	p.Shape = Enum.PartType.Cylinder
	p.Size = Vector3.new(h, d, d)
	p.CFrame = CFrame.new(base + Vector3.new(0, h / 2 - 0.5, 0)) * CFrame.Angles(0, 0, math.rad(90))
	p.Anchored = true
	p.Transparency = 1
	p.CanCollide = true
	p.CanQuery = true
	p.CanTouch = false
	p.CastShadow = false
	p.Parent = parent
end

-- the stone and huts a crown must not grow into
local overlap = OverlapParams.new()
overlap.FilterType = Enum.RaycastFilterType.Include
local function touchesStone(m: Model): boolean
	for _, p in m:GetChildren() do
		if p:IsA("BasePart") and p.Name ~= "Trunk" then
			for _, h in Workspace:GetPartBoundsInBox(p.CFrame, p.Size * 0.6, overlap) do
				if h.Transparency < 1 and h.Name ~= "Bound" and h.Parent and h.Parent.Name ~= "Bay" then
					return true
				end
			end
		end
	end
	return false
end

local function plantTree(name: string, base: Vector3, H: number, yaw: number): Model
	local src = Kit[name] :: Model
	local s = H / src:GetAttribute("Height")
	local w = src:GetAttribute("Width") * s
	if w > MAX_WIDTH then
		s *= MAX_WIDTH / w
	end
	local m = src:Clone()
	m.Name = "Tree"
	m:ScaleTo(s)
	m:PivotTo(CFrame.new(base - Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, yaw, 0))
	local realH = src:GetAttribute("Height") * s
	local fam = src:GetAttribute("Family")
	local d = if fam == "Fir"
		then math.clamp(0.75 * s, 1.1, 2.2)
		elseif fam == "Oak" then math.clamp(realH * 0.055, 1.6, 3.2)
		else math.clamp(realH * 0.04, 1.1, 2.4)
	trunk(m, base, d, math.min(14, realH * 0.4))
	m:SetAttribute("Look", name)
	return m
end

local function trees()
	local old = Forest:FindFirstChild("Trees")
	local fresh = Forest:FindFirstChild("MeshTrees")
	if fresh then
		fresh:Destroy()
	end
	fresh = Instance.new("Folder")
	fresh.Name = "MeshTrees"
	fresh.Parent = Forest
	local BG = Workspace.Gameplay.Battleground
	overlap.FilterDescendantsInstances = { BG.Shell, Forest.Places, Forest.Breach, BG.Chamber5, BG.Chamber6, BG.Chamber7 }
	-- the grown trees: where they still stand, or where they were kept
	local sources = {}
	if old then
		for _, t in old:GetChildren() do
			table.insert(sources, t)
		end
	end
	local kept = ServerStorage.Assets:FindFirstChild("Retired") and ServerStorage.Assets.Retired:FindFirstChild("ForestTreesGrown")
	if kept then
		for _, t in kept:GetChildren() do
			table.insert(sources, t)
		end
	end
	local made, swapped, dropped = 0, 0, 0
	for i, t in sources do
		local kind = t:GetAttribute("Kind")
		local seed = t:GetAttribute("Seed") or i
		local rng = Random.new(seed)
		local _, sz = t:GetBoundingBox()
		local oldH = sz.Y
		local base = t:GetPivot().Position
		local name, H
		if kind == "spruce" then
			name, H = pick(rng, FIRS), oldH * rng:NextNumber(0.95, 1.1)
		elseif kind == "beech" or kind == "oak" then
			name, H = pick(rng, OAKS), math.clamp(oldH * 0.75, 28, 55) * rng:NextNumber(0.92, 1.08)
		elseif kind == "orchard" then
			name, H = pick(rng, ORCHARD), math.max(oldH, 14) * rng:NextNumber(0.95, 1.15)
		elseif kind == "hollow" then
			name, H = if i % 2 == 0 then "Oak6" else "Oak4", rng:NextNumber(50, 58)
		else
			name, H = pick(rng, DEAD), math.max(oldH, 20) * rng:NextNumber(0.9, 1.15)
		end
		local m = plantTree(name, base, H, rng:NextNumber(0, math.pi * 2))
		m.Parent = fresh
		-- a crown in the castle's stone or a hut: a narrower fir, smaller, until it stands clear
		if touchesStone(m) then
			m:Destroy()
			local ok = false
			for attempt = 1, 6 do
				local f = plantTree("Fir" .. rng:NextInteger(1, 8), base, math.max(18, H * (1 - 0.12 * attempt)), rng:NextNumber(0, math.pi * 2))
				f.Parent = fresh
				if not touchesStone(f) then
					m = f
					ok = true
					swapped += 1
					break
				end
				f:Destroy()
			end
			if not ok then
				dropped += 1
				continue
			end
		end
		m:SetAttribute("Kind", kind)
		m:SetAttribute("Set", t:GetAttribute("Set"))
		m:SetAttribute("Seed", seed)
		made += 1
		if old and t.Parent == old then
			t.Parent = retired("ForestTreesGrown")
		end
		if i % 40 == 0 then
			task.wait()
		end
	end
	say(("trees: %d mesh trees (%d swapped for a narrow fir by the stone, %d left out)"):format(made, swapped, dropped))
end

--==========================================================================
-- PLANTS: the ferns of blades and the bramble balls become mesh ferns
--==========================================================================
local function plants()
	local U = Forest:FindFirstChild("Under")
	if not U then
		return
	end
	local folder = U:FindFirstChild("Plants")
	if folder then
		folder:Destroy()
	end
	folder = Instance.new("Folder")
	folder.Name = "Plants"
	folder.Parent = U
	local rng = Random.new(4242)
	local made = 0
	local function fern(at: Vector3, width: number)
		local src = if rng:NextNumber() < 0.65 then Kit.Fern1 else Kit.Fern2
		local m = src:Clone()
		m.Name = "Fern"
		m:ScaleTo(width / src:GetAttribute("Width"))
		m:PivotTo(CFrame.new(at) * CFrame.Angles(0, rng:NextNumber(0, math.pi * 2), 0))
		m.Parent = folder
		made += 1
	end
	-- the blades of one fern stand round one point
	local clusters = {}
	for _, c in U:GetChildren() do
		if c.Name == "Frond" and c:IsA("BasePart") then
			local p = c.Position
			local found
			for _, cl in clusters do
				if (Vector3.new(cl.sum.X / cl.n, 0, cl.sum.Z / cl.n) - Vector3.new(p.X, 0, p.Z)).Magnitude < 2.6 then
					found = cl
					break
				end
			end
			if not found then
				found = { sum = Vector3.zero, n = 0, low = math.huge, parts = {} }
				table.insert(clusters, found)
			end
			found.sum += p
			found.n += 1
			found.low = math.min(found.low, p.Y)
			table.insert(found.parts, c)
		end
	end
	for _, cl in clusters do
		local c = cl.sum / cl.n
		fern(Vector3.new(c.X, cl.low - 0.15, c.Z), rng:NextNumber(4.5, 7))
		for _, f in cl.parts do
			f:Destroy()
		end
	end
	for _, b in U:GetChildren() do
		if b.Name == "Bramble" and b:IsA("BasePart") then
			fern(Vector3.new(b.Position.X, b.Position.Y - b.Size.Y / 2, b.Position.Z), math.clamp(math.max(b.Size.X, b.Size.Z) * 1.25, 5, 9))
			b:Destroy()
		end
	end
	say(("plants: %d mesh ferns"):format(made))
end

--==========================================================================
-- FENCE: a low broken rail fence on the line of the invisible walls round the outer wood
--==========================================================================
local function fence()
	local Places = Forest.Places
	local old = Places:FindFirstChild("EdgeFence")
	if old then
		old:Destroy()
	end
	local folder = Instance.new("Folder")
	folder.Name = "EdgeFence"
	local rng = Random.new(1606)
	local STEP = 7.8
	-- the outer wood's edge (configs/Forest Outer), from the castle's west wall round to it again
	local lines = {
		{ Vector3.new(-197, 0, -1234), Vector3.new(-610, 0, -1234) },
		{ Vector3.new(-610, 0, -1234), Vector3.new(-610, 0, -1476) },
		{ Vector3.new(-610, 0, -1476), Vector3.new(-197, 0, -1476) },
	}
	local made = 0
	for _, ln in lines do
		local a, b = ln[1], ln[2]
		local dir = (b - a).Unit
		for i = 0, math.floor((b - a).Magnitude / STEP) - 1 do
			local p0 = a + dir * (i * STEP)
			local p1 = p0 + dir * STEP
			local mid = (p0 + p1) / 2
			local roll = rng:NextNumber()
			if roll >= 0.1 then -- one bay in ten is gone
				local y0, y1 = groundY(p0.X, p0.Z), groundY(p1.X, p1.Z)
				local ym = (y0 + y1) / 2
				local m = Kit.FenceBay:Clone()
				m.Name = "Bay"
				for _, r in m:GetChildren() do
					if r:GetAttribute("Rail") and rng:NextNumber() < 0.22 then
						r:Destroy() -- a rail is missing
					end
				end
				local at = Vector3.new(mid.X, ym - 0.35, mid.Z)
				local base = CFrame.lookAt(at, at - dir) * CFrame.Angles(-math.atan2(y1 - y0, STEP), 0, 0)
				local side = if rng:NextNumber() < 0.5 then 1 else -1
				local tilt = if roll < 0.3
					then CFrame.Angles(0, 0, math.rad(rng:NextNumber(76, 86)) * side) * CFrame.new(0, -0.2, 0) -- fallen flat
					elseif roll < 0.6 then CFrame.Angles(math.rad(rng:NextNumber(-4, 4)), 0, math.rad(rng:NextNumber(8, 24)) * side) -- leaning
					else CFrame.Angles(math.rad(rng:NextNumber(-3, 3)), math.rad(rng:NextNumber(-4, 4)), math.rad(rng:NextNumber(-5, 5)))
				m:PivotTo(base * tilt)
				m.Parent = folder
				made += 1
			end
		end
	end
	folder.Parent = Places
	-- nobody climbs over: the walls reach far above the tallest tree (about y 75)
	local bounds = Places:FindFirstChild("Bounds")
	if bounds then
		for _, w in bounds:GetChildren() do
			if w:IsA("BasePart") then
				w.Size = Vector3.new(w.Size.X, 320, w.Size.Z)
				w.Position = Vector3.new(w.Position.X, 140, w.Position.Z)
			end
		end
	end
	say(("fence: %d bays; the invisible walls now stand from y -20 to 300"):format(made))
end

--==========================================================================
-- BARK: the photo bark (moss baked into it) on what is left becomes plain dark wood
--==========================================================================
local function bark()
	local rng = Random.new(5150)
	local n = 0
	for _, d in Workspace:GetDescendants() do
		if d:IsA("BasePart") and (d.MaterialVariant:find("^OakBark") or d.MaterialVariant:find("^BeechBark") or d.MaterialVariant:find("^ForestMoss")) then
			d.MaterialVariant = ""
			d.Material = Enum.Material.Wood
			local k = rng:NextNumber(0.85, 1.12)
			d.Color = Color3.fromRGB(70 * k, 61 * k, 52 * k)
			n += 1
		end
	end
	say(("bark: %d pieces of plain dark wood"):format(n))
end

if ONLY == "trees" or ONLY == "all" then
	trees()
end
if ONLY == "plants" or ONLY == "all" then
	plants()
end
if ONLY == "fence" or ONLY == "all" then
	fence()
end
if ONLY == "bark" or ONLY == "all" then
	bark()
end
