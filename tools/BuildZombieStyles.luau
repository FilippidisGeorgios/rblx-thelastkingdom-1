--[[
	BuildZombieStyles — run in the Studio of the FORGOTTEN LANDS place, in EDIT MODE.
	Five STYLES of the dead for the developer to choose from (2026-11-02). Not five costumes on one idea: five ideas of what a dead
	thing in this castle is, each with one thing about it that is wrong in its own way (as Slenderman is wrong by his height and
	his face). All five are built the way the first dead were built, on the same blocky rig (`Assets.Undead.undead_shambler`):
	parts, welded to the bones of the rig, so they move with every clip the dead already have.

	  longman    THE LONG ONE      too tall and too thin; no face at all, a smooth pale head; very long fingers; a black coat
	  hanged     THE HANGED        a sack over the head tied with the noose, the rope cut; the neck broken sideways
	  penitent   THE PENITENT      bare and lashed; the head locked in an iron cage with a bell; chains dragging from the wrists
	  mourner    THE MOURNER       a black veil from the head to the floor, no feet, no face; long white hands out of the sleeves
	  burned     THE BURNED        charred, the cracks still glowing, smoking; a chain still round his waist (KEPT by the developer, 2026-11-03)

	Every one has HANDS made the same careful way: a palm, four fingers of two joints each curling toward the palm, a thumb set at
	the inner side, a nail at each tip.

	Result: models in `ServerStorage.Assets.ZombieStyles` (named style_<id>). Run again, it replaces them. Returns a report.
	NOTE: a tool, not game code. Not synced by Rojo. The result lives in the place (the developer saves it).
]]

local ServerStorage = game:GetService("ServerStorage")

local undead = ServerStorage.Assets:FindFirstChild("Undead")
assert(undead and undead:FindFirstChild("undead_shambler"), "ServerStorage.Assets.Undead.undead_shambler is not there")
local out = ServerStorage.Assets:FindFirstChild("ZombieStyles")
if not out then
	out = Instance.new("Folder")
	out.Name = "ZombieStyles"
	out.Parent = ServerStorage.Assets
end

local report = {}
local rng = Random.new(2026)

--==========================================================================
-- The rig
--==========================================================================
-- the shambler's own dressing: everything but the bones and the joints' balls (his head, cap, tabard, rags, arrow)
local STRIP = { "^Tab", "^Sk[FBLR]%d", "^StarBar", "^StarCore", "^Rib%d", "^Spine", "^Vein", "^Blotch", "^Tear", "^Rag", "^Pouch", "^Belt", "^Buckle", "^Sleeve", "^HollowLight", "^NeckCord", "^ArrowShaft", "^Fletching", "^Finger", "^Thumb" }

local GROUP = {
	skin = { "LeftHand", "RightHand", "Neck" },
	arms = { "LeftUpperArm", "LeftLowerArm", "RightUpperArm", "RightLowerArm", "LeftShoulderBall", "RightShoulderBall", "LeftElbowBall", "RightElbowBall", "LeftCuff", "RightCuff" },
	torso = { "UpperTorso", "LowerTorso" },
	legs = { "LeftUpperLeg", "LeftLowerLeg", "RightUpperLeg", "RightLowerLeg", "LeftKneeBall", "RightKneeBall" },
	feet = { "LeftFoot", "RightFoot", "LeftToe", "RightToe", "LeftBootTop", "RightBootTop" },
}

local function jointsOff(model: Model): { any }
	local list = {}
	for _, d in model:GetDescendants() do
		if d:IsA("WeldConstraint") or d:IsA("JointInstance") then
			table.insert(list, d)
			d.Enabled = false
		end
	end
	return list
end

local function rejoin(model: Model, list: { any })
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			d.C0 = d.Part0.CFrame:Inverse() * d.Part1.CFrame * d.C1
		end
	end
	for _, w in list do
		w.Enabled = true
	end
end

