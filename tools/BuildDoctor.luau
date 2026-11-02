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
local STRIP = { "^Tab", "^Sk[FBLR]%d", "^StarBar", "^StarCore", "^Rib%d", "^Spine", "^Vein", "^Blotch", "^Tear", "^Rag", "^Pouch", "^Belt", "^Buckle", "^Sleeve", "^HollowLight", "^NeckCord", "^ArrowShaft", "^Fletching", "^skin", "^hair", "^iron", "^bone" }
local stripped = 0
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
	-- the wide hat
	local topAt = (head.CFrame * CFrame.new(0, hs.Y / 2 + 0.32, 0)).Position
	local brim = gear(model, head, "Brim", Vector3.new(0.14, hs.X * 2.5, hs.X * 2.5), CFrame.new(topAt) * CFrame.Angles(0, 0, math.rad(90)), LEATHER, Enum.Material.Fabric, Enum.PartType.Cylinder)
	brim.Name = "Brim"
	-- a low crown: with the tall one his hat touched a ceiling of 7.6
	gear(model, head, "Crown", Vector3.new(hs.Y * 0.55, hs.X * 1.15, hs.X * 1.15), CFrame.new(topAt + Vector3.new(0, hs.Y * 0.25, 0)) * CFrame.Angles(0, 0, math.rad(90)), LEATHER, Enum.Material.Fabric, Enum.PartType.Cylinder)

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
	for _, side in { -1, 1 } do
		local lump = gear(model, upper, "Growth", Vector3.new(us.X * 0.32, us.X * 0.32, us.X * 0.32), upper.CFrame * CFrame.new(side * us.X * 0.55, us.Y * 0.45, 0.1), Color3.fromRGB(122, 126, 104), Enum.Material.Slate, Enum.PartType.Ball)
		lump.Name = "Growth"
	end
	-- a belt of vials
	for i = -2, 2 do
		local v = gear(model, lower, "Vial", Vector3.new(0.5, 0.18, 0.18), lower.CFrame * CFrame.new(i * lower.Size.X * 0.2, -0.1, -lower.Size.Z / 2 - 0.1), Color3.fromRGB(120, 150, 110), Enum.Material.Glass, Enum.PartType.Cylinder)
		v.Transparency = 0.45
	end
	gear(model, lower, "Belt", Vector3.new(lower.Size.X * 1.06, 0.2, lower.Size.Z * 1.06), lower.CFrame * CFrame.new(0, 0.1, 0), Color3.fromRGB(26, 20, 16), Enum.Material.Fabric)
	table.insert(report, "dressed: mask, beak, lenses, eyes, hat, coat, spines, growths")
end

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
