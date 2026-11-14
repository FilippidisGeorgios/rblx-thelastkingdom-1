--!nonstrict
--[[
	zombie/Bones — takes the flesh off a forearm and a hand and puts real skeleton meshes in its place.

	  Bones.arm(model, "Right" | "Left", opts)   opts: { armour = true } also hides the vambrace and the gauntlet
	  Bones.arms(model, opts)                    both arms
	  Bones.setLibrary(folder)                   the loaded asset (ServerStorage.ZombieLab.BoneArmMeshes by default)

	The meshes (tools/blender/make_bone_arm.py, uploaded as asset 99818223615911) are built in the frames of the bodies'
	own LowerArm and Hand, so each is welded with no turning. The importer turns a glTF model half a turn about Y, which is
	undone here (RY180): see docs/Pipelines.md.

	The original forearm, hand, fingers and veins are not deleted: they are made invisible, so the joints, the held weapon
	and the animation keep working exactly as before.
]]

local ServerStorage = game:GetService("ServerStorage")

local Bones = {}

local RY180 = CFrame.Angles(0, math.pi, 0)
Bones.COLOR = Color3.fromRGB(158, 146, 122)
Bones.THICK = 1.5 -- a skeleton's bones are thin, but at stud scale thin ones vanish: the forearm is fattened across its length
Bones.MATERIAL = Enum.Material.Limestone

local function library()
	local lab = ServerStorage:FindFirstChild("ZombieLab")
	local lib = lab and lab:FindFirstChild("BoneArmMeshes")
	assert(lib, "load the bone arm first (ZombieLab.BoneArmMeshes)")
	return lib
end

local function hide(p: BasePart)
	p.Transparency = 1
	p.CastShadow = false
end

local function weld(part0: BasePart, part1: BasePart, c0: CFrame)
	local w = Instance.new("Weld")
	w.Name = "BoneWeld"
	w.Part0 = part0
	w.Part1 = part1
	w.C0 = c0
	w.Parent = part1
end

local function finishMesh(m: MeshPart)
	m.Anchored = false
	m.CanCollide = false
	m.CanQuery = false
	m.CanTouch = false
	m.Massless = true
	m.CastShadow = true
	m.Material = Bones.MATERIAL
	m.Color = Bones.COLOR
	m.TextureID = ""
end

-- the meshes are placed in the target's frame: undo the importer's half turn about Y, then scale about the frame's origin
local function place(src: MeshPart, part0: BasePart, scale: Vector3, name: string): MeshPart
	local m = src:Clone()
	m.Name = name
	m.Size = src.Size * scale
	local c0 = RY180 * src.CFrame
	c0 = CFrame.new(c0.Position * scale) * c0.Rotation
	m.CFrame = part0.CFrame * c0
	finishMesh(m)
	m.Parent = part0.Parent
	weld(part0, m, c0)
	return m
end

local FLESH = { "^Finger", "^Thumb", "^Knuckles", "^Vein" }
local ARMOUR = { "Vambrace", "Gauntlet", "^Seam$" }

local function matches(name: string, patterns: { string }): boolean
	for _, p in patterns do
		if string.find(name, p) then
			return true
		end
	end
	return false
end

-- parts welded straight onto `part` whose names say flesh (or armour, if asked)
local function fleshOn(model: Model, part: BasePart, armour: boolean?): { BasePart }
	local found = {}
	for _, d in model:GetDescendants() do
		if d:IsA("Weld") or d:IsA("WeldConstraint") or d:IsA("ManualWeld") then
			local o = if d.Part0 == part then d.Part1 elseif d.Part1 == part then d.Part0 else nil
			if o and (matches(o.Name, FLESH) or (armour and matches(o.Name, ARMOUR))) then
				table.insert(found, o)
			end
		end
	end
	return found
end

