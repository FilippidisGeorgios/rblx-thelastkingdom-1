--[[
	BuildHuntsman — run in the Studio of the FORGOTTEN LANDS place, in EDIT MODE.
	Makes the body of the Huntsman of the King's Wood (docs/systems/Forest.md): the King's Master of the Hunt, tall and thin,
	on the first blocky rig of the dead (as the Doctor is), in the same rot (the developer: keep the zombies' clothing for every
	figure and build on it). The result is one more master in `ServerStorage.Assets.Undead` named `the_huntsman` (what
	`configs/Enemies.the_huntsman.Body` names), so it moves with every clip the dead have.

	  * HIS FACE is the skull of a stag with its antlers (a mesh made with `generate_mesh`, kept in
	    ServerStorage.Assets.Forest.StagSkull), worn over his own head; two dim points of light deep in the sockets.
	  * A long hunting coat to the knees, a hood thrown back, a belt with a hunting horn at the hip and a knife.
	  * Old leather gloves with real fingers (the same careful hands as the Doctor's).
	  * A boar spear in his right hand: a long ash shaft, a leaf blade and the cross-bar that stops a boar coming up the shaft.
	  * Dressed in RotCloth, RotLeather and RotSkin (MaterialService), one variation of each.

	A copy of `undead_shambler` is stripped of its own dressing (its head and helmet are MODELS of their own: they go too), scaled
	to `BODY` studs (the antlers add the rest of `configs/Forest.Huntsman.Height`), darkened, and dressed: every extra piece is
	welded to a part of the body, so it turns with it. Run again, it replaces the old one.

	NOTE: a tool, not game code. Not synced by Rojo. The result lives in the place (the developer saves it).
]]

local ChangeHistoryService = game:GetService("ChangeHistoryService")
local MaterialService = game:GetService("MaterialService")
local ServerStorage = game:GetService("ServerStorage")

local BODY = 7.2 -- the body's height without the antlers
local FROM = "undead_shambler"

local undead = ServerStorage.Assets:FindFirstChild("Undead")
assert(undead, "ServerStorage.Assets.Undead is not there")
local source = undead:FindFirstChild(FROM)
assert(source and source:IsA("Model"), FROM .. " is not there")

local report = {}
local rng = Random.new(66)

local function variant(base: string): string
	local list = {}
	for _, v in MaterialService:GetDescendants() do
		if v:IsA("MaterialVariant") and (v.Name == base or string.match(v.Name, "^" .. base .. "%d+$")) then
			table.insert(list, v.Name)
		end
	end
	table.sort(list)
	return if #list > 0 then list[rng:NextInteger(1, #list)] else ""
end
local CLOTH, LEATHER_V, SKIN = variant("RotCloth"), variant("RotLeather"), variant("RotSkin")

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

local function gear(model: Model, host: BasePart, name: string, size: Vector3, cf: CFrame, color: Color3, material: Enum.Material, shape: Enum.PartType?, mv: string?): Part
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
	if mv and mv ~= "" then
		p.MaterialVariant = mv
	end
	p.Parent = model
	-- a fixed Weld (a WeldConstraint takes its offset late, when the body enters the world: see Domain/CrawlerBody)
	local w = Instance.new("Weld")
	w.Part0 = host
	w.Part1 = p
	w.C0 = host.CFrame:ToObjectSpace(cf)
	w.Parent = p
	return p
end

-- a rod from `a` to `b` (a cylinder), welded to `host`
local function rod(model: Model, host: BasePart, name: string, a: Vector3, b: Vector3, r: number, color: Color3, material: Enum.Material, mv: string?): Part
	return gear(model, host, name, Vector3.new((b - a).Magnitude, r * 2, r * 2), CFrame.lookAt((a + b) / 2, b) * CFrame.Angles(0, math.rad(90), 0), color, material, Enum.PartType.Cylinder, mv)
end

-- HANDS, as tools/BuildDoctor: a palm, four two-jointed fingers curling to the palm, a thumb
local function hands(model: Model, skin: Color3, material: Enum.Material, o: any)
	for _, side in { { "RightHand", -1 }, { "LeftHand", 1 } } do
		local hand = model:FindFirstChild(side[1] :: string) :: BasePart?
		if hand then
			local inner = side[2] :: number
			local hs = hand.Size
			local cf = hand.CFrame
			local t = math.min(hs.Z * 0.62, hs.X * 0.19)
			local full = o.length or hs.Y
			local lens = { 0.9, 1.0, 0.93, 0.74 }
			local curl1, curl2 = math.rad(o.curl1 or 22), math.rad(o.curl2 or 34)
			for i = 1, 4 do
				local x = inner * hs.X * (0.37 - (i - 1) * 0.245)
				local L = full * lens[i]
				local L1, L2 = L * 0.56, L * 0.44
				local splay = math.rad((i - 2.5) * 5) * -inner
				local knuckle = CFrame.new(x, -hs.Y / 2 + t * 0.35, -hs.Z * 0.06) * CFrame.Angles(0, 0, splay)
				local bend1 = knuckle * CFrame.Angles(curl1 + rng:NextNumber(-0.06, 0.06), 0, 0)
				gear(model, hand, "Finger", Vector3.new(t, L1 + t * 0.4, t), cf * bend1 * CFrame.new(0, -L1 / 2, 0), skin, material, nil, LEATHER_V)
				local bend2 = bend1 * CFrame.new(0, -L1, 0) * CFrame.Angles(curl2 + rng:NextNumber(-0.08, 0.08), 0, 0)
				gear(model, hand, "Finger", Vector3.new(t * 0.86, L2 + t * 0.3, t * 0.86), cf * bend2 * CFrame.new(0, -L2 / 2, 0), skin, material, nil, LEATHER_V)
			end
			local tl = full * 0.62
			local root = CFrame.new(inner * hs.X * 0.5, -hs.Y * 0.05, -hs.Z * 0.15) * CFrame.Angles(0, 0, inner * math.rad(42))
			local t1 = root * CFrame.Angles(math.rad(28), 0, 0)
			gear(model, hand, "Thumb", Vector3.new(t * 1.05, tl * 0.55, t * 1.05), cf * t1 * CFrame.new(0, -tl * 0.27, 0), skin, material, nil, LEATHER_V)
			local t2 = t1 * CFrame.new(0, -tl * 0.55, 0) * CFrame.Angles(math.rad(24), 0, inner * math.rad(-14))
			gear(model, hand, "Thumb", Vector3.new(t * 0.92, tl * 0.48, t * 0.92), cf * t2 * CFrame.new(0, -tl * 0.22, 0), skin, material, nil, LEATHER_V)
			gear(model, hand, "Knuckles", Vector3.new(hs.X * 0.92, t * 0.7, hs.Z * 0.5), cf * CFrame.new(0, -hs.Y / 2 + t * 0.3, hs.Z * 0.2), skin:Lerp(Color3.new(0, 0, 0), 0.08), material, nil, LEATHER_V)
			hand.Color = skin
			hand.Material = material
			hand.MaterialVariant = LEATHER_V
		end
	end
end

local recording = ChangeHistoryService:TryBeginRecording("BuildHuntsman")

local old = undead:FindFirstChild("the_huntsman")
if old then
	old:Destroy()
end
local model = source:Clone()
model.Name = "the_huntsman"
model:SetAttribute("BodyWidth", nil)
-- the shambler's own dressing goes; only the rig's bones stay (its head and helmet are MODELS of their own)
local STRIP = { "^Tab", "^Sk[FBLR]%d", "^StarBar", "^StarCore", "^Rib%d", "^Spine", "^Vein", "^Blotch", "^Tear", "^Rag", "^Pouch", "^Belt", "^Buckle", "^Sleeve", "^HollowLight", "^NeckCord", "^ArrowShaft", "^Fletching", "^skin", "^hair", "^iron", "^bone", "^Finger", "^Thumb" }
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
-- every WeldConstraint the body still has becomes a fixed Weld (see Domain/CrawlerBody: they take their offset late)
for _, d in model:GetDescendants() do
	if d:IsA("WeldConstraint") then
		local a, b = d.Part0, d.Part1
		if a and b then
			local w = Instance.new("Weld")
			w.Part0 = a
			w.Part1 = b
			w.C0 = a.CFrame:ToObjectSpace(b.CFrame)
			w.Parent = d.Parent
		end
		d:Destroy()
	end
end
model.Parent = workspace
model:PivotTo(CFrame.new(0, 200, 0))

-- 1. height
local _, s0 = model:GetBoundingBox()
model:ScaleTo(BODY / s0.Y)
if jointError(model) > 0.05 then
	for _, d in model:GetDescendants() do
		if d:IsA("Motor6D") and d.Part0 and d.Part1 then
			d.C0 = d.Part0.CFrame:Inverse() * d.Part1.CFrame * d.C1
		end
	end
end
local _, s1 = model:GetBoundingBox()
table.insert(report, ("height %.2f -> %.2f (scale %.3f), joints off by %.3f"):format(s0.Y, s1.Y, model:GetScale(), jointError(model)))

-- 2. his own body: grey-brown dead skin under the clothes, dark old leather and cloth
for _, d in model:GetDescendants() do
	if d:IsA("BasePart") and d.Name ~= "HumanoidRootPart" then
		if d.Material == Enum.Material.Concrete then
			d.Color = Color3.fromRGB(96, 88, 80)
			d.MaterialVariant = SKIN
		elseif d.Material == Enum.Material.Fabric then
			d.Color = d.Color:Lerp(Color3.fromRGB(40, 38, 30), 0.6)
			d.MaterialVariant = CLOTH
		elseif d.Material == Enum.Material.Leather then
			d.Color = d.Color:Lerp(Color3.fromRGB(34, 26, 20), 0.6)
			d.MaterialVariant = LEATHER_V
		else
			d.Color = d.Color:Lerp(Color3.fromRGB(20, 18, 16), 0.4)
		end
	end
end

-- 3. dressing
local head = model:FindFirstChild("Head") :: BasePart
local upper = model:FindFirstChild("UpperTorso") :: BasePart
local lower = model:FindFirstChild("LowerTorso") :: BasePart
local rightHand = model:FindFirstChild("RightHand") :: BasePart
assert(head and upper and lower and rightHand, "no Head / UpperTorso / LowerTorso / RightHand")
local COAT = Color3.fromRGB(58, 52, 40) -- a hunter's green-brown, gone dark
local HIDE = Color3.fromRGB(52, 38, 28)
local IRON = Color3.fromRGB(58, 54, 50)
local BONE = Color3.fromRGB(196, 184, 156)
local hs = head.Size
local us = upper.Size
local ls = lower.Size

-- the stag's skull over his head, the antlers up and out
local forest = ServerStorage.Assets:FindFirstChild("Forest")
local skullSrc = forest and forest:FindFirstChild("StagSkull")
if skullSrc then
	local skull = skullSrc:Clone()
	skull.Name = "StagSkull"
	local _, ks = skull:GetBoundingBox()
	-- its width is the antlers' spread: about three heads wide
	skull:ScaleTo((hs.X * 3.3) / ks.X)
	local _, ks2 = skull:GetBoundingBox()
	-- generated facing -Z like the Doctor's mask: the cranium sits on his head, the face forward
	skull:PivotTo(head.CFrame * CFrame.new(0, ks2.Y * 0.22, -hs.Z * 0.18))
	for _, d in skull:GetDescendants() do
		if d:IsA("BasePart") then
			d.Anchored = false
			d.CanCollide = false
			d.CanQuery = false
			d.CanTouch = false
			d.Massless = true
			local w = Instance.new("Weld")
			w.Part0 = head
			w.Part1 = d
			w.C0 = head.CFrame:ToObjectSpace(d.CFrame)
			w.Parent = d
		end
	end
	skull.Parent = model
	-- two dim points of light deep in the sockets
	for _, side in { -1, 1 } do
		local eye = gear(model, head, "Eye", Vector3.new(0.16, 0.16, 0.16), head.CFrame * CFrame.new(side * hs.X * 0.2, hs.Y * 0.12, -hs.Z * 0.62), Color3.fromRGB(210, 230, 190), Enum.Material.Neon, Enum.PartType.Ball)
		local light = Instance.new("PointLight")
		light.Color = Color3.fromRGB(200, 230, 180)
		light.Range = 5
		light.Brightness = 0.6
		light.Shadows = false
		light.Parent = eye
	end
	table.insert(report, ("stag skull worn: %.2f x %.2f x %.2f"):format(ks2.X, ks2.Y, ks2.Z))
else
	warn("BuildHuntsman: ServerStorage.Assets.Forest.StagSkull is missing: no skull")
end
head.Transparency = 0

-- the hood, thrown back on his shoulders
gear(model, upper, "Hood", Vector3.new(us.X * 0.8, us.Y * 0.32, us.Z * 0.7), upper.CFrame * CFrame.new(0, us.Y * 0.42, us.Z * 0.42) * CFrame.Angles(math.rad(-20), 0, 0), COAT, Enum.Material.Fabric, nil, CLOTH)

-- the long coat: back, sides and two front skirts, to the knees, a little open
local long = us.Y * 2.0
for _, sx in { -1, 1 } do
	gear(model, upper, "CoatFront", Vector3.new(us.X * 0.46, long, 0.16), upper.CFrame * CFrame.new(sx * us.X * 0.27, us.Y * 0.5 - long / 2, -us.Z / 2 - 0.09) * CFrame.Angles(math.rad(-4), 0, math.rad(sx * 3)), COAT, Enum.Material.Fabric, nil, CLOTH)
	gear(model, upper, "CoatSide", Vector3.new(0.16, long * 0.98, us.Z * 1.12), upper.CFrame * CFrame.new(sx * (us.X / 2 + 0.09), us.Y * 0.5 - long * 0.49, 0) * CFrame.Angles(0, 0, math.rad(sx * 4)), COAT, Enum.Material.Fabric, nil, CLOTH)
end
gear(model, upper, "CoatBack", Vector3.new(us.X * 1.12, long * 1.02, 0.16), upper.CFrame * CFrame.new(0, us.Y * 0.5 - long * 0.51, us.Z / 2 + 0.09) * CFrame.Angles(math.rad(5), 0, 0), COAT, Enum.Material.Fabric, nil, CLOTH)
-- the collar and the shoulder capelet of hide
gear(model, upper, "Capelet", Vector3.new(us.X * 1.18, us.Y * 0.28, us.Z * 1.2), upper.CFrame * CFrame.new(0, us.Y * 0.36, 0), HIDE, Enum.Material.Leather, nil, LEATHER_V)

-- the belt, a knife, and the horn at his left hip
gear(model, lower, "Belt", Vector3.new(ls.X * 1.12, 0.26, ls.Z * 1.14), lower.CFrame * CFrame.new(0, ls.Y * 0.2, 0), HIDE, Enum.Material.Leather, nil, LEATHER_V)
gear(model, lower, "Buckle", Vector3.new(0.34, 0.3, 0.08), lower.CFrame * CFrame.new(0, ls.Y * 0.2, -ls.Z * 0.58), IRON, Enum.Material.CorrodedMetal)
gear(model, lower, "KnifeSheath", Vector3.new(0.22, 0.9, 0.12), lower.CFrame * CFrame.new(ls.X * 0.4, -ls.Y * 0.3, -ls.Z * 0.5) * CFrame.Angles(0, 0, math.rad(12)), HIDE, Enum.Material.Leather, nil, LEATHER_V)
do
	-- the horn: an ox horn curving back, bound with brass, hung by a strap
	local base = lower.CFrame * CFrame.new(-ls.X * 0.62, -ls.Y * 0.1, -ls.Z * 0.1)
	local pts = { base.Position, (base * CFrame.new(-0.15, -0.35, 0.45)).Position, (base * CFrame.new(-0.1, -0.5, 1.0)).Position, (base * CFrame.new(0.05, -0.38, 1.45)).Position }
	local radii = { 0.26, 0.2, 0.14, 0.09 }
	for i = 1, #pts - 1 do
		rod(model, lower, "Horn", pts[i], pts[i + 1], radii[i], BONE:Lerp(Color3.fromRGB(110, 92, 70), i / 4), Enum.Material.SmoothPlastic)
	end
	rod(model, lower, "HornBand", pts[1] + (pts[2] - pts[1]) * 0.1, pts[1] + (pts[2] - pts[1]) * 0.3, 0.28, Color3.fromRGB(150, 118, 62), Enum.Material.Metal)
	rod(model, lower, "HornStrap", (lower.CFrame * CFrame.new(-ls.X * 0.5, ls.Y * 0.2, 0)).Position, pts[2], 0.05, HIDE, Enum.Material.Leather, LEATHER_V)
end

-- the boar spear in his right hand: the shaft runs through the fist, the head up and forward
do
	-- laid out in the body's own rest pose: lowered, the head out in front at chest height, through the right fist (upright,
	-- it ran across his face: the dead hold their right hand out before them)
	local hand = rightHand
	local fwd = model:GetPivot().LookVector
	local up = (Vector3.yAxis * 0.45 + fwd + model:GetPivot().RightVector * 0.12).Unit
	local right = fwd:Cross(up).Unit
	local grip = hand.Position
	local butt = grip - up * 3.4
	local top = grip + up * 5.2
	rod(model, hand, "SpearShaft", butt, top, 0.12, Color3.fromRGB(96, 74, 52), Enum.Material.Wood)
	-- the leaf blade, flat across, standing along the shaft
	gear(model, hand, "SpearBlade", Vector3.new(0.5, 1.8, 0.08), CFrame.fromMatrix(top + up * 0.9, right, up), IRON, Enum.Material.CorrodedMetal)
	gear(model, hand, "SpearTip", Vector3.new(0.24, 0.5, 0.06), CFrame.fromMatrix(top + up * 2.0, right, up), IRON, Enum.Material.CorrodedMetal)
	-- the cross-bar under it
	local barAt = top - up * 0.2
	rod(model, hand, "SpearBar", barAt - right * 0.55, barAt + right * 0.55, 0.07, IRON, Enum.Material.CorrodedMetal)
	-- a hide wrap where the hand holds it
	rod(model, hand, "SpearWrap", grip - up * 0.5, grip + up * 0.5, 0.15, HIDE, Enum.Material.Leather, LEATHER_V)
end

-- 4. his hands, in old leather gloves
hands(model, Color3.fromRGB(46, 36, 28), Enum.Material.Leather, { curl1 = 30, curl2 = 44, length = rightHand.Size.Y * 1.2 })

-- 5. into the store
model:PivotTo(CFrame.new(0, 3, 0))
model.Parent = undead
local _, finalSize = model:GetBoundingBox()
table.insert(report, ("the_huntsman in Assets.Undead: %.2f wide, %.2f high, %.2f deep, %d parts"):format(finalSize.X, finalSize.Y, finalSize.Z, #model:GetDescendants()))

if recording then
	ChangeHistoryService:FinishRecording(recording, Enum.FinishRecordingOperation.Commit)
end
return report
