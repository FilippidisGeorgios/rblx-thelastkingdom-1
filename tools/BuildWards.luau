--[[
	BuildWards — the nine chambers, built to be believed.
	FORGOTTEN LANDS place, EDIT MODE. Loaded through the local file server
	(see the memory notes) or pasted into the Command Bar.

	--------------------------------------------------------------------------
	WHAT THIS IS

	The Outer Ward, the Stables and the Kitchens (chambers 1-3), the
	Graveyard, the Smithy and the Great Hall (4-6), the Rows, the Inner Ward
	and the Keep Steps (7-9), rebuilt as places people lived in rather than
	blocks standing in a yard. Every building
	is assembled from the way buildings were actually put together:

	  - a STONE PLINTH, because timber on wet ground rots in a decade;
	  - a TIMBER FRAME — sill, posts, rails, braces, a wall plate — with the
	    panels between filled with daub, so the frame reads proud of the wall;
	  - an upper storey that JETTIES out over the street, joist ends showing;
	  - a THATCH roof two and a half studs thick, rounded at the eaves, the
	    ridge pinned with hazel liggers, patched where it was repaired;
	  - shutters, plank doors on strap hinges, a chimney in rubble stone;
	  - and inside: boards, joists, a stair, furniture, the things people left.

	The look comes from MATERIALS (PBR variants generated for this place:
	TLK_Thatch3, TLK_Daub, TLK_OakBeam, ...) and from small irregularity: no
	two timbers the same colour, no panel quite the same cream, nothing
	perfectly level. Props (barrels, carts, beds, sacks) are textured meshes
	kept in ServerStorage.Assets.Props and cloned in.

	THE DEAD MUST BE ABLE TO REACH YOU. Every floor a player can stand on above
	the ground — a loft, a deck, a platform — is reached by a stair whose
	walking surface is an invisible ramp: the dead follow the floor
	(EnemyAIService) and route over ramps (PathfindingService). Nothing built
	here reaches the height of the curtain walls (the rule in RemoveStairs).

	--------------------------------------------------------------------------
	SECTIONS — what a run builds ("Look", "Area1" ... "Area9"). Each area
	clears its own folder and rebuilds it whole, so any one can be rerun alone.
	"Prototype" builds one house at the preview board outside the walls, to
	judge detail before it goes into a chamber.

	THE WORK IN EACH ROOM (AreaPlan.md) is not built here, only the places it
	happens. What the mechanics will look for, by name:
	  Area4  GraveBraziers.GraveBrazier  x4, attributes Section 1-4 and Lit,
	         a FirePoint part where the flame goes
	  Area5  ForgeHearth (attribute Mechanic = "Forge"), ForgeBellows,
	         ForgeAnvil; TorchRack.UnlitTorch x4; OilStore.OilJar;
	         Woodyard.DeadTree (attribute Choppable), the Axe in a stump,
	         Woodyard.PlankStack; Mine.GoldVein
	  Area6  GreatHall.BoardPoints.BoardPoint x4 (attribute Door 1-4), one
	         in each of the hall's doorways
	  Area7  Tavern.PrisonerChair (attribute Prisoner, a SeatPoint part)
	  Area8  PassageRubble (attribute Passage) by the way out; the
	         FallenTower and its two RubbleSlopes are the high ground
	  Area9  Keep.KeepDoor (attribute Sealed), Keep.ScribeSpot on the hall
	         floor inside; the keep has no stair: nothing reaches the
	         wall-walk until the ending opens it

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local SECTIONS = { "Area9" }
local SEED = 1500

--==========================================================================
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")
local MaterialService = game:GetService("MaterialService")
local ChangeHistoryService = game:GetService("ChangeHistoryService")

local Castle = require(ReplicatedStorage:WaitForChild("Config"):WaitForChild("Castle")) :: any
-- The walkable surface inside the walls. The terrain's voxels are full up to
-- y = 0, but a full voxel under an empty one renders and collides at ~2 (the
-- old tools all used 2 for this reason). Building at 0 buried every plinth and
-- let the dirt show through the floor boards.
local GROUND = 2

local rng = Random.new(SEED)
local made = 0

local function rand(a: number, b: number): number
	return rng:NextNumber(a, b)
end
local function jit(a: number): number
	return rng:NextNumber(-a, a)
end
local function chance(p: number): boolean
	return rng:NextNumber() < p
end
local function pick<T>(list: { T }): T
	return list[rng:NextInteger(1, #list)]
end

--==========================================================================
-- MATERIALS
--
-- Each entry: base material, the variant laid over it (if this place has it),
-- the tint, and how far a single piece may drift from that tint. The tint
-- multiplies the variant's own colour map, so near-white means "as painted".
--==========================================================================
local Mat = Enum.Material
local MAT = {
	thatch = { Mat.Grass, "TLK_Thatch2", Color3.fromRGB(196, 186, 162), 0.07 },
	thatchMoss = { Mat.Grass, "TLK_Thatch1", Color3.fromRGB(170, 164, 146), 0.07 },
	thatchBundles = { Mat.Grass, "TLK_Thatch3", Color3.fromRGB(186, 172, 146), 0.07 },
	thatchOld = { Mat.Grass, "TLK_Thatch1", Color3.fromRGB(150, 140, 122), 0.08 },
	hay = { Mat.Grass, "TLK_Hay", Color3.fromRGB(226, 206, 160), 0.08 },
	daub = { Mat.Plaster, "TLK_Daub", Color3.fromRGB(198, 186, 164), 0.07 },
	oak = { Mat.Wood, "TLK_OakBeam", Color3.fromRGB(168, 150, 132), 0.1 },
	oakDark = { Mat.Wood, "TLK_OakBeam", Color3.fromRGB(116, 100, 88), 0.1 },
	planks = { Mat.WoodPlanks, "TLK_OldPlanks", Color3.fromRGB(176, 156, 136), 0.1 },
	rubble = { Mat.Cobblestone, "TLK_Rubble", Color3.fromRGB(150, 144, 136), 0.08 },
	charred = { Mat.Wood, "TLK_Charred", Color3.fromRGB(70, 62, 58), 0.1 },
	shingles = { Mat.RoofShingles, "TLK_Shingles", Color3.fromRGB(196, 192, 186), 0.06 },
	burlap = { Mat.Fabric, "TLK_Burlap", Color3.fromRGB(158, 146, 126), 0.08 },
	cobbles = { Mat.Cobblestone, "TLK_Cobbles", Color3.fromRGB(190, 186, 180), 0.06 },
	iron = { Mat.CorrodedMetal, nil, Color3.fromRGB(64, 54, 48), 0.08 },
	ironDark = { Mat.Metal, nil, Color3.fromRGB(40, 38, 38), 0.05 },
	soot = { Mat.Slate, nil, Color3.fromRGB(34, 31, 30), 0.05 },
	stone = { Mat.Slate, nil, Color3.fromRGB(104, 100, 94), 0.06 },
	cloth = { Mat.Fabric, nil, Color3.fromRGB(112, 46, 40), 0.08 },
	linen = { Mat.Fabric, nil, Color3.fromRGB(190, 180, 160), 0.06 },
	ember = { Mat.Neon, nil, Color3.fromRGB(255, 120, 40), 0.05 },
	dark = { Mat.SmoothPlastic, nil, Color3.fromRGB(14, 12, 12), 0 },
	water = { Mat.Glass, nil, Color3.fromRGB(46, 54, 50), 0 },
}

local variantCache: { [string]: boolean } = {}
local function hasVariant(name: string?): boolean
	if not name then
		return false
	end
	if variantCache[name] == nil then
		variantCache[name] = MaterialService:FindFirstChild(name, true) ~= nil
	end
	return variantCache[name]
end

local function shade(c: Color3, f: number): Color3
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

local function dress(p: BasePart, key: string, tint: Color3?)
	local m = MAT[key] or MAT.oak
	p.Material = m[1]
	if hasVariant(m[2]) then
		p.MaterialVariant = m[2]
	end
	p.Color = shade(tint or m[3], 1 + jit(m[4]))
end

--==========================================================================
-- PRIMITIVES
--==========================================================================
local function newPart(class: string, parent: Instance, name: string, size: Vector3, cf: CFrame, key: string, tint: Color3?): BasePart
	local p = Instance.new(class) :: BasePart
	p.Name = name
	p.Anchored = true
	p.Size = size
	p.CFrame = cf
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CastShadow = math.max(size.X, size.Y, size.Z) >= 3
	dress(p, key, tint)
	p.Parent = parent
	made += 1
	return p
end

local function part(parent: Instance, name: string, size: Vector3, cf: CFrame, key: string, tint: Color3?): BasePart
	return newPart("Part", parent, name, size, cf, key, tint)
end

local function wedge(parent: Instance, name: string, size: Vector3, cf: CFrame, key: string, tint: Color3?): BasePart
	return newPart("WedgePart", parent, name, size, cf, key, tint)
end

-- A squared timber from a to b, w wide and h deep. `up` keeps its faces square to something.
local function beam(parent: Instance, name: string, a: Vector3, b: Vector3, w: number, h: number, key: string, up: Vector3?): BasePart
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local cf = CFrame.lookAt(mid, b, up or Vector3.yAxis)
	return part(parent, name, Vector3.new(w, h, len), cf, key)
end

-- A round pole from a to b.
local function pole(parent: Instance, name: string, a: Vector3, b: Vector3, r: number, key: string): BasePart
	local mid = (a + b) / 2
	local len = (b - a).Magnitude
	local p = part(parent, name, Vector3.new(len, r * 2, r * 2), CFrame.lookAt(mid, b) * CFrame.Angles(0, math.rad(90), 0), key)
	;(p :: Part).Shape = Enum.PartType.Cylinder
	return p
end

local function ball(parent: Instance, name: string, d: Vector3, cf: CFrame, key: string): BasePart
	local p = part(parent, name, d, cf, key)
	;(p :: Part).Shape = Enum.PartType.Ball
	return p
end

local function model(parent: Instance?, name: string): Model
	local m = Instance.new("Model")
	m.Name = name
	m.Parent = parent
	return m
end

-- Moves a model that was built round the origin so the origin lands on cf.
-- (A model with no primary part pivots on the middle of its parts, not on
-- the origin, so the pivot has to be put back first.)
local function place(m: Model, cf: CFrame)
	m.WorldPivot = CFrame.new()
	m:PivotTo(cf)
end

-- An invisible ramp: the walking surface under a flight of steps. A wedge is
-- tallest at its +Z face, so its frame looks back down the flight.
local function ramp(parent: Instance, foot: Vector3, dir: Vector3, rise: number, run: number, width: number): BasePart
	local flat = Vector3.new(dir.X, 0, dir.Z).Unit
	local centre = foot + flat * (run / 2) + Vector3.new(0, rise / 2, 0)
	local cf = CFrame.lookAt(centre, centre - flat) -- wedge's high side faces -Z of its frame
	local w = wedge(parent, "Ramp", Vector3.new(width, rise, run), cf, "dark")
	w.Transparency = 1
	w.CastShadow = false
	return w
end

-- Light and fire --------------------------------------------------------------
local function pointLight(parent: Instance, colour: Color3, brightness: number, range: number, shadows: boolean?)
	local l = Instance.new("PointLight")
	l.Color = colour
	l.Brightness = brightness
	l.Range = range
	l.Shadows = shadows == true
	l.Parent = parent
	return l
end

local function emitter(parent: Instance, props: { [string]: any }): ParticleEmitter
	local e = Instance.new("ParticleEmitter")
	for k, v in props do
		(e :: any)[k] = v
	end
	e.Parent = parent
	return e
end

local function smokeOn(parent: BasePart, rate: number, dark: boolean?)
	return emitter(parent, {
		Texture = "rbxasset://textures/particles/smoke_main.dds",
		Rate = rate,
		Lifetime = NumberRange.new(6, 10),
		Speed = NumberRange.new(2, 4),
		SpreadAngle = Vector2.new(12, 12),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 2), NumberSequenceKeypoint.new(1, 12) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.55), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(if dark then Color3.fromRGB(30, 28, 28) else Color3.fromRGB(70, 66, 64)),
		Acceleration = Vector3.new(0.6, 1.2, 0),
		LightInfluence = 1,
		RotSpeed = NumberRange.new(-20, 20),
		Rotation = NumberRange.new(0, 360),
	})
end

local function fireAt(parent: Instance, at: Vector3, scale: number, lightRange: number?)
	local core = part(parent, "FireCore", Vector3.new(0.4, 0.4, 0.4) * scale, CFrame.new(at), "ember")
	core.Transparency = 1
	core.CanCollide = false
	core.CastShadow = false
	emitter(core, {
		Texture = "rbxasset://textures/particles/fire_main.dds",
		Rate = 22 * scale,
		Lifetime = NumberRange.new(0.5, 1),
		Speed = NumberRange.new(1.5 * scale, 3 * scale),
		SpreadAngle = Vector2.new(10, 10),
		Size = NumberSequence.new({ NumberSequenceKeypoint.new(0, 1.4 * scale), NumberSequenceKeypoint.new(1, 0.2) }),
		Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.2), NumberSequenceKeypoint.new(1, 1) }),
		Color = ColorSequence.new(Color3.fromRGB(255, 170, 70), Color3.fromRGB(255, 90, 30)),
		LightEmission = 1,
		LightInfluence = 0,
		Acceleration = Vector3.new(0, 3, 0),
	})
	emitter(core, {
		Texture = "rbxasset://textures/particles/sparkles_main.dds",
		Rate = 4 * scale,
		Lifetime = NumberRange.new(1.5, 3),
		Speed = NumberRange.new(2, 5),
		SpreadAngle = Vector2.new(30, 30),
		Size = NumberSequence.new(0.12),
		Color = ColorSequence.new(Color3.fromRGB(255, 160, 60)),
		LightEmission = 1,
		Acceleration = Vector3.new(0.5, 2, 0),
	})
	pointLight(core, Color3.fromRGB(255, 150, 70), 1.4 + scale, lightRange or 22 * scale)
	return core
end

--==========================================================================
-- PROPS (textured meshes kept in ServerStorage.Assets.Props)
--==========================================================================
local propsRoot = ServerStorage:FindFirstChild("Assets") and ServerStorage.Assets:FindFirstChild("Props")

-- Clones a prop so its bottom sits on `cf`'s position, turned to `cf`.
local function prop(parent: Instance, name: string, cf: CFrame, scale: number?): Model?
	local template = propsRoot and propsRoot:FindFirstChild(name)
	if not template then
		return nil
	end
	local m = template:Clone()
	if scale and scale ~= 1 and m:IsA("Model") then
		m:ScaleTo(m:GetScale() * scale)
	end
	local box, size = m:GetBoundingBox()
	local pivot = m:GetPivot()
	-- pivot relative to the bottom-centre of the box
	local bottomOffset = pivot.Position - (box.Position - Vector3.new(0, size.Y / 2, 0))
	m:PivotTo(cf * CFrame.new(bottomOffset) * (pivot - pivot.Position))
	m.Parent = parent
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = true
			made += 1
		end
	end
	return m
end

--==========================================================================
-- THE TIMBER FRAME
--
-- One wall of a framed building. `W` is the wall's own frame: origin at its
-- left end on the line of the sill, +X along the wall, +Y up, -Z OUTSIDE.
-- `bays` is a list of "wall" | "window" | "door" | "open" | "gap".
--==========================================================================
local FRAME = 0.9 -- timber section
local STONE_T = 2.2 -- rubble masonry wall thickness
local INFILL = 0.55 -- daub panel thickness, set back from the outside face
local DOOR_H = 7.6
local WIN_SILL, WIN_HEAD = 3.3, 6.6

type WallOpts = {
	burnt: boolean?, -- charred frame, blackened or missing panels
	damage: number?, -- share of panels fallen out
	close: boolean?, -- close studding (studs every 1.7) instead of open panels
	doorOpen: number?, -- door leaf swung by this many degrees (nil = random)
	shutters: string?, -- "open" | "closed" | "broken" | nil (random)
	glow: boolean?, -- a warm light in the windows
	interior: boolean?, -- also face the inside (for walls you see from within)
	plinth: number?, -- how far the floor this wall stands on is above the ground
	-- stone walls only: openings bigger than a cottage's (a chapel, a hall)
	doorW: number?, -- door opening width (over 5: a pair of leaves)
	doorH: number?,
	winW: number?,
	winSill: number?,
	winHead: number?,
	T: number?, -- masonry thickness
	lancet: boolean?, -- pointed heads on windows and doors
	threshold: number?, -- top of the threshold stone (default: a house floor, 0.32)
	limewash: Color3?, -- the colour the daub was washed (the Rows were not all cream)
	hingeRight: boolean?, -- doors hang on their right post, so the leaf lies the other way
	archW: number?, -- "arch" bays
	archH: number?,
}

--[[
	Steps up to a door. The floor inside stands on the plinth, almost two studs
	above the yard: a player hops it, but the pathfinder (no jumping) reads it
	as a wall and the dead could never come in. Two worn stone steps for the
	eye, and the invisible ramp under them for the feet.
	W is the wall frame (origin on the outside face at floor level, -Z out).
]]
local function doorSteps(parent: Instance, W: CFrame, mid: number, width: number, plinth: number)
	local rise = plinth + 0.32
	local run = rise * 1.5
	local n = math.max(1, math.floor(rise / 0.8))
	for k = 1, n do
		local frac = k / (n + 1)
		local h = rise * frac
		local depth = run * (1 - frac) + 0.6
		local st = part(parent, "Step", Vector3.new(width + 0.6 - k * 0.2, h, depth), W * CFrame.new(mid + jit(0.1), -plinth + h / 2, -depth / 2 - 0.1), "stone")
		st.CanCollide = false
	end
	ramp(parent, (W * CFrame.new(mid, -plinth + 0.02, -run - 0.2)).Position, W.ZVector, rise, run + 0.2, width)
end

local function wattle(parent: Instance, W: CFrame, x0: number, x1: number, y0: number, y1: number, opts: WallOpts)
	-- The woven core where the daub has fallen out: staves and the rods between.
	local key = if opts.burnt then "charred" else "oakDark"
	for x = x0 + 0.5, x1 - 0.3, 0.9 do
		beam(parent, "Stave", (W * CFrame.new(x, y0, 0)).Position, (W * CFrame.new(x, y1, 0)).Position, 0.18, 0.18, key)
	end
	for y = y0 + 0.4, y1 - 0.3, 0.55 do
		beam(parent, "Withy", (W * CFrame.new(x0, y, 0.08 * (if math.floor(y * 2) % 2 == 0 then 1 else -1))).Position, (W * CFrame.new(x1, y, 0)).Position, 0.14, 0.14, key)
	end
end

local function panel(parent: Instance, W: CFrame, x0: number, x1: number, y0: number, y1: number, opts: WallOpts)
	if x1 - x0 < 0.2 or y1 - y0 < 0.2 then
		return
	end
	local damage = opts.damage or 0
	if chance(damage) then
		wattle(parent, W, x0, x1, y0, y1, opts)
		-- a few chunks still clinging at the bottom
		if chance(0.6) then
			part(parent, "DaubChunk", Vector3.new(x1 - x0, rand(0.4, 1.2), INFILL), W * CFrame.new((x0 + x1) / 2, y0 + 0.4, 0), "daub")
		end
		return
	end
	local tint = opts.limewash
	if opts.burnt then
		tint = shade(MAT.daub[3], rand(0.25, 0.5))
	end
	local p = part(parent, "Daub", Vector3.new(x1 - x0, y1 - y0, INFILL), W * CFrame.new((x0 + x1) / 2, (y0 + y1) / 2, 0.12), "daub", tint)
	p.CastShadow = false
end

local function timber(parent: Instance, name: string, W: CFrame, x0: number, y0: number, x1: number, y1: number, opts: WallOpts, size: number?)
	local key = if opts.burnt then "charred" else (if chance(0.25) then "oakDark" else "oak")
	local s = size or FRAME
	local a = (W * CFrame.new(x0 + jit(0.03), y0, -0.05 + jit(0.04))).Position
	local b = (W * CFrame.new(x1 + jit(0.03), y1, -0.05 + jit(0.04))).Position
	return beam(parent, name, a, b, s, s, key, W.ZVector)
end

local function shutter(parent: Instance, W: CFrame, x: number, y0: number, y1: number, width: number, hingeLeft: boolean, mode: string, opts: WallOpts)
	-- A leaf of three boards on two ledges, hung on iron straps.
	local leaf = model(parent, "Shutter")
	local angle = 0
	if mode == "open" then
		angle = rand(95, 160)
	elseif mode == "broken" then
		angle = rand(20, 70)
	end
	local hingeX = if hingeLeft then x else x + width
	local sign = if hingeLeft then 1 else -1
	local H = W * CFrame.new(hingeX, 0, -0.35) * CFrame.Angles(0, math.rad(angle) * sign, 0)
	local h = y1 - y0
	local key = if opts.burnt then "charred" else "planks"
	local boards = 3
	for i = 0, boards - 1 do
		local bx = sign * (width / boards) * (i + 0.5)
		part(leaf, "Board", Vector3.new(width / boards - 0.06, h - jit(0.1), 0.22), H * CFrame.new(bx, y0 + h / 2, 0), key)
	end
	for _, ly in { y0 + h * 0.22, y0 + h * 0.78 } do
		part(leaf, "Ledge", Vector3.new(width * 0.92, 0.32, 0.18), H * CFrame.new(sign * width / 2, ly, -0.18), key)
		part(leaf, "Strap", Vector3.new(width * 0.7, 0.16, 0.06), H * CFrame.new(sign * width * 0.35, ly, -0.29), "iron")
	end
	if mode == "broken" then
		-- hanging off its top hinge
		leaf:PivotTo(leaf:GetPivot() * CFrame.Angles(0, 0, math.rad(rand(-20, 20))))
	end
	return leaf
end

-- `right`: the leaf hangs on x1 instead of x0 (the second leaf of a pair).
local function door(parent: Instance, W: CFrame, x0: number, x1: number, y0: number, opts: WallOpts, right: boolean?)
	local width = x1 - x0
	local dh = opts.doorH or DOOR_H
	local leaf = model(parent, "Door")
	local open = opts.doorOpen
	if open == nil then
		-- open: these buildings are meant to be walked into (and so are the dead).
		-- Swung right back against the wall: a leaf standing out square into
		-- the room is a wall across it (it cut a cottage in half for the
		-- pathfinder, 2026-10-20).
		open = pick({ 155, 160, 165 })
	end
	local H
	if right then
		H = W * CFrame.new(x1 - 0.1, y0, 0.15) * CFrame.Angles(0, math.rad(open), 0) * CFrame.new(-width, 0, 0)
	else
		H = W * CFrame.new(x0 + 0.1, y0, 0.15) * CFrame.Angles(0, -math.rad(open), 0)
	end
	-- measured from the hinge, whichever side that is
	local function lx(x: number): number
		return if right then width - x else x
	end
	local key = if opts.burnt then "charred" else "planks"
	local n = math.max(3, math.floor(width / 0.9))
	for i = 0, n - 1 do
		local bw = width / n
		part(leaf, "Board", Vector3.new(bw - 0.05, dh - 0.2 - jit(0.05), 0.3), H * CFrame.new(bw * (i + 0.5), dh / 2, 0), key)
	end
	local ledges = if dh > 9 then { 1.1, dh * 0.37, dh * 0.68, dh - 1.1 } else { 1.1, dh / 2, dh - 1.1 }
	for _, ly in ledges do
		part(leaf, "Ledge", Vector3.new(width - 0.3, 0.42, 0.22), H * CFrame.new(width / 2, ly, 0.26), key)
		part(leaf, "Strap", Vector3.new(width * 0.72, 0.2, 0.07), H * CFrame.new(lx(width * 0.36), ly, -0.19), "iron")
		ball(leaf, "Nail", Vector3.new(0.16, 0.16, 0.16), H * CFrame.new(lx(width * 0.6), ly, -0.2), "ironDark")
	end
	local ring = part(leaf, "Ring", Vector3.new(0.12, 0.7, 0.7), H * CFrame.new(lx(width - 0.8), math.min(dh * 0.48, 3.8), -0.32), "ironDark")
	;(ring :: Part).Shape = Enum.PartType.Cylinder
	return leaf
end

-- One framed wall. Returns the model.
local function frameWall(parent: Instance, W: CFrame, L: number, H: number, bays: { string }, opts: WallOpts)
	local wall = model(parent, "Wall")
	local n = #bays
	local bw = L / n
	local railY = WIN_SILL - 0.45

	-- the wall plate runs through; the sill stops either side of a doorway,
	-- which gets a low threshold instead (a sill across it is a shin-high step)
	timber(wall, "Plate", W, 0, H - FRAME / 2, L, H - FRAME / 2, opts, 1.0)
	do
		local runStart = 0
		for i = 1, n + 1 do
			local kind = bays[i]
			if i == n + 1 or kind == "door" or kind == "open" then
				local runEnd = if i == n + 1 then L else (i - 1) * bw + FRAME / 2
				if runEnd - runStart > 0.3 then
					timber(wall, "Sill", W, runStart, FRAME / 2, runEnd, FRAME / 2, opts, 1.0)
				end
				runStart = i * bw - FRAME / 2
			end
		end
	end

	for i = 0, n do
		local x = math.clamp(i * bw, FRAME / 2, L - FRAME / 2)
		local corner = (i == 0 or i == n)
		timber(wall, if corner then "CornerPost" else "Post", W, x, FRAME, x, H - FRAME, opts, if corner then 1.15 else FRAME)
	end

	for i = 1, n do
		local kind = bays[i]
		local x0 = (i - 1) * bw + FRAME / 2
		local x1 = i * bw - FRAME / 2
		local mid = (x0 + x1) / 2
		local top = H - FRAME
		if kind == "loop" then
			kind = "wall"
		end
		if kind == "gap" then
			continue -- a missing bay: frame only, nothing between
		elseif kind == "door" then
			local dw = math.min(x1 - x0, 4.2)
			local d0 = mid - dw / 2
			timber(wall, "Lintel", W, x0, DOOR_H + 0.45, x1, DOOR_H + 0.45, opts)
			-- jamb posts either side of a narrow door in a wide bay
			if d0 - x0 > 0.6 then
				timber(wall, "Jamb", W, d0 - 0.35, FRAME, d0 - 0.35, DOOR_H, opts, 0.7)
				timber(wall, "Jamb", W, d0 + dw + 0.35, FRAME, d0 + dw + 0.35, DOOR_H, opts, 0.7)
				panel(wall, W, x0, d0 - 0.7, FRAME, DOOR_H, opts)
				panel(wall, W, d0 + dw + 0.7, x1, FRAME, DOOR_H, opts)
			end
			panel(wall, W, x0, x1, DOOR_H + 0.9, top, opts)
			door(wall, W, d0, d0 + dw, FRAME * 0.5, opts, opts.hingeRight)
			-- a worn threshold stone, and steps down to the yard
			-- (inside the wall line and level with the floor: a stone standing proud
			-- on the steps is a lip the pathfinder will not cross)
			part(wall, "Threshold", Vector3.new(dw + 0.4, 0.3, 1.0), W * CFrame.new(mid, 0.17, 0.5), "stone")
			if (opts.plinth or 0) > 0.3 then
				doorSteps(wall, W, mid, dw, opts.plinth :: number)
			end
		elseif kind == "window" then
			local ww = math.min(x1 - x0 - 0.8, 3.6)
			local w0 = mid - ww / 2
			timber(wall, "WindowSill", W, x0, WIN_SILL, x1, WIN_SILL, opts)
			timber(wall, "WindowHead", W, x0, WIN_HEAD, x1, WIN_HEAD, opts)
			panel(wall, W, x0, x1, FRAME, WIN_SILL - 0.45, opts)
			panel(wall, W, x0, x1, WIN_HEAD + 0.45, top, opts)
			panel(wall, W, x0, w0, WIN_SILL + 0.45, WIN_HEAD - 0.45, opts)
			panel(wall, W, w0 + ww, x1, WIN_SILL + 0.45, WIN_HEAD - 0.45, opts)
			-- mullions: square oak bars set diagonally, the medieval window
			for k = 1, 2 do
				local mx = w0 + ww * k / 3
				local bar = beam(wall, "Mullion", (W * CFrame.new(mx, WIN_SILL, 0)).Position, (W * CFrame.new(mx, WIN_HEAD, 0)).Position, 0.32, 0.32, if opts.burnt then "charred" else "oak", W.ZVector)
				bar.CFrame = bar.CFrame * CFrame.Angles(0, 0, math.rad(45))
			end
			local mode = opts.shutters or pick({ "open", "open", "closed", "broken" })
			if mode == "closed" then
				shutter(wall, W, w0, WIN_SILL + 0.3, WIN_HEAD - 0.3, ww / 2, true, "closed", opts)
				shutter(wall, W, w0 + ww / 2, WIN_SILL + 0.3, WIN_HEAD - 0.3, ww / 2, false, "closed", opts)
			else
				shutter(wall, W, w0, WIN_SILL + 0.3, WIN_HEAD - 0.3, ww / 2, true, mode, opts)
				if not (mode == "broken" and chance(0.5)) then
					shutter(wall, W, w0 + ww / 2, WIN_SILL + 0.3, WIN_HEAD - 0.3, ww / 2, false, if mode == "broken" then "open" else mode, opts)
				end
			end
			if opts.glow then
				-- a warm pane seen from outside; one weak light per window, or a
				-- long house with twenty windows burns out its own interior
				local g = part(wall, "Glow", Vector3.new(ww, WIN_HEAD - WIN_SILL - 0.9, 0.1), W * CFrame.new(mid, (WIN_SILL + WIN_HEAD) / 2, 0.6), "ember")
				g.Transparency = 0.72
				g.CanCollide = false
				g.CastShadow = false
				pointLight(g, Color3.fromRGB(255, 160, 80), 0.3, 9)
			end
		elseif kind == "open" then
			-- an open-fronted bay (a shed, a forge): rail only, nothing to fill
			timber(wall, "Rail", W, x0, H * 0.82, x1, H * 0.82, opts)
			if (opts.plinth or 0) > 0.3 then
				doorSteps(wall, W, mid, x1 - x0, opts.plinth :: number)
			end
		else
			-- plain wall: a rail, braces in the end bays, daub between
			timber(wall, "Rail", W, x0, railY, x1, railY, opts)
			if opts.close then
				local studs = math.max(1, math.floor((x1 - x0) / 1.7))
				local step = (x1 - x0) / (studs + 1)
				for s = 1, studs do
					local sx = x0 + step * s
					timber(wall, "Stud", W, sx, FRAME, sx, top, opts, 0.6)
				end
				for s = 0, studs do
					local a, b = x0 + step * s + 0.3, x0 + step * (s + 1) - 0.3
					panel(wall, W, a, b, FRAME, railY - 0.45, opts)
					panel(wall, W, a, b, railY + 0.45, top, opts)
				end
			else
				panel(wall, W, x0, x1, FRAME, railY - 0.45, opts)
				panel(wall, W, x0, x1, railY + 0.45, top, opts)
				if i == 1 or i == n then
					-- the brace runs from the corner post's foot up to the rail
					local fromLeft = (i == 1)
					local bx0 = if fromLeft then x0 else x1
					local bx1 = if fromLeft then math.min(x1, x0 + (railY - FRAME) * 1.2) else math.max(x0, x1 - (railY - FRAME) * 1.2)
					timber(wall, "Brace", W, bx0, FRAME, bx1, railY, opts, 0.7)
					-- and a curved tension brace above, plate to post
					local ux1 = if fromLeft then math.min(x1, x0 + 2.4) else math.max(x0, x1 - 2.4)
					timber(wall, "Brace", W, ux1, top, bx0, top - 2.4, opts, 0.7)
				end
			end
		end
	end
	return wall
end

--==========================================================================
-- FLOORS, STAIRS
--==========================================================================
local function boards(parent: Instance, cf: CFrame, w: number, d: number, opts: WallOpts?, holes: { { number } }?)
	-- Boards run along local Z. `holes` = list of {x0, x1, z0, z1} left open.
	local floor = model(parent, "Floor")
	local bw = 1.1
	local key = if opts and opts.burnt then "charred" else "planks"
	for x = -w / 2 + bw / 2, w / 2 - bw / 2 + 0.01, bw do
		local segs = { { -d / 2, d / 2 } }
		if holes then
			for _, h in holes do
				if x + bw / 2 > h[1] and x - bw / 2 < h[2] then
					local out = {}
					for _, s in segs do
						if h[3] > s[1] then
							table.insert(out, { s[1], math.min(s[2], h[3]) })
						end
						if h[4] < s[2] then
							table.insert(out, { math.max(s[1], h[4]), s[2] })
						end
					end
					segs = out
				end
			end
		end
		for _, s in segs do
			if s[2] - s[1] > 0.3 then
				local p = part(floor, "Board", Vector3.new(bw - 0.06, 0.32, s[2] - s[1]), cf * CFrame.new(x, jit(0.03), (s[1] + s[2]) / 2), key)
				p.CastShadow = false
			end
		end
	end
	return floor
end

-- A straight flight from `foot` rising `rise` along `dir`, `width` wide.
-- Treads are for the eye; the invisible ramp under them is what is walked on.
local function stair(parent: Instance, foot: Vector3, dir: Vector3, rise: number, width: number, key: string?, treadLen: number?)
	local m = model(parent, "Stair")
	local flat = Vector3.new(dir.X, 0, dir.Z).Unit
	local steps = math.max(2, math.ceil(rise / 0.95))
	local riser = rise / steps
	local tread = treadLen or 1.2
	local run = steps * tread
	local side = flat:Cross(Vector3.yAxis)
	local base = CFrame.lookAt(foot, foot + flat)
	for i = 0, steps - 1 do
		local t = part(m, "Tread", Vector3.new(width, 0.36, tread + 0.15), base * CFrame.new(0, riser * (i + 1) - 0.18, -(tread * (i + 0.5))), key or "planks")
		t.CanCollide = false
		t.CastShadow = false
	end
	-- the two strings the treads are housed in
	for _, s in { -1, 1 } do
		local a = foot + side * (s * (width / 2 + 0.2)) + Vector3.new(0, 0.4, 0)
		local b = foot + flat * run + side * (s * (width / 2 + 0.2)) + Vector3.new(0, rise + 0.4, 0)
		local str = beam(m, "String", a, b, 0.35, 1.1, "oakDark")
		str.CanCollide = false
	end
	ramp(m, foot, flat, rise, run, width)
	return m, run
end

--==========================================================================
-- ROOFS
--
-- A gabled roof over a W (x) by D (z) box whose wall heads are at `B`'s y.
-- The ridge runs along X. Thatch is thick, and its thickness is the whole
-- look: a thin slab with a straw texture reads as a painted lid.
--==========================================================================
type RoofOpts = {
	kind: string?, -- "thatch" | "shingles"
	pitch: number?, -- degrees
	overhang: number?, -- at the eaves
	gableOver: number?, -- past the gable walls
	holes: number?, -- share of the slope missing (rafters show)
	burnt: boolean?, -- thatch gone: only charred rafters left
	chimneyX: number?, -- a chimney stack through the ridge at this x
	chimneys: { number }?, -- or several
	gableKey: string?, -- what the gable triangles are made of (default daub)
	gableTint: Color3?, -- and their colour (a limewashed house's gables match it)
}

local function roof(parent: Instance, B: CFrame, W: number, D: number, opts: RoofOpts)
	local r = model(parent, "Roof")
	local kind = opts.kind or "thatch"
	local pitch = math.rad(opts.pitch or (if kind == "thatch" then 50 else 40))
	local oh = opts.overhang or (if kind == "thatch" then 2.2 else 1.4)
	local go = opts.gableOver or (if kind == "thatch" then 1.6 else 1.0)
	local T = if kind == "thatch" then 2.6 else 0.7
	local run = D / 2 + oh
	local slope = run / math.cos(pitch)
	local height = (D / 2) * math.tan(pitch)
	local len = W + go * 2
	local rafterKey = if opts.burnt then "charred" else "oakDark"

	-- Rafters (seen under the eaves, and wherever the covering is gone).
	local nR = math.floor(W / 2.2)
	for i = 0, nR do
		local x = -W / 2 + W * i / nR
		for _, s in { -1, 1 } do
			local eave = B * CFrame.new(x, -oh * math.tan(pitch), s * run)
			local ridge = B * CFrame.new(x, height, 0)
			if opts.burnt and chance(0.35) then
				-- burnt through: a stub, or fallen in
				local stub = eave.Position:Lerp(ridge.Position, rand(0.2, 0.6))
				beam(r, "Rafter", eave.Position, stub, 0.6, 0.75, rafterKey)
			else
				beam(r, "Rafter", eave.Position, ridge.Position, 0.6, 0.75, rafterKey)
			end
		end
	end
	beam(r, "RidgePiece", (B * CFrame.new(-W / 2 - go * 0.5, height, 0)).Position, (B * CFrame.new(W / 2 + go * 0.5, height, 0)).Position, 0.8, 1.0, rafterKey)

	if opts.burnt then
		-- a few blackened battens still nailed on, and nothing else
		for _, s in { -1, 1 } do
			for k = 1, 4 do
				if chance(0.6) then
					local t = k / 5
					local y = -oh * math.tan(pitch) + (height + oh * math.tan(pitch)) * t
					local z = s * run * (1 - t)
					local x0 = rand(-W / 2, 0)
					beam(r, "Batten", (B * CFrame.new(x0, y + 0.45, z)).Position, (B * CFrame.new(x0 + rand(3, W / 2), y + 0.45, z)).Position, 0.3, 0.3, "charred")
				end
			end
		end
		return r
	end

	-- The covering, laid in strips along the ridge so holes can be left.
	local strips = math.max(3, math.floor(len / 6))
	local stripLen = len / strips
	for _, s in { -1, 1 } do
		-- slope frame: origin at the eave centre, X along the ridge, Y out of the roof, Z up the slope
		local eaveLine = B * CFrame.new(0, -oh * math.tan(pitch), s * run)
		local S = eaveLine * CFrame.Angles(s * pitch, 0, 0)
		-- with s = 1 the slope rises toward -z: tilt so local +Z points down-slope
		for k = 0, strips - 1 do
			local x = -len / 2 + stripLen * (k + 0.5)
			local missing = (opts.holes or 0) > 0 and chance(opts.holes :: number)
			local mainKey = if kind == "thatch" then (if chance(0.18) then "thatchMoss" else "thatch") else "shingles"
			local SC = S * CFrame.new(x, T / 2 + 0.35, -s * slope / 2)
			if missing then
				-- the hole: covering only on the lower third, battens across the gap
				local keep = slope * rand(0.25, 0.45)
				part(r, "Covering", Vector3.new(stripLen + 0.02, T, keep), S * CFrame.new(x, T / 2 + 0.35, -s * keep / 2), mainKey)
				for b = 1, 4 do
					local zz = -s * (keep + (slope - keep) * b / 5)
					part(r, "Batten", Vector3.new(stripLen, 0.25, 0.35), S * CFrame.new(x, 0.55, zz), rafterKey)
				end
			else
				local p = part(r, "Covering", Vector3.new(stripLen + 0.02, T + jit(0.12), slope), SC, mainKey)
				p.CFrame = p.CFrame * CFrame.Angles(jit(0.006), 0, 0)
			end
		end
		if kind == "thatch" then
			-- The eave lip: thatch does not end in a sharp edge, it ends in a roll.
			local lip = part(r, "Eave", Vector3.new(len, T * 0.9, T * 0.9), S * CFrame.new(0, T * 0.45 + 0.35, -s * 0.1), "thatch")
			;(lip :: Part).Shape = Enum.PartType.Cylinder
			lip.CFrame = lip.CFrame * CFrame.Angles(0, 0, 0) -- cylinder axis along X already
			-- moss and damp along the lowest course
			for k = 0, strips - 1 do
				if chance(0.45) then
					local x = -len / 2 + stripLen * (k + rand(0.2, 0.8))
					part(r, "Moss", Vector3.new(rand(1.5, 4), 0.3, rand(1.5, 3)), S * CFrame.new(x, T + 0.42, -s * rand(0.5, 2.5)), "thatchOld")
				end
			end
		end
	end

	-- The ridge.
	if kind == "thatch" then
		local ridgeR = T * 0.95
		local ridgeCap = part(r, "RidgeRoll", Vector3.new(len + 0.2, ridgeR * 2, ridgeR * 2), B * CFrame.new(0, height + T * 0.85, 0), "thatchMoss")
		;(ridgeCap :: Part).Shape = Enum.PartType.Cylinder
		-- the sedge capping block, scalloped along both lower edges
		for _, s in { -1, 1 } do
			local n = math.floor(len / 1.8)
			for k = 0, n - 1 do
				local x = -len / 2 + len * (k + 0.5) / n
				local sc = B * CFrame.new(x, height + T * 0.2, s * (T * 0.9)) * CFrame.Angles(s * pitch, 0, 0)
				local scal = part(r, "Scallop", Vector3.new(len / n * 0.92, 0.5, 1.4), sc, "thatchMoss")
				scal.CastShadow = false
			end
			-- liggers: hazel rods pinned along the capping, with crossed spars
			local lz = s * (T * 0.75)
			beam(r, "Ligger", (B * CFrame.new(-len / 2, height + T * 0.95, lz)).Position, (B * CFrame.new(len / 2, height + T * 0.95, lz)).Position, 0.14, 0.14, "oak")
			for k = 0, math.floor(len / 1.4) do
				local x = -len / 2 + k * 1.4
				local a = B * CFrame.new(x, height + T * 1.0, lz)
				local b = B * CFrame.new(x + 0.7, height + T * 0.45, lz * 1.6)
				beam(r, "Spar", a.Position, b.Position, 0.1, 0.1, "oak")
			end
		end
	else
		beam(r, "RidgeBoard", (B * CFrame.new(-len / 2, height + T, 0)).Position, (B * CFrame.new(len / 2, height + T, 0)).Position, 1.1, 0.5, "oakDark")
	end

	-- Gable ends: a triangle of frame and daub (two wedges) with barge boards.
	for _, gx in { -1, 1 } do
		local G = B * CFrame.new(gx * W / 2, 0, 0)
		local tri = model(r, "Gable")
		for _, s in { -1, 1 } do
			local stoneGable = opts.gableKey == "rubble"
			-- a stone gable is the wall carried up, as thick as the wall; it
			-- stands inside the line of the wall's outer face
			local gt = if stoneGable then 2.4 else INFILL
			local w = wedge(tri, "GableFill", Vector3.new(gt, height, D / 2), G * CFrame.new(if stoneGable then -gx * gt / 2 else 0, height / 2, s * D / 4) * CFrame.Angles(0, if s > 0 then math.pi else 0, 0), opts.gableKey or "daub", opts.gableTint) -- a wedge is tallest at its +Z face: turn it to rise toward the ridge
			w.CastShadow = stoneGable
		end
		if opts.gableKey ~= "rubble" then
			beam(tri, "KingPost", (G * CFrame.new(-gx * 0.05, 0, 0)).Position, (G * CFrame.new(-gx * 0.05, height, 0)).Position, FRAME, FRAME, "oak")
			beam(tri, "Collar", (G * CFrame.new(-gx * 0.05, height * 0.5, -D / 4)).Position, (G * CFrame.new(-gx * 0.05, height * 0.5, D / 4)).Position, FRAME, FRAME, "oak")
		end
		for _, s in { -1, 1 } do
			local a = B * CFrame.new(gx * (W / 2 + go - 0.3), -oh * math.tan(pitch) + T * 0.5, s * run)
			local b = B * CFrame.new(gx * (W / 2 + go - 0.3), height + T * 0.15, 0)
			beam(r, "Barge", a.Position, b.Position, 0.45, 1.3, "oakDark")
		end
	end

	-- Chimney stacks through the ridge.
	for _, cx in (opts.chimneys or (if opts.chimneyX then { opts.chimneyX } else {})) do
		local top = height + T + 4
		local bottom = -B.Position.Y + GROUND -- from the ground
		local stack = part(r, "Chimney", Vector3.new(3.4, top - bottom, 3.4), B * CFrame.new(cx, (top + bottom) / 2, 0), "rubble")
		stack.CastShadow = true
		part(r, "ChimneyCap", Vector3.new(4.1, 0.6, 4.1), B * CFrame.new(cx, top + 0.3, 0), "stone")
		part(r, "ChimneyCap", Vector3.new(3.6, 0.5, 3.6), B * CFrame.new(cx, top + 0.85, 0), "soot")
		local pot = part(r, "Flue", Vector3.new(1.9, 1.4, 1.9), B * CFrame.new(cx, top + 1.5, 0), "soot")
		pot.CanCollide = false
		local smokeAt = part(r, "SmokeFrom", Vector3.new(0.5, 0.5, 0.5), B * CFrame.new(cx, top + 2.4, 0), "dark")
		smokeAt.Transparency = 1
		smokeAt.CanCollide = false
		smokeOn(smokeAt, 3)
	end
	return r
end

--==========================================================================
-- A BUILDING
--
-- `B` is the building's frame on the ground: origin at the centre of its
-- footprint, -Z is the FRONT (the street side). W along x, D along z.
--==========================================================================
-- Defined with the stonework below; declared here so house() can use it.
local stoneWall: (parent: Instance, W: CFrame, L: number, H: number, bays: { string }, opts: WallOpts) -> Model

type HouseOpts = {
	name: string?,
	W: number,
	D: number,
	storeys: number?, -- 1 or 2
	plinth: number?, -- height of the stone base
	storeyH: number?,
	jetty: number?, -- how far the upper storey oversails the front
	front: { string }?, -- bays, ground floor front
	back: { string }?,
	left: { string }?,
	right: { string }?,
	upperFront: { string }?,
	roof: RoofOpts?,
	burnt: boolean?,
	damage: number?,
	glow: boolean?,
	stairs: boolean?, -- an inside stair to the upper floor
	ground: string?, -- "stone": the ground storey in rubble masonry
	raised: boolean?, -- stands on something else (staddles): no stone base
	furnish: ((m: Model, B: CFrame, info: any) -> ())?,
	limewash: Color3?, -- the daub's colour, the whole house
	hingeRight: boolean?, -- (a door in an end wall: its leaf must lie away from the stair foot)
}

local function house(parent: Instance, B: CFrame, o: HouseOpts): Model
	local m = model(nil, o.name or "House")
	local W, D = o.W, o.D
	local storeys = o.storeys or 2
	local plinthH = o.plinth or 1.6
	local SH = o.storeyH or 10.5
	local jetty = if storeys > 1 then (o.jetty or 1.4) else 0
	local wallOpts: WallOpts = { burnt = o.burnt, damage = o.damage or 0.06, glow = o.glow, plinth = if o.raised then nil else (o.plinth or 1.6), limewash = o.limewash, hingeRight = o.hingeRight }

	if o.raised then
		-- a platform of heavy bearers instead of a stone base
		for _, z in { -D / 2 + 0.6, 0, D / 2 - 0.6 } do
			beam(m, "Bearer", (B * CFrame.new(-W / 2 - 0.4, plinthH / 2, z)).Position, (B * CFrame.new(W / 2 + 0.4, plinthH / 2, z)).Position, 0.9, plinthH, "oakDark")
		end
	else
		-- The plinth: rubble stone, with a slightly wider footing course.
		part(m, "Footing", Vector3.new(W + 1.4, 0.8, D + 1.4), B * CFrame.new(0, 0.2, 0), "rubble")
		part(m, "Plinth", Vector3.new(W + 0.5, plinthH, D + 0.5), B * CFrame.new(0, plinthH / 2, 0), "rubble")
	end
	-- big quoin stones at the corners
	for _, cx in (if o.raised then {} else { -1, 1 }) do
		for _, cz in { -1, 1 } do
			for k = 0, 1 do
				local q = part(m, "Quoin", Vector3.new(rand(1.4, 2.1), plinthH * 0.5 + jit(0.1), rand(1.2, 1.8)), B * CFrame.new(cx * (W / 2 + 0.1), plinthH * (0.25 + k * 0.5), cz * (D / 2 + 0.1)) * CFrame.Angles(0, jit(0.08), 0), "stone")
				q.CastShadow = false
			end
		end
	end

	-- Ground floor.
	local G = B * CFrame.new(0, plinthH, 0)
	boards(m, G * CFrame.new(0, 0.16, 0), W - 1, D - 1, wallOpts)
	local function walls(F: CFrame, w: number, d: number, h: number, front, back, left, right, opts: WallOpts, stone: boolean?)
		local build = if stone then stoneWall else frameWall
		-- front (-Z face), left-to-right as seen from outside
		build(m, F * CFrame.new(-w / 2, 0, -d / 2), w, h, front, opts)
		-- back (+Z face), seen from outside: runs +x to -x
		build(m, F * CFrame.new(w / 2, 0, d / 2) * CFrame.Angles(0, math.pi, 0), w, h, back, opts)
		-- left (-X face): seen from outside it runs back (+z) to front (-z)
		build(m, F * CFrame.new(-w / 2, 0, d / 2) * CFrame.Angles(0, math.pi / 2, 0), d, h, left, opts)
		-- right (+X face): front (-z) to back (+z)
		build(m, F * CFrame.new(w / 2, 0, -d / 2) * CFrame.Angles(0, -math.pi / 2, 0), d, h, right, opts)
	end
	local stoneGround = o.ground == "stone"
	-- inside a stone storey everything stands clear of 2.2 of masonry
	local inset = if stoneGround then STONE_T - 0.3 else 0
	local nW = math.max(2, math.floor(W / 4.6))
	local nD = math.max(2, math.floor(D / 4.6))
	local function fill(list, n, default)
		local out = {}
		for i = 1, n do
			out[i] = (list and list[i]) or default
		end
		return out
	end
	walls(G, W, D, SH, fill(o.front, nW, "wall"), fill(o.back, nW, "wall"), fill(o.left, nD, "wall"), fill(o.right, nD, "wall"), wallOpts, stoneGround)

	local top = plinthH + SH
	local info = { W = W, D = D, plinthH = plinthH, SH = SH, storeys = storeys }

	if storeys > 1 then
		local U = B * CFrame.new(0, top, -jetty / 2)
		local Wu, Du = W, D + jetty
		-- The stair well, worked out first: nothing may cross over it, or a
		-- body climbing the flight hits its head (and the pathfinder, which
		-- needs 6 studs of headroom, decides the floor above cannot be reached).
		-- 43 degrees: steep, as these stairs were. The pathfinder climbs a ramp
		-- up to 45 and refuses 48 (measured 2026-10-20).
		local TREAD = 1.0
		-- The flight must END FLUSH with the floor above: its ramp reaches the
		-- upper boards' top (SH + 1.11 over G) exactly where the well ends. Any
		-- lip or gap there and the pathfinder treats the loft as an island.
		local rise = SH + 1.11 - 0.3
		local stairRun = math.ceil(rise / 0.95) * TREAD
		-- the foot stands 3.5 in from the end wall so it can be walked onto
		local wellX0 = -W / 2 + 3.5 + inset
		local STAIR_W = 4.0 -- the pathfinder needs room for a 2-wide body plus margin
		local wellZ = D / 2 - 2.55 - inset
		local well = { wellX0 - 0.3, wellX0 + stairRun, wellZ - 2.15, wellZ + 2.15 }
		local hasStair = o.stairs ~= false
		-- ...and there must be FLOOR beyond its head: a flight that runs into
		-- the end wall leaves whoever climbs it standing on the top step with
		-- nowhere to go (every cottage was like that until 2026-10-20). The
		-- landing is what lets them step off sideways onto the floor.
		local landing = (W / 2 - 0.7 - inset) - (wellX0 + stairRun)
		if hasStair and landing < 2.6 then
			warn(("[Wards] %s: only %.1f of landing at the stair head; make it wider"):format(o.name or "House", landing))
		end
		-- Joists across the building, their ends showing where the front jetties
		-- out; over the well they are trimmed short and stop on a trimmer beam.
		local nJ = math.floor(W / 1.6)
		for i = 0, nJ do
			local x = -W / 2 + 0.5 + (W - 1) * i / nJ
			local back = D / 2
			if hasStair and x > well[1] - 0.5 and x < well[2] + 0.5 then
				back = well[3] - 0.3
			end
			beam(m, "Joist", (B * CFrame.new(x, top + 0.4, back)).Position, (B * CFrame.new(x, top + 0.4, -D / 2 - jetty - 0.4)).Position, 0.75, 0.8, if o.burnt then "charred" else "oakDark")
		end
		if hasStair then
			beam(m, "Trimmer", (B * CFrame.new(well[1] - 0.6, top + 0.4, well[3] - 0.5)).Position, (B * CFrame.new(well[2] + 0.6, top + 0.4, well[3] - 0.5)).Position, 0.8, 0.9, if o.burnt then "charred" else "oakDark")
		end
		-- the bressumer: the heavy beam the oversailing front stands on
		beam(m, "Bressumer", (B * CFrame.new(-W / 2 - 0.3, top + 0.4, -D / 2 - jetty)).Position, (B * CFrame.new(W / 2 + 0.3, top + 0.4, -D / 2 - jetty)).Position, 1.1, 1.1, if o.burnt then "charred" else "oak")
		-- upper floor, with the stair well along the back wall (the flight runs
		-- along the LONG side so it fits). The boards are laid in U, which sits
		-- jetty/2 forward of B.
		boards(m, U * CFrame.new(0, 0.95, 0), Wu - 0.8, Du - 0.8, wallOpts, if o.stairs ~= false then { { well[1], well[2], well[3] + jetty / 2, well[4] + jetty / 2 } } else nil)
		local upperOpts = table.clone(wallOpts)
		upperOpts.close = true
		upperOpts.plinth = nil
		local U2 = B * CFrame.new(0, top + 0.8, -jetty / 2)
		walls(U2, Wu, Du, SH - 1.4, fill(o.upperFront, nW, "window"), fill(nil, nW, if chance(0.5) then "window" else "wall"), fill(nil, nD, "wall"), fill(nil, math.max(2, math.floor(Du / 4.6)), "wall"), upperOpts)
		if o.stairs ~= false then
			local foot = (G * CFrame.new(wellX0, 0.3, wellZ)).Position
			stair(m, foot, (G.RightVector), rise, STAIR_W, nil, TREAD)
			-- a handrail on the open side over the middle of the flight only: the
			-- foot is walked onto end-on, the top is stepped off sideways
			local railZ = wellZ - 2.3
			for k = 1, 2 do
				local x = wellX0 + stairRun * k / 3
				local y = 0.3 + rise * k / 3
				beam(m, "Baluster", (G * CFrame.new(x, y, railZ)).Position, (G * CFrame.new(x, y + 3.2, railZ)).Position, 0.35, 0.35, "oakDark")
			end
			beam(m, "Handrail", (G * CFrame.new(wellX0 + stairRun / 3, rise / 3 + 3.5, railZ)).Position, (G * CFrame.new(wellX0 + stairRun * 2 / 3, rise * 2 / 3 + 3.5, railZ)).Position, 0.3, 0.4, "oak")
		end
		info.upperY = top + 1.1
		-- where a test can stand to ask "can the dead get up here?": the
		-- front of the upper floor, away from the stair
		m:SetAttribute("UpperProbe", (B * CFrame.new(-1, info.upperY + 2.5, -D / 2 + 3)).Position)
		local roofB = B * CFrame.new(0, top + 0.8 + SH - 1.4, -jetty / 2)
		local ro = table.clone((o.roof or {}) :: RoofOpts)
		ro.gableTint = ro.gableTint or o.limewash
		if ro.kind == "deck" then
			-- A FIGHTING DECK instead of a roof: boards on joists, a breastwork
			-- with crenels, and a second flight up from the upper floor along the
			-- inside of the front wall. Reached by a ramp, like every floor here.
			local dk = roofB
			local upRise = SH - 0.59 -- upper floor top (top + 1.11) to the deck boards' top (top + SH + 0.52)
			local upRun = math.ceil(upRise / 0.95) * TREAD
			local sx0 = -Wu / 2 + 3.5
			local sz = -Du / 2 + 2.55
			local nJ = math.floor(Wu / 1.8)
			for i = 0, nJ do
				local x = -Wu / 2 + 0.4 + (Wu - 0.8) * i / nJ
				local front = -Du / 2 - 0.5
				if x > sx0 - 0.8 and x < sx0 + upRun + 0.5 then
					front = sz + 2.45 -- trimmed clear of the flight
				end
				beam(m, "DeckJoist", (dk * CFrame.new(x, 0.4, front)).Position, (dk * CFrame.new(x, 0.4, Du / 2 + 0.5)).Position, 0.7, 0.8, if o.burnt then "charred" else "oakDark")
			end
			boards(m, dk * CFrame.new(0, 0.96, 0), Wu + 0.6, Du + 0.6, wallOpts, { { sx0 - 0.3, sx0 + upRun, sz - 2.15, sz + 2.15 } })
			stair(m, (B * CFrame.new(sx0, top + 1.11, -jetty / 2 + sz)).Position, B.RightVector, upRise, STAIR_W, nil, TREAD)
			-- the breastwork
			local function breast(a: Vector3, b: Vector3)
				local len = (b - a).Magnitude
				local n = math.max(2, math.floor(len / 2.6))
				for k = 0, n do
					local p = a:Lerp(b, k / n)
					beam(m, "BreastPost", p, p + Vector3.new(0, 4.4, 0), 0.5, 0.5, "oakDark")
				end
				for k = 0, n - 1 do
					if k % 3 ~= 1 then -- every third bay a crenel to shoot through
						local p0, p1 = a:Lerp(b, k / n), a:Lerp(b, (k + 1) / n)
						local mid = (p0 + p1) / 2
						local cf = CFrame.lookAt(mid, p1)
						for y = 0.75, 3.6, 0.95 do
							part(m, "BreastBoard", Vector3.new(0.3, 0.9, (p1 - p0).Magnitude), cf + Vector3.new(0, y, 0), "planks")
						end
					end
				end
				beam(m, "Coping", a + Vector3.new(0, 4.5, 0), b + Vector3.new(0, 4.5, 0), 0.6, 0.35, "oak")
			end
			local hw, hd = Wu / 2 + 0.2, Du / 2 + 0.2
			local y0 = 1.12
			local c1 = (dk * CFrame.new(-hw, y0, -hd)).Position
			local c2 = (dk * CFrame.new(hw, y0, -hd)).Position
			local c3 = (dk * CFrame.new(hw, y0, hd)).Position
			local c4 = (dk * CFrame.new(-hw, y0, hd)).Position
			breast(c1, c2)
			breast(c2, c3)
			breast(c3, c4)
			breast(c4, c1)
			info.deckY = top + 0.8 + SH - 1.4 + 1.12
			m:SetAttribute("DeckProbe", (dk * CFrame.new(Wu / 4, 1.12 + 2.5, Du / 4)).Position)
		else
			roof(m, roofB, Wu, Du, ro)
		end
	else
		local ro = table.clone((o.roof or {}) :: RoofOpts)
		ro.gableTint = ro.gableTint or o.limewash
		roof(m, B * CFrame.new(0, top, 0), W, D, ro)
	end

	-- Ceiling joists of the ground floor seen from inside (single storey: tie beams).
	if storeys == 1 then
		for i = 1, math.floor(W / 4) do
			local x = -W / 2 + W * i / (math.floor(W / 4) + 1)
			beam(m, "TieBeam", (B * CFrame.new(x, top - 0.5, -D / 2)).Position, (B * CFrame.new(x, top - 0.5, D / 2)).Position, 0.8, 0.9, if o.burnt then "charred" else "oakDark")
		end
	end

	if o.furnish then
		o.furnish(m, B, info)
	end

	m.Parent = parent
	return m
end

--==========================================================================
-- STONE
--
-- Rubble masonry, 2.2 thick, with dressed jambs and an oak lintel over every
-- opening. Same frame convention as frameWall: origin at the left end of the
-- OUTER face, +X along the wall, -Z outside (the masonry fills z 0..STONE_T).
--==========================================================================
function stoneWall(parent: Instance, W: CFrame, L: number, H: number, bays: { string }, opts: WallOpts): Model
	local wall = model(parent, "StoneWall")
	local n = #bays
	local bw = L / n
	local T = opts.T or STONE_T
	local dw, dh = opts.doorW or 4.2, opts.doorH or DOOR_H
	local ww, ws, wh = opts.winW or 2.6, opts.winSill or WIN_SILL, opts.winHead or WIN_HEAD
	local openings = {}
	for i, kind in bays do
		local cx = (i - 0.5) * bw
		if kind == "door" then
			table.insert(openings, { x0 = cx - dw / 2, x1 = cx + dw / 2, y0 = 0, y1 = dh, kind = "door" })
		elseif kind == "window" then
			table.insert(openings, { x0 = cx - ww / 2, x1 = cx + ww / 2, y0 = ws, y1 = wh, kind = "window" })
		elseif kind == "bay" then
			-- the whole bay open between two stone piers, under an oak lintel
			-- (a forge front, a cart shed)
			table.insert(openings, { x0 = (i - 1) * bw + 0.6, x1 = i * bw - 0.6, y0 = 0, y1 = opts.archH or 9, kind = "bay" })
		elseif kind == "arch" then
			-- an open archway: no leaves, no threshold (a chancel arch, a porch mouth)
			table.insert(openings, { x0 = cx - (opts.archW or 8) / 2, x1 = cx + (opts.archW or 8) / 2, y0 = 0, y1 = opts.archH or 10, kind = "arch" })
		elseif kind == "loop" then
			table.insert(openings, { x0 = cx - 0.35, x1 = cx + 0.35, y0 = 3.5, y1 = 7.5, kind = "loop" })
		end
	end
	local cuts = { 0, L }
	for _, o in openings do
		table.insert(cuts, o.x0)
		table.insert(cuts, o.x1)
	end
	table.sort(cuts)
	for i = 1, #cuts - 1 do
		local a, b = cuts[i], cuts[i + 1]
		if b - a > 0.05 then
			local mid = (a + b) / 2
			local spans = { { 0, H } }
			for _, o in openings do
				if mid > o.x0 and mid < o.x1 then
					local out = {}
					for _, s in spans do
						if o.y0 > s[1] then
							table.insert(out, { s[1], math.min(s[2], o.y0) })
						end
						if o.y1 < s[2] then
							table.insert(out, { math.max(s[1], o.y1), s[2] })
						end
					end
					spans = out
				end
			end
			for _, s in spans do
				if s[2] - s[1] > 0.05 then
					local tint = if opts.burnt then shade(MAT.rubble[3], 0.55) else nil
					part(wall, "Masonry", Vector3.new(b - a, s[2] - s[1], T), W * CFrame.new(mid, (s[1] + s[2]) / 2, T / 2), "rubble", tint)
				end
			end
		end
	end
	-- a darker band where rain splashes mud up the foot of the wall
	-- (paint only: it runs across the doorways too, so nothing may touch it)
	local splash = part(wall, "Splash", Vector3.new(L, 1.4, 0.12), W * CFrame.new(L / 2, 0.7, -0.05), "rubble", Color3.fromRGB(96, 84, 70))
	splash.CastShadow = false
	splash.CanCollide = false
	splash.CanQuery = false
	splash.CanTouch = false
	for _, o in openings do
		local w = o.x1 - o.x0
		local cx = (o.x0 + o.x1) / 2
		local pointed = opts.lancet and o.kind ~= "loop"
		if pointed then
			-- A pointed head: the two upper corners of the opening filled with
			-- masonry, sloping up to meet at the middle. (A wedge is tallest at
			-- its +Z face; turned upside down, solid above the slope.)
			local ah = math.min(w * 0.62, (o.y1 - o.y0) * 0.45)
			for _, sgn in { -1, 1 } do
				local jx = if sgn < 0 then o.x0 + w / 4 else o.x1 - w / 4
				local wg = wedge(wall, "ArchHead", Vector3.new(T, ah, w / 2), W * CFrame.new(jx, o.y1 - ah / 2, T / 2) * CFrame.Angles(0, sgn * math.pi / 2, 0) * CFrame.Angles(0, 0, math.pi), "rubble", if opts.burnt then shade(MAT.rubble[3], 0.55) else nil)
				wg.CastShadow = false
			end
			-- the dressed voussoirs along the arch
			for k = 0, 5 do
				local t = k / 5
				for _, sgn in { -1, 1 } do
					local px = cx + sgn * (w / 2 + 0.35) * (1 - t)
					local py = o.y1 - ah + ah * t + 0.35
					part(wall, "Voussoir", Vector3.new(0.9, 0.8, T + 0.12), W * CFrame.new(px, py, T / 2) * CFrame.Angles(0, 0, -sgn * math.atan2(ah, w / 2)), "stone", shade(MAT.stone[3], 0.8)).CastShadow = false
				end
			end
		elseif o.kind ~= "loop" then
			-- (between bays the pier is narrow: the lintels must not meet over it)
			local ext = if o.kind == "bay" then 0.5 else 0.9
			beam(wall, "Lintel", (W * CFrame.new(o.x0 - ext, o.y1 + 0.5, T * 0.35)).Position, (W * CFrame.new(o.x1 + ext, o.y1 + 0.5, T * 0.35)).Position, T * 0.7, if w > 5 then 1.6 else 1.0, if opts.burnt then "charred" else "oakDark", W.ZVector)
		end
		for _, jx in (if o.kind == "bay" then {} else { o.x0 - 0.45, o.x1 + 0.45 }) do
			local y = o.y0 + 0.6
			local k = 0
			local stop = if pointed then o.y1 - math.min(w * 0.62, (o.y1 - o.y0) * 0.45) else o.y1 - 0.3
			while y < stop do
				local big = (k % 2 == 0)
				part(wall, "Jamb", Vector3.new(if big then 1.3 else 0.9, 1.15, T + 0.12), W * CFrame.new(jx + (if big then (if jx < cx then -0.2 else 0.2) else 0), y, T / 2), "stone")
				y += 1.25
				k += 1
			end
		end
		if o.kind == "window" then
			part(wall, "WinSill", Vector3.new(w + 1, 0.45, T + 0.6), W * CFrame.new(cx, o.y0 - 0.22, T / 2 - 0.25), "stone")
			local bars = math.max(1, math.floor(w / 0.8))
			for k = 1, bars do
				local bx = o.x0 + w * k / (bars + 1)
				pole(wall, "WinBar", (W * CFrame.new(bx, o.y0, T * 0.3)).Position, (W * CFrame.new(bx, o.y1, T * 0.3)).Position, 0.09, "ironDark")
			end
			if opts.lancet then
				-- leaded glass, mostly gone: a few dull panes left in the lights
				for k = 0, bars do
					if chance(0.35) then
						local gx = o.x0 + w * (k + 0.5) / (bars + 1)
						local pane = part(wall, "Pane", Vector3.new(w / (bars + 1) - 0.1, rand(1.5, 4), 0.06), W * CFrame.new(gx, o.y0 + rand(1, 3), T * 0.32), "water", Color3.fromRGB(70, 82, 74))
						pane.Transparency = 0.45
						pane.CastShadow = false
					end
				end
			end
			if opts.glow then
				local g = part(wall, "Glow", Vector3.new(w, o.y1 - o.y0, 0.1), W * CFrame.new(cx, (o.y0 + o.y1) / 2, T - 0.2), "ember")
				g.Transparency = 0.72
				g.CanCollide = false
				g.CastShadow = false
				pointLight(g, Color3.fromRGB(255, 160, 80), 0.3, 9)
			end
		elseif o.kind == "bay" then
			-- paved through the thickness of the wall, level with the floor
			part(wall, "Threshold", Vector3.new(w + 0.6, 0.3, T), W * CFrame.new(cx, (opts.threshold or 0.32) - 0.15, T / 2), "stone")
			if (opts.plinth or 0) > 0.3 then
				doorSteps(wall, W, cx, w, opts.plinth :: number)
			end
		elseif o.kind == "door" then
			-- hung at the inside face, so the leaf swings back along it
			local DW = W * CFrame.new(0, 0, T - 0.45)
			if w > 5 then
				-- a pair of leaves, both swung back inside
				door(wall, DW, o.x0, cx, 0, opts)
				door(wall, DW, cx, o.x1, 0, opts, true)
			else
				door(wall, DW, o.x0, o.x1, 0, opts, opts.hingeRight)
			end
			local th = opts.threshold or 0.32
			part(wall, "Threshold", Vector3.new(w + 0.6, 0.3, T), W * CFrame.new(cx, th - 0.15, T / 2), "stone")
			if (opts.plinth or 0) > 0.3 then
				doorSteps(wall, W, cx, w, opts.plinth :: number)
			end
		end
	end
	return wall
end

--==========================================================================
-- SHEDS, TENTS, FENCES, THE CLUTTER OF A GARRISON
--==========================================================================

-- A lean-to against a wall: its BACK (+Z of B) is the high side.
local function leanTo(parent: Instance, B: CFrame, W: number, D: number, hHigh: number, hLow: number, opts: { kind: string?, burnt: boolean?, sides: boolean? }?)
	local o = opts or {}
	local m = model(parent, "LeanTo")
	local key = if o.burnt then "charred" else "oak"
	local posts = math.max(2, math.floor(W / 5) + 1)
	for i = 0, posts - 1 do
		local x = -W / 2 + W * i / (posts - 1)
		pole(m, "Post", (B * CFrame.new(x, 0, -D / 2)).Position, (B * CFrame.new(x, hLow, -D / 2)).Position, 0.45, key)
		pole(m, "WallPost", (B * CFrame.new(x, 0, D / 2 - 0.4)).Position, (B * CFrame.new(x, hHigh, D / 2 - 0.4)).Position, 0.4, key)
		-- a pad stone under each front post
		part(m, "PadStone", Vector3.new(1.4, 0.5, 1.4), B * CFrame.new(x, 0.15, -D / 2), "stone")
	end
	beam(m, "Plate", (B * CFrame.new(-W / 2 - 0.5, hLow, -D / 2)).Position, (B * CFrame.new(W / 2 + 0.5, hLow, -D / 2)).Position, 0.8, 0.8, key)
	beam(m, "WallPlate", (B * CFrame.new(-W / 2 - 0.5, hHigh, D / 2 - 0.4)).Position, (B * CFrame.new(W / 2 + 0.5, hHigh, D / 2 - 0.4)).Position, 0.8, 0.8, key)
	local over = 1.6
	local a = B * CFrame.new(0, hLow - over * (hHigh - hLow) / D, -D / 2 - over)
	local b = B * CFrame.new(0, hHigh, D / 2)
	local nR = math.floor(W / 2)
	for i = 0, nR do
		local x = -W / 2 + W * i / nR
		beam(m, "Rafter", (a * CFrame.new(x, 0.4, 0)).Position, (b * CFrame.new(x, 0.4, 0)).Position, 0.45, 0.6, if o.burnt then "charred" else "oakDark")
	end
	if not o.burnt then
		local kind = o.kind or "shingles"
		local T = if kind == "thatch" then 2.0 else 0.6
		local mid = (a.Position + b.Position) / 2
		local len = (b.Position - a.Position).Magnitude
		local cf = CFrame.lookAt(mid, b.Position) * CFrame.new(0, T / 2 + 0.7, 0)
		part(m, "Roof", Vector3.new(W + 1.6, T, len), cf, if kind == "thatch" then "thatch" else "shingles")
	end
	if o.sides then
		for _, s in { -1, 1 } do
			for y = 0.6, hLow - 0.4, 1.0 do
				part(m, "SideBoard", Vector3.new(0.3, 0.95, D - 0.6), B * CFrame.new(s * W / 2, y, 0) * CFrame.Angles(0, 0, jit(0.01)), if o.burnt then "charred" else "planks")
			end
		end
	end
	return m
end

-- An open shed: posts and a gabled roof, nothing between.
local function openShed(parent: Instance, B: CFrame, W: number, D: number, H: number, roofOpts: RoofOpts)
	local m = model(parent, "Shed")
	local key = if roofOpts.burnt then "charred" else "oak"
	local nx = math.max(2, math.floor(W / 5) + 1)
	for i = 0, nx - 1 do
		local x = -W / 2 + W * i / (nx - 1)
		for _, s in { -1, 1 } do
			pole(m, "Post", (B * CFrame.new(x, 0, s * D / 2)).Position, (B * CFrame.new(x, H, s * D / 2)).Position, 0.5, key)
			part(m, "PadStone", Vector3.new(1.5, 0.5, 1.5), B * CFrame.new(x, 0.15, s * D / 2), "stone")
			-- knee braces
			local kx = if i == 0 then 1.8 elseif i == nx - 1 then -1.8 else 1.8
			beam(m, "Knee", (B * CFrame.new(x, H - 2.2, s * D / 2)).Position, (B * CFrame.new(x + kx, H - 0.4, s * D / 2)).Position, 0.4, 0.4, key)
		end
		beam(m, "TieBeam", (B * CFrame.new(x, H - 0.4, -D / 2 - 0.4)).Position, (B * CFrame.new(x, H - 0.4, D / 2 + 0.4)).Position, 0.7, 0.8, key)
	end
	for _, s in { -1, 1 } do
		beam(m, "Plate", (B * CFrame.new(-W / 2 - 0.6, H, s * D / 2)).Position, (B * CFrame.new(W / 2 + 0.6, H, s * D / 2)).Position, 0.8, 0.8, key)
	end
	roof(m, B * CFrame.new(0, H + 0.4, 0), W, D, roofOpts)
	return m
end

-- A soldier's ridge tent: two uprights, a ridge pole, canvas, guy lines.
local function tent(parent: Instance, B: CFrame, w: number, d: number, h: number, state: string?)
	local m = model(parent, "Tent")
	local burnt = state == "burnt"
	local down = state == "collapsed"
	local hh = if down then h * 0.35 else h
	for _, s in { -1, 1 } do
		if not down then
			pole(m, "Upright", (B * CFrame.new(s * d / 2, 0, 0)).Position, (B * CFrame.new(s * d / 2, hh + 0.5, 0)).Position, 0.18, if burnt then "charred" else "oak")
		end
	end
	pole(m, "Ridge", (B * CFrame.new(-d / 2 - 0.3, hh, 0)).Position, (B * CFrame.new(d / 2 + 0.3, hh, 0)).Position, 0.15, if burnt then "charred" else "oak")
	for _, side in { -1, 1 } do
		local foot = B * CFrame.new(0, 0.1, side * w / 2)
		local top = B * CFrame.new(0, hh, 0)
		local len = (top.Position - foot.Position).Magnitude
		local panels = 4
		for k = 0, panels - 1 do
			if burnt and chance(0.45) then
				continue
			end
			local x = -d / 2 + d * (k + 0.5) / panels
			local a = foot * CFrame.new(x, 0, 0)
			local b = top * CFrame.new(x, 0, 0)
			local frac = if burnt then rand(0.4, 1) else 1
			local mid = a.Position:Lerp(b.Position, frac / 2)
			local cv = part(m, "Canvas", Vector3.new(d / panels + 0.05, 0.12, len * frac), CFrame.lookAt(mid, b.Position) * CFrame.Angles(0, 0, jit(0.03)), "burlap", if burnt then Color3.fromRGB(70, 62, 54) else Color3.fromRGB(196, 184, 160))
			cv.CastShadow = true
		end
		-- guy lines to pegs
		for _, s in { -1, 1 } do
			local peg = (B * CFrame.new(s * (d / 2 + 1.5), 0.4, side * (w / 2 + 2.2))).Position
			beam(m, "Guy", (B * CFrame.new(s * d / 2, hh * 0.9, side * 0.3)).Position, peg, 0.06, 0.06, "linen")
			pole(m, "Peg", peg - Vector3.new(0, 0.3, 0), peg + Vector3.new(0, 0.5, 0), 0.08, "oak")
		end
	end
	if burnt then
		for _ = 1, 3 do
			part(m, "Ash", Vector3.new(rand(1.5, 3), 0.15, rand(1.5, 3)), B * CFrame.new(rand(-d / 2, d / 2), 0.05, rand(-w / 3, w / 3)), "soot")
		end
	end
	return m
end

-- Post and rail, following a list of points. `broken` is the share of rails down.
local function fence(parent: Instance, pts: { Vector3 }, broken: number?)
	local m = model(parent, "Fence")
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local len = (b - a).Magnitude
		local n = math.max(1, math.floor(len / 3))
		for k = 0, n do
			local p = a:Lerp(b, k / n)
			local lean = CFrame.Angles(jit(0.06), 0, jit(0.06))
			local post = part(m, "Post", Vector3.new(0.55, 4.2, 0.55), CFrame.new(p + Vector3.new(0, 2.0, 0)) * lean, "oakDark")
			post.CastShadow = false
			if k < n then
				local q = a:Lerp(b, (k + 1) / n)
				for _, y in { 1.5, 3.2 } do
					if chance(broken or 0.1) then
						-- a rail down, one end still on its post
						beam(m, "Rail", p + Vector3.new(0, y, 0), q + Vector3.new(jit(0.4), 0.2, jit(0.4)), 0.35, 0.5, "oak")
					else
						beam(m, "Rail", p + Vector3.new(0, y + jit(0.1), 0), q + Vector3.new(0, y + jit(0.1), 0), 0.35, 0.5, "oak")
					end
				end
			end
		end
	end
	return m
end

-- Sharpened stakes driven in at an angle, points toward `facing`.
local function stakes(parent: Instance, a: Vector3, b: Vector3, facing: Vector3)
	local m = model(parent, "Stakes")
	local len = (b - a).Magnitude
	local f = Vector3.new(facing.X, 0, facing.Z).Unit
	for k = 0, math.floor(len / 1.3) do
		local p = a:Lerp(b, k / math.max(1, math.floor(len / 1.3))) + Vector3.new(jit(0.3), 0, jit(0.3))
		local l = rand(5, 7)
		local tip = p + f * (l * 0.6) + Vector3.new(0, l * 0.8, 0)
		pole(m, "Stake", p - f * 0.4, tip, rand(0.22, 0.3), "oak")
		local pt = part(m, "Point", Vector3.new(0.5, 0.5, 0.9), CFrame.lookAt(tip, tip + (tip - p).Unit) * CFrame.new(0, 0, -0.3), "oakDark")
		pt.CastShadow = false
	end
	return m
end

local function arrow(parent: Instance, at: Vector3, dir: Vector3)
	local d = dir.Unit
	local tail = at - d * 2.4
	pole(parent, "Shaft", tail, at, 0.05, "oak")
	for k = 0, 2 do
		local f = part(parent, "Fletch", Vector3.new(0.04, 0.3, 0.7), CFrame.lookAt(tail + d * 0.4, tail + d) * CFrame.Angles(0, 0, k * math.pi * 2 / 3) * CFrame.new(0, 0.12, 0), "linen")
		f.CastShadow = false
		f.CanCollide = false
	end
end

local function shield(parent: Instance, cf: CFrame, colour: Color3?)
	local s = part(parent, "Shield", Vector3.new(0.25, 2.8, 2.8), cf, "planks", colour or pick({ Color3.fromRGB(120, 44, 40), Color3.fromRGB(150, 140, 120), Color3.fromRGB(60, 70, 90) }))
	;(s :: Part).Shape = Enum.PartType.Cylinder
	ball(parent, "Boss", Vector3.new(0.7, 0.7, 0.7), cf * CFrame.new(-0.2, 0, 0), "ironDark")
	local rim = part(parent, "Rim", Vector3.new(0.2, 2.95, 2.95), cf * CFrame.new(0.03, 0, 0), "iron")
	;(rim :: Part).Shape = Enum.PartType.Cylinder
	return s
end

local function helmet(parent: Instance, cf: CFrame)
	local h = ball(parent, "Helm", Vector3.new(1.3, 1.1, 1.4), cf * CFrame.new(0, 0.35, 0), "ironDark")
	part(parent, "Brim", Vector3.new(1.8, 0.1, 1.9), cf * CFrame.new(0, 0.12, 0), "iron")
	return h
end

-- Spears in a rack: two posts, two bars, the shafts leaning in.
local function spearRack(parent: Instance, cf: CFrame, n: number)
	local m = model(parent, "SpearRack")
	for _, s in { -1, 1 } do
		beam(m, "Upright", (cf * CFrame.new(s * 2.6, 0, 0)).Position, (cf * CFrame.new(s * 2.6, 5.2, 0)).Position, 0.45, 0.45, "oakDark")
	end
	beam(m, "Bar", (cf * CFrame.new(-2.9, 4.6, 0)).Position, (cf * CFrame.new(2.9, 4.6, 0)).Position, 0.35, 0.45, "oak")
	beam(m, "Bar", (cf * CFrame.new(-2.9, 0.6, -0.6)).Position, (cf * CFrame.new(2.9, 0.6, -0.6)).Position, 0.35, 0.45, "oak")
	for i = 1, n do
		local x = -2.2 + 4.4 * (i - 0.5) / n
		if chance(0.2) then
			continue -- taken
		end
		local foot = (cf * CFrame.new(x, 0.3, -0.7)).Position
		local top = (cf * CFrame.new(x + jit(0.2), 8.5, 0.3)).Position
		pole(m, "Spear", foot, top, 0.09, "oak")
		local tip = part(m, "Head", Vector3.new(0.18, 1.3, 0.4), CFrame.lookAt(top, top + (top - foot).Unit) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, 0.6, 0), "ironDark")
		tip.CastShadow = false
	end
	return m
end

-- A straw archery butt on its stand, with arrows in it.
local function archeryButt(parent: Instance, cf: CFrame)
	local m = model(parent, "ArcheryButt")
	local face = cf * CFrame.new(0, 3.4, 0)
	local boss = part(m, "Boss", Vector3.new(1.4, 4.4, 4.4), face * CFrame.Angles(0, math.rad(90), 0), "hay")
	;(boss :: Part).Shape = Enum.PartType.Cylinder
	local rings = { { 3.6, Color3.fromRGB(196, 190, 170) }, { 2.6, Color3.fromRGB(40, 36, 34) }, { 1.6, Color3.fromRGB(180, 160, 120) }, { 0.8, Color3.fromRGB(140, 40, 34) } }
	for i, r in rings do
		local ring = part(m, "Ring", Vector3.new(0.05, r[1], r[1]), face * CFrame.new(0, 0, -0.7 - i * 0.012) * CFrame.Angles(0, math.rad(90), 0), "linen", r[2])
		;(ring :: Part).Shape = Enum.PartType.Cylinder
		ring.CastShadow = false
	end
	for _, s in { -1, 1 } do
		beam(m, "Leg", (cf * CFrame.new(s * 1.6, 0, 0.8)).Position, (cf * CFrame.new(s * 0.9, 5.4, -0.1)).Position, 0.3, 0.3, "oakDark")
	end
	beam(m, "BackLeg", (cf * CFrame.new(0, 0, 2.6)).Position, (cf * CFrame.new(0, 5.2, 0.2)).Position, 0.3, 0.3, "oakDark")
	for _ = 1, rng:NextInteger(2, 6) do
		local p = (face * CFrame.new(jit(1.6), jit(1.6), -0.6)).Position
		arrow(m, p, (face.LookVector * 1 + Vector3.new(jit(0.15), jit(0.1), jit(0.15))))
	end
	return m
end

-- A straw dummy, if the mesh is missing.
local function dummy(parent: Instance, cf: CFrame)
	local m = prop(parent, "Dummy", cf)
	if m then
		return m
	end
	-- A sack stuffed with straw on a post, lashed to a crossbar: what recruits
	-- hacked at every morning. It leans a little; they all ended up leaning.
	local d = model(parent, "Dummy")
	local lean = cf * CFrame.Angles(math.rad(rand(-6, 6)), 0, math.rad(rand(-7, 7)))
	part(d, "Socket", Vector3.new(1.3, 0.5, 1.3), cf * CFrame.new(0, 0.25, 0), "stone")
	pole(d, "Post", (lean * CFrame.new(0, 0, 0)).Position, (lean * CFrame.new(0, 6.6, 0)).Position, 0.24, "oakDark")
	pole(d, "Arm", (lean * CFrame.new(-2.3, 4.9, 0)).Position, (lean * CFrame.new(2.3, 4.85, 0)).Position, 0.17, "oakDark")
	-- the body: a sack, fatter at the chest, cinched at the waist
	local chest = part(d, "Chest", Vector3.new(1.6, 1.85, 1.85), lean * CFrame.new(0, 4.35, 0) * CFrame.Angles(0, 0, math.rad(90)), "burlap")
	;(chest :: Part).Shape = Enum.PartType.Cylinder
	local belly = part(d, "Belly", Vector3.new(1.3, 1.5, 1.5), lean * CFrame.new(0, 3.05, 0) * CFrame.Angles(0, 0, math.rad(90)), "burlap")
	;(belly :: Part).Shape = Enum.PartType.Cylinder
	for _, y in { 3.7, 4.95 } do
		local rope = part(d, "Lashing", Vector3.new(0.18, 1.98, 1.98), lean * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), "burlap", Color3.fromRGB(96, 78, 56))
		;(rope :: Part).Shape = Enum.PartType.Cylinder
		rope.CastShadow = false
	end
	-- straw bursting out of a cut, and out of both sleeves
	part(d, "Spill", Vector3.new(0.9, 0.5, 0.4), lean * CFrame.new(0.3, 4.1, -0.85) * CFrame.Angles(0, 0, 0.5), "hay")
	for _, s in { -1, 1 } do
		local sleeve = part(d, "Sleeve", Vector3.new(1.4, 0.75, 0.75), lean * CFrame.new(s * 1.55, 4.9, 0) * CFrame.Angles(0, 0, s * 0.08), "burlap")
		sleeve.CastShadow = false
		local tuft = part(d, "Straw", Vector3.new(0.5, 0.55, 0.55), lean * CFrame.new(s * 2.35, 4.85, 0), "hay")
		tuft.CastShadow = false
	end
	local neck = part(d, "Neck", Vector3.new(0.5, 0.5, 0.5), lean * CFrame.new(0, 5.45, 0), "burlap", Color3.fromRGB(96, 78, 56))
	neck.CastShadow = false
	ball(d, "Head", Vector3.new(1.15, 1.3, 1.15), lean * CFrame.new(0, 6.1, 0), "burlap")
	if chance(0.4) then
		helmet(d, lean * CFrame.new(0, 6.45, 0) * CFrame.Angles(math.rad(rand(-15, 15)), 0, math.rad(rand(-15, 15))))
	end
	return d
end

-- A timber watch platform: four posts, cross-braced, a boarded deck with a rail,
-- and a flight up to it. The flight is a ramp underneath, so the dead climb it.
local function watchPlatform(parent: Instance, B: CFrame, h: number, size: number, stairSide: number)
	local m = model(parent, "WatchPlatform")
	local s2 = size / 2
	for _, x in { -s2, s2 } do
		for _, z in { -s2, s2 } do
			pole(m, "Leg", (B * CFrame.new(x, 0, z)).Position, (B * CFrame.new(x * 1.0, h + 8.5, z)).Position, 0.5, "oakDark")
			part(m, "PadStone", Vector3.new(1.6, 0.6, 1.6), B * CFrame.new(x, 0.2, z), "stone")
		end
	end
	-- X bracing on each face, two tiers
	-- (no bracing on the face the flight arrives at: the braces would cross it)
	for _, face in { { -1, 0 }, { 1, 0 }, { 0, 1 } } do
		for tier = 0, 1 do
			local y0, y1 = tier * h / 2 + 0.8, (tier + 1) * h / 2 - 0.4
			local a, b
			if face[1] ~= 0 then
				a = B * CFrame.new(face[1] * s2, y0, -s2)
				b = B * CFrame.new(face[1] * s2, y1, s2)
				beam(m, "Brace", a.Position, b.Position, 0.35, 0.35, "oak")
				beam(m, "Brace", (B * CFrame.new(face[1] * s2, y0, s2)).Position, (B * CFrame.new(face[1] * s2, y1, -s2)).Position, 0.35, 0.35, "oak")
			else
				a = B * CFrame.new(-s2, y0, face[2] * s2)
				b = B * CFrame.new(s2, y1, face[2] * s2)
				beam(m, "Brace", a.Position, b.Position, 0.35, 0.35, "oak")
				beam(m, "Brace", (B * CFrame.new(s2, y0, face[2] * s2)).Position, (B * CFrame.new(-s2, y1, face[2] * s2)).Position, 0.35, 0.35, "oak")
			end
		end
	end
	-- the deck (with the hatch where the flight arrives)
	local D = B * CFrame.new(0, h, 0)
	for _, z in { -s2, s2 } do
		beam(m, "Bearer", (D * CFrame.new(-s2 - 0.8, -0.6, z)).Position, (D * CFrame.new(s2 + 0.8, -0.6, z)).Position, 0.8, 0.8, "oakDark")
	end
	boards(m, D, size + 1.4, size + 1.4, nil, nil)
	-- rail: the back all along; the front either side of where the flight arrives
	local gapX = stairSide * (s2 - 2.2)
	local function rail(x0: number, x1: number, z: number)
		beam(m, "Rail", (D * CFrame.new(x0, 3.4, z)).Position, (D * CFrame.new(x1, 3.4, z)).Position, 0.3, 0.4, "oak")
		beam(m, "Rail", (D * CFrame.new(x0, 1.8, z)).Position, (D * CFrame.new(x1, 1.8, z)).Position, 0.25, 0.35, "oak")
	end
	rail(-s2 - 0.6, s2 + 0.6, s2 + 0.6)
	if gapX - 2.5 > -s2 - 0.6 then
		rail(-s2 - 0.6, gapX - 2.5, -s2 - 0.6)
	end
	if gapX + 2.5 < s2 + 0.6 then
		rail(gapX + 2.5, s2 + 0.6, -s2 - 0.6)
	end
	for _, x in { -s2 - 0.6, s2 + 0.6 } do
		beam(m, "Rail", (D * CFrame.new(x, 3.4, -s2 - 0.6)).Position, (D * CFrame.new(x, 3.4, s2 + 0.6)).Position, 0.3, 0.4, "oak")
	end
	-- a small shingled canopy on the leg tops
	-- the canopy stands 8.5 over the deck: a body is 6 tall, and the
	-- pathfinder will not send one anywhere it cannot stand up
	roof(m, D * CFrame.new(0, 8.5, 0), size, size, { kind = "shingles", pitch = 32, overhang = 1.2, gableOver = 0.8 })
	-- the flight: arrives at the front edge (-z of the deck), on the stairSide half
	local arrive = D * CFrame.new(stairSide * (s2 - 2.2), 0, -(size + 1.4) / 2) -- exactly the deck edge
	local steps = math.ceil(h / 0.95)
	local run = steps * 1.25
	local foot = (arrive * CFrame.new(0, -h + 0.05, -run)).Position
	-- rising to the boards' top (h + 0.16) so ramp and deck are one surface
	stair(m, Vector3.new(foot.X, B.Position.Y + 0.05, foot.Z), (arrive.Position - foot) * Vector3.new(1, 0, 1), h + 0.11, 4.2, "oak", 1.25)
	return m
end

local function campfire(parent: Instance, cf: CFrame, lit: boolean)
	local m = model(parent, "Campfire")
	for k = 0, 9 do
		local a = k / 10 * math.pi * 2
		part(m, "Stone", Vector3.new(rand(0.8, 1.2), rand(0.5, 0.8), rand(0.8, 1.2)), cf * CFrame.new(math.cos(a) * 2, 0.3, math.sin(a) * 2) * CFrame.Angles(jit(0.3), a, jit(0.3)), "stone")
	end
	part(m, "Ash", Vector3.new(3.4, 0.2, 3.4), cf * CFrame.new(0, 0.1, 0), "soot")
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + jit(0.3)
		local p0 = (cf * CFrame.new(math.cos(a) * 1.6, 0.3, math.sin(a) * 1.6)).Position
		local p1 = (cf * CFrame.new(0, 0.9, 0)).Position
		pole(m, "Log", p0, p1, 0.3, if lit then "oakDark" else "charred")
	end
	if lit then
		fireAt(m, (cf * CFrame.new(0, 1.2, 0)).Position, 1.1, 30)
	else
		local e = part(m, "Embers", Vector3.new(1.4, 0.2, 1.4), cf * CFrame.new(0, 0.25, 0), "ember")
		e.Transparency = 0.4
		smokeOn(e, 1.5)
	end
	return m
end

-- Iron brazier on three legs, burning.
local function brazier(parent: Instance, cf: CFrame)
	local m = model(parent, "Brazier")
	for k = 0, 2 do
		local a = k / 3 * math.pi * 2
		beam(m, "Leg", (cf * CFrame.new(math.cos(a) * 1.3, 0, math.sin(a) * 1.3)).Position, (cf * CFrame.new(math.cos(a) * 0.8, 3.2, math.sin(a) * 0.8)).Position, 0.2, 0.2, "ironDark")
	end
	local bowl = part(m, "Bowl", Vector3.new(0.9, 2.6, 2.6), cf * CFrame.new(0, 3.5, 0) * CFrame.Angles(0, 0, math.rad(90)), "ironDark")
	;(bowl :: Part).Shape = Enum.PartType.Cylinder
	-- a heap of coals, glowing deep red, not a lit tile
	local coals = ball(m, "Coals", Vector3.new(2.2, 0.7, 2.2), cf * CFrame.new(0, 3.85, 0), "ember")
	coals.Color = Color3.fromRGB(150, 44, 14)
	for _ = 1, 5 do
		local c = part(m, "Coal", Vector3.new(rand(0.4, 0.7), rand(0.3, 0.5), rand(0.4, 0.7)), cf * CFrame.new(jit(0.7), 4.1, jit(0.7)) * CFrame.Angles(jit(1), jit(1), jit(1)), "soot")
		c.CastShadow = false
	end
	fireAt(m, (cf * CFrame.new(0, 4.6, 0)).Position, 1.0, 34)
	return m
end

-- Scatter: the small things that make the ground a place.
local surfaceRay = RaycastParams.new()
surfaceRay.FilterType = Enum.RaycastFilterType.Exclude
surfaceRay.IgnoreWater = true

-- The surface under (x, z), searched down from `fromY`: terrain, a floor, a deck.
local function surfaceAt(x: number, z: number, fromY: number): number
	local hit = workspace:Raycast(Vector3.new(x, fromY, z), Vector3.new(0, -(fromY + 10), 0), surfaceRay)
	return if hit then hit.Position.Y else GROUND
end

-- `soft`: nothing scattered can be bumped into. Used indoors, where a barrel
-- rolled in front of a stair would make the floor above unreachable.
local function clutter(parent: Instance, centre: Vector3, radius: number, count: number, kinds: { string }, soft: boolean?)
	local holder = model(parent, "Clutter")
	parent = holder
	for _ = 1, count do
		local a = rand(0, math.pi * 2)
		local r = math.sqrt(rng:NextNumber()) * radius
		local px, pz = centre.X + math.cos(a) * r, centre.Z + math.sin(a) * r
		-- settle on whatever is there, searching from just above the given level
		local p = Vector3.new(px, surfaceAt(px, pz, math.max(centre.Y, GROUND) + 3), pz)
		local k = pick(kinds)
		local yaw = CFrame.Angles(0, rand(0, math.pi * 2), 0)
		if k == "stone" then
			-- a field stone: rounded, half sunk, darker than masonry
			local s = rand(0.35, 1.2)
			local st = ball(parent, "Stone", Vector3.new(s * rand(1, 1.5), s * rand(0.5, 0.8), s), CFrame.new(p + Vector3.new(0, s * 0.12, 0)) * yaw * CFrame.Angles(jit(0.3), 0, jit(0.3)), "rubble", Color3.fromRGB(104, 98, 90))
			st.CastShadow = false
		elseif k == "plank" then
			part(parent, "Plank", Vector3.new(rand(0.8, 1.2), 0.25, rand(3, 7)), CFrame.new(p + Vector3.new(0, 0.15, 0)) * yaw * CFrame.Angles(jit(0.05), 0, jit(0.05)), "planks")
		elseif k == "straw" then
			-- loose straw: a few thin wisps crossing at random, never a tile
			for _ = 1, rng:NextInteger(3, 6) do
				local w = part(parent, "Straw", Vector3.new(rand(0.3, 0.8), 0.08, rand(1.2, 2.8)), CFrame.new(p + Vector3.new(jit(0.9), 0.05 + rand(0, 0.06), jit(0.9))) * CFrame.Angles(jit(0.06), rand(0, math.pi * 2), jit(0.06)), "hay", Color3.fromRGB(176, 158, 118))
				w.CastShadow = false
				w.CanCollide = false
			end
		elseif k == "arrow" then
			arrow(parent, p + Vector3.new(0, 0.3, 0), Vector3.new(jit(0.5), -1, jit(0.5)))
		elseif k == "shield" then
			shield(parent, CFrame.new(p + Vector3.new(0, 0.2, 0)) * yaw * CFrame.Angles(0, 0, math.rad(rand(80, 100))))
		elseif k == "helmet" then
			helmet(parent, CFrame.new(p) * yaw * CFrame.Angles(jit(0.6), 0, jit(0.6)))
		elseif k == "barrel" then
			prop(parent, "Barrel", CFrame.new(p) * yaw)
		elseif k == "barrelDown" then
			local b = prop(parent, "Barrel", CFrame.new(p + Vector3.new(0, 0.2, 0)) * yaw)
			if b then
				b:PivotTo(b:GetPivot() * CFrame.Angles(0, 0, math.rad(90)) + Vector3.new(0, -0.6, 0))
			end
		elseif k == "crate" then
			prop(parent, "Crate", CFrame.new(p) * yaw)
		elseif k == "sacks" then
			prop(parent, "Sacks", CFrame.new(p) * yaw)
		elseif k == "firewood" then
			prop(parent, "Firewood", CFrame.new(p) * yaw)
		elseif k == "bones" then
			for _ = 1, 4 do
				local b = part(parent, "Bone", Vector3.new(0.25, 0.25, rand(0.8, 1.8)), CFrame.new(p + Vector3.new(jit(0.8), 0.12, jit(0.8))) * CFrame.Angles(0, rand(0, 6), 0), "linen", Color3.fromRGB(196, 186, 162))
				b.CastShadow = false
			end
		end
	end
	if soft then
		for _, d in holder:GetDescendants() do
			if d:IsA("BasePart") then
				d.CanCollide = false
			end
		end
	end
	return holder
end

--==========================================================================
-- THE GROUND — terrain painted, not built: cobbles on the road, mud where
-- feet and wheels went, grass where nobody did.
--==========================================================================
local Terrain = workspace.Terrain

local function segDist(px: number, pz: number, a: Vector2, b: Vector2): number
	local vx, vz = b.X - a.X, b.Y - a.Y
	local t = math.clamp(((px - a.X) * vx + (pz - a.Y) * vz) / (vx * vx + vz * vz), 0, 1)
	return math.sqrt((px - (a.X + vx * t)) ^ 2 + (pz - (a.Y + vz * t)) ^ 2)
end

local function pathDist(px: number, pz: number, path: { Vector2 }): number
	local best = math.huge
	for i = 1, #path - 1 do
		best = math.min(best, segDist(px, pz, path[i], path[i + 1]))
	end
	return best
end

-- Paints the top voxel layer (y -4..0) of the castle floor between z0 and z1.
-- roads: { { path = {Vector2}, width = n, material = Enum.Material } }
-- areas: { { x0, x1, z0, z1, material, alt } } laid before the mud and the
-- roads (a churchyard's turf, a field's bare earth); `alt` breaks it up.
local function paintGround(z0: number, z1: number, roads: { any }, mudAround: { { Vector2 | number } }?, areas: { any }?)
	local inner = Castle.innerHalfWidth()
	local CH = 64
	for x0 = -inner, inner - 1, CH do
		for zz = z1, z0 - 1, CH do
			local region = Region3.new(Vector3.new(x0, -4, zz), Vector3.new(math.min(x0 + CH, inner), 0, math.min(zz + CH, z0))):ExpandToGrid(4)
			local mats, occ = Terrain:ReadVoxels(region, 4)
			local origin = region.CFrame.Position - region.Size / 2
			local size = mats.Size
			for i = 1, size.X do
				local x = origin.X + (i - 0.5) * 4
				for k = 1, size.Z do
					local z = origin.Z + (k - 0.5) * 4
					if z > z0 or z < z1 or math.abs(x) > inner + 2 then
						continue
					end
					for y = 1, size.Y do
						if occ[i][y][k] > 0 then
							local n1 = math.noise(x / 23, z / 23, 3.7)
							local n2 = math.noise(x / 9, z / 9, 8.1)
							local mat = Enum.Material.Ground
							-- grass creeps in along the foot of the walls
							local toWall = inner - math.abs(x)
							if toWall < 10 + n1 * 6 then
								mat = if n2 > 0.1 then Enum.Material.LeafyGrass else Enum.Material.Grass
							elseif n1 > 0.25 then
								mat = Enum.Material.Mud
							elseif n1 < -0.35 and n2 > 0 then
								mat = Enum.Material.Grass
							end
							if areas then
								for _, a in areas do
									if x >= math.min(a.x0, a.x1) and x <= math.max(a.x0, a.x1) and z >= math.min(a.z0, a.z1) and z <= math.max(a.z0, a.z1) then
										mat = if n2 > -0.1 or not a.alt then a.material else a.alt
									end
								end
							end
							if mudAround then
								for _, spot in mudAround do
									local c = spot[1] :: Vector2
									if (Vector2.new(x, z) - c).Magnitude < (spot[2] :: number) + n2 * 4 then
										mat = Enum.Material.Mud
									end
								end
							end
							for _, road in roads do
								local d = pathDist(x, z, road.path)
								local edge = road.width / 2 + n2 * 1.6
								if d < edge then
									mat = road.material
								elseif d < edge + 3.5 + n1 * 2 and road.verge then
									mat = road.verge
								end
							end
							mats[i][y][k] = mat
						end
					end
				end
			end
			Terrain:WriteVoxels(region, 4, mats, occ)
		end
		task.wait()
	end
end

-- Terrain textures for the whole place: the generated variants take over the
-- base materials, so the moat's mud and the bridge's cobbles match the yards.
local function terrainLook()
	pcall(function()
		if hasVariant("TLK_YardMud") then
			MaterialService:SetBaseMaterialOverride(Enum.Material.Mud, "TLK_YardMud")
		end
		if hasVariant("TLK_Cobbles") then
			MaterialService:SetBaseMaterialOverride(Enum.Material.Cobblestone, "TLK_Cobbles")
		end
	end)
	Terrain:SetMaterialColor(Enum.Material.Mud, Color3.fromRGB(80, 72, 64)) -- browner, not red: red mud reads as blood
	Terrain:SetMaterialColor(Enum.Material.Cobblestone, Color3.fromRGB(118, 112, 104))
	Terrain:SetMaterialColor(Enum.Material.LeafyGrass, Color3.fromRGB(70, 78, 48))
end

--==========================================================================
-- LANTERN POSTS along the roads: a post, an arm, a chain, the lantern, a pool
-- of warm light. Placed in the verge, alternating sides, and skipped wherever
-- anything already stands.
--==========================================================================
local function lanternPost(parent: Instance, cf: CFrame)
	local m = model(parent, "LanternPost")
	local post = pole(m, "Post", cf.Position, (cf * CFrame.new(0, 9.5, 0)).Position, 0.32, "oakDark")
	post.CastShadow = true
	part(m, "Foot", Vector3.new(1.4, 0.6, 1.4), cf * CFrame.new(0, 0.3, 0), "stone")
	beam(m, "Arm", (cf * CFrame.new(0, 9, 0)).Position, (cf * CFrame.new(0, 9, -2.6)).Position, 0.3, 0.35, "oakDark")
	beam(m, "Brace", (cf * CFrame.new(0, 7.4, 0)).Position, (cf * CFrame.new(0, 8.85, -1.5)).Position, 0.2, 0.2, "oakDark")
	beam(m, "Chain", (cf * CFrame.new(0, 8.8, -2.3)).Position, (cf * CFrame.new(0, 8.1, -2.3)).Position, 0.08, 0.08, "ironDark")
	local lamp = prop(m, "Lantern", cf * CFrame.new(0, 6.4, -2.3), 1.1)
	local glow = part(m, "LampGlow", Vector3.new(0.45, 0.6, 0.45), cf * CFrame.new(0, 7.1, -2.3), "ember")
	glow.CanCollide = false
	glow.CastShadow = false
	glow.Transparency = if lamp then 0.35 else 0
	pointLight(glow, Color3.fromRGB(255, 176, 96), 1.7, 26)
	return m
end

local function roadLanterns(parent: Instance, path: { Vector2 }, spacing: number, offset: number)
	local blockers = OverlapParams.new()
	blockers.FilterType = Enum.RaycastFilterType.Include
	blockers.FilterDescendantsInstances = { parent, workspace.Gameplay.Battleground }
	local side, walked, nextAt = 1, 0, spacing * 0.5
	for i = 1, #path - 1 do
		local a, b = path[i], path[i + 1]
		local seg = (b - a).Magnitude
		local dir = (b - a).Unit
		while nextAt <= walked + seg do
			local t = (nextAt - walked) / seg
			local p = a:Lerp(b, t)
			local n = Vector2.new(-dir.Y, dir.X) * side
			local q = p + n * offset
			local at3 = Vector3.new(q.X, GROUND, q.Y)
			local clear = true
			for _, hit in workspace:GetPartBoundsInRadius(at3 + Vector3.new(0, 4, 0), 3.2, blockers) do
				if hit.CanCollide then
					clear = false
					break
				end
			end
			if clear then
				-- the arm reaches out over the road
				local toRoad = Vector3.new(-n.X, 0, -n.Y)
				lanternPost(parent, CFrame.lookAt(at3, at3 + toRoad))
				side = -side
			end
			nextAt += spacing
		end
		walked += seg
	end
end

--==========================================================================
-- RUINS — a stone building that has partly come down. The walls stand to a
-- ragged line, highest at the corners (corners are what last), the rest lies
-- at the foot on the side it fell, with the floor beams that pulled out.
--==========================================================================
local function ruin(parent: Instance, B: CFrame, W: number, D: number, H: number)
	local m = model(parent, "Ruin")
	local function side(W0: CFrame, L: number)
		local col = 2.2
		local n = math.max(2, math.floor(L / col))
		for i = 0, n - 1 do
			local x = (i + 0.5) * L / n
			local t = math.abs((x / L) - 0.5) * 2 -- 0 mid, 1 corners
			local h = H * (0.15 + 0.85 * t ^ 1.6) * rand(0.6, 1.05)
			if h > 0.8 then
				part(m, "Masonry", Vector3.new(L / n + 0.02, h, STONE_T), W0 * CFrame.new(x, h / 2, STONE_T / 2), "rubble")
				-- broken course on top: a few loose stones
				if chance(0.5) then
					part(m, "Loose", Vector3.new(rand(0.8, 1.6), rand(0.5, 0.9), rand(0.8, 1.4)), W0 * CFrame.new(x + jit(0.4), h + 0.3, STONE_T / 2 + jit(0.3)) * CFrame.Angles(jit(0.3), jit(0.5), jit(0.3)), "stone")
				end
			end
		end
		-- the fall: a spread of stone along the outside
		for _ = 1, math.floor(L / 1.6) do
			local s = rand(0.6, 2.2)
			local p = part(m, "Rubble", Vector3.new(s, s * rand(0.5, 0.9), s * rand(0.7, 1.2)), W0 * CFrame.new(rand(0, L), s * 0.25, -rand(0.5, 5)) * CFrame.Angles(jit(0.6), rand(0, 6), jit(0.6)), if chance(0.6) then "rubble" else "stone")
			p.CastShadow = false
		end
	end
	side(B * CFrame.new(-W / 2, 0, -D / 2), W)
	side(B * CFrame.new(W / 2, 0, D / 2) * CFrame.Angles(0, math.pi, 0), W)
	side(B * CFrame.new(-W / 2, 0, D / 2) * CFrame.Angles(0, math.pi / 2, 0), D)
	side(B * CFrame.new(W / 2, 0, -D / 2) * CFrame.Angles(0, -math.pi / 2, 0), D)
	-- floor beams that came down with it, one end still in a socket
	for _ = 1, 4 do
		local a = B * CFrame.new(rand(-W / 2, W / 2), rand(H * 0.4, H * 0.7), D / 2 - 0.5)
		local b = B * CFrame.new(rand(-W / 3, W / 3), 0.5, rand(-D / 2, 0))
		beam(m, "FallenBeam", a.Position, b.Position, 0.9, 0.9, "charred")
	end
	clutter(m, B.Position, math.min(W, D) / 2, 10, { "stone", "plank", "stone" })
	return m
end

--==========================================================================
-- LIGHT ON THE WALLS — a torch every ~30 studs along the side walls and
-- either side of each passage, seated on the stone by raycast.
--==========================================================================
local wallRay = RaycastParams.new()
wallRay.FilterType = Enum.RaycastFilterType.Include

local function wallTorch(parent: Instance, from: Vector3, dir: Vector3, maxDist: number): boolean
	local hit = workspace:Raycast(from, dir * maxDist, wallRay)
	if not hit or math.abs(hit.Normal.Y) > 0.3 then
		return false
	end
	local n = Vector3.new(hit.Normal.X, 0, hit.Normal.Z).Unit
	local base = hit.Position + n * 0.2
	local m = model(parent, "Torch")
	local face = CFrame.lookAt(base, base + n)
	part(m, "Plate", Vector3.new(1.4, 2.2, 0.4), face * CFrame.new(0, 0, -0.1), "ironDark")
	pole(m, "Arm", base + n * 0.2, base + n * 1.6 + Vector3.new(0, 0.6, 0), 0.22, "ironDark")
	local cup = base + n * 1.7 + Vector3.new(0, 0.7, 0)
	part(m, "Cup", Vector3.new(0.9, 0.5, 0.9), CFrame.new(cup), "ironDark")
	pole(m, "Brand", cup - Vector3.new(0, 0.2, 0), cup + Vector3.new(0, 1.6, 0) + n * 0.25, 0.32, "oakDark")
	local core = fireAt(m, cup + Vector3.new(0, 2, 0) + n * 0.3, 0.9, 36)
	local l = core:FindFirstChildOfClass("PointLight")
	if l then
		l.Brightness = 2.8
	end
	return true
end

local function wallTorches(parent: Instance, index: number)
	local bg = workspace.Gameplay:FindFirstChild("Battleground")
	local include = { bg:FindFirstChild("Shell") }
	for k = math.max(1, index - 1), index do
		local s = bg:FindFirstChild(("Chamber%d"):format(k))
		if s and s:FindFirstChild("Structure") then
			table.insert(include, s.Structure)
		end
	end
	wallRay.FilterDescendantsInstances = include
	local zNear, zFar = Castle.chamberBounds(index)
	local folder = model(parent, "WallTorches")
	local placed = 0
	for z = zNear - 30, zFar + 30, -32 do
		for _, side in { -1, 1 } do
			if wallTorch(folder, Vector3.new(side * 90, GROUND + 11, z + jit(4)), Vector3.new(side, 0, 0), 140) then
				placed += 1
			end
		end
	end
	if index < Castle.Chambers then
		local x = Castle.gapX(index)
		for _, dx in { -34, 34, -70 * math.sign(x) } do
			if wallTorch(folder, Vector3.new(x + dx, GROUND + 12, zFar + 40), Vector3.new(0, 0, -1), 70) then
				placed += 1
			end
		end
	end
	return placed
end

--==========================================================================
-- SECTIONS
--==========================================================================
local gameplay = workspace:FindFirstChild("Gameplay")

-- The folder an area builds into: Battleground.Decorations.AreaN, cleared
-- first. The old generated contents (BuildChambers) and the old lights
-- (LightCastle) for that area go with it.
local function areaFolder(index: number): Folder
	local bg = gameplay:FindFirstChild("Battleground")
	local deco = bg:FindFirstChild("Decorations")
	local old = deco:FindFirstChild(("Area%d"):format(index))
	if old then
		old:Destroy()
	end
	local lights = bg:FindFirstChild("Lighting")
	local oldLights = lights and lights:FindFirstChild(("Area%d"):format(index))
	if oldLights then
		oldLights:Destroy()
	end
	local f = Instance.new("Folder")
	f.Name = ("Area%d"):format(index)
	f.Parent = deco
	return f
end

--[[
	Keeps the gameplay marks clear: enemies arrive on the spawn marks, and the
	checkpoint, objective and storyteller marks are where players stand. Any
	loose piece of clutter that landed within reach of one is taken away again
	(buildings are placed clear of them by hand; scatter is random).
]]
local LOOSE = { Stone = true, Plank = true, Straw = true, Bone = true, Shaft = true, Fletch = true, Shield = true, Boss = true, Rim = true, Helm = true, Brim = true, Ash = true }
local function clearMarkers(index: number, folder: Instance)
	local node = gameplay.Battleground:FindFirstChild(("Chamber%d"):format(index))
	if not node then
		return 0
	end
	local marks = {}
	for _, d in node:GetDescendants() do
		if d:IsA("BasePart") and not d:IsDescendantOf(node:FindFirstChild("Structure") or node) then
			table.insert(marks, d.Position)
		end
	end
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { folder }
	local removed = 0
	for _, p in marks do
		for _, hit in workspace:GetPartBoundsInRadius(p, 8, params) do
			local m = hit:FindFirstAncestorOfClass("Model")
			if LOOSE[hit.Name] or (m and m.Parent and m.Parent.Name == "Clutter" and #m:GetChildren() < 40 and (m.Name == "Barrel" or m.Name == "Crate" or m.Name == "Sacks" or m.Name == "Firewood")) then
				if LOOSE[hit.Name] then
					hit:Destroy()
				elseif m then
					m:Destroy()
				end
				removed += 1
			end
		end
	end
	return removed
end

-- A ground frame facing a compass direction: "N" is toward the gate (+z).
local FACING = { N = 180, S = 0, E = -90, W = 90 }
local function at(x: number, z: number, facing: string | number, y: number?): CFrame
	local deg = if type(facing) == "number" then facing else FACING[facing]
	return CFrame.new(x, (y or 0) + GROUND, z) * CFrame.Angles(0, math.rad(deg), 0)
end

--------------------------------------------------------------------------
-- Pieces for the stables and the kitchens
--------------------------------------------------------------------------

-- A bale: hay, two bands of twine.
local function bale(parent: Instance, cf: CFrame)
	local b = part(parent, "Bale", Vector3.new(3.6, 2.1, 2.2), cf * CFrame.new(0, 1.05, 0) * CFrame.Angles(jit(0.03), 0, jit(0.03)), "hay")
	for _, x in { -0.9, 0.9 } do
		local band = part(parent, "Twine", Vector3.new(0.12, 2.16, 2.26), cf * CFrame.new(x, 1.05, 0), "burlap", Color3.fromRGB(110, 90, 64))
		band.CastShadow = false
	end
	return b
end

local function baleStack(parent: Instance, cf: CFrame, cols: number, rows: number, layers: number)
	for l = 0, layers - 1 do
		for c = 0, cols - 1 do
			for r = 0, rows - 1 do
				if l == 0 or chance(0.8) then
					bale(parent, cf * CFrame.new(c * 3.7 + (l % 2) * 0.6, l * 2.12, r * 2.3) * CFrame.Angles(0, jit(0.05), 0))
				end
			end
		end
	end
end

-- Stall partitions inside a stable, against its back wall (B local +Z).
local function stalls(parent: Instance, B: CFrame, W: number, D: number, y: number, n: number)
	local m = model(parent, "Stalls")
	local depth = 7
	local zBack = D / 2 - 0.8
	for i = 0, n do
		local x = -W / 2 + 1 + (W - 2) * i / n
		local smashed = chance(0.35)
		local tilt = if smashed then CFrame.Angles(0, 0, math.rad(rand(-35, 35))) else CFrame.new()
		local P = B * CFrame.new(x, y, zBack - depth / 2) * tilt
		beam(m, "StallPost", (B * CFrame.new(x, y, zBack - depth)).Position, (B * CFrame.new(x, y + 5.4, zBack - depth)).Position, 0.6, 0.6, "oakDark")
		for k = 0, 4 do
			if not (smashed and chance(0.4)) then
				part(m, "StallBoard", Vector3.new(0.3, 0.85, depth - 0.4), P * CFrame.new(0, 0.5 + k * 0.9, 0), "planks")
			end
		end
		if smashed then
			-- boards kicked out into the aisle
			for _ = 1, 2 do
				part(m, "Kicked", Vector3.new(0.3, 0.85, rand(2, 5)), B * CFrame.new(x + jit(2), y + 0.2, zBack - depth - rand(1, 4)) * CFrame.Angles(math.rad(90), rand(0, 6), 0), "planks")
			end
		end
		if i < n then
			local cx = x + (W - 2) / n / 2
			-- manger and hay rack on the back wall
			part(m, "Manger", Vector3.new((W - 2) / n - 1, 1.4, 1.6), B * CFrame.new(cx, y + 2.4, zBack - 0.8), "planks")
			part(m, "MangerHay", Vector3.new((W - 2) / n - 1.4, 0.5, 1.2), B * CFrame.new(cx, y + 3.2, zBack - 0.8), "hay")
			part(m, "Bedding", Vector3.new((W - 2) / n - 0.6, 0.15, depth - 1), B * CFrame.new(cx, y + 0.1, zBack - depth / 2), "hay")
		end
	end
	return m
end

local function saddleRack(parent: Instance, cf: CFrame)
	local m = model(parent, "SaddleRack")
	for _, s in { -1, 1 } do
		beam(m, "Leg", (cf * CFrame.new(s * 1.2, 0, -0.6)).Position, (cf * CFrame.new(s * 1.2, 3.2, 0)).Position, 0.3, 0.3, "oakDark")
		beam(m, "Leg", (cf * CFrame.new(s * 1.2, 0, 0.6)).Position, (cf * CFrame.new(s * 1.2, 3.2, 0)).Position, 0.3, 0.3, "oakDark")
	end
	beam(m, "Bar", (cf * CFrame.new(-1.6, 3.3, 0)).Position, (cf * CFrame.new(1.6, 3.3, 0)).Position, 0.5, 0.5, "oak")
	local saddle = part(m, "Saddle", Vector3.new(2.4, 0.6, 1.9), cf * CFrame.new(0, 3.75, 0), "planks", Color3.fromRGB(96, 58, 36))
	saddle.Material = Enum.Material.Leather
	saddle.MaterialVariant = ""
	part(m, "Cantle", Vector3.new(0.4, 0.7, 1.6), cf * CFrame.new(-1.0, 4.1, 0), "planks", Color3.fromRGB(86, 52, 32)).Material = Enum.Material.Leather
	for _, s in { -1, 1 } do
		local strap = part(m, "Stirrup", Vector3.new(0.15, 1.8, 0.3), cf * CFrame.new(0.2, 2.9, s * 1.05), "iron")
		strap.CastShadow = false
	end
	return m
end

local function bellows(parent: Instance, cf: CFrame)
	local m = model(parent, "Bellows")
	part(m, "Board", Vector3.new(2.2, 0.25, 4), cf * CFrame.new(0, 2.2, 0), "planks")
	local bag = part(m, "Bag", Vector3.new(2, 1.1, 3.4), cf * CFrame.new(0, 2.9, 0), "planks", Color3.fromRGB(80, 54, 38))
	bag.Material = Enum.Material.Leather
	bag.MaterialVariant = ""
	part(m, "Board", Vector3.new(2.2, 0.25, 4), cf * CFrame.new(0, 3.6, 0) * CFrame.Angles(math.rad(6), 0, 0), "planks")
	pole(m, "Nozzle", (cf * CFrame.new(0, 2.6, -2)).Position, (cf * CFrame.new(0, 2.4, -3.4)).Position, 0.2, "iron")
	for _, z in { -1.4, 1.4 } do
		beam(m, "Leg", (cf * CFrame.new(0, 0, z)).Position, (cf * CFrame.new(0, 2.1, z)).Position, 0.4, 0.4, "oakDark")
	end
	beam(m, "Lever", (cf * CFrame.new(0, 3.8, 1.6)).Position, (cf * CFrame.new(0, 5.6, 4.2)).Position, 0.25, 0.25, "oak")
	return m
end

-- A stone hearth with a fire in it (and, if asked, an iron pot).
local function hearth(parent: Instance, cf: CFrame, w: number, lit: boolean)
	local m = model(parent, "Hearth")
	part(m, "HearthBase", Vector3.new(w, 1.2, 4), cf * CFrame.new(0, 0.6, 0), "stone")
	part(m, "Back", Vector3.new(w, 6, 1.2), cf * CFrame.new(0, 3, 1.8), "rubble")
	for _, s in { -1, 1 } do
		part(m, "Cheek", Vector3.new(1.2, 5, 3), cf * CFrame.new(s * (w / 2 - 0.6), 2.5, 0.6), "rubble")
	end
	part(m, "Mantel", Vector3.new(w + 0.6, 1, 3.4), cf * CFrame.new(0, 5.5, 0.4), "oakDark")
	part(m, "Soot", Vector3.new(w - 2.6, 4, 0.1), cf * CFrame.new(0, 3.2, 1.15), "soot")
	if lit then
		fireAt(m, (cf * CFrame.new(0, 1.8, 0.3)).Position, 1.3, 34)
	else
		part(m, "Ashes", Vector3.new(w - 3, 0.2, 2), cf * CFrame.new(0, 1.3, 0.2), "soot")
	end
	return m
end

-- A domed bread oven built against a wall, its mouth toward -Z.
local function breadOven(parent: Instance, cf: CFrame, lit: boolean)
	local m = model(parent, "Oven")
	part(m, "OvenBase", Vector3.new(7, 3, 7), cf * CFrame.new(0, 1.5, 0), "rubble")
	ball(m, "Dome", Vector3.new(7, 5.4, 7), cf * CFrame.new(0, 3.2, 0), "rubble")
	part(m, "Mouth", Vector3.new(2.4, 1.8, 0.4), cf * CFrame.new(0, 3.9, -3.4), if lit then "ember" else "dark").Transparency = if lit then 0.3 else 0
	part(m, "MouthArch", Vector3.new(3.2, 0.6, 0.8), cf * CFrame.new(0, 5.0, -3.3), "stone")
	part(m, "Ledge", Vector3.new(4, 0.4, 1.4), cf * CFrame.new(0, 3, -4), "stone")
	if lit then
		pointLight(m:FindFirstChild("Mouth") :: BasePart, Color3.fromRGB(255, 130, 60), 2, 16)
	end
	return m
end

-- A stone well: ring wall, a windlass under a little roof, boarded over.
local function well(parent: Instance, cf: CFrame, boarded: boolean)
	local m = model(parent, "Well")
	local R = 3.2
	for k = 0, 15 do
		local a = k / 16 * math.pi * 2
		part(m, "WellStone", Vector3.new(1.4, 3.2, 1.4), cf * CFrame.new(math.cos(a) * R, 1.6, math.sin(a) * R) * CFrame.Angles(0, -a, 0), "rubble")
		part(m, "Coping", Vector3.new(1.5, 0.4, 1.6), cf * CFrame.new(math.cos(a) * R, 3.4, math.sin(a) * R) * CFrame.Angles(0, -a, 0), "stone")
	end
	local water = part(m, "Dark", Vector3.new(0.2, R * 2 - 1, R * 2 - 1), cf * CFrame.new(0, 1.6, 0) * CFrame.Angles(0, 0, math.rad(90)), "dark")
	;(water :: Part).Shape = Enum.PartType.Cylinder
	for _, s in { -1, 1 } do
		beam(m, "WindlassPost", (cf * CFrame.new(s * (R + 0.4), 0, 0)).Position, (cf * CFrame.new(s * (R + 0.4), 7.4, 0)).Position, 0.7, 0.7, "oakDark")
	end
	pole(m, "Axle", (cf * CFrame.new(-R - 1.2, 5.6, 0)).Position, (cf * CFrame.new(R + 1.2, 5.6, 0)).Position, 0.45, "oak")
	beam(m, "Crank", (cf * CFrame.new(R + 1.2, 5.6, 0)).Position, (cf * CFrame.new(R + 1.2, 4.2, 0.6)).Position, 0.25, 0.25, "iron")
	beam(m, "Rope", (cf * CFrame.new(0, 5.2, 0)).Position, (cf * CFrame.new(0, 3.8, 0)).Position, 0.12, 0.12, "burlap")
	roof(m, cf * CFrame.new(0, 7.6, 0), R * 2 + 1.6, R * 2 + 1.6, { kind = "shingles", pitch = 38, overhang = 0.9, gableOver = 0.6 })
	if boarded then
		for k = -2, 2 do
			part(m, "Board", Vector3.new(R * 2 + 0.6, 0.3, 1.1), cf * CFrame.new(0, 3.75, k * 1.15) * CFrame.Angles(0, jit(0.08), jit(0.03)), "planks")
		end
		for _, x in { -2, 2 } do
			part(m, "Batten", Vector3.new(0.6, 0.3, R * 2), cf * CFrame.new(x, 4.0, 0), "planks")
		end
	end
	return m
end

-- Woven wattle hurdles along a line.
local function hurdles(parent: Instance, a: Vector3, b: Vector3, h: number)
	local m = model(parent, "Hurdles")
	local len = (b - a).Magnitude
	local n = math.max(2, math.floor(len / 1.1))
	for k = 0, n do
		local p = a:Lerp(b, k / n)
		local st = pole(m, "Sail", p, p + Vector3.new(jit(0.1), h + 0.4, jit(0.1)), 0.09, "oakDark")
		st.CastShadow = false
	end
	for y = 0.4, h - 0.1, 0.32 do
		local off = (if math.floor(y / 0.32) % 2 == 0 then 0.12 else -0.12)
		local dirN = (b - a).Unit:Cross(Vector3.yAxis) * off
		local rod = beam(m, "Withy", a + Vector3.new(0, y, 0) + dirN, b + Vector3.new(0, y, 0) + dirN, 0.14, 0.14, "oak")
		rod.CastShadow = false
	end
	return m
end

local function scarecrow(parent: Instance, cf: CFrame)
	local m = model(parent, "Scarecrow")
	pole(m, "Pole", (cf * CFrame.new(0, 0, 0)).Position, (cf * CFrame.new(0, 7, 0)).Position, 0.22, "oakDark")
	pole(m, "Arms", (cf * CFrame.new(-2.6, 5.2, 0)).Position, (cf * CFrame.new(2.6, 5.1, 0)).Position, 0.18, "oakDark")
	part(m, "Coat", Vector3.new(2.4, 2.8, 1.0), cf * CFrame.new(0, 4.4, 0), "burlap", Color3.fromRGB(110, 96, 74))
	for _, s in { -1, 1 } do
		part(m, "Sleeve", Vector3.new(2, 0.8, 0.8), cf * CFrame.new(s * 1.8, 5.1, 0) * CFrame.Angles(0, 0, s * 0.1), "burlap", Color3.fromRGB(100, 88, 70))
		part(m, "Straw", Vector3.new(0.6, 0.5, 0.6), cf * CFrame.new(s * 2.9, 5.0, 0), "hay")
	end
	ball(m, "Head", Vector3.new(1.3, 1.4, 1.3), cf * CFrame.new(0, 6.5, 0), "burlap")
	part(m, "HatBrim", Vector3.new(2.2, 0.15, 2.2), cf * CFrame.new(0, 7.15, 0), "hay")
	part(m, "HatTop", Vector3.new(1.2, 0.8, 1.2), cf * CFrame.new(0, 7.6, 0), "hay")
	return m
end

-- A bed of earth, raised a little, with what was growing in it.
local function bed(parent: Instance, cf: CFrame, w: number, d: number)
	local m = model(parent, "Bed")
	local soil = part(m, "Soil", Vector3.new(w, 0.6, d), cf * CFrame.new(0, 0.3, 0), "dark", Color3.fromRGB(58, 44, 34))
	soil.Material = Enum.Material.Ground
	for x = -w / 2 + 0.8, w / 2 - 0.8, 1.4 do
		for z = -d / 2 + 0.8, d / 2 - 0.8, 1.6 do
			if chance(0.6) then
				local dead = part(m, "Plant", Vector3.new(rand(0.5, 1.1), rand(0.4, 1.2), rand(0.5, 1.1)), cf * CFrame.new(x + jit(0.2), 0.8, z + jit(0.2)) * CFrame.Angles(jit(0.3), rand(0, 6), jit(0.3)), "hay", Color3.fromRGB(110, 96, 60))
				dead.CastShadow = false
				dead.CanCollide = false
			end
		end
	end
	return m
end

-- Staddle stones: the mushroom-shaped stones a granary stands on, so rats
-- cannot climb in.
local function staddle(parent: Instance, at3: Vector3, h: number)
	local stem = part(parent, "StaddleStem", Vector3.new(1.4, h - 0.5, 1.4), CFrame.new(at3 + Vector3.new(0, (h - 0.5) / 2, 0)), "stone")
	local cap = part(parent, "StaddleCap", Vector3.new(0.6, 2.8, 2.8), CFrame.new(at3 + Vector3.new(0, h - 0.3, 0)) * CFrame.Angles(0, 0, math.rad(90)), "stone")
	;(cap :: Part).Shape = Enum.PartType.Cylinder
	return stem
end

local function hams(parent: Instance, cf: CFrame, n: number)
	beam(parent, "HookBar", (cf * CFrame.new(-n * 0.8, 0, 0)).Position, (cf * CFrame.new(n * 0.8, 0, 0)).Position, 0.3, 0.3, "oakDark")
	for k = 1, n do
		local x = -n * 0.8 + (k - 0.5) * 1.6
		local hook = part(parent, "Hook", Vector3.new(0.08, 0.8, 0.08), cf * CFrame.new(x, -0.5, 0), "ironDark")
		hook.CastShadow = false
		local ham = ball(parent, "Ham", Vector3.new(1.1, 1.8, 1.1), cf * CFrame.new(x, -1.6, 0), "planks")
		ham.Color = Color3.fromRGB(110, 60, 44)
		ham.Material = Enum.Material.Leather
		ham.MaterialVariant = ""
	end
end

--------------------------------------------------------------------------
-- Pieces for the graveyard
--------------------------------------------------------------------------
local EARTH = Color3.fromRGB(74, 58, 44)
local BONE = Color3.fromRGB(196, 186, 162)
local GRAVESTONE = Color3.fromRGB(96, 93, 88) -- weathered, lichened: never clean grey

-- Earth as it comes out of a hole: a heap, never a block. Half of it is
-- under the ground, so `h` is how high it stands.
local function earthHeap(parent: Instance, cf: CFrame, w: number, d: number, h: number): BasePart
	local e = ball(parent, "Earth", Vector3.new(w, h * 2, d), cf * CFrame.Angles(0, jit(0.2), 0), "dark")
	e.Material = Enum.Material.Ground
	e.MaterialVariant = ""
	e.Color = shade(EARTH, 1 + jit(0.1))
	e.CastShadow = false
	-- a few clods rolled off it
	for _ = 1, rng:NextInteger(1, 3) do
		local c = ball(parent, "Clod", Vector3.new(rand(0.4, 0.9), rand(0.3, 0.6), rand(0.4, 0.9)), cf * CFrame.new(jit(w * 0.6), 0.15, jit(d * 0.6)), "dark")
		c.Material = Enum.Material.Ground
		c.MaterialVariant = ""
		c.Color = e.Color
		c.CastShadow = false
		c.CanCollide = false
	end
	return e
end

local function spade(parent: Instance, at3: Vector3, lean: CFrame?)
	local m = model(parent, "Spade")
	local cf = CFrame.new(at3) * (lean or CFrame.Angles(math.rad(rand(-18, 18)), rand(0, 6), math.rad(rand(-12, 12))))
	pole(m, "Handle", (cf * CFrame.new(0, 0.6, 0)).Position, (cf * CFrame.new(0, 4.6, 0)).Position, 0.1, "oak")
	part(m, "Grip", Vector3.new(0.9, 0.18, 0.18), cf * CFrame.new(0, 4.65, 0), "oakDark")
	local blade = part(m, "Blade", Vector3.new(1.1, 1.4, 0.1), cf * CFrame.new(0, 0.2, 0), "iron")
	blade.CastShadow = false
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	return m
end

-- A headstone, leaning the way old ones do. Its face is toward -Z.
local function headstone(parent: Instance, cf: CFrame, kind: string?)
	local k = kind or pick({ "slab", "slab", "round", "round", "cross", "broken" })
	local lean = cf * CFrame.Angles(math.rad(rand(-12, 12)), 0, math.rad(rand(-8, 8)))
	local tint = shade(GRAVESTONE, rand(0.72, 1.05))
	local top = 0
	if k == "slab" or k == "round" then
		local w, h = rand(1.8, 2.5), rand(2.4, 3.4)
		part(parent, "Headstone", Vector3.new(w, h, 0.45), lean * CFrame.new(0, h / 2 - 0.4, 0), "stone", tint)
		top = h - 0.4
		if k == "round" then
			local cap = part(parent, "Headstone", Vector3.new(0.45, w, w), lean * CFrame.new(0, top, 0) * CFrame.Angles(0, math.rad(90), 0), "stone", tint)
			;(cap :: Part).Shape = Enum.PartType.Cylinder
			top += w / 2
		end
	elseif k == "cross" then
		local h = rand(3.2, 4.2)
		part(parent, "Headstone", Vector3.new(0.6, h, 0.5), lean * CFrame.new(0, h / 2 - 0.4, 0), "stone", tint)
		part(parent, "Headstone", Vector3.new(2.2, 0.6, 0.5), lean * CFrame.new(0, h * 0.68, 0), "stone", tint)
		top = h - 0.4
	else
		-- snapped: the stump, and the top lying face down in front of it
		local w = rand(1.8, 2.4)
		part(parent, "Headstone", Vector3.new(w, rand(0.7, 1.3), 0.45), lean * CFrame.new(0, 0.2, 0), "stone", tint)
		local piece = part(parent, "Headstone", Vector3.new(w * rand(0.8, 1), 0.45, rand(1.4, 2.2)), cf * CFrame.new(jit(0.4), 0.2, -rand(1.4, 2)) * CFrame.Angles(jit(0.08), jit(0.4), jit(0.06)), "stone", tint)
		piece.CastShadow = false
	end
	if top > 0 and chance(0.55) then
		-- lichen along the top, where the rain sits
		local l = part(parent, "Lichen", Vector3.new(rand(0.8, 1.6), 0.12, 0.5), lean * CFrame.new(jit(0.3), top - 0.02, 0), "thatchOld", Color3.fromRGB(92, 100, 70))
		l.CastShadow = false
		l.CanCollide = false
	end
end

-- Two lengths of oak lashed together: what you put on a grave in a hurry.
local function woodCross(parent: Instance, cf: CFrame)
	local lean = cf * CFrame.Angles(math.rad(rand(-14, 14)), 0, math.rad(rand(-10, 10)))
	local h = rand(2.6, 3.5)
	part(parent, "Cross", Vector3.new(0.32, h + 0.6, 0.24), lean * CFrame.new(0, h / 2 - 0.3, 0), "oak")
	part(parent, "CrossBar", Vector3.new(1.6, 0.28, 0.22), lean * CFrame.new(0, h * 0.72, -0.06), "oak")
	local l = part(parent, "Lashing", Vector3.new(0.42, 0.42, 0.34), lean * CFrame.new(0, h * 0.72, 0), "burlap", Color3.fromRGB(96, 78, 56))
	l.CastShadow = false
end

-- A body wrapped for burial, its length along local X, head at +X.
local function shroud(parent: Instance, cf: CFrame)
	local m = model(parent, "Shroud")
	local tint = shade(Color3.fromRGB(176, 166, 146), rand(0.62, 0.95))
	local body = part(m, "Wrap", Vector3.new(4.8, 1.25, 1.35), cf * CFrame.new(-0.2, 0.6, 0), "linen", tint)
	;(body :: Part).Shape = Enum.PartType.Cylinder
	local head = ball(m, "Wrap", Vector3.new(1.3, 1.15, 1.15), cf * CFrame.new(2.4, 0.6, 0), "linen")
	head.Color = tint
	ball(m, "Wrap", Vector3.new(1.1, 0.9, 1.3), cf * CFrame.new(-2.6, 0.5, 0), "linen").Color = tint
	for _, x in { -1.7, 0.1, 1.9 } do
		local cord = part(m, "Cord", Vector3.new(0.16, 1.4, 1.48), cf * CFrame.new(x, 0.6, 0), "burlap", Color3.fromRGB(90, 72, 52))
		;(cord :: Part).Shape = Enum.PartType.Cylinder
		cord.CastShadow = false
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	return m
end

-- A plank coffin, its length along local Z. state: "closed" | "open" | "broken"
local function coffin(parent: Instance, cf: CFrame, state: string?)
	local m = model(parent, "Coffin")
	local L, Wd, H = 6.2, 2.1, 1.5
	part(m, "Base", Vector3.new(Wd, 0.2, L), cf * CFrame.new(0, 0.1, 0), "planks")
	for _, s in { -1, 1 } do
		if not (state == "broken" and s > 0) then
			part(m, "Side", Vector3.new(0.2, H, L), cf * CFrame.new(s * (Wd / 2 - 0.1), H / 2, 0), "planks")
		else
			part(m, "Side", Vector3.new(0.2, H, L * 0.6), cf * CFrame.new(s * (Wd / 2 + 0.6), 0.12, -0.8) * CFrame.Angles(0, 0.2, math.rad(88)), "planks")
		end
		part(m, "End", Vector3.new(Wd, H, 0.2), cf * CFrame.new(0, H / 2, s * (L / 2 - 0.1)), "planks")
	end
	if state == "closed" or state == nil then
		part(m, "Lid", Vector3.new(Wd + 0.2, 0.22, L + 0.2), cf * CFrame.new(0, H + 0.11, 0), "planks")
		for _, z in { -L / 3, 0, L / 3 } do
			part(m, "Batten", Vector3.new(Wd + 0.22, 0.16, 0.35), cf * CFrame.new(0, H + 0.3, z), "oakDark").CastShadow = false
		end
	elseif state == "open" then
		-- the lid pushed off and leaning against the side
		part(m, "Lid", Vector3.new(Wd + 0.2, 0.22, L + 0.2), cf * CFrame.new(-Wd / 2 - 0.9, H * 0.55, 0) * CFrame.Angles(0, 0, math.rad(-68)), "planks")
	else
		-- split from the inside: the lid in two, thrown clear
		part(m, "Lid", Vector3.new(Wd * 0.6, 0.22, L * 0.55), cf * CFrame.new(-Wd - 0.6, 0.12, L * 0.2) * CFrame.Angles(0, rand(-0.5, 0.5), 0), "planks")
		part(m, "Lid", Vector3.new(Wd * 0.5, 0.22, L * 0.4), cf * CFrame.new(Wd + 1.4, 0.3, -L * 0.3) * CFrame.Angles(0, rand(-0.8, 0.8), math.rad(15)), "planks")
	end
	return m
end

--[[
	A grave, its length along local Z, the head at +Z.
	  "old"    turf grown over, a headstone
	  "kerb"   a stone kerb round it, a better stone: someone paid for this one
	  "new"    a heap of earth, a wooden cross
	  "open"   the dead climbed out: the hole, the spoil thrown back, the box split
	  "dug"    dug and waiting, the spade still in the heap
]]
local function grave(parent: Instance, cf: CFrame, state: string)
	local m = model(parent, "Grave")
	if state == "old" or state == "kerb" then
		local hump = ball(m, "Turf", Vector3.new(2.8, 0.9, 6), cf * CFrame.new(0, 0, 0), "dark", Color3.fromRGB(70, 76, 50))
		hump.Material = Enum.Material.Grass
		hump.MaterialVariant = ""
		hump.CastShadow = false
		if state == "kerb" then
			for _, s in { -1, 1 } do
				part(m, "Kerb", Vector3.new(0.45, 0.6, 6.8), cf * CFrame.new(s * 1.7, 0.2, 0) * CFrame.Angles(0, 0, jit(0.05)), "stone", shade(GRAVESTONE, rand(0.8, 1)))
				part(m, "Kerb", Vector3.new(3.85, 0.6, 0.45), cf * CFrame.new(0, 0.2, s * 3.2), "stone", shade(GRAVESTONE, rand(0.8, 1)))
			end
		end
		headstone(m, cf * CFrame.new(0, 0, 3.5), if state == "kerb" then pick({ "round", "cross", "slab" }) else nil)
	elseif state == "new" then
		earthHeap(m, cf, 3, 6.6, rand(0.9, 1.3))
		woodCross(m, cf * CFrame.new(jit(0.2), 0, 3.6))
		if chance(0.2) then
			-- something left on it: a few stems gone brown
			local f = part(m, "Flowers", Vector3.new(0.9, 0.2, 0.5), cf * CFrame.new(jit(0.4), 1.1, rand(-1, 1)) * CFrame.Angles(0, rand(0, 6), 0.3), "hay", Color3.fromRGB(120, 100, 66))
			f.CanCollide = false
			f.CastShadow = false
		end
	elseif state == "open" or state == "dug" then
		-- the hole: a dark cut, and the earth banked up round it reads as depth
		local pit = part(m, "Pit", Vector3.new(2.6, 0.1, 5.8), cf * CFrame.new(0, 0.04, 0), "dark", Color3.fromRGB(16, 12, 10))
		pit.CastShadow = false
		for _, s in { -1, 1 } do
			local rim = part(m, "Rim", Vector3.new(0.5, 0.5, 6.2), cf * CFrame.new(s * 1.5, 0.12, 0) * CFrame.Angles(0, 0, s * 0.5), "dark", EARTH)
			rim.Material = Enum.Material.Ground
			rim.MaterialVariant = ""
			rim.CastShadow = false
		end
		earthHeap(m, cf * CFrame.new(-3.4, 0, 0), 3.2, 6.4, rand(1, 1.5))
		if state == "open" then
			earthHeap(m, cf * CFrame.new(3, 0, rand(-1, 1)), 2.4, 3.5, rand(0.6, 0.9))
			-- the lid, split, one board stood up out of the hole
			part(m, "Board", Vector3.new(0.9, 0.2, 3.4), cf * CFrame.new(0.3, 1.2, -1.6) * CFrame.Angles(math.rad(-55), 0.2, 0), "planks")
			part(m, "Board", Vector3.new(0.9, 0.2, 2.6), cf * CFrame.new(3.5, 0.15, 2) * CFrame.Angles(0, rand(0, 6), 0), "planks")
			if chance(0.6) then
				-- the cross knocked flat
				local cr = model(m, "Fallen")
				woodCross(cr, CFrame.new())
				place(cr, cf * CFrame.new(2.4, 0.3, 3.4) * CFrame.Angles(math.rad(84), rand(-0.4, 0.4), 0))
			else
				woodCross(m, cf * CFrame.new(0, 0, 3.7))
			end
		else
			spade(m, (cf * CFrame.new(-3.2, 1, 0.6)).Position)
			part(m, "Plank", Vector3.new(0.9, 0.22, 3.8), cf * CFrame.new(0, 0.18, 0) * CFrame.Angles(0, math.rad(90), 0), "planks")
		end
	end
	return m
end

-- A table tomb. `disturbed`: the lid pushed half off from inside.
local function tableTomb(parent: Instance, cf: CFrame, disturbed: boolean?)
	local m = model(parent, "TableTomb")
	local tint = shade(GRAVESTONE, rand(0.8, 1))
	part(m, "Plinth", Vector3.new(3.8, 0.6, 7.6), cf * CFrame.new(0, 0.3, 0), "stone", tint)
	part(m, "Chest", Vector3.new(3, 2.6, 6.8), cf * CFrame.new(0, 1.9, 0), "stone", tint)
	-- carved panels
	for _, s in { -1, 1 } do
		for k = -1, 1 do
			local p = part(m, "Panel", Vector3.new(0.1, 1.6, 1.7), cf * CFrame.new(s * 1.53, 1.9, k * 2.1), "stone", shade(tint, 0.82))
			p.CastShadow = false
		end
	end
	local lid = part(m, "Lid", Vector3.new(3.8, 0.5, 7.6), cf * CFrame.new(0, 3.45, 0), "stone", shade(tint, 1.06))
	if disturbed then
		lid.CFrame = cf * CFrame.new(1.4, 3.4, -0.9) * CFrame.Angles(0, 0.25, math.rad(-8))
		local inside = part(m, "Dark", Vector3.new(2.4, 0.1, 6.2), cf * CFrame.new(0, 3.18, 0), "dark")
		inside.CastShadow = false
	end
	return m
end

-- The churchyard cross: three steps, a socket stone, the shaft. Its head is
-- broken off and lying on the steps.
local function churchCross(parent: Instance, cf: CFrame)
	local m = model(parent, "ChurchyardCross")
	for k, s in { 7, 5.4, 3.8 } do
		part(m, "Step", Vector3.new(s, 0.9, s), cf * CFrame.new(0, 0.45 + (k - 1) * 0.9, 0) * CFrame.Angles(0, jit(0.02), 0), "stone", shade(GRAVESTONE, 1.05))
	end
	part(m, "Socket", Vector3.new(2.2, 1.6, 2.2), cf * CFrame.new(0, 3.5, 0), "stone", GRAVESTONE)
	part(m, "Shaft", Vector3.new(0.9, 7, 0.9), cf * CFrame.new(0, 7.6, 0), "stone", GRAVESTONE)
	part(m, "Break", Vector3.new(1, 0.5, 1), cf * CFrame.new(0.05, 11.2, 0) * CFrame.Angles(0.15, 0, 0.1), "stone", shade(GRAVESTONE, 0.9))
	local head = model(m, "Head")
	part(head, "Arm", Vector3.new(3.6, 0.8, 0.8), CFrame.new(0, 1.6, 0), "stone", GRAVESTONE)
	part(head, "Top", Vector3.new(0.8, 3.4, 0.8), CFrame.new(0, 1.8, 0), "stone", GRAVESTONE)
	place(head, cf * CFrame.new(2.6, 2.5, 1.2) * CFrame.Angles(math.rad(80), 0.6, 0))
	return m
end

-- A low churchyard wall from a to b, with coping, slumped in places.
-- `gaps`: {from, to} in studs along the wall where it is down altogether.
local function graveWall(parent: Instance, a: Vector3, b: Vector3, gaps: { { number } }?)
	local m = model(parent, "ChurchyardWall")
	local len = (b - a).Magnitude
	local n = math.max(1, math.floor(len / 2.4))
	local seg = len / n
	local base = CFrame.lookAt(a, b)
	for k = 0, n - 1 do
		local tm = (k + 0.5) * seg
		local down = false
		for _, g in gaps or {} do
			if tm > g[1] and tm < g[2] then
				down = true
			end
		end
		if down then
			if chance(0.5) then
				local s = rand(0.8, 1.6)
				part(m, "Rubble", Vector3.new(s, s * 0.6, s), base * CFrame.new(rand(-2.5, 2.5), s * 0.2, -tm) * CFrame.Angles(jit(0.5), rand(0, 6), jit(0.5)), "rubble").CastShadow = false
			end
			continue
		end
		local h = 3.4 + jit(0.15)
		if chance(0.12) then
			h = rand(1.6, 2.6) -- slumped
		end
		part(m, "Masonry", Vector3.new(2, h, seg + 0.02), base * CFrame.new(0, h / 2, -tm), "rubble")
		if h > 3 then
			part(m, "Coping", Vector3.new(2.5, 0.45, seg + 0.04), base * CFrame.new(0, h + 0.2, -tm) * CFrame.Angles(0, 0, jit(0.03)), "stone")
		end
	end
	return m
end

-- The lychgate: a roofed gate where the coffin waited for the priest. The
-- way through runs along local Z.
local function lychgate(parent: Instance, cf: CFrame)
	local m = model(parent, "Lychgate")
	local hw, hd, H = 3.6, 2.4, 7.6
	for _, sx in { -1, 1 } do
		-- a stone sill wall each side, the frame standing on it
		part(m, "SillWall", Vector3.new(1.2, 1.4, hd * 2 + 1.6), cf * CFrame.new(sx * (hw + 0.4), 0.7, 0), "rubble")
		beam(m, "Sill", (cf * CFrame.new(sx * (hw + 0.4), 1.6, -hd - 0.6)).Position, (cf * CFrame.new(sx * (hw + 0.4), 1.6, hd + 0.6)).Position, 0.8, 0.6, "oakDark")
		for _, sz in { -1, 1 } do
			beam(m, "Post", (cf * CFrame.new(sx * (hw + 0.4), 1.6, sz * hd)).Position, (cf * CFrame.new(sx * (hw + 0.4), H, sz * hd)).Position, 0.75, 0.75, "oakDark")
			beam(m, "Brace", (cf * CFrame.new(sx * (hw + 0.4), H - 2.4, sz * hd)).Position, (cf * CFrame.new(sx * (hw + 0.4), H - 0.3, sz * (hd - 1.8))).Position, 0.4, 0.4, "oak")
		end
		beam(m, "Plate", (cf * CFrame.new(sx * (hw + 0.4), H, -hd - 0.8)).Position, (cf * CFrame.new(sx * (hw + 0.4), H, hd + 0.8)).Position, 0.8, 0.8, "oakDark")
		-- the bench along each side, for the bearers
		part(m, "Bench", Vector3.new(0.9, 0.25, hd * 2 - 0.6), cf * CFrame.new(sx * (hw - 0.3), 1.9, 0), "planks")
		-- the gate leaves, standing open against the posts
		local g = model(m, "GateLeaf")
		for y = 0.6, 3.6, 1.0 do
			part(g, "Rail", Vector3.new(0.22, 0.3, 3.2), CFrame.new(0, y, -1.6), "oak")
		end
		for z = 0.2, 3.0, 0.7 do
			part(g, "Pale", Vector3.new(0.18, 4.2, 0.35), CFrame.new(0, 2.1, -z), "oak")
		end
		place(g, cf * CFrame.new(sx * (hw - 0.6), 0, -hd - 0.4) * CFrame.Angles(0, sx * math.rad(rand(5, 25)), 0)) -- swung right back, a little off the wall
	end
	for _, sz in { -1, 1 } do
		beam(m, "TieBeam", (cf * CFrame.new(-hw - 1.2, H - 0.2, sz * hd)).Position, (cf * CFrame.new(hw + 1.2, H - 0.2, sz * hd)).Position, 0.7, 0.8, "oakDark")
	end
	roof(m, cf * CFrame.new(0, H + 0.4, 0) * CFrame.Angles(0, math.pi / 2, 0), hd * 2 + 1.6, hw * 2 + 1.6, { kind = "shingles", pitch = 45, overhang = 1.4, gableOver = 1.0 })
	return m
end

-- An iron brazier on a stone pedestal, laid and NOT lit: lighting it is the
-- graveyard's work (AreaPlan, area 4). Named and tagged so the mechanic can
-- find it; `FirePoint` is where its flame goes.
local function sectionBrazier(parent: Instance, cf: CFrame, section: number)
	local m = model(parent, "GraveBrazier")
	m:SetAttribute("Section", section)
	m:SetAttribute("Lit", false)
	part(m, "Footing", Vector3.new(3.6, 0.6, 3.6), cf * CFrame.new(0, 0.3, 0), "stone")
	part(m, "Pedestal", Vector3.new(2.4, 3.2, 2.4), cf * CFrame.new(0, 2.2, 0), "rubble")
	part(m, "Cap", Vector3.new(3, 0.5, 3), cf * CFrame.new(0, 4.05, 0), "stone")
	-- the basket: a ring and bars
	local ring = part(m, "Ring", Vector3.new(0.3, 3.2, 3.2), cf * CFrame.new(0, 5.6, 0) * CFrame.Angles(0, 0, math.rad(90)), "ironDark")
	;(ring :: Part).Shape = Enum.PartType.Cylinder
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		beam(m, "Bar", (cf * CFrame.new(math.cos(a) * 0.9, 4.3, math.sin(a) * 0.9)).Position, (cf * CFrame.new(math.cos(a) * 1.55, 5.7, math.sin(a) * 1.55)).Position, 0.14, 0.14, "ironDark")
	end
	part(m, "Pan", Vector3.new(2, 0.3, 2), cf * CFrame.new(0, 4.45, 0), "ironDark")
	-- laid ready: split wood and pitch-black rags
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2 + jit(0.3)
		pole(m, "Kindling", (cf * CFrame.new(math.cos(a) * 0.9, 4.6, math.sin(a) * 0.9)).Position, (cf * CFrame.new(math.cos(a) * 0.2, 5.6, math.sin(a) * 0.2)).Position, 0.16, "oakDark")
	end
	local fp = part(m, "FirePoint", Vector3.new(0.4, 0.4, 0.4), cf * CFrame.new(0, 5.4, 0), "dark")
	fp.Transparency = 1
	fp.CanCollide = false
	fp.CanQuery = false
	return m
end

-- A candle: wax, a flame, and (if asked) a little light.
local function candle(parent: Instance, at3: Vector3, h: number, light: boolean?)
	local c = part(parent, "Candle", Vector3.new(h, 0.32, 0.32), CFrame.new(at3 + Vector3.new(0, h / 2, 0)) * CFrame.Angles(0, 0, math.rad(90)), "linen", Color3.fromRGB(214, 202, 172))
	;(c :: Part).Shape = Enum.PartType.Cylinder
	c.CanCollide = false
	c.CastShadow = false
	local f = part(parent, "Flame", Vector3.new(0.16, 0.34, 0.16), CFrame.new(at3 + Vector3.new(0, h + 0.2, 0)), "ember", Color3.fromRGB(255, 190, 110))
	f.CanCollide = false
	f.CastShadow = false
	if light then
		pointLight(f, Color3.fromRGB(255, 170, 90), 0.9, 12)
	end
	return c
end

-- A bell on its headstock, mouth down, hanging from `cf`.
local function bell(parent: Instance, cf: CFrame, size: number)
	local m = model(parent, "Bell")
	local bronze = Color3.fromRGB(104, 84, 60)
	local s = size
	for k, d in { { 0.55, 1.0 }, { 0.62, 0.86 }, { 0.72, 0.62 }, { 0.32, 1.18 } } do
		local y = ({ -0.4, -0.95, -1.5, -1.9 })[k] * s
		local p = part(m, "Bell", Vector3.new(d[1] * s, d[2] * s, d[2] * s), cf * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), "ironDark", bronze)
		;(p :: Part).Shape = Enum.PartType.Cylinder
	end
	ball(m, "Crown", Vector3.new(0.7 * s, 0.5 * s, 0.7 * s), cf * CFrame.new(0, -0.1 * s, 0), "ironDark").Color = bronze
	ball(m, "Clapper", Vector3.new(0.4 * s, 0.4 * s, 0.4 * s), cf * CFrame.new(0, -1.9 * s, 0), "ironDark")
	beam(m, "Headstock", (cf * CFrame.new(-0.9 * s, 0.25 * s, 0)).Position, (cf * CFrame.new(0.9 * s, 0.25 * s, 0)).Position, 0.5 * s, 0.5 * s, "oakDark")
	return m
end

-- A tree that has been dead for years: grey wood, no leaves, branches that
-- split and thin out. `h` is about how tall it stands.
local function deadTree(parent: Instance, cf: CFrame, h: number): Model
	local m = model(parent, "DeadTree")
	local bark = Color3.fromRGB(74, 66, 60)
	local function branch(from: Vector3, dir: Vector3, len: number, r: number, depth: number)
		local to = from + dir * len
		local b = pole(m, if depth == 3 then "Trunk" else "Branch", from, to, r, "oakDark")
		b.Color = shade(bark, rand(0.85, 1.12))
		b.CanCollide = depth == 3
		if depth <= 0 or r < 0.1 then
			return
		end
		local kids = if depth >= 2 then rng:NextInteger(2, 3) else rng:NextInteger(1, 3)
		for _ = 1, kids do
			local yaw = rand(0, math.pi * 2)
			local side = Vector3.new(math.cos(yaw), 0, math.sin(yaw))
			local nd = (dir + side * rand(0.4, 0.9) + Vector3.new(0, rand(-0.1, 0.25), 0)).Unit
			branch(to - dir * 0.15, nd, len * rand(0.55, 0.78), r * 0.6, depth - 1)
		end
	end
	local base = cf.Position
	local up = (Vector3.yAxis + Vector3.new(jit(0.12), 0, jit(0.12))).Unit
	branch(base - Vector3.new(0, 0.6, 0), up, h * 0.42, math.max(0.5, h * 0.045), 3)
	-- the root flare, gripping the ground
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + jit(0.4)
		local out = Vector3.new(math.cos(a), 0, math.sin(a))
		local root = pole(m, "Root", base + out * h * 0.09 - Vector3.new(0, 0.2, 0), base + Vector3.new(0, h * 0.06, 0), h * 0.025, "oakDark")
		root.Color = shade(bark, 0.9)
		root.CastShadow = false
	end
	return m
end

-- A buttress against a wall: `cf` on the ground at the wall's outer face,
-- -Z away from the wall. Stepped back once, each step weathered.
local function buttress(parent: Instance, cf: CFrame, h: number, burnt: boolean?)
	local tint = if burnt then shade(MAT.rubble[3], 0.55) else nil
	part(parent, "Buttress", Vector3.new(1.9, h * 0.6, 2.6), cf * CFrame.new(0, h * 0.3, -1.3), "rubble", tint)
	part(parent, "Buttress", Vector3.new(1.6, h * 0.4, 1.6), cf * CFrame.new(0, h * 0.8, -0.8), "rubble", tint)
	for _, y in { h * 0.6, h } do
		local d = if y < h then 1.0 else 1.6
		local zc = if y < h then -2.1 else -0.8
		local wg = wedge(parent, "Weathering", Vector3.new(if y < h then 1.95 else 1.65, 1.2, d), cf * CFrame.new(0, y + 0.6, zc) * CFrame.Angles(0, math.pi, 0), "stone")
		wg.CastShadow = false
	end
end

-- Corner quoins up a stone corner: big dressed blocks, alternating.
local function quoins(parent: Instance, cf: CFrame, h: number)
	local y, k = 0.6, 0
	while y < h - 0.6 do
		local long = k % 2 == 0
		part(parent, "Quoin", Vector3.new(if long then 2.2 else 1.3, 1.15, if long then 1.3 else 2.2), cf * CFrame.new(if long then 0.45 else 0, y, if long then 0 else 0.45), "stone").CastShadow = false
		y += 1.2
		k += 1
	end
end

-- Flagstones, laid over a rectangle (in B's frame) with their tops at `top`.
local function flags(parent: Instance, B: CFrame, x0: number, x1: number, z0: number, z1: number, top: number)
	local f = model(parent, "Flags")
	local S = 3.4
	local nx, nz = math.max(1, math.floor((x1 - x0) / S + 0.5)), math.max(1, math.floor((z1 - z0) / S + 0.5))
	local sx, sz = (x1 - x0) / nx, (z1 - z0) / nz
	for i = 0, nx - 1 do
		for k = 0, nz - 1 do
			local p = part(f, "Flag", Vector3.new(sx - 0.08, 0.5, sz - 0.08), B * CFrame.new(x0 + sx * (i + 0.5), top - 0.25 + jit(0.015), z0 + sz * (k + 0.5)), "stone", shade(Color3.fromRGB(112, 106, 98), rand(0.8, 1.08)))
			p.CastShadow = false
		end
	end
	-- the joints between them, dark
	local j = part(f, "Joints", Vector3.new(x1 - x0, 0.1, z1 - z0), B * CFrame.new((x0 + x1) / 2, top - 0.3, (z0 + z1) / 2), "dark", Color3.fromRGB(40, 36, 32))
	j.CastShadow = false
	return f
end

local function wall4(m: Instance, F: CFrame, w: number, d: number, h: number, south: { string }?, north: { string }?, west: { string }?, east: { string }?, opts: WallOpts)
	-- the house() convention: south is -Z (runs -x to +x), north +Z, west -X, east +X
	if south then
		stoneWall(m, F * CFrame.new(-w / 2, 0, -d / 2), w, h, south, opts)
	end
	if north then
		stoneWall(m, F * CFrame.new(w / 2, 0, d / 2) * CFrame.Angles(0, math.pi, 0), w, h, north, opts)
	end
	if west then
		stoneWall(m, F * CFrame.new(-w / 2, 0, d / 2) * CFrame.Angles(0, math.pi / 2, 0), d, h, west, opts)
	end
	if east then
		stoneWall(m, F * CFrame.new(w / 2, 0, -d / 2) * CFrame.Angles(0, -math.pi / 2, 0), d, h, east, opts)
	end
end

--[[
	THE CHAPEL. A nave and a lower chancel in rubble stone, lancet windows, a
	steep roof of stone slates, a bell-cote on the west gable and a porch on
	the north door. B: the centre of the nave on the ground; the altar is at
	+X, the porch on +Z. The floor is flush with the yard: the dead walk in
	as easily as the living did.

	Inside, the nave was turned into a mortuary when the ground filled up:
	the dead laid out in rows on the south side, candles round them.
]]
local function chapel(parent: Instance, B: CFrame): Model
	local m = model(nil, "Chapel")
	local NL, ND, NH = 36, 19, 15
	local CL, CD, CH = 14, 14, 12
	local T = 2.4
	local FLOOR = 0.05
	local so: WallOpts = { T = T, lancet = true, winW = 2.4, winSill = 6, winHead = 12.6, doorW = 5, doorH = 10, threshold = FLOOR, archW = 9, archH = 11.4, doorOpen = 160 }
	local co = table.clone(so)
	co.winSill, co.winHead = 5, 10.2
	local eo = table.clone(co)
	eo.winW = 4.4
	eo.winSill = 4.2

	wall4(m, B, NL, ND, NH, { "window", "window", "window", "window" }, { "window", "window", "door", "window" }, { "wall", "door", "wall" }, { "wall", "arch", "wall" }, so)
	local F = B * CFrame.new(NL / 2 + CL / 2, 0, 0)
	wall4(m, F, CL, CD, CH, { "window", "window" }, { "wall", "window" }, nil, nil, co)
	-- the east wall on its own: it carries the big window over the altar
	stoneWall(m, F * CFrame.new(CL / 2, 0, -CD / 2) * CFrame.Angles(0, -math.pi / 2, 0), CD, CH, { "window" }, eo)
	flags(m, B, -NL / 2 + T - 0.2, NL / 2, -ND / 2 + T - 0.2, ND / 2 - T + 0.2, FLOOR)
	flags(m, F, -CL / 2, CL / 2 - T + 0.2, -CD / 2 + T - 0.2, CD / 2 - T + 0.2, FLOOR)

	-- corners and buttresses
	for _, c in { { -NL / 2, -ND / 2, 0 }, { NL / 2, -ND / 2, 90 }, { -NL / 2, ND / 2, -90 }, { NL / 2, ND / 2, 180 } } do
		quoins(m, B * CFrame.new(c[1], 0, c[2]) * CFrame.Angles(0, math.rad(c[3]), 0), NH)
	end
	for _, x in { -9, 0, 9 } do
		buttress(m, B * CFrame.new(x, 0, -ND / 2) * CFrame.Angles(0, 0, 0), 9)
	end
	buttress(m, B * CFrame.new(9, 0, ND / 2) * CFrame.Angles(0, math.pi, 0), 9)
	for _, s in { -1, 1 } do
		buttress(m, F * CFrame.new(CL / 2, 0, s * (CD / 2 - 1.6)) * CFrame.Angles(0, -math.pi / 2, 0), 7.5)
	end

	-- roofs of stone slates, stone gables
	local slates = { kind = "shingles", pitch = 52, overhang = 1.0, gableOver = 0.4, gableKey = "rubble" }
	roof(m, B * CFrame.new(0, NH, 0), NL, ND, slates)
	roof(m, F * CFrame.new(0, CH, 0), CL, CD, slates)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.RoofShingles then
			d.Color = shade(Color3.fromRGB(120, 124, 126), rand(0.85, 1.05))
		end
	end

	-- the bell-cote on the west gable: two piers, a cap, the bell between
	local apex = NH + (ND / 2) * math.tan(math.rad(52))
	local bx = -NL / 2 + 1.2
	for _, s in { -1, 1 } do
		part(m, "BellPier", Vector3.new(2.4, 6.2, 1.2), B * CFrame.new(bx, apex + 2.4, s * 2.1), "rubble")
	end
	part(m, "BellCap", Vector3.new(2.8, 0.9, 5.6), B * CFrame.new(bx, apex + 5.9, 0), "stone")
	for _, s in { -1, 1 } do
		local w = wedge(m, "BellGable", Vector3.new(2.6, 1.6, 2.8), B * CFrame.new(bx, apex + 7.15, s * 1.4) * CFrame.Angles(0, if s > 0 then math.pi else 0, 0), "stone")
		w.CastShadow = true
	end
	bell(m, B * CFrame.new(bx, apex + 5.2, 0), 0.9)

	-- THE PORCH, on the north door (which is at x -4.5)
	local pso: WallOpts = { T = 1.6, lancet = true, archW = 5.4, archH = 8, threshold = FLOOR }
	stoneWall(m, B * CFrame.new(0.3, 0, ND / 2) * CFrame.Angles(0, -math.pi / 2, 0), 7, 9, { "wall" }, pso)
	stoneWall(m, B * CFrame.new(-9.3, 0, ND / 2 + 7) * CFrame.Angles(0, math.pi / 2, 0), 7, 9, { "wall" }, pso)
	stoneWall(m, B * CFrame.new(0.3, 0, ND / 2 + 7) * CFrame.Angles(0, math.pi, 0), 9.6, 9, { "arch" }, pso)
	flags(m, B, -7.8, -1.2, ND / 2, ND / 2 + 5.5, FLOOR)
	roof(m, B * CFrame.new(-4.5, 9, ND / 2 + 3.5) * CFrame.Angles(0, math.pi / 2, 0), 7, 9.6, { kind = "shingles", pitch = 48, overhang = 0.6, gableOver = 0.3, gableKey = "rubble" })
	for _, x in { -7.2, -1.8 } do
		part(m, "PorchBench", Vector3.new(1.2, 1.6, 5), B * CFrame.new(x, 0.8, ND / 2 + 3.2), "stone")
	end

	-- INSIDE -----------------------------------------------------------
	-- the rood beam across the chancel arch, the cross on it
	local rx = NL / 2 - T - 0.6
	beam(m, "RoodBeam", (B * CFrame.new(rx, 12.4, -ND / 2 + T)).Position, (B * CFrame.new(rx, 12.4, ND / 2 - T)).Position, 0.8, 0.9, "oakDark")
	part(m, "Rood", Vector3.new(0.5, 4.2, 0.5), B * CFrame.new(rx, 14.8, 0), "oakDark")
	part(m, "Rood", Vector3.new(0.5, 0.5, 2.6), B * CFrame.new(rx, 15.6, 0), "oakDark")

	-- the altar against the east wall: stone, a cloth, two candles, a cross
	local ax = CL / 2 - T - 1.3
	part(m, "Altar", Vector3.new(2.4, 3.4, 5.6), F * CFrame.new(ax, FLOOR + 1.7, 0), "stone")
	part(m, "AltarCloth", Vector3.new(2.6, 0.12, 5.9), F * CFrame.new(ax, FLOOR + 3.45, 0), "linen")
	part(m, "Frontal", Vector3.new(0.1, 2.6, 4.8), F * CFrame.new(ax - 1.25, FLOOR + 2.0, 0), "cloth")
	for _, z in { -2, 2 } do
		candle(m, (F * CFrame.new(ax, FLOOR + 3.5, z)).Position, 1.6, true)
	end
	part(m, "AltarCross", Vector3.new(0.25, 2.2, 0.25), F * CFrame.new(ax + 0.4, FLOOR + 4.6, 0), "iron", Color3.fromRGB(120, 100, 60))
	part(m, "AltarCross", Vector3.new(0.25, 0.25, 1.3), F * CFrame.new(ax + 0.4, FLOOR + 5.1, 0), "iron", Color3.fromRGB(120, 100, 60))

	-- a lord's tomb in the chancel, along the north wall, its effigy on top
	local tomb = tableTomb(m, F * CFrame.new(-1, FLOOR, 2.4) * CFrame.Angles(0, math.pi / 2, 0), false)
	local ef = F * CFrame.new(-1, FLOOR + 3.7, 2.4) * CFrame.Angles(0, math.pi / 2, 0)
	part(tomb, "Effigy", Vector3.new(1.5, 0.7, 4.4), ef * CFrame.new(0, 0.35, -0.3), "stone", GRAVESTONE)
	ball(tomb, "Effigy", Vector3.new(0.9, 0.8, 0.9), ef * CFrame.new(0, 0.5, 2.4), "stone").Color = GRAVESTONE
	part(tomb, "Effigy", Vector3.new(0.9, 0.4, 1.4), ef * CFrame.new(0, 0.8, 0.6), "stone", shade(GRAVESTONE, 0.92))

	-- the font by the west door
	local font = B * CFrame.new(-NL / 2 + T + 4, FLOOR, -ND / 2 + T + 3)
	local ped = part(m, "Font", Vector3.new(2.6, 1.3, 1.3), font * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, 0, math.rad(90)), "stone")
	;(ped :: Part).Shape = Enum.PartType.Cylinder
	local bowl = part(m, "Font", Vector3.new(1.4, 3, 3), font * CFrame.new(0, 3.3, 0) * CFrame.Angles(0, 0, math.rad(90)), "stone")
	;(bowl :: Part).Shape = Enum.PartType.Cylinder
	local lid = part(m, "FontLid", Vector3.new(0.3, 3.1, 3.1), font * CFrame.new(0.9, 3.6, 0.9) * CFrame.Angles(0.3, 0, math.rad(80)), "oakDark")
	;(lid :: Part).Shape = Enum.PartType.Cylinder

	-- the dead, laid out on the south side, heads to the wall; candles round them
	local row = model(m, "LaidOut")
	for k = 0, 8 do
		local x = -11 + k * 2.75
		shroud(row, B * CFrame.new(x + jit(0.2), FLOOR, -ND / 2 + T + 3.2) * CFrame.Angles(0, math.pi / 2 + jit(0.06), 0))
	end
	for k = 0, 9 do
		local x = -12.4 + k * 2.75
		candle(row, (B * CFrame.new(x, FLOOR, -ND / 2 + T + 6.4)).Position, rand(0.6, 1.4), k % 3 == 1)
	end
	-- benches pushed back against the north wall, one on its side
	for k, x in { -12, -2, 7 } do
		local b = model(m, "Bench")
		part(b, "Seat", Vector3.new(6, 0.35, 1.2), CFrame.new(0, 1.6, 0), "planks")
		for _, s in { -1, 1 } do
			part(b, "Leg", Vector3.new(0.35, 1.5, 1.0), CFrame.new(s * 2.4, 0.75, 0), "oakDark")
		end
		local cf = B * CFrame.new(x, FLOOR, ND / 2 - T - 1.4)
		if k == 2 then
			cf = cf * CFrame.new(0, 0.6, -0.8) * CFrame.Angles(math.rad(-85), 0.2, 0)
		end
		place(b, cf)
	end
	-- the lectern, by the chancel arch
	local lec = B * CFrame.new(NL / 2 - T - 3, FLOOR, -5.4)
	pole(m, "Lectern", (lec * CFrame.new(0, 0, 0)).Position, (lec * CFrame.new(0, 3.8, 0)).Position, 0.25, "oakDark")
	part(m, "Lectern", Vector3.new(1.6, 0.2, 2.2), lec * CFrame.new(0, 4.1, 0) * CFrame.Angles(0, 0, math.rad(-25)), "oak")
	part(m, "Book", Vector3.new(1.0, 0.25, 1.5), lec * CFrame.new(-0.1, 4.35, 0) * CFrame.Angles(0, 0, math.rad(-25)), "cloth", Color3.fromRGB(70, 40, 30))
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and (d.Name == "Lectern" or d.Name == "Book" or d.Name == "Font" or d.Name == "FontLid") then
			d.CanCollide = d.Name == "Font"
		end
	end
	clutter(m, (B * CFrame.new(0, 0, 2)).Position, 9, 10, { "straw", "straw" }, true)
	m.Parent = parent
	return m
end

-- A family vault: a little stone house for the dead, an iron gate hanging
-- open, the tomb inside opened from within. Front at -Z.
local function mausoleum(parent: Instance, B: CFrame): Model
	local m = model(nil, "Mausoleum")
	local W, D, H = 11, 13, 9
	local o: WallOpts = { T = 1.8, archW = 4.4, archH = 7.4, threshold = 0.05 }
	wall4(m, B, W, D, H, { "wall", "arch", "wall" }, { "wall" }, { "wall" }, { "wall" }, o)
	flags(m, B, -W / 2 + 1.6, W / 2 - 1.6, -D / 2, D / 2 - 1.6, 0.05)
	roof(m, B * CFrame.new(0, H, 0) * CFrame.Angles(0, math.pi / 2, 0), D, W, { kind = "shingles", pitch = 28, overhang = 0.5, gableOver = 0.5, gableKey = "rubble" })
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.RoofShingles then
			d.Color = shade(Color3.fromRGB(110, 112, 110), rand(0.85, 1.05))
		end
	end
	-- pilasters at the front corners, a plaque over the arch
	for _, s in { -1, 1 } do
		part(m, "Pilaster", Vector3.new(1.4, H, 0.6), B * CFrame.new(s * (W / 2 - 0.7), H / 2, -D / 2 - 0.25), "stone")
	end
	part(m, "Plaque", Vector3.new(3.4, 1.1, 0.3), B * CFrame.new(0, 8.3, -D / 2 - 0.1), "stone", shade(GRAVESTONE, 0.8))
	part(m, "Cornice", Vector3.new(W + 0.8, 0.6, 0.8), B * CFrame.new(0, H - 0.2, -D / 2 - 0.1), "stone")
	-- the gate: bars on two leaves, one hanging off its hinge
	for _, s in { -1, 1 } do
		local g = model(m, "Gate")
		for k = 0, 4 do
			part(g, "Bar", Vector3.new(0.14, 7, 0.14), CFrame.new(s * (0.2 + k * 0.45), 3.6, 0), "ironDark")
		end
		for _, y in { 0.8, 3.6, 6.6 } do
			part(g, "Rail", Vector3.new(2.2, 0.2, 0.14), CFrame.new(s * 1.1, y, 0), "ironDark")
		end
		local hinge = B * CFrame.new(s * 2.2, 0, -D / 2 - 0.3)
		local swing = if s < 0 then math.rad(-100) else math.rad(70)
		place(g, hinge * CFrame.Angles(0, swing, if s > 0 then math.rad(8) else 0) * CFrame.new(-s * 2.2, if s > 0 then -0.3 else 0, 0))
	end
	tableTomb(m, B * CFrame.new(0, 0.05, 1.4), true)
	clutter(m, (B * CFrame.new(0, 0.2, -2)).Position, 2.5, 5, { "bones", "stone" }, true)
	m.Parent = parent
	return m
end

--------------------------------------------------------------------------
-- AREA 1 — THE OUTER WARD. Guardhouse, barracks, muster yard, a watch
-- platform, the camp that burned, and a barricade across the yard: they
-- barred the way in from the gate. They knew what was coming.
--------------------------------------------------------------------------
local function area1()
	local f = areaFolder(1)
	local _, zFar = Castle.chamberBounds(1)

	-- THE ROAD: gate, arrival pad, through the gap in the barricade, then
	-- across to the passage in the far east corner.
	local road = { Vector2.new(0, -82), Vector2.new(0, -116), Vector2.new(18, -136), Vector2.new(58, -158), Vector2.new(100, -180), Vector2.new(132, -199), Vector2.new(153, zFar + 14) }
	local guardLane = { Vector2.new(-34, -48), Vector2.new(-70, -52), Vector2.new(-90, -55) }
	local barracksLane = { Vector2.new(4, -120), Vector2.new(-40, -150), Vector2.new(-100, -166) }
	paintGround(2, zFar + 2, {
		{ path = road, width = 13, material = Enum.Material.Cobblestone, verge = Enum.Material.Mud },
		{ path = guardLane, width = 6, material = Enum.Material.Mud },
		{ path = barracksLane, width = 5, material = Enum.Material.Mud },
	}, { { Vector2.new(-62, -128), 22 }, { Vector2.new(10, -175), 16 } })
	task.wait()

	-- 1. THE GUARDHOUSE — stone below, timber above, a fighting deck on top.
	local guard = house(f, at(-100, -55, "E"), {
		name = "Guardhouse",
		W = 24,
		D = 16,
		storeys = 2,
		ground = "stone",
		front = { "window", "door", "loop", "window" },
		back = { "loop", "window", "loop", "loop" },
		left = { "loop", "window", "loop" },
		right = { "window", "loop", "window" },
		upperFront = { "window", "window", "window", "window" },
		roof = { kind = "deck" },
		glow = true,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			prop(m, "Table", B * CFrame.new(4.5, y, -3.9) * CFrame.Angles(0, math.rad(4), 0))
			prop(m, "Barrel", B * CFrame.new(-7.6, y, -4.4))
			helmet(m, B * CFrame.new(4.9, y + 2.7, -3.6))
			if info.upperY then
				-- kept bare: two flights meet on this floor and the way between them stays open
				prop(m, "Chest", B * CFrame.new(9.6, info.upperY, -1.5))
				prop(m, "Sacks", B * CFrame.new(-9.6, info.upperY, 5.5))
			end
			if info.deckY then
				-- clear of the flight's head (front, x -8.5 to 2.5) and its hole
				brazier(m, B * CFrame.new(8, info.deckY, 1))
				prop(m, "Crate", B * CFrame.new(-6, info.deckY, 4))
				for _ = 1, 5 do
					arrow(m, (B * CFrame.new(rand(-9, 9), info.deckY + 0.2, rand(-6, 6))).Position, Vector3.new(jit(1), -0.8, jit(1)))
				end
			end
		end,
	})
	-- a brazier by the door, the racks outside, and the horse trough
	brazier(f, at(-86, -44, "E"))
	spearRack(f, at(-90, -70, "E"), 6)
	prop(f, "Trough", at(-87, -68, 90))
	task.wait()

	-- 2. THE BARRACKS — a long two-storey range, thatched, beds in rows.
	house(f, at(-118, -178, "N"), {
		name = "Barracks",
		W = 46,
		D = 15,
		storeys = 2,
		front = { "window", "door", "window", "wall", "window", "window", "wall", "window", "door", "window" },
		back = { "wall", "window", "wall", "window", "wall", "wall", "window", "wall", "window", "wall" },
		upperFront = { "window", "wall", "window", "window", "wall", "window", "window", "wall", "window", "wall" },
		roof = { kind = "thatch", chimneyX = 20.5, holes = 0.12 },
		damage = 0.1,
		glow = true,
		furnish = function(m, B, info)
			-- Along the walls only: the middle of the floor is the way through,
			-- door to door to the foot of the stair (which stands at x -19.5).
			local y = info.plinthH + 0.32
			for _, x in { -1.5, 4.1, 9.7 } do
				prop(m, "Bed", B * CFrame.new(x, y, 4.7), 1.5)
			end
			for _, x in { -9, 8 } do
				prop(m, "Bed", B * CFrame.new(x, y, -5.4), 1.5)
			end
			prop(m, "Table", B * CFrame.new(0, y, -5.2), 1.15)
			hearth(m, B * CFrame.new(18.2, y, 0) * CFrame.Angles(0, math.pi / 2, 0), 6, true) -- its back to the end stack
			prop(m, "Cauldron", B * CFrame.new(16.6, y + 1.2, 0))
			prop(m, "Shelf", B * CFrame.new(15, y, 6.4) * CFrame.Angles(0, math.pi, 0))
			if info.upperY then
				for k = 0, 5 do
					prop(m, "Bed", B * CFrame.new(-12 + k * 5.6, info.upperY, -6.6), 1.5)
				end
				prop(m, "Sacks", B * CFrame.new(10, info.upperY, 5))
				prop(m, "Crate", B * CFrame.new(16, info.upperY, 5))
			end
		end,
	})
	task.wait()

	-- 3. THE MUSTER YARD — dummies, butts, racks, a fence half down.
	local yard = model(f, "MusterYard")
	for i, p in { Vector2.new(-82, -108), Vector2.new(-70, -112), Vector2.new(-58, -107) } do
		dummy(yard, at(p.X, p.Y, 180 + jit(20)))
		if i == 2 then
			arrow(yard, Vector3.new(p.X + 0.3, 4.5, p.Y + 0.5), Vector3.new(0, -0.2, -1))
		end
	end
	archeryButt(yard, at(-92, -146, "N"))
	archeryButt(yard, at(-78, -148, 185))
	spearRack(yard, at(-46, -100, "N"), 7)
	spearRack(yard, at(-104, -122, "E"), 6)
	fence(yard, { Vector3.new(-108, GROUND, -96), Vector3.new(-108, GROUND, -156), Vector3.new(-40, GROUND, -156) }, 0.25)
	prop(yard, "HayBaleMesh", at(-100, -134, 20))
	clutter(yard, Vector3.new(-72, 0, -128), 22, 26, { "straw", "arrow", "arrow", "stone", "helmet" })
	brazier(yard, at(-64, -122, 0))
	brazier(yard, at(-88, -150, 0))
	task.wait()

	-- 4. THE WATCH PLATFORM — climbable, and so the dead can climb it too.
	watchPlatform(f, at(-52, -194, "N"), 13, 9, 1)

	-- 5. THE CAMP THAT BURNED.
	local camp = model(f, "Camp")
	tent(camp, at(-14, -162, "E"), 8, 10, 6.2)
	tent(camp, at(-6, -186, "E"), 8, 10, 6.2, "burnt")
	tent(camp, at(-30, -200, 15), 8, 10, 6.2, "collapsed")
	campfire(camp, at(10, -176, 0), true)
	clutter(camp, Vector3.new(0, 0, -182), 18, 18, { "straw", "barrelDown", "sacks", "plank", "stone", "bones" })
	local burning = model(camp, "Burning")
	fireAt(burning, Vector3.new(-6, GROUND + 2.2, -186), 1.6, 40)
	smokeOn(burning:FindFirstChild("FireCore") :: BasePart, 4, true)
	task.wait()

	-- 6. THE BARRICADE ACROSS THE YARD, facing the gate, with one gap.
	local bar = model(f, "Barricade")
	local function line(x0: number, x1: number, z: number)
		local x = x0
		while x < x1 do
			local k = pick({ "crate", "crate", "barrel", "cart", "sacks", "planks" })
			local cf = at(x, z + jit(1.5), 180 + jit(25))
			if k == "cart" and x1 - x > 8 then
				local c = prop(bar, "Cart", cf, 1.4)
				if c then
					c:PivotTo(c:GetPivot() * CFrame.Angles(0, 0, math.rad(85)) + Vector3.new(0, 1.5, 0))
				end
				x += 7
			elseif k == "planks" then
				for j = 0, 2 do
					part(bar, "Board", Vector3.new(0.4, 3.5, 7), CFrame.new(x + 1.5, GROUND + 2, z) * CFrame.Angles(0, math.rad(90), math.rad(-60 + j * 8)) * CFrame.new(0, 0, j * 0.6 - 0.6), "planks")
				end
				x += 4
			elseif k == "barrel" then
				prop(bar, "Barrel", cf)
				if chance(0.5) then
					prop(bar, "Barrel", at(x + 1, z - 2.4, 0))
				end
				x += 3
			elseif k == "sacks" then
				prop(bar, "Sacks", cf, 1.2)
				x += 4
			else
				prop(bar, "Crate", cf, 1.2)
				if chance(0.6) then
					prop(bar, "Crate", cf * CFrame.new(0, 3.1, 0) * CFrame.Angles(0, jit(0.4), 0), 1.1)
				end
				x += 4.4
			end
		end
		stakes(bar, Vector3.new(x0, GROUND, z + 4), Vector3.new(x1, GROUND, z + 4), Vector3.new(0, 0, 1))
	end
	line(-34, -6, -126)
	line(26, 92, -128)
	brazier(bar, at(-3, -122, 0))
	brazier(bar, at(24, -124, 0))
	clutter(bar, Vector3.new(30, 0, -116), 30, 22, { "arrow", "arrow", "arrow", "shield", "helmet", "stone" })
	task.wait()

	-- 7. THE ARMOURY — a lean-to on the east wall, racks and stores.
	local inner = Castle.innerHalfWidth()
	local arm = leanTo(f, at(inner - 9.5, -40, "W"), 40, 18, 14, 9.5, { kind = "shingles", sides = true })
	arm.Name = "Armoury"
	for k = 0, 3 do
		spearRack(arm, at(inner - 2.5, -55 + k * 9, "W"), 7)
	end
	prop(arm, "Anvil", at(inner - 10, -26, 30))
	prop(arm, "Table", at(inner - 9, -46, "W"), 1.2)
	for k = 0, 2 do
		helmet(arm, at(inner - 9 + jit(0.6), -47.5 + k * 1.6, 0, 3.05))
	end
	clutter(arm, Vector3.new(inner - 9, 0, -40), 14, 14, { "barrel", "crate", "shield", "sacks" })

	-- 8. THE STORE SHED in the north-west corner.
	local shed = openShed(f, at(-inner + 12, -34, "E"), 16, 12, 9, { kind = "shingles", pitch = 35, holes = 0.25 })
	shed.Name = "StoreShed"
	clutter(shed, Vector3.new(-inner + 12, 0, -34), 6, 10, { "firewood", "firewood", "crate", "sacks", "barrel" })
	prop(shed, "Cart", at(-inner + 15, -24, 70), 1.4)
	task.wait()

	-- 9. THE SERGEANT'S HOUSE, east side of the yard, and a burnt store by the
	--    far wall.
	house(f, at(100, -100, "W"), {
		name = "SergeantsHouse",
		W = 20,
		D = 13,
		storeys = 2,
		front = { "window", "door", "wall", "window" },
		roof = { kind = "thatch" },
		glow = true,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			-- An open hearth in the middle of the floor, the old way: no stack to
			-- wall off the foot of the stair, the smoke finds its own way out.
			prop(m, "Table", B * CFrame.new(4.8, y, -3.6))
			prop(m, "Shelf", B * CFrame.new(8, y, -2.5) * CFrame.Angles(0, -math.pi / 2, 0))
			local slab = part(m, "HearthStone", Vector3.new(3.6, 0.3, 3.6), B * CFrame.new(-4, y + 0.15, -2.6), "stone")
			slab.CanCollide = false
			local embers = part(m, "Embers", Vector3.new(2, 0.25, 2), B * CFrame.new(-4, y + 0.4, -2.6), "ember")
			embers.CanCollide = false
			embers.Transparency = 0.3
			fireAt(m, (B * CFrame.new(-4, y + 1.1, -2.6)).Position, 0.7, 22)
			local smoke = part(m, "SmokeHole", Vector3.new(0.5, 0.5, 0.5), B * CFrame.new(-4, info.plinthH + info.SH * 2 + 3, 0), "dark")
			smoke.Transparency = 1
			smoke.CanCollide = false
			smokeOn(smoke, 2)
			if info.upperY then
				prop(m, "Bed", B * CFrame.new(4, info.upperY, -3), 1.6)
				prop(m, "Chest", B * CFrame.new(-4, info.upperY, -4))
			end
		end,
	})
	house(f, at(56, -200, "N"), {
		name = "BurntStore",
		W = 15,
		D = 11,
		storeys = 1,
		burnt = true,
		damage = 0.45,
		front = { "door", "window", "wall" },
		roof = { kind = "thatch", burnt = true },
		furnish = function(m, B, info)
			clutter(m, (B * CFrame.new(0, info.plinthH, 0)).Position, 5, 8, { "barrelDown", "plank", "sacks", "stone" }, true)
			local ember = fireAt(m, (B * CFrame.new(2, info.plinthH + 1, 1)).Position, 0.9, 26)
			smokeOn(ember, 3, true)
		end,
	})
	task.wait()

	-- 10. THE DEAD OF THE LAST STAND, by the passage.
	local stand = model(f, "LastStand")
	clutter(stand, Vector3.new(128, 0, -186), 14, 24, { "shield", "helmet", "arrow", "arrow", "bones", "stone" })
	local pole0 = pole(stand, "BannerPole", Vector3.new(118, GROUND, -176), Vector3.new(119.5, GROUND + 13, -177), 0.2, "oakDark")
	pole0.CastShadow = false
	part(stand, "Banner", Vector3.new(0.15, 6, 3.6), CFrame.new(119.8, GROUND + 9.5, -175.4) * CFrame.Angles(0, 0, math.rad(-6)), "cloth")
	prop(stand, "Cart", at(138, -170, 120), 1.4)
	clutter(f, Vector3.new(0, 0, -100), 120, 40, { "stone", "stone", "straw", "plank", "arrow" })
	task.wait()

	-- 11. THE GATEKEEPER'S LODGING, inside the gate on the east, and the
	--     wagons that never left.
	house(f, at(70, -40, "W"), {
		name = "GatekeepersLodging",
		W = 24, -- a stone ground floor needs the length for its stair
		D = 15,
		storeys = 2,
		ground = "stone",
		front = { "window", "door", "loop", "window" },
		roof = { kind = "shingles" },
		glow = true,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			prop(m, "Table", B * CFrame.new(4.5, y, -3.4))
			prop(m, "Chest", B * CFrame.new(-7.5, y, -3.6))
			if info.upperY then
				prop(m, "Bed", B * CFrame.new(-3, info.upperY, -3), 1.6)
				prop(m, "Shelf", B * CFrame.new(9, info.upperY, -3) * CFrame.Angles(0, math.pi / 2, 0))
			end
		end,
	})
	local wagons = model(f, "WagonPark")
	prop(wagons, "Cart", at(100, -24, 75), 1.5)
	prop(wagons, "Cart", at(118, -32, 100), 1.5)
	clutter(wagons, Vector3.new(108, 0, -28), 9, 12, { "crate", "sacks", "barrel", "firewood" })
	task.wait()

	-- 12. A BUILDING THAT CAME DOWN, east of the yard; and a woodshed and
	--     latrine against the west wall behind the barracks.
	ruin(f, at(128, -142, "W"), 16, 12, 16)
	local inner = Castle.innerHalfWidth()
	local wood = leanTo(f, at(-inner + 6.5, -196, "E"), 22, 12, 11, 7.5, { kind = "shingles", sides = true })
	wood.Name = "Woodshed"
	for k = 0, 3 do
		prop(wood, "Firewood", at(-inner + 3, -205 + k * 6, 90), 1.4)
	end
	prop(wood, "Firewood", at(-inner + 7, -190, 90), 1.4)

	-- 13. Light on the walls, and lanterns along the road.
	roadLanterns(f, road, 38, 9)
	wallTorches(f, 1)
	clearMarkers(1, f)
end

--------------------------------------------------------------------------
-- AREA 2 — THE STABLES. A long stable range with the hayloft over it, the
-- tack room, an open hay barn, the farrier's forge, a carriage shed, the
-- paddock. The stalls are broken OUTWARD: whatever was in them did not use
-- the door.
--------------------------------------------------------------------------
local function area2()
	local f = areaFolder(2)
	local zNear, zFar = Castle.chamberBounds(2)
	local road = { Vector2.new(153, zNear - 16), Vector2.new(118, -262), Vector2.new(60, -282), Vector2.new(10, -300), Vector2.new(-45, -332), Vector2.new(-95, -380), Vector2.new(-132, -430), Vector2.new(-153, zFar + 14) }
	paintGround(zNear - 2, zFar + 2, {
		{ path = road, width = 12, material = Enum.Material.Cobblestone, verge = Enum.Material.Mud },
		{ path = { Vector2.new(30, -292), Vector2.new(50, -395) }, width = 7, material = Enum.Material.Mud },
		{ path = { Vector2.new(-60, -345), Vector2.new(-110, -318) }, width = 6, material = Enum.Material.Mud },
	}, { { Vector2.new(56, -322), 30 }, { Vector2.new(55, -392), 22 }, { Vector2.new(-30, -405), 16 } })
	task.wait()

	-- 1. THE STABLE RANGE.
	house(f, at(55, -412, "N"), {
		name = "Stables",
		W = 56,
		D = 15,
		storeys = 2,
		front = { "door", "wall", "door", "wall", "door", "wall", "door", "wall", "door", "wall", "door", "window" },
		upperFront = { "window", "wall", "wall", "door", "wall", "window", "window", "wall", "door", "wall", "wall", "window" },
		roof = { kind = "thatch", holes = 0.18 },
		damage = 0.12,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			stalls(m, B * CFrame.new(7, 0, 0), 40, 15, y, 8)
			clutter(m, (B * CFrame.new(0, info.plinthH, -3)).Position, 18, 14, { "straw", "straw", "plank", "barrelDown" }, true)
			if info.upperY then
				-- stacked on the front half of the loft: the back left is the stair head
				for _, x in { -4, 6, 16 } do
					baleStack(m, B * CFrame.new(x, info.upperY, -6.4), 2, 2, 2)
				end
				-- the test point goes where the bales are not
				m:SetAttribute("UpperProbe", (B * CFrame.new(-14, info.upperY + 2.5, -2)).Position)
				clutter(m, (B * CFrame.new(0, info.upperY, 0)).Position, 20, 16, { "straw" }, true)
			end
			-- hoist beams over the two loft doors, ropes still on the pulleys
			for _, x in { -11.5, 11.5 } do
				local topY = info.plinthH + info.SH + 0.8 + info.SH - 1.4
				local a = B * CFrame.new(x, topY - 0.6, -7.5 - 1.4)
				local b = a * CFrame.new(0, 0, -3.2)
				beam(m, "HoistBeam", (a * CFrame.new(0, 0, 2)).Position, b.Position, 0.8, 0.8, "oakDark")
				local pulley = part(m, "Pulley", Vector3.new(0.4, 1.2, 1.2), b * CFrame.new(0, -0.8, 0.4), "oakDark")
				;(pulley :: Part).Shape = Enum.PartType.Cylinder
				beam(m, "Rope", (b * CFrame.new(0, -1.2, 0.4)).Position, (b * CFrame.new(jit(0.3), -8, 0.6)).Position, 0.12, 0.12, "burlap")
			end
		end,
	})
	brazier(f, at(28, -396, 0))
	brazier(f, at(84, -396, 0))
	-- troughs between the doors, never in front of one
	prop(f, "Trough", at(48, -395, 0), 1.6)
	prop(f, "Trough", at(66.7, -395, 0), 1.6)
	task.wait()

	-- 2. THE TACK ROOM at the east end.
	house(f, at(110, -414, "W"), {
		name = "TackRoom",
		W = 13,
		D = 10,
		storeys = 1,
		front = { "door", "window" },
		roof = { kind = "shingles", pitch = 42 },
		glow = true,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			for k = 0, 2 do
				saddleRack(m, B * CFrame.new(-4 + k * 3.6, y, 2.5))
			end
			prop(m, "Chest", B * CFrame.new(4, y, -2.5))
		end,
	})

	-- 3. THE HAY BARN — open sided, thatched, full.
	local barn = openShed(f, at(-30, -418, "N"), 26, 16, 10, { kind = "thatch", pitch = 48, holes = 0.1 })
	barn.Name = "HayBarn"
	baleStack(barn, at(-40, -424, 0), 3, 3, 2)
	baleStack(barn, at(-24, -424, 0), 2, 3, 1)
	clutter(barn, Vector3.new(-30, 0, -412), 12, 18, { "straw", "straw", "straw" })
	part(barn, "Pitchfork", Vector3.new(0.15, 0.15, 6), CFrame.new(-18, GROUND + 2.5, -406) * CFrame.Angles(math.rad(70), 0, 0.3), "oak")
	task.wait()

	-- 4. THE FARRIER'S FORGE — open on the yard side.
	house(f, at(-118, -318, "E"), {
		name = "Forge",
		W = 20,
		D = 14,
		storeys = 1,
		front = { "open", "open", "open", "open" },
		roof = { kind = "shingles", pitch = 40, chimneyX = -6 },
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			hearth(m, B * CFrame.new(-6, y, -2.2), 6, true)
			bellows(m, B * CFrame.new(-1.4, y, -1.2) * CFrame.Angles(0, math.rad(90), 0))
			-- the anvil stands back from the open front: 1.6 inside a bay it shut it
			prop(m, "Anvil", B * CFrame.new(1.5, y, 3) * CFrame.Angles(0, 0.4, 0), 1.3)
			prop(m, "Trough", B * CFrame.new(6, y, -1), 1.3)
			prop(m, "Firewood", B * CFrame.new(7, y, 4.5), 1.3)
			-- horseshoes on a board, tongs, the coal heap
			local board = part(m, "ToolBoard", Vector3.new(5, 3, 0.3), B * CFrame.new(4, y + 4.5, 6.1), "planks")
			for k = 0, 5 do
				local shoe = part(m, "Horseshoe", Vector3.new(0.6, 0.7, 0.12), board.CFrame * CFrame.new(-2 + k * 0.8, 0.3 * (k % 2), -0.22), "ironDark")
				shoe.CastShadow = false
			end
			for _ = 1, 8 do
				local c = part(m, "Coal", Vector3.new(rand(0.4, 0.9), rand(0.3, 0.6), rand(0.4, 0.9)), B * CFrame.new(-9 + jit(1), y + 0.3, -2 + jit(1)) * CFrame.Angles(jit(1), jit(1), jit(1)), "soot")
				c.CastShadow = false
			end
		end,
	})
	task.wait()

	-- 5. THE CARRIAGE SHED.
	local carr = openShed(f, at(-78, -252, "S"), 24, 12, 9, { kind = "shingles", pitch = 34 })
	carr.Name = "CarriageShed"
	prop(carr, "Cart", at(-84, -252, 0), 1.7)
	prop(carr, "Cart", at(-70, -253, 8), 1.7)
	clutter(carr, Vector3.new(-78, 0, -252), 9, 8, { "barrel", "crate", "plank" })

	-- 6. THE PADDOCK, its rails down on the side the horses went through.
	local pad = model(f, "Paddock")
	fence(pad, { Vector3.new(20, GROUND, -300), Vector3.new(92, GROUND, -300), Vector3.new(92, GROUND, -345), Vector3.new(36, GROUND, -345) }, 0.15)
	fence(pad, { Vector3.new(20, GROUND, -345), Vector3.new(20, GROUND, -300) }, 0.7)
	prop(pad, "Trough", at(60, -340, 0), 1.6)
	local heap = ball(pad, "Manure", Vector3.new(7, 2.6, 6), CFrame.new(-6, GROUND + 0.6, -402), "dark", Color3.fromRGB(56, 42, 30))
	heap.Material = Enum.Material.Mud
	clutter(pad, Vector3.new(56, 0, -322), 30, 20, { "straw", "stone", "plank" })
	task.wait()

	-- 7. THE GROOMS' COTTAGES, one by each side wall: the men who slept
	--    nearest the horses.
	for _, c in { { 150, -300, "W" }, { -158, -405, "E" } } do
		house(f, at(c[1], c[2], c[3]), {
			name = "GroomsCottage",
			W = 20,
			D = 12,
			storeys = 2,
			front = { "window", "door", "window", "window" },
			roof = { kind = "thatch", holes = if c[1] < 0 then 0.25 else 0.05 },
			damage = if c[1] < 0 then 0.3 else 0.08,
			glow = c[1] > 0,
			furnish = function(m, B, info)
				local y = info.plinthH + 0.32
				prop(m, "Table", B * CFrame.new(4.5, y, -3.2))
				prop(m, "Barrel", B * CFrame.new(-6.8, y, -3.6)) -- clear of the stair head (back right)
				if info.upperY then
					prop(m, "Bed", B * CFrame.new(3, info.upperY, -3.4), 1.5)
					prop(m, "Sacks", B * CFrame.new(-4, info.upperY, -4))
				end
			end,
		})
		-- the dooryard: firewood against the wall, a bucket of nothing
		local yard = at(c[1], c[2], c[3])
		prop(f, "Firewood", yard * CFrame.new(-6.5, 0, -7.8), 1.3)
		prop(f, "Barrel", yard * CFrame.new(6.2, 0, -7.6))
	end

	-- 8. A dung cart by the heap, and the bones of a horse by the paddock.
	prop(f, "Cart", at(-14, -394, 60), 1.5)
	clutter(f, Vector3.new(30, GROUND, -352), 4, 8, { "bones", "bones", "straw" })
	baleStack(f, at(-52, -404, 10), 2, 1, 2)

	-- 9. Lights.
	roadLanterns(f, road, 38, 9)
	prop(f, "Wheelbarrow", at(4, -402, 40), 1.4)
	wallTorches(f, 2)
	clutter(f, Vector3.new(0, 0, -355), 140, 40, { "stone", "straw", "plank", "stone" })
	clearMarkers(2, f)
end

--------------------------------------------------------------------------
-- AREA 3 — THE KITCHENS. The kitchen hall with its great hearth, the
-- bakehouse and its ovens, a boarded well, a granary on staddle stones, the
-- stores emptied in a hurry, the garden, the smokehouse, the sty.
--------------------------------------------------------------------------
local function area3()
	local f = areaFolder(3)
	local zNear, zFar = Castle.chamberBounds(3)
	local road = { Vector2.new(-153, zNear - 16), Vector2.new(-122, -512), Vector2.new(-70, -538), Vector2.new(-10, -562), Vector2.new(40, -598), Vector2.new(90, -640), Vector2.new(128, -684), Vector2.new(153, zFar + 14) }
	paintGround(zNear - 2, zFar + 2, {
		{ path = road, width = 12, material = Enum.Material.Cobblestone, verge = Enum.Material.Mud },
		{ path = { Vector2.new(-40, -552), Vector2.new(-80, -620) }, width = 7, material = Enum.Material.Mud },
		{ path = { Vector2.new(10, -568), Vector2.new(55, -556) }, width = 6, material = Enum.Material.Mud },
	}, { { Vector2.new(-25, -590), 12 }, { Vector2.new(130, -560), 14 } })
	task.wait()

	-- 1. THE KITCHEN HALL.
	house(f, at(-85, -640, "N"), {
		name = "KitchenHall",
		W = 36,
		D = 18,
		storeys = 2,
		front = { "window", "door", "window", "window", "wall", "door", "window" },
		upperFront = { "window", "wall", "window", "window", "wall", "window", "window" },
		roof = { kind = "thatch", chimneyX = -13 },
		glow = true,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			hearth(m, B * CFrame.new(-13, y, -2.2), 9, true)
			prop(m, "Cauldron", B * CFrame.new(-13, y + 1.2, -2.6), 1.2)
			pole(m, "Spit", (B * CFrame.new(-16.5, y + 3.2, -3.2)).Position, (B * CFrame.new(-9.5, y + 3.2, -3.2)).Position, 0.12, "iron")
			prop(m, "Table", B * CFrame.new(0, y, -3), 1.3)
			prop(m, "Table", B * CFrame.new(10, y, -3) * CFrame.Angles(0, 0.06, 0), 1.3)
			prop(m, "BreadBasket", B * CFrame.new(0, y + 3.3, -2.9))
			prop(m, "Shelf", B * CFrame.new(4, y, 7.9) * CFrame.Angles(0, math.pi, 0), 1.2)
			prop(m, "Shelf", B * CFrame.new(12, y, 7.9) * CFrame.Angles(0, math.pi, 0), 1.2)
			prop(m, "Sacks", B * CFrame.new(15, y, 3))
			prop(m, "Barrel", B * CFrame.new(16, y, -6))
			prop(m, "Barrel", B * CFrame.new(14, y, -6.4))
			hams(m, B * CFrame.new(4, y + 9.4, 2), 4)
			if info.upperY then
				for k = 0, 3 do
					prop(m, "Bed", B * CFrame.new(-6 + k * 5.2, info.upperY, -3), 1.5)
				end
				prop(m, "Chest", B * CFrame.new(12, info.upperY, -4))
			end
		end,
	})
	task.wait()

	-- 2. THE BAKEHOUSE — stone, two great ovens along the back wall.
	house(f, at(55, -548, "S"), {
		name = "Bakehouse",
		W = 24,
		D = 16,
		storeys = 1,
		ground = "stone",
		front = { "window", "door", "window", "window", "window" },
		roof = { kind = "shingles", pitch = 40, chimneyX = 0 },
		glow = true,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			breadOven(m, B * CFrame.new(-6, y, 2.2), true)
			breadOven(m, B * CFrame.new(6, y, 2.2), false)
			prop(m, "Table", B * CFrame.new(5.5, y, -3.9), 1.2)
			prop(m, "BreadBasket", B * CFrame.new(4.2, y + 3.1, -4.1))
			prop(m, "BreadBasket", B * CFrame.new(7, y + 3.1, -4.0))
			prop(m, "Sacks", B * CFrame.new(-9, y, -4))
			prop(m, "Sacks", B * CFrame.new(9, y, -4.2))
			-- the peel, leaning on the wall
			beam(m, "Peel", (B * CFrame.new(-10, y, 0)).Position, (B * CFrame.new(-9.6, y + 7, 1.5)).Position, 0.15, 0.15, "oak")
		end,
	})
	task.wait()

	-- 3. THE WELL, boarded over.
	well(f, at(-25, -590, 20), true)

	-- 4. THE GRANARY, on staddle stones, with steps up to its door.
	local gran = model(f, "Granary")
	local GB = at(112, -600, "W")
	for _, x in { -6, -2, 2, 6 } do
		for _, z in { -4, 0, 4 } do
			staddle(gran, (GB * CFrame.new(x, 0, z)).Position, 3.4)
		end
	end
	house(gran, GB * CFrame.new(0, 3.4, 0), {
		name = "GranaryStore",
		W = 14,
		D = 10,
		storeys = 1,
		plinth = 0.6,
		raised = true,
		front = { "wall", "door", "wall" },
		roof = { kind = "thatch", pitch = 50 },
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			prop(m, "Sacks", B * CFrame.new(-4, y, 2))
			prop(m, "Sacks", B * CFrame.new(4, y, 2.5))
			clutter(m, (B * CFrame.new(0, y, 0)).Position, 4, 6, { "straw", "sacks" }, true)
		end,
	})
	local granRise = 3.4 + 0.6 + 0.3
	local granRun = math.ceil(granRise / 0.95) * 1.15
	stair(gran, (GB * CFrame.new(0, 0.05, -5 - granRun)).Position, GB.LookVector * -1, granRise, 4.0, "planks", 1.15)
	task.wait()

	-- 5. THE STORES, emptied in a hurry: doors open, sacks split, barrels rolled out.
	for _, s in { { -40, -514, "S" }, { -110, -560, "E" } } do
		house(f, at(s[1], s[2], s[3]), {
			name = "Store",
			W = 14,
			D = 10,
			storeys = 1,
			front = { "wall", "door", "window" },
			roof = { kind = "shingles", pitch = 38, holes = 0.2 },
			damage = 0.15,
			furnish = function(m, B, info)
				clutter(m, (B * CFrame.new(0, info.plinthH, 0)).Position, 4, 6, { "sacks", "barrelDown", "crate" }, true)
			end,
		})
		-- what was dragged out lies to either side of the door, never across it
		clutter(f, (at(s[1], s[2], s[3]) * CFrame.new(-6, 0, -8)).Position, 3, 4, { "barrelDown", "sacks", "plank", "straw" })
		clutter(f, (at(s[1], s[2], s[3]) * CFrame.new(6, 0, -8)).Position, 3, 4, { "sacks", "plank", "straw" })
	end
	task.wait()

	-- 6. THE KITCHEN GARDEN — wattle hurdles, raised beds, a scarecrow.
	local garden = model(f, "Garden")
	local g0, g1 = Vector3.new(0, GROUND, -640), Vector3.new(60, GROUND, -690)
	hurdles(garden, Vector3.new(g0.X, GROUND, g0.Z), Vector3.new(g1.X, GROUND, g0.Z), 3)
	hurdles(garden, Vector3.new(g1.X, GROUND, g0.Z), Vector3.new(g1.X, GROUND, g1.Z), 3)
	hurdles(garden, Vector3.new(g0.X, GROUND, g1.Z), Vector3.new(g1.X - 10, GROUND, g1.Z), 3)
	hurdles(garden, Vector3.new(g0.X, GROUND, g0.Z - 8), Vector3.new(g0.X, GROUND, g1.Z), 3)
	for x = 6, 52, 12 do
		for z = -648, -684, -12 do
			bed(garden, at(x, z, 0), 9, 8)
		end
	end
	scarecrow(garden, at(30, -662, 20))
	task.wait()

	-- 7. THE SMOKEHOUSE, still smoking.
	house(f, at(-140, -700, "E"), {
		name = "Smokehouse",
		W = 10,
		D = 9,
		storeys = 1,
		ground = "stone",
		front = { "door", "loop" },
		roof = { kind = "shingles", pitch = 42 },
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			hams(m, B * CFrame.new(0, y + 8.2, 0), 4)
			local embers = part(m, "Embers", Vector3.new(3, 0.3, 3), B * CFrame.new(0, y + 0.15, 1), "ember")
			embers.Transparency = 0.35
			pointLight(embers, Color3.fromRGB(255, 110, 50), 1.5, 12)
			local vent = part(m, "Vent", Vector3.new(0.5, 0.5, 0.5), B * CFrame.new(0, info.plinthH + info.SH + 4, 0), "dark")
			vent.Transparency = 1
			vent.CanCollide = false
			smokeOn(vent, 3)
		end,
	})

	-- 8. THE STY, by the east wall.
	local sty = model(f, "Sty")
	local SB = at(130, -560, "W")
	for _, seg in { { -6, -5, 6, -5 }, { 6, -5, 6, 5 }, { -6, 5, 6, 5 }, { -6, -5, -6, 1 } } do
		local a = (SB * CFrame.new(seg[1], 0, seg[2])).Position
		local b = (SB * CFrame.new(seg[3], 0, seg[4])).Position
		local len = (b - a).Magnitude
		part(sty, "StyWall", Vector3.new(1.4, 3, len + 1.4), CFrame.lookAt((a + b) / 2, b) + Vector3.new(0, 1.5, 0), "rubble")
	end
	leanTo(sty, SB * CFrame.new(0, 0, 3), 12, 5, 6, 4.2, { kind = "thatch" })
	clutter(sty, SB.Position, 4, 6, { "straw", "straw", "stone" })

	-- 9. The woodshed on the west wall, and light.
	local inner = Castle.innerHalfWidth()
	local wood = leanTo(f, at(-inner + 6.5, -552, "E"), 24, 12, 11, 7.5, { kind = "shingles", sides = true })
	wood.Name = "Woodshed"
	for k = 0, 3 do
		prop(wood, "Firewood", at(-inner + 3, -562 + k * 6, 90), 1.4)
	end
	-- 10. THE DAIRY, the COOKS' HOUSE and a stall of what was left to sell.
	house(f, at(-30, -700, "N"), {
		name = "Dairy",
		W = 16,
		D = 12,
		storeys = 1,
		ground = "stone",
		front = { "window", "door", "window" },
		roof = { kind = "thatch", pitch = 48 },
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			prop(m, "Table", B * CFrame.new(-3, y, 2.2), 1.1)
			for k = 0, 2 do
				prop(m, "Barrel", B * CFrame.new(-5 + k * 3, y, -2.4), 0.8)
			end
			prop(m, "Shelf", B * CFrame.new(4, y, 3.4) * CFrame.Angles(0, math.pi, 0))
		end,
	})
	house(f, at(-110, -690, "N"), {
		name = "CooksHouse",
		W = 20,
		D = 12,
		storeys = 2,
		front = { "window", "door", "window", "window" },
		roof = { kind = "shingles", pitch = 44 },
		glow = true,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			prop(m, "Table", B * CFrame.new(4.5, y, -3))
			prop(m, "Sacks", B * CFrame.new(-6.6, y, -3.4)) -- clear of the stair head (back right)
			if info.upperY then
				prop(m, "Bed", B * CFrame.new(3, info.upperY, -3.4), 1.5)
			end
		end,
	})
	local stall = openShed(f, at(25, -622, "N"), 10, 7, 7, { kind = "shingles", pitch = 30, holes = 0.2 })
	stall.Name = "Stall"
	prop(stall, "Table", at(25, -621, "N"), 1.2)
	prop(stall, "BreadBasket", at(23, -621, 10, 2.9))
	prop(stall, "BreadBasket", at(27, -620.5, -20, 2.9))
	prop(stall, "Sacks", at(29.5, -624, 0))
	prop(stall, "Barrel", at(20.5, -624.5, 0))

	brazier(f, at(-6, -575, 0))
	brazier(f, at(70, -620, 0))
	prop(f, "Wheelbarrow", at(66, -652, -30), 1.4)
	prop(f, "Cart", at(-60, -660, 15), 1.5)
	prop(f, "Firewood", at(-74, -626, 0), 1.3)
	prop(f, "Barrel", at(-98, -626, 0))
	roadLanterns(f, road, 38, 9)
	wallTorches(f, 3)
	clutter(f, Vector3.new(0, 0, -605), 140, 40, { "stone", "straw", "plank", "stone" })
	clearMarkers(3, f)
end

--------------------------------------------------------------------------
-- Helpers for the deeper areas
--------------------------------------------------------------------------

-- A ledger of where things already stand, so scattered pieces (graves,
-- trees, heaps) go round them instead of through them.
local function reserver()
	local list = {}
	local r = {}
	function r.add(x: number, z: number, radius: number)
		table.insert(list, { x, z, radius })
	end
	function r.rect(x0: number, z0: number, x1: number, z1: number)
		table.insert(list, { math.min(x0, x1), math.min(z0, z1), math.max(x0, x1), math.max(z0, z1), rect = true })
	end
	function r.free(x: number, z: number, pad: number): boolean
		for _, e in list do
			if e.rect then
				if x > e[1] - pad and x < e[3] + pad and z > e[2] - pad and z < e[4] + pad then
					return false
				end
			elseif (x - e[1]) ^ 2 + (z - e[2]) ^ 2 < (e[3] + pad) ^ 2 then
				return false
			end
		end
		return true
	end
	-- the gameplay marks of a chamber: nothing may land on them
	function r.marks(index: number, radius: number)
		local node = gameplay.Battleground:FindFirstChild(("Chamber%d"):format(index))
		for _, d in node:GetDescendants() do
			if d:IsA("BasePart") and not d:IsDescendantOf(node:FindFirstChild("Structure") or node) then
				r.add(d.Position.X, d.Position.Z, radius)
			end
		end
	end
	return r
end

-- A real hole in the ground, `L` along cf's X, `W` across, with an earth
-- ramp at the +X end so whatever falls in can walk out again.
local function digTrench(cf: CFrame, L: number, W: number, depth: number)
	Terrain:FillBlock(cf * CFrame.new(0, -depth / 2 + 1, 0), Vector3.new(L, depth + 2, W), Enum.Material.Air)
	Terrain:FillWedge(cf * CFrame.new(L / 2 - 6, -depth / 2 - 1, 0) * CFrame.Angles(0, math.pi / 2, 0), Vector3.new(W + 1, depth + 1, 12), Enum.Material.Ground)
end

-- A pyre: logs laid crosswise, the dead on top, burning.
local function pyre(parent: Instance, cf: CFrame)
	local m = model(parent, "Pyre")
	for layer = 0, 3 do
		local turn = if layer % 2 == 0 then 0 else math.pi / 2
		for k = -3, 3 do
			local a = (cf * CFrame.Angles(0, turn, 0) * CFrame.new(k * 1.1, 0.4 + layer * 0.8, -4)).Position
			local b = (cf * CFrame.Angles(0, turn, 0) * CFrame.new(k * 1.1 + jit(0.2), 0.4 + layer * 0.8, 4)).Position
			pole(m, "Log", a, b, 0.42, if layer < 2 then "charred" else "oakDark")
		end
	end
	for k = -1, 1 do
		local s = shroud(m, cf * CFrame.new(k * 2, 3.6, jit(0.6)) * CFrame.Angles(0, math.pi / 2 + jit(0.2), 0))
		for _, d in s:GetDescendants() do
			if d:IsA("BasePart") then
				d.Color = shade(d.Color, 0.45)
			end
		end
	end
	local ash = part(m, "Ash", Vector3.new(11, 0.2, 11), cf * CFrame.new(0, 0.1, 0), "soot")
	ash.CanCollide = false
	local fire = fireAt(m, (cf * CFrame.new(0, 3, 0)).Position, 2.6, 60)
	smokeOn(fire, 6, true)
	fireAt(m, (cf * CFrame.new(2.5, 2, 1.5)).Position, 1.4, 20)
	return m
end

-- A sawhorse with a plank half sawn on it.
local function sawhorse(parent: Instance, cf: CFrame)
	local m = model(parent, "Sawhorse")
	beam(m, "Bar", (cf * CFrame.new(-2, 2.6, 0)).Position, (cf * CFrame.new(2, 2.6, 0)).Position, 0.5, 0.5, "oakDark")
	for _, x in { -1.6, 1.6 } do
		for _, s in { -1, 1 } do
			beam(m, "Leg", (cf * CFrame.new(x, 2.5, 0)).Position, (cf * CFrame.new(x, 0, s * 1.1)).Position, 0.3, 0.3, "oakDark")
		end
	end
	part(m, "Plank", Vector3.new(7, 0.25, 1.1), cf * CFrame.new(0.8, 2.98, 0) * CFrame.Angles(0, 0.08, 0), "planks")
	return m
end

--------------------------------------------------------------------------
-- AREA 4 — THE GRAVEYARD. The chapel in its churchyard, old stones gone
-- green; and east of the wall, the new field: graves dug badly, too many,
-- too close, a pit for the ones there was no time for, and a pyre for the
-- ones after that. Some of the graves are open. Four braziers stand laid and
-- unlit, one to a section of the ground: lighting them is the work here.
--------------------------------------------------------------------------
local function area4()
	local f = areaFolder(4)
	local zNear, zFar = Castle.chamberBounds(4)
	local road = { Vector2.new(153, zNear - 16), Vector2.new(138, -772), Vector2.new(100, -796), Vector2.new(50, -812), Vector2.new(0, -824), Vector2.new(-30, -832) }
	local yardPath = { Vector2.new(-30, -832), Vector2.new(-40, -848), Vector2.new(-100, -854), Vector2.new(-128, -856) }
	local outRoad = { Vector2.new(-128, -856), Vector2.new(-142, -868), Vector2.new(-147, -900), Vector2.new(-153, -930), Vector2.new(-153, zFar + 14) }
	local CY = { x0 = -126, x1 = -12, zN = -834, zS = -926 } -- the churchyard wall
	local TRENCH = CFrame.new(72, GROUND, -906)

	digTrench(TRENCH, 30, 8, 8)
	paintGround(zNear - 2, zFar + 2, {
		{ path = road, width = 12, material = Enum.Material.Cobblestone, verge = Enum.Material.Mud },
		{ path = yardPath, width = 7, material = Enum.Material.Mud },
		{ path = outRoad, width = 12, material = Enum.Material.Cobblestone, verge = Enum.Material.Mud },
	}, { { Vector2.new(72, -906), 20 }, { Vector2.new(60, -868), 14 }, { Vector2.new(126, -930), 12 }, { Vector2.new(-55, -812), 12 } }, {
		{ x0 = CY.x0, x1 = CY.x1, z0 = CY.zS, z1 = CY.zN, material = Enum.Material.LeafyGrass, alt = Enum.Material.Grass },
		{ x0 = 0, x1 = 150, z0 = -952, z1 = -830, material = Enum.Material.Mud, alt = Enum.Material.Grass },
	})
	task.wait()

	local res = reserver()
	res.marks(4, 10)

	-- 1. THE CHAPEL, and the churchyard round it.
	local CB = at(-72, -882, 0)
	chapel(f, CB)
	res.rect(-95, -897, -36, -862)
	local yard = model(f, "Churchyard")
	local function g3(x: number, z: number): Vector3
		return Vector3.new(x, GROUND, z)
	end
	graveWall(yard, g3(CY.x0, CY.zN), g3(-34.6, CY.zN), { { 30, 37 } })
	graveWall(yard, g3(-25.4, CY.zN), g3(CY.x1, CY.zN))
	lychgate(yard, at(-30, CY.zN, 0))
	res.add(-30, CY.zN, 7)
	graveWall(yard, g3(CY.x0, CY.zN), g3(CY.x0, -850))
	graveWall(yard, g3(CY.x0, -862), g3(CY.x0, CY.zS), { { 30, 36 } })
	graveWall(yard, g3(CY.x0, CY.zS), g3(CY.x1, CY.zS), { { 66, 74 }, { 100, 106 } })
	graveWall(yard, g3(CY.x1, CY.zS), g3(CY.x1, CY.zN), { { 18, 26 }, { 52, 64 } })
	churchCross(yard, at(-27, -870, 15))
	res.add(-27, -870, 6)
	mausoleum(yard, at(-112, -912, "N"))
	res.rect(-119, -920, -105, -902)
	for _, t in { { -56, -904, true }, { -44, -903, false }, { -104, -892, false } } do
		tableTomb(yard, at(t[1], t[2], -90 + jit(4)), t[3])
		res.add(t[1], t[2], 5)
	end
	for _, p in { { -118, -842, 30 }, { -18, -918, 26 }, { -96, -918, 22 } } do
		deadTree(yard, at(p[1], p[2], 0), p[3])
		res.add(p[1], p[2], 3)
	end
	task.wait()

	-- the braziers, one to a section, laid and unlit
	local braziers = model(f, "GraveBraziers")
	for i, b in { { -106, -868 }, { -24, -912 }, { 58, -868 }, { 100, -930 } } do
		sectionBrazier(braziers, at(b[1], b[2], 0), i)
		res.add(b[1], b[2], 4.5)
	end

	-- the old graves: rows, mostly, though the rows have wandered
	local old = model(yard, "OldGraves")
	for x = CY.x0 + 6, CY.x1 - 5, 7.5 do
		for z = CY.zN - 6, CY.zS + 4, -5 do
			local gx, gz = x + jit(1), z + jit(0.6)
			if res.free(gx, gz, 3.6) and pathDist(gx, gz, yardPath) > 7.5 and chance(0.82) then
				local r = rng:NextNumber()
				grave(old, at(gx, gz, -90 + jit(6)), if r < 0.1 then "open" elseif r < 0.25 then "kerb" else "old")
			end
		end
	end
	task.wait()

	-- 2. THE NEW FIELD, east of the wall.
	res.rect(54, -914, 90, -898) -- the pit and its banks
	res.add(126, -930, 9) -- the pyre
	res.add(36, -900, 6) -- the cart
	res.add(140, -884, 4)
	local field = model(f, "NewGraves")
	for x = 8, 146, 7.5 do
		for z = -836, -946, -5 do
			local gx, gz = x + jit(1.6), z + jit(1)
			if res.free(gx, gz, 3.4) and pathDist(gx, gz, road) > 9 and chance(0.5) then
				local r = rng:NextNumber()
				local state = if r < 0.17 then "open" elseif r < 0.23 then "dug" else "new"
				grave(field, at(gx, gz, -90 + jit(24)), state)
			end
		end
	end
	deadTree(field, at(140, -884, 0), 28)
	task.wait()

	-- the pit: the dead in rows at the bottom, lime over them, spoil banked
	-- either side, and the ramp they were carried down
	local pit = model(f, "MassGrave")
	for k = -5, 4 do
		local x = 72 + k * 2.4
		local y = surfaceAt(x, -906, GROUND + 2)
		shroud(pit, CFrame.new(x, y, -906 + jit(0.4)) * CFrame.Angles(0, math.pi / 2 + jit(0.15), 0))
		if chance(0.6) then
			local lime = part(pit, "Lime", Vector3.new(rand(1.5, 2.6), 0.08, rand(2, 4)), CFrame.new(x + jit(0.6), y + 1.25, -906 + jit(1)) * CFrame.Angles(0, rand(0, 6), 0), "linen", Color3.fromRGB(214, 212, 204))
			lime.CanCollide = false
			lime.CastShadow = false
		end
	end
	for _, s in { -1, 1 } do
		for k = -2, 2 do
			earthHeap(pit, CFrame.new(72 + k * 6.5 + jit(1), GROUND, -906 + s * 7.5), 7, 4.5, rand(1.4, 2.2))
		end
	end
	spade(pit, Vector3.new(52, GROUND + 1, -900))
	spade(pit, Vector3.new(91, GROUND + 1, -913))
	for _, x in { 58, 66, 80 } do
		part(pit, "Plank", Vector3.new(1, 0.25, 11), CFrame.new(x, GROUND + 0.25, -906) * CFrame.Angles(0, jit(0.1), 0), "planks")
	end

	-- the cart that brought them, and the pyre for when the pit was full
	local cart = prop(f, "Cart", at(36, -900, 70), 1.6)
	if cart then
		for k = 0, 1 do
			shroud(f, at(36 + k * 1.4, -900, 160, 3.1))
		end
	end
	pyre(f, at(126, -930, 20))
	task.wait()

	-- 3. THE SEXTON'S HOUSE by the road, and his yard: coffins he made
	--    until there was no time to make them.
	house(f, at(-70, -805, "S"), {
		name = "SextonsHouse",
		W = 20,
		D = 12,
		storeys = 2,
		front = { "window", "door", "window", "window" },
		roof = { kind = "thatch", holes = 0.08 }, -- no stack: it would stand in the stair head
		damage = 0.1,
		glow = true,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			-- the door is mid-front and the stair foot back-left, reached past
			-- the left end wall: the whole left half is kept clear
			prop(m, "Table", B * CFrame.new(4.5, y, -3))
			prop(m, "Shelf", B * CFrame.new(8.2, y, -2) * CFrame.Angles(0, -math.pi / 2, 0))
			for k = 0, 1 do
				spade(m, (B * CFrame.new(7.6 - k * 0.8, y + 1, -5.2)).Position, CFrame.Angles(math.rad(-12), 0, math.rad(8)))
			end
			if info.upperY then
				prop(m, "Bed", B * CFrame.new(3, info.upperY, -3.4), 1.5)
				prop(m, "Chest", B * CFrame.new(-4, info.upperY, -4))
			end
		end,
	})
	local works = model(f, "CoffinYard")
	sawhorse(works, at(-50, -812, 10))
	for k = 0, 2 do
		coffin(works, at(-58 + k * 0.2, -818, 90 + jit(3), k * 1.6), "closed")
	end
	coffin(works, at(-44, -820, 80), "open")
	for _, p in { { -84, -814 }, { -86, -816 } } do
		spade(works, Vector3.new(p[1], GROUND + 1.2, p[2]), CFrame.Angles(math.rad(-14), 0, math.rad(4)))
	end
	clutter(works, Vector3.new(-50, 0, -814), 7, 10, { "plank", "plank", "stone" })

	-- 4. THE CHARNEL HOUSE: where the bones go when the ground is wanted again.
	house(f, at(-112, -810, "E"), {
		name = "CharnelHouse",
		W = 12,
		D = 9,
		storeys = 1,
		ground = "stone",
		front = { "door", "window" },
		roof = { kind = "shingles", pitch = 44 },
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			-- shelves of skulls and long bones, stacked the old way
			for k = 0, 2 do
				local sy = y + 0.6 + k * 1.6
				part(m, "Shelf", Vector3.new(7, 0.25, 1.4), B * CFrame.new(0, sy, 1.5), "planks")
				for j = 0, 6 do
					local skull = ball(m, "Bone", Vector3.new(0.75, 0.7, 0.85), B * CFrame.new(-3 + j * 1.0 + jit(0.1), sy + 0.5, 1.4), "linen")
					skull.Color = shade(BONE, rand(0.75, 1))
					skull.CanCollide = false
				end
			end
			clutter(m, (B * CFrame.new(0, info.plinthH, -1)).Position, 2.5, 4, { "bones" }, true)
		end,
	})

	-- 5. THE BELFRY: a timber bell tower standing free by the road, the
	--    bell under its little roof. Climbable, so the dead climb it too.
	local belfry = watchPlatform(f, at(40, -790, "N"), 13, 9, 1)
	belfry.Name = "Belfry"
	local b = bell(belfry, at(40, -790, 0, 13 + 8.2), 1.25)
	for _, d in b:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	beam(belfry, "BellRope", Vector3.new(40.6, GROUND + 13 + 5.4, -790), Vector3.new(41, GROUND + 13 + 1.2, -789.4), 0.14, 0.14, "burlap")

	-- 6. Light, and the litter of a place that was overwhelmed.
	roadLanterns(f, road, 38, 9)
	roadLanterns(f, outRoad, 34, 9)
	-- a lantern outside the lychgate, its arm over the way in
	lanternPost(f, CFrame.lookAt(Vector3.new(-39, GROUND, -829), Vector3.new(-30, GROUND, -829)))
	clutter(f, Vector3.new(70, 0, -880), 70, 30, { "stone", "bones", "plank", "stone" })
	clutter(f, Vector3.new(-70, 0, -880), 60, 20, { "stone", "stone", "straw" })
	wallTorches(f, 4)
	clearMarkers(4, f)
end

--------------------------------------------------------------------------
-- Pieces for the smithy
--------------------------------------------------------------------------
local CLAY = Color3.fromRGB(108, 80, 64) -- fired and sooted; brighter reads as pumpkins under the torches
local GOLD = Color3.fromRGB(212, 172, 64)

-- A smith's hearth: waist high, a bed of coals on top, the hood above it
-- carrying the smoke into the stack behind. Front at -Z.
local function forgeHearth(parent: Instance, cf: CFrame, lit: boolean): Model
	local m = model(parent, "ForgeHearth")
	part(m, "HearthBlock", Vector3.new(5.4, 2.8, 4.2), cf * CFrame.new(0, 1.4, 0), "rubble")
	part(m, "Kerb", Vector3.new(5.8, 0.4, 4.6), cf * CFrame.new(0, 2.95, 0), "stone")
	part(m, "Fireback", Vector3.new(4.4, 3.2, 0.35), cf * CFrame.new(0, 4.7, 1.8), "ironDark")
	-- the hood, plaster on oak, black with years of smoke
	local sooty = shade(MAT.daub[3], 0.4)
	part(m, "Hood", Vector3.new(5.6, 0.5, 3.4), cf * CFrame.new(0, 8.1, -0.4) * CFrame.Angles(math.rad(28), 0, 0), "daub", sooty)
	part(m, "HoodBack", Vector3.new(5.6, 5, 0.5), cf * CFrame.new(0, 9.5, 1.4), "daub", sooty)
	beam(m, "HoodBeam", (cf * CFrame.new(-3, 7.2, -1.9)).Position, (cf * CFrame.new(3, 7.2, -1.9)).Position, 0.5, 0.6, "oakDark")
	local bed = ball(m, "Coals", Vector3.new(3.4, 0.9, 2.8), cf * CFrame.new(0, 3.15, -0.2), "ember")
	if lit then
		bed.Color = Color3.fromRGB(170, 52, 16)
		fireAt(m, (cf * CFrame.new(0, 3.8, -0.2)).Position, 0.9, 30)
	else
		bed.Material = Enum.Material.Slate
		bed.Color = Color3.fromRGB(40, 34, 32)
	end
	for _ = 1, 7 do
		local c = part(m, "Coal", Vector3.new(rand(0.4, 0.8), rand(0.3, 0.5), rand(0.4, 0.8)), cf * CFrame.new(jit(1.4), 3.45, -0.2 + jit(1)) * CFrame.Angles(jit(1), jit(1), jit(1)), "soot")
		c.CastShadow = false
	end
	-- the tuyere through the side, where the bellows blow in
	pole(m, "Tuyere", (cf * CFrame.new(3.4, 3.1, -0.2)).Position, (cf * CFrame.new(2.2, 3.1, -0.2)).Position, 0.28, "ironDark")
	-- a blade left in the fire: the work that stopped
	local blade = part(m, "Blade", Vector3.new(0.45, 0.1, 3.8), cf * CFrame.new(-0.4, 3.62, -1.4) * CFrame.Angles(math.rad(8), 0.3, 0), "ironDark")
	if lit then
		local tip = part(m, "HotTip", Vector3.new(0.47, 0.12, 1.4), blade.CFrame * CFrame.new(0, 0, 1.2), "ember", Color3.fromRGB(255, 120, 40))
		tip.CastShadow = false
	end
	return m
end

local function grindstone(parent: Instance, cf: CFrame)
	local m = model(parent, "Grindstone")
	for _, s in { -1, 1 } do
		for _, z in { -1.4, 1.4 } do
			beam(m, "Leg", (cf * CFrame.new(s * 1.0, 0, z)).Position, (cf * CFrame.new(s * 0.9, 2.9, 0)).Position, 0.35, 0.35, "oakDark")
		end
	end
	local wheel = part(m, "Wheel", Vector3.new(0.7, 3.4, 3.4), cf * CFrame.new(0, 3.3, 0), "stone", Color3.fromRGB(150, 140, 120))
	;(wheel :: Part).Shape = Enum.PartType.Cylinder
	pole(m, "Axle", (cf * CFrame.new(-1.4, 3.3, 0)).Position, (cf * CFrame.new(1.8, 3.3, 0)).Position, 0.15, "iron")
	beam(m, "Crank", (cf * CFrame.new(1.8, 3.3, 0)).Position, (cf * CFrame.new(1.8, 2.4, 0.6)).Position, 0.18, 0.18, "iron")
	part(m, "Trough", Vector3.new(1.3, 0.8, 2.8), cf * CFrame.new(0, 1.6, 0), "planks")
	local water = part(m, "Water", Vector3.new(1.1, 0.1, 2.6), cf * CFrame.new(0, 1.95, 0), "water")
	water.CastShadow = false
	return m
end

-- A heavy bench with the work still on it: blades forged and not yet
-- hilted, an axe head, the hammer and the tongs where they were put down.
local function weaponBench(parent: Instance, cf: CFrame)
	local m = model(parent, "WeaponBench")
	part(m, "Top", Vector3.new(8, 0.45, 2.6), cf * CFrame.new(0, 3, 0), "planks")
	for _, x in { -3.4, 3.4 } do
		for _, z in { -0.9, 0.9 } do
			beam(m, "Leg", (cf * CFrame.new(x, 0, z)).Position, (cf * CFrame.new(x, 2.8, z)).Position, 0.45, 0.45, "oakDark")
		end
		beam(m, "Stretcher", (cf * CFrame.new(x, 0.8, -0.9)).Position, (cf * CFrame.new(x, 0.8, 0.9)).Position, 0.3, 0.3, "oakDark")
	end
	for k = 0, 3 do
		local blade = part(m, "Blade", Vector3.new(0.45, 0.1, 3.6 + jit(0.4)), cf * CFrame.new(-3 + k * 1.15, 3.28, jit(0.2)) * CFrame.Angles(0, jit(0.08), 0), "ironDark", Color3.fromRGB(78, 76, 74))
		blade.Material = Enum.Material.Metal
		blade.CastShadow = false
		part(m, "Tang", Vector3.new(0.18, 0.1, 1.1), blade.CFrame * CFrame.new(0, 0, blade.Size.Z / 2 + 0.5), "ironDark").CastShadow = false
	end
	part(m, "AxeHead", Vector3.new(1.4, 0.3, 0.9), cf * CFrame.new(2.4, 3.38, -0.6) * CFrame.Angles(0, 0.4, 0), "ironDark")
	part(m, "Spearhead", Vector3.new(0.3, 0.15, 1.6), cf * CFrame.new(3.3, 3.3, 0.5) * CFrame.Angles(0, -0.3, 0), "ironDark")
	-- the hammer, the tongs
	pole(m, "Handle", (cf * CFrame.new(1.4, 3.35, 0.7)).Position, (cf * CFrame.new(2.9, 3.35, 0.2)).Position, 0.1, "oak")
	part(m, "HammerHead", Vector3.new(0.5, 0.45, 1.1), cf * CFrame.new(1.4, 3.45, 0.7) * CFrame.Angles(0, -0.32, 0), "ironDark")
	for _, s in { -1, 1 } do
		beam(m, "Tong", (cf * CFrame.new(-1.6, 3.3, -0.8)).Position, (cf * CFrame.new(0.4, 3.3, -0.8 + s * 0.25)).Position, 0.12, 0.08, "ironDark")
	end
	return m
end

-- A mail shirt on a stand, a helmet on top.
local function armourStand(parent: Instance, cf: CFrame)
	local m = model(parent, "ArmourStand")
	part(m, "Base", Vector3.new(1.8, 0.3, 1.8), cf * CFrame.new(0, 0.15, 0), "oakDark")
	pole(m, "Post", (cf * CFrame.new(0, 0.3, 0)).Position, (cf * CFrame.new(0, 5.6, 0)).Position, 0.15, "oakDark")
	beam(m, "Shoulders", (cf * CFrame.new(-1.3, 5.1, 0)).Position, (cf * CFrame.new(1.3, 5.1, 0)).Position, 0.3, 0.3, "oakDark")
	local mail = Color3.fromRGB(86, 84, 80)
	part(m, "Mail", Vector3.new(2.3, 2.5, 1.2), cf * CFrame.new(0, 3.9, 0), "iron", mail)
	part(m, "Mail", Vector3.new(2.5, 1.4, 1.4), cf * CFrame.new(0, 2.2, 0), "iron", shade(mail, 0.9))
	for _, s in { -1, 1 } do
		part(m, "Sleeve", Vector3.new(0.9, 1.7, 0.9), cf * CFrame.new(s * 1.55, 4.3, 0) * CFrame.Angles(0, 0, s * 0.18), "iron", mail)
	end
	part(m, "Belt", Vector3.new(2.4, 0.3, 1.3), cf * CFrame.new(0, 2.9, 0), "planks", Color3.fromRGB(70, 46, 30)).Material = Enum.Material.Leather
	helmet(m, cf * CFrame.new(0, 5.55, 0))
	return m
end

-- Swords stood in a rack, points down.
local function swordRack(parent: Instance, cf: CFrame, n: number)
	local m = model(parent, "SwordRack")
	part(m, "Foot", Vector3.new(5.2, 0.5, 1.2), cf * CFrame.new(0, 0.25, 0), "oakDark")
	for _, s in { -1, 1 } do
		beam(m, "Upright", (cf * CFrame.new(s * 2.5, 0, 0)).Position, (cf * CFrame.new(s * 2.5, 4.4, 0)).Position, 0.4, 0.4, "oakDark")
	end
	beam(m, "Bar", (cf * CFrame.new(-2.7, 3.6, 0)).Position, (cf * CFrame.new(2.7, 3.6, 0)).Position, 0.4, 0.5, "oak")
	for i = 1, n do
		if chance(0.25) then
			continue -- taken
		end
		local x = -2 + 4 * (i - 0.5) / n
		local s = cf * CFrame.new(x, 0.5, 0) * CFrame.Angles(0, 0, jit(0.05))
		part(m, "Blade", Vector3.new(0.4, 3.6, 0.1), s * CFrame.new(0, 1.8, 0), "ironDark", Color3.fromRGB(96, 94, 90)).Material = Enum.Material.Metal
		part(m, "Guard", Vector3.new(1.3, 0.2, 0.25), s * CFrame.new(0, 3.7, 0), "ironDark")
		part(m, "Grip", Vector3.new(0.25, 1.1, 0.25), s * CFrame.new(0, 4.35, 0), "planks", Color3.fromRGB(60, 40, 28))
		ball(m, "Pommel", Vector3.new(0.4, 0.4, 0.4), s * CFrame.new(0, 5, 0), "ironDark")
	end
	return m
end

-- Torches in a rack, NOT lit: one of them is the way through the door (the
-- smithy's work, AreaPlan area 5). Named so the mechanic can find them.
local function torchRack(parent: Instance, cf: CFrame, n: number)
	local m = model(parent, "TorchRack")
	for _, s in { -1, 1 } do
		beam(m, "Post", (cf * CFrame.new(s * 2, 0, 0)).Position, (cf * CFrame.new(s * 2, 5.2, 0)).Position, 0.45, 0.45, "oakDark")
	end
	part(m, "Board", Vector3.new(4.6, 1.2, 0.3), cf * CFrame.new(0, 4.4, 0), "planks")
	for i = 1, n do
		local x = -1.6 + 3.2 * (i - 1) / math.max(1, n - 1)
		part(m, "Bracket", Vector3.new(0.5, 0.2, 0.7), cf * CFrame.new(x, 3.6, -0.4), "ironDark")
		local t = model(m, "UnlitTorch")
		pole(t, "Brand", (cf * CFrame.new(x, 2.2, -0.6)).Position, (cf * CFrame.new(x, 4.6, -0.6)).Position, 0.18, "oakDark")
		local rag = part(t, "Rag", Vector3.new(0.9, 0.5, 0.5), cf * CFrame.new(x, 4.75, -0.6) * CFrame.Angles(0, 0, math.rad(90)), "burlap", Color3.fromRGB(46, 40, 34))
		;(rag :: Part).Shape = Enum.PartType.Cylinder
	end
	return m
end

-- A clay jar of lamp oil, as tall as a child.
local function oilJar(parent: Instance, cf: CFrame, s: number)
	local m = model(parent, "OilJar")
	local clay = shade(CLAY, rand(0.78, 1.05))
	part(m, "Foot", Vector3.new(1.2 * s, 0.4 * s, 1.2 * s), cf * CFrame.new(0, 0.2 * s, 0), "stone", clay)
	ball(m, "Body", Vector3.new(2.2, 2.8, 2.2) * s, cf * CFrame.new(0, 1.55 * s, 0), "stone").Color = clay
	local neck = part(m, "Neck", Vector3.new(0.9 * s, 0.95 * s, 0.95 * s), cf * CFrame.new(0, 3.05 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), "stone", clay)
	;(neck :: Part).Shape = Enum.PartType.Cylinder
	local lip = part(m, "Lip", Vector3.new(0.2 * s, 1.2 * s, 1.2 * s), cf * CFrame.new(0, 3.5 * s, 0) * CFrame.Angles(0, 0, math.rad(90)), "stone", shade(clay, 0.9))
	;(lip :: Part).Shape = Enum.PartType.Cylinder
	part(m, "Stopper", Vector3.new(0.6 * s, 0.3 * s, 0.6 * s), cf * CFrame.new(0, 3.65 * s, 0), "burlap", Color3.fromRGB(90, 72, 52)).CastShadow = false
	-- the oil that ran down it
	local stain = part(m, "Stain", Vector3.new(0.12, 1.6 * s, 0.6 * s), cf * CFrame.new(0.95 * s, 1.6 * s, 0) * CFrame.Angles(0, 0, 0.25), "dark", Color3.fromRGB(40, 30, 20))
	stain.Transparency = 0.4
	stain.CastShadow = false
	stain.CanCollide = false
	return m
end

-- A felled trunk's stump; `axe`: the axe left in it.
local function stump(parent: Instance, cf: CFrame, r: number, axe: boolean?)
	local m = model(parent, "Stump")
	local s = part(m, "Stump", Vector3.new(1.4, r * 2, r * 2), cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(0, 0, math.rad(90)), "oakDark", Color3.fromRGB(80, 70, 62))
	;(s :: Part).Shape = Enum.PartType.Cylinder
	local face = part(m, "Cut", Vector3.new(0.1, r * 2 - 0.3, r * 2 - 0.3), cf * CFrame.new(0, 1.32, 0) * CFrame.Angles(0, 0, math.rad(90)), "planks", Color3.fromRGB(176, 150, 112))
	;(face :: Part).Shape = Enum.PartType.Cylinder
	face.CastShadow = false
	for k = 1, 5 do
		local chip = part(m, "Chip", Vector3.new(rand(0.3, 0.6), 0.1, rand(0.5, 1)), cf * CFrame.new(math.cos(k) * (r + rand(0.5, 2)), 0.05, math.sin(k) * (r + rand(0.5, 2))) * CFrame.Angles(0, rand(0, 6), 0), "planks", Color3.fromRGB(176, 150, 112))
		chip.CastShadow = false
		chip.CanCollide = false
	end
	if axe then
		local a = model(m, "Axe")
		a:SetAttribute("Axe", true)
		local h = cf * CFrame.new(0.2, 1.3, 0) * CFrame.Angles(math.rad(-30), 0.4, 0)
		pole(a, "Haft", (h * CFrame.new(0, 0, 0)).Position, (h * CFrame.new(0, 3.4, 0)).Position, 0.13, "oak")
		part(a, "Head", Vector3.new(0.25, 0.9, 1.5), h * CFrame.new(0, 0.1, -0.5), "ironDark")
	end
	return m
end

-- A two-wheeled cart's worth of ore in a mine tub, on the rails.
local function mineCart(parent: Instance, cf: CFrame)
	local m = model(parent, "MineCart")
	part(m, "Floor", Vector3.new(3, 0.25, 4.4), cf * CFrame.new(0, 1.35, 0), "planks")
	for _, s in { -1, 1 } do
		part(m, "Side", Vector3.new(0.25, 2, 4.8), cf * CFrame.new(s * 1.62, 2.35, 0) * CFrame.Angles(0, 0, s * math.rad(-9)), "planks")
		part(m, "End", Vector3.new(3.5, 2, 0.25), cf * CFrame.new(0, 2.35, s * 2.32), "planks")
		for _, y in { 1.6, 3.1 } do
			part(m, "Band", Vector3.new(3.7, 0.2, 0.3), cf * CFrame.new(0, y, s * 2.42), "ironDark").CastShadow = false
		end
	end
	for _, z in { -1.5, 1.5 } do
		pole(m, "Axle", (cf * CFrame.new(-1.6, 0.75, z)).Position, (cf * CFrame.new(1.6, 0.75, z)).Position, 0.14, "ironDark")
		for _, s in { -1, 1 } do
			local w = part(m, "Wheel", Vector3.new(0.3, 1.5, 1.5), cf * CFrame.new(s * 1.35, 0.75, z), "ironDark")
			;(w :: Part).Shape = Enum.PartType.Cylinder
		end
	end
	for _ = 1, 7 do
		local ore = ball(m, "Ore", Vector3.new(rand(0.7, 1.3), rand(0.6, 1), rand(0.7, 1.3)), cf * CFrame.new(jit(1), 3.1, jit(1.6)), "rubble")
		ore.Color = Color3.fromRGB(110, 76, 58)
		ore.CastShadow = false
	end
	return m
end

-- Rails on sleepers along a line of points; `broken`: share of lengths gone
-- or prised up. Underfoot, so nothing in them collides.
local function rails(parent: Instance, pts: { Vector3 }, broken: number?)
	local m = model(parent, "Rails")
	for i = 1, #pts - 1 do
		local a, b = pts[i], pts[i + 1]
		local len = (b - a).Magnitude
		local base = CFrame.lookAt(a, b)
		for d = 0.8, len, 2 do
			part(m, "Sleeper", Vector3.new(4, 0.35, 0.9), base * CFrame.new(jit(0.15), 0.12, -d) * CFrame.Angles(0, jit(0.08), 0), "oakDark").CastShadow = false
		end
		local n = math.max(1, math.floor(len / 6))
		for k = 0, n - 1 do
			local l0, l1 = len * k / n, len * (k + 1) / n
			for _, s in { -1, 1 } do
				if not chance(broken or 0) then
					part(m, "Rail", Vector3.new(0.25, 0.35, l1 - l0 - 0.1), base * CFrame.new(s * 1.35, 0.45, -(l0 + l1) / 2), "iron").CastShadow = false
				elseif chance(0.5) then
					part(m, "Rail", Vector3.new(0.25, 0.35, l1 - l0), base * CFrame.new(s * 2.8, 0.35, -(l0 + l1) / 2) * CFrame.Angles(0, s * 0.3, 0.6), "iron").CastShadow = false
				end
			end
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	return m
end

-- Timber sets holding up a tunnel: `cf` at the mouth on the floor, -Z out
-- of the hill. One set every five studs going in.
local function minePortal(parent: Instance, cf: CFrame, depth: number)
	local m = model(parent, "MinePortal")
	for k = 0, math.floor(depth / 5) do
		local set = cf * CFrame.new(0, 0, k * 5)
		for _, s in { -1, 1 } do
			beam(m, "Prop", (set * CFrame.new(s * 4.0, 0, 0)).Position, (set * CFrame.new(s * 3.5, 9.2, 0)).Position, 0.9, 0.9, if k == 0 then "oakDark" else "oak")
		end
		beam(m, "Cap", (set * CFrame.new(-4.4, 9.6, 0)).Position, (set * CFrame.new(4.4, 9.6, 0)).Position, 1.0, 1.0, "oakDark")
		if k > 0 then
			for x = -3.6, 3.6, 0.9 do
				part(m, "Lagging", Vector3.new(0.8, 0.2, 5), set * CFrame.new(x, 10.2, -2.5), "planks").CastShadow = false
			end
		end
	end
	local lamp = part(m, "Lamp", Vector3.new(0.5, 0.7, 0.5), cf * CFrame.new(2.8, 8.4, -0.6), "ember", Color3.fromRGB(255, 170, 90))
	lamp.CanCollide = false
	pointLight(lamp, Color3.fromRGB(255, 160, 80), 1.6, 22)
	return m
end

-- The bloomery: a shaft of clay where ore and charcoal became iron. A glow
-- at the tapping arch, smoke from the top, slag by its foot.
local function bloomery(parent: Instance, cf: CFrame, lit: boolean)
	local m = model(parent, "Bloomery")
	for k, d in { { 6.2, 2.4 }, { 5.2, 2.4 }, { 4.2, 2.4 }, { 3.4, 1.4 } } do
		local y = ({ 1.2, 3.6, 6.0, 7.9 })[k]
		local c = part(m, "Shaft", Vector3.new(d[2], d[1], d[1]), cf * CFrame.new(0, y, 0) * CFrame.Angles(0, 0, math.rad(90)), "stone", shade(CLAY, rand(0.7, 0.85)))
		;(c :: Part).Shape = Enum.PartType.Cylinder
	end
	local mouth = part(m, "Tap", Vector3.new(1.8, 1.6, 0.4), cf * CFrame.new(0, 1.0, -3.05), if lit then "ember" else "dark")
	local top = part(m, "Top", Vector3.new(0.2, 2.4, 2.4), cf * CFrame.new(0, 8.6, 0) * CFrame.Angles(0, 0, math.rad(90)), if lit then "ember" else "dark")
	;(top :: Part).Shape = Enum.PartType.Cylinder
	if lit then
		mouth.Color = Color3.fromRGB(255, 110, 30)
		pointLight(mouth, Color3.fromRGB(255, 120, 50), 2, 20)
		smokeOn(top, 4)
	end
	-- the slag, run out and left to set
	for _ = 1, 6 do
		local sl = ball(m, "Slag", Vector3.new(rand(0.8, 1.8), rand(0.4, 0.8), rand(0.8, 1.8)), cf * CFrame.new(jit(2.5), 0.2, -rand(4, 7)), "soot")
		sl.Reflectance = 0.12
		sl.CastShadow = false
	end
	bellows(m, cf * CFrame.new(3.8, 0, 1.2) * CFrame.Angles(0, math.rad(60), 0))
	return m
end

-- A charcoal clamp: wood stacked and smothered in earth, smoking for days.
local function charcoalClamp(parent: Instance, cf: CFrame)
	local m = model(parent, "CharcoalClamp")
	local dome = ball(m, "Clamp", Vector3.new(11, 6, 11), cf, "dark")
	dome.Material = Enum.Material.Ground
	dome.MaterialVariant = ""
	dome.Color = Color3.fromRGB(46, 40, 36)
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2 + jit(0.3)
		local vent = part(m, "Vent", Vector3.new(0.6, 0.4, 0.6), cf * CFrame.new(math.cos(a) * 3.4, 2.4, math.sin(a) * 3.4), "ember", Color3.fromRGB(150, 50, 16))
		vent.CanCollide = false
		vent.CastShadow = false
		smokeOn(vent, 1.6, k % 2 == 0)
	end
	-- turf patches, and the rake leaning on it
	for _ = 1, 5 do
		local t = part(m, "Turf", Vector3.new(rand(1.5, 2.5), 0.3, rand(1.5, 2.5)), cf * CFrame.new(jit(3), 2.6, jit(3)) * CFrame.Angles(jit(0.4), rand(0, 6), jit(0.4)), "thatchOld", Color3.fromRGB(70, 76, 50))
		t.CastShadow = false
	end
	pole(m, "Rake", (cf * CFrame.new(5.8, 0, 1)).Position, (cf * CFrame.new(4.2, 4.6, 1.3)).Position, 0.1, "oak")
	return m
end

-- The mine's hill: rock and slate heaped into the south-west corner, and the
-- adit cut into it. Terrain, not parts, so it reads as ground. A rerun
-- clears the corner above the floor first.
local MINE_MOUTH = Vector3.new(-124, GROUND, -1170)
local MINE_IN = Vector3.new(-0.707, 0, -0.707) -- the way the tunnel runs

local function mineHill()
	Terrain:FillBlock(CFrame.new(-131, 22, -1182), Vector3.new(86, 44, 84), Enum.Material.Air)
	for _, b in { { -152, -1198, 30 }, { -128, -1208, 22 }, { -163, -1166, 18 }, { -106, -1213, 13 }, { -131, -1177, 15 } } do
		Terrain:FillBall(Vector3.new(b[1], GROUND - b[3] * 0.18, b[2]), b[3], Enum.Material.Rock)
	end
	Terrain:FillBall(Vector3.new(-140, GROUND + 9, -1192), 9, Enum.Material.Slate)
	Terrain:FillBall(Vector3.new(-112, GROUND + 2, -1196), 7, Enum.Material.Slate)
	-- the adit, 30 in, from the floor's own level: cut 11 wide so that once
	-- the terrain has smoothed its walls it is still 7 or 8
	local cf = CFrame.lookAt(MINE_MOUTH, MINE_MOUTH + MINE_IN)
	Terrain:FillBlock(cf * CFrame.new(0, 4, -13), Vector3.new(11, 12, 34), Enum.Material.Air)
end

--------------------------------------------------------------------------
-- AREA 5 — THE SMITHY. A stone forge with two hearths, open along its
-- front; the armoury with its loft; the smith's house; the mine in the
-- south-west corner with its rails and its tubs; the bloomery and the
-- charcoal clamp; dead trees, an axe left in a stump, and the saw pit where
-- they become planks; the oil store and a rack of unlit torches.
-- Weapons half-finished on the bench. It was still working when it stopped.
--------------------------------------------------------------------------
local function area5()
	local f = areaFolder(5)
	local zNear, zFar = Castle.chamberBounds(5)
	local road = { Vector2.new(-153, zNear - 16), Vector2.new(-140, -1020), Vector2.new(-95, -1046), Vector2.new(-40, -1066), Vector2.new(10, -1082), Vector2.new(60, -1110), Vector2.new(110, -1145), Vector2.new(140, -1168), Vector2.new(153, zFar + 14) }
	local mineTrack = { Vector2.new(-60, -1080), Vector2.new(-80, -1118), Vector2.new(-100, -1146) }
	local yardLane = { Vector2.new(-10, -1080), Vector2.new(2, -1128), Vector2.new(2, -1166) }

	mineHill()
	local sawCf = CFrame.new(28, GROUND, -1046)
	digTrench(sawCf, 14, 5, 7)
	paintGround(zNear - 2, zFar + 2, {
		{ path = road, width = 12, material = Enum.Material.Cobblestone, verge = Enum.Material.Mud },
		{ path = mineTrack, width = 7, material = Enum.Material.Mud },
		{ path = yardLane, width = 6, material = Enum.Material.Mud },
	}, { { Vector2.new(-45, -1080), 18 }, { Vector2.new(14, -1158), 16 }, { Vector2.new(-100, -1146), 14 }, { Vector2.new(30, -1046), 12 } }, {
		{ x0 = -171, x1 = -88, z0 = -1222, z1 = -1136, material = Enum.Material.Slate, alt = Enum.Material.Mud },
		{ x0 = -28, x1 = -4, z0 = -1190, z1 = -1166, material = Enum.Material.Mud, alt = Enum.Material.Slate },
	})
	task.wait()

	-- 1. THE SMITHY — rubble stone, six open bays to the yard, two hearths
	--    backing onto two stacks, the bellows and anvils between.
	house(f, at(-45, -1100, "N"), {
		name = "Smithy",
		W = 30,
		D = 16,
		storeys = 1,
		plinth = 0.8,
		ground = "stone",
		front = { "bay", "bay", "bay", "bay", "bay", "bay" },
		back = { "wall", "window", "wall", "wall", "window", "wall" },
		left = { "wall", "window", "wall" },
		right = { "wall", "loop", "wall" },
		roof = { kind = "shingles", pitch = 38, chimneys = { -7.5, 7.5 } },
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			for i, s in { -1, 1 } do
				local h = forgeHearth(m, B * CFrame.new(s * 7.5, y, -2.3), true)
				local bl = bellows(m, B * CFrame.new(s * 11.2, y, 2.4))
				local stumpCf = B * CFrame.new(s * 2.6, y, -3.4)
				local st = part(m, "AnvilBlock", Vector3.new(1.3, 2.2, 2.2), stumpCf * CFrame.new(0, 0.65, 0) * CFrame.Angles(0, 0, math.rad(90)), "oakDark")
				;(st :: Part).Shape = Enum.PartType.Cylinder
				local anvil = prop(m, "Anvil", stumpCf * CFrame.new(0, 1.3, 0) * CFrame.Angles(0, math.rad(90), 0), 1.1)
				prop(m, "Trough", B * CFrame.new(s * 2.6, y, 0.9), 1.1)
				if i == 1 then
					-- the forge the smithy's work is done at (AreaPlan, area 5)
					h:SetAttribute("Mechanic", "Forge")
					bl.Name = "ForgeBellows"
					if anvil then
						anvil.Name = "ForgeAnvil"
					end
				end
			end
			-- behind the stacks: the bench, the bar iron, the coal
			weaponBench(m, B * CFrame.new(0, y, 4.4))
			for k = 0, 5 do
				part(m, "BarIron", Vector3.new(0.4, 0.3, 5), B * CFrame.new(-11 + (k % 3) * 0.5, y + 0.2 + math.floor(k / 3) * 0.32, 4) * CFrame.Angles(0, jit(0.04), 0), "ironDark").CastShadow = false
			end
			local heap = ball(m, "CoalHeap", Vector3.new(4.5, 2.4, 3.4), B * CFrame.new(10.6, y, 4.4), "soot")
			heap.CanCollide = false
			local board = part(m, "ToolBoard", Vector3.new(6, 3, 0.3), B * CFrame.new(-6, y + 5, 5.7), "planks")
			for k = 0, 6 do
				local t = part(m, "Tool", Vector3.new(0.18, rand(1.6, 2.6), 0.12), board.CFrame * CFrame.new(-2.6 + k * 0.85, -0.2, -0.22) * CFrame.Angles(0, 0, jit(0.1)), "ironDark")
				t.CastShadow = false
			end
		end,
	})
	-- the yard in front: a grindstone, an anvil outdoors, a rack of finished
	-- swords and the rack of torches nobody lit
	local yard = model(f, "SmithYard")
	grindstone(yard, at(-24, -1086, 10))
	local ob = at(-50, -1084, 0)
	local blk = part(yard, "AnvilBlock", Vector3.new(1.4, 2.4, 2.4), ob * CFrame.new(0, 0.7, 0) * CFrame.Angles(0, 0, math.rad(90)), "oakDark")
	;(blk :: Part).Shape = Enum.PartType.Cylinder
	prop(yard, "Anvil", ob * CFrame.new(0, 1.4, 0), 1.1)
	prop(yard, "Barrel", at(-46.5, -1085.5, 0))
	swordRack(yard, at(-34, -1086, "N"), 6)
	torchRack(f, at(-62.5, -1100, "W"), 4) -- against the smithy's west end
	prop(yard, "Cart", at(-80, -1090, 60), 1.5)
	for k = 0, 4 do
		part(yard, "BarIron", Vector3.new(0.4, 0.3, 5), CFrame.new(-80 + jit(0.4), GROUND + 2.6 + k * 0.3, -1090) * CFrame.Angles(0, math.rad(60), 0), "ironDark").CastShadow = false
	end
	-- loose bits only: a barrel rolled in front of a bay takes the bay away
	clutter(yard, Vector3.new(-45, 0, -1080), 12, 10, { "stone", "plank", "stone" })
	task.wait()

	-- 2. THE SMITH'S HOUSE.
	house(f, at(-50, -1030, "S"), {
		name = "SmithsHouse",
		W = 20,
		D = 12,
		storeys = 2,
		front = { "window", "door", "window", "window" },
		roof = { kind = "thatch", holes = 0.06 },
		glow = true,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			prop(m, "Table", B * CFrame.new(4.5, y, -3))
			prop(m, "Barrel", B * CFrame.new(-6.8, y, -3.6))
			prop(m, "Shelf", B * CFrame.new(8.2, y, -1.5) * CFrame.Angles(0, -math.pi / 2, 0))
			if info.upperY then
				prop(m, "Bed", B * CFrame.new(3, info.upperY, -3.4), 1.5)
				prop(m, "Chest", B * CFrame.new(-4, info.upperY, -4))
			end
		end,
	})
	prop(f, "Firewood", at(-50, -1030, "S") * CFrame.new(-6.5, 0, -7.8), 1.3)

	-- 3. THE ARMOURY: stone below, the store of finished arms; a loft above.
	house(f, at(55, -1142, "N"), {
		name = "Armoury",
		W = 24,
		D = 15,
		storeys = 2,
		ground = "stone",
		front = { "window", "door", "loop", "window" },
		back = { "loop", "loop", "loop", "loop" },
		roof = { kind = "shingles", pitch = 42 },
		glow = true,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			-- the right half only: the door, and the way from it to the stair
			-- foot on the left, stay clear
			-- (stone walls 2.2 thick: inside runs to x 9.8 and z -5.3)
			spearRack(m, B * CFrame.new(4.5, y, -4.3), 6)
			armourStand(m, B * CFrame.new(7.5, y, -3.4) * CFrame.Angles(0, -math.pi / 2, 0))
			armourStand(m, B * CFrame.new(7.5, y, -0.2) * CFrame.Angles(0, -math.pi / 2, 0))
			for k = 0, 2 do
				shield(m, B * CFrame.new(9.6, y + 5.4, -4.2 + k * 2.6))
			end
			if info.upperY then
				swordRack(m, B * CFrame.new(3, info.upperY, -5.8), 6)
				prop(m, "Chest", B * CFrame.new(-6, info.upperY, -5))
				prop(m, "Crate", B * CFrame.new(-2, info.upperY, -5.2))
				for k = 0, 3 do
					helmet(m, B * CFrame.new(-8 + k * 1.6, info.upperY + 0.2, -6.2))
				end
			end
		end,
	})
	swordRack(f, at(44, -1128, "N"), 5)
	spearRack(f, at(68, -1128, "N"), 6)
	task.wait()

	-- 4. THE MINE.
	local mine = model(f, "Mine")
	local inCf = CFrame.lookAt(MINE_MOUTH, MINE_MOUTH + MINE_IN)
	minePortal(mine, CFrame.lookAt(MINE_MOUTH, MINE_MOUTH - MINE_IN), 25)
	local deep = MINE_MOUTH + MINE_IN * 26
	rails(mine, { deep, MINE_MOUTH, Vector3.new(-104, GROUND, -1150), Vector3.new(-92, GROUND, -1140) }, 0.2)
	-- the tub at the face, at the end of the line (anywhere else it plugs the tunnel)
	mineCart(mine, CFrame.lookAt(MINE_MOUTH + MINE_IN * 25, MINE_MOUTH + MINE_IN * 30))
	local tipped = model(mine, "Tipped")
	mineCart(tipped, CFrame.new())
	place(tipped, CFrame.new(-95, GROUND + 1.4, -1138) * CFrame.Angles(0, math.rad(40), math.rad(95)))
	for _ = 1, 14 do
		local s = rand(0.8, 2.2)
		local ore = ball(mine, "Ore", Vector3.new(s, s * 0.7, s), CFrame.new(-88 + jit(4), GROUND + s * 0.2, -1134 + jit(4)) * CFrame.Angles(0, rand(0, 6), 0), "rubble")
		ore.Color = Color3.fromRGB(116, 80, 60)
		ore.CastShadow = false
	end
	-- gold in the walls of the adit, where the lamp catches it
	for k = 1, 12 do
		local t = rand(4, 24)
		local side = if k % 2 == 0 then 1 else -1
		local p = (inCf * CFrame.new(side * 4.3, rand(2.5, 8), -t)).Position
		local g = part(mine, "GoldVein", Vector3.new(rand(0.3, 0.6), rand(0.2, 0.5), rand(0.8, 2)), CFrame.new(p) * CFrame.Angles(jit(1), rand(0, 6), jit(1)), "iron", GOLD)
		g.Material = Enum.Material.Metal
		g.MaterialVariant = ""
		g.Reflectance = 0.25
		g.CastShadow = false
	end
	-- spoil and tools at the mouth
	for _ = 1, 10 do
		local s = rand(0.6, 1.8)
		local r = ball(mine, "Spoil", Vector3.new(s, s * 0.6, s), CFrame.new(MINE_MOUTH + Vector3.new(rand(4, 12), s * 0.15, rand(-2, 8))) * CFrame.Angles(0, rand(0, 6), 0), "rubble")
		r.CastShadow = false
	end
	spade(mine, MINE_MOUTH + Vector3.new(6, 1, 5), CFrame.Angles(math.rad(-15), 0, math.rad(10)))
	pole(mine, "Pick", MINE_MOUTH + Vector3.new(7.5, 0.3, 2), MINE_MOUTH + Vector3.new(7, 3.6, 2.6), 0.12, "oak")
	lanternPost(mine, CFrame.lookAt(MINE_MOUTH + Vector3.new(9, 0, -2), MINE_MOUTH))
	task.wait()

	-- 5. THE OIL STORE, a lean-to on the west wall: jars, casks.
	local inner = Castle.innerHalfWidth()
	local oil = leanTo(f, at(-inner + 9.5, -1058, "E"), 30, 14, 12, 8.5, { kind = "shingles", sides = true })
	oil.Name = "OilStore"
	for k = 0, 9 do
		oilJar(oil, at(-inner + 4 + (k % 2) * 3.2, -1070 + math.floor(k / 2) * 5 + (k % 2) * 2.4, rand(0, 360)), rand(0.9, 1.15))
	end
	prop(oil, "Barrel", at(-inner + 11, -1046, 0))
	prop(oil, "Barrel", at(-inner + 12.5, -1048.4, 0))
	clutter(oil, Vector3.new(-inner + 10, 0, -1058), 6, 6, { "straw", "plank" })

	-- 6. THE TREES, the stumps, the saw pit and the planks.
	local wood = model(f, "Woodyard")
	for _, t in { { 64, -1052, 30 }, { 88, -1040, 26 }, { 108, -1060, 32 }, { 134, -1046, 28 }, { 78, -1076, 24 }, { 124, -1084, 30 } } do
		local tree = deadTree(wood, at(t[1], t[2], 0), t[3])
		tree:SetAttribute("Choppable", true)
	end
	stump(wood, at(96, -1062, 0), 1.6, true)
	stump(wood, at(72, -1036, 0), 1.4)
	stump(wood, at(118, -1070, 0), 1.7)
	-- trunks waiting, stacked against chocks
	for k = 0, 4 do
		local y = 1.0 + (if k >= 3 then 1.7 else 0)
		local x = 44 + (k % 3) * 2.1 + (if k >= 3 then 1 else 0)
		pole(wood, "Log", Vector3.new(x, GROUND + y, -1034), Vector3.new(x + jit(0.4), GROUND + y, -1046), 1.0, "oakDark").Color = Color3.fromRGB(78, 68, 60)
	end
	-- the saw pit: a log over the hole on two bearers, the long saw in it
	for _, x in { -4.5, 4.5 } do
		beam(wood, "Bearer", (sawCf * CFrame.new(x, 0.5, -4)).Position, (sawCf * CFrame.new(x, 0.5, 4)).Position, 0.9, 0.9, "oakDark")
	end
	pole(wood, "SawLog", (sawCf * CFrame.new(-7, 1.9, 0)).Position, (sawCf * CFrame.new(7, 1.9, 0)).Position, 0.95, "oakDark").Color = Color3.fromRGB(86, 74, 62)
	part(wood, "Saw", Vector3.new(0.06, 9, 0.7), sawCf * CFrame.new(1.5, -1.4, 0), "iron").CastShadow = false
	for _, y in { 3, -5.8 } do
		part(wood, "SawHandle", Vector3.new(0.25, 0.25, 1.8), sawCf * CFrame.new(1.5, y, 0), "oak")
	end
	local sawdust = part(wood, "Sawdust", Vector3.new(4, 0.2, 3), sawCf * CFrame.new(-2, 0.1, 4), "hay", Color3.fromRGB(196, 170, 128))
	sawdust.CanCollide = false
	-- the planks already sawn: the ones that will board a door, further on
	local planks = model(wood, "PlankStack")
	for k = 0, 9 do
		part(planks, "Plank", Vector3.new(1.1, 0.25, 9), CFrame.new(12 + (k % 3) * 1.2, GROUND + 0.6 + math.floor(k / 3) * 0.27, -1040) * CFrame.Angles(0, jit(0.03), 0), "planks", Color3.fromRGB(190, 160, 120))
	end
	for _, z in { -1043.5, -1036.5 } do
		part(planks, "Chock", Vector3.new(4, 0.5, 0.6), CFrame.new(13.2, GROUND + 0.25, z), "oakDark")
	end
	task.wait()

	-- 7. THE BLOOMERY, the CHARCOAL CLAMP, the ore and the charcoal shed.
	bloomery(f, at(16, -1156, 0), true)
	charcoalClamp(f, at(-16, -1178, 0))
	local shed = openShed(f, at(34, -1184, "N"), 14, 9, 8, { kind = "shingles", pitch = 32, holes = 0.15 })
	shed.Name = "CharcoalShed"
	prop(shed, "Sacks", at(30, -1184, 10))
	prop(shed, "Sacks", at(36, -1185, -20))
	local cheap = ball(shed, "Charcoal", Vector3.new(5, 2.6, 4), CFrame.new(39, GROUND, -1183), "soot")
	cheap.CanCollide = false
	for _ = 1, 9 do
		local s = rand(0.8, 1.6)
		local ore = ball(f, "Ore", Vector3.new(s, s * 0.7, s), CFrame.new(-9 + jit(3), GROUND + s * 0.2, -1146 + jit(3)) * CFrame.Angles(0, rand(0, 6), 0), "rubble")
		ore.Color = Color3.fromRGB(116, 80, 60)
		ore.CastShadow = false
	end
	prop(f, "Wheelbarrow", at(-8, -1154, 30), 1.4)
	task.wait()

	-- 8. Light, and the litter.
	roadLanterns(f, road, 38, 9)
	clutter(f, Vector3.new(0, 0, -1110), 140, 36, { "stone", "plank", "stone", "straw" })
	wallTorches(f, 5)
	clearMarkers(5, f)
end

--------------------------------------------------------------------------
-- Pieces for the hall
--------------------------------------------------------------------------
local HERALDRY = { Color3.fromRGB(120, 30, 34), Color3.fromRGB(36, 48, 88), Color3.fromRGB(46, 70, 44), Color3.fromRGB(150, 116, 40) }

-- A trestle table, its length along local X. `over`: knocked on its side.
local function trestle(parent: Instance, cf: CFrame, len: number, over: boolean?)
	local m = model(parent, "Trestle")
	part(m, "Top", Vector3.new(len, 0.4, 3), CFrame.new(0, 3, 0), "planks")
	for _, x in { -len / 2 + 1.2, len / 2 - 1.2, if len > 14 then 0 else nil } do
		for _, s in { -1, 1 } do
			beam(m, "Leg", Vector3.new(x, 2.8, 0), Vector3.new(x, 0, s * 1.2), 0.35, 0.35, "oakDark")
		end
		beam(m, "Cross", Vector3.new(x, 2.7, -1.3), Vector3.new(x, 2.7, 1.3), 0.35, 0.4, "oakDark")
	end
	if over then
		-- on its side: the top stood up on edge, the legs sticking out
		place(m, cf * CFrame.new(0, 1.5, 0) * CFrame.Angles(math.rad(90 + jit(3)), 0, 0))
	else
		place(m, cf)
	end
	return m
end

local function bench(parent: Instance, cf: CFrame, len: number, over: boolean?)
	local m = model(parent, "Bench")
	part(m, "Seat", Vector3.new(len, 0.35, 1.2), CFrame.new(0, 1.7, 0), "planks")
	for _, x in { -len / 2 + 0.8, len / 2 - 0.8 } do
		part(m, "Leg", Vector3.new(0.35, 1.55, 1.0), CFrame.new(x, 0.78, 0), "oakDark")
	end
	place(m, if over then cf * CFrame.new(0, 0.6, 0) * CFrame.Angles(math.rad(90), 0, 0) else cf)
	return m
end

-- What was on the table when they got up from it.
local function feastTable(parent: Instance, cf: CFrame, len: number)
	local t = trestle(parent, cf, len)
	part(t, "Cloth", Vector3.new(len - 0.4, 0.06, 3.3), cf * CFrame.new(0, 3.24, 0), "linen")
	for x = -len / 2 + 1.5, len / 2 - 1.5, rand(1.6, 2.4) do
		local s = if chance(0.5) then 1 else -1
		local plate = part(t, "Platter", Vector3.new(0.12, 1.3, 1.3), cf * CFrame.new(x, 3.3, s * 0.8) * CFrame.Angles(0, 0, math.rad(90)), "iron", Color3.fromRGB(140, 136, 128))
		;(plate :: Part).Shape = Enum.PartType.Cylinder
		plate.CastShadow = false
		if chance(0.6) then
			local g = part(t, "Goblet", Vector3.new(0.6, 0.35, 0.35), cf * CFrame.new(x + 0.8, 3.6, s * 0.3) * CFrame.Angles(0, 0, math.rad(90)), "iron", Color3.fromRGB(150, 130, 90))
			;(g :: Part).Shape = Enum.PartType.Cylinder
			g.CastShadow = false
		elseif chance(0.4) then
			-- knocked over
			local g = part(t, "Goblet", Vector3.new(0.6, 0.35, 0.35), cf * CFrame.new(x + 0.6, 3.45, s * 0.4) * CFrame.Angles(0, rand(0, 6), 0), "iron", Color3.fromRGB(150, 130, 90))
			;(g :: Part).Shape = Enum.PartType.Cylinder
			g.CastShadow = false
		end
	end
	prop(t, "BreadBasket", cf * CFrame.new(len * 0.2, 3.3, 0))
	for _, x in { -len * 0.25, len * 0.35 } do
		candle(t, (cf * CFrame.new(x, 3.3, 0)).Position, 1.2, false)
	end
	return t
end

-- A banner on a pole along local X, hanging down from cf. `torn`: the
-- bottom gone ragged.
local function banner(parent: Instance, cf: CFrame, w: number, h: number, colour: Color3, torn: boolean?)
	local m = model(parent, "Banner")
	pole(m, "Pole", (cf * CFrame.new(-w / 2 - 0.5, 0, 0)).Position, (cf * CFrame.new(w / 2 + 0.5, 0, 0)).Position, 0.14, "oakDark")
	local hh = if torn then h * rand(0.55, 0.8) else h
	local cloth = part(m, "Cloth", Vector3.new(w, hh, 0.08), cf * CFrame.new(0, -hh / 2 - 0.2, 0), "cloth", colour)
	cloth.CastShadow = false
	-- the charge: a pale chevron, and a band at the head
	part(m, "Band", Vector3.new(w + 0.02, 0.5, 0.1), cf * CFrame.new(0, -0.6, 0), "cloth", Color3.fromRGB(190, 170, 120)).CastShadow = false
	if hh > h * 0.5 then
		for _, s in { -1, 1 } do
			local c = part(m, "Charge", Vector3.new(w * 0.62, 0.45, 0.1), cf * CFrame.new(s * w * 0.18, -h * 0.42, 0) * CFrame.Angles(0, 0, s * math.rad(-35)), "cloth", Color3.fromRGB(196, 178, 128))
			c.CastShadow = false
		end
	end
	if torn then
		for _ = 1, 3 do
			local rag = part(m, "Rag", Vector3.new(rand(0.4, 0.9), rand(0.8, 1.8), 0.08), cf * CFrame.new(rand(-w / 2, w / 2), -hh - rand(0.3, 0.8), 0) * CFrame.Angles(0, 0, jit(0.3)), "cloth", colour)
			rag.CastShadow = false
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	return m
end

-- An iron wheel of candles hung on chains from `top`, `drop` below it.
local function chandelier(parent: Instance, top: Vector3, drop: number, r: number)
	local m = model(parent, "Chandelier")
	local c = top - Vector3.new(0, drop, 0)
	local n = 12
	for k = 0, n - 1 do
		local a0, a1 = k / n * math.pi * 2, (k + 1) / n * math.pi * 2
		beam(m, "Ring", c + Vector3.new(math.cos(a0) * r, 0, math.sin(a0) * r), c + Vector3.new(math.cos(a1) * r, 0, math.sin(a1) * r), 0.25, 0.3, "ironDark")
	end
	for k = 0, 3 do
		local a = k / 4 * math.pi * 2
		beam(m, "Chain", c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), c + Vector3.new(0, 3.2, 0), 0.1, 0.1, "ironDark")
		beam(m, "Spoke", c + Vector3.new(math.cos(a) * r, 0, math.sin(a) * r), c, 0.18, 0.18, "ironDark")
	end
	beam(m, "Chain", c + Vector3.new(0, 3.2, 0), top, 0.12, 0.12, "ironDark")
	for k = 0, 7 do
		if chance(0.8) then
			local a = k / 8 * math.pi * 2 + 0.2
			candle(m, c + Vector3.new(math.cos(a) * r, 0.15, math.sin(a) * r), rand(0.6, 1.1), false)
		end
	end
	local glow = part(m, "Glow", Vector3.new(0.4, 0.4, 0.4), CFrame.new(c + Vector3.new(0, 1.2, 0)), "dark")
	glow.Transparency = 1
	pointLight(glow, Color3.fromRGB(255, 176, 100), 1.6, 34)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	return m
end

-- A torch in an iron sconce on a wall face: `cf` on the face, -Z out of it.
local function sconce(parent: Instance, cf: CFrame)
	local m = model(parent, "Sconce")
	part(m, "Plate", Vector3.new(1.0, 1.6, 0.25), cf * CFrame.new(0, 0, -0.12), "ironDark")
	beam(m, "Arm", (cf * CFrame.new(0, -0.3, -0.2)).Position, (cf * CFrame.new(0, 0.3, -1.1)).Position, 0.18, 0.18, "ironDark")
	pole(m, "Brand", (cf * CFrame.new(0, 0.1, -1.2)).Position, (cf * CFrame.new(0, 1.5, -1.45)).Position, 0.22, "oakDark")
	local core = fireAt(m, (cf * CFrame.new(0, 1.9, -1.5)).Position, 0.6, 26)
	local l = core:FindFirstChildOfClass("PointLight")
	if l then
		l.Brightness = 1.6
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	return m
end

--[[
	THE GREAT HALL. Rubble stone, buttressed, tall lancets high in the side
	walls; an open timber roof of arch-braced trusses, slates over, a louvre
	over the central hearth. The screens passage at the east end runs from
	the north door to the south door under the minstrels' gallery; the dais
	and the high table at the west end, the solar door beside it.

	B: the centre of the floor; X along the hall (the dais at -X), +Z north.
	Floors are flush with the yard and every door is eight wide: this is the
	room the last of them held, and the dead came in through the doors.
	The four door openings carry a "BoardPoint" (AreaPlan, area 6: the doors
	are boarded with the planks carried from the smithy).
]]
local function greatHall(parent: Instance, B: CFrame): Model
	local m = model(nil, "GreatHall")
	local L, D, H, T = 120, 46, 24, 2.8
	local FLOOR = 0.05
	local hx, hz = L / 2 - T, D / 2 - T -- the inside faces
	local so: WallOpts = { T = T, lancet = true, winW = 3.4, winSill = 11, winHead = 21, doorW = 8, doorH = 13, threshold = FLOOR, doorOpen = 162 }
	local SOUTH = { "window", "window", "window", "window", "door", "window", "window", "window", "door", "window" }
	local NORTH = { "window", "door", "window", "window", "window", "window", "window", "window", "window", "window" }
	wall4(m, B, L, D, H, SOUTH, NORTH, { "wall", "window", "window", "door" }, { "wall", "window", "window", "wall" }, so)
	flags(m, B, -hx - 0.2, hx + 0.2, -hz - 0.2, hz + 0.2, FLOOR)

	-- where the boards will go: one mark in each doorway
	local points = model(m, "BoardPoints")
	for i, d in { { 42, -D / 2 + T / 2 }, { 42, D / 2 - T / 2 }, { -6, -D / 2 + T / 2 }, { -L / 2 + T / 2, -17.25 } } do
		local alongX = math.abs(d[2]) > 20
		local p = part(points, "BoardPoint", if alongX then Vector3.new(8, 13, 0.2) else Vector3.new(0.2, 13, 8), B * CFrame.new(d[1], 6.5, d[2]), "dark")
		p.Transparency = 1
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p:SetAttribute("Door", i)
	end

	-- buttresses between the bays (not at the doors), quoins at the corners
	for k = 1, 9 do
		local x = -L / 2 + k * 12
		if math.abs(x - 36) > 1 and math.abs(x - 48) > 1 then
			buttress(m, B * CFrame.new(x, 0, D / 2) * CFrame.Angles(0, math.pi, 0), 16)
		end
		if math.abs(x - 36) > 1 and math.abs(x - 48) > 1 and math.abs(x) > 1 and math.abs(x + 12) > 1 then
			buttress(m, B * CFrame.new(x, 0, -D / 2), 16)
		end
	end
	for _, c in { { -L / 2, -D / 2, 0 }, { L / 2, -D / 2, 90 }, { -L / 2, D / 2, -90 }, { L / 2, D / 2, 180 } } do
		quoins(m, B * CFrame.new(c[1], 0, c[2]) * CFrame.Angles(0, math.rad(c[3]), 0), H)
	end

	-- THE ROOF: slates on rafters, stone gables, and the trusses you see
	-- from below: a tie beam, two arch braces, a king post, every ten studs
	local slates = { kind = "shingles", pitch = 45, overhang = 1.2, gableOver = 0.6, gableKey = "rubble", holes = 0.05 }
	roof(m, B * CFrame.new(0, H, 0), L, D, slates)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") and d.Material == Enum.Material.RoofShingles then
			d.Color = shade(Color3.fromRGB(112, 116, 118), rand(0.85, 1.05))
		end
	end
	local apex = H + (D / 2) * math.tan(math.rad(45))
	for x = -50, 50, 10 do
		local P = B * CFrame.new(x, 0, 0)
		beam(m, "TieBeam", (P * CFrame.new(0, H - 0.6, -hz - 0.6)).Position, (P * CFrame.new(0, H - 0.6, hz + 0.6)).Position, 1.1, 1.3, "oakDark")
		beam(m, "KingPost", (P * CFrame.new(0, H - 0.6, 0)).Position, (P * CFrame.new(0, apex - 0.8, 0)).Position, 1.0, 1.0, "oakDark")
		for _, s in { -1, 1 } do
			-- over the gallery flight (north wall, x 15..34) the brace, post and
			-- corbel were cut away: they took the headroom off the stair
			if s > 0 and x > 14 and x < 36 then
				beam(m, "Strut", (P * CFrame.new(0, H - 0.6, s * 6)).Position, (P * CFrame.new(0, apex - 6.5, s * 0.5)).Position, 0.6, 0.6, "oakDark")
				continue
			end
			beam(m, "WallPost", (P * CFrame.new(0, H - 7, s * (hz - 0.4))).Position, (P * CFrame.new(0, H - 0.6, s * (hz - 0.4))).Position, 0.9, 0.9, "oakDark")
			beam(m, "ArchBrace", (P * CFrame.new(0, H - 7, s * (hz - 0.6))).Position, (P * CFrame.new(0, H - 1.2, s * (hz - 7))).Position, 0.8, 0.9, "oakDark")
			part(m, "Corbel", Vector3.new(1.4, 1.2, 1.4), P * CFrame.new(0, H - 7.6, s * (hz - 0.3)), "stone")
			beam(m, "Strut", (P * CFrame.new(0, H - 0.6, s * 6)).Position, (P * CFrame.new(0, apex - 6.5, s * 0.5)).Position, 0.6, 0.6, "oakDark")
		end
	end
	-- the louvre over the hearth, still smoking
	local lv = B * CFrame.new(0, apex + 1.6, 0)
	part(m, "Louvre", Vector3.new(6, 3.4, 4.6), lv * CFrame.new(0, 1.2, 0), "planks", Color3.fromRGB(110, 96, 82))
	roof(m, lv * CFrame.new(0, 2.9, 0), 6, 4.6, { kind = "shingles", pitch = 40, overhang = 0.6, gableOver = 0.5 })
	local vent = part(m, "Vent", Vector3.new(0.5, 0.5, 0.5), lv * CFrame.new(0, 5, 0), "dark")
	vent.Transparency = 1
	vent.CanCollide = false
	smokeOn(vent, 3)

	-- THE SCREENS and the MINSTRELS' GALLERY over the passage
	local sx = 34 -- the screen's line; the passage is east of it
	-- the screen stops short of the gallery boards: the flight arrives over
	-- its head plate, and a plate standing proud of the ramp is a lip the
	-- dead cannot climb
	frameWall(m, B * CFrame.new(sx, FLOOR, -hz) * CFrame.Angles(0, -math.pi / 2, 0), hz * 2, 14.2, { "wall", "open", "wall", "open", "wall" }, { damage = 0.05 })
	local GY = 15 -- the gallery boards' centre; their top is GY + 0.16
	for z = -hz + 1, hz - 1, 2.2 do
		beam(m, "GalleryJoist", (B * CFrame.new(sx - 0.4, GY - 0.6, z)).Position, (B * CFrame.new(hx, GY - 0.6, z)).Position, 0.7, 0.8, "oakDark")
	end
	boards(m, B * CFrame.new((sx + hx) / 2, GY, 0), hx - sx, hz * 2)
	local deckTop = GY + 0.16
	-- the flight up to it, along the north wall, arriving flush at the edge
	local rise = deckTop - FLOOR
	local run = math.ceil(rise / 0.95) * 1.15
	local sz = hz - 2.4
	stair(m, (B * CFrame.new(sx - run, FLOOR, sz)).Position, B.RightVector, rise, 4.0, "planks", 1.15)
	for k = 1, 2 do
		local x = sx - run + run * k / 3
		local y = FLOOR + rise * k / 3
		beam(m, "Baluster", (B * CFrame.new(x, y, sz - 2.3)).Position, (B * CFrame.new(x, y + 3.2, sz - 2.3)).Position, 0.35, 0.35, "oakDark")
	end
	beam(m, "Handrail", (B * CFrame.new(sx - run * 2 / 3, FLOOR + rise / 3 + 3.5, sz - 2.3)).Position, (B * CFrame.new(sx - run / 3, FLOOR + rise * 2 / 3 + 3.5, sz - 2.3)).Position, 0.3, 0.4, "oak")
	-- the gallery's front: a balustrade, open where the flight comes up
	local railEnd = sz - 2.3
	for z = -hz + 0.4, railEnd, 1.3 do
		beam(m, "Baluster", (B * CFrame.new(sx - 0.2, deckTop, z)).Position, (B * CFrame.new(sx - 0.2, deckTop + 3.4, z)).Position, 0.28, 0.28, "oakDark")
	end
	beam(m, "GalleryRail", (B * CFrame.new(sx - 0.2, deckTop + 3.5, -hz)).Position, (B * CFrame.new(sx - 0.2, deckTop + 3.5, railEnd)).Position, 0.45, 0.4, "oak")
	bench(m, B * CFrame.new(46, deckTop, -6) * CFrame.Angles(0, math.pi / 2, 0), 6)
	prop(m, "Chest", B * CFrame.new(52, deckTop, 8))
	local drum = part(m, "Drum", Vector3.new(1.6, 2.2, 2.2), B * CFrame.new(44, deckTop + 1.1, 4), "planks", Color3.fromRGB(150, 120, 90))
	;(drum :: Part).Shape = Enum.PartType.Cylinder
	banner(m, B * CFrame.new(42, deckTop + 3.3, -hz + 4) * CFrame.Angles(0, math.pi / 2, 0), 3, 5, HERALDRY[1], true)

	-- THE DAIS at the west end, a step up (with the ramp under the step),
	-- the high table on it, the lord's chair, the cloth of estate behind
	local dx0, dx1 = -hx, -hx + 11
	local dz0 = -13
	part(m, "Dais", Vector3.new(dx1 - dx0, 1.0, hz - dz0), B * CFrame.new((dx0 + dx1) / 2, FLOOR + 0.5, (hz + dz0) / 2), "planks")
	part(m, "DaisEdge", Vector3.new(0.6, 1.0, hz - dz0), B * CFrame.new(dx1 - 0.3, FLOOR + 0.5, (hz + dz0) / 2), "stone").CastShadow = false
	ramp(m, (B * CFrame.new(dx1 + 3, FLOOR, (hz + dz0) / 2)).Position, -B.RightVector, 1.0, 3, hz - dz0 - 1)
	local dy = FLOOR + 1.0
	feastTable(m, B * CFrame.new(-51, dy, 4) * CFrame.Angles(0, math.pi / 2, 0), 16)
	local chair = model(m, "LordsChair")
	part(chair, "Seat", Vector3.new(2.6, 0.4, 2.4), CFrame.new(0, 2, 0), "oakDark")
	part(chair, "Back", Vector3.new(2.6, 5, 0.4), CFrame.new(0, 4.3, 1.1), "oakDark")
	for _, s in { -1, 1 } do
		part(chair, "Arm", Vector3.new(0.4, 1.2, 2.4), CFrame.new(s * 1.2, 2.8, 0), "oakDark")
		for _, z in { -1, 1 } do
			part(chair, "Leg", Vector3.new(0.4, 2, 0.4), CFrame.new(s * 1.1, 1, z * 1.0), "oakDark")
		end
	end
	part(chair, "Cushion", Vector3.new(2.2, 0.3, 2), CFrame.new(0, 2.3, 0), "cloth")
	place(chair, B * CFrame.new(-54.4, dy, 4) * CFrame.Angles(0, -math.pi / 2, 0))
	part(m, "ClothOfEstate", Vector3.new(0.15, 12, 9), B * CFrame.new(-hx + 0.1, dy + 9, 4), "cloth", HERALDRY[1]).CastShadow = false
	part(m, "Tester", Vector3.new(4, 0.4, 9.6), B * CFrame.new(-hx + 2, dy + 15.2, 4), "cloth", shade(HERALDRY[1], 0.8))
	for _, z in { -0.5, 8.5 } do
		part(m, "Trim", Vector3.new(0.2, 12, 0.4), B * CFrame.new(-hx + 0.1, dy + 9, z), "cloth", Color3.fromRGB(190, 160, 80)).CastShadow = false
	end

	-- THE BODY OF THE HALL: tables down both sides, most of them thrown
	-- over, one still laid; the hearth in the middle of the floor
	-- (north: clear of the gallery stair's foot at x 15.6; south: clear of
	-- the side door at x -6)
	for _, s in { -1, 1 } do
		for k, x in (if s > 0 then { -38, -18, 2 } else { -38, -20, 14 }) do
			local over = not (s == 1 and k == 2)
			local tz = s * (hz - 6)
			if over then
				trestle(m, B * CFrame.new(x + jit(1), FLOOR, tz) * CFrame.Angles(0, jit(0.08), 0), 16, true)
			else
				feastTable(m, B * CFrame.new(x, FLOOR, tz), 16)
			end
			bench(m, B * CFrame.new(x + jit(1), FLOOR, tz - s * 2.6) * CFrame.Angles(0, jit(0.1), 0), 14, over and chance(0.6))
			if chance(0.5) then
				bench(m, B * CFrame.new(x + jit(2), FLOOR, tz + s * 2.6), 14)
			end
		end
	end
	local hearthCf = B * CFrame.new(0, FLOOR, 0)
	part(m, "HearthSlab", Vector3.new(8, 0.3, 8), hearthCf * CFrame.new(0, 0.15, 0), "stone").CanCollide = false
	for k = 0, 11 do
		local a = k / 12 * math.pi * 2
		part(m, "Kerb", Vector3.new(1.4, 0.7, 1.0), hearthCf * CFrame.new(math.cos(a) * 3.6, 0.35, math.sin(a) * 3.6) * CFrame.Angles(0, -a, 0), "stone")
	end
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		pole(m, "Log", (hearthCf * CFrame.new(math.cos(a) * 2.4, 0.4, math.sin(a) * 2.4)).Position, (hearthCf * CFrame.new(0, 1.2, 0)).Position, 0.4, "charred")
	end
	fireAt(m, (hearthCf * CFrame.new(0, 1.4, 0)).Position, 1.8, 46)
	for _, x in { -25, 25 } do
		chandelier(m, (B * CFrame.new(x, H - 1.3, 0)).Position, 9, 3.2)
	end
	-- banners between the windows, some torn; sconces under them
	for k = 1, 9 do
		local x = -L / 2 + k * 12
		if math.abs(x - 36) > 1 and math.abs(x - 48) > 1 then
			for _, s in { -1, 1 } do
				local overStair = s > 0 and x > 12 and x < 36
				if not (s < 0 and (math.abs(x) < 1 or math.abs(x + 12) < 1)) and not overStair and chance(0.8) then
					banner(m, B * CFrame.new(x, 20, s * (hz - 0.5)), 3.4, 8, HERALDRY[rng:NextInteger(1, #HERALDRY)], chance(0.35))
				end
				if k % 2 == 0 then
					sconce(m, B * CFrame.new(x, 9, s * hz) * CFrame.Angles(0, if s > 0 then 0 else math.pi, 0))
				end
			end
		end
	end
	-- rushes on the floor, kicked about
	clutter(m, (B * CFrame.new(-6, 0, 0)).Position, 40, 50, { "straw", "straw", "straw", "bones" }, true)

	-- THE NORTH PORCH over the screens door
	local pso: WallOpts = { T = 2, lancet = true, archW = 9, archH = 13, threshold = FLOOR }
	local px = 42
	stoneWall(m, B * CFrame.new(px + 7, 0, D / 2) * CFrame.Angles(0, -math.pi / 2, 0), 8, 16, { "wall" }, pso)
	stoneWall(m, B * CFrame.new(px - 7, 0, D / 2 + 8) * CFrame.Angles(0, math.pi / 2, 0), 8, 16, { "wall" }, pso)
	stoneWall(m, B * CFrame.new(px + 7, 0, D / 2 + 8) * CFrame.Angles(0, math.pi, 0), 14, 16, { "arch" }, pso)
	flags(m, B, px - 5, px + 5, D / 2, D / 2 + 6, FLOOR)
	roof(m, B * CFrame.new(px, 16, D / 2 + 4) * CFrame.Angles(0, math.pi / 2, 0), 8, 14, { kind = "shingles", pitch = 45, overhang = 0.8, gableOver = 0.4, gableKey = "rubble" })

	m.Parent = parent
	return m
end

--------------------------------------------------------------------------
-- AREA 6 — THE GREAT HALL. The hall itself, which the road runs through by
-- its screens passage; the solar wing at its high end, the buttery at its
-- low end; north of it the court where the last feast was laid out under
-- pavilions; south, the lord's garden, the chamberlain's house, a range
-- that burned and one that fell.
--------------------------------------------------------------------------
local function area6()
	local f = areaFolder(6)
	local zNear, zFar = Castle.chamberBounds(6)
	local road = { Vector2.new(153, zNear - 16), Vector2.new(128, -1272), Vector2.new(84, -1300), Vector2.new(46, -1318), Vector2.new(32, -1330), Vector2.new(32, -1392), Vector2.new(14, -1404), Vector2.new(-40, -1420), Vector2.new(-100, -1428), Vector2.new(-146, -1436), Vector2.new(-153, zFar + 14) }
	local solarLane = { Vector2.new(-100, -1428), Vector2.new(-104, -1380), Vector2.new(-100, -1360) }
	paintGround(zNear - 2, zFar + 2, {
		{ path = road, width = 12, material = Enum.Material.Cobblestone, verge = Enum.Material.Mud },
		{ path = solarLane, width = 6, material = Enum.Material.Mud },
	}, { { Vector2.new(-45, -1300), 26 }, { Vector2.new(70, -1330), 14 } }, {
		{ x0 = -72, x1 = -24, z0 = -1410, z1 = -1388, material = Enum.Material.LeafyGrass, alt = Enum.Material.Grass },
	})
	task.wait()

	-- 1. THE HALL.
	greatHall(f, at(-10, -1360, 0))
	lanternPost(f, CFrame.lookAt(Vector3.new(21, GROUND, -1322), Vector3.new(32, GROUND, -1322)))
	lanternPost(f, CFrame.lookAt(Vector3.new(43, GROUND, -1398), Vector3.new(32, GROUND, -1398)))
	task.wait()

	-- 2. THE SOLAR WING at the high end: the lord's rooms, stone below,
	--    timber above, its door to the west.
	house(f, at(-88, -1360, "W"), {
		name = "Solar",
		W = 30,
		D = 16,
		storeys = 2,
		ground = "stone",
		front = { "window", "window", "door", "window", "window", "window" },
		upperFront = { "window", "window", "window", "window", "window", "window" },
		roof = { kind = "shingles", pitch = 46 },
		glow = true,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			-- the front right only: the door is mid-front, the stair foot back-left
			prop(m, "Table", B * CFrame.new(6, y, -3.6), 1.2)
			prop(m, "Chest", B * CFrame.new(11, y, -4.4))
			prop(m, "Shelf", B * CFrame.new(12, y, 0) * CFrame.Angles(0, -math.pi / 2, 0))
			banner(m, B * CFrame.new(4, y + 8, -5.6), 3, 5, HERALDRY[2])
			if info.upperY then
				prop(m, "Bed", B * CFrame.new(4, info.upperY, -4.6), 1.9)
				prop(m, "Chest", B * CFrame.new(-4, info.upperY, -5.4))
				prop(m, "Table", B * CFrame.new(-10, info.upperY, -4.4))
			end
		end,
	})

	-- 3. THE BUTTERY at the low end: the casks of ale and wine.
	house(f, at(62, -1360, "E"), {
		name = "Buttery",
		W = 24,
		D = 12,
		storeys = 1,
		ground = "stone",
		-- (a door in an end bay would be half inside the end wall's masonry)
		front = { "window", "door", "window", "door", "window" },
		roof = { kind = "shingles", pitch = 40, holes = 0.1 },
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			-- the casks along the back wall (stone: the inside ends at z 3.8)
			for k = 0, 5 do
				prop(m, "Barrel", B * CFrame.new(-8 + k * 3, y, 2.4) * CFrame.Angles(0, jit(0.5), 0))
			end
			-- the shelf on the end wall, out of the way of both doors
			prop(m, "Shelf", B * CFrame.new(9, y, 0) * CFrame.Angles(0, -math.pi / 2, 0))
			clutter(m, (B * CFrame.new(0, info.plinthH, 0.5)).Position, 4, 5, { "barrelDown", "sacks" }, true)
		end,
	})
	task.wait()

	-- 4. THE COURT, where the last feast was laid out: pavilions, tables
	--    thrown over, the spit over a fire long out, banners on poles.
	local court = model(f, "FeastCourt")
	for i, p in { { -62, -1300, 0, nil }, { -30, -1292, 18, "collapsed" }, { -92, -1306, -10, "burnt" } } do
		local t = tent(court, at(p[1], p[2], p[3]), 12, 14, 9, p[4])
		t.Name = "Pavilion"
		local k = 0
		for _, d in t:GetChildren() do
			if d.Name == "Canvas" then
				k += 1
				if k % 2 == 0 and p[4] ~= "burnt" then
					d.Color = shade(HERALDRY[(i % #HERALDRY) + 1], 1.1)
				end
			end
		end
		-- a pennant on the ridge
		if p[4] == nil then
			local top = (at(p[1], p[2], p[3]) * CFrame.new(7.3, 9.4, 0)).Position
			pole(court, "Pennon", top - Vector3.new(0, 1, 0), top + Vector3.new(0, 3, 0), 0.1, "oakDark")
			part(court, "Pennant", Vector3.new(0.06, 0.9, 2.4), CFrame.new(top + Vector3.new(0, 2.4, 1.2)), "cloth", HERALDRY[1]).CanCollide = false
		end
	end
	for _, t in { { -52, -1318, 10 }, { -74, -1322, -15 }, { -40, -1312, 80 } } do
		trestle(court, at(t[1], t[2], t[3]), 12, true)
		bench(court, at(t[1] + 3, t[2] - 4, t[3] + 20), 10, chance(0.5))
	end
	feastTable(court, at(-62, -1300, 0), 10) -- under the ridge, where the canvas is high
	-- the spit
	local spitCf = at(-6, -1300, 10)
	campfire(court, spitCf, false)
	for _, s in { -1, 1 } do
		pole(court, "Fork", (spitCf * CFrame.new(s * 3.2, 0, 0)).Position, (spitCf * CFrame.new(s * 3.2, 4.4, 0)).Position, 0.18, "oakDark")
	end
	pole(court, "Spit", (spitCf * CFrame.new(-4, 4.2, 0)).Position, (spitCf * CFrame.new(4, 4.2, 0)).Position, 0.1, "iron")
	local carcass = ball(court, "Roast", Vector3.new(4.2, 1.8, 2), spitCf * CFrame.new(0, 4.1, 0), "charred")
	carcass.CanCollide = false
	-- banners on tall poles along the way to the porch, and one down
	for _, b in { { 16, -1326 }, { 50, -1330 }, { -20, -1330 } } do
		pole(court, "BannerPole", Vector3.new(b[1], GROUND, b[2]), Vector3.new(b[1], GROUND + 18, b[2]), 0.25, "oakDark")
		banner(court, CFrame.new(b[1] + 2.4, GROUND + 17, b[2]), 3.6, 8, HERALDRY[rng:NextInteger(1, #HERALDRY)], chance(0.4))
	end
	local fallen = model(court, "FallenBanner")
	pole(fallen, "BannerPole", Vector3.new(-30, GROUND + 0.3, -1270), Vector3.new(-14, GROUND + 0.5, -1279), 0.25, "oakDark")
	local cl = part(fallen, "Cloth", Vector3.new(3.6, 0.08, 6), CFrame.new(-26, GROUND + 0.1, -1274) * CFrame.Angles(0, 0.5, 0), "cloth", HERALDRY[1])
	cl.CanCollide = false
	part(court, "MountingBlock", Vector3.new(3, 1.6, 4), CFrame.new(8, GROUND + 0.8, -1326), "stone")
	part(court, "MountingBlock", Vector3.new(3, 0.8, 2), CFrame.new(8, GROUND + 0.4, -1323.2), "stone")
	clutter(court, Vector3.new(-50, 0, -1305), 28, 26, { "straw", "barrelDown", "plank", "bones", "stone" })
	task.wait()

	-- 5. THE LORD'S GARDEN south of the hall: hurdles, beds gone to seed,
	--    a turf seat, a tree that will not leaf again.
	local garden = model(f, "LordsGarden")
	local gx0, gx1, gz0, gz1 = -70, -26, -1390, -1408 -- west of the hall's side door
	hurdles(garden, Vector3.new(gx0, GROUND, gz0), Vector3.new(gx1, GROUND, gz0), 2.6)
	hurdles(garden, Vector3.new(gx1, GROUND, gz0), Vector3.new(gx1, GROUND, gz1), 2.6)
	hurdles(garden, Vector3.new(gx0 + 10, GROUND, gz1), Vector3.new(gx1, GROUND, gz1), 2.6)
	hurdles(garden, Vector3.new(gx0, GROUND, gz0), Vector3.new(gx0, GROUND, gz1), 2.6)
	for _, x in { -52, -42 } do
		bed(garden, at(x, -1395, 0), 8, 5)
		bed(garden, at(x, -1403, 0), 8, 5)
	end
	deadTree(garden, at(-32, -1399, 0), 24)
	part(garden, "TurfSeat", Vector3.new(7, 1.6, 2.4), CFrame.new(-64, GROUND + 0.8, -1393), "stone")
	local turf = part(garden, "Turf", Vector3.new(6.8, 0.3, 2.2), CFrame.new(-64, GROUND + 1.75, -1393), "thatchOld", Color3.fromRGB(70, 76, 50))
	turf.CastShadow = false

	-- 6. THE CHAMBERLAIN'S HOUSE, a range that burned, one that fell.
	house(f, at(60, -1428, "N"), {
		name = "ChamberlainsHouse",
		W = 20,
		D = 12,
		storeys = 2,
		front = { "window", "door", "window", "window" },
		roof = { kind = "thatch", holes = 0.1 },
		damage = 0.12,
		glow = true,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			prop(m, "Table", B * CFrame.new(4.5, y, -3))
			prop(m, "Chest", B * CFrame.new(-6.8, y, -3.6))
			if info.upperY then
				prop(m, "Bed", B * CFrame.new(3, info.upperY, -3.4), 1.5)
			end
		end,
	})
	house(f, at(-115, -1400, "S"), {
		name = "BurntRange",
		W = 18,
		D = 11,
		storeys = 1,
		burnt = true,
		damage = 0.5,
		front = { "door", "window", "wall", "window" },
		roof = { kind = "thatch", burnt = true },
		furnish = function(m, B, info)
			clutter(m, (B * CFrame.new(0, info.plinthH, 0)).Position, 5, 8, { "plank", "barrelDown", "stone" }, true)
			local ember = fireAt(m, (B * CFrame.new(3, info.plinthH + 1, 1)).Position, 0.8, 22)
			smokeOn(ember, 3, true)
		end,
	})
	ruin(f, at(108, -1420, "N"), 18, 14, 16)
	prop(f, "Cart", at(84, -1418, 30), 1.5)
	prop(f, "Trough", at(72, -1416, 0), 1.5)
	task.wait()

	-- 7. Light.
	roadLanterns(f, road, 38, 9)
	clutter(f, Vector3.new(0, 0, -1360), 140, 30, { "stone", "plank", "stone", "arrow" })
	wallTorches(f, 6)
	clearMarkers(6, f)
end

--------------------------------------------------------------------------
-- Pieces for the Rows
--------------------------------------------------------------------------
-- What the daub was washed with. The Rows were the cheerful street: no two
-- fronts the same colour, and none of them the plain cream of the garrison.
local LIMEWASH = {
	cream = Color3.fromRGB(206, 194, 168),
	ochre = Color3.fromRGB(198, 164, 112),
	rose = Color3.fromRGB(198, 158, 142),
	white = Color3.fromRGB(214, 210, 198),
	grey = Color3.fromRGB(170, 168, 158),
	sage = Color3.fromRGB(166, 172, 142),
	blue = Color3.fromRGB(160, 168, 176),
}

-- A trade sign: a painted board hung square to the wall from an iron
-- bracket, the trade's device on both faces, so the street sees it coming
-- and going. `cf` on the wall face at bracket height, -Z out of the wall.
local function tradeSign(parent: Instance, cf: CFrame, trade: string)
	local m = model(parent, "TradeSign")
	m:SetAttribute("Trade", trade)
	part(m, "Plate", Vector3.new(0.9, 1.6, 0.2), cf * CFrame.new(0, 0, -0.1), "ironDark")
	beam(m, "Bracket", (cf * CFrame.new(0, 0.5, -0.1)).Position, (cf * CFrame.new(0, 0.5, -3.4)).Position, 0.2, 0.2, "ironDark")
	beam(m, "Stay", (cf * CFrame.new(0, -0.7, -0.1)).Position, (cf * CFrame.new(0, 0.45, -2.4)).Position, 0.12, 0.12, "ironDark")
	local H = cf * CFrame.new(0, 0.4, -2.1) * CFrame.Angles(math.rad(jit(5)), 0, 0)
	for _, z in { -0.9, 0.9 } do
		beam(m, "Chain", (H * CFrame.new(0, 0, z)).Position, (H * CFrame.new(0, -0.7, z)).Position, 0.06, 0.06, "ironDark")
	end
	local paint = pick(HERALDRY)
	local board = part(m, "Board", Vector3.new(0.22, 2.2, 2.8), H * CFrame.new(0, -1.85, 0), "planks", shade(paint, 0.8))
	part(m, "Frame", Vector3.new(0.26, 2.4, 0.18), H * CFrame.new(0, -1.85, -1.42), "oakDark")
	part(m, "Frame", Vector3.new(0.26, 2.4, 0.18), H * CFrame.new(0, -1.85, 1.42), "oakDark")
	local D = H * CFrame.new(0, -1.85, 0)
	local gilt = Color3.fromRGB(196, 168, 96)
	for _, s in { -1, 1 } do
		local F = D * CFrame.new(s * 0.14, 0, 0)
		if trade == "tavern" then
			-- the ale-stake's bush and a tankard
			local t = part(m, "Device", Vector3.new(0.08, 0.9, 0.7), F * CFrame.new(0, -0.1, 0), "linen", gilt)
			part(m, "Device", Vector3.new(0.08, 0.5, 0.18), F * CFrame.new(0, -0.05, 0.45), "linen", gilt)
			t.CastShadow = false
		elseif trade == "baker" then
			local l = part(m, "Device", Vector3.new(0.08, 0.9, 0.9), F, "linen", Color3.fromRGB(190, 140, 80))
			;(l :: Part).Shape = Enum.PartType.Cylinder
		elseif trade == "butcher" then
			part(m, "Device", Vector3.new(0.08, 1.0, 0.6), F * CFrame.Angles(math.rad(20), 0, 0), "linen", Color3.fromRGB(150, 70, 60))
		elseif trade == "cobbler" then
			part(m, "Device", Vector3.new(0.08, 0.9, 0.35), F * CFrame.new(0, 0.1, -0.2), "linen", gilt)
			part(m, "Device", Vector3.new(0.08, 0.3, 0.9), F * CFrame.new(0, -0.35, 0.05), "linen", gilt)
		elseif trade == "chandler" then
			part(m, "Device", Vector3.new(0.08, 1.0, 0.25), F * CFrame.new(0, -0.1, 0), "linen", Color3.fromRGB(220, 210, 180))
			part(m, "Device", Vector3.new(0.08, 0.25, 0.15), F * CFrame.new(0, 0.55, 0), "linen", Color3.fromRGB(255, 170, 60))
		elseif trade == "weaver" then
			for k = -1, 1 do
				part(m, "Device", Vector3.new(0.08, 0.9, 0.12), F * CFrame.new(0, 0, k * 0.3), "linen", gilt)
			end
			part(m, "Device", Vector3.new(0.08, 0.12, 0.9), F, "linen", gilt)
		else -- apothecary, and anything else: a pestle in a mortar
			part(m, "Device", Vector3.new(0.08, 0.5, 0.8), F * CFrame.new(0, -0.25, 0), "linen", gilt)
			part(m, "Device", Vector3.new(0.08, 0.8, 0.14), F * CFrame.new(0, 0.2, 0.2) * CFrame.Angles(math.rad(25), 0, 0), "linen", gilt)
		end
	end
	board.CastShadow = true
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	return m
end

-- Bunting: a rope from a to b, sagging, with pennants of faded cloth.
local BUNTING = { Color3.fromRGB(150, 52, 44), Color3.fromRGB(200, 170, 100), Color3.fromRGB(60, 80, 120), Color3.fromRGB(200, 190, 170), Color3.fromRGB(70, 100, 66) }
local function bunting(parent: Instance, a: Vector3, b: Vector3, sag: number)
	local m = model(parent, "Bunting")
	local len = (b - a).Magnitude
	local n = math.max(4, math.floor(len / 1.6))
	local function at3(t: number): Vector3
		return a:Lerp(b, t) - Vector3.new(0, sag * 4 * t * (1 - t), 0)
	end
	for k = 0, n - 1 do
		local p0, p1 = at3(k / n), at3((k + 1) / n)
		local r = beam(m, "Rope", p0, p1, 0.07, 0.07, "burlap")
		r.Color = Color3.fromRGB(110, 92, 66)
		r.CastShadow = false
		if k % 1 == 0 and not chance(0.15) then
			local mid = (p0 + p1) / 2
			local dir = (p1 - p0).Unit
			local flag = wedge(m, "Pennant", Vector3.new(0.05, 1.2, 1.0), CFrame.lookAt(mid, mid + dir) * CFrame.Angles(math.pi, 0, 0) * CFrame.new(0, 0.6, 0), "linen", shade(BUNTING[(k % #BUNTING) + 1], rand(0.75, 1)))
			flag.CastShadow = false
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	return m
end

-- A planter under a window, what grew in it long dead.
local function flowerBox(parent: Instance, cf: CFrame, w: number)
	local m = model(parent, "FlowerBox")
	part(m, "Box", Vector3.new(w, 0.9, 1.0), cf * CFrame.new(0, 0, -0.5), "planks")
	part(m, "Soil", Vector3.new(w - 0.3, 0.1, 0.8), cf * CFrame.new(0, 0.42, -0.5), "dark", Color3.fromRGB(58, 44, 34))
	for x = -w / 2 + 0.4, w / 2 - 0.4, 0.5 do
		if chance(0.7) then
			local st = part(m, "Stem", Vector3.new(0.12, rand(0.4, 1.0), 0.12), cf * CFrame.new(x, 0.75, -0.5 + jit(0.2)) * CFrame.Angles(jit(0.4), 0, jit(0.4)), "hay", Color3.fromRGB(110, 92, 60))
			st.CastShadow = false
		end
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	return m
end

-- The market cross: a stone shaft on steps, under a roof on four oak posts,
-- where bargains were sworn and proclamations read.
local function marketCross(parent: Instance, cf: CFrame)
	local m = model(parent, "MarketCross")
	for k, s in { 9, 7.2 } do
		part(m, "Step", Vector3.new(s, 0.8, s), cf * CFrame.new(0, 0.4 + (k - 1) * 0.8, 0), "stone")
	end
	part(m, "Shaft", Vector3.new(1.2, 8, 1.2), cf * CFrame.new(0, 5.6, 0), "stone")
	part(m, "Head", Vector3.new(2.6, 0.6, 0.6), cf * CFrame.new(0, 9.3, 0), "stone")
	part(m, "Head", Vector3.new(0.6, 1.8, 0.6), cf * CFrame.new(0, 9.5, 0), "stone")
	for _, x in { -3.8, 3.8 } do
		for _, z in { -3.8, 3.8 } do
			pole(m, "Post", (cf * CFrame.new(x, 1.6, z)).Position, (cf * CFrame.new(x, 11, z)).Position, 0.4, "oakDark")
		end
	end
	for _, s in { -1, 1 } do
		beam(m, "Plate", (cf * CFrame.new(-4.4, 11, s * 3.8)).Position, (cf * CFrame.new(4.4, 11, s * 3.8)).Position, 0.7, 0.7, "oakDark")
	end
	roof(m, cf * CFrame.new(0, 11.3, 0), 7.6, 7.6, { kind = "shingles", pitch = 40, overhang = 1.2, gableOver = 0.8 })
	-- a proclamation still nailed to a post, and a bench round the foot
	part(m, "Notice", Vector3.new(0.05, 1.6, 1.2), cf * CFrame.new(3.4, 6, 3.8) * CFrame.Angles(0, math.rad(90), jit(0.1)), "linen", Color3.fromRGB(200, 186, 150)).CanCollide = false
	return m
end

-- The stocks: two posts, the board with its leg holes, the bench behind.
local function stocks(parent: Instance, cf: CFrame)
	local m = model(parent, "Stocks")
	for _, x in { -2.6, 2.6 } do
		beam(m, "Post", (cf * CFrame.new(x, 0, 0)).Position, (cf * CFrame.new(x, 3.4, 0)).Position, 0.6, 0.6, "oakDark")
	end
	part(m, "Board", Vector3.new(5.6, 0.7, 0.4), cf * CFrame.new(0, 1.6, 0), "planks")
	part(m, "Board", Vector3.new(5.6, 0.7, 0.4), cf * CFrame.new(0, 2.32, 0), "planks")
	for _, x in { -1.4, -0.5, 0.5, 1.4 } do
		local hole = part(m, "Hole", Vector3.new(0.42, 0.42, 0.42), cf * CFrame.new(x, 1.96, 0), "dark")
		hole.CastShadow = false
	end
	part(m, "Bench", Vector3.new(5.2, 0.35, 1.2), cf * CFrame.new(0, 1.0, 1.6), "planks")
	for _, x in { -2.2, 2.2 } do
		part(m, "Leg", Vector3.new(0.35, 1.0, 1.0), cf * CFrame.new(x, 0.5, 1.6), "oakDark")
	end
	return m
end

-- A chair with the ropes still on it: where the villager in the Rows is
-- tied (AreaPlan, area 7: 20 seconds of held work to free them). Named and
-- tagged for the mechanic; `SeatPoint` is where the villager sits.
local function prisonerChair(parent: Instance, cf: CFrame)
	local m = model(parent, "PrisonerChair")
	m:SetAttribute("Prisoner", true)
	part(m, "Seat", Vector3.new(2.2, 0.35, 2.1), cf * CFrame.new(0, 2.0, 0), "planks")
	part(m, "Back", Vector3.new(2.2, 3.2, 0.3), cf * CFrame.new(0, 3.75, 0.95), "planks")
	for _, x in { -0.95, 0.95 } do
		for _, z in { -0.85, 0.85 } do
			beam(m, "Leg", (cf * CFrame.new(x, 0, z)).Position, (cf * CFrame.new(x, 1.85, z)).Position, 0.25, 0.25, "oakDark")
		end
	end
	-- the ropes: round the back, and loose coils on the floor
	for _, y in { 2.8, 3.8 } do
		local r = part(m, "Rope", Vector3.new(2.4, 0.18, 0.5), cf * CFrame.new(0, y, 0.95), "burlap", Color3.fromRGB(150, 124, 86))
		r.CastShadow = false
	end
	for k = 0, 2 do
		local c = part(m, "Coil", Vector3.new(0.2, 1.1, 1.1), cf * CFrame.new(-1.6 + k * 0.4, 0.12, -1.4) * CFrame.Angles(0, 0, math.rad(90)), "burlap", Color3.fromRGB(150, 124, 86))
		;(c :: Part).Shape = Enum.PartType.Cylinder
		c.CanCollide = false
		c.CastShadow = false
	end
	local seat = part(m, "SeatPoint", Vector3.new(1, 1, 1), cf * CFrame.new(0, 2.7, 0), "dark")
	seat.Transparency = 1
	seat.CanCollide = false
	seat.CanQuery = false
	return m
end

-- Tankards, a jug: what was on a tavern table.
local function tankards(parent: Instance, cf: CFrame, n: number)
	for _ = 1, n do
		local t = part(parent, "Tankard", Vector3.new(0.75, 0.5, 0.5), cf * CFrame.new(jit(2), 0.38, jit(0.9)) * CFrame.Angles(0, 0, math.rad(90)), "planks", Color3.fromRGB(120, 90, 60))
		;(t :: Part).Shape = Enum.PartType.Cylinder
		t.CanCollide = false
		t.CastShadow = false
	end
end

-- A barrel lying on its side, from the prop.
local function caskOnSide(parent: Instance, cf: CFrame)
	local b = prop(parent, "Barrel", cf)
	if b then
		b:PivotTo(b:GetPivot() * CFrame.Angles(0, 0, math.rad(90)) + Vector3.new(0, -0.6, 0))
	end
	return b
end

-- What a house in the Rows holds. Everything goes in the front-right of the
-- ground floor and the front of the upper: the door is mid-front, the stair
-- foot is reached past the left end wall, and the landing is back-right.
local function rowsFurnish(kind: string?, W: number, D: number)
	return function(m: Model, B: CFrame, info: any)
		local y = info.plinthH + 0.32
		local two = info.upperY ~= nil
		prop(m, "Table", B * CFrame.new(W / 2 - 4.5, y, -D / 2 + 3))
		if two then
			prop(m, "Barrel", B * CFrame.new(-W / 2 + 2.2, y, -D / 2 + 2.4))
			prop(m, "Shelf", B * CFrame.new(W / 2 - 1.3, y, -D / 2 + 3.2) * CFrame.Angles(0, -math.pi / 2, 0))
			prop(m, "Bed", B * CFrame.new(W / 2 - 6, info.upperY, -D / 2 + 3), 1.5)
			prop(m, "Chest", B * CFrame.new(-W / 2 + 5, info.upperY, -D / 2 + 2.2))
		else
			prop(m, "Bed", B * CFrame.new(-W / 2 + 3, y, D / 2 - 3), 1.4)
			prop(m, "Barrel", B * CFrame.new(W / 2 - 1.8, y, D / 2 - 1.8))
		end
		local top = B * CFrame.new(W / 2 - 4.5, y + 2.6, -D / 2 + 3)
		if kind == "baker" then
			prop(m, "BreadBasket", top * CFrame.new(-1.4, 0.1, 0))
			prop(m, "BreadBasket", top * CFrame.new(1.2, 0.1, 0.2))
			prop(m, "Sacks", B * CFrame.new(W / 2 - 2.2, y, 1.6)) -- not by the stair foot
		elseif kind == "butcher" then
			hams(m, B * CFrame.new(W / 2 - 4.5, y + 8, -D / 2 + 3.2), 3)
			local block = part(m, "Block", Vector3.new(2, 2.4, 2), B * CFrame.new(W / 2 - 1.8, y + 1.2, -D / 2 + 1.8), "oakDark")
			block.CanCollide = false
		elseif kind == "chandler" then
			for k = 0, 4 do
				candle(m, (top * CFrame.new(-2 + k * 0.9, 0.1, jit(0.6))).Position, rand(0.8, 1.6), k == 2)
			end
		elseif kind == "cobbler" then
			for k = 0, 3 do
				part(m, "Last", Vector3.new(0.5, 0.45, 1.1), top * CFrame.new(-1.8 + k * 1.1, 0.3, jit(0.5)) * CFrame.Angles(0, jit(0.4), 0), "planks", Color3.fromRGB(90, 60, 40)).CanCollide = false
			end
		elseif kind == "weaver" then
			-- a loom by the front window: frame, beam, the warp still on it
			local L = B * CFrame.new(W / 2 - 4.5, y, -D / 2 + 6.5)
			for _, x in { -2, 2 } do
				beam(m, "LoomPost", (L * CFrame.new(x, 0, 0)).Position, (L * CFrame.new(x, 5, 0)).Position, 0.35, 0.35, "oakDark")
			end
			beam(m, "LoomBeam", (L * CFrame.new(-2.2, 4.6, 0)).Position, (L * CFrame.new(2.2, 4.6, 0)).Position, 0.4, 0.4, "oak")
			local warp = part(m, "Warp", Vector3.new(3.6, 3.4, 0.06), L * CFrame.new(0, 2.8, 0), "linen", LIMEWASH.blue)
			warp.Transparency = 0.25
			warp.CanCollide = false
		elseif kind == "apothecary" then
			for k = 0, 5 do
				local jar = part(m, "Jar", Vector3.new(0.7, 0.45, 0.45), top * CFrame.new(-2 + k * 0.75, 0.45, jit(0.5)) * CFrame.Angles(0, 0, math.rad(90)), "stone", shade(CLAY, rand(0.8, 1.2)))
				;(jar :: Part).Shape = Enum.PartType.Cylinder
				jar.CanCollide = false
			end
		end
	end
end

--------------------------------------------------------------------------
-- AREA 7 — THE ROWS. Two streets of the servants' houses, the market square
-- between them with its cross, its stalls and its stocks, the market hall,
-- and the tavern. The only place in the castle that was ever cheerful: the
-- fronts are washed in colours, there are signs over the doors, flowers that
-- died in the boxes, bunting nobody took down. Narrow, so the dead come a
-- few at a time and keep coming. The villager is tied to a chair in the
-- tavern (AreaPlan, area 7).
--------------------------------------------------------------------------
local function area7()
	local f = areaFolder(7)
	local zNear, zFar = Castle.chamberBounds(7)
	local road = { Vector2.new(-153, zNear - 16), Vector2.new(-146, -1520), Vector2.new(-122, -1542), Vector2.new(-60, -1546), Vector2.new(0, -1546), Vector2.new(0, -1585), Vector2.new(0, -1630), Vector2.new(8, -1662), Vector2.new(100, -1664), Vector2.new(138, -1684), Vector2.new(153, zFar + 14) }
	local upperRow = { Vector2.new(-122, -1546), Vector2.new(72, -1546) }
	local lowerRow = { Vector2.new(-100, -1662), Vector2.new(100, -1664) }
	paintGround(zNear - 2, zFar + 2, {
		{ path = road, width = 10, material = Enum.Material.Cobblestone, verge = Enum.Material.Mud },
		{ path = upperRow, width = 10, material = Enum.Material.Cobblestone, verge = Enum.Material.Mud },
		{ path = lowerRow, width = 10, material = Enum.Material.Cobblestone, verge = Enum.Material.Mud },
	}, { { Vector2.new(20, -1700), 14 }, { Vector2.new(-60, -1700), 10 } }, {
		{ x0 = -46, x1 = 46, z0 = -1637, z1 = -1574, material = Enum.Material.Cobblestone, alt = Enum.Material.Cobblestone },
		{ x0 = -10, x1 = 40, z0 = -1712, z1 = -1684, material = Enum.Material.LeafyGrass, alt = Enum.Material.Mud },
	})
	task.wait()

	--[[
		The houses, every one written out (HouseAnatomy.md: on a street the
		player walks down, two identical neighbours is exactly the repetition
		you notice). Upper Row fronts at z -1539 (north side, facing south)
		and -1553 (south side, facing north); Lower Row at -1655 and -1669.
		`gable`: the end wall faces the street (the narrow burgage front), the
		door in it.
	]]
	-- n name, x/z centre, face, W x D, st storeys, roof, wash, trade, jetty, damage, burnt, ground, gable
	local specs: { any } = {
		-- Upper Row, north side
		{ n = "CobblersHouse", x = -73, z = -1533, face = "S", W = 20, D = 12, st = 2, roof = { kind = "thatch", chimneyX = 8.6 }, wash = LIMEWASH.cream, trade = "cobbler", jetty = 1.4, glow = true },
		{ n = "BakersHouse", x = -50, z = -1529, face = "E", W = 20, D = 12, st = 2, roof = { kind = "shingles", pitch = 46 }, wash = LIMEWASH.rose, trade = "baker", gable = true },
		{ n = "ChandlersShop", x = -28, z = -1533.5, face = "S", W = 16, D = 11, st = 1, roof = { kind = "shingles", pitch = 42 }, wash = LIMEWASH.ochre, trade = "chandler" },
		{ n = "WeaversHouse", x = 28, z = -1533, face = "S", W = 20, D = 12, st = 2, roof = { kind = "thatch" }, wash = LIMEWASH.sage, trade = "weaver", jetty = 1.8 },
		-- Upper Row, south side
		{ n = "LaundressHouse", x = -128, z = -1559, face = "N", W = 20, D = 12, st = 1, roof = { kind = "thatch", holes = 0.08 }, wash = LIMEWASH.white, damage = 0.12 },
		{ n = "ButchersHouse", x = -104, z = -1563, face = "W", W = 20, D = 12, st = 2, roof = { kind = "thatch" }, wash = LIMEWASH.grey, trade = "butcher", gable = true },
		{ n = "SaltStore", x = -82, z = -1558.5, face = "N", W = 16, D = 11, st = 1, roof = { kind = "shingles", pitch = 38 }, wash = LIMEWASH.cream, ground = "stone" },
		{ n = "ApothecarysHouse", x = -36, z = -1559, face = "N", W = 20, D = 12, st = 2, roof = { kind = "shingles", pitch = 44 }, wash = LIMEWASH.blue, trade = "apothecary", jetty = 1.6, glow = true },
		{ n = "Cottage", x = 24, z = -1562, face = "W", W = 18, D = 12, st = 1, roof = { kind = "thatch", holes = 0.15 }, wash = LIMEWASH.ochre, gable = true, damage = 0.2 },
		{ n = "CarpentersHouse", x = 48, z = -1559, face = "N", W = 20, D = 12, st = 1, roof = { kind = "thatch", chimneyX = -8.6 }, wash = LIMEWASH.rose },
		-- Lower Row, north side
		{ n = "Cottage", x = -84, z = -1649.5, face = "S", W = 16, D = 11, st = 1, roof = { kind = "thatch" }, wash = LIMEWASH.grey },
		{ n = "PottersHouse", x = -52, z = -1645, face = "E", W = 20, D = 12, st = 2, roof = { kind = "shingles", pitch = 48 }, wash = LIMEWASH.cream, gable = true },
		{ n = "TailorsHouse", x = 30, z = -1649, face = "S", W = 20, D = 12, st = 2, roof = { kind = "thatch" }, wash = LIMEWASH.blue, trade = "weaver", jetty = 1.6 },
		-- Lower Row, south side
		{ n = "BrewersHouse", x = -80, z = -1675, face = "N", W = 20, D = 12, st = 2, roof = { kind = "thatch", chimneyX = 8.6 }, wash = LIMEWASH.ochre, glow = true },
		{ n = "BurntCottage", x = -50, z = -1674.5, face = "N", W = 16, D = 11, st = 1, roof = { kind = "thatch", burnt = true }, wash = LIMEWASH.white, burnt = true, damage = 0.5 },
		{ n = "ClerksHouse", x = -20, z = -1679, face = "W", W = 20, D = 12, st = 2, roof = { kind = "shingles", pitch = 44 }, wash = LIMEWASH.white, gable = true },
		{ n = "WidowsHouse", x = 52, z = -1675, face = "N", W = 20, D = 12, st = 1, roof = { kind = "thatch", holes = 0.2 }, wash = LIMEWASH.rose, damage = 0.25 },
	}
	local res = reserver()
	res.marks(7, 10)
	for _, s in specs do
		local B = at(s.x, s.z, s.face)
		local nW = math.max(2, math.floor(s.W / 4.6))
		local nD = math.max(2, math.floor(s.D / 4.6))
		local o: any = {
			name = s.n, W = s.W, D = s.D, storeys = s.st, roof = s.roof, limewash = s.wash,
			jetty = s.jetty or (if s.gable then 0.6 else 1.2), damage = s.damage or 0.06, burnt = s.burnt, ground = s.ground,
			glow = s.glow == true, furnish = if s.burnt then nil else rowsFurnish(s.trade, s.W, s.D),
			-- a door in the street end lies back toward the front, not across
			-- the foot of the stair (which is just inside that end)
			hingeRight = s.gable,
		}
		if s.gable then
			-- the street sees the end wall: the door in it, front half
			o.left = if nD >= 3 then { "window", "window", "door" } else { "window", "door" }
			o.front = table.create(nW, "wall")
			o.front[2] = "window"
		else
			o.front = table.create(nW, "window")
			o.front[if nW >= 4 then 2 else math.ceil(nW / 2)] = "door"
		end
		house(f, B, o)
		-- the street face: where the sign, the butt and the flowers go
		local face = if s.gable then B * CFrame.new(-s.W / 2, 0, 0) * CFrame.Angles(0, math.pi / 2, 0) else B * CFrame.new(0, 0, -s.D / 2)
		local faceW = if s.gable then s.D else s.W
		-- the window the flowers go under: the last bay of a front, the back
		-- bay of a street end (the door has the front one)
		local winX = if s.gable then -(faceW / 2 - faceW / nD / 2) else faceW / 2 - faceW / nW / 2
		if s.trade then
			tradeSign(f, face * CFrame.new(faceW / 2 - 2.2, (s.st > 1 and 9.8 or 8.6), 0), s.trade)
		end
		if not s.burnt then
			prop(f, "Barrel", face * CFrame.new(-faceW / 2 + 1.4, 0, -1.6), 1.1)
			if chance(0.6) then
				flowerBox(f, face * CFrame.new(winX, 1.6 + 3.1, -0.3), 3.2)
			end
		end
	end
	task.wait()

	-- THE MARKET HALL on the west of the square: an open arcade of stone
	-- below where the stalls stood in the wet, the guild's room above.
	house(f, at(-64, -1606, "E"), {
		name = "MarketHall",
		W = 24,
		D = 14,
		storeys = 2,
		ground = "stone",
		front = { "bay", "bay", "bay", "bay", "bay" },
		upperFront = { "window", "window", "window", "window", "window" },
		roof = { kind = "shingles", pitch = 44 },
		limewash = LIMEWASH.white,
		glow = true,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			-- the weighing beam, sacks and crates on the right; the left kept open
			prop(m, "Sacks", B * CFrame.new(6, y, -2.5))
			prop(m, "Crate", B * CFrame.new(8.6, y, 0.5))
			beam(m, "ScaleBeam", (B * CFrame.new(1.6, y, -3)).Position, (B * CFrame.new(1.6, y + 6.5, -3)).Position, 0.4, 0.4, "oakDark")
			beam(m, "ScaleArm", (B * CFrame.new(-0.6, y + 6.3, -3)).Position, (B * CFrame.new(3.8, y + 6.3, -3)).Position, 0.25, 0.25, "iron")
			for _, x in { -0.4, 3.6 } do
				local pan = part(m, "Pan", Vector3.new(0.15, 1.4, 1.4), B * CFrame.new(x, y + 4.4, -3) * CFrame.Angles(0, 0, math.rad(90)), "iron", Color3.fromRGB(150, 120, 80))
				;(pan :: Part).Shape = Enum.PartType.Cylinder
				pan.CanCollide = false
			end
			if info.upperY then
				prop(m, "Table", B * CFrame.new(4, info.upperY, -4), 1.3)
				prop(m, "Chest", B * CFrame.new(-6, info.upperY, -5))
				banner(m, B * CFrame.new(4, info.upperY + 7, -6.6), 3, 5, HERALDRY[4])
			end
		end,
	})
	res.rect(-72, -1620, -55, -1592)

	-- THE TAVERN on the east of the square.
	local tavB = at(64, -1606, "W")
	house(f, tavB, {
		name = "Tavern",
		W = 26,
		D = 16,
		storeys = 2,
		front = { "window", "door", "window", "door", "window" },
		upperFront = { "window", "window", "window", "window", "window" },
		roof = { kind = "thatch", chimneyX = 11.4 },
		limewash = LIMEWASH.ochre,
		jetty = 1.6,
		glow = true,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			-- the hearth against the end stack, the bar along the back right,
			-- casks behind it; two tables in the front, and the chair
			hearth(m, B * CFrame.new(10.2, y, 0) * CFrame.Angles(0, math.pi / 2, 0), 6, true)
			part(m, "Bar", Vector3.new(6, 3.2, 1.4), B * CFrame.new(5.6, y + 1.6, 3.6), "planks")
			part(m, "BarTop", Vector3.new(6.4, 0.3, 1.8), B * CFrame.new(5.6, y + 3.35, 3.6), "oakDark")
			for k = 0, 1 do
				caskOnSide(m, B * CFrame.new(3.6 + k * 3.4, y + 0.3, 6))
			end
			tankards(m, B * CFrame.new(5.6, y + 3.5, 3.6), 4)
			-- (the doors are at x -5.2 and 5.2: the tables stand between and
			-- beyond them, never behind one)
			-- (the left door opens into the room's widest part: a table there
			-- made a funnel the pathfinder would not go through)
			for _, t in { { 0, 5 }, { 10.2, 3.6 } } do
				trestle(m, B * CFrame.new(t[1], y, -5.4), t[2])
				tankards(m, B * CFrame.new(t[1], y + 3.2, -5.4), 2)
			end
			bench(m, B * CFrame.new(0, y, -2.9), 4.4, chance(0.3))
			bench(m, B * CFrame.new(-11.4, y, -4.2) * CFrame.Angles(0, math.pi / 2, 0), 4.4)
			-- the chair in the open floor, facing the doors
			prisonerChair(m, B * CFrame.new(-6, y, -1.2) * CFrame.Angles(0, math.rad(190), 0))
			if info.upperY then
				for k = 0, 2 do
					prop(m, "Bed", B * CFrame.new(-6 + k * 5.5, info.upperY, -4.6), 1.5)
				end
				prop(m, "Chest", B * CFrame.new(9.8, info.upperY, -5.4))
				m:SetAttribute("UpperProbe", (B * CFrame.new(-8, info.upperY + 2.5, 0)).Position) -- between the beds and the stair
			end
		end,
	})
	res.rect(54, -1621, 74, -1591)
	local tavFace = tavB * CFrame.new(0, 0, -8)
	tradeSign(f, tavFace * CFrame.new(-3, 9.6, -0.1), "tavern")
	-- the ale-stake over the door and the benches outside
	pole(f, "AleStake", (tavFace * CFrame.new(5.2, 9, 0)).Position, (tavFace * CFrame.new(5.2, 9.6, -4.5)).Position, 0.18, "oakDark")
	local bush = ball(f, "AleBush", Vector3.new(1.8, 1.6, 1.8), tavFace * CFrame.new(5.2, 8.6, -4.6), "thatchOld", Color3.fromRGB(80, 84, 56))
	bush.CanCollide = false
	for _, z in { -10.5, 10.5 } do -- clear of both doors (at -5.2 and 5.2) and their steps
		trestle(f, tavFace * CFrame.new(z, 0, -6), 6)
		bench(f, tavFace * CFrame.new(z, 0, -8.1), 5)
		tankards(f, tavFace * CFrame.new(z, 3.2, -6), 2)
	end
	prop(f, "Barrel", tavFace * CFrame.new(-11.5, 0, -2))
	caskOnSide(f, tavFace * CFrame.new(-11.5, 0.4, -4.5))
	task.wait()

	-- THE SQUARE: the cross, the stalls, the stocks, a cart, the bunting.
	local sq = model(f, "MarketSquare")
	marketCross(sq, at(-22, -1614, 10))
	for _, st in { { -28, -1586, "S" }, { 24, -1588, "S" }, { 30, -1628, "N" } } do
		local stall = openShed(sq, at(st[1], st[2], st[3]), 10, 7, 7, { kind = "shingles", pitch = 30, holes = 0.25 })
		stall.Name = "Stall"
		local SB = at(st[1], st[2], st[3])
		prop(stall, "Table", SB * CFrame.new(0, 0, -1.6), 1.2)
		prop(stall, "Sacks", SB * CFrame.new(3.4, 0, 2))
		prop(stall, "Barrel", SB * CFrame.new(-3.6, 0, 2))
		if chance(0.5) then
			prop(stall, "BreadBasket", SB * CFrame.new(-1, 3.1, -1.6))
		else
			-- bolts of cloth, faded
			for k = 0, 2 do
				local bolt = part(stall, "Bolt", Vector3.new(2.4, 0.7, 0.7), SB * CFrame.new(-1.2 + k * 1.0, 3.5, -1.6) * CFrame.Angles(0, math.rad(90), 0), "linen", shade(BUNTING[k + 1], 0.8))
				;(bolt :: Part).Shape = Enum.PartType.Cylinder
				bolt.CanCollide = false
			end
		end
	end
	stocks(sq, at(16, -1620, "W"))
	prop(sq, "Cart", at(-36, -1628, 30), 1.5)
	prop(sq, "Wheelbarrow", at(36, -1606, -20), 1.3)
	clutter(sq, Vector3.new(0, 0, -1606), 34, 26, { "straw", "plank", "stone", "barrelDown", "crate" })
	local y = GROUND + 11
	-- strung from front to front, only where there is a house each side
	bunting(sq, Vector3.new(-57, y, -1598), Vector3.new(54, y, -1600), 4)
	bunting(sq, Vector3.new(-57, y, -1614), Vector3.new(54, y, -1612), 4.5)
	bunting(f, Vector3.new(-77, y, -1540.5), Vector3.new(-77, y, -1552.6), 1.2)
	bunting(f, Vector3.new(-30, y, -1539.4), Vector3.new(-32, y, -1552.6), 1.2)
	bunting(f, Vector3.new(24, y, -1540.9), Vector3.new(24, y, -1552.6), 1.2)
	bunting(f, Vector3.new(-84, y, -1655.4), Vector3.new(-84, y, -1668.6), 1.2)
	bunting(f, Vector3.new(36, y, -1656.7), Vector3.new(47, y, -1668.6), 1.5)
	task.wait()

	-- THE YARDS behind and between: hurdles round the gardens, a privy, a
	-- woodpile, a hen house, the trees that died.
	local yards = model(f, "Yards")
	local function garden(x0: number, z0: number, x1: number, z1: number)
		hurdles(yards, Vector3.new(x0, GROUND, z0), Vector3.new(x1, GROUND, z0), 2.6)
		hurdles(yards, Vector3.new(x1, GROUND, z0), Vector3.new(x1, GROUND, z1), 2.6)
		hurdles(yards, Vector3.new(x0 + 6, GROUND, z1), Vector3.new(x1, GROUND, z1), 2.6)
		for x = x0 + 5, x1 - 5, 9 do
			bed(yards, at(x, (z0 + z1) / 2, 0), 7, math.abs(z1 - z0) - 6)
		end
	end
	garden(-6, -1690, 38, -1708) -- behind the Lower Row
	garden(46, -1524, 70, -1510) -- the empty plot on the Upper Row
	local privy = model(yards, "Privy")
	local PB = at(-36, -1702, 0)
	for _, x in { -1.6, 1.6 } do
		for _, z in { -1.6, 1.6 } do
			beam(privy, "Post", (PB * CFrame.new(x, 0, z)).Position, (PB * CFrame.new(x, 6.5, z)).Position, 0.4, 0.4, "oakDark")
		end
	end
	for _, s in { { 0, -1.6 }, { 0, 1.6 }, { 1.6, 0 } } do
		part(privy, "Boards", if s[1] == 0 then Vector3.new(3.2, 6, 0.25) else Vector3.new(0.25, 6, 3.2), PB * CFrame.new(s[1], 3, s[2]), "planks")
	end
	part(privy, "Roof", Vector3.new(4.2, 0.4, 4.2), PB * CFrame.new(0, 6.8, 0) * CFrame.Angles(math.rad(10), 0, 0), "shingles")
	local hens = leanTo(yards, at(80, -1530, "S"), 8, 4, 4.6, 3, { kind = "thatch", sides = true })
	hens.Name = "HenHouse"
	clutter(hens, Vector3.new(80, 0, -1530), 3, 6, { "straw", "straw" }, true)
	for _, w in { { -40, -1640 }, { -10, -1696 }, { -112, -1680 } } do
		prop(yards, "Firewood", at(w[1], w[2], rand(0, 360)), 1.3)
	end
	for _, t in { { -100, -1700, 22 }, { 40, -1517, 20 }, { -6, -1525, 18 } } do
		deadTree(yards, at(t[1], t[2], 0), t[3])
	end
	prop(yards, "Cart", at(-30, -1652, 70), 1.4)
	task.wait()

	-- Light, litter, the walls.
	roadLanterns(f, road, 34, 8)
	clutter(f, Vector3.new(0, 0, -1600), 140, 34, { "stone", "straw", "plank", "stone" })
	wallTorches(f, 7)
	clearMarkers(7, f)
end

--------------------------------------------------------------------------
-- Pieces for the Inner Ward
--------------------------------------------------------------------------

-- A palisade of sharpened logs from a to b (on the ground), binding rails
-- behind, `gaps` ({from, to} in studs along it) where it is down.
local function palisade(parent: Instance, a: Vector3, b: Vector3, h: number, gaps: { { number } }?)
	local m = model(parent, "Palisade")
	local len = (b - a).Magnitude
	local dir = (b - a).Unit
	local base = CFrame.lookAt(a, b)
	local function down(t: number): boolean
		for _, g in gaps or {} do
			if t > g[1] and t < g[2] then
				return true
			end
		end
		return false
	end
	local t = 0.6
	while t < len do
		if down(t) then
			if chance(0.3) then
				-- a log pulled out and lying where it fell
				local p = base * CFrame.new(rand(-3, 3), 0.6, -t)
				pole(m, "Log", (p * CFrame.new(-h * 0.4, 0, 0)).Position, (p * CFrame.new(h * 0.4, 0, rand(-2, 2))).Position, 0.55, "oakDark")
			end
		else
			local r = rand(0.5, 0.65)
			local lh = h + jit(0.8)
			local foot = (base * CFrame.new(0, -0.5, -t)).Position
			local top = foot + Vector3.new(jit(0.15), lh, jit(0.15))
			pole(m, "Log", foot, top, r, "oakDark").Color = shade(Color3.fromRGB(86, 72, 60), rand(0.85, 1.1))
			local pt = part(m, "Point", Vector3.new(r * 1.6, 1.2, r * 1.6), CFrame.new(top + Vector3.new(0, 0.5, 0)) * CFrame.Angles(0, rand(0, 6), 0), "oak")
			pt.CastShadow = false
		end
		t += 1.25
	end
	-- the binding rails behind, run by run
	local runStart = 0
	local function rails(t0: number, t1: number)
		if t1 - t0 < 2 then
			return
		end
		-- on the inside face (the right-hand side looking from a to b is
		-- outside; the rails go on the left)
		local inside = -base.RightVector * 0.9
		for _, y in { 2.2, h - 1.8 } do
			beam(m, "Rail", (base * CFrame.new(0, y, -t0)).Position + inside, (base * CFrame.new(0, y, -t1)).Position + inside, 0.5, 0.6, "oak")
		end
	end
	local sorted = table.clone(gaps or {})
	table.sort(sorted, function(x, y)
		return x[1] < y[1]
	end)
	for _, g in sorted do
		rails(runStart, g[1])
		runStart = g[2]
	end
	rails(runStart, len)
	return m
end

-- A stand of arms: spears leant together in a cone, the way a camp kept them.
local function standOfArms(parent: Instance, cf: CFrame, n: number)
	local m = model(parent, "StandOfArms")
	local top = (cf * CFrame.new(0, 7.5, 0)).Position
	for k = 0, n - 1 do
		local a = k / n * math.pi * 2 + jit(0.2)
		local foot = (cf * CFrame.new(math.cos(a) * 2.4, 0, math.sin(a) * 2.4)).Position
		local tip = foot + (top - foot).Unit * 9.5
		pole(m, "Spear", foot, tip, 0.09, "oak")
		local head = part(m, "Head", Vector3.new(0.18, 1.2, 0.4), CFrame.lookAt(tip, tip + (tip - foot).Unit) * CFrame.Angles(math.rad(-90), 0, 0) * CFrame.new(0, 0.55, 0), "ironDark")
		head.CastShadow = false
	end
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.CanCollide = false
		end
	end
	return m
end

-- A mangonel: the frame, the uprights, the throwing arm. `broken`: the arm
-- snapped and the frame racked over.
local function mangonel(parent: Instance, cf: CFrame, broken: boolean)
	local m = model(parent, "Mangonel")
	for _, x in { -2.4, 2.4 } do
		beam(m, "Rail", (cf * CFrame.new(x, 0.6, -7)).Position, (cf * CFrame.new(x, 0.6, 7)).Position, 0.9, 1.0, "oakDark")
		beam(m, "Upright", (cf * CFrame.new(x, 0.6, 0)).Position, (cf * CFrame.new(x, 9, 0.8)).Position, 0.8, 0.8, "oakDark")
		beam(m, "Strut", (cf * CFrame.new(x, 0.6, 5)).Position, (cf * CFrame.new(x, 8, 1)).Position, 0.5, 0.5, "oak")
		local wheel = part(m, "Wheel", Vector3.new(0.5, 3.2, 3.2), cf * CFrame.new(x * 1.25, 1.6, -5), "oakDark")
		;(wheel :: Part).Shape = Enum.PartType.Cylinder
	end
	for _, z in { -6.5, 6.5 } do
		beam(m, "Cross", (cf * CFrame.new(-2.9, 0.6, z)).Position, (cf * CFrame.new(2.9, 0.6, z)).Position, 0.7, 0.8, "oakDark")
	end
	pole(m, "Axle", (cf * CFrame.new(-3, 8.6, 0.6)).Position, (cf * CFrame.new(3, 8.6, 0.6)).Position, 0.35, "iron")
	if broken then
		-- the arm snapped at the axle: the long half on the ground in front
		beam(m, "Arm", (cf * CFrame.new(0, 8.6, 0.6)).Position, (cf * CFrame.new(0.4, 12, 4.5)).Position, 0.7, 0.8, "oak")
		beam(m, "Arm", (cf * CFrame.new(0.8, 0.5, -9)).Position, (cf * CFrame.new(-1.5, 0.8, -20)).Position, 0.7, 0.8, "oak")
	else
		beam(m, "Arm", (cf * CFrame.new(0, 8.6, 0.6)).Position, (cf * CFrame.new(0, 17, -9)).Position, 0.7, 0.8, "oak")
	end
	part(m, "Counterweight", Vector3.new(3.2, 3, 3), cf * CFrame.new(0, 5.4, 3.4), "planks")
	-- a stone it never threw
	ball(m, "Shot", Vector3.new(2.2, 2.2, 2.2), cf * CFrame.new(3.6, 1.1, -3), "stone")
	return m
end

-- A camp cot: a frame, a stretched cloth, a blanket.
local function cot(parent: Instance, cf: CFrame)
	local m = model(parent, "Cot")
	for _, x in { -0.9, 0.9 } do
		beam(m, "Pole", (cf * CFrame.new(x, 1.4, -3)).Position, (cf * CFrame.new(x, 1.4, 3)).Position, 0.2, 0.2, "oak")
		for _, z in { -2.6, 2.6 } do
			beam(m, "Leg", (cf * CFrame.new(x, 0, z)).Position, (cf * CFrame.new(x * 0.6, 1.4, z)).Position, 0.15, 0.15, "oak")
		end
	end
	part(m, "Cloth", Vector3.new(1.8, 0.08, 5.8), cf * CFrame.new(0, 1.42, 0), "linen", Color3.fromRGB(170, 160, 140))
	part(m, "Blanket", Vector3.new(1.9, 0.18, 2.6), cf * CFrame.new(0, 1.55, 1.2) * CFrame.Angles(0, jit(0.1), jit(0.05)), "burlap", Color3.fromRGB(96, 80, 64))
	return m
end

-- A climbing slope of fallen masonry: an invisible ramp to walk on, the
-- stones heaped over it to see.
local function rubbleSlope(parent: Instance, foot: Vector3, dir: Vector3, rise: number, run: number, width: number)
	local m = model(parent, "RubbleSlope")
	ramp(m, foot, dir, rise, run, width)
	local flat = Vector3.new(dir.X, 0, dir.Z).Unit
	local side = flat:Cross(Vector3.yAxis)
	for _ = 1, math.floor(run * width / 5) do
		local t = rng:NextNumber()
		local p = foot + flat * (run * t) + side * jit(width / 2 + 1.5)
		local s = rand(1, 2.6)
		local y = rise * t
		local st = part(m, "Rubble", Vector3.new(s, s * rand(0.5, 0.9), s * rand(0.7, 1.2)), CFrame.new(p + Vector3.new(0, y - s * 0.3, 0)) * CFrame.Angles(jit(0.5), rand(0, 6), jit(0.5)), if chance(0.6) then "rubble" else "stone")
		st.CanCollide = false
		st.CastShadow = false
	end
	return m
end

--[[
	The tower that came down: its stump still standing, and the shaft lying
	across the yard in great drums of masonry, the crown with its merlons
	smashed at the far end. Its top is the only high ground in the ward, and
	the only ways up are the two slopes of rubble at its ends: where the dead
	have to funnel (AreaPlan, area 8). B: the stump's centre on the ground,
	the shaft lying along +X.
]]
local function fallenTower(parent: Instance, B: CFrame, segments: number)
	local m = model(parent, "FallenTower")
	local S, SH, SL = 18, 16, 22 -- the shaft's section and height, a drum's length
	-- the walking surface: just over the highest a rolled drum's edge can lift
	local DECK = SH + 0.25
	-- the stump: four walls to a ragged top, hollow, rubble inside
	for _, w in { { 0, -1, 0 }, { 0, 1, 180 }, { -1, 0, 90 }, { 1, 0, -90 } } do
		local F = B * CFrame.new(w[1] * 10, 0, w[2] * 10) * CFrame.Angles(0, math.rad(w[3]), 0)
		for k = 0, 7 do
			local x = -10 + (k + 0.5) * 2.5
			local h = (if w[1] > 0 then 9 else 16) + rand(-5, 6) * (if k == 0 or k == 7 then 0.4 else 1)
			part(m, "Masonry", Vector3.new(2.52, h, 2.4), F * CFrame.new(x, h / 2, 1.2), "rubble")
		end
	end
	for _ = 1, 10 do
		local s = rand(1.5, 3.5)
		part(m, "Rubble", Vector3.new(s, s * 0.7, s), B * CFrame.new(jit(6), s * 0.3, jit(6)) * CFrame.Angles(jit(0.6), rand(0, 6), jit(0.6)), "rubble").CastShadow = false
	end
	-- the drums, lying end to end
	local x0 = 12
	local deckFrom, deckTo = x0, x0
	for i = 1, segments do
		local cx = x0 + (i - 0.5) * (SL + 0.4)
		-- each drum came to rest a little turned and rolled: the walking
		-- surface is the invisible deck below, so the stone may sit untrue
		local D = B * CFrame.new(cx, 0, jit(1.0)) * CFrame.Angles(math.rad(jit(1.2)), math.rad(jit(2.5)), 0)
		local core = part(m, "Drum", Vector3.new(SL, SH, S), D * CFrame.new(0, SH / 2, 0), "rubble")
		core.CastShadow = true
		-- its loops and windows, lying on their sides now: long along the
		-- shaft, on the flanks and on what is now its top
		for _, s in { -1, 1 } do
			for k = -1, 1 do
				local slot = part(m, "Loop", Vector3.new(if k == 0 then 3.4 else 2.2, if k == 0 then 1.4 else 0.7, 0.2), D * CFrame.new(k * 6.5, SH * (if s > 0 then 0.5 else 0.6), s * (S / 2 + 0.02)), "dark")
				slot.CastShadow = false
			end
		end
		for k = -1, 1, 2 do
			local w = part(m, "Window", Vector3.new(3.6, 0.1, 1.6), D * CFrame.new(k * 5, SH + 0.03, jit(4)), "dark")
			w.CastShadow = false
			w.CanCollide = false
		end
		-- the string courses that ringed the standing tower at each floor now
		-- run round the drum like hoops
		for _, ex in { -SL / 2 + 0.7, SL / 2 - 0.7 } do
			for _, s in { -1, 1 } do
				part(m, "Course", Vector3.new(0.9, SH, 0.45), D * CFrame.new(ex, SH / 2, s * (S / 2 + 0.2)), "stone").CastShadow = false
			end
			local over = part(m, "Course", Vector3.new(0.9, 0.3, S + 0.9), D * CFrame.new(ex, SH + 0.12, 0), "stone")
			over.CanCollide = false
			over.CastShadow = false
		end
		-- the broken joint: loose stones and a floor beam's end
		for _ = 1, 5 do
			local s = rand(1, 2.4)
			part(m, "Rubble", Vector3.new(s, s * 0.7, s), D * CFrame.new(-SL / 2 + jit(1), rand(1, SH), rand(-S / 2, S / 2)) * CFrame.Angles(jit(0.6), rand(0, 6), jit(0.6)), "rubble").CastShadow = false
		end
		beam(m, "FloorBeam", (D * CFrame.new(SL / 2 - 0.5, SH * rand(0.3, 0.7), rand(-6, 6))).Position, (D * CFrame.new(SL / 2 + 2.5, SH * rand(0.2, 0.6), rand(-6, 6))).Position, 0.9, 0.9, "charred")
		deckTo = x0 + i * (SL + 0.4)
	end
	-- one walking surface along the whole top, so the joints are no gaps
	local deck = part(m, "Walk", Vector3.new(deckTo - deckFrom, 0.6, S - 1), B * CFrame.new((deckFrom + deckTo) / 2, DECK - 0.3, 0), "dark")
	deck.Transparency = 1
	deck.CastShadow = false
	-- the crown at the far end: merlons broken off and thrown sideways
	local cx = deckTo + 4
	for k = 0, 5 do
		local s = if k % 2 == 0 then 1 else -1
		local mer = part(m, "Merlon", Vector3.new(3.4, 4.5, 2.6), B * CFrame.new(cx + rand(0, 8), 2.2, s * rand(7, 12)) * CFrame.Angles(jit(0.6), rand(0, 6), jit(0.5)), "rubble")
		mer.CastShadow = true
	end
	-- the two ways up: rubble at the stump end, from the north, and at the
	-- crown end, from the east
	rubbleSlope(m, (B * CFrame.new(x0 + 8, 0, S / 2 + 24)).Position, B.LookVector, DECK, 24, 7)
	rubbleSlope(m, (B * CFrame.new(deckTo + 30, 0, 0)).Position, B.RightVector * -1, DECK, 30, 8)
	-- what lies on top: a broken banner pole, a shield, arrows
	pole(m, "BannerPole", (B * CFrame.new(x0 + 30, SH, 3)).Position, (B * CFrame.new(x0 + 41, SH + 0.6, 6)).Position, 0.2, "oakDark")
	return m, deckFrom, deckTo
end

--------------------------------------------------------------------------
-- AREA 8 — THE INNER WARD. The last line: a palisade across the ward with
-- its gate and two breaches, a firing step behind it, stakes before it;
-- the camp it guarded (the field hospital, the command tent, the stands of
-- arms, a broken mangonel); the marshal's house on the near side; and the
-- tower that came down across the yard, the only high ground, reached by two
-- slopes of rubble. The passage out is half buried (AreaPlan, area 8).
--------------------------------------------------------------------------
local function area8()
	local f = areaFolder(8)
	local zNear, zFar = Castle.chamberBounds(8)
	local road = { Vector2.new(153, zNear - 16), Vector2.new(128, -1776), Vector2.new(80, -1800), Vector2.new(40, -1824), Vector2.new(20, -1845), Vector2.new(-30, -1866), Vector2.new(-95, -1880), Vector2.new(-118, -1900), Vector2.new(-140, -1925), Vector2.new(-150, -1945), Vector2.new(-153, zFar + 14) }
	local LINE_Z = -1824
	paintGround(zNear - 2, zFar + 2, {
		{ path = road, width = 11, material = Enum.Material.Mud, verge = Enum.Material.Ground },
		{ path = { Vector2.new(-150, LINE_Z - 6), Vector2.new(150, LINE_Z - 6) }, width = 8, material = Enum.Material.Mud },
	}, { { Vector2.new(-90, -1870), 22 }, { Vector2.new(60, -1862), 20 }, { Vector2.new(-10, -1905), 34 }, { Vector2.new(-60, -1795), 16 } })
	task.wait()

	-- 1. THE LINE. Palisade 10 high along z -1824, gate at x 30..50, breaches.
	local line = model(f, "TheLine")
	local A, Bp = Vector3.new(-168, GROUND, LINE_Z), Vector3.new(168, GROUND, LINE_Z)
	-- gaps in studs from the west end: breach x -70..-58, the gate 30..50,
	-- a breach 100..112
	-- 8.5 high: from the firing step (4.5) a man sees over it to the chest
	palisade(line, A, Bp, 8.5, { { 98, 110 }, { 198, 218 }, { 268, 280 } })
	-- the gate: its posts, the beam over, the leaves thrown down
	for _, x in { 29, 51 } do
		pole(line, "GatePost", Vector3.new(x, GROUND - 1, LINE_Z), Vector3.new(x, GROUND + 13, LINE_Z), 0.9, "oakDark")
	end
	beam(line, "GateBeam", Vector3.new(27.5, GROUND + 12.4, LINE_Z), Vector3.new(52.5, GROUND + 12.4, LINE_Z), 1.0, 1.1, "oakDark")
	for k, x in { 33, 46 } do
		local leaf = model(line, "GateLeaf")
		for b = 0, 4 do
			part(leaf, "Board", Vector3.new(1.6, 0.4, 10), CFrame.new(-3.2 + b * 1.6, 0.2, 0), "planks")
		end
		for _, z in { -3.5, 3.5 } do
			part(leaf, "Ledge", Vector3.new(8, 0.35, 0.6), CFrame.new(0, 0.55, z), "oakDark")
		end
		place(leaf, CFrame.new(x, GROUND, LINE_Z + (if k == 1 then 7 else -8)) * CFrame.Angles(math.rad(jit(4)), rand(-0.6, 0.6), math.rad(jit(6))))
	end
	-- the firing step behind the centre and east runs, a ramp at each end
	local function step(x0: number, x1: number)
		local z = LINE_Z - 3
		local top = 4.5
		part(line, "FiringStep", Vector3.new(x1 - x0, 0.5, 4), CFrame.new((x0 + x1) / 2, GROUND + top - 0.25, z), "planks")
		for x = x0 + 1, x1 - 1, 4 do
			pole(line, "Prop", Vector3.new(x, GROUND, z + 1.6), Vector3.new(x, GROUND + top - 0.4, z + 1.6), 0.3, "oakDark")
			pole(line, "Prop", Vector3.new(x, GROUND, z - 1.6), Vector3.new(x, GROUND + top - 0.4, z - 1.6), 0.3, "oakDark")
		end
		local run = 8
		ramp(line, Vector3.new(x0 - run, GROUND, z), Vector3.new(1, 0, 0), top, run, 4)
		ramp(line, Vector3.new(x1 + run, GROUND, z), Vector3.new(-1, 0, 0), top, run, 4)
		for _, xr in { x0 - run / 2, x1 + run / 2 } do
			for k = 0, 2 do
				part(line, "StepBoard", Vector3.new(run / 3, 0.3, 4), CFrame.new(xr + (if xr < x0 then -run / 2 + run * (k + 0.5) / 3 else run / 2 - run * (k + 0.5) / 3), GROUND + top * (k + 1) / 3 - 0.15, z) * CFrame.Angles(0, 0, 0), "planks").CanCollide = false
			end
		end
	end
	step(-44, 16)
	step(64, 92)
	-- stakes before the line, braziers behind it
	stakes(line, Vector3.new(-56, GROUND, LINE_Z + 6), Vector3.new(26, GROUND, LINE_Z + 6), Vector3.new(0, 0, 1))
	stakes(line, Vector3.new(54, GROUND, LINE_Z + 6), Vector3.new(96, GROUND, LINE_Z + 6), Vector3.new(0, 0, 1))
	for _, x in { -30, 4, 74 } do
		brazier(line, at(x, LINE_Z - 10, 0))
	end
	clutter(line, Vector3.new(0, 0, LINE_Z + 20), 90, 50, { "arrow", "arrow", "arrow", "shield", "helmet", "stone" })
	clutter(line, Vector3.new(0, 0, LINE_Z - 12), 90, 24, { "arrow", "helmet", "shield", "bones" })
	task.wait()

	-- 2. THE CAMP behind the line.
	local camp = model(f, "Camp")
	-- the field hospital: two tents, cots in rows, the table
	for i, p in { { -100, -1858 }, { -80, -1848 } } do
		tent(camp, at(p[1], p[2], 90), 12, 14, 8, if i == 2 then "collapsed" else nil)
		if i == 1 then
			for k = -1, 1 do
				cot(camp, at(p[1] + k * 3, p[2] - 1, 0))
			end
			prop(camp, "Table", at(p[1] + 1, p[2] + 6, 90))
			for k = 0, 2 do
				part(camp, "Bandage", Vector3.new(rand(0.6, 1.4), 0.08, 0.4), CFrame.new(p[1] + 1 + jit(1), GROUND + 2.7, p[2] + 6 + jit(1)) * CFrame.Angles(0, rand(0, 6), 0), "linen").CanCollide = false
			end
		end
	end
	-- the command tent and its map table
	local ct = tent(camp, at(60, -1862, 0), 14, 18, 10)
	ct.Name = "CommandTent"
	local mt = trestle(camp, at(60, -1862, 0), 8)
	part(mt, "Map", Vector3.new(6, 0.06, 2.6), at(60, -1862, 4, 3.24), "linen", Color3.fromRGB(196, 178, 140)).CanCollide = false
	for _ = 1, 5 do
		local mk = part(mt, "Marker", Vector3.new(0.3, 0.4, 0.3), at(60 + jit(2.6), -1862 + jit(1), 0, 3.45), "cloth", pick(HERALDRY))
		mk.CanCollide = false
	end
	prop(camp, "Chest", at(66, -1858, 0))
	banner(camp, CFrame.new(54, GROUND + 9, -1862) * CFrame.Angles(0, math.rad(90), 0), 2.6, 5, HERALDRY[1], true)
	for _, p in { { -20, -1838 }, { 16, -1840 }, { 96, -1838 } } do
		standOfArms(camp, at(p[1], p[2], 0), 8)
	end
	mangonel(camp, at(104, -1872, 0), true)
	local cart = prop(camp, "Cart", at(26, -1864, 40), 1.5)
	if cart then
		local fire = fireAt(camp, Vector3.new(26, GROUND + 3, -1864), 1.6, 40)
		smokeOn(fire, 4, true)
	end
	clutter(camp, Vector3.new(-90, 0, -1866), 14, 14, { "crate", "sacks", "barrel", "straw" })
	clutter(camp, Vector3.new(70, 0, -1872), 14, 12, { "crate", "barrel", "sacks", "firewood" })
	task.wait()

	-- 3. THE FALLEN TOWER, lying west to east across the south of the ward.
	local _, deckFrom, deckTo = fallenTower(f, at(-78, -1905, 0), 5)
	task.wait()

	-- 4. THE MARSHAL'S HOUSE, on the near side of the line: where the orders
	--    came from. Stone below, a fighting deck on top.
	house(f, at(-60, -1790, "S"), {
		name = "MarshalsHouse",
		W = 24,
		D = 15,
		storeys = 2,
		ground = "stone",
		front = { "window", "door", "loop", "window", "loop" },
		roof = { kind = "deck" },
		glow = true,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			prop(m, "Table", B * CFrame.new(5, y, -3.6), 1.2)
			prop(m, "Chest", B * CFrame.new(9, y, -2))
			part(m, "Map", Vector3.new(4, 0.06, 2.4), B * CFrame.new(5, y + 3.2, -3.6), "linen", Color3.fromRGB(196, 178, 140)).CanCollide = false
			if info.deckY then
				brazier(m, B * CFrame.new(8, info.deckY, 1))
			end
		end,
	})

	-- 5. NORTH OF THE LINE: what was thrown up first and overrun.
	local fore = model(f, "Forefield")
	for _, c in { { -112, -1806, 70 }, { -96, -1810, 100 }, { 120, -1806, 80 } } do
		local cc = prop(fore, "Cart", at(c[1], c[2], c[3]), 1.5)
		if cc then
			cc:PivotTo(cc:GetPivot() * CFrame.Angles(0, 0, math.rad(80)) + Vector3.new(0, 1.5, 0))
		end
	end
	for _, t in { { -140, -1790, 26 }, { 150, -1800, 22 } } do
		deadTree(fore, at(t[1], t[2], 0), t[3])
	end
	-- where they burned the ones that fell before the line, between attacks
	pyre(fore, at(-24, -1798, 15))
	clutter(fore, Vector3.new(-24, 0, -1798), 12, 10, { "bones", "shield", "helmet", "plank" })

	-- 6. THE PASSAGE OUT, half buried: fallen masonry heaped either side of
	--    its mouth (the clearing is AreaPlan's area-8 work; the way is not
	--    shut yet, nothing here blocks it).
	local buried = model(f, "PassageRubble")
	buried:SetAttribute("Passage", 8)
	for _ = 1, 26 do
		local s = rand(1.5, 4)
		local side = if chance(0.5) then -1 else 1
		-- (west of the mouth is the side wall: only a strip of floor there)
		local p = Vector3.new(-153 + (if side > 0 then rand(13, 22) else -rand(12, 17)), GROUND + s * 0.3, -1956 + jit(8))
		local st = part(buried, "Rubble", Vector3.new(s, s * rand(0.5, 0.9), s * rand(0.7, 1.2)), CFrame.new(p) * CFrame.Angles(jit(0.6), rand(0, 6), jit(0.6)), if chance(0.6) then "rubble" else "stone")
		st.CastShadow = false
	end

	-- 7. Light and the walls.
	roadLanterns(f, road, 40, 9)
	clutter(f, Vector3.new(0, 0, -1860), 140, 30, { "stone", "arrow", "stone", "plank" })
	wallTorches(f, 8)
	clearMarkers(8, f)
	return deckFrom, deckTo
end

--------------------------------------------------------------------------
-- Pieces for the Keep Steps
--------------------------------------------------------------------------

-- A king of the line in stone on his plinth: robe, crown, a sword held
-- point-down before him. `fallen`: thrown down, his head beside him.
local function statue(parent: Instance, cf: CFrame, fallen: boolean?)
	local m = model(parent, "Statue")
	local tint = shade(GRAVESTONE, rand(0.95, 1.12))
	part(m, "Plinth", Vector3.new(4.6, 0.8, 4.6), cf * CFrame.new(0, 0.4, 0), "stone", tint)
	part(m, "Plinth", Vector3.new(3.8, 4.4, 3.8), cf * CFrame.new(0, 3, 0), "stone", tint)
	part(m, "Plinth", Vector3.new(4.4, 0.6, 4.4), cf * CFrame.new(0, 5.5, 0), "stone", tint)
	local fig = model(m, "Figure")
	local robe = part(fig, "Robe", Vector3.new(6.2, 2.6, 2.6), CFrame.new(0, 3.1, 0) * CFrame.Angles(0, 0, math.rad(90)), "stone", tint)
	;(robe :: Part).Shape = Enum.PartType.Cylinder
	part(fig, "Chest", Vector3.new(2.6, 2.4, 1.6), CFrame.new(0, 6.8, 0), "stone", tint)
	part(fig, "Shoulders", Vector3.new(3.4, 0.9, 1.7), CFrame.new(0, 7.8, 0), "stone", tint)
	ball(fig, "Head", Vector3.new(1.4, 1.6, 1.4), CFrame.new(0, 9.1, 0), "stone").Color = tint
	for k = 0, 4 do
		local a = k / 5 * math.pi * 2
		part(fig, "Crown", Vector3.new(0.3, 0.6, 0.3), CFrame.new(math.cos(a) * 0.6, 9.95, math.sin(a) * 0.6), "stone", tint)
	end
	part(fig, "Blade", Vector3.new(0.45, 4.6, 0.25), CFrame.new(0, 3.8, -1.5), "stone", tint)
	part(fig, "Guard", Vector3.new(1.8, 0.35, 0.35), CFrame.new(0, 6.2, -1.5), "stone", tint)
	for _, s in { -1, 1 } do
		part(fig, "Arm", Vector3.new(0.8, 2.6, 0.8), CFrame.new(s * 0.55, 6.3, -1.1) * CFrame.Angles(math.rad(-25), 0, s * 0.2), "stone", tint)
	end
	if fallen then
		place(fig, cf * CFrame.new(4.5, 1.3, 1) * CFrame.Angles(0, rand(0, 6), math.rad(90)))
		local head = fig:FindFirstChild("Head") :: BasePart
		if head then
			head.CFrame = cf * CFrame.new(-3.2, 0.7, -3.4)
		end
	else
		place(fig, cf * CFrame.new(0, 5.8, 0))
	end
	return m
end

-- A fountain gone dry: a basin of eight stones, the dark stain where the
-- water stood, a column with a bowl, cracked through.
local function fountain(parent: Instance, cf: CFrame)
	local m = model(parent, "Fountain")
	local R = 7
	for k = 0, 7 do
		local a = k / 8 * math.pi * 2
		part(m, "Basin", Vector3.new(R * 0.84, 2.2, 1.2), cf * CFrame.new(math.cos(a) * R, 1.1, math.sin(a) * R) * CFrame.Angles(0, -a + math.pi / 2, 0), "stone")
		part(m, "Coping", Vector3.new(R * 0.9, 0.4, 1.6), cf * CFrame.new(math.cos(a) * R, 2.4, math.sin(a) * R) * CFrame.Angles(0, -a + math.pi / 2, 0), "stone", shade(MAT.stone[3], 1.1))
	end
	local stain = part(m, "Dry", Vector3.new(0.2, R * 2 - 1, R * 2 - 1), cf * CFrame.new(0, 0.3, 0) * CFrame.Angles(0, 0, math.rad(90)), "dark", Color3.fromRGB(46, 42, 36))
	;(stain :: Part).Shape = Enum.PartType.Cylinder
	stain.CastShadow = false
	part(m, "Column", Vector3.new(1.6, 6, 1.6), cf * CFrame.new(0, 3, 0), "stone")
	local bowl = part(m, "Bowl", Vector3.new(0.9, 5, 5), cf * CFrame.new(0, 6.2, 0) * CFrame.Angles(0, 0, math.rad(90)), "stone")
	;(bowl :: Part).Shape = Enum.PartType.Cylinder
	part(m, "Crack", Vector3.new(0.15, 1, 5.1), cf * CFrame.new(0.4, 6.2, 0) * CFrame.Angles(0, 0.5, 0), "dark").CastShadow = false
	part(m, "Fallen", Vector3.new(1.4, 3, 1.4), cf * CFrame.new(3.5, 0.8, 2) * CFrame.Angles(math.rad(80), 0.4, 0), "stone")
	return m
end

-- Box hedges in a knot, gone brown: the king's garden.
local function knotGarden(parent: Instance, cf: CFrame, size: number)
	local m = model(parent, "KnotGarden")
	local hedge = Color3.fromRGB(78, 70, 48)
	local function h(a: Vector3, b: Vector3)
		local len = (b - a).Magnitude
		local p = part(m, "Hedge", Vector3.new(1.4, 1.8, len), CFrame.lookAt((a + b) / 2, b) + Vector3.new(0, 0.9, 0), "thatchOld", shade(hedge, rand(0.85, 1.1)))
		p.Material = Enum.Material.Grass
		p.MaterialVariant = ""
		p.CastShadow = false
	end
	local s = size / 2
	local c = { (cf * CFrame.new(-s, 0, -s)).Position, (cf * CFrame.new(s, 0, -s)).Position, (cf * CFrame.new(s, 0, s)).Position, (cf * CFrame.new(-s, 0, s)).Position }
	-- the border, open in the middle of each side
	for i = 1, 4 do
		local a, b = c[i], c[i % 4 + 1]
		h(a, a:Lerp(b, 0.4))
		h(a:Lerp(b, 0.6), b)
	end
	-- the knot: a diamond and two diagonals
	local mid = cf.Position
	local d = { (cf * CFrame.new(0, 0, -s * 0.6)).Position, (cf * CFrame.new(s * 0.6, 0, 0)).Position, (cf * CFrame.new(0, 0, s * 0.6)).Position, (cf * CFrame.new(-s * 0.6, 0, 0)).Position }
	for i = 1, 4 do
		h(d[i], d[i % 4 + 1])
	end
	for _, k in { { -1, -1 }, { 1, 1 } } do
		h((cf * CFrame.new(k[1] * s * 0.8, 0, k[2] * s * 0.8)).Position, (cf * CFrame.new(k[1] * s * 0.3, 0, k[2] * s * 0.3)).Position)
	end
	ball(m, "Topiary", Vector3.new(2.6, 3.4, 2.6), CFrame.new(mid + Vector3.new(0, 1.7, 0)), "thatchOld").Color = hedge
	return m
end

--[[
	THE KEEP. A great square tower against the back wall, higher than the
	curtain, its corner turrets higher still; walls four studs thick, loops
	low, lancets high, a parapet with merlons. The way in is at the first
	floor, at the head of the steps, and the door is SHUT: sealed until the
	King is dead (AreaPlan, area 9). Nothing climbs it. B: the centre of its
	footprint on the ground; the door face is +Z, toward the gate.
]]
local KEEP_DOOR_Y = 18
local function keep(parent: Instance, B: CFrame, L: number, D: number, H: number): Model
	local m = model(nil, "Keep")
	local T = 4
	local low: WallOpts = { T = T, lancet = true, winW = 1.0, winSill = 8, winHead = 13 }
	local mid: WallOpts = { T = T, lancet = true, winW = 3.4, winSill = 6, winHead = 16, doorW = 10, doorH = 16, doorOpen = 0, threshold = 0.05 }
	local high: WallOpts = { T = T, lancet = true, winW = 2.6, winSill = 6, winHead = 13 }
	local n = math.max(4, math.floor(L / 10))
	local function band(F: CFrame, len: number, h: number, kind: string, door: boolean?, opts: WallOpts)
		local count = math.max(3, math.floor(len / 10))
		if door and count % 2 == 0 then
			count += 1 -- an odd count, so there is a middle bay for the door
		end
		local bays = table.create(count, kind)
		if door then
			bays[math.ceil(count / 2)] = "door"
		end
		stoneWall(m, F, len, h, bays, opts)
	end
	local faces = {
		-- frame (origin at the left end of the outer face, -Z outside), length, is it the door face
		{ B * CFrame.new(L / 2, 0, D / 2) * CFrame.Angles(0, math.pi, 0), L, true }, -- north (+Z), toward the gate
		{ B * CFrame.new(-L / 2, 0, -D / 2), L, false }, -- south, against the curtain
		{ B * CFrame.new(-L / 2, 0, D / 2) * CFrame.Angles(0, math.pi / 2, 0), D, false }, -- west
		{ B * CFrame.new(L / 2, 0, -D / 2) * CFrame.Angles(0, -math.pi / 2, 0), D, false }, -- east
	}
	for _, fc in faces do
		local F, len, isDoor = fc[1], fc[2], fc[3]
		band(F, len, KEEP_DOOR_Y, "loop", false, low)
		band(F * CFrame.new(0, KEEP_DOOR_Y, 0), len, 26, "window", isDoor, mid)
		band(F * CFrame.new(0, KEEP_DOOR_Y + 26, 0), len, H - KEEP_DOOR_Y - 26, if isDoor then "window" else "loop", false, high)
		-- string courses between the stages
		for _, y in { KEEP_DOOR_Y, KEEP_DOOR_Y + 26 } do
			part(m, "StringCourse", Vector3.new(len + 0.4, 0.8, 0.8), F * CFrame.new(len / 2, y, -0.3), "stone")
		end
		-- the parapet: merlons and the gaps between
		local k = 0
		for x = 1.6, len - 1.6, 3.2 do
			if k % 2 == 0 then
				part(m, "Merlon", Vector3.new(3.2, 4.4, T), F * CFrame.new(x, H + 2.2, T / 2), "rubble")
			end
			k += 1
		end
		part(m, "Corbels", Vector3.new(len, 1.2, 1.4), F * CFrame.new(len / 2, H - 0.6, -0.5), "stone")
		-- a sloped plinth at the foot (a wedge is tallest at its +Z face: here,
		-- against the wall)
		local w = wedge(m, "Batter", Vector3.new(len + 2, 4, 2.4), F * CFrame.new(len / 2, 2, -1.2), "rubble")
		w.CastShadow = false
	end
	-- the four corner turrets, standing proud and higher
	for _, c in { { -1, -1 }, { 1, -1 }, { -1, 1 }, { 1, 1 } } do
		local tc = B * CFrame.new(c[1] * (L / 2 - 3), 0, c[2] * (D / 2 - 3))
		part(m, "Turret", Vector3.new(12, H + 12, 12), tc * CFrame.new(0, (H + 12) / 2, 0), "rubble")
		for k = 0, 3 do
			local a = k * math.pi / 2
			for j = -1, 1, 2 do
				part(m, "Merlon", Vector3.new(2.6, 3.4, 1.6), tc * CFrame.Angles(0, a, 0) * CFrame.new(j * 3.2, H + 13.7, 6.2), "rubble")
			end
			for _, y in { 28, 46, 62 } do
				local slit = part(m, "Slit", Vector3.new(0.7, 3.2, 0.2), tc * CFrame.Angles(0, a, 0) * CFrame.new(0, y, 6.05), "dark")
				slit.CastShadow = false
			end
		end
	end
	-- the floors inside (the keep is shut; these are for whatever opens it)
	part(m, "GroundSlab", Vector3.new(L - 2 * T, 1, D - 2 * T), B * CFrame.new(0, 0, 0), "stone")
	local hall = part(m, "HallFloor", Vector3.new(L - 2 * T, 1, D - 2 * T), B * CFrame.new(0, KEEP_DOOR_Y - 0.5, 0), "planks")
	hall.CastShadow = false
	local scribe = part(m, "ScribeSpot", Vector3.new(2, 2, 2), B * CFrame.new(0, KEEP_DOOR_Y + 1, -D / 4), "dark")
	scribe.Transparency = 1
	scribe.CanCollide = false
	scribe.CanQuery = false
	-- the sealed door: its leaves shut, a bar across, and the mark the
	-- mechanic finds (attribute Sealed)
	local doorMark = part(m, "KeepDoor", Vector3.new(10, 16, 0.4), B * CFrame.new(0, KEEP_DOOR_Y + 8, D / 2 - T / 2), "dark")
	doorMark.Transparency = 1
	doorMark.CanCollide = true
	doorMark:SetAttribute("Sealed", true)
	beam(m, "Bar", (B * CFrame.new(-6.5, KEEP_DOOR_Y + 7, D / 2 + 0.6)).Position, (B * CFrame.new(6.5, KEEP_DOOR_Y + 7.4, D / 2 + 0.6)).Position, 0.9, 0.9, "oakDark")
	for _, x in { -6.6, 6.6 } do
		part(m, "Staple", Vector3.new(0.6, 1.6, 0.8), B * CFrame.new(x, KEEP_DOOR_Y + 7.2, D / 2 + 0.3), "ironDark")
	end
	-- the realm's banners down the face, either side of the door
	for _, x in { -14, 14 } do
		banner(m, B * CFrame.new(x, KEEP_DOOR_Y + 30, D / 2 + 0.8), 5, 14, HERALDRY[1], x > 0)
	end
	m.Parent = parent
	return m
end

-- The steps: a flight of stone up to a landing, its parapets stepping up
-- either side. Treads to see, a ramp to walk, the masonry under it all.
local function grandStair(parent: Instance, foot: Vector3, dir: Vector3, rise: number, run: number, width: number)
	local m = model(parent, "KeepSteps")
	local flat = Vector3.new(dir.X, 0, dir.Z).Unit
	local side = flat:Cross(Vector3.yAxis)
	local steps = math.ceil(rise / 0.75)
	local tread = run / steps
	local riser = rise / steps
	local base = CFrame.lookAt(foot, foot + flat)
	for i = 0, steps - 1 do
		local t = part(m, "Step", Vector3.new(width, riser + 0.2, tread + 0.1), base * CFrame.new(0, riser * (i + 1) - (riser + 0.2) / 2, -(tread * (i + 0.5))), "stone", shade(MAT.stone[3], rand(0.92, 1.08)))
		t.CanCollide = false
		t.CastShadow = false
	end
	-- the masonry the flight is built on, seen from the sides
	local core = wedge(m, "StairMass", Vector3.new(width + 0.2, rise - 0.3, run), CFrame.lookAt(foot + flat * (run / 2) + Vector3.new(0, (rise - 0.3) / 2, 0), foot + flat * (run / 2) + Vector3.new(0, (rise - 0.3) / 2, 0) - flat), "rubble")
	core.CanCollide = false
	ramp(m, foot, flat, rise, run, width)
	-- the parapets, sloping, with a newel at each end
	for _, s in { -1, 1 } do
		local a = foot + side * (s * (width / 2 + 0.8)) + Vector3.new(0, 1.4, 0)
		local b = foot + flat * run + side * (s * (width / 2 + 0.8)) + Vector3.new(0, rise + 1.4, 0)
		beam(m, "Parapet", a, b, 1.6, 2.8, "rubble")
		beam(m, "Coping", a + Vector3.new(0, 1.6, 0), b + Vector3.new(0, 1.6, 0), 2.0, 0.5, "stone")
		local pf = foot + side * (s * (width / 2 + 0.8))
		part(m, "Newel", Vector3.new(2.6, 5, 2.6), CFrame.new(pf + Vector3.new(0, 2.5, 0)), "stone")
		part(m, "NewelCap", Vector3.new(3.2, 0.6, 3.2), CFrame.new(pf + Vector3.new(0, 5.3, 0)), "stone")
	end
	return m
end

--------------------------------------------------------------------------
-- AREA 9 — THE KEEP STEPS. The end of the castle: the keep against the
-- back wall, higher than anything, its door shut at the head of a great
-- flight of steps; the forecourt below where the King's guard made its last
-- stand; the kings of the line in stone along the way, one thrown down; a
-- fountain gone dry; the treasury, the chancery, the guardroom; the king's
-- knot garden gone brown. Whatever it was, it went in there.
--------------------------------------------------------------------------
local function area9()
	local f = areaFolder(9)
	local zNear, zFar = Castle.chamberBounds(9)
	local road = { Vector2.new(-153, zNear - 16), Vector2.new(-140, -2020), Vector2.new(-95, -2048), Vector2.new(-40, -2068), Vector2.new(0, -2085), Vector2.new(0, -2118) }
	paintGround(zNear - 2, zFar + 2, {
		{ path = road, width = 14, material = Enum.Material.Cobblestone, verge = Enum.Material.Mud },
		{ path = { Vector2.new(70, -2075), Vector2.new(120, -2075) }, width = 4, material = Enum.Material.Pebble },
		{ path = { Vector2.new(95, -2050), Vector2.new(95, -2100) }, width = 4, material = Enum.Material.Pebble },
	}, { { Vector2.new(-120, -2160), 16 } }, {
		{ x0 = -64, x1 = 64, z0 = -2152, z1 = -2058, material = Enum.Material.Cobblestone, alt = Enum.Material.Cobblestone },
		{ x0 = 72, x1 = 118, z0 = -2098, z1 = -2052, material = Enum.Material.LeafyGrass, alt = Enum.Material.Grass },
	})
	task.wait()

	-- 1. THE KEEP, 68 by 56, against the back wall; 72 to the parapet.
	local KB = at(0, -2188, 0)
	local KL, KD, KH = 68, 56, 72
	keep(f, KB, KL, KD, KH)
	task.wait()

	-- 2. THE STEPS: from the forecourt up to the landing before the door.
	local landingZ0 = -2188 + KD / 2 -- the keep's north face
	local landingDepth = 12
	local stepTop = landingZ0 + landingDepth
	local run = 30
	local land = part(f, "Landing", Vector3.new(32, KEEP_DOOR_Y, landingDepth), CFrame.new(0, GROUND + KEEP_DOOR_Y / 2, landingZ0 + landingDepth / 2), "rubble")
	land.Name = "KeepLanding"
	-- the paving starts exactly where the flight ends and at its height: a
	-- paving edge standing 0.12 proud of the ramp shut the landing off
	part(f, "LandingPaving", Vector3.new(32.4, 0.4, landingDepth), CFrame.new(0, GROUND + KEEP_DOOR_Y + 0.05 - 0.2, landingZ0 + landingDepth / 2), "stone")
	grandStair(f, Vector3.new(0, GROUND, stepTop + run), Vector3.new(0, 0, -1), KEEP_DOOR_Y + 0.05, run, 20)
	-- the landing's parapet, open to the steps; braziers at its corners
	for _, s in { -1, 1 } do
		beam(f, "Parapet", Vector3.new(s * 16.6, GROUND + KEEP_DOOR_Y + 1.4, landingZ0), Vector3.new(s * 16.6, GROUND + KEEP_DOOR_Y + 1.4, stepTop), 1.6, 2.8, "rubble")
		beam(f, "Parapet", Vector3.new(s * 10.8, GROUND + KEEP_DOOR_Y + 1.4, stepTop - 0.4), Vector3.new(s * 16.6, GROUND + KEEP_DOOR_Y + 1.4, stepTop - 0.4), 1.6, 2.8, "rubble")
		brazier(f, at(s * 13.6, landingZ0 + 3, 0, KEEP_DOOR_Y))
	end
	task.wait()

	-- 3. THE FORECOURT: the kings in stone along the way, the guard's last
	--    ring, the fountain, the braziers that are still lit.
	local court = model(f, "Forecourt")
	for i, p in { { -24, -2100 }, { 24, -2100 }, { -24, -2124 }, { 24, -2124 }, { -46, -2078 }, { 46, -2078 } } do
		statue(court, at(p[1], p[2], 180), i == 4)
	end
	fountain(court, at(-42, -2110, 0))
	for _, x in { -15, 15 } do
		brazier(court, at(x, stepTop + run + 4, 0))
	end
	-- the last stand: carts and crates thrown across the foot of the steps,
	-- the guard's shields where they fell
	local ring = model(court, "LastStand")
	for _, c in { { -30, -2134, 70 }, { 32, -2136, 110 } } do
		local cc = prop(ring, "Cart", at(c[1], c[2], c[3]), 1.5)
		if cc then
			cc:PivotTo(cc:GetPivot() * CFrame.Angles(0, 0, math.rad(82)) + Vector3.new(0, 1.5, 0))
		end
	end
	for _, c in { { -20, -2138 }, { 18, -2140 }, { -36, -2120 }, { 36, -2118 } } do
		prop(ring, "Crate", at(c[1], c[2], rand(0, 360)), 1.2)
	end
	clutter(ring, Vector3.new(0, 0, -2128), 34, 40, { "shield", "helmet", "shield", "arrow", "bones", "stone" })
	for _, x in { -54, 54 } do
		pole(ring, "BannerPole", Vector3.new(x, GROUND, -2140), Vector3.new(x, GROUND + 22, -2140), 0.3, "oakDark")
		banner(ring, CFrame.new(x + 2.8, GROUND + 21, -2140), 4.4, 10, HERALDRY[1], true)
	end
	-- the royal carriage, over on its side
	local car = model(court, "RoyalCarriage")
	local cb = at(-58, -2150, 30)
	part(car, "Body", Vector3.new(5, 5, 9), cb * CFrame.new(0, 3, 0), "planks", Color3.fromRGB(70, 40, 34))
	part(car, "Roof", Vector3.new(5.6, 0.5, 9.6), cb * CFrame.new(0, 5.7, 0), "cloth", HERALDRY[1])
	for _, z in { -3, 3 } do
		for _, x in { -2.9, 2.9 } do
			local w = part(car, "Wheel", Vector3.new(0.5, 4, 4), cb * CFrame.new(x, 2, z), "oakDark")
			;(w :: Part).Shape = Enum.PartType.Cylinder
		end
	end
	-- built where it stood; tipped over about its own base
	place(car, cb * CFrame.new(0, 2.4, 0) * CFrame.Angles(0, 0, math.rad(85)) * cb:Inverse())
	task.wait()

	-- 4. THE TREASURY (west), THE CHANCERY (east), THE GUARDROOM (by the way in).
	house(f, at(-112, -2160, "E"), {
		name = "Treasury",
		W = 18,
		D = 14,
		storeys = 1,
		ground = "stone",
		front = { "loop", "door", "loop" },
		roof = { kind = "shingles", pitch = 30 },
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			for k = 0, 2 do
				prop(m, "Chest", B * CFrame.new(-4 + k * 4, y, 2.4))
			end
			clutter(m, (B * CFrame.new(0, info.plinthH, -1)).Position, 3, 4, { "crate", "plank" }, true)
		end,
	})
	house(f, at(112, -2150, "W"), {
		name = "Chancery",
		W = 24,
		D = 15,
		storeys = 2,
		ground = "stone",
		front = { "window", "door", "window", "window", "window" },
		roof = { kind = "shingles", pitch = 44 },
		limewash = LIMEWASH.white,
		glow = true,
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			-- the clerks' desks, the rolls on the shelves
			prop(m, "Table", B * CFrame.new(5, y, -3.6), 1.1)
			prop(m, "Shelf", B * CFrame.new(9.2, y, -1) * CFrame.Angles(0, -math.pi / 2, 0), 1.2)
			for k = 0, 5 do
				local roll = part(m, "Roll", Vector3.new(1.4, 0.4, 0.4), B * CFrame.new(3 + k * 0.7, y + 2.8, -3.6 + jit(0.6)) * CFrame.Angles(0, rand(0, 6), 0), "linen", Color3.fromRGB(200, 186, 150))
				;(roll :: Part).Shape = Enum.PartType.Cylinder
				roll.CanCollide = false
			end
			candle(m, (B * CFrame.new(6.5, y + 2.7, -3.4)).Position, 1, true)
			if info.upperY then
				prop(m, "Bed", B * CFrame.new(5, info.upperY, -4), 1.5)
				prop(m, "Chest", B * CFrame.new(-4, info.upperY, -5))
			end
		end,
	})
	house(f, at(-120, -2052, "S"), {
		name = "Guardroom",
		W = 16,
		D = 12,
		storeys = 1,
		ground = "stone",
		front = { "loop", "door", "loop" },
		roof = { kind = "shingles", pitch = 36, holes = 0.15 },
		furnish = function(m, B, info)
			local y = info.plinthH + 0.32
			spearRack(m, B * CFrame.new(3, y, 1.8), 5)
			prop(m, "Table", B * CFrame.new(-2, y, -1), 1.0)
		end,
	})
	task.wait()

	-- 5. THE KNOT GARDEN, east of the forecourt, its trees dead.
	local garden = model(f, "KingsGarden")
	knotGarden(garden, at(95, -2075, 0), 40)
	for _, t in { { 76, -2056, 20 }, { 114, -2096, 24 }, { 114, -2054, 18 } } do
		deadTree(garden, at(t[1], t[2], 0), t[3])
	end
	part(garden, "Seat", Vector3.new(7, 1.6, 2.4), CFrame.new(95, GROUND + 0.8, -2098), "stone")

	-- 6. Light and the walls.
	roadLanterns(f, road, 30, 10)
	clutter(f, Vector3.new(0, 0, -2080), 140, 30, { "stone", "plank", "stone", "arrow" })
	wallTorches(f, 9)
	clearMarkers(9, f)
end

local function prototype()
	local root = workspace:FindFirstChild("TLK_Preview") or Instance.new("Folder")
	root.Name = "TLK_Preview"
	root.Parent = workspace
	local old = root:FindFirstChild("ProtoHouse")
	if old then
		old:Destroy()
	end
	local holder = Instance.new("Folder")
	holder.Name = "ProtoHouse"
	holder.Parent = root
	local B = CFrame.new(-640, 6, 470) * CFrame.Angles(0, math.rad(200), 0)
	house(holder, B, {
		name = "Prototype",
		W = 20,
		D = 13,
		storeys = 2,
		front = { "window", "door", "wall", "window" },
		roof = { kind = "thatch", chimneyX = 5 },
		glow = true,
		furnish = function(m, Bf, info)
			prop(m, "Table", Bf * CFrame.new(2, info.plinthH + 0.3, 0) * CFrame.Angles(0, math.rad(8), 0))
			prop(m, "Barrel", Bf * CFrame.new(6.5, info.plinthH + 0.3, 4.5))
			prop(m, "Sacks", Bf * CFrame.new(-5, info.plinthH + 0.3, 4.5))
			if info.upperY then
				prop(m, "Bed", Bf * CFrame.new(5, info.upperY, 2) * CFrame.Angles(0, math.rad(90), 0))
				prop(m, "Chest", Bf * CFrame.new(1, info.upperY, 5))
			end
		end,
	})
	local B2 = CFrame.new(-612, 6, 470) * CFrame.Angles(0, math.rad(160), 0)
	house(holder, B2, {
		name = "PrototypeBurnt",
		W = 14,
		D = 11,
		storeys = 1,
		burnt = true,
		damage = 0.4,
		front = { "door", "window", "wall" },
		roof = { kind = "thatch", burnt = true },
	})
end

local BUILDERS = {
	Look = terrainLook,
	Area1 = area1,
	Area2 = area2,
	Area3 = area3,
	Area4 = area4,
	Area5 = area5,
	Area6 = area6,
	Area7 = area7,
	Area8 = area8,
	Area9 = area9,
	Prototype = prototype,
}
local ORDER = { "Look", "Area1", "Area2", "Area3", "Area4", "Area5", "Area6", "Area7", "Area8", "Area9", "Prototype" }

local Tool = {}
function Tool.run(list: { string })
	pcall(function()
		ChangeHistoryService:SetWaypoint("Wards: before")
	end)
	local wanted = {}
	for _, n in list do
		wanted[n] = true
	end
	for _, n in ORDER do
		if wanted.all or wanted[n] then
			local before = made
			BUILDERS[n]()
			print(("[Wards] %s: %d parts"):format(n, made - before))
			task.wait()
		end
	end
	pcall(function()
		ChangeHistoryService:SetWaypoint("Wards")
	end)
	return made
end

-- Exposed for the area sections that follow (and for testing pieces alone).
Tool.lib = {
	part = part,
	wedge = wedge,
	beam = beam,
	pole = pole,
	ball = ball,
	model = model,
	ramp = ramp,
	stair = stair,
	boards = boards,
	frameWall = frameWall,
	roof = roof,
	house = house,
	prop = prop,
	fireAt = fireAt,
	smokeOn = smokeOn,
	pointLight = pointLight,
	rand = rand,
	jit = jit,
	chance = chance,
	pick = pick,
}

local AUTO_RUN = true
if AUTO_RUN then
	Tool.run(SECTIONS)
end

return Tool