function Bones.arm(model: Model, side: string, opts: { [string]: any }?)
	opts = opts or {}
	local la = model:FindFirstChild(side .. "LowerArm")
	local hand = model:FindFirstChild(side .. "Hand")
	if not (la and hand and la:IsA("BasePart") and hand:IsA("BasePart")) then
		return
	end
	local suf = if side == "Right" then "R" else "L"
	local lib = library()
	local fsrc = lib:FindFirstChild("Forearm" .. suf, true)
	local hsrc = lib:FindFirstChild("Hand" .. suf, true)
	local sf = math.clamp(la.Size.X / 1.12, 0.9, 1.3)
	local sh = math.clamp(hand.Size.X / 0.47, 0.85, 1.4) * 1.15

	hide(la)
	hide(hand)
	for _, p in fleshOn(model, la, opts.armour) do
		hide(p)
	end
	for _, p in fleshOn(model, hand, opts.armour) do
		hide(p)
	end
	-- the elbow's ball becomes the bone's knuckle
	local ball = model:FindFirstChild(side .. "ElbowBall")
	if ball and ball:IsA("BasePart") then
		ball.Material = Bones.MATERIAL
		ball.Color = Bones.COLOR
		ball.Size *= 0.6
	end

	place(fsrc, la, Vector3.new(sf, sf * Bones.THICK, sf * Bones.THICK), side .. "Forearm")
	place(hsrc, hand, Vector3.new(sh, sh, sh), side .. "BoneHand")
end

function Bones.arms(model: Model, opts: { [string]: any }?)
	Bones.arm(model, "Right", opts)
	Bones.arm(model, "Left", opts)
end

-- a plain bone part welded to `base` (the shin and the foot are built from these; the arms are real meshes)
local function boneBit(base: BasePart, shape: Enum.PartType, size: Vector3, c0: CFrame, name: string)
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape
	p.Size = size
	p.Color = Bones.COLOR
	p.Material = Bones.MATERIAL
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.CastShadow = false
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.CFrame = base.CFrame * c0
	weld(base, p, c0)
	p:SetAttribute("TLK_Added", true)
	p.Parent = base.Parent
	return p
end

-- Skin and boot off below the knee: a tibia with its fibula beside it, knobbed ends, and a bony foot. The lower leg's long
-- axis is local X with the knee at +X (the same convention as the arms).
function Bones.leg(model: Model, side: string)
	local ll = model:FindFirstChild(side .. "LowerLeg")
	local foot = model:FindFirstChild(side .. "Foot")
	if not (ll and ll:IsA("BasePart")) then
		return
	end
	hide(ll)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and string.find(d.Name, "^" .. side .. "Boot") or string.find(d.Name, "^" .. side .. "Cuff") or string.find(d.Name, "^" .. side .. "Toe") then
			hide(d)
		end
	end
	local L, W = ll.Size.X, math.max(ll.Size.Y, ll.Size.Z)
	local t = W * 0.36 -- tibia width
	-- tibia: a long cylinder (cylinders run along X), a knobbed head at the knee, a flared foot-end
	boneBit(ll, Enum.PartType.Cylinder, Vector3.new(L * 0.96, t, t), CFrame.new(0, 0, -0.02), "Tibia")
	boneBit(ll, Enum.PartType.Ball, Vector3.new(t * 1.9, t * 1.5, t * 1.7), CFrame.new(L * 0.47, 0, -0.02), "TibiaHead")
	boneBit(ll, Enum.PartType.Ball, Vector3.new(t * 1.5, t * 1.3, t * 1.4), CFrame.new(-L * 0.47, 0, -0.02), "TibiaFoot")
	-- fibula: slimmer, behind and outside
	boneBit(ll, Enum.PartType.Cylinder, Vector3.new(L * 0.9, t * 0.5, t * 0.5), CFrame.new(-L * 0.03, t * 0.7, t * 0.85), "Fibula")
	boneBit(ll, Enum.PartType.Ball, Vector3.new(t * 0.9, t * 0.8, t * 0.8), CFrame.new(L * 0.4, t * 0.7, t * 0.85), "FibulaHead")
	if foot and foot:IsA("BasePart") then
		hide(foot)
		local fl = foot.Size.Z
		boneBit(foot, Enum.PartType.Block, Vector3.new(foot.Size.X * 0.46, 0.1, fl * 0.5), CFrame.new(0, 0.04, -fl * 0.12), "Metatarsals")
		boneBit(foot, Enum.PartType.Ball, Vector3.new(0.26, 0.22, 0.3), CFrame.new(0, 0.05, fl * 0.34), "Heel")
		for k = -2, 2 do
			boneBit(foot, Enum.PartType.Block, Vector3.new(0.055, 0.05, fl * 0.2 - math.abs(k) * 0.012), CFrame.new(k * 0.085, 0.03, -fl * 0.42), "Toe")
		end
	end
end

function Bones.legs(model: Model)
	Bones.leg(model, "Right")
	Bones.leg(model, "Left")
end

return Bones
