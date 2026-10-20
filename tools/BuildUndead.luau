--[[
	BuildUndead — run in the FORGOTTEN LANDS place, in EDIT MODE. Builds the dead.

	The unit in the game today is one red anchored box. This replaces it with a
	body: an R15-named skeleton of Motor6Ds (so any R15 KeyframeSequence, the
	sword cuts included, fits it), dressed per type from parts. The brief is
	docs/systems/Bestiary.md; the animation protocol is docs/systems/Animation.md.

	WHAT IT BUILDS
	  One master Model per type into ServerStorage.Assets.Undead (not Rojo-owned;
	  EnemyService will clone from there). Each carries:
	    HumanoidRootPart  anchored, 2 x 5 x 1, invisible — what the AI moves
	    the limbs         unanchored, Massless, non-colliding, joined by Motor6D
	    Humanoid          health bar only (state machine off)
	    Animator          so a client can play a clip on it
	  and the attributes Type and Dressing.

	THE BODY (v2, 2026-10-20). Round limbs (cylinders) with ball joints, a skull
	built from a cranium, hollow cheeks, a hanging jaw and teeth, curled fingers,
	exposed ribs and veins, ragged hems and cloaks, weathered metal. Most of the
	look is in what is torn, worn and hanging, so that a figure reads as a person
	who died in their clothes, not as a mannequin in a costume.

	THE POSE IS BAKED IN. A joint's rest rotation is written into the Motor6D, so a
	shambler is hunched and reaching with no clip playing at all, and a clip is
	keyed as a rotation AWAY from that rest. Axes: +X swings a limb that hangs
	down FORWARD (-Z), and tips a part that stands up (torso, head) BACK. After the
	pose the whole body is lowered until its lowest foot stands on the floor.

	MODES
	  "build"   build the masters only
	  "lineup"  build, then stage a copy of each on the road outside the gate,
	            facing +Z, with a warm light, for a picture. Removed by "clear".
	  "clear"   remove the staged line-up (the masters stay)

	NOTE: a tool, not game code. Not synced by Rojo.
]]

local MODE = "build" -- "build" | "lineup" | "clear"
-- "field": the game's bodies, in Assets.Undead, wearing Assets.UndeadKitField.
-- "fine" : the close-up version, in Assets.UndeadFine, wearing Assets.UndeadKit.
local QUALITY = "field"
local ONLY: { string }? = nil -- e.g. { "undead_shambler" }

--==========================================================================
local ServerStorage = game:GetService("ServerStorage")
local ChangeHistoryService = game:GetService("ChangeHistoryService")
local MaterialService = game:GetService("MaterialService")
local Workspace = game:GetService("Workspace")

local Mat = Enum.Material
local rad = math.rad
local V3 = Vector3.new
local CF = CFrame.new
local ANG = CFrame.Angles

local function rgb(r: number, g: number, b: number): Color3
	return Color3.fromRGB(r, g, b)
end

local function shade(c: Color3, f: number): Color3
	return Color3.new(math.clamp(c.R * f, 0, 1), math.clamp(c.G * f, 0, 1), math.clamp(c.B * f, 0, 1))
end

-- The palette (docs/systems/Bestiary.md §3).
local C = {
	skin = rgb(100, 108, 112),
	skinDark = rgb(68, 74, 80),
	skinPale = rgb(128, 134, 134),
	vein = rgb(58, 54, 78),
	bordeaux = rgb(96, 36, 44),
	gold = rgb(150, 120, 52),
	linen = rgb(150, 138, 118),
	woad = rgb(70, 84, 100),
	mud = rgb(88, 66, 50),
	leather = rgb(70, 48, 36),
	leatherDark = rgb(44, 32, 26),
	rust = rgb(96, 68, 54),
	rustDark = rgb(62, 46, 40),
	mail = rgb(58, 60, 64),
	steel = rgb(110, 112, 114),
	bone = rgb(190, 180, 160),
	wood = rgb(84, 62, 44),
	woodDark = rgb(58, 44, 34),
	black = rgb(26, 24, 26),
	socket = rgb(22, 24, 28),
	eye = rgb(206, 228, 240),
	ichor = rgb(40, 34, 44),
}

local function hasVariant(name: string): boolean
	return MaterialService:FindFirstChild(name, true) ~= nil
end

local MAT = {
	skin = { Mat.Concrete, nil },
	cloth = { Mat.Fabric, nil },
	burlap = { Mat.Fabric, "TLK_Burlap" },
	leather = { Mat.Fabric, nil },
	wood = { Mat.Wood, "TLK_OakBeam" },
	iron = { Mat.Metal, nil },
	rusty = { Mat.CorrodedMetal, nil },
	steel = { Mat.Metal, nil },
	mail = { Mat.Metal, nil },
	bone = { Mat.SmoothPlastic, nil },
	gold = { Mat.Metal, nil },
	neon = { Mat.Neon, nil },
	dark = { Mat.SmoothPlastic, nil },
}