-- sideways growth or thinning about the vertical axis (tools/WidenUndead's method)
local function widen(model: Model, k: number)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local centre = root.Position
	local list = jointsOff(model)
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local cf = d.CFrame
			local rot = cf - cf.Position
			local function factor(axis: Vector3): number
				local dir = rot:VectorToWorldSpace(axis)
				return 1 + (k - 1) * math.sqrt(math.max(0, 1 - dir.Y * dir.Y))
			end
			local fx, fy, fz = factor(Vector3.xAxis), factor(Vector3.yAxis), factor(Vector3.zAxis)
			if d:IsA("Part") and d.Shape == Enum.PartType.Ball then
				local all = 1 + (k - 1) * 0.8
				fx, fy, fz = all, all, all
			end
			local at = cf.Position
			d.Size = Vector3.new(d.Size.X * fx, d.Size.Y * fy, d.Size.Z * fz)
			d.CFrame = CFrame.new(centre.X + k * (at.X - centre.X), at.Y, centre.Z + k * (at.Z - centre.Z)) * rot
		end
	end
	rejoin(model, list)
end

local function base(id: string, height: number, width: number): Model
	local model = undead.undead_shambler:Clone()
	model.Name = "style_" .. id
	model:SetAttribute("BodyWidth", nil)
	-- the head and helmet are MODELS of their own (head_gaunt, helm_kettle): they go too
	for _, d in model:GetChildren() do
		if d:IsA("Model") then
			d:Destroy()
		end
	end
	for _, d in model:GetChildren() do
		if d:IsA("BasePart") then
			local drop = d:IsA("UnionOperation")
			for _, pat in STRIP do
				if d.Name:find(pat) then
					drop = true
				end
			end
			if drop then
				d:Destroy()
			end
		end
	end
	model.Parent = workspace
	model:PivotTo(CFrame.new(0, 300, 0))
	local _, size = model:GetBoundingBox()
	model:ScaleTo(height / size.Y)
	local _, s2 = model:GetBoundingBox()
	widen(model, width / s2.X)
	return model
end

local function gear(model: Model, host: BasePart, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Shape = shape or Enum.PartType.Block
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Anchored = false
	p.CanCollide = false
	p.CanQuery = false
	p.CanTouch = false
	p.Massless = true
	p.TopSurface = Enum.SurfaceType.Smooth
	p.BottomSurface = Enum.SurfaceType.Smooth
	p.Parent = model
	local w = Instance.new("WeldConstraint")
	w.Part0 = host
	w.Part1 = p
	w.Parent = p
	return p
end

local function paint(model: Model, group: string, color: Color3, material: Enum.Material, variant: string?)
	for _, n in GROUP[group] do
		local p = model:FindFirstChild(n)
		if p and p:IsA("BasePart") then
			p.Color = color
			p.Material = material
			p.MaterialVariant = variant or ""
		end
	end
end

-- a shell: a garment around a body part, the same shape a little larger
local function shell(model: Model, n: string, grow: Vector3, color: Color3, material: Enum.Material, offset: CFrame?, variant: string?): Part?
	local p = model:FindFirstChild(n)
	if not (p and p:IsA("BasePart")) then
		return nil
	end
	local s = gear(model, p, n .. "Cloth", p.Size + grow, p.CFrame * (offset or CFrame.new()), color, material)
	s.MaterialVariant = variant or ""
	return s
end

local function egg(model: Model, host: BasePart, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material): Part
	local p = gear(model, host, name, size, cf, color, material)
	local mesh = Instance.new("SpecialMesh")
	mesh.MeshType = Enum.MeshType.Sphere
	mesh.Parent = p
	return p
end

--==========================================================================
-- HANDS: a palm (the rig's own hand), four fingers of two joints, a thumb, nails. In the hand's own frame the fingers leave
-- the hand along -Y, spread along X, and curl toward -Z (the palm). `inner` is the side of X toward the body.
--==========================================================================
local function hands(model: Model, skin: Color3, material: Enum.Material, o: any)
	for _, side in { { "RightHand", -1 }, { "LeftHand", 1 } } do
		local hand = model:FindFirstChild(side[1] :: string) :: BasePart?
		if hand then
			local inner = side[2] :: number
			local hs = hand.Size
			local cf = hand.CFrame
			local t = o.thick or math.min(hs.Z * 0.62, hs.X * 0.19)
			local full = o.length or hs.Y * 1.0
			local lens = { 0.9, 1.0, 0.93, 0.74 } -- index, middle, ring, little
			local curl1, curl2 = math.rad(o.curl1 or 22), math.rad(o.curl2 or 34)
			for i = 1, 4 do
				local x = inner * hs.X * (0.37 - (i - 1) * 0.245)
				local L = full * lens[i]
				local L1, L2 = L * 0.56, L * 0.44
				local splay = math.rad((i - 2.5) * (o.splay or 5)) * -inner
				local knuckle = CFrame.new(x, -hs.Y / 2 + t * 0.35, -hs.Z * 0.06) * CFrame.Angles(0, 0, splay)
				local bend1 = knuckle * CFrame.Angles(curl1 + rng:NextNumber(-0.06, 0.06), 0, 0)
				gear(model, hand, "Finger", Vector3.new(t, L1 + t * 0.4, t), cf * bend1 * CFrame.new(0, -L1 / 2, 0), skin, material)
				local bend2 = bend1 * CFrame.new(0, -L1, 0) * CFrame.Angles(curl2 + rng:NextNumber(-0.08, 0.08), 0, 0)
				gear(model, hand, "Finger", Vector3.new(t * 0.86, L2 + t * 0.3, t * 0.86), cf * bend2 * CFrame.new(0, -L2 / 2, 0), skin, material)
				if o.nail then
					gear(model, hand, "Nail", Vector3.new(t * 0.7, t * 0.9, t * 0.3), cf * bend2 * CFrame.new(0, -L2 + t * 0.2, t * 0.35), o.nail, Enum.Material.SmoothPlastic)
				end
			end
			-- the thumb: from the inner edge low on the palm, out and down, bent toward the palm
			local tl = full * 0.62
			local root = CFrame.new(inner * hs.X * 0.5, -hs.Y * 0.05, -hs.Z * 0.15) * CFrame.Angles(0, 0, inner * math.rad(42))
			local t1 = root * CFrame.Angles(math.rad(28), 0, 0)
			gear(model, hand, "Thumb", Vector3.new(t * 1.05, tl * 0.55, t * 1.05), cf * t1 * CFrame.new(0, -tl * 0.27, 0), skin, material)
			local t2 = t1 * CFrame.new(0, -tl * 0.55, 0) * CFrame.Angles(math.rad(24), 0, inner * math.rad(-14))
			gear(model, hand, "Thumb", Vector3.new(t * 0.92, tl * 0.48, t * 0.92), cf * t2 * CFrame.new(0, -tl * 0.22, 0), skin, material)
			if o.nail then
				gear(model, hand, "Nail", Vector3.new(t * 0.75, t * 0.9, t * 0.3), cf * t2 * CFrame.new(0, -tl * 0.44, t * 0.38), o.nail, Enum.Material.SmoothPlastic)
			end
			-- the knuckles: a slight ridge across the back of the hand
			gear(model, hand, "Knuckles", Vector3.new(hs.X * 0.92, t * 0.7, hs.Z * 0.5), cf * CFrame.new(0, -hs.Y / 2 + t * 0.3, hs.Z * 0.2), skin:Lerp(Color3.new(0, 0, 0), 0.08), material)
			hand.Color = skin
			hand.Material = material
		end
	end
end

local function floorY(model: Model): number
	local cf, size = model:GetBoundingBox()
	return cf.Position.Y - size.Y / 2
end

-- a hanging panel of cloth in the world's upright (a coat tail, a robe): from `top` down to `bottom`, `w` wide, at `x, z`,
-- facing `dir` (a unit vector in the ground plane), turned out by `flare` degrees at the bottom
local function panel(model: Model, host: BasePart, name: string, centre: Vector3, w: number, top: number, bottom: number, facing: Vector3, flare: number, color: Color3, material: Enum.Material, thick: number?): Part
	local h = top - bottom
	local at = Vector3.new(centre.X, (top + bottom) / 2, centre.Z)
	-- (a turn about X by +a tilts the panel's top inward and its foot outward: the hem flares)
	local cf = CFrame.lookAt(at, at + facing) * CFrame.Angles(math.rad(flare), 0, 0)
	return gear(model, host, name, Vector3.new(w, h, thick or 0.14), cf, color, material)
end

local function burlap(): string
	return "TLK_Burlap" .. tostring(rng:NextInteger(1, 3))
end

--==========================================================================
-- THE STYLES
--==========================================================================
local STYLE = {}

-- 1. THE LONG ONE: too tall, too thin, no face. A black funeral coat to below the knee. Long, long fingers.
function STYLE.longman(): Model
	local m = base("longman", 8.8, 2.7)
	local SKIN = Color3.fromRGB(178, 176, 170)
	local COAT = Color3.fromRGB(22, 21, 24)
	paint(m, "skin", SKIN, Enum.Material.SmoothPlastic)
	paint(m, "arms", COAT, Enum.Material.SmoothPlastic)
	paint(m, "torso", COAT, Enum.Material.SmoothPlastic)
	paint(m, "legs", Color3.fromRGB(30, 29, 32), Enum.Material.SmoothPlastic)
	paint(m, "feet", Color3.fromRGB(16, 15, 15), Enum.Material.SmoothPlastic)
	local head = m.Head :: BasePart
	local hs = head.Size
	-- the head: smooth, a little too long, nothing on it at all
	egg(m, head, "Face", Vector3.new(hs.X * 1.02, hs.Y * 1.32, hs.Z * 1.0), head.CFrame * CFrame.new(0, hs.Y * 0.14, 0), SKIN, Enum.Material.SmoothPlastic)
	-- a white collar and a black tie: the only line on the front of him
	local ut = m.UpperTorso :: BasePart
	local us = ut.Size
	gear(m, ut, "Collar", Vector3.new(us.X * 0.42, us.Y * 0.22, 0.06), ut.CFrame * CFrame.new(0, us.Y * 0.36, -us.Z / 2 - 0.03), Color3.fromRGB(226, 224, 218), Enum.Material.SmoothPlastic)
	gear(m, ut, "Tie", Vector3.new(us.X * 0.1, us.Y * 0.62, 0.07), ut.CFrame * CFrame.new(0, us.Y * 0.06, -us.Z / 2 - 0.05), Color3.fromRGB(10, 10, 12), Enum.Material.SmoothPlastic)
	-- the coat: lapels, and tails to below the knee, slightly open at the front
	local lt = m.LowerTorso :: BasePart
	local low = floorY(m)
	local waist = lt.Position
	local fwd = (ut.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
	local right = fwd:Cross(Vector3.yAxis)
	local top, bottom = waist.Y + lt.Size.Y * 0.4, low + 1.6
	panel(m, lt, "CoatBack", waist - fwd * (lt.Size.Z * 0.55), lt.Size.X * 1.25, top, bottom, -fwd, 6, COAT, Enum.Material.SmoothPlastic)
	for _, s in { -1, 1 } do
		panel(m, lt, "CoatFront", waist + fwd * (lt.Size.Z * 0.55) + right * s * lt.Size.X * 0.36, lt.Size.X * 0.5, top, bottom, fwd, 5, COAT, Enum.Material.SmoothPlastic)
		panel(m, lt, "CoatSide", waist + right * s * (lt.Size.X * 0.66), lt.Size.Z * 1.1, top, bottom + 0.3, right * s, 5, COAT, Enum.Material.SmoothPlastic)
		gear(m, ut, "Lapel", Vector3.new(us.X * 0.16, us.Y * 0.62, 0.06), ut.CFrame * CFrame.new(s * us.X * 0.24, us.Y * 0.12, -us.Z / 2 - 0.05) * CFrame.Angles(0, 0, math.rad(s * 10)), Color3.fromRGB(38, 37, 42), Enum.Material.SmoothPlastic)
	end
	hands(m, SKIN, Enum.Material.SmoothPlastic, { length = m.LeftHand.Size.Y * 2.6, thick = m.LeftHand.Size.X * 0.13, curl1 = 14, curl2 = 22, splay = 7, nail = Color3.fromRGB(150, 146, 140) })
	return m
end

-- 2. THE HANGED: a sack over the head, tied at the throat by the noose, the rope cut a little above; the head hangs to one side
function STYLE.hanged(): Model
	local m = base("hanged", 6.2, 3.0)
	local SKIN = Color3.fromRGB(108, 96, 102)
	paint(m, "skin", SKIN, Enum.Material.SmoothPlastic)
	paint(m, "arms", Color3.fromRGB(186, 176, 152), Enum.Material.Fabric)
	paint(m, "torso", Color3.fromRGB(190, 180, 156), Enum.Material.Fabric)
	paint(m, "legs", Color3.fromRGB(78, 62, 46), Enum.Material.Fabric)
	paint(m, "feet", Color3.fromRGB(52, 46, 48), Enum.Material.SmoothPlastic)
	local head = m.Head :: BasePart
	local hs = head.Size
	-- the broken neck: the sack is laid on the head turned 34 degrees down to the right
	local tilt = head.CFrame * CFrame.new(hs.X * 0.18, -hs.Y * 0.06, 0) * CFrame.Angles(0, 0, math.rad(-34))
	local BURLAP = Color3.fromRGB(168, 140, 96)
	local sack = gear(m, head, "Sack", Vector3.new(hs.X * 1.18, hs.Y * 1.16, hs.Z * 1.14), tilt * CFrame.new(0, hs.Y * 0.05, 0), BURLAP, Enum.Material.Fabric)
	sack.MaterialVariant = burlap()
	-- the gathered top, a little limp
	gear(m, head, "SackTop", Vector3.new(hs.X * 0.7, hs.Y * 0.3, hs.Z * 0.6), tilt * CFrame.new(-hs.X * 0.08, hs.Y * 0.7, 0) * CFrame.Angles(0, 0, math.rad(20)), BURLAP:Lerp(Color3.new(0, 0, 0), 0.1), Enum.Material.Fabric).MaterialVariant = burlap()
	-- a face daubed on the sack in old tar: two crosses for eyes, a stitched mouth
	local face = Instance.new("SurfaceGui")
	face.Face = Enum.NormalId.Front
	face.SizingMode = Enum.SurfaceGuiSizingMode.FixedSize
	face.CanvasSize = Vector2.new(200, 200)
	face.LightInfluence = 1
	face.Parent = sack
	local INK = Color3.fromRGB(28, 20, 16)
	local function stroke(x: number, y: number, w: number, h: number, r: number)
		local f = Instance.new("Frame")
		f.AnchorPoint = Vector2.new(0.5, 0.5)
		f.Position = UDim2.fromOffset(x, y)
		f.Size = UDim2.fromOffset(w, h)
		f.Rotation = r
		f.BorderSizePixel = 0
		f.BackgroundColor3 = INK
		f.BackgroundTransparency = 0.05
		f.Parent = face
	end
	for _, ex in { 62, 138 } do
		stroke(ex, 78, 44, 9, 45 + rng:NextNumber(-8, 8))
		stroke(ex, 78, 44, 9, -45 + rng:NextNumber(-8, 8))
	end
	stroke(100, 140, 92, 5, 3)
	for i = 0, 6 do
		stroke(58 + i * 14, 140, 4, 22, rng:NextNumber(-12, 12))
	end
	-- the noose round the neck, and the rope going up, cut and frayed
	local ROPE = Color3.fromRGB(150, 124, 80)
	local neckAt = head.CFrame * CFrame.new(0, -hs.Y * 0.48, 0)
	gear(m, head, "Noose", Vector3.new(0.26, hs.X * 0.95, hs.X * 0.95), neckAt * CFrame.Angles(0, 0, math.rad(90 - 20)), ROPE, Enum.Material.Fabric, Enum.PartType.Cylinder)
	gear(m, head, "Knot", Vector3.new(0.42, 0.42, 0.42), neckAt * CFrame.new(-hs.X * 0.42, hs.Y * 0.1, 0.1), ROPE, Enum.Material.Fabric, Enum.PartType.Ball)
	local ropeLen = 1.9
	gear(m, head, "Rope", Vector3.new(0.16, ropeLen, 0.16), neckAt * CFrame.new(-hs.X * 0.5, hs.Y * 0.1 + ropeLen / 2, 0.05) * CFrame.Angles(0, 0, math.rad(-12)), ROPE, Enum.Material.Fabric)
	for i = 1, 4 do
		gear(m, head, "Fray", Vector3.new(0.05, 0.32, 0.05), neckAt * CFrame.new(-hs.X * 0.5 - 0.2 + i * 0.04, hs.Y * 0.1 + ropeLen + 0.12, 0.05) * CFrame.Angles(rng:NextNumber(-0.5, 0.5), 0, rng:NextNumber(-0.6, 0.6)), ROPE:Lerp(Color3.new(1, 1, 1), 0.1), Enum.Material.Fabric)
	end
	-- a torn shirt hem and a rope round each wrist
	local lt = m.LowerTorso :: BasePart
	for i = -2, 2 do
		gear(m, lt, "Hem", Vector3.new(lt.Size.X * 0.2, rng:NextNumber(0.4, 0.8), lt.Size.Z * 1.05), lt.CFrame * CFrame.new(i * lt.Size.X * 0.19, -lt.Size.Y * 0.4, 0) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-6, 6))), Color3.fromRGB(176, 166, 140), Enum.Material.Fabric)
	end
	for _, n in { "LeftLowerArm", "RightLowerArm" } do
		local a = m:FindFirstChild(n) :: BasePart
		gear(m, a, "WristRope", Vector3.new(0.18, a.Size.Y * 1.25, a.Size.Z * 1.25), a.CFrame * CFrame.new(-a.Size.X * 0.36, 0, 0), ROPE, Enum.Material.Fabric)
	end
	hands(m, SKIN, Enum.Material.SmoothPlastic, { curl1 = 18, curl2 = 26, nail = Color3.fromRGB(70, 60, 64) })
	return m
end

-- 3. THE PENITENT: bare and lashed, the head locked in an iron cage with a bell at the mouth; chains hang from both wrists
function STYLE.penitent(): Model
	local m = base("penitent", 6.4, 3.3)
	local SKIN = Color3.fromRGB(84, 90, 92)
	local IRON = Color3.fromRGB(44, 40, 38)
	paint(m, "skin", SKIN, Enum.Material.SmoothPlastic)
	paint(m, "arms", SKIN, Enum.Material.SmoothPlastic)
	paint(m, "torso", SKIN, Enum.Material.SmoothPlastic)
	paint(m, "legs", Color3.fromRGB(110, 92, 66), Enum.Material.Fabric)
	paint(m, "feet", Color3.fromRGB(46, 44, 42), Enum.Material.SmoothPlastic)
	for _, n in { "LeftShoulderBall", "RightShoulderBall", "LeftElbowBall", "RightElbowBall", "LeftCuff", "RightCuff" } do
		local p = m:FindFirstChild(n)
		if p then
			(p :: BasePart).Color = SKIN
			;(p :: BasePart).Material = Enum.Material.SmoothPlastic
		end
	end
	local ut = m.UpperTorso :: BasePart
	local us = ut.Size
	-- the lashes: dark stripes across the back and over the shoulders, a few on the chest
	for i = 1, 9 do
		local back = i <= 7
		local z = if back then us.Z / 2 + 0.01 else -us.Z / 2 - 0.01
		gear(m, ut, "Lash", Vector3.new(us.X * rng:NextNumber(0.25, 0.42), 0.06, 0.03), ut.CFrame * CFrame.new(rng:NextNumber(-us.X * 0.12, us.X * 0.12), rng:NextNumber(-us.Y * 0.36, us.Y * 0.38), z) * CFrame.Angles(0, 0, math.rad(rng:NextNumber(-18, 18))), Color3.fromRGB(96, 22, 24), Enum.Material.SmoothPlastic)
	end
	-- a sackcloth skirt from the waist to the knee, tied with a cord
	local lt = m.LowerTorso :: BasePart
	local waist = lt.Position
	local low = floorY(m)
	local fwd = (ut.CFrame.LookVector * Vector3.new(1, 0, 1)).Unit
	local right = fwd:Cross(Vector3.yAxis)
	local top, bottom = waist.Y + lt.Size.Y * 0.4, low + 2.2
	local SACK = Color3.fromRGB(128, 104, 72)
	for k = 0, 3 do
		local dir = (fwd * math.cos(k * math.pi / 2) + right * math.sin(k * math.pi / 2)).Unit
		local w = if k % 2 == 0 then lt.Size.X * 1.1 else lt.Size.Z * 1.2
		local push = if k % 2 == 0 then lt.Size.Z * 0.55 else lt.Size.X * 0.56
		panel(m, lt, "Skirt", waist + dir * push, w, top, bottom + rng:NextNumber(-0.2, 0.3), dir, 8, SACK, Enum.Material.Fabric).MaterialVariant = burlap()
	end
	gear(m, lt, "Cord", Vector3.new(lt.Size.X * 1.18, 0.14, lt.Size.Z * 1.2), lt.CFrame * CFrame.new(0, lt.Size.Y * 0.35, 0), Color3.fromRGB(70, 54, 36), Enum.Material.Fabric)
	-- the head: grey, eyes sunk in dark, the mouth stitched; then the cage over it
	local head = m.Head :: BasePart
	local hs = head.Size
	local hcf = head.CFrame
	gear(m, head, "Skull", Vector3.new(hs.X * 0.92, hs.Y * 0.98, hs.Z * 0.94), hcf, SKIN:Lerp(Color3.new(1, 1, 1), 0.08), Enum.Material.SmoothPlastic)
	for _, ex in { -1, 1 } do
		gear(m, head, "Socket", Vector3.new(hs.X * 0.22, hs.Y * 0.16, 0.06), hcf * CFrame.new(ex * hs.X * 0.21, hs.Y * 0.08, -hs.Z * 0.47), Color3.fromRGB(16, 14, 14), Enum.Material.SmoothPlastic)
	end
	gear(m, head, "Mouth", Vector3.new(hs.X * 0.4, 0.05, 0.05), hcf * CFrame.new(0, -hs.Y * 0.24, -hs.Z * 0.47), Color3.fromRGB(40, 20, 20), Enum.Material.SmoothPlastic)
	for i = -2, 2 do
		gear(m, head, "Stitch", Vector3.new(0.035, 0.16, 0.04), hcf * CFrame.new(i * hs.X * 0.08, -hs.Y * 0.24, -hs.Z * 0.48), Color3.fromRGB(30, 22, 18), Enum.Material.SmoothPlastic)
	end
	-- the cage: eight bars round the head, two hoops, a cross over the crown, a plate over the mouth with a small bell on it
	local R = math.max(hs.X, hs.Z) * 0.62
	local H = hs.Y * 1.25
	for i = 0, 7 do
		local a = i * math.pi / 4
		gear(m, head, "Bar", Vector3.new(0.09, H, 0.09), hcf * CFrame.new(math.cos(a) * R, hs.Y * 0.05, math.sin(a) * R), IRON, Enum.Material.Metal)
	end
	for _, y in { -hs.Y * 0.5, hs.Y * 0.62 } do
		for i = 0, 7 do
			local a = (i + 0.5) * math.pi / 4
			local len = 2 * R * math.sin(math.pi / 8) + 0.06
			gear(m, head, "Hoop", Vector3.new(len, 0.1, 0.1), hcf * CFrame.new(math.cos(a) * R, y, math.sin(a) * R) * CFrame.Angles(0, -a + math.pi / 2, 0), IRON, Enum.Material.Metal)
		end
	end
	for _, r in { 0, math.pi / 2 } do
		gear(m, head, "Crown", Vector3.new(2 * R + 0.1, 0.1, 0.1), hcf * CFrame.new(0, hs.Y * 0.66, 0) * CFrame.Angles(0, r, 0) * CFrame.Angles(0, 0, 0), IRON, Enum.Material.Metal)
	end
	gear(m, head, "Bridle", Vector3.new(hs.X * 0.55, hs.Y * 0.2, 0.06), hcf * CFrame.new(0, -hs.Y * 0.24, -R - 0.02), IRON, Enum.Material.Metal)
	gear(m, head, "Bell", Vector3.new(0.32, 0.3, 0.3), hcf * CFrame.new(0, -hs.Y * 0.48, -R - 0.12), Color3.fromRGB(120, 96, 52), Enum.Material.Metal, Enum.PartType.Ball)
	-- chains from both wrists to the floor, links turned one against the next
	for _, n in { "LeftHand", "RightHand" } do
		local hand = m:FindFirstChild(n) :: BasePart
		local from = hand.Position + Vector3.new(0, 0.1, 0)
		-- (laid where it belongs before it is welded: moving a part after its weld is made drags what it is welded to)
		gear(m, hand, "Shackle", Vector3.new(0.18, 0.6, 0.6), CFrame.new(from + Vector3.new(0, 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), IRON, Enum.Material.Metal, Enum.PartType.Cylinder)
		local y = from.Y
		local k = 0
		while y > low + 0.15 do
			local link = gear(m, hand, "Link", Vector3.new(0.07, 0.3, 0.16), CFrame.new(from.X + math.sin(k * 0.4) * 0.03, y - 0.13, from.Z) * CFrame.Angles(0, if k % 2 == 0 then 0 else math.pi / 2, 0), IRON, Enum.Material.Metal)
			_ = link
			y -= 0.24
			k += 1
		end
		for j = 1, 5 do
			gear(m, hand, "Link", Vector3.new(0.07, 0.3, 0.16), CFrame.new(from.X + j * 0.24, low + 0.05, from.Z + j * 0.1) * CFrame.Angles(0, (if j % 2 == 0 then 0 else math.pi / 2) + 0.4, math.rad(90)), IRON, Enum.Material.Metal)
		end
	end
	hands(m, SKIN, Enum.Material.SmoothPlastic, { curl1 = 30, curl2 = 44, nail = Color3.fromRGB(60, 50, 48) })
	return m
end

-- 4. THE MOURNER: one black veil from the crown of the head to the floor, a tall narrow cone; no face, no feet; only the long
-- white hands come out of it, reaching
function STYLE.mourner(): Model
	local m = base("mourner", 7.4, 3.0)
	local SKIN = Color3.fromRGB(196, 192, 182)
	local VEIL = Color3.fromRGB(16, 14, 16)
	paint(m, "skin", SKIN, Enum.Material.SmoothPlastic)
	for _, g in { "arms", "torso", "legs", "feet" } do
		paint(m, g, VEIL, Enum.Material.Plastic)
	end
	local head = m.Head :: BasePart
	local hs = head.Size
	local ut = m.UpperTorso :: BasePart
	local low = floorY(m)
	-- the axis of the cone: straight up through the middle of the body, the peak just over the head
	local mid = (ut.Position + (m.LowerTorso :: BasePart).Position) / 2
	local peakY = head.Position.Y + hs.Y * 0.62
	local axis = Vector3.new((mid.X + head.Position.X) / 2, 0, (mid.Z + head.Position.Z) / 2)
	local rTop, rBottom = hs.X * 0.62, ut.Size.X * 0.92
	local N = 14
	for i = 0, N - 1 do
		local a = i * 2 * math.pi / N
		local dir = Vector3.new(math.cos(a), 0, math.sin(a))
		local bottom = low + 0.04 + rng:NextNumber(0, 0.35) -- a ragged hem, each strip a little different
		local hgt = peakY - bottom
		local rMid = (rTop + rBottom) / 2
		local slope = math.deg(math.atan((rBottom - rTop) / hgt))
		local width = 2 * rBottom * math.tan(math.pi / N) + 0.1
		local at = Vector3.new(axis.X + dir.X * rMid, (peakY + bottom) / 2, axis.Z + dir.Z * rMid)
		local strip = gear(m, ut, "Veil", Vector3.new(width, hgt, 0.1), CFrame.lookAt(at, at + dir) * CFrame.Angles(math.rad(slope), 0, 0), VEIL:Lerp(Color3.fromRGB(46, 40, 38), rng:NextNumber(0, 0.3)), Enum.Material.Plastic)
		_ = strip
	end
	-- the crown of the veil, rounded over the head
	egg(m, head, "VeilCrown", Vector3.new(rTop * 2.15, hs.Y * 0.7, rTop * 2.15), CFrame.new(axis.X, peakY - hs.Y * 0.08, axis.Z), VEIL, Enum.Material.Plastic)
	-- where the arms come out: sleeves of the same cloth round the forearms, and the hands bare
	-- (the sleeve stops short of the wrist, so the hand comes out of the cloth and is not framed by it)
	for _, n in { "LeftLowerArm", "RightLowerArm" } do
		local arm = m:FindFirstChild(n) :: BasePart
		-- the forearm itself is bare and bone-white: the arm comes out of the veil, long and thin
		arm.Color = SKIN
		arm.Material = Enum.Material.SmoothPlastic
		arm.Size = Vector3.new(arm.Size.X, arm.Size.Y * 0.62, arm.Size.Z * 0.62)
		-- a ROUND sleeve (a cylinder lies along its X, as the arm does): a square one showed as a black box behind the hand
		local d = math.max(arm.Size.Y, arm.Size.Z) + 0.5
		gear(m, arm, n .. "Sleeve", Vector3.new(arm.Size.X * 0.45, d, d), arm.CFrame * CFrame.new(arm.Size.X * 0.28, 0, 0), VEIL, Enum.Material.Plastic, Enum.PartType.Cylinder)
	end
	-- the joints' round balls would show through the veil at the shoulders
	-- (and the square cuffs at the wrists, which framed each hand like a box)
	for _, n in { "LeftShoulderBall", "RightShoulderBall", "LeftElbowBall", "RightElbowBall", "LeftKneeBall", "RightKneeBall", "LeftCuff", "RightCuff" } do
		local ball = m:FindFirstChild(n)
		if ball then
			(ball :: BasePart).Transparency = 1
		end
	end
	hands(m, SKIN, Enum.Material.SmoothPlastic, { length = m.LeftHand.Size.Y * 2.0, thick = m.LeftHand.Size.X * 0.14, curl1 = 18, curl2 = 26, splay = 4, nail = Color3.fromRGB(190, 184, 172) })
	return m
end

-- 5. THE BURNED: charred, the cracks still glowing, smoke and sparks rising off him (the stake was taken off, 2026-11-03)
function STYLE.burned(): Model
	local m = base("burned", 6.3, 3.2)
	local CHAR = Color3.fromRGB(46, 36, 30)
	for _, g in { "skin", "arms", "torso", "legs", "feet" } do
		paint(m, g, CHAR, Enum.Material.CrackedLava)
	end
	local head = m.Head :: BasePart
	local hs = head.Size
	local hcf = head.CFrame
	gear(m, head, "Skull", Vector3.new(hs.X * 0.9, hs.Y * 0.95, hs.Z * 0.92), hcf, CHAR, Enum.Material.CrackedLava)
	gear(m, head, "Jaw", Vector3.new(hs.X * 0.62, hs.Y * 0.22, hs.Z * 0.6), hcf * CFrame.new(0, -hs.Y * 0.5, -hs.Z * 0.12) * CFrame.Angles(math.rad(12), 0, 0), CHAR:Lerp(Color3.new(0, 0, 0), 0.3), Enum.Material.CrackedLava)
	for _, ex in { -1, 1 } do
		local e = gear(m, head, "Ember", Vector3.new(hs.X * 0.13, hs.X * 0.13, hs.X * 0.13), hcf * CFrame.new(ex * hs.X * 0.2, hs.Y * 0.08, -hs.Z * 0.46), Color3.fromRGB(255, 120, 30), Enum.Material.Neon, Enum.PartType.Ball)
		_ = e
	end
	-- (no stake on his back: the developer kept him without it, 2026-11-03) a chain still round the waist, where he was bound
	local ut = m.UpperTorso :: BasePart
	local lt = m.LowerTorso :: BasePart
	gear(m, lt, "ChainWaist", Vector3.new(lt.Size.X * 1.12, 0.14, lt.Size.Z * 1.15), lt.CFrame * CFrame.new(0, 0.1, 0), Color3.fromRGB(60, 52, 46), Enum.Material.CorrodedMetal)
	gear(m, lt, "ChainEnd", Vector3.new(0.12, 1.1, 0.12), lt.CFrame * CFrame.new(lt.Size.X * 0.3, -0.5, -lt.Size.Z * 0.5) * CFrame.Angles(0, 0, math.rad(8)), Color3.fromRGB(60, 52, 46), Enum.Material.CorrodedMetal)
	-- smoke rising off him, and a few sparks; a low orange light
	local smoke = Instance.new("ParticleEmitter")
	smoke.Texture = "rbxasset://textures/particles/smoke_main.dds"
	smoke.Color = ColorSequence.new(Color3.fromRGB(60, 56, 54), Color3.fromRGB(30, 28, 28))
	smoke.Transparency = NumberSequence.new({ NumberSequenceKeypoint.new(0, 0.85), NumberSequenceKeypoint.new(0.4, 0.75), NumberSequenceKeypoint.new(1, 1) })
	smoke.Size = NumberSequence.new(0.8, 2.6)
	smoke.Lifetime = NumberRange.new(2.5, 4)
	smoke.Rate = 6
	smoke.Speed = NumberRange.new(0.8, 1.6)
	smoke.SpreadAngle = Vector2.new(18, 18)
	smoke.Parent = ut
	local sparks = Instance.new("ParticleEmitter")
	sparks.Texture = "rbxasset://textures/particles/sparkles_main.dds"
	sparks.Color = ColorSequence.new(Color3.fromRGB(255, 150, 60))
	sparks.LightEmission = 1
	sparks.Size = NumberSequence.new(0.12, 0)
	sparks.Lifetime = NumberRange.new(0.8, 1.6)
	sparks.Rate = 3
	sparks.Speed = NumberRange.new(1, 2.5)
	sparks.SpreadAngle = Vector2.new(30, 30)
	sparks.Parent = ut
	local glow = Instance.new("PointLight")
	glow.Color = Color3.fromRGB(255, 120, 40)
	glow.Range = 7
	glow.Brightness = 0.7
	glow.Parent = ut
	hands(m, CHAR, Enum.Material.CrackedLava, { curl1 = 34, curl2 = 46 })
	return m
end

--==========================================================================
local ORDER = { "longman", "hanged", "penitent", "mourner", "burned" }
for _, id in ORDER do
	local old = out:FindFirstChild("style_" .. id)
	if old then
		old:Destroy()
	end
	local ok, res = pcall(STYLE[id])
	if ok then
		local m = res :: Model
		m:PivotTo(CFrame.new(0, 3, 0))
		m.Parent = out
		local _, size = m:GetBoundingBox()
		table.insert(report, ("%s: %.1f high, %.1f wide, %d parts"):format(id, size.Y, size.X, #m:GetDescendants()))
	else
		table.insert(report, id .. " FAILED: " .. tostring(res))
		for _, c in workspace:GetChildren() do
			if c.Name == "style_" .. id then
				c:Destroy()
			end
		end
	end
end
return report
