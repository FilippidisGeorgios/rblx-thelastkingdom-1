--[[
	BuildDoctor — run in the Studio of the FORGOTTEN LANDS place, in EDIT MODE.
	Makes the body of the Doctor of the Catacombs (docs/systems/Catacombs.md): a stooped, widened giant in a plague doctor's
	long coat, wide hat and bird-beak mask, with two white lights for eyes, from a shambler's body. The result is one more
	master in `ServerStorage.Assets.Undead` named `plague_doctor` (what `configs/Enemies.plague_doctor.Body` names), so it
	moves with every clip the dead have.

	HOW. A copy of `undead_shambler` is scaled to `HEIGHT` studs (`Model:ScaleTo`), thickened sideways to `WIDTH` studs (the same
	method as `tools/WidenUndead`: parts moved out and thickened about the vertical axis, joints re-written), darkened, and
	dressed: every extra piece is welded to a part of the body, so it turns with it. Run again, it replaces the old one.

	The numbers are `configs/Catacombs.Doctor.Height` and `.Width`. Only the eyes light the dark: they are Neon, with a very faint
	light in them; the coat and the mask are dark so that nothing of him shows until a lantern is near.

	NOTE: a tool, not game code. Not synced by Rojo. The result lives in the place (the developer saves it).
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage = game:GetService("ServerStorage")

local cfg = require(ReplicatedStorage.Config.Catacombs)
local HEIGHT = cfg.Doctor.Height
local WIDTH = cfg.Doctor.Width
local FROM = "undead_shambler"

local undead = ServerStorage.Assets:FindFirstChild("Undead")
assert(undead, "ServerStorage.Assets.Undead is not there")
local source = undead:FindFirstChild(FROM)
assert(source and source:IsA("Model"), FROM .. " is not there")

local report = {}

local function jointError(model: Model): number
	local worst = 0
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			local want = d.Part0.CFrame * d.C0 * d.C1:Inverse()
			worst = math.max(worst, (want.Position - d.Part1.Position).Magnitude)
		end
	end
	return worst
end

local function height(model: Model): number
	local _, size = model:GetBoundingBox()
	return size.Y
end

-- sideways growth about the vertical axis (see tools/WidenUndead)
local function widen(model: Model, k: number)
	local root = model:FindFirstChild("HumanoidRootPart") :: BasePart
	local centre = root.Position
	-- every weld AND every joint is switched off while parts are moved one by one: a part moved while it is still joined
	-- drags the whole body with it, and the pieces welded on (the skirt, the arrow) end up many studs away
	local welds: { any } = {}
	for _, d in model:GetDescendants() do
		if d:IsA("WeldConstraint") or d:IsA("JointInstance") then
			table.insert(welds, d)
			d.Enabled = false
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("BasePart") and d ~= root then
			local cf = d.CFrame
			local rot = cf - cf.Position
			local fx, fy, fz
			if d:IsA("Part") and d.Shape == Enum.PartType.Ball then
				local all = 1 + (k - 1) * 0.8
				fx, fy, fz = all, all, all
			else
				local function factor(axis: Vector3): number
					local dir = rot:VectorToWorldSpace(axis)
					local horizontal = math.sqrt(math.max(0, 1 - dir.Y * dir.Y))
					return 1 + (k - 1) * horizontal
				end
				fx, fy, fz = factor(Vector3.xAxis), factor(Vector3.yAxis), factor(Vector3.zAxis)
			end
			local at = cf.Position
			d.Size = Vector3.new(d.Size.X * fx, d.Size.Y * fy, d.Size.Z * fz)
			d.CFrame = CFrame.new(centre.X + k * (at.X - centre.X), at.Y, centre.Z + k * (at.Z - centre.Z)) * rot
			for _, a in d:GetChildren() do
				if a:IsA("Attachment") then
					a.Position = Vector3.new(a.Position.X * fx, a.Position.Y * fy, a.Position.Z * fz)
				end
			end
		end
	end
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			d.C0 = d.Part0.CFrame:Inverse() * d.Part1.CFrame * d.C1
		end
	end
	for _, w in welds do
		w.Enabled = true
	end
end

local function gear(model: Model, host: BasePart, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?): Part
	local p = Instance.new("Part")
	p.Name = name
	p.Size = size
	p.CFrame = cf
	p.Color = color
	p.Material = material
	p.Shape = shape or Enum.PartType.Block
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

-- HANDS, the same careful way as tools/BuildZombieStyles: a palm, four two-jointed fingers curling to the palm, a thumb
local rng = Random.new(7)
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

local recording = ChangeHistoryService:TryBeginRecording("BuildDoctor")

local old = undead:FindFirstChild("plague_doctor")
if old then
	old:Destroy()
end
local model = source:Clone()
model.Name = "plague_doctor"
model:SetAttribute("BodyWidth", nil)
-- the shambler's own dressing (a tabard with a star, an iron cap, hair, ribs, a chain of bone, a neck cord) is taken off: only the
-- bones of the rig stay, and the doctor is dressed anew (2026-11-02: the white chain on his chest read as a beard)
local STRIP = { "^Tab", "^Sk[FBLR]%d", "^StarBar", "^StarCore", "^Rib%d", "^Spine", "^Vein", "^Blotch", "^Tear", "^Rag", "^Pouch", "^Belt", "^Buckle", "^Sleeve", "^HollowLight", "^NeckCord", "^ArrowShaft", "^Fletching", "^skin", "^hair", "^iron", "^bone", "^Finger", "^Thumb" }
local stripped = 0
-- the head and helmet of the shambler are MODELS of their own (head_gaunt, helm_kettle): they go too (2026-11-02: his kettle helmet
-- and hair showed above the mask, the "second hat")
for _, d in model:GetChildren() do
	if d:IsA("Model") then
		d:Destroy()
		stripped += 1
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
			stripped += 1
		end
	end
end
model.Parent = workspace -- a model is scaled and measured where it can be seen; it goes back in the store at the end
model:PivotTo(CFrame.new(0, 200, 0))

-- 1. height
local h0 = height(model)
model:ScaleTo(HEIGHT / h0)
table.insert(report, ("height %.2f -> %.2f (scale %.3f), joints off by %.3f"):format(h0, height(model), model:GetScale(), jointError(model)))
if jointError(model) > 0.05 then
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			d.C0 = d.Part0.CFrame:Inverse() * d.Part1.CFrame * d.C1
		end
	end
	table.insert(report, ("joints re-written, now off by %.3f"):format(jointError(model)))
end

-- 2. width
local _, size0 = model:GetBoundingBox()
local k = WIDTH / size0.X
widen(model, k)
local _, size1 = model:GetBoundingBox()
table.insert(report, ("width %.2f -> %.2f (x%.3f), height now %.2f, joints off by %.3f"):format(size0.X, size1.X, k, size1.Y, jointError(model)))
model:SetAttribute("BodyWidth", k)

-- 3. darker: leather and old cloth, grey skin
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
		d.Color = d.Color:Lerp(Color3.fromRGB(14, 13, 15), 0.45)
	end
end

-- 4. dressing
local head = model:FindFirstChild("Head") :: BasePart?
local upper = (model:FindFirstChild("UpperTorso") or model:FindFirstChild("Torso")) :: BasePart?
local lower = (model:FindFirstChild("LowerTorso") or upper) :: BasePart?
if not (head and upper and lower) then
	warn("BuildDoctor: no Head / UpperTorso: the body is not dressed")
else
	local hs = head.Size
	local front = head.CFrame * CFrame.new(0, -hs.Y * 0.05, -hs.Z / 2)
	local forward = head.CFrame.LookVector
	local down = -head.CFrame.UpVector
	local LEATHER = Color3.fromRGB(34, 28, 24)
	local BONE = Color3.fromRGB(176, 166, 142)

	-- the mask: a plague doctor's beaked leather mask with brass-rimmed lenses, a mesh made with `generate_mesh` and kept in
	-- ServerStorage.Assets.CatacombMeshes.DocMask (2026-11-02: the first one, six cylinders and a plate, read as a white beard).
	-- Its front is -Z, the beak drops forward; it is scaled to the head and welded on. Behind each lens a white light.
	local meshes = ServerStorage.Assets:FindFirstChild("CatacombMeshes")
	local maskSrc = meshes and meshes:FindFirstChild("DocMask")
	if maskSrc then
		local mask = maskSrc:Clone()
		mask.Name = "PlagueMask"
		local s = (hs.X / 1.49) * 1.08
		mask:ScaleTo(s)
		local at = head.CFrame * CFrame.new(0, hs.Y * 0.08 - 0.35 * s - 0.32, -hs.Z / 2 + 0.1 - 0.14 * s)
		mask:PivotTo(at)
		for _, d in mask:GetDescendants() do
			if d:IsA("BasePart") then
				d.Anchored = false
				d.CanCollide = false
				d.CanQuery = false
				d.CanTouch = false
				d.Massless = true
				local w = Instance.new("WeldConstraint")
				w.Part0 = head
				w.Part1 = d
				w.Parent = d
			end
		end
		mask.Parent = model
		for _, side in { -1, 1 } do
			local eyeAt = (at * CFrame.new(side * 0.3 * s, 0.34 * s, 0.05 * s)).Position
			local eye = gear(model, head, "Eye", Vector3.new(hs.Y * 0.3, hs.Y * 0.3, hs.Y * 0.3), CFrame.new(eyeAt), Color3.fromRGB(255, 255, 255), Enum.Material.Neon, Enum.PartType.Ball)
			local light = Instance.new("PointLight")
			light.Color = Color3.fromRGB(235, 245, 255)
			light.Range = 11
			light.Brightness = 0.9
			light.Shadows = false
			light.Parent = eye
		end
	else
		warn("BuildDoctor: ServerStorage.Assets.CatacombMeshes.DocMask is missing: no mask")
	end
	-- ONE hat (2026-11-02: the developer saw two, a brim floating over the top of the mask): the crown is set down OVER the top of
	-- the mask, so the mask goes up into it, and the brim sits at the crown's foot
	local maskModel = model:FindFirstChild("PlagueMask")
	local maskTop = head.Position.Y + hs.Y / 2
	local maskWide = hs.X * 1.1
	if maskModel then
		local mcf, msize = (maskModel :: Model):GetBoundingBox()
		maskTop = mcf.Position.Y + msize.Y / 2
		maskWide = math.max(msize.X, hs.X) * 1.06
	end
	local crownH = hs.Y * 0.62
	local crownAt = Vector3.new(head.Position.X, maskTop - crownH * 0.3, head.Position.Z) + head.CFrame.LookVector * Vector3.new(1, 0, 1) * 0.05
	gear(model, head, "Crown", Vector3.new(crownH, maskWide, maskWide), CFrame.new(crownAt) * CFrame.Angles(0, 0, math.rad(90)), LEATHER, Enum.Material.Fabric, Enum.PartType.Cylinder)
	gear(model, head, "Brim", Vector3.new(0.12, maskWide * 2.1, maskWide * 2.1), CFrame.new(crownAt - Vector3.new(0, crownH / 2 - 0.06, 0)) * CFrame.Angles(0, 0, math.rad(90)), LEATHER, Enum.Material.Fabric, Enum.PartType.Cylinder)
	gear(model, head, "HatBand", Vector3.new(0.14, maskWide * 1.02, maskWide * 1.02), CFrame.new(crownAt - Vector3.new(0, crownH / 2 - 0.2, 0)) * CFrame.Angles(0, 0, math.rad(90)), Color3.fromRGB(70, 52, 30), Enum.Material.Leather, Enum.PartType.Cylinder)

	-- the long coat: a back, two sides and a shoulder cape, hanging well below the hips
	local us = upper.Size
	local long = us.Y * 2.2
	local backCf = upper.CFrame * CFrame.new(0, -us.Y * 0.3 - long / 2 + us.Y * 0.5, us.Z / 2 + 0.1)
	gear(model, upper, "CoatBack", Vector3.new(us.X * 1.25, long, 0.18), backCf, LEATHER, Enum.Material.Fabric)
	for _, side in { -1, 1 } do
		gear(model, upper, "CoatSide", Vector3.new(0.18, long * 0.9, us.Z * 1.1), upper.CFrame * CFrame.new(side * (us.X / 2 + 0.1), -us.Y * 0.3 - long * 0.45 + us.Y * 0.5, 0), LEATHER, Enum.Material.Fabric)
	end
	-- (the square cape box is gone: it stood round the neck like a table)

	-- what the experiments made of him: spines through the coat, pale lumps on the shoulders
	-- (no spines: they stood on his chest as a white chain, and the developer read it as a beard)
	-- (and no pale lumps on the shoulders: they read as two balls on him, not as anything)
	-- a belt of vials
	for i = -2, 2 do
		local v = gear(model, lower, "Vial", Vector3.new(0.5, 0.18, 0.18), lower.CFrame * CFrame.new(i * lower.Size.X * 0.2, -0.1, -lower.Size.Z / 2 - 0.1), Color3.fromRGB(120, 150, 110), Enum.Material.Glass, Enum.PartType.Cylinder)
		v.Transparency = 0.45
	end
	gear(model, lower, "Belt", Vector3.new(lower.Size.X * 1.06, 0.2, lower.Size.Z * 1.06), lower.CFrame * CFrame.new(0, 0.1, 0), Color3.fromRGB(26, 20, 16), Enum.Material.Fabric)
	table.insert(report, "dressed: mask, beak, lenses, eyes, hat, coat, spines, growths")
end

-- 4b. his hands, in old leather gloves (2026-11-02: the blocks with sticks for fingers looked false)
hands(model, Color3.fromRGB(46, 36, 28), Enum.Material.Leather, { curl1 = 26, curl2 = 38, length = (model:FindFirstChild("LeftHand") :: BasePart).Size.Y * 1.25 })

-- 5. into the store
model:PivotTo(CFrame.new(0, 3, 0))
model.Parent = undead
local _, finalSize = model:GetBoundingBox()
table.insert(report, ("plague_doctor in Assets.Undead: %.2f wide, %.2f high, %.2f deep, %d parts"):format(finalSize.X, finalSize.Y, finalSize.Z, #model:GetDescendants()))

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
print("[BuildDoctor]\n" .. table.concat(report, "\n"))
return report