--==========================================================================
-- THE SKELETON
-- { bone, parent, size (width, LENGTH, depth), joint (in the parent's frame),
--   pivot (in its own), joint name, shape }
-- A cylinder bone is stood on its end: its Part.Size is (length, width, depth)
-- and it is turned a quarter about Z, so the clips still turn it as an R15 limb.
--==========================================================================
local BONES = {
	{ "LowerTorso", "HumanoidRootPart", V3(1.6, 0.5, 0.85), V3(0, 0.13, 0), V3(0, 0, 0), "Root", "block" },
	{ "UpperTorso", "LowerTorso", V3(1.8, 1.55, 0.85), V3(0, 0.25, 0), V3(0, -0.775, 0), "Waist", "block" },
	{ "Head", "UpperTorso", V3(0.9, 1.0, 0.95), V3(0, 0.775, 0), V3(0, -0.55, 0), "Neck", "ball" },
	{ "RightUpperArm", "UpperTorso", V3(0.56, 1.15, 0.56), V3(1.08, 0.6, 0), V3(0, 0.52, 0), "RightShoulder", "cyl" },
	{ "LeftUpperArm", "UpperTorso", V3(0.56, 1.15, 0.56), V3(-1.08, 0.6, 0), V3(0, 0.52, 0), "LeftShoulder", "cyl" },
	{ "RightLowerArm", "RightUpperArm", V3(0.46, 1.05, 0.46), V3(0, -0.55, 0), V3(0, 0.5, 0), "RightElbow", "cyl" },
	{ "LeftLowerArm", "LeftUpperArm", V3(0.46, 1.05, 0.46), V3(0, -0.55, 0), V3(0, 0.5, 0), "LeftElbow", "cyl" },
	{ "RightHand", "RightLowerArm", V3(0.44, 0.4, 0.22), V3(0, -0.5, 0), V3(0, 0.18, 0), "RightWrist", "block" },
	{ "LeftHand", "LeftLowerArm", V3(0.44, 0.4, 0.22), V3(0, -0.5, 0), V3(0, 0.18, 0), "LeftWrist", "block" },
	{ "RightUpperLeg", "LowerTorso", V3(0.74, 1.15, 0.74), V3(0.45, -0.2, 0), V3(0, 0.52, 0), "RightHip", "cyl" },
	{ "LeftUpperLeg", "LowerTorso", V3(0.74, 1.15, 0.74), V3(-0.45, -0.2, 0), V3(0, 0.52, 0), "LeftHip", "cyl" },
	{ "RightLowerLeg", "RightUpperLeg", V3(0.52, 1.15, 0.52), V3(0, -0.55, 0), V3(0, 0.52, 0), "RightKnee", "cyl" },
	{ "LeftLowerLeg", "LeftUpperLeg", V3(0.52, 1.15, 0.52), V3(0, -0.55, 0), V3(0, 0.52, 0), "LeftKnee", "cyl" },
	{ "RightFoot", "RightLowerLeg", V3(0.56, 0.24, 1.1), V3(0, -0.55, 0), V3(0, 0.12, 0.25), "RightAnkle", "block" },
	{ "LeftFoot", "LeftLowerLeg", V3(0.56, 0.24, 1.1), V3(0, -0.55, 0), V3(0, 0.12, 0.25), "LeftAnkle", "block" },
}

local QUARTER = ANG(0, 0, rad(90))

local function finish(p: BasePart, castShadow: boolean?)
	p.Anchored = false
	p.CanCollide = false
	p.CanTouch = false
	p.CanQuery = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	local m = p.Size
	p.CastShadow = if castShadow ~= nil then castShadow else math.max(m.X, m.Y, m.Z) >= 1.4
end

local drift = Random.new(77)
local function paint(p: BasePart, key: string, color: Color3)
	local m = MAT[key] or MAT.cloth
	p.Material = m[1]
	if m[2] and hasVariant(m[2]) then
		p.MaterialVariant = m[2]
	end
	local f = 1 + drift:NextNumber(-0.07, 0.07)
	p.Color = Color3.new(math.clamp(color.R * f, 0, 1), math.clamp(color.G * f, 0, 1), math.clamp(color.B * f, 0, 1))
end

--==========================================================================
-- CONTEXT AND ACCESSORY HELPERS
--==========================================================================
type Ctx = {
	model: Model,
	root: BasePart,
	bones: { [string]: BasePart },
	frames: { [string]: CFrame }, -- each bone's joint-aligned frame, at its centre
	w: number, -- width scale
	h: number, -- height scale
	rng: Random,
	kitHead: boolean?, -- the sculpted head is on (it brings its own face and hair)
}

local function weld(a: BasePart, b: BasePart)
	local w = Instance.new("WeldConstraint")
	w.Part0 = a
	w.Part1 = b
	w.Parent = b
end

-- A part in a bone's own frame (origin at its centre, Y along the limb).
local function acc(ctx: Ctx, bone: string, name: string, size: Vector3, cf: CFrame, key: string, color: Color3, class: string?): BasePart
	local p = Instance.new(class or "Part") :: BasePart
	p.Name = name
	p.Size = size
	p.CFrame = ctx.frames[bone] * cf
	paint(p, key, color)
	finish(p)
	p.Parent = ctx.model
	weld(ctx.bones[bone], p)
	return p
end

local function wedgeAcc(ctx: Ctx, bone: string, name: string, size: Vector3, cf: CFrame, key: string, color: Color3): BasePart
	return acc(ctx, bone, name, size, cf, key, color, "WedgePart")
end

local function ballAcc(ctx: Ctx, bone: string, name: string, size: Vector3, cf: CFrame, key: string, color: Color3): BasePart
	local p = acc(ctx, bone, name, size, cf, key, color)
	local sp = p :: Part
	sp.Shape = Enum.PartType.Ball
	return p
end

-- A cylinder whose long axis runs along `cf`'s local Y; radius may differ in X and Z.
local function cylAcc(ctx: Ctx, bone: string, name: string, length: number, radius: number, cf: CFrame, key: string, color: Color3, radiusZ: number?): BasePart
	local p = acc(ctx, bone, name, V3(length, radius * 2, (radiusZ or radius) * 2), cf * QUARTER, key, color)
	local sp = p :: Part
	sp.Shape = Enum.PartType.Cylinder
	return p
end

-- A part placed in the ROOT's frame (y up, -Z forward) and welded to a bone: for
-- things that are easier to aim in the world than in a limb's frame.
local function rootAcc(ctx: Ctx, bone: string, name: string, size: Vector3, rootCf: CFrame, key: string, color: Color3, shape: Enum.PartType?, class: string?): BasePart
	local p = Instance.new(class or "Part") :: BasePart
	p.Name = name
	p.Size = size
	p.CFrame = ctx.root.CFrame * rootCf
	paint(p, key, color)
	finish(p)
	if shape then
		local sp = p :: Part
		sp.Shape = shape
	end
	p.Parent = ctx.model
	weld(ctx.bones[bone], p)
	return p
end

-- A shaft from `a` to `b` (root space), radius `r`.
local function rodRoot(ctx: Ctx, bone: string, name: string, a: Vector3, b: Vector3, r: number, key: string, color: Color3): BasePart
	local mid = (a + b) / 2
	local cf = CFrame.lookAt(mid, b) * ANG(0, rad(90), 0)
	return rootAcc(ctx, bone, name, V3((b - a).Magnitude, r * 2, r * 2), cf, key, color, Enum.PartType.Cylinder)
end

-- Where a bone's centre is, in root space.
local function pointOf(ctx: Ctx, bone: string, local_: Vector3?): Vector3
	return ctx.root.CFrame:PointToObjectSpace((ctx.frames[bone] * CF(local_ or V3())).Position)
end

local function handAt(ctx: Ctx, side: string): Vector3
	return pointOf(ctx, side .. "Hand", V3(0, -0.05, 0))
end

-- The falling star: four crossed bars, on a flat face. cf is in the bone's frame, facing -Z.
local function star(ctx: Ctx, bone: string, cf: CFrame, s: number, color: Color3)
	for i = 0, 3 do
		local bar = acc(ctx, bone, "StarBar" .. i, V3(s, s * 0.13, 0.03), cf * ANG(0, 0, rad(i * 45)), "gold", color)
		bar.CastShadow = false
	end
	local core = ballAcc(ctx, bone, "StarCore", V3(s * 0.22, s * 0.22, 0.05), cf, "gold", shade(color, 1.2))
	core.CastShadow = false
end

--==========================================================================
-- THE BODY
--==========================================================================
local function buildBody(id: string, spec: any, seed: number): Ctx
	local model = Instance.new("Model")
	model.Name = id

	local w = spec.w or 1
	local h = spec.h or 1
	local function S(v: Vector3): Vector3
		return V3(v.X * w, v.Y * h, v.Z * w)
	end

	local root = Instance.new("Part")
	root.Name = "HumanoidRootPart"
	root.Size = V3(2, 5, 1)
	root.Transparency = 1
	root.Anchored = true
	root.CFrame = CFrame.new()
	root.Parent = model
	model.PrimaryPart = root

	local bones: { [string]: BasePart } = { HumanoidRootPart = root }
	local frames: { [string]: CFrame } = { HumanoidRootPart = root.CFrame }
	local ctx: Ctx = { model = model, root = root, bones = bones, frames = frames, w = w, h = h, rng = Random.new(seed) }
	local qOf: { [string]: CFrame } = { HumanoidRootPart = CFrame.new() }
	local motors: { [string]: Motor6D } = {}

	for _, def in BONES do
		local name, parentName, size, joint, pivot, jointName, shape = def[1], def[2], def[3], def[4], def[5], def[6], def[7]
		local rotDeg: Vector3 = (spec.pose and spec.pose[name]) or V3()
		local R = ANG(rad(rotDeg.X), rad(rotDeg.Y), rad(rotDeg.Z))
		local parent = bones[parentName]
		local sJoint, sPivot, sSize = S(joint), S(pivot), S(size)
		local q = if shape == "cyl" then QUARTER else CFrame.new()

		local jf = frames[parentName] * CF(sJoint) * R * CF(-sPivot)
		local p = Instance.new("Part")
		p.Name = name
		if shape == "cyl" then
			p.Size = V3(sSize.Y, sSize.X, sSize.Z)
			;(p :: Part).Shape = Enum.PartType.Cylinder
		else
			p.Size = sSize
		end
		p.CFrame = jf * q
		finish(p, true)
		p.Parent = model

		local m = Instance.new("Motor6D")
		m.Name = jointName
		m.Part0 = parent
		m.Part1 = p
		m.C0 = qOf[parentName]:Inverse() * CF(sJoint)
		m.C1 = q:Inverse() * CF(sPivot) * R:Inverse()
		m.Parent = p

		bones[name] = p
		frames[name] = jf
		qOf[name] = q
		motors[name] = m

		local look = spec.look and spec.look[name]
		if look then
			paint(p, look[1], look[2])
		else
			paint(p, "skin", C.skin)
		end
	end

	-- The head is a skull, a little long.
	local head = bones.Head :: Part
	head.Shape = Enum.PartType.Ball

	-- Stand it on the floor: lower everything until the lowest foot touches it.
	local lowest = math.huge
	for _, side in { "Right", "Left" } do
		local foot = bones[side .. "Foot"]
		local cf, size = foot.CFrame, foot.Size
		for _, sx in { -0.5, 0.5 } do
			for _, sy in { -0.5, 0.5 } do
				for _, sz in { -0.5, 0.5 } do
					local y = (cf * CF(sx * size.X, sy * size.Y, sz * size.Z)).Position.Y
					lowest = math.min(lowest, y)
				end
			end
		end
	end
	local drop = -2.5 - lowest
	for name, p in bones do
		if name ~= "HumanoidRootPart" then
			p.CFrame = p.CFrame + V3(0, drop, 0)
			frames[name] = frames[name] + V3(0, drop, 0)
		end
	end
	motors.LowerTorso.C0 = motors.LowerTorso.C0 + V3(0, drop, 0)

	return ctx
end

local function finishModel(ctx: Ctx, id: string, dressing: string)
	local model = ctx.model
	local humanoid = Instance.new("Humanoid")
	humanoid.RequiresNeck = false
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.None
	humanoid.HealthDisplayType = Enum.HumanoidHealthDisplayType.AlwaysOff
	pcall(function()
		local loose: any = humanoid
		loose.EvaluateStateMachine = false
	end)
	pcall(function()
		humanoid.BreakJointsOnDeath = false
	end)
	humanoid.Parent = model
	local animator = Instance.new("Animator")
	animator.Parent = humanoid

	model:SetAttribute("Type", id)
	model:SetAttribute("Dressing", dressing)
	model:SetAttribute("Variant", 1)
end

--==========================================================================
-- THE TOOLKIT
--==========================================================================

-- A row of hanging strips: a ragged hem, a torn cloak. `cf` is the TOP-edge centre of
-- the row; strips run along its X and hang down its -Y; `flare` pushes the bottoms out
-- along its -Z (degrees).
local function strips(ctx: Ctx, bone: string, name: string, n: number, width: number, len: number, cf: CFrame, key: string, color: Color3, ragged: number, flare: number)
	for i = 1, n do
		local x = -width / 2 + (i - 0.5) * width / n
		local l = len * (1 - ragged * ctx.rng:NextNumber())
		local roll = rad(ctx.rng:NextNumber(-8, 8))
		local pitch = rad(flare + ctx.rng:NextNumber(-3, 3))
		local s = acc(
			ctx,
			bone,
			name .. i,
			V3(width / n * 0.96, l, 0.045),
			cf * CF(x, 0, 0) * ANG(pitch, 0, roll) * CF(0, -l / 2, 0),
			key,
			shade(color, 1 + ctx.rng:NextNumber(-0.12, 0.08))
		)
		s.CastShadow = false
	end
end

-- Hip skirt on all four sides, ragged.
local function skirt(ctx: Ctx, color: Color3, key: string, drop: number, ragged: number?)
	local w, h = ctx.w, ctx.h
	local d = drop * h
	local r = ragged or 0.45
	strips(ctx, "LowerTorso", "SkF", 6, 1.5 * w, d, CF(0, 0.2 * h, -0.46 * w), key, color, r, 8)
	strips(ctx, "LowerTorso", "SkB", 6, 1.5 * w, d, CF(0, 0.2 * h, 0.46 * w) * ANG(0, math.pi, 0), key, shade(color, 0.9), r, 8)
	strips(ctx, "LowerTorso", "SkL", 3, 0.8 * w, d, CF(-0.84 * w, 0.2 * h, 0) * ANG(0, rad(90), 0), key, shade(color, 0.95), r, 8)
	strips(ctx, "LowerTorso", "SkR", 3, 0.8 * w, d, CF(0.84 * w, 0.2 * h, 0) * ANG(0, rad(-90), 0), key, shade(color, 0.95), r, 8)
end

-- A torn cloak down the back from the shoulders.
local function cloak(ctx: Ctx, color: Color3, key: string, len: number, width: number?)
	local w, h = ctx.w, ctx.h
	strips(ctx, "UpperTorso", "Cl", 9, (width or 2.0) * w, len * h, CF(0, 0.74 * h, 0.5 * w) * ANG(0, math.pi, 0), key, color, 0.5, 7)
	-- the clasp and the fold at the neck
	acc(ctx, "UpperTorso", "CloakYoke", V3(2.0 * w, 0.22 * h, 0.2 * w), CF(0, 0.72 * h, 0.44 * w), key, shade(color, 1.1))
end

local function belt(ctx: Ctx, color: Color3, pouch: boolean?)
	local w, h = ctx.w, ctx.h
	acc(ctx, "LowerTorso", "Belt", V3(1.68 * w, 0.14 * h, 0.92 * w), CF(0, 0.15 * h, 0), "leather", color)
	acc(ctx, "LowerTorso", "Buckle", V3(0.2 * w, 0.18 * h, 0.04), CF(0, 0.15 * h, -0.47 * w), "gold", C.gold)
	if pouch then
		acc(ctx, "LowerTorso", "Pouch", V3(0.42 * w, 0.42 * h, 0.28 * w), CF(0.6 * w, 0.0, -0.5 * w), "leather", shade(color, 1.1))
		acc(ctx, "LowerTorso", "PouchFlap", V3(0.44 * w, 0.14 * h, 0.3 * w), CF(0.6 * w, 0.2 * h, -0.5 * w), "leather", shade(color, 0.9))
	end
end

-- Ball joints, to hide where a cylinder ends.
local function joints(ctx: Ctx, shoulder: Color3, shoulderKey: string, elbow: Color3, knee: Color3, kneeKey: string)
	local w, h = ctx.w, ctx.h
	for _, side in { "Right", "Left" } do
		ballAcc(ctx, side .. "UpperArm", side .. "ShoulderBall", V3(0.66 * w, 0.62 * h, 0.66 * w), CF(0, 0.55 * h, 0), shoulderKey, shoulder)
		ballAcc(ctx, side .. "UpperArm", side .. "ElbowBall", V3(0.5 * w, 0.5 * h, 0.5 * w), CF(0, -0.58 * h, 0), "skin", elbow)
		ballAcc(ctx, side .. "UpperLeg", side .. "KneeBall", V3(0.66 * w, 0.6 * h, 0.66 * w), CF(0, -0.56 * h, 0), kneeKey, knee)
	end
end

-- Veins: thin dark lines down the skin of a limb.
local function veins(ctx: Ctx, bone: string, length: number, radius: number)
	local w = ctx.w
	for i = -1, 1 do
		local v = cylAcc(ctx, bone, "Vein", length, 0.014, CF(i * radius * 0.7 * w, 0, -radius * 0.7 * w) * ANG(0, 0, rad(i * 4)), "dark", C.vein)
		v.CastShadow = false
	end
end

-- A blotch of decay on skin or cloth: flat, darker.
local function blotch(ctx: Ctx, bone: string, at: Vector3, size: Vector3, color: Color3)
	local b = ballAcc(ctx, bone, "Blotch", size, CF(at), "skin", color)
	b.CastShadow = false
end

-- Exposed ribs through a tear in the side of the torso.
local function ribs(ctx: Ctx, x: number, count: number)
	local w, h = ctx.w, ctx.h
	acc(ctx, "UpperTorso", "Tear", V3(0.72 * w, 1.0 * h, 0.04), CF(x * w, 0.1 * h, -0.435 * w), "skin", C.ichor).CastShadow = false
	for i = 0, count - 1 do
		local bar = cylAcc(ctx, "UpperTorso", "Rib" .. i, 0.62 * w, 0.032, CF(x * w, (0.46 - i * 0.2) * h, -0.46 * w) * ANG(0, 0, rad(90 + (i - 1.5) * 4)), "bone", shade(C.bone, 0.9))
		bar.CastShadow = false
	end
	acc(ctx, "UpperTorso", "Spine", V3(0.05, 0.9 * h, 0.04), CF((x + 0.34) * w, 0.1 * h, -0.46 * w), "bone", shade(C.bone, 0.85)).CastShadow = false
end

-- Hands: curled fingers and a thumb, both sides.
local function fingers(ctx: Ctx, curl: number)
	local w, h = ctx.w, ctx.h
	for _, side in { "Right", "Left" } do
		for i = -1, 1 do
			local f = cylAcc(ctx, side .. "Hand", "Finger", 0.34 * h, 0.04 * w, CF(i * 0.14 * w, -0.3 * h, -0.02 * w) * ANG(rad(-curl + math.abs(i) * 6), 0, rad(i * 3)) , "skin", C.skinDark)
			f.CastShadow = false
		end
		local t = cylAcc(ctx, side .. "Hand", "Thumb", 0.26 * h, 0.04 * w, CF((if side == "Right" then -0.24 else 0.24) * w, -0.1 * h, -0.05 * w) * ANG(rad(-curl * 0.6), 0, rad(if side == "Right" then 28 else -28)), "skin", C.skinDark)
		t.CastShadow = false
	end
end

-- The skull: cranium, hollow cheeks, deep sockets with the Hollow Light, a ruined nose,
-- teeth, and a jaw that hangs a little open. Everything in the head's frame.
--==========================================================================
-- THE FINE KIT (tools/BuildUndeadKit): heads, helmets, weapons and armour
-- sculpted from thousands of small cubes. Every helper returns nil when the kit
-- has not been built, so the plain pieces below stay as the fallback.
--==========================================================================
local function kitFolder(): Instance?
	local assets = ServerStorage:FindFirstChild("Assets")
	return assets and assets:FindFirstChild(if QUALITY == "field" then "UndeadKitField" else "UndeadKit")
end

local function mount(ctx: Ctx, piece: string, bone: string, world: CFrame, scale: number?): Model?
	local folder = kitFolder()
	local src = folder and folder:FindFirstChild(piece)
	if not src then
		return nil
	end
	local m = src:Clone() :: Model
	if scale and math.abs(scale - 1) > 0.001 then
		m:ScaleTo(scale)
	end
	m:PivotTo(world)
	for _, d in m:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanTouch = false
			d.CanQuery = false
			d.Massless = true
			weld(ctx.bones[bone], d)
		end
	end
	m.Parent = ctx.model
	return m
end

-- A kit piece placed in a bone's frame.
local function kit(ctx: Ctx, piece: string, bone: string, cf: CFrame, scale: number?): Model?
	return mount(ctx, piece, bone, ctx.frames[bone] * cf, scale)
end

-- A kit piece placed in the root's frame (y up, -Z forward).
local function kitRoot(ctx: Ctx, piece: string, bone: string, rootCf: CFrame, scale: number?): Model?
	return mount(ctx, piece, bone, ctx.root.CFrame * rootCf, scale)
end

-- A frame at `from` whose +X runs along `dir` (a weapon's own axis), rolled about it.
local function alongX(from: Vector3, dir: Vector3, roll: number?): CFrame
	return CFrame.lookAt(from, from + dir) * ANG(0, rad(90), 0) * ANG(rad(roll or 0), 0, 0)
end

-- The sculpted head, with the Hollow Light as two points in the clouded eyes.
local function kitHead(ctx: Ctx, piece: string, glow: number?): boolean
	local s = ctx.h
	if not kit(ctx, piece, "Head", CFrame.new(), s) then
		return false
	end
	ctx.bones.Head.Transparency = 1
	ctx.kitHead = true
	for _, sx in { -0.135, 0.135 } do
		local e = ballAcc(ctx, "Head", "HollowLight", V3(0.035, 0.035, 0.035) * s, CF(sx * s, 0.02 * s, -0.383 * s), "neon", C.eye)
		e.CastShadow = false
		e.Transparency = 1 - (glow or 0.85) * 0.9
	end
	return true
end

local function face(ctx: Ctx, glow: number?, jawOpen: number?, piece: string?)
	local w, h = ctx.w, ctx.h
	local open = (jawOpen or 12) + 8

	-- the neck, behind the skull
	cylAcc(ctx, "UpperTorso", "Neck", 0.34 * h, 0.2 * w, CF(0, 0.9 * h, 0.02 * w), "skin", C.skinDark)
	-- cords of the neck
	for _, sx in { -1, 1 } do
		cylAcc(ctx, "UpperTorso", "NeckCord", 0.3 * h, 0.04 * w, CF(sx * 0.1 * w, 0.88 * h, -0.14 * w) * ANG(rad(8), 0, 0), "skin", C.vein).CastShadow = false
	end
	if piece and kitHead(ctx, piece, glow) then
		return
	end

	for _, sx in { -1, 1 } do
		-- sunken socket, near black
		local socket = ballAcc(ctx, "Head", "Socket", V3(0.25 * w, 0.22 * h, 0.12 * w), CF(sx * 0.2 * w, 0.1 * h, -0.4 * w), "dark", C.socket)
		socket.CastShadow = false
		-- the Hollow Light: a point, deep in it
		local eye = ballAcc(ctx, "Head", "HollowLight", V3(0.085, 0.085, 0.05), CF(sx * 0.2 * w, 0.1 * h, -0.45 * w), "neon", C.eye)
		eye.CastShadow = false
		eye.Transparency = 1 - (glow or 0.85)
		-- hollow cheek and the cheekbone over it
		ballAcc(ctx, "Head", "Hollow", V3(0.24 * w, 0.3 * h, 0.1 * w), CF(sx * 0.27 * w, -0.14 * h, -0.38 * w), "skin", C.skinDark).CastShadow = false
		acc(ctx, "Head", "Cheekbone", V3(0.2 * w, 0.07 * h, 0.1 * w), CF(sx * 0.3 * w, -0.03 * h, -0.4 * w) * ANG(0, 0, rad(sx * 18)), "skin", C.skinPale).CastShadow = false
		-- ear
		wedgeAcc(ctx, "Head", "Ear", V3(0.07 * w, 0.26 * h, 0.2 * w), CF(sx * 0.46 * w, 0.0, 0.04 * w) * ANG(0, rad(if sx > 0 then 0 else 180), 0), "skin", C.skinDark).CastShadow = false
	end
	-- the brow, and a bridge down to a nose that is only a dark triangle
	acc(ctx, "Head", "Brow", V3(0.64 * w, 0.09 * h, 0.12 * w), CF(0, 0.24 * h, -0.4 * w), "skin", C.skinDark).CastShadow = false
	acc(ctx, "Head", "Bridge", V3(0.09 * w, 0.3 * h, 0.08 * w), CF(0, 0.06 * h, -0.45 * w), "skin", C.skinPale).CastShadow = false
	wedgeAcc(ctx, "Head", "NoseHole", V3(0.12 * w, 0.14 * h, 0.04 * w), CF(0, -0.12 * h, -0.46 * w) * ANG(0, 0, 0), "dark", C.socket).CastShadow = false

	-- the mouth: dark inside, teeth top and bottom, the jaw slack
	ballAcc(ctx, "Head", "MouthDark", V3(0.34 * w, 0.2 * h, 0.2 * w), CF(0, -0.3 * h, -0.36 * w), "dark", C.black).CastShadow = false
	acc(ctx, "Head", "TeethTop", V3(0.26 * w, 0.05 * h, 0.05 * w), CF(0, -0.24 * h, -0.45 * w), "bone", shade(C.bone, 0.72)).CastShadow = false
	local jaw = Instance.new("Model")
	jaw.Name = "Jaw"
	local jawPivot = CF(0, -0.2 * h, -0.1 * w)
	local jawRot = jawPivot * ANG(rad(open), 0, 0)
	local function jawPart(name: string, size: Vector3, cf: CFrame, key: string, color: Color3)
		local p = acc(ctx, "Head", name, size, jawRot * cf, key, color)
		p.CastShadow = false
		return p
	end
	jawPart("JawBone", V3(0.5 * w, 0.2 * h, 0.5 * w), CF(0, -0.18 * h, -0.2 * w), "skin", C.skinDark)
	jawPart("Chin", V3(0.34 * w, 0.14 * h, 0.2 * w), CF(0, -0.26 * h, -0.4 * w), "skin", C.skinDark)
	jawPart("TeethBottom", V3(0.22 * w, 0.045 * h, 0.05 * w), CF(0, -0.07 * h, -0.4 * w), "bone", shade(C.bone, 0.62))
end

-- Hair, matted: strands hanging off the back and sides of the skull.
local function hair(ctx: Ctx, color: Color3, amount: number)
	if ctx.kitHead then
		return -- the sculpted heads carry their own
	end
	local w, h = ctx.w, ctx.h
	for i = 1, amount do
		local a = ctx.rng:NextNumber(0, math.pi * 2)
		local ox, oz = math.cos(a) * 0.4 * w, math.sin(a) * 0.4 * w
		if oz < -0.1 then
			oz = -oz * 0.5 -- keep the face clear
		end
		local len = ctx.rng:NextNumber(0.3, 0.8) * h
		acc(ctx, "Head", "Hair" .. i, V3(0.07 * w, len, 0.05 * w), CF(ox, 0.34 * h - len / 2, oz) * ANG(0, -a, rad(ctx.rng:NextNumber(-8, 8))), "dark", shade(color, 1 + ctx.rng:NextNumber(-0.2, 0.2))).CastShadow = false
	end
end

local function boots(ctx: Ctx, color: Color3, cuff: Color3?)
	local w, h = ctx.w, ctx.h
	for _, side in { "Right", "Left" } do
		cylAcc(ctx, side .. "LowerLeg", side .. "BootTop", 0.62 * h, 0.31 * w, CF(0, -0.28 * h, 0), "leather", color)
		acc(ctx, side .. "Foot", side .. "Toe", V3(0.5 * w, 0.2 * h, 0.3 * w), CF(0, 0.0, -0.58 * w), "leather", shade(color, 0.9))
		cylAcc(ctx, side .. "LowerLeg", side .. "Cuff", 0.14 * h, 0.35 * w, CF(0, -0.0 * h, 0), "leather", cuff or shade(color, 1.25))
	end
end

-- A tabard: a long panel front and back, with the star, torn at the hem.
-- `out` pushes it off the body, for a tabard worn over armour.
local function tabard(ctx: Ctx, color: Color3, withStar: boolean, torn: boolean?, out: number?)
	local w, h = ctx.w, ctx.h
	local o = out or 0
	acc(ctx, "UpperTorso", "TabardFront", V3(1.3 * w, 1.0 * h, 0.07), CF(0, 0.18 * h, -0.46 * w - o), "cloth", color)
	acc(ctx, "UpperTorso", "TabardBack", V3(1.3 * w, 1.0 * h, 0.07), CF(0, 0.18 * h, 0.46 * w + o), "cloth", shade(color, 0.85))
	strips(ctx, "UpperTorso", "TabF", 5, 1.3 * w, 1.55 * h, CF(0, -0.32 * h, -0.465 * w - o), "cloth", color, if torn then 0.5 else 0.12, 4)
	strips(ctx, "UpperTorso", "TabB", 5, 1.3 * w, 1.55 * h, CF(0, -0.32 * h, 0.465 * w + o) * ANG(0, math.pi, 0), "cloth", shade(color, 0.85), if torn then 0.5 else 0.12, 4)
	if withStar then
		star(ctx, "UpperTorso", CF(0, 0.2 * h, -0.52 * w - o) * ANG(0, math.pi, 0), 0.56 * w, C.gold)
	end
end

-- A helmet from the kit, or the plain kettle hat if the kit is missing.
local function helmet(ctx: Ctx, piece: string, fallback: (() -> ())?, cf: CFrame?)
	local at = cf or (if piece == "helm_kettle" then CF(0, 0.07 * ctx.h, 0.04) * ANG(rad(10), 0, 0) else CFrame.new())
	if not kit(ctx, piece, "Head", at, ctx.h) and fallback then
		fallback()
	end
end

local function kettleHat(ctx: Ctx, color: Color3)
	local w, h = ctx.w, ctx.h
	cylAcc(ctx, "Head", "HatBrim", 0.06, 0.86 * w, CF(0, 0.28 * h, 0), "iron", shade(color, 0.85)).CastShadow = false
	ballAcc(ctx, "Head", "HatDome", V3(0.92 * w, 0.56 * h, 0.96 * w), CF(0, 0.4 * h, 0), "iron", shade(color, 0.9))
	-- the dent that killed him, and the rust round it
	ballAcc(ctx, "Head", "HatDent", V3(0.3 * w, 0.2 * h, 0.2 * w), CF(0.3 * w, 0.62 * h, -0.2 * w), "rusty", C.rustDark).CastShadow = false
	cylAcc(ctx, "Head", "ChinStrap", 0.6 * h, 0.018, CF(-0.46 * w, -0.04 * h, -0.08 * w), "leather", C.leatherDark).CastShadow = false
end

-- A coif of mail over the head and across the shoulders.
local function coif(ctx: Ctx, color: Color3)
	local w, h = ctx.w, ctx.h
	ballAcc(ctx, "Head", "Coif", V3(1.0 * w, 1.1 * h, 1.02 * w), CF(0, 0.04 * h, 0.04 * w), "mail", color)
	acc(ctx, "UpperTorso", "CoifCape", V3(1.74 * w, 0.28 * h, 0.96 * w), CF(0, 0.76 * h, 0), "mail", color)
	strips(ctx, "UpperTorso", "Aventail", 7, 1.7 * w, 0.5 * h, CF(0, 0.62 * h, -0.46 * w), "mail", shade(color, 0.9), 0.3, 12)
end

-- A raised hood, point at the back; the face stays in front of it, in shadow.
local function hood(ctx: Ctx, color: Color3, key: string)
	local w, h = ctx.w, ctx.h
	ballAcc(ctx, "Head", "Hood", V3(1.18 * w, 1.24 * h, 1.2 * w), CF(0, 0.1 * h, 0.2 * w), key, color)
	wedgeAcc(ctx, "Head", "HoodPoint", V3(0.7 * w, 0.8 * h, 0.7 * w), CF(0, 0.14 * h, 0.74 * w) * ANG(0, math.pi, 0), key, color)
	acc(ctx, "Head", "HoodBrow", V3(0.9 * w, 0.18 * h, 0.4 * w), CF(0, 0.44 * h, -0.28 * w), key, shade(color, 0.8))
	acc(ctx, "Head", "HoodFold", V3(1.7 * w, 0.3 * h, 1.0 * w), CF(0, -0.55 * h, 0.06 * w) * ANG(rad(-6), 0, 0), key, shade(color, 0.9))
end

local function arrowIn(ctx: Ctx, at: Vector3)
	local a = at
	local b = at + V3(0.15, 0.55, 0.85)
	rodRoot(ctx, "UpperTorso", "ArrowShaft", a, b, 0.028, "wood", C.wood)
	for k = 0, 1 do
		wedgeAcc(ctx, "UpperTorso", "Fletching" .. k, V3(0.015, 0.26, 0.24), CF(0, 0, 0), "cloth", C.linen).CFrame = ctx.root.CFrame * CFrame.lookAt(b + (a - b).Unit * 0.12 * (k + 1), b) * ANG(0, rad(90 * k), 0)
	end
end

--==========================================================================
-- THE TYPES
--==========================================================================
local TYPES: { [string]: any } = {}

local function leg(key: string, color: Color3)
	return { key, color }
end

-- Shambler: the household. Hunched, one arm reaching, the head forward of the shoulders.
TYPES.undead_shambler = {
	dressing = "gate guard",
	seed = 11,
	w = 1,
	h = 1,
	pose = {
		LowerTorso = V3(-8, 4, 5),
		UpperTorso = V3(-17, 8, -6),
		Head = V3(-6, -8, 10),
		RightUpperArm = V3(70, 0, -10),
		RightLowerArm = V3(38, 0, 0),
		LeftUpperArm = V3(20, 0, 12),
		LeftLowerArm = V3(14, 0, 0),
		RightUpperLeg = V3(-14, 0, -2),
		RightLowerLeg = V3(18, 0, 0),
		LeftUpperLeg = V3(20, 0, 4),
		LeftLowerLeg = V3(-12, 0, 0),
		LeftFoot = V3(0, 14, 0),
	},
	look = {
		UpperTorso = { "cloth", C.woad },
		LowerTorso = { "cloth", C.mud },
		RightUpperArm = { "cloth", C.woad },
		LeftUpperArm = { "cloth", C.woad },
		RightLowerArm = { "skin", C.skin },
		LeftLowerArm = { "skin", C.skin },
		RightUpperLeg = leg("cloth", shade(C.mud, 0.9)),
		LeftUpperLeg = leg("cloth", shade(C.mud, 0.9)),
		RightLowerLeg = leg("cloth", shade(C.mud, 0.8)),
		LeftLowerLeg = leg("cloth", shade(C.mud, 0.8)),
		RightFoot = { "leather", C.leatherDark },
		LeftFoot = { "leather", C.leatherDark },
	},
	dress = function(ctx: Ctx)
		local w, h = ctx.w, ctx.h
		face(ctx, 0.6, 18, "head_gaunt")
		fingers(ctx, 40)
		joints(ctx, C.woad, "cloth", C.skinDark, shade(C.mud, 0.9), "cloth")
		skirt(ctx, C.woad, "cloth", 1.0)
		tabard(ctx, C.bordeaux, true, true)
		belt(ctx, C.leather, true)
		boots(ctx, C.leatherDark)
		helmet(ctx, "helm_kettle", function()
			kettleHat(ctx, C.rustDark)
		end)
		hair(ctx, C.black, 8)
		ribs(ctx, -0.5, 4)
		veins(ctx, "RightLowerArm", 0.8 * h, 0.23)
		veins(ctx, "LeftLowerArm", 0.8 * h, 0.23)
		blotch(ctx, "LeftLowerArm", V3(0.1, 0.2, -0.2) * w, V3(0.3, 0.4, 0.14) * w, C.ichor)
		arrowIn(ctx, V3(0.5, 0.9, 0.5))
		-- a rag round the left hand and the sleeve that is gone from the right arm
		cylAcc(ctx, "LeftLowerArm", "Rag", 0.34 * h, 0.27 * w, CF(0, -0.28 * h, 0), "cloth", C.linen)
		strips(ctx, "RightUpperArm", "Sleeve", 4, 0.56 * w, 0.4 * h, CF(0, -0.36 * h, -0.3 * w), "cloth", C.woad, 0.6, 10)
	end,
}

-- A second dressing on the same type, to show what a dressing is.
TYPES.undead_shambler_scullion = {
	base = "undead_shambler",
	dressing = "scullion",
	seed = 12,
	look = {
		UpperTorso = { "cloth", C.linen },
		LowerTorso = { "cloth", shade(C.linen, 0.8) },
		RightUpperArm = { "cloth", C.linen },
		LeftUpperArm = { "cloth", C.linen },
		RightLowerArm = { "skin", C.skin },
		LeftLowerArm = { "skin", C.skin },
		RightUpperLeg = leg("cloth", C.mud),
		LeftUpperLeg = leg("cloth", C.mud),
		RightLowerLeg = leg("skin", C.skin),
		LeftLowerLeg = leg("cloth", C.mud),
		RightFoot = { "skin", C.skinDark },
		LeftFoot = { "leather", C.leatherDark },
	},
	dress = function(ctx: Ctx)
		local w, h = ctx.w, ctx.h
		face(ctx, 0.6, 22, "head_old")
		fingers(ctx, 44)
		joints(ctx, C.linen, "cloth", C.skinDark, C.mud, "cloth")
		skirt(ctx, C.linen, "cloth", 1.1)
		-- the apron, stained, torn at the hem
		acc(ctx, "UpperTorso", "ApronBib", V3(1.1 * w, 1.0 * h, 0.07), CF(0, 0.2 * h, -0.46 * w), "cloth", shade(C.linen, 0.78))
		strips(ctx, "UpperTorso", "Apron", 6, 1.3 * w, 1.7 * h, CF(0, -0.3 * h, -0.465 * w), "cloth", shade(C.linen, 0.74), 0.4, 6)
		acc(ctx, "UpperTorso", "Stain", V3(0.5 * w, 0.46 * h, 0.03), CF(0.2 * w, -0.2 * h, -0.5 * w), "cloth", C.rust).CastShadow = false
		acc(ctx, "UpperTorso", "Stain2", V3(0.3 * w, 0.6 * h, 0.03), CF(-0.3 * w, -0.5 * h, -0.5 * w), "cloth", shade(C.rust, 0.8)).CastShadow = false
		belt(ctx, C.leather, true)
		boots(ctx, C.leatherDark)
		-- a cap, tied behind
		ballAcc(ctx, "Head", "Cap", V3(1.02 * w, 0.7 * h, 1.04 * w), CF(0, 0.36 * h, 0.04 * w), "cloth", C.linen)
		wedgeAcc(ctx, "Head", "CapTie", V3(0.2 * w, 0.4 * h, 0.1 * w), CF(0, 0.2 * h, 0.52 * w) * ANG(0, math.pi, 0), "cloth", C.linen)
		hair(ctx, shade(C.mud, 0.7), 6)
		veins(ctx, "RightLowerArm", 0.8 * h, 0.23)
		veins(ctx, "LeftLowerArm", 0.8 * h, 0.23)
		blotch(ctx, "RightLowerLeg", V3(0.1, -0.1, -0.2) * w, V3(0.34, 0.5, 0.14) * w, C.ichor)
		-- a ladle in the reaching hand, and a cleaver at the belt
		local hand = handAt(ctx, "Right")
		rodRoot(ctx, "RightHand", "LadleHandle", hand + V3(0, 0.15, 0.35), hand + V3(0, -0.1, -1.55), 0.04, "wood", C.wood)
		rootAcc(ctx, "RightHand", "LadleBowl", V3(0.46, 0.2, 0.46), CF(hand + V3(0, -0.14, -1.7)), "iron", C.rustDark, Enum.PartType.Ball)
		acc(ctx, "LowerTorso", "CleaverBlade", V3(0.34 * w, 0.5 * h, 0.04), CF(-0.7 * w, -0.25 * h, -0.5 * w) * ANG(0, 0, rad(8)), "steel", shade(C.steel, 0.8))
		acc(ctx, "LowerTorso", "CleaverGrip", V3(0.08 * w, 0.3 * h, 0.08 * w), CF(-0.7 * w, 0.18 * h, -0.5 * w), "wood", C.wood)
	end,
}

-- Gravedigger: the biggest thing in the room, hooded, a grave-spade over the shoulder.
TYPES.undead_brute_heavy = {
	dressing = "gravedigger",
	seed = 21,
	w = 1.3,
	h = 1.16,
	pose = {
		LowerTorso = V3(-4, 0, 3),
		UpperTorso = V3(-12, -6, 0),
		Head = V3(-14, 0, 4),
		RightUpperArm = V3(38, 0, -16),
		RightLowerArm = V3(104, 0, 0),
		LeftUpperArm = V3(28, 0, 20),
		LeftLowerArm = V3(76, 0, 0),
		RightUpperLeg = V3(-8, 0, -3),
		RightLowerLeg = V3(10, 0, 0),
		LeftUpperLeg = V3(10, 0, 3),
		LeftLowerLeg = V3(4, 0, 0),
	},
	look = {
		UpperTorso = { "burlap", C.mud },
		LowerTorso = { "burlap", shade(C.mud, 0.8) },
		RightUpperArm = { "burlap", C.mud },
		LeftUpperArm = { "burlap", C.mud },
		RightLowerArm = { "skin", C.skin },
		LeftLowerArm = { "skin", C.skin },
		RightUpperLeg = leg("burlap", shade(C.mud, 0.7)),
		LeftUpperLeg = leg("burlap", shade(C.mud, 0.7)),
		RightLowerLeg = leg("burlap", shade(C.mud, 0.65)),
		LeftLowerLeg = leg("burlap", shade(C.mud, 0.65)),
		RightFoot = { "leather", C.leatherDark },
		LeftFoot = { "leather", C.leatherDark },
	},
	dress = function(ctx: Ctx)
		local w, h = ctx.w, ctx.h
		face(ctx, 0.78, 14, "head_heavy")
		fingers(ctx, 56)
		joints(ctx, shade(C.mud, 0.9), "burlap", C.skinDark, shade(C.mud, 0.7), "burlap")
		hood(ctx, shade(C.leatherDark, 1.3), "burlap")
		-- the sack across the shoulders, a mantle of hide
		acc(ctx, "UpperTorso", "Sack", V3(2.4 * w, 0.5 * h, 1.15 * w), CF(0, 0.62 * h, 0.02), "burlap", shade(C.mud, 0.95))
		strips(ctx, "UpperTorso", "Mantle", 8, 2.3 * w, 0.8 * h, CF(0, 0.45 * h, -0.5 * w), "burlap", shade(C.mud, 0.8), 0.4, 9)
		-- leather apron, split and black with old soil
		acc(ctx, "UpperTorso", "ApronBib", V3(1.4 * w, 1.0 * h, 0.08), CF(0, 0.2 * h, -0.47 * w), "leather", C.leather)
		strips(ctx, "UpperTorso", "Apron", 5, 1.5 * w, 1.8 * h, CF(0, -0.3 * h, -0.48 * w), "leather", shade(C.leather, 0.9), 0.35, 5)
		cloak(ctx, shade(C.mud, 0.7), "burlap", 2.8, 2.1)
		skirt(ctx, shade(C.mud, 0.7), "burlap", 1.3)
		-- a rope for a belt with the coil hanging, a lantern, a bunch of keys
		acc(ctx, "LowerTorso", "Rope", V3(1.72 * w, 0.14 * h, 0.96 * w), CF(0, 0.12 * h, 0), "burlap", C.linen)
		cylAcc(ctx, "LowerTorso", "RopeCoil", 0.2 * h, 0.3 * w, CF(-0.8 * w, -0.1 * h, -0.2 * w) * ANG(0, 0, rad(90)), "burlap", shade(C.linen, 0.9))
		acc(ctx, "LowerTorso", "Lantern", V3(0.3 * w, 0.4 * h, 0.3 * w), CF(0.82 * w, -0.1 * h, -0.2 * w), "iron", C.rustDark)
		ballAcc(ctx, "LowerTorso", "LanternEmber", V3(0.14, 0.14, 0.14), CF(0.82 * w, -0.08 * h, -0.2 * w), "neon", rgb(255, 120, 40)).CastShadow = false
		boots(ctx, C.leatherDark, shade(C.mud, 0.7))
		veins(ctx, "RightLowerArm", 0.8 * h, 0.23 * w)
		veins(ctx, "LeftLowerArm", 0.8 * h, 0.23 * w)
		blotch(ctx, "RightLowerArm", V3(0.1, 0.1, -0.2) * w, V3(0.3, 0.4, 0.14) * w, C.ichor)
		-- the grave-spade, two-handed, resting back over the right shoulder
		local r = handAt(ctx, "Right")
		local l = handAt(ctx, "Left")
		local dir = (r - l).Unit
		local bottom = l - dir * 1.7
		local top = r + dir * 2.4
		-- the sculpted spade: T-grip up behind the shoulder, the blade down in front,
		-- turned so the blade's face looks forward
		if not kitRoot(ctx, "spade", "RightHand", alongX(top, -dir, 90)) then
			rodRoot(ctx, "RightHand", "SpadeShaft", bottom, top, 0.095, "wood", C.wood)
			local blade = rootAcc(ctx, "RightHand", "SpadeBlade", V3(0.95, 1.2, 0.08), CFrame.lookAt(bottom - dir * 0.6, bottom - dir * 1.3), "iron", C.rustDark)
			blade.CastShadow = false
			rootAcc(ctx, "RightHand", "SpadeRim", V3(1.0, 0.1, 0.14), CFrame.lookAt(bottom - dir * 1.2, bottom - dir * 1.9), "iron", C.rust).CastShadow = false
			rootAcc(ctx, "RightHand", "SpadeSocket", V3(0.3, 0.46, 0.3), CFrame.lookAt(bottom - dir * 0.1, bottom - dir), "iron", C.rustDark, Enum.PartType.Cylinder)
			rootAcc(ctx, "RightHand", "SpadeGrip", V3(0.7, 0.13, 0.13), CFrame.lookAt(top, top + dir) * ANG(0, rad(90), rad(90)), "wood", C.woodDark)
			rootAcc(ctx, "RightHand", "SoilOnBlade", V3(0.6, 0.5, 0.1), CFrame.lookAt(bottom - dir * 0.9, bottom - dir * 1.5), "burlap", shade(C.mud, 0.55)).CastShadow = false
		end
		-- soil caked on everything below the knee
		for _, side in { "Right", "Left" } do
			cylAcc(ctx, side .. "LowerLeg", side .. "Dirt", 0.5 * h, 0.34 * w, CF(0, -0.3 * h, 0), "burlap", shade(C.mud, 0.5)).CastShadow = false
		end
	end,
}

-- Pikeman: the tall thin one, kettle-hat, brigandine, a spear taller than he is.
TYPES.undead_spearman = {
	dressing = "line pikeman",
	seed = 31,
	w = 0.94,
	h = 1.08,
	pose = {
		LowerTorso = V3(0, -8, -2),
		UpperTorso = V3(-6, -16, 0),
		Head = V3(-4, 12, 0),
		RightUpperArm = V3(40, 0, -8),
		RightLowerArm = V3(64, 0, 0),
		LeftUpperArm = V3(60, 0, 14),
		LeftLowerArm = V3(36, 0, 0),
		RightUpperLeg = V3(10, 0, 0),
		RightLowerLeg = V3(8, 0, 0),
		LeftUpperLeg = V3(-16, 0, 0),
		LeftLowerLeg = V3(10, 0, 0),
	},
	look = {
		UpperTorso = { "leather", C.leather },
		LowerTorso = { "cloth", C.woad },
		RightUpperArm = { "cloth", C.woad },
		LeftUpperArm = { "cloth", C.woad },
		RightLowerArm = { "mail", C.mail },
		LeftLowerArm = { "mail", C.mail },
		RightUpperLeg = leg("cloth", C.woad),
		LeftUpperLeg = leg("cloth", C.woad),
		RightLowerLeg = leg("cloth", shade(C.woad, 0.8)),
		LeftLowerLeg = leg("cloth", shade(C.woad, 0.8)),
		RightFoot = { "leather", C.leatherDark },
		LeftFoot = { "leather", C.leatherDark },
	},
	dress = function(ctx: Ctx)
		local w, h = ctx.w, ctx.h
		face(ctx, 0.72, 10, "head_old")
		fingers(ctx, 50)
		joints(ctx, C.steel, "steel", C.mail, shade(C.woad, 0.9), "cloth")
		skirt(ctx, C.woad, "cloth", 0.9)
		-- the brigandine: cloth over small plates, the brass rivet heads in rows
		local brig = kit(ctx, "torso_brigandine", "UpperTorso", CFrame.new(), math.max(w, h))
		if not brig then
			for row = 0, 3 do
				acc(ctx, "UpperTorso", "Plate" .. row, V3(1.88 * w, 0.28 * h, 0.9 * w), CF(0, (0.52 - row * 0.34) * h, 0), "steel", shade(C.steel, 0.74 + 0.05 * (row % 2))).CastShadow = false
				for k = -3, 3 do
					ballAcc(ctx, "UpperTorso", "Rivet", V3(0.07, 0.07, 0.05), CF(k * 0.25 * w, (0.52 - row * 0.34) * h, -0.455 * w), "gold", shade(C.gold, 0.7)).CastShadow = false
				end
			end
		end
		-- the tabard over it, narrower, so the brigandine shows at the sides
		tabard(ctx, C.bordeaux, true, true, if brig then 0.1 else 0)
		belt(ctx, C.leather, true)
		boots(ctx, C.leatherDark)
		-- vambraces
		for _, side in { "Right", "Left" } do
			if not kit(ctx, "vambrace", side .. "LowerArm", CF(0, -0.05 * h, 0), w) then
				cylAcc(ctx, side .. "LowerArm", side .. "Vambrace", 0.7 * h, 0.25 * w, CF(0, -0.05 * h, 0), "steel", shade(C.steel, 0.7))
			end
		end
		helmet(ctx, "helm_kettle", function()
			kettleHat(ctx, C.rustDark)
		end)
		hair(ctx, C.black, 5)
		-- the dead in a mail aventail
		strips(ctx, "UpperTorso", "Gorget", 7, 1.5 * w, 0.4 * h, CF(0, 0.74 * h, -0.4 * w - (if brig then 0.06 else 0)), "mail", C.mail, 0.3, 14)
		blotch(ctx, "RightUpperLeg", V3(0.0, 0.0, -0.3) * w, V3(0.36, 0.5, 0.14) * w, C.ichor)
		-- the spear, long, held low and forward
		local r = handAt(ctx, "Right")
		local l = handAt(ctx, "Left")
		local dir = (l - r).Unit
		local butt = r - dir * 2.6
		local tip = l + dir * 8.4
		if kitRoot(ctx, "spear_shaft", "RightHand", alongX(butt, dir)) then
			-- the sculpted head goes on the end of the sculpted shaft
			tip = butt + dir * 9.8
			kitRoot(ctx, "spear_head", "RightHand", alongX(tip, dir))
		else
			rodRoot(ctx, "RightHand", "SpearShaft", butt, tip, 0.085, "wood", C.wood)
			rootAcc(ctx, "RightHand", "SpearButt", V3(0.3, 0.2, 0.2), CFrame.lookAt(butt - dir * 0.1, butt - dir), "iron", C.rustDark, Enum.PartType.Cylinder)
			local headCf = CFrame.lookAt(tip + dir * 0.7, tip + dir * 2)
			rootAcc(ctx, "RightHand", "SpearHead", V3(0.34, 0.06, 1.1), headCf, "steel", shade(C.steel, 0.8))
			rootAcc(ctx, "RightHand", "SpearHeadCross", V3(0.06, 0.34, 1.1), headCf, "steel", shade(C.steel, 0.7))
			rootAcc(ctx, "RightHand", "SpearTip", V3(0.18, 0.06, 0.5), headCf * CF(0, 0, -0.7), "steel", shade(C.steel, 0.9), nil, "WedgePart")
			rootAcc(ctx, "RightHand", "SpearSocket", V3(0.2, 0.2, 0.9), CFrame.lookAt(tip + dir * 0.1, tip + dir), "iron", C.rustDark, Enum.PartType.Cylinder)
		end
		-- a rag of pennon below the head
		for k = 0, 2 do
			rootAcc(ctx, "RightHand", "Pennon" .. k, V3(0.03, 0.18, 0.9 - k * 0.2), CFrame.lookAt(tip - dir * (0.2 + k * 0.05) + V3(0, -0.12 - k * 0.1, 0), tip + dir), "cloth", C.bordeaux).CastShadow = false
		end
	end,
}

-- Shieldman: wide and low behind a kite shield with the whole star on it.
TYPES.undead_sentinel = {
	dressing = "household guard",
	seed = 41,
	w = 1.14,
	h = 1.02,
	pose = {
		LowerTorso = V3(-2, 4, 0),
		UpperTorso = V3(-8, 10, 0),
		Head = V3(-6, -10, 0),
		LeftUpperArm = V3(20, 0, 8),
		LeftLowerArm = V3(88, 0, 0),
		RightUpperArm = V3(-12, 0, -12),
		RightLowerArm = V3(68, 0, 0),
		RightUpperLeg = V3(-10, 0, 0),
		RightLowerLeg = V3(12, 0, 0),
		LeftUpperLeg = V3(14, 0, 4),
		LeftLowerLeg = V3(6, 0, 0),
	},
	look = {
		UpperTorso = { "mail", C.mail },
		LowerTorso = { "cloth", C.bordeaux },
		RightUpperArm = { "mail", C.mail },
		LeftUpperArm = { "mail", C.mail },
		RightLowerArm = { "steel", C.steel },
		LeftLowerArm = { "steel", C.steel },
		RightUpperLeg = leg("cloth", shade(C.bordeaux, 0.8)),
		LeftUpperLeg = leg("cloth", shade(C.bordeaux, 0.8)),
		RightLowerLeg = leg("steel", shade(C.steel, 0.75)),
		LeftLowerLeg = leg("steel", shade(C.steel, 0.75)),
		RightFoot = { "leather", C.leatherDark },
		LeftFoot = { "leather", C.leatherDark },
	},
	dress = function(ctx: Ctx)
		local w, h = ctx.w, ctx.h
		face(ctx, 0.9, 8, "head_heavy")
		fingers(ctx, 54)
		joints(ctx, C.steel, "steel", C.steel, shade(C.steel, 0.8), "steel")
		skirt(ctx, C.bordeaux, "cloth", 1.2, 0.3)
		-- the hauberk, and the surcoat over it
		local hauberk = kit(ctx, "torso_hauberk", "UpperTorso", CFrame.new(), math.max(w, h))
		tabard(ctx, C.bordeaux, true, false, if hauberk then 0.08 else 0)
		belt(ctx, C.leatherDark, false)
		boots(ctx, C.leatherDark, C.steel)
		-- mail coif, then a nasal helm over it
		if not kit(ctx, "coif_mail", "Head", CFrame.new(), h) then
			coif(ctx, C.mail)
		end
		helmet(ctx, "helm_nasal", function()
			ballAcc(ctx, "Head", "HelmDome", V3(1.04 * w, 0.84 * h, 1.08 * w), CF(0, 0.42 * h, 0), "steel", C.steel)
			cylAcc(ctx, "Head", "HelmBand", 0.1, 0.52 * w, CF(0, 0.2 * h, 0), "steel", shade(C.steel, 0.8)).CastShadow = false
			acc(ctx, "Head", "Nasal", V3(0.09, 0.6 * h, 0.06), CF(0, 0.06 * h, -0.5 * w), "steel", C.steel).CastShadow = false
		end)
		-- pauldrons, vambraces, greaves
		if not kit(ctx, "pauldron_r", "UpperTorso", CF(1.08 * w, 0.62 * h, 0), w) then
			for _, sx in { -1, 1 } do
				acc(ctx, "UpperTorso", "Pauldron", V3(0.9 * w, 0.26 * h, 0.9 * w), CF(sx * 1.08 * w, 0.76 * h, 0) * ANG(0, 0, rad(-sx * 16)), "steel", C.steel)
				acc(ctx, "UpperTorso", "PauldronLame", V3(0.84 * w, 0.2 * h, 0.84 * w), CF(sx * 1.1 * w, 0.58 * h, 0) * ANG(0, 0, rad(-sx * 12)), "steel", shade(C.steel, 0.85))
			end
		else
			kit(ctx, "pauldron_l", "UpperTorso", CF(-1.08 * w, 0.62 * h, 0), w)
		end
		for _, side in { "Right", "Left" } do
			kit(ctx, "vambrace", side .. "LowerArm", CF(0, -0.05 * h, 0), w)
			kit(ctx, "greave", side .. "LowerLeg", CF(0, -0.05 * h, 0), w)
		end
		-- the kite shield, on the left forearm, face out
		local l = pointOf(ctx, "LeftLowerArm")
		if not kitRoot(ctx, "shield_kite", "LeftLowerArm", CF(l + V3(0.35, 0.05, -0.4)) * ANG(0, rad(-10), 0)) then
			local at = CF(l + V3(0.7, 0.5, -0.7))
			local W = 1.7
			rootAcc(ctx, "LeftLowerArm", "ShieldTop", V3(W, 1.6, 0.16), at * CF(0, 0.5, 0), "wood", C.bordeaux)
			rootAcc(ctx, "LeftLowerArm", "ShieldPointL", V3(0.16, 1.5, W / 2), at * CF(-W / 4, -1.05, 0) * ANG(0, rad(90), 0) * ANG(0, 0, rad(180)), "wood", C.bordeaux, nil, "WedgePart")
			rootAcc(ctx, "LeftLowerArm", "ShieldPointR", V3(0.16, 1.5, W / 2), at * CF(W / 4, -1.05, 0) * ANG(0, rad(-90), 0) * ANG(0, 0, rad(180)), "wood", C.bordeaux, nil, "WedgePart")
			rootAcc(ctx, "LeftLowerArm", "ShieldBoss", V3(0.5, 0.5, 0.22), at * CF(0, 0.5, -0.1), "iron", C.rustDark, Enum.PartType.Ball)
			star(ctx, "LeftLowerArm", ctx.frames.LeftLowerArm:ToObjectSpace(ctx.root.CFrame * at * CF(0, 0.5, -0.12) * ANG(0, math.pi, 0)), 1.0, C.gold)
		end
		-- the arming sword, point up and forward, the flat of the blade to the front
		local r = handAt(ctx, "Right")
		if not kitRoot(ctx, "sword_arming", "RightHand", alongX(r, V3(0.3, 1, -0.4).Unit, 90)) then
			local tipP = r + V3(0.2, 3.3, -0.7)
			rodRoot(ctx, "RightHand", "SwordBlade", r + V3(0, 0.15, -0.1), tipP, 0.06, "steel", C.steel)
			rodRoot(ctx, "RightHand", "SwordGuard", r + V3(-0.5, 0.15, -0.1), r + V3(0.5, 0.15, -0.1), 0.055, "iron", C.rustDark)
		end
		blotch(ctx, "RightLowerLeg", V3(0, -0.1, -0.28) * w, V3(0.3, 0.46, 0.12) * w, C.ichor)
	end,
}

-- Wall archer: thin, coifed, a bow taller than the shoulders.
TYPES.undead_archer = {
	dressing = "wall archer",
	seed = 51,
	w = 0.9,
	h = 1.04,
	pose = {
		LowerTorso = V3(0, -10, 0),
		UpperTorso = V3(-6, -26, 0),
		Head = V3(-2, 26, 0),
		LeftUpperArm = V3(86, 0, 4),
		LeftLowerArm = V3(4, 0, 0),
		RightUpperArm = V3(48, 0, -32),
		RightLowerArm = V3(116, 0, 0),
		RightUpperLeg = V3(-8, 0, 0),
		RightLowerLeg = V3(10, 0, 0),
		LeftUpperLeg = V3(14, 0, 0),
		LeftLowerLeg = V3(6, 0, 0),
	},
	look = {
		UpperTorso = { "cloth", C.woad },
		LowerTorso = { "cloth", C.woad },
		RightUpperArm = { "cloth", C.woad },
		LeftUpperArm = { "cloth", C.woad },
		RightLowerArm = { "leather", C.leather },
		LeftLowerArm = { "leather", C.leather },
		RightUpperLeg = leg("cloth", C.mud),
		LeftUpperLeg = leg("cloth", C.mud),
		RightLowerLeg = leg("cloth", C.mud),
		LeftLowerLeg = leg("cloth", C.mud),
		RightFoot = { "leather", C.leatherDark },
		LeftFoot = { "leather", C.leatherDark },
	},
	dress = function(ctx: Ctx)
		local w, h = ctx.w, ctx.h
		face(ctx, 0.7, 12, "head_gaunt")
		fingers(ctx, 46)
		joints(ctx, C.woad, "cloth", C.leather, C.mud, "cloth")
		skirt(ctx, C.woad, "cloth", 1.0)
		belt(ctx, C.leather, true)
		boots(ctx, C.leatherDark)
		if not kit(ctx, "coif_mail", "Head", CFrame.new(), h) then
			coif(ctx, C.mail)
		end
		cloak(ctx, shade(C.woad, 0.65), "cloth", 2.4, 1.9)
		-- a quiver across the back, and its arrows: nocks and fletching up, heads down
		local quiverAt = CF(0.32 * w, -0.35 * h, 0.78 * w) * ANG(0, 0, rad(-12))
		if kit(ctx, "quiver", "UpperTorso", quiverAt, 1.5) then
			for i = 0, 4 do
				local off = CF(-0.09 + (i % 3) * 0.09, 1.55 + (i % 2) * 0.08, -0.06 + math.floor(i / 3) * 0.1)
				kit(ctx, "arrow", "UpperTorso", quiverAt * off * ANG(0, rad(i * 40), rad(-90)))
			end
		else
			acc(ctx, "UpperTorso", "Quiver", V3(0.5 * w, 1.6 * h, 0.5 * w), CF(0.3 * w, 0.1 * h, 0.8 * w) * ANG(0, 0, rad(-10)), "leather", C.leather)
		end
		acc(ctx, "UpperTorso", "Strap", V3(0.12, 2.0 * h, 0.06), CF(0, 0.0, -0.5 * w) * ANG(0, 0, rad(-32)), "leather", C.leatherDark)
		arrowIn(ctx, V3(-0.5, 0.7, 0.55))
		-- a bracer
		if not kit(ctx, "vambrace", "LeftLowerArm", CF(0, -0.1 * h, 0), w) then
			cylAcc(ctx, "LeftLowerArm", "Bracer", 0.6 * h, 0.27 * w, CF(0, -0.1 * h, 0), "leather", C.leatherDark)
		end
		-- the bow, in the left hand, the stave upright, the string toward the archer
		local l = handAt(ctx, "Left")
		local bowAt = CFrame.fromMatrix(l, V3(0, 1, 0), V3(-1, 0, 0), V3(0, 0, 1))
		if kitRoot(ctx, "bow_long", "LeftHand", bowAt) then
			-- an arrow nocked on the string, held by the right hand
			local rH = handAt(ctx, "Right")
			local nock = l + V3(0, 0, 0.31)
			kitRoot(ctx, "arrow", "RightHand", alongX(rH + (nock - rH) * 0.2, (l - rH + V3(0, 0, -0.6)).Unit))
			return
		end
		local pts = {
			l + V3(0.0, 2.6, 0.32),
			l + V3(0.0, 1.8, 0.1),
			l + V3(0.0, 0.9, -0.02),
			l + V3(0.0, 0.0, -0.08),
			l + V3(0.0, -0.9, -0.02),
			l + V3(0.0, -1.8, 0.1),
			l + V3(0.0, -2.6, 0.32),
		}
		for i = 1, 6 do
			rodRoot(ctx, "LeftHand", "BowLimb" .. i, pts[i], pts[i + 1], 0.065 - math.abs(3.5 - i - 0.5) * 0.004, "wood", C.wood)
		end
		rodRoot(ctx, "LeftHand", "BowGrip", pts[3] + V3(0, 0.4, 0), pts[5] + V3(0, -0.4, 0), 0.085, "leather", C.leatherDark)
		rodRoot(ctx, "LeftHand", "BowString", pts[1], pts[7], 0.012, "cloth", C.linen)
	end,
}

-- Runner: the couriers. Low, forward, arms trailing behind, a horn at the hip.
TYPES.undead_runner = {
	dressing = "courier",
	seed = 61,
	w = 0.86,
	h = 0.98,
	pose = {
		LowerTorso = V3(-14, 0, 0),
		UpperTorso = V3(-36, 0, 0),
		Head = V3(34, 0, 0),
		RightUpperArm = V3(8, 0, -12),
		RightLowerArm = V3(32, 0, 0),
		LeftUpperArm = V3(60, 0, 12),
		LeftLowerArm = V3(70, 0, 0),
		RightUpperLeg = V3(-44, 0, 0),
		RightLowerLeg = V3(42, 0, 0),
		LeftUpperLeg = V3(34, 0, 0),
		LeftLowerLeg = V3(30, 0, 0),
	},
	look = {
		UpperTorso = { "cloth", shade(C.linen, 0.8) },
		LowerTorso = { "cloth", C.mud },
		RightUpperArm = { "cloth", shade(C.linen, 0.8) },
		LeftUpperArm = { "cloth", shade(C.linen, 0.8) },
		RightLowerArm = { "skin", C.skin },
		LeftLowerArm = { "skin", C.skin },
		RightUpperLeg = leg("cloth", C.woad),
		LeftUpperLeg = leg("cloth", C.woad),
		RightLowerLeg = leg("skin", C.skin),
		LeftLowerLeg = leg("skin", C.skin),
		RightFoot = { "skin", C.skinDark },
		LeftFoot = { "skin", C.skinDark },
	},
	dress = function(ctx: Ctx)
		local w, h = ctx.w, ctx.h
		face(ctx, 0.95, 30, "head_torn")
		fingers(ctx, 30)
		joints(ctx, shade(C.linen, 0.8), "cloth", C.skinDark, C.woad, "cloth")
		skirt(ctx, C.mud, "cloth", 0.8, 0.6)
		belt(ctx, C.leather, false)
		-- starved: the ribs show through the torn shirt, the spine down the back
		ribs(ctx, 0.0, 5)
		-- the satchel and its strap
		acc(ctx, "LowerTorso", "Satchel", V3(0.7 * w, 0.7 * h, 0.35 * w), CF(-0.95 * w, -0.15 * h, 0.1 * w), "leather", C.leather)
		acc(ctx, "LowerTorso", "SatchelFlap", V3(0.72 * w, 0.22 * h, 0.38 * w), CF(-0.95 * w, 0.12 * h, 0.1 * w), "leather", shade(C.leather, 0.85))
		acc(ctx, "UpperTorso", "Strap", V3(0.12, 2.1 * h, 0.06), CF(0, 0, -0.46 * w) * ANG(0, 0, rad(28)), "leather", C.leatherDark)
		-- the courier's horn, hanging off the strap
		local horn = V3(0.65, 0.4, 0.5)
		rodRoot(ctx, "UpperTorso", "HornTube", horn, horn + V3(0.35, -0.5, 0.15), 0.09, "bone", C.bone)
		rodRoot(ctx, "UpperTorso", "HornBell", horn + V3(0.35, -0.5, 0.15), horn + V3(0.55, -0.9, 0.2), 0.19, "bone", shade(C.bone, 0.8))
		rodRoot(ctx, "UpperTorso", "HornBand", horn + V3(0.1, -0.15, 0.05), horn + V3(0.14, -0.2, 0.06), 0.11, "gold", C.gold).CastShadow = false
		-- matted hair, a few tufts left
		hair(ctx, C.black, 10)
		veins(ctx, "RightLowerArm", 0.8 * h, 0.23)
		veins(ctx, "LeftLowerArm", 0.8 * h, 0.23)
		veins(ctx, "RightLowerLeg", 0.8 * h, 0.26)
		blotch(ctx, "RightUpperArm", V3(0.1, 0.1, -0.2) * w, V3(0.3, 0.46, 0.14) * w, C.ichor)
	end,
}

--==========================================================================
local function resolve(id: string): any
	local spec = TYPES[id]
	if spec.base then
		local merged = table.clone(TYPES[spec.base])
		for k, v in spec do
			merged[k] = v
		end
		return merged
	end
	return spec
end

local function buildType(id: string): Model
	local spec = resolve(id)
	local ctx = buildBody(id, spec, spec.seed or 1)
	spec.dress(ctx)
	finishModel(ctx, spec.base or id, spec.dressing)
	ctx.model.Name = id
	return ctx.model
end

--==========================================================================
local recording = ChangeHistoryService:TryBeginRecording("BuildUndead")

local assets = ServerStorage:FindFirstChild("Assets") or Instance.new("Folder")
assets.Name = "Assets"
assets.Parent = ServerStorage
local STORE_NAME = if QUALITY == "field" then "Undead" else "UndeadFine"
local store = assets:FindFirstChild(STORE_NAME) or Instance.new("Folder")
store.Name = STORE_NAME
store.Parent = assets

local stage = Workspace:FindFirstChild("UndeadLineup")
if stage then
	stage:Destroy()
end

if MODE ~= "clear" then
	local order = {
		"undead_shambler",
		"undead_shambler_scullion",
		"undead_runner",
		"undead_brute_heavy",
		"undead_spearman",
		"undead_archer",
		"undead_sentinel",
	}
	local built = {}
	for _, id in order do
		if not ONLY or table.find(ONLY, id) then
			local old = store:FindFirstChild(id)
			if old then
				old:Destroy()
			end
			local m = buildType(id)
			m.Parent = store
			table.insert(built, m)
		end
	end

	if MODE == "lineup" then
		stage = Instance.new("Folder")
		stage.Name = "UndeadLineup"
		stage.Parent = Workspace
		local z = 215
		local x0 = -(#built - 1) * 7 / 2
		local params = RaycastParams.new()
		params.FilterType = Enum.RaycastFilterType.Include
		params.FilterDescendantsInstances = { Workspace.Terrain }
		for i, m in built do
			local copy = m:Clone()
			local x = x0 + (i - 1) * 7
			local hit = Workspace:Raycast(V3(x, 80, z), V3(0, -200, 0), params)
			local gy = hit and hit.Position.Y or 2
			copy.Parent = stage
			copy:PivotTo(CF(x, gy + 2.5, z) * ANG(0, math.pi, 0))
		end
		-- the light that stands in for a torch: warm, low, to one side; a cold fill from the other
		local lamp = Instance.new("Part")
		lamp.Name = "StageLight"
		lamp.Anchored = true
		lamp.CanCollide = false
		lamp.Transparency = 1
		lamp.Size = V3(1, 1, 1)
		lamp.Position = V3(x0 * 0.5, 8, z + 13)
		lamp.Parent = stage
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(255, 170, 100)
		light.Brightness = 1.4
		light.Range = 80
		light.Parent = lamp
		local lamp2 = lamp:Clone()
		lamp2:ClearAllChildren()
		lamp2.Position = V3(-x0 * 0.5, 9, z + 16)
		lamp2.Parent = stage
		local fill = Instance.new("PointLight")
		fill.Color = Color3.fromRGB(150, 175, 230)
		fill.Brightness = 0.8
		fill.Range = 80
		fill.Parent = lamp2
	end
end

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("[BuildUndead] " .. MODE .. " — " .. #store:GetChildren() .. " master(s) in ServerStorage.Assets.Undead")
